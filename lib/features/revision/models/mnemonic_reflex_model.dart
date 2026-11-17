import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';

class MedicalMnemonicItem extends Equatable {
  final String id;
  final String moduleName;
  final String acronym;
  final String title;
  final List<String> letterBreakdown;
  final String examTip;
  final bool isCustom;

  const MedicalMnemonicItem({
    required this.id,
    required this.moduleName,
    required this.acronym,
    required this.title,
    required this.letterBreakdown,
    required this.examTip,
    this.isCustom = false,
  });

  factory MedicalMnemonicItem.fromJson(Map<String, dynamic> json) {
    return MedicalMnemonicItem(
      id: json['id']?.toString() ?? '',
      moduleName: json['module_name']?.toString() ?? 'Général',
      acronym: json['title_or_keyword']?.toString() ?? '',
      title: json['title_or_keyword']?.toString() ?? '',
      letterBreakdown: (json['content_or_diagnosis']?.toString() ?? '')
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      examTip: json['explanation_or_trap']?.toString() ?? '',
      isCustom: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_name': moduleName,
        'item_type': 'mnemonic',
        'title_or_keyword': acronym,
        'content_or_diagnosis': letterBreakdown.join('\n'),
        'explanation_or_trap': examTip,
      };

  @override
  List<Object?> get props => [id, moduleName, acronym, title];
}

class ExamReflexAssociation extends Equatable {
  final String id;
  final String moduleName;
  final String triggerKeyword;
  final String reflexDiagnosis;
  final String classicTrap;
  final bool isCustom;

  const ExamReflexAssociation({
    required this.id,
    required this.moduleName,
    required this.triggerKeyword,
    required this.reflexDiagnosis,
    required this.classicTrap,
    this.isCustom = false,
  });

  factory ExamReflexAssociation.fromJson(Map<String, dynamic> json) {
    return ExamReflexAssociation(
      id: json['id']?.toString() ?? '',
      moduleName: json['module_name']?.toString() ?? 'Général',
      triggerKeyword: json['title_or_keyword']?.toString() ?? '',
      reflexDiagnosis: json['content_or_diagnosis']?.toString() ?? '',
      classicTrap: json['explanation_or_trap']?.toString() ?? '',
      isCustom: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_name': moduleName,
        'item_type': 'reflex',
        'title_or_keyword': triggerKeyword,
        'content_or_diagnosis': reflexDiagnosis,
        'explanation_or_trap': classicTrap,
      };

  @override
  List<Object?> get props => [id, moduleName, triggerKeyword, reflexDiagnosis];
}

class MnemonicsReflexRepository {
  static const String _localCustomKey = 'medsina_custom_mnemonics_v1';

