import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/pse_calculator_model.dart';

class PseCalculatorScreen extends StatefulWidget {
  final String? initialDrugId;
  const PseCalculatorScreen({super.key, this.initialDrugId});

  @override
  State<PseCalculatorScreen> createState() => _PseCalculatorScreenState();
}

class _PseCalculatorScreenState extends State<PseCalculatorScreen> {
  late PseDrugProtocol _selectedDrug;
  late PseDilutionPreset _selectedDilution;
  double _weightKg = 70.0;
  double _doseValue = 0.20;
  bool _reverseMode = false; // false: Dose -> ml/h, true: ml/h -> Dose
  double _manualFlowMlH = 5.0;

  @override
  void initState() {
    super.initState();
    final protocols = PseProtocolsCatalog.allProtocols;
    _selectedDrug = protocols.firstWhere(
      (p) => p.id == widget.initialDrugId,
      orElse: () => protocols.first,
    );
    _selectedDilution = _selectedDrug.dilutions.first;
    _doseValue = _selectedDrug.defaultDose;
  }

  void _selectDrug(PseDrugProtocol drug) {
    setState(() {
      _selectedDrug = drug;
      _selectedDilution = drug.dilutions.first;
      _doseValue = drug.defaultDose;
      _manualFlowMlH = drug.calculateFlowRateMlPerHour(
        doseValue: _doseValue,
        weightKg: _weightKg,
        dilution: _selectedDilution,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calculatedFlow = _selectedDrug.calculateFlowRateMlPerHour(
      doseValue: _doseValue,
      weightKg: _weightKg,
      dilution: _selectedDilution,
    );
    final deliveredDose = _selectedDrug.calculateDeliveredDose(
      flowRateMlPerHour: _manualFlowMlH,
      weightKg: _weightKg,
      dilution: _selectedDilution,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculateur PSE & Dilutions d\'Urgence',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Pousse-Seringue Électrique • Garde & Réanimation Algérie',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sélecteur horizontal des drogues vasoactives / urgences
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: PseProtocolsCatalog.allProtocols.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final drug = PseProtocolsCatalog.allProtocols[index];
                final selected = drug.id == _selectedDrug.id;
                return ChoiceChip(
                  selected: selected,
                  label: Text(
                    drug.dciName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppTheme.clinicalNavy),
                    ),
                  ),
                  selectedColor: AppTheme.primaryTeal,
                  onSelected: (_) => _selectDrug(drug),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Carte d'identité de l'ampoule & dilution
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.bentoCardDecoration(context, radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medication_liquid_rounded,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDrug.dciName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            '${_selectedDrug.commercialNamesDz} • ${_selectedDrug.ampoulePresentation}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'PROTOCOLE DE DILUTION EN SERINGUE :',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedDrug.dilutions.map((dil) {
                  final isSel = dil.id == _selectedDilution.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedDilution = dil),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? AppTheme.primaryTeal
                                : Colors.grey.withValues(alpha: 0.25),
                            width: isSel ? 1.6 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSel
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: isSel ? AppTheme.primaryTeal : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dil.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text(
                                'Préparation : ${dil.preparationInstruction}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 15, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Voie d\'abord : ${_selectedDrug.venousAccessRequirement}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Écran Digital du Pousse-Seringue Électrique
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.heroNavyDecoration(radius: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.speed_rounded, color: Color(0xFF2DD4BF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'MONITEUR PSE EN DIRECT',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    SegmentedButton<bool>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                      segments: const [
                        ButtonSegment(value: false, label: Text('Dose ➔ ml/h', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: true, label: Text('ml/h ➔ Dose', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_reverseMode},
                      onSelectionChanged: (s) => setState(() => _reverseMode = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'VITESSE PSE À RÉGLER',
                          style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_reverseMode ? _manualFlowMlH : calculatedFlow).toStringAsFixed(1)} ml/h',
                          style: const TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 48, color: Colors.white24),
                    Column(
                      children: [
                        const Text(
                          'POSOLOGIE DÉLIVRÉE',
                          style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_reverseMode ? deliveredDose : _doseValue).toStringAsFixed(2)} ${_selectedDrug.doseUnit.label}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Curseurs Poids & Dose / Débit
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.bentoCardDecoration(context, radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedDrug.doseUnit.isWeightDependent) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Poids du patient (kg)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_weightKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _weightKg.clamp(5.0, 140.0),
                    min: 5.0,
                    max: 140.0,
                    divisions: 135,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (v) => setState(() => _weightKg = v),
                  ),
                  const Divider(height: 20),
                ],
                if (!_reverseMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Posologie cible (${_selectedDrug.doseUnit.label})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        '${_doseValue.toStringAsFixed(2)} ${_selectedDrug.doseUnit.label}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryTeal,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _doseValue.clamp(_selectedDrug.minDose, _selectedDrug.maxDose),
                    min: _selectedDrug.minDose,
                    max: _selectedDrug.maxDose,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (v) => setState(() => _doseValue = v),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vitesse affichée sur le PSE (ml/h)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        '${_manualFlowMlH.toStringAsFixed(1)} ml/h',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryTeal,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _manualFlowMlH.clamp(0.5, 40.0),
                    min: 0.5,
                    max: 40.0,
                    divisions: 79,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (v) => setState(() => _manualFlowMlH = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Alertes de sécurité & Indications
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.bentoCardDecoration(context, radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Vigilance & Sécurité de Garde',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._selectedDrug.redFlagsAndPrecautions.map(
                  (flag) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        Expanded(child: Text(flag, style: const TextStyle(fontSize: 12.5))),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                const Text(
                  'Indications principales :',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ..._selectedDrug.indications.map(
                  (ind) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('✓ $ind', style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
