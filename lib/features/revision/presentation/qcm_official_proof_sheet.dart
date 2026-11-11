import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/utils/medical_text_formatter.dart';
import '../models/module_model.dart';
import '../models/qcm_model.dart';
import '../data/residency_repository.dart';
import 'course_mindmap_screen.dart';
import 'course_pdf_viewer_screen.dart';
import 'course_summary_screen.dart';
import 'samedis_pedagogiques_screen.dart';

class QcmOfficialProofSheet extends StatefulWidget {
  final QcmQuestion question;
  final CourseModel? course;

  const QcmOfficialProofSheet({
    super.key,
    required this.question,
    this.course,
  });

  static Future<void> show(
    BuildContext context, {
    required QcmQuestion question,
    CourseModel? course,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QcmOfficialProofSheet(
        question: question,
        course: course,
      ),
    );
  }

  @override
  State<QcmOfficialProofSheet> createState() => _QcmOfficialProofSheetState();
}

class _QcmOfficialProofSheetState extends State<QcmOfficialProofSheet> {
  CourseModel? _resolvedCourse;
  bool _isLoadingCourse = false;

  @override
  void initState() {
    super.initState();
    _resolvedCourse = widget.course;
    if (_resolvedCourse == null) {
      _resolveCourse();
    }
  }

  Future<void> _resolveCourse() async {
    setState(() => _isLoadingCourse = true);
    final found = await ResidencyRepository.findCourseById(widget.question.courseId) ??
        await ResidencyRepository.findCourseByNameOrId(widget.question.courseName);
    if (mounted) {
      setState(() {
        _resolvedCourse = found;
        _isLoadingCourse = false;
      });
    }
  }

  String _extractSearchKeywords() {
    final raw = widget.question.questionText;
    // Extract first clinical noun or keywords
    final words = raw.split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !['dans', 'pour', 'avec', 'quel', 'quelle', 'parmi', 'suivantes', 'propositions', 'concernant'].contains(w.toLowerCase()))
        .take(2)
        .join(' ');
    return words.isNotEmpty ? words : widget.question.courseName;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = widget.question;
    final course = _resolvedCourse;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF0F766E),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preuve & Source Officielle',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Certification de la réponse d\'annale',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // 1. Official Examination Stamp Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFF0FDFA), const Color(0xFFE0F2FE)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  q.source.isNotEmpty ? q.source : 'Concours Résidanat',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Text(
                              'Session ${q.year}',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (q.reusedYears.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              'Re-tombée aux concours : ${q.reusedYears.join(', ')}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        q.questionText,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Corrigé Type Officiel & Validation du Jury
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fact_check_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Grille Officielle de Correction',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Validé : ${q.correctAnswers.join(", ")}',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...q.options.where((o) => q.correctAnswers.contains(o.key)).map(
                            (opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      opt.key,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      opt.text,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (q.explanation.isNotEmpty) ...[
                        const Divider(height: 18),
                        Text(
                          MedicalTextFormatter.clean(q.explanation),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.white60 : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Action Buttons: Vérifier dans le Cours PDF, Fiche, Mind Map, Samedis Pédagogiques
                const Text(
                  'Vérifier directement dans les documents d\'origine :',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                // Button 1: Cours PDF
                _buildVerificationTile(
                  context,
                  isDark: isDark,
                  icon: Icons.picture_as_pdf_rounded,
                  accentColor: const Color(0xFF0D9488),
                  title: 'Cours PDF Officiel de la Faculté',
                  subtitle: course != null
                      ? '${course.name} (Recherche ciblée automatique)'
                      : 'Recherche directe dans le polycopié officiel',
                  buttonLabel: 'Ouvrir le Cours PDF ➔',
                  onTap: () {
                    if (course == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Support de cours en cours de chargement...')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoursePdfViewerScreen(
                          course: course,
                          initialSearchQuery: _extractSearchKeywords(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Button 2: Fiche Synthèse
                _buildVerificationTile(
                  context,
                  isDark: isDark,
                  icon: Icons.summarize_rounded,
                  accentColor: const Color(0xFF0284C7),
                  title: 'Fiche Synthèse & Pièges d\'Annales',
                  subtitle: 'Définitions, critères diagnostiques & arbres décisionnels',
                  buttonLabel: 'Consulter la Fiche ➔',
                  onTap: () {
                    if (course == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseSummaryScreen(
                          course: course,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Button 3: Mind Map (if available)
                if (course?.hasAnyMindmap == true) ...[
                  _buildVerificationTile(
                    context,
                    isDark: isDark,
                    icon: Icons.account_tree_rounded,
                    accentColor: const Color(0xFF8B5CF6),
                    title: 'Mind Map du Cours 🧠',
                    subtitle: 'Visualisation arborescente des concepts et connexions',
                    buttonLabel: 'Ouvrir la Mind Map ➔',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseMindmapScreen(
                            course: course!,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Button 4: Samedis Pédagogiques & TD
                _buildVerificationTile(
                  context,
                  isDark: isDark,
                  icon: Icons.school_rounded,
                  accentColor: const Color(0xFF10B981),
                  title: 'Samedis Pédagogiques & TD Cliniques',
                  subtitle: 'Cas cliniques transversaux & corrigés officiels des comités',
                  buttonLabel: 'Explorer les Samedis Pédagogiques ➔',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SamedisPedagogiquesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onTap,
            child: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
