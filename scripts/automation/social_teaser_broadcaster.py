#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=============================================================================
MEDSINA SOCIAL TEASER BROADCASTER (Modern Light Theme & Multi-Channel)
=============================================================================
Diffuse automatiquement des teasers cliniques attractifs (anti-spoiler) lors
de la génération autonome de contenus médicaux :
- Conduites à Tenir (CAT)
- Mémentos de Garde Hospitalière
- Urgences & DCI (Nomenclature Algérie Saidal/PCH)
- Normes Biologiques & Seuils Critiques
- Fiches Résumés de Cours Officiels du Résidanat
- Perles Cliniques & Pièges du Concours

Canaux cibles :
1. Facebook Page Officielle « Medsina » (ID: 1449308354921826)
2. Facebook Page Communauté « Résidanat Blida 2027 » (ID: 1405719695953624)
3. Facebook Page Partenaire « MedevSync » (ID: 1329939320211198)
3. Telegram Canal Officiel « @medsina_officiel »
=============================================================================
"""

import os
import sys
import re
import json
import tempfile
import requests
from pathlib import Path
from typing import Dict, Any, Optional, List
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def strip_emojis_for_image(text: str) -> str:
    """Retire les émojis non supportés par les polices vectorielles pour éviter les carrés vides."""
    if not text:
        return ""
    # Remove surrogate pairs and standard emoji ranges
    emoji_pattern = re.compile(
        "["
        "\U00010000-\U0010ffff"
        "\u2600-\u27bf"
        "\u2300-\u23ff"
        "\u2b50-\u2b55"
        "\u3030-\u303d"
        "]+",
        flags=re.UNICODE
    )
    cleaned = emoji_pattern.sub("", text)
    # Clean redundant whitespace
    return re.sub(r"\s+", " ", cleaned).strip()

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Official URLs
OFFICIAL_WEB_URL = "https://medsina.medevsync.com"
OFFICIAL_APK_URL = "https://medsina.medevsync.com/download/medsina.apk"
OFFICIAL_WIN_URL = "https://medsina.medevsync.com"
OFFICIAL_TELEGRAM_URL = "https://t.me/medsina_officiel"

# Path to logo asset
REPO_ROOT = Path(__file__).resolve().parents[2]
LOGO_PATH = REPO_ROOT / "assets" / "medsina-logo.png"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://qzfssrhhuorljftpdvjm.supabase.co")
SUPABASE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    or os.environ.get("SUPABASE_KEY")
    or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4"
)


# =============================================================================
# 1. GESTION DES IDENTIFIANTS & CREDENTIALS
# =============================================================================

def get_social_credentials() -> Dict[str, str]:
    """
    Récupère les identifiants pour les deux pages Facebook et le bot Telegram :
    1. Variables d'environnement (si définies)
    2. Table Supabase admin_system_settings
    """
    creds = {
        "medsina_page_id": os.environ.get("FB_MEDSINA_PAGE_ID", "1449308354921826").strip(),
        "medsina_token": os.environ.get("FB_MEDSINA_PAGE_ACCESS_TOKEN", "").strip(),
        "blida_page_id": os.environ.get("FB_BLIDA_PAGE_ID", "1405719695953624").strip(),
        "blida_token": os.environ.get("FB_BLIDA_PAGE_ACCESS_TOKEN", "").strip(),
        "medevsync_page_id": os.environ.get("FB_MEDEVSYNC_PAGE_ID", "1329939320211198").strip(),
        "medevsync_token": os.environ.get("FB_MEDEVSYNC_PAGE_ACCESS_TOKEN", "").strip(),
        "telegram_token": os.environ.get("TELEGRAM_BOT_TOKEN", "").strip(),
        "telegram_channel": os.environ.get("TELEGRAM_CHANNEL_ID", "@medsina_officiel").strip(),
    }

    # Fetch missing from Supabase
    if not (creds["medsina_token"] and creds["blida_token"] and creds["medevsync_token"] and creds["telegram_token"]):
        try:
            url = f"{SUPABASE_URL}/rest/v1/admin_system_settings?select=setting_key,setting_value"
            headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
            r = requests.get(url, headers=headers, timeout=10)
            if r.status_code == 200:
                settings = {x["setting_key"]: x["setting_value"] for x in r.json() if isinstance(x, dict)}
                if not creds["medsina_token"]:
                    creds["medsina_token"] = (settings.get("facebook_medsina_page_access_token") or "").strip()
                if not creds["blida_token"]:
                    creds["blida_token"] = (settings.get("facebook_blida_page_access_token") or settings.get("facebook_page_access_token") or "").strip()
                if not creds["medevsync_token"]:
                    creds["medevsync_token"] = (settings.get("facebook_medevsync_page_access_token") or "").strip()
                if not creds["telegram_token"]:
                    creds["telegram_token"] = (settings.get("telegram_bot_token") or "").strip()
                if not creds["telegram_channel"] or creds["telegram_channel"] == "@medsina_officiel":
                    ch = (settings.get("telegram_channel_id") or "").strip()
                    if ch:
                        creds["telegram_channel"] = ch
        except Exception as e:
            print(f"⚠️ Avertissement : lecture des identifiants Supabase : {e}")

    return creds


# =============================================================================
# 2. MOTEUR GRAPHIQUE LIGHT THEME (1080x1080)
# =============================================================================

def get_font(size: int, bold: bool = False):
    font_paths = []
    if sys.platform.startswith("win"):
        font_dir = Path("C:/Windows/Fonts")
        if bold:
            font_paths = [
                font_dir / "segoeuib.ttf",
                font_dir / "arialbd.ttf",
                font_dir / "calibrib.ttf",
            ]
        else:
            font_paths = [
                font_dir / "segoeui.ttf",
                font_dir / "arial.ttf",
                font_dir / "calibri.ttf",
            ]
    else:
        linux_fonts = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        ]
        font_paths = [Path(p) for p in linux_fonts]

    for p in font_paths:
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = bbox
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)

def draw_pill(draw, x, y, text, font, bg_color, text_color, pad_h=16, pad_v=8, radius=12, border_color=None):
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    w = tw + pad_h * 2
    h = th + pad_v * 2
    draw_rounded_rect(draw, [x, y, x + w, y + h], radius=radius, fill=bg_color, outline=border_color, width=1)
    tx = x + pad_h - bbox[0]
    ty = y + pad_v - bbox[1]
    draw.text((tx, ty), text, font=font, fill=text_color)
    return w, h

def draw_lock_icon(draw, cx, cy, size=24, color=(180, 83, 9)):
    body_w = size * 0.8
    body_h = size * 0.7
    bx0 = cx - body_w / 2
    by0 = cy - body_h / 2 + size * 0.15
    draw.rounded_rectangle([bx0, by0, bx0 + body_w, by0 + body_h], radius=size * 0.18, fill=color)
    shackle_r = size * 0.28
    sx = cx
    sy = by0 - size * 0.05
    draw.arc([sx - shackle_r, sy - shackle_r * 2, sx + shackle_r, sy], start=180, end=0, fill=color, width=max(2, int(size * 0.16)))
    draw.ellipse([cx - size * 0.08, by0 + body_h * 0.35, cx + size * 0.08, by0 + body_h * 0.35 + size * 0.16], fill=(255, 255, 255))

def render_modern_light_banner(content_type: str, data: Dict[str, Any], output_path: str) -> str:
    """
    Génère l'affiche promotionnelle carrée (1080x1080) au design Light Theme ultra-moderne.
    """
    W, H = 1080, 1080
    
    THEMES = {
        "cat": {
            "category": "CONDUITE À TENIR CLINIQUE (CAT)",
            "primary": (13, 148, 136),     # Medical Teal #0D9488
            "pill_bg": (204, 251, 241),    # #CCFBF1
            "pill_text": (15, 118, 110),   # #0F766E
            "orb_color": (13, 148, 136, 22),
            "flow_steps": ["1. Diagnostic & Scope", "2. Échocardiographie", "3. Inotropes & PAM", "4. Revascularisation"]
        },
        "memento": {
            "category": "MÉMENTO DE GARDE HOSPITALIÈRE",
            "primary": (99, 102, 241),     # Indigo #6366F1
            "pill_bg": (238, 242, 255),    # #EEF2FF
            "pill_text": (67, 56, 202),    # #4338CA
            "orb_color": (99, 102, 241, 22),
            "flow_steps": ["1. Appel Garde 3h", "2. Tri & Gravité", "3. Gestes Réflexes", "4. Bilan & Prescription"]
        },
        "drug": {
            "category": "MONOGRAPHIE D'URGENCE & DCI ALGÉRIE",
            "primary": (16, 185, 129),     # Emerald #10B981
            "pill_bg": (209, 250, 229),    # #D1FAE5
            "pill_text": (4, 120, 87),     # #047857
            "orb_color": (16, 185, 129, 22),
            "flow_steps": ["1. Indication Princeps", "2. Dilution & Solvant", "3. Débit Perfuseur", "4. Surveillance Scope"]
        },
        "lab": {
            "category": "NORMES DE LABORATOIRE & SEUILS CRITIQUES",
            "primary": (2, 132, 199),      # Sky Blue #0284C7
            "pill_bg": (224, 242, 254),    # #E0F2FE
            "pill_text": (3, 105, 161),    # #0369A1
            "orb_color": (2, 132, 199, 22),
            "flow_steps": ["1. Tube & Prélèvement", "2. Normes Usuelles", "3. Seuil Panique", "4. CAT Devant Anomalie"]
        },
        "summary": {
            "category": "FICHE RÉSUMÉ DU CONCOURS DU RÉSIDANAT",
            "primary": (217, 119, 6),      # Amber #D97706
            "pill_bg": (254, 243, 199),    # #FEF3C7
            "pill_text": (180, 83, 9),     # #B45309
            "orb_color": (217, 119, 6, 22),
            "flow_steps": ["1. Définition Concours", "2. Tableaux Cliniques", "3. Pièges d'Annales", "4. Fiche Mémorisation"]
        },
        "pearl": {
            "category": "PERLE CLINIQUE & PIÈGE DU CONCOURS",
            "primary": (168, 85, 247),     # Purple #A855F7
            "pill_bg": (243, 232, 255),    # #F3E8FF
            "pill_text": (126, 34, 206),    # #7E22CE
            "orb_color": (168, 85, 247, 22),
            "flow_steps": ["1. Cas Clinique", "2. Piège Fréquent", "3. Règle d'Or", "4. Référence Médicale"]
        }
    }
    
    cfg = THEMES.get(content_type, THEMES["cat"])
    primary_color = cfg["primary"]
    pill_bg = cfg["pill_bg"]
    pill_text = cfg["pill_text"]
    
    # Extract metadata from data dict
    raw_title = data.get("title") or data.get("name") or data.get("dci") or data.get("course_name") or "Protocole Médical Clinique"
    raw_specialty = data.get("specialty") or data.get("module_name") or data.get("category") or "Pratique Clinique"
    raw_subtitle = data.get("definition") or data.get("indication") or data.get("urgency_level") or "Protocole décisionnel & posologies validées"
    
    title = strip_emojis_for_image(raw_title)
    specialty = strip_emojis_for_image(raw_specialty)
    subtitle = strip_emojis_for_image(raw_subtitle)
    if len(subtitle) > 85:
        subtitle = subtitle[:82] + "..."
        
    # Extract 2 to 3 teaser bullet points
    raw_points = []
    if "red_flags" in data and isinstance(data["red_flags"], list):
        for rf in data["red_flags"][:2]:
            raw_points.append(f"Signe d'alerte : {rf}")
    if "steps" in data and isinstance(data["steps"], list):
        for step in data["steps"][:2]:
            st = step.get("title") or step.get("content", "")
            if st and st not in raw_points:
                raw_points.append(st)
    if "points" in data and isinstance(data["points"], list):
        for pt in data["points"][:3]:
            raw_points.append(pt)
    if "key_points" in data and isinstance(data["key_points"], list):
        for kp in data["key_points"][:3]:
            raw_points.append(kp)
    if "clinical_reflexes" in data and isinstance(data["clinical_reflexes"], list):
        for cr in data["clinical_reflexes"][:3]:
            raw_points.append(cr)
            
    # Fallback points if empty
    if not raw_points:
        raw_points = [
            f"Critères diagnostiques immédiats & démarche de première intention pour {title}",
            "Conduite à tenir structurée selon les recommandations officielles (MSPRH & Sociétés Savantes)",
            "Posologies hospitalières adaptées aux spécialités disponibles en Algérie (Saidal / PCH)"
        ]

    points = [strip_emojis_for_image(p) for p in raw_points if strip_emojis_for_image(p)]

    # 1. Base image with smooth light gradient
    img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    for y in range(H):
        ratio = y / H
        r = int(255 - ratio * 9)
        g = int(255 - ratio * 7)
        b = int(255 - ratio * 5)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))
        
    # Subtle background ambient orbs
    orb_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    orb_draw = ImageDraw.Draw(orb_layer)
    orb_draw.ellipse([680, -120, 1220, 420], fill=cfg["orb_color"])
    orb_draw.ellipse([-160, 580, 450, 1180], fill=(*primary_color, 12))
    orb_layer = orb_layer.filter(ImageFilter.GaussianBlur(90))
    img = Image.alpha_composite(img, orb_layer)
    draw = ImageDraw.Draw(img)
    
    # Micro dot-matrix texture
    for gx in range(40, W - 40, 40):
        for gy in range(40, H - 40, 40):
            draw.point((gx, gy), fill=(203, 213, 225, 110))
            
    # --- HEADER SECTION ---
    # Real Medsina Logo (left)
    if LOGO_PATH.exists():
        try:
            raw_logo = Image.open(LOGO_PATH).convert("RGBA")
            aspect = raw_logo.width / raw_logo.height
            logo_h = 44
            logo_w = int(logo_h * aspect)
            res_logo = raw_logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
            img.paste(res_logo, (60, 56), res_logo)
        except Exception:
            draw_rounded_rect(draw, [60, 55, 250, 105], radius=25, fill=(255, 255, 255, 230), outline=(226, 232, 240, 255))
            draw.text((80, 70), "MEDSINA", font=get_font(24, bold=True), fill=(15, 23, 42))
    else:
        draw_rounded_rect(draw, [60, 55, 250, 105], radius=25, fill=(255, 255, 255, 230), outline=(226, 232, 240, 255))
        draw.text((80, 70), "MEDSINA", font=get_font(24, bold=True), fill=(15, 23, 42))
        
    # Right Specialty Pill
    f_spec = get_font(16, bold=True)
    draw_pill(draw, W - 60 - 320, 58, specialty.upper()[:24], f_spec, (241, 245, 249), (71, 85, 105), pad_h=18, pad_v=8, radius=18, border_color=(203, 213, 225))
    
    # --- CATEGORY PILL & TITLES ---
    f_cat = get_font(16, bold=True)
    draw_pill(draw, 60, 138, f"●  {cfg['category']}", f_cat, pill_bg, pill_text, pad_h=16, pad_v=7, radius=14, border_color=(*primary_color, 70))
    
    f_title = get_font(42, bold=True)
    f_sub = get_font(22, bold=False)
    
    title_words = title.split()
    lines = []
    cur_line = []
    for word in title_words:
        test_line = " ".join(cur_line + [word])
        w = f_title.getbbox(test_line)[2] - f_title.getbbox(test_line)[0]
        if w > W - 120:
            lines.append(" ".join(cur_line))
            cur_line = [word]
        else:
            cur_line.append(word)
    if cur_line:
        lines.append(" ".join(cur_line))
        
    y_title = 195
    for l in lines[:2]:
        draw.text((60, y_title), l, font=f_title, fill=(15, 23, 42))
        y_title += 52
        
    if subtitle:
        draw.text((60, y_title + 4), subtitle, font=f_sub, fill=(100, 116, 139))
        y_title += 38
    else:
        y_title += 8
        
    # --- HERO SNEAK-PEEK CARD ---
    card_x0, card_y0 = 60, y_title + 14
    card_x1, card_y1 = W - 60, 895
    card_w = card_x1 - card_x0
    
    # Soft realistic shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    draw_rounded_rect(s_draw, [card_x0 + 4, card_y0 + 10, card_x1 - 4, card_y1 + 14], radius=26, fill=(15, 23, 42, 22))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)
    
    # Card surface
    draw_rounded_rect(draw, [card_x0, card_y0, card_x1, card_y1], radius=24, fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=2)
    
    # Card Header
    draw_rounded_rect(draw, [card_x0, card_y0, card_x1, card_y0 + 56], radius=24, fill=(248, 250, 252, 255))
    draw.rectangle([card_x0, card_y0 + 30, card_x1, card_y0 + 56], fill=(248, 250, 252, 255))
    draw.line([(card_x0, card_y0 + 56), (card_x1, card_y0 + 56)], fill=(226, 232, 240, 255), width=1)
    
    f_card_hdr = get_font(16, bold=True)
    draw.text((card_x0 + 24, card_y0 + 18), "EXTRAIT DU PROTOCOLE INTERACTIF (APERÇU CLINIQUE)", font=f_card_hdr, fill=(51, 65, 85))
    draw_pill(draw, card_x1 - 175, card_y0 + 13, "100% Hors-Ligne", get_font(13, bold=True), (240, 253, 244), (22, 101, 52), pad_h=12, pad_v=4, radius=10, border_color=(187, 247, 208))
    
    # Visual Decision Tree / Flow Steps
    flow_y = card_y0 + 74
    flow_steps = cfg.get("flow_steps", [])
    step_w = (card_w - 48 - (len(flow_steps) - 1) * 20) // len(flow_steps)
    f_flow = get_font(13, bold=True)
    for idx, step in enumerate(flow_steps):
        sx0 = card_x0 + 24 + idx * (step_w + 20)
        sx1 = sx0 + step_w
        sy0 = flow_y
        sy1 = flow_y + 36
        draw_rounded_rect(draw, [sx0, sy0, sx1, sy1], radius=10, fill=(241, 245, 249), outline=(226, 232, 240))
        bbox = f_flow.getbbox(step)
        tw = bbox[2] - bbox[0]
        tx = sx0 + (step_w - tw) // 2
        draw.text((tx, sy0 + 10), step, font=f_flow, fill=(71, 85, 105))
        if idx < len(flow_steps) - 1:
            draw.text((sx1 + 6, sy0 + 8), "›", font=get_font(18, bold=True), fill=(148, 163, 184))
            
    # Bullet points section
    cur_y = flow_y + 50
    f_body = get_font(18, bold=False)
    for i, p in enumerate(points[:3]):
        idx_box = [card_x0 + 24, cur_y + 2, card_x0 + 58, cur_y + 36]
        draw_rounded_rect(draw, idx_box, radius=17, fill=pill_bg, outline=(*primary_color, 90))
        draw.text((card_x0 + 35, cur_y + 7), str(i + 1), font=get_font(17, bold=True), fill=pill_text)
        
        p_words = p.split()
        p_lines = []
        c_p = []
        for w in p_words:
            t_str = " ".join(c_p + [w])
            tw = f_body.getbbox(t_str)[2] - f_body.getbbox(t_str)[0]
            if tw > (card_w - 95):
                p_lines.append(" ".join(c_p))
                c_p = [w]
            else:
                c_p.append(w)
        if c_p:
            p_lines.append(" ".join(c_p))
            
        py = cur_y
        for l in p_lines[:2]:
            draw.text((card_x0 + 72, py + 2), l, font=f_body, fill=(30, 41, 59))
            py += 26
        cur_y = py + 16
        
    # --- LOCK & SPOILER BANNER ---
    lock_y0 = card_y1 - 110
    lock_y1 = card_y1 - 16
    draw_rounded_rect(draw, [card_x0 + 16, lock_y0, card_x1 - 16, lock_y1], radius=16, fill=(254, 252, 232, 255), outline=(254, 240, 138, 255), width=1)
    
    padlock_box = [card_x0 + 32, lock_y0 + 18, card_x0 + 88, lock_y0 + 74]
    draw_rounded_rect(draw, padlock_box, radius=28, fill=(254, 243, 199), outline=(252, 211, 77))
    draw_lock_icon(draw, card_x0 + 60, lock_y0 + 46, size=24, color=(180, 83, 9))
    
    f_lt = get_font(17, bold=True)
    f_ld = get_font(15, bold=False)
    draw.text((card_x0 + 104, lock_y0 + 22), "Protocole Complet, Arbres Décisionnels & Posologies Débloqués sur Medsina", font=f_lt, fill=(15, 23, 42))
    draw.text((card_x0 + 104, lock_y0 + 48), "Consultez l'arbre interactif, les posologies adaptées PCH/Saidal et les QCMs officiels.", font=f_ld, fill=(113, 63, 18))
    
    # --- FOOTER SECTION ---
    footer_y = 926
    f_plat = get_font(15, bold=True)
    draw_pill(draw, 60, footer_y + 12, "PC (Windows)", f_plat, (241, 245, 249), (51, 65, 85), pad_h=15, pad_v=8, radius=14, border_color=(203, 213, 225))
    draw_pill(draw, 220, footer_y + 12, "Mobile (Android)", f_plat, (241, 245, 249), (51, 65, 85), pad_h=15, pad_v=8, radius=14, border_color=(203, 213, 225))
    draw_pill(draw, 410, footer_y + 12, "Web App", f_plat, (241, 245, 249), (51, 65, 85), pad_h=15, pad_v=8, radius=14, border_color=(203, 213, 225))
    
    btn_w = 340
    btn_x0 = W - 60 - btn_w
    btn_y0 = footer_y + 8
    draw_rounded_rect(draw, [btn_x0, btn_y0, btn_x0 + btn_w, btn_y0 + 54], radius=16, fill=(15, 23, 42))
    f_btn = get_font(16, bold=True)
    draw.text((btn_x0 + 28, btn_y0 + 18), "medsina.medevsync.com", font=f_btn, fill=(255, 255, 255))
    # Vector Chevron Arrow ->
    ax = btn_x0 + btn_w - 38
    ay = btn_y0 + 27
    draw.line([(ax - 12, ay), (ax, ay)], fill=(255, 255, 255), width=2)
    draw.line([(ax - 5, ay - 5), (ax, ay)], fill=(255, 255, 255), width=2)
    draw.line([(ax - 5, ay + 5), (ax, ay)], fill=(255, 255, 255), width=2)
    
    # Save output
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    img.convert("RGB").save(output_path, "PNG", quality=98)
    return output_path


# =============================================================================
# 3. GÉNÉRATEUR DE TEXTE TEASER (ANTI-SPOILER)
# =============================================================================

def build_teaser_copy(content_type: str, data: Dict[str, Any]) -> str:
    """
    Rédige un post teaser captivant respectant la règle anti-spoiler :
    - Titre accrocheur et situation clinique
    - 2-3 points réflexes d'alerte / repères clés
    - Barrière teaser invitant à débloquer le protocole intégral
    - Liens officiels (Web, Android APK, Windows PC, Telegram)
    """
    title = data.get("title") or data.get("name") or data.get("dci") or data.get("course_name") or "Protocole Médical Clinique"
    specialty = data.get("specialty") or data.get("module_name") or data.get("category") or "Pratique Clinique"

    headers_map = {
        "cat": f"🚨 NOUVELLE CONDUITE À TENIR (CAT) DISPONIBLE SUR MEDSINA ! 🩺⚡\n\nPraticiens hospitaliers, internes et futurs résidents : le protocole d'urgence pour « {title} » vient d'être intégré à vos Outils Pratiques !",
        "memento": f"🌙 NOUVEAU MÉMENTO DE GARDE HOSPITALIÈRE SUR MEDSINA ! 📋🏥\n\nPour ne rien oublier lors de vos gardes de nuit : la fiche réflexe « {title} » ({specialty}) est désormais disponible !",
        "drug": f"💊 NOUVELLE MONOGRAPHIE D'URGENCE & POSOLOGIE DCI SUR MEDSINA ! 🩺\n\nPrécision thérapeutique immédiate au lit du malade : la fiche complète pour « {title} » ({specialty}) est en ligne !",
        "lab": f"🧪 VALEURS DE RÉFÉRENCE & SEUILS CRITIQUES SUR MEDSINA ! 📊\n\nInterprétation biologique rapide : la fiche de référence pour « {title} » ({specialty}) a été ajoutée !",
        "summary": f"📚 NOUVELLE FICHE RÉSUMÉ DU CONCOURS DU RÉSIDANAT SUR MEDSINA ! 🎯\n\nPréparez efficacement vos révisions : le résumé officiel du cours « {title} » ({specialty}) est disponible !",
        "pearl": f"💡 PERLE CLINIQUE & PIÈGE DU CONCOURS SUR MEDSINA ! 🌟\n\nRetenez l'essentiel pour le concours et la pratique : focus sur « {title} » ({specialty}) !"
    }

    intro = headers_map.get(content_type, headers_map["cat"])

    # Extract teaser snippets (2 items max)
    snippets = []
    if "red_flags" in data and isinstance(data["red_flags"], list):
        for rf in data["red_flags"][:2]:
            snippets.append(f"• ⚠️ Alerte / Seuil : {rf}")
    elif "steps" in data and isinstance(data["steps"], list):
        for st in data["steps"][:2]:
            step_title = st.get("title") or ""
            step_content = st.get("content") or ""
            if step_title:
                snippets.append(f"• 📌 {step_title} : {step_content[:90]}...")
    elif "key_points" in data and isinstance(data["key_points"], list):
        for kp in data["key_points"][:2]:
            snippets.append(f"• 📌 {kp}")
    elif "clinical_reflexes" in data and isinstance(data["clinical_reflexes"], list):
        for cr in data["clinical_reflexes"][:2]:
            snippets.append(f"• ⚡ Réflexe de garde : {cr}")
            
    if not snippets:
        snippets = [
            f"• 📌 Situation clinique : Prise en charge initiale de « {title} »",
            "• ⚠️ Points d'alerte : Évaluation rapide de gravité et monitorage immédiat"
        ]

    snippet_text = "\n".join(snippets)

    post_text = f"""{intro}

