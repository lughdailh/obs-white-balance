#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <obs-module.h>

#include <atomic>
#include <chrono>
#include <mutex>
#include <thread>

#include "platform-eyedropper.hpp"

namespace white_balance {
namespace {

struct Completion {
  void *context;
  SampleCallback callback;
  SampledColor color;
};

std::atomic_bool sampling{false};
std::atomic_bool stopping{false};
std::mutex workerMutex;
std::thread worker;

void completeOnObsThread(void *data) {
  auto *completion = static_cast<Completion *>(data);
  completion->callback(completion->context, completion->color);
  delete completion;
}

bool buttonIsDown(int key) { return (GetAsyncKeyState(key) & 0x8000) != 0; }

void sampleNextClick(void *context, SampleCallback callback) {
  using namespace std::chrono_literals;

  while (!stopping && buttonIsDown(VK_LBUTTON))
    std::this_thread::sleep_for(10ms);

  SampledColor color;
  while (!stopping) {
    SetCursor(LoadCursor(nullptr, IDC_CROSS));
    if (buttonIsDown(VK_ESCAPE))
      break;
    if (buttonIsDown(VK_LBUTTON)) {
      POINT point{};
      if (GetCursorPos(&point)) {
        HDC screen = GetDC(nullptr);
        const COLORREF pixel =
            screen ? GetPixel(screen, point.x, point.y) : CLR_INVALID;
        if (screen)
          ReleaseDC(nullptr, screen);
        if (pixel != CLR_INVALID) {
          color = {true, GetRValue(pixel) / 255.0, GetGValue(pixel) / 255.0,
                   GetBValue(pixel) / 255.0};
        }
      }
      break;
    }
    std::this_thread::sleep_for(10ms);
  }

  if (!stopping) {
    auto *completion = new Completion{context, callback, color};
    obs_queue_task(OBS_TASK_UI, completeOnObsThread, completion, true);
  }
  sampling = false;
}

} // namespace

bool showEyedropper(void *context, SampleCallback callback) {
  bool expected = false;
  if (!sampling.compare_exchange_strong(expected, true))
    return false;

  std::lock_guard<std::mutex> lock(workerMutex);
  if (worker.joinable())
    worker.join();
  stopping = false;
  worker = std::thread(sampleNextClick, context, callback);
  return true;
}

void showAlert(const char *message) {
  MessageBoxA(nullptr, message, "White Balance", MB_OK | MB_ICONWARNING);
}

void shutdownEyedropper() {
  stopping = true;
  std::lock_guard<std::mutex> lock(workerMutex);
  if (worker.joinable())
    worker.join();
  sampling = false;
}

} // namespace white_balance
