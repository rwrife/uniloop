#!/usr/bin/env python3
"""Generate Windows Store listing art. Requires Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AppStore/windows"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with Image.open(ROOT / "AppStore/icon.png") as source:
        icon = source.convert("RGB")
    for size in (300, 150, 72):
        icon.resize((size, size), Image.Resampling.LANCZOS).save(
            OUT / f"app-tile-{size}x{size}.png"
        )

    logo = Image.new("RGB", (720, 1080), "#100b35")
    draw = ImageDraw.Draw(logo)
    for y in range(360):
        blend = y / 359
        color = tuple(round(a + (b - a) * blend) for a, b in (
            (49, 16), (16, 11), (88, 53)
        ))
        draw.line((0, y, 719, y), fill=color)
    font_path = str(ROOT / "assets/fonts/Bangers-Regular.ttf")
    title_font = ImageFont.truetype(font_path, 160)
    draw.text((364, 181), "UNILOOP", font=title_font, anchor="mm",
              fill="#7535a5", stroke_width=7, stroke_fill="#7535a5")
    draw.text((360, 171), "UNILOOP", font=title_font, anchor="mm",
              fill="#ffe600", stroke_width=3, stroke_fill="#100b35")
    subtitle_font = ImageFont.truetype(font_path, 36)
    draw.text((360, 288), "MOMENTUM RACER", font=subtitle_font,
              anchor="mm", fill="#66e7ff")
    logo.paste(icon.resize((720, 720), Image.Resampling.LANCZOS), (0, 360))
    logo.save(OUT / "store-logo-720x1080.png")

    with Image.open(ROOT / "assets/ui/splash.jpg") as source:
        hero = ImageOps.fit(source.convert("RGB"), (1920, 1080),
                            method=Image.Resampling.LANCZOS)
    hero.save(OUT / "hero-wallpaper-1920x1080.png")


if __name__ == "__main__":
    main()
