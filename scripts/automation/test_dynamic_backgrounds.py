#!/usr/bin/env python3
"""
Test Dynamic Diverse Background Generation for Medsina Facebook Posts
"""

import os
import random
from PIL import Image, ImageDraw, ImageFilter

THEME_PALETTES = {
    "blue": {
        "bg_top": (10, 28, 55),
        "bg_bottom": (12, 18, 32),
        "accent": (14, 165, 233),
        "accent_glow": (56, 189, 248),
        "badge_bg": (12, 74, 110),
        "card_bg": (20, 32, 55, 235),
        "card_border": (56, 189, 248, 90),
    },
    "emerald": {
        "bg_top": (6, 42, 32),
        "bg_bottom": (10, 24, 20),
        "accent": (16, 185, 129),
        "accent_glow": (52, 211, 153),
        "badge_bg": (6, 78, 59),
        "card_bg": (16, 38, 30, 235),
        "card_border": (52, 211, 153, 90),
    },
    "purple": {
        "bg_top": (38, 16, 58),
        "bg_bottom": (16, 12, 30),
        "accent": (168, 85, 247),
        "accent_glow": (192, 132, 252),
        "badge_bg": (88, 28, 135),
        "card_bg": (35, 20, 50, 235),
        "card_border": (192, 132, 252, 90),
    },
    "ruby": {
        "bg_top": (50, 14, 24),
        "bg_bottom": (22, 10, 16),
        "accent": (244, 63, 94),
        "accent_glow": (251, 113, 133),
        "badge_bg": (136, 19, 55),
        "card_bg": (42, 16, 24, 235),
        "card_border": (251, 113, 133, 90),
    },
    "amber": {
        "bg_top": (48, 28, 8),
        "bg_bottom": (22, 15, 10),
        "accent": (245, 158, 11),
        "accent_glow": (251, 191, 36),
        "badge_bg": (120, 53, 15),
        "card_bg": (38, 26, 18, 235),
        "card_border": (251, 191, 36, 90),
    },
    "cyan": {
        "bg_top": (6, 38, 52),
        "bg_bottom": (10, 22, 32),
        "accent": (6, 182, 212),
        "accent_glow": (34, 211, 238),
        "badge_bg": (22, 78, 99),
        "card_bg": (16, 36, 48, 235),
        "card_border": (34, 211, 238, 90),
    },
    "indigo": {
        "bg_top": (20, 24, 64),
        "bg_bottom": (12, 14, 34),
        "accent": (99, 102, 241),
        "accent_glow": (129, 140, 248),
        "badge_bg": (49, 46, 129),
        "card_bg": (24, 26, 56, 235),
        "card_border": (129, 140, 248, 90),
    },
    "slate": {
        "bg_top": (28, 34, 46),
        "bg_bottom": (12, 16, 26),
        "accent": (56, 189, 248),
        "accent_glow": (148, 163, 184),
        "badge_bg": (30, 41, 59),
        "card_bg": (26, 34, 48, 235),
        "card_border": (148, 163, 184, 90),
    }
}

PATTERN_STYLES = ["grid", "dots", "rings", "aurora", "mesh"]


