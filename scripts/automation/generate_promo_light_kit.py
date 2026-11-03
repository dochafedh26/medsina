#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - GÉNÉRATEUR DU KIT GRAPHIQUE PROMO LIGHT (INSPIRÉ FLYER FACEBOOK ADS)
=============================================================================
Génère :
1. medsina_flyer_infographie_light.png (1200x1800 - Affiche verticale type flyer)
2. medsina_post_facebook_1to1_light.png (1200x1200 - Post Carré pour Facebook/Insta)
3. medsina_telegram_poll_banner_light.png (1200x675 - Bannière Telegram 16:9)
=============================================================================
"""

import os
import sys
import math
import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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
# 1. GÉNÉRATION DE L'INFOGRAPHIE VERTICALE STYLE FLYER FACEBOOK (1200 x 1800)
# -----------------------------------------------------------------------------
def generate_vertical_flyer(output_path: str):
    W, H = 1200, 1800
    img = create_gradient_bg(W, H, COLOR_BG_TOP, COLOR_BG_BOT)
    draw = ImageDraw.Draw(img)

    # 1. Top Decorative Wave Header (Light Blue Glow)
    for i in range(120):
        alpha = int(45 * (1 - i / 120.0))
        draw.line([(0, i), (W, i)], fill=(10, 93, 194, alpha))

    # Logo en haut à gauche
    if os.path.exists(LOGO_PATH):
        logo = Image.open(LOGO_PATH).convert("RGBA")
        logo_w = 260
        logo_h = int(logo.height * (logo_w / logo.width))
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        img.paste(logo, (50, 40), logo)

    # Top-right Slogan "Révise aujourd'hui, Réussis demain !"
    f_slogan = get_font(23, bold=True)
    draw.text((820, 48), "Révise aujourd'hui,", fill=COLOR_PRIMARY_NAVY, font=f_slogan)
    f_slogan_sub = get_font(25, bold=True)
    draw.text((820, 78), "Réussis demain ! ✨", fill=COLOR_ROYAL_BLUE, font=f_slogan_sub)

    # 2. Main Header Badges & Title
    # Pill "FORMATION MÉDICALE PREMIUM & RÉSIDANAT"
    f_badge = get_font(18, bold=True)
    draw_rounded_rect(draw, (320, 130, 880, 168), radius=19, fill=COLOR_GOLD)
    draw.text((350, 138), "⚡ PLATEFORME MÉDICALE OFFICIELLE DU RÉSIDANAT", fill=COLOR_PRIMARY_NAVY, font=f_badge)

    # Giant Title: MEDSINA ULTRA
    f_title = get_font(68, bold=True)
    draw.text((180, 180), "MEDSINA ULTRA", fill=COLOR_PRIMARY_NAVY, font=f_title)

    # Angle Badge "2026-2027"
    draw_rounded_rect(draw, (860, 188, 1140, 246), radius=12, fill=COLOR_GOLD)
    f_year = get_font(34, bold=True)
    draw.text((885, 194), "2026-2027", fill=COLOR_PRIMARY_NAVY, font=f_year)

    # Subtitle Pill "De l'externe au Résident Major"
    draw_rounded_rect(draw, (360, 260, 840, 302), radius=21, fill=COLOR_ROYAL_BLUE)
    f_sub = get_font(21, bold=True)
    draw.text((410, 268), "De l'Externe au Résident Major", fill=COLOR_WHITE, font=f_sub)

    # Sub-tagline
    f_tagline = get_font(20, bold=False)
    draw.text((180, 318), "Maîtrise le programme officiel des 47 modules avec le simulateur d'examen et nos tuteurs IA !", fill=COLOR_TEXT_MUTED, font=f_tagline)

    # 3. Main Center Split Section : Left = 3D Mockup / Right = Numbered Checklist
    # --- COLONNE GAUCHE : Boîtier 3D Virtuel de l'Application ---
    box_x, box_y, box_w, box_h = 50, 380, 440, 680
    # Shadow
    draw_rounded_rect(draw, (box_x + 8, box_y + 8, box_x + box_w + 8, box_y + box_h + 8), radius=22, fill=(203, 213, 225, 160))
    # Card Container
    draw_rounded_rect(draw, (box_x, box_y, box_x + box_w, box_y + box_h), radius=22, fill=COLOR_PRIMARY_NAVY, outline=COLOR_ROYAL_BLUE, width=3)

    # Inside Mockup Book
    # Top banner of book
    draw_rounded_rect(draw, (box_x + 20, box_y + 20, box_x + box_w - 20, box_y + 90), radius=12, fill=COLOR_ROYAL_BLUE)
    f_book_badge = get_font(18, bold=True)
    draw.text((box_x + 40, box_y + 35), "SUITE MÉDICALE OFFICIELLE", fill=COLOR_WHITE, font=f_book_badge)
    draw.text((box_x + 85, box_y + 60), "ALGÉRIE 2026-2027", fill=COLOR_GOLD, font=get_font(15, bold=True))

    # App Icon in book
    if os.path.exists(ICON_PATH):
        icon_img = Image.open(ICON_PATH).convert("RGBA").resize((130, 130), Image.Resampling.LANCZOS)
        img.paste(icon_img, (box_x + 155, box_y + 115), icon_img)

    # Book Title
    f_book_title = get_font(30, bold=True)
    draw.text((box_x + 95, box_y + 260), "MEDSINA ULTRA", fill=COLOR_WHITE, font=f_book_title)

    # Gold pill inside book
    draw_rounded_rect(draw, (box_x + 70, box_y + 305, box_x + box_w - 70, box_y + 340), radius=16, fill=COLOR_GOLD)
    draw.text((box_x + 85, box_y + 312), "★ 47 MODULES OFFICIELS ★", fill=COLOR_PRIMARY_NAVY, font=get_font(16, bold=True))

    # Feature checklist inside book
    book_features = [
        "✓ +15 000 QCMs & Annales corrigées",
        "✓ Mode Tout ou Rien / Pondéré",
        "✓ Flashcards FSRS créées en 1 clic",
        "✓ Study Planner J-X intelligent",
        "✓ Tuteurs IA MedsinaTeacher",
        "✓ Vidal Algérie & CAT d'urgence"
    ]
    f_bf = get_font(16, bold=True)
    for idx, bf in enumerate(book_features):
        draw.text((box_x + 35, box_y + 365 + idx * 36), bf, fill=(241, 245, 249), font=f_bf)

    # Bottom badge across book
    draw_rounded_rect(draw, (box_x + 20, box_y + 595, box_x + box_w - 20, box_y + 655), radius=14, fill=COLOR_GOLD)
    f_ribbon = get_font(18, bold=True)
    draw.text((box_x + 42, box_y + 608), "BOOSTEZ VOS RÉSULTATS", fill=COLOR_PRIMARY_NAVY, font=f_ribbon)
    draw.text((box_x + 65, box_y + 630), "AVEC MEDSINA ULTRA !", fill=COLOR_PRIMARY_NAVY, font=get_font(14, bold=True))

    # --- COLONNE DROITE : CE QUE VOUS ALLEZ OBTENIR (11 ÉLÉMENTS NUMÉROTÉS) ---
    right_x = 520
    # Yellow Header "Ce que vous offre l'application"
    draw_rounded_rect(draw, (right_x, 375, right_x + 630, 420), radius=12, fill=COLOR_GOLD_LIGHT, outline=COLOR_GOLD, width=2)
    f_rh = get_font(22, bold=True)
    draw.text((right_x + 30, 383), "Ce que vous trouverez dans Medsina :", fill=COLOR_PRIMARY_NAVY, font=f_rh)

    features_11 = [
        ("1", "Les 47 modules officiels", "Alger, Blida, Oran, Constantine conformes CNES"),
        ("2", "Banque de +15 000 QCMs", "Classés par cours avec badge Tombabilité 🔥"),
        ("3", "Simulateur de Concours Blanc", "Chronométré, barème officiel Tout ou Rien / Pondéré"),
        ("4", "Alerte Pièges Automatique", "Détection « SAUF UNE » et questions éliminatoires"),
        ("5", "Statistiques Communautaires", "% de réussite en temps réel par proposition"),
        ("6", "Flashcards FSRS en 1 clic", "Répétition espacée pour ne plus jamais oublier"),
        ("7", "Study Planner J-X Prédictif", "Calcul quotidien des cours prioritaires à réviser"),
        ("8", "6 Tuteurs IA MedsinaTeacher", "Simulations réelles d'amphi et tours de salle"),
        ("9", "CAT d'Urgences & Vidal Algérie", "Protocoles thérapeutiques et posologies hospitalières"),
        ("10", "100% Hors-Ligne (Windows/Android)", "Révisez partout sans aucune connexion internet"),
        ("11", "Synchronisation Multi-Appareils", "Vos scores et flashcards synchronisés en temps réel")
    ]

    item_y = 435
    for num, title_f, desc_f in features_11:
        # Circle badge
        draw.ellipse([right_x, item_y + 2, right_x + 32, item_y + 34], fill=COLOR_ROYAL_BLUE)
        f_num = get_font(17, bold=True)
        draw.text((right_x + (10 if len(num) == 1 else 6), item_y + 6), num, fill=COLOR_WHITE, font=f_num)

        # Title & desc
        f_ftitle = get_font(18, bold=True)
        draw.text((right_x + 44, item_y + 2), title_f, fill=COLOR_PRIMARY_NAVY, font=f_ftitle)
        f_fdesc = get_font(15, bold=False)
        draw.text((right_x + 44, item_y + 24), desc_f, fill=COLOR_TEXT_MUTED, font=f_fdesc)

        item_y += 56

    # 4. Icon Cards Strip (6 Badges)
    strip_y = 1085
    cards_data = [
        ("Mode Hors-Ligne", "Windows & Android"),
        ("+15 000 QCMs", "Annales Corrigées"),
        ("47 Modules", "Programme National"),
        ("Multi-Support", "PC, Mobile, Tablette"),
        ("FSRS v4.5", "Répétition Intelligente"),
        ("Conçu par Médecins", "Pour Futurs Résidents")
    ]
    card_w = 175
    card_h = 75
    start_cx = 50
    spacing = 15
    for i, (ct, cd) in enumerate(cards_data):
        cx = start_cx + i * (card_w + spacing)
        draw_rounded_rect(draw, (cx, strip_y, cx + card_w, strip_y + card_h), radius=12, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
        draw.text((cx + 12, strip_y + 12), ct, fill=COLOR_ROYAL_BLUE, font=get_font(14, bold=True))
        draw.text((cx + 12, strip_y + 38), cd, fill=COLOR_TEXT_MUTED, font=get_font(12, bold=False))

    # 5. Grand Encadré Promo "30 JOURS GRATUITS" avec QR CODE
    promo_box_y = 1180
    promo_box_h = 240
    # Outer Card
    draw_rounded_rect(draw, (50, promo_box_y, W - 50, promo_box_y + promo_box_h), radius=22, fill=COLOR_PRIMARY_NAVY, outline=COLOR_GOLD, width=3)

    # Top yellow ribbon inside box
    draw_rounded_rect(draw, (50, promo_box_y, W - 50, promo_box_y + 50), radius=0, fill=COLOR_GOLD)
    draw_rounded_rect(draw, (50, promo_box_y, W - 50, promo_box_y + 50), radius=22, fill=COLOR_GOLD)
    draw.rectangle([50, promo_box_y + 25, W - 50, promo_box_y + 50], fill=COLOR_GOLD)
    draw.text((80, promo_box_y + 12), "🎁 OFFRE DE LANCEMENT : 30 JOURS ALL-ACCESS VIP GRATUITS (JUSQU'AU 30/11) !", fill=COLOR_PRIMARY_NAVY, font=get_font(21, bold=True))

    # QR Code on the right
    qr_img = make_qr_code("https://medsina.medevsync.com", 160)
    qr_bg_box = (W - 250, promo_box_y + 65, W - 70, promo_box_y + 225)
    draw_rounded_rect(draw, qr_bg_box, radius=12, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
    img.paste(qr_img, (W - 240, promo_box_y + 70), qr_img)

    f_qr_label = get_font(12, bold=True)
    draw.text((W - 245, promo_box_y + 210), "Scannez pour activer 30j", fill=COLOR_ROYAL_BLUE, font=f_qr_label)

    # Promo Details on the left
    f_p1 = get_font(25, bold=True)
    draw.text((85, promo_box_y + 68), "Profitez de l'Accès Intégral Sans Limite", fill=COLOR_WHITE, font=f_p1)

    f_p2 = get_font(17, bold=False)
    draw.text((85, promo_box_y + 106), "• Débloquez immédiatement les 47 modules et nos 15 000+ QCMs.", fill=(241, 245, 249), font=f_p2)
    draw.text((85, promo_box_y + 134), "• Offre spéciale 100 places réservées aux nouveaux inscrits de Novembre.", fill=(241, 245, 249), font=f_p2)

    # Red/Orange Action Button
    btn_x, btn_y, btn_w, btn_h = 85, promo_box_y + 170, 480, 50
    draw_rounded_rect(draw, (btn_x, btn_y, btn_x + btn_w, btn_y + btn_h), radius=14, fill=COLOR_RED_ACCENT)
    f_btn = get_font(20, bold=True)
    draw.text((btn_x + 30, btn_y + 12), "👉 Activez sur medsina.medevsync.com", fill=COLOR_WHITE, font=f_btn)

    # 6. Slogan "Transforme tes révisions en succès !"
    f_quote = get_font(34, bold=True)
    draw.text((360, 1445), "Transforme tes révisions en succès ! 🏆", fill=COLOR_PRIMARY_NAVY, font=f_quote)

    # 7. Red Tag "Disponible sur Chariow / Web / Windows / Android"
    draw_rounded_rect(draw, (380, 1505, 820, 1560), radius=16, fill=COLOR_RED_ACCENT)
    f_dispo = get_font(21, bold=True)
    draw.text((410, 1520), "Disponible sur Windows • Android • Web", fill=COLOR_WHITE, font=f_dispo)

    # 8. Bottom Reassurance Bar
    foot_y = 1600
    foot_h = 130
    draw_rounded_rect(draw, (50, foot_y, W - 50, foot_y + foot_h), radius=18, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)

    # 3 reassurance pills
    f_reassure = get_font(18, bold=True)
    draw.text((90, foot_y + 50), "🛡️ 100% Gratuit en Novembre", fill=COLOR_PRIMARY_NAVY, font=f_reassure)
    draw.text((460, foot_y + 50), "⚡ Activation Immédiate", fill=COLOR_PRIMARY_NAVY, font=f_reassure)
    draw.text((790, foot_y + 50), "🩺 Aucune Carte Requise", fill=COLOR_PRIMARY_NAVY, font=f_reassure)

    # Save flyer
    img.save(output_path, "PNG", quality=95)
    print(f"✅ Infographie verticale générée : {output_path}")


# -----------------------------------------------------------------------------
# 2. GÉNÉRATION DU POST FACEBOOK / INSTAGRAM FORMAT CARRÉ (1200 x 1200)
# -----------------------------------------------------------------------------
def generate_square_post(output_path: str):
    W, H = 1200, 1200
    img = create_gradient_bg(W, H, COLOR_BG_TOP, (226, 238, 252))
    draw = ImageDraw.Draw(img)

    # Logo
    if os.path.exists(LOGO_PATH):
        logo = Image.open(LOGO_PATH).convert("RGBA")
        logo_w = 260
        logo_h = int(logo.height * (logo_w / logo.width))
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        img.paste(logo, (50, 40), logo)

    # Top pill
    draw_rounded_rect(draw, (700, 45, 1150, 95), radius=16, fill=COLOR_GOLD)
    draw.text((725, 58), "🔥 CONCOURS RÉSIDANAT 2026-2027", fill=COLOR_PRIMARY_NAVY, font=get_font(17, bold=True))

    # Main Hero Title
    draw.text((60, 130), "30 JOURS ALL-ACCESS VIP", fill=COLOR_PRIMARY_NAVY, font=get_font(46, bold=True))
    draw.text((60, 195), "OFFERTS SUR MEDSINA !", fill=COLOR_ROYAL_BLUE, font=get_font(52, bold=True))

    draw.text((60, 275), "La seule plateforme complète qui simule les conditions réelles du concours :", fill=COLOR_TEXT_MUTED, font=get_font(21, bold=False))

    # 4 Big Value Cards
    cards = [
        ("📚 47 MODULES OFFICIELS", "+15 000 QCMs corrigés classés par cours et par Tombabilité 🔥"),
        ("⏱️ CONCOURS BLANCS RÉELS", "Chronométré, barème officiel Tout ou Rien / Pondéré"),
        ("🚨 DÉTECTION DES PIÈGES", "Vigilance automatique « SAUF UNE » et propositions pièges"),
        ("⚡ 100% HORS-LIGNE", "Fonctionne sans internet sur PC Windows & Smartphone Android")
    ]
    card_y = 330
    for title, desc in cards:
        draw_rounded_rect(draw, (60, card_y, W - 60, card_y + 115), radius=16, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
        # Left blue strip
        draw_rounded_rect(draw, (60, card_y, 75, card_y + 115), radius=8, fill=COLOR_ROYAL_BLUE)
        draw.text((95, card_y + 18), title, fill=COLOR_PRIMARY_NAVY, font=get_font(24, bold=True))
        draw.text((95, card_y + 60), desc, fill=COLOR_TEXT_MUTED, font=get_font(18, bold=False))
        card_y += 135

    # Bottom Promo Bar with QR Code
    foot_y = 890
    draw_rounded_rect(draw, (60, foot_y, W - 60, foot_y + 240), radius=20, fill=COLOR_PRIMARY_NAVY, outline=COLOR_GOLD, width=3)

    # QR Code
    qr_img = make_qr_code("https://medsina.medevsync.com", 160)
    img.paste(qr_img, (W - 240, foot_y + 40), qr_img)
    draw.text((W - 245, foot_y + 205), "Scannez pour tester", fill=COLOR_GOLD, font=get_font(13, bold=True))

    # Text in promo
    draw.text((90, foot_y + 30), "🎁 OFFRE LIMITÉE À 100 PLACES", fill=COLOR_GOLD, font=get_font(20, bold=True))
    draw.text((90, foot_y + 68), "Inscrivez-vous avant le 30 Novembre !", fill=COLOR_WHITE, font=get_font(30, bold=True))
    draw.text((90, foot_y + 120), "👉 Lien d'inscription directe dans le premier commentaire !", fill=(226, 232, 240), font=get_font(19, bold=False))

    draw_rounded_rect(draw, (90, foot_y + 165, 520, foot_y + 215), radius=12, fill=COLOR_RED_ACCENT)
    draw.text((120, foot_y + 178), "🔗 medsina.medevsync.com", fill=COLOR_WHITE, font=get_font(20, bold=True))

    img.save(output_path, "PNG", quality=95)
    print(f"✅ Post Carré Facebook généré : {output_path}")


# -----------------------------------------------------------------------------
# 3. GÉNÉRATION DE LA BANNIÈRE SONDAGE TELEGRAM (1200 x 675)
# -----------------------------------------------------------------------------
def generate_telegram_banner(output_path: str):
    W, H = 1200, 675
    img = create_gradient_bg(W, H, COLOR_BG_TOP, (224, 238, 252))
    draw = ImageDraw.Draw(img)

    # Logo
    if os.path.exists(LOGO_PATH):
        logo = Image.open(LOGO_PATH).convert("RGBA")
        logo_w = 260
        logo_h = int(logo.height * (logo_w / logo.width))
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        img.paste(logo, (50, 35), logo)

    # Badge RITUEL 20H
    draw_rounded_rect(draw, (750, 35, 1140, 85), radius=16, fill=COLOR_GOLD)
    draw.text((775, 48), "🌙 RITUEL QUOTIDIEN • 20H00", fill=COLOR_PRIMARY_NAVY, font=get_font(18, bold=True))

    # Title
    draw.text((50, 120), "QUESTION PIÈGE DU JOUR", fill=COLOR_PRIMARY_NAVY, font=get_font(46, bold=True))
    draw.text((50, 185), "Résidanat Algérie • Annales & Débats", fill=COLOR_ROYAL_BLUE, font=get_font(28, bold=True))

    # Features list
    features = [
        "🔥 QCM piège officiel posté chaque soir à 20h00",
        "🗳️ Votez en direct dans le sondage Telegram interactif",
        "💡 Corrigé argumenté + fiche réflexe le lendemain",
        "🎁 30 jours All-Access VIP offerts sur medsina.medevsync.com"
    ]
    f_y = 260
    for feat in features:
        draw_rounded_rect(draw, (50, f_y, W - 320, f_y + 55), radius=12, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=1)
        draw.text((75, f_y + 14), feat, fill=COLOR_PRIMARY_NAVY, font=get_font(18, bold=True))
        f_y += 68

    # QR Code on the right
    qr_img = make_qr_code("https://medsina.medevsync.com", 180)
    draw_rounded_rect(draw, (W - 270, 150, W - 50, 390), radius=16, fill=COLOR_WHITE, outline=COLOR_CARD_BORDER, width=2)
    img.paste(qr_img, (W - 250, 170), qr_img)
    draw.text((W - 255, 360), "medsina.medevsync.com", fill=COLOR_ROYAL_BLUE, font=get_font(12, bold=True))

    # Bottom bar
    draw_rounded_rect(draw, (50, 560, W - 50, 635), radius=14, fill=COLOR_PRIMARY_NAVY)
    draw.text((80, 582), "Canal Officiel : @medsina_officiel • Rejoignez la communauté des résidents !", fill=COLOR_WHITE, font=get_font(19, bold=True))

    img.save(output_path, "PNG", quality=95)
    print(f"✅ Bannière Telegram générée : {output_path}")


def main():
    flyer_path = os.path.join(OUTPUT_DIR, "medsina_flyer_infographie_light.png")
    square_path = os.path.join(OUTPUT_DIR, "medsina_post_facebook_1to1_light.png")
    tg_path = os.path.join(OUTPUT_DIR, "medsina_telegram_poll_banner_light.png")

    generate_vertical_flyer(flyer_path)
    generate_square_post(square_path)
    generate_telegram_banner(tg_path)
    print("\n🎉 Kit graphique moderne & light généré avec succès dans assets/facebook/ !")


if __name__ == "__main__":
    main()
