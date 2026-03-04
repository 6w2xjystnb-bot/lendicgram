/*
 *  LendicTweak.m v3 — NSURLPROTOCOL + ALWAYS-SC + SEARCH INJECTION
 *  Standalone dylib for Maple (Yandex Music fork, ru.yandex.mobile.music5)
 *
 *  WHAT CHANGED IN v3:
 *  ───────────────────
 *  Switched from `NSURLSession dataTaskWithRequest:` swizzling to `NSURLProtocol`.
 *  Why? Yandex/Maple likely uses Alamofire or proper NSURLSession delegates, which
 *  bypasses the naive block-based swizzling. `NSURLProtocol` sits below the
 *  SDK and intercepts *everything* inside the URL Loading System.
 *
 *  WHAT IT DOES
 *  ─────────────
 *  1. ALL TRACKS FROM SC
 *     Intercepts EVERY download-info API call. We replace the Yandex URL
 *     with the SoundCloud CDN URL.
 *     → Fixes broken tracks, unavailable tracks, geo-blocks.
 *
 *  2. SEARCH INJECTION
 *     Hooks the Yandex search API response. Runs a parallel SC search.
 *     SC tracks not already in the Yandex results are injected as fake
 *     Yandex track entries at the end of the list.
 */

#import "LendicTweak.h"
#import <objc/runtime.h>

// ═══════════════════════════════════════════════════════════════════════════
//  LendicSCTrack
// ═══════════════════════════════════════════════════════════════════════════

@implementation LendicSCTrack
- (NSArray<NSDictionary *> *)asYandexDownloadInfo {
    return @[@{
        @"codec":         @"mp3",
        @"gain":          @NO,
        @"preview":       @NO,
        @"url":           self.streamURL.absoluteString,
        @"bitrateInKbps": @(128)
    }];
}

- (NSDictionary *)asYandexTrackDict {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    long long fakeId = 9000000000LL + [self.scId longLongValue];
    d[@"id"]      = @(fakeId);
    d[@"title"]   = self.title;
    d[@"artists"] = @[@{@"id": @(fakeId), @"name": self.artist}];
    d[@"albums"]  = @[@{@"id": @(fakeId), @"title": @"SoundCloud", @"year": @(2024)}];
    if (self.artworkURL) d[@"coverUri"] = self.artworkURL.absoluteString;
    d[@"durationMs"]   = @(self.duration);
    d[@"available"]    = @YES;
    d[@"availableForPremiumUsers"] = @YES;
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
@property (nonatomic, strong) NSCache<NSString *, LendicSCTrack *> *playCache;
@property (nonatomic, strong) NSCache<NSString *, NSArray *>       *searchCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *inFlight;
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
    _clientId    = @"a13083696803730761e053f364023773";
    _cidFetchedAt = 0;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest  = 10;
    cfg.HTTPAdditionalHeaders = @{
        @"User-Agent": @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
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
            NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:p options:NSRegularExpressionCaseInsensitive error:nil];
            if (r) [arr addObject:r];
        }
        res = arr;
    });
    NSString *s = raw ?: @"";
    for (NSRegularExpression *r in res) {
        s = [r stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@""];
    }
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)cacheKey:(NSString *)title artist:(NSString *)artist {
    return [NSString stringWithFormat:@"%@§%@", [artist lowercaseString], [self normalise:title].lowercaseString];
}

- (BOOL)sc:(NSString *)scTitle matches:(NSString *)yaTitle {
    NSString *a = [self normalise:scTitle].lowercaseString;
    NSString *b = [self normalise:yaTitle].lowercaseString;
    return [a containsString:b] || [b containsString:a];
}

// ─── Client ID ───────────────────────────────────────────────────────────

