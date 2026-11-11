// HikaruUI - iOS 6 icin modern (iOS 18 gorunumlu) ana ekran.
// SpringBoard icine enjekte olur, kendi penceresini cizer, dokununca uygulamayi acar.
// Animasyon yok, blur yok -> pil dostu.
//
// Kural: yalnizca sistem uygulamalarinin ikonlari degistirildi (uygulama paketlerinin
// icine kuruldu). Ucuncu parti uygulamalar kendi orijinal ikonlariyla listelenir.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#define HK_SCREEN_W 320.0
#define HK_STATUSBAR_H 20.0
#define HK_DOCK_H 84.0
#define HK_ICON 57.0
#define HK_COLS 4
#define HK_ROWS 5

#pragma mark - log

static void HKLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%.0f] %@\n", [[NSDate date] timeIntervalSince1970], msg];
    FILE *f = fopen("/var/mobile/hikaru.log", "a");
    if (f) {
        fputs([line UTF8String], f);
        fclose(f);
    }
}

#pragma mark - model

@interface HKApp : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *ident;
@property (nonatomic, copy) NSString *path;      // .app yolu
@property (nonatomic, copy) NSString *iconFile;  // tercih edilen ikon dosyasi (yoksa bos)
@property (nonatomic, assign) BOOL dock;
@property (nonatomic, assign) BOOL system;       // bizim koyu setten mi
@end

@implementation HKApp
@end

// Sistem uygulamalari: kimlik -> @[gorunen ad, .app adi, ikon dosyasi]
static NSDictionary *HKCurated(void) {
    static NSDictionary *d = nil;
    if (d) return d;
    d = @{
        @"com.apple.MobileSMS":          @[@"Mesajlar",         @"MobileSMS",           @"icon@2x.png"],
        @"com.apple.mobilecal":          @[@"Takvim",           @"MobileCal",           @"icon@2x~iphone.png"],
        @"com.apple.mobileslideshow":    @[@"Fotoğraflar",      @"MobileSlideShow",     @"Photos@2x~iphone.png"],
        @"com.apple.camera":             @[@"Kamera",           @"Camera",              @"Camera@2x~iphone.png"],
        @"com.apple.weather":            @[@"Hava Durumu",      @"Weather",             @"icon@2x.png"],
        @"com.apple.mobiletimer":        @[@"Saat",             @"MobileTimer",         @"icon@2x~iphone.png"],
        @"com.apple.Maps":               @[@"Haritalar",        @"Maps",                @"Icon@2x.png"],
        @"com.apple.mobilenotes":        @[@"Notlar",           @"MobileNotes",         @"icon@2x.png"],
        @"com.apple.reminders":          @[@"Hatırlatıcılar",   @"Reminders",           @"icon@2x.png"],
        @"com.apple.mobilephone":        @[@"Telefon",          @"MobilePhone",         @"icon@2x~iphone.png"],
        @"com.apple.mobilemail":         @[@"Posta",            @"MobileMail",          @"Icon@2x.png"],
        @"com.apple.mobilesafari":       @[@"Safari",           @"MobileSafari",        @"icon@2x~iphone.png"],
        @"com.apple.mobileipod":         @[@"Müzik",            @"Music~iphone",        @"icon@2x.png"],
        @"com.apple.videos":             @[@"Videolar",         @"Videos",              @"icon@2x.png"],
        @"com.apple.gamecenter":         @[@"Oyun Merkezi",     @"Game Center~iphone",  @"icon@2x.png"],
        @"com.apple.AppStore":           @[@"App Store",        @"AppStore",            @"icon@2x.png"],
        @"com.apple.Preferences":        @[@"Ayarlar",          @"Preferences",         @"icon@2x~iphone.png"],
        @"com.apple.calculator":         @[@"Hesap Makinesi",   @"Calculator",          @"icon@2x.png"],
        @"com.apple.compass":            @[@"Pusula",           @"Compass",             @"Icon@2x.png"],
        @"com.apple.stocks":             @[@"Borsa",            @"Stocks",              @"icon@2x~iphone.png"],
        @"com.apple.VoiceMemos":         @[@"Sesli Notlar",     @"VoiceMemos",          @"icon@2x.png"],
        @"com.apple.Shoebox":            @[@"Cüzdan",           @"Shoebox",             @"icon@2x.png"],
        @"com.apple.MobileAddressBook":  @[@"Kişiler",          @"Contacts~iphone",     @"icon@2x.png"],
        @"com.apple.MobileStore":        @[@"iTunes",           @"MobileStore",         @"icon@2x.png"],
        @"com.apple.nike":               @[@"Nike+ iPod",       @"Nike",                @"icon@2x.png"],
    };
    return d;
}

