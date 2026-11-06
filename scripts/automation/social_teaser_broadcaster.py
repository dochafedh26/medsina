#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA SOCIAL TEASER BROADCASTER (Modern Light Theme & Multi-Channel)
=============================================================================
Diffuse automatiquement des teasers cliniques attractifs (anti-spoiler) lors
de la génération autonome de contenus médicaux :
- Conduites à Tenir (CAT)
- Mémentos de Garde Hospitalière
- Urgences & DCI (Nomenclature Algérie Saidal/PCH)
- Normes Biologiques & Seuils Critiques
- Fiches Résumés de Cours Officiels du Résidanat
- Perles Cliniques & Pièges du Concours

Canaux cibles :
1. Facebook Page Officielle « Medsina » (ID: 1449308354921826)
2. Facebook Page Communauté « Résidanat Blida 2027 » (ID: 1405719695953624)
3. Facebook Page Partenaire « MedevSync » (ID: 1329939320211198)
3. Telegram Canal Officiel « @medsina_officiel »
=============================================================================
"""

import os
import sys
import re
import json
import tempfile
import requests
from pathlib import Path
from typing import Dict, Any, Optional, List
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def strip_emojis_for_image(text: str) -> str:
    """Retire les émojis non supportés par les polices vectorielles pour éviter les carrés vides."""
    if not text:
        return ""
    # Remove surrogate pairs and standard emoji ranges
    emoji_pattern = re.compile(
        "["
        "\U00010000-\U0010ffff"
        "\u2600-\u27bf"
        "\u2300-\u23ff"
        "\u2b50-\u2b55"
        "\u3030-\u303d"
        "]+",
        flags=re.UNICODE
    )
    cleaned = emoji_pattern.sub("", text)
    # Clean redundant whitespace
    return re.sub(r"\s+", " ", cleaned).strip()

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Official URLs
OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OFFICIAL_WIN_URL = "https://medsina.medevsync.com"
OFFICIAL_TELEGRAM_URL = "https://t.me/medsina_officiel"

# Path to logo asset
REPO_ROOT = Path(__file__).resolve().parents[2]
LOGO_PATH = REPO_ROOT / "assets" / "medsina-logo.png"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    or os.environ.get("SUPABASE_KEY")
    or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)


# =============================================================================
# 1. GESTION DES IDENTIFIANTS & CREDENTIALS
# =============================================================================

def get_social_credentials() -> Dict[str, str]:
    """
    Récupère les identifiants pour les deux pages Facebook et le bot Telegram :
    1. Variables d'environnement (si définies)
    2. Table Supabase admin_system_settings
    """
    creds = {
        "medsina_page_id": os.environ.get("FB_MEDSINA_PAGE_ID", "1449308354921826").strip(),
        "medsina_token": os.environ.get("FB_MEDSINA_PAGE_ACCESS_TOKEN", "").strip(),
        "blida_page_id": os.environ.get("FB_BLIDA_PAGE_ID", "1405719695953624").strip(),
        "blida_token": os.environ.get("FB_BLIDA_PAGE_ACCESS_TOKEN", "").strip(),
        "medevsync_page_id": os.environ.get("FB_MEDEVSYNC_PAGE_ID", "1329939320211198").strip(),
        "medevsync_token": os.environ.get("FB_MEDEVSYNC_PAGE_ACCESS_TOKEN", "").strip(),
        "cat_page_id": os.environ.get("FB_CAT_PAGE_ID", "102416914491075").strip(),
        "cat_token": os.environ.get("FB_CAT_PAGE_ACCESS_TOKEN", "").strip(),
        "telegram_token": os.environ.get("TELEGRAM_BOT_TOKEN", "").strip(),
        "telegram_channel": os.environ.get("TELEGRAM_CHANNEL_ID", "@medsina_officiel").strip(),
        "telegram_community": os.environ.get("TELEGRAM_COMMUNITY_GROUP_ID", "-1004438944860").strip(),
        "telegram_topics_map": None
    }

    # Fetch missing from Supabase
    if not (creds["medsina_token"] and creds["blida_token"] and creds["medevsync_token"] and creds["telegram_token"]):
        try:
            url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
            headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
            r = requests.get(url, headers=headers, timeout=10)
            if r.status_code == 200:
                settings = {x["setting_key"]: x["setting_value"] for x in r.json() if isinstance(x, dict)}
                if not creds["medsina_token"]:
                    creds["medsina_token"] = (settings.get("facebook_medsina_page_access_token") or "").strip()
                if not creds["blida_token"]:
                    creds["blida_token"] = (settings.get("facebook_blida_page_access_token") or settings.get("facebook_page_access_token") or "").strip()
                if not creds["medevsync_token"]:
                    creds["medevsync_token"] = (settings.get("facebook_medevsync_page_access_token") or "").strip()
                if not creds["cat_token"]:
                    creds["cat_token"] = (settings.get("facebook_cat_page_access_token") or settings.get("facebook_user_access_token") or "").strip()
                if not creds["cat_page_id"]:
                    creds["cat_page_id"] = (settings.get("facebook_cat_page_id") or "102416914491075").strip()
                if not creds["telegram_token"]:
                    creds["telegram_token"] = (settings.get("telegram_bot_token") or "").strip()
                if not creds["telegram_channel"] or creds["telegram_channel"] == "@medsina_officiel":
                    ch = (settings.get("telegram_channel_id") or "").strip()
                    if ch:
                        creds["telegram_channel"] = ch
                if not creds.get("telegram_community"):
                    creds["telegram_community"] = (settings.get("telegram_community_group_id") or "-1004438944860").strip()
                if settings.get("telegram_topics_map"):
                    try:
                        creds["telegram_topics_map"] = json.loads(settings.get("telegram_topics_map"))
                    except Exception:
                        pass
        except Exception as e:
            print(f"⚠️ Avertissement : lecture des identifiants Supabase : {e}")

    return creds


# =============================================================================
# 2. MOTEUR GRAPHIQUE LIGHT THEME (1080x1080)
# =============================================================================

def get_font(size: int, bold: bool = False):
    font_paths = []
    if sys.platform.startswith("win"):
        font_dir = Path("C:/Windows/Fonts")
        if bold:
            font_paths = [
                font_dir / "segoeuib.ttf",
                font_dir / "arialbd.ttf",
                font_dir / "calibrib.ttf",
            ]
        else:
            font_paths = [
                font_dir / "segoeui.ttf",
                font_dir / "arial.ttf",
                font_dir / "calibri.ttf",
            ]
    else:
        linux_fonts = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        ]
        font_paths = [Path(p) for p in linux_fonts]

    for p in font_paths:
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = bbox
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)

def draw_pill(draw, x, y, text, font, bg_color, text_color, pad_h=16, pad_v=8, radius=12, border_color=None):
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    w = tw + pad_h * 2
    h = th + pad_v * 2
    draw_rounded_rect(draw, [x, y, x + w, y + h], radius=radius, fill=bg_color, outline=border_color, width=1)
    tx = x + pad_h - bbox[0]
    ty = y + pad_v - bbox[1]
    draw.text((tx, ty), text, font=font, fill=text_color)
    return w, h

def draw_lock_icon(draw, cx, cy, size=24, color=(180, 83, 9)):
    body_w = size * 0.8
    body_h = size * 0.7
    bx0 = cx - body_w / 2
    by0 = cy - body_h / 2 + size * 0.15
    draw.rounded_rectangle([bx0, by0, bx0 + body_w, by0 + body_h], radius=size * 0.18, fill=color)
    shackle_r = size * 0.28
    sx = cx
    sy = by0 - size * 0.05
    draw.arc([sx - shackle_r, sy - shackle_r * 2, sx + shackle_r, sy], start=180, end=0, fill=color, width=max(2, int(size * 0.16)))
    draw.ellipse([cx - size * 0.08, by0 + body_h * 0.35, cx + size * 0.08, by0 + body_h * 0.35 + size * 0.16], fill=(255, 255, 255))

def render_modern_light_banner(content_type: str, data: Dict[str, Any], output_path: str) -> str:
    """
    Génère l'affiche carrée (1080x1080) au design Infographie Bento Grid Pinterest 2026
    annonçant qu'un nouveau défi ou protocole est programmé et disponible dans l'App.
    """
    THEMES_MAP = {
        "cat": ("teal", "DEFI CLINIQUE & CAT LANCE", "CONDUITE A TENIR"),
        "memento": ("indigo", "MEMENTO DE GARDE DISPONIBLE", "GARDE HOSPITALIERE"),
        "drug": ("emerald", "PROTOCOLE THERAPEUTIQUE", "DCI & URGENCES"),
        "lab": ("cyan", "SEUILS CRITIQUES & BILAN", "BIOLOGIE MEDICALE"),
        "summary": ("amber", "FICHE & DEFI QCM CONCOURS", "RESIDANAT & EXTERNAT"),
        "pearl": ("purple", "DEFI PIEGE D'EXAMEN LANCE", "PERLE & QCM REEL"),
    }
    theme_key, badge_prefix, metric_tag = THEMES_MAP.get(content_type, THEMES_MAP["cat"])

    raw_title = data.get("title") or data.get("name") or data.get("dci") or data.get("course_name") or "Nouveau Defi Medical"
    raw_specialty = data.get("specialty") or data.get("module_name") or data.get("category") or "Medecine & Externat"

    title = strip_emojis_for_image(raw_title)
    specialty = strip_emojis_for_image(raw_specialty)

    try:
        from generate_modern_light_banner import build_modern_light_banner
        bento_data = {
            "theme": theme_key,
            "status_pill": "NOUVEAU SUR L'APPLICATION",
            "badge": f"{badge_prefix} • {specialty.upper()}",
            "title": title,
            "subtitle": f"Module {specialty} • Ce defi et sa fiche interactive sont lances et disponibles dans l'App Medsina.",
            "metric_tag": metric_tag,
            "metric_value": "100% APP",
            "metric_label": f"Spécialité : {specialty}",
            "metric_desc": "Accedez au protocole interactif complet et aux QCMs reels associes directement dans l'application.",
            "points": [
                f"Module / Specialite : {specialty}",
                f"Sujet Programme : {title}",
                "Disponibilite : Lance et accessible immediatement dans l'application Medsina",
            ],
            "callout_title": "Disponible Exclusivement dans l'Application Medsina !",
            "callout_sub": "Ouvrez l'application Medsina pour participer au defi et consulter la ressource complete.",
        }
        return build_modern_light_banner(data=bento_data, output_path=output_path, app_version="MEDSINA APP")
    except Exception as e:
        print(f"⚠️ Fallback render_modern_light_banner: {e}")
        raise


# =============================================================================
# 3. GÉNÉRATEUR DE TEXTE D'ANNONCE (ZÉRO SPOILER • DISPONIBLE DANS L'APP)
# =============================================================================

def build_teaser_copy(content_type: str, data: Dict[str, Any]) -> str:
    """
    Rédige une annonce concise informant qu'un nouveau défi / session / ressource
    est lancé ou programmé et disponible dans l'application Medsina (sans dévoiler le contenu).
    """
    title = data.get("title") or data.get("name") or data.get("dci") or data.get("course_name") or "Session Médicale"
    specialty = data.get("specialty") or data.get("module_name") or data.get("category") or "Médecine"

    type_labels = {
        "cat": "🎯 NOUVEAU DÉFI CLINIQUE & CAT LANCÉ SUR MEDSINA ! 🔔",
        "memento": "🌙 NOUVELLE SESSION DE GARDE PROGRAMMÉE SUR MEDSINA ! 🔔",
        "drug": "💊 NOUVEAU DÉFI THÉRAPEUTIQUE & POSOLOGIE DISPONIBLE SUR MEDSINA ! 🔔",
        "lab": "🧪 NOUVEAU DÉFI BIOLOGIQUE & SEUILS CRITIQUES SUR MEDSINA ! 🔔",
        "summary": "📚 NOUVELLE SESSION DE COURS & DÉFI QCM LANCÉS SUR MEDSINA ! 🔔",
        "pearl": "🎯 NOUVEAU DÉFI « PIÈGE D'EXAMEN & QCM » LANCÉ SUR MEDSINA ! 🔔",
    }

    header = type_labels.get(content_type, type_labels["cat"])

    post_text = f"""{header}

