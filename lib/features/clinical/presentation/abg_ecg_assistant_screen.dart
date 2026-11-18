import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/abg_ecg_analyzer_model.dart';
import '../models/ecg_interpreter_model.dart';

class AbgEcgAssistantScreen extends StatefulWidget {
  final int initialTab;
  const AbgEcgAssistantScreen({super.key, this.initialTab = 0});

  @override
  State<AbgEcgAssistantScreen> createState() => _AbgEcgAssistantScreenState();
}

class _AbgEcgAssistantScreenState extends State<AbgEcgAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // GDS Controllers
  final _phCtrl = TextEditingController(text: '7.16');
  final _paco2Ctrl = TextEditingController(text: '24');
  final _hco3Ctrl = TextEditingController(text: '8.5');
  final _pao2Ctrl = TextEditingController(text: '96');
  final _fio2Ctrl = TextEditingController(text: '21');
  final _naCtrl = TextEditingController(text: '134');
  final _clCtrl = TextEditingController(text: '98');
  final _lactatesCtrl = TextEditingController(text: '2.6');
  AbgAnalysisResult? _abgResult;

  // ECG — mesures
  double _largeBoxes = 4.0;
  double _qtMs = 380.0;
  bool _isFemale = false;
  bool _standardCalibration = true;
  bool _prKnown = true;
  double _prMs = 160;
  double _qrsMs = 90;

  // ECG — rythme & conduction
  EcgAtrialActivity _atrial = EcgAtrialActivity.sinus;
  EcgRegularity _regularity = EcgRegularity.regular;
  EcgAvBlock _avBlock = EcgAvBlock.none;
  EcgBundleBranch _bundleBranch = EcgBundleBranch.none;

  // ECG — axe & morphologie
  bool _qrsPositiveInLeadI = true;
  bool _qrsPositiveInLeadAvf = true;
  bool _pathologicQ = false;
  bool _voltageKnown = false;
  double _sokolowSV1 = 10;
  double _sokolowRV6 = 12;

  // ECG — repolarisation
  EcgStFinding _stFinding = EcgStFinding.isoelectric;
  EcgTerritory _territory = EcgTerritory.none;
  double _stElevationMm = 1.0;
  bool _stTwoContiguous = true;
  EcgTWave _tWave = EcgTWave.normal;

  // ECG — contrôle technique
  bool _technicalChecked = true;
  bool _avrNegative = true;
  bool _rProgressionNormal = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _runAbgAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phCtrl.dispose();
    _paco2Ctrl.dispose();
    _hco3Ctrl.dispose();
    _pao2Ctrl.dispose();
    _fio2Ctrl.dispose();
    _naCtrl.dispose();
    _clCtrl.dispose();
    _lactatesCtrl.dispose();
    super.dispose();
  }

  void _runAbgAnalysis() {
    final ph = double.tryParse(_phCtrl.text.replaceAll(',', '.')) ?? 7.40;
    final paco2 = double.tryParse(_paco2Ctrl.text.replaceAll(',', '.')) ?? 40.0;
    final hco3 = double.tryParse(_hco3Ctrl.text.replaceAll(',', '.')) ?? 24.0;
    final pao2 = double.tryParse(_pao2Ctrl.text.replaceAll(',', '.')) ?? 90.0;
    final fio2 = double.tryParse(_fio2Ctrl.text.replaceAll(',', '.')) ?? 21.0;
    final na = double.tryParse(_naCtrl.text.replaceAll(',', '.'));
    final cl = double.tryParse(_clCtrl.text.replaceAll(',', '.'));
    final lactates = double.tryParse(_lactatesCtrl.text.replaceAll(',', '.'));

    setState(() {
      _abgResult = AbgAnalysisEngine.analyze(
        ph: ph,
        paco2: paco2,
        hco3: hco3,
        pao2: pao2,
        fio2Percent: fio2,
        na: na,
        cl: cl,
        lactates: lactates,
      );
    });
  }

  void _applyPreset(AbgPresetCase preset) {
    _phCtrl.text = preset.ph.toString();
    _paco2Ctrl.text = preset.paco2.toString();
    _hco3Ctrl.text = preset.hco3.toString();
    _pao2Ctrl.text = preset.pao2.toString();
    _fio2Ctrl.text = preset.fio2Percent.toString();
    _naCtrl.text = preset.na.toString();
    _clCtrl.text = preset.cl.toString();
    _lactatesCtrl.text = preset.lactates.toString();
    _runAbgAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interpréteur GDS & Assistant ECG',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'GDS, trou anionique, Winter • Lecture ECG 12 dérivations & QTc',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          tabs: const [
            Tab(icon: Icon(Icons.bloodtype_rounded, size: 18), text: 'Gaz du Sang (GDS)'),
            Tab(icon: Icon(Icons.monitor_heart_rounded, size: 18), text: 'Assistant ECG & QTc'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbgTab(),
          _buildEcgTab(),
        ],
      ),
    );
  }

  Widget _buildAbgTab() {
    final res = _abgResult;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'CAS CLINIQUES PRÉ-REMPLIS (TEST RAPIDE) :',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryTeal,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AbgAnalysisEngine.presetCases.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final preset = AbgAnalysisEngine.presetCases[idx];
              return ActionChip(
                avatar: const Icon(Icons.flash_on_rounded, size: 15, color: AppTheme.primaryTeal),
                label: Text(preset.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _applyPreset(preset),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Saisie des paramètres gazométriques
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _numField(_phCtrl, 'pH (7.35-7.45)')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_paco2Ctrl, 'PaCO2 (mmHg)')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_hco3Ctrl, 'HCO3- (mmol/L)')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_pao2Ctrl, 'PaO2 (mmHg)')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_fio2Ctrl, 'FiO2 (%)')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_lactatesCtrl, 'Lactates')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_naCtrl, 'Na+ (mmol/L)')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_clCtrl, 'Cl- (mmol/L)')),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Interpréter le Gaz du Sang', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _runAbgAnalysis,
                ),
              ),
            ],
          ),
        ),
        if (res != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.heroNavyDecoration(radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIAGNOSTIC GAZOMÉTRIQUE',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  res.primaryDisorder,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(res.compensationStatus, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Divider(color: Colors.white24, height: 22),
                Text(res.oxygenationStatus, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                if (res.anionGap != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Trou Anionique : ${res.anionGap!.toStringAsFixed(1)} mmol/L (Normale : 12 ± 4)',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
                if (res.expectedPaCo2Winter != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Formule de Winter : PaCO2 attendue = ${res.expectedPaCo2Winter!.toStringAsFixed(1)} ± 2 mmHg',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          if (res.clinicalAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: res.clinicalAlerts
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('🚨 $a', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (res.probableEtiologies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.bentoCardDecoration(context, radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Étiologies à évoquer en priorité :', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...res.probableEtiologies.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('• $e', style: const TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSubmitted: (_) => _runAbgAnalysis(),
    );
  }

  // ---------------------------------------------------------------------------
  // Onglet « Assistant ECG & QTc »
  // ---------------------------------------------------------------------------

  EcgFindings _ecgFindings(double heartRate) {
    return EcgFindings(
      heartRateBpm: heartRate,
      atrial: _atrial,
      regularity: _regularity,
      avBlock: _avBlock,
      prMs: _prKnown ? _prMs : null,
      qrsMs: _qrsMs,
      qrsPositiveInLeadI: _qrsPositiveInLeadI,
      qrsPositiveInLeadAvf: _qrsPositiveInLeadAvf,
      bundleBranch: _bundleBranch,
      sokolowSV1mm: _voltageKnown ? _sokolowSV1 : null,
      sokolowRV6mm: _voltageKnown ? _sokolowRV6 : null,
      pathologicQ: _pathologicQ,
      stFinding: _stFinding,
      territory: _territory,
      stElevationMm: _stElevationMm,
      stTwoContiguousLeads: _stTwoContiguous,
      tWave: _tWave,
      qtMs: _qtMs,
      isFemale: _isFemale,
      standardCalibration: _standardCalibration,
      avrNegative: _technicalChecked ? _avrNegative : null,
      rProgressionNormal: _technicalChecked ? _rProgressionNormal : null,
    );
  }

  Widget _buildEcgTab() {
    final hr = EcgAnalysisHelper.computeHeartRateFromLargeBoxes(_largeBoxes);
    final result = EcgInterpreter.interpret(_ecgFindings(hr));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEcgSummaryCard(result),
        const SizedBox(height: 14),
        _ecgCard(
          title: 'MESURES ET CALIBRAGE',
          children: [
            _ecgSlider(
              label: 'Grands carreaux entre 2 R (5 mm)',
              value: _largeBoxes,
              display: '${_largeBoxes.toStringAsFixed(1)} carreaux • '
                  'RR ≈ ${result.rrMs.toStringAsFixed(0)} ms',
              min: 1.5,
              max: 10,
              divisions: 85,
              onChanged: (v) => setState(() => _largeBoxes = v),
            ),
            _ecgSlider(
              label: 'Intervalle QT mesuré',
              value: _qtMs,
              display: '${_qtMs.toStringAsFixed(0)} ms • '
                  '${(_qtMs / EcgInterpreter.largeBoxMs).toStringAsFixed(1)} grands carreaux',
              min: 260,
              max: 600,
              divisions: 68,
              onChanged: (v) => setState(() => _qtMs = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Patiente de sexe féminin (seuil QTc 460 ms)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              value: _isFemale,
              onChanged: (v) => setState(() => _isFemale = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Calibrage standard (25 mm/s • 10 mm/mV)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              value: _standardCalibration,
              onChanged: (v) => setState(() => _standardCalibration = v),
            ),
            const Text(
              '1 petit carreau = 0,04 s (1 mm) • 1 grand carreau = 0,2 s (5 mm) • '
              '10 mm = 1 mV. Fréquence = 300 / nombre de grands carreaux.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ecgCard(
          title: 'RYTHME ET CONDUCTION',
          children: [
            _ecgDropdown<EcgAtrialActivity>(
              label: 'Activité auriculaire',
              value: _atrial,
              items: const {
                EcgAtrialActivity.sinus: 'Ondes P sinusales (P avant chaque QRS)',
                EcgAtrialActivity.fibrillation: 'Fibrillation : pas de P, ligne tremblée',
                EcgAtrialActivity.flutter: 'Flutter : dents de scie ≈ 300/min',
                EcgAtrialActivity.absent: 'Aucune onde P visible',
              },
              onChanged: (v) => setState(() => _atrial = v),
            ),
            const SizedBox(height: 8),
            _ecgDropdown<EcgRegularity>(
              label: 'Régularité des QRS',
              value: _regularity,
              items: const {
                EcgRegularity.regular: 'Régulier',
                EcgRegularity.irregularlyIrregular: 'Irrégulièrement irrégulier',
              },
              onChanged: (v) => setState(() => _regularity = v),
            ),
            const SizedBox(height: 8),
            _ecgDropdown<EcgAvBlock>(
              label: 'Bloc auriculo-ventriculaire',
              value: _avBlock,
              items: const {
                EcgAvBlock.none: 'Aucun',
                EcgAvBlock.firstDegree: '1er degré (PR > 200 ms constant)',
                EcgAvBlock.secondDegreeWenckebach: '2e degré — Wenckebach (PR s\'allonge)',
                EcgAvBlock.secondDegreeMobitz2: '2e degré — Mobitz 2 (PR constant, QRS manquant)',
                EcgAvBlock.thirdDegree: '3e degré (dissociation P/QRS)',
              },
              onChanged: (v) => setState(() => _avBlock = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Intervalle PR mesuré (début P → début QRS)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              value: _prKnown,
              onChanged: (v) => setState(() => _prKnown = v),
            ),
            if (_prKnown)
              _ecgSlider(
                label: 'PR',
                value: _prMs,
                display: '${_prMs.toStringAsFixed(0)} ms • '
                    '${(_prMs / EcgInterpreter.smallBoxMs).toStringAsFixed(1)} petits carreaux',
                min: 80,
                max: 320,
                divisions: 48,
                onChanged: (v) => setState(() => _prMs = v),
              ),
            _ecgSlider(
              label: 'Durée du QRS',
              value: _qrsMs,
              display: '${_qrsMs.toStringAsFixed(0)} ms • '
                  '${(_qrsMs / EcgInterpreter.smallBoxMs).toStringAsFixed(1)} petits carreaux',
              min: 60,
              max: 200,
              divisions: 28,
              onChanged: (v) => setState(() => _qrsMs = v),
            ),
            _ecgDropdown<EcgBundleBranch>(
              label: 'Morphologie du QRS',
              value: _bundleBranch,
              items: const {
                EcgBundleBranch.none: 'Fin, sans bloc de branche',
                EcgBundleBranch.left: 'BBDG — W en V1, M en V6',
                EcgBundleBranch.right: 'BBDD — rSR\' en V1, qRs en V6',
              },
              onChanged: (v) => setState(() => _bundleBranch = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ecgCard(
          title: 'AXE, MORPHOLOGIE ET REPOLARISATION',
          children: [
            _ecgSegmented<bool>(
              label: 'QRS en D1',
              value: _qrsPositiveInLeadI,
              segments: const {true: 'Positif', false: 'Négatif'},
              onChanged: (v) => setState(() => _qrsPositiveInLeadI = v),
            ),
            _ecgSegmented<bool>(
              label: 'QRS en aVF',
              value: _qrsPositiveInLeadAvf,
              segments: const {true: 'Positif', false: 'Négatif'},
              onChanged: (v) => setState(() => _qrsPositiveInLeadAvf = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Onde Q pathologique (> 0,2 mV et/ou > 0,04 s)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              value: _pathologicQ,
              onChanged: (v) => setState(() => _pathologicQ = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Voltages mesurés (S en V1, R en V6)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              value: _voltageKnown,
              onChanged: (v) => setState(() => _voltageKnown = v),
            ),
            if (_voltageKnown) ...[
              _ecgSlider(
                label: 'S en V1',
                value: _sokolowSV1,
                display: '${_sokolowSV1.toStringAsFixed(0)} mm',
                min: 0,
                max: 40,
                divisions: 40,
                onChanged: (v) => setState(() => _sokolowSV1 = v),
              ),
              _ecgSlider(
                label: 'R en V6',
                value: _sokolowRV6,
                display: '${_sokolowRV6.toStringAsFixed(0)} mm • '
                    'S(V1)+R(V6) = ${(_sokolowSV1 + _sokolowRV6).toStringAsFixed(0)} mm',
                min: 0,
                max: 40,
                divisions: 40,
                onChanged: (v) => setState(() => _sokolowRV6 = v),
              ),
            ],
            const SizedBox(height: 6),
            _ecgDropdown<EcgStFinding>(
              label: 'Segment ST',
              value: _stFinding,
              items: const {
                EcgStFinding.isoelectric: 'Isoélectrique (normal)',
                EcgStFinding.elevation: 'Sus-décalage',
                EcgStFinding.depression: 'Sous-décalage',
              },
              onChanged: (v) => setState(() => _stFinding = v),
            ),
            if (_stFinding != EcgStFinding.isoelectric) ...[
              const SizedBox(height: 8),
              _ecgDropdown<EcgTerritory>(
                label: 'Territoire',
                value: _territory,
                items: const {
                  EcgTerritory.none: 'Non précisé',
                  EcgTerritory.anterior: 'Antérieur (V1-V4)',
                  EcgTerritory.inferior: 'Inférieur (D2-D3-aVF)',
                  EcgTerritory.lateral: 'Latéral (D1-aVL-V5-V6)',
                },
                onChanged: (v) => setState(() => _territory = v),
              ),
              if (_stFinding == EcgStFinding.elevation)
                _ecgSlider(
                  label: 'Amplitude du sus-décalage',
                  value: _stElevationMm,
                  display: '${_stElevationMm.toStringAsFixed(1)} mm',
                  min: 0.5,
                  max: 6,
                  divisions: 55,
                  onChanged: (v) => setState(() => _stElevationMm = v),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '≥ 2 dérivations contiguës',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                value: _stTwoContiguous,
                onChanged: (v) => setState(() => _stTwoContiguous = v),
              ),
            ],
            const SizedBox(height: 6),
            _ecgDropdown<EcgTWave>(
              label: 'Onde T',
              value: _tWave,
              items: const {
                EcgTWave.normal: 'Normale',
                EcgTWave.peaked: 'Ample et pointue',
                EcgTWave.inverted: 'Inversée',
                EcgTWave.flat: 'Plate',
              },
              onChanged: (v) => setState(() => _tWave = v),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Contrôles techniques effectués',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'aVR toujours négatif • D1 toujours positif • R croissante de V1 à V6',
                style: TextStyle(fontSize: 11),
              ),
              value: _technicalChecked,
              onChanged: (v) => setState(() => _technicalChecked = v),
            ),
            if (_technicalChecked) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('aVR négatif', style: TextStyle(fontSize: 13)),
                value: _avrNegative,
                onChanged: (v) => setState(() => _avrNegative = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Progression de R normale (V1 → V6)', style: TextStyle(fontSize: 13)),
                value: _rProgressionNormal,
                onChanged: (v) => setState(() => _rProgressionNormal = v),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _buildEcgReport(result),
        const SizedBox(height: 18),
        _buildEcgReference(),
        const SizedBox(height: 24),
        const Text(
          'Aide à la lecture : ne remplace pas l\'avis d\'un médecin ni un ECG sur papier 12 dérivations.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEcgSummaryCard(EcgInterpretationResult result) {
    final qtc = result.qtcBazett;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.heroNavyDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CALCULATEUR FRÉQUENCE & QTc (BAZETT / FRIDERICIA)',
            style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ecgMetric(
                'FRÉQUENCE',
                '${result.rrMs > 0 ? (60000 / result.rrMs).toStringAsFixed(0) : 0} bpm',
                Colors.white,
              ),
              _ecgMetric(
                'QTc BAZETT',
                '${qtc.toStringAsFixed(0)} ms',
                qtc >= EcgInterpreter.qtcCriticalMs ? const Color(0xFFF87171) : const Color(0xFF2DD4BF),
              ),
              _ecgMetric(
                'FRIDERICIA',
                '${result.qtcFridericia.toStringAsFixed(0)} ms',
                const Color(0xFF38BDF8),
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _confidenceBadge(result.confidence),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isTechnicallyValid
                      ? 'Tracé techniquement valide.'
                      : 'Tracé douteux : ${result.technicalIssues.length} anomalie(s) technique(s).',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEcgReport(EcgInterpretationResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.bentoCardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LECTURE STRUCTURÉE',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.4),
          ),
          if (result.criticalAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _alertBox(
              title: 'URGENCE',
              items: result.criticalAlerts,
              color: const Color(0xFFDC2626),
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _alertBox(
              title: 'POINTS DE VIGILANCE',
              items: result.warnings,
              color: const Color(0xFFD97706),
            ),
          ],
          if (result.technicalIssues.isNotEmpty) ...[
            const SizedBox(height: 10),
            _alertBox(
              title: 'TRACÉ NON INTERPRÉTABLE',
              items: result.technicalIssues,
              color: const Color(0xFF7C3AED),
            ),
          ],
          const Divider(height: 22),
          ...result.sections.map(_ecgSectionTile),
          if (result.missingData.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Pour augmenter la confiance : renseigner ${result.missingData.join(', ')}.',
              style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ecgSectionTile(EcgReportSection section) {
    final color = _severityColor(section.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey),
                ),
                Text(
                  section.value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
                ),
                Text(section.detail, style: const TextStyle(fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcgReference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RÉFÉRENTIEL DE LECTURE',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal),
        ),
        const SizedBox(height: 8),
        _ecgExpansion(
          title: 'Valeurs normales (25 mm/s, 10 mm/mV)',
          child: Column(
            children: EcgReference.normalValues
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            row['param']!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['value']!, style: const TextStyle(fontSize: 12)),
                              Text(
                                row['box']!,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _ecgExpansion(
          title: 'Contrôles techniques avant lecture',
          child: Column(
            children: EcgReference.technicalChecks
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${row['check']!}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          row['detail']!,
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _ecgExpansion(
          title: 'Territoires et dérivations',
          child: Column(
            children: EcgReference.territories
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            row['territory']!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${row['leads']!} — ${row['artery']!}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _ecgExpansion(
          title: 'Chronologie de l\'infarctus',
          child: Column(
            children: EcgReference.infarctionTimeline
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            row['time']!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(row['sign']!, style: const TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _ecgExpansion(
          title: 'Blocs de branche (WiLLiaM / MaRRoW)',
          child: Column(
            children: EcgReference.bundleBranchPatterns
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['block']!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        Text(row['pattern']!, style: const TextStyle(fontSize: 11.5)),
                        Text(
                          row['note']!,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  // --- Petits composants de l'onglet ECG -------------------------------------

  Widget _ecgCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.bentoCardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _ecgSlider({
    required String label,
    required String display,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            Text(
              display,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryTeal, fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppTheme.primaryTeal,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _ecgDropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
              items: items.entries
                  .map(
                    (e) => DropdownMenuItem<T>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _ecgSegmented<T>({
    required String label,
    required T value,
    required Map<T, String> segments,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: segments.entries
                  .map((e) => ButtonSegment<T>(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12))))
                  .toList(),
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ecgMetric(String label, String value, Color color, {bool small = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
        Text(
          value,
          style: TextStyle(color: color, fontSize: small ? 20 : 24, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _confidenceBadge(EcgConfidence confidence) {
    final label = switch (confidence) {
      EcgConfidence.high => 'CONFIANCE ÉLEVÉE',
      EcgConfidence.medium => 'CONFIANCE MOYENNE',
      EcgConfidence.low => 'CONFIANCE FAIBLE',
    };
    final color = switch (confidence) {
      EcgConfidence.high => const Color(0xFF10B981),
      EcgConfidence.medium => const Color(0xFFF59E0B),
      EcgConfidence.low => const Color(0xFFF87171),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.4),
      ),
    );
  }

  Widget _alertBox({required String title, required List<String> items, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(item, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ecgExpansion({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [child],
      ),
    );
  }

  Color _severityColor(EcgSeverity severity) {
    return switch (severity) {
      EcgSeverity.normal => AppTheme.primaryTeal,
      EcgSeverity.warning => const Color(0xFFD97706),
      EcgSeverity.critical => const Color(0xFFDC2626),
    };
  }
}