static NSArray *HKCuratedOrder(void) {
    return @[@"com.apple.MobileSMS", @"com.apple.mobilecal", @"com.apple.mobileslideshow",
             @"com.apple.camera", @"com.apple.weather", @"com.apple.mobiletimer",
             @"com.apple.Maps", @"com.apple.mobilenotes", @"com.apple.reminders",
             @"com.apple.videos", @"com.apple.gamecenter", @"com.apple.AppStore",
             @"com.apple.Preferences", @"com.apple.calculator", @"com.apple.compass",
             @"com.apple.stocks", @"com.apple.Shoebox", @"com.apple.VoiceMemos", @"com.apple.MobileAddressBook",
             @"com.apple.MobileStore", @"com.apple.nike"];
}

static NSArray *HKDockOrder(void) {
    return @[@"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", @"com.apple.mobileipod"];
}

static BOOL HKExists(NSString *p) {
    return [[NSFileManager defaultManager] fileExistsAtPath:p];
}

// Bir .app paketindeki en uygun iPhone @2x ikon dosyasini (adini) bulur.
// Once Info.plist'teki CFBundleIconFiles (SpringBoard'un kullandigi liste), sonra klasor taramasi.
static NSString *HKBestIconName(NSString *appPath, NSDictionary *info, NSString *preferred) {
    if (preferred && HKExists([appPath stringByAppendingPathComponent:preferred])) return preferred;

    NSMutableArray *declared = [NSMutableArray array];
    id files = info[@"CFBundleIconFiles"];
    if ([files isKindOfClass:[NSArray class]]) [declared addObjectsFromArray:files];
    id single = info[@"CFBundleIconFile"];
    if ([single isKindOfClass:[NSString class]]) [declared addObject:single];

    // listedeki son eleman en yuksek cozunurluk
    for (NSInteger i = (NSInteger)declared.count - 1; i >= 0; i--) {
        NSString *n = declared[i];
        if (![n isKindOfClass:[NSString class]]) continue;
        NSString *base = [n stringByDeletingPathExtension];
        NSString *ext = [n pathExtension];
        if (!ext.length) ext = @"png";
        NSArray *cands = @[[NSString stringWithFormat:@"%@@2x~iphone.%@", base, ext],
                           [NSString stringWithFormat:@"%@@2x.%@", base, ext],
                           n];
        for (NSString *c in cands)
            if (HKExists([appPath stringByAppendingPathComponent:c])) return c;
    }

    // yedek: sadece "icon", "icon-57", "appicon" gibi adlar (kaynak dosyalarini atla)
    NSString *best = nil;
    unsigned long long bestSize = 0;
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appPath error:NULL]) {
        NSString *low = [f lowercaseString];
        if (![low hasSuffix:@".png"]) continue;
        if ([low rangeOfString:@"@2x"].location == NSNotFound) continue;
        NSString *stem = [[low componentsSeparatedByString:@"@"] objectAtIndex:0];
        if (!([stem isEqualToString:@"icon"] || [stem isEqualToString:@"appicon"] ||
              [stem hasPrefix:@"icon-"])) continue;
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:
                               [appPath stringByAppendingPathComponent:f] error:NULL];
        unsigned long long size = [attrs fileSize];
        if (!best || size > bestSize) { best = f; bestSize = size; }
    }
    return best;
}

