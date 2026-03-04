TARGET      = iphone:clang:latest:10.0
INSTALL_TARGET_PROCESSES = Maple

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LendicTweak

LendicTweak_FILES      = LendicTweak.m
LendicTweak_CFLAGS     = -fobjc-arc -Wall -Wno-unused-variable
LendicTweak_FRAMEWORKS = Foundation AVFoundation UIKit Security
LendicTweak_LIBRARIES  =

# Pure ObjC runtime hooks — no MobileSubstrate/CydiaSubstrate needed
# Works with TrollStore, AltStore, Sideloadly (no jailbreak required)
LendicTweak_USE_SUBSTRATE = 0

include $(THEOS)/makefiles/tweak.mk

