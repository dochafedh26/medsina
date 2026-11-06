#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - AGENT AUTONOME "VIE RÉELLE DE L'ÉTUDIANT EN MÉDECINE" (1ère à 6ème Année)
=============================================================================
Annonce les défis et sessions pédagogiques programmés dans l'application Medsina
à partir des cours et QCMs réels de la banque officielle (`assets/data/qcms/Blida_*.json`) :
1. Matin (08h00) : Annonce du Défi Clinique « Lit du Malade & Tour de Salle » disponible dans l'App
2. Après-Midi (14h00) : Annonce de la « Session d'Amphi & Cours Interactif » programmée dans l'App
3. Soir (20h00) : Annonce officielle du « Défi de 20H Externat (Banque QCM Réelle) » lancé dans l'App
4. Fin de Rotation (J-3) : Annonce de l'ouverture de « l'EMD Blanc Chronométré (/20) » dans l'App

Règle stricte :
- Toutes les sessions et le Défi de 20H Externat sont alimentés par la vraie banque de QCMs.
- Les publications (Facebook & Telegram) annoncent uniquement qu'un défi est lancé / programmé
  et qu'il est disponible dès maintenant dans l'application Medsina (aucun spoiler de question).
- Les visuels utilisent le design Infographie Bento Grid Pinterest 2026 (1080x1080).
=============================================================================
"""

import os
import sys
import json
import random
import argparse
import datetime
import tempfile
import requests
from pathlib import Path
from typing import Dict, Any, List, Optional

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
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

# Correspondance officielle entre chaque année d'étude et les fichiers de la banque QCM réelle
YEAR_QCM_BANKS: Dict[int, List[Dict[str, Any]]] = {
    1: [
        {"file": "Blida_ANATOMIE_1_ERE.json", "module": "Anatomie 1ère Année", "weeks": 12},
        {"file": "Blida_BIOCHIMIE_1_ERE.json", "module": "Biochimie 1ère Année", "weeks": 12},
        {"file": "Blida_CYTOLOGIE_1_ERE.json", "module": "Cytologie", "weeks": 6},
        {"file": "Blida_EMBRYOLOGIE.json", "module": "Embryologie", "weeks": 6},
        {"file": "Blida_PHYSIOLOGIE_1_ERE.json", "module": "Physiologie 1ère Année", "weeks": 6},
        {"file": "Blida_BIOPHYSIQUE_1_ERE.json", "module": "Biophysique 1ère Année", "weeks": 6},
        {"file": "Blida_GENETIQUE.json", "module": "Génétique", "weeks": 6},
    ],
    2: [
        {"file": "Blida_ANATOMIE_2_EME.json", "module": "Anatomie 2ème Année", "weeks": 6},
        {"file": "Blida_PHYSIOLOGIE_2_EME.json", "module": "Physiologie 2ème Année", "weeks": 6},
        {"file": "Blida_BIOCHIMIE_2_EME.json", "module": "Biochimie 2ème Année", "weeks": 6},
        {"file": "Blida_HISTOLOGIE.json", "module": "Histologie", "weeks": 6},
        {"file": "Blida_IMMUNOLOGIE.json", "module": "Immunologie", "weeks": 6},
        {"file": "Blida_BIOPHYSIQUE_2_EME.json", "module": "Biophysique 2ème Année", "weeks": 6},
    ],
    3: [
        {"file": "Blida_ANATOMIE_PATHOLOGIQUE.json", "module": "Anatomie Pathologique", "weeks": 6},
        {"file": "Blida_PHARMACOLOGIE.json", "module": "Pharmacologie", "weeks": 6},
        {"file": "Blida_MICROBIOLOGIE.json", "module": "Microbiologie", "weeks": 6},
        {"file": "Blida_PARASITOLOGIE.json", "module": "Parasitologie", "weeks": 6},
        {"file": "Blida_RADIOLOGIE.json", "module": "Radiologie & Imagerie", "weeks": 6},
    ],
    4: [
        {"file": "Blida_CARDIOLOGIE.json", "module": "Cardiologie", "weeks": 6},
        {"file": "Blida_PNEUMOLOGIE.json", "module": "Pneumologie", "weeks": 6},
        {"file": "Blida_GASTROLOGIE.json", "module": "Hépato-Gastro-Entérologie", "weeks": 6},
        {"file": "Blida_NEUROLOGIE.json", "module": "Neurologie", "weeks": 6},
        {"file": "Blida_INFECTIEUX.json", "module": "Maladies Infectieuses", "weeks": 6},
        {"file": "Blida_HEMATOLOGIE.json", "module": "Hématologie", "weeks": 6},
    ],
    5: [
        {"file": "Blida_PEDIATRIE.json", "module": "Pédiatrie", "weeks": 12},
        {"file": "Blida_GYNECOLOGIE_OBSTETRIQUE.json", "module": "Gynécologie-Obstétrique", "weeks": 12},
        {"file": "Blida_ENDOCRINOLOGIE.json", "module": "Endocrinologie & Diabétologie", "weeks": 6},
        {"file": "Blida_UROLOGIE.json", "module": "Urologie", "weeks": 3},
        {"file": "Blida_NEPHROLOGIE.json", "module": "Néphrologie", "weeks": 3},
        {"file": "Blida_OTORHINOLARYNGOLOGIE.json", "module": "ORL", "weeks": 3},
        {"file": "Blida_OPHTALMOLOGIE.json", "module": "Ophtalmologie", "weeks": 3},
        {"file": "Blida_DERMATOLOGIE.json", "module": "Dermatologie", "weeks": 3},
        {"file": "Blida_PSYCHIATRIE.json", "module": "Psychiatrie", "weeks": 3},
        {"file": "Blida_ORTHOPEDIE_ET_TRAUMATOLOGIE.json", "module": "Orthopédie-Traumatologie", "weeks": 6},
        {"file": "Blida_RHUMATOLOGIE.json", "module": "Rhumatologie", "weeks": 6},
    ],
    6: [
        {"file": "Blida_URGENCES_UMC.json", "module": "Urgences Médico-Chirurgicales (UMC)", "weeks": 6},
        {"file": "Blida_THERAPEUTIQUE.json", "module": "Thérapeutique", "weeks": 3},
        {"file": "Blida_MEDECINE_LEGALE.json", "module": "Médecine Légale", "weeks": 3},
        {"file": "Blida_MEDECINE_DE_TRAVAIL.json", "module": "Médecine du Travail", "weeks": 3},
        {"file": "Blida_EPIDEMIOLOGIE.json", "module": "Épidémiologie & Santé Publique", "weeks": 3},
        {"file": "Blida_ECONOMIE_DE_SANTE.json", "module": "Économie de la Santé", "weeks": 3},
    ],
}

TEACHERS_CATALOG: Dict[int, Dict[str, Any]] = {
    1: {
        "year": 1,
        "name": "MedsinaTeacher • 1ère Année Médecine",
        "title": "Professeur en Sciences Fondamentales & Anatomie",
        "theme": "teal",
        "tag": "#1ereAnnee_Medecine",
    },
    2: {
        "year": 2,
        "name": "MedsinaTeacher • 2ème Année Médecine",
        "title": "Maître-Assistant en Physiologie & Unités Intégrées",
        "theme": "cyan",
        "tag": "#2emeAnnee_Medecine",
    },
    3: {
        "year": 3,
        "name": "MedsinaTeacher • 3ème Année Externat",
        "title": "Chef de Clinique en Sémiologie & Pré-Clinique",
        "theme": "indigo",
        "tag": "#3emeAnnee_Medecine",
    },
    4: {
        "year": 4,
        "name": "MedsinaTeacher • 4ème Année Externat",
        "title": "Professeur Hospitalo-Universitaire en Clinique I",
        "theme": "emerald",
        "tag": "#4emeAnnee_Externat",
    },
    5: {
        "year": 5,
        "name": "MedsinaTeacher • 5ème Année Externat",
        "title": "Professeur en Spécialités Médico-Chirurgicales",
        "theme": "amber",
        "tag": "#5emeAnnee_Externat",
    },
    6: {
        "year": 6,
        "name": "MedsinaTeacher • 6ème Année & Internat",
        "title": "Praticien Spécialiste aux UMC & Thérapeutique",
        "theme": "rose",
        "tag": "#6emeAnnee_Internat",
    },
}


# -----------------------------------------------------------------------------
# 1. SÉLECTION D'UN COURS ET D'UNE SÉRIE DE QCMs RÉELS DEPUIS LA BANQUE OFFICIELLE
# -----------------------------------------------------------------------------

def pick_real_qcm_challenge_for_year(year: int) -> Dict[str, Any]:
    """
    Lit directement les fichiers JSON officiels (`assets/data/qcms/Blida_*.json`)
    pour l'année d'étude ciblée et sélectionne de façon déterministe (par date du jour)
    le module et le cours réel du Défi de 20H Externat.
    """
    qcms_dir = REPO_ROOT / "assets" / "data" / "qcms"
    if not qcms_dir.exists():
        qcms_dir = Path("assets/data/qcms")

    banks = YEAR_QCM_BANKS.get(year, YEAR_QCM_BANKS[4])
    today = datetime.date.today()
    seed = today.year * 10000 + today.month * 100 + today.day + (year * 37)
    rng = random.Random(seed)

    available_modules = []
    for entry in banks:
        fp = qcms_dir / entry["file"]
        if fp.exists():
            available_modules.append((entry, fp))

    if not available_modules:
        return {
            "module": "Cardiologie",
            "topic": "Syndrome Coronarien Aigu",
            "rotation_weeks": 6,
            "course_qcm_count": 15,
            "module_qcm_count": 320,
            "exam_source": "Annales EMD Faculté de Médecine",
            "exam_year": 2024,
        }

    chosen_entry, chosen_fp = available_modules[seed % len(available_modules)]
    try:
        raw_list = json.loads(chosen_fp.read_text(encoding="utf-8"))
    except Exception:
        raw_list = []

    by_course: Dict[str, List[Dict[str, Any]]] = {}
    for q in raw_list:
        if not isinstance(q, dict):
            continue
        c_name = str(q.get("courseName") or "").strip()
        if not c_name or c_name.lower() in ("divers", "general", "général", "non classé", "sans titre"):
            continue
        by_course.setdefault(c_name, []).append(q)

    rich_courses = [(c, qs) for c, qs in by_course.items() if len(qs) >= 5]
    if not rich_courses and by_course:
        rich_courses = list(by_course.items())

    if rich_courses:
        rich_courses.sort(key=lambda x: x[0])
        course_name, course_qs = rich_courses[seed % len(rich_courses)]
        sample_q = rng.choice(course_qs)
        source_str = str(sample_q.get("source") or "Annales EMD Faculté").strip()
        exam_year = sample_q.get("year") or 2024
        challenge_count = min(15, max(5, len(course_qs)))
    else:
        course_name = chosen_entry["module"]
        course_qs = raw_list
        source_str = "Annales EMD Faculté"
        exam_year = 2024
        challenge_count = 15

    return {
        "module": chosen_entry["module"],
        "topic": course_name,
        "rotation_weeks": chosen_entry.get("weeks", 6),
        "course_qcm_count": len(course_qs),
        "challenge_qcm_count": challenge_count,
        "module_qcm_count": len(raw_list),
        "exam_source": source_str,
        "exam_year": exam_year,
    }


# -----------------------------------------------------------------------------
# 2. CONSTRUCTION DES ANNONCES (ZÉRO SPOILER • ANNONCE PURE DE DISPONIBILITÉ)
# -----------------------------------------------------------------------------

def build_student_life_content(year: int, phase: str, topic_data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    teacher = TEACHERS_CATALOG.get(year, TEACHERS_CATALOG[4])
    if not topic_data:
        topic_data = pick_real_qcm_challenge_for_year(year)

    module_name = topic_data["module"]
    topic_name = topic_data["topic"]
    weeks_total = topic_data.get("rotation_weeks", 6)
    challenge_count = topic_data.get("challenge_qcm_count", 15)
    module_qcm_count = topic_data.get("module_qcm_count", 250)
    exam_source = topic_data.get("exam_source", "Annales Officielles Faculté")

    today = datetime.date.today()
    current_week = ((today.day - 1) % weeks_total) + 1
    days_to_emd = max(2, (weeks_total - current_week) * 7 + 3)

    if phase == "evening":
        title_fr = f"🎯 Défi de 20H Externat Lancé • {module_name}"
        status_pill = f"DÉFI 20H LANCÉ • {year}E ANNÉE"
        badge = f"DÉFI DE 20H EXTERNAT • BANQUE QCM RÉELLE • {year}E ANNÉE"
        hero_title = f"Défi de 20H Externat : {topic_name}"
        hero_sub = f"Module {module_name} ({year}e Année) • Le défi du soir est lancé sur l'application Medsina."
        metric_tag = "BANQUE QCM OFFICIELLE"
        metric_value = f"{challenge_count} QCMs"
        metric_label = "100% Questions Réelles d'Annales"
        metric_desc = f"Source : {exam_source} ({module_qcm_count} QCMs officiels disponibles dans le module {module_name})."
        summary_pts = [
            f"Promotion & Module : {year}e Année Médecine — Stage de {module_name}",
            f"Cours Ciblé du Défi 20H : {topic_name} ({challenge_count} QCMs réels d'annales)",
            "Statut du Défi : Lancé à 20h00 et disponible immédiatement dans l'application Medsina",
        ]
        callout_title = "Le Défi de 20H Externat est Ouvert sur l'Application !"
        callout_sub = "Rendez-vous dans l'onglet Externat / Stage de l'application Medsina pour participer au défi chronométré."

        caption_fb = f"""🎯 [DÉFI DE 20H EXTERNAT LANCÉ SUR MEDSINA] 🔔
