import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/free_trial_quota_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/user_model.dart';
import '../../revision/bloc/revision_bloc.dart';
import '../../revision/bloc/revision_event.dart';
import '../../revision/bloc/revision_state.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/revision_session_model.dart';
import '../../revision/presentation/course_pdf_viewer_screen.dart';
import '../../revision/presentation/offline_storage_screen.dart';
import '../../revision/presentation/qcm_study_screen.dart';
import '../../revision/services/offline_course_manager.dart';
import '../data/models/externat_module_info.dart';
import 'widgets/externat_rotation_banner.dart';
import 'externat_course_session_screen.dart';
import 'externat_emd_simulation_screen.dart';

class ExternatCatalogScreen extends StatefulWidget {
  final int? initialYear;

  const ExternatCatalogScreen({
    super.key,
    this.initialYear,
  });

  @override
  State<ExternatCatalogScreen> createState() => _ExternatCatalogScreenState();
}

class _ExternatCatalogScreenState extends State<ExternatCatalogScreen> {
  late int _selectedYear;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedModuleIds = {};
  bool _onlyEmdQuestions = true;

  final Map<int, Map<String, dynamic>> _yearMeta = {
    1: {
      'title': '1ère Année • Sciences Fondamentales I',
      'subtitle': 'Anatomie générale, Cytologie, Embryologie, Histologie, Physiologie I, Biochimie I, Biophysique, Biostatistique, Chimie, SSH.',
      'advice': 'Misez sur la régularité quotidienne en Anatomie et Biochimie. Les schémas dessinés à la main fixent la mémoire à long terme.',
      'color': const Color(0xFF0284C7),
      'icon': Icons.science_rounded,
    },
    2: {
      'title': '2ème Année • Sciences Fondamentales II',
      'subtitle': 'Unités intégrées (Cardio-Respiratoire, Digestive, Urinaire, Endocrinologie, Neuro), Génétique, Immunologie fondamentale.',
      'advice': 'Comprenez la physiologie normale en profondeur : c\'est le socle indispensable pour toutes les pathologies des années suivantes.',
      'color': const Color(0xFF0D9488),
      'icon': Icons.biotech_rounded,
    },
    3: {
      'title': '3ème Année • Pré-Clinique & Sémiologie',
      'subtitle': 'Sémiologie médicale et chirurgicale, Pharmacologie, Microbiologie, Parasitologie-Mycologie, Immunopathologie, Anapathologie.',
      'advice': 'L\'année pivot : passez un maximum de temps au lit du malade durant vos stages pour corréler les signes physiques avec vos cours.',
      'color': const Color(0xFF6366F1),
      'icon': Icons.psychology_rounded,
    },
    4: {
      'title': '4ème Année • Externat & Pathologie I',
      'subtitle': 'Cardiologie, Pneumologie, Hépato-Gastro-Entérologie, Neurologie, Maladies Infectieuses, Hématologie Clinique, Traumatologie-Orthopédie.',
      'advice': 'Modules lourds et tombables : entraînez-vous systématiquement sur les annales d\'EMD de votre faculté et fiches réflexes.',
      'color': const Color(0xFF10B981),
      'icon': Icons.medical_services_rounded,
    },
    5: {
      'title': '5ème Année • Externat & Pathologie II',
      'subtitle': 'Pédiatrie, Gynécologie-Obstétrique, Uro-Néphrologie, Endocrinologie-Diabétologie, Psychiatrie, Dermatologie, Rhumatologie, ORL, Ophtalmo.',
      'advice': 'Rythme dense : préparez vos fiches de conduite à tenir d\'urgence avant chaque garde de stage (Pédiatrie & Gynéco en tête).',
      'color': const Color(0xFFF59E0B),
      'icon': Icons.child_care_rounded,
    },
    6: {
      'title': '6ème Année • Externat & Thérapeutique',
      'subtitle': 'Urgences Médico-Chirurgicales (UMC), Thérapeutique, Médecine du Travail, Médecine Légale, Épidémiologie, Gériatrie, Maladies Systémiques.',
      'advice': 'Dernière ligne droite avant l\'internat : synthétisez les urgences vitales et verrouillez les modules juridico-médicaux qui font la différence.',
      'color': const Color(0xFFE11D48),
      'icon': Icons.emergency_rounded,
    },
  };

