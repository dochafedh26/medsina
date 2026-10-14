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
            'Vérifier les coordonnées d\'urgence : Réanimation de garde, SAMU 115, Laboratoire central, Banque du sang (CTS).',
            'Tester le chariot d\'urgence du service : Défibrillateur opérationnel, laryngoscope, ampoules d\'Adrénaline disponibles.',
            'Vérifier les bilans biologiques en attente des admissions de fin d\'après-midi.',
            'Identifier les patients à surveiller étroitement (sepsis, détresse respiratoire, post-op immédiat).',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '📋 Règle de Rédaction d\'Ordonnance Conforme (MSPRH)',
          Icons.description_rounded,
          AppTheme.accentCyan,
          [
            'Identité complète : Nom, prénom, âge, poids (indispensable chez l\'enfant et l\'insuffisant rénal).',
            'Date du jour et signature lisible avec cachet médical obligatoire.',
            'Dénomination Commune Internationale (DCI) recommandée — la spécialité commerciale entre parenthèses.',
            'Posologie explicite : dose, voie d\'administration, rythme des prises et durée exacte du traitement.',
            'Mention « Ne pas dépasser » pour les antalgiques de palier 1 et 2.',
            'En pédiatrie : toujours indiquer le poids en kg et calculer la dose mg/kg/j.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '⚡ CAT Hypoglycémie Sévère (Glycémie < 0,5 g/L)',
          Icons.bolt_rounded,
          const Color(0xFFF59E0B),
          [
            'Confirmer immédiatement par dextrostix capillaire.',
            'Si voie veineuse disponible : G30% 50 mL IV direct (ou G10% 200 mL en 15 min).',
            'Si pas de voie veineuse : Glucagon 1 mg SC ou IM (contre-indiqué si hépatopathie sévère).',
            'Resucrage oral dès que la conscience est récupérée : jus de fruit + biscuit.',
            'Surveillance glycémique toutes les 30 min pendant 2 heures. Rechercher et traiter la cause.',
            'Hospitaliser si : sulfamides (hypoglycémie prolongée), récidive, sujet isolé, âge > 75 ans.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🫁 CAT Détresse Respiratoire Aiguë aux Urgences',
          Icons.air_rounded,
          const Color(0xFF0284C7),
          [
            'Appel immédiat réanimateur si SpO₂ < 88% sous O₂ haute concentration ou FR > 35/min.',
            'Installer en position demi-assise (45°), O₂ au masque haute concentration 12–15 L/min.',
            'Monitoring : SpO₂, FC, FR, PA, ECG, température.',
            'Bilan urgent : NFS, CRP, PCT, D-Dimères, BNP, GDS artériel, radio thorax.',
            'Éliminer les diagnostics immédiats : EP (Wells + D-Dimères), OAP (BNP + crépitants), pneumothorax (décompression si instable).',
            'En cas d\'OAP : Furosémide 40–80 mg IV + dérivés nitrés si PAS > 110 mmHg + VNI si nécessaire.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🫀 CAT Douleur Thoracique aux Urgences',
          Icons.favorite_border_rounded,
          const Color(0xFFEF4444),
          [
            'ECG 18 dérivations en moins de 10 minutes — recherche sus-décalage ST, Wellens, De Winter.',
            'Sus-décalage ST confirmé (SCA ST+) : alerte cardiologie, aspirine 500 mg PO + héparine selon protocole, préparation salle de cathétérisme ou fibrinolyse.',
            'Troponines hs à H0 et H3 pour les SCA sans sus-décalage.',
            'Bilan systématique : NFS, TP-TCA, ionogramme, créatinine, radio thorax, lipase si douleur épigastrique associée.',
            'Ne jamais prescrire de morphine d\'emblée sans ECG et bilan complet (risque de masquer une urgence chirurgicale).',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🔴 Choc Septique — Protocole « Sepsis 6 » Heure 1',
          Icons.emergency_rounded,
          const Color(0xFFDC2626),
          [
            '1. PRÉLEVER : Hémocultures (2 paires) et bilan infectieux AVANT les antibiotiques.',
            '2. OXYGÉNER : O₂ pour objectif SpO₂ ≥ 95% — IOT si GCS < 8 ou épuisement respiratoire.',
            '3. REMPLIR : Cristalloïdes 30 mL/kg en 30–60 min (NaCl 0,9% ou Ringer Lactate).',
            '4. ANTIBIOTIQUES : Administration large spectre dans l\'heure qui suit (Tazocilline ± Amikacine ou Carbapénème si terrain grave).',
            '5. VASOPRESSEURS : Noradrénaline si PAS < 65 mmHg malgré remplissage.',
            '6. MONITORER : Lactates, diurèse horaire (sonde urinaire), réponse au remplissage.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '⚠️ Fiche Réflexe : Agitation Aiguë de l\'Adulte en Garde',
          Icons.warning_rounded,
          const Color(0xFFEF4444),
          [
            'Priorité 1 : Éliminer une cause organique (Hypoglycémie capillaire immédiate ! Hypoxie, Globe urinaire, Fécalome sujet âgé, Intoxication CO/toxique).',
            'Priorité 2 : Mesures non médicamenteuses de désescalade verbale, environnement calme, retirer les objets dangereux.',
            'Priorité 3 : Sédatifs uniquement si danger imminent (Hydroxyzine 50–100 mg ou Cyamémazine 25–50 mg PO ou IM selon tolérance cardio-respiratoire).',
            'Éviter les benzodiazépines chez le sujet âgé ou BPCO (risque de dépression respiratoire majeure).',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '💊 Antidotes d\'Urgence à Connaître par Cœur',
          Icons.medication_liquid_rounded,
          const Color(0xFF7C3AED),
          [
            'Paracétamol : N-acétylcystéine (NAC) IV — efficace jusqu\'à H16, indispensable si paracétamolémie toxique.',
            'Benzodiazépines : Flumazénil 0,2 mg IV (attention : demi-vie courte, re-sédation possible).',
            'Opiacés / Morphine : Naloxone 0,4 mg IV ou SC, renouvelable toutes les 2–3 min.',
            'Organophosphorés (insecticides) : Atropine titrations IV fortes doses + Pralidoxime (2-PAM) si disponible.',
            'AVK (Sintrom, Coumadine) : PPSB (CCP) IV si hémorragie grave, Vitamine K1 IV si moins urgent.',
            'Héparine non fractionnée : Protamine sulfate 1 mg pour 100 UI d\'héparine.',
            'Digitaliques (Digoxine) : Fragments Fab anti-digitaliques (DigiFab) — indication stricte arythmie grave.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🧪 Valeurs Biologiques d\'Alerte Absolue',
          Icons.biotech_rounded,
          const Color(0xFF0D9488),
          [
            'Kaliémie < 2,5 mmol/L ou > 6,5 mmol/L → ECG urgent + correction immédiate.',
            'Natrémie < 120 mmol/L ou > 155 mmol/L → correction lente (risque de myélinolyse centropontine si trop rapide).',
            'Glycémie capillaire < 0,5 g/L → cf. CAT hypoglycémie sévère.',
            'pH artériel < 7,20 ou > 7,55 → GDS urgence, avis réanimateur.',
            'Plaquettes < 20 000/mm³ → risque hémorragique spontané, transfusion à discuter.',
            'TP < 30% avec saignement actif → PFC en urgence.',
            'Créatinine > 500 µmol/L aiguë + anurie → avis néphrologie / dialyse.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🤰 Urgences Obstétricales en Garde',
          Icons.pregnant_woman_rounded,
          const Color(0xFFEC4899),
          [
            'Pré-éclampsie sévère : PAS ≥ 160 ou PAD ≥ 110 mmHg + signes neurologiques → Nicardipine IV (ou Labétalol) + MgSO₄ 4 g IV lent, extraction fœtale en urgence.',
            'Hémorragie du post-partum (HPP) : Ocytocine 5–10 UI IV ou IM, massage utérin, sac de recueil, appel équipe obstétricale. Transfusion si Hb < 7 g/dL.',
            'Éclampsie (crise convulsive) : MgSO₄ 4 g IV sur 15 min + entretien 1–2 g/h. Antidote : Gluconate de calcium 10 mL IV si surdosage.',
            'Ne jamais prescrire AINS ou Aspirine en 3e trimestre (fermeture prématurée canal artériel).',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '👶 Urgences Pédiatriques — Règles de Calcul de Dose',
          Icons.child_care_rounded,
          const Color(0xFF2563EB),
          [
            'Paracétamol : 15 mg/kg/prise, max 60 mg/kg/j, toutes les 6h.',
            'Ibuprofène : 10 mg/kg/prise, max 30 mg/kg/j, toutes les 8h (CI < 3 mois, déshydratation, varicelle).',
            'Amoxicilline (infection courante) : 50 mg/kg/j en 2–3 prises. Angine : 50 mg/kg/j × 6 jours.',
            'Salbutamol nébulisé : 0,15 mg/kg (min 2,5 mg, max 5 mg) toutes les 20 min si asthme aigu grave.',
            'Soluté de réhydratation orale (SRO) : 5–10 mL/kg après chaque selle liquide, ou 50 mL/kg sur 4h si déshydratation modérée.',
            'Règle de poids rapide : Poids (kg) = (âge × 2) + 8 pour 1–10 ans (estimation d\'urgence).',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🧠 Coma — Prise en Charge Initiale Standardisée',
          Icons.psychology_rounded,
          const Color(0xFF6D28D9),
          [
            'A-B-C-D-E : Airway (luxation mandibule, canule Guédel), Breathing (O₂), Circulation (VVP, TA), Disability (Glasgow, pupilles, glycémie), Exposure (température, toxiques).',
            'Glycémie capillaire immédiate — Si < 0,5 g/L : G30% IV. Si alcoolisme : Thiamine 100 mg IV AVANT le glucose.',
            'Glasgow ≤ 8 : Protection des voies aériennes, avis réanimateur pour intubation.',
            'Pupilles fixes mydriatiques bilatérales : engagement cérébral → scanner cérébral en urgence extrême.',
            'Naloxone si suspicion opiacés (myosis serré + bradypnée + contexte).',
            'Bilan standard : Glycémie, ionogramme, urée, créatinine, NFS, GDS, toxiques, ECG, scanner cérébral.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🔥 Brûlures — Classification et Réanimation Initiale',
          Icons.local_fire_department_rounded,
          const Color(0xFFEA580C),
          [
            'Calcul de la Surface Corporelle Brûlée (SCB) : Règle des 9 de Wallace (tête=9%, bras=9% chacun, jambe=18% chacune, tronc ant.=18%, tronc post.=18%, périnée=1%).',
            'Brûlure grave : SCB ≥ 20% adulte, ≥ 10% enfant/sujet âgé, ou atteinte zones fonctionnelles (face, mains, périnée).',
            'Réanimation hydrique (Parkland) : 4 mL × kg × % SCB en 24h (moitié dans les 8 premières heures, moitié dans les 16 suivantes).',
            'Analgésie : Morphine titrée IV. Ne jamais appliquer de glace (aggrave la vasoconstriction).',
            'Refroidissement précoce : eau tiède 15–25°C, 15 minutes, dans les 30 premières minutes.',
            'Transfert en centre de brûlés si : SCB > 10%, brûlures profondes, faces/mains/périnée, inhalation de fumée.',
          ],
        ),
        const SizedBox(height: 14),
        _buildMementoCard(
          '🦂 CAT Envenimation Scorpionique (Algérie)',
          Icons.bug_report_rounded,
          const Color(0xFF059669),
          [
            'Classe I (Piqûre locale, asymptomatique) : Surveillance 4h, antalgiques, pas d\'antivenin.',
            'Classe II (Signes généraux modérés : sudation, priapisme, agitation) : Hospitalisation, Prazosine 0,25–0,5 mg sublingual + surveillance continue.',
            'Classe III (Choc, OAP, coma, convulsions) : Réanimation, Dobutamine si choc cardiogénique, VNI ou IOT, Sérothérapie anti-scorpionique IPA.',
            'Antalgiques de première ligne : Paracétamol IV + infiltration locale de Lidocaïne 2% au site de piqûre.',
            'Ne jamais prescrire de morphine dans le choc scorpionique (aggrave l\'instabilité hémodynamique).',
            'Signalement obligatoire au SEMEP et fiche de toxicovigilance IPA.',
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
