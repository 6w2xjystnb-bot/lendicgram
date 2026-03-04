/*
 *  LendicTweak.m v2 — ALWAYS-SC + SEARCH INJECTION
 *  Standalone dylib for Maple (Yandex Music fork, ru.yandex.mobile.music5)
 *
 *  WHAT IT DOES
 *  ─────────────
 *  1. ALL TRACKS FROM SC
 *     Intercepts EVERY download-info API call. Even if Yandex returns a
 *     valid URL, we replace it with the SoundCloud version.
 *     → Fixes broken/порваные дорожки, unavailable tracks, geo-blocks.
 *
 *  2. SEARCH INJECTION
 *     Hooks the Yandex search API response. Runs a parallel SC search.
 *     SC tracks not already in the Yandex results are injected as fake
 *     Yandex track entries at the end of the list.
 *     → Lets users find tracks that don't exist on Yandex at all.
 *
 *  SC RESOLUTION CHAIN (per track)
 *  ─────────────────────────────────
 *  supplement hook → cache {title, artist, trackId}
 *  download-info hook (always) →
 *    SC search?q=artist+title&filter.streamable=1&limit=10 →
 *    pick best →
 *    GET transcodings[progressive].url?client_id=... →
 *    { "url": "https://cf-media.sndcdn.com/..." }  ← direct CDN, ready for AVPlayer
 *    inject as fake download-info → Maple plays SC audio
 *
 *  CLIENT_ID
 *  ──────────
 *  Bootstrap key baked in. Auto-refreshed every 60 min by scraping
 *  soundcloud.com, extracting client_id from last JS bundle.
 */

#import "LendicTweak.h"
#import <objc/runtime.h>

// ═══════════════════════════════════════════════════════════════════════════
//  LendicSCTrack
// ═══════════════════════════════════════════════════════════════════════════

@implementation LendicSCTrack

// Format Maple expects for download-info (array of dicts with "url", "codec", etc.)
- (NSArray<NSDictionary *> *)asYandexDownloadInfo {
    return @[@{
        @"codec":         @"mp3",
        @"gain":          @NO,
        @"preview":       @NO,
        @"url":           self.streamURL.absoluteString,
        @"bitrateInKbps": @(128)
    }];
}

// Minimal fake Yandex track for search injection
// Keeps it simple — only fields Maple actually renders in the list
- (NSDictionary *)asYandexTrackDict {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    // Use a large fake numeric ID unlikely to collide with real Yandex IDs
    // Prefix with 9000000000 + SC id to make it unique and recognizable
    long long fakeId = 9000000000LL + [self.scId longLongValue];
    d[@"id"]      = @(fakeId);
    d[@"title"]   = self.title;
    d[@"artists"] = @[@{@"id": @(fakeId), @"name": self.artist}];
    d[@"albums"]  = @[@{@"id": @(fakeId), @"title": @"SoundCloud", @"year": @(2024)}];
    if (self.artworkURL) {
        d[@"coverUri"] = self.artworkURL.absoluteString;
    }
    d[@"durationMs"]   = @(self.duration);
    d[@"available"]    = @YES;         // tell Maple it's playable
    d[@"availableForPremiumUsers"] = @YES;
    // Tag so we can correlate when download-info fires for this fake id
    d[@"_lendicScId"]  = self.scId;
    return [d copy];
}

@end

// ═══════════════════════════════════════════════════════════════════════════
//  LendicManager
// ═══════════════════════════════════════════════════════════════════════════

@interface LendicManager ()
@property (nonatomic, copy)   NSString      *clientId;
@property (nonatomic, assign) NSTimeInterval cidFetchedAt;
@property (nonatomic, strong) NSURLSession  *session;
// Playback cache: normalized query → resolved LendicSCTrack (CDN URL)
@property (nonatomic, strong) NSCache<NSString *, LendicSCTrack *> *playCache;
// Search cache: query → array of LendicSCTrack (for search injection)
@property (nonatomic, strong) NSCache<NSString *, NSArray *>       *searchCache;
// In-flight dedup
@property (nonatomic, strong) NSMutableSet<NSString *> *inFlight;
// fakeId → scId mapping (so download-info hook can find the right track)
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *fakeIdMap;
@property (nonatomic, strong) dispatch_queue_t serial;
@end

