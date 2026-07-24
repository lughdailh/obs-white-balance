#include "calibration-math.hpp"
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace white_balance {
Calibration calibrateRgb(Rgb sample) {
  sample.red = std::clamp(sample.red, 0.0, 1.0);
  sample.green = std::clamp(sample.green, 0.0, 1.0);
  sample.blue = std::clamp(sample.blue, 0.0, 1.0);
  const double floor = 1.0 / 255.0;
  const double neutral =
      std::max(floor, (sample.red + sample.green + sample.blue) / 3.0);
  const Rgb gains{
      std::clamp(neutral / std::max(sample.red, floor), 0.25, 4.0),
      std::clamp(neutral / std::max(sample.green, floor), 0.25, 4.0),
      std::clamp(neutral / std::max(sample.blue, floor), 0.25, 4.0)};
  const double luma =
      0.2126 * sample.red + 0.7152 * sample.green + 0.0722 * sample.blue;
  return {sample, gains, luma < 0.12,
          std::max({sample.red, sample.green, sample.blue}) > 0.97};
}

Calibration calibrateBgraRegion(const std::uint8_t *pixels, std::size_t width,
                                std::size_t height, std::size_t stride,
                                double normalizedX, double normalizedY,
                                std::size_t radius) {
  if (!pixels || !width || !height || stride < width * 4)
    throw std::invalid_argument("Invalid BGRA image");
  normalizedX = std::clamp(normalizedX, 0.0, 1.0);
  normalizedY = std::clamp(normalizedY, 0.0, 1.0);
  const auto cx = static_cast<std::size_t>(
      std::llround(normalizedX * static_cast<double>(width - 1)));
  const auto cy = static_cast<std::size_t>(
      std::llround(normalizedY * static_cast<double>(height - 1)));
  const auto minX = cx > radius ? cx - radius : 0;
  const auto minY = cy > radius ? cy - radius : 0;
  const auto maxX = std::min(width - 1, cx + radius);
  const auto maxY = std::min(height - 1, cy + radius);
  double r = 0, g = 0, b = 0;
  std::size_t count = 0;
  for (std::size_t y = minY; y <= maxY; ++y) {
    const auto *row = pixels + y * stride;
    for (std::size_t x = minX; x <= maxX; ++x) {
      const auto *p = row + x * 4;
      b += p[0];
      g += p[1];
      r += p[2];
      ++count;
    }
  }
  return calibrateRgb(
      {r / count / 255.0, g / count / 255.0, b / count / 255.0});
}

std::string formatCalibration(const Calibration &c) {
  std::ostringstream out;
  out << std::fixed << std::setprecision(3) << "RGB " << c.sample.red << ", "
      << c.sample.green << ", " << c.sample.blue << " → gains " << c.gains.red
      << ", " << c.gains.green << ", " << c.gains.blue;
  return out.str();
}
}  // namespace white_balance
