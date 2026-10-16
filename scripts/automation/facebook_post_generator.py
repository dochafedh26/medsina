#!/usr/bin/env python3
"""
Medsina & MedevSync AI Facebook Automated Visual Post Generator
- Uses Gemini AI or Medsina Clinical Knowledge Base (Mementos, CATs, Urgences, Résumés).
- Generates high-definition branded 1080x1080 visual infographics with Pillow.
- Publishes native Photo Posts to the MedevSync Facebook Page via Meta Graph API.
- Retrieves credentials securely from Supabase admin_system_settings.
"""

import os
import re
import sys
import json
import time
import random
import argparse
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


def load_gemini_api_key() -> Optional[str]:
    key = os.environ.get("GEMINI_API_KEY")
    if key and not key.startswith("AQ."):
        return key.strip()

    secrets_file = Path(__file__).resolve().parents[2] / "lib" / "core" / "config" / "app_secrets.dart"
    if secrets_file.exists():
        content = secrets_file.read_text(encoding="utf-8")
        m = re.search(r"geminiApiKey\s*=\s*['\"]([^'\"]+)['\"]", content)
        if m and m.group(1).strip() and not m.group(1).startswith("AQ."):
            return m.group(1).strip()

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
                if not val.startswith("AQ."):
                    return val
    except Exception:
        pass

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
    """Replaces math/medical symbols and removes emojis to avoid missing font glyph boxes."""
    text = text.replace("≥", ">=").replace("≤", "<=").replace("±", "+/-").replace("→", "->").replace("•", "-")
    clean = re.sub(r'[\U00010000-\U0010ffff]', '', text)
    clean = re.sub(r'[^\x00-\x7F\u00C0-\u017F]', ' ', clean)
    return re.sub(r'\s+', ' ', clean).strip()


def build_from_memento(memento: Dict[str, Any]) -> Dict[str, Any]:
    """Builds post data from a Medsina on-call memento."""
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
    }
    theme = theme_map.get(category, "blue")

    caption = f"""📋 MÉMENTO DE GARDE : {title}
Spécialité : {category} 🏥

Chers confrères, internes et praticiens de garde, voici les points réflexes essentiels à maîtriser immédiatement au lit du malade :

"""
    for i, p in enumerate(points, 1):
        caption += f"{i}️⃣ {p}\n"

    caption += f"""
💡 Référence clinique : {memento.get('scientific_references', 'Recommandations & Consensus Pratique Médicale')}

📲 Retrouvez l'intégralité des fiches réflexes, l'analyseur d'ordonnance et les résumés du résidanat dans l'application Medsina (v1.0.7) !
Lien de téléchargement : Disponible pour tous les résidents et candidats au concours.

#MedevSync #Medsina #MedecineAlgerie #PratiqueHospitaliere #GardeMedicale #Residanat2027 #InternatMedecine"""

    return {
        "caption": caption,
        "badge": f"MÉMENTO • {category.upper()}",
        "title": title,
        "subtitle": f"{category} • Fiche Réflexe de Garde",
        "points": points,
        "theme": theme,
    }


def build_from_course_summary(summary: Dict[str, Any]) -> Dict[str, Any]:
    """Builds post data from a high-yield residency course summary."""
    course_name = summary.get("course_name", "Fiche de Révision")
    module_name = summary.get("module_name", "Module Médical")
    traps = summary.get("exam_traps", [])
    takeaways = summary.get("key_takeaways", [])

    points = (traps if traps else takeaways)[:4]

    caption = f"""📖 RÉVISION RÉSIDANAT 2027 : {course_name}
Module : {module_name} 🎯

Pour maximiser vos points et déjouer les pièges fréquents du concours, voici les points incontournables à retenir pour ce cours :

"""
    for i, p in enumerate(points, 1):
        caption += f"⚠️ {p}\n"

    caption += f"""
🎯 Synthétisé selon les consensus officiels et anales du concours de résidanat en Algérie (Blida, Alger, Constantine, Oran).

📲 Révisez plus intelligemment avec Medsina v1.0.7 : Fiches synthèses, QCMs corrigés et protocoles cliniques dans votre poche !

#MedevSync #Medsina #Residanat2027 #MedecineAlgerie #QCMConcours #RevisionMedicale #BlidaMed"""

    return {
        "caption": caption,
        "badge": f"CONCOURS 2027 • {module_name.upper()}",
        "title": f"Pièges & Clés : {course_name}",
        "subtitle": f"Module {module_name} • Concours Résidanat",
        "points": points,
        "theme": "purple",
    }


