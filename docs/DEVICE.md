# Cihaz envanteri (2026-11-10 okundu)

- Model: **iPhone3,1** (iPhone 4), armv7, A4 / SGX535
- OS: **iOS 6.1.3 (10B329)**, Darwin 13.0.0
- Disk: `/` 1.2 GB (76% dolu, ~300 MB boş), `/private/var` ~5.4 GB boş
- SSH: OpenSSH **6.7**, `root@192.168.1.187`, şifre `alpine` (varsayılan, değiştirilmedi)
  - Bağlantı için `ssh-rsa` + şifre zorunlu → `tools/iphone.sh`

## Kabuk araçları (kısıtlı!)

`/usr/bin` içinde **grep, sed, awk, head, wc, gzip yok**. Olanlar: `tar`, `unzip`,
`dpkg`, `find`, `killall`, `sbreload`, `ldrestart`, `uiopen`, `openssl`, `pincrush`,
`uicache`, `ssh/scp`, `7z`.

→ Uzak komut yazarken bunlara güvenme. `grep` gerekirse `pcregrep` var.

## Kurulu tweak / altyapı (Substrate)

`PreferenceLoader`, `RocketBootstrap`, `AppList`, `AppSyncUnified`, `WinterBoard`,
`BrowserChanger`, `MapsX`, `GoogleFix`, `TubeRepair`, `VeterisHelper`, `ABImageFixer`,
`STBridge`, `WK26` (UIKit bundle'ına hook atan tweak).

Yani: **theming (WinterBoard) ve tweak (Substrate) altyapısı hazır**, sadece derleme lazım.
`Dreamboard` kurulu değil (HTML tabanlı SpringBoard değişimi isteseydik o gerekirdi).

## Uygulama açma yolları

- `uiopen <url>` → URL şeması ile uygulama açar (`uiopen "tel://..."`). Bundle ID ile açmıyor.
- Bundle ID ile açmak için native `SBSLaunchApplicationWithIdentifier` (launcher kabuğu) gerekli.
- `sbreload` → SpringBoard'u yeniden başlatır (tweak/theme testi için pratik).

## Cihaza kopyalama

```bash
tools/push.sh --open   # prototype/ -> /var/mobile/hikaru-ui + Safari'de acar
```

## HikaruUI (native ana ekran) kurulumu

Derleme (WSL Ubuntu, theos + iPhoneOS9.3.sdk + cctools-port ld64 + ldid):

```bash
wsl -d Ubuntu -e bash -lc 'bash "/mnt/c/Users/Wugen/Projects/makeing-ios-6-usable-at-big-26/native/build.sh"'
```

Kurulum (binary'yi `openssl base64` ile tasi):

```bash
b64=$(base64 -w0 native/build/HikaruUI.dylib)
printf '%s' "$b64" | tools/iphone.sh "openssl base64 -d -A > /Library/MobileSubstrate/DynamicLibraries/HikaruUI.dylib; chmod 755 /Library/MobileSubstrate/DynamicLibraries/HikaruUI.dylib"
b64=$(base64 -w0 native/HikaruUI.plist)
printf '%s' "$b64" | tools/iphone.sh "openssl base64 -d -A > /Library/MobileSubstrate/DynamicLibraries/HikaruUI.plist"
tools/iphone.sh "killall SpringBoard"
```

Geri alma:

```bash
tools/iphone.sh "rm /Library/MobileSubstrate/DynamicLibraries/HikaruUI.dylib /Library/MobileSubstrate/DynamicLibraries/HikaruUI.plist; killall SpringBoard"
```

Notlar:
- iOS 9.3 SDK'si `.tbd` sembol dosyalari kullandigi icin link `-nostdlib -undefined dynamic_lookup` ile yapilir; semboller calisma aninda SpringBoard'dan cozulur.
- `ld64` (cctools-port) iOS icin "libSystem.dylib sart" kontrolu kaynakta `grandfather = true` ile devre disi birakildi.
- Aygit IP'si degisebilir; `tools/iphone.sh` varsayilani guncel tutulmali (su an 192.168.1.187).

## HikaruUI calisma sekli (v2)

- Pencere seviyesi **-0.5**: SpringBoard ana ekrani `SBAppWindow` (-1) ile uygulama
  pencereleri (0) arasinda. Bu sayede uygulama acilirken kendisi ustumuze gelir,
  Home'a basinca ana ekran kendiliginden geri gorunur (gizle/goster mantigi yok).
- Dokunusta: ikon tam ekrana buyur (~0.26 sn) -> uygulama acilir -> uygulama
  `activationState == 2` (on planda) olunca buyumus ikon kaldirilir.
  iOS 6'da uygulama acilisi 2.5-4 sn surdugu icin bu sure siyah bosluk yerine
  buyuyen ikonla ortulur.
- Uygulama acma: `SBApplicationController -applicationWithDisplayIdentifier:` +
  `SBUIController -activateApplicationAnimated:`. iOS 6'da `SBApplication -launch`
  yok, `SBSLaunchApplicationWithIdentifier` ise SpringBoard'u kilitliyor (kullanilmaz).
- Uygulama listesi `/Applications` + `/var/mobile/Applications` taranarak kurulur
  (SBAppTags hidden atlanir). Her 6 sn'de paket sayisi kontrol edilir; degisince
  liste otomatik yenilenir (respring gerekmez).
- Ikonlar acilista bir kez yuvarlatilip onbellege alinir (kaydirma kasmasin diye
  `cornerRadius`/`masksToBounds` kullanilmaz).
- Teshis: `/var/mobile/hikaru.log` (dokunus, acilis, tarama, pencere satirlari).

## Acma / kapama anahtari

- Ayarlar'da "Hikaru" satiri: `/Library/PreferenceLoader/Preferences/HikaruUI.plist`
  (kaynak: `native/prefs/HikaruUI.plist`, PreferenceLoader zaten kurulu).
- Anahtar `com.hikaru.ui` / `enabled` (varsayilan acik). Kapaliyken tweak pencereyi
  gizler, iPhone'un kendi iOS 6 ana ekrani gorunur; respring gerekmez.
- Tweak degeri `/var/mobile/Library/Preferences/com.hikaru.ui.plist` dosyasindan
  dogrudan okur (cfprefsd onbellegi iOS 6'da guncellenmedigi icin) ve 1.5 sn'lik
  tick ile uygular. `PostNotification = com.hikaru.ui/settingsChanged` aninda tetikler.
