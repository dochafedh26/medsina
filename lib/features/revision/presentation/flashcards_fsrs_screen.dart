import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_theme.dart';
import '../models/flashcard_fsrs_model.dart';

class FlashcardsFsrsScreen extends StatefulWidget {
  const FlashcardsFsrsScreen({super.key});

  @override
  State<FlashcardsFsrsScreen> createState() => _FlashcardsFsrsScreenState();
}

class _FlashcardsFsrsScreenState extends State<FlashcardsFsrsScreen> {
  final FlashcardFsrsService _service = FlashcardFsrsService.instance;
  bool _isAnswerVisible = false;
  int _sessionReviewedCount = 0;

  @override
  void initState() {
    super.initState();
    _service.ensureInitialized().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final stats = _service.getStatsSummary();
        final dueList = _service.dueCards;
        final activeCard = dueList.isNotEmpty ? dueList.first : null;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.psychology_alt_rounded, color: Color(0xFF8B5CF6), size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Répétition Espacée FSRS & Flashcards',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF7C3AED),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle Carte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _showCreateCardDialog(context),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. FSRS Metrics Header Card
              _buildFsrsMetricsBanner(stats, isDark),
              const SizedBox(height: 18),

              // 2. Active Review Deck Area
              if (activeCard != null)
                _buildActiveReviewCard(context, activeCard, dueList.length, isDark)
              else
                _buildAllCaughtUpCard(context, stats, isDark),

              const SizedBox(height: 24),

              // 3. All Cards Deck Browser
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bibliothèque de Cartes FSRS (${_service.cards.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  if (_sessionReviewedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_sessionReviewedCount révisée(s) cette session ✅',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ..._service.cards.map((card) => _buildDeckItemTile(context, card, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFsrsMetricsBanner(Map<String, dynamic> stats, bool isDark) {
    final retentionPct = ((stats['avgRetention'] as double? ?? 0.9) * 100).toStringAsFixed(0);
    final stability = (stats['avgStability'] as double? ?? 1.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Algorithme FSRS v4.5 • Mémoire à Long Terme',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rétention : $retentionPct%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildStatPill('🔥 À réviser', '${stats['dueToday']}', const Color(0xFFEA580C), isDark),
              _buildStatPill('🆕 Nouvelles', '${stats['new']}', const Color(0xFF0284C7), isDark),
              _buildStatPill('⏳ En cours', '${stats['learning']}', const Color(0xFFD97706), isDark),
              _buildStatPill('🏆 Matures (>21j)', '${stats['mature']}', const Color(0xFF059669), isDark),
              _buildStatPill('📐 Stabilité moy.', '${stability}j', const Color(0xFF7C3AED), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveReviewCard(
    BuildContext context,
    FlashcardFsrsItem card,
    int remainingCount,
    bool isDark,
  ) {
    return Card(
      elevation: isDark ? 0 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${card.moduleId} • ${card.courseName}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$remainingCount carte(s) due(s)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question / Front
            const Text(
              'RECTO (QUESTION / RAPPEL ACTIF) :',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: card.front,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.45),
              ),
            ),
            const SizedBox(height: 20),

            if (!_isAnswerVisible)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.flip_rounded, size: 18),
                  label: const Text(
                    'Afficher la Réponse (Recto/Verso)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: () => setState(() => _isAnswerVisible = true),
                ),
              )
            else ...[
              const Divider(height: 24),
              const Text(
                'VERSO (RÉPONSE & EXPLICATION) :',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: MarkdownBody(
                  data: card.back,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Évaluez votre rappel mémoriel (Planification FSRS) :',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildGradeButton(card, FsrsRating.again, 'À revoir', const Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  _buildGradeButton(card, FsrsRating.hard, 'Difficile', const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  _buildGradeButton(card, FsrsRating.good, 'Bien', const Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  _buildGradeButton(card, FsrsRating.easy, 'Facile', const Color(0xFF0284C7)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradeButton(
    FlashcardFsrsItem card,
    FsrsRating rating,
    String label,
    Color color,
  ) {
    final nextInterval = _service.previewNextIntervalLabel(card, rating);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await _service.reviewCard(card, rating);
          if (mounted) {
            setState(() {
              _isAnswerVisible = false;
              _sessionReviewedCount++;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Column(
            children: [
              Text(
                nextInterval,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllCaughtUpCard(BuildContext context, Map<String, dynamic> stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 46),
          const SizedBox(height: 10),
          const Text(
            'Bravo ! Toutes vos Flashcards du jour sont révisées 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Convertissez des QCM en Flashcards en 1 clic pendant vos sessions d\'entraînement ou ajoutez vos propres cartes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckItemTile(BuildContext context, FlashcardFsrsItem card, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          card.front.replaceAll('\n', ' ').replaceAll('**', ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
        subtitle: Text(
          '${card.courseName} • Stabilité: ${card.stability}j • Difficulté: ${card.difficulty}/10',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
          tooltip: 'Supprimer la carte',
          onPressed: () => _service.deleteCard(card.id),
        ),
      ),
    );
  }

  void _showCreateCardDialog(BuildContext context) {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    final courseCtrl = TextEditingController(text: 'Synthèse Résidanat');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.style_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Créer une Flashcard FSRS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: courseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Module / Cours',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: frontCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Recto (Question / Piège clinique)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: backCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Verso (Réponse clé & Explication)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (frontCtrl.text.trim().isNotEmpty && backCtrl.text.trim().isNotEmpty) {
                await _service.createCustomCard(
                  front: frontCtrl.text,
                  back: backCtrl.text,
                  courseName: courseCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter au Deck FSRS'),
          ),
        ],
      ),
    );
  }
}
