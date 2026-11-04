#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
MEDSINA - MODERN HTML/CSS INFOGRAPHIC GENERATOR (PLAYWRIGHT CHROMIUM)
=============================================================================
Generates agency-grade medical announcement infographics using modern
HTML5, CSS3 Glassmorphism, Google Fonts, and Playwright Chromium Headless.
Replaces legacy 2D Pillow drawing with crisp Retina 2x/4K marketing visuals.
=============================================================================
"""

import os
import sys
import tempfile
from pathlib import Path
from typing import List, Optional, Dict, Any

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

try:
    from playwright.sync_api import sync_playwright
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False


def build_infographic_html(
    title: str,
    source_type: str = "Drive Officiel",
    module: str = "Médecine & Résidanat",
    features: Optional[List[str]] = None,
    badge_label: str = "NOUVELLE RESSOURCE OFFICIELLE",
    cta_text: str = "📲 Disponible en illimité et hors-ligne dans l'application Medsina",
    aspect_ratio: str = "landscape"  # "landscape" (1200x675) or "square" (1080x1080)
) -> str:
    """Constructs modern Glassmorphism HTML markup."""
    feat_list = features or [
        "🩺 Polycopié de Cours Officiel Assaini",
        "⚡ Accessible 100% Hors-Ligne",
        "🎯 Banques de QCMs & Fiches Synthèses Liées"
    ]

    features_html = "".join([
        f'<div class="feature-item"><span class="feat-icon">✓</span><span>{f}</span></div>'
        for f in feat_list
    ])

    is_square = (aspect_ratio == "square")
    width = 1080 if is_square else 1200
    height = 1080 if is_square else 675
    card_width = 960 if is_square else 1080
    card_height = 960 if is_square else 535
    title_size = "40px" if is_square else "44px"

    html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Outfit:wght@700;800;900&display=swap" rel="stylesheet">
  <style>
    * {{
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    }}
    body {{
      width: {width}px;
      height: {height}px;
      background-color: #070B14;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      position: relative;
    }}

    /* Glow spheres in background */
    .glow-teal {{
      position: absolute;
      width: 650px;
      height: 650px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(13, 148, 136, 0.40) 0%, rgba(13, 148, 136, 0) 70%);
      top: -160px;
      right: -100px;
      pointer-events: none;
    }}
    .glow-cyan {{
      position: absolute;
      width: 550px;
      height: 550px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(14, 165, 233, 0.30) 0%, rgba(14, 165, 233, 0) 70%);
      bottom: -150px;
      left: -80px;
      pointer-events: none;
    }}
    .glow-navy {{
      position: absolute;
      width: 400px;
      height: 400px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(99, 102, 241, 0.25) 0%, rgba(99, 102, 241, 0) 70%);
      top: 40%;
      left: 30%;
      pointer-events: none;
    }}

    /* Subtle grid overlay */
    .grid-overlay {{
      position: absolute;
      inset: 0;
      background-image: 
        linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
      background-size: 40px 40px;
      pointer-events: none;
    }}

    /* Main Glassmorphism Container Card */
    .glass-card {{
      width: {card_width}px;
      height: {card_height}px;
      background: rgba(15, 23, 42, 0.65);
      backdrop-filter: blur(28px);
      -webkit-backdrop-filter: blur(28px);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-top: 1px solid rgba(255, 255, 255, 0.22);
      border-radius: 28px;
      padding: 44px 50px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      box-shadow: 
        0 30px 60px -12px rgba(0, 0, 0, 0.6),
        0 0 0 1px rgba(13, 148, 136, 0.15),
        inset 0 1px 1px 0 rgba(255, 255, 255, 0.15);
      position: relative;
      z-index: 10;
    }}

    /* Header Bar */
    .header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
    }}
    .brand-wrap {{
      display: flex;
      align-items: center;
      gap: 14px;
    }}
    .brand-icon {{
      width: 44px;
      height: 44px;
      background: linear-gradient(135deg, #0D9488, #0EA5E9);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      color: white;
      box-shadow: 0 4px 14px rgba(13, 148, 136, 0.4);
    }}
    .brand-text {{
      display: flex;
      flex-direction: column;
    }}
    .brand-name {{
      font-family: 'Outfit', sans-serif;
      font-size: 24px;
      font-weight: 900;
      letter-spacing: -0.5px;
      color: #FFFFFF;
      line-height: 1.1;
    }}
    .brand-name span {{
      color: #14B8A6;
    }}
    .brand-sub {{
      font-size: 11px;
      font-weight: 700;
      color: #94A3B8;
      letter-spacing: 1.8px;
      text-transform: uppercase;
    }}

    .badge-pill {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(20, 184, 166, 0.12);
      border: 1px solid rgba(20, 184, 166, 0.35);
      padding: 8px 18px;
      border-radius: 9999px;
      color: #2DD4BF;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      box-shadow: 0 0 20px rgba(13, 148, 136, 0.15);
    }}
    .badge-dot {{
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background-color: #2DD4BF;
      box-shadow: 0 0 8px #2DD4BF;
    }}

    /* Main Content Area */
    .main-content {{
      margin-top: 10px;
    }}
    .type-tag {{
      display: inline-block;
      color: #38BDF8;
      font-size: 13px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 2px;
      margin-bottom: 8px;
    }}
    .title {{
      font-family: 'Outfit', sans-serif;
      font-size: {title_size};
      font-weight: 800;
      color: #F8FAFC;
      line-height: 1.18;
      letter-spacing: -0.8px;
      text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }}
    .module-banner {{
      margin-top: 10px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      color: #CBD5E1;
      font-size: 17px;
      font-weight: 600;
    }}
    .module-badge {{
      color: #F59E0B;
      font-weight: 700;
    }}

    /* Features Cards */
    .features-container {{
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 24px;
    }}
    .feature-item {{
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 12px;
      padding: 10px 16px;
      color: #E2E8F0;
      font-size: 14px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }}
    .feat-icon {{
      color: #10B981;
      font-weight: 800;
    }}

    /* Footer Banner */
    .footer {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      padding-top: 18px;
    }}
    .cta-wrap {{
      display: flex;
      align-items: center;
      gap: 10px;
    }}
    .cta-text {{
      color: #38BDF8;
      font-size: 15px;
      font-weight: 700;
      letter-spacing: -0.2px;
    }}
    .domain-tag {{
      display: flex;
      align-items: center;
      gap: 8px;
      background: rgba(255, 255, 255, 0.06);
      padding: 6px 14px;
      border-radius: 8px;
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: #94A3B8;
      font-size: 12.5px;
      font-weight: 700;
    }}
    .dot-green {{
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background-color: #10B981;
    }}
  </style>
</head>
<body>
  <div class="grid-overlay"></div>
  <div class="glow-teal"></div>
  <div class="glow-cyan"></div>
  <div class="glow-navy"></div>

  <div class="glass-card">
    <div class="header">
      <div class="brand-wrap">
        <div class="brand-icon">⚕️</div>
        <div class="brand-text">
          <div class="brand-name">MEDSINA <span>ULTRA</span></div>
          <div class="brand-sub">Faculté de Médecine & Résidanat 2027</div>
        </div>
      </div>
      <div class="badge-pill">
        <span class="badge-dot"></span>
        {badge_label}
      </div>
    </div>

    <div class="main-content">
      <div class="type-tag">📁 {source_type}</div>
      <div class="title">{title}</div>
      <div class="module-banner">
        <span>Module Officiel :</span>
        <span class="module-badge">{module}</span>
        <span>• Concours 2027</span>
      </div>

      <div class="features-container">
        {features_html}
      </div>
    </div>

    <div class="footer">
      <div class="cta-wrap">
        <div class="cta-text">{cta_text}</div>
      </div>
      <div class="domain-tag">
        <span class="dot-green"></span>
        medsina.medevsync.com
      </div>
    </div>
  </div>
</body>
</html>
"""
    return html_content


