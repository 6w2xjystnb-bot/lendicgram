//
//  Tweak.m
//  lendicgram — Anti-Delete Tweak for Telegram iOS (v3: fishhook + LiveContainer)
//
//  Uses fishhook to rebind sqlite3 symbols. No jailbreak/substrate required.
//  Works with LiveContainer, TrollStore, and jailbreak setups.
//
//  When Telegram tries to DELETE message rows from its Postbox database,
//  the SQL query is replaced with a no-op (SELECT 0).
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import <string.h>
#import <dlfcn.h>
#import "fishhook.h"

// ──────────────────────────────────────────────────────────────────────
// MARK: - State
// ──────────────────────────────────────────────────────────────────────

static NSUInteger sBlockedCount = 0;
static BOOL sTweakLoaded = NO;

// ──────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ──────────────────────────────────────────────────────────────────────

static BOOL isPostboxDatabase(sqlite3 *db) {
    const char *path = sqlite3_db_filename(db, "main");
    if (!path) return NO;
    // Telegram Postbox DB path contains "postbox" directory
    return (strstr(path, "postbox") != NULL);
}

static BOOL isDeleteStatement(const char *sql) {
    if (!sql) return NO;
    while (*sql == ' ' || *sql == '\t' || *sql == '\n' || *sql == '\r') sql++;
    return (strncasecmp(sql, "DELETE", 6) == 0);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - sqlite3_prepare_v2 hook
// ──────────────────────────────────────────────────────────────────────

static int (*orig_sqlite3_prepare_v2)(sqlite3*, const char*, int,
                                       sqlite3_stmt**, const char**);

static int hook_sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte,
                                    sqlite3_stmt **ppStmt, const char **pzTail) {
    if (zSql && isDeleteStatement(zSql) && isPostboxDatabase(db)) {
        sBlockedCount++;
        NSLog(@"[lendicgram] BLOCKED DELETE #%lu: %.120s",
              (unsigned long)sBlockedCount, zSql);
        // Replace DELETE with no-op — statement succeeds but nothing removed
        return orig_sqlite3_prepare_v2(db, "SELECT 0", -1, ppStmt, pzTail);
    }
    return orig_sqlite3_prepare_v2(db, zSql, nByte, ppStmt, pzTail);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - sqlite3_prepare_v3 hook (modern SQLite API)
// ──────────────────────────────────────────────────────────────────────

static int (*orig_sqlite3_prepare_v3)(sqlite3*, const char*, int,
                                       unsigned int, sqlite3_stmt**,
                                       const char**);

static int hook_sqlite3_prepare_v3(sqlite3 *db, const char *zSql, int nByte,
                                    unsigned int prepFlags,
                                    sqlite3_stmt **ppStmt, const char **pzTail) {
    if (zSql && isDeleteStatement(zSql) && isPostboxDatabase(db)) {
        sBlockedCount++;
        NSLog(@"[lendicgram] BLOCKED DELETE v3 #%lu: %.120s",
              (unsigned long)sBlockedCount, zSql);
        return orig_sqlite3_prepare_v3(db, "SELECT 0", -1, prepFlags,
                                        ppStmt, pzTail);
    }
    return orig_sqlite3_prepare_v3(db, zSql, nByte, prepFlags, ppStmt, pzTail);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - sqlite3_exec hook
// ──────────────────────────────────────────────────────────────────────

static int (*orig_sqlite3_exec)(sqlite3*, const char*,
                                 int(*)(void*,int,char**,char**),
                                 void*, char**);

static int hook_sqlite3_exec(sqlite3 *db, const char *zSql,
                              int (*callback)(void*,int,char**,char**),
                              void *arg, char **errmsg) {
    if (zSql && isDeleteStatement(zSql) && isPostboxDatabase(db)) {
        sBlockedCount++;
        NSLog(@"[lendicgram] BLOCKED DELETE exec #%lu: %.120s",
              (unsigned long)sBlockedCount, zSql);
        return SQLITE_OK; // Pretend success
    }
    return orig_sqlite3_exec(db, zSql, callback, arg, errmsg);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Visual indicator
// ──────────────────────────────────────────────────────────────────────

static void showLoadedBanner(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 15.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                        if (w.isKeyWindow) { keyWindow = w; break; }
                    }
                }
            }
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            keyWindow = UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
        }

        if (!keyWindow) return;

        // Create a small banner at the top
        UILabel *banner = [[UILabel alloc] init];
        banner.text = @"✕ lendicgram active";
        banner.textColor = [UIColor whiteColor];
        banner.backgroundColor = [UIColor colorWithRed:0.18 green:0.75 blue:0.45 alpha:0.95];
        banner.textAlignment = NSTextAlignmentCenter;
        banner.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        banner.layer.cornerRadius = 16;
        banner.layer.masksToBounds = YES;

        CGFloat bannerW = 180, bannerH = 32;
        CGFloat screenW = keyWindow.bounds.size.width;
        banner.frame = CGRectMake((screenW - bannerW) / 2.0, -bannerH, bannerW, bannerH);
        [keyWindow addSubview:banner];

        // Animate in
        [UIView animateWithDuration:0.5 delay:0
             usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0
                         animations:^{
            CGFloat topInset = keyWindow.safeAreaInsets.top;
            banner.frame = CGRectMake((screenW - bannerW) / 2.0,
                                      topInset + 4, bannerW, bannerH);
        } completion:^(BOOL finished) {
            // Fade out after 2.5 seconds
            [UIView animateWithDuration:0.6 delay:2.5 options:0
                             animations:^{ banner.alpha = 0; }
                             completion:^(BOOL f) { [banner removeFromSuperview]; }];
        }];
    });
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Constructor — entry point (no substrate needed)
// ──────────────────────────────────────────────────────────────────────

__attribute__((constructor))
static void lendicgram_init(void) {
    @autoreleasepool {
        NSLog(@"[lendicgram] v3 (fishhook) loading...");

        // Rebind all sqlite3 symbols via fishhook
        struct rebinding rebindings[] = {
            {"sqlite3_prepare_v2", (void *)hook_sqlite3_prepare_v2,
             (void **)&orig_sqlite3_prepare_v2},
            {"sqlite3_prepare_v3", (void *)hook_sqlite3_prepare_v3,
             (void **)&orig_sqlite3_prepare_v3},
            {"sqlite3_exec", (void *)hook_sqlite3_exec,
             (void **)&orig_sqlite3_exec},
        };
        int result = rebind_symbols(rebindings, 3);

        NSLog(@"[lendicgram] fishhook rebind result: %d (0 = success)", result);

        sTweakLoaded = YES;
        showLoadedBanner();

        NSLog(@"[lendicgram] Anti-delete tweak loaded successfully.");
    }
}
