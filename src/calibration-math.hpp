#pragma once
#include <cstddef>
#include <cstdint>
#include <string>

namespace white_balance {
struct Rgb {
  double red;
  double green;
  double blue;
};
struct Calibration {
  Rgb sample;
  Rgb gains;
  bool tooDark;
  bool nearClipping;
};
Calibration calibrateBgraRegion(const std::uint8_t *pixels, std::size_t width,
                                std::size_t height, std::size_t stride,
                                double normalizedX, double normalizedY,
                                std::size_t radius);
std::string formatCalibration(const Calibration &calibration);
}  // namespace white_balance
