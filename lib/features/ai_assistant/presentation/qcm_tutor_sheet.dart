import 'package:flutter/material.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../revision/models/qcm_model.dart';

class QcmTutorSheet extends StatefulWidget {
  final QcmQuestion question;

  const QcmTutorSheet({super.key, required this.question});

  static void show(BuildContext context, QcmQuestion question) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QcmTutorSheet(question: question),
    );
  }

  @override
  State<QcmTutorSheet> createState() => _QcmTutorSheetState();
}

class _QcmTutorSheetState extends State<QcmTutorSheet> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String? _response;
  String _activeQuestionAsked = '';

  final List<String> _suggestedPrompts = [
    '💡 Explique-moi les pièges classiques de ce QCM',
    '❌ Pourquoi les autres propositions sont-elles fausses ?',
    '📑 Rappelle-moi le consensus officiel sur ce sujet',
    '🩺 Quelle est la CAT pratique en urgence ?',
  ];

  @override
  void initState() {
    super.initState();
    // Automatically trigger the first explanation on open
    _askTutor('Explique-moi en détail la justification médicale de cette question et pourquoi la réponse ${widget.question.correctAnswers.join(", ")} est la bonne.');
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _askTutor(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _activeQuestionAsked = query;
      _response = null;
    });

    final optionsList = widget.question.options.map((o) => '${o.key}. ${o.text}').toList();

    try {
      final answer = await GeminiService.explainQcm(
        questionTitle: widget.question.questionText,
        optionsText: optionsList,
        correctKeys: widget.question.correctAnswers,
        userQuery: query,
      );

      if (mounted) {
        setState(() {
          _response = answer;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = 'Erreur lors de la communication avec le Tuteur IA: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryTeal, AppTheme.accentCyan],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Tuteur IA Medsina',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Gemini 3.5 Flash',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Résidanat Blida • Consensus & Pièges d\'Examen',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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

          // Content scroll area
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Question summary card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.primaryTeal),
                          const SizedBox(width: 6),
                          Text(
                            'Question analysée :',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          Text(
                            'Réponse : ${widget.question.correctAnswers.join(", ")}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.question.questionText,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Suggested Prompts Horizontal Scroll
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedPrompts.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final prompt = _suggestedPrompts[i];
                      return ActionChip(
                        label: Text(prompt, style: const TextStyle(fontSize: 11.5)),
                        onPressed: _isLoading ? null : () => _askTutor(prompt),
                        backgroundColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100,
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                // Active question badge
                if (_activeQuestionAsked.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Question posée : "$_activeQuestionAsked"',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                    ),
                  ),

                // AI Response Area
                if (_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryTeal),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Gemini analyse le cas et les consensus médicaux...',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_response != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            const Text(
                              'Analyse Pédagogique du Tuteur :',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _response!,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Custom question input bar
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Posez une question personnalisée au tuteur...',
                      hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _askTutor(val.trim());
                        _queryController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                  onPressed: _isLoading
                      ? null
                      : () {
                          final text = _queryController.text.trim();
                          if (text.isNotEmpty) {
                            _askTutor(text);
                            _queryController.clear();
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
