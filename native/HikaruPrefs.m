// Ayarlar > Hikaru bundle'i: tek anahtar (modern ana ekran acik/kapali).
// PSListController'in kendi _specifiers ivar'ini de dolduruyoruz; yoksa
// tablo bos kaliyor (iOS 6 tablo veri kaynagi ivari dogrudan okuyor).
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern int notify_post(const char *name);

@interface PSSpecifier : NSObject
+ (id)preferenceSpecifierNamed:(id)name target:(id)target set:(SEL)set get:(SEL)get
                        detail:(Class)detail cell:(int)cell edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end

@interface PSListController : UIViewController
- (id)specifiers;
@end

static NSString *HKPrefPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/Preferences/com.hikaru.ui.plist"];
}

@interface HikaruRootListController : PSListController
@end

@implementation HikaruRootListController

- (id)specifiers {
    static NSArray *specs = nil;
    if (specs) return specs;

    NSMutableArray *arr = [NSMutableArray array];

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"iOS 18 Ana Ekran"
                                                        target:self set:NULL get:NULL
                                                        detail:Nil cell:0 edit:Nil];
    [group setProperty:@"Kapatinca iPhone'un kendi iOS 6 ana ekrani geri gelir. "
                       "Degisiklik birkac saniye icinde uygulanir, respring gerekmez."
                forKey:@"footerText"];
    [arr addObject:group];

    PSSpecifier *sw = [PSSpecifier preferenceSpecifierNamed:@"Modern ana ekran"
                                                     target:self
                                                        set:@selector(setPreferenceValue:specifier:)
                                                        get:@selector(readPreferenceValue:)
                                                     detail:Nil cell:6 edit:Nil];
    [sw setProperty:@"com.hikaru.ui" forKey:@"defaults"];
    [sw setProperty:@"enabled" forKey:@"key"];
    [sw setProperty:@YES forKey:@"default"];
    [arr addObject:sw];

    specs = [arr copy];

    // superclass'in ivar'ina da yaz (tablo buradan okuyor)
    Ivar iv = class_getInstanceVariable([PSListController class], "_specifiers");
    if (iv) object_setIvar(self, iv, specs);

    return specs;
}

- (id)readPreferenceValue:(PSSpecifier *)spec {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:HKPrefPath()];
    id v = [d objectForKey:@"enabled"];
    return v ? v : @YES;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)spec {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    NSDictionary *old = [NSDictionary dictionaryWithContentsOfFile:HKPrefPath()];
    if (old) [d addEntriesFromDictionary:old];
    [d setObject:(value ? value : @YES) forKey:@"enabled"];
    [d writeToFile:HKPrefPath() atomically:YES];
    notify_post("com.hikaru.ui/settingsChanged");
}

@end
