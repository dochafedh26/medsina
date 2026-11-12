import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/theme/app_theme.dart';
import 'package:medsina/core/theme/medsina_colors.dart';
import 'package:medsina/core/theme/theme_controller.dart';
import 'package:medsina/features/achievements/services/achievement_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MedsinaColors & Night Shift Theme', () {
    test('nightShift uses pure AMOLED black background and amber accent', () {
      expect(MedsinaColors.nightShift.background, const Color(0xFF000000));
      expect(MedsinaColors.nightShift.accent, const Color(0xFFF59E0B));
      expect(MedsinaColors.nightShift.isNightShift, isTrue);
      expect(AppTheme.nightShiftTheme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('MedsinaColors lerp and copyWith preserve tokens', () {
      final lerped = MedsinaColors.light.lerp(MedsinaColors.nightShift, 1.0);
      expect(lerped.background, MedsinaColors.nightShift.background);
      expect(lerped.isNightShift, isTrue);

      final copied = MedsinaColors.dark.copyWith(accent: Colors.red);
      expect(copied.accent, Colors.red);
    });

    test('ThemeController auto-activates Night Shift after 22h when enabled', () async {
      final tc = ThemeController.instance;
      await tc.setChoice(AppThemeChoice.system);
      await tc.setAutoNightShiftAfter22h(true);

      expect(tc.isNightShiftActiveAt(DateTime(2026, 11, 12, 23, 0)), isTrue);
      expect(tc.isNightShiftActiveAt(DateTime(2026, 11, 12, 14, 0)), isFalse);

      await tc.setAutoNightShiftAfter22h(false);
    });
  });

  group('AchievementEvaluator', () {
    test('evaluates all 8 trophies and computes unlocked XP accurately', () {
      final items = AchievementEvaluator.evaluate(
        totalQcmSolved: 120,
        averageAccuracy: 84.0,
        currentStreak: 7,
        maxStreak: 7,
        focusSessions: 5,
        fsrsCardsCount: 25,
        nightShiftUsed: true,
      );

      expect(items.length, 8);
      final unlocked = items.where((a) => a.isUnlocked).toList();
      // All except major_en_puissance (500 QCMs) should be unlocked
      expect(unlocked.length, 7);
      expect(
        AchievementEvaluator.totalEarnedXp(items),
        25 + 100 + 150 + 120 + 140 + 200 + 50,
      );
    });
  });
}
