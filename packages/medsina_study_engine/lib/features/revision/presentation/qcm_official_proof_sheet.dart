import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_core/core/utils/medical_text_formatter.dart';
import '../models/module_model.dart';
import '../models/qcm_model.dart';
import '../data/residency_repository.dart';
import 'package:medsina_core/core/interfaces/feature_contracts.dart';
import 'course_pdf_viewer_screen.dart';

/// Clinical search keyword extractor tailored for French medical residency MCQs.
/// Strips prompt boilerplate (Cochez la réponse, Concernant, RF, RJ...) and extracts
/// genuine anatomical, semiological, and therapeutic search terms.
class QcmKeywordExtractor {
  static const Set<String> _stopWords = {
    'le', 'la', 'les', 'l', 'd', 'un', 'une', 'des', 'ce', 'cet', 'cette', 'ces',
    'du', 'de', 'au', 'aux', 'dans', 'pour', 'avec', 'sans', 'sous', 'sur', 'vers',
    'chez', 'entre', 'par', 'selon', 'contre', 'en', 'et', 'ou', 'ni', 'car',
    'cochez', 'cocher', 'reponse', 'réponse', 'exacte', 'fausse', 'juste', 'vraie',
    'inexacte', 'erronee', 'erronée', 'incorrecte', 'proposition', 'propositions',
    'suivante', 'suivantes', 'parmi', 'toutes', 'tous', 'sauf', 'sont', 'peut',
    'peuvent', 'doit', 'doivent', 'faire', 'fait', 'font', 'être', 'etre', 'avoir',
    'plus', 'moins', 'quel', 'quelle', 'quels', 'quelles', 'lequel', 'laquelle',
    'lesquels', 'lesquelles', 'comme', 'ainsi', 'dont', 'leur', 'leurs', 'mais',
    'donc', 'lors', 'lorsque', 'lorsqu', 'devant', 'premier', 'premiere', 'première',
    'lieu', 'concernant', 'propos', 'sujet', 'énoncé', 'enonce', 'assertion',
    'affirmation', 'caractère', 'caractere', 'caractères', 'caracteres', 'élément',
    'element', 'éléments', 'elements', 'lésion', 'lesion', 'lésions', 'lesions',
    'prélèvement', 'prelevement', 'prélèvements', 'prelevements', 'indiquez',
    'choisir', 'noter', 'celui', 'celle', 'ceux', 'celles', 'autre', 'autres',
    'bonne', 'mauvaise', 'justes', 'vraies', 'fausses'
  };