@implementation LendicManager

+ (instancetype)shared {
    static LendicManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [LendicManager new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    // Bootstrap client_id (will be refreshed automatically)
    _clientId    = @"a13083696803730761e053f364023773";
    _cidFetchedAt = 0;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest  = 10;
    cfg.HTTPAdditionalHeaders = @{
        @"User-Agent":
            @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
             "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        @"Origin":  @"https://soundcloud.com",
        @"Referer": @"https://soundcloud.com/"
    };
    _session = [NSURLSession sessionWithConfiguration:cfg];

    _playCache   = [NSCache new]; _playCache.countLimit   = 400;
    _searchCache = [NSCache new]; _searchCache.countLimit = 100;
    _inFlight    = [NSMutableSet new];
    _fakeIdMap   = [NSMutableDictionary new];
    _serial      = dispatch_queue_create("lendic.serial", DISPATCH_QUEUE_SERIAL);
    return self;
}

// ─── Normalisation ────────────────────────────────────────────────────────

- (NSString *)normalise:(NSString *)raw {
    static NSArray<NSRegularExpression *> *res;
    static dispatch_once_t o;
    dispatch_once(&o, ^{
        NSArray *pats = @[
            @"\\(feat\\.?[^)]*\\)", @"\\(ft\\.?[^)]*\\)",
            @"\\(with[^)]*\\)",     @"\\[.*?\\]",
            @"\\(prod\\.?[^)]*\\)", @"\\(official[^)]*\\)",
            @"official\\s+(music\\s+)?video", @"official\\s+audio",
            @"lyric(s)?\\s+video",  @"\\(hd\\)", @"\\s+hd$", @"\\s+4k$"
        ];
        NSMutableArray *arr = [NSMutableArray new];
        for (NSString *p in pats) {
            NSRegularExpression *r = [NSRegularExpression
                regularExpressionWithPattern:p
                                     options:NSRegularExpressionCaseInsensitive
                                       error:nil];
            if (r) [arr addObject:r];
        }
        res = arr;
    });
    NSString *s = raw ?: @"";
    for (NSRegularExpression *r in res) {
        s = [r stringByReplacingMatchesInString:s options:0
                                          range:NSMakeRange(0, s.length)
                                   withTemplate:@""];
    }
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)cacheKey:(NSString *)title artist:(NSString *)artist {
    return [NSString stringWithFormat:@"%@§%@",
            [artist lowercaseString], [self normalise:title].lowercaseString];
}

- (BOOL)sc:(NSString *)scTitle matches:(NSString *)yaTitle {
    NSString *a = [self normalise:scTitle].lowercaseString;
    NSString *b = [self normalise:yaTitle].lowercaseString;
    return [a containsString:b] || [b containsString:a];
}

// ─── client_id refresh ───────────────────────────────────────────────────

- (void)ensureClientId:(void(^)(NSString *))cb {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (_clientId.length && (now - _cidFetchedAt) < 3600) {
        if (cb) cb(_clientId); return;
    }
    LENDIC_LOG(@"Refreshing SC client_id...");
    [[_session dataTaskWithURL:[NSURL URLWithString:SC_WEB]
            completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d) { if (cb) cb(self->_clientId); return; }
        NSString *html  = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        NSRegularExpression *sre = [NSRegularExpression
            regularExpressionWithPattern:@"<script[^>]+src=\"(https://[^\"]+\\.js)\""
                                 options:0 error:nil];
        NSMutableArray *scripts = [NSMutableArray new];
        [sre enumerateMatchesInString:html options:0
                                range:NSMakeRange(0, html.length)
                           usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *s) {
            NSRange rng = [m rangeAtIndex:1];
            if (rng.location != NSNotFound) [scripts addObject:[html substringWithRange:rng]];
        }];
        NSArray *last = scripts.count > 5
            ? [scripts subarrayWithRange:NSMakeRange(scripts.count - 5, 5)]
            : scripts;
        __block BOOL found = NO;
        __block NSInteger rem = last.count;
        if (!rem) { if (cb) cb(self->_clientId); return; }
        for (NSString *su in last) {
            [[self->_session dataTaskWithURL:[NSURL URLWithString:su]
                          completionHandler:^(NSData *jd, NSURLResponse *jr, NSError *je) {
                if (!found && jd) {
                    NSString *js = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
                    NSRegularExpression *cre = [NSRegularExpression
                        regularExpressionWithPattern:@"client_id[=:][\"']([a-zA-Z0-9]{20,40})[\"']"
                                             options:0 error:nil];
                    NSTextCheckingResult *m = [cre firstMatchInString:js options:0
                                                                range:NSMakeRange(0, js.length)];
                    if (m && m.numberOfRanges > 1) {
                        found = YES;
                        NSString *newId = [js substringWithRange:[m rangeAtIndex:1]];
                        LENDIC_LOG(@"New client_id: %@", newId);
                        self->_clientId       = newId;
                        self->_cidFetchedAt   = NSDate.date.timeIntervalSince1970;
                    }
                }
                if (--rem == 0 && cb) cb(self->_clientId);
            }] resume];
        }
    }] resume];
}

