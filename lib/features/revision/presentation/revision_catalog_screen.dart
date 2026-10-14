import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../bloc/revision_state.dart';
import '../models/module_model.dart';
import '../models/revision_session_model.dart';
import 'course_pdf_viewer_screen.dart';
import 'course_summary_screen.dart';
import 'custom_session_builder_dialog.dart';
import 'qcm_study_screen.dart';
import 'resume_session_sheet.dart';

class RevisionCatalogScreen extends StatefulWidget {
  const RevisionCatalogScreen({super.key});

  @override
  State<RevisionCatalogScreen> createState() => _RevisionCatalogScreenState();
}

class _RevisionCatalogScreenState extends State<RevisionCatalogScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  final List<String> _categories = [
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
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canPop
          ? AppBar(
              title: const Text(
                'Catalogue & Révision Résidanat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            final matchesCat = _selectedCategory == 'Tous' ||
                m.category.toLowerCase().contains(_selectedCategory.toLowerCase());
            final matchesSearch = _searchQuery.isEmpty ||
                m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                m.courses.any((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()));
            return matchesCat && matchesSearch;
          }).toList();

          final totalVisibleCourses = filteredModules.fold<int>(0, (sum, m) => sum + m.totalCourses);

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Navigation TabBar: Catalogue vs Sessions Sur-Mesure
                Container(
                  color: Theme.of(context).cardColor,
                  child: TabBar(
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
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Official Modules & Courses Catalogue
                      _buildCatalogTab(context, state, filteredModules, totalVisibleCourses),

                      // Tab 2: Custom Multi-Course Sessions
                      _buildCustomSessionsTab(context, state),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogTab(
    BuildContext context,
    RevisionState state,
    List<MedicalModuleModel> filteredModules,
    int totalVisibleCourses,
  ) {
    return Column(
      children: [
        // Search & Category Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  children: _categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(cat),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredModules.length} modules affichés • $totalVisibleCourses cours officiels révisables',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                  ),
                  if (state.activeCourseProgresses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildCustomSessionsTab(BuildContext context, RevisionState state) {
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
                  onPressed: () => CustomSessionBuilderDialog.show(context, state.modules),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Active Custom Sessions List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mes Sessions Enregistrées',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(
              '${state.customSessions.length} session(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
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
                          context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: false));
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
                        context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: isPaused));
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                        );
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
                        Row(
                          children: [
                            Text(
                              '${m.totalCourses} cours • ${m.totalQuestions} QCMs',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
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
  final CourseRevisionProgress? progress;

  const _CourseTile({
    required this.course,
    required this.moduleName,
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
    final isFree = user?.tier == SubscriptionTier.free;
    final isClinicalOnly = user?.tier == SubscriptionTier.clinicalPro;
    final isCardioPreview = moduleName.toLowerCase().contains('cardio');

    final bool isLocked = isExpired || (isFree && !isCardioPreview) || (isClinicalOnly && !isCardioPreview);

    String lockReason = '';
    if (isExpired) {
      lockReason = 'Votre abonnement a expiré. Veuillez renouveler votre formule pour accéder aux 47 modules et 6 240+ QCMs.';
    } else if (isClinicalOnly) {
      lockReason = 'Les 47 modules complets de préparation au Résidanat sont inclus dans le Pass Résident Élite ou All-Access. Votre Pass Clinique Pro est optimisé pour les urgences et la pratique hospitalière (avec accès au module Cardiologie en aperçu).';
    } else if (isFree) {
      lockReason = 'Le module "$moduleName" est réservé aux abonnés. Votre Pass Découverte inclut le module Cardiologie en accès gratuit. Choisissez le Pass Résident Élite ou All-Access pour débloquer tous les modules.';
    }

    final isPaused = progress != null && !progress!.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
            ),
          ),
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
          const SizedBox(width: 6),
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
          const SizedBox(width: 8),
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

              if (isPaused) {
                ResumeSessionSheet.show(context, course: course, progress: progress!);
              } else {
                context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(course, resume: false));
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
