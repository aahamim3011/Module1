# AuraMind — Module 1 (Forum) — Local Setup Guide (Mac)

এই গাইড অনুসরণ করে তোমার Mac-এ Module 1 (Zero-Knowledge Anonymous
Community Forum) ব্যাকএন্ড চালিয়ে দেখতে পারবে।

---

## ধাপ ১: প্রয়োজনীয় জিনিস ইনস্টল

```bash
# Homebrew না থাকলে আগে ইনস্টল করো: https://brew.sh

# PostgreSQL ইনস্টল করো
brew install postgresql@16
brew services start postgresql@16

# Python 3.11+ আছে কিনা চেক করো
python3 --version
```

---

## ধাপ ২: ডেটাবেস বানাও

```bash
# psql শেলে ঢোকো
psql postgres

# ভেতরে এই কমান্ডগুলো চালাও
CREATE USER auramind WITH PASSWORD 'auramind_dev' SUPERUSER;
CREATE DATABASE auramind_db OWNER auramind;
\q
```

তারপর schema লোড করো:

```bash
psql -U auramind -d auramind_db -h localhost -f database/demo_users.sql
psql -U auramind -d auramind_db -h localhost -f database/forum_schema.sql
```

> `demo_users.sql` টেস্টের জন্য একটা মিনিমাল `users` টেবিল আর দুইজন ডামি
> ইউজার বানায়। আসল প্রজেক্টে এটা Auth module-এর টেবিলের জায়গায় বসবে —
> তখন এই ফাইলটা লাগবে না।

---

## ধাপ ৩: Python ভার্চুয়াল এনভায়রনমেন্ট + ডিপেন্ডেন্সি

```bash
cd backend
python3 -m venv venv
source venv/bin/activate

pip install fastapi uvicorn sqlalchemy psycopg2-binary httpx pydantic
```

---

## ধাপ ৪: সার্ভার চালাও

```bash
# backend/ ফোল্ডারের ভেতর থেকে
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

ব্রাউজারে গিয়ে দেখো: **http://localhost:8000** — `{"status":"ok",...}`
দেখালে সার্ভার চলছে।

Interactive API docs (Swagger UI) দেখতে চাইলে:
**http://localhost:8000/docs** — এখান থেকেই সরাসরি ব্রাউজার থেকে
প্রতিটা endpoint টেস্ট করা যায়, কোনো curl লাগে না।

---

## ধাপ ৫: টেস্ট ইউজার আইডি বের করো

```bash
psql -U auramind -d auramind_db -h localhost \
  -c "SELECT user_id, username FROM users;"
```

দুইটা UUID পাবে (rafi123, mim_writes) — এগুলো demo auth-এর জন্য লাগবে।

---

## ধাপ ৬: একটা পোস্ট বানিয়ে টেস্ট করো

```bash
RAFI_ID="<উপরের কমান্ড থেকে পাওয়া UUID বসাও>"

curl -X POST http://localhost:8000/forum/posts \
  -H "Content-Type: application/json" \
  -H "X-Demo-User-Id: $RAFI_ID" \
  -d '{
    "title": "Test post",
    "body": "My email is test@example.com, reach me at 01711223344"
  }'
```

Response-এ দেখবে email আর phone number স্বয়ংক্রিয়ভাবে
`[email removed]` / `[phone number removed]` হয়ে গেছে, আর একটা
pseudonym (যেমন `QuietMeadow123`) অ্যাসাইন হয়েছে।

Feed দেখতে:
```bash
curl http://localhost:8000/forum/posts
```

Report করতে (অন্য ইউজারের আইডি দিয়ে):
```bash
MIM_ID="<mim এর UUID>"
POST_ID="<উপরের response থেকে post_id>"

curl -X POST http://localhost:8000/forum/reports \
  -H "Content-Type: application/json" \
  -H "X-Demo-User-Id: $MIM_ID" \
  -d "{\"post_id\": \"$POST_ID\", \"reason\": \"triggering\"}"
```

তারপর আবার feed দেখলে পোস্টটা আর থাকবে না (auto-hidden)।

---

## নোট

- `app/auth/dependencies.py`-এর `X-Demo-User-Id` header দিয়ে auth simulate
  করা হয়েছে। আসল প্রজেক্টে টিমের JWT-based auth module বসবে, এই ফাইলটা
  তখন বাদ যাবে।
- `app/models/user.py` শুধু demo-এর জন্য একটা হালকা User model — Auth
  module-এর নিজস্ব model থাকলে এটা বাদ দিয়ে সেটাই ইমপোর্ট করবে।
- AI moderation (Hugging Face) টেস্ট করতে `HF_API_TOKEN` environment
  variable সেট করতে হবে:
  ```bash
  export HF_API_TOKEN="your_token_here"
  ```
  টোকেন ছাড়া চালালে moderation ধাপ skip হয়ে যায়, error দেয় না।