def generate_post_content_gemini(topic: str, gemini_key: str) -> Dict[str, Any]:
    system_prompt = """Tu es le Directeur Médical & Marketing de MedevSync, la startup algérienne éditrice de l'application mobile "Medsina" (Plateforme médicale globale pour étudiants, internes et candidats au concours de Résidanat 2027 en Algérie).
Ton rôle est de créer des publications Facebook modernes, captivantes, hautement pédagogiques et attractives.

Tu dois répondre UNIQUEMENT par un objet JSON valide avec la structure suivante :
{
  "caption": "Texte complet du post Facebook avec émojis, mise en page aérée, accroche percutante, 4 points médicaux clés, appel à l'action pour télécharger Medsina v1.0.7 et hashtags ciblés (#MedevSync #Medsina #MedecineAlgerie #Residanat2027 #PratiqueClinique)",
  "badge": "TITRE DU BADGE (ex: PROTOCOLE D'URGENCE, PERLE DU JOUR, VIDAL ALGÉRIE, PIÈGE DE CONCOURS)",
  "title": "Titre choc et court pour l'image (max 50 caractères)",
  "subtitle": "Spécialité & Thème (ex: Cardiologie & Urgences Médicales • Medsina)",
  "points": [
    "Point 1 court et percutant (max 15 mots)",
    "Point 2 court et percutant (max 15 mots)",
    "Point 3 court et percutant (max 15 mots)",
    "Point 4 court et percutant (max 15 mots)"
  ],
  "theme": "blue | emerald | amber | purple"
}"""

    prompt = f"""Génère une publication Facebook médicale complète, ultra-attractive et éducative pour l'application Medsina sur le thème : "{topic}".
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
                    return json.loads(clean)
        except Exception as e:
            print(f"Gemini {model} error: {e}")
            continue

    raise RuntimeError("Failed to generate response across all Gemini models.")


def get_curated_or_ai_post(topic: Optional[str] = None) -> Dict[str, Any]:
    assets_dir = Path(__file__).resolve().parents[2] / "assets" / "data"
    mementos_file = assets_dir / "on_call_mementos.json"
    summaries_file = assets_dir / "course_summaries.json"

    gemini_key = load_gemini_api_key()
    if topic and gemini_key:
        try:
            print(f"🧠 Utilisation de Gemini AI pour le thème : '{topic}'")
            return generate_post_content_gemini(topic, gemini_key)
        except Exception as e:
            print(f"Notice Gemini indisponible ({e}), bascule sur la base médicale interne Medsina...")

    # Load from curated clinical database
    if mementos_file.exists():
        try:
            mementos = json.loads(mementos_file.read_text(encoding="utf-8"))
            if topic:
                filtered = [m for m in mementos if topic.lower() in m.get("title", "").lower() or topic.lower() in m.get("category", "").lower()]
                if filtered:
                    return build_from_memento(random.choice(filtered))
            # Pick a rich memento (e.g. Hypoglycemia, Checklist, or Choc)
            if mementos:
                return build_from_memento(random.choice(mementos))
        except Exception as e:
            print(f"Warning reading mementos: {e}")

    if summaries_file.exists():
        try:
            summaries = json.loads(summaries_file.read_text(encoding="utf-8"))
            if summaries:
                return build_from_course_summary(random.choice(summaries))
        except Exception as e:
            print(f"Warning reading course summaries: {e}")

    # Ultimate fallback template: Analyseur d'ordonnance & Vidal Algérie
    return {
        "caption": """🚨 SÉCURITÉ DE PRESCRIPTION : LES INTERACTIONS MÉDICAMENTEUSES GRAVES EN GARDE ! 💊

L'analyse d'ordonnance est un acte médical critique au lit du malade. En garde ou en consultation, certaines associations médicamenteuses exposent à des risques vitaux immédiats :

1️⃣ Sintrom (Acénocoumarol) + Rifampicine : Induction enzymatique majeure du CYP2C9 entraînant une baisse drastique de l'INR et un risque thrombotique fatal.
2️⃣ Colchicine + Clarithromycine : Inhibition du CYP3A4 et de la P-glycoprotéine avec surdosage mortel en colchicine (Aplasie médullaire, choc).
3️⃣ Double AINS (ex. Kétoprofène + Aspirine) : Majoration drastique du risque d'ulcère hémorragique digestif sans bénéfice antalgique supplémentaire.
4️⃣ Plavix (Clopidogrel) + Oméprazole : Perte d'efficacité antiagrégante par blocage du CYP2C19 → Risque d'infarctus ou de thrombose de stent.

🔍 Avec l'Analyseur d'Ordonnance intelligent de Medsina, ces interactions et contre-indications de terrain (diabète, HTA, insuffisance rénale) sont détectées instantanément selon la nomenclature officielle algérienne !

📲 Téléchargez Medsina v1.0.7 et sécurisez chaque prescription.

#MedevSync #Medsina #VidalAlgerie #SecuriteDuPatient #PrescriptionMedicale #MedecineAlgerie #Residanat2027 #Internat""",
        "badge": "SÉCURITÉ • VIDAL ALGÉRIE",
        "title": "Interactions Mortelles : 4 Pièges en Garde",
        "subtitle": "Pharmacologie Clinique & Urgences Médicales",
        "points": [
            "Sintrom + Rifampicine : Inefficacité anticoagulante et thrombose.",
            "Colchicine + Clarithromycine : Toxicité médullaire mortelle.",
            "Double AINS (Kétoprofène + Aspirine) : Hémorragie digestive haute.",
            "Plavix + Oméprazole : Perte d'efficacité et récidive d'IDM."
        ],
        "theme": "amber",
    }


