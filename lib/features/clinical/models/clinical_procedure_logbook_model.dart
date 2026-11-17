import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';

enum ProcedureAutonomyLevel {
  observed,
  assisted,
  autonomous,
}

extension ProcedureAutonomyLevelExtension on ProcedureAutonomyLevel {
  String get label {
    switch (this) {
      case ProcedureAutonomyLevel.observed:
        return 'Observé';
      case ProcedureAutonomyLevel.assisted:
        return 'Assisté';
      case ProcedureAutonomyLevel.autonomous:
        return 'Autonome ✓';
    }
  }
}

class ClinicalProcedureGuide extends Equatable {
  final String id;
  final String title;
  final String specialty;
  final int targetAutonomousCount;
  final List<String> indications;
  final List<String> contraindicationsRedFlags;
  final List<String> equipmentChecklist;
  final List<String> steps;
  final String postProcedureCare;

  const ClinicalProcedureGuide({
    required this.id,
    required this.title,
    required this.specialty,
    required this.targetAutonomousCount,
    required this.indications,
    required this.contraindicationsRedFlags,
    required this.equipmentChecklist,
    required this.steps,
    required this.postProcedureCare,
  });

  @override
  List<Object?> get props => [id, title, specialty];
}

class ProcedureLogEntry extends Equatable {
  final String id;
  final String procedureId;
  final String procedureTitle;
  final String hospitalService;
  final ProcedureAutonomyLevel autonomyLevel;
  final String? notes;
  final DateTime performedAt;

  const ProcedureLogEntry({
    required this.id,
    required this.procedureId,
    required this.procedureTitle,
    required this.hospitalService,
    required this.autonomyLevel,
    this.notes,
    required this.performedAt,
  });

