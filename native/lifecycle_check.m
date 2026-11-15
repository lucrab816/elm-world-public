#import "cozy_lifecycle.m"
static NSUInteger passed=0, failed=0, originalQuitCalls=0;
static void check(BOOL result, NSString *name) {
    if(result) passed++; else { failed++; NSLog(@"FAILED: %@",name); }
}
static void pump(void) { [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]; }
@interface TestOriginalDelegate : NSObject <NSApplicationDelegate>
@end
@implementation TestOriginalDelegate
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender { originalQuitCalls++; return NSTerminateNow; }
@end
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        TestOriginalDelegate *original=[TestOriginalDelegate new];
        NSApp.delegate=original;
        initialize(NULL,COZY_SCENE);
        pump();
        check(enabled && NSApp.delegate==proxy,@"Delegate installed");
        check(activity!=nil,@"Background activity registered without forbidding system sleep");
        NSDictionary *state=readJSON(statePath);
        check([state[@"pid"] intValue]==getpid(),@"Published state belongs to this process");
        [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NSWorkspaceWillSleepNotification object:nil];
        pump();
        check([readJSON(statePath)[@"sleeping"] boolValue],@"WillSleep freezes simulation flag");
        [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NSWorkspaceDidWakeNotification object:nil];
        pump();
        state=readJSON(statePath);
        check(![state[@"sleeping"] boolValue] && [state[@"wake_sequence"] intValue]==1,@"DidWake increments sequence");
        check([proxy applicationShouldTerminate:NSApp]==NSTerminateCancel,@"Quit waits for game save");
        check([readJSON(statePath)[@"quit_sequence"] intValue]==1 && originalQuitCalls==0,@"Quit forwarded as a request, not a close");
        NSData *ack=[NSJSONSerialization dataWithJSONObject:@{@"pid":@(getpid()),@"allow_quit":@YES} options:0 error:nil];
        [ack writeToFile:ackPath atomically:YES];
        check([proxy applicationShouldTerminate:NSApp]==NSTerminateNow && originalQuitCalls==1,@"Acknowledged save allows normal engine termination");
        deinitialize(NULL,COZY_SCENE);
        check(NSApp.delegate==original,@"Original delegate restored on cleanup");
        check(![NSFileManager.defaultManager fileExistsAtPath:statePath],@"Lifecycle flags cleaned on exit");
        printf("NATIVE_LIFECYCLE_CHECK passed=%lu failed=%lu\n",(unsigned long)passed,(unsigned long)failed);
        return failed?1:0;
    }
}