  static const List<MedicalMnemonicItem> builtinMnemonics = [
    MedicalMnemonicItem(
      id: 'mn_kusmaul',
      moduleName: 'Néphrologie / Réa',
      acronym: 'KUSMAUL',
      title: 'Étiologies des Acidoses Métaboliques à Trou Anionique Élevé',
      letterBreakdown: [
        'K : Ketoacidosis (Acidocétose diabétique, alcoolique, jeûne)',
        'U : Urémie (Insuffisance rénale aiguë/chronique)',
        'S : Salicylés (Intoxication à l\'aspirine)',
        'M : Méthanol / Metformine',
        'A : Acidose Lactique (Choc, hypoxie)',
        'U : Urémie / Éthylène glycol',
        'L : Lactates',
      ],
      examTip: 'Piège Résidanat : Les diarrhées aiguës donnent une acidose métabolique à Trou Anionique NORMAL (hyperchlorémique).',
    ),
    MedicalMnemonicItem(
      id: 'mn_cha2ds2vasc',
      moduleName: 'Cardiologie',
      acronym: 'CHA₂DS₂-VASc',
      title: 'Risque Thromboembolique dans la Fibrillation Atriale (FA)',
      letterBreakdown: [
        'C : Cardiopathie / Insuffisance cardiaque (1 pt)',
        'H : HTA (1 pt)',
        'A₂ : Âge ≥ 75 ans (2 pts)',
        'D : Diabète (1 pt)',
        'S₂ : Stroke / AVC / AIT antérieur (2 pts)',
        'V : Vasculaire (AOMI, IDM, plaque aortique) (1 pt)',
        'A : Âge 65–74 ans (1 pt)',
        'Sc : Sexe féminin (1 pt — modificateur)',
      ],
      examTip: 'Anticoagulation indiquée dès ≥ 2 chez l\'homme ou ≥ 3 chez la femme (à discuter dès 1 H / 2 F).',
    ),
    MedicalMnemonicItem(
      id: 'mn_ranson',
      moduleName: 'Gastro-Entérologie',
      acronym: 'GLACÉ / RANSON',
      title: 'Critères de Gravité de la Pancréatite Aiguë à l\'Admission',
      letterBreakdown: [
        'G : Glycémie > 11 mmol/L (2 g/L)',
        'L : Leucocytes > 16 000 /mm³',
        'A : Âge > 55 ans',
        'C : Cytolyse ASAT > 250 UI/L',
        'É : Élévation LDH > 350 UI/L',
      ],
      examTip: 'La gravité d\'une pancréatite aiguë n\'est JAMAIS corrélée au taux de Lipasémie !',
    ),
    MedicalMnemonicItem(
      id: 'mn_crab',
      moduleName: 'Hématologie',
      acronym: 'CRAB',
      title: 'Critères d\'Atteinte d\'Organe du Myélome Multiple',
      letterBreakdown: [
        'C : Calcémie élevée (Hypercalcémie > 2,75 mmol/L)',
        'R : Rein (Insuffisance rénale, créatinine > 177 µmol/L)',
        'A : Anémie (Hb < 10 g/dL)',
        'B : Bone (Lésions ostéolytiques à l\'emporte-pièce)',
      ],
      examTip: 'La VS est très accélérée mais la CRP reste normale (sauf infection associée).',
    ),
    MedicalMnemonicItem(
      id: 'mn_4t',
      moduleName: 'Gynécologie-Obstétrique',
      acronym: 'Les 4 T',
      title: 'Étiologies de l\'Hémorragie du Post-Partum (HPP)',
      letterBreakdown: [
        'T : Tonus (Atonie utérine — 70 à 80% des cas, 1ère cause)',
        'T : Tissu (Rétention placentaire / débris)',
        'T : Traumatisme (Déchirure col/vagin/périnée, rupture utérine)',
        'T : Thrombine (Troubles de la coagulation, CIVD)',
      ],
      examTip: '1er geste : révision utérine + massage utérin + Ocytocine IV.',
    ),
    MedicalMnemonicItem(
      id: 'mn_sapho',
      moduleName: 'Neurologie / Urgences',
      acronym: 'FAST / AVC',
      title: 'Critères Cliniques Rapides d\'AVC & Fenêtre Thrombolyse',
      letterBreakdown: [
        'F : Face (Asymétrie faciale)',
        'A : Arm (Déficit moteur d\'un membre)',
        'S : Speech (Dysarthrie / Aphasie)',
        'T : Time (Heure exacte du début < 4h30 pour rt-PA IV)',
      ],
      examTip: 'Ne JAMAIS faire baisser la PA avant 220/120 mmHg dans l\'AVC ischémique (sauf si thrombolyse < 185/110).',
    ),
  ];

