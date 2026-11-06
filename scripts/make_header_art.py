#!/usr/bin/env python3
"""Compose 小象单词 product-page artwork for App Store Connect (标题 / 搜索结果).

Sizes accepted by App Store Connect:
    标题      5244 x 2950, 3840 x 1646
    搜索结果  5244 x 2950, 3840 x 2560, 1920 x 1280

Usage:
    python3 scripts/make_header_art.py AppStoreScreenshots/ProductPage
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_appstore_screenshots import GOLD, MASCOT, background, font  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ILLUSTRATIONS = os.path.join(ROOT, "YiCiQianJin", "Illustrations")
SERIF = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"

OUTPUTS = [
    ("title-5244x2950.png", (5244, 2950)),
    ("title-3840x1646.png", (3840, 1646)),
    ("search-3840x2560.png", (3840, 2560)),
    ("search-1920x1280.png", (1920, 1280)),
]

# (word, meaning, rotation in degrees) — back to front.
CARDS = [
    ("journey", "旅行，旅程", 9),
    ("festival", "节日；音乐节", -10),
    ("harbour", "海港，港口；庇护", 0),
]
TAGS = ["一词一画", "六种题型", "科学复习", "千金等级"]


def sparkle(draw: ImageDraw.ImageDraw, x: float, y: float, r: float, alpha: int = 230) -> None:
    pts = [(x, y - r * 2.2), (x + r * 0.5, y - r * 0.5), (x + r * 2.2, y), (x + r * 0.5, y + r * 0.5),
           (x, y + r * 2.2), (x - r * 0.5, y + r * 0.5), (x - r * 2.2, y), (x - r * 0.5, y - r * 0.5)]
    draw.polygon(pts, fill=(255, 236, 170, alpha))


def word_card(word: str, meaning: str, width: int) -> Image.Image:
    """Glassy card: illustration on top, serif headword and meaning below (like the study screen)."""
    pad = int(width * 0.06)
    art_w = width - pad * 2
    word_size, meaning_size = int(width * 0.15), int(width * 0.065)
    height = pad + art_w + int(pad * 0.9) + word_size + int(meaning_size * 0.6) + meaning_size + int(pad * 1.3)
    radius = int(width * 0.09)

    card = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    # Opaque so overlapping cards in the fan don't show through each other.
    d.rounded_rectangle((0, 0, width - 1, height - 1), radius, fill=(118, 104, 222, 255),
                        outline=(176, 166, 245, 255), width=max(2, width // 160))

    art = Image.open(os.path.join(ILLUSTRATIONS, f"{word}.webp")).convert("RGB")
    art = art.resize((art_w, art_w), Image.LANCZOS)
    mask = Image.new("L", art.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, art_w, art_w), int(radius * 0.7), fill=255)
    card.paste(art, (pad, pad), mask)

    y = pad + art_w + int(pad * 0.9)
    d.text((width / 2, y), word, font=ImageFont.truetype(SERIF, word_size), fill="white", anchor="ma")
    y += word_size + int(meaning_size * 0.6)
    d.text((width / 2, y), meaning, font=font("medium", meaning_size), fill=(255, 255, 255, 215), anchor="ma")
    return card


def with_shadow(img: Image.Image, blur: int, offset: int, opacity: int = 90) -> Image.Image:
    margin = blur * 3
    out = Image.new("RGBA", (img.width + margin * 2, img.height + margin * 2 + offset), (0, 0, 0, 0))
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    alpha = img.split()[3].point(lambda a: min(opacity, a))
    shadow.paste((20, 10, 60, 255), (margin, margin + offset), alpha)
    out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(blur)))
    out.alpha_composite(img, (margin, margin))
    return out


def compose(w: int, h: int) -> Image.Image:
    canvas = background(w, h)
    wide = w / h > 2.0  # 3840 x 1646 banner
    # Scale against a 16:9 box so 3:2 search art doesn't get oversized text that collides with the cards.
    u = min(h, int(w / 1.78))
    draw = ImageDraw.Draw(canvas)
    for cx, cy, r in ((0.06, 0.16, 0.012), (0.47, 0.12, 0.008), (0.93, 0.86, 0.01), (0.04, 0.84, 0.007)):
        sparkle(draw, cx * w, cy * h, r * u * (1.6 if wide else 1))

    # ---- Right: a fan of word cards, kept inside the central safe area.
    card_w = int(u * (0.40 if wide else 0.31))
    fan_cx = int(w * (0.72 if wide else 0.725))
    fan_cy = int(h * 0.52)
    spread = int(card_w * 0.74)  # side cards show their headword next to the front card
    for i, (word, meaning, angle) in enumerate(CARDS):
        front = i == len(CARDS) - 1
        cw = int(card_w * 1.08) if front else card_w
        card = with_shadow(word_card(word, meaning, cw), blur=int(card_w * 0.06), offset=int(card_w * 0.04))
        card = card.rotate(angle, resample=Image.BICUBIC, expand=True)
        dx = (spread if i == 0 else -spread if i == 1 else 0)
        dy = int(card_w * 0.08) if not front else -int(card_w * 0.02)
        canvas.alpha_composite(card, (fan_cx + dx - card.width // 2, fan_cy + dy - card.height // 2))

    # ---- Left: mascot, name, tagline, feature tags.
    left = int(w * (0.09 if wide else 0.08))
    mascot_size = int(u * (0.36 if wide else 0.30))
    title_size = int(u * (0.135 if wide else 0.105))
    sub_size = int(u * (0.05 if wide else 0.04))
    tag_size = int(u * (0.034 if wide else 0.027))
    tag_h = int(tag_size * 2.1)
    block_h = mascot_size + int(u * 0.01) + title_size + int(sub_size * 0.9) + sub_size + int(tag_size * 1.6) + tag_h
    y = (h - block_h) // 2

    mascot = Image.open(MASCOT).convert("RGBA").resize((mascot_size, mascot_size), Image.LANCZOS)
    canvas.alpha_composite(with_shadow(mascot, blur=int(mascot_size * 0.04), offset=int(mascot_size * 0.03), opacity=70),
                           (left - int(mascot_size * 0.04 * 3) - int(mascot_size * 0.06), y - int(mascot_size * 0.04 * 3)))
    y += mascot_size + int(u * 0.01)
    # Translucent shapes go on an overlay: ImageDraw on RGBA replaces pixels instead of blending.
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    draw = ImageDraw.Draw(canvas)
    draw.text((left, y), "小象单词", font=font("semibold", title_size), fill="white")
    y += title_size + int(sub_size * 0.9)
    draw.text((left, y), "一词一画 · 每天陪你记一个词", font=font("regular", sub_size), fill=(232, 228, 255))
    y += sub_size + int(tag_size * 1.6)

    tag_font = font("medium", tag_size)
    x = left
    for i, tag in enumerate(TAGS):
        tw = draw.textlength(tag, font=tag_font)
        pill_w = int(tw + tag_h * 0.9)
        if i == 0:
            draw.rounded_rectangle((x, y, x + pill_w, y + tag_h), tag_h // 2, fill=GOLD)
            color = (74, 41, 0)
        else:
            odraw.rounded_rectangle((x, y, x + pill_w, y + tag_h), tag_h // 2, fill=(255, 255, 255, 40),
                                    outline=(255, 255, 255, 130), width=max(2, u // 600))
            color = "white"
        odraw.text((x + pill_w / 2, y + tag_h / 2), tag, font=tag_font, fill=color, anchor="mm")
        x += pill_w + int(tag_h * 0.3)
    canvas = Image.alpha_composite(canvas, overlay)

    return canvas.convert("RGB")


def main(dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for name, (w, h) in OUTPUTS:
        img = compose(w, h)
        assert img.size == (w, h)
        path = os.path.join(dst, name)
        img.save(path, optimize=True)
        print(path, img.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "AppStoreScreenshots", "ProductPage"))
