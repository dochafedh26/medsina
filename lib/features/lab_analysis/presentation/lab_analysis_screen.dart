import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/free_trial_quota_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai_assistant/presentation/clinical_copilot_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/lab_preset_model.dart';

class LabAnalysisScreen extends StatefulWidget {
  final String? initialLabText;
  final String? initialContext;
  final bool showAppBar;

  const LabAnalysisScreen({
    super.key,
    this.initialLabText,
    this.initialContext,
    this.showAppBar = true,
  });

  @override
  State<LabAnalysisScreen> createState() => _LabAnalysisScreenState();
}

class _LabAnalysisScreenState extends State<LabAnalysisScreen> {
  final TextEditingController _labTextController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedSex = 'Non précisé';
  bool _showPatientDetails = false;
  bool _isAnalyzing = false;
  String _analysisResult = '';
  StreamSubscription<String>? _streamSub;

  List<LabCalculatorResult> _liveCalculations = [];
  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    if (widget.initialLabText != null && widget.initialLabText!.isNotEmpty) {
      _labTextController.text = widget.initialLabText!;
    }
    if (widget.initialContext != null && widget.initialContext!.isNotEmpty) {
      _contextController.text = widget.initialContext!;
      _showPatientDetails = true;
    }
    _labTextController.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _labTextController.removeListener(_onTextChanged);
    _labTextController.dispose();
    _ageController.dispose();
    _contextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _labTextController.text;
    final calcs = LabAnalysisHelper.extractCalculations(text);
    setState(() {
      _liveCalculations = calcs;
    });
  }

  void _loadPreset(LabPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      _labTextController.text = preset.sampleText;
      if (preset.clinicalContext != null) {
        _contextController.text = preset.clinicalContext!;
        _showPatientDetails = true;
      }
      _analysisResult = '';
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _labTextController.text = data.text!;
        _selectedPresetId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bilan collé depuis le presse-papiers avec succès.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearAll() {
    setState(() {
      _labTextController.clear();
      _contextController.clear();
      _ageController.clear();
      _selectedSex = 'Non précisé';
      _selectedPresetId = null;
      _analysisResult = '';
      _isAnalyzing = false;
    });
    _streamSub?.cancel();
  }

  Future<void> _startAnalysis() async {
    final text = _labTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir ou coller des résultats biologiques à analyser.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final user = context.read<AuthBloc>().state.user;
    if (user?.tier == SubscriptionTier.free) {
      if (!FreeTrialQuotaService.instance.canAnalyzeLab(user)) {
        FreeTrialQuotaService.showQuotaLimitDialog(
          context,
          featureTitle: 'Limite Bilan Biologique Atteinte',
          message: 'Le Pass Découverte inclut 1 interprétation complète de bilan biologique gratuite. Pour continuer à analyser vos bilans et gazométries sans restriction, abonnez-vous à l\'un de nos plans.',
        );
        return;
      }
      FreeTrialQuotaService.instance.consumeLabAnalysis(user);
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = '';
    });

    _streamSub?.cancel();

    try {
      final stream = GeminiService.streamLabAnalysis(
        labData: text,
        patientAge: _ageController.text.trim(),
        patientSex: _selectedSex == 'Non précisé' ? null : _selectedSex,
        clinicalContext: _contextController.text.trim(),
      );

      final buffer = StringBuffer();
      _streamSub = stream.listen(
        (chunk) {
          buffer.write(chunk);
          if (mounted) {
            setState(() {
              _analysisResult = buffer.toString();
            });
            // Auto scroll down smoothly while streaming
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          }
        },
        onDone: () {
          if (mounted) setState(() => _isAnalyzing = false);
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              if (_analysisResult.isEmpty) {
                _analysisResult = '⚠️ **Erreur lors de l\'analyse** : $e\n\nVeuillez vérifier votre connexion ou réessayer.';
              }
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisResult = '⚠️ **Erreur** : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // 1. Header Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryTeal.withValues(alpha: 0.15),
                    AppTheme.accentCyan.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moteur d\'Interprétation Biologique Croisée',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Diagnostic syndromique, formules automatiques, seuils d\'urgence UMC & pièges résidanat.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. High-Yield Presets Chips
            const Text(
              '⚡ Cas Cliniques & Profils Fréquents :',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: LabAnalysisHelper.defaultPresets.map((preset) {
                  final isSelected = _selectedPresetId == preset.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        preset.title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      backgroundColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100,
                      selectedColor: AppTheme.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryTeal : Colors.grey.withValues(alpha: 0.25),
                        ),
                      ),
                      onSelected: (_) => _loadPreset(preset),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Patient Details Accordion (Optional)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _showPatientDetails = !_showPatientDetails),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: _showPatientDetails ? AppTheme.primaryTeal : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Détails du Patient (Optionnel)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _showPatientDetails ? AppTheme.primaryTeal : null,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showPatientDetails ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showPatientDetails) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Âge (ans)',
                                    hintText: 'ex: 45',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedSex,
                                  decoration: const InputDecoration(
                                    labelText: 'Sexe',
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Non précisé', child: Text('Non précisé')),
                                    DropdownMenuItem(value: 'Homme', child: Text('Homme ♂')),
                                    DropdownMenuItem(value: 'Femme', child: Text('Femme ♀')),
                                    DropdownMenuItem(value: 'Femme Enceinte', child: Text('Femme Enceinte 🤰')),
                                  ],
                                  onChanged: (val) => setState(() => _selectedSex = val ?? 'Non précisé'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _contextController,
                            decoration: const InputDecoration(
                              labelText: 'Motif d\'admission ou Antécédents',
                              hintText: 'ex: Diabétique sous insuline, dyspnée aiguë, anurie...',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Lab Input Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📝 Résultats Biologiques :',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 14),
                      label: const Text('Coller', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                    if (_labTextController.text.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 32),
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () => _labTextController.clear(),
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        label: const Text('Effacer', style: TextStyle(fontSize: 11.5)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _labTextController,
              maxLines: 8,
              minLines: 5,
              style: const TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Collez ou saisissez votre bilan biologique ici...\n'
                    'Exemple :\n'
                    'Na+ : 132 mmol/L\n'
                    'K+ : 5.8 mmol/L\n'
                    'Cl- : 96 mmol/L\n'
                    'HCO3- : 12 mmol/L\n'
                    'Glycémie : 3.8 g/L\n'
                    'Créatinine : 145 µmol/L',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // 5. Live Deterministic Calculation Chips
            if (_liveCalculations.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calculate_rounded, size: 16, color: AppTheme.primaryTeal),
                        SizedBox(width: 6),
                        Text(
                          'Calculs Automatiques Détectés en Temps Réel :',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primaryDarkTeal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _liveCalculations.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.isAlert
                                ? const Color(0xFFFEF2F2)
                                : (isDark ? AppTheme.darkSurface : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: c.isAlert ? const Color(0xFFEF4444) : Colors.grey.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.title,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: c.isAlert ? const Color(0xFF991B1B) : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${c.value} ${c.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: c.isAlert ? const Color(0xFFDC2626) : AppTheme.primaryDarkTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.interpretation,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: c.isAlert ? const Color(0xFFB91C1C) : Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 6. Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isAnalyzing ? null : _startAnalysis,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.psychology_rounded, size: 20),
                label: Text(
                  _isAnalyzing ? 'Analyse Biologique en Cours...' : 'Lancer l\'Interprétation Médicale Croisée ✨',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 7. Results View
            if (_isAnalyzing || _analysisResult.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assessment_rounded, color: AppTheme.primaryTeal, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Rapport d\'Analyse Clinique :',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ],
                  ),
                  if (_analysisResult.isNotEmpty)
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Copier le rapport',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _analysisResult));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rapport copié dans le presse-papiers.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Interroger le Copilote Gemini',
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                          onPressed: () {
                            ClinicalCopilotSheet.show(
                              context,
                              initialSituation:
                                  'Contexte Bilan Biologique :\n${_labTextController.text}\n\nSynthèse :\n${_analysisResult.length > 500 ? '${_analysisResult.substring(0, 500)}...' : _analysisResult}',
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Streaming Markdown Result Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _analysisResult.isEmpty && _isAnalyzing
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppTheme.primaryTeal),
                              SizedBox(height: 14),
                              Text(
                                'Analyse des paramètres, calcul des trou anionique/osmolaire et confrontation au référentiel...',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : MarkdownBody(
                        data: _analysisResult,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          h1: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.primaryDarkTeal),
                          h2: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryDarkTeal),
                          h3: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F766E)),
                          p: const TextStyle(fontSize: 12.8, height: 1.45),
                          listBullet: const TextStyle(fontSize: 13, color: AppTheme.primaryTeal),
                          strong: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
              const SizedBox(height: 14),

              // Copilot Follow-up Banner
              if (_analysisResult.isNotEmpty && !_isAnalyzing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Une question spécifique sur ce bilan ? Discutez-en en direct avec le Copilote.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          ClinicalCopilotSheet.show(
                            context,
                            initialSituation:
                                'Bilan Analysé :\n${_labTextController.text}\n\nQuestions sur l\'attitude pratique et les posologies.',
                          );
                        },
                        child: const Text('Copilote ✨', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.biotech_rounded, color: AppTheme.primaryTeal, size: 24),
            SizedBox(width: 8),
            Text(
              'Analyseur de Bilan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (_labTextController.text.isNotEmpty || _analysisResult.isNotEmpty)
            IconButton(
              tooltip: 'Réinitialiser',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: content,
    );
  }
}
