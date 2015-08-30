//
//  StatusItemView.m
//  RealSyncStatus
//
//  Created by Dmitry Krivomazov on 08.06.14.
//

@interface StatusItemView : NSView {
@private
    NSImage *_image;
    NSStatusItem *_statusItem;
}

- (id)initWithStatusItem:(NSStatusItem *)statusItem;

- (void)setImage:(NSImage *)newImage;

@property (nonatomic, strong, readonly) NSStatusItem *statusItem;
@property (nonatomic, strong) NSImage *image;

@end
