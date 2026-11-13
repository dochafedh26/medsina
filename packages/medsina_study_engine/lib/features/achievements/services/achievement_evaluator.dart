import 'package:flutter/material.dart';
import 'package:medsina_core/core/services/user_study_progress_service.dart';
import 'package:medsina_core/core/theme/theme_controller.dart';
import 'package:medsina_practical_tools/features/focus/services/focus_timer_service.dart';
import '../../revision/models/flashcard_fsrs_model.dart';
import '../models/achievement_model.dart';

class AchievementEvaluator {
  const AchievementEvaluator._();

  static Future<List<MedicalAchievement>> evaluateLive() async {
    final progress = await UserStudyProgressService.instance.initialize();
    await FlashcardFsrsService.instance.ensureInitialized();
    final cards = FlashcardFsrsService.instance.cards;
    final focus = FocusTimerService.instance;
    await focus.initialize();
    final isNightShift = ThemeController.instance.isNightShiftActive;

    return evaluate(
      totalQcmSolved: progress.totalQcmSolved,
      averageAccuracy: progress.averageAccuracy,
      currentStreak: progress.currentStreak,
      maxStreak: progress.maxStreak,
      focusSessions: focus.completedSessionsTotal,
      fsrsCardsCount: cards.length,
      nightShiftUsed: isNightShift,
    );
  }

  static List<MedicalAchievement> evaluate({
    required int totalQcmSolved,
    required double averageAccuracy,
    required int currentStreak,
    required int maxStreak,
    required int focusSessions,
    required int fsrsCardsCount,
    required bool nightShiftUsed,
  }) {
    final bestStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
    final precisionScore =
        totalQcmSolved >= 50 ? averageAccuracy.round() : 0;

    return [
      MedicalAchievement(
        id: 'premier_pas',
        title: 'Premier Pas',
        description: 'Résoudre votre tout premier QCM officiel sur Medsina.',
        icon: Icons.flag_rounded,
        color: const Color(0xFF10B981),
        targetValue: 1,
        currentValue: totalQcmSolved,
        xpReward: 25,
      ),
      MedicalAchievement(
        id: 'centurion_blida',
        title: 'Centurion Blida',
        description: 'Atteindre 100 QCM résolus en entraînement ou concours.',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFF0D9488),
        targetValue: 100,
        currentValue: totalQcmSolved,
        xpReward: 100,
      ),
      MedicalAchievement(
        id: 'major_en_puissance',
        title: 'Major en Puissance',
        description: 'Franchir le cap des 500 QCM résolus.',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF8B5CF6),
        targetValue: 500,
        currentValue: totalQcmSolved,
        xpReward: 300,
      ),
      MedicalAchievement(
        id: 'assiduite_7j',
        title: 'Assiduité 7j',
        description: 'Maintenir une série de 7 jours consécutifs de révision.',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFF59E0B),
        targetValue: 7,
        currentValue: bestStreak,
        xpReward: 150,
      ),
      MedicalAchievement(
        id: 'concentration_profonde',
        title: 'Concentration Profonde',
        description: 'Terminer 5 sessions Focus Pomodoro complètes.',
        icon: Icons.timer_rounded,
        color: const Color(0xFF0284C7),
        targetValue: 5,
        currentValue: focusSessions,
        xpReward: 120,
      ),
      MedicalAchievement(
        id: 'memoire_fsrs',
        title: 'Mémoire FSRS',
        description: 'Constituer un deck de 20 flashcards FSRS v4.5.',
        icon: Icons.psychology_rounded,
        color: const Color(0xFFEC4899),
        targetValue: 20,
        currentValue: fsrsCardsCount,
        xpReward: 140,
      ),
      MedicalAchievement(
        id: 'precision_chirurgicale',
        title: 'Précision Chirurgicale',
        description: 'Maintenir ≥ 80% de précision sur au moins 50 QCM.',
        icon: Icons.gps_fixed_rounded,
        color: const Color(0xFF14B8A6),
        targetValue: 80,
        currentValue: precisionScore,
        xpReward: 200,
      ),
      MedicalAchievement(
        id: 'garde_de_nuit',
        title: 'Garde de Nuit',
        description: 'Activer le mode AMOLED Ambre pour réviser sans fatigue.',
        icon: Icons.nightlight_round,
        color: const Color(0xFFF59E0B),
        targetValue: 1,
        currentValue: nightShiftUsed ? 1 : 0,
        xpReward: 50,
      ),
    ];
  }

  static int totalEarnedXp(List<MedicalAchievement> list) {
    return list
        .where((a) => a.isUnlocked)
        .fold<int>(0, (sum, a) => sum + a.xpReward);
  }
}
