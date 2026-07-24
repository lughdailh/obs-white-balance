#include "calibration-math.hpp"
#include <cassert>
#include <cmath>
#include <cstdint>
#include <vector>

static bool near(double a, double b) { return std::abs(a - b) < 0.01; }
int main() {
  auto direct = white_balance::calibrateRgb(
      {100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0});
  assert(direct.gains.red > direct.gains.green);
  assert(direct.gains.green > direct.gains.blue);
  assert(near(direct.sample.red * direct.gains.red,
              direct.sample.blue * direct.gains.blue));

  std::vector<std::uint8_t> neutral(4 * 4 * 4);
  for (std::size_t i = 0; i < neutral.size(); i += 4) {
    neutral[i] = neutral[i + 1] = neutral[i + 2] = 128;
    neutral[i + 3] = 255;
  }
  auto result =
      white_balance::calibrateBgraRegion(neutral.data(), 4, 4, 16, 0.5, 0.5, 2);
  assert(near(result.gains.red, 1));
  assert(near(result.gains.green, 1));
  assert(near(result.gains.blue, 1));

  std::vector<std::uint8_t> blue(3 * 3 * 4, 255);
  for (std::size_t i = 0; i < blue.size(); i += 4) {
    blue[i] = 200;
    blue[i + 1] = 150;
    blue[i + 2] = 100;
  }
  result =
      white_balance::calibrateBgraRegion(blue.data(), 3, 3, 12, 0.5, 0.5, 1);
  assert(result.gains.red > result.gains.green);
  assert(result.gains.green > result.gains.blue);
  assert(near(result.sample.red * result.gains.red,
              result.sample.blue * result.gains.blue));
}
