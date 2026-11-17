import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/abg_ecg_analyzer_model.dart';

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

  // ECG Controllers
  double _largeBoxes = 4.0;
  double _qtMs = 380.0;
  bool _isFemale = false;
  final Set<int> _checkedEcgSteps = {};

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
              'Gazométrie Artérielle, Trou Anionique, Winter & QTc',
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

  Widget _buildEcgTab() {
    final hr = EcgAnalysisHelper.computeHeartRateFromLargeBoxes(_largeBoxes);
    final qtcBazett = EcgAnalysisHelper.computeQtcBazett(qtMs: _qtMs, heartRateBpm: hr);
    final qtcFridericia = EcgAnalysisHelper.computeQtcFridericia(qtMs: _qtMs, heartRateBpm: hr);
    final qtcWarning = EcgAnalysisHelper.interpretQtc(qtcBazett, isFemale: _isFemale);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                  Column(
                    children: [
                      const Text('FRÉQUENCE', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                      Text('${hr.toStringAsFixed(0)} bpm', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('QTc BAZETT', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                      Text(
                        '${qtcBazett.toStringAsFixed(0)} ms',
                        style: TextStyle(
                          color: qtcBazett >= 500 ? const Color(0xFFF87171) : const Color(0xFF2DD4BF),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('FRIDERICIA', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                      Text('${qtcFridericia.toStringAsFixed(0)} ms', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(qtcWarning, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grands carreaux entre 2 R (5 mm)', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_largeBoxes.toStringAsFixed(1)} carreaux', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
                ],
              ),
              Slider(
                value: _largeBoxes,
                min: 1.5,
                max: 10.0,
                divisions: 85,
                activeColor: AppTheme.primaryTeal,
                onChanged: (v) => setState(() => _largeBoxes = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Intervalle QT mesuré (ms)', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_qtMs.toStringAsFixed(0)} ms', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
                ],
              ),
              Slider(
                value: _qtMs,
                min: 260,
                max: 600,
                divisions: 34,
                activeColor: AppTheme.primaryTeal,
                onChanged: (v) => setState(() => _qtMs = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Patiente de sexe féminin (seuil QTc 460 ms)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _isFemale,
                onChanged: (v) => setState(() => _isFemale = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'LECTURE SYSTÉMATISÉE EN 7 ÉTAPES (CHECK-LIST) :',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal),
        ),
        const SizedBox(height: 8),
        ...EcgAnalysisHelper.sevenStepsChecklist.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final checked = _checkedEcgSteps.contains(idx);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: CheckboxListTile(
              value: checked,
              activeColor: AppTheme.primaryTeal,
              title: Text(item['step']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              subtitle: Text(item['detail']!, style: const TextStyle(fontSize: 12.5)),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _checkedEcgSteps.add(idx);
                  } else {
                    _checkedEcgSteps.remove(idx);
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }
}
