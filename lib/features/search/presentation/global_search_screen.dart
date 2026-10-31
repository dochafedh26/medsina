import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../clinical/models/cat_protocol_model.dart';
import '../../clinical/models/emergency_drug_model.dart';
import '../../help/presentation/user_guide_pdf_viewer_screen.dart';
import '../../practical_tools/models/lab_value_model.dart';
import '../../revision/models/course_summary_model.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/qcm_model.dart';
import '../../revision/presentation/course_pdf_viewer_screen.dart';
import '../../revision/presentation/course_summary_screen.dart';
import '../models/search_result_item.dart';
import '../services/global_search_service.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const GlobalSearchScreen({super.key, this.initialQuery});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isSearching = false;
  String _currentQuery = '';
  SearchResultType? _selectedCategory;
  List<SearchResultItem> _results = [];
  List<String> _recentSearches = [];

  final List<String> _suggestedTopics = [
    'SCA ST+',
    'Hyperkaliémie',
    'Score de Wells',
    'Score de Glasgow',
    'Asthme aigu grave',
    'Appendicite',
    'Choc septique',
    'Pneumonie',
    'Ménopause',
    'Méningite',
    'Garde',
    'Aspirine',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecents();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _executeSearch(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final list = await GlobalSearchService.instance.getRecentSearches();
    if (mounted) setState(() => _recentSearches = list);
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 220), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (mounted) {
        setState(() {
          _currentQuery = trimmed;
          _isSearching = false;
          _results = [];
        });
      }
      return;
    }

    setState(() {
      _currentQuery = trimmed;
      _isSearching = true;
    });

    final res = await GlobalSearchService.instance.search(
      trimmed,
      filterType: _selectedCategory,
    );

    if (mounted) {
      setState(() {
        _results = res;
        _isSearching = false;
      });
    }

    if (trimmed.length >= 3) {
      GlobalSearchService.instance.saveRecentSearch(trimmed);
      _loadRecents();
    }
  }

  void _onCategorySelected(SearchResultType? type) {
    setState(() => _selectedCategory = type);
    if (_currentQuery.length >= 2) {
      _executeSearch(_currentQuery);
    }
  }

  void _applySuggestion(String tag) {
    _searchController.text = tag;
    _executeSearch(tag);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 1,
        title: _buildSearchInputField(isDark),
      ),
      body: Column(
        children: [
          _buildCategoryFilterBar(isDark),
          if (_isSearching)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: AppTheme.primaryTeal,
              minHeight: 2.5,
            ),
          Expanded(
            child: _currentQuery.length < 2
                ? _buildEmptyStateSuggestions(isDark)
                : _buildSearchResultsList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInputField(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryTeal.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher cours, QCMs, CAT, mémentos, doses...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryTeal, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _executeSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onChanged: _onQueryChanged,
        onSubmitted: _executeSearch,
      ),
    );
  }

  Widget _buildCategoryFilterBar(bool isDark) {
    final filters = [
      {'label': 'Tous', 'type': null},
      {'label': '📚 Cours & PDF', 'type': SearchResultType.course},
      {'label': '📑 Fiches & Pièges', 'type': SearchResultType.courseSummary},
      {'label': '🩺 CAT Urgences', 'type': SearchResultType.catProtocol},
      {'label': '📌 Mémentos', 'type': SearchResultType.memento},
      {'label': '🎯 QCMs', 'type': SearchResultType.qcm},
      {'label': '💊 Médicaments', 'type': SearchResultType.emergencyDrug},
      {'label': '🧮 Normes & Scores', 'type': SearchResultType.clinicalScore},
      {'label': '📖 Guide Medsina', 'type': SearchResultType.userGuide},
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final type = filter['type'] as SearchResultType?;
          final isSelected = _selectedCategory == type;

          return FilterChip(
            selected: isSelected,
            label: Text(
              filter['label'] as String,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ),
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            selectedColor: AppTheme.primaryTeal,
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onSelected: (_) => _onCategorySelected(type),
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateSuggestions(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Recherches Récentes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () async {
                    await GlobalSearchService.instance.clearRecentSearches();
                    _loadRecents();
                  },
                  child: const Text('Effacer', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((term) {
                return ActionChip(
                  avatar: const Icon(Icons.north_west_rounded, size: 14, color: AppTheme.primaryTeal),
                  label: Text(term, style: const TextStyle(fontSize: 12)),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  onPressed: () => _applySuggestion(term),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          const Row(
            children: [
              Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pathologies & Sujets Populaires Concours',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTopics.map((topic) {
              return ActionChip(
                label: Text(topic, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                onPressed: () => _applySuggestion(topic),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F766E).withValues(alpha: 0.3), const Color(0xFF1E293B)]
                    : [const Color(0xFFCCFBF1), const Color(0xFFF0FDFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryTeal, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medsina Omnisearch • Recherche Indexée',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tapez n\'importe quel mot médical pour scanner les 47 cours PDF, 6 240+ QCMs, 30+ protocoles d\'urgences, mémentos et doses.',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(bool isDark) {
    if (_results.isEmpty && !_isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Aucun résultat pour "$_currentQuery"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Essayez avec un autre terme médical ou sélectionnez "Tous" dans les filtres.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return _buildResultCard(item, isDark);
      },
    );
  }

  Widget _buildResultCard(SearchResultItem item, bool isDark) {
    final badgeColor = _getBadgeColor(item.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.15)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleItemClick(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Subtitle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.typeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title with highlight
              _buildHighlightedText(
                item.title,
                _currentQuery,
                baseStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.3,
                ),
                highlightStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFFEF08A) : const Color(0xFF78350F),
                  backgroundColor: isDark
                      ? const Color(0xFFD97706).withValues(alpha: 0.38)
                      : const Color(0xFFFDE047).withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 6),

              // Context Snippet with highlight
              if (item.snippet.isNotEmpty)
                _buildHighlightedText(
                  item.snippet,
                  _currentQuery,
                  maxLines: 2,
                  baseStyle: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    height: 1.4,
                  ),
                  highlightStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFFEF08A) : const Color(0xFF78350F),
                    backgroundColor: isDark
                        ? const Color(0xFFD97706).withValues(alpha: 0.32)
                        : const Color(0xFFFDE047).withValues(alpha: 0.55),
                  ),
                ),

              const SizedBox(height: 10),

              // Action button row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item.actionLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: badgeColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Normalizes diacritics and case strictly 1-to-1 per UTF-16 code unit so
  /// string length and indices remain 100% identical to [input] (even with emojis).
  static String _foldDiacritics1To1(String input) {
    final codeUnits = List<int>.filled(input.length, 0);
    for (int i = 0; i < input.length; i++) {
      int c = input.codeUnitAt(i);
      // ASCII uppercase A-Z -> a-z
      if (c >= 0x41 && c <= 0x5A) {
        c += 0x20;
      } else if (c >= 0xC0 && c <= 0x17F) {
        switch (c) {
          case 0xC0: case 0xC1: case 0xC2: case 0xC3: case 0xC4: case 0xC5:
          case 0xE0: case 0xE1: case 0xE2: case 0xE3: case 0xE4: case 0xE5:
          case 0xC6: case 0xE6:
            c = 0x61; // 'a'
            break;
          case 0xC7: case 0xE7:
            c = 0x63; // 'c'
            break;
          case 0xC8: case 0xC9: case 0xCA: case 0xCB:
          case 0xE8: case 0xE9: case 0xEA: case 0xEB:
            c = 0x65; // 'e'
            break;
          case 0xCC: case 0xCD: case 0xCE: case 0xCF:
          case 0xEC: case 0xED: case 0xEE: case 0xEF:
            c = 0x69; // 'i'
            break;
          case 0xD1: case 0xF1:
            c = 0x6E; // 'n'
            break;
          case 0xD2: case 0xD3: case 0xD4: case 0xD5: case 0xD6:
          case 0xF2: case 0xF3: case 0xF4: case 0xF5: case 0xF6:
          case 0x152: case 0x153:
            c = 0x6F; // 'o'
            break;
          case 0xD9: case 0xDA: case 0xDB: case 0xDC:
          case 0xF9: case 0xFA: case 0xFB: case 0xFC:
            c = 0x75; // 'u'
            break;
          case 0xDD: case 0xFD: case 0xFF: case 0x178:
            c = 0x79; // 'y'
            break;
        }
      }
      codeUnits[i] = c;
    }
    return String.fromCharCodes(codeUnits);
  }

  Widget _buildHighlightedText(
    String text,
    String query, {
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
    int? maxLines,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }

    final normText = _foldDiacritics1To1(text);
    final normQuery = _foldDiacritics1To1(trimmedQuery);

    final highlighted = List<bool>.filled(text.length, false);
    bool anyMatch = false;

    void markOccurrences(String pattern) {
      if (pattern.isEmpty) return;
      int searchFrom = 0;
      while (searchFrom <= normText.length - pattern.length) {
        final idx = normText.indexOf(pattern, searchFrom);
        if (idx == -1) break;
        for (int k = idx; k < idx + pattern.length; k++) {
          highlighted[k] = true;
        }
        anyMatch = true;
        searchFrom = idx + pattern.length;
      }
    }

    if (normText.contains(normQuery)) {
      markOccurrences(normQuery);
    } else {
      final tokens = normQuery
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2)
          .toList();
      for (final token in tokens) {
        markOccurrences(token);
      }
    }

    if (!anyMatch) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }

    // Build contiguous spans without ever splitting a UTF-16 surrogate pair
    final spans = <TextSpan>[];
    int runStart = 0;
    bool currentHighlight = highlighted[0];

    for (int i = 1; i < text.length; i++) {
      final prevUnit = text.codeUnitAt(i - 1);
      final isSurrogateContinuation = prevUnit >= 0xD800 && prevUnit <= 0xDBFF;
      if (isSurrogateContinuation) {
        highlighted[i] = currentHighlight;
        continue;
      }
      if (highlighted[i] != currentHighlight) {
        spans.add(
          TextSpan(
            text: text.substring(runStart, i),
            style: currentHighlight ? highlightStyle : null,
          ),
        );
        runStart = i;
        currentHighlight = highlighted[i];
      }
    }
    spans.add(
      TextSpan(
        text: text.substring(runStart),
        style: currentHighlight ? highlightStyle : null,
      ),
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  Color _getBadgeColor(SearchResultType type) {
    switch (type) {
      case SearchResultType.course:
        return const Color(0xFF0F766E); // Teal
      case SearchResultType.courseSummary:
        return const Color(0xFF0284C7); // Sky blue
      case SearchResultType.catProtocol:
        return const Color(0xFFDC2626); // Red Urgence
      case SearchResultType.memento:
        return const Color(0xFFD97706); // Amber
      case SearchResultType.qcm:
        return const Color(0xFF7C3AED); // Purple
      case SearchResultType.emergencyDrug:
        return const Color(0xFF059669); // Emerald
      case SearchResultType.labValue:
        return const Color(0xFFE11D48); // Rose
      case SearchResultType.clinicalScore:
        return const Color(0xFF2563EB); // Royal Blue
      case SearchResultType.userGuide:
        return const Color(0xFF10B981); // Green
    }
  }

  // ---------------------------------------------------------------------------
  // Action Handlers
  // ---------------------------------------------------------------------------
  void _handleItemClick(SearchResultItem item) {
    switch (item.type) {
      case SearchResultType.course:
        final course = item.payload['course'] as CourseModel;
        final module = item.payload['module'] as MedicalModuleModel;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CoursePdfViewerScreen(
              course: course,
              moduleName: module.name,
              initialSearchQuery: _currentQuery,
            ),
          ),
        );
        break;

      case SearchResultType.courseSummary:
        final summary = item.payload as CourseSummaryModel;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseSummaryScreen(
              course: CourseModel(
                id: summary.courseId,
                moduleId: summary.moduleId,
                name: summary.courseName,
                questionsCount: 0,
              ),
              moduleName: summary.moduleName,
            ),
          ),
        );
        break;

      case SearchResultType.catProtocol:
        _showCatProtocolModal(item.payload as ClinicalProtocol);
        break;

      case SearchResultType.memento:
        _showMementoModal(item.payload as OnCallMemento);
        break;

      case SearchResultType.qcm:
        final qcm = item.payload as QcmQuestion;
        _showQcmModal(qcm);
        break;

      case SearchResultType.emergencyDrug:
        _showDrugModal(item.payload as EmergencyDrugModel);
        break;

      case SearchResultType.labValue:
        _showLabModal(item.payload as LabValue);
        break;

      case SearchResultType.clinicalScore:
        _showScoreModal(item.payload as Map<String, dynamic>);
        break;

      case SearchResultType.userGuide:
        final pageMap = item.payload as Map<String, dynamic>;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserGuidePdfViewerScreen(
              initialPage: pageMap['page'] as int?,
              initialSearchQuery: _currentQuery,
            ),
          ),
        );
        break;
    }
  }

  void _showQcmModal(QcmQuestion qcm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool revealed = false;
        final selectedKeys = <String>{};

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${qcm.source} ${qcm.year}'.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              qcm.courseName,
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        qcm.questionText,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(qcm.options.length, (optIdx) {
                        final opt = qcm.options[optIdx];
                        final isCorrect = qcm.correctAnswers.contains(opt.key);
                        final isSelected = selectedKeys.contains(opt.key);

                        Color? tileColor;
                        Color? borderColor;
                        if (revealed) {
                          if (isCorrect) {
                            tileColor = Colors.green.withValues(alpha: 0.12);
                            borderColor = Colors.green;
                          } else if (isSelected) {
                            tileColor = Colors.red.withValues(alpha: 0.12);
                            borderColor = Colors.red;
                          }
                        } else if (isSelected) {
                          tileColor = AppTheme.primaryTeal.withValues(alpha: 0.12);
                          borderColor = AppTheme.primaryTeal;
                        }

                        return InkWell(
                          onTap: revealed
                              ? null
                              : () {
                                  setSheetState(() {
                                    if (selectedKeys.contains(opt.key)) {
                                      selectedKeys.remove(opt.key);
                                    } else {
                                      selectedKeys.add(opt.key);
                                    }
                                  });
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: tileColor ?? Colors.grey.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: borderColor ?? Colors.grey.withValues(alpha: 0.2),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: (revealed && isCorrect)
                                      ? Colors.green
                                      : (isSelected ? AppTheme.primaryTeal : Colors.grey.shade400),
                                  child: Text(
                                    opt.key,
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    opt.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: (revealed && isCorrect) ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      if (!revealed)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setSheetState(() => revealed = true);
                          },
                          child: const Text('Vérifier la réponse', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                  SizedBox(width: 6),
                                  Text('Explication & Justification Concours',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                qcm.explanation.trim().isNotEmpty
                                    ? qcm.explanation
                                    : 'Réponse(s) exacte(s) : ${qcm.correctAnswers.join(", ")}.',
                                style: const TextStyle(fontSize: 12.5, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCatProtocolModal(ClinicalProtocol protocol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          protocol.urgencyLevel.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(protocol.specialty, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    protocol.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    protocol.definition,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (protocol.redFlags.isNotEmpty) ...[
                    const Text('🚨 Drapeaux Rouges & Critères de Gravité',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                    const SizedBox(height: 8),
                    ...protocol.redFlags.map((rf) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              Expanded(child: Text(rf, style: const TextStyle(fontSize: 12.5))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],
                  const Text('📋 Étapes de Prise en Charge',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...protocol.steps.map((step) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: Colors.grey.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(step.content, style: const TextStyle(fontSize: 12)),
                              if (step.bulletPoints.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                ...step.bulletPoints.map((bp) => Text('  - $bp', style: const TextStyle(fontSize: 11.5))),
                              ],
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMementoModal(OnCallMemento memento) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.nightlight_round, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      memento.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Catégorie : ${memento.category}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              ...memento.points.map((pt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pt, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showDrugModal(EmergencyDrugModel drug) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication_rounded, color: Color(0xFF059669), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drug.dci, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Marque Saidal / Nom : ${drug.brand} • ${drug.category}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 20),
              const Text('Posologie d\'Urgence :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(drug.dose, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Indications :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(drug.indication, style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showLabModal(LabValue lab) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.biotech_rounded, color: Color(0xFFE11D48), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(lab.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 20),
              Text('Norme de référence : ${lab.normalRange} ${lab.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryTeal)),
              const SizedBox(height: 10),
              Text('📈 Si élevé : ${lab.highInterpretation}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              Text('📉 Si bas : ${lab.lowInterpretation}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showScoreModal(Map<String, dynamic> scoreItem) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(scoreItem['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 4),
              Text(scoreItem['subtitle'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 20),
              Text(scoreItem['snippet'] as String, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
