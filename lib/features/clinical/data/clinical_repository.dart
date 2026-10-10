import '../models/cat_protocol_model.dart';

class ClinicalRepository {
  static List<ClinicalProtocol> getInitialProtocols() {
    return [
      const ClinicalProtocol(
        id: 'cat_sca_st_plus',
        title: 'Syndrome Coronarien Aigu avec Sus-décalage de ST (SCA ST+ / IDM)',
        specialty: 'Cardiologie & Urgences',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Occlusion coronarienne aiguë complète nécessitant une reperfusion myocardique en extrême urgence (< 120 min).',
        redFlags: [
          'Douleur rétro-sternale constrictive > 20 min irradiant au bras gauche/mâchoire résistant aux dérivés nitrés',
          'Choc cardiogénique (PAS < 90 mmHg, marbrures, oligurie)',
          'Troubles du rythme ventriculaire (TV, FV, BAV III)',
          'Signes d\'insuffisance cardiaque aiguë (crépitants, galop B3)',
        ],
        steps: [
          ClinicalStep(
            title: '1. Conditionnement immédiat (< 10 min)',
            content: 'Patient au repos strict au lit, 2 VVP de bon calibre, monitorage scope ECG continu, SpO2, TA.',
            bulletPoints: [
              'Oxygénothérapie SEULEMENT si SpO2 < 90%',
              'ECG 12 dérivations + V7-V8-V9 et V3R-V4R interprété en < 10 min',
              'Bilan biologique d\'urgence sans attendre les résultats pour la reperfusion (Troponine, NFS, Iono, TP/INR, Groupe Rhésus)',
            ],
          ),
          ClinicalStep(
            title: '2. Stratégie de Reperfusion',
            content: 'Le temps c\'est du myocarde : choix guidé par le délai premier contact médical (PCM) - angioplastie.',
            bulletPoints: [
              'Si Angioplastie primaire possible en < 120 min : Transfert immédiat en salle de cathétérisme',
              'Si délai > 120 min : Fibrinolyse IV immédiate (Ténectéplase) dans les 10 min, sauf contre-indication absolue',
            ],
          ),
          ClinicalStep(
            title: '3. Traitement Antithrombotique d\'urgence',
            content: 'Double antiagrégation plaquettaire + anticoagulation parentérale immédiate.',
            bulletPoints: [
              'Aspirine : 150-300 mg IV ou PO à croquer',
              'Inhibiteur P2Y12 : Ticagrélor (180 mg charge) ou Prasugrel (60 mg) ou Clopidogrel (600 mg)',
              'Héparine non fractionnée (HNF) bolus 70-100 UI/kg ou Enoxaparine 0,5 mg/kg IV',
            ],
          ),
          ClinicalStep(
            title: '4. Traitement Symptomatique',
            content: 'Soulager la douleur et réduire le travail cardiaque.',
            bulletPoints: [
              'Morphine IV titrée (2-3 mg toutes les 5-10 min) si douleur intense persistante',
              'Dérivés nitrés IV si OAP associé (contre-indiqué si PAS < 90 mmHg ou IDM ventriculaire droit)',
            ],
          ),
        ],
        treatments: [
          'Aspirine 250 mg IV',
          'Ticagrélor 180 mg PO (ou Clopidogrel 600 mg)',
          'HNF IV 5000 UI ou Énoxaparine',
          'Morphine titrée IV',
        ],
        references: 'Recommandations ESC / SFC 2023 - Prise en charge des syndromes coronariens aigus.',
      ),
      const ClinicalProtocol(
        id: 'cat_avc_ischemique',
        title: 'Accident Vasculaire Cérébral Ischémique Aigu (AVC)',
        specialty: 'Neurologie & Urgences',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Déficit neurologique focal soudain évocateur d\'ischémie cérébrale. Fenêtre thérapeutique majeure : thrombolyse IV < 4h30, thrombectomie < 6h (voire 24h selon imagerie de perfusion).',
        redFlags: [
          'Affaissement du visage, déficit moteur brutal (bras/jambe), troubles du langage (FAST score)',
          'Troubles de vigilance d\'emblée (coma, score de Glasgow < 8)',
          'Crise comitiale inaugurale',
          'Céphalée brutale "en coup de tonnerre" (suspecter HSA)',
        ],
        steps: [
          ClinicalStep(
            title: '1. Prise en charge initiale immédiate',
            content: 'Déterminer l\'heure EXACTE de début des symptômes (ou dernière heure vue normal).',
            bulletPoints: [
              'Alerte filière neuro-vasculaire (UNV)',
              'Scope, SpO2, TA, glycémie capillaire IMMÉDIATE (éliminer hypoglycémie)',
              'Position demi-assise 30°, patient à jeun strict (ne rien donner à boire ou manger)',
              'Imagerie cérébrale en urgence absolue : IRM cérébrale (Diffusion/FLAIR/T2*/ARM) ou TDM cérébral sans injection + angioscan',
            ],
          ),
          ClinicalStep(
            title: '2. Contrôle des paramètres hémodynamiques & métaboliques',
            content: 'Respecter l\'hypertension artérielle réactionnelle (sauvegarder la pénombre ischémique).',
            bulletPoints: [
              'Ne PAS faire baisser la TA sauf si PAS > 220 mmHg ou PAD > 120 mmHg (ou > 185/110 si thrombolyse prévue)',
              'Traiter la fièvre (Paracétamol si T > 38°C) et l\'hyperglycémie (Insuline si glycémie > 1,8 g/L)',
              'Pas de soluté glucosé hypotonique',
            ],
          ),
          ClinicalStep(
            title: '3. Revascularisation',
            content: 'Thrombolyse intraveineuse par Altéplase (rt-PA) 0,9 mg/kg en l\'absence de contre-indication + Thrombectomie mécanique si occlusion proximale.',
            bulletPoints: [
              'rt-PA IV dans les 4h30 suivant le début des symptômes',
              'Thrombectomie mécanique jusqu\'à 6h (grandes artères sylvienne M1 ou carotide interne)',
            ],
          ),
        ],
        treatments: [
          'rt-PA (Actilyse) 0,9 mg/kg IV si éligible',
          'Loxen (Nicardipine) IV si TA > 185/110 mmHg avant thrombolyse',
          'Sérum physiologique NaCl 0,9%',
        ],
        references: 'Recommandations ESO / SFNV 2022 - Prise en charge précoce de l\'AVC aigu.',
      ),
      const ClinicalProtocol(
        id: 'cat_choc_anaphylactique',
        title: 'Choc Anaphylactique & Réaction Allergique Grave',
        specialty: 'Réanimation & Allergologie',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Réaction d\'hypersensibilité systémique sévère, d\'évolution rapide, engageant le pronostic vital par défaillance respiratoire et/ou hémodynamique.',
        redFlags: [
          'Stridor laryngé, dyspnée sifflante, œdème de Quincke (œdème de la luette/langue)',
          'Collapsus cardiovasculaire : PAS < 90 mmHg, tachycardie, cyanose, malaise',
          'Atteinte cutanéo-muqueuse diffuse (urticaire géant, prurit palmo-plantaire)',
          'Signes digestifs associés (douleurs abdominales violentes, vomissements)',
        ],
        steps: [
          ClinicalStep(
            title: '1. Traitement salvateur immédiat (< 1 minute)',
            content: 'L\'Adrénaline par voie intramusculaire (IM) est le traitement de première ligne, à injecter sans aucun délai.',
            bulletPoints: [
              'Arrêt immédiat de l\'allergène suspecté (médicament, perfusion, piqûre d\'hyménoptère)',
              'Position : décubitus dorsal jambes surélevées (Trendelenburg), ou position assise si détresse respiratoire prédominante',
              'ADRÉNALINE IM face antéro-latérale de la cuisse : 0,5 mg chez l\'adulte (0,01 mg/kg chez l\'enfant, max 0,3 mg)',
              'Répéter l\'injection IM après 5 à 15 minutes en cas d\'absence d\'amélioration',
            ],
          ),
          ClinicalStep(
            title: '2. Réanimation d\'urgence',
            content: 'Rétablissement de la volémie et de l\'oxygénation.',
            bulletPoints: [
              'Oxygénothérapie fort débit (masque haute concentration 10-15 L/min)',
              'Remplissage vasculaire rapide par cristalloïdes isotoniques (NaCl 0,9% ou Ringer Lactate 500 à 1000 mL en 15-30 min)',
              'Aérosol de Salbutamol (5 mg) si bronchospasme résiduel',
            ],
          ),
          ClinicalStep(
            title: '3. Traitements secondaires (après stabilisation)',
            content: 'Ne remplacent JAMAIS l\'adrénaline ; préviennent le rebond.',
            bulletPoints: [
              'Corticoïdes IV : Méthylprednisolone (Solumédrol) 1-2 mg/kg IV',
              'Antihistaminique H1 IV : Polaramine 5 mg IV lent',
              'Surveillance hospitalière minimale de 12 à 24 heures (risque de réaction biphasique)',
            ],
          ),
        ],
        treatments: [
          'Adrénaline 0,5 mg IM (face antérolatérale cuisse)',
          'Cristalloïdes (NaCl 0,9%) 1000 mL IV rapide',
          'Solumédrol 80-120 mg IV',
          'Aérosols Bêta-2 mimétiques (Salbutamol 5 mg)',
        ],
        references: 'Recommandations SFMU / SFA / EAACI - Prise en charge de l\'anaphylaxie.',
      ),
      const ClinicalProtocol(
        id: 'cat_asthme_aigu_grave',
        title: 'Crise d\'Asthme Aigu Grave (AAG)',
        specialty: 'Pneumologie & Urgences',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Exacerbation sévère d\'asthme menaçant le pronostic vital, ne répondant pas aux bronchodilatateurs usuels.',
        redFlags: [
          'Silence auscultatoire ("poumon muet"), impossibilité de parler',
          'Cyanose, sueurs profuses, agitation ou somnolence (signes d\'hypercapnie)',
          'Tirage intercostal et sus-sternal, respiration paradoxale (balancement thoraco-abdominal)',
          'Pouls paradoxal, FC > 120 bpm, FR > 30/min, DEP < 30% ou indosable',
        ],
        steps: [
          ClinicalStep(
            title: '1. Traitement bronchodilatateur intensif',
            content: 'Nébulisation continue de bronchodilatateurs sous oxygène.',
            bulletPoints: [
              'Oxygène fort débit pour maintenir SpO2 entre 93% et 95%',
              'Nébulisation combinée : Salbutamol 5 mg + Ipratropium (Atrovent) 0,5 mg sous débit d\'O2 de 6-8 L/min',
              'Renouveler la nébulisation toutes les 20 minutes pendant la première heure',
            ],
          ),
          ClinicalStep(
            title: '2. Corticothérapie systémique précoce',
            content: 'Indispensable pour lever l\'inflammation bronchique et restaurer la sensibilité des récepteurs.',
            bulletPoints: [
              'Méthylprednisolone 1 à 2 mg/kg IV (ex: Solumédrol 80-120 mg IV)',
              'Délai d\'action : 4 à 6 heures',
            ],
          ),
          ClinicalStep(
            title: '3. En cas d\'échec ou d\'épuisement',
            content: 'Mesures d\'escalade thérapeutique.',
            bulletPoints: [
              'Sulfate de magnésium IV : 2 g en perfusion sur 20 minutes',
              'Adrénaline en nébulisation ou IV titrée si collapsus associé',
              'Préparation à l\'intubation en séquence rapide si arrêt respiratoire imminent',
            ],
          ),
        ],
        treatments: [
          'Salbutamol 5 mg en nébulisation (O2 6-8 L/min)',
          'Atrovent 0,5 mg en nébulisation',
          'Solumédrol 1 mg/kg IV',
          'Sulfate de Magnésium 2 g IV',
        ],
        references: 'GINA Guidelines 2023 & SPLF - Prise en charge des exacerbations sévères d\'asthme.',
      ),
      const ClinicalProtocol(
        id: 'cat_acidocetose_diabetique',
        title: 'Acidocétose Diabétique de l\'Adulte',
        specialty: 'Endocrinologie & Urgences',
        urgencyLevel: 'Urgence Relative',
        definition: 'Complication métabolique aiguë du diabète caractérisée par la triade : hyperglycémie (> 2,5 g/L), cétose franche (acétonurie ++ ou cétonémie > 3 mmol/L) et acidose métabolique (pH < 7,30, bicarbonates < 15 mmol/L).',
        redFlags: [
          'Respiration ample et rapide de Kussmaul avec haleine acétonique fruitée',
          'Déshydratation globale sévère (perte hydrique de 5 à 10 L)',
          'Troubles de conscience, confusion, coma',
          'Hypokaliémie initiale < 3,3 mmol/L (DANGER immédiat d\'arrêt cardiaque lors de l\'insulinothérapie !)',
        ],
        steps: [
          ClinicalStep(
            title: '1. Réhydratation hydro-électrolytique (Priorité absolue)',
            content: 'Restaurer la volémie avant tout.',
            bulletPoints: [
              'Sérum salé isotonique NaCl 0,9% : 1000 mL la 1ère heure, puis 500 mL/h pendant 2 à 4h',
              'Relais par Sérum Glucosé 5% ou 10% avec NaCl dès que la glycémie descend sous 2,5 g/L (14 mmol/L) pour éviter l\'hypoglycémie et l\'œdème cérébral',
            ],
          ),
          ClinicalStep(
            title: '2. Gestion de la Kaliémie (Règle d\'or)',
            content: 'L\'insuline fait chuter le potassium intracellulaire.',
            bulletPoints: [
              'Si K+ < 3,3 mmol/L : NE PAS débuter l\'insuline ! Recharger d\'abord en potassium (KCl 20-30 mEq/L)',
              'Si K+ entre 3,3 et 5,0 mmol/L : Ajouter KCl 2-3 g par litre de soluté en même temps que l\'insuline',
              'Si K+ > 5,0 mmol/L : Débuter l\'insuline sans potassium, contrôler l\'ionogramme toutes les 2 heures',
            ],
          ),
          ClinicalStep(
            title: '3. Insulinothérapie IVSE',
            content: 'Insuline rapide à débit constant.',
            bulletPoints: [
              'Insuline rapide (Actrapid/Umuline) en pousse-seringue électrique : 0,1 UI/kg/heure',
              'Objectif de baisse glycémique : 0,5 à 0,7 g/L par heure (ne pas corriger trop vite)',
            ],
          ),
        ],
        treatments: [
          'NaCl 0,9% (1 à 2 L dans les 2 premières heures)',
          'KCl selon kaliémie',
          'Insuline rapide IVSE 0,1 UI/kg/h',
          'Recherche et traitement du facteur déclenchant (Infection, IDM, arrêt insuline)',
        ],
        references: 'Consensus ADA / SFD - Décompensations acido-cétosiques du diabète.',
      ),
    ];
  }
}