// Geriye uyumluluk: tam yolu dondurur.
static NSString *HKIconInBundle(NSString *appPath, NSString *preferred) {
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                          [appPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *name = HKBestIconName(appPath, info, preferred);
    return name ? [appPath stringByAppendingPathComponent:name] : nil;
}

// Info.plist'ten gorunen uygulama listesini toplar.
static NSArray *HKScanApps(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSMutableArray *dirs = [NSMutableArray array];
    for (NSString *f in [fm contentsOfDirectoryAtPath:@"/Applications" error:NULL]) {
        if ([f hasSuffix:@".app"]) [dirs addObject:[@"/Applications" stringByAppendingPathComponent:f]];
    }
    // kullanici uygulamalari: /var/mobile/Applications/<UUID>/<Ad>.app
    NSArray *uuids = [fm contentsOfDirectoryAtPath:@"/var/mobile/Applications" error:NULL];
    for (NSString *u in uuids) {
        NSString *base = [@"/var/mobile/Applications" stringByAppendingPathComponent:u];
        for (NSString *f in [fm contentsOfDirectoryAtPath:base error:NULL]) {
            if ([f hasSuffix:@".app"]) [dirs addObject:[base stringByAppendingPathComponent:f]];
        }
    }

    for (NSString *appPath in dirs) {
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                              [appPath stringByAppendingPathComponent:@"Info.plist"]];
        if (!info) continue;

        NSString *ident = info[@"CFBundleIdentifier"];
        if (!ident || [seen containsObject:ident]) continue;

        // gizli servis uygulamalari ana ekranda gorunmez
        NSArray *tags = info[@"SBAppTags"];
        if ([tags isKindOfClass:[NSArray class]] && [tags containsObject:@"hidden"]) continue;
        if (!info[@"CFBundleExecutable"]) continue;

        NSArray *cur = HKCurated()[ident];
        NSString *iconName = HKBestIconName(appPath, info, cur ? cur[2] : nil);
        if (!iconName) continue;   // ikonu olmayan (servis) paketleri atla

        HKApp *a = [[HKApp alloc] init];
        a.ident = ident;
        a.path = appPath;
        a.iconFile = iconName;

        if (cur) {
            a.name = cur[0];
            a.system = YES;
        } else {
            NSDictionary *loc = [info objectForKey:@"CFBundleDisplayName"] ? info : nil;
            NSString *n = loc[@"CFBundleDisplayName"];
            if (!n) n = info[@"CFBundleDisplayName"];
            if (!n) n = info[@"CFBundleName"];
            if (!n) n = [[appPath lastPathComponent] stringByDeletingPathExtension];
            a.name = n;
            a.system = NO;
        }
        [seen addObject:ident];
        [out addObject:a];
    }
    return out;
}

// Sirali liste: dock, sonra sistem uygulamalari, sonra ucuncu parti (alfabetik).
static NSMutableDictionary *gAppObjects = nil;
static id HKApplicationFor(NSString *ident);
static NSMutableArray *gOrderedCache = nil;

static void HKResetAppCache(void) {
    gOrderedCache = nil;
    gAppObjects = nil;
}

static NSArray *HKOrderedApps(void) {
    if (gOrderedCache) return gOrderedCache;

    NSArray *all = HKScanApps();
    NSMutableDictionary *byIdent = [NSMutableDictionary dictionary];
    for (HKApp *a in all) byIdent[a.ident] = a;

    NSMutableArray *grid = [NSMutableArray array];
    NSMutableArray *dock = [NSMutableArray array];
    NSMutableSet *used = [NSMutableSet set];

    for (NSString *ident in HKDockOrder()) {
        HKApp *a = byIdent[ident];
        if (a) { a.dock = YES; [dock addObject:a]; [used addObject:ident]; }
    }
    for (NSString *ident in HKCuratedOrder()) {
        HKApp *a = byIdent[ident];
        if (a && ![used containsObject:ident]) { [grid addObject:a]; [used addObject:ident]; }
    }
    NSMutableArray *rest = [NSMutableArray array];
    for (HKApp *a in all) if (![used containsObject:a.ident]) [rest addObject:a];
    [rest sortUsingComparator:^NSComparisonResult(HKApp *x, HKApp *y) {
        return [x.name localizedCaseInsensitiveCompare:y.name];
    }];
    [grid addObjectsFromArray:rest];

    gOrderedCache = [NSMutableArray arrayWithArray:@[grid, dock]];
    HKLog(@"tarama: %lu grid, %lu dock, %lu toplam", (unsigned long)grid.count,
          (unsigned long)dock.count, (unsigned long)all.count);
    for (HKApp *a in all) HKLog(@"  app %@ | %@ | %@", a.ident, a.name, a.iconFile);
    return gOrderedCache;
}

#pragma mark - uygulama acma

static UIWindow *gWindow;
static NSTimeInterval gHideTime = 0;
static NSString *gLastLaunch = nil;
static void HKRestoreHome(void);
static void HKShow(void);
static UIView *gRootView;

