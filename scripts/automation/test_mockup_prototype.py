#!/usr/bin/env python3
"""
Medsina Smartphone & Desktop Mockup Generator Engine
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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

def create_rounded_mask(size, radius):
    """Creates a supersampled antialiased rounded corner mask."""
    w, h = size
    scale = 4
    mask = Image.new("L", (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (w * scale - 1, h * scale - 1)], radius=radius * scale, fill=255)
    return mask.resize((w, h), Image.Resampling.LANCZOS)

def create_shadow(image_size, radius=24, offset=(0, 16), shadow_color=(0, 0, 0, 140)):
    """Creates a soft realistic shadow behind an element."""
    w, h = image_size
    pad = radius * 2
    shadow = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(
        [(pad + offset[0], pad + offset[1]), (pad + w + offset[0], pad + h + offset[1])],
        radius=radius,
        fill=shadow_color
    )
    return shadow.filter(ImageFilter.GaussianBlur(radius)), pad

def render_phone_mockup(screen_img: Image.Image, target_width: int = 380) -> Image.Image:
    """Renders a modern sleek smartphone mockup with titanium bezel, status bar, and realistic shadow."""
    aspect_ratio = 19.5 / 9.0
    bezel = 10
    screen_w = target_width - bezel * 2
    screen_h = int(screen_w * aspect_ratio)
    phone_w = target_width
    phone_h = screen_h + bezel * 2
    corner_radius = 36

    # 1. Scale with cover (fill entire phone screen)
    scale = max(screen_w / screen_img.width, screen_h / screen_img.height)
    new_w = int(screen_img.width * scale)
    new_h = int(screen_img.height * scale)
    scaled = screen_img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)

    crop_x = (new_w - screen_w) // 2
    crop_y = 0  # keep top header visible
    screen_canvas = scaled.crop((crop_x, crop_y, crop_x + screen_w, crop_y + screen_h))

    # 2. Add realistic Mobile Status Bar (Time, Wifi, Battery) with top scrim
    scrim = Image.new("RGBA", (screen_w, 40), (0, 0, 0, 0))
    scrim_draw = ImageDraw.Draw(scrim)
    for y in range(40):
        a = int(120 * (1.0 - y / 40.0))
        scrim_draw.line([(0, y), (screen_w, y)], fill=(0, 0, 0, a))
    screen_canvas.alpha_composite(scrim, (0, 0))

    font_status = get_font(13, bold=True)
    status_draw = ImageDraw.Draw(screen_canvas)
    status_draw.text((22, 11), "09:41", font=font_status, fill=(255, 255, 255, 240))

    # Battery icon at top right
    bx = screen_w - 44
    status_draw.rounded_rectangle([(bx, 13), (bx + 24, 24)], radius=3, outline=(255, 255, 255, 220), width=1)
    status_draw.rounded_rectangle([(bx + 2, 15), (bx + 18, 22)], radius=2, fill=(16, 185, 129, 255))
    status_draw.rectangle([(bx + 24, 16), (bx + 26, 21)], fill=(255, 255, 255, 220))

    # 3. Add bottom Home Indicator bar with scrim
    bottom_scrim = Image.new("RGBA", (screen_w, 28), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bottom_scrim)
    for y in range(28):
        a = int(100 * (y / 28.0))
        b_draw.line([(0, y), (screen_w, y)], fill=(0, 0, 0, a))
    screen_canvas.alpha_composite(bottom_scrim, (0, screen_h - 28))

    bar_w = 110
    bar_h = 4
    bar_x = (screen_w - bar_w) // 2
    bar_y = screen_h - 12
    status_draw.rounded_rectangle([(bar_x, bar_y), (bar_x + bar_w, bar_y + bar_h)], radius=2, fill=(255, 255, 255, 200))

    # Mask screen to rounded corners
    screen_mask = create_rounded_mask((screen_w, screen_h), radius=corner_radius - 8)
    screen_canvas.putalpha(screen_mask)

    # 4. Build Phone Frame
    frame = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)

    # Outer titanium bezel with metallic sheen
    frame_draw.rounded_rectangle([(0, 0), (phone_w - 1, phone_h - 1)], radius=corner_radius, fill=(15, 23, 42, 255), outline=(71, 85, 105, 255), width=2)
    frame_draw.rounded_rectangle([(bezel - 2, bezel - 2), (phone_w - bezel + 1, phone_h - bezel + 1)], radius=corner_radius - 6, outline=(30, 41, 59, 255), width=1)

    # Paste screen inside
    frame.paste(screen_canvas, (bezel, bezel), screen_canvas)

    # Dynamic Island / Pill at top
    pill_w = 76
    pill_h = 16
    pill_x = (phone_w - pill_w) // 2
    pill_y = bezel + 6
    pill_draw = ImageDraw.Draw(frame)
    pill_draw.rounded_rectangle([(pill_x, pill_y), (pill_x + pill_w, pill_y + pill_h)], radius=pill_h // 2, fill=(0, 0, 0, 255))
    pill_draw.ellipse([(pill_x + 12, pill_y + 3), (pill_x + 22, pill_y + 13)], fill=(15, 25, 45, 255))

    # 5. Composite with drop shadow
    shadow, pad = create_shadow((phone_w, phone_h), radius=28, offset=(0, 18), shadow_color=(0, 0, 0, 160))
    canvas = Image.new("RGBA", (phone_w + pad * 2, phone_h + pad * 2), (0, 0, 0, 0))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(frame, (pad, pad), frame)

    return canvas

def render_desktop_mockup(screen_img: Image.Image, target_width: int = 560) -> Image.Image:
    """Renders a modern sleek Web Browser / Desktop Window mockup with URL bar and shadows."""
    aspect_ratio = 16.0 / 10.0
    header_h = 36
    window_w = target_width
    screen_w = window_w
    screen_h = int(screen_w / aspect_ratio)
    window_h = screen_h + header_h
    corner_radius = 16

    # 1. Resize and crop screen image
    screen_aspect = screen_img.width / screen_img.height
    if screen_aspect > aspect_ratio:
        new_h = screen_h
        new_w = int(new_h * screen_aspect)
        resized_screen = screen_img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)
        left = (new_w - screen_w) // 2
        cropped_screen = resized_screen.crop((left, 0, left + screen_w, screen_h))
    else:
        new_w = screen_w
        new_h = int(new_w / screen_aspect)
        resized_screen = screen_img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)
        top = (new_h - screen_h) // 2
        cropped_screen = resized_screen.crop((0, top, screen_w, top + screen_h))

    # Mask bottom corners
    mask = Image.new("L", (window_w, window_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (window_w - 1, window_h - 1)], radius=corner_radius, fill=255)

    # 2. Build Window Container
    window = Image.new("RGBA", (window_w, window_h), (15, 23, 42, 255))
    w_draw = ImageDraw.Draw(window)

    # Window background and border
    w_draw.rounded_rectangle([(0, 0), (window_w - 1, window_h - 1)], radius=corner_radius, fill=(24, 32, 50, 255), outline=(71, 85, 105, 180), width=1)

    # Header Bar
    w_draw.rounded_rectangle([(0, 0), (window_w - 1, header_h + 10)], radius=corner_radius, fill=(30, 41, 59, 255))
    w_draw.rectangle([(0, header_h - 2), (window_w - 1, header_h)], fill=(51, 65, 85, 200))

    # Traffic light buttons (macOS style)
    w_draw.ellipse([(14, 12), (24, 22)], fill=(239, 68, 68, 255))  # Close (Red)
    w_draw.ellipse([(32, 12), (42, 22)], fill=(245, 158, 11, 255))  # Min (Yellow)
    w_draw.ellipse([(50, 12), (60, 22)], fill=(16, 185, 129, 255))  # Max (Green)

    # Address / URL pill in center
    url_w = 260
    url_h = 22
    url_x = (window_w - url_w) // 2
    url_y = 7
    w_draw.rounded_rectangle([(url_x, url_y), (url_x + url_w, url_y + url_h)], radius=6, fill=(15, 23, 42, 220), outline=(51, 65, 85, 200), width=1)
    
    font_url = get_font(11, bold=False)
    w_draw.text((url_x + 14, url_y + 3), "🔒 medsina.medevsync.com", font=font_url, fill=(148, 163, 184, 255))

    # Paste screen content below header
    window.paste(cropped_screen, (0, header_h))

    # Apply overall rounded mask
    window.putalpha(mask)

    # 3. Add drop shadow
    shadow, pad = create_shadow((window_w, window_h), radius=28, offset=(0, 18), shadow_color=(0, 0, 0, 170))
    canvas = Image.new("RGBA", (window_w + pad * 2, window_h + pad * 2), (0, 0, 0, 0))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(window, (pad, pad), window)

    return canvas

def render_duo_mockup(desktop_img: Image.Image, mobile_img: Image.Image, canvas_w: int = 560, canvas_h: int = 580) -> Image.Image:
    """Renders both Desktop and Mobile in an aesthetic cross-platform arrangement."""
    duo = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))

    # 1. Desktop window in the background (width ~460)
    desktop_mock = render_desktop_mockup(desktop_img, target_width=440)
    duo.paste(desktop_mock, (0, 30), desktop_mock)

    # 2. Smartphone in the foreground right
    phone_mock = render_phone_mockup(mobile_img, target_width=220)
    duo.paste(phone_mock, (canvas_w - phone_mock.width + 10, canvas_h - phone_mock.height + 25), phone_mock)

    return duo

if __name__ == "__main__":
    p_desk = Path("assets/screenshots/desktop/prescription_audit_pc.png")
    p_mob = Path("assets/screenshots/mobile/clinical_copilot_mobile.png")

    if p_mob.exists():
        im_mob = Image.open(p_mob)
        mock_phone = render_phone_mockup(im_mob, 320)
        mock_phone.save("test_mockup_phone_final.png")
        print("Generated test_mockup_phone_final.png")

    if p_desk.exists():
        im_desk = Image.open(p_desk)
        mock_desk = render_desktop_mockup(im_desk, 540)
        mock_desk.save("test_mockup_desktop_final.png")
        print("Generated test_mockup_desktop_final.png")

    if p_desk.exists() and p_mob.exists():
        duo = render_duo_mockup(im_desk, im_mob, 560, 580)
        duo.save("test_mockup_duo_final.png")
        print("Generated test_mockup_duo_final.png")
