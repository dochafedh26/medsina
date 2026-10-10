import 'package:flutter/material.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_theme.dart';

class ClinicalCopilotSheet extends StatefulWidget {
  final String? initialSituation;

  const ClinicalCopilotSheet({super.key, this.initialSituation});

  static void show(BuildContext context, {String? initialSituation}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClinicalCopilotSheet(initialSituation: initialSituation),
    );
  }

  @override
  State<ClinicalCopilotSheet> createState() => _ClinicalCopilotSheetState();
}

class _ClinicalCopilotSheetState extends State<ClinicalCopilotSheet> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String? _response;
  String _activeQuestionAsked = '';

  final List<String> _clinicalSuggestions = [
    '⚡ CAT devant une détresse respiratoire aiguë',
    '💊 Choix de l\'antibiothérapie de première intention',
    '🔍 Diagnostics différentiels devant une douleur thoracique',
    '🧪 Interprétation d\'une gazométrie artérielle',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSituation != null && widget.initialSituation!.isNotEmpty) {
      _askCopilot('Donne-moi la conduite à tenir immédiate, les examens prioritaires et le traitement d\'urgence.');
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _askCopilot(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _activeQuestionAsked = query;
      _response = null;
    });

    try {
      final answer = await GeminiService.getClinicalAdvice(
        clinicalSituation: widget.initialSituation ?? 'Consultation médicale hospitalière / Urgences',
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
          _response = 'Erreur lors de la communication avec le Copilote Clinique: $e';
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
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Copilote Clinique & Urgences',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Gemini IA',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Aide à la Décision Médicale & CAT en Temps Réel',
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
                if (widget.initialSituation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment_rounded, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text(
                              'Protocole / Cas Sélectionné :',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.initialSituation!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Suggestions Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _clinicalSuggestions.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final item = _clinicalSuggestions[i];
                      return ActionChip(
                        label: Text(item, style: const TextStyle(fontSize: 11.5)),
                        onPressed: _isLoading ? null : () => _askCopilot(item),
                        backgroundColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100,
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                if (_activeQuestionAsked.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Requête clinique : "$_activeQuestionAsked"',
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
                            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Gemini synthétise les recommandations et conduites à tenir...',
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
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.health_and_safety_rounded, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Text(
                              'Recommandations du Copilote Clinique :',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
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
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        'Posez une question sur un protocole d\'urgence, un dosage ou un cas pratique.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Input Bar
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Ex: Posologie amoxicilline dans la PAC chez l\'adulte...',
                      hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.healing_rounded, size: 18),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _askCopilot(val.trim());
                        _queryController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: _isLoading
                      ? null
                      : () {
                          final text = _queryController.text.trim();
                          if (text.isNotEmpty) {
                            _askCopilot(text);
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
