import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_theme.dart';
import '../models/flashcard_fsrs_model.dart';

class FlashcardsFsrsScreen extends StatefulWidget {
  final String? initialCardId;

  const FlashcardsFsrsScreen({
    super.key,
    this.initialCardId,
  });

  @override
  State<FlashcardsFsrsScreen> createState() => _FlashcardsFsrsScreenState();
}

class _FlashcardsFsrsScreenState extends State<FlashcardsFsrsScreen> {
  final FlashcardFsrsService _service = FlashcardFsrsService.instance;
  final TextEditingController _searchController = TextEditingController();

  FlashcardFsrsItem? _activeCardOverride;
  bool _isAnswerVisible = false;
  int _sessionReviewedCount = 0;
  bool _isCramMode = false;
  int _cramIndex = 0;
  String _selectedStatusFilter = 'all'; // 'all', 'due', 'new', 'learning', 'mature'
  String _selectedModuleFilter = 'all';
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    _service.ensureInitialized().then((_) {
      if (mounted) {
        if (widget.initialCardId != null) {
          final found = _service.cards.where((c) => c.id == widget.initialCardId).firstOrNull;
          if (found != null) {
            _activeCardOverride = found;
          }
        }
        setState(() {});
      }
    });
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FlashcardFsrsItem> _getFilteredCards() {
    final query = _searchController.text.trim().toLowerCase();
    return _service.cards.where((card) {
      final matchesQuery = query.isEmpty ||
          card.front.toLowerCase().contains(query) ||
          card.back.toLowerCase().contains(query) ||
          card.courseName.toLowerCase().contains(query) ||
          card.moduleId.toLowerCase().contains(query);

      final matchesStatus = switch (_selectedStatusFilter) {
        'due' => card.isDueNow,
        'new' => card.state == FsrsCardState.newCard,
        'learning' => card.state == FsrsCardState.learning,
        'mature' => card.isMature,
        _ => true,
      };

      final matchesModule = _selectedModuleFilter == 'all' ||
          card.moduleId.toLowerCase() == _selectedModuleFilter.toLowerCase();

      return matchesQuery && matchesStatus && matchesModule;
    }).toList();
  }

  List<String> _extractAvailableModules() {
    final modules = <String>{};
    for (final c in _service.cards) {
      if (c.moduleId.trim().isNotEmpty) {
        modules.add(c.moduleId.trim());
      }
    }
    return modules.toList()..sort();
  }

