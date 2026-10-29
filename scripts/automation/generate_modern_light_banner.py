#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modern Light Infography Generator for Medsina (2026 Edition)
============================================================
Generates ultra-modern, crisp, light-themed 1080x1080 marketing banners.
Features:
- Premium pastel mesh-gradient lighting (soft teal & cyan)
- Subtle geometric dot-grid texture
- Slate-900 high-contrast typography
- 4 Bento Feature Cards with ambient soft shadows
- Realistic Ultra-Slim Laptop & Mobile Duo Mockup
- Platform Badges (Web, Windows, Android)
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ARTIFACT_DIR = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0ba098d1-adef-41a0-8ca2-353fed62237c")
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
SAMPLE_OUTPUT = str(ARTIFACT_DIR / "sample_light_modern_infography.png")


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

    # Dark inner drop
    draw.rounded_rectangle(
        [(margin, margin + offset_y), (margin + width, margin + height + offset_y)],
        radius=radius,
        fill=(15, 23, 42, shadow_alpha),
    )
    img = img.filter(ImageFilter.GaussianBlur(blur))
    return img, margin


def build_modern_light_banner(output_path: str = SAMPLE_OUTPUT):
    width, height = 1080, 1080

    # 1. Base Canvas (Soft Warm White #F8FAFC)
    canvas = Image.new("RGBA", (width, height), (248, 250, 252, 255))

    # 2. Add Pastel Mesh Light Orbs in Background
    orb_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb_layer)

    # Orb 1 (Top-Right): Soft Cyan / Teal Glow
    orb_draw.ellipse([(620, -100), (1150, 480)], fill=(186, 230, 253, 140))
    orb_draw.ellipse([(700, -40), (1050, 350)], fill=(204, 251, 241, 160))

    # Orb 2 (Center-Left): Soft Indigo / Lavender Glow
    orb_draw.ellipse([(-120, 380), (450, 950)], fill=(224, 231, 255, 130))
    orb_draw.ellipse([(50, 480), (380, 850)], fill=(219, 234, 254, 110))

    # Orb 3 (Bottom-Right): Subtle Mint Accent
    orb_draw.ellipse([(720, 720), (1180, 1150)], fill=(209, 250, 229, 130))

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
    logo_path = Path("medsina/assets/medsina-icon.png")
    if not logo_path.exists():
        logo_path = Path(r"d:\REVISION RESIDANAT\ressources\residanat-blida-2027\medsina\assets\medsina-icon.png")

    if logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((48, 48), Image.Resampling.LANCZOS)
            canvas.paste(logo_img, (header_x + 18, header_y + 14), logo_img)
        except Exception:
            pass

    draw.text((header_x + 76, header_y + 16), "MEDSINA", font=f_brand, fill=(15, 23, 42))
    draw.text((header_x + 76, header_y + 44), "Plateforme Médicale Globale • Résidanat Blida & National", font=f_brand_sub, fill=(100, 116, 139))

    # Version Pill inside Header
    v_pill_w = 150
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
    draw.ellipse([(v_pill_x + 14, v_pill_y + 13), (v_pill_x + 24, v_pill_y + 23)], fill=(16, 185, 129))
    draw.text((v_pill_x + 32, v_pill_y + 10), "v1.0.26 OFFICIEL", font=f_pill, fill=(13, 148, 136))

    # 6. Hero Title Area
    hero_y = 146

    # Tag Badge
    tag_text = "MAJ MAJEURE • SYNCHRONISATION MULTI-APPAREILS & OFFLINE"
    bbox_t = f_pill.getbbox(tag_text)
    tw = (bbox_t[2] - bbox_t[0]) + 28
    draw.rounded_rectangle(
        [(55, hero_y), (55 + tw, hero_y + 30)],
        radius=8,
        fill=(224, 242, 254),
        outline=(186, 230, 253),
        width=1,
    )
    draw.text((69, hero_y + 7), tag_text, font=f_pill, fill=(2, 132, 199))

    # Hero Main Title
    draw.text((55, hero_y + 42), "Double Sauvegarde Cloud & Mode Hors-Ligne", font=f_hero, fill=(15, 23, 42))
    draw.text(
        (55, hero_y + 94),
        "Passez de votre PC Windows à votre mobile Android sans perte • Révision 100% autonome à l'hôpital",
        font=f_hero_sub,
        fill=(71, 85, 105),
    )

    # 7. Left Side: 4 Modern Bento Cards
    bento_x = 55
    bento_y = 300
    bento_w = 460
    bento_h = 135

    cards_data = [
        {
            "num": "01",
            "icon": "☁️",
            "title": "Double Sauvegarde Automatique",
            "desc": "Vos sessions sur-mesure, notes QCM, avancement et cartes FSRS sont synchronisés en direct sur Supabase.",
            "color": (14, 165, 233),  # Sky blue
            "bg_accent": (240, 249, 255),
        },
        {
            "num": "02",
            "icon": "🔄",
            "title": "Continuité Multi-Appareils",
            "desc": "Commencez une session sur votre PC portable Windows et reprenez-la sur votre smartphone ou tablette Android.",
            "color": (99, 102, 241),  # Indigo
            "bg_accent": (238, 242, 255),
        },
        {
            "num": "03",
            "icon": "📴",
            "title": "Mode Hors-Ligne à la Demande",
            "desc": "Téléchargez un cours ou tout un pack module en 1 clic pour réviser aux urgences ou en garde sans internet.",
            "color": (16, 185, 129),  # Emerald
            "bg_accent": (236, 253, 245),
        },
        {
            "num": "04",
            "icon": "⚡",
            "title": "Gestion du Stockage & Lecteur 0s",
            "desc": "Suivi précis des Mo consommés, ouverture immédiate des PDF enregistrés et option Wi-Fi uniquement.",
            "color": (245, 158, 11),  # Amber
            "bg_accent": (254, 243, 199),
        },
    ]

    for i, c in enumerate(cards_data):
        cy = bento_y + i * (bento_h + 16)

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
            fill=c["bg_accent"],
            outline=c["color"],
            width=1,
        )
        draw.text((px + 12, py + 8), c["num"], font=f_card_num, fill=c["color"])

        # Title
        draw.text((bento_x + 68, cy + 22), c["title"], font=f_card_title, fill=(15, 23, 42))

        # Description (2-3 lines wrapping)
        desc_words = c["desc"].split()
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
    # Load Real Screenshot
    sc_path = Path("medsina/assets/screenshots/desktop/Screenshot 2026-10-20 175342_dashboard.png")
    if not sc_path.exists():
        sc_path = Path(r"d:\REVISION RESIDANAT\ressources\residanat-blida-2027\medsina\assets\screenshots\desktop\Screenshot 2026-10-20 175342_dashboard.png")

    if sc_path.exists():
        try:
            screen_img = Image.open(sc_path).convert("RGBA")

            # Mockup Dimensions
            mockup_w = 490
            mockup_h = 320
            mockup_x = 540
            mockup_y = 310

            # Screen inner area
            screen_inner_w = mockup_w - 24
            screen_inner_h = mockup_h - 26

            # Resize screenshot with LANCZOS
            screen_resized = screen_img.resize((screen_inner_w, screen_inner_h), Image.Resampling.LANCZOS)

            # Build Laptop Top Lid
            lid = Image.new("RGBA", (mockup_w, mockup_h), (0, 0, 0, 0))
            lid_draw = ImageDraw.Draw(lid)

            # Lid frame (Space Gray / Sleek Silver #1E293B frame)
            lid_draw.rounded_rectangle(
                [(0, 0), (mockup_w, mockup_h)],
                radius=16,
                fill=(30, 41, 59),
                outline=(51, 65, 85),
                width=2,
            )
            # Paste screen inside frame
            lid.paste(screen_resized, (12, 14))

            # Glass Gloss reflection diagonally
            gloss = Image.new("RGBA", (mockup_w, mockup_h), (0, 0, 0, 0))
            g_draw = ImageDraw.Draw(gloss)
            g_draw.polygon([(0, 0), (mockup_w // 2, 0), (0, mockup_h)], fill=(255, 255, 255, 20))
            lid = Image.alpha_composite(lid, gloss)

            # Laptop Base / Bottom Hinge
            base_w = mockup_w + 50
            base_h = 16
            base_x = mockup_x - 25
            base_y = mockup_y + mockup_h

            # Big soft floor shadow
            floor_shadow = Image.new("RGBA", (base_w + 80, 50), (0, 0, 0, 0))
            fs_draw = ImageDraw.Draw(floor_shadow)
            fs_draw.ellipse([(10, 10), (base_w + 70, 40)], fill=(15, 23, 42, 65))
            floor_shadow = floor_shadow.filter(ImageFilter.GaussianBlur(16))
            canvas.paste(floor_shadow, (base_x - 40, base_y - 10), floor_shadow)

            # Paste Lid
            canvas.paste(lid, (mockup_x, mockup_y), lid)
            draw = ImageDraw.Draw(canvas)

            # Draw Laptop Bottom Chassis (Sleek anodized aluminum)
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

            # Right Bottom Feature Card (Sync Status Visual Spotlight)
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

            # Spotlight Header
            f_spot_h = get_font(18, bold=True)
            f_spot_sub = get_font(13, bold=False)
            draw.text((spot_x + 20, spot_y + 20), "Architecture Hybride Cloud + Sandbox Sécurisée", font=f_spot_h, fill=(15, 23, 42))
            draw.text((spot_x + 20, spot_y + 48), "Conforme aux besoins intenses des concours et des gardes hospitalières", font=f_spot_sub, fill=(100, 116, 139))

            # 3 Mini Pills inside Spotlight (Zero overflow, crisp status dots)
            pills = [
                ("Cloud Sync Supabase", (240, 253, 250), (13, 148, 136), (16, 185, 129)),
                ("Cache Chiffré Local", (238, 242, 255), (79, 70, 229), (99, 102, 241)),
                ("Mode Wi-Fi Éco", (254, 243, 199), (180, 83, 9), (245, 158, 11)),
            ]

            # Measure total width to center pills inside card
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
                # Status indicator dot
                draw.ellipse([(cur_px + 10, py + 12), (cur_px + 18, py + 20)], fill=dot_col)
                draw.text((cur_px + 24, py + 8), title, font=f_pill, fill=text_col)
                cur_px += pw + 8

            # Highlights stats line
            f_stat_val = get_font(26, bold=True)
            f_stat_lbl = get_font(12, bold=False)

            stats = [
                ("47", "Modules Clés"),
                ("1 205", "Cours Structurés"),
                ("0s", "Temps d'Ouverture"),
            ]
            st_x = spot_x + 30
            st_y = spot_y + 145
            for val, lbl in stats:
                draw.text((st_x, st_y), val, font=f_stat_val, fill=(13, 148, 136))
                draw.text((st_x, st_y + 36), lbl, font=f_stat_lbl, fill=(100, 116, 139))
                st_x += 150

        except Exception as e:
            print(f"Error rendering mockup: {e}")

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
        fill=(15, 23, 42, 250),  # Sleek dark navy contrast bar
        outline=(51, 65, 85, 255),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, foot_layer)
    draw = ImageDraw.Draw(canvas)

    # Footer CTA Content
    draw.text((footer_x + 28, footer_y + 16), "DISPONIBLE DÈS MAINTENANT", font=f_footer_label, fill=(45, 212, 191))
    draw.text((footer_x + 28, footer_y + 42), "Accédez à Medsina sur tous vos écrans", font=f_brand_sub, fill=(148, 163, 184))

    # Download Platforms Badges on Right (Clean text with status dots)
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
    print(f"Sample Light Modern Infography generated: {output_path}")
    return output_path


if __name__ == "__main__":
    build_modern_light_banner()
