#pragma once
#include "calibration-math.hpp"
#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace white_balance {
struct Snapshot {
  std::vector<std::uint8_t> bgra;
  std::size_t width;
  std::size_t height;
  std::size_t stride;
};
std::optional<Calibration> showCalibrationDialog(const Snapshot &snapshot,
                                                 std::size_t sampleRadius);
}  // namespace white_balance