━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 APERÇU CLINIQUE & POINTS CLÉS :
{snippet_text}

🔒 [...] LA SUITE DU PROTOCOLE COMPLET SUR MEDSINA :
L'arbre décisionnel interactif complet en 4 étapes, les posologies exactes adaptées à la pharmacie hospitalière algérienne (PCH & Saidal), les contre-indications de terrain et les QCMs officiels sont consultables dès maintenant.
━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ 100% Hors-ligne en salle de garde et au bloc UMC.
🔍 Recherche instantanée via Omnisearch (Ctrl+K).

📲 Accédez ou inscrivez-vous dès aujourd'hui :
👉 Web App directe : {OFFICIAL_WEB_URL}
👉 Téléchargement direct APK Android : {OFFICIAL_APK_URL}
👉 Téléchargement Windows PC : {OFFICIAL_WIN_URL}
👉 Canal Telegram Officiel : {OFFICIAL_TELEGRAM_URL}

#Medsina #MedevSync #ResidanatBlida2027 #MedecineAlgerie #UrgencesMedicales #InternatMedecine #AlgerieMedecine"""

    return post_text.strip()


# =============================================================================
# 4. DIFFUSEUR PARALLÈLE MULTICANALE
# =============================================================================

def publish_to_facebook_page(page_id: str, token: str, page_name: str, image_path: Optional[str], caption: str, dry_run: bool = False) -> Optional[str]:
    if dry_run:
        print(f'   [DRY-RUN] Facebook {page_name} ({page_id}): simulation réussie.')
        return 'dry_run_post_id'

    if not page_id or not token:
        print(f'   ⚠️ Facebook {page_name} ignoré : page_id ou token manquant.')
        return None

    # Assurer la mention @followers dans le corps du texte
    fb_caption = caption
    if '@followers' not in fb_caption:
        fb_caption = '@followers\n\n' + fb_caption

    pid = None

    if image_path and os.path.exists(image_path):
        try:
            url = f'https://graph.facebook.com/v21.0/{page_id}/photos'
            with open(image_path, 'rb') as f:
                files = {'source': (os.path.basename(image_path), f, 'image/png')}
                data = {'caption': fb_caption, 'access_token': token}
                r = requests.post(url, data=data, files=files, timeout=40)
            if r.status_code == 200:
                res = r.json()
                pid = res.get('post_id') or res.get('id')
                print(f'   ✅ Succès Facebook {page_name} (Photo)! Post ID: {pid}')
            else:
                print(f'   ⚠️ Avertissement photo Facebook {page_name} ({r.status_code}): {r.text[:120]}')
        except Exception as e:
            print(f'   ⚠️ Erreur upload photo Facebook {page_name}: {e}')

    if not pid:
        try:
            url = f'https://graph.facebook.com/v21.0/{page_id}/feed'
            data = {'message': fb_caption, 'link': OFFICIAL_WEB_URL, 'access_token': token}
            r = requests.post(url, data=data, timeout=30)
            if r.status_code == 200:
                pid = r.json().get('id')
                print(f'   ✅ Succès Facebook {page_name} (Feed Text)! Post ID: {pid}')
            else:
                print(f'   ❌ Échec Facebook {page_name} ({r.status_code}): {r.text[:150]}')
        except Exception as e:
            print(f'   ❌ Erreur Facebook feed {page_name}: {e}')

    if pid:
        try:
            comment_url = f'https://graph.facebook.com/v21.0/{pid}/comments'
            c_data = {
                'message': '@followers Retrouvez la fiche complète sur https://medsina.medevsync.com',
                'access_token': token
            }
            requests.post(comment_url, data=c_data, timeout=10)
        except Exception:
            pass

    return pid