// Sinifta "launch"/"activate" iceren metodlari loga yazar (teshis icin).
static void HKDumpSelectors(NSString *className) {
    Class c = NSClassFromString(className);
    if (!c) { HKLog(@"  [%@] sinif yok", className); return; }
    unsigned int n = 0;
    Method *ms = class_copyMethodList(c, &n);
    NSMutableArray *hits = [NSMutableArray array];
    for (unsigned int i = 0; i < n; i++) {
        NSString *sel = NSStringFromSelector(method_getName(ms[i]));
        NSString *low = [sel lowercaseString];
        if ([low rangeOfString:@"launch"].location != NSNotFound ||
            [low rangeOfString:@"activate"].location != NSNotFound ||
            [low rangeOfString:@"displayidentifier"].location != NSNotFound)
            [hits addObject:sel];
    }
    free(ms);
    HKLog(@"  [%@] %@", className, [hits componentsJoinedByString:@", "]);
}

static void HKDumpClasses(void) {
    HKLog(@"--- secici dokumu ---");
    HKDumpSelectors(@"SBApplicationController");
    HKDumpSelectors(@"SBApplication");
    HKDumpSelectors(@"SBUIController");
    HKDumpSelectors(@"SBIconController");
    HKDumpSelectors(@"SBUserApplicationController");
    HKLog(@"--- dokum sonu ---");
}

static id HKUIController(void) {
    static id ui = nil;
    if (!ui) {
        Class c = NSClassFromString(@"SBUIController");
        ui = [c respondsToSelector:@selector(sharedInstance)] ? [c performSelector:@selector(sharedInstance)] : nil;
    }
    return ui;
}

// SBApplication nesnelerini onbellege alir: dokunusta arama yapilmaz.
static id HKAppObject(NSString *ident) {
    if (!gAppObjects) gAppObjects = [NSMutableDictionary dictionary];
    id obj = gAppObjects[ident];
    if (!obj) {
        obj = HKApplicationFor(ident);
        if (obj) gAppObjects[ident] = obj;
    }
    return obj;
}

static id HKApplicationFor(NSString *ident) {
    Class ctrlClass = NSClassFromString(@"SBApplicationController");
    id ctrl = [ctrlClass respondsToSelector:@selector(sharedInstance)]
              ? [ctrlClass performSelector:@selector(sharedInstance)] : nil;
    if (!ctrl) { HKLog(@"SBApplicationController yok"); return nil; }
    id app = nil;
    if ([ctrl respondsToSelector:@selector(applicationWithDisplayIdentifier:)])
        app = [ctrl performSelector:@selector(applicationWithDisplayIdentifier:) withObject:ident];
    if (!app && [ctrl respondsToSelector:@selector(applicationWithBundleIdentifier:)])
        app = [ctrl performSelector:@selector(applicationWithBundleIdentifier:) withObject:ident];
    return app;
}

// Uygulamayi SpringBoard'un KENDI yoluyla acar.
// SBSLaunchApplicationWithIdentifier kullanilmaz: SpringBoard ana thread'inden
// cagirildiginda kendine XPC atip kilitleniyor (cihaz donuyor).
static BOOL HKLaunch(NSString *ident) {
    id app = HKAppObject(ident);
    if (!app) return NO;

    // iOS 6'da SBApplication'da -launch yok; SpringBoard kendi ikonuna basinca
    // SBUIController -activateApplicationAnimated: kullaniyor.
    id ui = HKUIController();
    if (ui && [ui respondsToSelector:@selector(activateApplicationAnimated:)]) {
        HKLog(@"aciliyor (SBUIController activateApplicationAnimated:): %@", ident);
        [ui performSelector:@selector(activateApplicationAnimated:) withObject:app];
        return YES;
    }
    if (ui && [ui respondsToSelector:@selector(launchIcon:)]) {
        Class iconCtrlClass = NSClassFromString(@"SBIconController");
        id iconCtrl = [iconCtrlClass respondsToSelector:@selector(sharedInstance)]
                      ? [iconCtrlClass performSelector:@selector(sharedInstance)] : nil;
        id icon = nil;
        if ([iconCtrl respondsToSelector:@selector(iconOfDisplayIdentifier:)])
            icon = [iconCtrl performSelector:@selector(iconOfDisplayIdentifier:) withObject:ident];
        if (icon) {
            HKLog(@"aciliyor (SBUIController launchIcon:): %@", ident);
            [ui performSelector:@selector(launchIcon:) withObject:icon];
            return YES;
        }
    }
    HKLog(@"ACILAMADI: %@ (SBUIController=%@)", ident, ui);
    return NO;
}

