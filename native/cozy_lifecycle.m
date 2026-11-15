// Minimal Godot GDExtension entry ABI; no engine functions or third-party runtime needed.
#import <Cocoa/Cocoa.h>
#include <stdint.h>
#include <unistd.h>
typedef enum { COZY_CORE, COZY_SERVERS, COZY_SCENE, COZY_EDITOR } CozyLevel;
typedef struct { CozyLevel minimum_initialization_level; void *userdata;
    void (*initialize)(void *, CozyLevel); void (*deinitialize)(void *, CozyLevel); } CozyInitialization;
typedef void (*CozyFunction)(void);
typedef CozyFunction (*CozyGetProcAddress)(const char *);

static id originalDelegate, activity;
static NSTimer *timer;
static NSMutableArray *observers;
static NSString *directory, *statePath, *commandPath, *ackPath;
static BOOL sleeping = NO;
static NSUInteger wakeSequence = 0, quitSequence = 0;
static NSDictionary *lastPublished;
static BOOL enabled = NO;

static NSWindow *gameWindow(void) {
    for (NSWindow *window in NSApp.windows) {
        if ((window.styleMask & NSWindowStyleMaskTitled) && window.canBecomeMainWindow) return window;
    }
    return NSApp.mainWindow;
}
static void publish(void) {
    NSWindow *window = gameWindow();
    NSDictionary *state = @{ @"pid":@(getpid()), @"sleeping":@(sleeping),
        @"wake_sequence":@(wakeSequence), @"quit_sequence":@(quitSequence),
        @"background":@(NSApp.hidden || !window || window.miniaturized || !window.visible) };
    if ([state isEqual:lastPublished]) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    if ([data writeToFile:statePath options:NSDataWritingAtomic error:nil]) lastPublished = state;
}
static NSDictionary *readJSON(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || data.length > 8192) return nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
static void showWorld(void) {
    [NSApp unhide:nil];
    NSWindow *window = gameWindow();
    if (window.miniaturized) [window deminiaturize:nil];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    publish();
}
@interface CozyLifecycleDelegate : NSObject <NSApplicationDelegate>
@end
@implementation CozyLifecycleDelegate
- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [originalDelegate respondsToSelector:selector];
}
- (id)forwardingTargetForSelector:(SEL)selector { return originalDelegate; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    NSDictionary *ack = readJSON(ackPath);
    if ([ack[@"pid"] intValue] == getpid() && [ack[@"allow_quit"] boolValue]) {
        if ([originalDelegate respondsToSelector:_cmd]) return [originalDelegate applicationShouldTerminate:sender];
        return NSTerminateNow;
    }
    quitSequence++;
    publish(); // Godot saves first, then acknowledges an explicit quit.
    return NSTerminateCancel;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    showWorld();
    return NO;
}
@end
static CozyLifecycleDelegate *proxy;
static void observe(NSNotificationCenter *center, NSNotificationName name, void (^handler)(NSNotification *)) {
    id observer = [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:handler];
    [observers addObject:@[center, observer]];
}
static void initialize(void *userdata, CozyLevel level) {
    if (level != COZY_SCENE) return;
    for (NSString *argument in NSProcessInfo.processInfo.arguments) {
        if ([argument hasSuffix:@"-test"]) return; // Tests never touch a real user's lifecycle state.
    }
    if (!NSApp) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *testRoot = NSProcessInfo.processInfo.environment[@"COZY_LIFECYCLE_TEST_ROOT"];
        directory = testRoot.length ? testRoot : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Godot/app_userdata/温馨小世界"];
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        statePath = [directory stringByAppendingPathComponent:@"lifecycle.json"];
        commandPath = [directory stringByAppendingPathComponent:@"lifecycle-command.json"];
        ackPath = [directory stringByAppendingPathComponent:@"lifecycle-quit.json"];
        originalDelegate = NSApp.delegate;
        proxy = [CozyLifecycleDelegate new];
        NSApp.delegate = proxy;
        enabled = YES;
        observers = [NSMutableArray new];
        observe(NSWorkspace.sharedWorkspace.notificationCenter, NSWorkspaceWillSleepNotification, ^(NSNotification *n){ sleeping=YES; publish(); });
        observe(NSWorkspace.sharedWorkspace.notificationCenter, NSWorkspaceDidWakeNotification, ^(NSNotification *n){ sleeping=NO; wakeSequence++; publish(); });
        for (NSString *name in @[NSApplicationDidHideNotification, NSApplicationDidUnhideNotification,
                NSWindowDidMiniaturizeNotification, NSWindowDidDeminiaturizeNotification]) {
            observe(NSNotificationCenter.defaultCenter, name, ^(NSNotification *n){ publish(); });
        }
        activity = [NSProcessInfo.processInfo beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep reason:@"Keep the user-requested village simulation running while its window is hidden"];
        timer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t){
            NSDictionary *command = readJSON(commandPath);
            if ([command[@"pid"] intValue] == getpid()) {
                [NSFileManager.defaultManager removeItemAtPath:commandPath error:nil];
                if ([command[@"action"] isEqual:@"hide"]) [NSApp hide:nil];
                if ([command[@"action"] isEqual:@"show"]) showWorld();
            }
            publish();
        }];
        publish();
    });
}
static void deinitialize(void *userdata, CozyLevel level) {
    if (level != COZY_SCENE || !enabled) return;
    [timer invalidate];
    for (NSArray *entry in observers) [entry[0] removeObserver:entry[1]];
    if (NSApp.delegate == proxy) NSApp.delegate = originalDelegate;
    if (activity) [NSProcessInfo.processInfo endActivity:activity];
    // Files contain only process lifecycle flags, never credentials or character memories.
    for (NSString *path in @[statePath, commandPath, ackPath]) {
        if ([readJSON(path)[@"pid"] intValue] == getpid()) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
    enabled = NO;
}
__attribute__((visibility("default"))) uint8_t cozy_lifecycle_init(CozyGetProcAddress getProc, void *library, CozyInitialization *init) {
    init->minimum_initialization_level = COZY_SCENE;
    init->userdata = NULL;
    init->initialize = initialize;
    init->deinitialize = deinitialize;
    return 1;
}
