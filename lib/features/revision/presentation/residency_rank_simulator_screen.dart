import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/residency_rank_simulator_model.dart';

class ResidencyRankSimulatorScreen extends StatefulWidget {
  const ResidencyRankSimulatorScreen({super.key});

  @override
  State<ResidencyRankSimulatorScreen> createState() =>
      _ResidencyRankSimulatorScreenState();
}

class _ResidencyRankSimulatorScreenState
    extends State<ResidencyRankSimulatorScreen> {
  String _selectedFaculty = 'Blida';
  double _fondamentalesScore = 13.5;
  double _medicaleScore = 14.5;
  double _chirurgicaleScore = 14.0;
  String _categoryFilter = 'Toutes';

  @override
  Widget build(BuildContext context) {
    final avg = ResidencyRankSimulatorData.computeWeightedAverage(
      sciencesFondamentales: _fondamentalesScore,
      pathologieMedicale: _medicaleScore,
      pathologieChirurgicale: _chirurgicaleScore,
    );
    final estRank = ResidencyRankSimulatorData.estimateRank(avg);

    final filtered = ResidencyRankSimulatorData.specialties.where((s) {
      if (_categoryFilter == 'Toutes') return true;
      return s.category == _categoryFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simulateur Classement & Spécialités', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Seuils Indicatifs Résidanat Algérie (Blida, Alger, Oran, Constantine)', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.heroNavyDecoration(radius: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PROJECTION CONCOURS', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.w900, fontSize: 11)),
                    DropdownButton<String>(
                      value: _selectedFaculty,
                      dropdownColor: AppTheme.clinicalNavy,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      items: ResidencyRankSimulatorData.faculties
                          .map((f) => DropdownMenuItem(value: f, child: Text('Fac : $f')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedFaculty = v ?? 'Blida'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('MOYENNE ESTIMÉE', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                        Text('${avg.toStringAsFixed(2)} / 20', style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Container(width: 1, height: 42, color: Colors.white24),
                    Column(
                      children: [
                        const Text('RANG INDICATIF', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                        Text('~$estRankᵉ', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.bentoCardDecoration(context, radius: 18),
            child: Column(
              children: [
                _scoreSlider('Sciences Fondamentales (Anat, Physio, Bio...)', _fondamentalesScore, (v) => setState(() => _fondamentalesScore = v)),
                _scoreSlider('Pathologie Médicale (Cardio, Pneumo, Pédiatrie...)', _medicaleScore, (v) => setState(() => _medicaleScore = v)),
                _scoreSlider('Pathologie Chirurgicale & Spécialités (Gynéco, Ortho...)', _chirurgicaleScore, (v) => setState(() => _chirurgicaleScore = v)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Toutes', 'Médicale', 'Chirurgicale', 'Biologique'].map((cat) {
                final sel = _categoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Colors.white : null)),
                    selected: sel,
                    selectedColor: AppTheme.primaryTeal,
                    onSelected: (_) => setState(() => _categoryFilter = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          ...filtered.map((spec) {
            final threshold = spec.thresholdForFaculty(_selectedFaculty);
            final status = spec.evaluateStatus(avg, _selectedFaculty);
            final diff = avg - threshold;
            final Color badgeColor;
            final String badgeText;
            switch (status) {
              case SpecialtyAccessibilityStatus.accessible:
                badgeColor = const Color(0xFF10B981);
                badgeText = 'Accessible (+${diff.toStringAsFixed(2)})';
                break;
              case SpecialtyAccessibilityStatus.competitive:
                badgeColor = const Color(0xFFF59E0B);
                badgeText = 'Zone charnière (${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(2)})';
                break;
              case SpecialtyAccessibilityStatus.toConsolidate:
                badgeColor = const Color(0xFFEF4444);
                badgeText = 'Manque ${(-diff).toStringAsFixed(2)} pts';
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                title: Text(spec.specialtyName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: Text('${spec.category} • Seuil $_selectedFaculty : ${threshold.toStringAsFixed(2)}/20 (Rang ~${spec.typicalClosingRank})', style: const TextStyle(fontSize: 11.5)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badgeText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _scoreSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            Text('${value.toStringAsFixed(2)} / 20', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
          ],
        ),
        Slider(
          value: value,
          min: 6.0,
          max: 19.5,
          divisions: 54,
          activeColor: AppTheme.primaryTeal,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