👨‍🏫 {teacher['name']}
📌 Promotion : {year}e Année Médecine • Module : {module_name}
{teacher['tag']} #Medsina #Defi20HExternat #MedecineAlgerie

Le Défi de 20H Externat de ce soir est officiellement lancé et programmé dans l'application Medsina ! 🚀

📋 AU PROGRAMME DU DÉFI DE CE SOIR :
• 🏥 Module : {module_name} ({year}e Année)
• 📖 Cours ciblé : « {topic_name} »
• 🎯 Contenu : Série de {challenge_count} QCMs 100% réels issus de la banque officielle des QCMs ({exam_source} — {module_qcm_count} QCMs disponibles dans le module).
• ⏱️ Format : Épreuve chronométrée avec note sur 20 et corrigé détaillé.

🔒 Aucune question n'est dévoilée sur la page : le défi se déroule exclusivement en conditions réelles dans l'application !

📲 Ouvrez dès maintenant l'application Medsina pour relever le Défi de 20H Externat 👇"""

        caption_tg = f"""🎯 <b>[DÉFI DE 20H EXTERNAT — LANCÉ DANS L'APP]</b> 🔔
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>Promotion :</b> {year}e Année Médecine • <b>{module_name}</b>
🏷️ {teacher['tag']} #Defi20HExternat #Medsina

Le <b>Défi de 20H Externat</b> est officiellement lancé et disponible dans l'application Medsina !

📋 <b>Fiche officielle du défi :</b>
• 📖 <b>Cours ciblé :</b> <i>{topic_name}</i>
• ✅ <b>Banque QCM :</b> {challenge_count} QCMs réels issus des annales officielles ({exam_source})
• ⏱️ <b>Format :</b> Chronométré dans l'App avec score /20 et corrigé complet

📲 <b>Participez au défi maintenant dans l'application Medsina :</b>
🔗 {OFFICIAL_WEB_URL}"""

    elif phase == "morning":
        title_fr = f"☀️ Session Lit du Malade Programmée • {module_name}"
        status_pill = f"SESSION 08H DISPONIBLE • {year}E ANNEE"
        badge = f"STAGE HOSPITALIER • LIT DU MALADE • {year}E ANNEE"
        hero_title = f"Session Lit du Malade : {topic_name}"
        hero_sub = f"Module {module_name} ({year}e Annee) • Votre guide clinique de tour de salle est disponible dans l'App."
        metric_tag = "STAGE & CLINIQUE"
        metric_value = f"SEM. {current_week}/{weeks_total}"
        metric_label = f"Module : {module_name}"
        metric_desc = f"Checklist au lit du malade, constantes, drapeaux rouges et {module_qcm_count} QCMs reels disponibles dans l'App."
        summary_pts = [
            f"Stage en Cours : {module_name} ({year}e Annee Medecine — Semaine {current_week}/{weeks_total})",
            f"Cas Clinique Programme : {topic_name} (Interrogatoire, Examen physique & Bilan d'urgence)",
            "Disponibilite : Session disponible des maintenant en mode Lit du Malade sur l'application Medsina",
        ]
        callout_title = "Session Clinique Disponible dans l'Application Medsina"
        callout_sub = "Ouvrez le mode Lit du Malade dans l'application pendant votre stage pour suivre la conduite a tenir."

        caption_fb = f"""☀️ [SESSION LIT DU MALADE PROGRAMMÉE SUR MEDSINA] 🩺
👨‍🏫 {teacher['name']}
📌 Promotion : {year}e Année Médecine • Stage : {module_name}
{teacher['tag']} #Medsina #StageHospitalier #MedecineAlgerie

Une nouvelle session clinique « Lit du Malade » est programmée et disponible ce matin dans l'application Medsina ! 🏥

📋 PROGRAMME DE LA MATINÉE DE STAGE :
• 🏥 Service / Module : {module_name} (Semaine {current_week}/{weeks_total})
• 🎯 Sujet clinique : « {topic_name} »
• 🩺 Disponible dans l'App : Interrogatoire ciblé, gestes d'examen physique, drapeaux rouges, bilans d'urgence et QCMs réels associés.

📲 Ouvrez l'application Medsina en mode « Lit du Malade » pour accéder directement à votre session de stage 👇"""

        caption_tg = f"""☀️ <b>[SESSION LIT DU MALADE — DISPONIBLE DANS L'APP]</b> 🩺
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>Promotion :</b> {year}e Année • <b>{module_name}</b>
🏷️ {teacher['tag']} #Medsina #StageHospitalier

Votre session clinique du matin est programmée et disponible dans l'application Medsina :

• 🎯 <b>Sujet du jour :</b> <i>{topic_name}</i>
• 🏥 <b>Rotation :</b> Semaine {current_week}/{weeks_total} en {module_name}
• 📲 <b>Contenu App :</b> Réflexes au lit du malade, bilans de 1ère intention et QCMs réels du cours.

🔗 <b>Ouvrir dans l'application Medsina :</b> {OFFICIAL_WEB_URL}"""

    elif phase == "afternoon":
        title_fr = f"🏛️ Session d'Amphi & Défi QCM • {module_name}"
        status_pill = f"SESSION AMPHI LANCEE • {year}E ANNEE"
        badge = f"AMPHI INTERACTIF & QCM REELS • {year}E ANNEE"
        hero_title = f"Session Cours & QCM : {topic_name}"
        hero_sub = f"Module {module_name} ({year}e Annee) • La seance d'amphi et sa serie de QCMs reels sont disponibles dans l'App."
        metric_tag = "COURS & BANQUE QCM"
        metric_value = f"{module_qcm_count} QCMs"
        metric_label = f"Banque Officielle {module_name}"
        metric_desc = f"Synthese magistrale, pieges d'EMD et {challenge_count} QCMs reels cibles sur {topic_name} dans l'App."
        summary_pts = [
            f"Module & Promotion : {module_name} ({year}e Annee Medecine)",
            f"Cours du Jour : {topic_name} (Synthese, Pieges du Professeur & Auto-evaluation)",
            f"Entrainement QCM : Serie de {challenge_count} QCMs reels disponible dans l'application Medsina",
        ]
        callout_title = "Seance d'Amphi & Serie QCM Disponibles dans l'App !"
        callout_sub = "Accedez au cours interactif et lancez la serie de QCMs reels correspondante sur Medsina."

        caption_fb = f"""🏛️ [SESSION D'AMPHI & SÉRIE QCM DISPONIBLES SUR MEDSINA] 📚
👨‍🏫 {teacher['name']}
📌 Promotion : {year}e Année Médecine • Module : {module_name}
{teacher['tag']} #Medsina #CoursMedecine #ExternatAlgerie

La session pédagogique de l'après-midi ainsi que son entraînement QCM sont programmés et disponibles dans l'application Medsina ! 🎯

📋 AU PROGRAMME DANS L'APPLICATION :
• 📖 Module : {module_name} ({year}e Année)
• 🎯 Cours ciblé : « {topic_name} »
• ✅ Inclus dans l'App : Fiche de synthèse structurée, pièges d'examen EMD et série de {challenge_count} QCMs réels issus de la banque officielle ({exam_source}).

📲 Ouvrez l'application Medsina dès maintenant pour suivre la session et tester vos connaissances 👇"""

        caption_tg = f"""🏛️ <b>[SESSION D'AMPHI & SÉRIE QCM — DISPONIBLES DANS L'APP]</b> 📚
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>Promotion :</b> {year}e Année • <b>{module_name}</b>
🏷️ {teacher['tag']} #Medsina #Externat

La session de cours de l'après-midi et son défi QCM sont disponibles dans l'application Medsina :

• 📖 <b>Cours :</b> <i>{topic_name}</i>
• ✅ <b>Entraînement :</b> Série de {challenge_count} QCMs réels ({exam_source})
• 💡 <b>Inclus :</b> Synthèse, pièges du Professeur aux EMDs et corrigé détaillé.

🔗 <b>Accéder à la session sur Medsina :</b> {OFFICIAL_WEB_URL}"""

    else:  # emd_alert
        title_fr = f"📝 Simulation EMD Blanc Lancée • {module_name}"
        status_pill = f"EMD BLANC OUVERT • {year}E ANNEE"
        badge = f"SIMULATION EMD OFFICIELLE /20 • {year}E ANNEE"
        hero_title = f"EMD Blanc Officiel : {module_name}"
        hero_sub = f"Promotion {year}e Annee • L'examen blanc chronometre issu de la banque officielle des QCMs est ouvert dans l'App."
        metric_tag = "EXAMEN BLANC /20"
        metric_value = "20 QCMs"
        metric_label = f"Banque Reelle ({module_qcm_count} QCMs)"
        metric_desc = f"Epreuve chronometree notee sur 20 avec questions reelles d'EMD ({exam_source}) et diagnostic complet."
        summary_pts = [
            f"Module Evalue : {module_name} ({year}e Annee Medecine — J-{days_to_emd} avant l'EMD)",
            f"Banque Officielle : 20 QCMs reels tires des {module_qcm_count} questions officielles du module",
            "Disponibilite : Simulateur EMD Blanc ouvert et accessible maintenant dans l'application Medsina",
        ]
        callout_title = "Simulateur EMD Blanc Ouvert dans l'Application Medsina !"
        callout_sub = "Passez l'epreuve en conditions reelles d'examen et obtenez immediatement votre note sur 20."

        caption_fb = f"""🔥 [SIMULATION EMD BLANC LANCÉE SUR MEDSINA] 📝
👨‍🏫 {teacher['name']}
📌 Promotion : {year}e Année Médecine • Module : {module_name}
{teacher['tag']} #Medsina #EMDBlanc #MedecineAlgerie

Un nouvel examen blanc chronométré (EMD Blanc /20) est programmé et ouvert dès maintenant dans l'application Medsina ! ⏱️

📋 DÉTAILS DE L'ÉPREUVE DANS L'APPLICATION :
• 🏥 Module évalué : {module_name} ({year}e Année)
• ✅ Questions : 20 QCMs 100% réels sélectionnés depuis la banque officielle ({exam_source} — {module_qcm_count} QCMs dans le module)
• 📊 Évaluation : Chronomètre officiel, notation automatique sur 20 et corrigé détaillé question par question.

📲 Lancez votre simulation d'EMD Blanc dès maintenant dans l'application Medsina 👇"""

        caption_tg = f"""🔥 <b>[SIMULATION EMD BLANC — OUVERTE DANS L'APP]</b> 📝
👨‍🏫 <b>{teacher['name']}</b>
📌 <b>Promotion :</b> {year}e Année • <b>Module : {module_name}</b>
🏷️ {teacher['tag']} #Medsina #SimulationEMD

Une nouvelle session d'<b>EMD Blanc chronométré (/20)</b> est lancée et disponible dans l'application Medsina :

• ✅ <b>Banque officielle :</b> 20 QCMs réels issus des annales ({exam_source})
• ⏱️ <b>Conditions réelles :</b> Chronomètre d'examen et calcul immédiat de votre note sur 20
• 💡 <b>Correction :</b> Corrigé détaillé et analyse de vos points faibles par cours.

🔗 <b>Lancer l'EMD Blanc sur Medsina :</b> {OFFICIAL_WEB_URL}"""

    first_comment_fb = (
        f"📲 Accédez directement au défi et aux {module_qcm_count}+ QCMs réels du module {module_name} dans l'application Medsina :\n"
        f"🌐 Web App : {OFFICIAL_WEB_URL}\n"
        f"📱 Application Android (.apk) : {OFFICIAL_APK_URL}\n"
        f"✈️ Canal Telegram Officiel : {OFFICIAL_TELEGRAM_URL}"
    )

    return {
        "year": year,
        "phase": phase,
        "teacher": teacher,
        "module": module_name,
        "topic": topic_name,
        "title_fr": title_fr,
        "status_pill": status_pill,
        "badge": badge,
        "hero_title": hero_title,
        "hero_sub": hero_sub,
        "metric_tag": metric_tag,
        "metric_value": metric_value,
        "metric_label": metric_label,
        "metric_desc": metric_desc,
        "summary_pts": summary_pts,
        "callout_title": callout_title,
        "callout_sub": callout_sub,
        "caption_fb": caption_fb,
        "caption_tg": caption_tg,
        "first_comment_fb": first_comment_fb,
        "days_to_emd": days_to_emd,
        "current_week": current_week,
        "weeks_total": weeks_total,
    }


