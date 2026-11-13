import 'package:flutter/material.dart';
import 'package:medsina_core/core/services/user_loyalty_service.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import '../dialogs/loyalty_rewards_dialog.dart';

class LoyaltyStreakCard extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const LoyaltyStreakCard({
    super.key,
    this.margin = EdgeInsets.zero,
  });

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
        final progressRatio = stats.nextLevelThreshold > 0
            ? (stats.loyaltyPoints / stats.nextLevelThreshold).clamp(0.0, 1.0)
            : 1.0;

        return Container(
          margin: margin,
          decoration: AppTheme.bentoCardDecoration(
            context,
            radius: 22,
            borderColor: levelColor.withValues(alpha: isDark ? 0.35 : 0.22),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => LoyaltyRewardsDialog.show(context, stats),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF97316).withValues(alpha: 0.18),
                                const Color(0xFFFB923C).withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFF97316).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
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
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Paliers 🎁',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: levelColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: levelColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: levelColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stats.loyaltyLevel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Assiduité clinique • ${stats.connectionCount}e session',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${stats.loyaltyPoints} XP',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: levelColor,
                              ),
                            ),
                            Text(
                              'Objectif : ${stats.nextLevelThreshold} XP',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 7,
                            backgroundColor: levelColor.withValues(alpha: 0.14),
                            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