#pragma mark - debug

// Cihazin kendi ekran goruntusunu (SpringBoard) Camera Roll'a kaydeder.
static const double kDebugTimes[6] = {0.5, 1.0, 1.5, 2.5, 4.0, 6.0};

static void HKShot(const char *tag) {
    Class c = NSClassFromString(@"SBScreenShotter");
    id shotter = (c && [c respondsToSelector:@selector(sharedInstance)])
                 ? [c performSelector:@selector(sharedInstance)] : nil;
    HKLog(@"SHOT %s (shotter=%@)", tag, shotter);
    if (shotter && [shotter respondsToSelector:@selector(saveScreenshot)])
        [shotter performSelector:@selector(saveScreenshot)];
}

// Saniye saniye durum satiri: ne gorunuyor, hangi uygulama onde.
static void HKDebugLine(const char *phase) {
    NSMutableString *st = [NSMutableString string];
    NSArray *ordered = HKOrderedApps();
    for (NSArray *grp in ordered)
        for (HKApp *a in grp) {
            id obj = HKAppObject(a.ident);
            if (!obj || ![obj respondsToSelector:@selector(activationState)]) continue;
            int v = (int)[obj performSelector:@selector(activationState)];
            if (v != 1) [st appendFormat:@"%@=%d ", a.ident, v];
        }
    HKLog(@"DBG %s pencere(gizli=%d alpha=%.2f) onde[%@]", phase,
          gWindow ? (int)gWindow.hidden : -1, gRootView ? gRootView.alpha : -1.0, st);
}

#pragma mark - ikon maskeleme

// Ikonu bir kez yuvarlatip onbellege alir: her karede cornerRadius/masksToBounds
// ile offscreen render yapmak iPhone 4'te kaydirmayi kasiyordu.
static NSMutableDictionary *gIconCache = nil;

static UIImage *HKRoundImage(NSString *path, CGFloat radius) {
    if (!gIconCache) gIconCache = [NSMutableDictionary dictionary];
    UIImage *cached = gIconCache[path];
    if (cached) return cached;

    UIImage *src = [UIImage imageWithContentsOfFile:path];
    if (!src) return nil;

    CGSize size = src.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                                    cornerRadius:radius];
    [clip addClip];
    [src drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (out) gIconCache[path] = out;
    return out;
}

#pragma mark - ikon karosu

@interface HKIconView : UIControl
@property (nonatomic, strong) HKApp *app;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *label;
@end

@implementation HKIconView

- (id)initWithApp:(HKApp *)app size:(CGFloat)size {
    self = [super initWithFrame:CGRectMake(0, 0, size, size + 20)];
    if (!self) return nil;
    self.app = app;
    self.backgroundColor = [UIColor clearColor];

    CGFloat iconSize = size - 6;
    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(3, 0, iconSize, iconSize)];
    _imageView.userInteractionEnabled = NO;

    NSString *iconPath = app.iconFile ? [app.path stringByAppendingPathComponent:app.iconFile] : nil;
    UIImage *img = iconPath ? HKRoundImage(iconPath, iconSize * 0.2237) : nil;
    if (!img) {
        NSString *fallback = HKIconInBundle(app.path, app.iconFile);
        if (fallback) img = HKRoundImage(fallback, iconSize * 0.2237);
    }
    if (img) {
        _imageView.image = img;
    } else {
        _imageView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
        HKLog(@"ikon yok: %@ / %@", app.ident, app.path);
    }
    [self addSubview:_imageView];

    _label = [[UILabel alloc] initWithFrame:CGRectMake(-4, size - 1, size + 8, 14)];
    _label.text = app.name;
    _label.font = [UIFont systemFontOfSize:10.5];
    _label.textColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.backgroundColor = [UIColor clearColor];
    _label.adjustsFontSizeToFitWidth = YES;
    _label.minimumScaleFactor = 0.72;
    _label.userInteractionEnabled = NO;
    [self addSubview:_label];
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.imageView.alpha = highlighted ? 0.55 : 1.0;
}