# -----------------------------------------------------------------------------
# 3. DIFFUSION VERS LES RÉSEAUX (FACEBOOK, TELEGRAM & SUPABASE IN-APP)
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


def publish_photo_to_facebook(page_id: str, token: str, image_path: str, caption: str, first_comment: Optional[str] = None) -> Dict[str, Any]:
    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"
    with open(image_path, "rb") as f:
        resp = requests.post(
            url,
            data={"caption": caption, "access_token": token},
            files={"source": f},
            timeout=45,
        )
    res_data = resp.json()

    if first_comment and res_data.get("id"):
        target_post_id = res_data.get("post_id") or res_data.get("id")
        try:
            c_url = f"https://graph.facebook.com/v21.0/{target_post_id}/comments"
            requests.post(c_url, data={"message": first_comment, "access_token": token}, timeout=15)
            print("   💬 1er commentaire avec liens officiels auto-publié sur Facebook !")
        except Exception as e_c:
            print(f"   ⚠️ Notice 1er commentaire : {e_c}")

    return res_data


def run_student_life_cycle(year: int, phase: str, dry_run: bool = False) -> Dict[str, Any]:
    print(f"\n=======================================================")
    print(f"🩺 MEDSINA STUDENT LIFE AGENT: Année {year} | Phase: {phase.upper()}")
    print(f"=======================================================")

    content = build_student_life_content(year, phase)
    teacher = content["teacher"]

    print(f"👨‍🏫 Tuteur : {teacher['name']}")
    print(f"📖 Module Réel (Banque QCM) : {content['module']} | Cours : {content['topic']}")

    # 1. Génération de l'infographie Bento Grid Pinterest 2026
    image_path = None
    if build_modern_light_banner:
        output_dir = Path(tempfile.gettempdir()) / "medsina_banners"
        output_dir.mkdir(parents=True, exist_ok=True)
        img_file = output_dir / f"student_life_y{year}_{phase}.png"

        banner_data = {
            "theme": teacher["theme"],
            "status_pill": content["status_pill"],
            "badge": content["badge"],
            "title": content["hero_title"],
            "subtitle": content["hero_sub"],
            "metric_tag": content["metric_tag"],
            "metric_value": content["metric_value"],
            "metric_label": content["metric_label"],
            "metric_desc": content["metric_desc"],
            "points": content["summary_pts"],
            "callout_title": content["callout_title"],
            "callout_sub": content["callout_sub"],
        }
        try:
            image_path = build_modern_light_banner(
                data=banner_data,
                output_path=str(img_file),
                app_version=f"{year}e ANNEE",
            )
            print(f"🎨 Infographie Pinterest 2026 Bento générée : {image_path}")
        except Exception as e:
            print(f"⚠️ Notice génération infographie : {e}")

    if dry_run:
        print("\n🧪 [MODE SIMULATION / DRY-RUN ACTIF]")
        print("--- APERÇU FACEBOOK ---")
        print(content["caption_fb"])
        print("\n--- 💬 1ER COMMENTAIRE FACEBOOK ---")
        print(content.get("first_comment_fb", ""))
        print("\n--- APERÇU TELEGRAM ---")
        print(content["caption_tg"])
        return {"success": True, "dry_run": True, "image_path": image_path, "content": content}

    # 2. Diffusion Telegram (Annonce pure avec l'infographie Bento, aucun Quiz Poll spoiler)
    tg_results = {}
    if send_telegram_broadcast:
        print("\n✈️ Diffusion de l'annonce sur Telegram (Canal officiel & Topics communautaires)...")
        target_topic = 18 if phase in ("emd_alert", "evening") else 8
        try:
            tg_res = send_telegram_broadcast(
                message_text=content["caption_tg"],
                image_path=image_path,
                topic_id=target_topic,
                category="externat",
                dry_run=False,
                auto_pin=(phase == "evening"),
            )
            tg_results = tg_res
            print(f"✅ Annonce Telegram diffusée ! ID: {tg_res.get('message_id')}")
        except Exception as e:
            print(f"❌ Erreur Telegram : {e}")

    # 3. Diffusion Facebook sur les 3 pages officielles
    fb_results = {}
    try:
        pages = fetch_facebook_pages()
        print("\n📘 Publication de l'annonce sur les 3 pages Facebook officielles...")
        for p_key, p_info in pages.items():
            if not p_info.get("token"):
                continue
            try:
                if image_path and os.path.exists(image_path):
                    res = publish_photo_to_facebook(
                        p_info["page_id"],
                        p_info["token"],
                        image_path,
                        content["caption_fb"],
                        first_comment=content.get("first_comment_fb"),
                    )
                else:
                    url = f"https://graph.facebook.com/v21.0/{p_info['page_id']}/feed"
                    res = requests.post(
                        url,
                        data={"message": content["caption_fb"], "access_token": p_info["token"]},
                        timeout=20,
                    ).json()

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
                title=content["title_fr"][:65],
                message=f"{content['module']} ({year}e Année) : {content['topic']} disponible dans l'App.",
                notif_type="announcement",
                target_id="global",
            )
            print("🔔 Notification In-App transmise aux étudiants !")
        except Exception as e:
            print(f"⚠️ Notice In-App : {e}")

    return {
        "success": True,
        "year": year,
        "phase": phase,
        "image_path": image_path,
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
    parser.add_argument(
        "--phase",
        type=str,
        default="auto",
        choices=["morning", "afternoon", "evening", "emd_alert", "auto"],
        help="Phase de la journée",
    )
    parser.add_argument("--dry-run", action="store_true", help="Mode test sans publication réelle")
    args = parser.parse_args()

    phase = resolve_auto_phase() if args.phase == "auto" else args.phase

    if args.year == "all":
        years = [1, 2, 3, 4, 5, 6]
    elif args.year == "auto":
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
