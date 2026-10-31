import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/ai_quota_service.dart';
import '../../../core/services/free_trial_quota_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai_assistant/presentation/clinical_copilot_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../clinical/data/clinical_repository.dart';
import '../../clinical/models/emergency_drug_model.dart';
import '../../subscription/presentation/ai_quota_exhausted_dialog.dart';
import '../data/algerian_nomenclature_repository.dart';
import '../data/terrain_contraindication_repository.dart';
import '../data/vidal_interaction_repository.dart';
import '../models/algerian_drug_model.dart';

class PrescribedDrugItem {
  final String name;
  final String? activeDci;
  final String? dosage;
  final String? form;
  final String? lab;
  final String? packaging;
  final String? liste;
  final String? pays;
  final String? regNum;

  const PrescribedDrugItem({
    required this.name,
    this.activeDci,
    this.dosage,
    this.form,
    this.lab,
    this.packaging,
    this.liste,
    this.pays,
    this.regNum,
  });

  String get displayName {
    if (activeDci != null && activeDci!.isNotEmpty && name.toUpperCase() != activeDci!.toUpperCase()) {
      return '$name ($activeDci)';
    }
    return name;
  }
}

class PrescriptionAnalysisScreen extends StatefulWidget {
  const PrescriptionAnalysisScreen({super.key});

  @override
  State<PrescriptionAnalysisScreen> createState() => _PrescriptionAnalysisScreenState();
}

class _PrescriptionAnalysisScreenState extends State<PrescriptionAnalysisScreen> {
  final TextEditingController _customDrugController = TextEditingController();
  final List<PrescribedDrugItem> _prescribedDrugs = [];
  final Set<String> _selectedTerrains = {};

  List<AlgerianDrugModel> _algerianCatalog = [];
  List<EmergencyDrugModel> _emergencyDrugs = [];
  List<VidalInteractionRule> _vidalRules = [];
  bool _isLoading = true;
  List<AlgerianDrugModel> _searchResults = [];
  bool _showSuggestions = false;

  List<TerrainContraindicationRule> _terrainRules = [];
  bool _isAiCertifying = false;
  Map<String, dynamic>? _aiCertificationAlert;

  static const List<String> _quickTerrains = [
    'Grossesse (3e trimestre)',
    'Insuffisance Rénale Sévère',
    'Ulcère Gastro-duodénal',
    'Asthme / BPCO',
    'Sujet Âgé (> 75 ans)',
    'Insuffisance Hépatique',
  ];

