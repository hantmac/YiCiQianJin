#!/usr/bin/env python3
"""Compose App Store marketing screenshots (headline + real app UI) at exact App Store Connect sizes (iPhone Duo and Dynamic Island iPhones).

Raw captures come from the UI test AppStoreScreenshotTests:
    TEST_RUNNER_SCREENSHOT_DIR=/tmp/duo-outer xcodebuild test ... \
        -only-testing:YiCiQianJinUITests/AppStoreScreenshotTests

Usage:
    python3 scripts/make_appstore_screenshots.py outer /tmp/duo-outer AppStoreScreenshots/iPhoneDuo-outer
    python3 scripts/make_appstore_screenshots.py inner /tmp/duo-inner AppStoreScreenshots/iPhoneDuo-inner

App Store Connect sizes: outer 1398 x 2034 (or 2034 x 1398), inner 2007 x 2853 (or 2853 x 2007).
Kinds: outer, outer-landscape, inner, inner-landscape, iphone-6.3, iphone-6.5, iphone-6.9, ipad-13, ipad-12.9 (+ -landscape).
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZES = {
    "outer": (1398, 2034),
    "outer-landscape": (2034, 1398),
    "inner": (2007, 2853),
    "inner-landscape": (2853, 2007),
    # iPhone with Dynamic Island. Raw captures: iPhone 17 Pro (1206 x 2622) work for all three.
    "iphone-6.3": (1206, 2622),   # 中等显示屏 (6.1"/6.3")
    "iphone-6.5": (1284, 2778),   # 6.5"
    "iphone-6.9": (1320, 2868),   # 大显示屏 (6.9")
    # iPad 13" / 12.9". Raw captures: iPad Pro 13-inch (M5), 2064 x 2752.
    "ipad-13": (2064, 2752),
    "ipad-12.9": (2048, 2732),
    "ipad-13-landscape": (2752, 2064),
    "ipad-12.9-landscape": (2732, 2048),
}

# (raw capture name, headline, subline) in App Store order.
SLIDES = [
    ("1-study", "一词一画，看见就记住", "每个单词配一幅插画，还有双语例句和真人般发音"),
    ("2-picture-quiz", "看图选词，越考越上瘾", "第二天先考昨天的词，六种题型轮番上阵"),
    ("3-home", "每天一个词，连胜不断", "今日任务一目了然，学完倒计时等明天的新词"),
    ("4-library", "温故知新，记忆看得见", "按记忆规律自动复习，易错词、掌握度清清楚楚"),
    ("5-check-in", "赚千金，升等级，解锁成就", "从「词汇萌新」一路晋升到「千金状元」"),
]

ROTATE = "cw"  # how sideways landscape captures are turned upright; see compose()

MASCOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "YiCiQianJin",
                      "Assets.xcassets", "Mascot.imageset", "Mascot@3x.png")

TOP = (92, 107, 230)
BOTTOM = (92, 56, 148)
GOLD = (255, 209, 92)


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    paths = glob.glob("/System/Library/Fonts/PingFang.ttc") + glob.glob(
        "/System/Library/AssetsV2/com_apple_MobileAsset_Font*/*/AssetData/PingFang.ttc")
    if not paths:
        sys.exit("PingFang.ttc not found")
    index = {"regular": 3, "medium": 7, "semibold": 11}[weight]  # PingFang SC faces
    return ImageFont.truetype(paths[0], size, index=index)


def background(w: int, h: int) -> Image.Image:
    import numpy as np
    t = (np.arange(w)[None, :] / w * 0.35 + np.arange(h)[:, None] / h * 0.65)[..., None]
    top, bottom = np.array(TOP, float), np.array(BOTTOM, float)
    grad = Image.fromarray((top + (bottom - top) * t).astype("uint8"), "RGB")
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((w * 0.45, -h * 0.25, w * 1.35, h * 0.35), fill=GOLD + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    return Image.alpha_composite(grad.convert("RGBA"), glow)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width, img.height), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(kind: str, raw_path: str, headline: str, subline: str) -> Image.Image:
    w, h = SIZES[kind]
    landscape = w > h
    u = min(w, h)  # type scale follows the short side so landscape text isn't oversized
    canvas = background(w, h)
    draw = ImageDraw.Draw(canvas)

    # Brand pill + headline + subline, centered.
    pad_top = int(h * (0.045 if landscape else 0.055))
    pill_font = font("semibold", int(u * 0.026))
    pill_text = "小象单词"
    tw = draw.textlength(pill_text, font=pill_font)
    pill_h = int(u * 0.052)
    pill_w = int(tw + pill_h * 1.1)
    # Mascot sits left of the brand pill; the pair is centered together.
    mascot_size = int(pill_h * 2.1)
    gap = int(pill_h * 0.25)
    group_w = mascot_size + gap + pill_w
    gx = (w - group_w) // 2
    mascot = Image.open(MASCOT).convert("RGBA").resize((mascot_size, mascot_size), Image.LANCZOS)
    canvas.alpha_composite(mascot, (gx, pad_top + pill_h // 2 - mascot_size // 2))
    px = gx + mascot_size + gap
    draw.rounded_rectangle((px, pad_top, px + pill_w, pad_top + pill_h), pill_h // 2, fill=GOLD)
    draw.text((px + pill_w / 2, pad_top + pill_h / 2), pill_text, font=pill_font, fill=(74, 41, 0), anchor="mm")
    pad_top += (mascot_size - pill_h) // 2  # headline starts below the mascot

    head_size = int(u * (0.062 if landscape else 0.072))
    head_font = font("semibold", head_size)
    y = pad_top + pill_h + int(u * 0.03)
    draw.text((w / 2, y), headline, font=head_font, fill="white", anchor="ma")
    y += int(head_size * 1.35)
    sub_size = int(u * (0.03 if landscape else 0.034))
    sub_font = font("regular", sub_size)
    draw.text((w / 2, y), subline, font=sub_font, fill=(255, 255, 255, 215), anchor="ma")
    text_bottom = y + int(sub_size * 1.6)

    shot = Image.open(raw_path).convert("RGB")
    if landscape and shot.height > shot.width:
        # XCUIScreenshot returns the raw portrait framebuffer; landscape UI comes out sideways.
        # Duo inner (unfolded in DeviceHub) needs clockwise; tests that set .landscapeLeft need
        # counter-clockwise (pass "ccw" as the 4th argument).
        shot = shot.rotate(90 if ROTATE == "ccw" else -90, expand=True)
    sy = text_bottom + int(u * 0.035)
    if landscape and kind.startswith("ipad"):
        # iPad: the app UI is small on a 13" canvas, so go big and bleed off the bottom edge.
        target_w = int(w * 0.84)
    elif landscape:
        # Fit entirely below the headline so both panes of the split layout stay visible.
        avail_h = h - sy - int(u * 0.05)
        target_w = min(int(w * 0.86), int(avail_h * shot.width / shot.height))
    else:
        # Portrait: bottom-anchored, bleeding off the bottom edge.
        target_w = int(w * 0.80)
    scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    radius = int(min(target_w, shot.height) * 0.065)
    framed = rounded(shot, radius)
    sx = (w - target_w) // 2

    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((sx, sy + 24, sx + target_w, sy + shot.height + 24), radius, fill=(20, 10, 60, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(framed, (sx, sy))
    border = ImageDraw.Draw(canvas)
    border.rounded_rectangle((sx, sy, sx + target_w, sy + shot.height), radius, outline=(255, 255, 255, 90), width=max(3, u // 400))
    return canvas.convert("RGB")


def main(kind: str, src: str, dst: str) -> None:
    if kind not in SIZES:
        sys.exit(f"kind must be one of {list(SIZES)}")
    os.makedirs(dst, exist_ok=True)
    for i, (name, headline, subline) in enumerate(SLIDES, start=1):
        raw = os.path.join(src, name + ".png")
        if not os.path.exists(raw):
            sys.exit(f"missing capture {raw}")
        raw_w, raw_h = Image.open(raw).size
        if raw_w > raw_h and SIZES[kind][0] < SIZES[kind][1]:
            sys.exit(f"{raw} is {raw_w}x{raw_h}; orientation doesn't match kind '{kind}'")
        out = compose(kind, raw, headline, subline)
        assert out.size == SIZES[kind]
        path = os.path.join(dst, f"{i:02d}-{name}.png")
        out.save(path, optimize=True)
        print(path, out.size)


if __name__ == "__main__":
    if len(sys.argv) == 5:
        ROTATE = sys.argv.pop()
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