  static List<String> extractCandidates({
    required String questionText,
    required List<QcmOption> options,
    required List<String> correctAnswers,
    required String courseName,
  }) {
    final candidates = <String>[];

    // 1. Clean question prompt boilerplate
    var q = questionText.replaceAll(
      RegExp(r'\((?:RF|RJ|1RJ|2RJ|CS|QCM|FS|sauf une|cocher.*?)\)', caseSensitive: false),
      ' ',
    );
    q = q.replaceAll(
      RegExp(
        r'^\s*(?:coch(?:ez|er)|indiqu(?:ez|er)|not(?:ez|er)|choisir)\s+(?:la|les|une|le)?\s*(?:réponse|reponse|proposition|assertion|énoncé|affirmation)?s?\s*(?:exacte|juste|fausse|vraie|erronée|incorrecte|inexacte)?s?\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );
    q = q.replaceAll(
      RegExp(r'^\s*toutes?\s+ces?\s+propositions?\s+concernant\s+', caseSensitive: false),
      '',
    );
    q = q.replaceAll(
      RegExp(r'^\s*(?:concernant|à propos d[e\x27\’]?|au sujet d[e\x27\’]?)\s+', caseSensitive: false),
      '',
    );
    q = q.replaceAll(
      RegExp(
        r'^\s*(?:parmi\s+(?:les|ces)\s+.*?(?:suivantes?|propositions?|caractères?|éléments?|lésions?|prélèvements?)[,\s]+(?:laquelle|lequel|quelle|quel|celui)\s+(?:est|sont|ne\s+caractérise\s+pas|constitue|n[\x27\’]est\s+pas)\s+.*?:?\s*)',
        caseSensitive: false,
      ),
      '',
    );
    q = q.replaceAll(
      RegExp(r'^\s*quel(?:le)?s?\s+est\s+(?:la|le|les)?\s*', caseSensitive: false),
      '',
    );
    q = q.replaceAll(
      RegExp(
        r'[:\s]*(?:sont\s+justes?\s+sauf\s+.*|sont\s+vraies?\s+sauf\s+.*|cocher\s+la\s+réponse\s+.*)$',
        caseSensitive: false,
      ),
      '',
    );

    final qWords = q
        .split(RegExp(r'[\s,;:«»\"\(\)\x27\’\.\-\?\!/]+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w.toLowerCase()))
        .toList();

    if (qWords.length >= 2) {
      candidates.add('${qWords[0]} ${qWords[1]}');
    }
    if (qWords.isNotEmpty) {
      candidates.add(qWords[0]);
    }
    if (qWords.length >= 4) {
      candidates.add('${qWords[2]} ${qWords[3]}');
    } else if (qWords.length >= 3) {
      candidates.add(qWords[2]);
    }

    // 2. Extract clinical terms from validated correct option(s)
    final correctOptions = options.where((o) => correctAnswers.contains(o.key));
    for (final opt in correctOptions) {
      final optWords = opt.text
          .split(RegExp(r'[\s,;:«»\"\(\)\x27\’\.\-\?\!/]+'))
          .where((w) => w.length >= 4 && !_stopWords.contains(w.toLowerCase()))
          .toList();
      if (optWords.length >= 2) {
        candidates.add('${optWords[0]} ${optWords[1]}');
      }
      if (optWords.isNotEmpty) {
        candidates.add(optWords[0]);
      }
    }

    // 3. Fallback to course name
    if (courseName.trim().isNotEmpty) {
      final cWords = courseName
          .split(RegExp(r'[\s,;:«»\"\(\)\x27\’\.\-\?\!/]+'))
          .where((w) => w.length >= 4 && !_stopWords.contains(w.toLowerCase()))
          .toList();
      if (cWords.length >= 2) {
        candidates.add('${cWords[0]} ${cWords[1]}');
      }
      if (cWords.isNotEmpty) {
        candidates.add(cWords[0]);
      }
    }

    final seen = <String>{};
    final dedup = <String>[];
    for (final c in candidates) {
      final norm = c.trim().toLowerCase();
      if (norm.length >= 3 && !seen.contains(norm)) {
        seen.add(norm);
        dedup.add(c.trim());
      }
    }

    return dedup;
  }
}

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
  late final TextEditingController _searchQueryController;
  List<String> _candidateKeywords = [];

  @override
  void initState() {
    super.initState();
    _resolvedCourse = widget.course;
    _initSearchKeywords();
    if (_resolvedCourse == null) {
      _resolveCourse();
    }
  }

  void _initSearchKeywords() {
    _candidateKeywords = QcmKeywordExtractor.extractCandidates(
      questionText: widget.question.questionText,
      options: widget.question.options,
      correctAnswers: widget.question.correctAnswers,
      courseName: widget.course?.name ?? widget.question.courseName,
    );

    final initialKeyword = _candidateKeywords.isNotEmpty
        ? _candidateKeywords.first
        : (widget.course?.name ?? widget.question.courseName);

    _searchQueryController = TextEditingController(text: initialKeyword);
  }

  @override
  void dispose() {
    _searchQueryController.dispose();
    super.dispose();
  }

  Future<void> _resolveCourse() async {
    setState(() => _isLoadingCourse = true);
    final found = await ResidencyRepository.findCourseById(widget.question.courseId) ??
        await ResidencyRepository.findCourseByNameOrId(widget.question.courseName);
    if (mounted) {
      setState(() {
        _resolvedCourse = found;
        _isLoadingCourse = false;
        // Re-evaluate candidates if course name has changed
        if (found != null && _candidateKeywords.isEmpty) {
          _initSearchKeywords();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = widget.question;
    final course = _resolvedCourse;

    final cleanedQuestionText = MedicalTextFormatter.clean(q.questionText);
    final currentSearchQuery = _searchQueryController.text.trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
              color: Colors.grey.withValues(alpha: 0.35),
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
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
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
                        'Certification de la réponse d\'annale & Corrigé officiel',
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
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
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
                          if (course != null || q.courseName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 12, color: Color(0xFF0D9488)),
                                  const SizedBox(width: 4),
                                  Text(
                                    course?.name ?? q.courseName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF0F766E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
                      if (q.clinicalCaseText != null && q.clinicalCaseText!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE).withValues(alpha: isDark ? 0.15 : 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.medical_information_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Cas Clinique & Données de l\'Énoncé :',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                MedicalTextFormatter.clean(q.clinicalCaseText!),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        cleanedQuestionText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
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
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
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
                      const SizedBox(height: 12),

                      // Full options list with clear validation distinction
                      ...q.options.map((opt) {
                        final isCorrect = q.correctAnswers.contains(opt.key);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.08)
                                : (isDark ? Colors.black12 : const Color(0xFFF9FAFB)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect
                                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                  : (isDark ? Colors.white10 : Colors.black12),
                              width: isCorrect ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isCorrect ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  opt.key,
                                  style: TextStyle(
                                    color: isCorrect ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  MedicalTextFormatter.clean(opt.text),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                                    color: isCorrect
                                        ? (isDark ? Colors.white : const Color(0xFF065F46))
                                        : (isDark ? Colors.white60 : Colors.black87),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isCorrect)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 11, color: Colors.white),
                                      SizedBox(width: 3),
                                      Text(
                                        'Validé',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                      if (q.explanation.isNotEmpty) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 15, color: Color(0xFF0D9488)),
                            const SizedBox(width: 6),
                            const Text(
                              'Justification du Corrigé Type & Références :',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: MedicalTextFormatter.clean(q.explanation),
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            h1: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            listBullet: const TextStyle(color: Color(0xFF0D9488)),
                            tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
                            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                        ),
                      ],

                      if (q.examTrap != null && q.examTrap!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withValues(alpha: isDark ? 0.15 : 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade400.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Piège d\'annale : ${q.examTrap!}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Section: Recherche Ciblée & Mots-Clés
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.search_rounded, color: Color(0xFF0D9488), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Vérification dans les Documents Officiels',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recherchez la réponse exacte dans les polycopiés, corrigés de TD et comités pédagogiques :',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Editable Keyword Field
                      TextField(
                        controller: _searchQueryController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Terme exact à localiser dans le cours',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF0F766E),
                          ),
                          prefixIcon: const Icon(Icons.find_in_page_rounded, size: 18, color: Color(0xFF0D9488)),
                          suffixIcon: _searchQueryController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchQueryController.clear();
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick-select Candidate Chips
                      if (_candidateKeywords.isNotEmpty) ...[
                        Text(
                          'Mots-clés pertinents extraits de la question & corrigé :',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _candidateKeywords.take(5).map((kw) {
                            final isSelected = currentSearchQuery.toLowerCase() == kw.toLowerCase();
                            return ChoiceChip(
                              label: Text(
                                kw,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0D9488),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _searchQueryController.text = kw;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Button 1: Cours PDF Officiel de la Faculté
                _buildVerificationTile(
                  context,
                  isDark: isDark,
                  icon: Icons.picture_as_pdf_rounded,
                  accentColor: const Color(0xFF0D9488),
                  title: 'Cours PDF Officiel de la Faculté',
                  subtitle: course != null
                      ? '${course.name} • Recherche ciblée sur "${currentSearchQuery.isNotEmpty ? currentSearchQuery : course.name}"'
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
                          initialSearchQuery: currentSearchQuery.isNotEmpty
                              ? currentSearchQuery
                              : course.name,
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
                    MedsinaFeatureRegistry.instance.dispatchRoute(context, 'course_summary', {'course': course});
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
                      MedsinaFeatureRegistry.instance.dispatchRoute(context, 'course_mindmap', {'course': course!});
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
                  subtitle: currentSearchQuery.isNotEmpty
                      ? 'Cas cliniques transversaux (Filtre "$currentSearchQuery")'
                      : 'Cas cliniques transversaux & corrigés officiels des comités',
                  buttonLabel: 'Explorer les Samedis Pédagogiques ➔',
                  onTap: () {
                    MedsinaFeatureRegistry.instance.dispatchRoute(context, 'samedis_pedagogiques', {'initialSearchQuery': currentSearchQuery});
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
              color: accentColor.withValues(alpha: 0.12),
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
