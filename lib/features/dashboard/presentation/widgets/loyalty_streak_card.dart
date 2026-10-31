import 'package:flutter/material.dart';
import '../../../../core/services/user_loyalty_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../dialogs/loyalty_rewards_dialog.dart';

class LoyaltyStreakCard extends StatelessWidget {
  const LoyaltyStreakCard({super.key});

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Chef de Clinique Élite':
        return const Color(0xFFEAB308);
      case 'Résident Major':
        return const Color(0xFF8B5CF6);
      case 'Interne Assidu':
        return const Color(0xFF0EA5E9);
      default:
        return AppTheme.primaryTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<UserLoyaltyStats>(
      valueListenable: UserLoyaltyService.instance.statsNotifier,
      builder: (context, stats, _) {
        final levelColor = _getLevelColor(stats.loyaltyLevel);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                levelColor.withValues(alpha: isDark ? 0.18 : 0.08),
                const Color(0xFFF97316).withValues(alpha: isDark ? 0.12 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: levelColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => LoyaltyRewardsDialog.show(context, stats),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;

                    final streakBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text(
                            '${stats.streakDays}j d\'affilée',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    );

                    final levelInfo = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stats.loyaltyLevel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: levelColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${stats.connectionCount}e connexion',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${stats.loyaltyPoints} XP',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• Prochain rang dans ${stats.nextLevelThreshold - stats.loyaltyPoints} XP',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    final ctaButton = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Récompenses',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: levelColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: levelColor),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              streakBadge,
                              ctaButton,
                            ],
                          ),
                          const SizedBox(height: 8),
                          levelInfo,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        streakBadge,
                        const SizedBox(width: 14),
                        Expanded(child: levelInfo),
                        const SizedBox(width: 8),
                        ctaButton,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