- (void)fire {
    // 1) Ikon tam ekrana buyur (iOS 18'deki "uygulamaya girme" hissi)
    UIImage *icon = self.imageView.image;
    CGRect startRect = [self.imageView convertRect:self.imageView.bounds toView:gWindow];
    UIImageView *zoom = [[UIImageView alloc] initWithFrame:startRect];
    zoom.image = icon;
    zoom.contentMode = UIViewContentModeScaleToFill;
    zoom.layer.cornerRadius = self.imageView.layer.cornerRadius;
    zoom.layer.masksToBounds = YES;
    zoom.backgroundColor = [UIColor blackColor];
    [gWindow addSubview:zoom];
    [gWindow bringSubviewToFront:zoom];

    [UIView animateWithDuration:0.26
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         zoom.frame = gWindow.bounds;
                         zoom.layer.cornerRadius = 0.0;
                         gRootView.alpha = 0.0;
                     }
                     completion:nil];

    // 2) Uygulamayi ac (animasyonla ayni anda)
    NSTimeInterval t0 = [[NSDate date] timeIntervalSince1970];
    BOOL ok = HKLaunch(self.app.ident);
    HKLog(@"DOKUNULDU: %@ (%@) komut %.0f ms surdu, ok=%d", self.app.name, self.app.ident,
          ([[NSDate date] timeIntervalSince1970] - t0) * 1000.0, (int)ok);

    // 3) Uygulama on plana gelene kadar buyumus ikon ekranda kalsin (siyah bosluk olmasin),
    //    sonra ana ekran arkada hazirlanir.
    __block int tries = 0;
    __block void (^poll)(void);
    poll = ^{
        tries++;
        id app = HKAppObject(self.app.ident);
        int st = (app && [app respondsToSelector:@selector(activationState)])
                 ? (int)[app performSelector:@selector(activationState)] : 0;
        BOOL done = (st == 2) || (tries > 20);   // on planda ya da ~6 sn gecti
        if (done) {
            HKLog(@"uygulama on planda (state=%d, %d deneme)", st, tries);
            [zoom removeFromSuperview];
            [self resetVisual];
            gRootView.alpha = 1.0;
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), poll);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), poll);

}

- (void)resetVisual {
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.alpha = 1.0;
    self.label.alpha = 1.0;
}

@end

#pragma mark - ana gorunum

@interface HKRootView : UIView <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *pager;
@property (nonatomic, strong) UIPageControl *dots;
@property (nonatomic, strong) NSArray *pages;
@end