def render_banner_image(data: Dict[str, Any], output_path: str):
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

    # 1. Base gradient
    base = Image.new("RGBA", (width, height), t["bg_bottom"])
    draw = ImageDraw.Draw(base)

    for y in range(height):
        ratio = y / height
        r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
        g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
        b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # 2. Ambient glow
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([(-100, -100), (450, 450)], fill=(*t["accent"], 45))
    glow_draw.ellipse([(width - 350, height - 350), (width + 150, height + 150)], fill=(*t["accent"], 35))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    base = Image.alpha_composite(base, glow)
    draw = ImageDraw.Draw(base)

    # 3. Fonts
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
    font_footer = get_font(22, bold=True)

    # 4. Header with logo
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
    draw.text((header_x, 102), "Medsina • Plateforme Médicale Officielle", font=font_brand_sub, fill=(148, 163, 184, 255))

    # Version pill
    draw.rounded_rectangle([(width - 240, 75), (width - 70, 120)], radius=12, fill=(30, 41, 59, 200), outline=t["accent"], width=1)
    draw.text((width - 222, 85), "Version 1.0.7", font=font_brand_sub, fill=(255, 255, 255, 230))

    # 5. Badge
    raw_badge = strip_emojis_for_image(data.get("badge", "MÉDECINE & CLINIQUE"))
    badge_text = f"  {raw_badge.upper()}  "
    bbox = font_badge.getbbox(badge_text)
    bw = (bbox[2] - bbox[0]) + 24
    bh = 42
    draw.rounded_rectangle([(70, 185), (70 + bw, 185 + bh)], radius=10, fill=t["badge_bg"], outline=t["accent"], width=2)
    draw.text((82, 194), badge_text.strip(), font=font_badge, fill=t["accent_glow"])

    # 6. Title
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

    # Subtitle
    raw_sub = strip_emojis_for_image(data.get("subtitle", "Pratique Médicale & Résidanat 2027"))
    draw.text((70, y_text + 4), raw_sub, font=font_subtitle, fill=(148, 163, 184, 255))
    y_text += 52

    # 7. Card container
    card_y = y_text + 15
    card_h = 880 - card_y
    card_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card_layer)
    card_draw.rounded_rectangle([(70, card_y), (width - 70, card_y + card_h)], radius=24, fill=t["card_bg"], outline=t["card_border"], width=2)
    base = Image.alpha_composite(base, card_layer)
    draw = ImageDraw.Draw(base)

    # 8. Bullet points
    py = card_y + 35
    points = data.get("points", [])
    for i, pt in enumerate(points[:4]):
        clean_pt = strip_emojis_for_image(pt)
        # Bullet circle
        draw.ellipse([(105, py + 8), (127, py + 30)], fill=t["accent"])
        draw.text((113, py + 7), str(i + 1), font=font_brand_sub, fill=(15, 23, 42, 255))

        # Wrapped point text
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

    # 9. Bottom Footer
    footer_y = 930
    draw.line([(70, footer_y), (width - 70, footer_y)], fill=(51, 65, 85, 200), width=1)
    draw.text((70, footer_y + 26), "Medsina App • Pratique Clinique & Résidanat", font=font_footer, fill=t["accent_glow"])
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
    parser = argparse.ArgumentParser(description="Generate and publish an AI/medical visual post to Facebook")
    parser.add_argument("--topic", type=str, default=None, help="Medical topic to generate")
    parser.add_argument("--dry-run", action="store_true", help="Generate content and image without publishing to Facebook")
    parser.add_argument("--output-image", type=str, default="output_banner.png", help="Path to save generated image")
    args = parser.parse_args()

    print("=" * 65)
    print("🎨 MEDEVSYNC & MEDSINA FACEBOOK VISUAL POST GENERATOR")
    print(f"📌 Thème   : {args.topic or 'Automatique (Base Clinique Medsina)'}")
    print(f"⚙️ Mode    : {'DRY RUN (Aperçu local)' if args.dry_run else 'PUBLICATION EN DIRECT'}")
    print("=" * 65)

    print("\n🧠 1. Sélection & génération du contenu médical...")
    post_data = get_curated_or_ai_post(args.topic)
    print(f"Titre   : {post_data.get('title')}")
    print(f"Badge   : {post_data.get('badge')}")
    print(f"Thème   : {post_data.get('theme')}")

    print("\n🖼️ 2. Création de l'infographie haute résolution (1080x1080)...")
    img_path = render_banner_image(post_data, args.output_image)
    print(f"Image générée avec succès : {img_path}")

    print("\n📝 3. Légende du Post Facebook :")
    print("-" * 50)
    print(post_data.get("caption"))
    print("-" * 50)

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
