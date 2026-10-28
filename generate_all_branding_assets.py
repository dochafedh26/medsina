import base64
import math
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw
from playwright.sync_api import sync_playwright

MEDSINA_ROOT = Path(r"D:\REVISION RESIDANAT\ressources\residanat-blida-2027\medsina")
ASSETS_DIR = MEDSINA_ROOT / "assets"

def create_launcher_assets():
    print("--- 1. Generating App Launcher Icons ---")
    master_emblem = Image.open(ASSETS_DIR / "emblem_master.png")
    mw, mh = master_emblem.size

    # A. app_launcher_foreground.png (1024x1024, emblem scaled to safe zone)
    # Safe zone for Android adaptive icon: central 66% circle (radius ~338px)
    # We determined 566 x 388 sits comfortably inside radius 320px
    fg_w, fg_h = 566, int(mh * (566 / mw))
    emblem_fg = master_emblem.resize((fg_w, fg_h), Image.Resampling.LANCZOS)

    fg_img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    fg_x = (1024 - fg_w) // 2
    fg_y = (1024 - fg_h) // 2
    fg_img.paste(emblem_fg, (fg_x, fg_y), emblem_fg)
    fg_img.save(ASSETS_DIR / "app_launcher_foreground.png", optimize=True)
    print("Saved app_launcher_foreground.png (1024x1024)")

    # B. app_launcher_icon.png (1024x1024, master dark launcher icon)
    # Background: deep dark navy #071526 with radial cyan/teal glow
    icon_w, icon_h = 1024, 1024
    bg_img = Image.new("RGBA", (icon_w, icon_h), (7, 21, 38, 255)) # #071526

    # Create radial glow in center
    glow_layer = Image.new("RGBA", (icon_w, icon_h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    cx, cy = icon_w // 2, icon_h // 2
    # Draw concentric circles for smooth radial gradient
    max_radius = 450
    for r in range(max_radius, 0, -2):
        t = r / max_radius
        # Center: cyan (14, 165, 233), Mid: teal (13, 148, 136), Outer: 0
        if t < 0.4:
            alpha = int((1.0 - (t / 0.4) * 0.3) * 65)
            color = (14, 165, 233, alpha)
        else:
            alpha = int((1.0 - (t - 0.4) / 0.6) * 45)
            color = (13, 148, 136, alpha)
        glow_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)

    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(35))
    bg_img = Image.alpha_composite(bg_img, glow_layer)

    # Scale emblem for master launcher icon (600px wide)
    em_w = 600
    em_h = int(mh * (em_w / mw))
    emblem_master_icon = master_emblem.resize((em_w, em_h), Image.Resampling.LANCZOS)

    # Soft ambient drop shadow / glow behind emblem
    shadow_layer = Image.new("RGBA", (icon_w, icon_h), (0, 0, 0, 0))
    em_x = (icon_w - em_w) // 2
    em_y = (icon_h - em_h) // 2
    shadow_layer.paste(emblem_master_icon, (em_x, em_y), emblem_master_icon)
    # Extract alpha mask of emblem and expand as cyan glow
    glow_halo = Image.new("RGBA", (icon_w, icon_h), (14, 165, 233, 0))
    alpha_mask = shadow_layer.split()[3]
    glow_halo.putalpha(alpha_mask)
    glow_halo = glow_halo.filter(ImageFilter.GaussianBlur(18))
    
    # Adjust glow brightness
    halo_data = glow_halo.load()
    for y in range(icon_h):
        for x in range(icon_w):
            r, g, b, a = halo_data[x, y]
            if a > 0:
                halo_data[x, y] = (14, 165, 233, int(a * 0.45))

    bg_img = Image.alpha_composite(bg_img, glow_halo)
    bg_img.paste(emblem_master_icon, (em_x, em_y), emblem_master_icon)
    bg_img.save(ASSETS_DIR / "app_launcher_icon.png", optimize=True)
    print("Saved app_launcher_icon.png (1024x1024)")


def create_icon_asset():
    print("--- 2. Generating medsina-icon.png ---")
    master_emblem = Image.open(ASSETS_DIR / "emblem_master.png")
    mw, mh = master_emblem.size

    # Square 512x512 transparent
    icon_size = 512
    em_w = 440
    em_h = int(mh * (em_w / mw))
    emblem_resized = master_emblem.resize((em_w, em_h), Image.Resampling.LANCZOS)

    icon_img = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    ex = (icon_size - em_w) // 2
    ey = (icon_size - em_h) // 2
    icon_img.paste(emblem_resized, (ex, ey), emblem_resized)
    icon_img.save(ASSETS_DIR / "medsina-icon.png", optimize=True)
    print("Saved medsina-icon.png (512x512)")


def create_horizontal_logos():
    print("--- 3. Generating Horizontal Logos (Playwright) ---")
    with open(ASSETS_DIR / "emblem_master.png", "rb") as f:
        emblem_b64 = base64.b64encode(f.read()).decode("utf-8")

    html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800;900&display=swap');
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: transparent;
    display: inline-flex;
    align-items: center;
    padding: 10px;
  }}
  .logo-container {{
    display: inline-flex;
    align-items: center;
    gap: 18px;
    height: 140px;
    padding: 6px 12px;
  }}
  .emblem {{
    height: 118px;
    width: auto;
    object-fit: contain;
    filter: drop-shadow(0 2px 10px rgba(13, 148, 136, 0.22));
  }}
  .brand-text {{
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
    font-size: 88px;
    font-weight: 800;
    letter-spacing: -2px;
    line-height: 1;
    margin-top: -4px;
  }}
  .light {{
    color: #0F172A;
  }}
  .dark {{
    color: #FFFFFF;
  }}
</style>
</head>
<body>
  <div class="logo-container" id="logo-node">
    <img class="emblem" src="data:image/png;base64,{emblem_b64}">
    <span class="brand-text light" id="text-node">medsina</span>
  </div>
</body>
</html>"""

    tmp_light = ASSETS_DIR / "tmp_logo_light.png"
    tmp_dark = ASSETS_DIR / "tmp_logo_dark.png"

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.set_content(html_content)
        page.evaluate("() => document.fonts.ready")
        page.wait_for_timeout(1000)

        # 1. Render light logo
        elem = page.locator("#logo-node")
        elem.screenshot(path=str(tmp_light), omit_background=True)

        # 2. Render dark logo
        page.evaluate("""() => {
            document.getElementById('text-node').className = 'brand-text dark';
        }""")
        elem.screenshot(path=str(tmp_dark), omit_background=True)
        browser.close()

    # Crop tightly with uniform elegant padding
    for tmp_file, out_file in [(tmp_light, "medsina-logo.png"), (tmp_dark, "medsina-logo-dark.png")]:
        im = Image.open(tmp_file)
        bbox = im.getbbox()
        pad_x, pad_y = 6, 6
        crop_box = (
            max(0, bbox[0] - pad_x),
            max(0, bbox[1] - pad_y),
            min(im.width, bbox[2] + pad_x),
            min(im.height, bbox[3] + pad_y),
        )
        cropped = im.crop(crop_box)
        cropped.save(ASSETS_DIR / out_file, optimize=True)
        print(f"Saved {out_file} ({cropped.size[0]}x{cropped.size[1]})")
        tmp_file.unlink(missing_ok=True)


def main():
    create_launcher_assets()
    create_icon_asset()
    create_horizontal_logos()
    print("=== All branding assets generated successfully! ===")

if __name__ == "__main__":
    main()
