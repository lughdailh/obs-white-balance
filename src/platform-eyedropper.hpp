#pragma once

namespace white_balance {

struct SampledColor {
  bool selected = false;
  double red = 0.0;
  double green = 0.0;
  double blue = 0.0;
};

using SampleCallback = void (*)(void *context, const SampledColor &color);

bool showEyedropper(void *context, SampleCallback callback);
void showAlert(const char *message);
void shutdownEyedropper();

} // namespace white_balance