@implementation HKRootView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor blackColor];
    self.userInteractionEnabled = YES;

    CGFloat w = frame.size.width, h = frame.size.height;
    CGFloat gridH = h - HK_DOCK_H;

    NSArray *ordered = HKOrderedApps();
    NSArray *grid = ordered[0];
    NSArray *dock = ordered[1];

    NSInteger perPage = HK_ROWS * HK_COLS;
    NSInteger pageCount = (NSInteger)((grid.count + perPage - 1) / perPage);
    if (pageCount < 1) pageCount = 1;

    _pager = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, gridH)];
    _pager.pagingEnabled = YES;
    _pager.showsHorizontalScrollIndicator = NO;
    _pager.showsVerticalScrollIndicator = NO;
    _pager.delegate = self;
    _pager.contentSize = CGSizeMake(w * pageCount, gridH);
    _pager.backgroundColor = [UIColor clearColor];
    [self addSubview:_pager];

    NSMutableArray *pageViews = [NSMutableArray array];
    for (NSInteger p = 0; p < pageCount; p++) {
        UIView *page = [[UIView alloc] initWithFrame:CGRectMake(p * w, 0, w, gridH)];
        CGFloat cellW = w / HK_COLS;
        NSInteger start = p * perPage;
        NSInteger end = MIN(start + perPage, (NSInteger)grid.count);
        for (NSInteger i = start; i < end; i++) {
            NSInteger k = i - start;
            NSInteger row = k / HK_COLS, col = k % HK_COLS;
            HKIconView *iv = [[HKIconView alloc] initWithApp:grid[i] size:HK_ICON];
            CGRect f = iv.frame;
            f.origin.x = col * cellW + (cellW - HK_ICON) / 2.0;
            f.origin.y = 10 + row * 74;
            iv.frame = f;
            [iv addTarget:iv action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
            [iv addTarget:iv action:@selector(setHighlighted:) forControlEvents:UIControlEventTouchDown];
            [iv addTarget:iv action:@selector(setHighlighted:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
            [page addSubview:iv];
        }
        [_pager addSubview:page];
        [pageViews addObject:page];
    }
    self.pages = pageViews;

    // sayfa noktalari
    _dots = [[UIPageControl alloc] initWithFrame:CGRectMake(0, gridH - 18, w, 16)];
    _dots.numberOfPages = pageCount;
    _dots.currentPage = 0;
    _dots.userInteractionEnabled = NO;
    [self addSubview:_dots];

    // dock: iOS 18'deki gibi yari saydam, yuvarlatilmis panel
    UIView *dockBar = [[UIView alloc] initWithFrame:CGRectMake(0, gridH, w, HK_DOCK_H)];
    dockBar.backgroundColor = [UIColor clearColor];
    [self addSubview:dockBar];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(8, 4, w - 16, HK_DOCK_H - 12)];
    panel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    panel.layer.cornerRadius = 24.0;
    panel.userInteractionEnabled = NO;
    [dockBar addSubview:panel];

    CGFloat cellW = w / HK_COLS;
    NSInteger n = MIN((NSInteger)dock.count, HK_COLS);
    CGFloat startX = (w - n * cellW) / 2.0;
    for (NSInteger i = 0; i < n; i++) {
        HKIconView *iv = [[HKIconView alloc] initWithApp:dock[i] size:HK_ICON];
        CGRect f = iv.frame;
        f.origin.x = startX + i * cellW + (cellW - HK_ICON) / 2.0;
        f.origin.y = 8;
        iv.frame = f;
        [iv addTarget:iv action:@selector(fire) forControlEvents:UIControlEventTouchUpInside];
        [iv addTarget:iv action:@selector(setHighlighted:) forControlEvents:UIControlEventTouchDown];
        [iv addTarget:iv action:@selector(setHighlighted:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [dockBar addSubview:iv];
    }

    return self;
}

- (void)resetAllVisuals {
    for (UIView *page in self.pages)
        for (UIView *v in [page subviews])
            if ([v isKindOfClass:[HKIconView class]]) [(HKIconView *)v resetVisual];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _pager && self.pages.count > 1) {
        CGFloat w = scrollView.frame.size.width;
        NSInteger p = (NSInteger)floor((scrollView.contentOffset.x + w / 2.0) / w);
        p = MAX(0, MIN(p, (NSInteger)self.pages.count - 1));
        if (_dots.currentPage != p) _dots.currentPage = p;
    }
}

@end

#pragma mark - yasam dongusu


// Kendi penceremiz -0.5 seviyesinde: ana ekran SBAppWindow (-1) uzerinde,
// uygulamalar ise (level 0) ustunde. Boylece uygulama acilinca otomatik olarak
// ustumuzde kalir, Home'a basinca kendiliginden geri gorunuruz.
static UIWindow *HKMakeWindow(void) {
    CGRect scr = [[UIScreen mainScreen] bounds];
    UIWindow *w = [[UIWindow alloc] initWithFrame:scr];
    w.windowLevel = -0.5;
    w.backgroundColor = [UIColor blackColor];
    w.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (!gRootView) {
        CGRect f = CGRectMake(0, HK_STATUSBAR_H, scr.size.width, scr.size.height - HK_STATUSBAR_H);
        gRootView = [[HKRootView alloc] initWithFrame:f];
        gRootView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    [w addSubview:gRootView];
    HKLog(@"pencere kuruldu level=-0.5 %@", NSStringFromCGRect(scr));
    return w;
}

#pragma mark - acma/kapama

// Ayarlar > Hikaru anahtari: /var/mobile/Library/Preferences/com.hikaru.ui.plist
static BOOL HKEnabled(void) {
    // cfprefsd onbellegine guvenmiyoruz: anahtar dosyadan okunur (Ayarlar yazar,
    // SpringBoard 1.5 sn icinde gorur).
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
                      @"Library/Preferences/com.hikaru.ui.plist"];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!d) return YES;                        // varsayilan: acik
    id v = [d objectForKey:@"enabled"];
    return v ? [v boolValue] : YES;
}

static BOOL gLastEnabled = YES;
static BOOL gAppliedOnce = NO;

static void HKApplyEnabled(void) {
    BOOL on = HKEnabled();
    if (gAppliedOnce && on == gLastEnabled) return;
    gAppliedOnce = YES;
    gLastEnabled = on;
    if (on) {
        HKLog(@"tema acildi");
        HKShow();
    } else {
        HKLog(@"tema kapatildi");
        if (gWindow) gWindow.hidden = YES;
    }
}

static void HKOnSettingsChanged(CFNotificationCenterRef center, void *observer,
                                CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ HKApplyEnabled(); });
}

