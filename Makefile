THEOS_DEVICE_IP = iphone
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = lendicgram

lendicgram_FILES = Tweak.xm LendicgramManager.m
lendicgram_CFLAGS = -fobjc-arc
lendicgram_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Telegram" || true
