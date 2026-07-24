#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <windowsx.h>

#include <obs-module.h>

#include <atomic>
#include <chrono>
#include <mutex>
#include <thread>

#include "platform-eyedropper.hpp"

namespace white_balance {
namespace {

constexpr wchar_t pickerClassName[] = L"ObsWhiteBalanceEyedropper";

struct Completion {
  void *context;
  SampleCallback callback;
  SampledColor color;
};

struct PickerState {
  POINT point{};
  bool selected = false;
};

std::atomic_bool sampling{false};
std::atomic_bool stopping{false};
std::atomic<HWND> pickerWindow{nullptr};
std::mutex workerMutex;
std::thread worker;

void completeOnObsThread(void *data) {
  auto *completion = static_cast<Completion *>(data);
  completion->callback(completion->context, completion->color);
  delete completion;
}

LRESULT CALLBACK pickerWindowProc(HWND window, UINT message, WPARAM wParam,
                                  LPARAM lParam) {
  auto *state =
      reinterpret_cast<PickerState *>(GetWindowLongPtrW(window, GWLP_USERDATA));

  if (message == WM_NCCREATE) {
    const auto *create = reinterpret_cast<CREATESTRUCTW *>(lParam);
    state = static_cast<PickerState *>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(state));
  }

  switch (message) {
  case WM_SETCURSOR:
    SetCursor(LoadCursorW(nullptr, IDC_CROSS));
    return TRUE;
  case WM_LBUTTONDOWN:
    if (state) {
      state->point = {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
      ClientToScreen(window, &state->point);
      state->selected = true;
    }
    DestroyWindow(window);
    return 0;
  case WM_KEYDOWN:
    if (wParam == VK_ESCAPE) {
      DestroyWindow(window);
      return 0;
    }
    break;
  case WM_CLOSE:
    DestroyWindow(window);
    return 0;
  case WM_DESTROY:
    pickerWindow = nullptr;
    PostQuitMessage(0);
    return 0;
  default:
    break;
  }
  return DefWindowProcW(window, message, wParam, lParam);
}

bool registerPickerClass(HINSTANCE instance) {
  WNDCLASSEXW windowClass{};
  windowClass.cbSize = sizeof(windowClass);
  windowClass.lpfnWndProc = pickerWindowProc;
  windowClass.hInstance = instance;
  windowClass.hCursor = LoadCursorW(nullptr, IDC_CROSS);
  windowClass.lpszClassName = pickerClassName;
  if (RegisterClassExW(&windowClass))
    return true;
  return GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

SampledColor sampleScreenPixel(const POINT &point) {
  SampledColor color;
  HDC screen = GetDC(nullptr);
  const COLORREF pixel =
      screen ? GetPixel(screen, point.x, point.y) : CLR_INVALID;
  if (screen)
    ReleaseDC(nullptr, screen);
  if (pixel != CLR_INVALID) {
    color = {true, GetRValue(pixel) / 255.0, GetGValue(pixel) / 255.0,
             GetBValue(pixel) / 255.0};
  }
  return color;
}

void sampleNextClick(void *context, SampleCallback callback) {
  HMODULE instance = nullptr;
  GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                         GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                     reinterpret_cast<LPCWSTR>(&pickerWindow), &instance);
  PickerState state;
  SampledColor color;

  if (!stopping && registerPickerClass(instance)) {
    const int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
    const int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
    const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);

    HWND window = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED, pickerClassName,
        L"White Balance Eyedropper", WS_POPUP, left, top, width, height,
        nullptr, nullptr, instance, &state);
    if (window) {
      pickerWindow = window;
      SetLayeredWindowAttributes(window, 0, 1, LWA_ALPHA);
      ShowWindow(window, SW_SHOW);
      SetWindowPos(window, HWND_TOPMOST, left, top, width, height,
                   SWP_SHOWWINDOW);
      SetForegroundWindow(window);
      SetFocus(window);
      SetCapture(window);

      MSG message{};
      while (!stopping && GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
      }

      if (IsWindow(window))
        DestroyWindow(window);
      ReleaseCapture();
      if (state.selected) {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
        color = sampleScreenPixel(state.point);
      }
    }
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
  const HWND window = pickerWindow.load();
  if (window)
    PostMessageW(window, WM_CLOSE, 0, 0);
  std::lock_guard<std::mutex> lock(workerMutex);
  if (worker.joinable())
    worker.join();
  sampling = false;
}

} // namespace white_balance
