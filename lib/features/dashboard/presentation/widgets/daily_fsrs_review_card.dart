import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../revision/models/flashcard_fsrs_model.dart';
import '../../../revision/presentation/flashcards_fsrs_screen.dart';

class DailyFsrsReviewCard extends StatefulWidget {
  const DailyFsrsReviewCard({super.key});

  @override
  State<DailyFsrsReviewCard> createState() => _DailyFsrsReviewCardState();
}

class _DailyFsrsReviewCardState extends State<DailyFsrsReviewCard> {
  final FlashcardFsrsService _service = FlashcardFsrsService.instance;

  @override
  void initState() {
    super.initState();
    _service.ensureInitialized();
  }

  void _openFullFsrsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FlashcardsFsrsScreen()),
    );
  }

  Future<void> _openQuickReviewModal() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _QuickFsrsReviewDialog(service: _service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final dueCards = _service.dueCards;
        final totalCards = _service.cards.length;
        final matureCards = _service.cards.where((c) => c.isMature).length;
        final dueCount = dueCards.length;
        final hasDue = dueCount > 0;
        final accentColor = hasDue ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
        final masteryRatio = totalCards > 0 ? (matureCards / totalCards).clamp(0.0, 1.0) : 0.0;

        return Container(
          decoration: AppTheme.bentoCardDecoration(
            context,
            radius: 22,
            borderColor: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasDue ? Icons.bolt_rounded : Icons.verified_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'RÉVISION ESPACÉE FSRS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openFullFsrsScreen,
                      icon: const Icon(Icons.style_rounded, size: 16),
                      label: Text(
                        '$totalCards cartes',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Main Content Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasDue
                                ? '$dueCount ${dueCount == 1 ? "carte due" : "cartes dues"} aujourd\'hui'
                                : 'Objectif FSRS atteint pour aujourd\'hui ! 🎉',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasDue
                                ? 'Prochaine carte : ${dueCards.first.courseName.isNotEmpty ? dueCards.first.courseName : "Révision médicale"}'
                                : 'Toutes vos cartes programmées sont mémorisées ($matureCards/$totalCards matures).',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: hasDue ? _openQuickReviewModal : _openFullFsrsScreen,
                      icon: Icon(
                        hasDue ? Icons.play_arrow_rounded : Icons.explore_rounded,
                        size: 18,
                      ),
                      label: Text(
                        hasDue ? 'Révision éclair' : 'Explorer',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasDue ? AppTheme.primaryTeal : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Retention / Mastery Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: masteryRatio,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickFsrsReviewDialog extends StatefulWidget {
  final FlashcardFsrsService service;

  const _QuickFsrsReviewDialog({required this.service});

  @override
  State<_QuickFsrsReviewDialog> createState() => _QuickFsrsReviewDialogState();
}

class _QuickFsrsReviewDialogState extends State<_QuickFsrsReviewDialog> {
  bool _showBack = false;
  int _reviewedCount = 0;

  Future<void> _rateCard(FlashcardFsrsItem card, FsrsRating rating) async {
    await widget.service.reviewCard(card, rating);
    if (!mounted) return;
    setState(() {
      _showBack = false;
      _reviewedCount += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final dueCards = widget.service.dueCards;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 540,
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: dueCards.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.celebration_rounded,
                          size: 52,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Session éclair terminée !',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vous avez révisé $_reviewedCount ${_reviewedCount <= 1 ? "carte" : "cartes"} avec succès.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retour au Tableau de bord'),
                        ),
                      ],
                    )
                  : _buildCardReviewBody(context, dueCards.first, dueCards.length, isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardReviewBody(
    BuildContext context,
    FlashcardFsrsItem card,
    int remainingCount,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                card.courseName.isNotEmpty ? card.courseName : 'Flashcard FSRS',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '$remainingCount restante${remainingCount > 1 ? "s" : ""}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: MarkdownBody(data: card.front),
                ),
                if (_showBack) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: MarkdownBody(data: card.back),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_showBack)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showBack = true),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text(
                'Afficher la réponse',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.clinicalNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              _ratingBtn(card, FsrsRating.again, 'À revoir', const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _ratingBtn(card, FsrsRating.hard, 'Difficile', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _ratingBtn(card, FsrsRating.good, 'Bien', const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _ratingBtn(card, FsrsRating.easy, 'Facile', const Color(0xFF3B82F6)),
            ],
          ),
      ],
    );
  }

  Widget _ratingBtn(
    FlashcardFsrsItem card,
    FsrsRating rating,
    String label,
    Color color,
  ) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _rateCard(card, rating),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }
}