def generate_dynamic_background(
    width: int = 1080,
    height: int = 1080,
    theme_key: str = None,
    pattern: str = None,
    gradient_type: str = None
) -> tuple[Image.Image, dict]:
    """
    Generates a rich, unique, high-end background with gradient, dynamic lighting, and subtle patterns.
    """
    # 1. Select palette
    if not theme_key or theme_key not in THEME_PALETTES:
        theme_key = random.choice(list(THEME_PALETTES.keys()))
    t = THEME_PALETTES[theme_key]

    # 2. Select gradient style (vertical, diagonal_tl_br, diagonal_tr_bl, radial)
    if not gradient_type:
        gradient_type = random.choice(["vertical", "diagonal_tl_br", "diagonal_tr_bl", "radial"])

    base = Image.new("RGBA", (width, height), t["bg_bottom"])
    draw = ImageDraw.Draw(base)

    if gradient_type == "vertical":
        for y in range(height):
            ratio = y / height
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    elif gradient_type == "diagonal_tl_br":
        max_dist = width + height
        for i in range(0, max_dist, 2):
            ratio = i / max_dist
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            # Draw 45 degree line
            draw.line([(0, i), (i, 0)], fill=(r, g, b, 255), width=2)
    elif gradient_type == "diagonal_tr_bl":
        max_dist = width + height
        for i in range(0, max_dist, 2):
            ratio = i / max_dist
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.line([(width, i), (width - i, 0)], fill=(r, g, b, 255), width=2)
    else:  # radial
        cx, cy = width // 2, int(height * 0.4)
        max_rad = int(((width / 2) ** 2 + height ** 2) ** 0.5)
        for r_step in range(max_rad, 0, -4):
            ratio = r_step / max_rad
            r = int(t["bg_top"][0] * (1 - ratio) + t["bg_bottom"][0] * ratio)
            g = int(t["bg_top"][1] * (1 - ratio) + t["bg_bottom"][1] * ratio)
            b = int(t["bg_top"][2] * (1 - ratio) + t["bg_bottom"][2] * ratio)
            draw.ellipse(
                [(cx - r_step, cy - r_step), (cx + r_step, cy + r_step)],
                fill=(r, g, b, 255)
            )

    # 3. Dynamic ambient glowing halos
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Main accent halo
    halo_x = random.choice([int(width * 0.1), int(width * 0.75), int(width * 0.5)])
    halo_y = random.choice([int(height * 0.15), int(height * 0.45), int(height * 0.8)])
    glow_draw.ellipse(
        [(halo_x - 300, halo_y - 300), (halo_x + 300, halo_y + 300)],
        fill=(*t["accent"], 45)
    )

    # Secondary complementary halo
    halo2_x = width - halo_x
    halo2_y = height - halo_y
    glow_draw.ellipse(
        [(halo2_x - 250, halo2_y - 250), (halo2_x + 250, halo2_y + 250)],
        fill=(*t["accent_glow"], 35)
    )

    glow = glow.filter(ImageFilter.GaussianBlur(85))
    base = Image.alpha_composite(base, glow)

    # 4. Subtle texture / pattern overlay
    if not pattern:
        pattern = random.choice(PATTERN_STYLES)

    pattern_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(pattern_layer)

    if pattern == "grid":
        # Tech blueprint grid
        step = 54
        for x in range(0, width, step):
            p_draw.line([(x, 0), (x, height)], fill=(255, 255, 255, 11), width=1)
        for y in range(0, height, step):
            p_draw.line([(0, y), (width, y)], fill=(255, 255, 255, 11), width=1)
        # Random crosshairs
        for _ in range(8):
            rx = random.randint(1, width // step - 1) * step
            ry = random.randint(1, height // step - 1) * step
            p_draw.line([(rx - 6, ry), (rx + 6, ry)], fill=(*t["accent_glow"], 50), width=1)
            p_draw.line([(rx, ry - 6), (rx, ry + 6)], fill=(*t["accent_glow"], 50), width=1)

    elif pattern == "dots":
        # Matrix dots
        step = 40
        for x in range(20, width, step):
            for y in range(20, height, step):
                p_draw.ellipse([(x - 1, y - 1), (x + 1, y + 1)], fill=(255, 255, 255, 16))

    elif pattern == "rings":
        # Concentric tech radar / sonar pulses
        cx, cy = int(width * 0.75), int(height * 0.45)
        for r_step in range(60, 600, 75):
            p_draw.ellipse(
                [(cx - r_step, cy - r_step), (cx + r_step, cy + r_step)],
                outline=(*t["accent"], 18),
                width=1
            )

    elif pattern == "aurora":
        # Diagonal luminous light streak
        streak = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(streak)
        s_draw.line([(-200, height + 200), (width + 200, -200)], fill=(*t["accent_glow"], 35), width=120)
        s_draw.line([(-100, height + 300), (width + 300, -100)], fill=(*t["accent"], 25), width=80)
        streak = streak.filter(ImageFilter.GaussianBlur(60))
        pattern_layer = Image.alpha_composite(pattern_layer, streak)

    elif pattern == "mesh":
        # Angled geometric polygons
        for i in range(4):
            poly_x = random.randint(100, width - 100)
            poly_y = random.randint(100, height - 100)
            poly_r = random.randint(60, 160)
            p_draw.regular_polygon((poly_x, poly_y, poly_r), n_sides=6, outline=(255, 255, 255, 14), width=1)

    base = Image.alpha_composite(base, pattern_layer)

    return base, t


if __name__ == "__main__":
    for i, p in enumerate(PATTERN_STYLES):
        bg, theme = generate_dynamic_background(pattern=p)
        filename = f"test_bg_{p}.png"
        bg.save(filename)
        print(f"Saved {filename} with pattern {p}")

