// AuraMind — Module 1: Zero-Knowledge Anonymous Community Forum
// Author: Abdullah Al Hamim (22299096)
//
// Deterministically derives a color + icon from avatarSeed so the same
// pseudonym always looks the same, without storing any actual image.

import 'package:flutter/material.dart';

class PseudonymAvatar extends StatelessWidget {
  final String seed;
  final double radius;

  const PseudonymAvatar({super.key, required this.seed, this.radius = 20});

  static const _palette = [
    Color(0xFF7C9885), // sage
    Color(0xFF8E7CC3), // lavender
    Color(0xFFD4A574), // sand
    Color(0xFF6FA8DC), // sky
    Color(0xFFE07A5F), // terracotta
    Color(0xFF81B29A), // mint
  ];

  static const _icons = [
    Icons.spa_outlined,
    Icons.eco_outlined,
    Icons.water_drop_outlined,
    Icons.brightness_5_outlined,
    Icons.nightlight_outlined,
    Icons.cloud_outlined,
  ];

  int _hashSeed() => seed.codeUnits.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final hash = _hashSeed();
    final color = _palette[hash % _palette.length];
    final icon = _icons[hash % _icons.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: radius),
    );
  }
}
