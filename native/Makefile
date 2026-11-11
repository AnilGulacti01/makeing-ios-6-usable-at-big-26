THEOS = /root/theos
ARCHS = armv7
TARGET = iphone:clang:9.3:6.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = HikaruUI
HikaruUI_FILES = HikaruUI.m
HikaruUI_FRAMEWORKS = UIKit CoreGraphics QuartzCore
HikaruUI_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
HikaruUI_LDFLAGS = -fuse-ld=/usr/local/bin/arm-apple-darwin11-ld

include $(THEOS)/makefiles/library.mk