def render_html_to_png(
    html_content: str,
    output_path: str,
    aspect_ratio: str = "landscape",
    device_scale_factor: int = 2
) -> str:
    """Renders HTML string to a PNG file using Playwright Chromium in Retina quality."""
    is_square = (aspect_ratio == "square")
    width = 1080 if is_square else 1200
    height = 1080 if is_square else 675

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(
            viewport={"width": width, "height": height},
            device_scale_factor=device_scale_factor
        )
        page.set_content(html_content, wait_until="networkidle")
        # Ensure fonts and layout are settled
        page.wait_for_timeout(400)
        page.screenshot(path=output_path, type="png")
        browser.close()

    return output_path


def generate_modern_infographic(
    title: str,
    source_type: str = "Drive Officiel",
    module: str = "Médecine & Résidanat",
    features: Optional[List[str]] = None,
    badge_label: str = "NOUVELLE RESSOURCE OFFICIELLE",
    output_path: Optional[str] = None,
    aspect_ratio: str = "landscape"
) -> str:
    """
    Main entry point: Generates high-definition glassmorphism infographic.
    Falls back to Pillow if Playwright is unavailable.
    """
    if not output_path:
        suffix = f"_{aspect_ratio}.png"
        fd, output_path = tempfile.mkstemp(prefix="medsina_modern_", suffix=suffix)
        os.close(fd)

    if PLAYWRIGHT_AVAILABLE:
        try:
            html = build_infographic_html(
                title=title,
                source_type=source_type,
                module=module,
                features=features,
                badge_label=badge_label,
                aspect_ratio=aspect_ratio
            )
            render_html_to_png(html, output_path, aspect_ratio=aspect_ratio)
            print(f"✨ [Modern Infographic] Infographie générée avec Playwright Chromium ({aspect_ratio}) : {output_path}")
            return output_path
        except Exception as e:
            print(f"⚠️ [Modern Infographic] Échec Playwright ({e}), bascule sur Pillow...")

    # Pillow fallback
    from PIL import Image, ImageDraw, ImageFont
    w, h = (1080, 1080) if aspect_ratio == "square" else (1200, 675)
    img = Image.new("RGB", (w, h), color=(15, 23, 42))
    draw = ImageDraw.Draw(img)
    draw.rectangle([40, 40, w - 40, h - 40], outline=(13, 148, 136), width=3)
    try:
        font = ImageFont.truetype("segoeuib.ttf", 36)
    except Exception:
        font = ImageFont.load_default()
    draw.text((70, 70), f"MEDSINA ULTRA - {badge_label}", font=font, fill=(20, 184, 166))
    draw.text((70, 160), title[:45], font=font, fill=(255, 255, 255))
    draw.text((70, 240), f"Module : {module}", font=font, fill=(245, 158, 11))
    img.save(output_path, "PNG")
    return output_path


if __name__ == "__main__":
    test_out = generate_modern_infographic(
        title="Cancérologie du Pancréas & Conduites Pratiques",
        source_type="Drive Officiel & Livret 2027",
        module="Hépato-Gastro-Entérologie",
        features=[
            "🩺 Polycopié Officiel Assaini & Annoté",
            "⚡ Fiche Synthèse avec Pièges de Concours",
            "🎯 120 QCMs Corrigés & Expliqués",
            "📲 Mode 100% Hors-Ligne dans l'App Medsina"
        ],
        aspect_ratio="landscape",
        output_path="test_modern_infographic_landscape.png"
    )
    print(f"Test réussi : {test_out}")
