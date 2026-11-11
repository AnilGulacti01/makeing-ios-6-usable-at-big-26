# makeing ios 6 usable at big 26

iPhone 4 (iOS 6.1, jailbreak) cihazı **bugün hâlâ kullanılabilir** hale getirme projesi.
Birinci hedef: modern iOS arayüzü (iOS 18 düzeni + iOS 26 "Liquid Glass" hissi), bataryayı
sömürmeden.

> **Durum: geliştirme aşamasında (WIP).** Cihazda çalışan bir sürüm var ama API'ler,
> dosya yolları ve kurulum adımları değişebilir. Sürüm notları ve cihaz üzerinde
> doğrulanan davranışlar `docs/DEVICE.md` içinde.

## Şu an durum

| Katman | Durum |
|---|---|
| Springboard UI prototipi (HTML/CSS/JS) | ✅ çalışıyor — `prototype/` |
| iOS 18 koyu ikon seti (24 sistem uygulaması, gerçek SpringBoard) | ✅ cihazda kurulu |
| Native tweak `HikaruUI.dylib` (armv7 + arm64 olmayan cihaz) | ✅ cihazda çalışıyor |
| Dinamik uygulama listesi (sistem + App Store uygulamaları) | ✅ otomatik tarama, yeni kurulan uygulama ana ekrana düşer |
| Uygulama açma (SBUIController) + ikon zoom animasyonu | ✅ |
| Ayarlar > Hikaru: modern ana ekranı aç/kapat | ✅ PreferenceBundle, respring gerekmez |
| Klasörler, widget'lar, arama, kilit ekranı | ⬜ sırada |

Kurulum ve derleme: `docs/DEVICE.md` (WSL + theos SDK + `native/build.sh`).

## Neden HTML/CSS ile başladık

- iPhone 4 = A4, 512 MB RAM, 1420 mAh batarya. Her şeyi native yazmak en hafif çözüm
  ama derleme için macOS/theos zinciri gerekiyor; UI'ı tasarlamak için her seferinde
  derleme beklemek iterasyonu öldürüyor.
- iOS 6 Safari (WebKit 536) bu iş için yeterli: `-webkit-filter`, SVG, `border-radius`,
  gradient, transform geçişleri var. Yeter ki **ES5** ve **prefix'li** yazılsın.
- UI oturunca aynı işareti native kabuğa taşıyacağız (UIWebView ya da doğrudan UIKit).

## Hızlı test

Windows'ta (bu makinede):

```bash
cd prototype && python -m http.server 8080
# Chrome: http://localhost:8080
```

Telefonda (aynı Wi-Fi):

```
Safari -> http://192.168.1.125:8080
```

Sonra "Ana Ekrana Ekle" ile tam ekran açabiirsin. Kısayollar: `C` kontrol merkezi,
`S` arama, `Esc` kapat (masaüstü önizlemede).

## Yapı

```
prototype/          çalışan arayüz (iOS 6 uyumlu, ES5)
  index.html        iskelet + SVG ikon sprite
  css/ui.css        tüm stil (prefix'li, grid/flex/gap yok)
  js/ui.js          uygulama listesi, sayfalama, arama, kontrol merkezi
docs/IOS6-LIMITS.md ne var ne yok (kritik referans)
tools/serve.sh      yerel sunucu
tools/deploy.sh     SSH ile cihaza kopyala + respring
```

## Batarya kuralları (pazarlık konusu değil)

1. Sürekli çalışan animasyon yok. Sürekli `setInterval` yok (saat 20 sn'de bir).
2. Canlı blur yerine statik gradient/rgba katman. `-webkit-backdrop-filter` iOS 6'da yok;
   `-webkit-filter: blur()` var ama her karede çalıştırmak A4'ü yorar.
3. Ekran kapalıyken UI tamamen durur (native kabukta `applicationDidEnterBackground`).
4. Uygulama arka planda tutulmaz; aç → kullan → çık mantığı.
5. Animasyonlar sadece `transform` / `opacity` (GPU), 250 ms altı.

## İkonlar

```bash
python tools/fetch_icons.py     # kaynaklardan indirir, 114x114 uretir
tools/install_icons.sh          # cihaza kur (yedek alir, respring atar)
tools/install_icons.sh --restore  # orijinale don
```

Kaynaklar: `catwithabaloon/iOS-18-icon-pack` (1024px gerçek iOS 18 ikonları) +
`SysAdminDoc/iOSIconPack` (MIT, eksik kalanlar). İkon dosyaları lisans nedeniyle
repoya commit edilmez, script üretir.

**Dark (siyah) set** — cihazda kurulu olan bu:

```bash
python tools/make_dark.py         # açık ikonları iOS 18 dark'a çevir (2 strateji)
python tools/make_placeholders.py # karşılığı olmayan sistem uygulamalarına düz monogram
python tools/darken_system.py     # CgBI orijinalleri cihazdan çekip karart (yedek yol)
```

Kapsam: 19 sistem uygulaması gerçek iOS 18 dark ikonu (Takvim ve Saat dahil, canlı
çizim feda edildi) + 5 sistem uygulamasına (Sesli Notlar, Oyun Merkezi, Kişiler,
iTunes, Nike) setin diliyle düz monogram. **Üçüncü parti uygulamalara dokunulmaz.**

Teknik notlar: iOS 18 varlıkları kare gelir → `squircle()` süper-elips maskesi
uygulanır; cihazdaki eski ikonlar Apple'ın CgBI (crush) PNG formatındadır →
`decode_cgbi()` ile çözülür. Kullanıcı sırası: `killall SpringBoard` (sbreload mobil
kullanıcıda `launch_msg(GetJob)` hatası veriyor).

## Yol haritası

1. **UI** — springboard, dock, arama, kontrol merkezi (bu repo, şu an).
2. **Kabuk** — theos ile armv7 `.deb`: WebView'ı tam ekran açan, `AppLaunch` ile
   diğer uygulamaları başlatan launcher. SSH üzerinden kurulum.
3. **Sistem** — SpringBoard'a hook (Cydia Substrate): gerçek ana ekranı bizimkiyle
   değiştirmek, durum çubuğu ve kilit ekranını modernleştirmek.
4. **Uygulama uyumu** — Safari/YouTube gibi günlük uygulamalar için eski sürüm +
   TLS/güvenlik ayarları.

## Lisans / not

Ticari marka ve Apple'a ait kaynak (SF Pro fontu, orijinal ikon varlıkları) bu repoya
girmez — ikonlar SVG olarak sıfırdan çizildi, font sistem Helvetica Neue.
