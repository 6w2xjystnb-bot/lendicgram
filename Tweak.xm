//
//  Tweak.xm
//  lendicgram — Anti-Delete Tweak for Telegram iOS
//
//  Hooks into Telegram iOS to intercept message deletion.
//  Deleted messages become semi-transparent (alpha 0.45) with a red ✕ badge,
//  similar to Ayugram's anti-delete feature.
//
//  Compatible with Telegram iOS 10.x – 11.x (arm64).
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "LendicgramManager.h"

// ──────────────────────────────────────────────────────────────────────
// MARK: - Associated-object keys
// ──────────────────────────────────────────────────────────────────────
static const char kDeletedBadgeKey = '\0';
static const char kOriginalAlphaKey = '\0';

// ──────────────────────────────────────────────────────────────────────
// MARK: - Constants
// ──────────────────────────────────────────────────────────────────────
static CGFloat const kDeletedAlpha      = 0.45;
static CGFloat const kBadgeSize         = 20.0;
static CGFloat const kBadgeMargin       = 4.0;

// ──────────────────────────────────────────────────────────────────────
// MARK: - Helper: Create the ✕ badge view
// ──────────────────────────────────────────────────────────────────────
static UIView *_lendicgram_createBadge(void) {
    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kBadgeSize, kBadgeSize)];
    badge.backgroundColor = [UIColor colorWithRed:0.92 green:0.26 blue:0.24 alpha:0.90];
    badge.layer.cornerRadius = kBadgeSize / 2.0;
    badge.layer.masksToBounds = YES;
    badge.tag = 0x4C454E44; // "LEND"

    UILabel *cross = [[UILabel alloc] initWithFrame:badge.bounds];
    cross.text = @"✕";
    cross.textColor = [UIColor whiteColor];
    cross.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    cross.textAlignment = NSTextAlignmentCenter;
    cross.adjustsFontSizeToFitWidth = YES;
    [badge addSubview:cross];

    return badge;
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Helper: Apply deleted appearance to a cell/node view
// ──────────────────────────────────────────────────────────────────────
static void _lendicgram_applyDeletedStyle(UIView *contentView) {
    if (!contentView) return;

    NSNumber *saved = objc_getAssociatedObject(contentView, &kOriginalAlphaKey);
    if (!saved) {
        objc_setAssociatedObject(contentView, &kOriginalAlphaKey,
                                 @(contentView.alpha),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    contentView.alpha = kDeletedAlpha;

    UIView *existing = objc_getAssociatedObject(contentView, &kDeletedBadgeKey);
    if (!existing) {
        UIView *badge = _lendicgram_createBadge();

        badge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                 UIViewAutoresizingFlexibleBottomMargin;
        badge.frame = CGRectMake(
            contentView.bounds.size.width - kBadgeSize - kBadgeMargin,
            kBadgeMargin,
            kBadgeSize,
            kBadgeSize
        );

        [contentView addSubview:badge];
        objc_setAssociatedObject(contentView, &kDeletedBadgeKey,
                                 badge,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Helper: Restore normal appearance
// ──────────────────────────────────────────────────────────────────────
static void _lendicgram_removeDeletedStyle(UIView *contentView) {
    if (!contentView) return;

    NSNumber *saved = objc_getAssociatedObject(contentView, &kOriginalAlphaKey);
    contentView.alpha = saved ? saved.doubleValue : 1.0;

    UIView *badge = objc_getAssociatedObject(contentView, &kDeletedBadgeKey);
    [badge removeFromSuperview];
    objc_setAssociatedObject(contentView, &kDeletedBadgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(contentView, &kOriginalAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Helper: Safely extract int64 from an object
// ──────────────────────────────────────────────────────────────────────
static int64_t _lendicgram_extractId(id obj, SEL sel) {
    if (obj && [obj respondsToSelector:sel]) {
        id val = ((id(*)(id, SEL))objc_msgSend)(obj, sel);
        if ([val respondsToSelector:@selector(longLongValue)]) {
            return [val longLongValue];
        }
    }
    return 0;
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 1 — TGModernConversationController (legacy)
// ══════════════════════════════════════════════════════════════════════

%hook TGModernConversationController

- (void)_deleteMessages:(id)messageIds animated:(BOOL)animated {
    if ([messageIds isKindOfClass:[NSArray class]]) {
        for (NSNumber *msgId in (NSArray *)messageIds) {
            [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                             inChat:0];
        }
    }
    // Suppress deletion — do NOT call %orig
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 2 — TGGenericModernConversationCompanion
// ══════════════════════════════════════════════════════════════════════

%hook TGGenericModernConversationCompanion

- (void)controllerDeletedMessages:(id)messageIds forEveryone:(BOOL)forEveryone {
    int64_t chatId = _lendicgram_extractId(self, @selector(conversationId));

    if ([messageIds isKindOfClass:[NSArray class]]) {
        for (NSNumber *msgId in (NSArray *)messageIds) {
            [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                             inChat:chatId];
        }
    }
    // Suppress deletion — do NOT call %orig
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 3 — TGMessageModernConversationItem (legacy cells)
// ══════════════════════════════════════════════════════════════════════

%hook TGMessageModernConversationItem

- (UIView *)cellForItem {
    UIView *cell = %orig;

    int64_t msgId = 0;
    if ([(id)self respondsToSelector:@selector(message)]) {
        id msg = ((id(*)(id, SEL))objc_msgSend)((id)self, @selector(message));
        msgId = _lendicgram_extractId(msg, @selector(mid));
    }

    if ([[LendicgramManager sharedManager] isMessageDeleted:msgId inChat:0]) {
        _lendicgram_applyDeletedStyle(cell);
    } else {
        _lendicgram_removeDeletedStyle(cell);
    }

    return cell;
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 4 — ChatHistoryListNodeImpl (Swift bridge, TG 9.x+)
// ══════════════════════════════════════════════════════════════════════

%hook ChatHistoryListNodeImpl

- (void)removeMessagesAtIds:(id)messageIds {
    int64_t chatId = _lendicgram_extractId((id)self, @selector(chatPeerId));

    if ([messageIds isKindOfClass:[NSArray class]]) {
        for (NSNumber *msgId in (NSArray *)messageIds) {
            [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                             inChat:chatId];
        }
    }
    // Suppress removal — do NOT call %orig
    // Trigger re-layout so the deleted style shows
    if ([(id)self respondsToSelector:@selector(setNeedsLayout)]) {
        [(UIView *)(id)self setNeedsLayout];
    }
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 5 — ChatMessageBubbleItemNode (message bubble UI)
// ══════════════════════════════════════════════════════════════════════

%hook ChatMessageBubbleItemNode

- (void)layoutSubviews {
    %orig;

    int64_t msgId = 0;
    int64_t chatId = 0;

    if ([(id)self respondsToSelector:@selector(item)]) {
        id item = ((id(*)(id, SEL))objc_msgSend)((id)self, @selector(item));
        if (item && [item respondsToSelector:@selector(message)]) {
            id message = ((id(*)(id, SEL))objc_msgSend)(item, @selector(message));
            msgId = _lendicgram_extractId(message, NSSelectorFromString(@"id"));
        }
    }

    if ([[LendicgramManager sharedManager] isMessageDeleted:msgId inChat:chatId]) {
        _lendicgram_applyDeletedStyle((UIView *)self);
    } else {
        _lendicgram_removeDeletedStyle((UIView *)self);
    }
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 6 — AccountStateManagerImpl (server-pushed deletions)
// ══════════════════════════════════════════════════════════════════════

%hook AccountStateManagerImpl

- (void)deleteMessages:(id)messageIds peerId:(id)peerId {
    int64_t chatId = 0;
    if ([peerId respondsToSelector:@selector(longLongValue)]) {
        chatId = [peerId longLongValue];
    }

    if ([messageIds isKindOfClass:[NSArray class]]) {
        for (NSNumber *msgId in (NSArray *)messageIds) {
            [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                             inChat:chatId];
        }
    }
    // Suppress deletion — do NOT call %orig
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 7 — TGDatabaseMessageDraft (safeguard)
// ══════════════════════════════════════════════════════════════════════

%hook TGDatabaseMessageDraft
%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Constructor: Initialize + runtime discovery
// ══════════════════════════════════════════════════════════════════════

%ctor {
    %init;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        // Discover Swift ChatController delete-related selectors for debugging
        Class chatCtrl = NSClassFromString(@"TelegramUI.ChatControllerImpl");
        if (chatCtrl) {
            unsigned int count = 0;
            Method *methods = class_copyMethodList(chatCtrl, &count);
            for (unsigned int i = 0; i < count; i++) {
                SEL sel = method_getName(methods[i]);
                NSString *selName = NSStringFromSelector(sel);
                if ([selName containsString:@"deleteMessage"] ||
                    [selName containsString:@"removeMessage"]) {
                    NSLog(@"[lendicgram] ChatControllerImpl selector: %@", selName);
                }
            }
            if (methods) free(methods);
        }

        Class postbox = NSClassFromString(@"Postbox.MessageHistoryTable");
        if (postbox) {
            unsigned int count = 0;
            Method *methods = class_copyMethodList(postbox, &count);
            for (unsigned int i = 0; i < count; i++) {
                SEL sel = method_getName(methods[i]);
                NSString *selName = NSStringFromSelector(sel);
                if ([selName containsString:@"remove"] ||
                    [selName containsString:@"delete"]) {
                    NSLog(@"[lendicgram] MessageHistoryTable selector: %@", selName);
                }
            }
            if (methods) free(methods);
        }

        NSLog(@"[lendicgram] Anti-delete tweak loaded. %lu saved messages.",
              (unsigned long)[[LendicgramManager sharedManager] deletedMessageCount]);
    });
}
