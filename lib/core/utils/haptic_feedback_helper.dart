import 'package:flutter/services.dart';

/// Differentiated tactile haptic feedback for Medsina study interactions.
class HapticFeedbackHelper {
  const HapticFeedbackHelper._();

  static Future<void> onCorrectAnswer() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> onWrongAnswer() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> onMilestone() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> onTap() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
