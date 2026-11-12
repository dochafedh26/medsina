import 'package:flutter/material.dart';

class MedicalAchievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int targetValue;
  final int currentValue;
  final int xpReward;

  const MedicalAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetValue,
    required this.currentValue,
    required this.xpReward,
  });

  bool get isUnlocked => currentValue >= targetValue;

  double get progress =>
      targetValue <= 0 ? 1.0 : (currentValue / targetValue).clamp(0.0, 1.0);
}
