THEOS_DEVICE_IP = iphone
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = lendicgram

lendicgram_FILES = Tweak.m fishhook.c
lendicgram_CFLAGS = -fobjc-arc
lendicgram_FRAMEWORKS = UIKit Foundation
lendicgram_LDFLAGS = -lsqlite3
lendicgram_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk
