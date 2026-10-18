#!/usr/bin/env python3
"""
Test generation of full 1080x1080 banner with real mockup
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from PIL import Image, ImageDraw, ImageFont, ImageFilter
from test_mockup_prototype import (
    render_desktop_mockup,
    render_phone_mockup,
    render_duo_mockup,
    get_font,
)

def strip_emojis_for_image(text: str) -> str:
    import re
    return re.sub(r'[^\w\s\d.,!?:;/\-+%°()\'"éèêëàâäôöûüçîïÉÈÊËÀÂÄÔÖÛÜÇÎÏ]', '', text)


def render_banner_with_mockup(data: dict, mockup_type: str = "desktop", output_path: str = "test_banner_out.png"):
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

    # 2. Halos lumineux
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([(-100, -100), (450, 450)], fill=(*t["accent"], 45))
    glow_draw.ellipse([(width - 350, height - 350), (width + 150, height + 150)], fill=(*t["accent"], 40))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    base = Image.alpha_composite(base, glow)
    draw = ImageDraw.Draw(base)

    # 3. Polices
    font_brand = get_font(26, bold=True)
    font_brand_sub = get_font(17, bold=False)
    font_badge = get_font(18, bold=True)
    font_title = get_font(38, bold=True)
    font_subtitle = get_font(22, bold=False)
    font_point = get_font(22, bold=False)
    font_footer = get_font(20, bold=True)
    font_cta = get_font(18, bold=True)

    # 4. En-tête avec logo
    header_x = 65
    logo_path = Path("assets/medsina-icon.png")
    if logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((68, 68), Image.Resampling.LANCZOS)
            base.paste(logo_img, (header_x, 55), logo_img)
            header_x += 80
        except Exception:
            pass

    draw.text((header_x, 58), "MEDEVSYNC", font=font_brand, fill=(255, 255, 255, 255))
    draw.text((header_x, 90), "Medsina • Plateforme Médicale Globale", font=font_brand_sub, fill=(148, 163, 184, 255))

    # Badge Version
    version_label = "Version 1.0.8"
    draw.rounded_rectangle([(width - 215, 65), (width - 65, 108)], radius=10, fill=(30, 41, 59, 200), outline=t["accent"], width=1)
    draw.text((width - 195, 75), version_label, font=font_brand_sub, fill=(255, 255, 255, 230))

    # Separator
    draw.line([(65, 140), (width - 65, 140)], fill=(51, 65, 85, 180), width=1)

    # 5. Badge thématique
    raw_badge = strip_emojis_for_image(data.get("badge", "SÉCURITÉ • VIDAL ALGÉRIE"))
    badge_text = f"  {raw_badge.upper()}  "
    bbox = font_badge.getbbox(badge_text)
    bw = (bbox[2] - bbox[0]) + 20
    bh = 36
    draw.rounded_rectangle([(65, 165), (65 + bw, 165 + bh)], radius=8, fill=t["badge_bg"], outline=t["accent"], width=2)
    draw.text((75, 172), badge_text.strip(), font=font_badge, fill=t["accent_glow"])

    # 6. Titre & Sous-titre
    raw_title = strip_emojis_for_image(data.get("title", "Sécurisez Vos Prescriptions en Garde"))
    draw.text((65, 215), raw_title, font=font_title, fill=(255, 255, 255, 255))

    raw_sub = strip_emojis_for_image(data.get("subtitle", "Vidal Algérien & Analyseur d'Ordonnance Intelligent"))
    draw.text((65, 265), raw_sub, font=font_subtitle, fill=(148, 163, 184, 255))

    # 7. Contenu principal (SPLIT LAYOUT)
    # Left column: Features / Points
    # Right column: Mockup
    content_y = 315

    # Render Mockup
    if mockup_type == "desktop":
        screen_file = data.get("screenshot_desktop", "assets/screenshots/desktop/prescription_audit_pc.png")
        if os.path.exists(screen_file):
            im_screen = Image.open(screen_file)
            mockup = render_desktop_mockup(im_screen, target_width=510)
            base.paste(mockup, (505, content_y - 20), mockup)
    elif mockup_type == "phone":
        screen_file = data.get("screenshot_mobile", "assets/screenshots/mobile/clinical_copilot_mobile.png")
        if os.path.exists(screen_file):
            im_screen = Image.open(screen_file)
            mockup = render_phone_mockup(im_screen, target_width=320)
            base.paste(mockup, (620, content_y - 20), mockup)
    elif mockup_type == "duo":
        desk_file = data.get("screenshot_desktop", "assets/screenshots/desktop/prescription_audit_pc.png")
        mob_file = data.get("screenshot_mobile", "assets/screenshots/mobile/clinical_copilot_mobile.png")
        if os.path.exists(desk_file) and os.path.exists(mob_file):
            im_desk = Image.open(desk_file)
            im_mob = Image.open(mob_file)
            duo = render_duo_mockup(im_desk, im_mob, 540, 560)
            base.paste(duo, (495, content_y - 20), duo)

    # Left Column Points Container (Width ~430)
    card_w = 425
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

    # Draw Points inside Left Card
    py = content_y + 25
    points = data.get("points", [
        "Détection instantanée des interactions sévères",
        "Contrôle automatique du terrain rénal et hépatique",
        "5 425+ Spécialités pharmaceutiques d'Algérie",
        "Calculateur posologique et audit MedsinaPilot"
    ])

    for i, pt in enumerate(points[:4]):
        clean_pt = strip_emojis_for_image(pt)
        # Badge number
        draw.ellipse([(85, py + 4), (105, py + 24)], fill=t["accent"])
        draw.text((92, py + 3), str(i + 1), font=font_brand_sub, fill=(15, 23, 42, 255))

        # Text wrapping within 310px
        words = clean_pt.split()
        lines = []
        cur = []
        for w in words:
            test = " ".join(cur + [w])
            if font_point.getbbox(test)[2] > 310:
                lines.append(" ".join(cur))
                cur = [w]
            else:
                cur.append(w)
        if cur:
            lines.append(" ".join(cur))

        for l in lines[:2]:
            draw.text((118, py), l, font=font_point, fill=(241, 245, 249, 255))
            py += 30
        py += 22

    # Download CTA Banner inside Card
    cta_y = content_y + card_h - 100
    draw.rounded_rectangle([(85, cta_y), (65 + card_w - 20, cta_y + 75)], radius=12, fill=(30, 41, 59, 240), outline=t["accent"], width=1)
    draw.text((100, cta_y + 14), "DISPONIBLE DÈS MAINTENANT", font=font_badge, fill=t["accent_glow"])
    draw.text((100, cta_y + 44), "📱 Android APK  •  💻 Windows PC  •  🌐 Web", font=font_brand_sub, fill=(255, 255, 255, 230))

    # 8. Pied de page
    footer_y = 945
    draw.line([(65, footer_y), (width - 65, footer_y)], fill=(51, 65, 85, 180), width=1)
    draw.text((65, footer_y + 24), "medsina.medevsync.com  •  Portail Officiel MedevSync", font=font_footer, fill=t["accent_glow"])
    draw.text((width - 310, footer_y + 26), "Algérie • Résidanat 2027", font=font_brand_sub, fill=(148, 163, 184, 255))

    base.convert("RGB").save(output_path, "PNG", quality=95)
    print(f"Banner saved to {output_path}")
    return output_path

if __name__ == "__main__":
    data_sample = {
        "badge": "SÉCURITÉ • VIDAL ALGÉRIE",
        "title": "Sécurisez Vos Prescriptions en Garde",
        "subtitle": "Vidal Algérien & Analyseur d'Ordonnance Intelligent",
        "theme": "amber",
        "points": [
            "Détection instantanée des interactions médicamenteuses sévères",
            "Contrôle automatique du terrain rénal, hépatique et grossesse",
            "5 425+ Spécialités MSPRH (Saidal, IPA, PCH) à jour 2026",
            "Audit pharmacologique complet assisté par MedsinaPilot"
        ],
        "screenshot_desktop": "assets/screenshots/desktop/prescription_audit_pc.png",
        "screenshot_mobile": "assets/screenshots/mobile/clinical_copilot_mobile.png"
    }

    render_banner_with_mockup(data_sample, mockup_type="desktop", output_path="test_banner_desktop.png")
    render_banner_with_mockup(data_sample, mockup_type="duo", output_path="test_banner_duo.png")
