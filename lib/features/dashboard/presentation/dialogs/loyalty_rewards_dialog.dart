import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/user_loyalty_service.dart';
import '../../../../core/theme/app_theme.dart';

class LoyaltyRewardsDialog extends StatelessWidget {
  final UserLoyaltyStats stats;

  const LoyaltyRewardsDialog({super.key, required this.stats});

  static Future<void> show(BuildContext context, UserLoyaltyStats stats) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LoyaltyRewardsDialog(stats: stats),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Chef de Clinique Élite':
        return const Color(0xFFEAB308); // Gold
      case 'Résident Major':
        return const Color(0xFF8B5CF6); // Purple
      case 'Interne Assidu':
        return const Color(0xFF0EA5E9); // Blue
      default:
        return AppTheme.primaryTeal;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Chef de Clinique Élite':
        return Icons.military_tech_rounded;
      case 'Résident Major':
        return Icons.workspace_premium_rounded;
      case 'Interne Assidu':
        return Icons.verified_user_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final levelColor = _getLevelColor(stats.loyaltyLevel);
    final levelIcon = _getLevelIcon(stats.loyaltyLevel);
    final now = DateTime.now();

    // Past 7 days for the weekly tracker
    final pastWeekDays = List.generate(7, (i) {
      return now.subtract(Duration(days: 6 - i));
    });

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Programme de Fidélité',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${stats.connectionCount} connexions enregistrées',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 16,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Rank Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      levelColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      levelColor.withValues(alpha: isDark ? 0.10 : 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: levelColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(levelIcon, color: levelColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stats.loyaltyLevel,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: levelColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${stats.loyaltyPoints} Points XP cumulés',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                '${stats.streakDays}j',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF97316),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Progress to next rank
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progression vers ${stats.nextLevelName}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            Text(
                              '${stats.loyaltyPoints} / ${stats.nextLevelThreshold} XP',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: levelColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: stats.progressToNextLevel,
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.black26 : Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 7-day Weekly Habit Tracker
              const Text(
                'Assiduité des 7 Derniers Jours',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: pastWeekDays.map((day) {
                    final isActive = stats.isDayActive(day);
                    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                    final dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                    final label = dayLabels[(day.weekday - 1) % 7];

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                            color: isToday ? AppTheme.primaryTeal : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white10 : Colors.grey.shade300),
                            border: isToday
                                ? Border.all(color: AppTheme.primaryTeal, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              isActive ? Icons.check_rounded : Icons.circle,
                              size: isActive ? 18 : 6,
                              color: isActive ? Colors.white : (isDark ? Colors.white24 : Colors.grey.shade500),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Privileges & Rewards Unlocked
              const Text(
                'Vos Avantages & Récompenses',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _buildPerkTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Record Personnel de Série',
                subtitle: '${stats.maxStreakDays} jours consécutifs ininterrompus',
                isDark: isDark,
              ),
              _buildPerkTile(
                icon: Icons.percent_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Remise VIP Déblocable (-15%)',
                subtitle: stats.loyaltyPoints >= 300
                    ? 'Débloqué ! Utilisez le code MAJOR15 lors de votre renouvellement.'
                    : 'Atteignez le rang Résident Major (300 XP) pour débloquer.',
                isDark: isDark,
                isUnlocked: stats.loyaltyPoints >= 300,
              ),
              _buildPerkTile(
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Quotas Tuteur IA Doublés',
                subtitle: stats.loyaltyPoints >= 700
                    ? 'Actif ! Vous bénéficiez du doublement de vos questions d\'analyse.'
                    : 'Accessible au rang Chef de Clinique Élite (700 XP).',
                isDark: isDark,
                isUnlocked: stats.loyaltyPoints >= 700,
              ),
              const SizedBox(height: 18),

              // How to earn XP summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, color: AppTheme.primaryTeal, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Astuce : Ouvrez l\'application chaque jour (+10 XP) et terminez une série de QCMs (+15 XP) pour grimper dans le classement !',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Share button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Text('🔥', style: TextStyle(fontSize: 16)),
                label: Text(
                  'Partager ma Série (${stats.streakDays} jours) avec mes collègues',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () async {
                  final text = Uri.encodeComponent(
                    '🔥 J\'ai validé ${stats.streakDays} jours d\'affilée de révision sur Medsina (Niveau : ${stats.loyaltyLevel}) ! Rejoins notre groupe d\'entraide : https://t.me/+TVTTgt8eIMk5NmI0',
                  );
                  final uri = Uri.parse('https://t.me/share/url?url=https://t.me/+TVTTgt8eIMk5NmI0&text=$text');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerkTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    bool isUnlocked = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isUnlocked ? iconColor : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isUnlocked ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isUnlocked)
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
