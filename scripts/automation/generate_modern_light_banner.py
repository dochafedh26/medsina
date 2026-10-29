#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modern Light Infography Generator for Medsina (2026 Edition)
============================================================
Generates ultra-modern, crisp, light-themed 1080x1080 marketing banners.
Features:
- Premium pastel mesh-gradient lighting (soft teal, blue, indigo, emerald)
- Subtle geometric dot-grid texture
- Slate-900 high-contrast typography
- 4 Bento Feature Cards with ambient soft shadows
- Realistic Ultra-Slim Laptop & Mobile Duo Mockup
- Platform Badges (Web, Windows, Android)
- Full QCM Quiz layout for exam prep posts
"""

import os
import re
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ARTIFACT_DIR = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0ba098d1-adef-41a0-8ca2-353fed62237c")
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
SAMPLE_OUTPUT = str(ARTIFACT_DIR / "sample_light_modern_infography.png")
SAMPLE_QCM_OUTPUT = str(ARTIFACT_DIR / "sample_light_modern_qcm.png")

# ---------------------------------------------------------------------------
# COLOR PALETTES (Light & Vibrant Pastel Mesh Orbs)
# ---------------------------------------------------------------------------

LIGHT_THEMES = {
    "teal": {
        "orbs": [
            ((620, -100), (1150, 480), (186, 230, 253, 140)),  # Sky
            ((700, -40), (1050, 350), (204, 251, 241, 160)),   # Cyan
            ((-120, 380), (450, 950), (224, 231, 255, 130)),  # Indigo
            ((720, 720), (1180, 1150), (209, 250, 229, 130)), # Mint
        ],
        "accent": (13, 148, 136),
        "tag_bg": (224, 242, 254),
        "tag_border": (186, 230, 253),
        "tag_text": (2, 132, 199),
    },
    "blue": {
        "orbs": [
            ((600, -80), (1120, 450), (191, 219, 254, 150)),
            ((680, -20), (1020, 330), (224, 231, 255, 160)),
            ((-100, 350), (420, 900), (186, 230, 253, 140)),
            ((700, 700), (1150, 1120), (219, 234, 254, 140)),
        ],
        "accent": (2, 132, 199),
        "tag_bg": (239, 246, 255),
        "tag_border": (191, 219, 254),
        "tag_text": (29, 78, 216),
    },
    "purple": {
        "orbs": [
            ((600, -80), (1120, 450), (233, 213, 255, 150)),
            ((680, -20), (1020, 330), (243, 232, 255, 160)),
            ((-100, 350), (420, 900), (224, 231, 255, 140)),
            ((700, 700), (1150, 1120), (245, 208, 254, 130)),
        ],
        "accent": (124, 58, 237),
        "tag_bg": (245, 243, 255),
        "tag_border": (221, 214, 254),
        "tag_text": (109, 40, 217),
    },
    "emerald": {
        "orbs": [
            ((600, -80), (1120, 450), (167, 243, 208, 150)),
            ((680, -20), (1020, 330), (204, 251, 241, 160)),
            ((-100, 350), (420, 900), (236, 253, 245, 140)),
            ((700, 700), (1150, 1120), (209, 250, 229, 140)),
        ],
        "accent": (5, 150, 105),
        "tag_bg": (236, 253, 245),
        "tag_border": (167, 243, 208),
        "tag_text": (4, 120, 87),
    },
}

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

def clean_text_for_image(text: str) -> str:
    """Removes raw emoji codepoints that cause missing glyph square boxes on Windows."""
    if not text:
        return ""
    # Strip emojis and pictographs
    cleaned = re.sub(r'[\U00010000-\U0010ffff]', '', text)
    cleaned = re.sub(r'[\u2600-\u26ff\u2700-\u27bf]', '', cleaned)
    # Clean redundant spaces
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned


def get_font(size: int, bold: bool = False):
    font_names = (
        ["segoeuib.ttf", "arialbd.ttf"] if bold else ["segoeui.ttf", "arial.ttf"]
    )
    for name in font_names:
        p = Path(r"C:\Windows\Fonts") / name
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except Exception:
                pass
    return ImageFont.load_default()


def create_ambient_shadow(width, height, radius=20, blur=18, offset_y=8, shadow_alpha=35):
    """Generates a realistic multi-layer ambient drop shadow."""
    margin = blur * 2 + 20
    sw = width + margin * 2
    sh = height + margin * 2
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle(
        [(margin, margin + offset_y), (margin + width, margin + height + offset_y)],
        radius=radius,
        fill=(15, 23, 42, shadow_alpha),
    )
    img = img.filter(ImageFilter.GaussianBlur(blur))
    return img, margin


def resolve_asset_path(rel_or_abs: Optional[str]) -> Optional[Path]:
    if not rel_or_abs:
        return None
    p = Path(rel_or_abs)
    if p.exists():
        return p
    # Search common workspace locations
    roots = [
        Path.cwd(),
        Path.cwd() / "medsina",
        Path(r"d:\REVISION RESIDANAT\ressources\residanat-blida-2027"),
        Path(r"d:\REVISION RESIDANAT\ressources\residanat-blida-2027\medsina"),
    ]
    for r in roots:
        cand = r / rel_or_abs
        if cand.exists():
            return cand
    return None


# ---------------------------------------------------------------------------
# MAIN MODERN LIGHT BANNER GENERATOR
# ---------------------------------------------------------------------------

def build_modern_light_banner(
    data: Optional[Dict[str, Any]] = None,
    output_path: Optional[str] = None,
    app_version: str = "v1.0.26",
) -> str:
    """
    Renders a stunning 1080x1080 modern light banner for Medsina announcements,
    version releases, and feature showcases.
    """
    if data is None:
        data = {}
    if output_path is None:
        output_path = SAMPLE_OUTPUT

    width, height = 1080, 1080

    theme_key = data.get("theme", "teal")
    if theme_key not in LIGHT_THEMES:
        theme_key = "teal"
    theme = LIGHT_THEMES[theme_key]

    # 1. Base Canvas (Soft Warm White #F8FAFC)
    canvas = Image.new("RGBA", (width, height), (248, 250, 252, 255))

    # 2. Add Pastel Mesh Light Orbs in Background
    orb_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb_layer)

    for box_tl, box_br, col in theme["orbs"]:
        orb_draw.ellipse([box_tl, box_br], fill=col)

    orb_layer = orb_layer.filter(ImageFilter.GaussianBlur(110))
    canvas = Image.alpha_composite(canvas, orb_layer)

    # 3. Add Geometric Dot-Grid Texture (Subtle tech watermark)
    dot_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dot_draw = ImageDraw.Draw(dot_layer)
    for x in range(40, width - 40, 36):
        for y in range(40, height - 40, 36):
            dot_draw.ellipse([(x, y), (x + 2, y + 2)], fill=(148, 163, 184, 50))
    canvas = Image.alpha_composite(canvas, dot_layer)

    draw = ImageDraw.Draw(canvas)

    # 4. Fonts
    f_brand = get_font(25, bold=True)
    f_brand_sub = get_font(14, bold=False)
    f_pill = get_font(13, bold=True)
    f_hero = get_font(40, bold=True)
    f_hero_sub = get_font(18, bold=False)
    f_card_num = get_font(13, bold=True)
    f_card_title = get_font(17, bold=True)
    f_card_desc = get_font(13, bold=False)
    f_footer_label = get_font(14, bold=True)
    f_footer_btn = get_font(13, bold=True)

    # 5. Header Bar (Glassmorphism Pill)
    header_w = width - 110
    header_h = 76
    header_x = 55
    header_y = 45

    # Header shadow
    h_shadow, h_m = create_ambient_shadow(header_w, header_h, radius=20, blur=14, offset_y=4, shadow_alpha=25)
    canvas.paste(h_shadow, (header_x - h_m, header_y - h_m), h_shadow)

    # Header background
    header_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(header_layer)
    h_draw.rounded_rectangle(
        [(header_x, header_y), (header_x + header_w, header_y + header_h)],
        radius=20,
        fill=(255, 255, 255, 240),
        outline=(255, 255, 255, 255),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, header_layer)
    draw = ImageDraw.Draw(canvas)

    # Header Logo
    logo_path = resolve_asset_path("assets/medsina-icon.png")
    if logo_path and logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((48, 48), Image.Resampling.LANCZOS)
            canvas.paste(logo_img, (header_x + 18, header_y + 14), logo_img)
        except Exception:
            pass

    draw.text((header_x + 76, header_y + 16), "MEDSINA", font=f_brand, fill=(15, 23, 42))
    draw.text((header_x + 76, header_y + 44), "Plateforme Médicale Globale • Résidanat Blida & National", font=f_brand_sub, fill=(100, 116, 139))

    # Version Pill inside Header
    display_ver = f"{app_version.upper()} OFFICIEL" if "OFFICIEL" not in app_version.upper() else app_version.upper()
    bbox_ver = f_pill.getbbox(display_ver)
    v_pill_w = (bbox_ver[2] - bbox_ver[0]) + 46
    v_pill_h = 36
    v_pill_x = header_x + header_w - v_pill_w - 18
    v_pill_y = header_y + 20
    draw.rounded_rectangle(
        [(v_pill_x, v_pill_y), (v_pill_x + v_pill_w, v_pill_y + v_pill_h)],
        radius=18,
        fill=(240, 253, 250),
        outline=(153, 246, 228),
        width=1,
    )
    # Green pulse dot
    draw.ellipse([(v_pill_x + 14, v_pill_y + 13), (v_pill_x + 22, v_pill_y + 21)], fill=(16, 185, 129))
    draw.text((v_pill_x + 30, v_pill_y + 10), display_ver, font=f_pill, fill=(13, 148, 136))

    # 6. Hero Title Area
    hero_y = 146

    # Tag Badge
    raw_badge = clean_text_for_image(data.get("badge", "MAJ MAJEURE • SYNCHRONISATION MULTI-APPAREILS & OFFLINE"))
    bbox_t = f_pill.getbbox(raw_badge)
    tw = (bbox_t[2] - bbox_t[0]) + 28
    draw.rounded_rectangle(
        [(55, hero_y), (55 + tw, hero_y + 30)],
        radius=8,
        fill=theme["tag_bg"],
        outline=theme["tag_border"],
        width=1,
    )
    draw.text((69, hero_y + 7), raw_badge, font=f_pill, fill=theme["tag_text"])

    # Hero Main Title
    raw_title = clean_text_for_image(data.get("title", "Double Sauvegarde Cloud & Mode Hors-Ligne"))
    draw.text((55, hero_y + 42), raw_title, font=f_hero, fill=(15, 23, 42))

    # Hero Subtitle
    raw_sub = clean_text_for_image(
        data.get("subtitle", "Passez de votre PC Windows à votre mobile Android sans perte • Révision 100% autonome à l'hôpital")
    )
    draw.text((55, hero_y + 94), raw_sub, font=f_hero_sub, fill=(71, 85, 105))

    # 7. Left Side: 4 Modern Bento Cards
    bento_x = 55
    bento_y = 300
    bento_w = 460
    bento_h = 135

    raw_points = data.get("points") or [
        "Double Sauvegarde Automatique : Vos sessions sur-mesure, notes QCM, avancement et cartes FSRS sont synchronisés en direct sur Supabase.",
        "Continuité Multi-Appareils : Commencez une session sur votre PC portable Windows et reprenez-la sur votre smartphone ou tablette Android.",
        "Mode Hors-Ligne à la Demande : Téléchargez un cours ou tout un pack module en 1 clic pour réviser aux urgences ou en garde sans internet.",
        "Gestion du Stockage & Lecteur 0s : Suivi précis des Mo consommés, ouverture immédiate des PDF enregistrés et option Wi-Fi uniquement.",
    ]

    card_palettes = [
        {"color": (14, 165, 233), "bg_accent": (240, 249, 255)},  # Sky blue
        {"color": (99, 102, 241), "bg_accent": (238, 242, 255)},  # Indigo
        {"color": (16, 185, 129), "bg_accent": (236, 253, 245)},  # Emerald
        {"color": (245, 158, 11), "bg_accent": (254, 243, 199)},  # Amber
    ]

    for i, p_text in enumerate(raw_points[:4]):
        cy = bento_y + i * (bento_h + 16)
        c_style = card_palettes[i % len(card_palettes)]

        # Extract title and desc
        clean_p = clean_text_for_image(p_text)
        if " : " in clean_p:
            c_title, c_desc = clean_p.split(" : ", 1)
        elif ":" in clean_p:
            c_title, c_desc = clean_p.split(":", 1)
        else:
            words = clean_p.split()
            c_title = " ".join(words[:3])
            c_desc = " ".join(words[3:])

        # Ambient Shadow for Card
        card_shadow, c_m = create_ambient_shadow(bento_w, bento_h, radius=18, blur=12, offset_y=4, shadow_alpha=20)
        canvas.paste(card_shadow, (bento_x - c_m, cy - c_m), card_shadow)

        # Card Base (Crisp White with ultra-subtle border)
        card_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        c_draw = ImageDraw.Draw(card_layer)
        c_draw.rounded_rectangle(
            [(bento_x, cy), (bento_x + bento_w, cy + bento_h)],
            radius=18,
            fill=(255, 255, 255, 245),
            outline=(226, 232, 240, 255),
            width=2,
        )
        canvas = Image.alpha_composite(canvas, card_layer)
        draw = ImageDraw.Draw(canvas)

        # Number Badge Pill
        pill_w = 42
        pill_h = 32
        px = bento_x + 16
        py = cy + 16
        draw.rounded_rectangle(
            [(px, py), (px + pill_w, py + pill_h)],
            radius=8,
            fill=c_style["bg_accent"],
            outline=c_style["color"],
            width=1,
        )
        draw.text((px + 12, py + 8), f"0{i+1}", font=f_card_num, fill=c_style["color"])

        # Title
        draw.text((bento_x + 68, cy + 22), c_title.strip(), font=f_card_title, fill=(15, 23, 42))

        # Description (2-3 lines wrapping)
        desc_words = c_desc.strip().split()
        lines = []
        cur = []
        for w in desc_words:
            test = " ".join(cur + [w])
            if f_card_desc.getbbox(test)[2] > 410:
                lines.append(" ".join(cur))
                cur = [w]
            else:
                cur.append(w)
        if cur:
            lines.append(" ".join(cur))

        dy = cy + 58
        for l in lines[:3]:
            draw.text((bento_x + 18, dy), l, font=f_card_desc, fill=(71, 85, 105))
            dy += 20

    # 8. Right Side: Modern Laptop Mockup on Elevated Pedestal
    sc_path = resolve_asset_path(data.get("screenshot_desktop") or "assets/screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png")
    if not sc_path or not sc_path.exists():
        sc_path = resolve_asset_path("assets/screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png")

    if sc_path and sc_path.exists():
        try:
            screen_img = Image.open(sc_path).convert("RGBA")

            mockup_w = 490
            mockup_h = 320
            mockup_x = 540
            mockup_y = 310

            screen_inner_w = mockup_w - 24
            screen_inner_h = mockup_h - 26

            screen_resized = screen_img.resize((screen_inner_w, screen_inner_h), Image.Resampling.LANCZOS)

            # Build Laptop Top Lid
            lid = Image.new("RGBA", (mockup_w, mockup_h), (0, 0, 0, 0))
            lid_draw = ImageDraw.Draw(lid)

            lid_draw.rounded_rectangle(
                [(0, 0), (mockup_w, mockup_h)],
                radius=16,
                fill=(30, 41, 59),
                outline=(51, 65, 85),
                width=2,
            )
            lid.paste(screen_resized, (12, 14))

            # Glass reflection
            gloss = Image.new("RGBA", (mockup_w, mockup_h), (0, 0, 0, 0))
            g_draw = ImageDraw.Draw(gloss)
            g_draw.polygon([(0, 0), (mockup_w // 2, 0), (0, mockup_h)], fill=(255, 255, 255, 20))
            lid = Image.alpha_composite(lid, gloss)

            # Laptop Base
            base_w = mockup_w + 50
            base_h = 16
            base_x = mockup_x - 25
            base_y = mockup_y + mockup_h

            floor_shadow = Image.new("RGBA", (base_w + 80, 50), (0, 0, 0, 0))
            fs_draw = ImageDraw.Draw(floor_shadow)
            fs_draw.ellipse([(10, 10), (base_w + 70, 40)], fill=(15, 23, 42, 65))
            floor_shadow = floor_shadow.filter(ImageFilter.GaussianBlur(16))
            canvas.paste(floor_shadow, (base_x - 40, base_y - 10), floor_shadow)

            canvas.paste(lid, (mockup_x, mockup_y), lid)
            draw = ImageDraw.Draw(canvas)

            # Chassis
            draw.rounded_rectangle(
                [(base_x, base_y), (base_x + base_w, base_y + base_h)],
                radius=8,
                fill=(203, 213, 225),
                outline=(148, 163, 184),
                width=1,
            )
            # Trackpad notch
            draw.rounded_rectangle(
                [(base_x + base_w // 2 - 40, base_y), (base_x + base_w // 2 + 40, base_y + 4)],
                radius=2,
                fill=(148, 163, 184),
            )

            # Right Bottom Feature Card (Visual Spotlight)
            spot_w = 490
            spot_h = 240
            spot_x = 540
            spot_y = base_y + 40

            spot_shadow, sm = create_ambient_shadow(spot_w, spot_h, radius=20, blur=14, offset_y=6, shadow_alpha=25)
            canvas.paste(spot_shadow, (spot_x - sm, spot_y - sm), spot_shadow)

            spot_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
            s_draw = ImageDraw.Draw(spot_layer)
            s_draw.rounded_rectangle(
                [(spot_x, spot_y), (spot_x + spot_w, spot_y + spot_h)],
                radius=20,
                fill=(255, 255, 255, 250),
                outline=(226, 232, 240),
                width=2,
            )
            canvas = Image.alpha_composite(canvas, spot_layer)
            draw = ImageDraw.Draw(canvas)

            f_spot_h = get_font(18, bold=True)
            f_spot_sub = get_font(13, bold=False)

            sp_title = clean_text_for_image(data.get("spotlight_title", "Architecture Hybride Cloud + Sandbox Sécurisée"))
            sp_sub = clean_text_for_image(data.get("spotlight_sub", "Conforme aux besoins intenses des concours et des gardes hospitalières"))

            draw.text((spot_x + 20, spot_y + 20), sp_title, font=f_spot_h, fill=(15, 23, 42))
            draw.text((spot_x + 20, spot_y + 48), sp_sub, font=f_spot_sub, fill=(100, 116, 139))

            # 3 Mini Status Pills (Zero overflow, exact dynamic centering)
            pills = [
                ("Cloud Sync Supabase", (240, 253, 250), (13, 148, 136), (16, 185, 129)),
                ("Cache Chiffré Local", (238, 242, 255), (79, 70, 229), (99, 102, 241)),
                ("Mode Wi-Fi Éco", (254, 243, 199), (180, 83, 9), (245, 158, 11)),
            ]

            pill_widths = []
            for title, _, _, _ in pills:
                b = f_pill.getbbox(title)
                pill_widths.append((b[2] - b[0]) + 36)

            total_pills_w = sum(pill_widths) + (len(pills) - 1) * 8
            start_px = spot_x + max(16, (spot_w - total_pills_w) // 2)
            py = spot_y + 85

            cur_px = start_px
            for idx, (title, bg_col, text_col, dot_col) in enumerate(pills):
                pw = pill_widths[idx]
                draw.rounded_rectangle(
                    [(cur_px, py), (cur_px + pw, py + 32)],
                    radius=16,
                    fill=bg_col,
                    outline=text_col,
                    width=1,
                )
                draw.ellipse([(cur_px + 10, py + 12), (cur_px + 18, py + 20)], fill=dot_col)
                draw.text((cur_px + 24, py + 8), title, font=f_pill, fill=text_col)
                cur_px += pw + 8

            # Highlights stats line
            f_stat_val = get_font(26, bold=True)
            f_stat_lbl = get_font(12, bold=False)

            stats = data.get("stats") or [
                ("47", "Modules Clés"),
                ("1 205", "Cours Structurés"),
                ("0s", "Temps d'Ouverture"),
            ]
            st_x = spot_x + 30
            st_y = spot_y + 145
            for val, lbl in stats:
                draw.text((st_x, st_y), str(val), font=f_stat_val, fill=theme["accent"])
                draw.text((st_x, st_y + 36), clean_text_for_image(str(lbl)), font=f_stat_lbl, fill=(100, 116, 139))
                st_x += 150

        except Exception as e:
            print(f"Error rendering mockup in modern banner: {e}")

    # 9. Bottom Footer Bar (Elevated Floating Dock)
    footer_w = width - 110
    footer_h = 76
    footer_x = 55
    footer_y = height - footer_h - 40

    foot_shadow, f_m = create_ambient_shadow(footer_w, footer_h, radius=22, blur=16, offset_y=4, shadow_alpha=30)
    canvas.paste(foot_shadow, (footer_x - f_m, footer_y - f_m), foot_shadow)

    foot_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ft_draw = ImageDraw.Draw(foot_layer)
    ft_draw.rounded_rectangle(
        [(footer_x, footer_y), (footer_x + footer_w, footer_y + footer_h)],
        radius=22,
        fill=(15, 23, 42, 250),
        outline=(51, 65, 85, 255),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, foot_layer)
    draw = ImageDraw.Draw(canvas)

    # Footer CTA Content
    draw.text((footer_x + 28, footer_y + 16), "DISPONIBLE DÈS MAINTENANT", font=f_footer_label, fill=(45, 212, 191))
    draw.text((footer_x + 28, footer_y + 42), "Accédez à Medsina sur tous vos écrans", font=f_brand_sub, fill=(148, 163, 184))

    # Platform Badges
    platforms = [
        ("Web Direct", (30, 41, 59), (56, 189, 248)),
        ("Windows (.exe)", (30, 41, 59), (56, 189, 248)),
        ("Android (.apk)", (13, 148, 136), (45, 212, 191)),
    ]
    p_right_x = footer_x + footer_w - 20
    for title, col, dot_col in reversed(platforms):
        bbox_btn = f_footer_btn.getbbox(title)
        bw = (bbox_btn[2] - bbox_btn[0]) + 34
        bx = p_right_x - bw
        by = footer_y + 18
        draw.rounded_rectangle(
            [(bx, by), (bx + bw, by + 40)],
            radius=12,
            fill=col,
            outline=(71, 85, 105) if col != (13, 148, 136) else (45, 212, 191),
            width=1,
        )
        draw.ellipse([(bx + 10, by + 16), (bx + 18, by + 24)], fill=dot_col)
        draw.text((bx + 24, by + 12), title, font=f_footer_btn, fill=(255, 255, 255))
        p_right_x -= bw + 10

    # Save Output
    canvas = canvas.convert("RGB")
    canvas.save(output_path, "PNG", quality=95)
    print(f"Modern Light Banner saved: {output_path}")
    return str(output_path)


# ---------------------------------------------------------------------------
# MODERN LIGHT QCM QUIZ BANNER GENERATOR
# ---------------------------------------------------------------------------

def build_modern_qcm_banner(
    data: Dict[str, Any],
    output_path: Optional[str] = None,
    app_version: str = "v1.0.26",
) -> str:
    """
    Renders a crisp, modern light 1080x1080 quiz infography for real exam MCQs.
    """
    if output_path is None:
        output_path = SAMPLE_QCM_OUTPUT

    width, height = 1080, 1080
    qcm = data.get("qcm", {})

    theme_key = data.get("theme", "blue")
    if theme_key not in LIGHT_THEMES:
        theme_key = "blue"
    theme = LIGHT_THEMES[theme_key]

    # 1. Base Canvas & Orbs
    canvas = Image.new("RGBA", (width, height), (248, 250, 252, 255))
    orb_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb_layer)

    for box_tl, box_br, col in theme["orbs"]:
        orb_draw.ellipse([box_tl, box_br], fill=col)

    orb_layer = orb_layer.filter(ImageFilter.GaussianBlur(110))
    canvas = Image.alpha_composite(canvas, orb_layer)

    # Texture grid
    dot_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dot_draw = ImageDraw.Draw(dot_layer)
    for x in range(40, width - 40, 36):
        for y in range(40, height - 40, 36):
            dot_draw.ellipse([(x, y), (x + 2, y + 2)], fill=(148, 163, 184, 50))
    canvas = Image.alpha_composite(canvas, dot_layer)

    draw = ImageDraw.Draw(canvas)

    # Fonts
    f_brand = get_font(25, bold=True)
    f_brand_sub = get_font(14, bold=False)
    f_pill = get_font(13, bold=True)
    f_title = get_font(32, bold=True)
    f_sub = get_font(18, bold=False)
    f_question = get_font(23, bold=True)
    f_opt_letter = get_font(19, bold=True)
    f_opt_text = get_font(18, bold=False)
    f_footer_label = get_font(15, bold=True)

    # 2. Header Glassmorphism Bar
    header_w = width - 110
    header_h = 76
    header_x = 55
    header_y = 45

    h_shadow, h_m = create_ambient_shadow(header_w, header_h, radius=20, blur=14, offset_y=4, shadow_alpha=25)
    canvas.paste(h_shadow, (header_x - h_m, header_y - h_m), h_shadow)

    h_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(h_layer)
    h_draw.rounded_rectangle(
        [(header_x, header_y), (header_x + header_w, header_y + header_h)],
        radius=20,
        fill=(255, 255, 255, 240),
        outline=(255, 255, 255, 255),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, h_layer)
    draw = ImageDraw.Draw(canvas)

    logo_path = resolve_asset_path("assets/medsina-icon.png")
    if logo_path and logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((48, 48), Image.Resampling.LANCZOS)
            canvas.paste(logo_img, (header_x + 18, header_y + 14), logo_img)
        except Exception:
            pass

    draw.text((header_x + 76, header_y + 16), "MEDSINA", font=f_brand, fill=(15, 23, 42))
    draw.text((header_x + 76, header_y + 44), "Plateforme Médicale • Archives & Annales Officielles", font=f_brand_sub, fill=(100, 116, 139))

    # Session Badge
    session_year = str(qcm.get("year") or "2024")
    sess_text = f"SESSION {session_year}"
    bbox_s = f_pill.getbbox(sess_text)
    sw = (bbox_s[2] - bbox_s[0]) + 36
    sx = header_x + header_w - sw - 18
    draw.rounded_rectangle([(sx, header_y + 20), (sx + sw, header_y + 56)], radius=18, fill=(240, 253, 250), outline=(153, 246, 228), width=1)
    draw.ellipse([(sx + 14, header_y + 33), (sx + 22, header_y + 41)], fill=(16, 185, 129))
    draw.text((sx + 28, header_y + 30), sess_text, font=f_pill, fill=(13, 148, 136))

    # 3. Tag Badge & Course Title
    hero_y = 145
    raw_source = clean_text_for_image(qcm.get("source", "CONCOURS OFFICIEL")).upper()
    tag_label = f"ANNALES RÉELLES • {raw_source}"
    bbox_tag = f_pill.getbbox(tag_label)
    tw = (bbox_tag[2] - bbox_tag[0]) + 28
    draw.rounded_rectangle([(55, hero_y), (55 + tw, hero_y + 30)], radius=8, fill=theme["tag_bg"], outline=theme["tag_border"], width=1)
    draw.text((69, hero_y + 7), tag_label, font=f_pill, fill=theme["tag_text"])

    course_name = clean_text_for_image(qcm.get("courseName", "Question d'Examen"))
    module_name = clean_text_for_image(qcm.get("moduleName", "Module Clinique"))
    draw.text((55, hero_y + 40), f"QCM : {course_name}", font=f_title, fill=(15, 23, 42))
    draw.text((55, hero_y + 85), f"Module : {module_name} • Concours National de Résidanat", font=f_sub, fill=(71, 85, 105))

    # 4. Elevated Question Card
    q_box_w = width - 110
    q_box_h = 160
    q_box_x = 55
    q_box_y = 280

    q_shadow, qm = create_ambient_shadow(q_box_w, q_box_h, radius=20, blur=14, offset_y=4, shadow_alpha=25)
    canvas.paste(q_shadow, (q_box_x - qm, q_box_y - qm), q_shadow)

    q_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    qd = ImageDraw.Draw(q_layer)
    qd.rounded_rectangle(
        [(q_box_x, q_box_y), (q_box_x + q_box_w, q_box_y + q_box_h)],
        radius=20,
        fill=(255, 255, 255, 250),
        outline=(226, 232, 240, 255),
        width=2,
    )
    # Left accent bar
    qd.rounded_rectangle([(q_box_x, q_box_y + 10), (q_box_x + 8, q_box_y + q_box_h - 10)], radius=4, fill=theme["accent"])
    canvas = Image.alpha_composite(canvas, q_layer)
    draw = ImageDraw.Draw(canvas)

    raw_q_text = clean_text_for_image(qcm.get("questionText", "")).strip()
    words = raw_q_text.split()
    lines = []
    cur = []
    for w in words:
        test = " ".join(cur + [w])
        if f_question.getbbox(test)[2] > (q_box_w - 70):
            lines.append(" ".join(cur))
            cur = [w]
        else:
            cur.append(w)
    if cur:
        lines.append(" ".join(cur))

    qy = q_box_y + 28
    for line in lines[:3]:
        draw.text((q_box_x + 32, qy), line, font=f_question, fill=(15, 23, 42))
        qy += 38

    # 5. Options Cards (A, B, C, D, E)
    options = qcm.get("options", [])[:5]
    opt_y = 465
    opt_h = 68
    opt_w = width - 110

    for i, opt in enumerate(options):
        oy = opt_y + i * (opt_h + 12)
        key = str(opt.get("key", chr(65 + i))).upper()
        text = clean_text_for_image(opt.get("text", "")).strip()

        # Option Card
        o_shadow, om = create_ambient_shadow(opt_w, opt_h, radius=14, blur=8, offset_y=3, shadow_alpha=15)
        canvas.paste(o_shadow, (55 - om, oy - om), o_shadow)

        o_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        od = ImageDraw.Draw(o_layer)
        od.rounded_rectangle(
            [(55, oy), (55 + opt_w, oy + opt_h)],
            radius=14,
            fill=(255, 255, 255, 245),
            outline=(226, 232, 240, 255),
            width=1,
        )
        canvas = Image.alpha_composite(canvas, o_layer)
        draw = ImageDraw.Draw(canvas)

        # Letter Pill
        letter_pill_w = 44
        letter_pill_h = 44
        lpx = 75
        lpy = oy + 12
        draw.rounded_rectangle(
            [(lpx, lpy), (lpx + letter_pill_w, lpy + letter_pill_h)],
            radius=10,
            fill=(241, 245, 249),
            outline=(203, 213, 225),
            width=1,
        )
        draw.text((lpx + 14, lpy + 10), key, font=f_opt_letter, fill=(30, 41, 59))

        # Option Text
        # Truncate or wrap if long
        if f_opt_text.getbbox(text)[2] > (opt_w - 120):
            text = text[:95] + "..."
        draw.text((135, oy + 22), text, font=f_opt_text, fill=(30, 41, 59))

    # 6. Bottom Floating Dock (Call To Action)
    dock_w = width - 110
    dock_h = 76
    dock_x = 55
    dock_y = height - dock_h - 40

    d_shadow, dm = create_ambient_shadow(dock_w, dock_h, radius=22, blur=16, offset_y=4, shadow_alpha=30)
    canvas.paste(d_shadow, (dock_x - dm, dock_y - dm), d_shadow)

    dock_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dock_layer)
    dd.rounded_rectangle(
        [(dock_x, dock_y), (dock_x + dock_w, dock_y + dock_h)],
        radius=22,
        fill=(15, 23, 42, 250),
        outline=(51, 65, 85, 255),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, dock_layer)
    draw = ImageDraw.Draw(canvas)

    draw.text((dock_x + 28, dock_y + 16), "VOTEZ VOTRE REPONSE EN COMMENTAIRE !", font=f_footer_label, fill=(45, 212, 191))
    draw.text((dock_x + 28, dock_y + 42), "Explication du Pr., corrigé officiel & pièges sur Medsina", font=f_brand_sub, fill=(148, 163, 184))

    # Right Button
    btn_text = "Voir le Corrigé Direct"
    bbox_btn = f_pill.getbbox(btn_text)
    bw = (bbox_btn[2] - bbox_btn[0]) + 38
    bx = dock_x + dock_w - bw - 20
    by = dock_y + 18
    draw.rounded_rectangle([(bx, by), (bx + bw, by + 40)], radius=12, fill=(13, 148, 136), outline=(45, 212, 191), width=1)
    draw.ellipse([(bx + 12, by + 16), (bx + 20, by + 24)], fill=(45, 212, 191))
    draw.text((bx + 26, by + 12), btn_text, font=f_pill, fill=(255, 255, 255))

    canvas = canvas.convert("RGB")
    canvas.save(output_path, "PNG", quality=95)
    print(f"Modern Light QCM Banner saved: {output_path}")
    return str(output_path)


if __name__ == "__main__":
    build_modern_light_banner()