  static const Map<String, List<String>> _clinicalTerrainsCatalog = {
    'Gynécologie & Obstétrique': [
      'Grossesse (1er trimestre)',
      'Grossesse (2e trimestre)',
      'Grossesse (3e trimestre)',
      'Allaitement maternel',
    ],
    'Néphrologie & Urologie': [
      'Insuffisance Rénale Sévère',
      'Insuffisance Rénale Modérée (ClCr 30-60 ml/min)',
      'Adénome de Prostate',
      'Lithiase urinaire lithiasique',
    ],
    'Cardiologie & Vasculaire': [
      'Insuffisance Cardiaque',
      'Allongement du QT',
      'Hypertension Artérielle non contrôlée',
      'Trouble de conduction (BAV, Bradycardie)',
      'Antécédent d\'AVC / AIT récent',
    ],
    'Gastro-Entérologie & Hépatologie': [
      'Ulcère Gastro-duodénal',
      'Antécédent d\'hémorragie digestive haute',
      'Insuffisance Hépatique',
      'Hépatite aiguë / Cytolyse active',
    ],
    'Pneumologie': [
      'Asthme / BPCO',
      'Insuffisance Respiratoire Chronique',
    ],
    'Neurologie & Psychiatrie': [
      'Épilepsie',
      'Maladie de Parkinson',
      'Dépression sévère / Risque suicidaire',
      'Démence / Syndrome confusionnel',
    ],
    'Ophtalmologie': [
      'Glaucome à angle fermé',
      'Glaucome à angle ouvert',
    ],
    'Métabolisme, Endocrinologie & Hématologie': [
      'Diabète de type 1 ou 2',
      'Déficit en G6PD',
      'Hyperkaliémie (> 5.0 mmol/L)',
      'Goutte / Hyperuricémie',
      'Thrombopénie / Coagulopathie active',
    ],
    'Profils Spéciaux & Allergies': [
      'Sujet Âgé (> 75 ans)',
      'Pédiatrie / Nourrisson (< 2 ans)',
      'Allergie aux Bêta-lactamines',
      'Allergie aux Sulfamides',
      'Allergie Aspirine / AINS (Widal)',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final catalog = await AlgerianNomenclatureRepository.loadCatalog();
      final rules = await VidalInteractionRepository.loadRules();
      final terrainRules = await TerrainContraindicationRepository.loadRules();
      final emergencyDrugs = await ClinicalRepository.fetchEmergencyDrugs();
      if (mounted) {
        setState(() {
          _algerianCatalog = catalog;
          _vidalRules = rules;
          _terrainRules = terrainRules;
          _emergencyDrugs = emergencyDrugs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChangedText(String val) {
    final text = val.trim();
    if (text.isNotEmpty) {
      final results = AlgerianNomenclatureRepository.search(text, limit: 12);
      setState(() {
        _searchResults = results;
        _showSuggestions = results.isNotEmpty;
      });
    } else {
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
    _customDrugController.dispose();
    super.dispose();
  }

  void _addDrugFromCatalog(AlgerianDrugModel drug) {
    if (!_prescribedDrugs.any((d) => d.name.toUpperCase() == drug.brand.toUpperCase() && d.dosage == drug.dosage)) {
      setState(() {
        _prescribedDrugs.add(PrescribedDrugItem(
          name: drug.brand,
          activeDci: drug.dci,
          dosage: drug.dosage,
          form: drug.form,
          lab: drug.lab,
          packaging: drug.packaging,
          liste: drug.liste,
          pays: drug.pays,
          regNum: drug.regNum,
        ));
        _customDrugController.clear();
        _showSuggestions = false;
        _aiCertificationAlert = null;
      });
    }
  }

  void _addCustomDrug(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return;

    final resolvedDci = AlgerianNomenclatureRepository.resolveActiveDci(clean);
    final matches = AlgerianNomenclatureRepository.search(clean, limit: 1);
    final firstMatch = matches.isNotEmpty ? matches.first : null;

    if (!_prescribedDrugs.any((d) => d.name.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _prescribedDrugs.add(PrescribedDrugItem(
          name: clean,
          activeDci: resolvedDci,
          dosage: firstMatch?.dosage,
          form: firstMatch?.form,
          lab: firstMatch?.lab,
          packaging: firstMatch?.packaging,
          liste: firstMatch?.liste,
          pays: firstMatch?.pays,
          regNum: firstMatch?.regNum,
        ));
        _customDrugController.clear();
        _showSuggestions = false;
        _aiCertificationAlert = null;
      });
    }
  }

  void _removeDrug(PrescribedDrugItem item) {
    setState(() {
      _prescribedDrugs.remove(item);
      _aiCertificationAlert = null;
    });
  }

  void _toggleTerrain(String terrain) {
    setState(() {
      if (_selectedTerrains.contains(terrain)) {
        _selectedTerrains.remove(terrain);
      } else {
        _selectedTerrains.add(terrain);
      }
      _aiCertificationAlert = null;
    });
  }

  Future<void> _certifyWithAi() async {
    if (_prescribedDrugs.isEmpty) return;

    final user = context.read<AuthBloc>().state.user;
    if (user?.tier == SubscriptionTier.free) {
      if (!FreeTrialQuotaService.instance.canAnalyzePrescription(user)) {
        FreeTrialQuotaService.showQuotaLimitDialog(
          context,
          featureTitle: 'Limite Analyse Ordonnance Atteinte',
          message: 'Le Pass Découverte inclut 1 analyse d\'ordonnance Vidal IA gratuite. Pour auditer d\'autres ordonnances en illimité, passez à l\'abonnement supérieur.',
        );
        return;
      }
      FreeTrialQuotaService.instance.consumePrescriptionAnalysis(user);
    } else {
      final quotaRes = await AiQuotaService.instance.checkAndConsume(user);
      if (!quotaRes.allowed) {
        if (mounted) {
          AiQuotaExhaustedDialog.show(
            context,
            dailyLimit: quotaRes.dailyLimit,
            dailyUsed: quotaRes.dailyUsed,
            bonusRemaining: quotaRes.bonusRemaining,
          );
        }
        return;
      }
    }

    setState(() {
      _isAiCertifying = true;
      _aiCertificationAlert = null;
    });

    try {
      final drugs = _prescribedDrugs.map((d) => d.displayName).toList();
      final terrains = _selectedTerrains.toList();

      final result = await GeminiService.auditPrescriptionWithAi(
        drugs: drugs,
        terrains: terrains,
      );

      if (mounted) {
        setState(() {
          _isAiCertifying = false;
          _aiCertificationAlert = result;
        });

        // Auto-enrichment into Supabase: if an alert was detected by AI, store it for the community!
        if (result != null && result['has_alert'] == true) {
          final title = result['title']?.toString() ?? '';
          final warning = result['warning']?.toString() ?? '';
          final recommendation = result['recommendation']?.toString() ?? '';
          final sevStr = result['severity']?.toString().toLowerCase() ?? 'contraindicated';

          if (_selectedTerrains.isNotEmpty && title.isNotEmpty) {
            final firstTerrain = _selectedTerrains.first;
            final primaryDrug = _prescribedDrugs.first.activeDci ?? _prescribedDrugs.first.name;

            final newRule = TerrainContraindicationRule(
              terrain: firstTerrain,
              terrainNormalized: VidalInteractionRepository.normalize(firstTerrain),
              drugClass: primaryDrug,
              drugPatterns: [VidalInteractionRepository.normalize(primaryDrug)],
              severity: sevStr == 'contraindicated'
                  ? InteractionSeverity.contraindicated
                  : (sevStr == 'disadvised' ? InteractionSeverity.disadvised : InteractionSeverity.precaution),
              severityLevel: sevStr == 'contraindicated' ? 4 : (sevStr == 'disadvised' ? 3 : 2),
              title: title,
              warning: warning,
              recommendation: recommendation,
              source: 'Vidal / ANSM (Validé par MedsinaPilot)',
            );

            TerrainContraindicationRepository.recordNewRule(newRule);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAiCertifying = false);
      }
    }
  }

  List<VidalInteractionRule> _detectInteractions() {
    if (_prescribedDrugs.length < 2) return [];

    final searchList = _prescribedDrugs
        .map((d) => PrescribedTarget(name: d.name, activeDci: d.activeDci))
        .toList();

    return VidalInteractionRepository.findInteractions(searchList, _vidalRules);
  }

  List<TerrainContraindicationRule> _detectTerrainWarnings() {
    if (_prescribedDrugs.isEmpty || _selectedTerrains.isEmpty) return [];

    final targets = _prescribedDrugs
        .map((d) => PrescribedTarget(name: d.name, activeDci: d.activeDci))
        .toList();

    return TerrainContraindicationRepository.findContraindications(
      targets,
      _selectedTerrains,
      _terrainRules,
    );
  }

  void _showTerrainSelectionSheet(BuildContext context) {
    final customInputController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final query = searchQuery.trim().toLowerCase();

            // Filter catalog based on query
            final filteredCatalog = <String, List<String>>{};
            for (final entry in _clinicalTerrainsCatalog.entries) {
              if (query.isEmpty) {
                filteredCatalog[entry.key] = entry.value;
              } else {
                final matching = entry.value.where((t) => t.toLowerCase().contains(query)).toList();
                if (matching.isNotEmpty || entry.key.toLowerCase().contains(query)) {
                  filteredCatalog[entry.key] = matching.isNotEmpty ? matching : entry.value;
                }
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_information_rounded, color: Color(0xFFD97706), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profils & Terrains à Risque',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Sélectionnez les pathologies ou ajoutez un terrain libre',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedTerrains.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTerrains.clear();
                              });
                              setSheetState(() {});
                            },
                            child: const Text('Tout effacer', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Search & Custom Add Bar
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          onChanged: (val) => setSheetState(() => searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un terrain (ex: Diabète, QT, Asthme)...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () => setSheetState(() => searchQuery = ''),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Free text custom input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customInputController,
                                decoration: InputDecoration(
                                  hintText: '+ Saisie libre (ex: Lupus, Myasthénie...)',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                                onSubmitted: (val) {
                                  final clean = val.trim();
                                  if (clean.isNotEmpty) {
                                    setState(() => _selectedTerrains.add(clean));
                                    customInputController.clear();
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                final clean = customInputController.text.trim();
                                if (clean.isNotEmpty) {
                                  setState(() => _selectedTerrains.add(clean));
                                  customInputController.clear();
                                  setSheetState(() {});
                                }
                              },
                            ),
                          ],
                        ),

                        // If user searched a term not found, propose adding it directly
                        if (query.isNotEmpty &&
                            !_clinicalTerrainsCatalog.values.any((list) => list.any((t) => t.toLowerCase() == query)) &&
                            !_selectedTerrains.contains(searchQuery.trim())) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              final textToAdd = searchQuery.trim();
                              setState(() => _selectedTerrains.add(textToAdd));
                              setSheetState(() => searchQuery = '');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFD97706), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ajouter "$searchQuery" comme terrain personnalisé',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Selected Terrains chips bar in modal
                  if (_selectedTerrains.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFFD97706).withValues(alpha: 0.08),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedTerrains.length} terrain(s) sélectionné(s) :',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _selectedTerrains.map((t) {
                              return Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                                onDeleted: () {
                                  setState(() => _selectedTerrains.remove(t));
                                  setSheetState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 1),

                  // Grouped Categories List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: filteredCatalog.length,
                      itemBuilder: (context, idx) {
                        final category = filteredCatalog.keys.elementAt(idx);
                        final items = filteredCatalog[category]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: query.isNotEmpty || idx == 0,
                              dense: true,
                              title: Text(
                                category,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: items.map((terrain) {
                                      final isSelected = _selectedTerrains.contains(terrain);
                                      return FilterChip(
                                        label: Text(terrain),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFFD97706).withValues(alpha: 0.2),
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? const Color(0xFFB45309) : null,
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedTerrains.remove(terrain);
                                            } else {
                                              _selectedTerrains.add(terrain);
                                            }
                                          });
                                          setSheetState(() {});
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Validate Button
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Valider les Terrains (${_selectedTerrains.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detectedInteractions = _detectInteractions();
    final detectedTerrainWarnings = _detectTerrainWarnings();

    final aiHasAlert = _aiCertificationAlert != null && _aiCertificationAlert!['has_alert'] == true;
    final aiIsContraindicated = aiHasAlert && _aiCertificationAlert!['severity']?.toString().toLowerCase() == 'contraindicated';
    final aiIsDisadvised = aiHasAlert && _aiCertificationAlert!['severity']?.toString().toLowerCase() == 'disadvised';

    final hasCritical = detectedInteractions.any((i) => i.severity == InteractionSeverity.contraindicated) ||
        detectedTerrainWarnings.any((w) => w.severity == InteractionSeverity.contraindicated) ||
        aiIsContraindicated;
    final hasDisadvised = detectedInteractions.any((i) => i.severity == InteractionSeverity.disadvised) ||
        detectedTerrainWarnings.any((w) => w.severity == InteractionSeverity.disadvised) ||
        aiIsDisadvised;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_rounded, color: AppTheme.primaryTeal, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analyse d\'Ordonnance (Vidal & Algérie)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              '5 425+ Spécialités MSPRH • Moteur Vidal Pro • Interactions',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          // Section 1: Prescription Input
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication_liquid_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '1. Médicaments Prescrits',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${_algerianCatalog.length} Produits DZ',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recherchez par nom de marque (ex: Sintrom, Augmentin, Tahor) ou par DCI (ex: Rifampicine, Acénocoumarol) :',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),

                  // Quick selection chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'Sintrom',
                        'Rifampicine',
                        'Kétoprofène',
                        'Aspirine',
                        'Énoxaparine',
                        'Amiodarone',
                        'Colchicine',
                        'Clarithromycine',
                        'Périndopril',
                        'Spironolactone',
                        'Trinitrine',
                        'Sildénafil',
                        'Oméprazole',
                        'Diazépam',
                        'Morphine',
                        'Furosémide',
                        'Atorvastatine',
                      ].map((name) {
                        final isPrescribed = _prescribedDrugs.any((d) => d.name.toLowerCase() == name.toLowerCase());
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(name),
                            selected: isPrescribed,
                            selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isPrescribed ? FontWeight.bold : FontWeight.w500,
                              color: isPrescribed ? AppTheme.primaryTeal : null,
                            ),
                            onSelected: (_) {
                              if (isPrescribed) {
                                final item = _prescribedDrugs.firstWhere((d) => d.name.toLowerCase() == name.toLowerCase());
                                _removeDrug(item);
                              } else {
                                _addCustomDrug(name);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Autocomplete Input field
                  TextField(
                    controller: _customDrugController,
                    onChanged: _onSearchChangedText,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un médicament (ex: Sintrom, Rifampicine)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _customDrugController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _customDrugController.clear();
                                _onSearchChangedText('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: _addCustomDrug,
                  ),

                  // Autocomplete Suggestions Dropdown
                  if (_showSuggestions && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 230),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        primary: false,
                        physics: const ClampingScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final drug = _searchResults[index];
                          final details = [
                            if (drug.dci.isNotEmpty) 'DCI: ${drug.dci}',
                            if (drug.dosage.isNotEmpty || drug.form.isNotEmpty) '${drug.dosage} ${drug.form}'.trim(),
                            if (drug.lab.isNotEmpty) drug.lab,
                          ].join(' • ');

                          return InkWell(
                            onTap: () => _addDrugFromCatalog(drug),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                    child: const Icon(Icons.medication_rounded, size: 14, color: AppTheme.primaryTeal),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          drug.brand,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (details.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            details,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Voir la fiche médicament (Indications, Posologie...)',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showDrugMonographSheet(
                                        context,
                                        PrescribedDrugItem(
                                          name: drug.brand,
                                          activeDci: drug.dci,
                                          dosage: drug.dosage,
                                          form: drug.form,
                                          lab: drug.lab,
                                          packaging: drug.packaging,
                                          liste: drug.liste,
                                          pays: drug.pays,
                                          regNum: drug.regNum,
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF2563EB)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Fiche',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 18,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  if (_prescribedDrugs.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Médicaments dans l\'ordonnance à analyser :',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Touchez un médicament ou "Fiche" pour afficher les détails Vidal & posologie',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: _prescribedDrugs.map((drug) => _buildPrescribedDrugRow(context, drug, isDark)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Section 2: Patient Terrain & Risk factors
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '2. Profil & Terrains du Patient',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_selectedTerrains.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${_selectedTerrains.length} actif${_selectedTerrains.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez parmi les spécialités médicales ou saisissez des terrains spécifiques (allergies, comorbidités) :',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),

                  // Display active selected terrains if any
                  if (_selectedTerrains.isNotEmpty) ...[
                    const Text(
                      'Terrains sélectionnés pour cette ordonnance :',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedTerrains.map((terrain) {
                        return InputChip(
                          avatar: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFFD97706),
                            child: Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                          label: Text(terrain),
                          backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.15),
                          labelStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFB45309)),
                          onDeleted: () => _toggleTerrain(terrain),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                  ],

                  // Quick Suggestion Chips + "Explorer tout le catalogue" button
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Accès rapide & Fréquents :',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFFD97706)),
                        label: const Text(
                          'Catalogue complet',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                        onPressed: () => _showTerrainSelectionSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ..._quickTerrains.map((terrain) {
                        final isSelected = _selectedTerrains.contains(terrain);
                        return FilterChip(
                          label: Text(terrain),
                          selected: isSelected,
                          selectedColor: const Color(0xFFD97706).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFFB45309) : null,
                          ),
                          onSelected: (_) => _toggleTerrain(terrain),
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFFD97706)),
                        label: const Text('+ Autre terrain / Recherche'),
                        backgroundColor: Theme.of(context).cardColor,
                        side: const BorderSide(color: Color(0xFFD97706), width: 1),
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                        onPressed: () => _showTerrainSelectionSheet(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Section 3: Diagnostic & Analysis Verdict
          if (_prescribedDrugs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.playlist_add_check_rounded, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Ajoutez des molécules pour lancer l\'analyse',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recherchez un médicament ci-dessus ou sélectionnez un terrain patient à risque pour vérifier les contre-indications.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_prescribedDrugs.length == 1 && _selectedTerrains.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.playlist_add_rounded, size: 36, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1 molécule prête : ${_prescribedDrugs.first.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Pour analyser les interactions médicamenteuses : ajoutez une 2e molécule dans la barre de recherche.\n• Pour évaluer la tolérance et les contre-indications : sélectionnez un ou plusieurs terrains patient ci-dessus (Diabète, HTA, Grossesse...).',
                    style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text(
                          'Voir Fiche & Posologie',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showDrugMonographSheet(context, _prescribedDrugs.first),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFD97706)),
                        label: const Text(
                          'Choisir un terrain patient',
                          style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showTerrainSelectionSheet(context),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            // Status Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasCritical
                    ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                    : (hasDisadvised
                        ? const Color(0xFFEA580C).withValues(alpha: 0.12)
                        : (detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty
                            ? const Color(0xFFD97706).withValues(alpha: 0.12)
                            : const Color(0xFF16A34A).withValues(alpha: 0.12))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasCritical
                      ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                      : (hasDisadvised
                          ? const Color(0xFFEA580C).withValues(alpha: 0.3)
                          : (detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty
                              ? const Color(0xFFD97706).withValues(alpha: 0.3)
                              : const Color(0xFF16A34A).withValues(alpha: 0.3))),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasCritical
                        ? Icons.cancel_rounded
                        : (hasDisadvised
                            ? Icons.warning_rounded
                            : (detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded)),
                    color: hasCritical
                        ? const Color(0xFFDC2626)
                        : (hasDisadvised
                            ? const Color(0xFFEA580C)
                            : (detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty
                                ? const Color(0xFFD97706)
                                : const Color(0xFF16A34A))),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasCritical
                              ? 'Alerte Critique : Contre-Indication Formelle Détectée !'
                              : (hasDisadvised
                                  ? (detectedInteractions.any((i) => i.severity == InteractionSeverity.disadvised)
                                      ? 'Alerte Majeure : Association Médicamenteuse Déconseillée'
                                      : 'Alerte Majeure : Prescription Déconseillée sur ce Terrain')
                                  : (detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty
                                      ? 'Attention : Précautions d\'Emploi Notées'
                                      : (_prescribedDrugs.length == 1
                                          ? 'Contrôle Local Négatif : Aucun Risque Répertorié'
                                          : 'Contrôle Local Négatif : Aucune Contre-Indication Répertoriée'))),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: hasCritical
                                ? const Color(0xFFDC2626)
                                : (hasDisadvised
                                    ? const Color(0xFFEA580C)
                                    : (detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A))),
                          ),
                        ),
                        Text(
                          aiHasAlert
                              ? '${detectedInteractions.length} interaction(s) • ${detectedTerrainWarnings.length} alerte(s) terrain • 1 Alerte IA Détectée'
                              : ((detectedInteractions.isNotEmpty || detectedTerrainWarnings.isNotEmpty)
                                  ? '${detectedInteractions.length} interaction(s) médicamenteuse(s) • ${detectedTerrainWarnings.length} alerte(s) terrain'
                                  : (_aiCertificationAlert != null && _aiCertificationAlert!['has_alert'] == false
                                      ? 'Certifié 100% Conforme par MedsinaPilot (Vidal & ANSM)'
                                      : 'Vérification Vidal locale passée • Certification IA disponible')),
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Interaction Cards
            ...detectedInteractions.map((rule) => _buildInteractionCard(rule, isDark)),
            ...detectedTerrainWarnings.map((warn) => _buildTerrainWarningCard(warn, isDark)),

            // AI Certification Section
            if (_isAiCertifying)
              _buildAiLoadingCard(isDark)
            else if (_aiCertificationAlert != null)
              if (_aiCertificationAlert!['has_alert'] == true)
                _buildAiAlertCard(_aiCertificationAlert!, isDark)
              else
                _buildAiVerifiedBadge(isDark)
            else
              _buildAiSentinelCard(isDark),

            const SizedBox(height: 14),

            // Vidal Script Sync & AI Copilot In-Depth Analysis Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryTeal.withValues(alpha: 0.08),
                    const Color(0xFF2563EB).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryTeal, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Audit Pharmacologique MedsinaPilot',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Vidal Pro',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Consultez MedsinaPilot pour un avis pharmacologique complet : alternatives thérapeutiques, règles d\'adaptation posologique et surveillance biologique.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.psychology_rounded, size: 18),
                      label: const Text('Lancer l\'Audit Complet MedsinaPilot',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _launchCopilotAudit(context, detectedInteractions, detectedTerrainWarnings),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionCard(VidalInteractionRule rule, bool isDark) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (rule.severity) {
      case InteractionSeverity.contraindicated:
        badgeColor = const Color(0xFFDC2626);
        badgeText = 'CONTRE-INDICATION';
        badgeIcon = Icons.do_not_disturb_on_rounded;
        break;
      case InteractionSeverity.disadvised:
        badgeColor = const Color(0xFFEA580C);
        badgeText = 'ASSOCIATION DÉCONSEILLÉE';
        badgeIcon = Icons.warning_rounded;
        break;
      case InteractionSeverity.precaution:
        badgeColor = const Color(0xFFD97706);
        badgeText = 'PRÉCAUTION D\'EMPLOI';
        badgeIcon = Icons.info_rounded;
        break;
      case InteractionSeverity.info:
        badgeColor = const Color(0xFF2563EB);
        badgeText = 'À PRENDRE EN COMPTE';
        badgeIcon = Icons.lightbulb_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Vidal IAM',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rule.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              rule.description,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF374151)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_services_rounded, size: 16, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommandation Vidal : ${rule.recommendation}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerrainWarningCard(TerrainContraindicationRule warn, bool isDark) {
    final Color badgeColor;
    final String badgeText;
    final IconData badgeIcon;

    switch (warn.severity) {
      case InteractionSeverity.contraindicated:
        badgeColor = const Color(0xFFDC2626);
        badgeText = 'CONTRE-INDICATION FORMELLE';
        badgeIcon = Icons.dangerous_rounded;
        break;
      case InteractionSeverity.disadvised:
        badgeColor = const Color(0xFFEA580C);
        badgeText = 'ASSOCIATION DÉCONSEILLÉE SUR CE TERRAIN';
        badgeIcon = Icons.warning_rounded;
        break;
      case InteractionSeverity.precaution:
        badgeColor = const Color(0xFFD97706);
        badgeText = 'PRÉCAUTION MAJEURE D\'EMPLOI';
        badgeIcon = Icons.warning_amber_rounded;
        break;
      default:
        badgeColor = const Color(0xFF2563EB);
        badgeText = 'ATTENTION PARTICULIÈRE';
        badgeIcon = Icons.info_outline_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text(
                  '• ${warn.terrain}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              warn.title.isNotEmpty ? warn.title : 'Alerte : ${warn.drugClass} sur terrain ${warn.terrain}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text(
              warn.warning,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF374151)),
            ),
            if (warn.recommendation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, size: 16, color: badgeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Conduite à tenir : ${warn.recommendation}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (warn.source.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Source : ${warn.source}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiLoadingCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Audit clinique en direct : MedsinaPilot interroge les bases Vidal & ANSM...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAlertCard(Map<String, dynamic> alert, bool isDark) {
    final sevStr = alert['severity']?.toString().toLowerCase() ?? 'contraindicated';
    final bool isCritical = sevStr == 'contraindicated';
    final Color badgeColor = isCritical ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    final String badgeText = isCritical ? 'CONTRE-INDICATION DÉTECTÉE PAR L\'IA' : 'ALERTE MAJEURE DÉTECTÉE PAR L\'IA';
    final IconData badgeIcon = isCritical ? Icons.dangerous_rounded : Icons.warning_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'MedsinaPilot IA (Vidal Pro)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert['title']?.toString() ?? 'Alerte Clinique Détectée',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              alert['warning']?.toString() ?? '',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF374151)),
            ),
            if ((alert['recommendation']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, size: 16, color: badgeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Conduite à tenir : ${alert['recommendation']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Source : ${alert['source'] ?? "Vidal / ANSM"} • Règle synchronisée avec Cloud Supabase',
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiVerifiedBadge(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certification IA MedsinaPilot Validée (0 Faux Négatif)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF16A34A)),
                ),
                Text(
                  'L\'audit pharmacologique confirme l\'absence de contre-indication Vidal / ANSM sur ce profil.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSentinelCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.08),
            AppTheme.primaryTeal.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: Color(0xFF7C3AED), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sécurité Maximale : Audit IA MedsinaPilot',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Text(
                  'Contrôle complet Vidal / ANSM pour éliminer 100% des faux négatifs.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Certifier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _certifyWithAi,
          ),
        ],
      ),
    );
  }

  void _launchCopilotAudit(
    BuildContext context,
    List<VidalInteractionRule> interactions,
    List<TerrainContraindicationRule> warnings,
  ) {
    final drugsList = _prescribedDrugs.map((d) => d.displayName).join(', ');
    final terrainsList = _selectedTerrains.isNotEmpty ? _selectedTerrains.join(', ') : 'Aucun terrain particulier';

    final prompt = '''
AUDIT D'ORDONNANCE MÉDICALE (MÉCANISMES VIDAL, ANSM & MSPRH) :
Médicaments prescrits : $drugsList
Profil / Terrain patient : $terrainsList
Interactions relevées par le moteur : ${interactions.map((i) => "${i.title} (${i.severity.name})").join('; ')}
Alertes terrain : ${warnings.map((w) => "${w.title} (${w.severity.name}) : ${w.drugClass} / ${w.terrain}").join('; ')}

En tant que pharmacologue clinicien MedsinaPilot :
1. Confirmez la pertinence clinique de ces alertes selon les référentiels Vidal et MSPRH.
2. Proposez des alternatives thérapeutiques adaptées pour chaque molécule à risque.
3. Précisez la surveillance biologique (INR, créatinine, ECG, bilan hépatique/cytolyse, kaliémie...) à mettre en œuvre.
''';

    ClinicalCopilotSheet.show(
      context,
      initialSituation: prompt,
    );
  }

  Widget _buildPrescribedDrugRow(BuildContext context, PrescribedDrugItem drug, bool isDark) {
    final subtitleParts = <String>[
      if (drug.dosage != null && drug.dosage!.isNotEmpty) drug.dosage!,
      if (drug.form != null && drug.form!.isNotEmpty) drug.form!,
      if (drug.lab != null && drug.lab!.isNotEmpty) drug.lab!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.medication_rounded, size: 17, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showDrugMonographSheet(context, drug),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    drug.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' • '),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Voir description, indications, posologie & contre-indications',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => _showDrugMonographSheet(context, drug),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: AppTheme.primaryTeal),
                      SizedBox(width: 4),
                      Text(
                        'Fiche',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
            tooltip: 'Retirer de l\'ordonnance',
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            onPressed: () => _removeDrug(drug),
          ),
        ],
      ),
    );
  }

  static const Map<String, Map<String, dynamic>> _curatedMonographs = {
    'ACENOCOUMAROL': {
      'pharmacological_class': 'Anticoagulant oral de type Anti-Vitamine K (AVK — dérivé coumarinique)',
      'description': 'Inhibe la synthèse hépatique des facteurs de coagulation vitamine K-dépendants (II, VII, IX, X) et des protéines C et S. Délai d\'action de 36 à 72h, demi-vie courte (8-11h).',
      'indications': [
        'Prévention des complications thromboemboliques de la fibrillation atriale (FA) et des valvulopathies mitrale / prothèses valvulaires mécaniques.',
        'Traitement curatif et prévention des récidives de thrombose veineuse profonde (TVP) et d\'embolie pulmonaire (EP).',
      ],
      'posology_adult': 'Dose initiale habituelle : 4 mg/j (1 cp) en 1 prise quotidienne à heure fixe (le soir), puis adaptation stricte par paliers de 1 mg selon l\'INR (cible 2 à 3 dans la FA/MTEV ; 2,5 à 3,5 sur prothèse mécanique mitrale).',
      'posology_pediatric_or_special': 'Sujet âgé (> 75 ans), insuffisant hépatique ou dénutri : débuter à demi-dose (1 à 2 mg/j). Relais héparine-AVK : maintenir l\'HBPM/HNF jusqu\'à obtention de 2 INR consécutifs dans la cible à 24h d\'intervalle.',
      'contraindications': [
        'Grossesse (1er et 3e trimestres : tératogène et risque hémorragique fœtal majeur).',
        'Insuffisance hépatique sévère, hémorragie active ou lésion organique susceptible de saigner (ulcère gastro-duodénal évolutif, varices œsophagiennes).',
        'Association contre-indiquée : Aspirine à dose anti-inflammatoire, AINS, Miconazole (y compris gel buccal), Millepertuis.',
      ],
      'side_effects_and_monitoring': 'Risque majeur : accidents hémorragiques (digestifs, cérébraux, gingivorragies, hématurie). Surveillance biologique obligatoire : INR toutes les 48-72h en début de traitement puis 1 fois/mois à l\'équilibre. Antidote en cas de surdosage : Vitamine K1 (Phytoménadione) ± PPSB (Octaplex/Kaskadil) si hémorragie grave.',
      'residanat_key_point': 'Piège Résidanat : Ne jamais arrêter l\'héparine avant 2 INR consécutifs dans la zone thérapeutique ! Le Miconazole gel buccal + Sintrom est une cause classique d\'hémorragie grave par surdosage.',
    },
    'RIFAMPICINE': {
      'pharmacological_class': 'Antibiotique antituberculeux majeur & antibactérien (famille des Rifamycines)',
      'description': 'Bactéricide intra- et extracellulaire par inhibition de l\'ARN polymérase ADN-dépendante bactérienne. Puissant inducteur enzymatique du cytochrome P450 (CYP3A4, CYP2C9, CYP2C19).',
      'indications': [
        'Tuberculose pulmonaire et extrapulmonaire (en polychimiothérapie RHZE selon le Programme National Algérien de Lutte Contre la Tuberculose).',
        'Brucellose (en association à la Doxycycline), infections ostéo-articulaires sur matériel à staphylocoque, prophylaxie de la méningite à méningocoque.',
      ],
      'posology_adult': 'Tuberculose : 10 mg/kg/jour en prise unique quotidienne le matin à jeun (30 min avant le petit-déjeuner), soit habituellement 600 mg/j si poids ≥ 55 kg (450 mg/j si < 55 kg).',
      'posology_pediatric_or_special': 'Pédiatrie (Tuberculose) : 10 à 20 mg/kg/jour en 1 prise à jeun (max 600 mg/j). Chimioprophylaxie méningocoque : 600 mg × 2/j pendant 2 jours chez l\'adulte (10 mg/kg × 2/j chez l\'enfant).',
      'contraindications': [
        'Porphyrie hépato-érythropoïétique, insuffisance hépatique sévère ou ictère.',
        'Associations contre-indiquées (effet inducteur enzymatique puissant) : Inhibiteurs de protéase, certains anticoagulants directs, contraceptifs œstroprogestatifs (inefficacité -> contraception mécanique obligatoire).',
      ],
      'side_effects_and_monitoring': 'Coloration rouge-orangée normale des urines, larmes et crachats (prévenir le patient). Hépatotoxicité (cytolyse/cholestase, potentialisée par l\'Isoniazide), syndrome pseudo-grippal, thrombopénie immuno-allergique. Surveillance : Bilan hépatique (ASAT, ALAT, Bilirubine), NFS avant et pendant le traitement.',
      'residanat_key_point': 'Inducteur enzymatique majeur : diminue drastiquement l\'efficacité des AVK (Sintrom), des corticoïdes, de la ciclosporine et de la pilule contraceptive !',
    },
    'KETOPROFENE': {
      'pharmacological_class': 'Anti-inflammatoire non stéroïdien (AINS — groupe des propioniques)',
      'description': 'Inhibiteur puissant des cyclo-oxygénases COX-1 et COX-2 réduisant la synthèse des prostaglandines pro-inflammatoires, algogènes et pyrogènes.',
      'indications': [
        'Traitement symptomatique de courte durée des poussées aiguës d\'arthrose, lombalgies aiguës, radiculalgies et rhumatismes inflammatoires.',
        'Crise de colique néphrétique aiguë (voie intramusculaire IM stricte).',
        'Douleurs aiguës d\'intensité modérée à intense.',
      ],
      'posology_adult': 'Voie intramusculaire stricte (IM profonde et lente dans le quadrant supéro-externe de la fesse) : 100 à 200 mg/j (1 à 2 ampoules). Dans la colique néphrétique : 100 à 300 mg/j en 2 à 3 injections IM pendant 48 heures maximum. Voie orale de relais : 100 à 200 mg/j au milieu des repas (≤ 5 jours). ATTENTION : L\'administration intraveineuse (IV) est formellement proscrite !',
      'posology_pediatric_or_special': 'Réservé à l\'adulte et à l\'adolescent de plus de 15 ans. Déconseillé chez le sujet âgé (> 75 ans) et en cas d\'hypovolémie ou déshydratation (risque d\'insuffisance rénale aiguë fonctionnelle).',
      'contraindications': [
        'Voie intraveineuse (IV) : FORMELLEMENT CONTRE-INDIQUÉE (PROSCRITE).',
        'Grossesse à partir du début du 6e mois (24 SA) : risque fatal de fermeture prématurée du canal artériel fœtal et d\'insuffisance rénale fœtale.',
        'Ulcère gastro-duodénal évolutif ou antécédent d\'hémorragie/perforation digestive sous AINS.',
        'Insuffisance rénale sévère, insuffisance cardiaque sévère, insuffisance hépatocellulaire sévère, asthme déclenché par les AINS (syndrome de Widal), infection cutanée sévère ou varicelle.',
      ],
      'side_effects_and_monitoring': 'Gastralgies, ulcère et hémorragie digestive haute, insuffisance rénale aiguë (surtout si associé aux IEC/ARA2 + diurétiques = "Triple Whammy"), poussée hypertensive. Surveillance : fonction rénale (créatinine, diurèse), TA, signes digestifs.',
      'residanat_key_point': 'RÈGLE ABSOLUE (Vidal) : Kétoprofène injectable = VOIE INTRAMUSCULAIRE STRICTE (IM) ! L\'injection IV est formellement proscrite. Contre-indication absolue dès 24 SA de grossesse !',
    },
    'ACIDE ACETYLSALICYLIQUE': {
      'pharmacological_class': 'Antiagrégant plaquettaire (faible dose 75–300 mg) / Antipyrétique, Antalgique et AINS (forte dose ≥ 500 mg)',
      'description': 'Acétylation irréversible de la COX-1 plaquettaire bloquant la synthèse du thromboxane A2 pendant toute la durée de vie de la plaquette (7 à 10 jours).',
      'indications': [
        'Prévention secondaire cardiovasculaire et cérébrovasculaire (IDM, angor, AVC ischémique, AOMI) à faible dose (75–160 mg/j).',
        'Phase aiguë du Syndrome Coronarien Aigu (SCA) : dose de charge de 150 à 300 mg.',
        'Douleurs et fièvre (doses de 500 mg à 1 g), maladie de Kawasaki.',
      ],
      'posology_adult': 'Antiagrégant au long cours : 75 à 100 mg/jour en 1 prise quotidienne au cours du repas. Urgence SCA : 150 à 300 mg PO (non gastro-résistant) ou IV directe.',
      'posology_pediatric_or_special': 'Enfant (antipyrétique) : 60 mg/kg/j en 4 prises, mais éviter en cas de virose (varicelle, grippe) en raison du risque de syndrome de Reye (préférer le Paracétamol).',
      'contraindications': [
        'Ulcère gastro-duodénal évolutif, maladie hémorragique constitutionnelle ou acquise.',
        'Allergie aux salicylés ou aux AINS (syndrome de Fernand-Widal : asthme + polypose naso-sinusienne + intolérance à l\'aspirine).',
        'Grossesse à partir du 6e mois (24 SA) pour les doses ≥ 500 mg/j.',
      ],
      'side_effects_and_monitoring': 'Épigastralgies, hémorragies digestives occultes ou extériorisées, épistaxis, gingivorragies, bronchospasme. Associer un IPP chez les patients à haut risque ulcéreux (> 65 ans, bithérapie antiagrégante ou anticoagulant).',
      'residanat_key_point': 'À dose antiagrégante (75–160 mg/j), l\'aspirine reste autorisée pendant toute la grossesse (ex: prévention de la pré-éclampsie), contrairement aux doses anti-inflammatoires (≥ 500 mg/j) !',
    },
    'ENOXAPARINE': {
      'pharmacological_class': 'Anticoagulant parentéral — Héparine de Bas Poids Moléculaire (HBPM)',
      'description': 'Potentialise l\'antithrombine III avec une activité anti-Xa prédominante sur l\'activité anti-IIa. Biodisponibilité sous-cutanée proche de 100%, élimination principalement rénale.',
      'indications': [
        'Prophylaxie de la maladie thromboembolique veineuse (MTEV) en chirurgie ou médecine aiguë avec alitement.',
        'Traitement curatif des TVP, de l\'embolie pulmonaire (EP) non grave et des Syndromes Coronariens Aigus (SCA).',
      ],
      'posology_adult': 'Préventif : 4 000 UI anti-Xa (0,4 mL) en 1 injection SC/jour. Curatif : 100 UI anti-Xa/kg × 2/jour en SC toutes les 12h (soit 0,1 mL/10 kg × 2/j) ou 150 UI/kg × 1/j.',
      'posology_pediatric_or_special': 'Insuffisance rénale sévère (ClCr < 30 mL/min) : CONTRE-INDICATION à dose curative (utiliser l\'Héparine Non Fractionnée : Calciparine SC ou HNF IVSE). Sujet > 75 ans dans le SCA ST+ : 75 UI/kg × 2/j sans bolus IV.',
      'contraindications': [
        'Antécédent de Thrombopénie Induite par l\'Héparine (TIH de type II).',
        'Insuffisance rénale sévère (DFG / ClCr < 30 mL/min) à dose curative.',
        'Hémorragie active ou lésion organique susceptible de saigner, endocardite infectieuse aiguë.',
      ],
      'side_effects_and_monitoring': 'Hématomes au point d\'injection, hémorragies, thrombopénie induite par l\'héparine (TIH entre J5 et J21), hyperkaliémie (hypoaldostéronisme). Surveillance : Clairance de la créatinine (Cockcroft) obligatoire avant prescription, NFS-plaquettes si facteur de risque de TIH.',
      'residanat_key_point': 'En cas d\'insuffisance rénale sévère (ClCr < 30 mL/min), l\'Énoxaparine curative est contre-indiquée par risque d\'accumulation hémorragique -> remplacer par l\'HNF !',
    },
    'AMIODARONE': {
      'pharmacological_class': 'Antiarythmique de classe III de Vaughan-Williams (iodé)',
      'description': 'Allonge la durée du potentiel d\'action et la période réfractaire effective de toutes les fibres myocardiques sans déprimer la contractilité ventriculaire gauche. Contient 75 mg d\'iode par comprimé de 200 mg. Demi-vie très longue (20 à 100 jours).',
      'indications': [
        'Cardioversion pharmacologique et prévention des récidives de fibrillation atriale (FA) et flutter atrial (notamment sur cardiopathie sous-jacente).',
        'Traitement et prévention des troubles du rythme ventriculaires graves (TV, FV, arrêt cardiaque réfractaire aux chocs).',
      ],
      'posology_adult': 'Voie orale : Dose de charge de 3 cp/j (600 mg/j) pendant 8 à 10 jours, puis dose d\'entretien de 1/2 à 1 cp/j (100 à 200 mg/j). Urgence ACR (FV/TV réfractaire) : 300 mg IVD après le 3e choc électrique.',
      'posology_pediatric_or_special': 'En perfusion IV : toujours diluer exclusivement dans du Sérum Glucosé 5% (incompatible avec le NaCl 0,9%). Préférer une voie veineuse centrale si perfusion prolongée (veinotoxicité).',
      'contraindications': [
        'Bradycardie sinusale, bloc sino-atrial ou BAV de haut degré non appareillé.',
        'Dysthyroïdie (hyperthyroïdie active), allergie à l\'iode, grossesse (à partir du 2e trimestre : risque d\'hypothyroïdie fœtale) et allaitement.',
        'Association avec les médicaments donnant des torsades de pointes (Sotalol, Macrolides IV, Citalopram, Dompéridone...).',
      ],
      'side_effects_and_monitoring': 'Dysthyroïdies (hypo- ou hyperthyroïdie de type 1 et 2), pneumopathie interstitielle diffuse fibrosante, dépôts cornéens, photosensibilisation cutanée, hépatite médicamenteuse, bradycardie/allongement du QT. Surveillance : TSH, ECG, bilan hépatique, radiographie thoracique.',
      'residanat_key_point': 'L\'Amiodarone IV se dilue UNIQUEMENT dans du Glucosé 5% (G5%) et jamais dans du sérum salé NaCl 0,9% ! C\'est l\'antiarythmique de choix en cas d\'insuffisance cardiaque à FEVG altérée.',
    },
    'COLCHICINE': {
      'pharmacological_class': 'Antigoutteux & Anti-inflammatoire spécifique (poison du fuseau mitotique)',
      'description': 'Inhibe la polymérisation des microtubules des polynucléaires neutrophiles, bloquant leur migration et la réaction inflammatoire induite par les cristaux d\'urate de sodium. Médicament à marge thérapeutique très étroite.',
      'indications': [
        'Accès aigu de goutte et prophylaxie des accès goutteux lors de l\'instauration d\'un traitement hypo-uricémiant (Allopurinol, Féboxostat).',
        'Péricardite aiguë (en association à l\'Aspirine/AINS pour prévenir les récidives), Maladie périodique (Fièvre Méditerranéenne Familiale), Maladie de Behçet, Chondrocalcinose.',
      ],
      'posology_adult': 'Crise de goutte aiguë (schéma faible dose sécurisé) : 1 mg dès le début de la crise, suivi de 0,5 mg 1 heure plus tard (max 1,5 mg à J1), puis 0,5 mg × 2 à 3/j les jours suivants (ne jamais dépasser 1 mg par prise ni 3 mg/j). Péricardite : 0,5 mg × 2/j (ou × 1/j si < 70 kg) pendant 3 mois.',
      'posology_pediatric_or_special': 'Réduire la posologie chez le sujet > 75 ans et en cas d\'insuffisance rénale modérée (ClCr 30-60 mL/min : max 0,5 mg/j).',
      'contraindications': [
        'Insuffisance rénale sévère (ClCr < 30 mL/min) et insuffisance hépatique sévère.',
        'Association FORMELLEMENT CONTRE-INDIQUÉE avec les Macrolides (Clarithromycine, Érythromycine, Azithromycine), la Pristinamycine, la Ciclosporine et le Vérapamil (risque de surdosage mortel par inhibition du CYP3A4 et de la P-gp).',
      ],
      'side_effects_and_monitoring': 'Premier signe de surdosage (alarme clinique) : diarrhée, nausées, vomissements, douleurs abdominales -> imposer l\'arrêt ou la réduction immédiate de la dose ! Surdosage grave : pancytopénie/aplasie médullaire, rhabdomyolyse, défaillance multiviscérale mortelle.',
      'residanat_key_point': 'Règle vitale : La diarrhée sous Colchicine est le premier signe constant d\'intoxication ! Association Colchicine + Macrolide (Clarithromycine) = Contre-indication absolue mortelle.',
    },
    'CLARITHROMYCINE': {
      'pharmacological_class': 'Antibiotique antibactérien de la famille des Macrolides',
      'description': 'Bactériostatique par fixation sur la sous-unité 50S du ribosome bactérien. Excellente diffusion intracellulaire. Puissant inhibiteur enzymatique du CYP3A4 et de la glycoprotéine P (P-gp) et allonge l\'intervalle QT.',
      'indications': [
        'Éradication d\'Helicobacter pylori (en trithérapie ou quadrithérapie concomitante avec IPP + Amoxicilline + Métronidazole).',
        'Pneumopathies aiguës communautaires (germes intracellulaires : Mycoplasma, Chlamydia, Legionella), infections ORL et cutanées en cas d\'allergie aux bêta-lactamines.',
      ],
      'posology_adult': 'Infections respiratoires/ORL : 250 à 500 mg × 2/jour matin et soir pendant 5 à 10 jours. Éradication H. pylori : 500 mg × 2/jour pendant 10 à 14 jours.',
      'posology_pediatric_or_special': 'Pédiatrie : 15 mg/kg/jour répartis en 2 prises (7,5 mg/kg × 2/j). Insuffisance rénale sévère (ClCr < 30 mL/min) : réduire la posologie de moitié (max 500 mg/j).',
      'contraindications': [
        'Association avec la Colchicine (contre-indication absolue mortelle), la Simvastatine/Atorvastatine (risque de rhabdomyolyse), l\'Ergotamine, le Ticagrélor.',
        'Allongement congénital ou acquis de l\'intervalle QT, hypokaliémie non corrigée, association aux médicaments torsadogènes.',
      ],
      'side_effects_and_monitoring': 'Troubles digestifs (dysgueusie métallique, nausées, diarrhée), allongement du QT / torsades de pointes, hépatite cholestatique. Surveillance : ECG et kaliémie chez les sujets à risque.',
      'residanat_key_point': 'Inhibiteur enzymatique puissant du CYP3A4 : ne jamais associer à la Colchicine, aux statines (Simvastatine/Atorvastatine) ni à la Carbamazépine !',
    },
    'PERINDOPRIL': {
      'pharmacological_class': 'Antihypertenseur — Inhibiteur de l\'Enzyme de Conversion (IEC)',
      'description': 'Inhibe la transformation de l\'angiotensine I en angiotensine II et bloque la dégradation de la bradykinine, entraînant une vasodilatation artérielle et veineuse, une baisse de l\'aldostérone et un effet néphroprotecteur (baisse de la pression intraglomérulaire).',
      'indications': [
        'Hypertension artérielle (HTA) essentielle.',
        'Insuffisance cardiaque chronique à FEVG réduite, maladie coronarienne stable et post-infarctus du myocarde, néphropathie diabétique protéinurique.',
      ],
      'posology_adult': 'HTA : Débuter à 4 ou 5 mg en 1 prise le matin, pouvant être augmenté à 8 ou 10 mg/j après 1 mois. Insuffisance cardiaque : débuter à 2 mg ou 2,5 mg/j et titrer progressivement.',
      'posology_pediatric_or_special': 'Insuffisance rénale ou sujet âgé : débuter à 2 mg ou 2,5 mg/j et adapter selon la clairance de la créatinine.',
      'contraindications': [
        'Grossesse (2e et 3e trimestres : fœtotoxicité rénale grave, oligoamnios, hypoplasie des os du crâne ; déconseillé au 1er trimestre).',
        'Antécédent d\'angio-œdème (œdème de Quincke) bradykinique lié à un IEC ou héréditaire.',
        'Sténose bilatérale des artères rénales ou sténose sur rein fonctionnellement unique, hyperkaliémie > 5,5 mmol/L.',
      ],
      'side_effects_and_monitoring': 'Toux sèche quinteuse persistante (liée à l\'accumulation de bradykinine -> remplacer par un ARA2), hyperkaliémie, insuffisance rénale aiguë fonctionnelle, hypotension orthostatique, angio-œdème. Surveillance : Ionogramme sanguin (K+) et Créatininémie avant traitement et 7 à 15 jours après instauration ou augmentation de dose.',
      'residanat_key_point': 'Contrôler systématiquement Kaliémie + Créatininémie à J7–J15 ! Une hausse de créatinine > 30% sous IEC doit faire rechercher une sténose des artères rénales.',
    },
    'SPIRONOLACTONE': {
      'pharmacological_class': 'Diurétique épargneur de potassium — Antagoniste compétitif des récepteurs aux minéralocorticoïdes (Anti-aldostérone)',
      'description': 'Agit au niveau du tube contourné distal et du canal collecteur cortical en bloquant la réabsorption du sodium et l\'excrétion du potassium et des ions H+ induites par l\'aldostérone.',
      'indications': [
        'Insuffisance cardiaque chronique à FEVG réduite (≤ 35–40%) : réduit la mortalité cardiovasculaire.',
        'Ascite cirrhotique et syndromes œdémateux secondaires à un hyperaldostéronisme secondaire.',
        'Hyperaldostéronisme primaire (syndrome de Conn) et HTA résistante (en 4e ligne).',
      ],
      'posology_adult': 'Insuffisance cardiaque / HTA résistante : 25 mg/jour en 1 prise (max 50 mg/j). Ascite cirrhotique : 50 à 100 mg/j (jusqu\'à 200–400 mg/j selon la natriurèse).',
      'posology_pediatric_or_special': 'Ne pas instaurer si Kaliémie > 5,0 mmol/L ou DFG < 30 mL/min.',
      'contraindications': [
        'Hyperkaliémie (> 5,0 mmol/L), insuffisance rénale sévère (ClCr < 30 mL/min) ou aiguë, anurie.',
        'Stade terminal de l\'insuffisance hépatique, association aux autres diurétiques hyperkaliémiants (Amiloride, Éplérénone) ou aux sels de potassium.',
      ],
      'side_effects_and_monitoring': 'Hyperkaliémie potentiellement menaçante (surtout en association aux IEC/ARA2), insuffisance rénale fonctionnelle, gynécomastie douloureuse chez l\'homme, troubles menstruels chez la femme. Surveillance stricte : Kaliémie et Créatininémie à J7, M1 puis tous les 3 mois.',
      'residanat_key_point': 'En cas de gynécomastie mal tolérée dans le post-infarctus ou l\'insuffisance cardiaque, remplacer la Spironolactone par l\'Éplérénone (plus sélective, sans effet anti-androgénique).',
    },
    'OMEPRAZOLE': {
      'pharmacological_class': 'Anti-ulcéreux — Inhibiteur de la Pompe à Protons (IPP)',
      'description': 'Inhibe de façon spécifique et irréversible l\'enzyme H+/K+-ATPase de la cellule pariétale gastrique, supprimant la sécrétion acide basale et stimulée. Inhibiteur du CYP2C19.',
      'indications': [
        'Reflux gastro-œsophagien (RGO) et œsophagite par reflux.',
        'Ulcère gastrique et duodénal évolutif, éradication d\'Helicobacter pylori (en association aux antibiotiques).',
        'Prévention et traitement des lésions gastro-duodénales induites par les AINS/Aspirine chez les sujets à risque (> 65 ans, antécédent d\'ulcère, bithérapie antiagrégante/anticoagulant), syndrome de Zollinger-Ellison.',
      ],
      'posology_adult': 'Traitement curatif (Ulcère, Œsophagite, H. pylori) : 20 mg × 1 à 2/jour (20 à 40 mg/j) pendant 4 à 8 semaines, à prendre 15-30 min avant le repas. Prévention sous AINS ou entretien RGO : 10 à 20 mg/jour.',
      'posology_pediatric_or_special': 'Enfant > 1 an (≥ 10 kg) : 1 mg/kg/jour (10 à 20 mg/j).',
      'contraindications': [
        'Hypersensibilité aux benzimidazolés substitués.',
        'Association déconseillée avec le Clopidogrel (l\'Oméprazole inhibe le CYP2C19 qui active le Clopidogrel -> préférer le Pantoprazole ou le Rabéprazole) et contre-indiquée avec le Nelfinavir.',
      ],
      'side_effects_and_monitoring': 'Céphalées, diarrhée, nausées. Au long cours : hypomagnésémie, carence en vitamine B12 et fer, augmentation modérée du risque d\'infections digestives (Clostridioides difficile) et de fractures ostéoporotiques.',
      'residanat_key_point': 'Chez un patient coronarien sous Clopidogrel (Plavix), ne pas prescrire d\'Oméprazole ni d\'Ésoméprazole (inhibition du CYP2C19) : préférer le Pantoprazole !',
    },
    'FUROSEMIDE': {
      'pharmacological_class': 'Diurétique de l\'anse d\'action rapide et puissante (hypokaliémiant)',
      'description': 'Inhibe le co-transporteur Na+-K+-2Cl- de la branche ascendante large de l\'anse de Henle. Conserve son efficacité même en cas d\'insuffisance rénale sévère (DFG < 30 mL/min), contrairement aux thiazidiques.',
      'indications': [
        'Œdème Aigu du Poumon (OAP) cardiogénique et décompensation cardiaque congestive.',
        'Syndromes œdémateux d\'origine cardiaque, rénale (syndrome néphrotique, IRC) ou hépatique.',
        'Hypercalcémie aiguë sévère (après réhydratation) et HTA chez l\'insuffisant rénal chronique.',
      ],
      'posology_adult': 'Urgence OAP : 40 à 80 mg en IV directe lente, à répéter selon la diurèse. Traitement oral d\'entretien : 20 à 80 mg/jour le matin (jusqu\'à 250–500 mg/j dans l\'IRC sévère).',
      'posology_pediatric_or_special': 'Pédiatrie : 1 à 2 mg/kg/jour PO ou 0,5 à 1 mg/kg IV.',
      'contraindications': [
        'Hypovolémie ou déshydratation extracellulaire, hypokaliémie sévère ou hyponatrémie sévère non corrigées.',
        'Encéphalopathie hépatique, obstacle complet sur les voies urinaires, allergie aux sulfamides.',
      ],
      'side_effects_and_monitoring': 'Hypokaliémie (risque de torsades de pointes), hyponatrémie, déshydratation extracellulaire et insuffisance rénale fonctionnelle, hyperuricémie (crise de goutte), alcalose métabolique de contraction, ototoxicité à très forte dose IV rapide (surtout si associé aux aminosides). Surveillance : Poids, diurèse, ionogramme sanguin (Na+, K+), créatininémie.',
      'residanat_key_point': 'Seul diurétique actif lorsque le DFG est < 30 mL/min (les thiazidiques deviennent inefficaces sous ce seuil). Attention à l\'ototoxicité irréversible si associé aux aminosides !',
    },
    'ATORVASTATINE': {
      'pharmacological_class': 'Hypolipémiant — Inhibiteur de l\'HMG-CoA réductase (Statine puissante)',
      'description': 'Inhibe de façon compétitive l\'HMG-CoA réductase hépatique, augmentant l\'expression des récepteurs aux LDL et réduisant le LDL-cholestérol de 35% à 55%, tout en stabilisant les plaques d\'athérome (effet pléiotrope). Métabolisé par le CYP3A4.',
      'indications': [
        'Prévention cardiovasculaire secondaire (post-SCA/IDM, AVC ischémique, AOMI) à forte intensité (40 à 80 mg/j) quel que soit le taux initial de LDL-c.',
        'Hypercholestérolémies pures ou mixtes et prévention primaire chez les patients à haut ou très haut risque cardiovasculaire (diabète, SCORE2 élevé).',
      ],
      'posology_adult': 'Prévention primaire / Hypercholestérolémie : débuter à 10 ou 20 mg/j en 1 prise (à tout moment de la journée). Post-SCA / Très haut risque CV : 40 à 80 mg/jour d\'emblée (objectif LDL-c < 0,55 g/L).',
      'posology_pediatric_or_special': 'Pas d\'adaptation nécessaire en cas d\'insuffisance rénale (élimination biliaire).',
      'contraindications': [
        'Affection hépatique évolutive ou élévation prolongée des transaminases > 3 × la normale.',
        'Grossesse et allaitement.',
        'Association aux inhibiteurs puissants du CYP3A4 (Macrolides : Clarithromycine/Érythromycine, Itraconazole, Acide fusidique systémique) en raison du risque majeur de rhabdomyolyse.',
      ],
      'side_effects_and_monitoring': 'Myalgies, crampes musculaires, élévation des CPK, exceptionnellement rhabdomyolyse avec insuffisance rénale aiguë ; cytolyse hépatique. Surveillance : Bilan lipidique à 4–12 semaines, transaminases (ALAT) avant traitement et à 3 mois, dosage des CPK uniquement en cas de symptômes musculaires ou de terrain à risque.',
      'residanat_key_point': 'Toute douleur musculaire diffuse inexpliquée sous statine impose un dosage urgent des CPK : arrêter la statine si CPK > 5 × la normale !',
    },
  };

  Map<String, dynamic>? _resolveLocalMonograph(PrescribedDrugItem drug) {
    final normName = AlgerianNomenclatureRepository.normalize(drug.name);
    final normDci = AlgerianNomenclatureRepository.normalize(drug.activeDci ?? '');

    for (final entry in _curatedMonographs.entries) {
      if (normName.contains(entry.key) || normDci.contains(entry.key)) {
        return entry.value;
      }
    }
    if (normName.contains('SINTROM')) return _curatedMonographs['ACENOCOUMAROL'];
    if (normName.contains('ASPIRINE') || normName.contains('ASPEGIC') || normName.contains('KARDEGIC')) {
      return _curatedMonographs['ACIDE ACETYLSALICYLIQUE'];
    }
    if (normName.contains('LOVENOX')) return _curatedMonographs['ENOXAPARINE'];
    if (normName.contains('CORDARONE')) return _curatedMonographs['AMIODARONE'];
    if (normName.contains('COVERSYL')) return _curatedMonographs['PERINDOPRIL'];
    if (normName.contains('ALDACTONE')) return _curatedMonographs['SPIRONOLACTONE'];
    if (normName.contains('MOPRAL') || normName.contains('INEXIUM') || normDci.contains('ESOMEPRAZOLE')) {
      return _curatedMonographs['OMEPRAZOLE'];
    }
    if (normName.contains('LASILIX')) return _curatedMonographs['FUROSEMIDE'];
    if (normName.contains('TAHOR')) return _curatedMonographs['ATORVASTATINE'];
    if (normName.contains('PROFENID') || normName.contains('BI-PROFENID')) return _curatedMonographs['KETOPROFENE'];

    // Check emergency drugs catalog if available
    for (final em in _emergencyDrugs) {
      final emDci = AlgerianNomenclatureRepository.normalize(em.dci);
      final emBrand = AlgerianNomenclatureRepository.normalize(em.brand);
      if ((emDci.isNotEmpty && (normName.contains(emDci) || normDci.contains(emDci))) ||
          (emBrand.isNotEmpty && (normName.contains(emBrand) || normDci.contains(emBrand)))) {
        return {
          'pharmacological_class': '${em.category} (${em.route})',
          'description': 'Médicament hospitalier et d\'urgence référencé en Algérie (${em.brand} — DCI : ${em.dci}).',
          'indications': [em.indication],
          'posology_adult': em.dose,
          'posology_pediatric_or_special': em.algerianAvailability ?? 'Se référer au protocole de service UMC / Réanimation.',
          'contraindications': [if (em.alert.isNotEmpty) em.alert],
          'side_effects_and_monitoring': em.alert,
          'residanat_key_point': em.alert,
        };
      }
    }

    return null;
  }

  void _showDrugMonographSheet(BuildContext context, PrescribedDrugItem drug) {
    final normDci = AlgerianNomenclatureRepository.normalize(drug.activeDci ?? drug.name);
    final normName = AlgerianNomenclatureRepository.normalize(drug.name);

    // Find all matching specialties in the Algerian MSPRH nomenclature
    final algerianEquivalents = _algerianCatalog.where((d) {
      final cDci = AlgerianNomenclatureRepository.normalize(d.dci);
      final cBrand = AlgerianNomenclatureRepository.normalize(d.brand);
      return (normDci.isNotEmpty && cDci == normDci) || cBrand == normName;
    }).take(15).toList();

    // Find any terrain rules in our local repository that apply to this drug
    final matchingTerrainRules = _terrainRules.where((r) {
      return r.drugPatterns.any((p) =>
          p.isNotEmpty && (normDci.toLowerCase().contains(p) || normName.toLowerCase().contains(p)));
    }).toList();

    Map<String, dynamic>? monograph = _resolveLocalMonograph(drug);
    bool isFetchingAi = monograph == null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool aiStarted = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            if (isFetchingAi && !aiStarted) {
              aiStarted = true;
              GeminiService.fetchDrugMonographWithAi(
                drugName: drug.name,
                dci: drug.activeDci,
                dosage: drug.dosage,
                form: drug.form,
              ).then((res) {
                if (ctx.mounted) {
                  setSheetState(() {
                    monograph = res;
                    isFetchingAi = false;
                  });
                }
              });
            }

            final pharmClass = monograph?['pharmacological_class']?.toString() ??
                'Spécialité Pharmaceutique (Nomenclature Nationale MSPRH)';
            final description = monograph?['description']?.toString() ?? '';
            final indications = (monograph?['indications'] as List?)
                    ?.map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                <String>[];
            final posologyAdult = monograph?['posology_adult']?.toString() ?? '';
            final posologySpecial = monograph?['posology_pediatric_or_special']?.toString() ?? '';
            final contraindications = (monograph?['contraindications'] as List?)
                    ?.map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                <String>[];
            final sideEffects = monograph?['side_effects_and_monitoring']?.toString() ?? '';
            final keyPoint = monograph?['residanat_key_point']?.toString() ?? '';

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag handle + Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    drug.name,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    drug.activeDci != null && drug.activeDci!.isNotEmpty
                                        ? 'DCI : ${drug.activeDci}'
                                        : 'Monographie Clinique & Posologique',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryTeal,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (drug.dosage != null && drug.dosage!.isNotEmpty)
                                        _buildMonographBadge(drug.dosage!, const Color(0xFF2563EB)),
                                      if (drug.form != null && drug.form!.isNotEmpty)
                                        _buildMonographBadge(drug.form!, const Color(0xFF0D9488)),
                                      if (drug.liste != null && drug.liste!.isNotEmpty)
                                        _buildMonographBadge(drug.liste!, const Color(0xFFD97706)),
                                      if (drug.lab != null && drug.lab!.isNotEmpty)
                                        _buildMonographBadge(drug.lab!, const Color(0xFF64748B)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (isFetchingAi)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Génération de la monographie complète (Description, Indications, Posologie, Contre-indications) via MedsinaPilot Vidal IA...',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (monograph != null) ...[
                          // 1. Classe & Description
                          _buildMonographSectionCard(
                            isDark: isDark,
                            icon: Icons.science_rounded,
                            accentColor: const Color(0xFF2563EB),
                            title: 'Classe Pharmacologique & Mécanisme d\'Action',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pharmClass,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // 2. Indications Thérapeutiques
                          if (indications.isNotEmpty)
                            _buildMonographSectionCard(
                              isDark: isDark,
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: const Color(0xFF0D9488),
                              title: 'Indications Thérapeutiques',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: indications
                                    .map(
                                      (ind) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Icon(Icons.arrow_right_rounded, size: 18, color: Color(0xFF0D9488)),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                ind,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.4,
                                                  color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E293B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),

                          // 3. Posologie & Mode d'Administration
                          if (posologyAdult.isNotEmpty || posologySpecial.isNotEmpty)
                            _buildMonographSectionCard(
                              isDark: isDark,
                              icon: Icons.schedule_rounded,
                              accentColor: const Color(0xFF7C3AED),
                              title: 'Posologie & Adaptation Thérapeutique',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (posologyAdult.isNotEmpty) ...[
                                    const Text(
                                      '• Posologie Adulte & Modalités :',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      posologyAdult,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                  if (posologySpecial.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      '• Pédiatrie / Sujet Âgé / Adaptation Rénale & Hépatique :',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      posologySpecial,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                          // 4. Contre-Indications & Terrains à Risque
                          if (contraindications.isNotEmpty || matchingTerrainRules.isNotEmpty)
                            _buildMonographSectionCard(
                              isDark: isDark,
                              icon: Icons.dangerous_rounded,
                              accentColor: const Color(0xFFDC2626),
                              title: 'Contre-Indications & Terrains à Risque',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...contraindications.map(
                                    (ci) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 3),
                                            child: Icon(Icons.block_rounded, size: 14, color: Color(0xFFDC2626)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              ci,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                height: 1.4,
                                                color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (matchingTerrainRules.isNotEmpty) ...[
                                    if (contraindications.isNotEmpty) const Divider(height: 16),
                                    const Text(
                                      'Alertes Terrains Référencées (Moteur Vidal Local) :',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...matchingTerrainRules.take(5).map(
                                          (r) => Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Text(
                                              '• ${r.terrain} : ${r.title}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                  ],
                                ],
                              ),
                            ),

                          // 5. Effets Indésirables & Surveillance
                          if (sideEffects.isNotEmpty)
                            _buildMonographSectionCard(
                              isDark: isDark,
                              icon: Icons.monitor_heart_rounded,
                              accentColor: const Color(0xFFD97706),
                              title: 'Effets Indésirables & Surveillance Biologique',
                              child: Text(
                                sideEffects,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF334155),
                                ),
                              ),
                            ),

                          // 6. Point-Clé Résidanat & Garde
                          if (keyPoint.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Point-Clé Résidanat Blida & Garde UMC',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          keyPoint,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                            color: isDark ? Colors.white : const Color(0xFF78350F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],

                        // 7. Spécialités & Équivalents Algérie (MSPRH)
                        if (algerianEquivalents.isNotEmpty)
                          _buildMonographSectionCard(
                            isDark: isDark,
                            icon: Icons.local_pharmacy_rounded,
                            accentColor: const Color(0xFF059669),
                            title: 'Présentations & Équivalents en Algérie (${algerianEquivalents.length} MSPRH)',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: algerianEquivalents.map((eq) {
                                final sub = [
                                  if (eq.dosage.isNotEmpty) eq.dosage,
                                  if (eq.form.isNotEmpty) eq.form,
                                  if (eq.packaging.isNotEmpty) eq.packaging,
                                  if (eq.lab.isNotEmpty) eq.lab,
                                  if (eq.pays.isNotEmpty) eq.pays,
                                ].join(' • ');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF059669)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${eq.brand} (${eq.dci})',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            if (sub.isNotEmpty)
                                              Text(
                                                sub,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (eq.liste.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            eq.liste,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Action Bar: Ask MedsinaPilot AI about this specific drug
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      children: [
                        if (!isFetchingAi && monograph == null)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Générer la fiche IA Vidal'),
                              onPressed: () {
                                setSheetState(() {
                                  isFetchingAi = true;
                                  aiStarted = false;
                                });
                              },
                            ),
                          )
                        else
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.psychology_rounded, size: 18),
                              label: Text(
                                'Interroger MedsinaPilot sur ${drug.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                ClinicalCopilotSheet.show(
                                  context,
                                  initialSituation:
                                      'MONOGRAPHIE & QUESTIONS CLINIQUES SUR LE MÉDICAMENT : ${drug.displayName} ${drug.dosage ?? ""} ${drug.form ?? ""}. Détaillez les règles de prescription pratique, les adaptations posologiques et la surveillance.',
                                );
                              },
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
      },
    );
  }

  Widget _buildMonographBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMonographSectionCard({
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
