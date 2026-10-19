#!/usr/bin/env python3
"""
Medsina & MedevSync AI Facebook Automated Visual Post Generator (v2.0)
- Deux axes de publication automatisés :
    A) Commercial & Promotionnel : met en avant les fonctionnalités phares (Analyseur d'ordonnance,
       Mode hors-ligne, Annales Résidanat, Codex Urgences, Assistant IA) avec fort appel au téléchargement.
    B) Médical & Pédagogique : extraits concrets de l'application (Fiches réflexes de garde, CATs,
       Pièges de concours, Posologies d'urgence).
- Infographies visuelles modernes haute définition 1080x1080 générées avec Pillow.
- Publication en photo native sur la page Facebook MedevSync via l'API Meta Graph.
- Toujours enrichi des 3 liens officiels :
    * Version Web : https://medsina.medevsync.com
    * Téléchargement APK Android : https://medsina.medevsync.com/download/medsina.apk
    * Téléchargement Installateur PC : https://medsina.medevsync.com/download/medsina-setup.exe
"""

import os
import re
import sys
import json
import time
import random
import argparse
import datetime
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Optional, Dict, Any, List

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

GEMINI_MODELS = [
    "gemini-3.8-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-pro-preview",
    "gemini-4-argon",
]

# Liens permanents officiels Octenium & Web MedevSync
OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OFFICIAL_WIN_URL = "https://medsina.medevsync.com/download/medsina-setup.exe"

