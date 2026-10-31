import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/free_trial_quota_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/user_model.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../bloc/revision_state.dart';
import '../data/residency_repository.dart';
import '../models/module_model.dart';
import '../models/revision_session_model.dart';
import 'course_pdf_viewer_screen.dart';
import 'course_summary_screen.dart';
import '../../exam/models/exam_session_model.dart';
import '../../exam/presentation/exam_runner_screen.dart';
import 'custom_session_builder_dialog.dart';
import 'flashcards_fsrs_screen.dart';
import 'qcm_study_screen.dart';
import 'resume_session_sheet.dart';
import 'study_planner_screen.dart';
import '../../national_exam/presentation/national_exams_list_screen.dart';
import '../../group_revision/presentation/group_revision_hub_screen.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../services/offline_course_manager.dart';
import 'offline_storage_screen.dart';
import 'samedis_pedagogiques_screen.dart';
import 'temoignages_conseils_screen.dart';

class RevisionCatalogScreen extends StatefulWidget {
  const RevisionCatalogScreen({super.key});

  @override
  State<RevisionCatalogScreen> createState() => _RevisionCatalogScreenState();
}

class _RevisionCatalogScreenState extends State<RevisionCatalogScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  bool _initializedCategory = false;

  final List<String> _defaultCategories = [
    'Tous',
    'Clinique & Concours Résidanat',
    '1ère Année',
    '2ème Année',
    '3ème Année',
  ];

  @override
  void initState() {
    super.initState();
    context.read<RevisionBloc>().add(LoadModulesEvent());
    context.read<RevisionBloc>().add(LoadSavedSessionsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final authUser = context.watch<AuthBloc>().state.user;
    final isStudent = authUser?.isStudent == true;
    final studentYear = authUser?.studyYear ?? 1;

    if (!_initializedCategory) {
      _selectedCategory = isStudent ? 'Mon Année (${studentYear}e)' : 'Tous';
      _initializedCategory = true;
    }

    final screenTitle = isStudent
        ? '🎓 Cursus Universitaire • ${studentYear}e Année'
        : 'Catalogue & Révision Résidanat';

    return Scaffold(
      appBar: canPop
          ? AppBar(
              title: Text(
                screenTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: BlocBuilder<RevisionBloc, RevisionState>(
        builder: (context, state) {
          if (state.status == RevisionStatus.loading && state.modules.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
          }

          final filteredModules = state.modules.where((m) {
            bool matchesCat = true;
            if (isStudent && _selectedCategory == 'Mon Année (${studentYear}e)') {
              matchesCat = ResidencyRepository.getYearForModule(m) == studentYear;
            } else if (_selectedCategory == 'Tous' || _selectedCategory == 'Tous les Modules') {
              matchesCat = true;
            } else if (_selectedCategory.contains('1ère')) {
              matchesCat = ResidencyRepository.getYearForModule(m) == 1;
            } else if (_selectedCategory.contains('2ème')) {
              matchesCat = ResidencyRepository.getYearForModule(m) == 2;
            } else if (_selectedCategory.contains('3ème')) {
              matchesCat = ResidencyRepository.getYearForModule(m) == 3;
            } else if (_selectedCategory.contains('4ème')) {
              matchesCat = ResidencyRepository.getYearForModule(m) == 4;
            } else if (_selectedCategory.contains('5ème')) {
              matchesCat = ResidencyRepository.getYearForModule(m) == 5;
            } else if (_selectedCategory.contains('6ème')) {
              matchesCat = ResidencyRepository.getYearForModule(m) == 6;
            } else {
              matchesCat = m.category.toLowerCase().contains(_selectedCategory.toLowerCase());
            }

            final matchesSearch = _searchQuery.isEmpty ||
                m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                m.courses.any((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()));
            return matchesCat && matchesSearch;
          }).toList();

          final totalVisibleCourses = filteredModules.fold<int>(0, (sum, m) => sum + m.totalCourses);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktopWide = constraints.maxWidth >= 1050;

              final tabBar = TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppTheme.primaryTeal,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryTeal,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.menu_book_rounded, size: 20),
                    text: 'Catalogue (47 Modules)',
                  ),
                  Tab(
                    icon: const Icon(Icons.dashboard_customize_rounded, size: 20),
                    text: state.customSessions.isNotEmpty
                        ? 'Sessions Sur-Mesure (${state.customSessions.length})'
                        : 'Sessions Sur-Mesure',
                  ),
                  const Tab(
                    icon: Icon(Icons.emoji_events_rounded, size: 20),
                    text: 'Concours Blancs 🏆',
                  ),
                  const Tab(
                    icon: Icon(Icons.groups_rounded, size: 20),
                    text: 'Groupes de Révision 👥',
                  ),
                  const Tab(
                    icon: Icon(Icons.calendar_month_rounded, size: 20),
                    text: 'Study Planner (3 Couches)',
                  ),
                  const Tab(
                    icon: Icon(Icons.psychology_alt_rounded, size: 20),
                    text: 'Flashcards FSRS 🧠',
                  ),
                  const Tab(
                    icon: Icon(Icons.school_rounded, size: 20),
                    text: 'Samedis Pédagogiques 📚',
                  ),
                  const Tab(
                    icon: Icon(Icons.lightbulb_rounded, size: 20),
                    text: 'Témoignages & Conseils 💡',
                  ),
                ],
              );

              return DefaultTabController(
                length: 8,
                child: Column(
                  children: [
                    // Navigation TabBar: On mobile and tablet, TabBar has 100% full width to avoid squishing tabs!
                    Container(
                      color: Theme.of(context).cardColor,
                      width: double.infinity,
                      child: isDesktopWide
                          ? Row(
                              children: [
                                Expanded(child: tabBar),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildCloudSyncPill(context),
                                      const SizedBox(width: 8),
                                      _buildOfflineStorageButton(context),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : tabBar,
                    ),
                    const Divider(height: 1),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Official Modules & Courses Catalogue
                          _buildCatalogTab(context, state, filteredModules, totalVisibleCourses, isDesktopWide: isDesktopWide),

                          // Tab 2: Custom Multi-Course Sessions
                          _buildCustomSessionsTab(context, state, isDesktopWide: isDesktopWide),

                          // Tab 3: Concours Blancs Nationaux & Palmarès
                          const NationalExamsListScreen(),

                          // Tab 4: Groupes de Révision & Défis
                          const GroupRevisionHubScreen(),

                          // Tab 5: Study Planner par Couches & Analytics
                          const StudyPlannerScreen(),

                          // Tab 6: Répétition Espacée FSRS & Flashcards
                          const FlashcardsFsrsScreen(),

                          // Tab 7: Samedis Pédagogiques (Dr KARE & Enseignants)
                          const SamedisPedagogiquesScreen(),

                          // Tab 8: Retours d'expérience, Témoignages & Conseils des Majors
                          const TemoignagesConseilsScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCloudSyncPill(BuildContext context) {
    return AnimatedBuilder(
      animation: CloudSyncService.instance,
      builder: (context, _) {
        final sync = CloudSyncService.instance;
        final isSyncing = sync.isSyncing;

        return Tooltip(
          message: isSyncing
              ? 'Synchronisation des données avec Supabase en cours...'
              : (sync.lastSyncTime != null
                  ? 'Cloud synchronisé (${sync.lastSyncTime!.hour.toString().padLeft(2, '0')}:${sync.lastSyncTime!.minute.toString().padLeft(2, '0')})\nCliquez pour forcer la synchronisation'
                  : 'Double Sauvegarde Cloud active\nCliquez pour synchroniser'),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isSyncing
                ? null
                : () async {
                    final ok = await CloudSyncService.instance.syncAll(forceUpload: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? '☁️ Vos données sont 100% synchronisées sur le Cloud !'
                              : 'Erreur de synchronisation Cloud. Vérifiez votre connexion.'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSyncing ? Colors.amber.shade50 : Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSyncing ? Colors.amber.shade300 : Colors.teal.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSyncing)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                    )
                  else
                    const Icon(Icons.cloud_done_rounded, color: Colors.teal, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isSyncing ? 'Synchro...' : 'Cloud OK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSyncing ? Colors.amber.shade900 : Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineStorageButton(BuildContext context) {
    return AnimatedBuilder(
      animation: OfflineCourseManager.instance,
      builder: (context, _) {
        return Tooltip(
          message: 'Gérer les cours téléchargés et le stockage hors-ligne',
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal.shade700,
              side: BorderSide(color: Colors.teal.shade200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.offline_pin_rounded, size: 16, color: Colors.teal),
            label: const Text(
              'Mode Hors-Ligne',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineStorageScreen()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCatalogTab(
    BuildContext context,
    RevisionState state,
    List<MedicalModuleModel> filteredModules,
    int totalVisibleCourses, {
    bool isDesktopWide = true,
  }) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;
    final isFree = user?.tier == SubscriptionTier.free;

    if (isFree) {
      _checkAndPromptFreeModules(context, user, state.modules);
    }

    final selectedModules = FreeTrialQuotaService.instance.selectedFreeModules;

    return Column(
      children: [
        // Search & Category Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user?.isStudent == true) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Programme Universitaire • ${ResidencyRepository.getYearTitle(user?.studyYear ?? 1)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8)),
                            ),
                            const Text(
                              'Affichage ciblé : cours de votre année & QCMs d\'examens (EMD/Faculté). Les concours de résidanat sont exclus.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher parmi les 47 modules et 1 205 cours (ex: HTA, Asthme, ECG)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: (context.watch<AuthBloc>().state.user?.isStudent == true
                      ? [
                          'Mon Année (${context.watch<AuthBloc>().state.user?.studyYear ?? 1}e)',
                          '1ère Année',
                          '2ème Année',
                          '3ème Année',
                          '4ème Année',
                          '5ème Année',
                          '6ème Année',
                          'Tous les Modules',
                        ]
                      : _defaultCategories).map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(cat),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    '${filteredModules.length} modules affichés • $totalVisibleCourses cours officiels révisables',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (state.activeCourseProgresses.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${state.activeCourseProgresses.length} révision(s) en pause ⏸️',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      if (!isDesktopWide) ...[
                        _buildCloudSyncPill(context),
                        _buildOfflineStorageButton(context),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isFree) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade50,
                  Colors.amber.shade100.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stars_rounded, color: Colors.amber.shade900, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pass Découverte Actif',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF78350F)),
                      ),
                      Text(
                        selectedModules.isNotEmpty
                            ? 'Modules choisis : ${selectedModules.join(" & ")} (2 cours débloqués par spécialité • 1 session QCM test)'
                            : 'Choisissez 2 spécialités médicales à explorer (2 cours gratuits par spécialité).',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF78350F),
                  ),
                  onPressed: () => _showSelectFreeModulesDialog(context, user!, state.modules),
                  child: Text(
                    selectedModules.isNotEmpty ? 'Modifier' : 'Choisir',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 1),

        // Modules List
        Expanded(
          child: filteredModules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun module trouvé pour "$_searchQuery"',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredModules.length,
                  itemBuilder: (context, index) {
                    final module = filteredModules[index];
                    return _ModuleCard(
                      module: module,
                      activeProgresses: state.activeCourseProgresses,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomSessionsTab(
    BuildContext context,
    RevisionState state, {
    bool isDesktopWide = true,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Promo Creation Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryTeal.withValues(alpha: 0.12),
                AppTheme.primaryTeal.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sessions de Révision Sur-Mesure',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Créez des séries ciblées en combinant plusieurs modules & cours',
                          style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Nouvelle Session Personnalisée 🎯',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () async {
                    await CustomSessionBuilderDialog.show(context, state.modules);
                    if (context.mounted) {
                      context.read<RevisionBloc>().add(LoadSavedSessionsEvent());
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Active Custom Sessions List
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'Mes Sessions Enregistrées',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDesktopWide) ...[
                  _buildCloudSyncPill(context),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${state.customSessions.length} session(s)',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (state.customSessions.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.dashboard_customize_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucune session personnalisée pour le moment.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliquez sur le bouton ci-dessus pour composer votre première session multi-cours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ...state.customSessions.map((s) => _CustomSessionCard(session: s)),
        ],
      ],
    );
  }

  bool _checkedTrialModules = false;

  void _checkAndPromptFreeModules(BuildContext context, UserModel? user, List<MedicalModuleModel> modules) {
    if (_checkedTrialModules) return;
    if (user != null && user.tier == SubscriptionTier.free && modules.isNotEmpty) {
      _checkedTrialModules = true;
      FreeTrialQuotaService.instance.loadQuotas(user.id).then((_) {
        if (mounted) {
          setState(() {});
          if (FreeTrialQuotaService.instance.selectedFreeModules.length < 2) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSelectFreeModulesDialog(context, user, modules);
            });
          }
        }
      });
    }
  }

  void _showSelectFreeModulesDialog(BuildContext context, UserModel user, List<MedicalModuleModel> allModules) {
    final currentSelected = List<String>.from(FreeTrialQuotaService.instance.selectedFreeModules);
    final selectedNames = <String>{...currentSelected};
    String filterText = '';

    showDialog(
      context: context,
      barrierDismissible: currentSelected.length >= 2,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final displayModules = allModules.where((m) {
            if (filterText.isEmpty) return true;
            return m.name.toLowerCase().contains(filterText.toLowerCase());
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stars_rounded, color: Colors.amber.shade900, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pass Découverte',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Choisissez 2 spécialités médicales à explorer',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sélectionnez 2 modules de révision. Les 2 premiers cours de chacun seront immédiatement débloqués pour vos tests (${selectedNames.length}/2 sélectionnés).',
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une spécialité...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                    ),
                    onChanged: (val) => setDlgState(() => filterText = val.trim()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayModules.length,
                      itemBuilder: (context, i) {
                        final mod = displayModules[i];
                        final isChecked = selectedNames.contains(mod.name);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            mod.name,
                            style: TextStyle(
                              fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                              color: isChecked ? AppTheme.primaryTeal : null,
                            ),
                          ),
                          subtitle: Text('${mod.totalCourses} cours • ${mod.totalQuestions} QCMs', style: const TextStyle(fontSize: 11)),
                          value: isChecked,
                          onChanged: (bool? val) {
                            setDlgState(() {
                              if (val == true) {
                                if (selectedNames.length >= 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Le Pass Découverte est limité à 2 modules au choix.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                selectedNames.add(mod.name);
                              } else {
                                selectedNames.remove(mod.name);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (currentSelected.length >= 2)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedNames.length == 2 ? AppTheme.primaryTeal : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text('Valider mes 2 modules (${selectedNames.length}/2)'),
                onPressed: selectedNames.length == 2
                    ? () async {
                        final list = selectedNames.toList();
                        await FreeTrialQuotaService.instance.selectFreeModules(user.id, list);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF16A34A),
                              content: Text('Modules activés : ${list.join(" & ")}. Les 2 premiers cours sont débloqués !'),
                            ),
                          );
                        }
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String cat) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(cat),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryTeal : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedCategory = cat),
    );
  }
}

class _CustomSessionCard extends StatelessWidget {
  final CustomRevisionSession session;
  const _CustomSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final currentQ = session.currentQuestionIndex + 1;
    final totalQ = session.totalQuestions;
    final pct = (session.progressPercentage * 100).toInt();
    final isPaused = session.currentQuestionIndex > 0 && !session.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPaused ? AppTheme.primaryTeal.withValues(alpha: 0.4) : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'En pause ⏸️ ($pct%)',
                      style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) {
                    if (val == 'delete') {
                      context.read<RevisionBloc>().add(DeleteCustomSessionEvent(session.id));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Supprimer la session', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${session.courseIds.length} cours • ${session.moduleNames.take(2).join(", ")}${session.moduleNames.length > 2 ? "..." : ""}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: session.progressPercentage,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
              ),
            ),
            const SizedBox(height: 12),

            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalQ > 0 ? 'Question $currentQ sur $totalQ' : '${session.questionLimit == -1 ? "Tous" : session.questionLimit} questions',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (isPaused) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Recommencer', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          final user = context.read<AuthBloc>().state.user;
                          if (user?.tier == SubscriptionTier.free) {
                            if (!FreeTrialQuotaService.instance.canStartQcmSession(user)) {
                              FreeTrialQuotaService.showQuotaLimitDialog(
                                context,
                                featureTitle: 'Session Test Pass Découverte Utilisée',
                                message: 'Vous avez déjà utilisé votre session de révision test gratuite. Pour continuer à vous entraîner sur les 6 240+ QCMs sans limite, abonnez-vous à l\'un de nos plans.',
                              );
                              return;
                            }
                            FreeTrialQuotaService.instance.consumeQcmSession(user);
                          }
                          final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
                          context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: false, filterForStudent: isStudent));
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 34),
                      ),
                      icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.play_arrow_rounded, size: 16),
                      label: Text(
                        isPaused ? 'Reprendre (Q. $currentQ)' : 'Démarrer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        final user = context.read<AuthBloc>().state.user;
                        if (!isPaused && user?.tier == SubscriptionTier.free) {
                          if (!FreeTrialQuotaService.instance.canStartQcmSession(user)) {
                            FreeTrialQuotaService.showQuotaLimitDialog(
                              context,
                              featureTitle: 'Session Test Pass Découverte Utilisée',
                              message: 'Vous avez déjà utilisé votre session de révision test gratuite. Pour composer et démarrer des sessions sur-mesure en illimité, abonnez-vous à l\'un de nos plans.',
                            );
                            return;
                          }
                          FreeTrialQuotaService.instance.consumeQcmSession(user);
                        }
                        if (session.sessionMode == 'exam') {
                          ResidencyRepository.getQuestionsForMultipleCoursesAsync(
                            courseIds: session.courseIds,
                            moduleIds: session.moduleIds,
                            limit: session.questionLimit,
                            shuffle: session.shuffleQuestions,
                            allowedTypes: session.allowedTypes,
                          ).then((rawPool) {
                            if (rawPool.isNotEmpty && context.mounted) {
                              final examSession = ExamSessionModel(
                                id: session.id,
                                title: session.title,
                                questions: rawPool,
                                durationMinutes: session.durationMinutes ?? 60,
                                startedAt: DateTime.now(),
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExamRunnerScreen(
                                    session: examSession,
                                    correctionStyle: session.correctionStyle,
                                  ),
                                ),
                              ).then((_) {
                                if (context.mounted) {
                                  context.read<RevisionBloc>().add(LoadSavedSessionsEvent());
                                }
                              });
                            }
                          });
                          return;
                        }

                        final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
                        context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: isPaused, filterForStudent: isStudent));
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                        ).then((_) {
                          if (context.mounted) {
                            context.read<RevisionBloc>().add(LoadSavedSessionsEvent());
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final MedicalModuleModel module;
  final Map<String, CourseRevisionProgress> activeProgresses;

  const _ModuleCard({required this.module, required this.activeProgresses});

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _expanded = false;

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'favorite': return Icons.favorite_rounded;
      case 'air': return Icons.air_rounded;
      case 'psychology': return Icons.psychology_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'child_care': return Icons.child_care_rounded;
      case 'coronavirus': return Icons.coronavirus_rounded;
      case 'emergency': return Icons.emergency_rounded;
      case 'accessibility_new': return Icons.accessibility_new_rounded;
      case 'pregnant_woman': return Icons.pregnant_woman_rounded;
      case 'visibility': return Icons.visibility_rounded;
      case 'hearing': return Icons.hearing_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'spa': return Icons.spa_rounded;
      case 'bloodtype': return Icons.bloodtype_rounded;
      case 'medication': return Icons.medication_rounded;
      case 'self_improvement': return Icons.self_improvement_rounded;
      case 'shield': return Icons.shield_rounded;
      case 'science': return Icons.science_rounded;
      default: return Icons.school_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getIconData(m.iconName), color: AppTheme.primaryTeal, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${m.totalCourses} cours • ${m.totalQuestions} QCMs',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.category,
                                style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Téléchargement du pack "${m.name}" (${m.courses.length} cours) en cours...'),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                await OfflineCourseManager.instance.downloadEntireModule(m);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Pack "${m.name}" disponible en mode hors-ligne !'),
                                      backgroundColor: Colors.teal,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download_for_offline_rounded, size: 12, color: Colors.teal),
                                    SizedBox(width: 4),
                                    Text(
                                      'Pack Hors-Ligne',
                                      style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 24),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: m.courses.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final course = m.courses[i];
                  return _CourseTile(
                    course: course,
                    moduleName: m.name,
                    courseIndex: i,
                    progress: widget.activeProgresses[course.id],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final CourseModel course;
  final String moduleName;
  final int courseIndex;
  final CourseRevisionProgress? progress;

  const _CourseTile({
    required this.course,
    required this.moduleName,
    required this.courseIndex,
    this.progress,
  });

  void _showPaywallPrompt(BuildContext context, String lockReason) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Contenu Verrouillé'),
          ],
        ),
        content: Text(
          lockReason.isNotEmpty
              ? lockReason
              : 'Ce cours fait partie du programme officiel avancé. Choisissez un abonnement pour débloquer l\'accès complet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            onPressed: () {
              Navigator.pop(dlgContext);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
              );
            },
            child: const Text('Voir les Plans'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;
    final isExpired = user?.isSubscriptionActive == false;
    final isClinicalOnly = user?.tier == SubscriptionTier.clinicalPro;
    final isFree = user?.tier == SubscriptionTier.free;

    final isUnlocked = FreeTrialQuotaService.instance.isCourseUnlocked(user, moduleName, courseIndex);
    final bool isLocked = !isUnlocked;

    String lockReason = '';
    if (isExpired) {
      lockReason = 'Votre abonnement a expiré. Veuillez renouveler votre formule pour accéder aux 47 modules et 6 240+ QCMs.';
    } else if (isClinicalOnly) {
      lockReason = 'Les 47 modules complets de préparation au Résidanat sont inclus dans le Pass Résident Élite ou All-Access. Votre Pass Clinique Pro est optimisé pour les urgences et la pratique hospitalière.';
    } else if (isFree) {
      final selected = FreeTrialQuotaService.instance.selectedFreeModules;
      if (selected.isEmpty) {
        lockReason = 'Veuillez choisir vos 2 spécialités médicales d\'essai dans le catalogue pour débloquer leurs 2 premiers cours.';
      } else {
        final normModule = FreeTrialQuotaService.instance.normalizeModuleName(moduleName);
        final isChosen = selected.any((m) {
          final chosenNorm = FreeTrialQuotaService.instance.normalizeModuleName(m);
          return normModule.contains(chosenNorm) || chosenNorm.contains(normModule);
        });
        if (!isChosen) {
          lockReason = 'Le module "$moduleName" n\'a pas été sélectionné dans vos 2 spécialités d\'essai (${selected.join(", ")}). Passez au Pass Résident Élite ou All-Access pour débloquer l\'intégralité des 47 modules.';
        } else {
          lockReason = 'Dans le Pass Découverte, seuls les 2 premiers cours de chaque spécialité choisie sont accessibles gratuitement. Passez au Pass Résident Élite ou All-Access pour débloquer les autres cours de ce module.';
        }
      }
    }

    final isPaused = progress != null && !progress!.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;

          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  if (isPaused) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⏸️ En pause (${progress!.currentQuestionIndex + 1}/${progress!.totalQuestions})',
                        style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${course.questionsCount} questions officielles de concours',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.5)),
                ),
                icon: Icon(
                  isLocked ? Icons.lock_outline_rounded : Icons.menu_book_rounded,
                  size: 14,
                  color: AppTheme.primaryTeal,
                ),
                label: const Text(
                  'Fiche',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (isLocked) {
                    _showPaywallPrompt(context, lockReason);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseSummaryScreen(
                        course: course,
                        moduleName: moduleName,
                      ),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                icon: Icon(isLocked ? Icons.lock_outline_rounded : Icons.picture_as_pdf_rounded, size: 14),
                label: const Text('PDF', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  if (isLocked) {
                    _showPaywallPrompt(context, lockReason);
                    return;
                  }
                  if (course.hasPdf || (course.pdfDownloadUrl != null && course.pdfDownloadUrl!.isNotEmpty)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoursePdfViewerScreen(
                          course: course,
                          moduleName: moduleName,
                        ),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Support PDF pour "${course.name}" en cours de préparation.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (!isLocked && (course.hasPdf || (course.pdfDownloadUrl != null && course.pdfDownloadUrl!.isNotEmpty)))
                AnimatedBuilder(
                  animation: OfflineCourseManager.instance,
                  builder: (context, _) {
                    final mgr = OfflineCourseManager.instance;
                    final progress = mgr.getProgress(course.id);
                    final isDownloading = progress > 0;
                    final isOffline = mgr.isCourseAvailableOfflineSync(course.id);

                    if (isDownloading) {
                      final pct = (progress * 100).toInt();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('$pct%', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }

                    if (isOffline) {
                      return Tooltip(
                        message: 'Disponible 100% hors-ligne',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.offline_pin_rounded, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Hors-ligne', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    }

                    return Tooltip(
                      message: 'Télécharger pour consultation hors-ligne (sans internet)',
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: BorderSide(color: Colors.teal.shade200),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 14),
                        label: const Text('Hors-ligne', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Téléchargement de "${course.name}" lancé...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          final ok = await mgr.downloadCourse(course);
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cours "${course.name}" prêt pour le mode hors-ligne !'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked
                      ? Colors.grey.shade400
                      : (isPaused ? const Color(0xFFD97706) : AppTheme.primaryTeal),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                icon: Icon(
                  isLocked
                      ? Icons.lock_rounded
                      : (isPaused ? Icons.play_arrow_rounded : Icons.play_arrow_rounded),
                  size: 16,
                ),
                label: Text(
                  isLocked ? 'Débloquer' : (isPaused ? 'Continuer' : 'Réviser'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (isLocked) {
                    _showPaywallPrompt(context, lockReason);
                    return;
                  }

                  if (!isPaused && user?.tier == SubscriptionTier.free) {
                    if (!FreeTrialQuotaService.instance.canStartQcmSession(user)) {
                      FreeTrialQuotaService.showQuotaLimitDialog(
                        context,
                        featureTitle: 'Session Test Pass Découverte Utilisée',
                        message: 'Vous avez déjà utilisé votre session de révision test gratuite. Pour continuer à vous entraîner sur l\'ensemble des 6 240+ QCMs sans limite, abonnez-vous à l\'un de nos plans.',
                      );
                      return;
                    }
                    FreeTrialQuotaService.instance.consumeQcmSession(user);
                  }

                  if (isPaused) {
                    ResumeSessionSheet.show(context, course: course, progress: progress!);
                  } else {
                    final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
                    context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(course, resume: false, filterForStudent: isStudent));
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                    );
                  }
                },
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 8),
                actionButtons,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleSection),
              const SizedBox(width: 12),
              actionButtons,
            ],
          );
        },
      ),
    );
  }
}
