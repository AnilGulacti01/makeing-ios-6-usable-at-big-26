"""iOS 18 karsiligi olmayan sistem uygulamalarinin ORIGINAL ikonlarini
ayni koyu/flat stile cevirir. Ucuncu parti uygulamalara dokunulmaz.

Cihazdan ikon cekilir (base64 ile, binary bozulmasin), karartilir, squircle
maskesi uygulanir ve theme/icons-dark/<App>/icon@2x.png olarak yazilir.
"""
import base64
import os
import struct
import subprocess
import sys
import zlib

from PIL import Image

from fetch_icons import squircle
from make_dark import background_model, strategy_a, strategy_b

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HELPER = os.path.join(ROOT, "tools", "iphone.sh")
ORIG = os.path.join(ROOT, ".cache", "originals")
OUT = os.path.join(ROOT, "theme", "icons-dark")

# (uygulama klasoru, cihazdaki dosya, guclu karartma?)
APPS = [
    ("VoiceMemos", "icon@2x.png", False),
    ("Game Center~iphone", "icon@2x.png", True),
    ("Contacts~iphone", "icon@2x.png", False),
    ("MobileStore", "icon@2x.png", True),
    ("Nike", "icon@2x.png", True),
]


def decode_cgbi(data):
    """Apple'in CgBI (crush) PNG'sini normal RGBA'ya cevirir."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("PNG degil")
    i, chunks = 8, []
    while i < len(data):
        ln = struct.unpack(">I", data[i:i + 4])[0]
        typ = data[i + 4:i + 8]
        chunks.append((typ, data[i + 8:i + 8 + ln]))
        i += 12 + ln
        if typ == b"IEND":
            break

    ihdr = [p for t, p in chunks if t == b"IHDR"][0]
    w, h, depth, ctype, _, _, _ = struct.unpack(">IIBBBBB", ihdr)
    if depth != 8 or ctype != 6:
        raise ValueError("desteklenmeyen CgBI (depth=%d type=%d)" % (depth, ctype))

    raw = b"".join(p for t, p in chunks if t == b"IDAT")
    buf = zlib.decompressobj(-15).decompress(raw)  # zlib basligi yok

    bpp, stride = 4, w * 4
    out, prev, pos = bytearray(), bytearray(stride), 0
    for _ in range(h):
        ft = buf[pos]
        pos += 1
        line = bytearray(buf[pos:pos + stride])
        pos += stride
        if ft == 1:
            for j in range(bpp, stride):
                line[j] = (line[j] + line[j - bpp]) & 255
        elif ft == 2:
            for j in range(stride):
                line[j] = (line[j] + prev[j]) & 255
        elif ft == 3:
            for j in range(stride):
                a = line[j - bpp] if j >= bpp else 0
                line[j] = (line[j] + ((a + prev[j]) >> 1)) & 255
        elif ft == 4:
            for j in range(stride):
                a = line[j - bpp] if j >= bpp else 0
                b, c = prev[j], (prev[j - bpp] if j >= bpp else 0)
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[j] = (line[j] + pr) & 255
        out += line
        prev = line

    px = bytearray(len(out))
    for j in range(0, len(out), 4):
        bl, g, r, al = out[j], out[j + 1], out[j + 2], out[j + 3]
        if 0 < al < 255:  # premultiplied alpha geri al, BGRA -> RGBA
            r, g, bl = min(255, r * 255 // al), min(255, g * 255 // al), min(255, bl * 255 // al)
        px[j], px[j + 1], px[j + 2], px[j + 3] = r, g, bl, al
    return Image.frombytes("RGBA", (w, h), bytes(px))


def open_icon(path):
    with open(path, "rb") as f:
        data = f.read()
    if b"CgBI" in data[:64]:
        return decode_cgbi(data)
    return Image.open(path).convert("RGBA")


def fetch(app, filename):
    os.makedirs(ORIG, exist_ok=True)
    dst = os.path.join(ORIG, "%s.png" % app.replace(" ", "_").replace("~", "_"))
    if os.path.exists(dst):
        return dst
    remote = "/Applications/%s.app/%s" % (app, filename)
    out = subprocess.run(["bash", HELPER, "openssl base64 -in '%s'" % remote],
                         capture_output=True, check=True)
    data = base64.b64decode(out.stdout)
    with open(dst, "wb") as f:
        f.write(data)
    print("cekildi: %s (%d bayt)" % (app, len(data)))
    return dst


def convert(src, dst, size=114, strong=False):
    im = open_icon(src)
    # ekranda gorunen kare alani koru (iOS 6 ikonlari tam kare gelir)
    im = im.resize((size * 4, size * 4), Image.LANCZOS) if im.size[0] < size * 2 else im
    im = im.resize((size, size), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, al = a[:, :, :3], a[:, :, 3]
    top, bot, resid = background_model(rgb, al)
    opaque = al > 0.9
    bg_frac = float((resid < 0.08)[opaque].mean()) if opaque.sum() else 0.0
    out = strategy_a(rgb, al, top, bot, resid) if bg_frac >= 0.28 else strategy_b(rgb, al, strong)
    res = (np.dstack([out, al]) * 255).round().astype(np.uint8)
    img = Image.fromarray(res, "RGBA")
    img = squircle(img, size)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst)
    return bg_frac


def main():
    for app, filename, strong in APPS:
        src = fetch(app, filename)
        dst = os.path.join(OUT, app, filename)
        frac = convert(src, dst, strong=strong)
        print("dark: %-20s bg%%=%.2f -> %s" % (app, frac, os.path.relpath(dst, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
