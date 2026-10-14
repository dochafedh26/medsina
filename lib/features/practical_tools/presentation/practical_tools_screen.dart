import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/lab_value_model.dart';

class PracticalToolsScreen extends StatefulWidget {
  const PracticalToolsScreen({super.key});

  @override
  State<PracticalToolsScreen> createState() => _PracticalToolsScreenState();
}

class _PracticalToolsScreenState extends State<PracticalToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _labSearch = '';
  final List<LabValue> _allLabs = PracticalToolsRepository.getLabValues();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              Tab(icon: Icon(Icons.biotech_rounded), text: 'Normes Biologiques'),
              Tab(icon: Icon(Icons.nightlight_round), text: 'Mémento de Garde'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLabValuesTab(),
              _buildOnCallTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabValuesTab() {
    final filtered = _allLabs.where((lab) {
      final q = _labSearch.toLowerCase();
      return lab.name.toLowerCase().contains(q) ||
          lab.category.toLowerCase().contains(q) ||
          lab.highInterpretation.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un examen biologique (ex: potassium, sodium, CRP)...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _labSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _labSearch = ''),
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _labSearch = val),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final lab = filtered[index];
              return _LabValueCard(lab: lab);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOnCallTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMementoCard(
          '🚨 Checklist de Début de Garde Hospitalière',
          Icons.checklist_rounded,
          AppTheme.primaryTeal,
          [
            'Prendre les transmissions orales et écrites du médecin sortant (patients instables en priorité).',
            'Vérifier les coordonnées d\'urgence : Réanimation de garde, SAMU, Laboratoire central, Banque du sang (CTS).',
            'Tester le chariot d\'urgence du service : Défibrillateur opérationnel, laryngoscope, ampoules d\'Adrénaline disponibles.',
            'Vérifier les bilans en attente des admissions de fin d\'après-midi.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '📋 Règle de Rédaction d\'Ordonnance Conforme',
          Icons.description_rounded,
          AppTheme.accentCyan,
          [
            'Nom, prénom, âge, poids (indispensable chez l\'enfant et l\'insuffisant rénal).',
            'Date du jour et signature lisible avec cachet médical.',
            'Dénomination Commune Internationale (DCI) recommandée.',
            'Posologie explicite, voie d\'administration, rythme des prises et durée exacte du traitement.',
            'Mention "Ne pas dépasser" pour les antalgiques de palier 1 et 2.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '⚠️ Fiche Réflexe : Agitation Aiguë de l\'Adulte en Garde',
          Icons.warning_rounded,
          const Color(0xFFEF4444),
          [
            'Priorité 1 : Éliminer une cause organique d\'extrême urgence (Hypoglycémie capillaire immédiate ! Hypoxie, Globe urinaire fécalome chez le sujet âgé, Intoxication CO/toxique).',
            'Priorité 2 : Mesures non médicamenteuses de désescalade verbale, environnement calme, retirer les objets dangereux.',
            'Priorité 3 : Sédatifs uniquement si danger imminent (Hydroxyzine 50-100 mg ou Cyamémazine 25-50 mg PO ou IM selon tolérance cardio-respiratoire).',
          ],
        ),
      ],
    );
  }

  Widget _buildMementoCard(String title, IconData icon, Color color, List<String> points) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                      Expanded(
                        child: Text(p, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _LabValueCard extends StatefulWidget {
  final LabValue lab;
  const _LabValueCard({required this.lab});

  @override
  State<_LabValueCard> createState() => _LabValueCardState();
}

class _LabValueCardState extends State<_LabValueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lab.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lab.category,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${lab.normalRange} ${lab.unit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: AppTheme.primaryDarkTeal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // High interpretation
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔺 Si Élevé : ${lab.highInterpretation}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.35),
                ),
              ),

              // Low interpretation
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔻 Si Bas : ${lab.lowInterpretation}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),

              if (lab.clinicalNotes.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...lab.clinicalNotes.map((n) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('💡 $n', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
