//
//  LendicgramManager.h
//  lendicgram — Anti-Delete Tweak for Telegram iOS
//
//  Singleton manager that persists deleted message IDs across app launches.
//

#import <Foundation/Foundation.h>

@interface LendicgramManager : NSObject

+ (instancetype)sharedManager;

/// Mark a message ID as deleted (anti-delete saved).
- (void)markMessageAsDeleted:(int64_t)messageId inChat:(int64_t)chatId;

/// Check whether a message was deleted by the remote peer.
- (BOOL)isMessageDeleted:(int64_t)messageId inChat:(int64_t)chatId;

/// Remove a saved deleted message (if the user explicitly dismisses it).
- (void)clearDeletedMessage:(int64_t)messageId inChat:(int64_t)chatId;

/// Total number of saved deleted messages.
- (NSUInteger)deletedMessageCount;

@end
