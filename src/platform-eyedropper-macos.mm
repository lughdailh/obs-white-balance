#import <AppKit/AppKit.h>

#include "platform-eyedropper.hpp"

namespace white_balance {

bool showEyedropper(void *context, SampleCallback callback) {
  NSColorSampler *sampler = [[NSColorSampler alloc] init];
  [sampler showSamplerWithSelectionHandler:^(NSColor *selectedColor) {
    (void)sampler;
    SampledColor sample;
    if (selectedColor) {
      NSColor *srgb =
          [selectedColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
      CGFloat red = 0.0;
      CGFloat green = 0.0;
      CGFloat blue = 0.0;
      CGFloat alpha = 0.0;
      [srgb getRed:&red green:&green blue:&blue alpha:&alpha];
      sample = {true, static_cast<double>(red), static_cast<double>(green),
                static_cast<double>(blue)};
    }
    callback(context, sample);
  }];
  return true;
}

void showAlert(const char *message) {
  NSAlert *box = [[NSAlert alloc] init];
  box.messageText = @"White Balance";
  box.informativeText = [NSString stringWithUTF8String:message];
  [box runModal];
}

void shutdownEyedropper() {}

} // namespace white_balance
