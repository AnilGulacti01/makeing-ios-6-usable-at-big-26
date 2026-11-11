# iOS 6 (iPhone 4) — ne var ne yok

Bu dosya, arayüz yazarken "bu çalışır mı?" sorusunun tek kaynağı. Cihaz: iPhone 4
(iPhone3,1), iOS 6.1.6, Safari/WebKit 536.26, 320×480 pt @2x, 512 MB RAM, armv7.

## YOK — yazma, çalışmaz

| Özellik | Not |
|---|---|
| CSS değişkeni `var(--x)` | 2016+ |
| CSS Grid, `gap`, `aspect-ratio`, `min()`/`clamp()` | yok |
| `backdrop-filter` | cam efekti taklit edilecek (rgba + kenar ışığı) |
| `position: sticky`, `:is()`, `:where()`, `:has()` | yok |
| Modern flexbox (`gap`, `flex-basis`) | `-webkit-box` kullan veya inline-block |
| `let`, `const`, arrow function, template literal, class, Promise, fetch | **ES5 zorunlu** |
| `Array.from`, `Object.assign`, `includes`, `Map/Set` | yok |
| `requestAnimationFrame` döngüleri | var ama A4'te pil yer |
| `@font-face` ile SF Pro | lisans + performans; sistem Helvetica Neue kullan |
| Girinti/scroll momentum iyi | `-webkit-overflow-scrolling: touch` var |

## VAR

| Özellik | Not |
|---|---|
| `-webkit-filter: blur()/saturate()` | iOS 6'da geldi; **statik** kullan, animasyonda kullanma |
| SVG (inline, `<use xlink:href>`) | sprite çalışır |
| `border-radius`, gradyan (`-webkit-linear-gradient` + standard), `box-shadow` | |
| `transform`, `transition` | sadece transform/opacity geçişi akıcı |
| `touchstart/touchmove/touchend` | `click` gecikmeli; tap için touchend + preventDefault |
| `-webkit-tap-highlight-color` | mavi kutu flash'ını kapatır |
| `canvas`, `localStorage` | var |

## Performans / batarya eşikleri

- Tek karede tam ekran blur = A4'te 20-30 ms. Panel açılışında 1 kez bile sınırda;
  tercih etme.
- `box-shadow` büyük yarıçap (30px+) + animasyon = kare düşmesi.
- Sürekli `setInterval` (saat 1 sn'de bir) → CPU uyanık kalır. 20-60 sn yeter.
- Görsel ağırlık: toplam prototip < 300 KB hedef (3G'siz, RAM dar).
- Ekran kapalıyken WebView'da timer çalıştırma.

## Cihaz bağlantısı

- SSH: `ssh root@<ip>` (Cydia → OpenSSH kurulu, varsayılan şifre `alpine` — değiştir).
- Dosya kopyalama: `scp -r prototype root@<ip>:/var/mobile/`
- SpringBoard yeniden başlatma: `ssh root@<ip> "killall -9 SpringBoard"`
- Debian paket kurulumu (native kabuk aşaması): `dpkg -i paket.deb` + `killall SpringBoard`
- Cydia deposu gerekmez; doğrudan `scp` + `dpkg` yeterli.
