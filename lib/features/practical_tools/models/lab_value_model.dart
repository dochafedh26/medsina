import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/supabase_service.dart';

// =============================================================================
// 1. LAB REFERENCE VALUE MODEL (NORMES BIOLOGIQUES)
// =============================================================================

class LabValue extends Equatable {
  final String id;
  final String name;
  final String category;
  final String normalRange;
  final String unit;
  final String highInterpretation;
  final String lowInterpretation;
  final List<String> clinicalNotes;

  const LabValue({
    required this.id,
    required this.name,
    required this.category,
    required this.normalRange,
    required this.unit,
    required this.highInterpretation,
    required this.lowInterpretation,
    this.clinicalNotes = const [],
  });

  factory LabValue.fromJson(Map<String, dynamic> json) {
    List<String> notes = [];
    if (json['clinical_notes'] != null) {
      if (json['clinical_notes'] is List) {
        notes = (json['clinical_notes'] as List).map((e) => e.toString()).toList();
      } else if (json['clinical_notes'] is String) {
        try {
          final parsed = jsonDecode(json['clinical_notes']);
          if (parsed is List) {
            notes = parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    return LabValue(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Général',
      normalRange: json['normal_range']?.toString() ?? json['normalRange']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      highInterpretation: json['high_interpretation']?.toString() ?? json['highInterpretation']?.toString() ?? '',
      lowInterpretation: json['low_interpretation']?.toString() ?? json['lowInterpretation']?.toString() ?? '',
      clinicalNotes: notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'normal_range': normalRange,
      'unit': unit,
      'high_interpretation': highInterpretation,
      'low_interpretation': lowInterpretation,
      'clinical_notes': clinicalNotes,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        normalRange,
        unit,
        highInterpretation,
        lowInterpretation,
        clinicalNotes,
      ];
}

// =============================================================================
// 2. ON-CALL MEMENTO MODEL (MÉMENTO DE GARDE HOSPITALIÈRE)
// =============================================================================

class OnCallMemento extends Equatable {
  final String id;
  final String title;
  final String category;
  final String iconName;
  final String colorHex;
  final int priorityLevel;
  final List<String> points;
  final String? scientificReferences;

  const OnCallMemento({
    required this.id,
    required this.title,
    required this.category,
    this.iconName = 'warning_rounded',
    this.colorHex = '#EF4444',
    this.priorityLevel = 1,
    required this.points,
    this.scientificReferences,
  });

  IconData get icon {
    switch (iconName) {
      case 'checklist_rounded':
        return Icons.checklist_rounded;
      case 'description_rounded':
        return Icons.description_rounded;
      case 'bolt_rounded':
        return Icons.bolt_rounded;
      case 'air_rounded':
        return Icons.air_rounded;
      case 'favorite_border_rounded':
        return Icons.favorite_border_rounded;
      case 'emergency_rounded':
        return Icons.emergency_rounded;
      case 'medication_liquid_rounded':
        return Icons.medication_liquid_rounded;
      case 'biotech_rounded':
        return Icons.biotech_rounded;
      case 'pregnant_woman_rounded':
        return Icons.pregnant_woman_rounded;
      case 'child_care_rounded':
        return Icons.child_care_rounded;
      case 'psychology_rounded':
        return Icons.psychology_rounded;
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'bug_report_rounded':
        return Icons.bug_report_rounded;
      case 'health_and_safety_rounded':
        return Icons.health_and_safety_rounded;
      case 'healing_rounded':
        return Icons.healing_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Color get color {
    try {
      final clean = colorHex.replaceFirst('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
    } catch (_) {}
    return const Color(0xFFEF4444);
  }

  factory OnCallMemento.fromJson(Map<String, dynamic> json) {
    List<String> pts = [];
    if (json['points'] != null) {
      if (json['points'] is List) {
        pts = (json['points'] as List).map((e) => e.toString()).toList();
      } else if (json['points'] is String) {
        try {
          final parsed = jsonDecode(json['points']);
          if (parsed is List) pts = parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
    }

    return OnCallMemento(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Urgences & Garde',
      iconName: json['icon_name']?.toString() ?? json['iconName']?.toString() ?? 'warning_rounded',
      colorHex: json['color_hex']?.toString() ?? json['colorHex']?.toString() ?? '#EF4444',
      priorityLevel: int.tryParse(json['priority_level']?.toString() ?? json['priorityLevel']?.toString() ?? '1') ?? 1,
      points: pts,
      scientificReferences: json['scientific_references']?.toString() ?? json['scientificReferences']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'icon_name': iconName,
      'color_hex': colorHex,
      'priority_level': priorityLevel,
      'points': points,
      'scientific_references': scientificReferences,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        iconName,
        colorHex,
        priorityLevel,
        points,
        scientificReferences,
      ];
}

// =============================================================================
// 3. PRACTICAL TOOLS REPOSITORY (HYBRID CLOUD-FIRST & OFFLINE-FALLBACK)
// =============================================================================

class PracticalToolsRepository {
  static List<LabValue>? _cachedLabValues;
  static List<OnCallMemento>? _cachedMementos;

  /// Synchronous fallback
  static List<LabValue> getLabValues() {
    return _cachedLabValues ?? _getInitialLabValues();
  }

  /// Synchronous fallback
  static List<OnCallMemento> getOnCallMementos() {
    return _cachedMementos ?? _getInitialMementos();
  }

  /// Asynchronous fetching: Cloud Supabase -> Local Assets -> Static Built-in
  static Future<List<LabValue>> getLabValuesAsync({bool refresh = false}) async {
    if (!refresh && _cachedLabValues != null && _cachedLabValues!.isNotEmpty) {
      return _cachedLabValues!;
    }

    // 1. Try Supabase Cloud
    try {
      final cloudData = await SupabaseService.fetchLabReferenceValues();
      if (cloudData.isNotEmpty) {
        _cachedLabValues = cloudData.map((e) => LabValue.fromJson(e)).toList();
        return _cachedLabValues!;
      }
    } catch (_) {}

    // 2. Try Local Asset JSON
    try {
      final jsonStr = await rootBundle.loadString('assets/data/lab_reference_values.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      _cachedLabValues = list.map((e) => LabValue.fromJson(e as Map<String, dynamic>)).toList();
      return _cachedLabValues!;
    } catch (_) {}

    // 3. Fallback to Built-in
    _cachedLabValues = _getInitialLabValues();
    return _cachedLabValues!;
  }

  /// Asynchronous fetching: Cloud Supabase -> Local Assets -> Static Built-in
  static Future<List<OnCallMemento>> getOnCallMementosAsync({bool refresh = false}) async {
    if (!refresh && _cachedMementos != null && _cachedMementos!.isNotEmpty) {
      return _cachedMementos!;
    }

    // 1. Try Supabase Cloud
    try {
      final cloudData = await SupabaseService.fetchOnCallMementos();
      if (cloudData.isNotEmpty) {
        _cachedMementos = cloudData.map((e) => OnCallMemento.fromJson(e)).toList();
        return _cachedMementos!;
      }
    } catch (_) {}

    // 2. Try Local Asset JSON
    try {
      final jsonStr = await rootBundle.loadString('assets/data/on_call_mementos.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      _cachedMementos = list.map((e) => OnCallMemento.fromJson(e as Map<String, dynamic>)).toList();
      return _cachedMementos!;
    } catch (_) {}

    // 3. Fallback to Built-in
    _cachedMementos = _getInitialMementos();
    return _cachedMementos!;
  }

  static List<LabValue> _getInitialLabValues() {
    return const [
      LabValue(
        id: 'lab_potassium',
        name: 'Potassium sérique (Kaliémie)',
        category: 'Ionogramme & Rein',
        normalRange: '3.5 - 5.0',
        unit: 'mmol/L',
        highInterpretation: 'Hyperkaliémie : Urgence si > 6.0 mmol/L ou signes ECG (ondes T pointues et symétriques, élargissement QRS). Risque d\'arrêt en asystolie. Causes : insuffisance rénale, acidose, rhabdomyolyse, médicaments (IEC, ARA2, spironolactone).',
        lowInterpretation: 'Hypokaliémie : Urgence si < 3.0 mmol/L. Risque de troubles du rythme ventriculaire (torsades de pointes, fibrillation). Signes ECG : onde U, aplatissement T, sous-décalage ST. Causes : pertes digestives (vomissements, diarrhée), diurétiques de l\'anse, hyperaldostéronisme.',
        clinicalNotes: [
          'Attention à la fausse hyperkaliémie par hémolyse lors du prélèvement (garrot trop serré).',
          'Toute dyskaliémie justifie un ECG 12 dérivations immédiat.',
        ],
      ),
      LabValue(
        id: 'lab_sodium',
        name: 'Sodium sérique (Natrémie)',
        category: 'Ionogramme & Rein',
        normalRange: '135 - 145',
        unit: 'mmol/L',
        highInterpretation: 'Hypernatrémie (> 145 mmol/L) : Traduit toujours un déficit hydrique intracellulaire. Soif intense, sécheresse des muqueuses, fièvre, troubles de conscience. Corriger prudemment (< 10-12 mmol/L par 24h) pour éviter l\'œdème cérébral.',
        lowInterpretation: 'Hyponatrémie (< 135 mmol/L) : Hyperhydratation intracellulaire. Céphalées, nausées, dégoût de l\'eau, risque de convulsions et coma si < 120 mmol/L. Risque majeur de myélinolyse centropontine si correction trop rapide.',
        clinicalNotes: [
          'Calculer la glycémie pour corriger la natrémie : Na corrigé = Na mesuré + 1.6 * (Glycémie g/L - 1).',
        ],
      ),
      LabValue(
        id: 'lab_creatinine',
        name: 'Créatinine sérique & DFG',
        category: 'Ionogramme & Rein',
        normalRange: 'Homme : 60 - 110 | Femme : 45 - 90',
        unit: 'µmol/L',
        highInterpretation: 'Insuffisance rénale aiguë ou chronique. Toujours comparer à la valeur antérieure. Calculer impérativement le Débit de Filtration Glomérulaire (DFG) par CKD-EPI.',
        lowInterpretation: 'Dénutrition sévère, amyotrophie majeure, grossesse.',
        clinicalNotes: [
          'L\'élévation aiguë de 26 µmol/L en 48h définit une insuffisance rénale aiguë (critères KDIGO).',
        ],
      ),
      LabValue(
        id: 'lab_hemoglobine',
        name: 'Hémoglobine (NFS)',
        category: 'Hématologie',
        normalRange: 'Homme : 13 - 17 | Femme : 12 - 15.5 | Grossesse : > 10.5',
        unit: 'g/dL',
        highInterpretation: 'Polyglobulie (Primitive : Maladie de Vaquez ; Secondaire : Hypoxie chronique BPCO, cardiopathie cyanogène, tabagisme).',
        lowInterpretation: 'Anémie. Classifier selon le VGM (Microcytaire < 80 fl : carence martiale, thalassémie ; Normo/Macrocytaire : régénérative ou arégénérative).',
        clinicalNotes: [
          'Seuil transfusionnel standard chez le coronarien : Hb < 10 g/dL ; chez le sujet jeune sans comorbidité : Hb < 7 g/dL.',
        ],
      ),
      LabValue(
        id: 'lab_plaquettes',
        name: 'Numération plaquettaire',
        category: 'Hématologie',
        normalRange: '150 000 - 400 000',
        unit: '/mm³',
        highInterpretation: 'Thrombocytose (> 450 000) : Réactionnelle (infection, inflammation, carence en fer, splénectomie) ou Syndrome myéloprolifératif (Thrombocytémie essentielle).',
        lowInterpretation: 'Thrombopénie (< 150 000) : Risque hémorragique spontané si < 20 000/mm³. Éliminer un artefact à l\'EDTA (faire tube citraté). Causes : CIVD, MAT/PTT, PTI, sepsis, héparine (TIH).',
        clinicalNotes: [
          'Rechercher impérativement un purpura pétéchial ou des bulles hémorragiques buccales si < 50 000/mm³.',
        ],
      ),
      LabValue(
        id: 'lab_crp',
        name: 'Protéine C-Réactive (CRP)',
        category: 'Inflammation & Infectiologie',
        normalRange: '< 5',
        unit: 'mg/L',
        highInterpretation: 'Syndrome inflammatoire biologique aigu. Infection bactérienne (> 50-100 mg/L), sepsis sévère, maladie auto-immune active, nécrose tissulaire (infarctus).',
        lowInterpretation: 'Absence d\'inflammation systémique significative.',
        clinicalNotes: [
          'La CRP cinétique : commence à s\'élever 6 à 12h après le stimulus, pic à 48h, demi-vie courte (très bon marqueur d\'efficacité thérapeutique).',
        ],
      ),
    ];
  }

  static List<OnCallMemento> _getInitialMementos() {
    return const [
      OnCallMemento(
        id: 'memento_checklist_garde',
        title: '🚨 Checklist de Début de Garde Hospitalière',
        category: 'Organisation & Sécurité',
        iconName: 'checklist_rounded',
        colorHex: '#0D9488',
        priorityLevel: 3,
        points: [
          'Prendre les transmissions orales et écrites du médecin sortant (patients instables en priorité).',
          'Vérifier les coordonnées d\'urgence : Réanimation de garde, SAMU 115, Laboratoire central, Banque du sang (CTS).',
          'Tester le chariot d\'urgence du service : Défibrillateur opérationnel, laryngoscope, ampoules d\'Adrénaline disponibles.',
          'Vérifier les bilans biologiques en attente des admissions de fin d\'après-midi.',
          'Identifier les patients à surveiller étroitement (sepsis, détresse respiratoire, post-op immédiat).',
        ],
      ),
      OnCallMemento(
        id: 'memento_ordonnance_conforme',
        title: '📋 Règle de Rédaction d\'Ordonnance Conforme (MSPRH)',
        category: 'Bonne Pratique Médicale',
        iconName: 'description_rounded',
        colorHex: '#0284C7',
        priorityLevel: 3,
        points: [
          'Identité complète : Nom, prénom, âge, poids (indispensable chez l\'enfant et l\'insuffisant rénal).',
          'Date du jour et signature lisible avec cachet médical obligatoire.',
          'Dénomination Commune Internationale (DCI) recommandée — la spécialité commerciale entre parenthèses.',
          'Posologie explicite : dose, voie d\'administration, rythme des prises et durée exacte du traitement.',
          'Mention « Ne pas dépasser » pour les antalgiques de palier 1 et 2.',
          'En pédiatrie : toujours indiquer le poids en kg et calculer la dose mg/kg/j.',
        ],
      ),
      OnCallMemento(
        id: 'memento_hypoglycemie',
        title: '⚡ CAT Hypoglycémie Sévère (Glycémie < 0,5 g/L)',
        category: 'Urgences Métaboliques',
        iconName: 'bolt_rounded',
        colorHex: '#F59E0B',
        priorityLevel: 1,
        points: [
          'Confirmer immédiatement par dextrostix capillaire.',
          'Si voie veineuse disponible : G30% 50 mL IV direct (ou G10% 200 mL en 15 min).',
          'Si pas de voie veineuse : Glucagon 1 mg SC ou IM (contre-indiqué si hépatopathie sévère).',
          'Resucrage oral dès que la conscience est récupérée : jus de fruit + biscuit.',
          'Surveillance glycémique toutes les 30 min pendant 2 heures. Rechercher et traiter la cause.',
          'Hospitaliser si : sulfamides (hypoglycémie prolongée), récidive, sujet isolé, âge > 75 ans.',
        ],
      ),
    ];
  }
}
