-- =====================================================================
-- AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
-- Author: Abdullah Al Hamim (22299096)
-- Database: PostgreSQL
-- =====================================================================
-- Design decision: pseudonyms are FIXED per user (persistent), never
-- randomized per post. This preserves community trust/continuity while
-- keeping the pseudonym fully decoupled from any user-identifying data
-- in every publicly-readable table.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. USERS  (assumed to already exist from the Auth module — shown here
--    only for foreign-key reference; do NOT recreate if it already
--    exists in the shared schema)
-- ---------------------------------------------------------------------
-- CREATE TABLE users (
--     user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--     email         VARCHAR(255) UNIQUE NOT NULL,
--     username      VARCHAR(100) UNIQUE NOT NULL,
--     phone_number  VARCHAR(20),
--     password_hash TEXT NOT NULL,
--     role          VARCHAR(20) NOT NULL DEFAULT 'end_user',
--     created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- ---------------------------------------------------------------------
-- 2. PSEUDONYMS
--    One row per user. This is the ONLY table that links a real
--    user_id to a forum identity. It must NEVER be joined into any
--    public-facing query/view/API response.
-- ---------------------------------------------------------------------
CREATE TABLE forum_pseudonyms (
    pseudonym_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    display_name    VARCHAR(50) NOT NULL UNIQUE,   -- e.g. "QuietOtter42"
    avatar_seed     VARCHAR(50) NOT NULL,          -- deterministic seed for a generated avatar icon
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE forum_pseudonyms IS
    'Sensitive linkage table: user_id <-> pseudonym. Access restricted to backend service role only.';

-- ---------------------------------------------------------------------
-- 3. FORUM POSTS
--    Public-facing content. References pseudonym_id ONLY — never
--    user_id — so anything served to the client is already anonymous
--    at the data layer, not just the API layer.
-- ---------------------------------------------------------------------
CREATE TABLE forum_posts (
    post_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pseudonym_id        UUID NOT NULL REFERENCES forum_pseudonyms(pseudonym_id) ON DELETE CASCADE,
    parent_post_id      UUID REFERENCES forum_posts(post_id) ON DELETE CASCADE, -- NULL = top-level post, else a reply
    title               VARCHAR(200),              -- NULL for replies
    body                TEXT NOT NULL,
    scrubbed_body       TEXT,                       -- PII-scrubbed version actually rendered publicly
    moderation_status   VARCHAR(20) NOT NULL DEFAULT 'pending'
                          CHECK (moderation_status IN ('pending','approved','quarantined','removed')),
    is_hidden           BOOLEAN NOT NULL DEFAULT false,  -- flipped true instantly by SafeSpace reports
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_forum_posts_pseudonym ON forum_posts(pseudonym_id);
CREATE INDEX idx_forum_posts_parent ON forum_posts(parent_post_id);
CREATE INDEX idx_forum_posts_status ON forum_posts(moderation_status) WHERE is_hidden = false;
CREATE INDEX idx_forum_posts_created ON forum_posts(created_at DESC);

-- ---------------------------------------------------------------------
-- 4. AI MODERATION QUEUE
--    Every post gets a row here once scored by the content-moderation
--    classifier. Admin reviews items above threshold.
-- ---------------------------------------------------------------------
CREATE TABLE moderation_queue (
    queue_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id         UUID NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
    flag_type       VARCHAR(30) NOT NULL
                      CHECK (flag_type IN ('bullying','hate_speech','spam','self_harm_risk','other')),
    confidence      NUMERIC(4,3) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
    model_version   VARCHAR(50) NOT NULL,           -- e.g. "bert-forum-mod-v1.2"
    reviewed        BOOLEAN NOT NULL DEFAULT false,
    reviewed_by     UUID REFERENCES users(user_id), -- admin who resolved it
    review_decision VARCHAR(20) CHECK (review_decision IN ('approve','remove', NULL)),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at     TIMESTAMPTZ
);

CREATE INDEX idx_moderation_queue_unreviewed ON moderation_queue(reviewed) WHERE reviewed = false;

-- ---------------------------------------------------------------------
-- 5. SAFESPACE REPORTS
--    User-driven reporting. Any user (identified only by their OWN
--    pseudonym as reporter) can flag a post. First report hides it
--    instantly pending admin review.
-- ---------------------------------------------------------------------
CREATE TABLE safespace_reports (
    report_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id         UUID NOT NULL REFERENCES forum_posts(post_id) ON DELETE CASCADE,
    reporter_pseudonym_id UUID NOT NULL REFERENCES forum_pseudonyms(pseudonym_id),
    reason          VARCHAR(30) NOT NULL
                      CHECK (reason IN ('harmful','triggering','harassment','spam','other')),
    details         TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'open'
                      CHECK (status IN ('open','resolved_removed','resolved_reinstated')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at     TIMESTAMPTZ,
    resolved_by     UUID REFERENCES users(user_id)
);

CREATE INDEX idx_safespace_reports_post ON safespace_reports(post_id);
CREATE INDEX idx_safespace_reports_status ON safespace_reports(status) WHERE status = 'open';

-- ---------------------------------------------------------------------
-- 6. TRIGGER: auto-hide a post the instant it receives its first
--    open SafeSpace report (matches spec: "instantly triggers ...
--    temporarily hides the post ... until reviewed by an admin")
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_hide_post_on_report()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE forum_posts
    SET is_hidden = true,
        updated_at = now()
    WHERE post_id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_hide_post_on_report
AFTER INSERT ON safespace_reports
FOR EACH ROW
EXECUTE FUNCTION fn_hide_post_on_report();

-- ---------------------------------------------------------------------
-- 7. VIEW: what the public API is actually allowed to SELECT from.
--    Never expose forum_posts or forum_pseudonyms directly to clients —
--    always go through this view.
-- ---------------------------------------------------------------------
CREATE VIEW public_forum_feed AS
SELECT
    p.post_id,
    p.parent_post_id,
    p.title,
    COALESCE(p.scrubbed_body, p.body) AS body,
    fp.display_name,
    fp.avatar_seed,
    p.created_at
FROM forum_posts p
JOIN forum_pseudonyms fp ON fp.pseudonym_id = p.pseudonym_id
WHERE p.moderation_status = 'approved'
  AND p.is_hidden = false;
