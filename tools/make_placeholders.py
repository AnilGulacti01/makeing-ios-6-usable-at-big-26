"""iOS 18 karsiligi bulunmayan sistem uygulamalari icin, dark setin diliyle
duz (flat) monogram ikon uretir. Yabanci marka/logosu taklit etmez.

Cikti: theme/icons-dark/<App>/<dosya>.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from fetch_icons import squircle

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "theme", "icons-dark")
FONT = "C:/Windows/Fonts/segoeui.ttf"

# (uygulama klasoru, ikon dosyasi, harf, ust renk, alt renk)
ITEMS = [
    ("VoiceMemos", "icon@2x.png", "S", (196, 42, 52), (108, 16, 26)),
    ("Game Center~iphone", "icon@2x.png", "O", (26, 132, 138), (10, 58, 66)),
    ("Contacts~iphone", "icon@2x.png", "K", (70, 70, 78), (34, 34, 40)),
    ("MobileStore", "icon@2x.png", "i", (150, 40, 170), (58, 14, 74)),
    ("Nike", "icon@2x.png", "N", (168, 62, 24), (70, 24, 10)),
]


def make(letter, top, bot, size=456):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1.0)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    f = ImageFont.truetype(FONT, int(size * 0.52))
    d.text((size / 2, size / 2), letter, font=f, fill=(245, 245, 250), anchor="mm")
    return img.convert("RGBA")


def main():
    for app, filename, letter, top, bot in ITEMS:
        img = squircle(make(letter, top, bot), 114)
        d = os.path.join(OUT, app)
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, filename))
        print("placeholder: %-20s %s" % (app, letter))
    return 0


if __name__ == "__main__":
    sys.exit(main())
