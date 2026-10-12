import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/medical_text_formatter.dart';
import '../../../core/widgets/medsina_logo.dart';

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

        // Gently scroll down so user immediately sees the beginning of the generated answer
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              80.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = 'Erreur lors de la communication avec MedsinaPilot: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    final sheetContent = Container(
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
                const MedsinaLogo.icon(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'MedsinaPilot • Clinique & Urgences',
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 10, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text(
                                  'medsina_ressources (Drive) • HAS / ESC / SFMU',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fermer',
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                            'MedsinaPilot synthétise les recommandations officielles et la conduite à tenir...',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_response != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.health_and_safety_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Recommandations & Protocole Clinique :',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copier tout le protocole',
                              color: const Color(0xFF2563EB),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _response!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Protocole copié dans le presse-papiers !'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        MarkdownBody(
                          data: MedicalTextFormatter.clean(_response!),
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                            ),
                            h1: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            ),
                            h2: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            ),
                            h3: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            listBullet: TextStyle(
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            listIndent: 22.0,
                            blockSpacing: 10.0,
                            blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            blockquoteDecoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(left: BorderSide(color: Color(0xFF2563EB), width: 4)),
                            ),
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
                const SizedBox(height: 24),
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

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: sheetContent,
        ),
      );
    }

    return sheetContent;
  }
}
