#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - GÉNÉRATEUR INFOGRAPHIE "RECRUTEMENT DÉLÉGUÉS & ÉMISSAIRES BLIDA"
=============================================================================
Génère :
1. medsina_emissaires_blida_square.png (1200x1200 - Post Facebook / Instagram)
2. medsina_emissaires_blida_flyer.png (1200x1600 - Affiche Verticale HD)
=============================================================================
"""

import os
import sys
import json
import qrcode
from PIL import Image, ImageDraw, ImageFont

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "../../"))
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")
OUTPUT_DIR = os.path.join(ASSETS_DIR, "facebook")
os.makedirs(OUTPUT_DIR, exist_ok=True)

LOGO_PATH = os.path.join(ASSETS_DIR, "medsina-logo.png")
ICON_PATH = os.path.join(ASSETS_DIR, "medsina-icon.png")

# Palette Light Moderne Médicale
COLOR_BG_TOP = (248, 250, 253)        # #F8FAFD
COLOR_BG_BOT = (235, 243, 252)        # #EBF3FC
COLOR_PRIMARY_NAVY = (11, 37, 69)     # #0B2545
COLOR_ROYAL_BLUE = (10, 93, 194)      # #0A5DC2
COLOR_CYAN_ACCENT = (14, 165, 233)    # #0EA5E9
COLOR_EMERALD = (16, 185, 129)        # #10B981
COLOR_EMERALD_BG = (236, 253, 245)    # #ECFDF5
COLOR_GOLD = (245, 158, 11)           # #F59E0B
COLOR_GOLD_LIGHT = (254, 243, 199)    # #FEF3C7
COLOR_RED_ACCENT = (239, 68, 68)      # #EF4444
COLOR_WHITE = (255, 255, 255)
COLOR_TEXT_DARK = (15, 23, 42)        # #0F172A
COLOR_TEXT_MUTED = (71, 85, 105)      # #475569
COLOR_CARD_BORDER = (219, 234, 254)   # #DBEAFE


def get_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    font_name = "segoeuib.ttf" if bold else "segoeui.ttf"
    alt_name = "arialbd.ttf" if bold else "arial.ttf"
    path = os.path.join(r"C:\Windows\Fonts", font_name)
    if os.path.exists(path):
        return ImageFont.truetype(path, size)
    alt_path = os.path.join(r"C:\Windows\Fonts", alt_name)
    if os.path.exists(alt_path):
        return ImageFont.truetype(alt_path, size)
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


def make_qr_code(url: str, size: int) -> Image.Image:
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=1,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img_qr = qr.make_image(fill_color="#0B2545", back_color="white").convert("RGBA")
    return img_qr.resize((size, size), Image.Resampling.LANCZOS)


# -----------------------------------------------------------------------------
# 1. POST FORMAT CARRÉ (1200 x 1200) - FACEBOOK FEED & INSTAGRAM
# -----------------------------------------------------------------------------
def generate_square_emissaires_post(output_path: str):
    W, H = 1200, 1200
    img = create_gradient_bg(W, H, COLOR_BG_TOP, (228, 240, 254))
    draw = ImageDraw.Draw(img)

    # Logo
    if os.path.exists(LOGO_PATH):
        logo = Image.open(LOGO_PATH).convert("RGBA")
        logo_w = 260
        logo_h = int(logo.height * (logo_w / logo.width))
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        img.paste(logo, (50, 38), logo)

    # Top Location Pill (Blida)
    draw_rounded_rect(draw, (650, 42, 1150, 92), radius=16, fill=COLOR_ROYAL_BLUE)
    draw.text((680, 55), "🏛️ FACULTÉ DE MÉDECINE DE BLIDA", fill=COLOR_WHITE, font=get_font(18, bold=True))

    # Header Titles
    draw_rounded_rect(draw, (50, 120, 520, 158), radius=14, fill=COLOR_GOLD)
    draw.text((75, 128), "📢 RECRUTEMENT AMBASSADEURS 2026-2027", fill=COLOR_PRIMARY_NAVY, font=get_font(16, bold=True))

    draw.text((50, 175), "DÉLÉGUÉS & ÉMISSAIRES", fill=COLOR_PRIMARY_NAVY, font=get_font(48, bold=True))
    draw.text((50, 238), "DE PROMOTION RECHERCHÉS !", fill=COLOR_ROYAL_BLUE, font=get_font(46, bold=True))

    draw.text((50, 305), "Ouvert aux délégués officiels et à tout étudiant motivé souhaitant représenter son amphi (1ère à 6ème Année & Internes).", fill=COLOR_TEXT_MUTED, font=get_font(18, bold=False))

    # Targeted promotions grid (3 pills)
    years_data = [
        "1ère & 2ème Année (Fondamentales & Physio)",
        "3ème & 4ème Année (Sémiologie & Pathologie I)",
        "5ème, 6ème Année & Internat (Patho II, Urgences & Concours)"
    ]
    px = 50
    for y_text in years_data:
        draw_rounded_rect(draw, (px, 355, px + 350, 400), radius=12, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
        draw.text((px + 15, 368), y_text, fill=COLOR_PRIMARY_NAVY, font=get_font(13, bold=True))
        px += 370

    # 3 Big Value Cards
    cards = [
        ("🎁 1 AN ALL-ACCESS VIP OFFERT POUR VOUS", "Accès complet 12 mois débloqué à toute la plateforme Medsina (47 modules, 15 000+ QCMs, annales Blida)."),
        ("👥 30 JOURS ALL-ACCESS VIP POUR TOUTE VOTRE PROMO", "Chaque collègue de votre amphi ou groupe de stage bénéficie de l'accès intégral offert ce mois-ci."),
        ("🤝 MISSIONS LÉGÈRES & CONFRATERNELLES", "Relayer 2x/semaine la Question Piège du Jour et faire remonter les besoins spécifiques de votre amphi.")
    ]

    cy = 425
    for title, desc in cards:
        draw_rounded_rect(draw, (50, cy, W - 50, cy + 105), radius=16, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
        # Left blue strip
        draw_rounded_rect(draw, (50, cy, 65, cy + 105), radius=8, fill=COLOR_ROYAL_BLUE)
        draw.text((85, cy + 16), title, fill=COLOR_PRIMARY_NAVY, font=get_font(21, bold=True))
        draw.text((85, cy + 52), desc, fill=COLOR_TEXT_MUTED, font=get_font(16, bold=False))
        cy += 122

    # Bottom Call To Action Container with QR Code
    box_y = 810
    draw_rounded_rect(draw, (50, box_y, W - 50, box_y + 260), radius=22, fill=COLOR_PRIMARY_NAVY, outline=COLOR_GOLD, width=3)

    # QR Code
    qr_img = make_qr_code("https://medsina.medevsync.com", 170)
    img.paste(qr_img, (W - 250, box_y + 45), qr_img)
    draw.text((W - 245, box_y + 225), "Scannez pour tester", fill=COLOR_GOLD, font=get_font(13, bold=True))

    # Text inside CTA container
    draw_rounded_rect(draw, (85, box_y + 25, 450, box_y + 65), radius=10, fill=COLOR_GOLD)
    draw.text((105, box_y + 33), "⚡ PLACES LIMITÉES PAR PROMOTION", fill=COLOR_PRIMARY_NAVY, font=get_font(16, bold=True))

    draw.text((85, box_y + 80), "Postulez directement en message privé !", fill=COLOR_WHITE, font=get_font(28, bold=True))
    draw.text((85, box_y + 125), "Envoyez simplement votre Année d'étude et votre motivation à :", fill=(226, 232, 240), font=get_font(18, bold=False))

    draw.text((85, box_y + 160), "✈️ Telegram privé : @chikhtouamidoc", fill=COLOR_CYAN_ACCENT, font=get_font(22, bold=True))
    draw.text((85, box_y + 195), "🌐 Plateforme Web : medsina.medevsync.com", fill=COLOR_GOLD, font=get_font(20, bold=True))

    # Reassurance footer
    draw.text((120, 1115), "🛡️ Partenariat d'entraide médicale 100% gratuit • CHU Blida & Faculté Frantz Fanon • Aucun frais", fill=COLOR_TEXT_MUTED, font=get_font(16, bold=True))

    img.save(output_path, "PNG", quality=95)
    print(f"✅ Infographie carrée Émissaires Blida générée : {output_path}")


# -----------------------------------------------------------------------------
# 2. AFFICHE VERTICALE FLYER (1200 x 1600)
# -----------------------------------------------------------------------------
def generate_flyer_emissaires_post(output_path: str):
    W, H = 1200, 1600
    img = create_gradient_bg(W, H, COLOR_BG_TOP, (230, 242, 254))
    draw = ImageDraw.Draw(img)

    # Logo
    if os.path.exists(LOGO_PATH):
        logo = Image.open(LOGO_PATH).convert("RGBA")
        logo_w = 260
        logo_h = int(logo.height * (logo_w / logo.width))
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        img.paste(logo, (50, 40), logo)

    # Top slogan
    draw.text((820, 48), "Ensemble pour la réussite", fill=COLOR_PRIMARY_NAVY, font=get_font(21, bold=True))
    draw.text((820, 75), "du Concours à Blida ! ✨", fill=COLOR_ROYAL_BLUE, font=get_font(23, bold=True))

    # Top Location Pill
    draw_rounded_rect(draw, (330, 130, 870, 172), radius=16, fill=COLOR_GOLD)
    draw.text((355, 140), "🏛️ FACULTÉ DE MÉDECINE DE BLIDA • CHU FRANTZ FANON", fill=COLOR_PRIMARY_NAVY, font=get_font(17, bold=True))

    # Giant Headline
    draw.text((160, 195), "RECRUTEMENT ÉMISSAIRES", fill=COLOR_PRIMARY_NAVY, font=get_font(56, bold=True))
    draw.text((220, 265), "& DÉLÉGUÉS DE PROMO", fill=COLOR_ROYAL_BLUE, font=get_font(52, bold=True))

    # Tagline
    draw_rounded_rect(draw, (310, 345, 890, 390), radius=18, fill=COLOR_ROYAL_BLUE)
    draw.text((340, 355), "Devenez l'Ambassadeur Medsina de votre Amphi !", fill=COLOR_WHITE, font=get_font(20, bold=True))

    draw.text((180, 415), "Programme officiel de soutien universitaire aux étudiants de médecine et futurs résidents.", fill=COLOR_TEXT_MUTED, font=get_font(18, bold=False))

    # 4 Feature Cards (Avantages pour l'Émissaire)
    perks = [
        ("🎁 1 AN ALL-ACCESS VIP OFFERT", "Accès complet illimité offert à toute l'application (47 modules, 15 000+ QCMs, annales Blida)."),
        ("👥 30 JOURS GRATUITS POUR VOTRE PROMO", "Chaque collègue de votre amphi ou stage bénéficie de l'accès All-Access VIP offert en Novembre."),
        ("📚 CORRIGÉS OFFICIELS & PIÈGES DE BLIDA", "Recevez en avant-première les fiches réflexes, CAT d'urgence et annales triées par tombabilité 🔥."),
        ("🏆 STATUT PRIVILÉGIÉ D'AMBASSADEUR", "Lien direct avec le Dr Chikh Touami et l'équipe médicale pour co-construire les outils de révision.")
    ]

    py = 470
    for title, desc in perks:
        draw_rounded_rect(draw, (60, py, W - 60, py + 95), radius=16, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
        draw_rounded_rect(draw, (60, py, 75, py + 95), radius=8, fill=COLOR_EMERALD)
        draw.text((100, py + 14), title, fill=COLOR_PRIMARY_NAVY, font=get_font(21, bold=True))
        draw.text((100, py + 48), desc, fill=COLOR_TEXT_MUTED, font=get_font(16, bold=False))
        py += 112

    # Checklist "Vos 3 Missions Simples"
    draw_rounded_rect(draw, (60, py + 15, W - 60, py + 230), radius=18, fill=COLOR_EMERALD_BG, outline=COLOR_EMERALD, width=2)
    draw.text((90, py + 32), "🎯 VOS MISSIONS EN TANT QU'ÉMISSAIRE :", fill=COLOR_PRIMARY_NAVY, font=get_font(22, bold=True))

    missions = [
        "1. Relayer 2 à 3 fois par semaine la « Question Piège du Jour » dans le groupe de votre promo.",
        "2. Faire remonter les remarques et annales spécifiques pour optimiser le simulateur d'EMD.",
        "3. Aider vos collègues à tester les concours blancs chronométrés au barème officiel de Blida."
    ]
    my = py + 75
    for m in missions:
        draw.text((95, my), m, fill=COLOR_PRIMARY_NAVY, font=get_font(17, bold=False))
        my += 42

    # Bottom Contact & QR Box
    c_box_y = 1190
    draw_rounded_rect(draw, (60, c_box_y, W - 60, c_box_y + 280), radius=22, fill=COLOR_PRIMARY_NAVY, outline=COLOR_GOLD, width=3)

    qr_img = make_qr_code("https://medsina.medevsync.com", 180)
    img.paste(qr_img, (W - 270, c_box_y + 50), qr_img)
    draw.text((W - 265, c_box_y + 240), "Scannez pour tester", fill=COLOR_GOLD, font=get_font(13, bold=True))

    draw_rounded_rect(draw, (95, c_box_y + 30, 480, c_box_y + 70), radius=10, fill=COLOR_GOLD)
    draw.text((115, c_box_y + 38), "⚡ CONTACTEZ LE DR CHIKH TOUAMI", fill=COLOR_PRIMARY_NAVY, font=get_font(17, bold=True))

    draw.text((95, c_box_y + 90), "Rejoignez l'équipe des Émissaires dès aujourd'hui !", fill=COLOR_WHITE, font=get_font(26, bold=True))
    draw.text((95, c_box_y + 135), "Envoyez votre Année d'étude (1ère à 6ème / Interne) par message :", fill=(226, 232, 240), font=get_font(18, bold=False))

    draw.text((95, c_box_y + 175), "✈️ Telegram privé : @chikhtouamidoc", fill=COLOR_CYAN_ACCENT, font=get_font(23, bold=True))
    draw.text((95, c_box_y + 215), "🌐 Plateforme officielle : medsina.medevsync.com", fill=COLOR_GOLD, font=get_font(20, bold=True))

    # Footer
    draw.text((250, 1515), "Medsina • L'excellence médicale au service des étudiants de Blida • 100% Confraternel", fill=COLOR_TEXT_MUTED, font=get_font(16, bold=True))

    img.save(output_path, "PNG", quality=95)
    print(f"✅ Affiche Flyer Émissaires Blida générée : {output_path}")


def main():
    sq_path = os.path.join(OUTPUT_DIR, "medsina_emissaires_blida_square.png")
    fl_path = os.path.join(OUTPUT_DIR, "medsina_emissaires_blida_flyer.png")

    generate_square_emissaires_post(sq_path)
    generate_flyer_emissaires_post(fl_path)
    print("\n🎉 Kit Infographie Émissaires Blida généré avec succès !")


if __name__ == "__main__":
    main()