def get_current_app_version() -> str:
    """Detects the latest official Medsina release version automatically.
    1. Checks Supabase app_releases table (latest active release).
    2. Checks live Octenium web version.json.
    3. Checks local pubspec.yaml.
    """
    # 1. Supabase app_releases
    try:
        url = f"{SUPABASE_URL}/rest/v1/app_releases?select=version_name&is_active=eq.true&order=build_number.desc&limit=1"
        req = urllib.request.Request(
            url,
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data and data[0].get("version_name"):
                return str(data[0]["version_name"]).strip().lstrip("v")
    except Exception:
        pass

    # 2. Live Octenium version.json
    try:
        with urllib.request.urlopen(f"{OFFICIAL_WEB_URL}/version.json", timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("version"):
                return str(data["version"]).strip().lstrip("v")
    except Exception:
        pass

    # 3. Local pubspec.yaml
    try:
        pubspec = Path(__file__).resolve().parents[2] / "pubspec.yaml"
        if pubspec.exists():
            for line in pubspec.read_text(encoding="utf-8").splitlines():
                if line.startswith("version:"):
                    return line.split(":")[1].strip().split("+")[0].lstrip("v")
    except Exception:
        pass

    return "1.0.8"

APP_VERSION = get_current_app_version()

OFFICIAL_FOOTER = f"""
━━━━━━━━━━━━━━━━━━━━
📲 TESTEZ ET TÉLÉCHARGEZ MEDSINA (v{APP_VERSION}) :
🌐 Version Web Directe : {OFFICIAL_WEB_URL}
📱 Télécharger sur Android (.apk) : {OFFICIAL_APK_URL}
💻 Télécharger sur PC Windows (.exe) : {OFFICIAL_WIN_URL}

🇩🇿 Conçu par MedevSync pour les médecins, résidents, internes et candidats au concours en Algérie.
#MedevSync #Medsina #MedecineAlgerie #Residanat2027 #PratiqueClinique #SanteNumerique #UrgencesMedicales #Internat"""


def load_gemini_api_key() -> Optional[str]:
    key = os.environ.get("GEMINI_API_KEY")
    if key and key.strip():
        return key.strip()

    try:
        url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?setting_key=eq.gemini_api_key&select=setting_value"
        req = urllib.request.Request(
            url,
            headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            rows = json.loads(resp.read().decode("utf-8"))
            if rows and rows[0].get("setting_value"):
                val = rows[0]["setting_value"].strip()
                if val:
                    return val
    except Exception:
        pass

    secrets_file = Path(__file__).resolve().parents[2] / "lib" / "core" / "config" / "app_secrets.dart"
    if secrets_file.exists():
        content = secrets_file.read_text(encoding="utf-8")
        m = re.search(r"geminiApiKey\s*=\s*['\"]([^'\"]+)['\"]", content)
        if m and m.group(1).strip():
            return m.group(1).strip()

    return None


def get_facebook_credentials() -> Dict[str, str]:
    page_id = os.environ.get("FB_PAGE_ID")
    page_token = os.environ.get("FB_PAGE_ACCESS_TOKEN")

    if not page_id or not page_token:
        try:
            url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
            req = urllib.request.Request(
                url,
                headers={"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                rows = json.loads(resp.read().decode("utf-8"))
                for row in rows:
                    if row.get("setting_key") == "facebook_page_id" and not page_id:
                        page_id = row.get("setting_value")
                    elif row.get("setting_key") == "facebook_page_access_token" and not page_token:
                        page_token = row.get("setting_value")
        except Exception as e:
            print(f"Warning: Could not fetch Facebook credentials from Supabase: {e}", file=sys.stderr)

    if not page_id or not page_token:
        raise ValueError("Missing Facebook credentials (facebook_page_id or facebook_page_access_token).")

    return {"page_id": page_id.strip(), "page_token": page_token.strip()}


def strip_emojis_for_image(text: str) -> str:
    """Remplace les symboles mathématiques/médicaux et retire les émojis pour éviter les glyphes manquants."""
    text = (
        text.replace("≥", ">=")
        .replace("≤", "<=")
        .replace("±", "+/-")
        .replace("→", "->")
        .replace("•", "-")
        .replace("’", "'")
        .replace("‘", "'")
        .replace("«", '"')
        .replace("»", '"')
    )
    clean = re.sub(r'[\U00010000-\U0010ffff]', '', text)
    clean = re.sub(r'[^\x00-\x7F\u00C0-\u024F]', ' ', clean)
    return re.sub(r'\s+', ' ', clean).strip()


# -------------------------------------------------------------
# POSTS COMMERCIAUX / PROMOTIONNELS (AXE A)
# -------------------------------------------------------------

COMMERCIAL_SHOWCASES: List[Dict[str, Any]] = [
    {
        "id": "promo_vidal_ordonnance",
        "badge": "SÉCURITÉ • VIDAL ALGÉRIE",
        "title": "Sécurisez Vos Prescriptions en Garde",
        "subtitle": "Vidal Algérien & Analyseur d'Ordonnance Intelligent",
        "theme": "amber",
        "mockup_type": "desktop",
        "screenshot_desktop": "assets/screenshots/desktop/prescription_audit_pc.png",
        "points": [
            "Détection instantanée des interactions médicamenteuses sévères.",
            "Contrôle automatique des contre-indications de terrain (rein, diabète).",
            "Nomenclature pharmaceutique complète (Saidal, IPA, PCH).",
            "Calculateur de clairance et adaptation posologique intégrée."
        ],
        "lead": """🚨 MÉDECINS & INTERNES DE GARDE : NE LAISSEZ PLUS PASSER UNE INTERACTION MÉDICAMENTEUSE ! 💊

Combien de fois avez-vous hésité au lit du malade sur l'association de deux molécules en urgence ?
Une interaction médicamenteuse méconnue peut virer au drame (hémorragie sous Sintrom, aplasie sous Colchicine, récidive d'infarctus sous Plavix).

Avec l'application Medsina, vous disposez d'un Analyseur d'Ordonnance de nouvelle génération spécialement calibré sur le marché pharmaceutique algérien :
✨ Analysez une ordonnance complète en 3 secondes.
✨ Détectez les interactions de niveau 1 (Contre-indication absolue) et niveau 2 (Association déconseillée).
✨ Vérifiez les contre-indications selon le terrain du patient (grossesse, HTA, ulcère, hépatite)."""
    },
    {
        "id": "promo_offline_hospital",
        "badge": "TECHNOLOGIE • 100% HORS-LIGNE",
        "title": "Toute la Médecine dans Votre Poche Sans Internet",
        "subtitle": "Mode Hors-Ligne Total • Pratique Hospitalière",
        "theme": "emerald",
        "mockup_type": "duo",
        "screenshot_desktop": "assets/screenshots/desktop/clinical_copilot_pc.png",
        "screenshot_mobile": "assets/screenshots/mobile/clinical_copilot_mobile.png",
        "points": [
            "Accès immédiat à toutes vos fiches cliniques au fond des urgences.",
            "Protocoles de réanimation et CATs disponibles en zone blanche.",
            "Aucun temps de chargement au lit du malade.",
            "Base de données locale optimisée et ultra-rapide."
        ],
        "lead": """📶 PAS DE RÉSEAU DANS LES SOUS-SOLS DU C.H.U ? AUCUN PROBLÈME AVEC MEDSINA ! 🏥

Les urgences médicales et les salles de garde sont souvent situées dans des zones où la 4G ne passe pas. Or, c'est précisément là que vous avez un besoin vital de consulter un protocole de dilution ou une CAT d'urgence.

Medsina a été pensée dès le premier jour pour fonctionner à 100% HORS-LIGNE :
✨ L'intégralité des CATs, mémentos et valeurs biologiques reste accessible partout.
✨ Consultez vos fiches à toute vitesse, sans dépendre d'une connexion internet.
✨ Vos révisions de QCM et fiches de synthèse vous accompagnent dans les transports et à l'hôpital."""
    },
    {
        "id": "promo_residanat_2027",
        "badge": "CONCOURS • RÉSIDANAT 2027",
        "title": "Préparez le Concours Comme un Major",
        "subtitle": "Fiches Synthèses & QCMs Corrigés de Concours",
        "theme": "purple",
        "mockup_type": "desktop",
        "screenshot_desktop": "assets/screenshots/desktop/revision_qcm_pc.png",
        "points": [
            "Fiches officielles couvrant les 47 modules du résidanat.",
            "Pièges typiques d'examen et points clés à haut rendement.",
            "Banque de QCMs des facultés algériennes (Blida, Alger, Oran...).",
            "Moteur de révision intelligent pour cibler vos lacunes."
        ],
        "lead": """🎯 OBJECTIF RÉSIDANAT 2027 : RÉVISEZ AVEC LES MEILLEURES FICHES ET ÉVITEZ LES PIÈGES ! 📚

Le concours de résidanat ne récompense pas ceux qui lisent le plus de pages, mais ceux qui maîtrisent les points discriminants et déjouent les questions pièges.

Dans Medsina, chaque cours est distillé pour aller droit au but :
✨ Les points clés indispensables à retenir pour répondre aux QCMs.
✨ La section exclusive « Pièges Fréquents du Concours » rédigée selon les anales officielles.
✨ Des milliers de questions d'entraînement corrigées et commentées.
✨ Disponible sur mobile pour réviser partout, ou sur grand écran avec notre version Web !"""
    },
    {
        "id": "promo_codex_urgences",
        "badge": "PRATIQUE • CODEX D'URGENCE",
        "title": "DCI & Spécialités Disponibles en Algérie",
        "subtitle": "Guide Posologique & Dilutions Hospitalières",
        "theme": "blue",
        "mockup_type": "phone",
        "screenshot_mobile": "assets/screenshots/mobile/clinical_copilot_mobile.png",
        "points": [
            "Correspondance DCI <-> Noms commerciaux algériens (Saidal, IPA).",
            "Posologies exactes d'urgence adulte et pédiatrique en mg/kg.",
            "Protocoles de titration et débits de perfusion IVSE.",
            "Recommandations récentes des sociétés savantes validées."
        ],
        "lead": """💉 PROTOCOLES D'URGENCE : LES BONNES DOSES, AVEC LES MÉDICAMENTS DU SERVICE ! ⚡

Adrénaline, Loxen, Dobutamine, Lasilix, Cordarone... En situation critique, vous n'avez pas le temps de chercher les règles de dilution sur Google.

Le Codex des Urgences de Medsina vous donne instantanément :
✨ Le protocole de dilution pas-à-pas (combien d'ampoules dans combien de soluté G5% ou SSI).
✨ La vitesse de démarrage au PSE et les paliers d'adaptation selon la pression artérielle.
✨ Les noms de spécialités commerciales réellement disponibles dans les pharmacies hospitalières algériennes."""
    },
    {
        "id": "promo_ai_medsinapilot",
        "badge": "IA MÉDICALE • MEDSINAPILOT",
        "title": "Votre Assistant IA Médical Dédié 24h/24",
        "subtitle": "MedsinaPilot • Intelligence Artificielle Clinique",
        "theme": "blue",
        "mockup_type": "duo",
        "screenshot_desktop": "assets/screenshots/desktop/clinical_copilot_pc.png",
        "screenshot_mobile": "assets/screenshots/mobile/ai_copilot_mobile.png",
        "points": [
            "Posez n'importe quelle question clinique en langage naturel.",
            "Aide au diagnostic différentiel et orientation thérapeutique.",
            "Synthèse de consensus médicaux 2024-2026 en quelques secondes.",
            "Conçu spécifiquement pour la médecine et le résidanat en Algérie."
        ],
        "lead": """🤖 UN COPILOTE MÉDICAL INTELLIGENT TOUJOURS À VOS CÔTÉS EN GARDE ET EN RÉVISION ! 💡

Bloqué sur un cas clinique atypique ? Besoin d'une synthèse rapide entre deux démarches étiologiques ?
MedsinaPilot est l'assistant IA médical propulsé au cœur de l'application Medsina :
✨ Formulé pour respecter la rigueur et le vocabulaire médical hospitalier.
✨ Vous aide à structurer vos réflexions cliniques et à vérifier les consensus.
✨ Un gain de temps inestimable pour les étudiants et praticiens connectés."""
    }
]


def build_commercial_post(showcase: Dict[str, Any]) -> Dict[str, Any]:
    caption = f"""{showcase['lead']}

🎯 Retrouvez dès aujourd'hui cette fonctionnalité et bien plus encore sur votre plateforme médicale officielle !
{OFFICIAL_FOOTER}"""

    return {
        "caption": caption,
        "badge": showcase["badge"],
        "title": showcase["title"],
        "subtitle": showcase["subtitle"],
        "points": showcase["points"],
        "theme": showcase["theme"],
        "mockup_type": showcase.get("mockup_type"),
        "screenshot_desktop": showcase.get("screenshot_desktop"),
        "screenshot_mobile": showcase.get("screenshot_mobile"),
    }


# -------------------------------------------------------------
# POSTS MÉDICAUX / EXTRAITS CLINIQUES (AXE B)
# -------------------------------------------------------------

def build_from_memento(memento: Dict[str, Any]) -> Dict[str, Any]:
    """Construit une publication Facebook à partir d'un mémento réflexe de garde."""
    title = memento.get("title", "Mémento de Garde Hospitalière")
    category = memento.get("category", "Garde & Urgence")
    points = memento.get("points", [])[:4]

    theme_map = {
        "Organisation & Sécurité": "blue",
        "Urgences Métaboliques": "amber",
        "Cardiologie & Vasculaire": "blue",
        "Neurologie & Psychiatrie": "purple",
        "Pneumologie & Réanimation": "emerald",
        "Bonne Pratique Médicale": "blue",
        "Gynécologie-Obstétrique": "blue",
    }
    theme = theme_map.get(category, "blue")

    caption = f"""📋 [EXTRAIT CLINIQUE MEDSINA] : {title}
Spécialité : {category} 🏥

Chers confrères, internes et praticiens de garde, voici les réflexes indispensables extraits directement de la bibliothèque Medsina :

"""
    for i, p in enumerate(points, 1):
        caption += f"{i}️⃣ {p}\n"

    caption += f"""
💡 Référence clinique : {memento.get('scientific_references', 'Recommandations & Consensus Pratique Médicale')}
{OFFICIAL_FOOTER}"""

    return {
        "caption": caption,
        "badge": f"MÉMENTO • {category.upper()}",
        "title": title,
        "subtitle": f"{category} • Extrait Pratique Medsina",
        "points": points,
        "theme": theme,
        "mockup_type": "phone",
        "screenshot_mobile": "assets/screenshots/mobile/clinical_copilot_mobile.png",
    }


def build_from_course_summary(summary: Dict[str, Any]) -> Dict[str, Any]:
    """Construit une publication Facebook à partir d'une fiche synthèse de cours du résidanat."""
    course_name = summary.get("course_name", "Fiche de Révision")
    module_name = summary.get("module_name", "Module Médical")
    traps = summary.get("exam_traps", [])
    takeaways = summary.get("key_takeaways", [])

    points = (traps if traps else takeaways)[:4]

    caption = f"""📖 [FICHE CONCOURS MEDSINA] : {course_name}
Module : {module_name} 🎯

Voici un extrait direct des points clés et pièges de concours disponibles dans la fiche officielle Medsina pour réviser efficacement :

"""
    for i, p in enumerate(points, 1):
        caption += f"⚠️ {p}\n"

    caption += f"""
🎯 Synthèse conforme aux consensus officiels et anales du concours de résidanat en Algérie (Blida, Alger, Constantine, Oran).
{OFFICIAL_FOOTER}"""

    return {
        "caption": caption,
        "badge": f"CONCOURS 2027 • {module_name.upper()}",
        "title": f"Pièges & Clés : {course_name}",
        "subtitle": f"Module {module_name} • Concours Résidanat",
        "points": points,
        "theme": "purple",
        "mockup_type": "desktop",
        "screenshot_desktop": "assets/screenshots/desktop/revision_qcm_pc.png",
    }


def generate_post_content_gemini(topic: str, gemini_key: str, post_type: str = "commercial") -> Dict[str, Any]:
    angle = (
        "Mets l'accent sur les fonctionnalités innovantes de l'application Medsina et donne envie aux médecins de la télécharger."
        if post_type == "commercial"
        else "Partage un extrait médical clinique concret et ultra-pédagogique (protocole d'urgence, perle ou piège de concours) issu de l'application."
    )

    system_prompt = f"""Tu es le Directeur Médical & Marketing de MedevSync, la startup algérienne éditrice de l'application mobile et web "Medsina" (Plateforme médicale globale pour étudiants, internes et candidats au concours de Résidanat 2027 en Algérie).
Ton rôle est de créer des publications Facebook modernes, percutantes et attractives.
{angle}

RÈGLES IMPÉRATIVES DE RÉDACTION :
1. "points" : Doit contenir exactement 4 points.
2. Chaque point DOIT être une phrase complète, autonome, bien formulée et terminée (8 à 12 mots maximum, avec ponctuation finale). Ne JAMAIS couper une phrase à mi-chemin.
3. Le texte doit être en français irréprochable et adapté au contexte médical algérien (CHU, gardes, concours résidanat).
4. Plateformes : Medsina est disponible sur Android (APK), PC Windows et Web (NE JAMAIS mentionner iOS ou iPhone).

Tu dois répondre UNIQUEMENT par un objet JSON valide avec la structure suivante :
{{
  "caption": "Texte complet du post Facebook avec émojis, mise en page aérée, accroche percutante et points médicaux clés (SANS les liens finaux car ils seront ajoutés automatiquement)",
  "badge": "TITRE DU BADGE (ex: PROTOCOLE D'URGENCE, VIDAL ALGÉRIE, PIÈGE DE CONCOURS, APPLICATION MEDSINA)",
  "title": "Titre choc et court pour l'image (max 50 caractères)",
  "subtitle": "Spécialité & Thème (ex: Cardiologie & Urgences Médicales • Medsina)",
  "points": [
    "Phrase 1 complète et percutante (8 à 12 mots).",
    "Phrase 2 complète et percutante (8 à 12 mots).",
    "Phrase 3 complète et percutante (8 à 12 mots).",
    "Phrase 4 complète et percutante (8 à 12 mots)."
  ],
  "theme": "blue | emerald | amber | purple"
}}"""

    prompt = f"""Rédige une publication Facebook médicale et attractive pour l'application Medsina sur le thème : "{topic}".
Le contenu doit cibler les médecins généralistes, résidents, internes et candidats au concours de résidanat en Algérie."""

    for model in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={gemini_key}"
        payload = {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.3,
                "maxOutputTokens": 4096,
                "responseMimeType": "application/json",
            }
        }
        try:
            resp = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=35)
            if resp.status_code == 200:
                data = resp.json()
                parts = data.get("candidates", [])[0].get("content", {}).get("parts", [])
                if parts and "text" in parts[0]:
                    clean = re.sub(r"^```json\s*", "", parts[0]["text"].strip())
                    clean = re.sub(r"\s*```$", "", clean)
                    parsed = json.loads(clean)
                    caption_raw = parsed.get("caption", "").strip()
                    caption_raw = re.sub(r'\s*(et\s+)?(sur\s+)?iOS\b', '', caption_raw, flags=re.IGNORECASE)
                    parsed["caption"] = caption_raw + "\n" + OFFICIAL_FOOTER

                    # Attribution intelligente des captures d'écran et maquettes selon le contexte
                    t_lower = (parsed.get("title", "") + " " + parsed.get("subtitle", "") + " " + parsed.get("badge", "") + " " + topic).lower()
                    if any(k in t_lower for k in ["vidal", "ordonnance", "médicament", "posologie", "interaction", "prescription"]):
                        parsed["mockup_type"] = "desktop"
                        parsed["screenshot_desktop"] = "assets/screenshots/desktop/prescription_audit_pc.png"
                    elif any(k in t_lower for k in ["concours", "résidanat", "qcm", "anales", "révision", "module"]):
                        parsed["mockup_type"] = "desktop"
                        parsed["screenshot_desktop"] = "assets/screenshots/desktop/revision_qcm_pc.png"
                    elif any(k in t_lower for k in ["urgence", "garde", "cat", "protocole", "réanimation", "ecg"]):
                        parsed["mockup_type"] = "phone"
                        parsed["screenshot_mobile"] = "assets/screenshots/mobile/clinical_copilot_mobile.png"
                    else:
                        parsed["mockup_type"] = "duo"
                        parsed["screenshot_desktop"] = "assets/screenshots/desktop/clinical_copilot_pc.png"
                        parsed["screenshot_mobile"] = "assets/screenshots/mobile/ai_copilot_mobile.png"

                    return parsed
        except Exception as e:
            print(f"Gemini {model} error: {e}")
            continue

    raise RuntimeError("Failed to generate response across all Gemini models.")


def get_post_data(topic: Optional[str] = None, post_type: str = "auto") -> Dict[str, Any]:
    """Sélectionne ou génère le contenu du post selon le type (commercial vs médical)."""
    # Résolution automatique selon l'heure si post_type == "auto"
    # Matin (5h - 13h UTC) : Visée Médicale (Extrait clinique / Perle)
    # Après-midi / Soir (13h - 23h UTC) : Visée Commerciale (Promo de l'application)
    resolved_type = post_type
    if post_type == "auto":
        cur_hour = datetime.datetime.now(datetime.timezone.utc).hour
        resolved_type = "medical" if 5 <= cur_hour < 13 else "commercial"
        print(f"⏰ Mode Auto (Heure UTC : {cur_hour}h) -> Sélection du type : {resolved_type.upper()}")

    gemini_key = load_gemini_api_key()
    if topic and gemini_key:
        try:
            print(f"🧠 Utilisation de Gemini AI ({resolved_type.upper()}) pour : '{topic}'")
            return generate_post_content_gemini(topic, gemini_key, post_type=resolved_type)
        except Exception as e:
            print(f"Notice Gemini indisponible ({e}), bascule sur la base locale Medsina...")

    # Axe A : Commercial / Promotionnel
    if resolved_type == "commercial":
        showcase = random.choice(COMMERCIAL_SHOWCASES)
        print(f"📢 Post Commercial sélectionné : {showcase['title']}")
        return build_commercial_post(showcase)

    # Axe B : Médical / Extraits Cliniques
    assets_dir = Path(__file__).resolve().parents[2] / "assets" / "data"
    mementos_file = assets_dir / "on_call_mementos.json"
    summaries_file = assets_dir / "course_summaries.json"

    # Alternance aléatoire entre mémentos de garde et fiches de révision de concours
    pick_memento = random.choice([True, False])

    if pick_memento and mementos_file.exists():
        try:
            mementos = json.loads(mementos_file.read_text(encoding="utf-8"))
            if topic:
                filtered = [m for m in mementos if topic.lower() in m.get("title", "").lower() or topic.lower() in m.get("category", "").lower()]
                if filtered:
                    return build_from_memento(random.choice(filtered))
            if mementos:
                m = random.choice(mementos)
                print(f"🩺 Extrait Mémento sélectionné : {m.get('title')}")
                return build_from_memento(m)
        except Exception as e:
            print(f"Warning reading mementos: {e}")

    if summaries_file.exists():
        try:
            summaries = json.loads(summaries_file.read_text(encoding="utf-8"))
            if summaries:
                s = random.choice(summaries)
                print(f"📖 Extrait Cours sélectionné : {s.get('course_name')}")
                return build_from_course_summary(s)
        except Exception as e:
            print(f"Warning reading summaries: {e}")

    # Fallback par défaut vers un showcase commercial
    return build_commercial_post(COMMERCIAL_SHOWCASES[0])


# -------------------------------------------------------------
# MOTEUR DE RENDU GRAPHIQUE HAUTE DÉFINITION 1080x1080 (PILLOW)
# -------------------------------------------------------------

def resolve_asset_path(path_str: Optional[str]) -> Optional[Path]:
    """Résout le chemin d'un asset en testant localement et par rapport à la racine du projet."""
    if not path_str:
        return None
    candidates = [
        Path(path_str),
        Path(__file__).resolve().parents[2] / path_str,
        Path(__file__).resolve().parent / path_str,
        Path(__file__).resolve().parents[1] / path_str,
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def get_font(size: int, bold: bool = False):
    font_paths = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for p in font_paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def create_rounded_mask(size, radius):
    """Creates an antialiased supersampled rounded corner mask."""
    w, h = size
    scale = 4
    mask = Image.new("L", (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (w * scale - 1, h * scale - 1)], radius=radius * scale, fill=255)
    return mask.resize((w, h), Image.Resampling.LANCZOS)


def create_shadow(image_size, radius=24, offset=(0, 16), shadow_color=(0, 0, 0, 140)):
    """Creates a soft realistic shadow behind a device mockup."""
    w, h = image_size
    pad = radius * 2
    shadow = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(
        [(pad + offset[0], pad + offset[1]), (pad + w + offset[0], pad + h + offset[1])],
        radius=radius,
        fill=shadow_color
    )
    return shadow.filter(ImageFilter.GaussianBlur(radius)), pad


def render_phone_mockup(screen_img: Image.Image, target_width: int = 380) -> Image.Image:
    """Renders a sleek smartphone mockup with titanium chassis, status bar, and drop shadow."""
    aspect_ratio = 19.5 / 9.0
    bezel = 10
    screen_w = target_width - bezel * 2
    screen_h = int(screen_w * aspect_ratio)
    phone_w = target_width
    phone_h = screen_h + bezel * 2
    corner_radius = 36

    # 1. Scale with cover (fill entire phone screen)
    scale = max(screen_w / screen_img.width, screen_h / screen_img.height)
    new_w = int(screen_img.width * scale)
    new_h = int(screen_img.height * scale)
    scaled = screen_img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)

    crop_x = (new_w - screen_w) // 2
    crop_y = 0  # keep top header visible
    screen_canvas = scaled.crop((crop_x, crop_y, crop_x + screen_w, crop_y + screen_h))

    # 2. Add realistic Mobile Status Bar (Time, Wifi, Battery) with top scrim
    scrim = Image.new("RGBA", (screen_w, 40), (0, 0, 0, 0))
    scrim_draw = ImageDraw.Draw(scrim)
    for y in range(40):
        a = int(120 * (1.0 - y / 40.0))
        scrim_draw.line([(0, y), (screen_w, y)], fill=(0, 0, 0, a))
    screen_canvas.alpha_composite(scrim, (0, 0))

    font_status = get_font(13, bold=True)
    status_draw = ImageDraw.Draw(screen_canvas)
    status_draw.text((22, 11), "09:41", font=font_status, fill=(255, 255, 255, 240))

    # Battery icon at top right
    bx = screen_w - 44
    status_draw.rounded_rectangle([(bx, 13), (bx + 24, 24)], radius=3, outline=(255, 255, 255, 220), width=1)
    status_draw.rounded_rectangle([(bx + 2, 15), (bx + 18, 22)], radius=2, fill=(16, 185, 129, 255))
    status_draw.rectangle([(bx + 24, 16), (bx + 26, 21)], fill=(255, 255, 255, 220))

    # 3. Add bottom Home Indicator bar with scrim
    bottom_scrim = Image.new("RGBA", (screen_w, 28), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bottom_scrim)
    for y in range(28):
        a = int(100 * (y / 28.0))
        b_draw.line([(0, y), (screen_w, y)], fill=(0, 0, 0, a))
    screen_canvas.alpha_composite(bottom_scrim, (0, screen_h - 28))

    bar_w = 110
    bar_h = 4
    bar_x = (screen_w - bar_w) // 2
    bar_y = screen_h - 12
    status_draw.rounded_rectangle([(bar_x, bar_y), (bar_x + bar_w, bar_y + bar_h)], radius=2, fill=(255, 255, 255, 200))

    # Mask screen to rounded corners
    screen_mask = create_rounded_mask((screen_w, screen_h), radius=corner_radius - 8)
    screen_canvas.putalpha(screen_mask)

    # 4. Build Phone Frame
    frame = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)

    frame_draw.rounded_rectangle([(0, 0), (phone_w - 1, phone_h - 1)], radius=corner_radius, fill=(15, 23, 42, 255), outline=(71, 85, 105, 255), width=2)
    frame_draw.rounded_rectangle([(bezel - 2, bezel - 2), (phone_w - bezel + 1, phone_h - bezel + 1)], radius=corner_radius - 6, outline=(30, 41, 59, 255), width=1)

    frame.paste(screen_canvas, (bezel, bezel), screen_canvas)

    # Dynamic Island Pill at top
    pill_w = 76
    pill_h = 16
    pill_x = (phone_w - pill_w) // 2
    pill_y = bezel + 6
    pill_draw = ImageDraw.Draw(frame)
    pill_draw.rounded_rectangle([(pill_x, pill_y), (pill_x + pill_w, pill_y + pill_h)], radius=pill_h // 2, fill=(0, 0, 0, 255))
    pill_draw.ellipse([(pill_x + 12, pill_y + 3), (pill_x + 22, pill_y + 13)], fill=(15, 25, 45, 255))

    # 5. Drop shadow
    shadow, pad = create_shadow((phone_w, phone_h), radius=28, offset=(0, 18), shadow_color=(0, 0, 0, 160))
    canvas = Image.new("RGBA", (phone_w + pad * 2, phone_h + pad * 2), (0, 0, 0, 0))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(frame, (pad, pad), frame)

    return canvas


def render_desktop_mockup(screen_img: Image.Image, target_width: int = 510) -> Image.Image:
    """Renders a sleek browser window mockup with traffic lights, URL bar, and drop shadow."""
    aspect_ratio = 16.0 / 10.0
    header_h = 36
    window_w = target_width
    screen_w = window_w
    screen_h = int(screen_w / aspect_ratio)
    window_h = screen_h + header_h
    corner_radius = 16

    screen_aspect = screen_img.width / screen_img.height
    if screen_aspect > aspect_ratio:
        new_h = screen_h
        new_w = int(new_h * screen_aspect)
        resized_screen = screen_img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)
        left = (new_w - screen_w) // 2
        cropped_screen = resized_screen.crop((left, 0, left + screen_w, screen_h))
    else:
        new_w = screen_w
        new_h = int(new_w / screen_aspect)
        resized_screen = screen_img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)
        top = (new_h - screen_h) // 2
        cropped_screen = resized_screen.crop((0, top, screen_w, top + screen_h))

    mask = Image.new("L", (window_w, window_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (window_w - 1, window_h - 1)], radius=corner_radius, fill=255)

    window = Image.new("RGBA", (window_w, window_h), (15, 23, 42, 255))
    w_draw = ImageDraw.Draw(window)

    w_draw.rounded_rectangle([(0, 0), (window_w - 1, window_h - 1)], radius=corner_radius, fill=(24, 32, 50, 255), outline=(71, 85, 105, 180), width=1)
    w_draw.rounded_rectangle([(0, 0), (window_w - 1, header_h + 10)], radius=corner_radius, fill=(30, 41, 59, 255))
    w_draw.rectangle([(0, header_h - 2), (window_w - 1, header_h)], fill=(51, 65, 85, 200))

    # Traffic light buttons
    w_draw.ellipse([(14, 12), (24, 22)], fill=(239, 68, 68, 255))
    w_draw.ellipse([(32, 12), (42, 22)], fill=(245, 158, 11, 255))
    w_draw.ellipse([(50, 12), (60, 22)], fill=(16, 185, 129, 255))

    # URL bar
    url_w = 260
    url_h = 22
    url_x = (window_w - url_w) // 2
    url_y = 7
    w_draw.rounded_rectangle([(url_x, url_y), (url_x + url_w, url_y + url_h)], radius=6, fill=(15, 23, 42, 220), outline=(51, 65, 85, 200), width=1)
    font_url = get_font(11, bold=False)
    w_draw.text((url_x + 14, url_y + 3), "medsina.medevsync.com", font=font_url, fill=(148, 163, 184, 255))

    window.paste(cropped_screen, (0, header_h))
    window.putalpha(mask)

    shadow, pad = create_shadow((window_w, window_h), radius=28, offset=(0, 18), shadow_color=(0, 0, 0, 170))
    canvas = Image.new("RGBA", (window_w + pad * 2, window_h + pad * 2), (0, 0, 0, 0))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(window, (pad, pad), window)

    return canvas


def render_duo_mockup(desktop_img: Image.Image, mobile_img: Image.Image, canvas_w: int = 540, canvas_h: int = 560) -> Image.Image:
    """Renders both Desktop and Mobile in an aesthetic cross-platform arrangement."""
    duo = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    desktop_mock = render_desktop_mockup(desktop_img, target_width=440)
    duo.paste(desktop_mock, (0, 25), desktop_mock)

    phone_mock = render_phone_mockup(mobile_img, target_width=220)
    duo.paste(phone_mock, (canvas_w - phone_mock.width + 10, canvas_h - phone_mock.height + 25), phone_mock)
    return duo


THEME_PALETTES: Dict[str, Dict[str, Any]] = {
    "blue": {
        "bg_top": (10, 28, 55),
        "bg_bottom": (12, 18, 32),
        "accent": (14, 165, 233),
        "accent_glow": (56, 189, 248),
        "badge_bg": (12, 74, 110),
        "card_bg": (20, 32, 55, 235),
        "card_border": (56, 189, 248, 90),
    },
    "emerald": {
        "bg_top": (6, 42, 32),
        "bg_bottom": (10, 24, 20),
        "accent": (16, 185, 129),
        "accent_glow": (52, 211, 153),
        "badge_bg": (6, 78, 59),
        "card_bg": (16, 38, 30, 235),
        "card_border": (52, 211, 153, 90),
    },
    "purple": {
        "bg_top": (38, 16, 58),
        "bg_bottom": (16, 12, 30),
        "accent": (168, 85, 247),
        "accent_glow": (192, 132, 252),
        "badge_bg": (88, 28, 135),
        "card_bg": (35, 20, 50, 235),
        "card_border": (192, 132, 252, 90),
    },
    "ruby": {
        "bg_top": (50, 14, 24),
        "bg_bottom": (22, 10, 16),
        "accent": (244, 63, 94),
        "accent_glow": (251, 113, 133),
        "badge_bg": (136, 19, 55),
        "card_bg": (42, 16, 24, 235),
        "card_border": (251, 113, 133, 90),
    },
    "amber": {
        "bg_top": (48, 28, 8),
        "bg_bottom": (22, 15, 10),
        "accent": (245, 158, 11),
        "accent_glow": (251, 191, 36),
        "badge_bg": (120, 53, 15),
        "card_bg": (38, 26, 18, 235),
        "card_border": (251, 191, 36, 90),
    },
    "cyan": {
        "bg_top": (6, 38, 52),
        "bg_bottom": (10, 22, 32),
        "accent": (6, 182, 212),
        "accent_glow": (34, 211, 238),
        "badge_bg": (22, 78, 99),
        "card_bg": (16, 36, 48, 235),
        "card_border": (34, 211, 238, 90),
    },
    "indigo": {
        "bg_top": (20, 24, 64),
        "bg_bottom": (12, 14, 34),
        "accent": (99, 102, 241),
        "accent_glow": (129, 140, 248),
        "badge_bg": (49, 46, 129),
        "card_bg": (24, 26, 56, 235),
        "card_border": (129, 140, 248, 90),
    },
    "slate": {
        "bg_top": (28, 34, 46),
        "bg_bottom": (12, 16, 26),
        "accent": (56, 189, 248),
        "accent_glow": (148, 163, 184),
        "badge_bg": (30, 41, 59),
        "card_bg": (26, 34, 48, 235),
        "card_border": (148, 163, 184, 90),
    }
}

PATTERN_STYLES: List[str] = ["grid", "dots", "rings", "aurora", "mesh"]


def generate_dynamic_background(
    width: int = 1080,
    height: int = 1080,
    theme_key: Optional[str] = None,
    pattern: Optional[str] = None,
    gradient_type: Optional[str] = None
) -> tuple:
    """Génère un fond visuel dynamique haute définition avec dégradés variables, halos d'éclairage et motifs texturés."""
    if not theme_key or theme_key not in THEME_PALETTES:
        theme_key = random.choice(list(THEME_PALETTES.keys()))
    t = THEME_PALETTES[theme_key]

    if not gradient_type:
        gradient_type = random.choice(["vertical", "diagonal_tl_br", "diagonal_tr_bl", "radial"])

    base = Image.new("RGBA", (width, height), t["bg_bottom"])
    draw = ImageDraw.Draw(base)

    if gradient_type == "vertical":
        for y in range(height):
            ratio = y / height
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    elif gradient_type == "diagonal_tl_br":
        max_dist = width + height
        for i in range(0, max_dist, 2):
            ratio = i / max_dist
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.line([(0, i), (i, 0)], fill=(r, g, b, 255), width=2)
    elif gradient_type == "diagonal_tr_bl":
        max_dist = width + height
        for i in range(0, max_dist, 2):
            ratio = i / max_dist
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.line([(width, i), (width - i, 0)], fill=(r, g, b, 255), width=2)
    else:  # radial spotlight
        cx, cy = width // 2, int(height * 0.4)
        max_rad = int(((width / 2) ** 2 + height ** 2) ** 0.5)
        for r_step in range(max_rad, 0, -4):
            ratio = r_step / max_rad
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.ellipse([(cx - r_step, cy - r_step), (cx + r_step, cy + r_step)], fill=(r, g, b, 255))

    # Halos lumineux d'ambiance avec coordonnées dynamiques
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    halo_x = random.choice([int(width * 0.1), int(width * 0.75), int(width * 0.5)])
    halo_y = random.choice([int(height * 0.15), int(height * 0.45), int(height * 0.8)])
    glow_draw.ellipse([(halo_x - 300, halo_y - 300), (halo_x + 300, halo_y + 300)], fill=(*t["accent"], 45))

    halo2_x = width - halo_x
    halo2_y = height - halo_y
    glow_draw.ellipse([(halo2_x - 250, halo2_y - 250), (halo2_x + 250, halo2_y + 250)], fill=(*t["accent_glow"], 35))

    glow = glow.filter(ImageFilter.GaussianBlur(85))
    base = Image.alpha_composite(base, glow)

    # Motifs géométriques & textures subtiles en arrière-plan
    if not pattern:
        pattern = random.choice(PATTERN_STYLES)

    pattern_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(pattern_layer)

    if pattern == "grid":
        step = 54
        for x in range(0, width, step):
            p_draw.line([(x, 0), (x, height)], fill=(255, 255, 255, 11), width=1)
        for y in range(0, height, step):
            p_draw.line([(0, y), (width, y)], fill=(255, 255, 255, 11), width=1)
        for _ in range(8):
            rx = random.randint(1, width // step - 1) * step
            ry = random.randint(1, height // step - 1) * step
            p_draw.line([(rx - 6, ry), (rx + 6, ry)], fill=(*t["accent_glow"], 50), width=1)
            p_draw.line([(rx, ry - 6), (rx, ry + 6)], fill=(*t["accent_glow"], 50), width=1)

    elif pattern == "dots":
        step = 40
        for x in range(20, width, step):
            for y in range(20, height, step):
                p_draw.ellipse([(x - 1, y - 1), (x + 1, y + 1)], fill=(255, 255, 255, 16))

    elif pattern == "rings":
        cx, cy = int(width * 0.75), int(height * 0.45)
        for r_step in range(60, 600, 75):
            p_draw.ellipse([(cx - r_step, cy - r_step), (cx + r_step, cy + r_step)], outline=(*t["accent"], 18), width=1)

    elif pattern == "aurora":
        streak = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(streak)
        s_draw.line([(-200, height + 200), (width + 200, -200)], fill=(*t["accent_glow"], 35), width=120)
        s_draw.line([(-100, height + 300), (width + 300, -100)], fill=(*t["accent"], 25), width=80)
        streak = streak.filter(ImageFilter.GaussianBlur(60))
        pattern_layer = Image.alpha_composite(pattern_layer, streak)

    elif pattern == "mesh":
        for _ in range(4):
            poly_x = random.randint(100, width - 100)
            poly_y = random.randint(100, height - 100)
            poly_r = random.randint(60, 160)
            p_draw.regular_polygon((poly_x, poly_y, poly_r), n_sides=6, outline=(255, 255, 255, 14), width=1)

    base = Image.alpha_composite(base, pattern_layer)
    return base, t


def render_banner_image(data: Dict[str, Any], output_path: str) -> str:
    width, height = 1080, 1080

    # 1. Sélection dynamique du thème pour assurer une variété permanente du fond
    requested_theme = data.get("theme")
    if requested_theme and requested_theme in THEME_PALETTES and random.random() < 0.5:
        selected_theme = requested_theme
    else:
        selected_theme = random.choice(list(THEME_PALETTES.keys()))

    base, t = generate_dynamic_background(width, height, theme_key=selected_theme)
    draw = ImageDraw.Draw(base)

    # 3. Polices de caractères
    font_brand = get_font(26, bold=True)
    font_brand_sub = get_font(18, bold=False)
    font_badge = get_font(18, bold=True)
    font_title = get_font(38, bold=True)
    font_subtitle = get_font(22, bold=False)
    font_point = get_font(19, bold=False)
    font_footer = get_font(20, bold=True)

    # 4. En-tête avec logo officiel Medsina
    logo_path = resolve_asset_path("assets/medsina-icon.png")
    header_x = 65
    if logo_path and logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((68, 68), Image.Resampling.LANCZOS)
            base.paste(logo_img, (header_x, 55), logo_img)
            header_x += 80
        except Exception:
            pass

    draw.text((header_x, 58), "MEDEVSYNC", font=font_brand, fill=(255, 255, 255, 255))
    draw.text((header_x, 90), "Medsina • Plateforme Médicale Globale", font=font_brand_sub, fill=(148, 163, 184, 255))

    # Badge de version & Web
    version_label = f"Version {APP_VERSION}"
    bbox_v = font_brand_sub.getbbox(version_label)
    vw = (bbox_v[2] - bbox_v[0]) + 30
    draw.rounded_rectangle([(width - 65 - vw, 65), (width - 65, 108)], radius=10, fill=(30, 41, 59, 200), outline=t["accent"], width=1)
    draw.text((width - 65 - vw + 15, 75), version_label, font=font_brand_sub, fill=(255, 255, 255, 230))

    # Ligne de séparation en-tête
    draw.line([(65, 140), (width - 65, 140)], fill=(51, 65, 85, 180), width=1)

    # 5. Badge thématique
    raw_badge = strip_emojis_for_image(data.get("badge", "MÉDECINE & CLINIQUE"))
    badge_text = f"  {raw_badge.upper()}  "
    bbox = font_badge.getbbox(badge_text)
    bw = (bbox[2] - bbox[0]) + 20
    bh = 36
    draw.rounded_rectangle([(65, 165), (65 + bw, 165 + bh)], radius=8, fill=t["badge_bg"], outline=t["accent"], width=2)
    draw.text((75, 172), badge_text.strip(), font=font_badge, fill=t["accent_glow"])

    # 6. Titre de l'infographie
    raw_title = strip_emojis_for_image(data.get("title", "Perle Clinique & Concours"))
    draw.text((65, 215), raw_title, font=font_title, fill=(255, 255, 255, 255))

    # Sous-titre
    raw_sub = strip_emojis_for_image(data.get("subtitle", "Pratique Médicale & Résidanat 2027"))
    draw.text((65, 265), raw_sub, font=font_subtitle, fill=(148, 163, 184, 255))

    # 7. Vérification de la disponibilité des mockups (Split Layout)
    mockup_type = data.get("mockup_type")
    path_desk = resolve_asset_path(data.get("screenshot_desktop"))
    path_mob = resolve_asset_path(data.get("screenshot_mobile"))

    can_render_mockup = False
    if mockup_type == "desktop" and path_desk:
        can_render_mockup = True
    elif mockup_type == "phone" and path_mob:
        can_render_mockup = True
    elif mockup_type == "duo" and (path_desk or path_mob):
        can_render_mockup = True

    content_y = 315

    if can_render_mockup:
        # === A. LAYOUT SPLIT AVEC MOCKUP RÉEL ===
        # A.1 Rendu du mockup à droite
        if mockup_type == "desktop" and path_desk:
            im_desk = Image.open(path_desk)
            mockup = render_desktop_mockup(im_desk, target_width=490)
            base.paste(mockup, (505, content_y - 15), mockup)
        elif mockup_type == "phone" and path_mob:
            im_mob = Image.open(path_mob)
            mockup = render_phone_mockup(im_mob, target_width=320)
            base.paste(mockup, (625, content_y - 15), mockup)
        elif mockup_type == "duo":
            im_desk = Image.open(path_desk) if path_desk else None
            im_mob = Image.open(path_mob) if path_mob else None
            if im_desk and im_mob:
                duo = render_duo_mockup(im_desk, im_mob, 530, 560)
                base.paste(duo, (495, content_y - 15), duo)
            elif im_desk:
                mockup = render_desktop_mockup(im_desk, target_width=490)
                base.paste(mockup, (505, content_y - 15), mockup)
            elif im_mob:
                mockup = render_phone_mockup(im_mob, target_width=320)
                base.paste(mockup, (625, content_y - 15), mockup)

        # A.2 Conteneur des fonctionnalités à gauche (largeur 440)
        card_w = 440
        card_h = 560
        card_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        card_draw = ImageDraw.Draw(card_layer)
        card_draw.rounded_rectangle(
            [(65, content_y), (65 + card_w, content_y + card_h)],
            radius=20,
            fill=t["card_bg"],
            outline=t["card_border"],
            width=2
        )
        base = Image.alpha_composite(base, card_layer)
        draw = ImageDraw.Draw(base)

        # Points clés
        py = content_y + 25
        points = data.get("points", [])
        for i, pt in enumerate(points[:4]):
            clean_pt = strip_emojis_for_image(pt)
            draw.ellipse([(85, py + 3), (107, py + 25)], fill=t["accent"])
            draw.text((93, py + 3), str(i + 1), font=font_brand_sub, fill=(15, 23, 42, 255))

            words = clean_pt.split()
            lines = []
            cur = []
            for w in words:
                test = " ".join(cur + [w])
                if font_point.getbbox(test)[2] > 355:
                    lines.append(" ".join(cur))
                    cur = [w]
                else:
                    cur.append(w)
            if cur:
                lines.append(" ".join(cur))

            for l in lines:
                draw.text((118, py), l, font=font_point, fill=(241, 245, 249, 255))
                py += 26
            py += 14

        # Bannière CTA de téléchargement intégrée
        cta_y = content_y + card_h - 90
        draw.rounded_rectangle(
            [(85, cta_y), (65 + card_w - 20, cta_y + 70)],
            radius=12,
            fill=(30, 41, 59, 240),
            outline=t["accent"],
            width=1
        )
        draw.text((100, cta_y + 12), "DISPONIBLE DÈS MAINTENANT", font=font_badge, fill=t["accent_glow"])
        draw.text((100, cta_y + 38), "Android APK  •  Windows PC  •  Version Web", font=font_brand_sub, fill=(255, 255, 255, 230))

    else:
        # === B. FALLBACK : LAYOUT PLEINE LARGEUR STANDARD ===
        card_y = content_y
        card_h = 880 - card_y
        card_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        card_draw = ImageDraw.Draw(card_layer)
        card_draw.rounded_rectangle(
            [(65, card_y), (width - 65, card_y + card_h)],
            radius=24,
            fill=t["card_bg"],
            outline=t["card_border"],
            width=2
        )
        base = Image.alpha_composite(base, card_layer)
        draw = ImageDraw.Draw(base)

        py = card_y + 35
        points = data.get("points", [])
        font_point_full = get_font(24, bold=False)
        for i, pt in enumerate(points[:4]):
            clean_pt = strip_emojis_for_image(pt)
            draw.ellipse([(100, py + 5), (124, py + 29)], fill=t["accent"])
            draw.text((109, py + 5), str(i + 1), font=font_brand_sub, fill=(15, 23, 42, 255))

            pt_words = clean_pt.split()
            p_lines = []
            p_cur = []
            for pw in pt_words:
                test_p = " ".join(p_cur + [pw])
                if font_point_full.getbbox(test_p)[2] > 760:
                    p_lines.append(" ".join(p_cur))
                    p_cur = [pw]
                else:
                    p_cur.append(pw)
            if p_cur:
                p_lines.append(" ".join(p_cur))

            for pl in p_lines:
                draw.text((144, py), pl, font=font_point_full, fill=(241, 245, 249, 255))
                py += 34
            py += 16

    # 8. Pied de page
    footer_y = 945
    draw.line([(65, footer_y), (width - 65, footer_y)], fill=(51, 65, 85, 180), width=1)
    draw.text((65, footer_y + 24), "medsina.medevsync.com  •  Portail Officiel MedevSync", font=font_footer, fill=t["accent_glow"])
    draw.text((width - 310, footer_y + 26), "Algérie • Résidanat 2027", font=font_brand_sub, fill=(148, 163, 184, 255))

    dir_name = os.path.dirname(output_path)
    if dir_name:
        os.makedirs(dir_name, exist_ok=True)
    base.convert("RGB").save(output_path, "PNG", quality=95)
    return output_path


def publish_photo_to_facebook(image_path: str, caption: str) -> Dict[str, Any]:
    creds = get_facebook_credentials()
    page_id = creds["page_id"]
    token = creds["page_token"]

    url = f"https://graph.facebook.com/v21.0/{page_id}/photos"

    with open(image_path, "rb") as img_file:
        files = {
            "source": (os.path.basename(image_path), img_file, "image/png"),
        }
        data = {
            "caption": caption,
            "access_token": token,
        }
        resp = requests.post(url, data=data, files=files, timeout=60)

    if resp.status_code == 200:
        return resp.json()
    else:
        raise RuntimeError(f"Facebook Graph API Error ({resp.status_code}): {resp.text}")


def main():
    parser = argparse.ArgumentParser(description="Generate and publish an AI/medical visual post to Facebook (2x/day)")
    parser.add_argument("--topic", type=str, default=None, help="Specific medical or promotional topic to generate")
    parser.add_argument("--type", choices=["auto", "commercial", "medical"], default="auto", help="Post objective: commercial (download CTA) or medical (clinical extract)")
    parser.add_argument("--dry-run", action="store_true", help="Generate content and image without publishing to Facebook")
    parser.add_argument("--output-image", type=str, default="output_banner.png", help="Path to save generated image")
    args = parser.parse_args()

    print("=" * 65)
    print("🎨 MEDEVSYNC & MEDSINA FACEBOOK VISUAL PUBLISHER (2x/JOUR)")
    print(f"📌 Thème   : {args.topic or 'Automatique'}")
    print(f"🎯 Visée   : {args.type.upper()}")
    print(f"⚙️ Mode    : {'DRY RUN (Aperçu local)' if args.dry_run else 'PUBLICATION EN DIRECT'}")
    print("=" * 65)

    print("\n🧠 1. Sélection & génération du contenu adapté...")
    post_data = get_post_data(topic=args.topic, post_type=args.type)
    print(f"Titre   : {post_data.get('title')}")
    print(f"Badge   : {post_data.get('badge')}")
    print(f"Thème   : {post_data.get('theme')}")

    print("\n🖼️ 2. Création de l'infographie haute résolution (1080x1080)...")
    img_path = render_banner_image(post_data, args.output_image)
    print(f"Image générée avec succès : {img_path}")

    print("\n📝 3. Légende du Post Facebook (avec liens officiels Octenium) :")
    print("-" * 55)
    print(post_data.get("caption"))
    print("-" * 55)

    if args.dry_run:
        print("\n[DRY RUN] Publication Facebook/Telegram ignorée. Image prête pour inspection.")
        try:
            from telegram_publisher import format_telegram_caption, send_telegram_broadcast
            tg_caption = format_telegram_caption(
                title=post_data.get("title", ""),
                badge=post_data.get("badge", ""),
                points=post_data.get("points", []),
                reference=post_data.get("reference", ""),
                app_version=APP_VERSION
            )
            send_telegram_broadcast(message_text=tg_caption, image_path=img_path, dry_run=True)
        except Exception as e:
            print(f"Notice Telegram dry-run: {e}")
        return

    print("\n🚀 4. Publication de la photo et du texte sur la page Facebook Medevsync...")
    try:
        res = publish_photo_to_facebook(img_path, post_data.get("caption", ""))
        photo_id = res.get("id")
        post_id = res.get("post_id")
        print(f"🎉 SUCCÈS FACEBOOK ! Photo ID: {photo_id} | Post ID: {post_id}")
        if post_id:
            print(f"🔗 Lien : https://www.facebook.com/{post_id}")
    except Exception as e:
        print(f"❌ Erreur lors de la publication Facebook: {e}")

    print("\n✈️ 5. Diffusion automatique sur le Canal Officiel Telegram...")
    try:
        from telegram_publisher import format_telegram_caption, send_telegram_broadcast
        tg_caption = format_telegram_caption(
            title=post_data.get("title", ""),
            badge=post_data.get("badge", ""),
            points=post_data.get("points", []),
            reference=post_data.get("reference", ""),
            app_version=APP_VERSION
        )
        send_telegram_broadcast(message_text=tg_caption, image_path=img_path, dry_run=False)
    except Exception as e:
        print(f"⚠️ Information Telegram: {e}")


if __name__ == "__main__":
    main()

