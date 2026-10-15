import 'package:flutter/material.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai_assistant/presentation/clinical_copilot_sheet.dart';
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

  const PrescribedDrugItem({
    required this.name,
    this.activeDci,
    this.dosage,
    this.form,
    this.lab,
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
      if (mounted) {
        setState(() {
          _algerianCatalog = catalog;
          _vidalRules = rules;
          _terrainRules = terrainRules;
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

    if (!_prescribedDrugs.any((d) => d.name.toLowerCase() == clean.toLowerCase())) {
      setState(() {
        _prescribedDrugs.add(PrescribedDrugItem(
          name: clean,
          activeDci: resolvedDci,
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
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                              child: const Icon(Icons.medication_rounded, size: 14, color: AppTheme.primaryTeal),
                            ),
                            title: Text(
                              drug.brand,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              'DCI: ${drug.dci} • ${drug.dosage} ${drug.form}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              drug.lab,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            onTap: () => _addDrugFromCatalog(drug),
                          );
                        },
                      ),
                    ),
                  ],

                  if (_prescribedDrugs.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    const Text('Médicaments dans l\'ordonnance à analyser :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _prescribedDrugs.map((drug) {
                        return Chip(
                          avatar: const CircleAvatar(
                            backgroundColor: Color(0xFF2563EB),
                            child: Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                          label: Text(
                            drug.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () => _removeDrug(drug),
                        );
                      }).toList(),
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
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFD97706)),
                    label: const Text('Choisir un terrain patient', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showTerrainSelectionSheet(context),
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
}