  static const List<ExamReflexAssociation> builtinReflexes = [
    ExamReflexAssociation(
      id: 'rf_1',
      moduleName: 'Cardiologie',
      triggerKeyword: 'Douleur thoracique + Fièvre + Frottement péricardique + Sus-décalage ST concave diffus sans miroir',
      reflexDiagnosis: 'Péricardite Aiguë (AINS + Colchicine)',
      classicTrap: 'Ne pas thrombolyser ni anticoaguler ! Absence de signe en miroir contrairement au SCA ST+.',
    ),
    ExamReflexAssociation(
      id: 'rf_2',
      moduleName: 'Neurologie',
      triggerKeyword: 'Céphalée en coup de tonnerre ("la pire de sa vie") + Syndrome méningé apyrétique',
      reflexDiagnosis: 'Hémorragie Méningée (Sous-arachnoïdienne) — TDM cérébrale sans injection en urgence',
      classicTrap: 'Si TDM normale alors que forte suspicion : faire une Ponction Lombaire (xanthochromie).',
    ),
    ExamReflexAssociation(
      id: 'rf_3',
      moduleName: 'Pneumologie',
      triggerKeyword: 'Jeune homme longiligne fumeur + Douleur thoracique brutale + Tympanisme + Abolition du MV',
      reflexDiagnosis: 'Pneumothorax Spontané Primaire',
      classicTrap: 'Si signes de gravité (détresse respiratoire, choc) : exsufflation à l\'aiguille immédiate sans attendre la radio !',
    ),
    ExamReflexAssociation(
      id: 'rf_4',
      moduleName: 'Endocrinologie',
      triggerKeyword: 'Triade : HTA paroxystique + Céphalées + Sueurs + Palpitations (Triade de Ménard)',
      reflexDiagnosis: 'Phéochromocytome — Dosage Métanéphrines / Normétanéphrines urinaires ou plasmatiques',
      classicTrap: 'Ne JAMAIS donner de Bêta-bloquant seul en premier (risque de poussée hypertensive majeure par effet alpha non opposé).',
    ),
    ExamReflexAssociation(
      id: 'rf_5',
      moduleName: 'Infectiologie',
      triggerKeyword: 'Fièvre + Souffle cardiaque nouvellement apparu + Nodules d\'Osler / Purpura / Janeway',
      reflexDiagnosis: 'Endocardite Infectieuse — Hémocultures (3 séries) + ETT/ETO avant ATB si stable',
      classicTrap: 'En cas de sepsis sévère ou choc : ne pas retarder l\'antibiothérapie probabiliste après 2 paires d\'hémocs.',
    ),
    ExamReflexAssociation(
      id: 'rf_6',
      moduleName: 'Pédiatrie',
      triggerKeyword: 'Nourrisson 3-6 semaines + Vomissements en jet alimentaires post-prandiaux tardifs + Cassure pondérale',
      reflexDiagnosis: 'Sténose Hypertrophique du Pylore — Échographie abdominale (olive pylorique) + Alcalose hypochlorémique',
      classicTrap: 'Correction hydro-électrolytique AVANT la chirurgie (pyloromyotomie extra-muqueuse).',
    ),
    ExamReflexAssociation(
      id: 'rf_7',
      moduleName: 'Gynécologie',
      triggerKeyword: 'Femme en âge de procréer + Retard de règles + Douleur pelvienne unilatérale + Métrorragies noirâtres',
      reflexDiagnosis: 'Grossesse Extra-Utérine (GEU) jusqu\'à preuve du contraire — Beta-hCG + Écho pelvienne',
      classicTrap: 'Toujours vérifier le groupe Rhésus et prévoir Immunoglobulines anti-D si Rhésus négatif.',
    ),
    ExamReflexAssociation(
      id: 'rf_8',
      moduleName: 'Néphrologie',
      triggerKeyword: 'Œdèmes + Protéinurie > 3 g/24h (ou > 50 mg/kg/j enfant) + Hypoalbuminémie < 30 g/L',
      reflexDiagnosis: 'Syndrome Néphrotique Pur (LGM chez l\'enfant, GEM chez l\'adulte)',
      classicTrap: 'Risque thromboembolique majeur (thrombose veine rénale) si albuminémie < 20 g/L.',
    ),
  ];

  static Future<List<MedicalMnemonicItem>> loadAllMnemonics() async {
    final custom = await _loadCustomItems<MedicalMnemonicItem>(
      type: 'mnemonic',
      fromJson: MedicalMnemonicItem.fromJson,
    );
    return [...custom, ...builtinMnemonics];
  }

  static Future<List<ExamReflexAssociation>> loadAllReflexes() async {
    final custom = await _loadCustomItems<ExamReflexAssociation>(
      type: 'reflex',
      fromJson: ExamReflexAssociation.fromJson,
    );
    return [...custom, ...builtinReflexes];
  }

  static Future<List<T>> _loadCustomItems<T>({
    required String type,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final list = <T>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localCustomKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic> && item['item_type'] == type) {
            list.add(fromJson(item));
          }
        }
      }
    } catch (_) {}

    if (SupabaseService.isAuthenticated && SupabaseService.currentUser != null) {
      try {
        final rows = await SupabaseService.client
            .from('user_custom_mnemonics')
            .select()
            .eq('item_type', type)
            .order('created_at', ascending: false)
            .limit(40);
        final existingIds = list.map((e) => (e as dynamic).id.toString()).toSet();
        for (final r in rows) {
          final id = r['id']?.toString() ?? '';
          if (!existingIds.contains(id)) {
            list.add(fromJson(Map<String, dynamic>.from(r)));
          }
        }
      } catch (_) {}
    }
    return list;
  }

  static Future<void> saveCustomItem(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localCustomKey);
    final existing = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    existing.insert(0, payload);
    await prefs.setString(_localCustomKey, jsonEncode(existing));

    final uid = SupabaseService.currentUser?.id;
    if (SupabaseService.isAuthenticated && uid != null) {
      try {
        await SupabaseService.client.from('user_custom_mnemonics').upsert({
          ...payload,
          'user_id': uid,
        });
      } catch (_) {}
    }
  }
}