- (void)ensureClientId:(void(^)(NSString *))cb {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (_clientId.length && (now - _cidFetchedAt) < 3600) {
        if (cb) cb(_clientId); return;
    }
    LENDIC_LOG(@"Refreshing SC client_id...");
    [[_session dataTaskWithURL:[NSURL URLWithString:SC_WEB] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d) { if (cb) cb(self->_clientId); return; }
        NSString *html  = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        NSRegularExpression *sre = [NSRegularExpression regularExpressionWithPattern:@"<script[^>]+src=\"(https://[^\"]+\\.js)\"" options:0 error:nil];
        NSMutableArray *scripts = [NSMutableArray new];
        [sre enumerateMatchesInString:html options:0 range:NSMakeRange(0, html.length) usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *s) {
            NSRange rng = [m rangeAtIndex:1];
            if (rng.location != NSNotFound) [scripts addObject:[html substringWithRange:rng]];
        }];
        NSArray *last = scripts.count > 5 ? [scripts subarrayWithRange:NSMakeRange(scripts.count - 5, 5)] : scripts;
        __block BOOL found = NO;
        __block NSInteger rem = last.count;
        if (!rem) { if (cb) cb(self->_clientId); return; }
        for (NSString *su in last) {
            [[self->_session dataTaskWithURL:[NSURL URLWithString:su] completionHandler:^(NSData *jd, NSURLResponse *jr, NSError *je) {
                if (!found && jd) {
                    NSString *js = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
                    NSRegularExpression *cre = [NSRegularExpression regularExpressionWithPattern:@"client_id[=:][\"']([a-zA-Z0-9]{20,40})[\"']" options:0 error:nil];
                    NSTextCheckingResult *m = [cre firstMatchInString:js options:0 range:NSMakeRange(0, js.length)];
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

- (void)scSearchRaw:(NSString *)query limit:(NSInteger)limit clientId:(NSString *)cid completion:(void(^)(NSArray<NSDictionary *> *))cb {
    NSString *enc = [query stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *urlStr = [NSString stringWithFormat:@"%@/search/tracks?q=%@&client_id=%@&limit=%ld&filter.streamable=1", SC_API, enc, cid, (long)limit];
    [[_session dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d || e) { if (cb) cb(@[]); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSArray *col = json[@"collection"] ?: @[];
        if (cb) cb(col);
    }] resume];
}

- (void)resolveTranscoding:(NSString *)transcodingURL clientId:(NSString *)cid completion:(void(^)(NSURL *))cb {
    NSString *full = [transcodingURL stringByAppendingFormat:@"?client_id=%@", cid];
    [[_session dataTaskWithURL:[NSURL URLWithString:full] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d || e) { if (cb) cb(nil); return; }
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *s = j[@"url"];
        if (cb) cb(s ? [NSURL URLWithString:s] : nil);
    }] resume];
}

- (void)resolveForTitle:(NSString *)title artist:(NSString *)artist completion:(void(^)(LendicSCTrack *))cb {
    if (!title.length) { if (cb) cb(nil); return; }
    NSString *key = [self cacheKey:title artist:artist];

    LendicSCTrack *hit = [_playCache objectForKey:key];
    if (hit) { if (cb) cb(hit); return; }

    @synchronized(_inFlight) {
        if ([_inFlight containsObject:key]) { if (cb) cb(nil); return; }
        [_inFlight addObject:key];
    }

    [self ensureClientId:^(NSString *cid) {
        NSString *q = [[NSString stringWithFormat:@"%@ %@", artist, [self normalise:title]] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        [self scSearchRaw:q limit:10 clientId:cid completion:^(NSArray<NSDictionary *> *col) {
            NSDictionary *best = nil;
            for (NSDictionary *t in col) {
                if (![t[@"streamable"] boolValue] || [t[@"policy"] isEqualToString:@"BLOCK"]) continue;
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
                if (cb) cb(nil); return;
            }

            NSString *progURL = nil;
            for (NSDictionary *tc in best[@"media"][@"transcodings"]) {
                if ([tc[@"format"][@"protocol"] isEqualToString:@"progressive"]) { progURL = tc[@"url"]; break; }
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
                if (art) track.artworkURL = [NSURL URLWithString:[art stringByReplacingOccurrencesOfString:@"-large" withString:@"-t500x500"]];

                LENDIC_LOG(@"✅ SC resolved: %@ – %@  →  %@", track.artist, track.title, cdnURL);
                [self->_playCache setObject:track forKey:key];
                if (cb) cb(track);
            }];
        }];
    }];
}

- (LendicSCTrack *)cachedForTitle:(NSString *)title artist:(NSString *)artist {
    return [_playCache objectForKey:[self cacheKey:title artist:artist]];
}

- (void)searchSC:(NSString *)query limit:(NSInteger)limit completion:(void(^)(NSArray<LendicSCTrack *> *))cb {
    NSString *key = [NSString stringWithFormat:@"search§%@", query.lowercaseString];
    NSArray *cached = [_searchCache objectForKey:key];
    if (cached) { if (cb) cb(cached); return; }

    [self ensureClientId:^(NSString *cid) {
        [self scSearchRaw:query limit:limit clientId:cid completion:^(NSArray<NSDictionary *> *col) {
            NSMutableArray *results = [NSMutableArray new];
            for (NSDictionary *t in col) {
                if (![t[@"streamable"] boolValue] || [t[@"policy"] isEqualToString:@"BLOCK"]) continue;
                LendicSCTrack *tr = [LendicSCTrack new];
                tr.scId    = [NSString stringWithFormat:@"%@", t[@"id"]];
                tr.title   = t[@"title"]  ?: @"";
                tr.artist  = t[@"user"][@"username"] ?: @"";
                tr.duration = [t[@"duration"] integerValue];
                NSString *art = t[@"artwork_url"];
                if (art) tr.artworkURL = [NSURL URLWithString:[art stringByReplacingOccurrencesOfString:@"-large" withString:@"-t500x500"]];
                long long fakeId = 9000000000LL + [tr.scId longLongValue];
                dispatch_async(self->_serial, ^{ self->_fakeIdMap[@(fakeId)] = tr.scId; });
                [results addObject:tr];
            }
            NSArray *final = [results copy];
            [self->_searchCache setObject:final forKey:key];
            if (cb) cb(final);
        }];
    }];
}

- (NSString *)scIdForFakeYandexId:(long long)fakeId {
    __block NSString *r;
    dispatch_sync(_serial, ^{ r = self->_fakeIdMap[@(fakeId)]; });
    return r;
}

- (void)registerScTrack:(LendicSCTrack *)t {
    long long fakeId = 9000000000LL + [t.scId longLongValue];
    dispatch_async(_serial, ^{ self->_fakeIdMap[@(fakeId)] = t.scId; });
    if (t.streamURL) [_playCache setObject:t forKey:[NSString stringWithFormat:@"scid§%@", t.scId]];
}

- (LendicSCTrack *)trackByScId:(NSString *)scId {
    return [_playCache objectForKey:[NSString stringWithFormat:@"scid§%@", scId]];
}

@end

// ═══════════════════════════════════════════════════════════════════════════
//  GLOBAL CACHES
// ═══════════════════════════════════════════════════════════════════════════

static NSMutableDictionary<NSString *, NSDictionary *> *gMeta;
static dispatch_queue_t gMetaQ;

static BOOL isYandex(NSURL *u) { return u.host && [u.host containsString:@"music.yandex"]; }
static BOOL isDlInfo(NSURL *u) { return isYandex(u) && [u.path containsString:@"download-info"]; }
static BOOL isSupp(NSURL *u)   { return isYandex(u) && ([u.path containsString:@"/tracks/"] || [u.path containsString:@"/track/"]); }
static BOOL isSearch(NSURL *u) { return isYandex(u) && [u.path containsString:@"/search"]; }

static NSString *yandexTrackId(NSURL *url) {
    NSString *p = url.path ?: @"";
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"/tracks?/(\\d+)" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:p options:0 range:NSMakeRange(0, p.length)];
    if (m && m.numberOfRanges > 1) return [p substringWithRange:[m rangeAtIndex:1]];
    return nil;
}

// ═══════════════════════════════════════════════════════════════════════════
//  NSURLPROTOCOL PROXY INTERCEPTOR
// ═══════════════════════════════════════════════════════════════════════════

static NSURLSession *gForwardingSession = nil;

@interface LendicURLProtocol : NSURLProtocol
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@end

@implementation LendicURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    if ([NSURLProtocol propertyForKey:@"LendicProxied" inRequest:request]) return NO;
    if (isSupp(url) || isDlInfo(url) || isSearch(url)) return YES;
    return NO;
}

+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    return [self canInitWithRequest:task.currentRequest];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newReq = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"LendicProxied" inRequest:newReq];

    if (!gForwardingSession) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        gForwardingSession = [NSURLSession sessionWithConfiguration:cfg];
    }

    self.dataTask = [gForwardingSession dataTaskWithRequest:newReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self.client URLProtocol:self didFailWithError:error];
            return;
        }
        [self processResponseWithData:data response:response];
    }];
    [self.dataTask resume];
}