static void HKShow(void) {
    @autoreleasepool {
        if (!HKEnabled()) { gLastEnabled = NO; return; }
        gLastEnabled = YES;
        if (!gWindow) gWindow = HKMakeWindow();
        gWindow.hidden = NO;
        [gWindow bringSubviewToFront:gRootView];
        HKLog(@"pencere gosterildi");
    }
}

static NSUInteger HKCountBundles(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUInteger n = 0;
    for (NSString *f in [fm contentsOfDirectoryAtPath:@"/Applications" error:NULL])
        if ([f hasSuffix:@".app"]) n++;
    for (NSString *u in [fm contentsOfDirectoryAtPath:@"/var/mobile/Applications" error:NULL])
        for (NSString *f in [fm contentsOfDirectoryAtPath:
                             [@"/var/mobile/Applications" stringByAppendingPathComponent:u] error:NULL])
            if ([f hasSuffix:@".app"]) n++;
    return n;
}

// Yeni uygulama kurulunca listeyi kendiliginden yeniler.
static void HKRefreshIfNeeded(void) {
    static NSUInteger lastCount = 0;
    static BOOL initialized = NO;
    NSUInteger now = HKCountBundles();
    if (!initialized) { initialized = YES; lastCount = now; return; }
    if (now == lastCount) return;
    HKLog(@"uygulama sayisi degisti: %lu -> %lu, liste yenileniyor",
          (unsigned long)lastCount, (unsigned long)now);
    lastCount = now;

    HKResetAppCache();
    if (gRootView) {
        [gRootView removeFromSuperview];
        gRootView = nil;
    }
    if (gWindow) { [gWindow removeFromSuperview]; gWindow = nil; }
    HKShow();
}

static void HKRestoreHome(void) {
    if (!gWindow) return;
    [gRootView performSelector:@selector(resetAllVisuals)];
    gRootView.alpha = 1.0;
    gWindow.hidden = NO;
    gLastLaunch = nil;
    HKLog(@"ana ekran arkada hazir");
}

// Pencere bazen SpringBoard tarafindan kaldirilabiliyor; kontrol et.
// DIKKAT: gizli pencere kendiliginden acilmaz, yoksa uygulamanin acilis
// animasyonunu ezip ekrani kaplar.
static void HKTick(void) {
    static NSInteger tickCount = 0;
    HKApplyEnabled();
    if (!gWindow) HKShow();
    tickCount++;

    if (tickCount % 4 == 0) HKRefreshIfNeeded();
}

// Uygulama arka plana inince / kapaninca ana ekrani geri gosterir.
static void HKOnAppState(CFNotificationCenterRef center, void *observer,
                         CFStringRef name, const void *object, CFDictionaryRef info) {
    id app = (__bridge id)object;
    int st = 0;
    if ([app respondsToSelector:@selector(activationState)])
        st = (int)[app performSelector:@selector(activationState)];
    HKLog(@"durum: %@ = %d", [app class], st);
    (void)st;
}

static void HKOnDidFinishLaunching(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object, CFDictionaryRef info) {
    HKLog(@"SBSpringBoardDidLaunchNotification");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ HKShow(); });
}

@interface HKTicker : NSObject
@end

@implementation HKTicker
+ (void)tick:(NSTimer *)t { HKTick(); }
@end

__attribute__((constructor)) static void HKInit(void) {
    @autoreleasepool {
        HKLog(@"=== HikaruUI yuklendi ===");
        CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
                                        HKOnDidFinishLaunching,
                                        CFSTR("SBSpringBoardDidLaunchNotification"),
                                        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        HKOnSettingsChanged,
                                        CFSTR("com.hikaru.ui/settingsChanged"),
                                        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
                                        HKOnAppState,
                                        CFSTR("SBApplicationActivationStateDidChange"),
                                        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            HKShow();
            [NSTimer scheduledTimerWithTimeInterval:1.5
                                                      target:[HKTicker class]
                                                    selector:@selector(tick:)
                                                    userInfo:nil
                                                     repeats:YES];
        });
    }
}
