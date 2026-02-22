//
//  Tweak.xm
//  lendicgram — Anti-Delete Tweak for Telegram iOS (v2: SQLite hook)
//
//  Hooks sqlite3_prepare_v2 via MobileSubstrate to intercept DELETE queries
//  in Telegram's Postbox database. When the app tries to delete message rows,
//  the query is replaced with a no-op (SELECT 0), keeping messages in the DB.
//
//  This approach works regardless of Swift/ObjC — it operates at the C level.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <sqlite3.h>
#import <string.h>
#import <dlfcn.h>

// ──────────────────────────────────────────────────────────────────────
// MARK: - Configuration
// ──────────────────────────────────────────────────────────────────────

// Set to YES to block all Postbox DELETEs (including user-initiated).
// Set to NO to only log without blocking (diagnostic mode).
static BOOL kBlockDeletes = YES;

// Enable verbose logging to Console/syslog (filter: [lendicgram])
static BOOL kVerboseLog = YES;

// ──────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ──────────────────────────────────────────────────────────────────────

// Check if the database belongs to Telegram's Postbox
static BOOL isPostboxDatabase(sqlite3 *db) {
    const char *path = sqlite3_db_filename(db, "main");
    if (!path) return NO;
    // Postbox database path contains "postbox" in the directory structure
    return (strstr(path, "postbox") != NULL);
}

// Check if this SQL is a DELETE statement
static BOOL isDeleteStatement(const char *sql) {
    if (!sql) return NO;
    // Skip leading whitespace
    while (*sql == ' ' || *sql == '\t' || *sql == '\n' || *sql == '\r') sql++;
    return (strncasecmp(sql, "DELETE", 6) == 0);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Stats tracking
// ──────────────────────────────────────────────────────────────────────

static NSUInteger sBlockedCount = 0;
static NSUInteger sAllowedCount = 0;

// ──────────────────────────────────────────────────────────────────────
// MARK: - sqlite3_prepare_v2 hook
// ──────────────────────────────────────────────────────────────────────

// Original function pointer (filled by MSHookFunction)
static int (*orig_sqlite3_prepare_v2)(sqlite3 *db,
                                       const char *zSql,
                                       int nByte,
                                       sqlite3_stmt **ppStmt,
                                       const char **pzTail);

static int hooked_sqlite3_prepare_v2(sqlite3 *db,
                                      const char *zSql,
                                      int nByte,
                                      sqlite3_stmt **ppStmt,
                                      const char **pzTail) {
    // Only intercept DELETE statements on the Postbox database
    if (zSql && isDeleteStatement(zSql) && isPostboxDatabase(db)) {

        if (kVerboseLog) {
            // Log the first 200 chars of the query for debugging
            NSLog(@"[lendicgram] POSTBOX DELETE detected (#%lu): %.200s",
                  (unsigned long)(sBlockedCount + 1), zSql);
        }

        if (kBlockDeletes) {
            sBlockedCount++;
            // Replace the DELETE with a no-op SELECT — the statement
            // succeeds (no error) but nothing is deleted from the DB.
            return orig_sqlite3_prepare_v2(db, "SELECT 0", -1, ppStmt, pzTail);
        }
    }

    sAllowedCount++;
    return orig_sqlite3_prepare_v2(db, zSql, nByte, ppStmt, pzTail);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - sqlite3_prepare (v1 fallback) hook
// ──────────────────────────────────────────────────────────────────────

static int (*orig_sqlite3_prepare)(sqlite3 *db,
                                    const char *zSql,
                                    int nByte,
                                    sqlite3_stmt **ppStmt,
                                    const char **pzTail);

static int hooked_sqlite3_prepare(sqlite3 *db,
                                   const char *zSql,
                                   int nByte,
                                   sqlite3_stmt **ppStmt,
                                   const char **pzTail) {
    if (zSql && isDeleteStatement(zSql) && isPostboxDatabase(db)) {
        if (kBlockDeletes) {
            sBlockedCount++;
            if (kVerboseLog) {
                NSLog(@"[lendicgram] POSTBOX DELETE (v1) blocked: %.200s", zSql);
            }
            return orig_sqlite3_prepare(db, "SELECT 0", -1, ppStmt, pzTail);
        }
    }
    return orig_sqlite3_prepare(db, zSql, nByte, ppStmt, pzTail);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - sqlite3_exec hook (some operations use exec directly)
// ──────────────────────────────────────────────────────────────────────

static int (*orig_sqlite3_exec)(sqlite3 *db,
                                 const char *zSql,
                                 int (*callback)(void*, int, char**, char**),
                                 void *arg,
                                 char **errmsg);

static int hooked_sqlite3_exec(sqlite3 *db,
                                const char *zSql,
                                int (*callback)(void*, int, char**, char**),
                                void *arg,
                                char **errmsg) {
    if (zSql && isDeleteStatement(zSql) && isPostboxDatabase(db)) {
        if (kBlockDeletes) {
            sBlockedCount++;
            if (kVerboseLog) {
                NSLog(@"[lendicgram] POSTBOX DELETE (exec) blocked: %.200s", zSql);
            }
            // Return SQLITE_OK without actually executing the DELETE
            return SQLITE_OK;
        }
    }
    return orig_sqlite3_exec(db, zSql, callback, arg, errmsg);
}

// ──────────────────────────────────────────────────────────────────────
// MARK: - Constructor: install hooks
// ──────────────────────────────────────────────────────────────────────

%ctor {
    @autoreleasepool {
        NSLog(@"[lendicgram] Anti-delete tweak v2 (SQLite hook) loading...");

        // Load user preferences (if set)
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.lendicgram"];
        if ([prefs objectForKey:@"blockDeletes"] != nil) {
            kBlockDeletes = [prefs boolForKey:@"blockDeletes"];
        }
        if ([prefs objectForKey:@"verboseLog"] != nil) {
            kVerboseLog = [prefs boolForKey:@"verboseLog"];
        }

        // Hook sqlite3_prepare_v2 — main query preparation function
        MSHookFunction((void *)sqlite3_prepare_v2,
                        (void *)hooked_sqlite3_prepare_v2,
                        (void **)&orig_sqlite3_prepare_v2);

        // Hook sqlite3_prepare — fallback for older API usage
        MSHookFunction((void *)sqlite3_prepare,
                        (void *)hooked_sqlite3_prepare,
                        (void **)&orig_sqlite3_prepare);

        // Hook sqlite3_exec — some batch operations use this
        MSHookFunction((void *)sqlite3_exec,
                        (void *)hooked_sqlite3_exec,
                        (void **)&orig_sqlite3_exec);

        NSLog(@"[lendicgram] Hooks installed. blockDeletes=%d, verboseLog=%d",
              kBlockDeletes, kVerboseLog);

        // Show a subtle notification on first launch with the tweak
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            NSLog(@"[lendicgram] Tweak active. Blocked %lu DELETEs so far.",
                  (unsigned long)sBlockedCount);
        });
    }
}
