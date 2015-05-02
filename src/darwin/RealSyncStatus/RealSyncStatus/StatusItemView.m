//
//  StatusItemView.h
//  RealSyncStatus
//
//  Created by Dmitry Krivomazov on 08.06.14.
//

#import "StatusItemView.h"

@implementation StatusItemView

@synthesize statusItem = _statusItem;
@synthesize image = _image;

int realsyncTerminalWindowPid = 0;

- (id)initWithStatusItem:(NSStatusItem *)statusItem
{
    CGFloat itemWidth = [statusItem length];
    CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
    NSRect itemRect = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
    self = [super initWithFrame:itemRect];
    
    if (self != nil) {
        _statusItem = statusItem;
        _statusItem.view = self;
        
        realsyncTerminalWindowPid = [[[NSUserDefaults standardUserDefaults] valueForKey:@"terminalpid"] intValue];
        
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(onNotify:)
                                                                name:@"RealSync.notification.windowPid"
                                                              object:nil
                                                  suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    }
    return self;
}

- (void)onNotify:(NSNotification *)note
{
    NSString *object = [note object];
    realsyncTerminalWindowPid = [object intValue];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[self.statusItem drawStatusBarBackgroundInRect:dirtyRect withHighlight:false];
    
    NSImage *icon = self.image;
    NSSize iconSize = [icon size];
    NSRect bounds = self.bounds;
    CGFloat iconX = roundf((NSWidth(bounds) - iconSize.width) / 2);
    CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
    NSPoint iconPoint = NSMakePoint(iconX, iconY);

	[icon drawAtPoint:iconPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

- (void)setImage:(NSImage *)newImage
{
    if (_image != newImage) {
        _image = newImage;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    if (realsyncTerminalWindowPid == 0) {
        return;
    }
    
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:realsyncTerminalWindowPid];
    
    if (app.hidden) {
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        [app unhide];
    } else {
        [app hide];
    }
}

@end
