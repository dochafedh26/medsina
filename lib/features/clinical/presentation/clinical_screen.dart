import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/clinical_bloc.dart';
import '../bloc/clinical_event.dart';
import '../bloc/clinical_state.dart';
import '../models/cat_protocol_model.dart';
import '../models/clinical_calculator_model.dart';

class ClinicalScreen extends StatefulWidget {
  const ClinicalScreen({super.key});

  @override
  State<ClinicalScreen> createState() => _ClinicalScreenState();
}

class _ClinicalScreenState extends State<ClinicalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<ClinicalBloc>().add(LoadClinicalDataEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryTeal,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.primaryTeal,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [
              Tab(
                icon: Icon(Icons.emergency_rounded),
                text: 'Conduites à Tenir (CAT) & Protocoles',
              ),
              Tab(
                icon: Icon(Icons.calculate_rounded),
                text: 'Scores & Calculateurs Cliniques',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ProtocolsTab(),
              _CalculatorsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtocolsTab extends StatelessWidget {
  const _ProtocolsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClinicalBloc, ClinicalState>(
      builder: (context, state) {
        if (state.status == ClinicalStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Search & Filter header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une urgence, symptôme, maladie...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => context.read<ClinicalBloc>().add(const SearchProtocolsEvent('')),
                            )
                          : null,
                    ),
                    onChanged: (val) => context.read<ClinicalBloc>().add(SearchProtocolsEvent(val)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.availableSpecialties.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final spec = state.availableSpecialties[index];
                        final isSelected = spec == state.selectedSpecialty;
                        return ChoiceChip(
                          label: Text(spec),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryTeal : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (_) => context.read<ClinicalBloc>().add(FilterSpecialtyEvent(spec)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Protocols List
            Expanded(
              child: state.filteredProtocols.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Aucun protocole ne correspond à votre recherche.'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.filteredProtocols.length,
                      itemBuilder: (context, index) {
                        final proto = state.filteredProtocols[index];
                        return _ProtocolCard(protocol: proto);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ProtocolCard extends StatefulWidget {
  final ClinicalProtocol protocol;
  const _ProtocolCard({required this.protocol});

  @override
  State<_ProtocolCard> createState() => _ProtocolCardState();
}

class _ProtocolCardState extends State<_ProtocolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.protocol;
    final isVital = p.urgencyLevel == 'Urgence Vitale';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVital ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.urgencyLevel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isVital ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        p.specialty,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              p.definition,
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
            ),

            if (_expanded) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),

              // Red flags
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Signes de Gravité / Red Flags',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626), fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...p.redFlags.map((rf) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                              Expanded(child: Text(rf, style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)))),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('Étapes de la Prise en Charge :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),

              ...p.steps.map((st) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkSurfaceElevated
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryTeal)),
                        const SizedBox(height: 4),
                        Text(st.content, style: const TextStyle(fontSize: 12)),
                        if (st.bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...st.bulletPoints.map((bp) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('  ✓ $bp', style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
                              )),
                        ],
                      ],
                    ),
                  )),

              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💊 Traitements Immédiats :', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 4),
                    ...p.treatments.map((t) => Text('• $t', style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Text(
                'Source : ${p.references}',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalculatorsTab extends StatefulWidget {
  const _CalculatorsTab();

  @override
  State<_CalculatorsTab> createState() => _CalculatorsTabState();
}

class _CalculatorsTabState extends State<_CalculatorsTab> {
  // Glasgow State
  int _gcsEye = 4;
  int _gcsVerbal = 5;
  int _gcsMotor = 6;

  // Wells PE State
  bool _wellsDvt = false;
  bool _wellsAltDiagnosis = true;
  bool _wellsHr = false;
  bool _wellsImmob = false;
  bool _wellsHistory = false;
  bool _wellsHemo = false;
  bool _wellsCancer = false;

  // Cockcroft State
  int _age = 65;
  double _weight = 70;
  double _creatinine = 90;
  bool _isFemale = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGlasgowCard(),
        const SizedBox(height: 16),
        _buildWellsPeCard(),
        const SizedBox(height: 16),
        _buildCockcroftCard(),
      ],
    );
  }

  Widget _buildGlasgowCard() {
    final res = ClinicalCalculators.calculateGlasgow(eye: _gcsEye, verbal: _gcsVerbal, motor: _gcsMotor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_rounded, color: AppTheme.primaryTeal),
                const SizedBox(width: 10),
                const Text('Score de Glasgow (GCS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                _buildScorePill(res.value.toString() + res.unit, res.severityColor),
              ],
            ),
            const SizedBox(height: 14),
            _buildDropdownRow('Ouverture des yeux (Y) :', _gcsEye, {
              4: '4 - Spontanée',
              3: '3 - Au bruit / ordre',
              2: '2 - À la douleur',
              1: '1 - Nulle',
            }, (val) => setState(() => _gcsEye = val!)),
            const SizedBox(height: 8),
            _buildDropdownRow('Réponse verbale (V) :', _gcsVerbal, {
              5: '5 - Orientée',
              4: '4 - Confuse',
              3: '3 - Inappropriée',
              2: '2 - Incompréhensible',
              1: '1 - Nulle',
            }, (val) => setState(() => _gcsVerbal = val!)),
            const SizedBox(height: 8),
            _buildDropdownRow('Réponse motrice (M) :', _gcsMotor, {
              6: '6 - Aux ordres',
              5: '5 - Orientée à la douleur',
              4: '4 - Retrait / Évitement',
              3: '3 - Décortication (Flexion)',
              2: '2 - Décérébration (Extension)',
              1: '1 - Nulle',
            }, (val) => setState(() => _gcsMotor = val!)),
            const SizedBox(height: 14),
            _buildResultBox(res),
          ],
        ),
      ),
    );
  }

  Widget _buildWellsPeCard() {
    final res = ClinicalCalculators.calculateWellsPE(
      signsDvt: _wellsDvt,
      altDiagnosisLessLikely: _wellsAltDiagnosis,
      heartRateOver100: _wellsHr,
      immobilizationOrSurgery: _wellsImmob,
      previousDvtPe: _wellsHistory,
      hemoptysis: _wellsHemo,
      activeCancer: _wellsCancer,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.air_rounded, color: AppTheme.accentCyan),
                const SizedBox(width: 10),
                const Text('Score de Wells — Embolie Pulmonaire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                _buildScorePill('${res.value} pts', res.severityColor),
              ],
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              dense: true,
              value: _wellsDvt,
              title: const Text('Signes cliniques de TVP (+3 pts)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsDvt = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              value: _wellsAltDiagnosis,
              title: const Text('Diagnostic alternatif moins probable qu\'une EP (+3 pts)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsAltDiagnosis = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              value: _wellsHr,
              title: const Text('Fréquence cardiaque > 100 bpm (+1.5 pt)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsHr = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              value: _wellsImmob,
              title: const Text('Immobilisation >= 3j ou chirurgie < 4 semaines (+1.5 pt)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsImmob = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              value: _wellsHistory,
              title: const Text('Antécédent personnel de TVP ou EP (+1.5 pt)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsHistory = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              value: _wellsHemo,
              title: const Text('Hémoptysie (+1 pt)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsHemo = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              value: _wellsCancer,
              title: const Text('Cancer actif ou sous traitement < 6 mois (+1 pt)', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _wellsCancer = v ?? false),
            ),
            const SizedBox(height: 12),
            _buildResultBox(res),
          ],
        ),
      ),
    );
  }

  Widget _buildCockcroftCard() {
    final res = ClinicalCalculators.calculateCockcroft(
      age: _age,
      weightKg: _weight,
      creatinineUmolL: _creatinine,
      isFemale: _isFemale,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop_rounded, color: AppTheme.medicalPurple),
                const SizedBox(width: 10),
                const Text('Clairance Cockcroft & Gault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                _buildScorePill('${res.value} ${res.unit}', res.severityColor),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _age.toString(),
                    decoration: const InputDecoration(labelText: 'Âge (années)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _age = int.tryParse(v) ?? _age),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _weight.toString(),
                    decoration: const InputDecoration(labelText: 'Poids (kg)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _weight = double.tryParse(v) ?? _weight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _creatinine.toString(),
                    decoration: const InputDecoration(labelText: 'Créatininémie (µmol/L)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _creatinine = double.tryParse(v) ?? _creatinine),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    initialValue: _isFemale,
                    decoration: const InputDecoration(labelText: 'Sexe'),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('Homme')),
                      DropdownMenuItem(value: true, child: Text('Femme')),
                    ],
                    onChanged: (v) => setState(() => _isFemale = v ?? false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildResultBox(res),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow(String label, int value, Map<int, String> options, ValueChanged<int?> onChanged) {
    return Row(
      children: [
        SizedBox(width: 180, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: options.entries
                .map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildScorePill(String text, String colorName) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);

    if (colorName == 'green') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (colorName == 'amber') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (colorName == 'red') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
    );
  }

  Widget _buildResultBox(CalculatorResult res) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(res.interpretation, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryDarkTeal)),
          const SizedBox(height: 4),
          Text(res.recommendation, style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}
