import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

import os
from pathlib import Path
from playwright.sync_api import sync_playwright

ARTIFACT_DIR = Path(r"C:\Users\PC-Service\.gemini\antigravity\brain\0ba098d1-adef-41a0-8ca2-353fed62237c")
WORKSPACE_ASSETS_DIR = Path(r"D:\REVISION RESIDANAT\ressources\residanat-blida-2027\medsina\assets\facebook")

WORKSPACE_ASSETS_DIR.mkdir(parents=True, exist_ok=True)
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

# -----------------------------------------------------------------------------
# 1. PROFILE PHOTO: APP ICON (CLEAN LIGHT THEME)
# -----------------------------------------------------------------------------
PROFILE_ICON_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800;900&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 800px;
    height: 800px;
    background: radial-gradient(circle at 50% 40%, #FFFFFF 0%, #F0FDF9 50%, #E2E8F0 100%);
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    position: relative;
  }

  .ambient-glow {
    position: absolute;
    width: 580px;
    height: 580px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(14, 165, 233, 0.25) 0%, rgba(13, 148, 136, 0.18) 45%, transparent 70%);
    filter: blur(45px);
  }

  .icon-card {
    position: relative;
    width: 520px;
    height: 520px;
    border-radius: 125px;
    background: linear-gradient(145deg, #0D9488 0%, #0EA5E9 55%, #2563EB 100%);
    box-shadow: 
      0 32px 75px -12px rgba(13, 148, 136, 0.48),
      0 14px 32px -6px rgba(14, 165, 233, 0.38),
      inset 0 2.5px 5px rgba(255, 255, 255, 0.55),
      inset 0 -3px 6px rgba(0, 0, 0, 0.18);
    display: flex;
    align-items: center;
    justify-content: center;
    border: 3px solid rgba(255, 255, 255, 0.45);
  }

  .inner-shine {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 48%;
    border-radius: 122px 122px 200px 200px;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.32) 0%, rgba(255, 255, 255, 0) 100%);
    pointer-events: none;
  }

  svg {
    filter: drop-shadow(0 14px 28px rgba(0, 0, 0, 0.18));
  }
</style>
</head>
<body>
  <div class="ambient-glow"></div>
  <div class="icon-card">
    <div class="inner-shine"></div>
    <svg width="270" height="270" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="36" y="10" width="28" height="80" rx="9.5" fill="white" />
      <rect x="10" y="36" width="80" height="28" rx="9.5" fill="white" />
      <path d="M 12 50 L 32 50 L 39 33 L 48 68 L 57 24 L 64 56 L 70 50 L 88 50" 
            stroke="#0D9488" 
            stroke-width="5.5" 
            stroke-linecap="round" 
            stroke-linejoin="round" />
      <circle cx="50" cy="50" r="3.5" fill="#0EA5E9" />
    </svg>
  </div>
</body>
</html>
"""

# -----------------------------------------------------------------------------
# 2. PROFILE PHOTO: BADGE & TYPOGRAPHY
# -----------------------------------------------------------------------------
PROFILE_BADGE_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800;900&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 800px;
    height: 800px;
    background: radial-gradient(circle at 50% 32%, #FFFFFF 0%, #F0FDF9 55%, #E2E8F0 100%);
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    position: relative;
  }

  .ambient-glow {
    position: absolute;
    top: 100px;
    width: 460px;
    height: 460px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(14, 165, 233, 0.22) 0%, rgba(13, 148, 136, 0.16) 55%, transparent 75%);
    filter: blur(40px);
  }

  .icon-card {
    position: relative;
    width: 330px;
    height: 330px;
    border-radius: 80px;
    background: linear-gradient(145deg, #0D9488 0%, #0EA5E9 60%, #2563EB 100%);
    box-shadow: 
      0 26px 55px -10px rgba(13, 148, 136, 0.42),
      0 10px 24px -4px rgba(14, 165, 233, 0.32),
      inset 0 2.5px 4px rgba(255, 255, 255, 0.45);
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2.5px solid rgba(255, 255, 255, 0.45);
    margin-bottom: 26px;
  }

  .inner-shine {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 48%;
    border-radius: 78px 78px 130px 130px;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.3) 0%, rgba(255, 255, 255, 0) 100%);
  }

  .brand-title {
    font-size: 72px;
    font-weight: 900;
    letter-spacing: 4px;
    color: #0F172A;
    line-height: 1;
    display: flex;
    align-items: center;
  }

  .brand-title span.dot {
    color: #0D9488;
  }

  .brand-tagline {
    font-size: 19px;
    font-weight: 800;
    color: #0D9488;
    letter-spacing: 3px;
    text-transform: uppercase;
    margin-top: 10px;
    background: rgba(13, 148, 136, 0.1);
    padding: 7px 20px;
    border-radius: 30px;
    border: 1.2px solid rgba(13, 148, 136, 0.28);
  }
</style>
</head>
<body>
  <div class="ambient-glow"></div>
  
  <div class="icon-card">
    <div class="inner-shine"></div>
    <svg width="185" height="185" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="36" y="10" width="28" height="80" rx="9" fill="white" />
      <rect x="10" y="36" width="80" height="28" rx="9" fill="white" />
      <path d="M 12 50 L 32 50 L 39 33 L 48 68 L 57 24 L 64 56 L 70 50 L 88 50" 
            stroke="#0D9488" 
            stroke-width="5.5" 
            stroke-linecap="round" 
            stroke-linejoin="round" />
    </svg>
  </div>

  <div class="brand-title">MEDSINA<span class="dot">.</span></div>
  <div class="brand-tagline">Assistant Clinique IA</div>
</body>
</html>
"""