  FlashcardFsrsItem? _resolveActiveCard(List<FlashcardFsrsItem> dueList) {
    if (_activeCardOverride != null) {
      return _activeCardOverride;
    }
    if (_isCramMode) {
      final allFiltered = _getFilteredCards();
      if (allFiltered.isNotEmpty && _cramIndex < allFiltered.length) {
        return allFiltered[_cramIndex];
      }
      return null;
    }
    return dueList.isNotEmpty ? dueList.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final stats = _service.getStatsSummary();
        final dueList = _service.dueCards;
        final activeCard = _resolveActiveCard(dueList);
        final filteredCards = _getFilteredCards();
        final availableModules = _extractAvailableModules();

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.psychology_alt_rounded, color: Color(0xFF8B5CF6), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Répétition Espacée FSRS & Flashcards',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showGuide ? Icons.help_rounded : Icons.help_outline_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
                tooltip: 'Guide de Réutilisation FSRS',
                onPressed: () => setState(() => _showGuide = !_showGuide),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                  foregroundColor: const Color(0xFF7C3AED),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _showCreateCardDialog(context),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 0. Guide Banner (Collapsible)
              if (_showGuide) ...[
                _buildHowToReuseGuide(isDark),
                const SizedBox(height: 16),
              ],

              // 1. FSRS Metrics Header Card
              _buildFsrsMetricsBanner(stats, isDark),
              const SizedBox(height: 18),

              // 2. Active Review Deck Area
              if (activeCard != null)
                _buildActiveReviewCard(
                  context,
                  activeCard,
                  _isCramMode ? (filteredCards.length - _cramIndex) : dueList.length,
                  isDark,
                )
              else
                _buildAllCaughtUpCard(context, stats, isDark),

              const SizedBox(height: 24),

              // 3. Card Library Browser Header & Search Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bibliothèque de Cartes (${_service.cards.length})',
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

              // Search Input Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par question, cours ou mot-clé...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Toutes (${_service.cards.length})', 'all'),
                    const SizedBox(width: 6),
                    _buildFilterChip('🔥 À réviser (${stats['dueToday']})', 'due'),
                    const SizedBox(width: 6),
                    _buildFilterChip('🆕 Nouvelles (${stats['new']})', 'new'),
                    const SizedBox(width: 6),
                    _buildFilterChip('⏳ En cours (${stats['learning']})', 'learning'),
                    const SizedBox(width: 6),
                    _buildFilterChip('🏆 Matures (${stats['mature']})', 'mature'),
                  ],
                ),
              ),

              // Module Filter Chips (if multiple modules)
              if (availableModules.length > 1) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: Text(
                          'Tous modules',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedModuleFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: _selectedModuleFilter == 'all'
                            ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                            : null,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _selectedModuleFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      ...availableModules.map((mod) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                mod,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _selectedModuleFilter.toLowerCase() == mod.toLowerCase()
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              backgroundColor: _selectedModuleFilter.toLowerCase() == mod.toLowerCase()
                                  ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                                  : null,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _selectedModuleFilter = mod),
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Card List
              if (filteredCards.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Aucune carte trouvée pour ce filtre.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ...filteredCards.map((card) => _buildDeckItemTile(context, card, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF7C3AED),
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatusFilter = value);
      },
    );
  }

  Widget _buildHowToReuseGuide(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Comment Réutiliser vos Flashcards FSRS au Quotidien ?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _showGuide = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildGuideStep(
            '1',
            'Création depuis les QCMs',
            'Quand vous ratez un QCM ou tombez sur un piège, cliquez sur « Créer Flashcard 🧠 ». La carte s\'ajoute immédiatement ici.',
          ),
          _buildGuideStep(
            '2',
            'Session quotidienne de 5 à 10 min',
            'Chaque matin ou soir, ouvrez l\'onglet Flashcards. FSRS affiche uniquement les cartes arrivées à échéance mémorielle.',
          ),
          _buildGuideStep(
            '3',
            'Notation du rappel actif',
            'Lisez le Recto, réfléchissez à la réponse, puis révélez le Verso. Notez honnêtement : « À revoir » (<10 min), « Difficile » (1-2j), « Bien » (3-5j) ou « Facile » (7-14j).',
          ),
          _buildGuideStep(
            '4',
            'Mode Révision Libre / Cramming avant Examen',
            'Avant un concours blanc ou un partiel, lancez la Révision Libre pour revoir toutes vos cartes d\'un coup sans attendre l\'échéance FSRS !',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF7C3AED),
            child: Text(
              number,
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$title : ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final isOverride = _activeCardOverride != null;

    return Card(
      elevation: isDark ? 0 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverride ? const Color(0xFF10B981) : const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          width: isOverride ? 2.0 : 1.4,
        ),
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
                if (isOverride)
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Retour file d\'attente', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _activeCardOverride = null),
                  )
                else
                  Text(
                    _isCramMode ? 'Mode Cramming • $remainingCount restante(s)' : '$remainingCount carte(s) due(s)',
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
              if (_activeCardOverride != null) {
                _activeCardOverride = null;
              }
              if (_isCramMode) {
                _cramIndex++;
              }
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
          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 48),
          const SizedBox(height: 10),
          const Text(
            'Bravo ! Toutes vos Flashcards du jour sont révisées 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Votre mémoire à long terme est à jour selon l\'algorithme FSRS. Vous pouvez continuer à ficher des QCM ou lancer une révision libre sans attendre !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Mode Révision Libre (Cramming)', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _isCramMode = true;
                    _cramIndex = 0;
                  });
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer une Carte Manuelle', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showCreateCardDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeckItemTile(BuildContext context, FlashcardFsrsItem card, bool isDark) {
    final statusColor = card.isDueNow
        ? const Color(0xFFEA580C)
        : (card.isMature ? const Color(0xFF10B981) : const Color(0xFF0284C7));
    final statusLabel = card.isDueNow
        ? 'À réviser'
        : (card.isMature ? 'Mature (${card.stability.toStringAsFixed(0)}j)' : 'En cours');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => _showCardDetailsModal(context, card),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            card.linkedQuestionId != null ? Icons.style_rounded : Icons.edit_note_rounded,
            color: statusColor,
            size: 18,
          ),
        ),
        title: Text(
          card.front.replaceAll('\n', ' ').replaceAll('**', ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${card.moduleId} • ${card.courseName}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Color(0xFF7C3AED)),
              tooltip: 'Réviser cette carte',
              onPressed: () {
                setState(() {
                  _activeCardOverride = card;
                  _isAnswerVisible = false;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              tooltip: 'Supprimer la carte',
              onPressed: () => _service.deleteCard(card.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardDetailsModal(BuildContext context, FlashcardFsrsItem card) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.style_rounded, color: Color(0xFF7C3AED), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.courseName.isNotEmpty ? card.courseName : 'Flashcard Personnelle',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Module: ${card.moduleId} • Répétitions: ${card.reps} • Stabilité: ${card.stability.toStringAsFixed(1)}j',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RECTO (QUESTION) :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),
                        MarkdownBody(data: card.front),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VERSO (RÉPONSE & EXPLICATION) :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                        const SizedBox(height: 6),
                        MarkdownBody(data: card.back),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Réviser cette Carte Maintenant', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeCardOverride = card;
                        _isAnswerVisible = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Supprimer',
                  onPressed: () async {
                    await _service.deleteCard(card.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
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
