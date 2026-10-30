import 'package:flutter/material.dart';
import '../../data/models/externat_pedagogical_models.dart';
import '../../services/externat_pedagogy_service.dart';

class ExternatBedsideDialog extends StatefulWidget {
  final String moduleName;
  final String? initialSymptom;

  const ExternatBedsideDialog({
    super.key,
    required this.moduleName,
    this.initialSymptom,
  });

  static Future<void> show(BuildContext context, {required String moduleName, String? initialSymptom}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExternatBedsideDialog(
        moduleName: moduleName,
        initialSymptom: initialSymptom,
      ),
    );
  }

  @override
  State<ExternatBedsideDialog> createState() => _ExternatBedsideDialogState();
}

class _ExternatBedsideDialogState extends State<ExternatBedsideDialog> {
  final TextEditingController _symptomController = TextEditingController();
  bool _isLoading = false;
  BedsideGuidanceModel? _guidance;
  String? _errorMessage;

  final List<String> _quickSuggestions = [
    'Douleur thoracique aiguë',
    'Détresse respiratoire',
    'Syndrome méningé fébrile',
    'Ascite volumineuse',
    'Hémorragie digestive',
    'Déficit moteur brutal',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSymptom != null && widget.initialSymptom!.isNotEmpty) {
      _symptomController.text = widget.initialSymptom!;
      _fetchGuidance(widget.initialSymptom!);
    }
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _fetchGuidance(String symptom) async {
    if (symptom.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ExternatPedagogyService.generateBedsideGuidance(
        symptomOrTopic: symptom.trim(),
        moduleName: widget.moduleName,
      );
      if (mounted) {
        setState(() {
          _guidance = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Lit du Malade • Stage Pratique',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Guide d\'examen express • ${widget.moduleName}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search / Symptom Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _symptomController,
                    decoration: InputDecoration(
                      hintText: 'Symptôme ou cas (ex: ascite fébrile)...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (val) => _fetchGuidance(val),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : () => _fetchGuidance(_symptomController.text),
                  child: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ],
            ),
          ),

          // Suggestions chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _quickSuggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _symptomController.text = s;
                      _fetchGuidance(s);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _guidance == null
                    ? _buildPlaceholder(isDark)
                    : _buildGuidanceView(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorMessage != null ? Icons.error_outline_rounded : Icons.hotel_rounded,
              size: 48,
              color: _errorMessage != null ? Colors.red : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage != null ? 'Erreur de chargement' : 'Prêt pour le tour de salle ?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ??
                  'Indiquez le tableau clinique ou le symptôme du malade hospitalisé pour obtenir les questions d\'interrogatoire, gestes d\'examen et bilans urgents.',
              style: TextStyle(
                fontSize: 12,
                color: _errorMessage != null ? Colors.red : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceView(bool isDark) {
    final g = _guidance!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Interrogatoire Clé
        _buildSectionCard(
          title: '1. Interrogatoire au Lit du Malade',
          icon: Icons.record_voice_over_rounded,
          color: const Color(0xFF0284C7),
          items: g.questionsInterrogatoire,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 2. Examens Physiques Indispensables
        _buildSectionCard(
          title: '2. Gestes d\'Examen Physique à Réaliser',
          icon: Icons.health_and_safety_rounded,
          color: const Color(0xFF10B981),
          items: g.examensPhysiquesCles,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 3. Bilans d'Urgence
        _buildSectionCard(
          title: '3. Bilans Complémentaires de 1ère Intention',
          icon: Icons.science_rounded,
          color: const Color(0xFF8B5CF6),
          items: g.bilansUrgence,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 4. Drapeaux Rouges
        _buildSectionCard(
          title: '4. Drapeaux Rouges (Appeler le Résident de Garde) 🚨',
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
          items: g.drapeauxRouges,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // 5. Note Contexte Algérien
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pratique Hospitalière en Algérie : ${g.algerianContextNote}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.amber.shade200 : const Color(0xFF78350F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
