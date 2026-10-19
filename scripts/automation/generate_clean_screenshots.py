#!/usr/bin/env python3
"""
Generate ultra-clean, high-resolution, pixel-perfect Medsina application screenshots
for use in Facebook & social media marketing mockups.
Completely eliminates raw HTML code, microscopic unreadable text, and awkward crops.
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

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


def generate_qcm_desktop_screenshot(output_path: str):
    """Génère un écran QCM haute définition 1200x750 pour Desktop avec interface soignée."""
    w, h = 1200, 750
    im = Image.new("RGBA", (w, h), (248, 250, 252, 255))
    draw = ImageDraw.Draw(im)

    font_nav = get_font(18, bold=True)
    font_sub = get_font(14, bold=False)
    font_q_title = get_font(22, bold=True)
    font_choice = get_font(17, bold=False)
    font_choice_bold = get_font(17, bold=True)
    font_badge = get_font(14, bold=True)
    font_expl = get_font(16, bold=False)

    # 1. Sidebar gauche (250px)
    draw.rectangle([(0, 0), (250, h)], fill=(15, 23, 42, 255))
    # Logo
    draw.ellipse([(28, 28), (64, 64)], fill=(14, 165, 233, 255))
    draw.text((38, 34), "M", font=get_font(24, bold=True), fill=(255, 255, 255, 255))
    draw.text((76, 32), "MEDSINA", font=font_nav, fill=(255, 255, 255, 255))
    draw.text((76, 54), "Résidanat 2027", font=font_sub, fill=(148, 163, 184, 255))

    # Nav items
    nav_items = [
        ("Tableau de bord", False),
        ("Formation Résidanat", True),
        ("Banque de QCMs", False),
        ("Analyseur Vidal", False),
        ("Codex Urgences", False),
        ("MedsinaPilot IA", False),
    ]
    ny = 110
    for label, active in nav_items:
        if active:
            draw.rounded_rectangle([(16, ny), (234, ny + 44)], radius=8, fill=(30, 41, 59, 255))
            draw.rectangle([(16, ny + 8), (20, ny + 36)], fill=(14, 165, 233, 255))
            draw.text((36, ny + 12), label, font=font_nav, fill=(56, 189, 248, 255))
        else:
            draw.text((36, ny + 12), label, font=get_font(16, bold=False), fill=(148, 163, 184, 255))
        ny += 54

    # Profil badge bottom
    draw.rounded_rectangle([(16, h - 70), (234, h - 20)], radius=8, fill=(30, 41, 59, 255))
    draw.ellipse([(26, h - 60), (56, h - 30)], fill=(16, 185, 129, 255))
    draw.text((35, h - 54), "D", font=get_font(16, bold=True), fill=(255, 255, 255, 255))
    draw.text((66, h - 58), "Dr. Hafedh", font=get_font(15, bold=True), fill=(255, 255, 255, 255))
    draw.text((66, h - 40), "Médecin Pro VIP", font=font_sub, fill=(52, 211, 153, 255))

    # 2. Zone Principale (QCM)
    main_x = 280

    # Header de révision
    draw.rounded_rectangle([(main_x, 24), (main_x + 190, 56)], radius=6, fill=(238, 242, 255, 255), outline=(199, 210, 254, 255))
    draw.text((main_x + 14, 32), "CARDIOLOGIE • VASCULAIRE", font=font_badge, fill=(79, 70, 229, 255))

    draw.text((main_x + 210, 32), "Question 14 / 20  •  Concours Officiel 2024", font=get_font(15, bold=True), fill=(71, 85, 105, 255))

    # Intitulé de la question
    q_box_y = 75
    draw.rounded_rectangle([(main_x, q_box_y), (w - 35, q_box_y + 110)], radius=12, fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=1)
    draw.text((main_x + 20, q_box_y + 18), "Concernant le traitement d'urgence du Syndrome Coronarien Aigu ST+ (IDM ST+),", font=font_q_title, fill=(15, 23, 42, 255))
    draw.text((main_x + 20, q_box_y + 54), "quelle est la proposition exacte recommandée par les consensus récents (ESC) ?", font=font_q_title, fill=(15, 23, 42, 255))

    # Choix A, B, C, D
    choices = [
        ("A", "La thrombolyse intraveineuse reste le premier choix quel que soit le d\u00e9lai du PCM.", False),
        ("B", "L'angioplastie primaire est recommand\u00e9e si le d\u00e9lai PCM - Guide est < 120 min.", True),
        ("C", "L'association aspirine + h\u00e9parine doit \u00eatre diff\u00e9r\u00e9e jusqu'\u00e0 la salle de coronarographie.", False),
        ("D", "Le traitement par b\u00eata-bloquants IV est syst\u00e9matique \u00e0 la phase aigu\u00eb m\u00eame si Killip > I.", False),
    ]

    cy = q_box_y + 125
    for letter, text, is_correct in choices:
        bg_col = (240, 253, 244, 255) if is_correct else (255, 255, 255, 255)
        border_col = (34, 197, 94, 255) if is_correct else (226, 232, 240, 255)
        border_w = 2 if is_correct else 1

        draw.rounded_rectangle([(main_x, cy), (w - 35, cy + 54)], radius=10, fill=bg_col, outline=border_col, width=border_w)

        # Badge lettre
        badge_fill = (34, 197, 94, 255) if is_correct else (241, 245, 249, 255)
        badge_text_col = (255, 255, 255, 255) if is_correct else (71, 85, 105, 255)
        draw.ellipse([(main_x + 14, cy + 12), (main_x + 44, cy + 42)], fill=badge_fill)
        draw.text((main_x + 24, cy + 16), letter, font=font_choice_bold, fill=badge_text_col)

        # Texte du choix
        t_col = (22, 101, 52, 255) if is_correct else (51, 65, 85, 255)
        draw.text((main_x + 58, cy + 16), text, font=font_choice, fill=t_col)

        if is_correct:
            draw.rounded_rectangle([(w - 175, cy + 12), (w - 50, cy + 42)], radius=6, fill=(220, 252, 231, 255), outline=(34, 197, 94, 255))
            draw.text((w - 165, cy + 17), "[VRAI] Valid\u00e9", font=font_badge, fill=(22, 101, 52, 255))

        cy += 64

    # Bo\u00eete d'explication p\u00e9dagogique haute valeur
    ey = cy + 10
    draw.rounded_rectangle([(main_x, ey), (w - 35, h - 30)], radius=12, fill=(240, 249, 255, 255), outline=(186, 230, 253, 255), width=2)

    # En-t\u00eate explication
    draw.text((main_x + 20, ey + 16), "SYNTH\u00c8SE DU MAJOR & PI\u00c8GES DU CONCOURS :", font=get_font(15, bold=True), fill=(3, 105, 161, 255))
    draw.text((main_x + 20, ey + 42), "\u2022 Si PCM -> Guide < 120 min : Angioplastie primaire imm\u00e9diate en USIC (Option B exacte).", font=font_expl, fill=(15, 23, 42, 255))
    draw.text((main_x + 20, ey + 68), "\u2022 Si d\u00e9lai > 120 min : Fibrinolyse IV sans d\u00e9lai (< 10 min apr\u00e8s diagnostic), puis transfert.", font=font_expl, fill=(15, 23, 42, 255))
    draw.text((main_x + 20, ey + 94), "\u2022 Pi\u00e8ge classique du r\u00e9sidanat : les b\u00eata-bloquants IV pr\u00e9coces sont contre-indiqu\u00e9s si Killip > I.", font=font_expl, fill=(15, 23, 42, 255))

    # Badge bouton IA en bas \u00e0 droite
    btn_x = w - 300
    btn_y = h - 68
    draw.rounded_rectangle([(btn_x, btn_y), (w - 50, btn_y + 32)], radius=8, fill=(14, 165, 233, 255))
    draw.text((btn_x + 22, btn_y + 6), "Approfondir avec MedsinaPilot", font=get_font(13, bold=True), fill=(255, 255, 255, 255))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    im.save(output_path, "PNG", quality=95)
    print(f"Generated clean QCM screenshot: {output_path}")


def generate_vidal_desktop_screenshot(output_path: str):
    """G\u00e9n\u00e8re un \u00e9cran Analyseur Vidal haute d\u00e9finition 1200x750 pour Desktop avec alertes claires."""
    w, h = 1200, 750
    im = Image.new("RGBA", (w, h), (248, 250, 252, 255))
    draw = ImageDraw.Draw(im)

    font_nav = get_font(18, bold=True)
    font_sub = get_font(14, bold=False)
    font_badge = get_font(14, bold=True)
    font_card_title = get_font(20, bold=True)
    font_text = get_font(16, bold=False)
    font_text_bold = get_font(16, bold=True)

    # 1. Sidebar gauche (250px)
    draw.rectangle([(0, 0), (250, h)], fill=(15, 23, 42, 255))
    draw.ellipse([(28, 28), (64, 64)], fill=(14, 165, 233, 255))
    draw.text((38, 34), "M", font=get_font(24, bold=True), fill=(255, 255, 255, 255))
    draw.text((76, 32), "MEDSINA", font=font_nav, fill=(255, 255, 255, 255))
    draw.text((76, 54), "Vidal Alg\u00e9rie 2026", font=font_sub, fill=(148, 163, 184, 255))

    nav_items = [
        ("Tableau de bord", False),
        ("Formation R\u00e9sidanat", False),
        ("Banque de QCMs", False),
        ("Analyseur Vidal", True),
        ("Codex Urgences", False),
        ("MedsinaPilot IA", False),
    ]
    ny = 110
    for label, active in nav_items:
        if active:
            draw.rounded_rectangle([(16, ny), (234, ny + 44)], radius=8, fill=(30, 41, 59, 255))
            draw.rectangle([(16, ny + 8), (20, ny + 36)], fill=(245, 158, 11, 255))
            draw.text((36, ny + 12), label, font=font_nav, fill=(251, 191, 36, 255))
        else:
            draw.text((36, ny + 12), label, font=get_font(16, bold=False), fill=(148, 163, 184, 255))
        ny += 54

    main_x = 280

    # Header
    draw.rounded_rectangle([(main_x, 24), (main_x + 220, 56)], radius=6, fill=(254, 243, 199, 255), outline=(252, 211, 77, 255))
    draw.text((main_x + 14, 32), "S\u00c9CURIT\u00c9 \u2022 VIDAL ALG\u00c9RIE", font=font_badge, fill=(180, 83, 9, 255))
    draw.text((main_x + 240, 32), "5 425 Sp\u00e9cialit\u00e9s MSPRH \u2022 Nomenclature Nationale", font=get_font(15, bold=True), fill=(71, 85, 105, 255))

    # Ordonnance analys\u00e9e Card
    oy = 75
    draw.rounded_rectangle([(main_x, oy), (w - 35, oy + 120)], radius=12, fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=1)
    draw.text((main_x + 20, oy + 16), "M\u00e9dicaments Saisis dans l'Ordonnance de Garde :", font=font_card_title, fill=(15, 23, 42, 255))

    # Chips m\u00e9dicaments
    meds = [
        ("Sintrom 4mg (Ac\u00e9nocoumarol)", (238, 242, 255), (79, 70, 229)),
        ("Bi-Prof\u00e9nid 150mg (K\u00e9toprof\u00e8ne)", (254, 242, 242), (220, 38, 38)),
        ("Inexium 40mg (\u00c9som\u00e9prazole)", (240, 253, 244), (22, 101, 52)),
    ]
    mx = main_x + 20
    for med_name, bg_c, txt_c in meds:
        draw.rounded_rectangle([(mx, oy + 60), (mx + 280, oy + 98)], radius=20, fill=(*bg_c, 255), outline=(*txt_c, 150), width=1)
        # Small circle bullet
        draw.ellipse([(mx + 14, oy + 76), (mx + 20, oy + 82)], fill=(*txt_c, 255))
        draw.text((mx + 26, oy + 70), med_name, font=get_font(14, bold=True), fill=(*txt_c, 255))
        mx += 295

    # Alerte d'Interaction Majeure
    ay = oy + 140
    draw.rounded_rectangle([(main_x, ay), (w - 35, ay + 210)], radius=14, fill=(254, 242, 242, 255), outline=(239, 68, 68, 255), width=2)

    # Red badge
    draw.rounded_rectangle([(main_x + 20, ay + 18), (main_x + 360, ay + 52)], radius=6, fill=(220, 38, 38, 255))
    draw.text((main_x + 32, ay + 24), "CONTRE-INDICATION ABSOLUE (NIVEAU 1)", font=get_font(14, bold=True), fill=(255, 255, 255, 255))

    draw.text((main_x + 20, ay + 68), "Interaction S\u00e9v\u00e8re : Sintrom (AVK) + Bi-Prof\u00e9nid (AINS)", font=get_font(19, bold=True), fill=(153, 27, 27, 255))
    draw.text((main_x + 20, ay + 104), "\u2022 Risque Clinique : Majoration dramatique du risque d'h\u00e9morragie digestive par agression de la muqueuse gastrique", font=font_text, fill=(30, 41, 59, 255))
    draw.text((main_x + 20, ay + 130), "  et inhibition plaquettaire cumulative avec l'hypoprothrombin\u00e9mie.", font=font_text, fill=(30, 41, 59, 255))
    draw.text((main_x + 20, ay + 164), "\u2022 Recommandation Medsina : Arr\u00eater imm\u00e9diatement le k\u00e9toprof\u00e8ne. Pr\u00e9f\u00e9rer le Parac\u00e9tamol en antalgie.", font=font_text_bold, fill=(185, 28, 28, 255))

    # Terrain Patient Card
    py = ay + 230
    draw.rounded_rectangle([(main_x, py), (w - 35, h - 30)], radius=12, fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=1)
    draw.text((main_x + 20, py + 16), "Contr\u00f4le Automatique du Terrain Physiopathologique :", font=font_card_title, fill=(15, 23, 42, 255))
    draw.text((main_x + 20, py + 48), "\u2022 Insuffisance R\u00e9nale : Clairance calcul\u00e9e (CKD-EPI) = 52 ml/min -> Adaptation posologique automatique sugg\u00e9r\u00e9e.", font=font_text, fill=(71, 85, 105, 255))
    draw.text((main_x + 20, py + 74), "\u2022 Statut : Analyse certifi\u00e9e conforme aux monographies officielles de la pharmacop\u00e9e alg\u00e9rienne 2026.", font=get_font(14, bold=True), fill=(16, 185, 129, 255))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    im.save(output_path, "PNG", quality=95)
    print(f"Generated clean Vidal screenshot: {output_path}")


def generate_mobile_clinical_screenshot(output_path: str):
    """G\u00e9n\u00e8re un \u00e9cran mobile haute d\u00e9finition 750x1500 pour Smartphone avec dialogue clinique limpide."""
    w, h = 750, 1500
    im = Image.new("RGBA", (w, h), (248, 250, 252, 255))
    draw = ImageDraw.Draw(im)

    font_header = get_font(26, bold=True)
    font_sub = get_font(18, bold=False)
    font_bubble_user = get_font(22, bold=False)
    font_resp_title = get_font(22, bold=True)
    font_resp_body = get_font(20, bold=False)
    font_badge = get_font(17, bold=True)

    # 1. En-t\u00eate mobile de l'application
    draw.rectangle([(0, 0), (w, 140)], fill=(15, 23, 42, 255))
    draw.ellipse([(35, 45), (95, 105)], fill=(14, 165, 233, 255))
    draw.text((50, 58), "M", font=get_font(32, bold=True), fill=(255, 255, 255, 255))
    draw.text((115, 50), "MedsinaPilot IA", font=font_header, fill=(255, 255, 255, 255))
    draw.text((115, 85), "Copilote Clinique & Urgences 24h/24", font=font_sub, fill=(148, 163, 184, 255))

    # Badge 'En Ligne'
    draw.rounded_rectangle([(w - 150, 60), (w - 35, 96)], radius=18, fill=(6, 78, 59, 255))
    draw.ellipse([(w - 138, 73), (w - 126, 85)], fill=(52, 211, 153, 255))
    draw.text((w - 118, 68), "Actif", font=get_font(15, bold=True), fill=(52, 211, 153, 255))

    # 2. Bulle utilisateur (M\u00e9decin de garde)
    user_y = 175
    draw.rounded_rectangle([(140, user_y), (w - 35, user_y + 115)], radius=18, fill=(14, 165, 233, 255))
    draw.text((165, user_y + 20), "Dr. Hafedh (Garde Urgences)", font=get_font(16, bold=True), fill=(224, 242, 254, 255))
    draw.text((165, user_y + 48), "Homme 58 ans, douleur thoracique typique", font=font_bubble_user, fill=(255, 255, 255, 255))
    draw.text((165, user_y + 76), "\u00e0 H2, sus-d\u00e9calage V1-V4. Quelle est la CAT ?", font=font_bubble_user, fill=(255, 255, 255, 255))

    # 3. R\u00e9ponse MedsinaPilot Card
    ai_y = user_y + 140
    draw.rounded_rectangle([(35, ai_y), (w - 35, h - 140)], radius=22, fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=2)

    # Titre IA
    draw.rounded_rectangle([(60, ai_y + 25), (410, ai_y + 65)], radius=8, fill=(238, 242, 255, 255))
    draw.text((75, ai_y + 32), "RECOMMANDATION CLINIQUE URGENTE", font=font_badge, fill=(79, 70, 229, 255))

    draw.text((60, ai_y + 80), "Syndrome Coronarien Aigu ST+ (IDM Ant\u00e9rieur)", font=font_resp_title, fill=(15, 23, 42, 255))

    steps = [
        ("1. Alerte USIC & Coronarographie :", "Objectif PCM-Guide < 120 min. Alerte SAMU/Coro imm\u00e9diate."),
        ("2. Double Antiagr\u00e9gation Plaquettaire :", "\u2022 Aspirine 250-300 mg IVD (ou per os m\u00e2ch\u00e9)\n\u2022 Ticagr\u00e9lor (Brilique) 180 mg per os (ou Prasugrel 60 mg)."),
        ("3. Anticoagulation Efficace Imm\u00e9diate :", "\u2022 HNF : 5000 UI IV bolus (ou 70-100 UI/kg)\n\u2022 Alternative : \u00c9noxaparine (Lovenox) 30 mg IV bolus puis 1 mg/kg SC."),
        ("4. Traitement Symptomatique & Surveillance :", "\u2022 Morphine titr\u00e9e IV si EVA > 5 (2 mg/5 min)\n\u2022 Oxyg\u00e8ne UNIQUEMENT si SaO2 < 90%\n\u2022 Scope ECG continu et d\u00e9fibrillateur \u00e0 port\u00e9e imm\u00e9diate.")
    ]

    sy = ai_y + 125
    for title_s, body_s in steps:
        draw.text((60, sy), title_s, font=get_font(20, bold=True), fill=(3, 105, 161, 255))
        sy += 28
        for line in body_s.split("\n"):
            draw.text((60, sy), line, font=font_resp_body, fill=(51, 65, 85, 255))
            sy += 28
        sy += 16

    # Source officielle
    draw.rounded_rectangle([(60, sy + 10), (w - 60, sy + 55)], radius=8, fill=(241, 245, 249, 255))
    draw.text((75, sy + 20), "Conforme Consensus ESC 2023 & Programme Officiel R\u00e9sidanat", font=get_font(15, bold=True), fill=(100, 116, 139, 255))

    # 4. Input bar bas
    draw.rectangle([(0, h - 120), (w, h)], fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=1)
    draw.rounded_rectangle([(35, h - 95), (w - 110, h - 25)], radius=24, fill=(241, 245, 249, 255))
    draw.text((65, h - 68), "Posez votre question clinique (ex: posologie cordarone)...", font=get_font(18, bold=False), fill=(148, 163, 184, 255))
    # Send button
    draw.ellipse([(w - 95, h - 90), (w - 40, h - 35)], fill=(14, 165, 233, 255))
    # Clean arrow
    draw.polygon([(w - 74, h - 70), (w - 56, h - 62), (w - 74, h - 54)], fill=(255, 255, 255, 255))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    im.save(output_path, "PNG", quality=95)
    print(f"Generated clean Mobile Clinical screenshot: {output_path}")


if __name__ == "__main__":
    generate_qcm_desktop_screenshot("assets/screenshots/desktop/revision_qcm_pc.png")
    generate_vidal_desktop_screenshot("assets/screenshots/desktop/prescription_audit_pc.png")
    generate_mobile_clinical_screenshot("assets/screenshots/mobile/clinical_copilot_mobile.png")
    generate_mobile_clinical_screenshot("assets/screenshots/mobile/ai_copilot_mobile.png")
    print("All pristine screenshots generated successfully!")
