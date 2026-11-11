"""Acik iOS 18 ikonlarini "dark" varyanta cevirir.

Iki strateji:
  A) Arka plani duz olan ikonlar (Telefon, Mesajlar, Mail, Muzik...):
     kenar gradyanindan arka plan cikarilir, yerine cok koyu gradyan konur,
     glif rengi korunur (beyazsa ikonun vurgu rengine cevrilir).
  B) Gorseli ikonu tamamen kaplayan ikonlar (Safari, Fotograflar, Ayarlar,
     Hesap Makinesi, Haritalar...): nötr (dusuk doygunluk) pikseller karartilir,
     doygun renkler korunur.

Girdi:  theme/icons/<App>/<dosya>.png
Cikti:  theme/icons-dark/<App>/<dosya>.png
"""
import colorsys
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "theme", "icons")
DST = os.path.join(ROOT, "theme", "icons-dark")

# B stratejisinde renkli pikselleri de karartmak istedigin uygulamalar
DARKEN_STRONG = {"Maps", "MobileSlideShow"}

# karartma sonucu bozulan ikonlar: acik hali kullanilir
KEEP_LIGHT = {"Shoebox"}


def hls_of(c):
    return colorsys.rgb_to_hls(float(c[0]), float(c[1]), float(c[2]))


def dark_of(c, l, s_cap):
    h, _, s = hls_of(c)
    return np.array(colorsys.hls_to_rgb(h, l, min(s, s_cap)), np.float32)


def accent_of(c):
    h, _, s = hls_of(c)
    return np.array(colorsys.hls_to_rgb(h, 0.58, max(s, 0.55)), np.float32)


def background_model(rgb, al):
    """Ust/alt kenardan arka plan gradyanini tahmin eder + maske."""
    h = rgb.shape[0]
    band = max(1, int(0.04 * h))
    opaque = al > 0.9

    def band_color(rows):
        px = rgb[rows][opaque[rows]]
        return np.median(px, axis=0) if len(px) else np.array([0.5, 0.5, 0.5], np.float32)

    top = band_color(slice(0, band))
    bot = band_color(slice(h - band, h))

    v = top - bot
    nv = float(np.dot(v, v))
    if nv < 1e-4:
        resid = np.sqrt(((rgb - top[None, None, :]) ** 2).sum(axis=2))
    else:
        d = rgb - bot[None, None, :]
        t = np.clip(np.tensordot(d, v, axes=([2], [0])) / nv, 0.0, 1.0)
        proj = bot[None, None, :] + t[:, :, None] * v[None, None, :]
        resid = np.sqrt(((rgb - proj) ** 2).sum(axis=2))
    return top, bot, resid


def strategy_a(rgb, al, top, bot, resid):
    h, w, _ = rgb.shape
    ga = np.clip((resid - 0.06) / 0.18, 0.0, 1.0) * al

    strong = ga > 0.85
    glyph = np.median(rgb[strong], axis=0) if strong.sum() > 20 else np.array([1, 1, 1], np.float32)
    _, gl, gs = hls_of(glyph)

    if gl > 0.72 and gs < 0.22:
        glyph_layer = np.tile(accent_of(top), (h, w, 1))
    elif gl < 0.28:
        dist = np.sqrt(((rgb - glyph[None, None, :]) ** 2).sum(axis=2))
        glyph_layer = np.where((dist < 0.35)[:, :, None], np.array([0.93, 0.93, 0.95], np.float32), rgb)
    else:
        glyph_layer = rgb

    bg_top = dark_of(top, 0.17, 0.32)
    bg_bot = dark_of(bot, 0.07, 0.24)
    tt = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    bg = np.tile(bg_top[None, None, :] * (1 - tt) + bg_bot[None, None, :] * tt, (1, w, 1))

    safe = np.maximum(al, 1e-4)[:, :, None]
    out = (glyph_layer * ga[:, :, None] + bg * np.maximum(al - ga, 0)[:, :, None]) / safe
    return np.clip(out, 0, 1)


def strategy_b(rgb, al, strong=False):
    """Notr pikselleri koyuya cevir, doygun renkleri koru."""
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
    val = mx

    neutral = sat < 0.18
    new_val = np.where(neutral, 0.07 + (1.0 - val) * 0.33, val * (0.45 if strong else 0.88))

    scale = np.where(val > 1e-4, new_val / np.maximum(val, 1e-4), 0.0)
    out = np.clip(rgb * scale[:, :, None], 0, 1)
    return out


def convert(path, out_path, size=114):
    im = Image.open(path).convert("RGBA")
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, al = a[:, :, :3], a[:, :, 3]

    top, bot, resid = background_model(rgb, al)
    opaque = al > 0.9
    bg_frac = float((resid < 0.08)[opaque].mean()) if opaque.sum() else 0.0

    app = os.path.basename(os.path.dirname(out_path))
    if bg_frac >= 0.28:
        out = strategy_a(rgb, al, top, bot, resid)
    else:
        out = strategy_b(rgb, al, strong=app in DARKEN_STRONG)

    res = np.dstack([out, al])
    Image.fromarray((res * 255).round().astype(np.uint8), "RGBA").save(out_path)


def main():
    if not os.path.isdir(SRC):
        print("once tools/fetch_icons.py calistir")
        return 1
    n = 0
    for app in sorted(os.listdir(SRC)):
        s = os.path.join(SRC, app)
        if not os.path.isdir(s):
            continue
        d = os.path.join(DST, app)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(s):
            if f.endswith(".png"):
                if app in KEEP_LIGHT:
                    # karartma gorseli bozuyor (or. Wallet kart destesi) -> acik hali kullanilir
                    shutil.copyfile(os.path.join(s, f), os.path.join(d, f))
                else:
                    convert(os.path.join(s, f), os.path.join(d, f))
                n += 1
    print("%d dark ikon: %s" % (n, DST))
    return 0


if __name__ == "__main__":
    sys.exit(main())