- (void)stopLoading {
    [self.dataTask cancel];
}

- (void)finishWithData:(NSData *)data response:(NSURLResponse *)response statusCode:(NSInteger)code {
    NSHTTPURLResponse *orig = (NSHTTPURLResponse *)response;
    NSMutableDictionary *hdrs = [(orig.allHeaderFields ?: @{}) mutableCopy];
    [hdrs removeObjectForKey:@"Content-Length"]; // length might have changed
    
    NSHTTPURLResponse *newResp = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:code HTTPVersion:@"HTTP/1.1" headerFields:hdrs];
    
    [self.client URLProtocol:self didReceiveResponse:newResp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)processResponseWithData:(NSData *)data response:(NSURLResponse *)response {
    NSURL *url = self.request.URL;
    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
    NSInteger code = httpResp.statusCode;
    
    // 1. Supplement → Cache metadata
    if (isSupp(url)) {
        NSString *tid = yandexTrackId(url);
        if (tid && data) {
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSDictionary *td = nil;
            if ([obj isKindOfClass:[NSDictionary class]]) {
                id inner = obj[@"track"] ?: obj[@"result"];
                if ([inner isKindOfClass:[NSArray class]]) td = ((NSArray *)inner).firstObject;
                else if ([inner isKindOfClass:[NSDictionary class]]) td = inner;
                else td = obj;
            } else if ([obj isKindOfClass:[NSArray class]]) {
                td = ((NSArray *)obj).firstObject;
            }
            NSString *t = td[@"title"];
            NSString *a = ((NSArray *)td[@"artists"]).firstObject[@"name"] ?: @"";
            if (t.length) {
                dispatch_async(gMetaQ, ^{ gMeta[tid] = @{@"title":t, @"artist":a}; });
                LENDIC_LOG(@"Mapped #%@: %@ – %@", tid, a, t);
                [[LendicManager shared] resolveForTitle:t artist:a completion:nil]; // pre-warm
            }
        }
        [self finishWithData:data response:response statusCode:code];
        return;
    }
    
    // 2. Download Info → ALWAYS Replace with SC
    if (isDlInfo(url)) {
        NSString *tid = yandexTrackId(url);
        LendicManager *mgr = [LendicManager shared];
        long long numId = tid ? [tid longLongValue] : 0;
        NSString *scId  = (numId > 9000000000LL) ? [mgr scIdForFakeYandexId:numId] : nil;
        
        void(^inject)(LendicSCTrack *) = ^(LendicSCTrack *track) {
            NSData *fake = [NSJSONSerialization dataWithJSONObject:[track asYandexDownloadInfo] options:0 error:nil];
            [self finishWithData:fake response:response statusCode:200];
        };

        if (scId) {
            LENDIC_LOG(@"Injected Track Play: fakeID=%lld -> scId=%@", numId, scId);
            LendicSCTrack *cached = [mgr trackByScId:scId];
            if (cached) { inject(cached); return; }
            [mgr ensureClientId:^(NSString *cid) {
                NSString *apiURL = [NSString stringWithFormat:@"%@/tracks/%@?client_id=%@", SC_API, scId, cid];
                NSURLSessionDataTask *task = [mgr.session dataTaskWithURL:[NSURL URLWithString:apiURL] completionHandler:^(NSData *jd, NSURLResponse *jr, NSError *je) {
                    NSDictionary *t = [NSJSONSerialization JSONObjectWithData:jd options:0 error:nil];
                    NSString *pURL  = nil;
                    for (NSDictionary *tc in t[@"media"][@"transcodings"]) {
                        if ([tc[@"format"][@"protocol"] isEqualToString:@"progressive"]) { pURL = tc[@"url"]; break; }
                    }
                    if (!pURL) { [self finishWithData:data response:response statusCode:code]; return; }
                    [mgr resolveTranscoding:pURL clientId:cid completion:^(NSURL *cdnURL) {
                        if (!cdnURL) { [self finishWithData:data response:response statusCode:code]; return; }
                        LendicSCTrack *tr = [LendicSCTrack new];
                        tr.scId = scId; tr.streamURL = cdnURL; tr.title = t[@"title"] ?: @""; tr.artist = t[@"user"][@"username"] ?: @"";
                        [mgr registerScTrack:tr];
                        inject(tr);
                    }];
                }];
                [task resume];
            }];
            return;
        }

        // Real Yandex Track Fallback
        __block NSDictionary *meta = nil;
        dispatch_sync(gMetaQ, ^{ meta = tid ? gMeta[tid] : nil; });
        NSString *title  = meta[@"title"]  ?: @"";
        NSString *artist = meta[@"artist"] ?: @"";
        if (!title.length) {
            LENDIC_LOG(@"DlInfo: No meta for #%@ - leaving alone", tid);
            [self finishWithData:data response:response statusCode:code];
            return;
        }

        [mgr resolveForTitle:title artist:artist completion:^(LendicSCTrack *track) {
            if (track) {
                LENDIC_LOG(@"DlInfo: Replaced '%@' with SC URL", title);
                inject(track);
            } else {
                LENDIC_LOG(@"DlInfo: Failed to resolve SC for '%@', passthrough", title);
                [self finishWithData:data response:response statusCode:code];
            }
        }];
        return; // wait for async resolve
    }
    
    // 3. Search Info → Inject SC-only tracks
    if (isSearch(url) && data) {
        NSURLComponents *c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString *q = nil;
        for (NSURLQueryItem *qi in c.queryItems) { if ([qi.name isEqualToString:@"text"] || [qi.name isEqualToString:@"query"]) q = qi.value; }
        
        if (!q.length) { [self finishWithData:data response:response statusCode:code]; return; }
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) { [self finishWithData:data response:response statusCode:code]; return; }
        
        NSMutableSet *yaTitles = [NSMutableSet new];
        NSArray *yaResults = json[@"result"][@"tracks"][@"results"] ?: json[@"tracks"][@"results"] ?: json[@"result"][@"results"] ?: @[];
        for (NSDictionary *t in yaResults) {
            NSString *yt = [t[@"title"] lowercaseString];
            if (yt.length) [yaTitles addObject:yt];
        }
        
        [[LendicManager shared] searchSC:q limit:15 completion:^(NSArray<LendicSCTrack *> *scTracks) {
            NSMutableArray *novel = [NSMutableArray new];
            for (LendicSCTrack *t in scTracks) {
                BOOL dup = NO;
                for (NSString *ya in yaTitles) {
                    if ([ya containsString:t.title.lowercaseString] || [t.title.lowercaseString containsString:ya]) { dup = YES; break; }
                }
                if (!dup) [novel addObject:[t asYandexTrackDict]];
            }
            if (!novel.count) { [self finishWithData:data response:response statusCode:code]; return; }
            
            LENDIC_LOG(@"Search: +%lu novel SC tracks for '%@'", (unsigned long)novel.count, q);
            NSMutableDictionary *mutJson = [json mutableCopy];
            NSMutableDictionary *result = [[mutJson[@"result"] mutableCopy] ?: [NSMutableDictionary new] copy];
            NSMutableDictionary *tracks = [[result[@"tracks"] mutableCopy] ?: [NSMutableDictionary new] copy];
            NSMutableArray *results     = [[tracks[@"results"] mutableCopy] ?: [NSMutableArray new] copy];
            [results addObjectsFromArray:novel];
            tracks[@"results"]  = results;
            result[@"tracks"]   = tracks;
            mutJson[@"result"]  = result;
            
            NSData *newData = [NSJSONSerialization dataWithJSONObject:mutJson options:0 error:nil];
            [self finishWithData:newData response:response statusCode:code];
        }];
        return; // wait for async search
    }

    // Default passthrough
    [self finishWithData:data response:response statusCode:code];
}