Un nouveau défi et sa session interactive sont programmés et disponibles dès maintenant dans l'application Medsina :

📋 FICHE OFFICIELLE :
• 🏥 Module / Spécialité : {specialty}
• 🎯 Sujet programmé : « {title} »
• ✅ Inclus dans l'App : Session interactive, arbre décisionnel et série de QCMs réels issus de la banque officielle.

🔒 Le contenu et les questions ne sont pas dévoilés dans cette publication : tout se passe directement dans l'application !

📲 Ouvrez l'application Medsina pour relever le défi :
👉 Web App directe : {OFFICIAL_WEB_URL}
👉 Application Android (.apk) : {OFFICIAL_APK_URL}
👉 Canal Telegram Officiel : {OFFICIAL_TELEGRAM_URL}

#Medsina #MedevSync #DefiMedsina #MedecineAlgerie #ExternatAlgerie #Residanat2027"""

    return post_text.strip()


# =============================================================================
# 4. DIFFUSEUR PARALLÈLE MULTICANALE
# =============================================================================

def publish_to_facebook_page(page_id: str, token: str, page_name: str, image_path: Optional[str], caption: str, dry_run: bool = False) -> Optional[str]:
    if dry_run:
        print(f'   [DRY-RUN] Facebook {page_name} ({page_id}): simulation réussie.')
        return 'dry_run_post_id'

    if not page_id or not token:
        print(f'   ⚠️ Facebook {page_name} ignoré : page_id ou token manquant.')
        return None

    # Assurer la mention @followers dans le corps du texte
    fb_caption = caption
    if '@followers' not in fb_caption:
        fb_caption = '@followers\n\n' + fb_caption

    pid = None

    if image_path and os.path.exists(image_path):
        try:
            url = f'https://graph.facebook.com/v21.0/{page_id}/photos'
            with open(image_path, 'rb') as f:
                files = {'source': (os.path.basename(image_path), f, 'image/png')}
                data = {'caption': fb_caption, 'access_token': token}
                r = requests.post(url, data=data, files=files, timeout=40)
            if r.status_code == 200:
                res = r.json()
                pid = res.get('post_id') or res.get('id')
                print(f'   ✅ Succès Facebook {page_name} (Photo)! Post ID: {pid}')
            else:
                print(f'   ⚠️ Avertissement photo Facebook {page_name} ({r.status_code}): {r.text[:120]}')
        except Exception as e:
            print(f'   ⚠️ Erreur upload photo Facebook {page_name}: {e}')

    if not pid:
        try:
            url = f'https://graph.facebook.com/v21.0/{page_id}/feed'
            data = {'message': fb_caption, 'link': OFFICIAL_WEB_URL, 'access_token': token}
            r = requests.post(url, data=data, timeout=30)
            if r.status_code == 200:
                pid = r.json().get('id')
                print(f'   ✅ Succès Facebook {page_name} (Feed Text)! Post ID: {pid}')
            else:
                print(f'   ❌ Échec Facebook {page_name} ({r.status_code}): {r.text[:150]}')
        except Exception as e:
            print(f'   ❌ Erreur Facebook feed {page_name}: {e}')

    if pid:
        try:
            comment_url = f'https://graph.facebook.com/v21.0/{pid}/comments'
            c_data = {
                'message': '@followers Retrouvez la fiche complète sur https://medsina.medevsync.com',
                'access_token': token
            }
            requests.post(comment_url, data=c_data, timeout=10)
        except Exception:
            pass

    return pid


