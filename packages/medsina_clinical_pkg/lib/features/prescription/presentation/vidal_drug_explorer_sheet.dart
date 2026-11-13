import 'package:flutter/material.dart';
import 'package:medsina_core/core/services/gemini_service.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import '../data/algerian_nomenclature_repository.dart';
import '../data/therapeutic_classes.dart';
import '../models/algerian_drug_model.dart';

class VidalDrugExplorerSheet extends StatefulWidget {
  final int initialTabIndex;
  final Set<String> prescribedDrugNames;
  final void Function(AlgerianDrugModel drug) onAddDrug;
  final void Function(AlgerianDrugModel drug) onShowMonograph;

  const VidalDrugExplorerSheet({
    super.key,
    this.initialTabIndex = 0,
    required this.prescribedDrugNames,
    required this.onAddDrug,
    required this.onShowMonograph,
  });

  @override
  State<VidalDrugExplorerSheet> createState() => _VidalDrugExplorerSheetState();
}

class _VidalDrugExplorerSheetState extends State<VidalDrugExplorerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiQueryController = TextEditingController();

  // Tab 1: Spécialités & Filtres
  String? _selectedClassPrefix;
  String? _selectedLab;
  String? _selectedForm;
  String? _selectedListe;
  String? _selectedType;
  String? _selectedOrigin;
  List<AlgerianDrugModel> _filteredDrugs = [];

  // Tab 2: Substances (DCI)
  List<DciSummary> _dciList = [];
  String? _expandedDci;
  List<AlgerianDrugModel> _expandedDciEquivalents = [];

  // Tab 3: Classes Thérapeutiques
  Map<String, int> _classCounts = {};

  // Tab 4: Laboratoires
  List<LaboratorySummary> _labList = [];

  // Tab 5: Indication & Équivalences Internationales (IA + Catalogue DZ)
  bool _isIndicationMode = true;
  bool _isAiLoading = false;
  String? _aiError;
  List<Map<String, dynamic>> _indicationResults = [];
  Map<String, dynamic>? _internationalEquivResult;
  List<AlgerianDrugModel> _internationalDzMatches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _classCounts = AlgerianNomenclatureRepository.getTherapeuticClassCounts();
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _aiQueryController.dispose();
    super.dispose();
  }

  void _refreshData() {
    final query = _searchController.text.trim();
    setState(() {
      _filteredDrugs = AlgerianNomenclatureRepository.advancedSearch(
        DrugSearchFilter(
          query: query,
          therapeuticClassPrefix: _selectedClassPrefix,
          laboratory: _selectedLab,
          formCategory: _selectedForm,
          liste: _selectedListe,
          drugType: _selectedType,
          originStatus: _selectedOrigin,
        ),
        limit: 80,
      );
      _dciList = AlgerianNomenclatureRepository.getUniqueDcis(
        query: query,
        therapeuticClassPrefix: _selectedClassPrefix,
        limit: 100,
      );
      _labList = AlgerianNomenclatureRepository.getUniqueLaboratories(
        query: query,
        limit: 100,
      );
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedClassPrefix = null;
      _selectedLab = null;
      _selectedForm = null;
      _selectedListe = null;
      _selectedType = null;
      _selectedOrigin = null;
      _searchController.clear();
    });
    _refreshData();
  }

  Future<void> _runAiSearch() async {
    final q = _aiQueryController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isAiLoading = true;
      _aiError = null;
    });

    try {
      if (_isIndicationMode) {
        final results = await GeminiService.searchDrugsByIndicationWithAi(q);
        if (!mounted) return;
        setState(() {
          _indicationResults = results;
          _isAiLoading = false;
          if (results.isEmpty) {
            _aiError = 'Aucun résultat trouvé pour cette indication.';
          }
        });
      } else {
        final res = await GeminiService.resolveInternationalEquivalentWithAi(q);
        if (!mounted) return;
        final keyword = res?['search_keyword']?.toString() ?? res?['dci']?.toString() ?? '';
        final dzMatches = keyword.isNotEmpty
            ? AlgerianNomenclatureRepository.getEquivalentsForDci(keyword)
            : <AlgerianDrugModel>[];
        setState(() {
          _internationalEquivResult = res;
          _internationalDzMatches = dzMatches;
          _isAiLoading = false;
          if (res == null) {
            _aiError = 'Impossible de résoudre cette spécialité étrangère.';
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAiLoading = false;
        _aiError = 'Erreur réseau lors de la recherche Vidal IA.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAnyFilter = _selectedClassPrefix != null ||
        _selectedLab != null ||
        _selectedForm != null ||
        _selectedListe != null ||
        _selectedType != null ||
        _selectedOrigin != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.manage_search_rounded, color: AppTheme.primaryTeal, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explorateur Médicaments (Style Vidal)',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Spécialités • DCI • Classes • Labos • Indications & Équiv.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (hasAnyFilter)
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: const Text('Réinit.', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tabController.index != 4)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _refreshData(),
                      decoration: InputDecoration(
                        hintText: _tabController.index == 1
                            ? 'Filtrer les substances actives (DCI)...'
                            : _tabController.index == 3
                                ? 'Rechercher un laboratoire (ex: El Kendi, Saidal, Sanofi)...'
                                : 'Rechercher une spécialité, DCI, code MSPRH, labo...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _refreshData();
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppTheme.primaryTeal,
                  indicatorColor: AppTheme.primaryTeal,
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Spécialités'),
                    Tab(text: 'DCI (Substances)'),
                    Tab(text: 'Classes (28)'),
                    Tab(text: 'Laboratoires'),
                    Tab(text: 'Indication / Équiv.'),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSpecialtiesTab(isDark),
                _buildDciTab(isDark),
                _buildClassesTab(isDark),
                _buildLabsTab(isDark),
                _buildIndicationAndEquivTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesTab(bool isDark) {
    final classInfo = _selectedClassPrefix != null
        ? TherapeuticClasses.all.where((c) => c.codePrefix == _selectedClassPrefix).firstOrNull
        : null;

    return Column(
      children: [
        // Facet Filter Bar (Type, Liste, Forme, Origine)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (classInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text('${classInfo.codePrefix} • ${classInfo.shortName}', style: const TextStyle(fontSize: 11)),
                      selected: true,
                      selectedColor: classInfo.color.withValues(alpha: 0.2),
                      onDeleted: () {
                        setState(() => _selectedClassPrefix = null);
                        _refreshData();
                      },
                    ),
                  ),
                if (_selectedLab != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text('Labo: $_selectedLab', style: const TextStyle(fontSize: 11)),
                      selected: true,
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                      onDeleted: () {
                        setState(() => _selectedLab = null);
                        _refreshData();
                      },
                    ),
                  ),
                _buildFilterChip('Princeps (RE)', _selectedType == 'RE', () {
                  setState(() => _selectedType = _selectedType == 'RE' ? null : 'RE');
                  _refreshData();
                }),
                _buildFilterChip('Générique (GE)', _selectedType == 'GE', () {
                  setState(() => _selectedType = _selectedType == 'GE' ? null : 'GE');
                  _refreshData();
                }),
                _buildFilterChip('Bio', _selectedType == 'BIO', () {
                  setState(() => _selectedType = _selectedType == 'BIO' ? null : 'BIO');
                  _refreshData();
                }),
                _buildFilterChip('Liste I', _selectedListe == 'LISTE I', () {
                  setState(() => _selectedListe = _selectedListe == 'LISTE I' ? null : 'LISTE I');
                  _refreshData();
                }),
                _buildFilterChip('Liste II', _selectedListe == 'LISTE II', () {
                  setState(() => _selectedListe = _selectedListe == 'LISTE II' ? null : 'LISTE II');
                  _refreshData();
                }),
                _buildFilterChip('Stupéfiant', _selectedListe == 'STUPEFIANT', () {
                  setState(() => _selectedListe = _selectedListe == 'STUPEFIANT' ? null : 'STUPEFIANT');
                  _refreshData();
                }),
                _buildFilterChip('Fabriqué DZ', _selectedOrigin == 'F', () {
                  setState(() => _selectedOrigin = _selectedOrigin == 'F' ? null : 'F');
                  _refreshData();
                }),
                _buildFilterChip('Importé', _selectedOrigin == 'I', () {
                  setState(() => _selectedOrigin = _selectedOrigin == 'I' ? null : 'I');
                  _refreshData();
                }),
                for (final form in ['COMPRIME', 'GELULE', 'SIROP / SUSP', 'INJECTABLE', 'COLLYRE', 'CREME / POMMADE', 'SUPPOSITOIRE'])
                  _buildFilterChip(form, _selectedForm == form, () {
                    setState(() => _selectedForm = _selectedForm == form ? null : form);
                    _refreshData();
                  }),
              ],
            ),
          ),
        ),

        // Count banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Text(
                '${_filteredDrugs.length} résultat(s) affiché(s)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                'Touchez + pour ajouter à l\'ordonnance',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),

        // Drug list
        Expanded(
          child: _filteredDrugs.isEmpty
              ? const Center(
                  child: Text('Aucune spécialité ne correspond à ces critères.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: _filteredDrugs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) => _buildDrugTile(_filteredDrugs[index], isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
        selected: selected,
        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildDrugTile(AlgerianDrugModel drug, bool isDark) {
    final isAdded = widget.prescribedDrugNames.contains(drug.brand.toLowerCase());
    final classInfo = TherapeuticClasses.fromCode(drug.code);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdded ? AppTheme.primaryTeal.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: (classInfo?.color ?? AppTheme.primaryTeal).withValues(alpha: 0.14),
            child: Icon(classInfo?.icon ?? Icons.medication_rounded,
                size: 16, color: classInfo?.color ?? AppTheme.primaryTeal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        drug.brand,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    if (drug.type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: drug.type == 'RE'
                              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                              : Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          drug.type == 'RE' ? 'Princeps' : (drug.type == 'GE' ? 'Générique' : drug.type),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: drug.type == 'RE' ? const Color(0xFF2563EB) : Colors.teal,
                          ),
                        ),
                      ),
                  ],
                ),
                if (drug.dci.isNotEmpty)
                  Text(
                    'DCI : ${drug.dci}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                  ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (drug.dosage.isNotEmpty) drug.dosage,
                    if (drug.form.isNotEmpty) drug.form,
                    if (drug.packaging.isNotEmpty) drug.packaging,
                  ].join(' • '),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (drug.lab.isNotEmpty)
                      Text(
                        '${drug.lab}${drug.pays.isNotEmpty ? ' (${drug.pays})' : ''}',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                    if (drug.liste.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(drug.liste, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              IconButton(
                tooltip: 'Ajouter à l\'ordonnance',
                icon: Icon(
                  isAdded ? Icons.check_circle_rounded : Icons.add_circle_rounded,
                  color: isAdded ? Colors.green : AppTheme.primaryTeal,
                ),
                onPressed: () {
                  widget.onAddDrug(drug);
                  setState(() {});
                },
              ),
              InkWell(
                onTap: () => widget.onShowMonograph(drug),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Fiche',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDciTab(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: _dciList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final summary = _dciList[index];
        final isExpanded = _expandedDci == summary.dci;
        final classInfo = summary.classPrefix != null
            ? TherapeuticClasses.fromCode(summary.classPrefix!)
            : null;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: (classInfo?.color ?? AppTheme.primaryTeal).withValues(alpha: 0.15),
                  child: Icon(Icons.science_rounded, size: 16, color: classInfo?.color ?? AppTheme.primaryTeal),
                ),
                title: Text(summary.dci, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                  '${summary.totalSpecialties} spécialité(s) • ${summary.princepsCount} Princeps • ${summary.genericCount} Génériques'
                  '${summary.sampleBrands.isNotEmpty ? '\nEx: ${summary.sampleBrands.join(', ')}' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDci = null;
                      _expandedDciEquivalents = [];
                    } else {
                      _expandedDci = summary.dci;
                      _expandedDciEquivalents = AlgerianNomenclatureRepository.getEquivalentsForDci(summary.dci);
                    }
                  });
                },
              ),
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: _expandedDciEquivalents
                        .map((eq) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _buildDrugTile(eq, isDark),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassesTab(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: TherapeuticClasses.all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final cls = TherapeuticClasses.all[index];
        final count = _classCounts[cls.codePrefix] ?? 0;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cls.color.withValues(alpha: 0.14),
              child: Icon(cls.icon, color: cls.color, size: 20),
            ),
            title: Text(
              '${cls.codePrefix} • ${cls.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              '$count spécialités MSPRH • ${cls.keywords.take(3).join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              setState(() => _selectedClassPrefix = cls.codePrefix);
              _refreshData();
              _tabController.animateTo(0);
            },
          ),
        );
      },
    );
  }

  Widget _buildLabsTab(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: _labList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final lab = _labList[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
              child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF2563EB)),
            ),
            title: Text(lab.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(
              '${lab.country.isNotEmpty ? lab.country : 'Non précisé'} • ${lab.productCount} produit(s)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              setState(() => _selectedLab = lab.name);
              _refreshData();
              _tabController.animateTo(0);
            },
          ),
        );
      },
    );
  }

  Widget _buildIndicationAndEquivTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Toggle between Indication Search and International Equivalence
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.medical_information_rounded, size: 16),
              label: Text('Par Indication', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.public_rounded, size: 16),
              label: Text('Équiv. Étrangères', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_isIndicationMode},
          onSelectionChanged: (val) {
            setState(() {
              _isIndicationMode = val.first;
              _aiError = null;
            });
          },
        ),
        const SizedBox(height: 12),

        Text(
          _isIndicationMode
              ? 'Recherchez une pathologie ou indication (ex: "HTA", "Angine bactérienne", "Ulcère gastrique") pour obtenir les DCI recommandées et leurs spécialités disponibles en Algérie.'
              : 'Saisissez un nom commercial étranger / français (ex: "Doliprane", "Spasfon", "Kardégic", "Tahor") pour trouver sa DCI et ses équivalents MSPRH en Algérie.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _aiQueryController,
                onSubmitted: (_) => _runAiSearch(),
                decoration: InputDecoration(
                  hintText: _isIndicationMode
                      ? 'Ex: HTA, Infection urinaire, Asthme...'
                      : 'Ex: Doliprane, Spasfon, Kardégic...',
                  prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isAiLoading ? null : _runAiSearch,
              child: const Text('Rechercher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        if (_isAiLoading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Center(
            child: Text('Analyse Vidal IA & croisement avec la nomenclature DZ...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],

        if (_aiError != null) ...[
          const SizedBox(height: 14),
          Text(_aiError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],

        if (_isIndicationMode && _indicationResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final item in _indicationResults) ...[
            Builder(builder: (context) {
              final dci = item['dci']?.toString() ?? '';
              final dzEquivalents = AlgerianNomenclatureRepository.getEquivalentsForDci(dci).take(4).toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(dci, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryTeal)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['line_of_treatment']?.toString() ?? '',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item['therapeutic_class']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if ((item['usual_dosage']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Posologie : ${item['usual_dosage']}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                      ),
                    if ((item['key_precaution']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('⚠️ ${item['key_precaution']}', style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                      ),
                    if (dzEquivalents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Spécialités disponibles en Algérie :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: dzEquivalents.map((eq) {
                          return ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 14, color: AppTheme.primaryTeal),
                            label: Text('${eq.brand} ${eq.dosage}'.trim(), style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              widget.onAddDrug(eq);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],

        if (!_isIndicationMode && _internationalEquivResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_internationalEquivResult!['foreign_name']} → ${_internationalEquivResult!['dci']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryTeal),
                ),
                const SizedBox(height: 4),
                Text(
                  _internationalEquivResult!['pharmacological_class']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if ((_internationalEquivResult!['notes']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_internationalEquivResult!['notes'].toString(), style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Équivalents algériens MSPRH (${_internationalDzMatches.length}) :',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final eq in _internationalDzMatches.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildDrugTile(eq, isDark),
            ),
        ],
      ],
    );
  }
}