# -----------------------------------------------------------------------------
# 3. PROFILE PHOTO: DARK CONTRAST EDITION
# -----------------------------------------------------------------------------
PROFILE_DARK_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800;900&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 800px;
    height: 800px;
    background: radial-gradient(circle at 50% 40%, #064E3B 0%, #042F2E 40%, #0F172A 85%);
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    position: relative;
  }

  .ambient-glow {
    position: absolute;
    width: 580px;
    height: 580px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(14, 165, 233, 0.3) 0%, rgba(16, 185, 129, 0.22) 50%, transparent 75%);
    filter: blur(55px);
  }

  .icon-card {
    position: relative;
    width: 520px;
    height: 520px;
    border-radius: 125px;
    background: linear-gradient(145deg, #0D9488 0%, #0EA5E9 55%, #2563EB 100%);
    box-shadow: 
      0 32px 75px -10px rgba(0, 0, 0, 0.6),
      0 0 50px rgba(14, 165, 233, 0.35),
      inset 0 2.5px 5px rgba(255, 255, 255, 0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    border: 3px solid rgba(255, 255, 255, 0.35);
  }

  .inner-shine {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 48%;
    border-radius: 122px 122px 200px 200px;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.32) 0%, rgba(255, 255, 255, 0) 100%);
  }

  svg {
    filter: drop-shadow(0 14px 28px rgba(0, 0, 0, 0.25));
  }
</style>
</head>
<body>
  <div class="ambient-glow"></div>
  <div class="icon-card">
    <div class="inner-shine"></div>
    <svg width="270" height="270" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="36" y="10" width="28" height="80" rx="9.5" fill="white" />
      <rect x="10" y="36" width="80" height="28" rx="9.5" fill="white" />
      <path d="M 12 50 L 32 50 L 39 33 L 48 68 L 57 24 L 64 56 L 70 50 L 88 50" 
            stroke="#0D9488" 
            stroke-width="5.5" 
            stroke-linecap="round" 
            stroke-linejoin="round" />
      <circle cx="50" cy="50" r="3.5" fill="#0EA5E9" />
    </svg>
  </div>
</body>
</html>
"""

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        # 1. Profile: Icon Light
        page = browser.new_page(viewport={"width": 800, "height": 800}, device_scale_factor=2)
        page.set_content(PROFILE_ICON_HTML)
        page.wait_for_timeout(800)
        page.screenshot(path=str(ARTIFACT_DIR / "medsina_fb_profile_icon.png"), type="png")
        page.screenshot(path=str(WORKSPACE_ASSETS_DIR / "medsina_fb_profile_icon.png"), type="png")
        page.close()

        # 2. Profile: Badge Light
        page = browser.new_page(viewport={"width": 800, "height": 800}, device_scale_factor=2)
        page.set_content(PROFILE_BADGE_HTML)
        page.wait_for_timeout(800)
        page.screenshot(path=str(ARTIFACT_DIR / "medsina_fb_profile_badge.png"), type="png")
        page.screenshot(path=str(WORKSPACE_ASSETS_DIR / "medsina_fb_profile_badge.png"), type="png")
        page.close()

        # 3. Profile: Dark Contrast
        page = browser.new_page(viewport={"width": 800, "height": 800}, device_scale_factor=2)
        page.set_content(PROFILE_DARK_HTML)
        page.wait_for_timeout(800)
        page.screenshot(path=str(ARTIFACT_DIR / "medsina_fb_profile_dark.png"), type="png")
        page.screenshot(path=str(WORKSPACE_ASSETS_DIR / "medsina_fb_profile_dark.png"), type="png")
        page.close()

        browser.close()
    print("Profile pictures updated without guide lines!")

if __name__ == "__main__":
    main()