def publish_to_telegram(
    token: str,
    channel_id: str,
    image_path: Optional[str],
    caption: str,
    community_group_id: Optional[str] = None,
    topic_id: Optional[int] = None,
    category: Optional[str] = None,
    dry_run: bool = False,
    auto_pin: bool = False
) -> bool:
    """
    Diffuse sur le canal officiel et sur le topic dédié dans le supergroupe MEDSINA-COMMUNITY.
    """
    if dry_run:
        print('   [DRY-RUN] Telegram broadcast simulé avec succès.')
        return True

    try:
        from telegram_publisher import send_telegram_broadcast
        res = send_telegram_broadcast(
            message_text=caption,
            image_path=image_path,
            bot_token=token,
            channel_id=channel_id,
            community_group_id=community_group_id,
            topic_id=topic_id,
            category=category,
            dry_run=dry_run,
            auto_pin=auto_pin,
            broadcast_to_community=True
        )
        return bool(res.get("success"))
    except Exception as e:
        print(f"   ⚠️ Erreur Telegram : {e}")
        return False


def broadcast_content_teaser(
    content_type: str,
    data: Dict[str, Any],
    supabase=None,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Point d'entrée principal appelé par medsina_agent.py :
    1. Génère l'image 1080x1080 Light Theme moderne
    2. Rédige le texte teaser structuré (anti-spoiler)
    3. Diffuse sur Facebook Page Blida, Facebook Page MedevSync et Telegram
    4. Met à jour latest_facebook_published_post dans Supabase
    """
    print(f"\n📢 DIFFUSION DU TEASER CLINIQUE ({content_type.upper()}) EN LIGHT THEME MODERNE")
    print("-" * 65)

    results = {
        "content_type": content_type,
        "title": data.get("title") or data.get("name") or data.get("dci"),
        "banner_path": None,
        "facebook_medsina_post_id": None,
        "facebook_blida_post_id": None,
        "facebook_medevsync_post_id": None,
        "telegram_success": False
    }

    # 1. Generate modern light banner image
    temp_dir = tempfile.gettempdir()
    slug = (data.get("id") or content_type).replace("/", "_").replace(" ", "_")
    banner_path = os.path.join(temp_dir, f"medsina_teaser_{slug}.png")

    try:
        render_modern_light_banner(content_type, data, banner_path)
        results["banner_path"] = banner_path
        print(f"   🎨 Affiche Light Theme générée : {banner_path}")
    except Exception as e:
        print(f"   ⚠️ Erreur génération affiche (fallback sans image) : {e}")
        banner_path = None

    # 2. Build teaser copy
    caption = build_teaser_copy(content_type, data)

    # 3. Resolve credentials
    creds = get_social_credentials()

    # 4a. Publish to Facebook Page Officielle : Medsina
    print("   🚀 Diffusion sur Facebook : Medsina (Page Officielle)...")
    p0_id = publish_to_facebook_page(
        page_id=creds["medsina_page_id"],
        token=creds["medsina_token"],
        page_name="Medsina Officiel",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_medsina_post_id"] = p0_id

    # 4b. Publish to Facebook Page Communauté : Résidanat Blida 2027
    print("   🚀 Diffusion sur Facebook : Résidanat Blida 2027...")
    p1_id = publish_to_facebook_page(
        page_id=creds["blida_page_id"],
        token=creds["blida_token"],
        page_name="Résidanat Blida 2027",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_blida_post_id"] = p1_id

    # 5. Publish to Facebook Page 2 : MedevSync
    print("   🚀 Diffusion sur Facebook : MedevSync...")
    p2_id = publish_to_facebook_page(
        page_id=creds["medevsync_page_id"],
        token=creds["medevsync_token"],
        page_name="MedevSync",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_medevsync_post_id"] = p2_id

    # 5b. Publish to Facebook Page 4 : CAT aux Urgences
    print("   🚀 Diffusion sur Facebook : CAT aux Urgences...")
    p3_id = publish_to_facebook_page(
        page_id=creds["cat_page_id"],
        token=creds["cat_token"],
        page_name="CAT aux Urgences",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_cat_post_id"] = p3_id

    # 6. Publish to Telegram (Official Channel + Dedicated Community Topic)
    print("   🚀 Diffusion sur Telegram : Canal Officiel et Topic Communauté...")
    tg_ok = publish_to_telegram(
        token=creds["telegram_token"],
        channel_id=creds["telegram_channel"],
        community_group_id=creds.get("telegram_community"),
        category=content_type,
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["telegram_success"] = tg_ok

    # 7. Update Supabase admin_system_settings with last post ID
    last_post_id = p0_id or p1_id or p2_id or p3_id
    if last_post_id and not dry_run and last_post_id != "dry_run_post_id":
        try:
            import datetime
            now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
            headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json"}
            requests.patch(
                f"{SUPABASE_URL}/rest/v1/admin_system_settings?setting_key=eq.latest_facebook_published_post",
                headers=headers,
                json={"setting_value": str(last_post_id), "updated_at": now_iso},
                timeout=10
            )
        except Exception:
            pass

    print("-" * 65)
    return results


# =============================================================================
# 5. TEST CLI & DRY-RUN
# =============================================================================

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Medsina Social Teaser Broadcaster")
    parser.add_argument("--type", type=str, default="cat", choices=["cat", "memento", "drug", "lab", "summary", "pearl"])
    parser.add_argument("--dry-run", action="store_true", help="Simuler sans poster")
    args = parser.parse_args()

    sample_data = {
        "id": "cat_test_sample",
        "title": "Prise en Charge du Choc Anaphylactique",
        "specialty": "Allergologie & Urgences",
        "definition": "Urgence vitale absolue caractérisée par une défaillance cardio-circulatoire ou respiratoire aiguë.",
        "red_flags": [
            "Stridor, dyspnée laryngée ou bronchospasme sévère réfractaire",
            "Chute brutale de la pression artérielle (PAS < 90 mmHg) ou collapsus"
        ],
        "steps": [
            {"title": "1. Adrénaline IM Immédiate", "content": "0.5 mg IM (cuisse antérolatérale) sans attendre"},
            {"title": "2. Oxygène & Remplissage", "content": "Oxygène fort débit 15 L/min + Cristalloïdes 20 mL/kg"}
        ]
    }

    res = broadcast_content_teaser(args.type, sample_data, dry_run=args.dry_run)
    print("Résultat du broadcast :", res)
