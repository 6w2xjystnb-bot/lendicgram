//
//  LendicgramManager.m
//  lendicgram — Anti-Delete Tweak for Telegram iOS
//
//  Persists deleted message IDs in NSUserDefaults (suite "com.lendicgram").
//

#import "LendicgramManager.h"

static NSString *const kSuiteName       = @"com.lendicgram";
static NSString *const kDeletedMsgsKey  = @"deletedMessages";

@implementation LendicgramManager {
    NSUserDefaults *_defaults;
    NSMutableDictionary<NSString *, NSMutableSet<NSNumber *> *> *_store;
}

+ (instancetype)sharedManager {
    static LendicgramManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:kSuiteName];
        [self _load];
    }
    return self;
}

#pragma mark - Public API

- (void)markMessageAsDeleted:(int64_t)messageId inChat:(int64_t)chatId {
    NSString *chatKey = [self _keyForChat:chatId];
    NSMutableSet<NSNumber *> *set = _store[chatKey];
    if (!set) {
        set = [NSMutableSet set];
        _store[chatKey] = set;
    }
    [set addObject:@(messageId)];
    [self _save];
}

- (BOOL)isMessageDeleted:(int64_t)messageId inChat:(int64_t)chatId {
    NSString *chatKey = [self _keyForChat:chatId];
    return [_store[chatKey] containsObject:@(messageId)];
}

- (void)clearDeletedMessage:(int64_t)messageId inChat:(int64_t)chatId {
    NSString *chatKey = [self _keyForChat:chatId];
    [_store[chatKey] removeObject:@(messageId)];
    if (_store[chatKey].count == 0) {
        [_store removeObjectForKey:chatKey];
    }
    [self _save];
}

- (NSUInteger)deletedMessageCount {
    NSUInteger total = 0;
    for (NSMutableSet *set in _store.allValues) {
        total += set.count;
    }
    return total;
}

#pragma mark - Persistence helpers

- (NSString *)_keyForChat:(int64_t)chatId {
    return [NSString stringWithFormat:@"%lld", chatId];
}

- (void)_load {
    NSDictionary *raw = [_defaults objectForKey:kDeletedMsgsKey];
    _store = [NSMutableDictionary dictionary];
    if ([raw isKindOfClass:[NSDictionary class]]) {
        for (NSString *chatKey in raw) {
            NSArray *ids = raw[chatKey];
            if ([ids isKindOfClass:[NSArray class]]) {
                NSMutableSet *set = [NSMutableSet setWithArray:ids];
                _store[chatKey] = set;
            }
        }
    }
}

- (void)_save {
    NSMutableDictionary *serializable = [NSMutableDictionary dictionary];
    for (NSString *chatKey in _store) {
        serializable[chatKey] = [_store[chatKey] allObjects];
    }
    [_defaults setObject:serializable forKey:kDeletedMsgsKey];
    [_defaults synchronize];
}

@end
