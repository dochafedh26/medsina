import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'ai_pack_purchase_modal.dart';

class AiQuotaExhaustedDialog extends StatelessWidget {
  final int dailyLimit;
  final int dailyUsed;
  final int bonusRemaining;

  const AiQuotaExhaustedDialog({
    super.key,
    required this.dailyLimit,
    required this.dailyUsed,
    required this.bonusRemaining,
  });

  static Future<void> show(
    BuildContext context, {
    required int dailyLimit,
    required int dailyUsed,
    required int bonusRemaining,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AiQuotaExhaustedDialog(
        dailyLimit: dailyLimit,
        dailyUsed: dailyUsed,
        bonusRemaining: bonusRemaining,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Top Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 36),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Quota Journalier IA Atteint',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Vous avez consommé vos $dailyLimit requêtes quotidiennes allouées pour aujourd\'hui afin de garantir une disponibilité optimale à tous.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Progress Bar Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Consommation du Jour',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$dailyUsed / $dailyLimit requêtes',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Réinitialisation automatique gratuite demain à 00h00.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Attendre Demain', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text(
                      'Recharger IA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      AiPackPurchaseModal.show(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

