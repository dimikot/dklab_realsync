//
//  AppDelegate.m
//  RealSyncStatus
//
//  Created by Dmitry Krivomazov on 08.06.14.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    processesNumber = 1;
    
    // Install status item into the menu bar
    NSStatusItem *statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:28.0];
    self.statusItemView = [[StatusItemView alloc] initWithStatusItem:statusItem];
    self.statusItemView.image = [NSImage imageNamed:@"Status"];

    // Add observer for notifications from perl script
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(onNotify:)
                                                            name:@"RealSync.notification.statusChanged"
                                                          object:nil
                                              suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}

- (void) onNotify:(NSNotification *)note
{
    NSString *object = [note object];
    
    if ([object isEqual: @"rsync"] || [object isEqual: @"transfer"]) {
        self.statusItemView.image = [NSImage imageNamed:@"StatusHighlighted"];
    } else if ([object isEqual: @"exit"]) {
        if (--processesNumber <= 0) {
            [[NSApplication sharedApplication] terminate:nil];
        }
    } else if ([object isEqual: @"started"]) {
        processesNumber++;
    } else {
        self.statusItemView.image = [NSImage imageNamed:@"Status"];
    }
}

@end
