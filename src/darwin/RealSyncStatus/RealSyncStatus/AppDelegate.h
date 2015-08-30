//
//  AppDelegate.h
//  RealSyncStatus
//
//  Created by Dmitry Krivomazov on 08.06.14.
//

#import <Cocoa/Cocoa.h>
#import "StatusItemView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    @private int processesNumber;
}

@property (nonatomic, strong) StatusItemView *statusItemView;

@end