// ─── Low-level: fetch SC search results ──────────────────────────────────
// Returns raw SC collection array (NSDictionary per track)

- (void)scSearchRaw:(NSString *)query
              limit:(NSInteger)limit
           clientId:(NSString *)cid
         completion:(void(^)(NSArray<NSDictionary *> *))cb {
    NSString *enc = [query stringByAddingPercentEncodingWithAllowedCharacters:
                     NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *urlStr = [NSString stringWithFormat:
        @"%@/search/tracks?q=%@&client_id=%@&limit=%ld&filter.streamable=1",
        SC_API, enc, cid, (long)limit];
    [[_session dataTaskWithURL:[NSURL URLWithString:urlStr]
            completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d || e) { if (cb) cb(@[]); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSArray *col = json[@"collection"] ?: @[];
        if (cb) cb(col);
    }] resume];
}

// ─── Resolve: progressive transcoding URL → signed CDN URL ───────────────

- (void)resolveTranscoding:(NSString *)transcodingURL
                  clientId:(NSString *)cid
                completion:(void(^)(NSURL *))cb {
    NSString *full = [transcodingURL stringByAppendingFormat:@"?client_id=%@", cid];
    [[_session dataTaskWithURL:[NSURL URLWithString:full]
            completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d || e) { if (cb) cb(nil); return; }
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *s = j[@"url"];
        if (cb) cb(s ? [NSURL URLWithString:s] : nil);
    }] resume];
}

// ─── Public: resolveForTitle:artist: ─────────────────────────────────────
// Searches SC for best match, resolves CDN URL, caches result.

