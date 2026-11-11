"""iOS 18 ikon setini indirir ve iPhone 4 (iOS 6) icin 114x114 PNG uretir.

Kaynaklar:
  1) catwithabaloon/iOS-18-icon-pack (Beta "Light" zip) - 1024px, gercek iOS 18 ikonlari
  2) SysAdminDoc/iOSIconPack (MIT) - iOS 18 gorunumlu, 192px; eksik kalanlar icin

Cikti: theme/icons/<App.app>/<hedef-dosya>.png
Kalici (dinamik) ikonlar bilerek degistirilmez: Takvim ve Saat — SpringBoard bunlari
canli cizer, statik PNG koyarsak tarih/saat donar.
"""
import io
import os
import sys
import zipfile
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, ".cache")
OUT = os.path.join(ROOT, "theme", "icons")

BETA_ZIP = ("https://github.com/catwithabaloon/iOS-18-icon-pack/releases/"
            "download/Beta/IOS.18.Icons.Light.zip")
MIT_RAW = ("https://raw.githubusercontent.com/SysAdminDoc/iOSIconPack/master/"
           "app/src/main/res/drawable-xxxhdpi/%s.png")

# (uygulama klasoru, cihazdaki ikon dosyasi, kaynak)
#   beta:<dosya adi>   -> 1024px zip icinden
#   mit:<ad>           -> MIT repodan tek dosya
MAP = [
    ("MobilePhone",       "icon@2x~iphone.png", "beta:com.apple.mobilephone"),
    ("MobileSMS",         "icon@2x.png",        "beta:com.apple.MobileSMS"),
    ("MobileSafari",      "icon@2x~iphone.png", "beta:com.apple.mobilesafari"),
    ("Camera",            "Camera@2x~iphone.png", "beta:com.apple.camera"),
    ("MobileSlideShow",   "Photos@2x~iphone.png", "beta:com.apple.mobileslideshow"),
    ("Music~iphone",      "icon@2x.png",        "beta:com.apple.Music"),
    ("MobileMail",        "Icon@2x.png",        "beta:com.apple.mail"),
    ("Preferences",       "icon@2x~iphone.png", "beta:settings app"),
    ("Weather",           "icon@2x.png",        "beta:com.apple.weather"),
    ("Maps",              "Icon@2x.png",        "beta:com.apple.Maps"),
    ("MobileNotes",       "icon@2x.png",        "beta:com.apple.Notes"),
    ("Calculator",        "icon@2x.png",        "beta:com.apple.calculator"),
    ("AppStore",          "icon@2x.png",        "beta:com.apple.AppStore"),
    ("Reminders",         "icon@2x.png",        "beta:com.apple.reminders"),
    ("Stocks",            "icon@2x~iphone.png", "beta:com.apple.stocks"),
    ("Videos",            "icon@2x.png",        "beta:AppleTVLogo.svg"),
    ("Compass",           "Icon@2x.png",        "mit:ios18_compass"),
    # canli cizilen Takvim/Saat de statik iOS 18 ikonuna cevriliyor
    ("MobileCal",         "icon@2x~iphone.png", "mit:ios18_calendar"),
    ("MobileTimer",       "icon@2x~iphone.png", "beta:com.apple.mobiletimer"),
    ("Shoebox",           "icon@2x.png",        "beta:com.apple.Passbook"),
]

SIZES = {"icon@2x~iphone.png": 114, "icon@2x.png": 114, "Icon@2x.png": 114,
         "Camera@2x~iphone.png": 114, "Photos@2x~iphone.png": 114}


def squircle(img, out_size=114, power=4.6, ss=4):
    """iOS tarzi yuvarlak kose (superellipse) maskesi uygular.

    4x buyuk tuvalde maskelenir, sonra hedef boyuta kucultulur -> kenarlar yumusak.
    """
    import numpy as np

    n = out_size * ss
    big = img.resize((n, n), Image.LANCZOS)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    inside = (np.abs((xx - c) / c) ** power + np.abs((yy - c) / c) ** power) <= 1.0
    alpha = np.minimum(np.asarray(big.split()[3], dtype=np.float32),
                       np.where(inside, 255.0, 0.0)).astype(np.uint8)
    big.putalpha(Image.fromarray(alpha))
    return big.resize((out_size, out_size), Image.LANCZOS)


def download(url, path):
    if os.path.exists(path):
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    print("indiriliyor:", url)
    with urllib.request.urlopen(url, timeout=90) as r, open(path, "wb") as f:
        f.write(r.read())
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    zpath = download(BETA_ZIP, os.path.join(CACHE, "ios18-light.zip"))
    zf = zipfile.ZipFile(zpath)
    names = zf.namelist()

    written = []
    for app, target, src in MAP:
        kind, key = src.split(":", 1)
        if kind == "beta":
            match = [n for n in names if os.path.basename(n).lower() == key.lower() + ".png"]
            if not match:
                print("!! beta icinde yok:", key)
                continue
            data = zf.read(match[0])
            img = Image.open(io.BytesIO(data)).convert("RGBA")
        else:
            p = download(MIT_RAW % key, os.path.join(CACHE, key + ".png"))
            img = Image.open(p).convert("RGBA")

        size = SIZES.get(target, 114)
        img = squircle(img, size)
        d = os.path.join(OUT, app)
        os.makedirs(d, exist_ok=True)
        out = os.path.join(d, target)
        img.save(out)
        written.append(out)
        print("yazildi: %-22s -> %s" % (app, target))

    print("\n%d ikon hazir: %s" % (len(written), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
