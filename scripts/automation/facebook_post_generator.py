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
    try:
        pubspec = Path(__file__).resolve().parents[2] / "pubspec.yaml"
        if pubspec.exists():
            for line in pubspec.read_text(encoding="utf-8").splitlines():
                if line.startswith("version:"):
                    return line.split(":")[1].strip().split("+")[0]
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
    )
    clean = re.sub(r'[\U00010000-\U0010ffff]', '', text)
    clean = re.sub(r'[^\x00-\x7F\u00C0-\u017F]', ' ', clean)
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

Tu dois répondre UNIQUEMENT par un objet JSON valide avec la structure suivante :
{{
  "caption": "Texte complet du post Facebook avec émojis, mise en page aérée, accroche percutante et 4 points médicaux clés (SANS les liens finaux car ils seront ajoutés automatiquement)",
  "badge": "TITRE DU BADGE (ex: PROTOCOLE D'URGENCE, VIDAL ALGÉRIE, PIÈGE DE CONCOURS, APPLICATION MEDSINA)",
  "title": "Titre choc et court pour l'image (max 50 caractères)",
  "subtitle": "Spécialité & Thème (ex: Cardiologie & Urgences Médicales • Medsina)",
  "points": [
    "Point 1 court et percutant (max 15 mots)",
    "Point 2 court et percutant (max 15 mots)",
    "Point 3 court et percutant (max 15 mots)",
    "Point 4 court et percutant (max 15 mots)"
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
                    parsed["caption"] = parsed.get("caption", "").strip() + "\n" + OFFICIAL_FOOTER
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

def render_banner_image(data: Dict[str, Any], output_path: str) -> str:
    width, height = 1080, 1080
    theme = data.get("theme", "blue")

    themes = {
        "blue": {
            "bg_top": (10, 25, 47),
            "bg_bottom": (15, 23, 42),
            "accent": (14, 165, 233),
            "accent_glow": (56, 189, 248),
            "badge_bg": (12, 74, 110),
            "card_bg": (20, 32, 55, 235),
            "card_border": (56, 189, 248, 90),
        },
        "emerald": {
            "bg_top": (6, 35, 25),
            "bg_bottom": (15, 23, 42),
            "accent": (16, 185, 129),
            "accent_glow": (52, 211, 153),
            "badge_bg": (6, 78, 59),
            "card_bg": (18, 40, 32, 235),
            "card_border": (52, 211, 153, 90),
        },
        "amber": {
            "bg_top": (45, 26, 6),
            "bg_bottom": (15, 23, 42),
            "accent": (245, 158, 11),
            "accent_glow": (251, 191, 36),
            "badge_bg": (120, 53, 15),
            "card_bg": (40, 28, 18, 235),
            "card_border": (251, 191, 36, 90),
        },
        "purple": {
            "bg_top": (30, 15, 50),
            "bg_bottom": (15, 23, 42),
            "accent": (168, 85, 247),
            "accent_glow": (192, 132, 252),
            "badge_bg": (88, 28, 135),
            "card_bg": (32, 20, 48, 235),
            "card_border": (192, 132, 252, 90),
        }
    }

    t = themes.get(theme, themes["blue"])

    # 1. Fond dégradé vertical
    base = Image.new("RGBA", (width, height), t["bg_bottom"])
    draw = ImageDraw.Draw(base)

    for y in range(height):
        ratio = y / height
        r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
        g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
        b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # 2. Halos lumineux d'ambiance
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([(-100, -100), (450, 450)], fill=(*t["accent"], 45))
    glow_draw.ellipse([(width - 350, height - 350), (width + 150, height + 150)], fill=(*t["accent"], 35))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    base = Image.alpha_composite(base, glow)
    draw = ImageDraw.Draw(base)

    # 3. Polices de caractères
    def get_font(size: int, bold: bool = False):
        font_paths = [
            "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
            "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ]
        for p in font_paths:
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    pass
        return ImageFont.load_default()

    font_brand = get_font(26, bold=True)
    font_brand_sub = get_font(18, bold=False)
    font_badge = get_font(20, bold=True)
    font_title = get_font(44, bold=True)
    font_subtitle = get_font(24, bold=False)
    font_point = get_font(27, bold=False)
    font_footer = get_font(21, bold=True)

    # 4. En-tête avec logo officiel Medsina
    assets_dir = Path(__file__).resolve().parents[2] / "assets"
    logo_path = assets_dir / "medsina-icon.png"
    header_x = 70
    if logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((72, 72), Image.Resampling.LANCZOS)
            base.paste(logo_img, (header_x, 65), logo_img)
            header_x += 88
        except Exception:
            pass

    draw.text((header_x, 70), "MEDEVSYNC", font=font_brand, fill=(255, 255, 255, 255))
    draw.text((header_x, 102), "Medsina • Plateforme Médicale Globale", font=font_brand_sub, fill=(148, 163, 184, 255))

    # Badge de version & Web
    draw.rounded_rectangle([(width - 250, 75), (width - 70, 120)], radius=12, fill=(30, 41, 59, 200), outline=t["accent"], width=1)
    draw.text((width - 232, 85), "Version 1.0.7", font=font_brand_sub, fill=(255, 255, 255, 230))

    # 5. Badge thématique
    raw_badge = strip_emojis_for_image(data.get("badge", "MÉDECINE & CLINIQUE"))
    badge_text = f"  {raw_badge.upper()}  "
    bbox = font_badge.getbbox(badge_text)
    bw = (bbox[2] - bbox[0]) + 24
    bh = 42
    draw.rounded_rectangle([(70, 185), (70 + bw, 185 + bh)], radius=10, fill=t["badge_bg"], outline=t["accent"], width=2)
    draw.text((82, 194), badge_text.strip(), font=font_badge, fill=t["accent_glow"])

    # 6. Titre de l'infographie
    raw_title = strip_emojis_for_image(data.get("title", "Perle Clinique & Concours"))
    words = raw_title.split()
    lines = []
    cur = []
    for w in words:
        test_line = " ".join(cur + [w])
        if font_title.getbbox(test_line)[2] > 920:
            lines.append(" ".join(cur))
            cur = [w]
        else:
            cur.append(w)
    if cur:
        lines.append(" ".join(cur))

    y_text = 252
    for l in lines[:2]:
        draw.text((70, y_text), l, font=font_title, fill=(255, 255, 255, 255))
        y_text += 56

    # Sous-titre
    raw_sub = strip_emojis_for_image(data.get("subtitle", "Pratique Médicale & Résidanat 2027"))
    draw.text((70, y_text + 4), raw_sub, font=font_subtitle, fill=(148, 163, 184, 255))
    y_text += 52

    # 7. Conteneur central en verre dépoli (Glassmorphism)
    card_y = y_text + 15
    card_h = 880 - card_y
    card_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card_layer)
    card_draw.rounded_rectangle([(70, card_y), (width - 70, card_y + card_h)], radius=24, fill=t["card_bg"], outline=t["card_border"], width=2)
    base = Image.alpha_composite(base, card_layer)
    draw = ImageDraw.Draw(base)

    # 8. Puces clés de contenu
    py = card_y + 35
    points = data.get("points", [])
    for i, pt in enumerate(points[:4]):
        clean_pt = strip_emojis_for_image(pt)
        draw.ellipse([(105, py + 8), (127, py + 30)], fill=t["accent"])
        draw.text((113, py + 7), str(i + 1), font=font_brand_sub, fill=(15, 23, 42, 255))

        pt_words = clean_pt.split()
        p_lines = []
        p_cur = []
        for pw in pt_words:
            test_p = " ".join(p_cur + [pw])
            if font_point.getbbox(test_p)[2] > 740:
                p_lines.append(" ".join(p_cur))
                p_cur = [pw]
            else:
                p_cur.append(pw)
        if p_cur:
            p_lines.append(" ".join(p_cur))

        for pl in p_lines[:2]:
            draw.text((148, py), pl, font=font_point, fill=(241, 245, 249, 255))
            py += 38
        py += 22

    # 9. Pied de page avec URL officielle
    footer_y = 930
    draw.line([(70, footer_y), (width - 70, footer_y)], fill=(51, 65, 85, 200), width=1)
    draw.text((70, footer_y + 26), "medsina.medevsync.com  •  Web, Android & PC", font=font_footer, fill=t["accent_glow"])
    draw.text((width - 320, footer_y + 28), "MedevSync HealthTech", font=font_brand_sub, fill=(148, 163, 184, 255))

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
        print("\n[DRY RUN] Publication ignorée. Image prête pour inspection.")
        return

    print("\n🚀 4. Publication de la photo et du texte sur la page Facebook Medevsync...")
    res = publish_photo_to_facebook(img_path, post_data.get("caption", ""))
    photo_id = res.get("id")
    post_id = res.get("post_id")
    print(f"🎉 SUCCÈS ! Photo ID: {photo_id} | Post ID: {post_id}")
    if post_id:
        print(f"🔗 Lien : https://www.facebook.com/{post_id}")


if __name__ == "__main__":
    main()