def publish_to_telegram(token: str, channel_id: str, image_path: Optional[str], caption: str, dry_run: bool = False, auto_pin: bool = False) -> bool:
    if dry_run:
        print('   [DRY-RUN] Telegram broadcast simulé avec succès.')
        return True

    if not token or not channel_id:
        print('   ⚠️ Telegram ignoré : token ou channel_id manquant.')
        return False

    reply_markup = {
        'inline_keyboard': [
            [
                {'text': '🌐 Ouvrir sur Medsina Web', 'url': OFFICIAL_WEB_URL},
                {'text': '📲 Télécharger APK Android', 'url': OFFICIAL_APK_URL}
            ],
            [
                {'text': '💻 Télécharger PC Windows', 'url': OFFICIAL_WIN_URL},
                {'text': '👥 Page Facebook Medsina', 'url': 'https://www.facebook.com/residanatblida2027'}
            ]
        ]
    }

    suffix = f'\n\n👉 Suite complète sur {OFFICIAL_WEB_URL}'
    max_body_len = 940 - len(suffix)

    tg_caption = caption
    if len(tg_caption) > (1010 - len(suffix)):
        cut_point = tg_caption[:max_body_len]
        if '\n' in cut_point:
            cut_point = cut_point.rsplit('\n', 1)[0]
        tg_caption = cut_point.strip() + '...' + suffix

    msg_id = None
    try:
        if image_path and os.path.exists(image_path):
            url = f'https://api.telegram.org/bot{token}/sendPhoto'
            with open(image_path, 'rb') as f:
                files = {'photo': f}
                data = {
                    'chat_id': channel_id,
                    'caption': tg_caption,
                    'reply_markup': json.dumps(reply_markup)
                }
                r = requests.post(url, data=data, files=files, timeout=35)

            if r.status_code == 200 and r.json().get('ok'):
                msg_id = r.json().get('result', {}).get('message_id')
                print(f'   ✅ Succès Telegram photo (@medsina_officiel)! Message ID: {msg_id}')
            else:
                print(f'   ⚠️ Avertissement sendPhoto Telegram ({r.status_code}): {r.text[:160]}')
                print('   🔄 Repli résilient : Envoi photo + texte détaillé via sendMessage (supporte 4096 car)...')
                short_caption = caption[:180].rsplit('\n', 1)[0] + f'\n\n👉 {OFFICIAL_WEB_URL}'
                with open(image_path, 'rb') as f2:
                    requests.post(url, data={'chat_id': channel_id, 'caption': short_caption}, files={'photo': f2}, timeout=30)
                msg_url = f'https://api.telegram.org/bot{token}/sendMessage'
                r3 = requests.post(msg_url, data={'chat_id': channel_id, 'text': caption[:4000], 'reply_markup': json.dumps(reply_markup)}, timeout=25)
                if r3.status_code == 200 and r3.json().get('ok'):
                    msg_id = r3.json().get('result', {}).get('message_id')
                    print(f'   ✅ Succès Telegram en repli décomposé! Message ID: {msg_id}')
        else:
            url = f'https://api.telegram.org/bot{token}/sendMessage'
            data = {'chat_id': channel_id, 'text': caption[:4000], 'reply_markup': json.dumps(reply_markup)}
            r = requests.post(url, data=data, timeout=20)
            if r.status_code == 200 and r.json().get('ok'):
                msg_id = r.json().get('result', {}).get('message_id')
                print(f'   ✅ Succès Telegram sendMessage (@medsina_officiel)! Message ID: {msg_id}')
            else:
                print(f'   ⚠️ Avertissement Telegram ({r.status_code}): {r.text[:150]}')

        if msg_id:
            if auto_pin:
                try:
                    pin_url = f'https://api.telegram.org/bot{token}/pinChatMessage'
                    requests.post(pin_url, json={'chat_id': channel_id, 'message_id': msg_id, 'disable_notification': False}, timeout=10)
                    print(f'   📌 Message Telegram #{msg_id} épinglé avec notification push.')
                except Exception:
                    pass
            return True

    except Exception as e:
        print(f'   ⚠️ Erreur Telegram : {e}')

    return False


