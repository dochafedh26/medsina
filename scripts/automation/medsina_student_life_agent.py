#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - AGENT AUTONOME "VIE RÉELLE DE L'ÉTUDIANT EN MÉDECINE" (1ère à 6ème Année)
=============================================================================
Simule le déroulement de la vie universitaire réelle d'un étudiant en médecine :
1. Matin (08h00) : Phase "Lit du Malade & Visite de Stage" (ou TP ostéo/bioch 1ère-2ème)
2. Après-Midi (14h00) : Phase "Séance d'Amphi & Cours Magistral" avec Piège du Professeur aux EMDs
3. Soir (19h00) : Phase "Défi EMD du Soir & Suivi de Stage" (3 QCMs flash + décompte rotation)
4. Fin de Rotation (J-3) : Alerte "EMD Blanc Chronométré /20" pour valider le module

Multi-Diffusion Ciblée :
- Telegram : Canal officiel (@medsina_officiel) & Topics du supergroupe (ID 8 & ID 18)
  avec hashtags par promotion (#1ereAnnee, #4emeAnnee, #MedsinaTeacher...)
- Facebook : Pages Résidanat Blida 2027, Medsina Officiel, MedevSync avec infographie
- Supabase In-App : Notification temps réel aux étudiants
=============================================================================
"""

import os
import sys
import json
import time
import random
import argparse
import datetime
import requests
from pathlib import Path
from typing import Dict, Any, List, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from generate_modern_light_banner import build_modern_light_banner
except ImportError:
    build_modern_light_banner = None

try:
    from telegram_publisher import send_telegram_broadcast
except ImportError:
    send_telegram_broadcast = None

try:
    from notify_multichannel import send_in_app_notification
except ImportError:
    send_in_app_notification = None

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    or os.environ.get("SUPABASE_KEY")
    or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

OFFICIAL_TELEGRAM_URL = "https://t.me/medsina_officiel"
OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"

# Drives Officiels Faculté de Médecine Blida & Promotions
YEAR_DRIVE_LINKS = {
    1: "https://drive.google.com/drive/folders/1OpTSOfoyXF8sTK1tW2323KmAqXzBVUzV",
    2: "https://drive.google.com/drive/folders/1mNbDj7B936Tm2O87ycOCqqXvCvOUI5EL",
    3: "https://drive.google.com/drive/folders/1TZhLE7o-QQVemz5oxAqO46SoM2rCcYep",
    4: "https://drive.google.com/drive/folders/1TZhLE7o-QQVemz5oxAqO46SoM2rCcYep",
    5: "https://drive.google.com/drive/folders/13Z89CeV8bpQlL74OVFMfjrone2M0XQ--",
    6: "https://drive.google.com/drive/folders/1-4j0fd19TOa4jyAFeIIzbh6zIu085O5q",
}
BLIDA_GENERAL_DRIVE = "https://drive.google.com/drive/folders/1fPjicGWf2sFz5oJ6nTxWExlT5FggBVml"
BLIDA_COLLECTION_DRIVE = "https://drive.google.com/drive/folders/13sszUJvcPvFFROkVxFLcF2FcFnm2QAKz"
SAMEDI_PEDAGOGIQUE_2026_DRIVE = "https://drive.google.com/drive/folders/1NXSP4l7Eip9eKxsRKgUy5qRZDG4zEF1k"

# Dictionnaire des personas enseignants MedsinaTeacher par année
TEACHERS_CATALOG = {
    1: {
        "year": 1,
        "name": "MedsinaTeacher - Sciences Fondamentales & Anatomie",
        "short_name": "MedsinaTeacher 1ère Année",
        "title": "Professeur en Sciences Fondamentales & Anatomie",
        "tagline": "Maîtrisez les bases anatomiques et biochimiques sans apprendre par cœur inutilement.",
        "theme": "teal",
        "tag": "#1ereAnnee_Medecine",
        "modules": ["Anatomie Générale", "Ostéologie & Arthrologie", "Biochimie Structurale", "Cytologie", "Embryologie"],
        "sample_topics": [
            {
                "module": "Anatomie Générale",
                "topic": "Plexus Brachial & Nerf Radial",
                "morning_focus": "Recherche du trajet du nerf radial dans la gouttière humérale et testing du signe de la main en col de cygne.",
                "lecture_focus": "Rapports anatomiques des racines C5 à T1, faisceaux et innervation sensitive et motrice de l'avant-bras.",
                "trap": "Confondre l'innervation de la face dorsale de la 1ère commissure (nerf radial pur) avec le nerf médian.",
                "flash_q": "Quelle racine innerve principalement le réflexe tricipital ? Réponse : C7.",
                "rotation_weeks": 4,
            },
            {
                "module": "Biochimie",
                "topic": "Cycle de Krebs & Voie des Pentoses Phosphates",
                "morning_focus": "Observation des réactions enzymatiques et régulation par le rapport ATP/ADP et NADH.",
                "lecture_focus": "Étapes irréversibles régulatrices (Citrate synthase, Isocitrate DH, Alpha-cétoglutarate DH) et bilan énergétique.",
                "trap": "Oublier que la Succinate Déshydrogénase est la seule enzyme liée à la membrane mitochondriale interne (Complexe II).",
                "flash_q": "Combien d'ATP sont générés par tour de cycle de Krebs complet ? Réponse : 10 ATP (selon P/O moderne).",
                "rotation_weeks": 4,
            }
        ]
    },
    2: {
        "year": 2,
        "name": "MedsinaTeacher - Physiologie & Unités Intégrées",
        "short_name": "MedsinaTeacher 2ème Année",
        "title": "Maître-Assistant en Physiologie & Unités Intégrées",
        "tagline": "Comprendre la physiologie normale, c'est résoudre d'avance toutes les pathologies.",
        "theme": "cyan",
        "tag": "#2emeAnnee_Medecine",
        "modules": ["Unité Cardio-Respiratoire", "Unité Rénale", "Unité Digestive", "Neurophysiologie"],
        "sample_topics": [
            {
                "module": "Unité Cardio-Respiratoire",
                "topic": "Régulation de la Pression Artérielle & Baroréflexe",
                "morning_focus": "Enregistrement de la pression artérielle aux deux bras et manœuvre de Valsalva.",
                "lecture_focus": "Boucle à court terme (barorécepteurs sinu-carotidiens et aortiques) vs système rénine-angiotensine-aldostérone (moyen terme).",
                "trap": "Attribuer l'effet chronotrope négatif au nerf sympathique alors qu'il est exclusivement médié par le pneumogastrique (X).",
                "flash_q": "Quel nerf transmet les afférences baroréceptrices du sinus carotidien ? Réponse : Nerf de Hering (IX).",
                "rotation_weeks": 6,
            },
            {
                "module": "Unité Rénale",
                "topic": "Filtration Glomérulaire & Système Contre-Courant",
                "morning_focus": "Calcul de la clairance rénale et analyse de la fraction d'excrétion sodée.",
                "lecture_focus": "Forces de Starling glomérulaires, gradient cortico-médullaire et rôle de l'anse de Henle.",
                "trap": "Confondre l'effet de l'angiotensine II sur l'artériole efférente (vasoconstriction qui préserve le DFG) avec l'afférente.",
                "flash_q": "Où s'exerce l'action majeure de l'aldostérone ? Réponse : Tube contourné distal et canal collecteur.",
                "rotation_weeks": 6,
            }
        ]
    },
    3: {
        "year": 3,
        "name": "MedsinaTeacher - Sémiologie & Pré-Clinique",
        "short_name": "MedsinaTeacher 3ème Année",
        "title": "Chef de Clinique en Sémiologie Médicale & Chirurgicale",
        "tagline": "De l'amphi au lit du malade : l'examen clinique rigoureux fait 80% du diagnostic.",
        "theme": "indigo",
        "tag": "#3emeAnnee_Medecine",
        "modules": ["Sémiologie Cardiovasculaire", "Sémiologie Pleuro-Pulmonaire", "Sémiologie Abdominale", "Sémiologie Neurologique"],
        "sample_topics": [
            {
                "module": "Sémiologie Cardiovasculaire",
                "topic": "Souffles Cardiaques & Auscultation Valvulaire",
                "morning_focus": "Auscultation systématique aux 4 foyers : recherche du souffle systolique râpeux irradiant aux carotides.",
                "lecture_focus": "Différencier Rétrécissement Aortique (mésosystolique, éjection) et Insuffisance Mitrale (holosystolique, irradiation axillaire).",
                "trap": "Penser qu'un éclat de B2 au foyer aortique témoigne d'un rétrécissement aortique calcifié serré (en réalité B2 est aboli).",
                "flash_q": "Quel signe physique signe une insuffisance aortique sévère ? Réponse : Élargissement de la différentielle tensionnelle.",
                "rotation_weeks": 6,
            },
            {
                "module": "Sémiologie Pleuro-Pulmonaire",
                "topic": "Syndromes d'Épanchement Pleural Liquidien & Aérien",
                "morning_focus": "Recherche de la triade d'épanchement liquidien : abolition du murmure vésiculaire, matité franche, abolition des vibrations vocales.",
                "lecture_focus": "Comparaison clinique rigoureuse entre pleurésie et condensation pulmonaire (vibrations vocales augmentées dans la condensation).",
                "trap": "Confondre la matité avec tympanisme : dans le pneumothorax, les vibrations vocales et murmure sont abolis avec tympanisme franc.",
                "flash_q": "Quel est le repère d'introduction d'une ponction pleurale exploratrice ? Réponse : Bord supérieur de la côte inférieure.",
                "rotation_weeks": 6,
            }
        ]
    },
    4: {
        "year": 4,
        "name": "MedsinaTeacher - Pathologie Médicale & Chirurgicale I",
        "short_name": "MedsinaTeacher 4ème Année",
        "title": "Professeur Hospitalo-Universitaire en Clinique I",
        "tagline": "Grandes pathologies d'hospitalisation : raisonnement rapide, consensus et zéro impasse.",
        "theme": "emerald",
        "tag": "#4emeAnnee_Externat",
        "modules": ["Cardiologie", "Pneumologie", "Hépato-Gastro-Entérologie", "Neurologie", "Infectieux", "Hématologie"],
        "sample_topics": [
            {
                "module": "Cardiologie",
                "topic": "Syndrome Coronarien Aigu ST+ (Infarctus du Myocarde)",
                "morning_focus": "Devant une douleur thoracique rétrosternale constrictive > 20 min, ECG 12 dérivations en < 10 min et pose de 2 voies veineuses.",
                "lecture_focus": "Territoires ECG, coronarographie d'urgence < 120 min ou fibrinolyse si délai > 120 min selon ESC 2023. Double anti-agrégation immédiate.",
                "trap": "Attendre le résultat de la troponine pour déclencher la coronarographie d'un SCA ST+ (perte de temps fatale, l'ECG suffit).",
                "flash_q": "Quelle dérivation explore la paroi inférieure du ventricule gauche ? Réponse : DII, DIII, aVF.",
                "rotation_weeks": 6,
            },
            {
                "module": "Pneumologie",
                "topic": "Exacerbation Sévère d'Asthme & Asthme Aigu Grave (AAG)",
                "morning_focus": "Recherche des signes de lutte : tirage sus-sternal, respiration paradoxale, impossibilité de prononcer une phrase, DEP < 50%.",
                "lecture_focus": "Nébulisation continue de Salbutamol + Ipratropium sous O2, corticothérapie systémique précoce, surveillance gazométrique.",
                "trap": "Considérer le silence auscultatoire comme une amélioration : c'est un signe d'épuisement respiratoire imminent (drapeau rouge absolu).",
                "flash_q": "Quel gaz du sang traduit une gravité extrême dans l'AAG ? Réponse : Normocapnie ou hypercapnie (épuisement).",
                "rotation_weeks": 6,
            }
        ]
    },
    5: {
        "year": 5,
        "name": "MedsinaTeacher - Pathologie Médico-Chirurgicale II",
        "short_name": "MedsinaTeacher 5ème Année",
        "title": "Professeur en Spécialités Médico-Chirurgicales",
        "tagline": "Gérer les rotations courtes avec intensité : Pédiatrie, Gynécologie, ORL et Ophtalmo.",
        "theme": "amber",
        "tag": "#5emeAnnee_Externat",
        "modules": ["Pédiatrie", "Gynécologie-Obstétrique", "ORL", "Ophtalmologie", "Dermatologie", "Uro-Néphrologie"],
        "sample_topics": [
            {
                "module": "Pédiatrie",
                "topic": "Déshydratation Aiguë du Nourrisson & SRO",
                "morning_focus": "Calcul de la perte de poids en % : pli cutané persistant, fontanelle antérieure déprimée, cernes oculaires, diurèse.",
                "lecture_focus": "Plan A, B, C de l'OMS : réhydratation orale prioritaire si perte < 10%, remplissage d'urgence au SSI 20 ml/kg si collapsus.",
                "trap": "Prescrire des anti-diarrhéiques freinateurs de transit chez le nourrisson (contre-indication absolue !).",
                "flash_q": "Quelle quantité de soluté de réhydratation orale (SRO) donner en cas de perte de 5-9% ? Réponse : 75 ml/kg sur 4 heures.",
                "rotation_weeks": 12,
            },
            {
                "module": "Gynécologie-Obstétrique",
                "topic": "Hémorragies du 3ème Trimestre & Placenta Praevia",
                "morning_focus": "Examen au spéculum impératif mais interdiction absolue du toucher vaginal avant confirmation échographique de l'insertion placentaire.",
                "lecture_focus": "Diagnostic différentiel : Placenta Praevia (saignement rouge indolore) vs Hématome Rétro-Placentaire (douleur en coup de poignard, utérus de bois).",
                "trap": "Réaliser un toucher vaginal à l'aveugle devant une métrorragie du 3ème trimestre (risque d'hémorragie cataclysmique).",
                "flash_q": "Quel examen d'imagerie confirme formellement la position du placenta ? Réponse : Échographie pelvienne obstétricale.",
                "rotation_weeks": 12,
            }
        ]
    },
    6: {
        "year": 6,
        "name": "MedsinaTeacher - Urgences (UMC) & Thérapeutique",
        "short_name": "MedsinaTeacher 6ème Année",
        "title": "Praticien Spécialiste aux UMC & Enseignant Thérapeutique",
        "tagline": "Objectif Internat & Résidanat : maîtriser l'urgence vitale et l'ordonnance parfaite.",
        "theme": "rose",
        "tag": "#6emeAnnee_Internat",
        "modules": ["Urgences Médico-Chirurgicales (UMC)", "Thérapeutique d'Urgence", "Médecine Légale", "Médecine du Travail"],
        "sample_topics": [
            {
                "module": "Urgences Médico-Chirurgicales",
                "topic": "Choc Anaphylactique & Voie d'Abord Immédiate",
                "morning_focus": "Reconnaissance réflexe au déchoquage : prurit palmo-plantaire, hypotension, stridor laryngé, bronchospasme.",
                "lecture_focus": "Adrénaline IM 0.5 mg à la face antéro-latérale de la cuisse sans délai, remplissage cristalloïde, O2 fort débit, corticothérapie IV secondaire.",
                "trap": "Administrer l'adrénaline en IV directe sans dilution chez un patient non intubé ou attendre les antihistaminiques (erreur mortelle).",
                "flash_q": "Quelle est la dose d'adrénaline IM chez l'adulte en 1ère intention ? Réponse : 0.5 mg (0.5 ml de solution au 1/1000).",
                "rotation_weeks": 6,
            },
            {
                "module": "Thérapeutique d'Urgence",
                "topic": "Œdème Aigu du Poumon (OAP) Flash Hypertensif",
                "morning_focus": "Patient assis jambes pendantes, cyanose, sueurs, râles crépitants en marée montante bilatérale, TA à 220/120 mmHg.",
                "lecture_focus": "Trinitrine IV au PSE (titration rapide), Diurétique de l'anse (Furosémide IV), VNI au masque si détresse persistante.",
                "trap": "Allonger le patient ou administrer des bêtabloquants en phase aiguë d'OAP congestif (risque d'arrêt cardiaque par décompensation).",
                "flash_q": "Quelle mesure posturale immédiate doit être appliquée avant tout traitement ? Réponse : Assis, jambes pendantes au bord du lit.",
                "rotation_weeks": 6,
            }
        ]
    }
}


# -----------------------------------------------------------------------------
# 1. GÉNÉRATION DES TEXTES DE LA "VIE RÉELLE DE L'ÉTUDIANT"
# -----------------------------------------------------------------------------

# Promotion Spéciale Nouveaux Inscrits (02 au 30 Novembre 2026)
PROMO_START = datetime.datetime(2026, 11, 2)
PROMO_END = datetime.datetime(2026, 11, 30, 23, 59, 59)

def get_promo_footer(is_telegram: bool = False) -> str:
    now = datetime.datetime.now()
    if PROMO_START <= now <= PROMO_END:
        if is_telegram:
            return "\n\n🎁 <b>[OFFRE SPÉCIALE NOVEMBRE 2026]</b> : <i>1 Mois All-Access VIP Offert pour toute nouvelle inscription jusqu'au 30/11 ! Accédez à tous les cours et 6 240+ QCMs dès maintenant.</i>"
        else:
            return "\n\n🎁 [OFFRE SPÉCIALE NOVEMBRE 2026] : 1 Mois All-Access VIP Offert pour toute nouvelle inscription jusqu'au 30/11 ! Accédez à tous les cours et 6 240+ QCMs dès aujourd'hui."
    return ""

def build_student_life_content(year: int, phase: str, topic_data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    teacher = TEACHERS_CATALOG.get(year, TEACHERS_CATALOG[4])
    if not topic_data:
        topic_data = random.choice(teacher["sample_topics"])

    module_name = topic_data["module"]
    topic_name = topic_data["topic"]
    weeks_total = topic_data.get("rotation_weeks", 6)
    current_week = random.randint(1, weeks_total)
    days_to_emd = (weeks_total - current_week) * 7 + random.randint(1, 5)

    if phase == "morning":
        title_fr = f"☀️ [Lit du Malade • Tour de Salle] {teacher['name']}"
        badge = f"STAGE CLIQUE • {year}e ANNÉE • {module_name.upper()}"
        summary_pts = [
            f"Cas du jour : {topic_name}",
            f"Examen au lit : {topic_data['morning_focus']}",
            f"Piège en salle : {topic_data['trap']}",
            f"Fiche réflexe disponible sur Medsina pour votre tour de service !"
        ]
        caption_fb = f"""🩺 {teacher['name']} ({teacher['title']})
📍 EN DIRECT DU SERVICE • LIT DU MALADE ({year}e Année • {module_name})
{teacher['tag']} #MedsinaTeacher #MedecineAlgerie

Bonjour chers externes et futurs confrères ! ☀️
C'est l'heure du tour de salle du matin dans le service de {module_name}.

🎯 CAS DU JOUR AU LIT DU MALADE :
👉 {topic_name}

🔎 GESTES ET SIGNES À RECHERCHER CE MATIN :
• {topic_data['morning_focus']}

⚠️ PIÈGE CLASSIQUE À ÉVITER DEVANT LE PATIENT :
• {topic_data['trap']}

📋 Vous êtes en stage hospitalier ? Ouvrez Medsina en mode « Lit du Malade » pour avoir en 30 secondes vos questions d'interrogatoire, l'examen ciblé et les bilans d'urgence de première intention.

Bon courage à tous dans vos services ce matin ! 🩺🇩🇿
👉 {OFFICIAL_WEB_URL}"""

        caption_tg = f"""☀️ <b>[LIT DU MALADE • TOUR DE SALLE]</b>
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>Promotion :</b> {year}e Année • {module_name}
🏷️ {teacher['tag']} #MedsinaTeacher

Bonjour la promotion ! C'est l'heure de la visite en salle :

🎯 <b>Cas clinique du jour :</b> {topic_name}
🔎 <b>À rechercher ce matin :</b>
{topic_data['morning_focus']}

⚠️ <b>Piège à éviter :</b>
{topic_data['trap']}

📲 <i>Ouvrez le mode « Lit du Malade » dans Medsina pour accéder aux réflexes d'urgence et bilans recommandés.</i>
🔗 {OFFICIAL_WEB_URL}"""

    elif phase == "afternoon":
        title_fr = f"🏛️ [Séance d'Amphi • Cours Magistral] {teacher['name']}"
        badge = f"AMPHI MAGISTRAL • {year}e ANNÉE • PIÈGE EMD"
        summary_pts = [
            f"Cours officiel : {topic_name}",
            f"Physiopathologie & Recommandations : {topic_data['lecture_focus']}",
            f"LE PIÈGE DU PROFESSEUR : {topic_data['trap']}",
            f"Séance interactive avec auto-évaluation disponible sur l'app !"
        ]
        caption_fb = f"""🏛️ {teacher['name']} ({teacher['title']})
📚 SÉANCE D'AMPHI INTERACTIVE • COURS DU JOUR ({year}e Année • {module_name})
{teacher['tag']} #MedsinaTeacher #AmphiMedecine

Chers étudiants de {year}e année,
Après la matinée de stage, place à l'enseignement théorique de l'après-midi.

📖 MODULE : {module_name}
🎯 COURS OFFICIEL : {topic_name}

💡 SYNTHÈSE DIDACTIQUE & RECOMMANDATIONS :
• {topic_data['lecture_focus']}

🚨 LE PIÈGE DU PROFESSEUR AUX EXAMENS EMD :
« {topic_data['trap']} »
(C'est la question piège classique posée chaque année qui fait chuter les notes ! Notez-la bien dans vos carnets !)

✨ Retrouvez la séance interactive complète délivrée par votre tuteur dans Medsina : cas d'accroche, cours structuré, questions flash d'amphi et fiche anti-sèche pour l'examen !

👉 Consultez le cours : {OFFICIAL_WEB_URL}"""

        caption_tg = f"""🏛️ <b>[AMPHI MAGISTRAL • SÉANCE DU JOUR]</b>
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>{year}e Année :</b> {module_name} — <i>{topic_name}</i>
🏷️ {teacher['tag']} #MedsinaTeacher #CoursAmphi

Chers étudiants, voici votre cours d'amphi de l'après-midi :

💡 <b>Recommandations & Points Clés :</b>
{topic_data['lecture_focus']}

🚨 <b>LE PIÈGE DU PROFESSEUR AUX EMDs :</b>
« {topic_data['trap']} »

📲 <i>Faites la séance interactive complète sur Medsina avec les 4 chapitres et l'anti-sèche EMD.</i>
🔗 {OFFICIAL_WEB_URL}"""

    elif phase == "evening":
        title_fr = f"🎯 [Défi EMD du Soir & Décompte] {teacher['name']}"
        badge = f"DÉFI DU SOIR • SEM. {current_week}/{weeks_total} • J-{days_to_emd}"
        summary_pts = [
            f"Décompte rotation : Semaine {current_week}/{weeks_total} ({module_name})",
            f"J-{days_to_emd} avant l'EMD blanc officiel !",
            f"Question flash du soir : {topic_data['flash_q']}",
            f"Testez votre score en temps réel sur Medsina !"
        ]
        caption_fb = f"""🌙 {teacher['name']} ({teacher['title']})
🎯 DÉFI EMD DU SOIR & SUIVI DE ROTATION ({year}e Année • {module_name})
{teacher['tag']} #MedsinaTeacher #DefiEMD

Fin de journée pour la promotion ! C'est l'heure de tester si vous avez bien fixé le cours de cet après-midi :

⏳ ÉTAT DE VOTRE ROTATION DE STAGE :
• Semaine en cours : {current_week}/{weeks_total} en {module_name}
• Compte à rebours : J-{days_to_emd} avant l'évaluation EMD !

🎯 QUESTION FLASH DU SOIR :
❓ {topic_data['flash_q']}

⚠️ Piège réflexe à mémoriser : {topic_data['trap']}

Révisez efficacement chaque soir avec les séries de QCMs classés par cours et annales de faculté sur Medsina.

Bonne soirée et bon travail personnel ! 🩺
👉 {OFFICIAL_WEB_URL}"""

        caption_tg = f"""🌙 <b>[DÉFI FLASH EMD DU SOIR & COMPTE À REBOURS]</b>
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>{year}e Année • {module_name}</b> (Semaine {current_week}/{weeks_total} • J-{days_to_emd})
🏷️ {teacher['tag']} #MedsinaTeacher

C'est l'heure du test de fixation du soir :

🎯 <b>Question Flash :</b>
❓ {topic_data['flash_q']}

⚠️ <b>Rappel Piège :</b> {topic_data['trap']}
⏳ <i>Votre rotation avance : J-{days_to_emd} avant l'EMD blanc !</i>

📲 <i>Testez vos connaissances en illimité sur Medsina :</i>
🔗 {OFFICIAL_WEB_URL}"""

    else:  # emd_alert
        title_fr = f"📝 [Alerte EMD Blanc Chronométré] {teacher['name']}"
        badge = f"SIMULATION EMD /20 • J-3 ÉPREUVE • {module_name.upper()}"
        summary_pts = [
            f"Module : {module_name} ({year}e Année)",
            f"Examen blanc officiel noté sur 20 avec seuil de validation",
            f"Minuterie conforme faculté & Palette de navigation QCS/QCM",
            f"Corrigé détaillé et analyse prédictive de vos points faibles !"
        ]
        caption_fb = f"""🔥 {teacher['name']} ({teacher['title']})
📝 ALERTE EMD BLANC CHRONOMÉTRÉ EN LIGNE ({year}e Année • {module_name})
{teacher['tag']} #MedsinaTeacher #EMDBlanc #Validation20

Alerte examen pour les étudiants de {year}e année !
Votre rotation de stage en {module_name} touche à sa fin : il est temps de tester vos connaissances en conditions réelles d'examen !

🎯 CE QUE VOUS TROUVEREZ DANS LE SIMULATEUR D'EMD MEDSINA :
✅ Épreuve officielle conforme aux annales de faculté (QCS, QCMs et cas cliniques).
⏱️ Minuterie officielle d'examen avec décompte temps réel.
📊 Calcul automatique de votre note sur 20 avec statut (Validé / Non Validé).
💡 Justifications détaillées de chaque proposition et diagnostic de vos erreurs.

Ne partez pas à l'épreuve sans avoir validé votre EMD blanc sur l'application !

Lancez votre examen maintenant :
👉 {OFFICIAL_WEB_URL}"""

        caption_tg = f"""🔥 <b>[ALERTE EMD BLANC CHRONOMÉTRÉ]</b>
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>{year}e Année • Module : {module_name}</b>
🏷️ {teacher['tag']} #MedsinaTeacher #SimulationEMD

L'épreuve d'examen blanc est prête ! Testez votre niveau avant le grand jour :

📝 <b>Caractéristiques de l'épreuve :</b>
• Questions conformes annales de faculté
• Notation officielle sur 20
• Chronomètre d'examen
• Corrigé argumenté ligne par ligne

📲 <i>Passez votre EMD blanc sur l'application Medsina :</i>
🔗 {OFFICIAL_WEB_URL}"""

    return {
        "year": year,
        "phase": phase,
        "teacher": teacher,
        "module": module_name,
        "topic": topic_name,
        "title_fr": title_fr,
        "badge": badge,
        "summary_pts": summary_pts,
        "caption_fb": caption_fb + get_promo_footer(is_telegram=False),
        "caption_tg": caption_tg + get_promo_footer(is_telegram=True),
        "days_to_emd": days_to_emd,
        "current_week": current_week,
        "weeks_total": weeks_total
    }


# -----------------------------------------------------------------------------
# 2. DIFFUSION VERS LES RÉSEAUX (FACEBOOK, TELEGRAM & SUPABASE)
# -----------------------------------------------------------------------------

def fetch_facebook_pages() -> Dict[str, Dict[str, str]]:
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value",
        headers=headers,
        timeout=15,
    )
    r.raise_for_status()
    settings = {row["setting_key"]: row["setting_value"] for row in r.json()}

    return {
        "residanat_blida_2027": {
            "name": "Résidanat Blida 2027",
            "page_id": "1405719695953624",
            "token": settings.get("facebook_page_access_token", "").strip(),
        },
        "medsina": {
            "name": "Medsina (Page Officielle)",
            "page_id": settings.get("facebook_medsina_page_id", "1449308354921826").strip(),
            "token": settings.get("facebook_medsina_page_access_token", "").strip(),
        },
        "medevsync": {
            "name": "MedevSync",
            "page_id": settings.get("facebook_medevsync_page_id", "1329939320211198").strip(),
            "token": settings.get("facebook_medevsync_page_access_token", "").strip(),
        },
    }


def publish_photo_to_facebook(page_id: str, token: str, image_path: str, caption: str) -> Dict[str, Any]:
    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
    with open(image_path, "rb") as f:
        resp = requests.post(
            url,
            data={"caption": caption, "access_token": token},
            files={"source": f},
            timeout=45,
        )
    return resp.json()


def run_student_life_cycle(year: int, phase: str, dry_run: bool = False) -> Dict[str, Any]:
    print(f"\n=======================================================")
    print(f"🩺 MEDSINA STUDENT LIFE AGENT: Année {year} | Phase: {phase.upper()}")
    print(f"=======================================================")

    content = build_student_life_content(year, phase)
    teacher = content["teacher"]

    print(f"👨‍🏫 Tuteur : {teacher['name']}")
    print(f"📖 Module : {content['module']} | Sujet : {content['topic']}")

    # 1. Génération de l'infographie moderne
    image_path = None
    if build_modern_light_banner:
        output_dir = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0752fc32-0933-427d-8738-1205d9f05bcf")
        output_dir.mkdir(parents=True, exist_ok=True)
        img_file = output_dir / f"student_life_y{year}_{phase}.png"

        banner_data = {
            "theme": teacher["theme"],
            "badge": content["badge"],
            "title": teacher["name"],
            "subtitle": f"{content['module']} • {content['topic']}",
            "points": content["summary_pts"],
        }
        try:
            image_path = build_modern_light_banner(
                data=banner_data,
                output_path=str(img_file),
                app_version=f"{year}e ANNÉE",
            )
            print(f"🎨 Infographie générée avec succès : {image_path}")
        except Exception as e:
            print(f"⚠️ Notice génération infographie : {e}")

    if dry_run:
        print("\n🧪 [MODE SIMULATION / DRY-RUN ACTIF]")
        print("--- APERÇU FACEBOOK ---")
        print(content["caption_fb"])
        print("\n--- APERÇU TELEGRAM ---")
        print(content["caption_tg"])
        return {"success": True, "dry_run": True, "content": content}

    # 2. Diffusion Telegram
    tg_results = {}
    if send_telegram_broadcast:
        print("\n✈️ Diffusion sur Telegram (Canal officiel & Topics communautaires)...")
        # Topic 18 pour EMD, Topic 8 pour Externat/Cursus
        target_topic = 18 if phase == "emd_alert" else 8
        try:
            tg_res = send_telegram_broadcast(
                message_text=content["caption_tg"],
                image_path=image_path,
                topic_id=target_topic,
                category="externat",
                dry_run=False,
                auto_pin=False,
            )
            tg_results = tg_res
            print(f"✅ Telegram diffusé ! ID: {tg_res.get('message_id')}")
        except Exception as e:
            print(f"❌ Erreur Telegram : {e}")

    # 3. Diffusion Facebook sur les 3 pages
    fb_results = {}
    try:
        pages = fetch_facebook_pages()
        print("\n📘 Publication sur les 3 pages Facebook officielles...")
        for p_key, p_info in pages.items():
            if not p_info.get("token"):
                continue
            try:
                if image_path and os.path.exists(image_path):
                    res = publish_photo_to_facebook(p_info["page_id"], p_info["token"], image_path, content["caption_fb"])
                else:
                    url = f"https://graph.facebook.com/v21.0/{p_info['page_id']}/feed"
                    res = requests.post(url, data={"message": content["caption_fb"], "access_token": p_info["token"]}, timeout=20).json()

                post_id = res.get("id") or res.get("post_id")
                fb_results[p_key] = {"success": True, "id": post_id}
                print(f"   🎉 Succès sur {p_info['name']} ! ID: {post_id}")
            except Exception as e:
                print(f"   ❌ Erreur sur {p_info['name']} : {e}")
                fb_results[p_key] = {"success": False, "error": str(e)}
    except Exception as e:
        print(f"⚠️ Notice récupération Facebook : {e}")

    # 4. Notification In-App Supabase
    if send_in_app_notification:
        try:
            send_in_app_notification(
                title=content["title_fr"][:60],
                message=content["summary_pts"][0],
                notif_type="pedagogical_agent",
                payload={"year": year, "phase": phase, "module": content["module"]}
            )
            print("🔔 Notification In-App transmise aux étudiants !")
        except Exception as e:
            print(f"⚠️ Notice In-App : {e}")

    return {
        "success": True,
        "year": year,
        "phase": phase,
        "telegram": tg_results,
        "facebook": fb_results,
    }


def resolve_auto_phase() -> str:
    hour = datetime.datetime.now().hour
    if hour < 12:
        return "morning"
    elif hour < 17:
        return "afternoon"
    else:
        return "evening"


def main():
    parser = argparse.ArgumentParser(description="Medsina Student Life Pedagogical Agent")
    parser.add_argument("--year", type=str, default="auto", help="Année d'étude (1 à 6, ou 'all'/'auto')")
    parser.add_argument("--phase", type=str, default="auto", choices=["morning", "afternoon", "evening", "emd_alert", "auto"], help="Phase de la journée")
    parser.add_argument("--dry-run", action="store_true", help="Mode test sans publication réelle")
    args = parser.parse_args()

    phase = resolve_auto_phase() if args.phase == "auto" else args.phase

    if args.year == "all":
        years = [1, 2, 3, 4, 5, 6]
    elif args.year == "auto":
        # Alterne selon le jour de la semaine
        day = datetime.datetime.now().weekday()
        years = [(day % 6) + 1]
    else:
        try:
            years = [int(args.year)]
        except ValueError:
            years = [4]

    for y in years:
        run_student_life_cycle(y, phase, dry_run=args.dry_run)


if __name__ == "__main__":
    main()

