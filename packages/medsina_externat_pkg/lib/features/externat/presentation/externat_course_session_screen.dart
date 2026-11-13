import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../data/models/externat_module_info.dart';
import '../data/models/externat_pedagogical_models.dart';
import '../services/externat_pedagogy_service.dart';

class ExternatCourseSessionScreen extends StatefulWidget {
  final String moduleName;
  final String courseName;
  final int studyYear;

  const ExternatCourseSessionScreen({
    super.key,
    required this.moduleName,
    required this.courseName,
    required this.studyYear,
  });

  @override
  State<ExternatCourseSessionScreen> createState() => _ExternatCourseSessionScreenState();
}

class _ExternatCourseSessionScreenState extends State<ExternatCourseSessionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ExternatTeacherPersona _teacher;
  InteractiveCourseSession? _session;
  bool _isLoading = true;
  String? _errorMessage;

  // Track user selections on flash questions: questionIndex -> selectedOptionIndex
  final Map<int, int> _selectedFlashAnswers = {};

  @override
  void initState() {
    super.initState();
    _teacher = ExternatCurriculumMatrix.getTeacherForYear(widget.studyYear);
    _tabController = TabController(length: 4, vsync: this);
    _loadCourseSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await ExternatPedagogyService.generateCourseSession(
        moduleName: widget.moduleName,
        courseName: widget.courseName,
        year: widget.studyYear,
      );
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Impossible de charger la session interactive : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.moduleName} • ${_teacher.name}',
              style: TextStyle(
                fontSize: 11,
                color: _teacher.themeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Régénérer la séance avec l\'Enseignant IA',
            onPressed: _loadCourseSession,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copier la fiche réflexe',
            onPressed: _session == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _session!.cheatSheetSummary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Fiche réflexe copiée dans le presse-papier !'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _teacher.themeColor,
          indicatorWeight: 3,
          labelColor: _teacher.themeColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.medical_information_rounded, size: 20), text: 'Amphi & Cas'),
            Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Cours Complet'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 20), text: 'Questions Flash'),
            Tab(icon: Icon(Icons.summarize_rounded, size: 20), text: 'Fiche Réflexe'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState(isDark)
          : _errorMessage != null
              ? _buildErrorState(isDark)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHookAndIntroTab(isDark),
                    _buildFullLectureTab(isDark),
                    _buildFlashQuestionsTab(isDark),
                    _buildCheatSheetTab(isDark),
                  ],
                ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _teacher.themeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_teacher.icon, size: 48, color: _teacher.themeColor),
            ),
            const SizedBox(height: 24),
            Text(
              '${_teacher.name} prépare votre séance...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Structuration des cas cliniques, pièges d\'EMD et questions flash d\'auto-évaluation.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                color: _teacher.themeColor,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Erreur inconnue',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCourseSession,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1 : CAS CLINIQUE D'ACCROCHE & PIÈGE DU PROFESSEUR ---
  Widget _buildHookAndIntroTab(bool isDark) {
    final s = _session!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Teacher Persona Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _teacher.themeColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _teacher.themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_teacher.icon, color: _teacher.themeColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            s.teacherName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _teacher.themeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Tuteur IA ${widget.studyYear}e Année',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: _teacher.themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.teacherTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '« ${_teacher.tagline} »',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: _teacher.themeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Clinical Hook Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Cas Clinique d\'Accroche (Amphi)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.clinicalHook,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Professor's Trap Card (Le Piège de l'Enseignant)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Le Piège Classique de l\'Enseignant aux EMDs ⚠️',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.professorTrap,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.amber.shade200 : const Color(0xFF78350F),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _teacher.themeColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: const Text('Passer au Cours Magistral Structuré', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _tabController.animateTo(1),
        ),
      ],
    );
  }

  // --- TAB 2 : COURS MAGISTRAL STRUCTURÉ ---
  Widget _buildFullLectureTab(bool isDark) {
    final s = _session!;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: s.lectureSections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final sec = s.lectureSections[i];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _teacher.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: _teacher.themeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sec.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MarkdownBody(
                data: sec.contentMarkdown,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Point Clé : ${sec.keyTakeaway}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3 : QUESTIONS FLASH D'ÉVALUATION ---
  Widget _buildFlashQuestionsTab(bool isDark) {
    final s = _session!;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: s.flashQuestions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (ctx, qIndex) {
        final q = s.flashQuestions[qIndex];
        final userChoice = _selectedFlashAnswers[qIndex];
        final hasAnswered = userChoice != null;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _teacher.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Question Flash ${qIndex + 1}/${s.flashQuestions.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _teacher.themeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                q.question,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),

              // Options
              ...List.generate(q.options.length, (optIndex) {
                final isSelected = userChoice == optIndex;
                final isCorrect = optIndex == q.correctOptionIndex;

                Color tileBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
                Color tileBgColor = Colors.transparent;

                if (hasAnswered) {
                  if (isCorrect) {
                    tileBorderColor = const Color(0xFF10B981);
                    tileBgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
                  } else if (isSelected) {
                    tileBorderColor = Colors.red;
                    tileBgColor = Colors.red.withValues(alpha: 0.1);
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: hasAnswered
                        ? null
                        : () {
                            setState(() {
                              _selectedFlashAnswers[qIndex] = optIndex;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: tileBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tileBorderColor, width: isSelected || (hasAnswered && isCorrect) ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? (isCorrect ? const Color(0xFF10B981) : Colors.red)
                                  : (isDark ? Colors.white10 : Colors.grey.shade100),
                            ),
                            child: Text(
                              String.fromCharCode(65 + optIndex),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.options[optIndex],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected || (hasAnswered && isCorrect) ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasAnswered && isCorrect)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                          else if (hasAnswered && isSelected && !isCorrect)
                            const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Explanation Box
              if (hasAnswered) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF0284C7), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q.explanation,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- TAB 4 : FICHE RÉFLEXE DE SYNTHÈSE ---
  Widget _buildCheatSheetTab(bool isDark) {
    final s = _session!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Fiche Réflexe Spéciale EMD',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF10B981), size: 20),
                    tooltip: 'Copier la fiche',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: s.cheatSheetSummary));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Fiche réflexe copiée !'),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              MarkdownBody(
                data: s.cheatSheetSummary,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
