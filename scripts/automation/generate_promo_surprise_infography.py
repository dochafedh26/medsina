#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA — GÉNÉRATEUR INFOGRAPHIE 2 : APPEL INSCRIPTION & GRANDE SURPRISE FIN PROMO
=============================================================================
Affiche haute résolution (1200 x 1600) incitant les candidats et étudiants
à créer leur compte gratuit dès maintenant sur Medsina, avec le teasing
d'une grande surprise exclusive réservée à tous les inscrits en fin de promo !
=============================================================================
"""

import os
import sys
import qrcode
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

# Palette Médicale Énergique & Premium
COLOR_BG_TOP = (248, 250, 253)
COLOR_BG_BOT = (235, 244, 255)
COLOR_PRIMARY_NAVY = (11, 37, 69)      # #0B2545
COLOR_ROYAL_BLUE = (10, 93, 194)       # #0A5DC2
COLOR_CYAN_ACCENT = (14, 165, 233)     # #0EA5E9
COLOR_EMERALD = (16, 185, 129)         # #10B981
COLOR_EMERALD_BG = (236, 253, 245)     # #ECFDF5
COLOR_GOLD = (217, 119, 6)             # #D97706
COLOR_GOLD_LIGHT = (254, 243, 199)     # #FEF3C7
COLOR_CRIMSON = (220, 38, 38)          # #DC2626
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


def draw_number_circle(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, bg_color, text_color, num: str):
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=bg_color)
    font = get_font(int(radius * 1.1), bold=True)
    bbox = font.getbbox(num)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    draw.text((cx - w / 2, cy - h / 2 - 2), num, fill=text_color, font=font)


def draw_bullet_dot(draw: ImageDraw.ImageDraw, cx: int, cy: int, radius: int, color):
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)


def draw_medical_cross(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int, color):
    w = max(4, size // 3)
    draw.rounded_rectangle((cx - w // 2, cy - size // 2, cx + w // 2, cy + size // 2), radius=2, fill=color)
    draw.rounded_rectangle((cx - size // 2, cy - w // 2, cx + size // 2, cy + w // 2), radius=2, fill=color)


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


def generate_promo_surprise_infography(output_path: str):
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

    # 2. Pillule Compte à Rebours
    pill_x1, pill_y1, pill_x2, pill_y2 = 700, 42, 1150, 92
    draw_rounded_rect(draw, (pill_x1, pill_y1, pill_x2, pill_y2), radius=16, fill=COLOR_CRIMSON)
    draw_bullet_dot(draw, pill_x1 + 25, (pill_y1 + pill_y2) // 2, 6, COLOR_WHITE)
    draw.text((pill_x1 + 42, 55), "CAMPAGNE SPÉCIALE NOVEMBRE", fill=COLOR_WHITE, font=get_font(16, bold=True))

    # 3. Badge catégorie doré
    draw_rounded_rect(draw, (50, 130, 480, 172), radius=14, fill=COLOR_GOLD)
    draw_bullet_dot(draw, 72, 151, 5, COLOR_WHITE)
    draw.text((88, 140), "APPEL AUX CANDIDATS & ÉTUDIANTS", fill=COLOR_WHITE, font=get_font(16, bold=True))

    # 4. Grands Titres d'accroche
    draw.text((50, 190), "PAS ENCORE INSCRIT SUR MEDSINA ?", fill=COLOR_PRIMARY_NAVY, font=get_font(48, bold=True))
    draw.text((50, 252), "IL EST ENCORE TEMPS DE REJOINDRE !", fill=COLOR_ROYAL_BLUE, font=get_font(44, bold=True))

    draw.text(
        (50, 318),
        "Créez votre compte en 30 secondes et débloquez immédiatement vos outils officiels de révision :",
        fill=COLOR_TEXT_MUTED,
        font=get_font(18, bold=False)
    )

    # 5. CARTON MAJEUR : LE TEASING DE LA GRANDE SURPRISE DE FIN DE PROMO
    surprise_y = 365
    draw_rounded_rect(draw, (50, surprise_y, W - 50, surprise_y + 195), radius=22, fill=COLOR_GOLD_LIGHT, outline=COLOR_GOLD, width=3)
    
    # Macaron étoile
    draw_rounded_rect(draw, (85, surprise_y + 20, 450, surprise_y + 62), radius=10, fill=COLOR_GOLD)
    draw_bullet_dot(draw, 105, surprise_y + 41, 5, COLOR_WHITE)
    draw.text((120, surprise_y + 30), "ÉVÉNEMENT EXCLUSIF FIN NOVEMBRE", fill=COLOR_WHITE, font=get_font(15, bold=True))

    draw.text((85, surprise_y + 75), "UNE GRANDE SURPRISE VOUS ATTEND !", fill=COLOR_PRIMARY_NAVY, font=get_font(30, bold=True))
    draw.text(
        (85, surprise_y + 120),
        "Tous les étudiants et médecins inscrits sur l'application pendant la promo de Novembre\n"
        "bénéficieront d'un avantage exceptionnel et inédit dévoilé à la clôture de la campagne !",
        fill=COLOR_TEXT_DARK,
        font=get_font(18, bold=False)
    )

    # 6. Grille des 4 Raisons Incontournables de s'inscrire MAINTENANT
    reasons = [
        ("1", COLOR_ROYAL_BLUE, "TÉLÉCHARGEMENT DES LIVRETS ALL-IN-ONE 2027", "Accédez aux nouveaux livrets complets de révision (Fiche express, cours complet, QCMs d'entraînement sans corrigé et grille officielle du corrigé type)."),
        ("2", COLOR_EMERALD, "BANQUE DE 15 000+ QCMS CLASSÉS PAR SESSION", "Entraînez-vous sur les annales réelles du concours avec barème officiel, perles cliniques et explications détaillées."),
        ("3", COLOR_GOLD, "CONCOURS BLANCS CHRONOMÉTRÉS & BARÈME BLIDA", "Simulez vos épreuves dans les conditions réelles d'examen avec classement instantané et analyse de vos points faibles."),
        ("4", COLOR_CYAN_ACCENT, "ACCÈS PRIORITAIRE À LA SURPRISE DE FIN DE PROMO", "Votre compte sera automatiquement éligible au grand cadeau de fin de promo réservé aux membres inscrits.")
    ]

    ry = 585
    for num, badge_col, title, desc in reasons:
        draw_rounded_rect(draw, (50, ry, W - 50, ry + 115), radius=16, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
        draw_rounded_rect(draw, (50, ry, 64, ry + 115), radius=8, fill=badge_col)
        draw_number_circle(draw, 108, ry + 57, 24, badge_col, COLOR_WHITE, num)
        draw.text((150, ry + 20), title, fill=COLOR_PRIMARY_NAVY, font=get_font(21, bold=True))
        draw.text((150, ry + 58), desc, fill=COLOR_TEXT_MUTED, font=get_font(15, bold=False))
        ry += 135

    # 7. Conteneur Appel à l'action bas (Bleu Nuit avec contour Or + QR Code)
    box_y = 1150
    box_h = 360
    draw_rounded_rect(draw, (50, box_y, W - 50, box_y + box_h), radius=22, fill=COLOR_PRIMARY_NAVY, outline=COLOR_GOLD, width=3)

    # QR Code
    qr_img = make_qr_code("https://medsina.medevsync.com", 210)
    img.paste(qr_img, (W - 290, box_y + 65), qr_img)
    draw.text((W - 280, box_y + 295), "Scannez pour vous inscrire", fill=COLOR_GOLD, font=get_font(14, bold=True))

    # Badge inscription gratuite
    draw_rounded_rect(draw, (85, box_y + 28, 430, box_y + 68), radius=10, fill=COLOR_EMERALD)
    draw_bullet_dot(draw, 105, box_y + 48, 5, COLOR_WHITE)
    draw.text((120, box_y + 36), "INSCRIPTION 100% GRATUITE & SANS FRAIS", fill=COLOR_WHITE, font=get_font(15, bold=True))

    draw.text((85, box_y + 86), "Rejoignez la communauté Medsina dès ce soir !", fill=COLOR_WHITE, font=get_font(26, bold=True))
    draw.text((85, box_y + 128), "Créez votre profil en quelques clics sur la plateforme Web ou Mobile :", fill=(226, 232, 240), font=get_font(17, bold=False))

    draw_bullet_dot(draw, 100, box_y + 175, 7, COLOR_GOLD)
    draw.text((118, box_y + 163), "Site Officiel : medsina.medevsync.com", fill=COLOR_GOLD, font=get_font(22, bold=True))

    draw_bullet_dot(draw, 100, box_y + 218, 7, COLOR_CYAN_ACCENT)
    draw.text((118, box_y + 206), "Canal Telegram : @medsina_officiel", fill=COLOR_CYAN_ACCENT, font=get_font(21, bold=True))

    draw_bullet_dot(draw, 100, box_y + 261, 7, COLOR_EMERALD)
    draw.text((118, box_y + 249), "Contact & Support : 0770 25 84 53  |  @docchikhtouami", fill=COLOR_EMERALD, font=get_font(20, bold=True))

    # 8. Pied de page
    footer_text = "Faculté de Médecine de Blida & Toutes Facultés d'Algérie  •  CHU Frantz Fanon  •  medsina.medevsync.com"
    f_font = get_font(15, bold=True)
    f_bbox = f_font.getbbox(footer_text)
    f_w = f_bbox[2] - f_bbox[0]
    draw.text(((W - f_w) // 2, 1545), footer_text, fill=COLOR_TEXT_MUTED, font=f_font)

    img.save(output_path, "PNG", quality=95)
    print(f"✅ Infographie Promo Surprise générée : {output_path}")


if __name__ == "__main__":
    out = str(OUTPUT_DIR / "medsina_promo_surprise_announcement.png")
    generate_promo_surprise_infography(out)
