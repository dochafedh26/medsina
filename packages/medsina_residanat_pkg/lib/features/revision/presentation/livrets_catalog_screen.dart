import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:medsina_core/core/network/supabase_service.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_bloc.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_event.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_state.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import 'package:medsina_study_engine/features/revision/presentation/course_pdf_viewer_screen.dart';
import 'course_summary_screen.dart';
import 'package:medsina_study_engine/features/revision/presentation/qcm_study_screen.dart';

class _BookletCatalogItem {
  final CourseModel course;
  final String moduleName;

  const _BookletCatalogItem({
    required this.course,
    required this.moduleName,
  });
}

class LivretsCatalogScreen extends StatefulWidget {
  final bool embeddedInTab;

  const LivretsCatalogScreen({
    super.key,
    this.embeddedInTab = false,
  });

  @override
  State<LivretsCatalogScreen> createState() => _LivretsCatalogScreenState();
}

class _LivretsCatalogScreenState extends State<LivretsCatalogScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  List<CourseModel> _cloudBooklets = [];

  @override
  void initState() {
    super.initState();
    _loadGeneratedBooklets();
  }

  Future<void> _loadGeneratedBooklets() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final rows = await SupabaseService.fetchGeneratedBookletCourses();
      final loaded = rows
          .map((r) => CourseModel.fromJson(r))
          .where((c) => c.hasPublishedBooklet)
          .toList();
      if (mounted) {
        setState(() {
          _cloudBooklets = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static String _prettyModuleName(String moduleId, List<MedicalModuleModel> modules) {
    final normId = moduleId.trim();
    for (final m in modules) {
      if (m.id.toLowerCase() == normId.toLowerCase()) {
        return m.name;
      }
    }

    const Map<String, String> knownMap = {
      'mod_cardio': 'Cardiologie',
      'Blida_CARDIOLOGIE': 'Cardiologie',
      'Blida_HEPATO_GASTRO_ENTEROLOGIE': 'Hépato-Gastro-Entérologie',
      'Blida_GASTROLOGIE': 'Hépato-Gastro-Entérologie',
      'Blida_ANATOMIE_1_ERE': 'Anatomie 1ère Année',
      'Blida_ANATOMIE_2_EME': 'Anatomie 2ème Année',
      'Blida_BIOCHIMIE_1_ERE': 'Biochimie 1ère Année',
      'Blida_BIOCHIMIE_2_EME': 'Biochimie 2ème Année',
      'Blida_PHYSIOLOGIE_1_ERE': 'Physiologie 1ère Année',
      'Blida_PHYSIOLOGIE_2_EME': 'Physiologie 2ème Année',
      'Blida_PNEUMOLOGIE': 'Pneumologie',
      'Blida_NEUROLOGIE': 'Neurologie',
      'Blida_INFECTIEUX': 'Maladies Infectieuses',
      'Blida_HEMATOLOGIE': 'Hématologie',
      'Blida_PEDIATRIE': 'Pédiatrie',
      'Blida_GYNECOLOGIE_OBSTETRIQUE': 'Gynécologie-Obstétrique',
      'Blida_ENDOCRINOLOGIE': 'Endocrinologie & Diabétologie',
      'Blida_NEPHROLOGIE': 'Néphrologie',
      'Blida_UROLOGIE': 'Urologie',
      'Blida_URGENCES_UMC': 'Urgences Médico-Chirurgicales (UMC)',
      'Blida_THERAPEUTIQUE': 'Thérapeutique',
      'Blida_ORTHOPEDIE_ET_TRAUMATOLOGIE': 'Orthopédie & Traumatologie',
      'Blida_RHUMATOLOGIE': 'Rhumatologie',
      'Blida_DERMATOLOGIE': 'Dermatologie',
      'Blida_PSYCHIATRIE': 'Psychiatrie',
      'Blida_OPHTALMOLOGIE': 'Ophtalmologie',
      'Blida_OTORHINOLARYNGOLOGIE': 'ORL',
    };

    if (knownMap.containsKey(normId)) {
      return knownMap[normId]!;
    }

    return normId
        .replaceAll('Blida_', '')
        .replaceAll('mod_', '')
        .replaceAll('_', ' ')
        .trim();
  }

  List<_BookletCatalogItem> _buildMergedBooklets(List<MedicalModuleModel> stateModules) {
    final Map<String, _BookletCatalogItem> byId = {};

    // 1. From live Supabase query
    for (final c in _cloudBooklets) {
      if (c.hasPublishedBooklet) {
        final modId = c.moduleId == 'mod_cardio' ? 'Blida_CARDIOLOGIE' : c.moduleId;
        final normalizedCourse = c.copyWith(moduleId: modId);
        byId[c.id] = _BookletCatalogItem(
          course: normalizedCourse,
          moduleName: _prettyModuleName(c.moduleId, stateModules),
        );
      }
    }

    // 2. Merge any from RevisionBloc state.modules
    for (final mod in stateModules) {
      for (final c in mod.courses) {
        if (c.hasPublishedBooklet) {
          final existing = byId[c.id];
          if (existing == null) {
            byId[c.id] = _BookletCatalogItem(
              course: c,
              moduleName: mod.name,
            );
          } else if (existing.course.questionsCount == 0 && c.questionsCount > 0) {
            byId[c.id] = _BookletCatalogItem(
              course: existing.course.copyWith(questionsCount: c.questionsCount),
              moduleName: mod.name,
            );
          }
        }
      }
    }

    final list = byId.values.toList();
    list.sort((a, b) {
      // Sort Hypertombables first, then by generated timestamp or QCM count
      if (a.course.isHypertombable != b.course.isHypertombable) {
        return a.course.isHypertombable ? -1 : 1;
      }
      final ga = a.course.bundleGeneratedAt ?? '';
      final gb = b.course.bundleGeneratedAt ?? '';
      if (ga != gb) {
        return gb.compareTo(ga);
      }
      return b.course.questionsCount.compareTo(a.course.questionsCount);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = BlocBuilder<RevisionBloc, RevisionState>(
      builder: (context, state) {
        final allBooklets = _buildMergedBooklets(state.modules);
        final hyperCount = allBooklets.where((b) => b.course.isHypertombable).length;
        final totalQcms = allBooklets.fold<int>(0, (sum, b) => sum + b.course.questionsCount);

        // Unique modules with counts
        final Map<String, int> moduleCounts = {};
        for (final item in allBooklets) {
          moduleCounts[item.moduleName] = (moduleCounts[item.moduleName] ?? 0) + 1;
        }
        final sortedModules = moduleCounts.keys.toList()..sort();

        // Filter items
        final filtered = allBooklets.where((item) {
          final matchesFilter = _selectedFilter == 'Tous' ||
              (_selectedFilter == 'Hypertombables' && item.course.isHypertombable) ||
              item.moduleName == _selectedFilter;

          final q = _searchQuery.trim().toLowerCase();
          final matchesSearch = q.isEmpty ||
              item.course.name.toLowerCase().contains(q) ||
              item.moduleName.toLowerCase().contains(q) ||
              item.course.residanatYears.any((y) => y.toLowerCase().contains(q));

          return matchesFilter && matchesSearch;
        }).toList();

        return RefreshIndicator(
          color: const Color(0xFFD97706),
          onRefresh: _loadGeneratedBooklets,
          child: CustomScrollView(
            slivers: [
              // 1. Hero Bento Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: _buildHeroHeaderCard(
                    context,
                    isDark: isDark,
                    totalBooklets: allBooklets.length,
                    hyperCount: hyperCount,
                    modulesCount: sortedModules.length,
                    totalQcms: totalQcms,
                  ),
                ),
              ),

              // 2. Search & Filter Chips Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un livret par cours, module ou session (ex: Cancer du pancréas, Valvulopathies, 2022)...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD97706)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'Tous les Livrets (${allBooklets.length})',
                              value: 'Tous',
                              icon: Icons.auto_stories_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: '🔥 Hypertombables ($hyperCount)',
                              value: 'Hypertombables',
                              icon: Icons.local_fire_department_rounded,
                              accentColor: const Color(0xFFDC2626),
                              isDark: isDark,
                            ),
                            ...sortedModules.map((modName) {
                              final count = moduleCounts[modName] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildFilterChip(
                                  label: '$modName ($count)',
                                  value: modName,
                                  icon: Icons.folder_special_rounded,
                                  isDark: isDark,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Loading or Empty or Grid of Booklet Bento Cards
              if (_isLoading && allBooklets.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFD97706)),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 54,
                            color: Colors.amber.shade700.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucun livret ne correspond à votre filtre',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Essayez de réinitialiser les filtres ou cliquez sur Actualiser.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedFilter = 'Tous';
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Afficher tous les livrets'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final crossAxisCount = width >= 1120
                          ? 3
                          : width >= 700
                              ? 2
                              : 1;

                      if (crossAxisCount == 1) {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildBookletBentoCard(context, filtered[index], isDark: isDark),
                            ),
                            childCount: filtered.length,
                          ),
                        );
                      }

                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 256,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildBookletBentoCard(context, filtered[index], isDark: isDark),
                          childCount: filtered.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (widget.embeddedInTab) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🔥 Catalogue des Livrets Résidanat 2027',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser les livrets depuis le Cloud',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadGeneratedBooklets,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildHeroHeaderCard(
    BuildContext context, {
    required bool isDark,
    required int totalBooklets,
    required int hyperCount,
    required int modulesCount,
    required int totalQcms,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFFD97706),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVRETS TOUT-EN-UN • RÉSIDANAT 2027',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '● SYNCHRONISÉ CLOUD',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Catalogue Spécifique des Livrets de Révision Générés',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chaque livret PDF réunit en un seul document : Couverture & Tombabilité + Fiche de Synthèse & Pièges + Polycopié Officiel + Série de QCMs sans corrigé + Grille de Correction commentée.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualiser les livrets générés',
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                ),
                onPressed: _loadGeneratedBooklets,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildMetricPill(
                label: 'Livrets Disponibles',
                value: '$totalBooklets',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFD97706),
                isDark: isDark,
              ),
              _buildMetricPill(
                label: 'Sujets Hypertombables',
                value: '$hyperCount 🔥',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFDC2626),
                isDark: isDark,
              ),
              _buildMetricPill(
                label: 'Modules Couverts',
                value: '$modulesCount',
                icon: Icons.folder_special_rounded,
                color: AppTheme.primaryTeal,
                isDark: isDark,
              ),
              _buildMetricPill(
                label: 'QCMs Intégrés',
                value: '$totalQcms+',
                icon: Icons.quiz_rounded,
                color: const Color(0xFF2563EB),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Color accentColor = const Color(0xFFD97706),
  }) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? Colors.white : accentColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey.shade200 : const Color(0xFF334155)),
        ),
      ),
      selectedColor: accentColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      side: BorderSide(
        color: isSelected
            ? accentColor
            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildBookletBentoCard(
    BuildContext context,
    _BookletCatalogItem item, {
    required bool isDark,
  }) {
    final course = item.course;
    final isHyper = course.isHypertombable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHyper
              ? const Color(0xFFF59E0B).withValues(alpha: 0.65)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isHyper ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHyper ? const Color(0xFFD97706) : Colors.black)
                .withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Module Badge + Hypertombable Badge
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.moduleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isHyper)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🔥 HYPERTOMBABLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '📘 LIVRET 2027',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Course Title
              Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // 4-in-1 Booklet Contents Tags
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildContentTag('✓ Fiche Synthèse', isDark),
                  _buildContentTag('✓ Cours Complet', isDark),
                  _buildContentTag(
                    course.questionsCount > 0 ? '✓ ${course.questionsCount} QCMs' : '✓ QCMs Concours',
                    isDark,
                  ),
                  _buildContentTag('✓ Corrigé Type', isDark),
                ],
              ),

              if (course.residanatYears.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ' Tombé aux concours : ${course.residanatYears.take(4).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Action Buttons Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text(
                    'Ouvrir Livret PDF',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoursePdfViewerScreen(
                          course: course,
                          moduleName: item.moduleName,
                          isBooklet: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryTeal,
                  side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseSummaryScreen(
                        course: course,
                        moduleName: item.moduleName,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Fiche',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
                onPressed: () {
                  context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(course, resume: false));
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                  );
                },
                child: const Text(
                  'QCMs',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentTag(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
        ),
      ),
    );
  }
}