  @override
  void initState() {
    super.initState();
    final authUser = context.read<AuthBloc>().state.user;
    if (widget.initialYear != null && widget.initialYear! >= 1 && widget.initialYear! <= 6) {
      _selectedYear = widget.initialYear!;
    } else if (authUser?.isStudent == true && authUser?.studyYear != null) {
      _selectedYear = (authUser!.studyYear!).clamp(1, 6);
    } else {
      _selectedYear = 4; // Default to 4th year
    }

    context.read<RevisionBloc>().add(LoadModulesEvent());
    context.read<RevisionBloc>().add(LoadSavedSessionsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: BlocBuilder<RevisionBloc, RevisionState>(
        builder: (context, state) {
          if (state.status == RevisionStatus.loading && state.modules.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
          }

          final yearModules = ResidencyRepository.filterModulesForStudent(state.modules, _selectedYear);
          final filteredModules = yearModules.where((m) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            final matchesMod = m.name.toLowerCase().contains(query);
            final matchesCourse = m.courses.any((c) => c.name.toLowerCase().contains(query));
            return matchesMod || matchesCourse;
          }).toList();

          final totalYearCourses = yearModules.fold(0, (sum, m) => sum + m.courses.length);

          return RefreshIndicator(
            color: AppTheme.primaryTeal,
            onRefresh: () async {
              context.read<RevisionBloc>().add(LoadModulesEvent());
              context.read<RevisionBloc>().add(LoadSavedSessionsEvent());
            },
            child: CustomScrollView(
              slivers: [
                // 1. Sticky Year Selector & Header Bar
                SliverToBoxAdapter(
                  child: _buildYearSelectorHeader(context, isDark, user),
                ),

                // 2. Year Motivational Banner & Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: _buildYearInfoCard(isDark, yearModules.length, totalYearCourses),
                  ),
                ),

                // 2.5 Active Rotation & AI Year Tutor Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: ExternatRotationBanner(
                      studyYear: _selectedYear,
                      yearModules: yearModules,
                      onRotationChanged: () {
                        setState(() {});
                      },
                    ),
                  ),
                ),

                // 3. Search Bar & EMD Toggle
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildSearchAndFilterBar(isDark),
                  ),
                ),

                // 4. Modules & Courses Accordion
                if (filteredModules.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Aucun cours ou module trouvé pour "$_searchQuery" en ${_selectedYear}e année.'
                                : 'Aucun module répertorié pour la ${_selectedYear}e année.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final mod = filteredModules[index];
                          final isExpanded = _expandedModuleIds.contains(mod.id);
                          return _buildModuleCard(context, mod, isExpanded, isDark, user, state);
                        },
                        childCount: filteredModules.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearSelectorHeader(BuildContext context, bool isDark, UserModel? user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
    
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppTheme.primaryTeal, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
        
                    children: [
                      const Text(
                        'Cursus Externat & Université',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Programme officiel (1ère à 6ème Année)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildOfflineStoragePill(context, isDark),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Year Pills (1ère to 6ème)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(6, (idx) {
                final year = idx + 1;
                final isSelected = _selectedYear == year;
                final isMyYear = user?.isStudent == true && user?.studyYear == year;
                final meta = _yearMeta[year]!;
                final Color themeColor = meta['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      meta['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade300 : themeColor),
                    ),
                    label: Text(
                      isMyYear ? '$year${year == 1 ? "ère" : "ème"} Année ★' : '$year${year == 1 ? "ère" : "ème"} Année',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: themeColor,
                    backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? themeColor : (isMyYear ? themeColor.withValues(alpha: 0.6) : Colors.transparent),
                      width: isMyYear ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedYear = year;
                          _expandedModuleIds.clear();
                        });
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineStoragePill(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: OfflineCourseManager.instance,
      builder: (context, _) {
        return Tooltip(
          message: 'Mode Hors-Ligne & Gestion du stockage',
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineStorageScreen()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: const Row(
    
                children: [
                  Icon(Icons.offline_pin_rounded, color: AppTheme.primaryTeal, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'Hors-Ligne',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearInfoCard(bool isDark, int modCount, int courseCount) {
    final meta = _yearMeta[_selectedYear]!;
    final Color color = meta['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [color.withValues(alpha: 0.25), const Color(0xFF1E293B)]
              : [color.withValues(alpha: 0.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          '$modCount modules',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                        ),
                        Text(
                          '• $courseCount cours officiels',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meta['subtitle'] as String,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meta['advice'] as String,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher un module ou cours en ${_selectedYear}e année (ex: HTA, ECG, Diabète)...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            InkWell(
              onTap: () => setState(() => _onlyEmdQuestions = !_onlyEmdQuestions),
              borderRadius: BorderRadius.circular(8),
              child: Row(
    
                children: [
                  Switch.adaptive(
                    value: _onlyEmdQuestions,
                    activeTrackColor: AppTheme.primaryTeal,
                    onChanged: (val) => setState(() => _onlyEmdQuestions = val),
                  ),
                  Text(
                    'Questions EMD / Faculté uniquement',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_yearMeta[_selectedYear]!['color'] as Color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _yearMeta[_selectedYear]!['title'].toString().split('•')[0].trim(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _yearMeta[_selectedYear]!['color'] as Color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModuleCard(
    BuildContext context,
    MedicalModuleModel mod,
    bool isExpanded,
    bool isDark,
    UserModel? user,
    RevisionState state,
  ) {
    final modInfo = ExternatCurriculumMatrix.findModuleInfo(mod.name, _selectedYear);
    final courses = mod.courses.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return mod.name.toLowerCase().contains(q) || c.name.toLowerCase().contains(q);
    }).toList();

    return Card(
      elevation: isDark ? 0 : 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        children: [
          // Module Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedModuleIds.remove(mod.id);
                } else {
                  _expandedModuleIds.add(mod.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_special_rounded, color: AppTheme.primaryTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mod.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${mod.courses.length} cours officiels${modInfo != null ? ' • ${modInfo.durationWeeks} sem. (${modInfo.rotationType})' : ' révisables'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Start EMD Session Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.quiz_rounded, size: 14),
                    label: const Text('EMD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _startModuleEmdSession(context, mod, user),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.timer_rounded, size: 14),
                    label: const Text('Blanc /20', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExternatEmdSimulationScreen(
                            moduleName: mod.name,
                            studyYear: _selectedYear,
                            allModules: state.modules,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),

          // Course List if expanded
          if (isExpanded) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: courses.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, cIdx) {
                final course = courses[cIdx];
                return _buildCourseRow(context, mod, course, isDark, user, state);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseRow(
    BuildContext context,
    MedicalModuleModel mod,
    CourseModel course,
    bool isDark,
    UserModel? user,
    RevisionState state,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;

          final titleCol = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                'Support officiel Faculté • Polycopie & Schémas',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 6,
            runSpacing: 6,

            children: [
              // PDF Reader Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                label: const Text('Cours PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoursePdfViewerScreen(
                        course: course,
                        moduleName: '${_selectedYear}e Année • ${mod.name}',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // QCMs / EMD Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.school_rounded, size: 14),
                label: const Text('EMD QCM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _startCourseQcmSession(context, course, user),
              ),
              const SizedBox(width: 8),
              // Interactive Teacher AI Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.psychology_rounded, size: 14),
                label: const Text('Enseignant IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExternatCourseSessionScreen(
                        moduleName: mod.name,
                        courseName: course.name,
                        studyYear: _selectedYear,
                      ),
                    ),
                  );
                },
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleCol,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: actionButtons,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleCol),
              const SizedBox(width: 10),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  void _startCourseQcmSession(BuildContext context, CourseModel course, UserModel? user) {
    if (user?.tier == SubscriptionTier.free) {
      if (!FreeTrialQuotaService.instance.canStartQcmSession(user)) {
        FreeTrialQuotaService.showQuotaLimitDialog(
          context,
          featureTitle: 'Session Test Utilisée',
          message: 'Abonnez-vous au Pass Étudiant pour vous entraîner sur tous les cours et EMDs en illimité.',
        );
        return;
      }
      FreeTrialQuotaService.instance.consumeQcmSession(user);
    }

    context.read<RevisionBloc>().add(
          OpenCourseQuestionsEvent(
            course,
            resume: false,
            filterForStudent: _onlyEmdQuestions,
          ),
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }

  void _startModuleEmdSession(BuildContext context, MedicalModuleModel mod, UserModel? user) {
    if (user?.tier == SubscriptionTier.free) {
      if (!FreeTrialQuotaService.instance.canStartQcmSession(user)) {
        FreeTrialQuotaService.showQuotaLimitDialog(
          context,
          featureTitle: 'Session Test Utilisée',
          message: 'Abonnez-vous au Pass Étudiant pour lancer des examens d\'externat illimités.',
        );
        return;
      }
      FreeTrialQuotaService.instance.consumeQcmSession(user);
    }

    final session = CustomRevisionSession(
      id: 'externat_emd_${mod.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Examen EMD ${_selectedYear}e Année : ${mod.name}',
      moduleIds: [mod.id],
      moduleNames: [mod.name],
      courseIds: mod.courses.map((c) => c.id).toList(),
      courseNames: mod.courses.map((c) => c.name).toList(),
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      questionLimit: 30,
      shuffleQuestions: true,
      sessionMode: 'training',
      correctionStyle: 'immediate',
      currentQuestionIndex: 0,
      totalQuestions: 0,
      userAnswers: const {},
      revealedQuestions: const {},
    );

    context.read<RevisionBloc>().add(
          StartCustomSessionEvent(
            session,
            resume: false,
            filterForStudent: _onlyEmdQuestions,
          ),
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }
}
