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
      const ClinicalProtocol(
        id: 'cat_envenimation_scorpionique',
        title: 'Envenimation Scorpionique (Protocole National Algérie)',
        specialty: 'Toxicologie & Urgences Algérie',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Piqûre de scorpion avec envenimation potentiellement mortelle (Androctonus australis). Priorité absolue de santé publique en Algérie.',
        redFlags: [
          'Stade 1 : Signes locaux isolés (douleur vive, œdème minime)',
          'Stade 2 : Signes généraux/systémiques (sueurs profuses, priapisme, myosis/mydriase, vomissements, HTA, tachycardie)',
          'Stade 3 : Détresse vitale (OAP cardiogénique, choc cardiogénique, collapsus, détresse respiratoire, convulsions, coma)',
          'Facteur de haut risque : Enfant de moins de 15 ans et sujet âgé',
        ],
        steps: [
          ClinicalStep(
            title: '1. Conduite Immédiate & Triage',
            content: 'Tout piqué de scorpion doit être gardé sous surveillance médicale minimale de 4 heures.',
            bulletPoints: [
              'Repos strict au lit, rassurer le patient et la famille (le stress aggrave la décharge catécholaminergique)',
              'NE PAS inciser, NE PAS poser de garrot, NE PAS cautériser, NE PAS aspirer',
              'Désinfection locale de la piqûre, vérifier la vaccination antitétanique (VAT)',
              'Prise des constantes vitales (FC, TA, SpO2, FR, Température) toutes les 30 minutes',
            ],
          ),
          ClinicalStep(
            title: '2. Immunothérapie Antiscorpionique (Sérum SAS de l\'Institut Pasteur d\'Algérie)',
            content: 'Indication formelle dès le Stade 2 ou 3.',
            bulletPoints: [
              'Sérum Antiscorpionique (SAS) polyvalent de l\'IPA : 1 à 2 ampoules en IV directe lente (ou perfusion dans 50 mL de NaCl 0,9% sur 15 min)',
              'Efficacité maximale si administré précocement (< 2 heures après la piqûre)',
              'Peut être répété après 2 heures si persistance ou aggravation des signes généraux',
            ],
          ),
          ClinicalStep(
            title: '3. Prise en charge en Réanimation (Stade 3 / Défaillance myocardique)',
            content: 'Le venin provoque une sidération myocardique par toxine inotrope négative et décharge catécholaminergique massive.',
            bulletPoints: [
              'Si OAP / Choc cardiogénique : Transfert immédiat en Réanimation UMC',
              'Oxygénothérapie fort débit ou ventilation non invasive (VNI)',
              'Inotrope positif de choix : Dobutamine IVSE (5 à 15 µg/kg/min)',
              'Contre-indication formelle aux bêtabloquants et aux digitaliques en phase aiguë',
            ],
          ),
        ],
        treatments: [
          'Sérum Antiscorpionique (SAS) IPA IV',
          'Dobutamine IVSE si choc cardiogénique',
          'Paracétamol injectable si douleur (éviter morphiniques qui majorent la dépression respiratoire)',
          'Vaccin Antitétanique (VAT)',
        ],
        references: 'Guide National de Prise en Charge de l\'Envenimation Scorpionique - Ministère de la Santé (MSPRH) & Institut Pasteur d\'Algérie (IPA).',
      ),
      const ClinicalProtocol(
        id: 'cat_rage_prophylaxie',
        title: 'Prophylaxie Post-Exposition de la Rage (Protocole Algérie - IPA/OMS)',
        specialty: 'Infectiologie & Santé Publique',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Conduite à tenir obligatoire après toute morsure, griffure ou léchage par un animal suspect (chien, chat, renard, chacal). La rage déclarée est mortelle à 100%.',
        redFlags: [
          'Catégorie I : Contact ou léchage sur peau intacte -> Pas de risque.',
          'Catégorie II : Morsure superficielle, griffure sans saignement -> Vaccin antirabique seul.',
          'Catégorie III : Morsure transdermique avec saignement, léchage sur peau lésée ou muqueuse, griffure tête/cou/mains -> Vaccin + Sérothérapie antirabique immédiate !',
          'Animal disparu, abattu ou mort -> Traiter d\'emblée comme animal enragé.',
        ],
        steps: [
          ClinicalStep(
            title: '1. Soins Locaux Immédiats (Étape salvatrice)',
            content: 'Élimine mécaniquement plus de 90% du virus présent dans la plaie.',
            bulletPoints: [
              'Lavage abondant et vigoureux à l\'eau et au savon (ou détergent) pendant au moins 15 minutes',
              'Rinçage à grande eau puis application d\'un antiseptique iodé (Bétadine) ou alcoolique',
              'NE PAS SUTURER la plaie d\'emblée (favorise l\'inoculation virale profonde) sauf impératif hémostatique majeur',
            ],
          ),
          ClinicalStep(
            title: '2. Vaccination Antirabique (Protocole Zagreb officiel)',
            content: 'Vaccin antirabique sur cellules Vero (fourni par l\'Institut Pasteur d\'Algérie).',
            bulletPoints: [
              'Schéma 2-1-1 (Zagreb) par voie intramusculaire dans le deltoïde (JAMAIS dans le fessier) :',
              '• J0 : 2 doses (1 injection deltoïde droit + 1 injection deltoïde gauche)',
              '• J7 : 1 dose',
              '• J21 : 1 dose',
            ],
          ),
          ClinicalStep(
            title: '3. Sérothérapie Antirabique (Catégorie III)',
            content: 'Immunoglobulines antirabiques humaines ou sérum équin.',
            bulletPoints: [
              'Dose : Sérum équin 40 UI/kg ou Immunoglobulines humaines 20 UI/kg',
              'Infiltrer la totalité de la dose autour et dans la plaie, le reste en IM à distance du site vaccinal',
              'Vérifier et mettre à jour la vaccination antitétanique (VAT + Sérum SAT)',
            ],
          ),
        ],
        treatments: [
          'Lavage à grande eau et savon (15 min)',
          'Vaccin antirabique IPA (J0, J0, J7, J21)',
          'Sérothérapie antirabique (plaie de cat. III)',
          'Vaccin Antitétanique (VAT) + Antibiothérapie préventive (Amoxicilline-Ac. Clavulanique)',
        ],
        references: 'Protocole National de Lutte contre la Rage - Ministère de la Santé Algérien & OMS.',
      ),
      const ClinicalProtocol(
        id: 'cat_acr_adulte',
        title: 'Arrêt Cardio-Respiratoire (ACR) Adulte (ERC / SFMU 2025)',
        specialty: 'Réanimation & UMC',
        urgencyLevel: 'Urgence Vitale Extrême',
        definition: 'Absence de conscience, de pouls carotidien et de respiration normale (ou gasps). Chaque minute perdue diminue la survie de 10%.',
        redFlags: [
          'Inconscient + Pas de respiration efficace (gasping)',
          'Reconnaissance immédiate en < 10 secondes',
          'Rythmes Choquables : Fibrillation Ventriculaire (FV), Tachycardie Ventriculaire sans pouls (TV)',
          'Rythmes Non Choquables : Asystolie, Activité Électrique Sans Pouls (AESP)',
        ],
        steps: [
          ClinicalStep(
            title: '1. Chaîne de survie & MCE immédiat',
            content: 'Alerter l\'équipe de déchocage / réa et débuter le massage cardiaque externe sans délai.',
            bulletPoints: [
              'MCE continu : fréquence 100-120/min, profondeur 5-6 cm, dépression complète du thorax',
              'Ratio compressions/ventilations 30:2 (ou compressions continues dès intubation)',
              'Poser le défibrillateur / scope sans interrompre le massage plus de 5 secondes',
            ],
          ),
          ClinicalStep(
            title: '2. Si Rythme Choquable (FV / TV)',
            content: 'Défibrillation précoce.',
            bulletPoints: [
              'Choc électrique externe (150-200 J biphasique) -> Reprise IMMÉDIATE du MCE pendant 2 min',
              'Après 3ème choc : Adrénaline 1 mg IV + Amiodarone 300 mg IV (ou Lidocaïne)',
              'Après 5ème choc : Adrénaline 1 mg IV + Amiodarone 150 mg IV',
              'Renouveler Adrénaline 1 mg tous les 2 cycles (3-5 min)',
            ],
          ),
          ClinicalStep(
            title: '3. Si Rythme Non Choquable (Asystolie / AESP)',
            content: 'MCE continu + Adrénaline immédiate + Recherche des causes réversibles (4H & 4T).',
            bulletPoints: [
              'Adrénaline 1 mg IV directe d\'emblée, répétée toutes les 3 à 5 minutes',
              'Rechercher et traiter les 4H : Hypoxie, Hypovolémie, Hypo/Hyperkaliémie, Hypothermie',
              'Rechercher et traiter les 4T : Pneumothorax sous Tension, Tamponnade, Toxiques, Thrombose (EP ou coronaire)',
            ],
          ),
        ],
        treatments: [
          'Adrénaline 1 mg IV toutes les 3-5 min',
          'Amiodarone 300 mg IV (après 3e choc), puis 150 mg',
          'Oxygénothérapie 100% avec ballon auto-remplisseur (BAVU)',
        ],
        references: 'Recommandations ERC / SFMU 2025/2026 - Réanimation Cardiorespiratoire Adulte.',
      ),
      const ClinicalProtocol(
        id: 'cat_choc_septique',
        title: 'Sepsis & Choc Septique (Surviving Sepsis Campaign / SFMU)',
        specialty: 'Réanimation & Infectiologie',
        urgencyLevel: 'Urgence Vitale',
        definition: 'Dysfonction d\'organe menaçant le pronostic vital causée par une réponse dérégulée de l\'hôte à une infection. Le choc septique associe hypotension persistante nécessitant des vasopresseurs et hyperlactatémie > 2 mmol/L.',
        redFlags: [
          'Score qSOFA >= 2 (PAS <= 100 mmHg, FR >= 22/min, Glasgow < 15)',
          'Hypotension réfractaire au remplissage (PAM < 65 mmHg)',
          'Marbrures cutanées des genoux, temps de recoloration cutanée > 3 sec, oligurie < 0,5 mL/kg/h',
          'Lactates sanguins élevés > 2 mmol/L (> 4 mmol/L = défaillance sévère)',
        ],
        steps: [
          ClinicalStep(
            title: '1. "Bundle" de la première heure (Hour-1 Bundle)',
            content: '5 actions salvatrices à exécuter impérativement dans les 60 premières minutes.',
            bulletPoints: [
              '1. Doser les lactates sanguins (répéter si > 2 mmol/L)',
              '2. Hémocultures (au moins 2 paires) AVANT de débuter les antibiotiques',
              '3. Antibiothérapie IV à large spectre immédiate adaptée à la porte d\'entrée suspectée',
              '4. Remplissage vasculaire rapide par cristalloïdes (NaCl 0,9% ou Ringer) : 30 mL/kg en perfusion en < 3 heures',
              '5. Noradrénaline précoce si PAM < 65 mmHg pendant ou après le remplissage',
            ],
          ),
          ClinicalStep(
            title: '2. Antibiothérapies de première intention selon la porte d\'entrée',
            content: 'Traiter fort et ciblé.',
            bulletPoints: [
              'Pulmonaire : Céfotaxime ou Ceftriaxone 2 g/j IV + Lévofloxacine ou Macrolide',
              'Urinaire : Céfotaxime/Ceftriaxone + Amikacine 25-30 mg/kg en dose unique journalière',
              'Digestive : Ceftriaxone + Métronidazole (Flagyl) 500 mg x 3/j + Gentamicine',
              'Inconnue : Pipéracilline-Tazobactam (Tazocilline) ou Céfépime + Amikacine',
            ],
          ),
        ],
        treatments: [
          'Cristalloïdes 30 mL/kg en perfusion rapide',
          'Noradrénaline IVSE titrée pour PAM >= 65 mmHg',
          'Ceftriaxone 2 g IV + Amikacine 25-30 mg/kg IV',
          'Hydrocortisone 200 mg/j IV si vasopresseurs à forte dose réfractaires',
        ],
        references: 'Surviving Sepsis Campaign (SSC) 2021 & Recommandations SFMU / SRLF.',
      ),
      const ClinicalProtocol(
        id: 'cat_triage_umc_algerie',
        title: 'Triage & Régulation des Urgences (Référentiel National Algérien)',
        specialty: 'Urgences Médico-Chirurgicales (UMC)',
        urgencyLevel: 'Organisationnel & Clinique',
        definition: 'Cadre réglementaire officiel du Ministère de la Santé (MSPRH) pour le tri et l\'accueil des urgences en milieu hospitalier et polyclinique.',
        redFlags: [
          'U1 (Code ROUGE) : Urgence Vitale Immédiate - Prise en charge sans délai (< 5 minutes en salle de déchoquage)',
          'U2 (Code ORANGE) : Urgence Grave Différée - Risque de décompensation rapide, soins < 30 minutes',
          'U3 (Code VERT) : Urgence Relative - Fonctions vitales stables, consultation et orientation ambulatoire / polyclinique',
        ],
        steps: [
          ClinicalStep(
            title: '1. Évaluation Initiale de l\'Infirmier d\'Accueil et d\'Orientation (IAO)',
            content: 'Détermination du code de gravité en < 3 minutes à l\'admission.',
            bulletPoints: [
              'Mesure systématique des constantes : TA, FC, SpO2, Température, Glycémie capillaire, Conscience (Glasgow)',
              'Recherche des signes d\'alarme vitale : cyanose, sueurs, tirage, marbrures, douleur thoracique aiguë',
              'Orientation immédiate : Déchoquage (U1), Box d\'examen prioritaire (U2), Salle d\'attente surveillée (U3)',
            ],
          ),
          ClinicalStep(
            title: '2. Gradation et Transferts inter-établissements',
            content: 'Désengorgement des CHU et utilisation optimale du plateau technique.',
            bulletPoints: [
              'Les polycliniques de proximité gèrent les cas U3 (sutures simples, asthme léger, angines, coliques néphrétiques simples)',
              'Les CHU et EPH concentrent les plateaux de réanimation, imagerie en coupe (TDM) et blocs opératoires d\'urgence',
            ],
          ),
        ],
        treatments: [
          'Scope de déchoquage U1',
          'Conditionnement immédiat : VVP, O2, monitoring',
          'Fiche de liaison d\'urgence standardisée MSPRH',
        ],
        references: 'Référentiel National des Urgences Médico-Chirurgicales - Ministère de la Santé (MSPRH Algérie).',
      ),
    ];
  }
}
