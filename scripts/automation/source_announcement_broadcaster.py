#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - AUTOMATED SOURCE ANNOUNCEMENT BROADCASTER
=============================================================================
Publishes multi-channel announcements whenever a new medical resource
(Google Drive, official course, QCM bank, clinical guide, or externat resource)
is discovered or added to Medsina.

Channels:
1. In-App Realtime Notifications & Dedicated "Annonces & Nouveautés" Hub (Supabase WebSocket)
2. Facebook Official Pages (Medsina, Résidanat Blida 2027, MedevSync)
3. Telegram Official Channel (@medsina_officiel) & Community Group (-1004438944860)

Features:
- Generates high-definition branded medical infographics with Pillow.
- Uploads flyers to Supabase Storage 'facebook_assets' for permanent public CDN access.
- Publishes clean, structured, professional posts (NO raw URL dumping).
=============================================================================
"""

import os
import sys
import re
import json
import time
import tempfile
import argparse
import requests
from pathlib import Path
from typing import Dict, Any, Optional, List
from PIL import Image, ImageDraw, ImageFont

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
ASSETS_DIR = REPO_ROOT / "assets"
LOGO_PATH = ASSETS_DIR / "medsina-logo.png"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SERVICE_ROLE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)

# -----------------------------------------------------------------------------
# 1. GRAPHICS ENGINE : GENERATE BRANDED MEDICAL INFOGRAPHIC
# -----------------------------------------------------------------------------
def get_font(size: int, bold: bool = False):
    """Loads system or truetype font safely."""
    font_names = (
        ["segoeuib.ttf", "arialbd.ttf", "calibrib.ttf", "DejaVuSans-Bold.ttf"]
        if bold
        else ["segoeui.ttf", "arial.ttf", "calibri.ttf", "DejaVuSans.ttf"]
    )
    for name in font_names:
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    return ImageFont.load_default()

def strip_emojis(text: str) -> str:
    """Removes non-standard unicode characters that could fail Pillow rendering."""
    if not text:
        return ""
    emoji_pattern = re.compile(
        r"[\U00010000-\U0010ffff\u2600-\u27bf\u2300-\u23ff\u2b50-\u2b55\u3030-\u303d]+",
        flags=re.UNICODE
    )
    return emoji_pattern.sub("", text).strip()

def generate_source_infographic(
    source_title: str,
    source_type: str = "Drive Officiel",
    module: str = "Médecine & Résidanat",
    features: Optional[List[str]] = None,
    output_path: Optional[str] = None
) -> str:
    """
    Renders a 1200x675 modern medical infographic flyer with Medsina branding.
    """
    width, height = 1200, 675
    img = Image.new("RGB", (width, height), color=(15, 23, 42)) # Deep Slate Dark Background
    draw = ImageDraw.Draw(img)

    # 1. Subtle Radial / Gradient glow background
    for r in range(500, 0, -10):
        alpha = int(35 * (1 - r / 500))
        glow_color = (13, 148, 136, alpha) # Teal glow
        draw.ellipse([800 - r, 100 - r, 800 + r, 100 + r], fill=glow_color[:3])

    # 2. Header Bar with Medsina Branding
    # Try loading Medsina logo if present
    if LOGO_PATH.exists():
        try:
            logo = Image.open(LOGO_PATH).convert("RGBA")
            logo.thumbnail((90, 90))
            img.paste(logo, (50, 40), mask=logo)
        except Exception:
            pass

    font_brand = get_font(28, bold=True)
    draw.text((150, 46), "MEDSINA", fill=(255, 255, 255), font=font_brand)
    font_sub = get_font(14, bold=False)
    draw.text((150, 80), "PLATEFORME MÉDICALE OFFICIELLE D'ALGÉRIE", fill=(148, 163, 184), font=font_sub)

    # Top-right Pill : NOUVELLE RESSOURCE AJOUTÉE
    pill_text = f"NOUVEAUTE : {strip_emojis(source_type).upper()}"
    font_pill = get_font(13, bold=True)
    pill_box = [850, 45, 1140, 85]
    draw.rounded_rectangle(pill_box, radius=20, fill=(13, 148, 136))
    draw.text((875, 54), pill_text, fill=(255, 255, 255), font=font_pill)

    # Divider line
    draw.line([(50, 120), (1150, 120)], fill=(51, 65, 85), width=2)

    # 3. Main Hero Card
    card_box = [50, 150, 1150, 560]
    draw.rounded_rectangle(card_box, radius=24, fill=(30, 41, 59), outline=(51, 65, 85), width=2)

    # Category Pill inside Card
    cat_box = [85, 180, 85 + 320, 218]
    draw.rounded_rectangle(cat_box, radius=12, fill=(13, 148, 136, 40), outline=(13, 148, 136), width=1)
    font_cat = get_font(14, bold=True)
    draw.text((105, 190), f"MODULE : {strip_emojis(module).upper()}", fill=(45, 212, 191), font=font_cat)

    # Title
    clean_title = strip_emojis(source_title)
    if len(clean_title) > 60:
        clean_title = clean_title[:57] + "..."
    font_title = get_font(36, bold=True)
    draw.text((85, 235), clean_title, fill=(255, 255, 255), font=font_title)

    # Subtitle / description
    font_desc = get_font(17, bold=False)
    draw.text(
        (85, 290),
        "Ressource clinique & pédagogique indexée dans la bibliothèque Medsina.",
        fill=(203, 213, 225),
        font=font_desc
    )

    # 4. Features grid
    items = features or [
        "Cours complets & Résumés officiels du Résidanat",
        "Banques de QCMs, annales corrigées & cas cliniques",
        "Intégration directe & consultation 100% Hors-Ligne",
        "Téléchargement et synchronisation multi-appareils"
    ]

    font_bullet = get_font(16, bold=True)
    font_check = get_font(18, bold=True)

    y_pos = 345
    for i, item in enumerate(items[:4]):
        col_x = 85 if i % 2 == 0 else 630
        row_y = y_pos if i < 2 else y_pos + 65

        # Small icon background
        icon_box = [col_x, row_y, col_x + 36, row_y + 36]
        draw.rounded_rectangle(icon_box, radius=8, fill=(13, 148, 136))
        draw.text((col_x + 10, row_y + 6), ">", fill=(255, 255, 255), font=font_check)

        clean_item = strip_emojis(item)
        draw.text((col_x + 50, row_y + 8), clean_item, fill=(241, 245, 249), font=font_bullet)

    # Action Banner at bottom of Card
    cta_box = [85, 480, 1115, 535]
    draw.rounded_rectangle(cta_box, radius=14, fill=(15, 23, 42), outline=(13, 148, 136), width=1)
    font_cta = get_font(16, bold=True)
    draw.text(
        (110, 496),
        "DISPONIBLE DES MAINTENANT SUR MEDSINA WEB & APPLICATION MOBILE / PC",
        fill=(45, 212, 191),
        font=font_cta
    )

    # 5. Footer Bar
    font_footer = get_font(13, bold=False)
    draw.text(
        (50, 600),
        "Medsina  Residanat Blida 2027  Excellence academique medicale",
        fill=(100, 116, 139),
        font=font_footer
    )
    draw.text(
        (920, 600),
        "https://medsina.medevsync.com",
        fill=(13, 148, 136),
        font=font_footer
    )

    if not output_path:
        tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
        output_path = tmp.name
        tmp.close()

    img.save(output_path, "PNG", quality=95)
    print(f"  [Graphics] Infographie generee avec succes : {output_path}")
    return output_path

# -----------------------------------------------------------------------------
# 2. STORAGE ENGINE : UPLOAD BANNER TO SUPABASE
# -----------------------------------------------------------------------------
def upload_banner_to_supabase(image_path: str, filename_prefix: str = "source_banner") -> Optional[str]:
    """
    Uploads an image file to Supabase Storage 'facebook_assets' bucket and returns its public URL.
    """
    if not os.path.exists(image_path):
        return None

    filename = f"{filename_prefix}_{int(time.time())}.png"
    url = f"{SUPABASE_URL}/storage/v1/object/facebook_assets/{filename}"
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "image/png",
        "x-upsert": "true"
    }

    try:
        with open(image_path, "rb") as f:
            data = f.read()
        res = requests.post(url, headers=headers, data=data, timeout=20)
        if res.status_code in (200, 201):
            public_url = f"{SUPABASE_URL}/storage/v1/object/public/facebook_assets/{filename}"
            print(f"  ☁️ [Storage] Infographie mise en ligne avec succès sur Supabase : {public_url}")
            return public_url
        else:
            print(f"  ⚠️ [Storage] Échec upload Supabase ({res.status_code}): {res.text}")
    except Exception as e:
        print(f"  ❌ [Storage] Erreur upload : {e}")

    return None

# -----------------------------------------------------------------------------
# 3. MASTER BROADCASTER (IN-APP + FACEBOOK + TELEGRAM)
# -----------------------------------------------------------------------------
def broadcast_new_source(
    title: str,
    source_type: str = "Drive Officiel",
    module: str = "Médecine & Résidanat",
    url: Optional[str] = None,
    description: Optional[str] = None,
    features: Optional[List[str]] = None,
    custom_image_path: Optional[str] = None,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Broadcasts announcement of a new medical source to:
    1. In-App Notifications & Annonces Hub
    2. Facebook Pages (3 pages)
    3. Telegram Official Channel & Community
    """
    print("\n" + "=" * 65)
    print(f"📢 DIFFUSION OFFICIELLE NOUVELLE SOURCE : {title}")
    print("=" * 65)

    results = {
        "image_url": None,
        "in_app": False,
        "facebook": False,
        "telegram": False
    }

    # 1. Generate Infographic Flyer if not provided
    img_path = custom_image_path
    if not img_path or not os.path.exists(img_path):
        img_path = generate_source_infographic(
            source_title=title,
            source_type=source_type,
            module=module,
            features=features
        )

    # 2. Upload to Supabase Storage for permanent CDN image URL
    public_img_url = upload_banner_to_supabase(img_path)
    results["image_url"] = public_img_url

    # 3. Clean professional message for In-App (NO UGLY RAW URL DUMP)
    in_app_summary = description or (
        f"Une nouvelle ressource clinique et académique majeure vient d'être indexée dans Medsina !\n\n"
        f"• Type de ressource : {source_type}\n"
        f"• Module & Spécialité : {module}\n"
        f"• Contenu : Cours détaillés, séries de QCMs, fiches résumées & cas cliniques.\n\n"
        f"Disponible directement depuis votre espace de révision et dans l'application 100% Hors-Ligne."
    )

    action_label = "Consulter le Drive 📁" if "drive" in (url or "").lower() else "Accéder à la Source 🚀"

    # 4. Post to In-App Realtime (Supabase medical_notifications)
    notif_id = f"source_{int(time.time() * 1000)}"
    notif_payload = {
        "id": notif_id,
        "title": f"📁 Nouvelle Source : {title}",
        "message": in_app_summary,
        "type": "announcement",
        "target_role": "all",
        "metadata": {
            "badge": f"{source_type.upper()} 📁",
            "image_url": public_img_url,
            "action_url": url,
            "action_label": action_label,
            "is_announcement": True,
            "source_type": source_type,
            "source_title": title,
            "module": module,
            "created_via": "source_announcement_broadcaster"
        },
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    try:
        r = requests.post(f"{SUPABASE_URL}/rest/v1/medical_notifications", headers=headers, json=notif_payload, timeout=12)
        if r.status_code in (200, 201):
            print(f"  📲 [In-App] Diffusé en temps réel dans l'espace Annonces & Nouveautés (ID: {notif_id})")
            results["in_app"] = True
        else:
            print(f"  ⚠️ [In-App] Supabase error ({r.status_code}): {r.text}")
    except Exception as e:
        print(f"  ❌ [In-App] Erreur broadcast : {e}")

    # 5. Post to Telegram Official Channel
    try:
        from telegram_publisher import send_telegram_broadcast
        tg_text = (
            f"<b>📁 NOUVELLE SOURCE AJOUTÉE : {title}</b>\n\n"
            f"📚 <b>Module :</b> {module}\n"
            f"🔖 <b>Type :</b> {source_type}\n\n"
            f"{in_app_summary}\n\n"
            f"🌐 <i>Retrouvez cette source dès maintenant dans l'application Medsina.</i>"
        )
        tg_res = send_telegram_broadcast(
            tg_text,
            image_path=img_path,
            category="drive",
            app_version="1.0.29"
        )
        if tg_res.get("success") or tg_res.get("ok"):
            print("  ✈️ [Telegram] Diffusé sur le canal officiel Telegram et forum communautaire !")
            results["telegram"] = True
        else:
            print(f"  ℹ️ [Telegram] Réponse : {tg_res}")
    except Exception as e:
        print(f"  ⚠️ [Telegram] Erreur diffusion : {e}")

    # 6. Post to Facebook Pages
    try:
        from facebook_publisher import get_all_facebook_pages, publish_to_page_feed
        fb_caption = (
            f"📢 NOUVELLE RESSOURCE OFFICIELLE AJOUTÉE !\n\n"
            f"📁 {title}\n"
            f"🩺 Module : {module}\n"
            f"🏷️ Type : {source_type}\n\n"
            f"{in_app_summary}\n\n"
            f"📲 Disponible en illimité et 100% Hors-Ligne dans l'application Medsina :\n"
            f"👉 https://medsina.medevsync.com\n\n"
            f"#Medsina #RésidanatBlida2027 #MédecineAlgérie #ConcoursRésidanat"
        )
        pages = get_all_facebook_pages()
        for page in pages:
            if not page.get("token"):
                continue
            res = publish_to_page_feed(
                page_id=page["page_id"],
                token=page["token"],
                message=fb_caption,
                link=url or "https://medsina.medevsync.com"
            )
            if res.get("id"):
                print(f"  📢 [Facebook] Publié avec succès sur {page['name']} (Post ID: {res['id']})")
                results["facebook"] = True
    except Exception as e:
        print(f"  ⚠️ [Facebook] Erreur diffusion : {e}")

    print("\n📊 Bilan de la diffusion :")
    print(f"  - Espace In-App « Annonces & Nouveautés » : {'✅ SUCCÈS' if results['in_app'] else '❌ ÉCHEC'}")
    print(f"  - Telegram Officiel : {'✅ SUCCÈS' if results['telegram'] else 'ℹ️ VÉRIFIER TOKEN'}")
    print(f"  - Facebook Multi-Pages : {'✅ SUCCÈS' if results['facebook'] else 'ℹ️ VÉRIFIER TOKEN'}")
    print("=" * 65 + "\n")

    return results

def main():
    parser = argparse.ArgumentParser(description="Broadcast an announcement for a new source across Medsina, FB & Telegram.")
    parser.add_argument("--title", type=str, required=True, help="Title of the source (e.g. 'Drive Dr Chakib Goumari')")
    parser.add_argument("--type", type=str, default="Drive Officiel", help="Source type (Drive Officiel, Banque QCM, Cours, Externat)")
    parser.add_argument("--module", type=str, default="Médecine & Résidanat", help="Module or domain")
    parser.add_argument("--url", type=str, default=None, help="Direct URL of the source (Google Drive, Telegram, etc.)")
    parser.add_argument("--desc", type=str, default=None, help="Custom description")
    parser.add_argument("--image", type=str, default=None, help="Path to custom infographic flyer (optional)")
    parser.add_argument("--dry-run", action="store_true", help="Test run without posting")
    args = parser.parse_args()

    broadcast_new_source(
        title=args.title,
        source_type=args.type,
        module=args.module,
        url=args.url,
        description=args.desc,
        custom_image_path=args.image,
        dry_run=args.dry_run
    )

if __name__ == "__main__":
    main()

