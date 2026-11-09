// Now Playing bridge.
//
// Since macOS 15.4 only Apple-signed processes may read the system "Now Playing" information (MediaRemote).
// /usr/bin/perl is Apple-signed and can load third-party libraries, so Islet runs:
//     /usr/bin/perl mediaremote.pl libIsletMediaRemote.dylib islet_stream
// The perl script calls islet_stream(), which never returns: it prints one JSON object per line whenever
// what's playing changes, and reads commands ("toggle", "next", "prev", "seek 42.5") from stdin.
// When stdin closes (Islet quit), the process exits.

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <pthread.h>

typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetPlayingFn)(dispatch_queue_t, void (^)(BOOL));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef NSString *(*MRClientStringFn)(id);
typedef BOOL (*MRSendFn)(unsigned int, NSDictionary *);
typedef void (*MRSetElapsedFn)(double);

static MRRegisterFn fRegister;
static MRGetInfoFn fGetInfo;
static MRGetPlayingFn fGetPlaying;
static MRGetClientFn fGetClient;
static MRClientStringFn fClientBundle;
static MRClientStringFn fClientParent;
static MRSendFn fSend;
static MRSetElapsedFn fSetElapsed;

static NSString *gLastArt = nil;
static BOOL gPending = NO;

static void emit(NSDictionary *d) {
    NSData *j = [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
    if (!j) return;
    fwrite(j.bytes, 1, j.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void put(NSMutableDictionary *o, NSString *key, id value, Class cls) {
    if (value && [value isKindOfClass:cls]) o[key] = value;
}

static void refresh(void) {
    gPending = NO;
    dispatch_queue_t q = dispatch_get_main_queue();
    fGetInfo(q, ^(NSDictionary *info) {
        fGetPlaying(q, ^(BOOL playing) {
            void (^finish)(NSString *, NSString *) = ^(NSString *bundle, NSString *parent) {
                NSMutableDictionary *o = [NSMutableDictionary dictionary];
                o[@"playing"] = @(playing);
                put(o, @"title", info[@"kMRMediaRemoteNowPlayingInfoTitle"], NSString.class);
                put(o, @"artist", info[@"kMRMediaRemoteNowPlayingInfoArtist"], NSString.class);
                put(o, @"album", info[@"kMRMediaRemoteNowPlayingInfoAlbum"], NSString.class);
                put(o, @"duration", info[@"kMRMediaRemoteNowPlayingInfoDuration"], NSNumber.class);
                put(o, @"elapsed", info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"], NSNumber.class);
                put(o, @"rate", info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"], NSNumber.class);
                id ts = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                if ([ts isKindOfClass:NSDate.class]) o[@"timestamp"] = @([(NSDate *)ts timeIntervalSince1970]);
                if (bundle) o[@"bundle"] = bundle;
                if (parent) o[@"parent"] = parent;
                id art = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                if ([art isKindOfClass:NSData.class] && [(NSData *)art length] > 0) {
                    NSData *a = art;
                    NSString *h = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)a.length, (unsigned long)a.hash];
                    o[@"artId"] = h;
                    if (![h isEqualToString:gLastArt]) {
                        gLastArt = h;
                        o[@"art"] = [a base64EncodedStringWithOptions:0];
                    }
                }
                emit(o);
            };
            if (fGetClient && fClientBundle) {
                fGetClient(q, ^(id client) {
                    NSString *b = client ? fClientBundle(client) : nil;
                    NSString *p = (client && fClientParent) ? fClientParent(client) : nil;
                    finish([b isKindOfClass:NSString.class] ? b : nil, [p isKindOfClass:NSString.class] ? p : nil);
                });
            } else {
                finish(nil, nil);
            }
        });
    });
}

static void schedule(void) {
    if (gPending) return;
    gPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ refresh(); });
}

static void *readCommands(void *arg) {
    (void)arg;
    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        NSString *s = [[NSString stringWithUTF8String:line] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!s.length) continue;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([s isEqualToString:@"toggle"]) fSend(2, nil);
            else if ([s isEqualToString:@"play"]) fSend(0, nil);
            else if ([s isEqualToString:@"pause"]) fSend(1, nil);
            else if ([s isEqualToString:@"next"]) fSend(4, nil);
            else if ([s isEqualToString:@"prev"]) fSend(5, nil);
            else if ([s hasPrefix:@"seek "] && fSetElapsed) fSetElapsed([[s substringFromIndex:5] doubleValue]);
            else if ([s isEqualToString:@"get"]) refresh();
            schedule();
        });
    }
    exit(0);   // Islet went away
    return NULL;
}

__attribute__((visibility("default"))) void islet_stream(void *perl, void *cv) {
    (void)perl; (void)cv;
    @autoreleasepool {
        void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
        if (!h) { emit(@{@"error": @"MediaRemote missing"}); exit(2); }
        fRegister = (MRRegisterFn)dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
        fGetInfo = (MRGetInfoFn)dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
        fGetPlaying = (MRGetPlayingFn)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        fGetClient = (MRGetClientFn)dlsym(h, "MRMediaRemoteGetNowPlayingClient");
        fClientBundle = (MRClientStringFn)dlsym(h, "MRNowPlayingClientGetBundleIdentifier");
        fClientParent = (MRClientStringFn)dlsym(h, "MRNowPlayingClientGetParentAppBundleIdentifier");
        fSend = (MRSendFn)dlsym(h, "MRMediaRemoteSendCommand");
        fSetElapsed = (MRSetElapsedFn)dlsym(h, "MRMediaRemoteSetElapsedTime");
        if (!fRegister || !fGetInfo || !fGetPlaying || !fSend) { emit(@{@"error": @"MediaRemote symbols"}); exit(3); }

        fRegister(dispatch_get_main_queue());
        for (NSString *n in @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                              @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                              @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
                              @"kMRMediaRemoteNowPlayingApplicationClientStateDidChange"]) {
            [[NSNotificationCenter defaultCenter] addObserverForName:n object:nil queue:NSOperationQueue.mainQueue
                                                          usingBlock:^(NSNotification *note) { (void)note; schedule(); }];
        }
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(t, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), 4 * NSEC_PER_SEC, NSEC_PER_SEC / 2);
        dispatch_source_set_event_handler(t, ^{ schedule(); });
        dispatch_resume(t);

        pthread_t th;
        pthread_create(&th, NULL, readCommands, NULL);
        pthread_detach(th);

        emit(@{@"hello": @1});
        refresh();
        CFRunLoopRun();
    }
}
