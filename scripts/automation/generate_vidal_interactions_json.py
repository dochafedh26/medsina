#!/usr/bin/env python3
"""
Medsina Platform - Comprehensive Vidal Drug-Drug Interaction Rules Generator
Covers the essential clinical pharmacopeia and high-risk prescription alerts
with exhaustive brand synonyms (Algeria & France) and active DCIs.
"""

import json
from pathlib import Path

rules = [
    # -------------------------------------------------------------------------
    # 1. ANTITHROMBOTIQUES & RISQUE HÉMORRAGIQUE MAJEUR
    # -------------------------------------------------------------------------
    {
        "drugA": [
            "ACENOCOUMAROL", "SINTROM", "AURACENO", "NOVAROL", 
            "WARFARINE", "COUMADINE", "FLUINDIONE", "PREVISCAN", "AVK", "ANTIVITAMINE K"
        ],
        "drugB": [
            "CLOPIDOGREL", "PLAVIX", "DAZIL", "PIDOGREL", "GREPID", "CLOPID", 
            "TICAGRELOR", "BRILIQUE", "PRASUGREL", "EFIENT", 
            "ASPIRINE", "KARDEGIC", "ASPEGIC", "ACIDE ACETYLSALICYLIQUE",
            "TICLOPIDINE", "TICLID", "ANTIAGREGANT", "ANTIAGREGANTS PLAQUETTAIRES"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Antivitamines K (Sintrom) + Antiagrégants Plaquettaires (Plavix, Clopidogrel, Kardégic)",
        "description": "Majoration majeure du risque hémorragique par addition des effets anticoagulants (inhibition de la synthèse des facteurs vit-K dépendants) et antiagrégants plaquettaires. Risque d'hémorragie digestive haute et d'accident vasculaire cérébral hémorragique.",
        "recommendation": "Association déconseillée sauf indication cardiologique formelle (ex: SCA ou angioplastie avec stent chez un patient ayant une indication formelle aux AVK : valve mécanique ou FA à haut risque). Si nécessaire : réduire la durée au strict minimum, maintenir l'INR dans la cible basse (2.0 - 2.5), associer systématiquement un protecteur gastrique (IPP: Pantoprazole 20mg) et surveiller l'hémogramme."
    },
    {
        "drugA": [
            "RIVAROXABAN", "XARELTO", "RIVAROX", "XARABAN",
            "APIXABAN", "ELIQUIS", "APIXAN",
            "DABIGATRAN", "PRADAXA", "EDOXABAN", "LIXIANA", "AOD", "ANTICOAGULANTS ORAUX DIRECTS"
        ],
        "drugB": [
            "CLOPIDOGREL", "PLAVIX", "DAZIL", "PIDOGREL",
            "TICAGRELOR", "BRILIQUE", "PRASUGREL", "EFIENT",
            "ASPIRINE", "KARDEGIC", "ASPEGIC", "ACIDE ACETYLSALICYLIQUE", "ANTIAGREGANT"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Anticoagulants Oraux Directs (AOD) + Antiagrégants Plaquettaires (Plavix, Aspirine)",
        "description": "Augmentation substantielle du risque d'hémorragie majeure (notamment gastro-intestinale et intracrânienne) par synergie pharmacodynamique antithrombotique.",
        "recommendation": "À réserver exclusivement aux suites immédiates d'angioplastie coronaire (stent). Limiter la bithérapie à la durée minimale recommandée (consensus ESC), associer obligatoirement un IPP et surveiller l'hémoglobine."
    },
    {
        "drugA": [
            "ACENOCOUMAROL", "SINTROM", "AURACENO", "NOVAROL", "WARFARINE", "COUMADINE", "AVK"
        ],
        "drugB": [
            "RIVAROXABAN", "XARELTO", "APIXABAN", "ELIQUIS", "DABIGATRAN", "PRADAXA", "EDOXABAN", "AOD"
        ],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Association de Deux Anticoagulants Oraux (AVK + AOD)",
        "description": "Risque hémorragique létal par surdosage anticoagulant sans bénéfice antithrombotique additionnel.",
        "recommendation": "Contre-indication absolue. En cas de relai d'un AOD vers un AVK ou inversement, suivre scrupuleusement les protocoles stricts de transition avec surveillance journalière de l'INR."
    },
    {
        "drugA": [
            "CLOPIDOGREL", "PLAVIX", "DAZIL", "PIDOGREL", "GREPID"
        ],
        "drugB": [
            "OMEPRAZOLE", "MOPRAL", "ZOLTUM", "LOSEC", "OMEBACT", 
            "ESOMEPRAZOLE", "INEXIUM", "NEXIUM", "ESOMEX"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Clopidogrel (Plavix) + Oméprazole / Éséméprazole",
        "description": "Diminution très significative des concentrations du métabolite actif du clopidogrel par inhibition puissante de son activation hépatique par le cytochrome CYP2C19, entraînant une diminution de son efficacité antiagrégante et un risque accru de récidive d'infarctus ou de thrombose aiguë de stent.",
        "recommendation": "Association déconseillée. En cas de nécessité d'une protection gastrique sous Clopidogrel, privilégier le Pantoprazole (Inipomp 20mg) ou le Rabéprazole (Pariet 10mg) qui n'inhibent pas le CYP2C19."
    },
    {
        "drugA": [
            "ACENOCOUMAROL", "SINTROM", "AURACENO", "NOVAROL", "WARFARINE", "AVK", "ANTIVITAMINE K"
        ],
        "drugB": [
            "KETOPROFENE", "PROFENID", "BI-PROFENID", "KETUM", 
            "DICLOFENAC", "VOLTARENE", "CLOFENAL", "DICLOGESIC", 
            "IBUPROFENE", "ADVIL", "NUROFEN", "BRUFEN", "ANTARENE", 
            "NAPROXENE", "APRANAX", "NAPROSYNE", 
            "CELECOXIB", "CELEBREX", "MELOXICAM", "MOBIC", 
            "INDOMETACINE", "INDOCID", "ACIDE TIAPROFENIQUE", "SURGAM", "PIROXICAM", "FELDENE", 
            "AINS", "ANTI-INFLAMMATOIRES NON STEROIDIENS"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Antivitamines K (Sintrom) + Anti-inflammatoires Non Stéroïdiens (AINS)",
        "description": "Majoration majeure du risque hémorragique par agression directe de la muqueuse gastroduodénale, inhibition réversible ou irréversible de l'agrégation plaquettaire surajoutée à l'hypoprothrombinémie.",
        "recommendation": "Association déconseillée. Si indispensable, surveillance clinique rigoureuse de tout signe de saignement digestif ou cutanéomuqueux, contrôle strict de l'INR et adjonction systématique d'un IPP (Pantoprazole ou Oméprazole 20mg)."
    },
    {
        "drugA": [
            "ACENOCOUMAROL", "SINTROM", "AURACENO", "NOVAROL", "WARFARINE", "AVK"
        ],
        "drugB": [
            "AMIODARONE", "CORDARONE", "AMIO"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Antivitamines K (Sintrom) + Amiodarone",
        "description": "Augmentation considérable de l'effet anticoagulant et risque hémorragique majeur par diminution du métabolisme hépatique de l'AVK (inhibition du CYP2C9). Cet effet peut persister plusieurs semaines après l'arrêt de l'amiodarone compte tenu de sa demi-vie prolongée.",
        "recommendation": "Contrôle de l'INR à J3, J5 puis hebdomadaire. Réduire la posologie de l'AVK d'un tiers à la moitié dès l'instauration de l'amiodarone."
    },
    {
        "drugA": [
            "ACENOCOUMAROL", "SINTROM", "AURACENO", "NOVAROL", "WARFARINE", "AVK"
        ],
        "drugB": [
            "RIFAMPICINE", "RIFAMYCINE", "RIFADINE", "RIMACTAN"
        ],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Antivitamines K (Sintrom) + Rifampicine",
        "description": "Diminution très importante des concentrations plasmatiques de l'antivitamine K par augmentation de son métabolisme hépatique par induction enzymatique (CYP2C9/CYP3A4), avec risque de moindre efficacité anticoagulante et récidive thromboembolique.",
        "recommendation": "Contrôler plus fréquemment l'INR (tous les 2 à 3 jours au début) et adapter la posologie de l'antivitamine K (Sintrom) pendant l'association et après son arrêt."
    },
    {
        "drugA": [
            "ACENOCOUMAROL", "SINTROM", "WARFARINE", "AVK"
        ],
        "drugB": [
            "MICONAZOLE", "DAKTARIN", "FLUCONAZOLE", "TRIFLUCAN", "VORICONAZOLE", "VFEND", "ITRACONAZOLE"
        ],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Antivitamines K (Sintrom) + Miconazole / Azolés",
        "description": "Hémorragies imprévisibles, potentiellement mortelles, par inhibition massive du catabolisme de l'AVK au niveau hépatique.",
        "recommendation": "Contre-indication absolue avec le Miconazole (y compris gel buccal). Avec le fluconazole, surveillance renforcée de l'INR et réduction préventive de la dose de Sintrom de 30 à 50%."
    },
    {
        "drugA": [
            "ENOXAPARINE", "LOVENOX", "CLEXANE", "ENOXAMED", "NADROPARINE", "FRAXIPARINE", "TINZAPARINE", "INNOHEP", "HEPARINE", "HNF", "HBPM"
        ],
        "drugB": [
            "KETOPROFENE", "PROFENID", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "NAPROXENE", "AINS"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Héparines (Énoxaparine) + AINS",
        "description": "Majoration importante du risque hémorragique par altération de l'hémostase primaire et lésions de la muqueuse digestive par les AINS.",
        "recommendation": "Association déconseillée, en particulier aux doses curatives d'héparine. Utiliser un antalgique non lésionnel (Paracétamol)."
    },
    {
        "drugA": [
            "ENOXAPARINE", "LOVENOX", "HEPARINE", "HBPM", "HNF"
        ],
        "drugB": [
            "CLOPIDOGREL", "PLAVIX", "ASPIRINE", "KARDEGIC", "TICAGRELOR", "PRASUGREL"
        ],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Héparines (Énoxaparine) + Antiagrégants Plaquettaires",
        "description": "Addition des effets antithrombotiques avec majoration du risque d'hémorragie digestive, cérébrale ou aux points de ponction.",
        "recommendation": "Association validée dans les syndromes coronariens aigus et l'angioplastie : requiert une surveillance clinique étroite (hématomes, saignements occultes, NFS régulière)."
    },
    {
        "drugA": [
            "CLOPIDOGREL", "PLAVIX", "DAZIL", "PIDOGREL", "TICAGRELOR", "PRASUGREL"
        ],
        "drugB": [
            "KETOPROFENE", "PROFENID", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "NAPROXENE", "CELECOXIB", "AINS"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Antiagrégants Plaquettaires (Plavix, Clopidogrel) + AINS",
        "description": "Augmentation substantielle du risque d'ulcération muqueuse et de saignement digestif haut par synergie néfaste entre l'inhibition plaquettaire et l'inhibition des COX digestives.",
        "recommendation": "Éviter les AINS chez les patients traités par antiagrégants. Si indispensable, prescription obligatoire d'un IPP gastroprotecteur."
    },
    {
        "drugA": [
            "CLOPIDOGREL", "PLAVIX", "DAZIL", "PIDOGREL"
        ],
        "drugB": [
            "ASPIRINE", "KARDEGIC", "ASPEGIC", "ACIDE ACETYLSALICYLIQUE"
        ],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Double Antiagrégation Plaquettaire (Plavix + Aspirine / Kardégic)",
        "description": "Synergie antiplaquettaire puissante augmentant le risque d'hémorragie digestive et cutanéo-muqueuse.",
        "recommendation": "Association de référence après syndrome coronarien aigu ou angioplastie avec pose de stent. Nécessite une durée d'exposition strictement limitée (selon score PRECISE-DAPT / ARC-HBR), surveillance clinique des saignements et coprescription d'IPP chez les patients à haut risque gastro-intestinal."
    },

    # -------------------------------------------------------------------------
    # 2. AINS, CORTICOÏDES & SYSTÈME GASTRO-INTESTINAL
    # -------------------------------------------------------------------------
    {
        "drugA": [
            "KETOPROFENE", "PROFENID", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "ADVIL", "NAPROXENE", "APRANAX", "CELECOXIB", "MELOXICAM", "INDOMETACINE"
        ],
        "drugB": [
            "ASPIRINE", "KARDEGIC", "ASPEGIC", "ACIDE ACETYLSALICYLIQUE", "KETOPROFENE", "DICLOFENAC", "IBUPROFENE", "NAPROXENE", "AINS"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Association de Deux Anti-inflammatoires Non Stéroïdiens (AINS)",
        "description": "Majoration majeure du risque d'ulcération gastro-duodénale, perforation et hémorragie digestive haute par effet cumulatif sans bénéfice antalgique supplémentaire.",
        "recommendation": "Supprimer l'un des deux AINS. Si aspirine antiagrégante requise, associer systématiquement un IPP protecteur (Pantoprazole ou Oméprazole 20mg)."
    },
    {
        "drugA": [
            "PREDNISONE", "CORTANCYL", "PREDNISOLONE", "SOLUPRED", "METHYLPREDNISOLONE", "SOLUMEDROL", "BETAMETHASONE", "CELESTENE", "DEXAMETHASONE", "CORTICOIDES"
        ],
        "drugB": [
            "KETOPROFENE", "PROFENID", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "NAPROXENE", "AINS"
        ],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Corticoïdes + AINS",
        "description": "Augmentation majeure du risque d'ulcération gastroduodénale et d'hémorragie digestive haute par inhibition conjointe des prostaglandines et de la trophicité muqueuse.",
        "recommendation": "Associer systématiquement un inhibiteur de la pompe à protons (Oméprazole ou Pantoprazole 20 à 40 mg/j)."
    },
    {
        "drugA": [
            "FLUOXETINE", "PROZAC", "PAROXETINE", "DEROXAT", "SERTRALINE", "ZOLOFT", "ESCITALOPRAM", "SEROPLEX", "CITALOPRAM", "SEROPRAM", "VENLAFAXINE", "EFFEXOR", "ISRS"
        ],
        "drugB": [
            "KETOPROFENE", "PROFENID", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "ASPIRINE", "KARDEGIC", "AINS"
        ],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Antidépresseurs Sérotoninergiques (ISRS) + AINS ou Aspirine",
        "description": "Risque accru de saignement, en particulier gastro-intestinal, par déplétion plaquettaire en sérotonine (altération de l'activation plaquettaire) combinée aux lésions muqueuses des AINS.",
        "recommendation": "Surveillance des signes d'hémorragie occulte. Envisager un IPP chez les patients présentant d'autres facteurs de risque digestif (âge > 65 ans, antécédent d'ulcère)."
    },

    # -------------------------------------------------------------------------
    # 3. COLCHICINE, MÉTHOTREXATE & ONCO-HÉMATOLOGIE
    # -------------------------------------------------------------------------
    {
        "drugA": ["COLCHICINE", "COLCHIMAX"],
        "drugB": ["CLARITHROMYCINE", "ZECLAR", "NAXOGYN", "ERYTHROMYCINE", "TELITHROMYCINE", "MACROLIDES"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Colchicine + Macrolides (Clarithromycine)",
        "description": "Majoration des effets indésirables de la colchicine par inhibition de son métabolisme par le CYP3A4 et blocage de la glycoprotéine P, entraînant une intoxication colchicinique aiguë gravissime potentiellement létale (agranulocytose, collapsus, défaillance multiviscérale).",
        "recommendation": "Contre-indication formelle. Utiliser un autre antibiotique sans effet inhibiteur enzymatique (Amoxicilline, Céfotaxime)."
    },
    {
        "drugA": ["COLCHICINE", "COLCHIMAX"],
        "drugB": ["CICLOSPORINE", "NEORAL", "SANDIMMUN", "ATORVASTATINE", "TAHOR", "SIMVASTATINE", "ZOCOR", "STATINES"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Colchicine + Ciclosporine ou Statines",
        "description": "Majoration du risque de toxicité neuromusculaire (myopathie toxique, rhabdomyolyse aiguë) et rénale.",
        "recommendation": "Association déconseillée. En cas de traitement concomitant indispensable, surveiller étroitement les signes musculaires et la fonction rénale, doser les CPK."
    },
    {
        "drugA": ["METHOTREXATE", "NOVATREX", "METOJECT"],
        "drugB": ["KETOPROFENE", "PROFENID", "ASPIRINE", "KARDEGIC", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "AINS"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Méthotrexate + AINS",
        "description": "Majoration de la toxicité hématologique (aplasie médullaire létale) et rénale du méthotrexate par diminution de sa clairance rénale tubulaire et déplacement de ses sites de fixation protéique par les AINS.",
        "recommendation": "Contre-indication absolue si Méthotrexate > 20 mg/semaine. Pour les faibles doses de rhumatologie, réaliser une NFS et un contrôle de la fonction rénale chaque semaine."
    },
    {
        "drugA": ["METHOTREXATE", "NOVATREX", "METOJECT"],
        "drugB": ["COTRIMOXAZOLE", "BACTRIM", "TRIMETHOPRIME", "SULFAMETHOXAZOLE"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Méthotrexate + Cotrimoxazole (Bactrim)",
        "description": "Pancytopénie sévère, aplasie médullaire foudroyante par synergie d'inhibition enzymatique sur la dihydrofolate réductase et diminution de l'excrétion tubulaire du méthotrexate.",
        "recommendation": "Contre-indication formelle et absolue. Utiliser une autre classe antibiotique."
    },
    {
        "drugA": ["ALLOPURINOL", "ZYLORIC", "FEBUXOSTAT", "ADENURIC"],
        "drugB": ["AZATHIOPRINE", "IMUREL", "MERCAPTOPURINE", "PURINETHOL"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Allopurinol + Azathioprine (Imurel)",
        "description": "Aplasie médullaire aiguë gravissime potentiellement mortelle par inhibition de la xanthine-oxydase, enzyme clé du catabolisme de l'azathioprine et de la 6-mercaptopurine, provoquant leur accumulation toxique massive.",
        "recommendation": "Contre-indication formelle. Si l'association est incontournable, réduire la dose d'azathioprine à 25% (un quart) de la posologie habituelle et surveiller la NFS de manière hebdomadaire."
    },

    # -------------------------------------------------------------------------
    # 4. CARDIOVASCULAIRE, HYPERTENSION & DYSRHYTHMIES
    # -------------------------------------------------------------------------
    {
        "drugA": ["TRINITRINE", "NATISPRAY", "LENITRAL", "ISOSORBIDE", "RISORDAN", "MOLSIDOMINE", "CORVASAL", "DERIVES NITRES"],
        "drugB": ["SILDENAFIL", "VIAGRA", "REVATIO", "TADALAFIL", "CIALIS", "VARDENAFIL", "LEVITRA", "INHIBITEURS PDE5"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Dérivés Nitrés + Inhibiteurs de la PDE-5 (Viagra, Cialis)",
        "description": "Risque d'hypotension artérielle sévère, collapsus cardiovasculaire brutal, ischémie myocardique aiguë et arrêt cardiaque par synergie vasodilatatrice puissante sur la voie NO/GMPc.",
        "recommendation": "Contre-indication formelle et absolue. Respecter un délai minimal de 24h (Sildénafil) ou 48h (Tadalafil) avant tout dérivé nitré."
    },
    {
        "drugA": ["PERINDOPRIL", "COVERSYL", "RAMIPRIL", "TRIATEC", "VALSARTAN", "TAREG", "CANDESARTAN", "ATACAND", "LOSARTAN", "COZAAR", "IRBESARTAN", "APROVEL", "IEC", "ARA2"],
        "drugB": ["SPIRONOLACTONE", "ALDACTONE", "EPLERENONE", "INSPRA", "AMILORIDE"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "IEC / ARA2 + Spironolactone (Diurétique épargneur de K+)",
        "description": "Risque d'hyperkaliémie sévère potentiellement mortelle par double blocage du système rénine-angiotensine-aldostérone, en particulier chez l'insuffisant rénal ou le sujet âgé.",
        "recommendation": "Surveillance rigoureuse de la kaliémie et de la créatininémie à J7, J15 puis tous les mois. Éviter tout apport potassique supplémentaire."
    },
    {
        "drugA": ["PERINDOPRIL", "RAMIPRIL", "ENALAPRIL", "CAPTOPRIL", "IEC"],
        "drugB": ["VALSARTAN", "CANDESARTAN", "LOSARTAN", "IRBESARTAN", "TELMISARTAN", "ARA2", "SARTANS"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "IEC + ARA2 (Double blocage du Système Rénine-Angiotensine)",
        "description": "Risque accru d'hypotension artérielle, de syncope, d'hyperkaliémie et d'insuffisance rénale aiguë sans bénéfice cardiovasculaire additionnel démontré.",
        "recommendation": "Association déconseillée voire contre-indiquée (études ONTARGET). Utiliser un seul bloqueur du SRAA."
    },
    {
        "drugA": ["PERINDOPRIL", "RAMIPRIL", "VALSARTAN", "CANDESARTAN", "IEC", "ARA2"],
        "drugB": ["KETOPROFENE", "PROFENID", "ASPIRINE", "KARDEGIC", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "AINS"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "IEC / ARA2 + AINS (Trépied hémodynamique rénal)",
        "description": "Insuffisance rénale aiguë par diminution de la filtration glomérulaire (l'AINS bloque la synthèse des prostaglandines vasodilatatrices de l'artériole afférente tandis que l'IEC dilate l'artériole efférente) et baisse de l'effet antihypertenseur.",
        "recommendation": "Hydrater le patient, surveiller la fonction rénale et la pression artérielle en début de traitement."
    },
    {
        "drugA": ["AMIODARONE", "CORDARONE"],
        "drugB": ["BISOPROLOL", "CARVEDILOL", "METOPROLOL", "SOTALOL", "DILTIAZEM", "VERAPAMIL", "BETA-BLOQUANTS"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Amiodarone + Bradycardisants / Bêta-bloquants",
        "description": "Risque de troubles majeurs de l'automatisme cardiaque (bradycardie sinusale excessive), d'échappement ventriculaire et de bloc auriculoventriculaire (BAV) complet.",
        "recommendation": "Surveillance clinique et électrocardiographique (ECG) régulière."
    },
    {
        "drugA": ["BISOPROLOL", "CARDENSIEL", "METOPROLOL", "ATENOLOL", "CARVEDILOL", "PROPRANOLOL", "BETA-BLOQUANTS"],
        "drugB": ["VERAPAMIL", "ISOPTINE", "DILTIAZEM", "TILDIEM"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Bêta-bloquants + Inhibiteurs Calciques Bradycardisants (Vérapamil, Diltiazem)",
        "description": "Troubles graves du rythme et de la conduction : bradycardie extrême, arrêt sinusal, BAV de haut degré, défaillance cardiaque aiguë et collapsus.",
        "recommendation": "Contre-indication formelle par voie intraveineuse. En voie orale, association fortement déconseillée à réserver au spécialiste."
    },
    {
        "drugA": ["AMIODARONE", "CORDARONE", "SOTALOL", "SOTAHEXAL"],
        "drugB": ["CLARITHROMYCINE", "ZECLAR", "ERYTHROMYCINE", "CIPROFLOXACINE", "LEVOFLOXACINE", "MOXIFLOXACINE", "HALOPERIDOL", "CHLORPROMAZINE", "AMISULPRIDE"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Médicaments Donnant des Torsades de Pointes (Allongement du QT)",
        "description": "Risque accru de troubles du rythme ventriculaire graves, notamment torsades de pointes et fibrillation ventriculaire mortelle par allongement synergique de l'intervalle QT.",
        "recommendation": "Contre-indication formelle. Pratiquer un ECG préalable, contrôler la kaliémie et la magnésémie."
    },
    {
        "drugA": ["DIGOXINE"],
        "drugB": ["AMIODARONE", "CORDARONE"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Digoxine + Amiodarone",
        "description": "Majoration de la digoxinémie (de 50 à 100%) par inhibition de son élimination rénale et de la P-glycoprotéine, avec risque majeur d'intoxication digitalique (nausées, vision jaune, BAV, tachycardie ventriculaire).",
        "recommendation": "Diminuer la posologie de digoxine de moitié dès l'introduction de l'amiodarone, doser la digoxinémie et surveiller l'ECG."
    },
    {
        "drugA": ["DIGOXINE"],
        "drugB": ["GLUCONATE DE CALCIUM", "CALCIUM CHLORURE", "CALCIUM IV"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Digoxine + Calcium IV",
        "description": "Troubles du rythme ventriculaire graves, voire arrêt cardiaque mortel par synergie sur l'inotropisme et le potentiel d'action myocardique.",
        "recommendation": "Contre-indication formelle à l'injection intraveineuse de sels de calcium chez le patient digitalisé."
    },
    {
        "drugA": ["DIGOXINE"],
        "drugB": ["CLARITHROMYCINE", "ZECLAR", "ERYTHROMYCINE", "TELITHROMYCINE", "MACROLIDES"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Digoxine + Macrolides",
        "description": "Augmentation de la digoxinémie par inactivation de la flore digestive métabolisante (Eubacterium lentum) et inhibition de la P-gp, majorant le risque d'intoxication digitalique.",
        "recommendation": "Surveillance clinique, ECG et dosage de la digoxinémie. Adapter la posologie de digoxine pendant le traitement macrolide."
    },

    # -------------------------------------------------------------------------
    # 5. SYSTÈME NERVEUX CENTRAL & PSYCHIATRIE
    # -------------------------------------------------------------------------
    {
        "drugA": ["DIAZEPAM", "VALIUM", "ALPRAZOLAM", "XANAX", "LORAZEPAM", "TEMESTA", "BROMAZEPAM", "LEXOMIL", "CLONAZEPAM", "RIVOTRIL", "BENZODIAZEPINES"],
        "drugB": ["MORPHINE", "OXYCODONE", "OXYCONTIN", "FENTANYL", "DUROGESIC", "METHADONE", "TRAMADOL", "CODEINE", "OPIOIDES"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Benzodiazépines + Opioïdes",
        "description": "Synergie dépressive respiratoire centrale et sédation profonde : risque majeur de détresse respiratoire, coma hypercapnique et décès par arrêt respiratoire.",
        "recommendation": "Réduire les doses au minimum efficace, surveiller la saturation en oxygène (SpO2) et la fréquence respiratoire. Disposer de Naloxone et Flumazénil."
    },
    {
        "drugA": ["TRAMADOL", "TOPALGIC", "CONTRAMAL", "ZALDIAR"],
        "drugB": ["FLUOXETINE", "PROZAC", "PAROXETINE", "DEROXAT", "SERTRALINE", "ZOLOFT", "VENLAFAXINE", "EFFEXOR", "DULOXETINE", "CYMBALTA", "ISRS"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Tramadol + Antidépresseurs Sérotoninergiques (ISRS/IRSNa)",
        "description": "Risque accru de convulsions par abaissement du seuil épileptogène et risque de syndrome sérotoninergique potentiellement fatal (hyperthermie, myoclonies, confusion).",
        "recommendation": "Surveiller les signes évocateurs (sueurs, tremblements, rigidité). Respecter scrupuleusement les posologies recommandées."
    },
    {
        "drugA": ["LITHIUM", "TERALITHE"],
        "drugB": ["KETOPROFENE", "PROFENID", "ASPIRINE", "DICLOFENAC", "VOLTARENE", "IBUPROFENE", "AINS", "HYDROCHLOROTHIAZIDE", "FUROSEMIDE", "PERINDOPRIL", "RAMIPRIL", "IEC"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Lithium + AINS, Diurétiques ou IEC",
        "description": "Augmentation de la lithémie pouvant atteindre des seuils toxiques par diminution de l'excrétion rénale tubulaire du lithium.",
        "recommendation": "Association déconseillée. Si nécessaire, surveillance rapprochée de la lithémie et ajustement posologique."
    },

    # -------------------------------------------------------------------------
    # 6. MÉTABOLISME, STATINES & DIABÈTE
    # -------------------------------------------------------------------------
    {
        "drugA": ["ATORVASTATINE", "TAHOR", "SIMVASTATINE", "ZOCOR", "STATINES"],
        "drugB": ["CLARITHROMYCINE", "ZECLAR", "ERYTHROMYCINE", "TELITHROMYCINE", "MACROLIDES"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Statines (Simvastatine / Atorvastatine) + Macrolides",
        "description": "Majoration très importante des concentrations plasmatiques de la statine par inhibition puissante du CYP3A4, avec risque majeur de rhabdomyolyse aiguë et d'insuffisance rénale anurique.",
        "recommendation": "Contre-indication formelle avec la simvastatine. Pour l'atorvastatine, interrompre temporairement le traitement par statine pendant l'antibiothérapie ou utiliser la Pravastatine."
    },
    {
        "drugA": ["ATORVASTATINE", "TAHOR", "SIMVASTATINE", "ZOCOR", "ROSUVASTATINE", "CRESTOR", "STATINES"],
        "drugB": ["GEMFIBROZIL", "LIPUR", "FENOFIBRATE", "LIPANTHYL", "FIBRATES"],
        "severity": "contraindicated",
        "severityLevel": 4,
        "title": "Statines + Fibrates (Gemfibrozil, Fénofibrate)",
        "description": "Majoration du risque d'atteinte musculaire (myopathie toxique, rhabdomyolyse aiguë avec myoglobinurie et insuffisance rénale aiguë).",
        "recommendation": "Contre-indication absolue avec le Gemfibrozil. Avec le fénofibrate, surveillance clinique et dosage des CPK avant et en cours de traitement."
    },
    {
        "drugA": ["METFORMINE", "GLUCOPHAGE", "STAGID"],
        "drugB": ["PRODUITS DE CONTRASTE IODES", "TELEBRIX", "XENETIX", "OMNIPAQUE", "SCANNER INJECTE", "IODE IV"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Metformine + Produits de Contraste Iodés (Scanner Injecté)",
        "description": "Risque d'acidose lactique aiguë foudroyante en cas de survenue d'une insuffisance rénale fonctionnelle induite par l'injection de produit de contraste iodé.",
        "recommendation": "Arrêter la metformine 48h avant l'examen injecté (ou au moment de l'examen en urgence). Ne reprendre que 48h après contrôle d'une créatininémie normale."
    },

    # -------------------------------------------------------------------------
    # 7. INFECTIOLOGIE & ENZYMOLOGIE
    # -------------------------------------------------------------------------
    {
        "drugA": ["FUROSEMIDE", "LASILIX", "DIURETIQUES DE L'ANSE"],
        "drugB": ["GENTAMICINE", "GENTALLINE", "AMIKACINE", "AMIKLIN", "TOBRAMYCINE", "AMINOSIDES"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Furosémide + Aminosides (Gentamicine)",
        "description": "Majoration de la néphrotoxicité et de l'ototoxicité (lésions irréversibles de la cochlée et de l'appareil vestibulaire) par toxicité cellulaire synergique.",
        "recommendation": "Assurer une hydratation hydro-électrolytique adéquate, surveiller la fonction rénale et doser les taux résiduels de l'aminoside."
    },
    {
        "drugA": ["CIPROFLOXACINE", "CIFLOX", "LEVOFLOXACINE", "TAVANIC", "OFLOXACINE", "OFLOCET", "FLUOROQUINOLONES"],
        "drugB": ["PREDNISONE", "CORTANCYL", "SOLUPRED", "METHYLPREDNISOLONE", "CORTICOIDES"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Fluoroquinolones + Corticoïdes",
        "description": "Augmentation notable du risque de tendinite et de rupture tendineuse (notamment du tendon d'Achille), en particulier chez le sujet âgé de plus de 60 ans.",
        "recommendation": "Informer le patient d'arrêter tout effort et de consulter d'urgence au moindre signe de douleur au talon."
    },
    {
        "drugA": ["RIFAMPICINE", "RIFAMYCINE", "CARBAMAZEPINE", "TEGRETOL", "PHENYTOINE", "PHENOBARBITAL"],
        "drugB": ["ETHINYLESTRADIOL", "LEVONORGESTREL", "DESOGESTREL", "MINIDRIL", "MICROGYNON", "CONTRACEPTIFS ORAUX"],
        "severity": "disadvised",
        "severityLevel": 3,
        "title": "Inducteurs Enzymatiques + Contraceptifs Hormonaux",
        "description": "Diminution drastique de l'efficacité contraceptive par augmentation du métabolisme hépatique des œstroprogestatifs par induction enzymatique, avec risque élevé de grossesse non désirée.",
        "recommendation": "Utiliser impérativement une méthode contraceptive non hormonale (préservatif, stérilet au cuivre) pendant toute la durée du traitement et jusqu'à 4 semaines après son arrêt."
    },
    {
        "drugA": ["RIFAMPICINE", "RIFAMYCINE"],
        "drugB": ["ATORVASTATINE", "TAHOR", "SIMVASTATINE", "ZOCOR", "ROSUVASTATINE", "CRESTOR", "STATINES"],
        "severity": "precaution",
        "severityLevel": 2,
        "title": "Rifampicine + Statines",
        "description": "Baisse très importante des concentrations plasmatiques de la statine par induction du CYP3A4 et des transporteurs OATP, diminuant l'effet hypocholestérolémiant.",
        "recommendation": "Surveiller le bilan lipidique et réévaluer la posologie de la statine."
    }
]

def main():
    target_path = Path(__file__).resolve().parents[2] / "assets" / "data" / "vidal_drug_interactions.json"
    target_path.parent.mkdir(parents=True, exist_ok=True)
    with open(target_path, "w", encoding="utf-8") as f:
        json.dump(rules, f, ensure_ascii=False, indent=2)

    print(f"[OK] Generated {len(rules)} exhaustive Vidal drug interaction rules into {target_path}")

if __name__ == "__main__":
    main()
