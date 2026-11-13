import '../../comments/presentation/medical_comments_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/theme/app_theme.dart';
import '../../ai_assistant/presentation/clinical_copilot_sheet.dart';
import '../data/course_summary_repository.dart';
import '../models/course_summary_model.dart';
import '../models/module_model.dart';
import 'course_pdf_viewer_screen.dart';
import 'course_mindmap_screen.dart';
import 'qcm_study_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';

class CourseSummaryScreen extends StatefulWidget {
  final CourseModel course;
  final String? moduleName;

  const CourseSummaryScreen({
    super.key,
    required this.course,
    this.moduleName,
  });

  @override
  State<CourseSummaryScreen> createState() => _CourseSummaryScreenState();
}

class _CourseSummaryScreenState extends State<CourseSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CourseSummaryModel? _summary;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final summary = await CourseSummaryRepository.getSummaryForCourse(
      widget.course.id,
      course: widget.course,
      moduleName: widget.moduleName,
    );
    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGenerateSummary() async {
    setState(() => _isGenerating = true);
    try {
      final generated = await CourseSummaryRepository.generateAndSaveSummary(
        course: widget.course,
        moduleName: widget.moduleName,
      );

      if (mounted) {
        if (generated != null) {
          setState(() {
            _summary = generated;
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fiche de synthèse générée et enregistrée avec succès !',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: const Text('Impossible de générer la fiche. Veuillez réessayer dans quelques instants.'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.course.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.moduleName ?? "Module"} • Fiche Synthétique Concours',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent),
            tooltip: 'Assistant IA Médical',
            onPressed: () {
              ClinicalCopilotSheet.show(
                context,
                initialSituation:
                    'Peux-tu m\'expliquer les points les plus tombables en QCM pour le cours "${widget.course.name}" (${widget.moduleName ?? ""}) ?',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_rounded, color: Color(0xFF8B5CF6)),
            tooltip: 'Mind Map 🧠 (Carte Mentale)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseMindmapScreen(
                    course: widget.course,
                    moduleName: widget.moduleName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Commentaires & Notes du Cours',
            onPressed: () {
              MedicalCommentsSheet.show(
                context,
                targetType: 'course',
                targetId: widget.course.id,
                targetTitle: widget.course.name,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadSummary,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.article_rounded, size: 20), text: 'Fiche Synthèse'),
            Tab(icon: Icon(Icons.star_rounded, size: 20), text: 'Points Clés'),
            Tab(icon: Icon(Icons.warning_amber_rounded, size: 20), text: 'Pièges Concours'),
            Tab(icon: Icon(Icons.account_tree_rounded, size: 20), text: 'Mind Map 🧠'),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement de la fiche synthétique...'),
                ],
              ),
            )
          : _summary == null
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMarkdownTab(),
                    _buildKeyTakeawaysTab(),
                    _buildExamTrapsTab(),
                    _buildMindMapTab(isDark),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    if (_isGenerating) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Génération de la Fiche Synthétique...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Medsina AI synthétise le cours "${widget.course.name}", extrait les points clés à haut rendement et repère les pièges d\'annales de concours...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enregistrement automatique sur le Cloud et en local',
                style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, size: 48, color: AppTheme.primaryTeal),
            ),
            const SizedBox(height: 20),
            const Text(
              'Fiche en cours de génération',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Le robot MedsinaPilot résume les cours toutes les 4 heures.\nCette fiche sera bientôt disponible sur le Cloud.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text(
                'Générer avec Medsina AI ✨',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _handleGenerateSummary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Livret All-in-One Concours 2027 Card
          if (widget.course.isHypertombable || widget.course.hasPublishedBooklet)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'LIVRET RÉVISION 2027',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF92400E),
                                fontSize: 13,
                              ),
                            ),
                            if (widget.course.isHypertombable) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'HYPERTOMBABLE',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.course.residanatYears.isNotEmpty
                              ? 'Annales Concours : Sessions ${widget.course.residanatYears.join(', ')}'
                              : 'Fiche Synthèse + Cours + QCMs + Corrigé type officiel',
                          style: const TextStyle(color: Color(0xFF78350F), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Ouvrir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CoursePdfViewerScreen(
                            course: widget.course,
                            moduleName: widget.moduleName,
                            isBooklet: true,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Highlight Banner
          if (_summary!.diagnosticCriteria != null || _summary!.treatmentSummary != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_summary!.diagnosticCriteria != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Critères Diagnostiques :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summary!.diagnosticCriteria!,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ],
                  if (_summary!.treatmentSummary != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.medication_rounded, size: 18, color: Colors.indigo),
                        const SizedBox(width: 8),
                        const Text(
                          'Ligne Thérapeutique Clé :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summary!.treatmentSummary!,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),

          // Main Markdown Content
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: MarkdownBody(
                data: _summary!.summaryMarkdown,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h2: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTeal,
                    height: 1.8,
                  ),
                  p: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF1E293B)),
                  listBullet: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                  strong: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildKeyTakeawaysTab() {
    final list = _summary!.keyTakeaways;
    if (list.isEmpty) {
      return const Center(child: Text('Aucun point clé listé.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final text = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
          ),
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryTeal,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamTrapsTab() {
    final list = _summary!.examTraps;
    if (list.isEmpty) {
      return const Center(child: Text('Aucun piège de concours répertorié pour ce cours.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final text = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFFFFFBEB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFDE68A)),
          ),
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Piège QCM n°${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Color(0xFF451A03),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMindMapTab(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.account_tree_rounded,
                size: 56,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mind Map Décisionnelle 2027',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arbre de décision clinique, flux diagnostique et thérapeutique optimisé pour le Concours de Résidanat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _buildMindmapFeatureRow(
                    Icons.touch_app_rounded,
                    'Navigation tactile interactive par branches',
                    const Color(0xFF0284C7),
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMindmapFeatureRow(
                    Icons.fullscreen_rounded,
                    'Aperçu vectoriel plein écran Format Paysage A3',
                    const Color(0xFF8B5CF6),
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMindmapFeatureRow(
                    Icons.cloud_done_rounded,
                    'Stockage Cloud Google Drive & 100% Hors-Ligne',
                    const Color(0xFF10B981),
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              icon: const Icon(Icons.account_tree_rounded),
              label: const Text(
                'Ouvrir la Mind Map du Cours 🧠',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseMindmapScreen(
                      course: widget.course,
                      moduleName: widget.moduleName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMindmapFeatureRow(
      IconData icon, String text, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (widget.course.hasPublishedBooklet) ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(
                    'Livret 2027 🔥',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoursePdfViewerScreen(
                          course: widget.course,
                          moduleName: widget.moduleName,
                          isBooklet: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Support PDF'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoursePdfViewerScreen(
                        course: widget.course,
                        moduleName: widget.moduleName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.quiz_rounded, size: 18),
                label: const Text(
                  'QCMs du Cours',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(widget.course, resume: false));
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.forum_outlined, size: 20),
              tooltip: 'Commentaires & Notes du Cours',
              onPressed: () {
                MedicalCommentsSheet.show(
                  context,
                  targetType: 'course',
                  targetId: widget.course.id,
                  targetTitle: widget.course.name,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
