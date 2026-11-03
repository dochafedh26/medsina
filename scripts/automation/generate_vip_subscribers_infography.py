#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — GÉNÉRATEUR INFOGRAPHIE 1 : LISTE DES ABONNÉS PROMO VIP NOVEMBRE
=============================================================================
Génère une affiche haute résolution (1200 x 1600) célébrant les 40 confrères
ayant activé leur Pass All-Access VIP 30 Jours Offert, avec répartition
par facultés (Blida, Alger, Oran, Constantine, Annaba, Sétif, Tlemcen...).
=============================================================================
"""

import os
import sys
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parents[1] if len(SCRIPT_DIR.parents) > 1 else SCRIPT_DIR
ASSETS_DIR = Path(r"medsina/assets")
OUTPUT_DIR = ASSETS_DIR / "facebook"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

LOGO_PATH = ASSETS_DIR / "medsina-logo.png"

# Palette Médicale Prestige
COLOR_BG_TOP = (248, 250, 253)
COLOR_BG_BOT = (235, 244, 255)
COLOR_PRIMARY_NAVY = (11, 37, 69)      # #0B2545
COLOR_ROYAL_BLUE = (10, 93, 194)       # #0A5DC2
COLOR_CYAN_ACCENT = (14, 165, 233)     # #0EA5E9
COLOR_EMERALD = (16, 185, 129)         # #10B981
COLOR_EMERALD_BG = (236, 253, 245)     # #ECFDF5
COLOR_GOLD = (217, 119, 6)             # #D97706
COLOR_GOLD_LIGHT = (254, 243, 199)     # #FEF3C7
COLOR_WHITE = (255, 255, 255)
COLOR_TEXT_DARK = (15, 23, 42)         # #0F172A
COLOR_TEXT_MUTED = (71, 85, 105)       # #475569
COLOR_CARD_BORDER = (219, 234, 254)    # #DBEAFE


def get_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    font_name = "segoeuib.ttf" if bold else "segoeui.ttf"
    alt_name = "arialbd.ttf" if bold else "arial.ttf"
    for name in [font_name, alt_name]:
        p = os.path.join(r"C:\Windows\Fonts", name)
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def create_gradient_bg(width: int, height: int, top_color, bot_color) -> Image.Image:
    base = Image.new("RGBA", (width, height), top_color)
    draw = ImageDraw.Draw(base)
    for y in range(height):
        ratio = y / float(height)
        r = int(top_color[0] * (1 - ratio) + bot_color[0] * ratio)
        g = int(top_color[1] * (1 - ratio) + bot_color[1] * ratio)
        b = int(top_color[2] * (1 - ratio) + bot_color[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    return base


def draw_rounded_rect(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_bullet_dot(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, color):
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)


def draw_medical_cross(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, color):
    w = max(4, size // 3)
    draw.rounded_rectangle((cx - w // 2, cy - size // 2, cx + w // 2, cy + size // 2), radius=2, fill=color)
    draw.rounded_rectangle((cx - size // 2, cy - w // 2, cx + size // 2, cy + w // 2), radius=2, fill=color)


def generate_vip_subscribers_infography(subscribers_list: list, output_path: str):
    W, H = 1200, 1600
    img = create_gradient_bg(W, H, COLOR_BG_TOP, COLOR_BG_BOT)
    draw = ImageDraw.Draw(img)

    # 1. Logo Medsina
    if LOGO_PATH.exists():
        logo = Image.open(LOGO_PATH).convert("RGBA")
        logo_w = 260
        logo_h = int(logo.height * (logo_w / logo.width))
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        img.paste(logo, (50, 40), logo)

    # 2. Pillule Promo Novembre
    pill_x1, pill_y1, pill_x2, pill_y2 = 720, 42, 1150, 92
    draw_rounded_rect(draw, (pill_x1, pill_y1, pill_x2, pill_y2), radius=16, fill=COLOR_ROYAL_BLUE)
    draw_medical_cross(draw, pill_x1 + 26, (pill_y1 + pill_y2) // 2, 16, COLOR_WHITE)
    draw.text((pill_x1 + 44, 55), "CAMPAGNE PROMO NOVEMBRE", fill=COLOR_WHITE, font=get_font(17, bold=True))

    # 3. Badge doré
    draw_rounded_rect(draw, (50, 130, 460, 172), radius=14, fill=COLOR_GOLD)
    draw_bullet_dot(draw, 72, 151, 5, COLOR_WHITE)
    draw.text((88, 140), "ALL-ACCESS VIP • 30 JOURS DÉBLOQUÉS", fill=COLOR_WHITE, font=get_font(16, bold=True))

    # 4. Grands Titres
    draw.text((50, 190), "BIENVENUE À NOS NOUVEAUX", fill=COLOR_PRIMARY_NAVY, font=get_font(48, bold=True))
    draw.text((50, 252), "ABONNÉS VIP ALL-ACCESS !", fill=COLOR_ROYAL_BLUE, font=get_font(46, bold=True))

    draw.text(
        (50, 318),
        f"Félicitations aux {len(subscribers_list)} confrères et candidats au Résidanat ayant activé leur accès 100% offert ce mois-ci :",
        fill=COLOR_TEXT_MUTED,
        font=get_font(18, bold=False)
    )

    # 5. Bandeau Statistiques & Facultés participantes
    stat_box_y = 365
    draw_rounded_rect(draw, (50, stat_box_y, W - 50, stat_box_y + 85), radius=16, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)

    stats = [
        ("40 BÉNÉFICIAIRES", "Comptes VIP actifs", COLOR_ROYAL_BLUE),
        ("8 FACULTÉS", "Blida, Alger, Oran, Cste...", COLOR_EMERALD),
        ("47 MODULES", "15 000+ QCMs & Livrets", COLOR_GOLD)
    ]
    sx = 50
    step_w = (W - 100) // 3
    for title, sub, col in stats:
        draw_bullet_dot(draw, sx + 25, stat_box_y + 42, 6, col)
        draw.text((sx + 42, stat_box_y + 18), title, fill=COLOR_PRIMARY_NAVY, font=get_font(19, bold=True))
        draw.text((sx + 42, stat_box_y + 48), sub, fill=COLOR_TEXT_MUTED, font=get_font(14, bold=False))
        sx += step_w

    # 6. Grille des 40 Noms / Abonnés (en 3 colonnes compactes et prestigieuses)
    grid_y = 475
    draw_rounded_rect(draw, (50, grid_y, W - 50, 1260), radius=18, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
    
    # En-tête de tableau
    draw_rounded_rect(draw, (50, grid_y, W - 50, grid_y + 48), radius=16, fill=COLOR_PRIMARY_NAVY)
    draw.text((80, grid_y + 14), "PROMOTION DES NOUVEAUX RÉSIDENTS & EXTERNES ÉLITE 2026-2027", fill=COLOR_WHITE, font=get_font(16, bold=True))

    col_w = (W - 140) // 3
    row_h = 36
    start_content_y = grid_y + 60

    # Clean and format names
    def format_subscriber_name(u):
        raw = u["name"].strip()
        # Clean up lowercase prefix
        parts = [p.capitalize() for p in raw.split()]
        formatted = " ".join(parts)
        if not formatted.lower().startswith("dr") and not formatted.lower().startswith("docteur"):
            formatted = f"Dr. {formatted}"
        fac = u.get("faculty", "")
        short_fac = ""
        if "Blida" in fac:
            short_fac = "Blida"
        elif "Alger" in fac:
            short_fac = "Alger"
        elif "Oran" in fac:
            short_fac = "Oran"
        elif "Constantine" in fac:
            short_fac = "Cste"
        elif "Annaba" in fac:
            short_fac = "Annaba"
        elif "Sétif" in fac:
            short_fac = "Sétif"
        elif "Tlemcen" in fac:
            short_fac = "Tlemcen"
        return formatted[:20], short_fac

    # Display up to 39-40 users
    for idx, user in enumerate(subscribers_list[:39]):
        col_idx = idx % 3
        row_idx = idx // 3
        x = 70 + col_idx * (col_w + 15)
        y = start_content_y + row_idx * row_h

        name_str, fac_str = format_subscriber_name(user)
        # Alternate subtle background per row
        if row_idx % 2 == 1:
            draw_rounded_rect(draw, (x - 8, y - 4, x + col_w - 5, y + row_h - 8), radius=6, fill=(248, 250, 252))

        # Macaron numéro
        draw_bullet_dot(draw, x + 6, y + 10, 4, COLOR_ROYAL_BLUE if (row_idx % 2 == 0) else COLOR_EMERALD)
        draw.text((x + 18, y + 2), f"{idx+1}. {name_str}", fill=COLOR_TEXT_DARK, font=get_font(14, bold=True))
        if fac_str:
            f_box_x = x + col_w - 75
            draw_rounded_rect(draw, (f_box_x, y + 1, f_box_x + 65, y + 22), radius=4, fill=COLOR_GOLD_LIGHT)
            draw.text((f_box_x + 8, y + 4), fac_str, fill=COLOR_GOLD, font=get_font(11, bold=True))

    # 7. Conteneur Bas : Vos Avantages VIP
    box_y = 1285
    box_h = 240
    draw_rounded_rect(draw, (50, box_y, W - 50, box_y + box_h), radius=22, fill=COLOR_PRIMARY_NAVY, outline=COLOR_GOLD, width=3)

    draw_rounded_rect(draw, (85, box_y + 20, 410, box_y + 60), radius=10, fill=COLOR_GOLD)
    draw_bullet_dot(draw, 105, box_y + 40, 5, COLOR_PRIMARY_NAVY)
    draw.text((120, box_y + 28), "PASS INTÉGRALEMENT DÉBLOQUÉ", fill=COLOR_PRIMARY_NAVY, font=get_font(15, bold=True))

    draw.text((85, box_y + 75), "Accès Illimité Actif pendant 30 Jours :", fill=COLOR_WHITE, font=get_font(24, bold=True))

    perks = [
        ("• 47 Modules Médicaux Débloqués", "• 15 000+ QCMs avec Annales & Corrigés Types"),
        ("• Nouveaux Livrets Révision Résidanat 2027", "• Simulateur EMD & Concours Blancs au Barème de Blida"),
        ("• Assistant IA Médical MedsinaPilot 24/7", "• Fiches CAT Urgences, Mémentos de Garde & Codex DCI")
    ]
    py = box_y + 115
    for p1, p2 in perks:
        draw.text((85, py), p1, fill=COLOR_CYAN_ACCENT, font=get_font(16, bold=True))
        draw.text((580, py), p2, fill=COLOR_EMERALD, font=get_font(16, bold=True))
        py += 36

    # 8. Pied de page
    footer_text = "Medsina • Plateforme Médicale Universitaire & Concours Résidanat  •  medsina.medevsync.com"
    f_font = get_font(15, bold=True)
    f_bbox = f_font.getbbox(footer_text)
    f_w = f_bbox[2] - f_bbox[0]
    draw.text(((W - f_w) // 2, 1545), footer_text, fill=COLOR_TEXT_MUTED, font=f_font)

    img.save(output_path, "PNG", quality=95)
    print(f"✅ Infographie VIP Subscribers générée : {output_path}")


if __name__ == "__main__":
    out = str(OUTPUT_DIR / "medsina_promo_vip_subscribers.png")
    # Load from vip_users.json if available
    v_path = Path("vip_users.json")
    if v_path.exists():
        with open(v_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = []
    generate_vip_subscribers_infography(data, out)