- (void)resolveForTitle:(NSString *)title
                 artist:(NSString *)artist
             completion:(void(^)(LendicSCTrack *))cb {
    if (!title.length) { if (cb) cb(nil); return; }
    NSString *key = [self cacheKey:title artist:artist];

    LendicSCTrack *hit = [_playCache objectForKey:key];
    if (hit) { if (cb) cb(hit); return; }

    @synchronized(_inFlight) {
        if ([_inFlight containsObject:key]) { if (cb) cb(nil); return; }
        [_inFlight addObject:key];
    }

    [self ensureClientId:^(NSString *cid) {
        NSString *q = [[NSString stringWithFormat:@"%@ %@",
                        artist, [self normalise:title]]
                       stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

        [self scSearchRaw:q limit:10 clientId:cid completion:^(NSArray<NSDictionary *> *col) {
            // Pick best candidate
            NSDictionary *best = nil;
            for (NSDictionary *t in col) {
                if (![t[@"streamable"] boolValue]) continue;
                if ([t[@"policy"] isEqualToString:@"BLOCK"]) continue;
                BOOL hasP = NO;
                for (NSDictionary *tc in t[@"media"][@"transcodings"]) {
                    if ([tc[@"format"][@"protocol"] isEqualToString:@"progressive"]) { hasP = YES; break; }
                }
                if (!hasP) continue;
                if (!best) best = t;
                if ([self sc:t[@"title"] ?: @"" matches:title]) { best = t; break; }
            }

            if (!best) {
                LENDIC_LOG(@"No SC match: %@ – %@", artist, title);
                @synchronized(self->_inFlight) { [self->_inFlight removeObject:key]; }
                if (cb) cb(nil);
                return;
            }

            // Find progressive transcoding
            NSString *progURL = nil;
            for (NSDictionary *tc in best[@"media"][@"transcodings"]) {
                if ([tc[@"format"][@"protocol"] isEqualToString:@"progressive"]) {
                    progURL = tc[@"url"]; break;
                }
            }

            [self resolveTranscoding:progURL clientId:cid completion:^(NSURL *cdnURL) {
                @synchronized(self->_inFlight) { [self->_inFlight removeObject:key]; }
                if (!cdnURL) { if (cb) cb(nil); return; }

                LendicSCTrack *track = [LendicSCTrack new];
                track.scId      = [NSString stringWithFormat:@"%@", best[@"id"]];
                track.title     = best[@"title"]  ?: title;
                track.artist    = best[@"user"][@"username"] ?: artist;
                track.streamURL = cdnURL;
                track.duration  = [best[@"duration"] integerValue];
                NSString *art   = best[@"artwork_url"];
                if (art) track.artworkURL = [NSURL URLWithString:
                    [art stringByReplacingOccurrencesOfString:@"-large" withString:@"-t500x500"]];

                LENDIC_LOG(@"✅ %@ – %@  →  %@", track.artist, track.title, cdnURL);
                [self->_playCache setObject:track forKey:key];
                if (cb) cb(track);
            }];
        }];
    }];
}

- (LendicSCTrack *)cachedForTitle:(NSString *)title artist:(NSString *)artist {
    return [_playCache objectForKey:[self cacheKey:title artist:artist]];
}

// ─── Public: searchSC:limit:completion: ──────────────────────────────────
// For search injection — returns up to `limit` LendicSCTrack objects.
// CDN URLs are NOT resolved here (that happens lazily when track is played).

- (void)searchSC:(NSString *)query
           limit:(NSInteger)limit
      completion:(void(^)(NSArray<LendicSCTrack *> *))cb {
    NSString *key = [NSString stringWithFormat:@"search§%@", query.lowercaseString];
    NSArray *cached = [_searchCache objectForKey:key];
    if (cached) { if (cb) cb(cached); return; }

    [self ensureClientId:^(NSString *cid) {
        [self scSearchRaw:query limit:limit clientId:cid
               completion:^(NSArray<NSDictionary *> *col) {
            NSMutableArray *results = [NSMutableArray new];
            for (NSDictionary *t in col) {
                if (![t[@"streamable"] boolValue]) continue;
                if ([t[@"policy"] isEqualToString:@"BLOCK"]) continue;
                LendicSCTrack *tr = [LendicSCTrack new];
                tr.scId    = [NSString stringWithFormat:@"%@", t[@"id"]];
                tr.title   = t[@"title"]  ?: @"";
                tr.artist  = t[@"user"][@"username"] ?: @"";
                tr.duration = [t[@"duration"] integerValue];
                NSString *art = t[@"artwork_url"];
                if (art) tr.artworkURL = [NSURL URLWithString:
                    [art stringByReplacingOccurrencesOfString:@"-large" withString:@"-t500x500"]];
                // streamURL is nil here — resolved lazily on play
                // Register in fakeIdMap so the download-info hook can find it
                long long fakeId = 9000000000LL + [tr.scId longLongValue];
                dispatch_async(self->_serial, ^{
                    self->_fakeIdMap[@(fakeId)] = tr.scId;
                });
                [results addObject:tr];
            }
            NSArray *final = [results copy];
            [self->_searchCache setObject:final forKey:key];
            if (cb) cb(final);
        }];
    }];
}

// ─── fakeId → scId lookup ────────────────────────────────────────────────

- (NSString *)scIdForFakeYandexId:(long long)fakeId {
    __block NSString *r;
    dispatch_sync(_serial, ^{ r = self->_fakeIdMap[@(fakeId)]; });
    return r;
}

- (void)registerScTrack:(LendicSCTrack *)t {
    long long fakeId = 9000000000LL + [t.scId longLongValue];
    dispatch_async(_serial, ^{ self->_fakeIdMap[@(fakeId)] = t.scId; });
    // Also pre-cache in playCache under scId as key, if it has a CDN URL
    if (t.streamURL) [_playCache setObject:t forKey:[NSString stringWithFormat:@"scid§%@", t.scId]];
}

- (LendicSCTrack *)trackByScId:(NSString *)scId {
    return [_playCache objectForKey:[NSString stringWithFormat:@"scid§%@", scId]];
}

@end // LendicManager

// ═══════════════════════════════════════════════════════════════════════════
//  GLOBAL STATE
// ═══════════════════════════════════════════════════════════════════════════

// supplement hook: yandexTrackId → {title, artist}
static NSMutableDictionary<NSString *, NSDictionary *> *gMeta;
static dispatch_queue_t gMetaQ;

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

static BOOL isYandex(NSURL *url) {
    return url.host && [url.host containsString:@"music.yandex"];
}
static BOOL isDlInfo(NSURL *url) {
    return isYandex(url) && [url.path containsString:@"download-info"];
}
static BOOL isSupp(NSURL *url) {
    if (!isYandex(url)) return NO;
    NSString *p = url.path;
    return [p containsString:@"/tracks/"] || [p containsString:@"/track/"];
}
static BOOL isSearch(NSURL *url) {
    return isYandex(url) && [url.path containsString:@"/search"];
}

static NSString *yandexTrackId(NSURL *url) {
    NSString *p = url.path ?: @"";
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:@"/tracks?/(\\d+)" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:p options:0
                                               range:NSMakeRange(0, p.length)];
    if (m && m.numberOfRanges > 1) return [p substringWithRange:[m rangeAtIndex:1]];
    return nil;
}

