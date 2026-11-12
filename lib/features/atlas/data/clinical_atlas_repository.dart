import '../../../core/network/supabase_service.dart';
import '../models/clinical_atlas_model.dart';

class ClinicalAtlasRepository {
  static final ClinicalAtlasRepository instance = ClinicalAtlasRepository._();
  ClinicalAtlasRepository._();

  Future<List<ClinicalAtlasCase>> loadCases() async {
    try {
      final rows = await SupabaseService.client
          .from('clinical_atlas_cases')
          .select()
          .order('created_at', ascending: false);
      if (rows.isNotEmpty) {
        final remote = rows
            .map((r) => ClinicalAtlasCase.fromJson(Map<String, dynamic>.from(r)))
            .toList();
        final remoteIds = remote.map((c) => c.id).toSet();
        return [
          ...remote,
          ...curatedCases.where((c) => !remoteIds.contains(c.id)),
        ];
      }
    } catch (_) {}
    return curatedCases;
  }

  static List<ClinicalAtlasCase> filterCases(
    List<ClinicalAtlasCase> cases, {
    ClinicalModality? modality,
    String? specialty,
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return cases.where((c) {
      if (modality != null && c.modality != modality) return false;
      if (specialty != null &&
          specialty.isNotEmpty &&
          specialty != 'Toutes' &&
          c.specialty != specialty) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${c.title} ${c.specialty} ${c.diagnosis} ${c.clinicalContext} ${c.tags.join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  static const List<ClinicalAtlasCase> curatedCases = [
    ClinicalAtlasCase(
      id: 'atlas_ecg_stemi_ant',
      title: 'Sus-décalage ST en V1–V4 (Onde de Pardee)',
      specialty: 'Cardiologie',
      modality: ClinicalModality.ecg,
      clinicalContext:
          'Homme de 58 ans, tabagique, douleur thoracique rétrosternale constrictive irradiant au bras gauche depuis 90 min.',
      keyFindings: [
        'Sus-décalage du segment ST convexe vers le haut en V1, V2, V3, V4 (≥ 2 mm)',
        'Miroir (sous-décalage ST) en territoire inférieur (DII, DIII, aVF)',
        'Rythme sinusal régulier à 88 bpm',
      ],
      diagnosis: 'Syndrome Coronarien Aigu ST+ (SCA ST+) antérieur étendu',
      differentialDiagnosis: [
        'Péricardite aiguë (sus-décalage diffus concave, sans miroir)',
        'Syndrome de Brugada',
        'Repolarisation précoce bénigne',
      ],
      highYieldPearl:
          'Angioplastie primaire en urgence (< 120 min) ou fibrinolyse si délai > 120 min. Double antiagrégation + anticoagulation immédiate.',
      tags: ['Urgences', 'SCA', 'ECG', 'Blida 2024'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_ecg_bav3',
      title: 'Dissociation auriculo-ventriculaire complète',
      specialty: 'Cardiologie',
      modality: ClinicalModality.ecg,
      clinicalContext:
          'Femme de 74 ans admise pour syncope brutale à l\'emporte-pièce (Adams-Stokes) et asthénie.',
      keyFindings: [
        'Ondes P régulières à 85/min sans relation fixe avec les QRS',
        'Rythme d\'échappement ventriculaire régulier lent à 34/min',
        'QRS larges (> 120 ms) évoquant un échappement infra-hisien',
      ],
      diagnosis: 'Bloc Auriculo-Ventriculaire complet (BAV 3e degré)',
      differentialDiagnosis: [
        'BAV 2e degré Mobitz II',
        'Bradycardie sinusale sévère',
        'Hyperkaliémie majeure',
      ],
      highYieldPearl:
          'Éliminer une cause réversible (hyperkaliémie, bêtabloquants, IDM inférieur) et poser un stimulateur cardiaque définitif (pacemaker).',
      tags: ['Cardiologie', 'Syncope', 'Rythmologie'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_rx_pno',
      title: 'Hyperclarté périphérique avasculaire unilatérale',
      specialty: 'Pneumologie',
      modality: ClinicalModality.radiologie,
      clinicalContext:
          'Jeune homme de 22 ans, longiligne, douleur thoracique droite brutale en coup de poignard avec dyspnée.',
      keyFindings: [
        'Hyperclarté gazeuse périphérique droite dépourvue de trame vasculaire',
        'Ligne bordante pleurale viscérale nette rétractée vers le hile',
        'Refoulement médiastinal controlatéral si compressif',
      ],
      diagnosis: 'Pneumothorax spontané complet droit',
      differentialDiagnosis: [
        'Bulle d\'emphysème géante',
        'Kyste aérien pulmonaire',
        'Embolie pulmonaire (signe de Westermark)',
      ],
      highYieldPearl:
          'Si signes de gravité (détresse respiratoire, instabilité hémodynamique) = pneumothorax compressif → exsufflation à l\'aiguille immédiate au 2e EIC.',
      tags: ['Pneumologie', 'Urgences', 'Radio Thorax'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_rx_oap',
      title: 'Opacités alvéolaires bilatérales en « ailes de papillon »',
      specialty: 'Pneumologie',
      modality: ClinicalModality.radiologie,
      clinicalContext:
          'Patient de 69 ans hypertendu, orthopnée aiguë nocturne, grésillement laryngé, SpO2 84%.',
      keyFindings: [
        'Opacités floconneuses péri-hilaires bilatérales symétriques',
        'Cardiomégalie (index cardiothoracique > 0,55)',
        'Lignes B de Kerley aux bases et émoussement des culs-de-sac pleuraux',
      ],
      diagnosis: 'Œdème Aigu du Poumon (OAP) cardiogénique',
      differentialDiagnosis: [
        'SDRA (OAP lésionnel sans cardiomégalie)',
        'Pneumopathie bilatérale infectieuse',
        'Hémorragie intra-alvéolaire',
      ],
      highYieldPearl:
          'Position assise, O2 / VNI (CPAP), Furosémide IV + Dérivés nitrés IV (si PAS ≥ 100 mmHg).',
      tags: ['Cardiologie', 'Pneumologie', 'OAP'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_tdm_hsd',
      title: 'Hyperdensité juxta-osseuse en croissant concave',
      specialty: 'Neurologie',
      modality: ClinicalModality.tdmIrm,
      clinicalContext:
          'Patient de 76 ans sous AVK, chute bénigne il y a 48h, céphalées progressives et hémiparésie gauche.',
      keyFindings: [
        'Collection hyperdense extra-axiale droite en croissant concave vers le parenchyme',
        'Franchit les sutures crâniennes mais respecte la faux du cerveau',
        'Effet de masse avec déviation de la ligne médiane',
      ],
      diagnosis: 'Hématome Sous-Dural Aigu (HSDA)',
      differentialDiagnosis: [
        'Hématome Extra-Dural (lentille biconvexe, ne franchit pas les sutures)',
        'Hémorragie méningée',
        'AVC ischémique sylvien',
      ],
      highYieldPearl:
          'HSD = croissant concave (veines ponts). HED = lentille biconvexe (artère méningée moyenne). Antagoniser les AVK en urgence (PPSB + Vitamine K).',
      tags: ['Neurologie', 'Neurochirurgie', 'TDM'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_derm_erytheme_noueux',
      title: 'Nouures érythémateuses chaudes des crêtes tibiales',
      specialty: 'Dermatologie',
      modality: ClinicalModality.dermatologie,
      clinicalContext:
          'Femme de 29 ans, fébricule, arthralgies des chevilles et lésions douloureuses bilatérales des jambes.',
      keyFindings: [
        'Nouures dermo-hypodermiques chaudes, fermes, douloureuses à la palpation',
        'Topographie bilatérale et symétrique sur la face antérieure des jambes',
        'Évolution contusiforme (biligénie locale) sans ulcération',
      ],
      diagnosis: 'Érythème noueux (hypodermite nodulaire aiguë)',
      differentialDiagnosis: [
        'Érysipèle (placard unilatéral bien limité)',
        'Vascularite nodulaire',
        'Cellulite infectieuse',
      ],
      highYieldPearl:
          'Étiologies classiques à rechercher systématiquement : Sarcoïdose (Syndrome de Löfgren), Streptocoque, Tuberculose, MICI, Médicaments.',
      tags: ['Dermatologie', 'Médecine Interne'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_ophtalmo_rd',
      title: 'Microanévrismes, exsudats secs et hémorragies rétiniennes',
      specialty: 'Ophtalmologie',
      modality: ClinicalModality.ophtalmologie,
      clinicalContext:
          'Patient diabétique de type 2 depuis 14 ans, HbA1c à 9,4%, baisse d\'acuité visuelle progressive.',
      keyFindings: [
        'Microanévrismes punctiformes au pôle postérieur',
        'Hémorragies rétiniennes en flammèche et en tache',
        'Exsudats secs lipidiques périmaculaires en couronne (circinés)',
      ],
      diagnosis: 'Rétinopathie diabétique non proliférante sévère + maculopathie',
      differentialDiagnosis: [
        'Occlusion de la veine centrale de la rétine (OVCR)',
        'Rétinopathie hypertensive stade III',
      ],
      highYieldPearl:
          'Tout diabétique de type 2 doit avoir un fond d\'œil dès le diagnostic puis annuellement. Traitement : équilibre glycémique/tensionnel + PPR si proliférante.',
      tags: ['Ophtalmologie', 'Endocrinologie', 'Diabète'],
    ),
    ClinicalAtlasCase(
      id: 'atlas_anapath_reed_sternberg',
      title: 'Cellules géantes binucléées en « œil de hibou »',
      specialty: 'Hématologie',
      modality: ClinicalModality.anatomopathologie,
      clinicalContext:
          'Homme de 26 ans, adénopathies cervicales fermes indolores, sueurs nocturnes et prurit généralisé.',
      keyFindings: [
        'Présence de grandes cellules binucléées à nucléoles éosinophiles proéminents',
        'Aspect classique en « miroir » ou « œil de hibou » (CD15+, CD30+)',
        'Fond réactionnel polymorphe riche en lymphocytes et éosinophiles',
      ],
      diagnosis: 'Lymphome de Hodgkin classique (cellules de Reed-Sternberg)',
      differentialDiagnosis: [
        'Lymphome B diffus à grandes cellules',
        'Mononucléose infectieuse',
        'Tuberculose ganglionnaire',
      ],
      highYieldPearl:
          'La cellule de Reed-Sternberg (CD15+, CD30+) est pathognomonique du Lymphome de Hodgkin. Bilan d\'extension par TEP-scanner.',
      tags: ['Hématologie', 'Anapath'],
    ),
  ];
}
