#pragma once
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

// ─────────────────────────────────────────────────────────────────
//  LendicTweak v2 — ALWAYS-SC + SEARCH INJECTION
//  Standalone: no backend, hits SoundCloud directly from device
//
//  Modes:
//    1. ALWAYS-SC audio  — replaces ALL Yandex download-info URLs
//       with SoundCloud CDN URLs (fixes broken/unavailable tracks)
//    2. Search injection — hooks Yandex search responses and adds
//       SC-only tracks not present in the Yandex catalog
// ─────────────────────────────────────────────────────────────────

#define SC_API        @"https://api-v2.soundcloud.com"
#define SC_WEB        @"https://soundcloud.com"
#define DEEZER_API    @"https://api.deezer.com"

#define LENDIC_LOG(fmt, ...) NSLog(@"[LendicTweak] " fmt, ##__VA_ARGS__)

NS_ASSUME_NONNULL_BEGIN

// A resolved SC track with a direct playable URL
@interface LendicSCTrack : NSObject
@property (nonatomic, copy)   NSString *scId;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *artist;
@property (nonatomic, strong) NSURL    *streamURL;   // signed CDN URL, ~30min TTL
@property (nonatomic, strong) NSURL    *artworkURL;
@property (nonatomic, assign) NSInteger duration;    // milliseconds

// Convert to a Yandex-compatible download-info array entry
- (NSArray<NSDictionary *> *)asYandexDownloadInfo;

// Convert to a minimal fake Yandex track dict for search injection
- (NSDictionary *)asYandexTrackDict;
@end

// Core manager — client_id, search, resolve, cache
@interface LendicManager : NSObject
+ (instancetype)shared;

// Resolve: search SC for title+artist, return direct CDN stream URL
- (void)resolveForTitle:(NSString *)title
                 artist:(NSString *)artist
             completion:(void(^)(LendicSCTrack * _Nullable))completion;

// Cached resolved track (sync, may return nil)
- (LendicSCTrack *)cachedForTitle:(NSString *)title artist:(NSString *)artist;

// SC search: returns up to `limit` streamable SC tracks for a raw query
// Used for search injection (not for playback resolution)
- (void)searchSC:(NSString *)query
           limit:(NSInteger)limit
      completion:(void(^)(NSArray<LendicSCTrack *> *))completion;

// Ensure client_id is valid (refresh if needed)
- (void)ensureClientId:(void(^)(NSString *))completion;
@end

NS_ASSUME_NONNULL_END
