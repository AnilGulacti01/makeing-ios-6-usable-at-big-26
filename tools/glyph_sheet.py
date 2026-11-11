"""Segoe MDL2 glif kataloğu — ikon seçmek için görsel sayfa üretir."""
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/segmdl2.ttf"
LABEL = "C:/Windows/Fonts/segoeui.ttf"

CELL = 56
COLS = 16
ROWS = 16


def sheet(start):
    img = Image.new("RGB", (COLS * CELL, ROWS * CELL), (18, 18, 22))
    d = ImageDraw.Draw(img)
    gf = ImageFont.truetype(FONT, 26)
    lf = ImageFont.truetype(LABEL, 9)
    for i in range(COLS * ROWS):
        cp = start + i
        x = (i % COLS) * CELL
        y = (i // COLS) * CELL
        d.text((x + CELL // 2, y + CELL // 2 - 4), chr(cp), font=gf,
               fill=(235, 235, 240), anchor="mm")
        d.text((x + CELL // 2, y + CELL - 9), "%04X" % cp, font=lf,
               fill=(130, 130, 145), anchor="mm")
    return img


if __name__ == "__main__":
    for start in [int(a, 16) for a in sys.argv[1:]] or [0xE700]:
        img = sheet(start)
        out = "tools/_sheet_%04X.png" % start
        img.save(out)
        print(out)
