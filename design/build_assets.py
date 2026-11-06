#!/usr/bin/env python3
"""Render the 小象单词 app icon and in-app mascot images from design/mascot.svg.

Requires rsvg-convert (brew install librsvg) and Pillow.
    python3 design/build_assets.py
"""
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "YiCiQianJin", "Assets.xcassets")
TOP, BOTTOM = (96, 112, 236), (98, 58, 160)


def render_svg(size: int) -> Image.Image:
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        out = f.name
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), os.path.join(HERE, "mascot.svg"), "-o", out], check=True)
    img = Image.open(out).convert("RGBA")
    os.remove(out)
    return img


def icon(size: int = 1024) -> Image.Image:
    t = (np.arange(size)[None, :] / size * 0.4 + np.arange(size)[:, None] / size * 0.6)[..., None]
    top, bottom = np.array(TOP, float), np.array(BOTTOM, float)
    bg = Image.fromarray((top + (bottom - top) * t).astype("uint8"), "RGB").convert("RGBA")
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Soft top-left highlight (a gold glow turns muddy grey over the violet).
    ImageDraw.Draw(glow).ellipse((-size * 0.3, -size * 0.4, size * 0.75, size * 0.45), fill=(255, 255, 255, 55))
    bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(size * 0.12)))
    # Little sparkles echo the gold reward theme.
    d = ImageDraw.Draw(bg)
    for cx, cy, r in ((0.17, 0.2, 0.022), (0.84, 0.17, 0.016), (0.13, 0.78, 0.014)):
        x, y, rr = cx * size, cy * size, r * size
        d.polygon([(x, y - rr * 2.2), (x + rr * 0.5, y - rr * 0.5), (x + rr * 2.2, y), (x + rr * 0.5, y + rr * 0.5),
                   (x, y + rr * 2.2), (x - rr * 0.5, y + rr * 0.5), (x - rr * 2.2, y), (x - rr * 0.5, y - rr * 0.5)],
                  fill=(255, 236, 170, 230))
    mascot = render_svg(int(size * 0.94))
    off = ((size - mascot.width) // 2, int(size * 0.045))
    bg.alpha_composite(mascot, off)
    return bg.convert("RGB")  # App Store icons must not have an alpha channel


def main() -> None:
    icon_path = os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon.png")
    icon().save(icon_path, optimize=True)
    print("wrote", icon_path)

    mascot_dir = os.path.join(ASSETS, "Mascot.imageset")
    os.makedirs(mascot_dir, exist_ok=True)
    for scale in (1, 2, 3):
        render_svg(200 * scale).save(os.path.join(mascot_dir, f"Mascot@{scale}x.png"), optimize=True)
    with open(os.path.join(mascot_dir, "Contents.json"), "w") as f:
        f.write("""{
  "images" : [
    { "filename" : "Mascot@1x.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "Mascot@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "Mascot@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""")
    print("wrote", mascot_dir)


if __name__ == "__main__":
    main()
