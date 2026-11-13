import 'package:flutter/material.dart';

class TherapeuticClassInfo {
  final String codePrefix;
  final String name;
  final String shortName;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  const TherapeuticClassInfo({
    required this.codePrefix,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.color,
    this.keywords = const [],
  });
}

class TherapeuticClasses {
  static const List<TherapeuticClassInfo> all = [
    TherapeuticClassInfo(
      codePrefix: '01',
      name: 'Allergologie',
      shortName: 'Allergologie',
      icon: Icons.air_rounded,
      color: Color(0xFF0EA5E9),
      keywords: ['allergie', 'antihistaminique', 'urticaire', 'rhinite'],
    ),
    TherapeuticClassInfo(
      codePrefix: '02',
      name: 'Anesthésie & Réanimation',
      shortName: 'Anesthésie / Réa',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFF6366F1),
      keywords: ['anesthésie', 'réanimation', 'sédation', 'curare', 'morphinique'],
    ),
    TherapeuticClassInfo(
      codePrefix: '03',
      name: 'Antalgiques & Antipyrétiques',
      shortName: 'Antalgiques',
      icon: Icons.healing_rounded,
      color: Color(0xFF10B981),
      keywords: ['douleur', 'fièvre', 'antalgique', 'paracétamol', 'antispasmodique'],
    ),
    TherapeuticClassInfo(
      codePrefix: '04',
      name: 'Anti-inflammatoires',
      shortName: 'Anti-inflam.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFF59E0B),
      keywords: ['ains', 'inflammation', 'corticoïde', 'douleur'],
    ),
    TherapeuticClassInfo(
      codePrefix: '05',
      name: 'Cancérologie & Oncologie',
      shortName: 'Cancérologie',
      icon: Icons.biotech_rounded,
      color: Color(0xFF8B5CF6),
      keywords: ['cancer', 'chimiothérapie', 'oncologie', 'cytotoxique'],
    ),
    TherapeuticClassInfo(
      codePrefix: '06',
      name: 'Cardiologie & Angéiologie',
      shortName: 'Cardiologie',
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF4444),
      keywords: ['coeur', 'hta', 'hypertension', 'arythmie', 'insuffisance cardiaque', 'statine'],
    ),
    TherapeuticClassInfo(
      codePrefix: '07',
      name: 'Dermatologie',
      shortName: 'Dermatologie',
      icon: Icons.spa_rounded,
      color: Color(0xFFEC4899),
      keywords: ['peau', 'eczéma', 'psoriasis', 'mycose', 'acné', 'cicatrisation'],
    ),
    TherapeuticClassInfo(
      codePrefix: '08',
      name: 'Produits de Contraste & Imagerie',
      shortName: 'Imagerie',
      icon: Icons.medical_information_rounded,
      color: Color(0xFF64748B),
      keywords: ['irm', 'scanner', 'contraste', 'radiologie'],
    ),
    TherapeuticClassInfo(
      codePrefix: '09',
      name: 'Endocrinologie & Hormones',
      shortName: 'Endocrinologie',
      icon: Icons.science_rounded,
      color: Color(0xFF14B8A6),
      keywords: ['thyroïde', 'hormone', 'corticoïde', 'oestrogène', 'progestatif'],
    ),
    TherapeuticClassInfo(
      codePrefix: '10',
      name: 'Gastro-Entérologie & Hépatologie',
      shortName: 'Gastro-Entéro',
      icon: Icons.medical_services_rounded,
      color: Color(0xFFD97706),
      keywords: ['estomac', 'ulcère', 'ipp', 'reflux', 'diarrhée', 'constipation', 'foie'],
    ),
    TherapeuticClassInfo(
      codePrefix: '11',
      name: 'Gynécologie & Obstétrique',
      shortName: 'Gynécologie',
      icon: Icons.pregnant_woman_rounded,
      color: Color(0xFFF43F5E),
      keywords: ['grossesse', 'contraception', 'ovule', 'utérus'],
    ),
    TherapeuticClassInfo(
      codePrefix: '12',
      name: 'Hématologie & Hémostase',
      shortName: 'Hématologie',
      icon: Icons.bloodtype_rounded,
      color: Color(0xFFDC2626),
      keywords: ['anticoagulant', 'avk', 'hbpm', 'anémie', 'fer', 'antiagrégant'],
    ),
    TherapeuticClassInfo(
      codePrefix: '13',
      name: 'Infectiologie (Antibiotiques / Antiviraux)',
      shortName: 'Infectiologie',
      icon: Icons.coronavirus_rounded,
      color: Color(0xFF059669),
      keywords: ['infection', 'antibiotique', 'antiviral', 'antifongique', 'bactérie'],
    ),
    TherapeuticClassInfo(
      codePrefix: '14',
      name: 'Métabolisme, Nutrition & Diabète',
      shortName: 'Métabolisme / Diabète',
      icon: Icons.monitor_weight_rounded,
      color: Color(0xFF2563EB),
      keywords: ['diabète', 'insuline', 'glycémie', 'vitamine', 'lipides'],
    ),
    TherapeuticClassInfo(
      codePrefix: '15',
      name: 'Neurologie',
      shortName: 'Neurologie',
      icon: Icons.psychology_rounded,
      color: Color(0xFF7C3AED),
      keywords: ['épilepsie', 'migraine', 'parkinson', 'alzheimer', 'neuropathie'],
    ),
    TherapeuticClassInfo(
      codePrefix: '16',
      name: 'Psychiatrie',
      shortName: 'Psychiatrie',
      icon: Icons.mood_rounded,
      color: Color(0xFF4F46E5),
      keywords: ['dépression', 'anxiété', 'psychose', 'insomnie', 'antidépresseur'],
    ),
    TherapeuticClassInfo(
      codePrefix: '17',
      name: 'Ophtalmologie',
      shortName: 'Ophtalmologie',
      icon: Icons.visibility_rounded,
      color: Color(0xFF0284C7),
      keywords: ['oeil', 'collyre', 'glaucome', 'conjonctivite'],
    ),
    TherapeuticClassInfo(
      codePrefix: '18',
      name: 'ORL (Oto-Rhino-Laryngologie)',
      shortName: 'ORL',
      icon: Icons.hearing_rounded,
      color: Color(0xFF0D9488),
      keywords: ['oreille', 'nez', 'gorge', 'otite', 'sinusite', 'angine'],
    ),
    TherapeuticClassInfo(
      codePrefix: '19',
      name: 'Parasitologie',
      shortName: 'Parasitologie',
      icon: Icons.pest_control_rounded,
      color: Color(0xFF65A30D),
      keywords: ['parasite', 'antiparasitaire', 'paludisme', 'helminthe'],
    ),
    TherapeuticClassInfo(
      codePrefix: '20',
      name: 'Pneumologie',
      shortName: 'Pneumologie',
      icon: Icons.air_rounded,
      color: Color(0xFF38BDF8),
      keywords: ['asthme', 'bpco', 'bronche', 'toux', 'poumon', 'inhalateur'],
    ),
    TherapeuticClassInfo(
      codePrefix: '21',
      name: 'Rhumatologie',
      shortName: 'Rhumatologie',
      icon: Icons.accessibility_new_rounded,
      color: Color(0xFFEA580C),
      keywords: ['arthrose', 'polyarthrite', 'goutte', 'ostéoporose'],
    ),
    TherapeuticClassInfo(
      codePrefix: '22',
      name: 'Voies Respiratoires Hautes / Rhume',
      shortName: 'ORL / Rhume',
      icon: Icons.masks_rounded,
      color: Color(0xFF0891B2),
      keywords: ['rhume', 'grippe', 'décongestionnant', 'toux'],
    ),
    TherapeuticClassInfo(
      codePrefix: '23',
      name: 'Stomatologie & Buccodentaire',
      shortName: 'Stomatologie',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFF06B6D4),
      keywords: ['bouche', 'dents', 'bain de bouche', 'aphte', 'gingivite'],
    ),
    TherapeuticClassInfo(
      codePrefix: '24',
      name: 'Toxicologie, Antidotes & Chélateurs',
      shortName: 'Toxicologie',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFB91C1C),
      keywords: ['antidote', 'intoxication', 'surdosage', 'chélateur'],
    ),
    TherapeuticClassInfo(
      codePrefix: '25',
      name: 'Urologie & Néphrologie',
      shortName: 'Urologie / Néphro',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0369A1),
      keywords: ['rein', 'prostate', 'vessie', 'diurétique', 'lithiase'],
    ),
    TherapeuticClassInfo(
      codePrefix: '26',
      name: 'Antiseptiques, Désinfectants & Solutés',
      shortName: 'Antiseptiques / Solutés',
      icon: Icons.clean_hands_rounded,
      color: Color(0xFF059669),
      keywords: ['antiseptique', 'perfusion', 'soluté', 'désinfectant'],
    ),
    TherapeuticClassInfo(
      codePrefix: '27',
      name: 'Dérivés du Sang & Immunomodulateurs',
      shortName: 'Sang & Immuno',
      icon: Icons.shield_rounded,
      color: Color(0xFF9333EA),
      keywords: ['immunoglobuline', 'albumine', 'greffe', 'immunosuppresseur'],
    ),
    TherapeuticClassInfo(
      codePrefix: '28',
      name: 'Immunothérapie & Maladies Rares',
      shortName: 'Maladies Rares',
      icon: Icons.hub_rounded,
      color: Color(0xFF7E22CE),
      keywords: ['maladie rare', 'biothérapie', 'orphelin'],
    ),
  ];

  static final Map<String, TherapeuticClassInfo> _byPrefix = {
    for (final c in all) c.codePrefix: c,
  };

  /// Extracts the 2-digit MSPRH class prefix from a drug code (e.g. "06 A 002" -> "06").
  static String extractPrefix(String code) {
    final trimmed = code.trim();
    if (trimmed.length >= 2) {
      return trimmed.substring(0, 2);
    }
    return '';
  }

  static TherapeuticClassInfo? fromCode(String code) {
    return _byPrefix[extractPrefix(code)];
  }
}