  factory ProcedureLogEntry.fromJson(Map<String, dynamic> json) {
    final levelStr = json['autonomy_level']?.toString() ?? 'observed';
    final level = ProcedureAutonomyLevel.values.firstWhere(
      (e) => e.name == levelStr,
      orElse: () => ProcedureAutonomyLevel.observed,
    );
    return ProcedureLogEntry(
      id: json['id']?.toString() ?? '',
      procedureId: json['procedure_id']?.toString() ?? '',
      procedureTitle: json['procedure_title']?.toString() ?? '',
      hospitalService: json['hospital_service']?.toString() ?? 'Urgences',
      autonomyLevel: level,
      notes: json['notes']?.toString(),
      performedAt: json['performed_at'] != null
          ? DateTime.parse(json['performed_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'procedure_id': procedureId,
        'procedure_title': procedureTitle,
        'hospital_service': hospitalService,
        'autonomy_level': autonomyLevel.name,
        'notes': notes,
        'performed_at': performedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, procedureId, autonomyLevel, performedAt];
}

class ProcedureLogbookRepository {
  static const String _localKey = 'medsina_procedure_logs_v1';

  static const List<ClinicalProcedureGuide> guides = [
    ClinicalProcedureGuide(
      id: 'proc_pl',
      title: 'Ponction Lombaire (PL)',
      specialty: 'Neurologie / Urgences',
      targetAutonomousCount: 5,
      indications: [
        'Suspicion de méningite / méningo-encéphalite',
        'Hémorragie méningée à TDM normale',
        'Syndrome de Guillain-Barré (dissociation albumino-cytologique)',
      ],
      contraindicationsRedFlags: [
        'Signes d\'engagement cérébral ou déficit focal / GCS ≤ 11 (TDM cérébrale OBLIGATOIRE avant PL)',
        'Trouble sévère de l\'hémostase (Plaquettes < 50 000, TP < 50%, anticoagulation curative)',
        'Infection cutanée au point de ponction',
      ],
      equipmentChecklist: [
        'Aiguille à PL (20G ou 22G atraumatique pointe crayon si disponible)',
        'Gants stériles + masque + champ stérile + Bétadine / Chlorhexidine',
        '3 à 4 tubes stériles numérotés (Biochimie, Cyto-Bactério, Virologie/PCR)',
        'Pansement stérile + crème EMLA (si non urgent)',
      ],
      steps: [
        'Installer le patient assis dos rond ou en décubitus latéral chien de fusil.',
        'Repérer la ligne bi-iliaque (espace L4-L5) ou L3-L4 (toujours sous L2).',
        'Antisepsie chirurgicale en 4 temps et port des gants stériles.',
        'Introduire l\'aiguille biseau parallèle aux fibres, dirigée légèrement vers l\'ombilic.',
        'Recueillir 10 à 15 gouttes par tube, remettre le mandrin avant de retirer l\'aiguille.',
      ],
      postProcedureCare: 'Surveillance céphalées post-PL (syndrome post-PL : hydratation, décubitus, caféine, blood-patch si persistant).',
    ),
    ClinicalProcedureGuide(
      id: 'proc_ascite',
      title: 'Ponction d\'Ascite (Diagnostique & Évacuatrice)',
      specialty: 'Gastro-Entérologie / Urgences',
      targetAutonomousCount: 5,
      indications: [
        'Toute ascite inaugurale ou décompensation ascitique du cirrhotique (rechercher ISLA)',
        'Ascite tendue mal tolérée (dyspnée, hernie)',
      ],
      contraindicationsRedFlags: [
        'CIVD ou fibrinolyse clinique active',
        'Vessie pleine non sondée ou cicatrice chirurgicale / circulation collatérale au site',
      ],
      equipmentChecklist: [
        'Cathéter court 16G/18G ou aiguille IM (diagnostique)',
        'Tubulure + bocal de recueil (si évacuatrice)',
        'Tubes : Biochimie (Protides, Albumine), Cytologie (PNN > 250/mm³ = ISLA), Flacons hémoculture',
        'Flacons d\'Albumine 20% (si évacuation > 4-5 Litres)',
      ],
      steps: [
        'Repérer la Fosse Iliaque Gauche (union 1/3 externe - 2/3 internes de la ligne ombilic - EIAS gauche).',
        'Antisepsie stérile et ponction perpendiculaire (technique en Z recommandée).',
        'Prélever les tubes diagnostiques + ensemencer directement les flacons d\'hémoculture au lit du malade.',
      ],
      postProcedureCare: 'Si évacuation ≥ 5 L chez le cirrhotique : perfuser 8 g d\'Albumine par litre d\'ascite évacué.',
    ),
    ClinicalProcedureGuide(
      id: 'proc_gds',
      title: 'Gazométrie Artérielle Radiale (GDS)',
      specialty: 'Réanimation / Pneumologie',
      targetAutonomousCount: 10,
      indications: [
        'Détresse respiratoire aiguë, décompensation BPCO',
        'État de choc, acidocétose, trouble métabolique sévère',
      ],
      contraindicationsRedFlags: [
        'Test d\'Allen négatif (suppléance ulnaire insuffisante)',
        'Fistule artério-veineuse sur le membre, artériopathie sévère',
      ],
      equipmentChecklist: [
        'Seringue héparinée spécifique GDS avec bouchon hermétique',
        'Compresses stériles + antiseptique alcoolique + gants',
        'Glace / sachet de transport rapide au laboratoire (< 15 min)',
      ],
      steps: [
        'Réaliser le Test d\'Allen pour vérifier la perméabilité de l\'artère ulnaire.',
        'Mettre le poignet en légère hyperextension, palper le pouls radial entre 2 doigts.',
        'Ponctionner à 30-45° biseau vers le haut ; le sang pulse spontanément dans la seringue.',
        'Comprimer fermement pendant au moins 5 minutes (10 min si sous anticoagulants).',
      ],
      postProcedureCare: 'Chasser toute bulle d\'air de la seringue, noter la FiO2/débit O2 et la température du patient.',
    ),
    ClinicalProcedureGuide(
      id: 'proc_suture',
      title: 'Suture Cutanée aux Urgences & Anesthésie Locale',
      specialty: 'Chirurgie / Urgences',
      targetAutonomousCount: 8,
      indications: [
        'Plaie franche récente (< 6-12h selon localisation)',
      ],
      contraindicationsRedFlags: [
        'Morsure animale/humaine ou plaie souillée à haut risque infectieux (laisser ouverte / parage)',
        'Lésion tendineuse, nerveuse ou vasculaire sous-jacente (explorer AVANT de fermer)',
        'Lidocaïne adrénalinée CONTRE-INDIQUÉE aux extrémités (doigts, nez, oreilles, verge)',
      ],
      equipmentChecklist: [
        'Boîte de petite chirurgie (porte-aiguille, pince à griffes, ciseaux)',
        'Fil non résorbable (Monofilament 3/0 membres, 4/0 main, 5/0 ou 6/0 visage)',
        'Lidocaïne 1% ou 2% (dose max 4 mg/kg sans adrénaline)',
        'Sérum physiologique pour lavage abondant + Bétadine',
      ],
      steps: [
        'Tester la sensibilité et la motricité distale AVANT l\'anesthésie locale.',
        'Laver abondamment au sérum physiologique, anesthésier les berges en traçant.',
        'Réaliser des points simples séparés ou points de Blair-Donati si tension.',
        'Vérifier la vaccination antitétanique (VAT / SAT).',
      ],
      postProcedureCare: 'Ablation des fils : Visage J5, Cou/Cuir chevelu J7, Tronc/Membres sup J10, Membres inf/Dos J12-J14.',
    ),
    ClinicalProcedureGuide(
      id: 'proc_sv',
      title: 'Sondage Vésical Évacuateur',
      specialty: 'Urologie / Urgences',
      targetAutonomousCount: 5,
      indications: [
        'Rétention aiguë d\'urines (RAU)',
        'Monitorage strict de la diurèse en réanimation / état de choc',
      ],
      contraindicationsRedFlags: [
        'Urétrorragie sur traumatisme du bassin (rupture urétrale suspectée = KT sus-pubien !)',
        'Prostatite aiguë (préférer le cathéter sus-pubien)',
      ],
      equipmentChecklist: [
        'Sonde de Foley double courant CH 16 ou 18 (+ sac collecteur clos)',
        'Gel lubrifiant anesthésique (Xylocaïne gel) + seringue 10 ml d\'eau PPI (PAS de NaCl pour le ballonnet)',
        'Set de sondage stérile + gants stériles + antiseptique muqueux',
      ],
      steps: [
        'Antisepsie rigoureuse du méat et lubrification de l\'urètre.',
        'Introduire la sonde jusqu\'à la garde (obtenir un reflux franc d\'urine) AVANT de gonfler le ballonnet.',
        'Gonfler le ballonnet avec 10 ml d\'eau stérile PPI sans résistance ni douleur.',
        'Raccorder au sac collecteur en système clos et décalotter/recalotter le prépuce (risque paraphimosis).',
      ],
      postProcedureCare: 'Surveiller le syndrome de levée d\'obstacle (SLO) : compenser la polyurie si diurèse > 200 ml/h.',
    ),
  ];

  static Future<List<ProcedureLogEntry>> loadLogs() async {
    final list = <ProcedureLogEntry>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(ProcedureLogEntry.fromJson(item));
          }
        }
      }
    } catch (_) {}

    final uid = SupabaseService.currentUser?.id;
    if (SupabaseService.isInitialized && uid != null) {
      try {
        final rows = await SupabaseService.client
            .from('user_procedure_logs')
            .select()
            .eq('user_id', uid)
            .order('performed_at', ascending: false);
        final existingIds = list.map((e) => e.id).toSet();
        for (final r in rows) {
          final entry = ProcedureLogEntry.fromJson(Map<String, dynamic>.from(r));
          if (!existingIds.contains(entry.id)) {
            list.add(entry);
          }
        }
      } catch (_) {}
    }
    list.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return list;
  }

  static Future<void> addLog(ProcedureLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    final existing = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    existing.insert(0, entry.toJson());
    await prefs.setString(_localKey, jsonEncode(existing));

    final uid = SupabaseService.currentUser?.id;
    if (SupabaseService.isInitialized && uid != null) {
      try {
        await SupabaseService.client.from('user_procedure_logs').upsert({
          ...entry.toJson(),
          'user_id': uid,
        });
      } catch (_) {}
    }
  }
}