@end

// ═══════════════════════════════════════════════════════════════════════════
//  NSURLSessionConfiguration Swizzling (Alamofire/AFNetworking support)
// ═══════════════════════════════════════════════════════════════════════════

static IMP gOrigDefaultConfig;
static NSURLSessionConfiguration *lendic_defaultSessionConfiguration(id self, SEL _cmd) {
    NSURLSessionConfiguration *config = ((NSURLSessionConfiguration*(*)(id,SEL))gOrigDefaultConfig)(self, _cmd);
    NSMutableArray *protocols = [config.protocolClasses mutableCopy] ?: [NSMutableArray new];
    [protocols insertObject:[LendicURLProtocol class] atIndex:0];
    config.protocolClasses = protocols;
    return config;
}

static IMP gOrigEphemeralConfig;
static NSURLSessionConfiguration *lendic_ephemeralSessionConfiguration(id self, SEL _cmd) {
    NSURLSessionConfiguration *config = ((NSURLSessionConfiguration*(*)(id,SEL))gOrigEphemeralConfig)(self, _cmd);
    NSMutableArray *protocols = [config.protocolClasses mutableCopy] ?: [NSMutableArray new];
    [protocols insertObject:[LendicURLProtocol class] atIndex:0];
    config.protocolClasses = protocols;
    return config;
}

__attribute__((constructor))
static void LendicSetup(void) {
    gMeta  = [NSMutableDictionary new];
    gMetaQ = dispatch_queue_create("lendic.meta", DISPATCH_QUEUE_SERIAL);

    // 1. Register for [NSURLSession sharedSession]
    [NSURLProtocol registerClass:[LendicURLProtocol class]];

    // 2. Swizzle configurations for custom sessions (like Alamofire)
    Class cls = NSClassFromString(@"NSURLSessionConfiguration");
    Method m1 = class_getClassMethod(cls, @selector(defaultSessionConfiguration));
    if (m1) {
        gOrigDefaultConfig = method_getImplementation(m1);
        method_setImplementation(m1, (IMP)lendic_defaultSessionConfiguration);
    }
    Method m2 = class_getClassMethod(cls, @selector(ephemeralSessionConfiguration));
    if (m2) {
        gOrigEphemeralConfig = method_getImplementation(m2);
        method_setImplementation(m2, (IMP)lendic_ephemeralSessionConfiguration);
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[LendicManager shared] ensureClientId:^(NSString *cid) {
            LENDIC_LOG(@"🟢 LendicTweak v3 (NSURLProtocol) Ready — client_id: %@", cid);
        }];
    });
}
