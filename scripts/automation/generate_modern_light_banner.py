#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pinterest 2026 Editorial Bento Grid Infographic Generator for Medsina (1080x1080)
=================================================================================
Generates ultra-modern, crisp, Pinterest-inspired 2026 Bento Grid 1080x1080
announcement infographics for Medsina:
- Multi-OS TrueType typography (Linux DejaVu/Liberation + Windows Segoe UI/Arial)
- Warm Alabaster canvas (#F8FAFC) with ambient pastel mesh orbs & micro dot-grid
- Floating Glass Header Pill with live status indicator ("DEFI LANCE SUR L'APP")
- Editorial Hero Announcement Card (Category Pill, Bold Wrapped Title, Subtitle)
- Asymmetric 2-Column Pinterest Bento Grid:
  * Left Top: High-Contrast Dark-Navy Hero Metric Tile (15+ QCMs / 20H00 / Annales)
  * Left Bottom: Soft Tinted 3-Pillar Badge Tile (Banque QCM Reelle, Chrono, Corrige)
  * Right Main: Structured "FICHE OFFICIELLE DU DEFI" 3-Step Bento Ticket
  * Right Bottom: Anti-Spoiler Callout Banner ("Exclusivement dans l'application Medsina")
- Elevated Dark-Navy Bottom CTA Dock ("medsina.medevsync.com • Android • Windows • Web")
"""

import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple
from PIL import Image, ImageDraw, ImageFont, ImageFilter

DEFAULT_OUT_DIR = Path(tempfile.gettempdir())
SAMPLE_OUTPUT = str(DEFAULT_OUT_DIR / "sample_light_modern_infography.png")
SAMPLE_QCM_OUTPUT = str(DEFAULT_OUT_DIR / "sample_light_modern_qcm.png")

# ---------------------------------------------------------------------------
# PINTEREST 2026 BENTO COLOR PALETTES
# ---------------------------------------------------------------------------

LIGHT_THEMES: Dict[str, Dict[str, Any]] = {
    "teal": {
        "orbs": [
            ((600, -100), (1160, 460), (153, 246, 228, 125)),
            ((-140, 340), (460, 960), (186, 230, 253, 120)),
            ((680, 680), (1180, 1160), (209, 250, 229, 130)),
        ],
        "accent": (13, 148, 136),        # #0D9488
        "accent_light": (45, 212, 191),  # #2DD4BF
        "soft_bg": (240, 253, 250),      # #F0FDFA
        "soft_border": (153, 246, 228),  # #99F6E4
        "tag_bg": (204, 251, 241),       # #CCFBF1
        "tag_border": (94, 234, 212),    # #5EEAD4
        "tag_text": (15, 118, 110),      # #0F766E
    },
    "cyan": {
        "orbs": [
            ((600, -100), (1160, 460), (165, 243, 252, 135)),
            ((-140, 340), (460, 960), (186, 230, 253, 125)),
            ((680, 680), (1180, 1160), (224, 242, 254, 130)),
        ],
        "accent": (2, 132, 199),         # #0284C7
        "accent_light": (56, 189, 248),  # #38BDF8
        "soft_bg": (240, 249, 255),      # #F0F9FF
        "soft_border": (186, 230, 253),  # #BAE6FD
        "tag_bg": (224, 242, 254),       # #E0F2FE
        "tag_border": (125, 211, 252),   # #7DD3FC
        "tag_text": (3, 105, 161),       # #0369A1
    },
    "blue": {
        "orbs": [
            ((600, -100), (1160, 460), (191, 219, 254, 140)),
            ((-140, 340), (460, 960), (224, 231, 255, 125)),
            ((680, 680), (1180, 1160), (219, 234, 254, 130)),
        ],
        "accent": (37, 99, 235),         # #2563EB
        "accent_light": (96, 165, 250),  # #60A5FA
        "soft_bg": (239, 246, 255),      # #EFF6FF
        "soft_border": (191, 219, 254),  # #BFDBFE
        "tag_bg": (219, 234, 254),       # #DBEAFE
        "tag_border": (147, 197, 253),   # #93C5FD
        "tag_text": (29, 78, 216),       # #1D4ED8
    },
    "indigo": {
        "orbs": [
            ((600, -100), (1160, 460), (199, 210, 254, 140)),
            ((-140, 340), (460, 960), (224, 231, 255, 130)),
            ((680, 680), (1180, 1160), (238, 242, 255, 135)),
        ],
        "accent": (79, 70, 229),         # #4F46E5
        "accent_light": (129, 140, 248), # #818CF8
        "soft_bg": (238, 242, 255),      # #EEF2FF
        "soft_border": (199, 210, 254),  # #C7D2FE
        "tag_bg": (224, 231, 255),       # #E0E7FF
        "tag_border": (165, 180, 252),   # #A5B4FC
        "tag_text": (67, 56, 202),       # #4338CA
    },
    "purple": {
        "orbs": [
            ((600, -100), (1160, 460), (233, 213, 255, 140)),
            ((-140, 340), (460, 960), (224, 231, 255, 130)),
            ((680, 680), (1180, 1160), (243, 232, 255, 130)),
        ],
        "accent": (124, 58, 237),        # #7C3AED
        "accent_light": (167, 139, 250), # #A78BFA
        "soft_bg": (245, 243, 255),      # #F5F3FF
        "soft_border": (221, 214, 254),  # #DDD6FE
        "tag_bg": (237, 233, 254),       # #EDE9FE
        "tag_border": (196, 181, 253),   # #C4B5FD
        "tag_text": (109, 40, 217),      # #6D28D9
    },
    "emerald": {
        "orbs": [
            ((600, -100), (1160, 460), (167, 243, 208, 135)),
            ((-140, 340), (460, 960), (204, 251, 241, 125)),
            ((680, 680), (1180, 1160), (209, 250, 229, 135)),
        ],
        "accent": (5, 150, 105),         # #059669
        "accent_light": (52, 211, 153),  # #34D399
        "soft_bg": (236, 253, 245),      # #ECFDF5
        "soft_border": (167, 243, 208),  # #A7F3D0
        "tag_bg": (209, 250, 229),       # #D1FAE5
        "tag_border": (110, 231, 183),   # #6EE7B7
        "tag_text": (4, 120, 87),        # #047857
    },
    "amber": {
        "orbs": [
            ((600, -100), (1160, 460), (253, 230, 138, 130)),
            ((-140, 340), (460, 960), (254, 243, 199, 125)),
            ((680, 680), (1180, 1160), (254, 215, 170, 120)),
        ],
        "accent": (217, 119, 6),         # #D97706
        "accent_light": (251, 191, 36),  # #FBBF24
        "soft_bg": (255, 251, 235),      # #FFFBEB
        "soft_border": (253, 230, 138),  # #FDE68A
        "tag_bg": (254, 243, 199),       # #FEF3C7
        "tag_border": (252, 211, 77),    # #FCD34D
        "tag_text": (180, 83, 9),        # #B45309
    },
    "rose": {
        "orbs": [
            ((600, -100), (1160, 460), (254, 205, 211, 135)),
            ((-140, 340), (460, 960), (252, 231, 243, 125)),
            ((680, 680), (1180, 1160), (255, 228, 230, 130)),
        ],
        "accent": (225, 29, 72),         # #E11D48
        "accent_light": (251, 113, 133), # #FB7185
        "soft_bg": (255, 241, 242),      # #FFF1F2
        "soft_border": (254, 205, 211),  # #FECDD3
        "tag_bg": (255, 228, 230),       # #FFE4E6
        "tag_border": (253, 164, 175),   # #FDA4AF
        "tag_text": (190, 18, 60),       # #BE123C
    },
}

# ---------------------------------------------------------------------------
# TYPOGRAPHY & DRAWING HELPERS
# ---------------------------------------------------------------------------

def clean_text_for_image(text: str) -> str:
    """Removes raw emoji codepoints and normalizes symbols so vector fonts render cleanly."""
    if not text:
        return ""
    text = (
        str(text)
        .replace("≥", ">=")
        .replace("≤", "<=")
        .replace("±", "+/-")
        .replace("→", "->")
        .replace("’", "'")
        .replace("‘", "'")
        .replace("«", '"')
        .replace("»", '"')
    )
    cleaned = re.sub(r'[\U00010000-\U0010ffff]', '', text)
    cleaned = re.sub(r'[\u2600-\u26ff\u2700-\u27bf]', '', cleaned)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned


def get_font(size: int, bold: bool = False):
    """Cross-platform TrueType font loader (Linux Ubuntu/Debian + Windows + macOS)."""
    candidates: List[Path] = []

    if sys.platform.startswith("win"):
        win_dir = Path(r"C:\Windows\Fonts")
        names = ["segoeuib.ttf", "arialbd.ttf", "calibrib.ttf"] if bold else ["segoeui.ttf", "arial.ttf", "calibri.ttf"]
        candidates.extend(win_dir / n for n in names)

    linux_paths = (
        [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
            "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
            "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        ]
        if bold
        else [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
            "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
            "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
        ]
    )
    candidates.extend(Path(p) for p in linux_paths)

    for p in candidates:
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except Exception:
                pass
    return ImageFont.load_default()


def wrap_text(text: str, font, max_width: int) -> List[str]:
    """Wraps text cleanly into lines that fit within max_width pixels."""
    text = clean_text_for_image(text)
    if not text:
        return []
    words = text.split()
    lines: List[str] = []
    cur: List[str] = []
    for w in words:
        test = " ".join(cur + [w])
        bbox = font.getbbox(test)
        if (bbox[2] - bbox[0]) > max_width and cur:
            lines.append(" ".join(cur))
            cur = [w]
        else:
            cur.append(w)
    if cur:
        lines.append(" ".join(cur))
    return lines


def create_ambient_shadow(width: int, height: int, radius: int = 24, blur: int = 16, offset_y: int = 6, shadow_alpha: int = 24):
    """Generates a soft ambient drop shadow for Bento cards."""
    margin = blur * 2 + 16
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


def paste_bento_card(
    canvas: Image.Image,
    x: int,
    y: int,
    w: int,
    h: int,
    radius: int = 26,
    fill: Tuple[int, int, int, int] = (255, 255, 255, 248),
    outline: Tuple[int, int, int, int] = (226, 232, 240, 255),
    outline_width: int = 2,
    shadow_alpha: int = 22,
) -> Image.Image:
    """Draws an elevated Bento card with ambient shadow onto canvas and returns updated canvas."""
    if shadow_alpha > 0:
        sh_img, sh_m = create_ambient_shadow(w, h, radius=radius, blur=14, offset_y=5, shadow_alpha=shadow_alpha)
        canvas.paste(sh_img, (x - sh_m, y - sh_m), sh_img)

    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle(
        [(x, y), (x + w, y + h)],
        radius=radius,
        fill=fill,
        outline=outline,
        width=outline_width,
    )
    return Image.alpha_composite(canvas, layer)


def resolve_asset_path(rel_or_abs: Optional[str]) -> Optional[Path]:
    if not rel_or_abs:
        return None
    p = Path(rel_or_abs)
    if p.exists():
        return p
    repo_root = Path(__file__).resolve().parents[2]
    for root in [repo_root, Path.cwd(), Path.cwd() / "medsina"]:
        cand = root / rel_or_abs
        if cand.exists():
            return cand
    return None


def draw_check_circle(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, bg_color: Tuple[int, int, int], fg_color: Tuple[int, int, int]):
    """Draws a crisp vector checkmark badge."""
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=bg_color)
    draw.line([(cx - r // 2, cy), (cx - r // 6, cy + r // 2), (cx + r // 2 + 1, cy - r // 3)], fill=fg_color, width=3)


def draw_target_icon(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color: Tuple[int, int, int]):
    """Draws a crisp vector bullseye target icon."""
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], outline=color, width=3)
    r2 = int(r * 0.58)
    draw.ellipse([(cx - r2, cy - r2), (cx + r2, cy + r2)], outline=color, width=2)
    r3 = max(3, int(r * 0.22))
    draw.ellipse([(cx - r3, cy - r3), (cx + r3, cy + r3)], fill=color)


# ---------------------------------------------------------------------------
# PINTEREST 2026 EDITORIAL BENTO BANNER GENERATOR (1080x1080)
# ---------------------------------------------------------------------------

def build_modern_light_banner(
    data: Optional[Dict[str, Any]] = None,
    output_path: Optional[str] = None,
    app_version: str = "v1.0.49",
) -> str:
    """
    Renders a Pinterest 2026 Editorial Bento Grid 1080x1080 announcement infographic.
    Designed to announce a launched/scheduled challenge or clinical session in Medsina
    without spoiling questions or answers.
    """
    if data is None:
        data = {}
    if output_path is None:
        output_path = SAMPLE_OUTPUT

    width, height = 1080, 1080
    theme_key = str(data.get("theme", "teal")).lower()
    theme = LIGHT_THEMES.get(theme_key, LIGHT_THEMES["teal"])
    accent = theme["accent"]
    accent_light = theme["accent_light"]

    # 1. Base Canvas (#F8FAFC) + Blurred Pastel Mesh Orbs + Micro Dot Grid
    canvas = Image.new("RGBA", (width, height), (248, 250, 252, 255))
    orb_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb_layer)
    for box_tl, box_br, col in theme["orbs"]:
        orb_draw.ellipse([box_tl, box_br], fill=col)
    orb_layer = orb_layer.filter(ImageFilter.GaussianBlur(105))
    canvas = Image.alpha_composite(canvas, orb_layer)

    dot_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dot_draw = ImageDraw.Draw(dot_layer)
    for x in range(44, width - 44, 34):
        for y in range(44, height - 44, 34):
            dot_draw.ellipse([(x, y), (x + 2, y + 2)], fill=(148, 163, 184, 48))
    canvas = Image.alpha_composite(canvas, dot_layer)

    # Fonts
    f_brand = get_font(24, bold=True)
    f_brand_sub = get_font(13, bold=False)
    f_pill = get_font(13, bold=True)
    f_hero_title = get_font(34, bold=True)
    f_hero_sub = get_font(17, bold=False)
    f_metric_big = get_font(44, bold=True)
    f_metric_lbl = get_font(14, bold=True)
    f_metric_sub = get_font(13, bold=False)
    f_card_hdr = get_font(14, bold=True)
    f_step_num = get_font(13, bold=True)
    f_step_title = get_font(17, bold=True)
    f_step_desc = get_font(14, bold=False)
    f_callout_title = get_font(15, bold=True)
    f_callout_sub = get_font(13, bold=False)
    f_footer_title = get_font(15, bold=True)
    f_footer_sub = get_font(13, bold=False)
    f_footer_btn = get_font(14, bold=True)

    # -----------------------------------------------------------------------
    # 2. TOP FLOATING GLASS HEADER BAR (y: 36..112)
    # -----------------------------------------------------------------------
    hx, hy, hw, hh = 48, 36, width - 96, 76
    canvas = paste_bento_card(
        canvas, hx, hy, hw, hh,
        radius=22,
        fill=(255, 255, 255, 242),
        outline=(226, 232, 240, 255),
        outline_width=2,
        shadow_alpha=20,
    )
    draw = ImageDraw.Draw(canvas)

    logo_path = resolve_asset_path("assets/medsina-icon.png")
    if logo_path and logo_path.exists():
        try:
            logo_img = Image.open(logo_path).convert("RGBA")
            logo_img.thumbnail((46, 46), Image.Resampling.LANCZOS)
            canvas.paste(logo_img, (hx + 18, hy + 15), logo_img)
            draw = ImageDraw.Draw(canvas)
        except Exception:
            pass

    draw.text((hx + 74, hy + 15), "MEDSINA", font=f_brand, fill=(15, 23, 42))
    draw.text((hx + 74, hy + 44), "Plateforme Médicale • Externat & Résidanat Algérie", font=f_brand_sub, fill=(100, 116, 139))

    # Right Live Pill inside Header
    status_pill = clean_text_for_image(data.get("status_pill") or f"{app_version.upper()} • DISPONIBLE SUR L'APP")
    bbox_sp = f_pill.getbbox(status_pill)
    sp_w = (bbox_sp[2] - bbox_sp[0]) + 46
    sp_h = 36
    sp_x = hx + hw - sp_w - 18
    sp_y = hy + 20
    draw.rounded_rectangle([(sp_x, sp_y), (sp_x + sp_w, sp_y + sp_h)], radius=18, fill=theme["soft_bg"], outline=theme["soft_border"], width=1)
    draw.ellipse([(sp_x + 14, sp_y + 13), (sp_x + 22, sp_y + 21)], fill=(16, 185, 129))
    draw.text((sp_x + 30, sp_y + 10), status_pill, font=f_pill, fill=theme["tag_text"])

    # -----------------------------------------------------------------------
    # 3. HERO EDITORIAL BENTO CARD (y: 128..332)
    # -----------------------------------------------------------------------
    hero_x, hero_y, hero_w, hero_h = 48, 128, width - 96, 204
    canvas = paste_bento_card(
        canvas, hero_x, hero_y, hero_w, hero_h,
        radius=28,
        fill=(255, 255, 255, 248),
        outline=(226, 232, 240, 255),
        outline_width=2,
        shadow_alpha=24,
    )
    draw = ImageDraw.Draw(canvas)

    # Left vertical accent stripe inside Hero card
    draw.rounded_rectangle(
        [(hero_x + 18, hero_y + 22), (hero_x + 26, hero_y + hero_h - 22)],
        radius=4,
        fill=accent,
    )

    # Category / Badge Pill
    raw_badge = clean_text_for_image(data.get("badge", "DÉFI 20H EXTERNAT • BANQUE QCM OFFICIELLE"))
    bbox_b = f_pill.getbbox(raw_badge)
    bw = min(hero_w - 160, (bbox_b[2] - bbox_b[0]) + 32)
    draw.rounded_rectangle(
        [(hero_x + 44, hero_y + 22), (hero_x + 44 + bw, hero_y + 54)],
        radius=10,
        fill=theme["tag_bg"],
        outline=theme["tag_border"],
        width=1,
    )
    draw.text((hero_x + 60, hero_y + 30), raw_badge, font=f_pill, fill=theme["tag_text"])

    # Right decorative target icon in Hero card
    draw_target_icon(draw, hero_x + hero_w - 54, hero_y + 54, 24, accent)

    # Hero Title (1 to 2 wrapped lines)
    raw_title = clean_text_for_image(data.get("title", "Défi QCM & Session Pédagogique Lancée"))
    title_lines = wrap_text(raw_title, f_hero_title, hero_w - 120)[:2]
    ty = hero_y + 66
    for line in title_lines:
        draw.text((hero_x + 44, ty), line, font=f_hero_title, fill=(15, 23, 42))
        ty += 42

    # Hero Subtitle
    raw_sub = clean_text_for_image(
        data.get("subtitle", "Un nouveau défi issu de la banque officielle des QCMs est disponible dans l'application Medsina.")
    )
    sub_lines = wrap_text(raw_sub, f_hero_sub, hero_w - 90)[:2]
    sy = max(ty + 4, hero_y + 152)
    for sline in sub_lines[:1]:
        draw.text((hero_x + 44, sy), sline, font=f_hero_sub, fill=(71, 85, 105))

    # -----------------------------------------------------------------------
    # 4. ASYMMETRIC 2-COLUMN PINTEREST BENTO GRID (y: 350..928)
    # -----------------------------------------------------------------------
    grid_y = 350
    left_x, left_w = 48, 372
    right_x, right_w = 438, width - 438 - 48  # 594 px

    # --- 4A. LEFT TOP: DARK-NAVY HIGH-CONTRAST HERO METRIC BENTO TILE ---
    lt_y, lt_h = grid_y, 280
    canvas = paste_bento_card(
        canvas, left_x, lt_y, left_w, lt_h,
        radius=28,
        fill=(15, 23, 42, 255),
        outline=(51, 65, 85, 255),
        outline_width=2,
        shadow_alpha=28,
    )
    draw = ImageDraw.Draw(canvas)

    # Subtle glowing accent pill inside dark tile
    metric_tag = clean_text_for_image(data.get("metric_tag", "BANQUE QCM OFFICIELLE"))
    bbox_mt = f_pill.getbbox(metric_tag)
    mt_w = (bbox_mt[2] - bbox_mt[0]) + 28
    draw.rounded_rectangle(
        [(left_x + 26, lt_y + 24), (left_x + 26 + mt_w, lt_y + 54)],
        radius=10,
        fill=(30, 41, 59),
        outline=accent_light,
        width=1,
    )
    draw.text((left_x + 40, lt_y + 31), metric_tag, font=f_pill, fill=accent_light)

    metric_big = clean_text_for_image(data.get("metric_value", "100% QCM"))
    draw.text((left_x + 26, lt_y + 72), metric_big, font=f_metric_big, fill=(255, 255, 255))

    metric_label = clean_text_for_image(data.get("metric_label", "100% Questions Réelles d'Annales"))
    ml_wrapped = wrap_text(metric_label, f_metric_lbl, left_w - 48)[:1]
    if ml_wrapped:
        draw.text((left_x + 26, lt_y + 132), ml_wrapped[0], font=f_metric_lbl, fill=accent_light)

    metric_desc = clean_text_for_image(
        data.get("metric_desc", "Sélection officielle issue des annales de la Faculté de Médecine avec corrigé détaillé.")
    )
    md_lines = wrap_text(metric_desc, f_metric_sub, left_w - 48)[:4]
    mdy = lt_y + 162
    for ml in md_lines:
        draw.text((left_x + 26, mdy), ml, font=f_metric_sub, fill=(148, 163, 184))
        mdy += 22

    # --- 4B. LEFT BOTTOM: SOFT TINTED 3-PILLAR CHECKLIST BENTO TILE ---
    lb_y, lb_h = lt_y + lt_h + 18, 280
    canvas = paste_bento_card(
        canvas, left_x, lb_y, left_w, lb_h,
        radius=28,
        fill=theme["soft_bg"] + (255,),
        outline=theme["soft_border"] + (255,),
        outline_width=2,
        shadow_alpha=18,
    )
    draw = ImageDraw.Draw(canvas)

    draw.text((left_x + 26, lb_y + 24), "INCLUS DANS CETTE SESSION", font=f_card_hdr, fill=theme["tag_text"])

    pillars = data.get("pillars") or [
        ("Questions Réelles", "Banque QCM officielle de la faculté"),
        ("Mode Examen Chrono", "Conditions réelles d'EMD notées sur /20"),
        ("Corrigé & Explications", "Analyse détaillée et pièges du Pr."),
    ]
    py = lb_y + 62
    for p_title, p_sub in pillars[:3]:
        draw_check_circle(draw, left_x + 40, py + 18, 13, accent, (255, 255, 255))
        draw.text((left_x + 64, py + 2), clean_text_for_image(p_title), font=f_step_title, fill=(15, 23, 42))
        sub_wrapped = wrap_text(p_sub, f_metric_sub, left_w - 84)[:1]
        if sub_wrapped:
            draw.text((left_x + 64, py + 26), sub_wrapped[0], font=f_metric_sub, fill=(71, 85, 105))
        py += 68

    # --- 4C. RIGHT MAIN: "CARTE OFFICIELLE DU DEFI" 3-STEP BENTO TICKET ---
    rt_y, rt_h = grid_y, 442
    canvas = paste_bento_card(
        canvas, right_x, rt_y, right_w, rt_h,
        radius=28,
        fill=(255, 255, 255, 250),
        outline=(226, 232, 240, 255),
        outline_width=2,
        shadow_alpha=24,
    )
    draw = ImageDraw.Draw(canvas)

    # Card Top Subheader
    draw.rounded_rectangle(
        [(right_x + 2, rt_y + 2), (right_x + right_w - 2, rt_y + 56)],
        radius=26,
        fill=(248, 250, 252),
    )
    draw.line([(right_x + 20, rt_y + 56), (right_x + right_w - 20, rt_y + 56)], fill=(226, 232, 240), width=1)
    draw.text((right_x + 28, rt_y + 20), "PROGRAMME & DETAILS DU DEFI SUR L'APPLICATION", font=f_card_hdr, fill=(51, 65, 85))

    raw_points = data.get("points") or [
        "Module & Promotion : Programme officiel de la Faculte de Medecine sur Medsina.",
        "Format de l'Epreuve : Serie de QCMs reels selectionnes depuis la banque officielle.",
        "Disponibilite : Defi lance et accessible immediatement sur l'application Medsina.",
    ]

    step_colors = [
        (accent, theme["tag_bg"]),
        ((79, 70, 229), (238, 242, 255)),
        ((5, 150, 105), (209, 250, 229)),
        ((217, 119, 6), (254, 243, 199)),
    ]

    pts_to_render = raw_points[:3]
    item_y = rt_y + 74
    item_h = 108

    for idx, pt in enumerate(pts_to_render):
        sc_fg, sc_bg = step_colors[idx % len(step_colors)]
        clean_pt = clean_text_for_image(pt)
        if " : " in clean_pt:
            st_title, st_desc = clean_pt.split(" : ", 1)
        elif ":" in clean_pt:
            st_title, st_desc = clean_pt.split(":", 1)
        else:
            st_title = f"Point Cle 0{idx + 1}"
            st_desc = clean_pt

        # Inner Bento Row Box
        row_x = right_x + 22
        row_w = right_w - 44
        draw.rounded_rectangle(
            [(row_x, item_y), (row_x + row_w, item_y + item_h)],
            radius=18,
            fill=(248, 250, 252),
            outline=(226, 232, 240),
            width=1,
        )

        # Number Badge
        nb_x, nb_y, nb_w, nb_h = row_x + 16, item_y + 18, 44, 34
        draw.rounded_rectangle([(nb_x, nb_y), (nb_x + nb_w, nb_y + nb_h)], radius=10, fill=sc_bg, outline=sc_fg, width=1)
        draw.text((nb_x + 11, nb_y + 8), f"0{idx + 1}", font=f_step_num, fill=sc_fg)

        # Step Title
        st_title_wrapped = wrap_text(st_title.strip(), f_step_title, row_w - 90)[:1]
        if st_title_wrapped:
            draw.text((row_x + 74, item_y + 16), st_title_wrapped[0], font=f_step_title, fill=(15, 23, 42))

        # Step Description (up to 2 lines)
        desc_lines = wrap_text(st_desc.strip(), f_step_desc, row_w - 90)[:2]
        dy = item_y + 44
        for dl in desc_lines:
            draw.text((row_x + 74, dy), dl, font=f_step_desc, fill=(71, 85, 105))
            dy += 21

        item_y += item_h + 14

    # --- 4D. RIGHT BOTTOM: ZERO-SPOILER / APP-EXCLUSIVE CALLOUT BENTO TILE ---
    rb_y, rb_h = rt_y + rt_h + 18, 118
    canvas = paste_bento_card(
        canvas, right_x, rb_y, right_w, rb_h,
        radius=24,
        fill=(254, 252, 232, 255),
        outline=(253, 224, 71, 255),
        outline_width=2,
        shadow_alpha=16,
    )
    draw = ImageDraw.Draw(canvas)

    # Left Icon Circle
    ic_cx, ic_cy = right_x + 48, rb_y + rb_h // 2
    draw.ellipse([(ic_cx - 24, ic_cy - 24), (ic_cx + 24, ic_cy + 24)], fill=(254, 240, 138), outline=(234, 179, 8), width=2)
    draw_target_icon(draw, ic_cx, ic_cy, 13, (161, 98, 7))

    callout_title = clean_text_for_image(
        data.get("callout_title", "Defi Lance & Disponible Exclusivement dans l'App Medsina")
    )
    callout_sub = clean_text_for_image(
        data.get("callout_sub", "Aucune question n'est devoilee ici : ouvrez l'application pour participer au defi en conditions reelles.")
    )
    draw.text((right_x + 86, rb_y + 22), callout_title, font=f_callout_title, fill=(113, 63, 18))
    cs_lines = wrap_text(callout_sub, f_callout_sub, right_w - 106)[:2]
    csy = rb_y + 48
    for csl in cs_lines:
        draw.text((right_x + 86, csy), csl, font=f_callout_sub, fill=(133, 77, 14))
        csy += 20

    # -----------------------------------------------------------------------
    # 5. BOTTOM FLOATING DARK-NAVY CTA DOCK (y: 948..1036)
    # -----------------------------------------------------------------------
    fx, fy, fw, fh = 48, 948, width - 96, 88
    canvas = paste_bento_card(
        canvas, fx, fy, fw, fh,
        radius=24,
        fill=(15, 23, 42, 252),
        outline=(51, 65, 85, 255),
        outline_width=2,
        shadow_alpha=28,
    )
    draw = ImageDraw.Draw(canvas)

    draw.text((fx + 28, fy + 20), "PARTICIPEZ AU DEFI MAINTENANT SUR MEDSINA", font=f_footer_title, fill=accent_light)
    draw.text((fx + 28, fy + 48), "Disponible sur Mobile Android (.apk), PC Windows (.exe) & Web Direct", font=f_footer_sub, fill=(148, 163, 184))

    # CTA Pill Button on Right
    cta_label = "medsina.medevsync.com  ->"
    bbox_cta = f_footer_btn.getbbox(cta_label)
    cta_w = (bbox_cta[2] - bbox_cta[0]) + 44
    cta_h = 46
    cta_x = fx + fw - cta_w - 22
    cta_y = fy + (fh - cta_h) // 2
    draw.rounded_rectangle(
        [(cta_x, cta_y), (cta_x + cta_w, cta_y + cta_h)],
        radius=14,
        fill=accent,
        outline=accent_light,
        width=1,
    )
    draw.text((cta_x + 22, cta_y + 13), cta_label, font=f_footer_btn, fill=(255, 255, 255))

    # Save Output
    out_dir = os.path.dirname(output_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    canvas.convert("RGB").save(output_path, "PNG", quality=96)
    print(f"Pinterest 2026 Bento Banner saved: {output_path}")
    return str(output_path)


# ---------------------------------------------------------------------------
# PINTEREST 2026 QCM CHALLENGE ANNOUNCEMENT BANNER (NO SPOILERS)
# ---------------------------------------------------------------------------

def build_modern_qcm_banner(
    data: Dict[str, Any],
    output_path: Optional[str] = None,
    app_version: str = "v1.0.49",
) -> str:
    """
    Renders a Pinterest 2026 Bento Grid announcement card for a real QCM challenge
    without spoiling the question or options on the social image.
    """
    if output_path is None:
        output_path = SAMPLE_QCM_OUTPUT

    qcm = data.get("qcm", {})
    source = clean_text_for_image(qcm.get("source") or "Annales Officielles Faculte")
    course_name = clean_text_for_image(qcm.get("courseName") or data.get("title") or "Cours Officiel")
    module_name = clean_text_for_image(qcm.get("moduleName") or data.get("subtitle") or "Module Medical")
    session_year = str(qcm.get("year") or "2024")
    opts_count = len(qcm.get("options") or []) or 5

    bento_payload = {
        "theme": data.get("theme", "blue"),
        "status_pill": f"DEFI QCM LANCE • SESSION {session_year}",
        "badge": f"DEFI QCM REEL • {source.upper()}",
        "title": f"Nouveau Defi QCM : {course_name}",
        "subtitle": f"Module {module_name} • Le defi est programme et disponible dans l'application Medsina",
        "metric_tag": "BANQUE QCM REELLE",
        "metric_value": f"SESSION {session_year}",
        "metric_label": f"Module : {module_name}",
        "metric_desc": f"Question officielle issue de {source} ({opts_count} propositions) avec correction detaillee dans l'App.",
        "points": [
            f"Module & Cours Cible : {module_name} — {course_name}",
            f"Source Officielle : {source} (Session {session_year}) — Banque de QCMs Medsina",
            "Rerelevez le Defi : Ouvrez l'application Medsina pour repondre et debloquer le corrige",
        ],
        "callout_title": "Le Defi QCM est Lance dans l'Application Medsina !",
        "callout_sub": "Connectez-vous sur l'application pour tenter ce QCM reel, verifier votre score et lire l'explication du Pr.",
    }
    return build_modern_light_banner(data=bento_payload, output_path=output_path, app_version=app_version)


if __name__ == "__main__":
    p1 = build_modern_light_banner()
    p2 = build_modern_qcm_banner({
        "theme": "teal",
        "qcm": {
            "source": "EMD Blida",
            "courseName": "Infarctus du Myocarde (SCA ST+)",
            "moduleName": "Cardiologie",
            "year": 2024,
            "options": [{"key": "A"}, {"key": "B"}, {"key": "C"}, {"key": "D"}, {"key": "E"}],
        }
    })
    print("Generated sample banners:", p1, p2)