def broadcast_content_teaser(
    content_type: str,
    data: Dict[str, Any],
    supabase=None,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Point d'entrée principal appelé par medsina_agent.py :
    1. Génère l'image 1080x1080 Light Theme moderne
    2. Rédige le texte teaser structuré (anti-spoiler)
    3. Diffuse sur Facebook Page Blida, Facebook Page MedevSync et Telegram
    4. Met à jour latest_facebook_published_post dans Supabase
    """
    print(f"\n📢 DIFFUSION DU TEASER CLINIQUE ({content_type.upper()}) EN LIGHT THEME MODERNE")
    print("-" * 65)

    results = {
        "content_type": content_type,
        "title": data.get("title") or data.get("name") or data.get("dci"),
        "banner_path": None,
        "facebook_medsina_post_id": None,
        "facebook_blida_post_id": None,
        "facebook_medevsync_post_id": None,
        "telegram_success": False
    }

    # 1. Generate modern light banner image
    temp_dir = tempfile.gettempdir()
    slug = (data.get("id") or content_type).replace("/", "_").replace(" ", "_")
    banner_path = os.path.join(temp_dir, f"medsina_teaser_{slug}.png")

    try:
        render_modern_light_banner(content_type, data, banner_path)
        results["banner_path"] = banner_path
        print(f"   🎨 Affiche Light Theme générée : {banner_path}")
    except Exception as e:
        print(f"   ⚠️ Erreur génération affiche (fallback sans image) : {e}")
        banner_path = None

    # 2. Build teaser copy
    caption = build_teaser_copy(content_type, data)

    # 3. Resolve credentials
    creds = get_social_credentials()

    # 4a. Publish to Facebook Page Officielle : Medsina
    print("   🚀 Diffusion sur Facebook : Medsina (Page Officielle)...")
    p0_id = publish_to_facebook_page(
        page_id=creds["medsina_page_id"],
        token=creds["medsina_token"],
        page_name="Medsina Officiel",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_medsina_post_id"] = p0_id

    # 4b. Publish to Facebook Page Communauté : Résidanat Blida 2027
    print("   🚀 Diffusion sur Facebook : Résidanat Blida 2027...")
    p1_id = publish_to_facebook_page(
        page_id=creds["blida_page_id"],
        token=creds["blida_token"],
        page_name="Résidanat Blida 2027",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_blida_post_id"] = p1_id

    # 5. Publish to Facebook Page 2 : MedevSync
    print("   🚀 Diffusion sur Facebook : MedevSync...")
    p2_id = publish_to_facebook_page(
        page_id=creds["medevsync_page_id"],
        token=creds["medevsync_token"],
        page_name="MedevSync",
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["facebook_medevsync_post_id"] = p2_id

    # 6. Publish to Telegram Official Channel
    print("   🚀 Diffusion sur Telegram : @medsina_officiel...")
    tg_ok = publish_to_telegram(
        token=creds["telegram_token"],
        channel_id=creds["telegram_channel"],
        image_path=banner_path,
        caption=caption,
        dry_run=dry_run
    )
    results["telegram_success"] = tg_ok

    # 7. Update Supabase admin_system_settings with last post ID
    last_post_id = p0_id or p1_id or p2_id
    if last_post_id and not dry_run and last_post_id != "dry_run_post_id":
        try:
            import datetime
            now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
            headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json"}
            requests.patch(
                f"{SUPABASE_URL}/rest/v1/admin_system_settings?setting_key=eq.latest_facebook_published_post",
                headers=headers,
                json={"setting_value": str(last_post_id), "updated_at": now_iso},
                timeout=10
            )
        except Exception:
            pass

    print("-" * 65)
    return results


# =============================================================================
# 5. TEST CLI & DRY-RUN
# =============================================================================

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Medsina Social Teaser Broadcaster")
    parser.add_argument("--type", type=str, default="cat", choices=["cat", "memento", "drug", "lab", "summary", "pearl"])
    parser.add_argument("--dry-run", action="store_true", help="Simuler sans poster")
    args = parser.parse_args()

    sample_data = {
        "id": "cat_test_sample",
        "title": "Prise en Charge du Choc Anaphylactique",
        "specialty": "Allergologie & Urgences",
        "definition": "Urgence vitale absolue caractérisée par une défaillance cardio-circulatoire ou respiratoire aiguë.",
        "red_flags": [
            "Stridor, dyspnée laryngée ou bronchospasme sévère réfractaire",
            "Chute brutale de la pression artérielle (PAS < 90 mmHg) ou collapsus"
        ],
        "steps": [
            {"title": "1. Adrénaline IM Immédiate", "content": "0.5 mg IM (cuisse antérolatérale) sans attendre"},
            {"title": "2. Oxygène & Remplissage", "content": "Oxygène fort débit 15 L/min + Cristalloïdes 20 mL/kg"}
        ]
    }

    res = broadcast_content_teaser(args.type, sample_data, dry_run=args.dry_run)
    print("Résultat du broadcast :", res)
