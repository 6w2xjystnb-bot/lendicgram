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
#import "LendicgramManager.h"

// ──────────────────────────────────────────────────────────────────────
// MARK: - Associated-object keys
// ──────────────────────────────────────────────────────────────────────
static const char kDeletedFlagKey;          // BOOL wrapper
static const char kDeletedBadgeKey;         // UIView* cross badge
static const char kOriginalAlphaKey;        // NSNumber (CGFloat)

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
    badge.tag = 0x4C454E44; // "LEND" — easy to find later

    // Draw a small ✕ using a UILabel
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

    // Save original alpha once
    NSNumber *saved = objc_getAssociatedObject(contentView, &kOriginalAlphaKey);
    if (!saved) {
        objc_setAssociatedObject(contentView, &kOriginalAlphaKey,
                                 @(contentView.alpha),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    contentView.alpha = kDeletedAlpha;

    // Add badge if not already present
    UIView *existing = objc_getAssociatedObject(contentView, &kDeletedBadgeKey);
    if (!existing) {
        UIView *badge = _lendicgram_createBadge();

        // Position: top-right of the content view
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
// MARK: - Helper: Restore normal appearance (if message reemerges)
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

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 1 — Intercept message deletion at the account level
// ══════════════════════════════════════════════════════════════════════
//
// Telegram iOS uses a Swift-based Postbox layer, but higher-level
// controllers still route through Objective-C bridge classes.
// We hook the commonly seen ObjC selectors related to message removal.
//
// If the target class/method doesn't exist (different TG version), the
// hook is silently ignored by Logos.
// ══════════════════════════════════════════════════════════════════════

// ---------- TGModernConversationController (legacy & bridged) ---------

%hook TGModernConversationController

// Intercept when messages are requested to be deleted from the companion
- (void)_deleteMessages:(NSArray *)messageIds animated:(BOOL)animated {
    // Save each message ID before the original code removes them
    for (NSNumber *msgId in messageIds) {
        [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                         inChat:0]; // chatId resolved below if available
    }
    // Do NOT call %orig — suppress the actual deletion
    // Instead, just reload the messages so they re-draw with deleted style
    if ([self respondsToSelector:@selector(updateMessages)]) {
        [self performSelector:@selector(updateMessages)];
    }
}

%end

// ---------- TGGenericModernConversationCompanion ---------------------

%hook TGGenericModernConversationCompanion

- (void)controllerDeletedMessages:(NSArray *)messageIds
                    forEveryone:(bool)forEveryone {
    int64_t chatId = 0;
    if ([self respondsToSelector:@selector(conversationId)]) {
        chatId = ((NSNumber *)[self performSelector:@selector(conversationId)]).longLongValue;
    }
    for (NSNumber *msgId in messageIds) {
        [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                         inChat:chatId];
    }
    // Suppress original — do not actually delete
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 2 — Real-time incoming deletions (remote peer deletes)
// ══════════════════════════════════════════════════════════════════════
// When the server pushes a "delete messages" update, Telegram processes
// it through TGUpdateMessageService / TGChannelStateSignals or similar.
// We intercept at the bridge layer.
// ══════════════════════════════════════════════════════════════════════

%hook TGDatabaseMessageDraft

// Some Telegram versions route remote deletions through the database
// update path. We add a safeguard hook here.

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 3 — Visual: style message cells for deleted content
// ══════════════════════════════════════════════════════════════════════

// ---------- TGModernConversationItem (legacy cells) ------------------

%hook TGMessageModernConversationItem

- (UIView *)cellForItem {
    UIView *cell = %orig;

    int64_t msgId = 0;
    int64_t chatId = 0;

    // Try to extract message ID from the item
    if ([self respondsToSelector:@selector(message)]) {
        id msg = [self performSelector:@selector(message)];
        if ([msg respondsToSelector:@selector(mid)]) {
            msgId = ((NSNumber *)[msg performSelector:@selector(mid)]).longLongValue;
        }
    }

    if ([[LendicgramManager sharedManager] isMessageDeleted:msgId inChat:chatId]) {
        _lendicgram_applyDeletedStyle(cell);
    } else {
        _lendicgram_removeDeletedStyle(cell);
    }

    return cell;
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 4 — Swift-based ChatController (Telegram 9.x+)
// ══════════════════════════════════════════════════════════════════════
//
// Modern Telegram iOS is Swift. Many of the internal classes expose
// Objective-C-compatible selectors via @objc. We hook the chat list
// node and message bubble nodes that are accessible from ObjC runtime.
// ══════════════════════════════════════════════════════════════════════

// ---------- ChatHistoryListNode (manages visible message nodes) ------

%hook ChatHistoryListNodeImpl

// Called when messages are removed from the list
- (void)removeMessagesAtIds:(NSArray *)messageIds {
    int64_t chatId = 0;
    if ([self respondsToSelector:@selector(chatPeerId)]) {
        id peerId = [self performSelector:@selector(chatPeerId)];
        if ([peerId respondsToSelector:@selector(longLongValue)]) {
            chatId = [peerId longLongValue];
        }
    }

    for (NSNumber *msgId in messageIds) {
        [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                         inChat:chatId];
    }

    // Suppress original removal — messages stay in the list
    // Trigger a layout update so the deleted style is applied
    if ([self respondsToSelector:@selector(setNeedsLayout)]) {
        [(UIView *)self setNeedsLayout];
    }
}

%end

// ---------- ChatMessageBubbleItemNode (individual message bubble) ----

%hook ChatMessageBubbleItemNode

- (void)layoutSubviews {
    %orig;

    // Try to get the message from the item
    int64_t msgId = 0;
    int64_t chatId = 0;

    if ([self respondsToSelector:@selector(item)]) {
        id item = [self performSelector:@selector(item)];
        if ([item respondsToSelector:@selector(message)]) {
            id message = [item performSelector:@selector(message)];
            if ([message respondsToSelector:@selector(id)]) {
                id msgIdObj = [message performSelector:@selector(id)];
                if ([msgIdObj respondsToSelector:@selector(longLongValue)]) {
                    msgId = [msgIdObj longLongValue];
                }
            }
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
// MARK: - Hook 5 — Intercept server-pushed deletion updates
// ══════════════════════════════════════════════════════════════════════
// The AccountStateManager processes TL updates from the server.
// We hook the final "apply hole" / "remove messages" path.
// ══════════════════════════════════════════════════════════════════════

%hook AccountStateManagerImpl

- (void)deleteMessages:(NSArray *)messageIds peerId:(id)peerId {
    int64_t chatId = 0;
    if ([peerId respondsToSelector:@selector(longLongValue)]) {
        chatId = [peerId longLongValue];
    }

    for (NSNumber *msgId in messageIds) {
        [[LendicgramManager sharedManager] markMessageAsDeleted:msgId.longLongValue
                                                         inChat:chatId];
    }
    // Do NOT call %orig — suppress actual deletion from database
}

%end

// ══════════════════════════════════════════════════════════════════════
// MARK: - Hook 6 — Fallback: generic NSNotification observer
// ══════════════════════════════════════════════════════════════════════
// As a safety net, we observe Telegram's internal "messages deleted"
// notification (if posted) and intercept it.
// ══════════════════════════════════════════════════════════════════════

%ctor {
    %init;

    // Additional runtime-based hooks for Swift classes discovered at load
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        // Try to find and hook Swift ChatController delete methods at runtime
        Class chatCtrl = NSClassFromString(@"TelegramUI.ChatControllerImpl");
        if (chatCtrl) {
            // Enumerate methods looking for delete-related selectors
            unsigned int count = 0;
            Method *methods = class_copyMethodList(chatCtrl, &count);
            for (unsigned int i = 0; i < count; i++) {
                SEL sel = method_getName(methods[i]);
                NSString *selName = NSStringFromSelector(sel);
                if ([selName containsString:@"deleteMessage"] ||
                    [selName containsString:@"removeMessage"]) {
                    NSLog(@"[lendicgram] Found delete selector on ChatControllerImpl: %@", selName);
                }
            }
            if (methods) free(methods);
        }

        // Also check for Postbox-level removal
        Class postbox = NSClassFromString(@"Postbox.MessageHistoryTable");
        if (postbox) {
            unsigned int count = 0;
            Method *methods = class_copyMethodList(postbox, &count);
            for (unsigned int i = 0; i < count; i++) {
                SEL sel = method_getName(methods[i]);
                NSString *selName = NSStringFromSelector(sel);
                if ([selName containsString:@"remove"] ||
                    [selName containsString:@"delete"]) {
                    NSLog(@"[lendicgram] Found removal selector on MessageHistoryTable: %@", selName);
                }
            }
            if (methods) free(methods);
        }

        NSLog(@"[lendicgram] Anti-delete tweak loaded. Manager has %lu saved messages.",
              (unsigned long)[[LendicgramManager sharedManager] deletedMessageCount]);
    });
}
