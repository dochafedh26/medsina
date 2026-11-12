import 'package:flutter/material.dart';
import '../../../core/theme/medsina_colors.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../models/achievement_model.dart';
import '../services/achievement_evaluator.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<MedicalAchievement> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await AchievementEvaluator.evaluateLive();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final unlockedCount = _items.where((a) => a.isUnlocked).length;
    final earnedXp = AchievementEvaluator.totalEarnedXp(_items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges & Succès Médicaux'),
      ),
      body: _loading
          ? const SkeletonCardList(itemCount: 5, itemHeight: 96)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: mc.accentSoft,
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: mc.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          size: 38, color: mc.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$unlockedCount / ${_items.length} Trophées débloqués',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: mc.textPrimary,
                                  ),
                            ),
                            Text(
                              '$earnedXp XP cumulés grâce aux succès',
                              style: TextStyle(color: mc.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._items.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: mc.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: a.isUnlocked
                              ? a.color.withValues(alpha: 0.5)
                              : mc.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: (a.isUnlocked ? a.color : mc.textSecondary)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              a.icon,
                              color: a.isUnlocked ? a.color : mc.textSecondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: mc.textPrimary,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      '+${a.xpReward} XP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: a.isUnlocked
                                            ? a.color
                                            : mc.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.description,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: mc.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: a.progress,
                                    minHeight: 7,
                                    backgroundColor: mc.surfaceElevated,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      a.isUnlocked ? a.color : mc.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
