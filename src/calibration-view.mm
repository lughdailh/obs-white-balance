#import <AppKit/AppKit.h>
#include "calibration-view.hpp"
#include <algorithm>

@interface WBImageView : NSView
@property(nonatomic, strong) NSImage *image;
@property(nonatomic) NSPoint selection;
@property(nonatomic) BOOL hasSelection;
@end

@implementation WBImageView
- (BOOL)isFlipped { return YES; }
- (NSRect)imageRect {
  NSSize size = self.image.size;
  CGFloat scale = std::min(NSWidth(self.bounds) / size.width,
                           NSHeight(self.bounds) / size.height);
  NSSize draw = NSMakeSize(size.width * scale, size.height * scale);
  return NSMakeRect((NSWidth(self.bounds) - draw.width) / 2,
                    (NSHeight(self.bounds) - draw.height) / 2, draw.width,
                    draw.height);
}
- (void)drawRect:(NSRect)dirty {
  (void)dirty;
  [[NSColor blackColor] setFill];
  NSRectFill(self.bounds);
  [self.image drawInRect:[self imageRect]
                fromRect:NSZeroRect
               operation:NSCompositingOperationCopy
                fraction:1.0];
  if (self.hasSelection) {
    [[NSColor whiteColor] setStroke];
    NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(
                                                        self.selection.x - 9,
                                                        self.selection.y - 9,
                                                        18, 18)];
    outer.lineWidth = 3;
    [outer stroke];
    [[NSColor systemRedColor] setStroke];
    NSBezierPath *inner = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(
                                                        self.selection.x - 8,
                                                        self.selection.y - 8,
                                                        16, 16)];
    inner.lineWidth = 1.5;
    [inner stroke];
  }
}
- (void)mouseDown:(NSEvent *)event {
  self.selection = [self convertPoint:event.locationInWindow fromView:nil];
  self.hasSelection = YES;
  [self setNeedsDisplay:YES];
}
@end

namespace white_balance {
std::optional<Calibration> showCalibrationDialog(const Snapshot &snapshot,
                                                 std::size_t radius) {
  @autoreleasepool {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:nullptr
                      pixelsWide:static_cast<NSInteger>(snapshot.width)
                      pixelsHigh:static_cast<NSInteger>(snapshot.height)
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                    bitmapFormat:NSBitmapFormatAlphaFirst
                     bytesPerRow:static_cast<NSInteger>(snapshot.stride)
                    bitsPerPixel:32];
    if (!bitmap)
      return std::nullopt;
    std::copy(snapshot.bgra.begin(), snapshot.bgra.end(), bitmap.bitmapData);
    NSImage *image =
        [[NSImage alloc] initWithSize:NSMakeSize(snapshot.width, snapshot.height)];
    [image addRepresentation:bitmap];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"White Balance";
    alert.informativeText =
        @"Click a neutral white or grey area. This frozen reference is only "
         "analysed once.";
    [alert addButtonWithTitle:@"Calibrate"];
    [alert addButtonWithTitle:@"Cancel"];
    WBImageView *view =
        [[WBImageView alloc] initWithFrame:NSMakeRect(0, 0, 720, 405)];
    view.image = image;
    alert.accessoryView = view;

    while (true) {
      if ([alert runModal] != NSAlertFirstButtonReturn)
        return std::nullopt;
      NSRect rect = [view imageRect];
      if (!view.hasSelection || !NSPointInRect(view.selection, rect)) {
        alert.informativeText =
            @"Click inside the white or grey reference before calibrating.";
        continue;
      }
      double x = (view.selection.x - NSMinX(rect)) / NSWidth(rect);
      double y = (view.selection.y - NSMinY(rect)) / NSHeight(rect);
      return calibrateBgraRegion(snapshot.bgra.data(), snapshot.width,
                                 snapshot.height, snapshot.stride, x, y,
                                 radius);
    }
  }
}
}  // namespace white_balance