// ═══════════════════════════════════════════════════════════════════════════
//  HOOK: NSURLSession dataTaskWithRequest:completionHandler:
// ═══════════════════════════════════════════════════════════════════════════

typedef NSURLSessionDataTask *(*TaskFn)(id, SEL, NSURLRequest *, void(^)(NSData *, NSURLResponse *, NSError *));
static IMP gOrigTask;

static NSURLSessionDataTask *lendic_task(
    NSURLSession *self_,
    SEL _cmd,
    NSURLRequest *req,
    void(^ch)(NSData *, NSURLResponse *, NSError *))
{
    TaskFn orig = (TaskFn)gOrigTask;
    NSURL *url  = req.URL;

    // ── 1. Supplement → cache metadata + pre-warm ────────────────────────
    if (isSupp(url) && ch) {
        NSString *tid = yandexTrackId(url);
        void(^w)(NSData *, NSURLResponse *, NSError *) = ^(NSData *d, NSURLResponse *r, NSError *e) {
            if (d && tid) {
                id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                NSDictionary *td = nil;
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    id inner = obj[@"track"] ?: obj[@"result"];
                    if ([inner isKindOfClass:[NSArray class]])      td = ((NSArray *)inner).firstObject;
                    else if ([inner isKindOfClass:[NSDictionary class]]) td = inner;
                    else td = obj;
                } else if ([obj isKindOfClass:[NSArray class]]) {
                    td = ((NSArray *)obj).firstObject;
                }
                NSString *t = td[@"title"];
                NSString *a = ((NSArray *)td[@"artists"]).firstObject[@"name"] ?: @"";
                if (t.length) {
                    dispatch_async(gMetaQ, ^{ gMeta[tid] = @{@"title":t, @"artist":a}; });
                    LENDIC_LOG(@"Meta #%@: %@ – %@", tid, a, t);
                    // Pre-warm: start resolving in background NOW
                    [[LendicManager shared] resolveForTitle:t artist:a completion:nil];
                }
            }
            ch(d, r, e);
        };
        return orig(self_, _cmd, req, w);
    }

    // ── 2. download-info → ALWAYS replace with SC ────────────────────────
    if (isDlInfo(url) && ch) {
        NSString *tid   = yandexTrackId(url);
        LendicManager *mgr = [LendicManager shared];

        // Check if this is a fake Yandex ID (injected SC track from search)
        long long numId = tid ? [tid longLongValue] : 0;
        NSString *scId  = (numId > 9000000000LL) ? [mgr scIdForFakeYandexId:numId] : nil;

        void(^w)(NSData *, NSURLResponse *, NSError *) = ^(NSData *d, NSURLResponse *r, NSError *e) {

            // Helper: inject CDN URL as fake download-info
            void(^inject)(LendicSCTrack *) = ^(LendicSCTrack *track) {
                NSData *fake = [NSJSONSerialization
                    dataWithJSONObject:[track asYandexDownloadInfo] options:0 error:nil];
                NSHTTPURLResponse *fr = [[NSHTTPURLResponse alloc]
                    initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1"
                   headerFields:@{@"Content-Type":@"application/json"}];
                ch(fake, fr, nil);
            };

            // Case A: fake ID from search injection — resolve directly by scId
            if (scId) {
                LendicSCTrack *cached = [mgr trackByScId:scId];
                if (cached) { inject(cached); return; }
                // Resolve from scratch: fetch track info by scId
                [mgr ensureClientId:^(NSString *cid) {
                    NSString *apiURL = [NSString stringWithFormat:
                        @"%@/tracks/%@?client_id=%@", SC_API, scId, cid];
                    NSURLSession *sess = mgr.session;
                    [[sess dataTaskWithURL:[NSURL URLWithString:apiURL]
                         completionHandler:^(NSData *jd, NSURLResponse *jr, NSError *je) {
                        NSDictionary *t = [NSJSONSerialization JSONObjectWithData:jd options:0 error:nil];
                        NSString *pURL  = nil;
                        for (NSDictionary *tc in t[@"media"][@"transcodings"]) {
                            if ([tc[@"format"][@"protocol"] isEqualToString:@"progressive"]) {
                                pURL = tc[@"url"]; break;
                            }
                        }
                        if (!pURL) { ch(d, r, e); return; }
                        [mgr resolveTranscoding:pURL clientId:cid completion:^(NSURL *cdnURL) {
                            if (!cdnURL) { ch(d, r, e); return; }
                            LendicSCTrack *tr = [LendicSCTrack new];
                            tr.scId      = scId;
                            tr.title     = t[@"title"] ?: @"";
                            tr.artist    = t[@"user"][@"username"] ?: @"";
                            tr.streamURL = cdnURL;
                            tr.duration  = [t[@"duration"] integerValue];
                            [mgr registerScTrack:tr];
                            inject(tr);
                        }];
                    }] resume];
                }];
                return;
            }

            // Case B: real Yandex track — ALWAYS replace with SC version
            __block NSDictionary *meta = nil;
            dispatch_sync(gMetaQ, ^{ meta = tid ? gMeta[tid] : nil; });
            NSString *title  = meta[@"title"]  ?: @"";
            NSString *artist = meta[@"artist"] ?: @"";

            if (!title.length) {
                LENDIC_LOG(@"No meta for #%@, pass through", tid);
                ch(d, r, e); return;
            }

            // Check play cache first (may already be pre-warmed)
            LendicSCTrack *prewarm = [mgr cachedForTitle:title artist:artist];
            if (prewarm) { LENDIC_LOG(@"⚡ Cache hit: %@", title); inject(prewarm); return; }

            LENDIC_LOG(@"Resolving SC for: %@ – %@", artist, title);
            [mgr resolveForTitle:title artist:artist completion:^(LendicSCTrack *track) {
                if (track) {
                    inject(track);
                } else {
                    // SC miss — fall back to original Yandex audio (if any)
                    LENDIC_LOG(@"SC miss for '%@', using Yandex", title);
                    ch(d, r, e);
                }
            }];
        };

        // We fire the original request AND intercept its response
        return orig(self_, _cmd, req, w);
    }

    // ── 3. Search → inject SC-only tracks ───────────────────────────────
    if (isSearch(url) && ch) {
        // Extract search query from URL parameters
        NSURLComponents *comps = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *searchQuery  = nil;
        for (NSURLQueryItem *qi in comps.queryItems) {
            if ([qi.name isEqualToString:@"text"] || [qi.name isEqualToString:@"query"]) {
                searchQuery = qi.value; break;
            }
        }

        if (!searchQuery.length) return orig(self_, _cmd, req, ch);

        NSString *sq = [searchQuery copy];

        void(^w)(NSData *, NSURLResponse *, NSError *) = ^(NSData *d, NSURLResponse *r, NSError *e) {
            if (!d) { ch(d, r, e); return; }

            id json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) { ch(d, r, e); return; }

            // Collect existing Yandex track titles (to dedup SC results)
            NSMutableSet *yaTitles = [NSMutableSet new];
            NSArray *yaResults = json[@"result"][@"tracks"][@"results"]
                              ?: json[@"tracks"][@"results"]
                              ?: json[@"result"][@"results"]
                              ?: @[];
            for (NSDictionary *t in yaResults) {
                NSString *yt = [t[@"title"] lowercaseString];
                if (yt.length) [yaTitles addObject:yt];
            }

            // Run SC search in parallel, then inject
            [[LendicManager shared] searchSC:sq limit:15
                                  completion:^(NSArray<LendicSCTrack *> *scTracks) {
                // Only SC tracks not already in Yandex results
                NSMutableArray *novel = [NSMutableArray new];
                for (LendicSCTrack *t in scTracks) {
                    BOOL dup = NO;
                    for (NSString *ya in yaTitles) {
                        if ([ya containsString:t.title.lowercaseString] ||
                            [t.title.lowercaseString containsString:ya]) {
                            dup = YES; break;
                        }
                    }
                    if (!dup) [novel addObject:[t asYandexTrackDict]];
                }

                if (!novel.count) { ch(d, r, e); return; }

                LENDIC_LOG(@"Search injection: +%lu SC tracks for '%@'",
                           (unsigned long)novel.count, sq);

                // Deep-copy the Yandex response and append SC tracks
                NSMutableDictionary *mutJson = [json mutableCopy];
                // Traverse to the tracks results array and append
                NSMutableDictionary *result = [[mutJson[@"result"] mutableCopy] ?: [NSMutableDictionary new] copy];
                NSMutableDictionary *tracks = [[result[@"tracks"] mutableCopy] ?: [NSMutableDictionary new] copy];
                NSMutableArray *results     = [[tracks[@"results"] mutableCopy] ?: [NSMutableArray new] copy];
                [results addObjectsFromArray:novel];
                tracks[@"results"]  = results;
                result[@"tracks"]   = tracks;
                mutJson[@"result"]  = result;

                NSData *newData = [NSJSONSerialization dataWithJSONObject:mutJson options:0 error:nil];
                if (!newData) { ch(d, r, e); return; }

                NSHTTPURLResponse *newResp = [[NSHTTPURLResponse alloc]
                    initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1"
                   headerFields:@{@"Content-Type": @"application/json"}];
                ch(newData, newResp, nil);
            }];
        };

        return orig(self_, _cmd, req, w);
    }

    return orig(self_, _cmd, req, ch);
}

__attribute__((constructor))
static void LendicSetup(void) {
    gMeta  = [NSMutableDictionary new];
    gMetaQ = dispatch_queue_create("lendic.meta", DISPATCH_QUEUE_SERIAL);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        Method m = class_getInstanceMethod(
            [NSURLSession class],
            @selector(dataTaskWithRequest:completionHandler:));
        if (m) {
            gOrigTask = method_getImplementation(m);
            method_setImplementation(m, (IMP)lendic_task);
            LENDIC_LOG(@"✅ Hooked");
        }
        // Pre-fetch client_id immediately
        [[LendicManager shared] ensureClientId:^(NSString *cid) {
            LENDIC_LOG(@"🟢 Ready — client_id: %@", cid);
        }];
    });
}
