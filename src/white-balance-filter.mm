#import <AppKit/AppKit.h>
#include <obs-module.h>
#include <media-io/video-scaler.h>
#include "calibration-view.hpp"
#include <mutex>
#include <stdexcept>
#include <string>

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("obs-white-balance", "en-US")
MODULE_EXPORT const char *obs_module_description(void) {
  return "One-shot white balance calibration filter";
}

namespace {
constexpr const char *RED = "red_gain";
constexpr const char *GREEN = "green_gain";
constexpr const char *BLUE = "blue_gain";
constexpr const char *STRENGTH = "strength";
constexpr const char *RADIUS = "sample_radius";
constexpr const char *SUMMARY = "calibration_summary";

struct Filter {
  obs_source_t *source = nullptr;
  obs_source_t *parent = nullptr;
  gs_effect_t *effect = nullptr;
  gs_eparam_t *redParam = nullptr;
  gs_eparam_t *greenParam = nullptr;
  gs_eparam_t *blueParam = nullptr;
  float red = 1, green = 1, blue = 1, strength = 1;
  std::mutex mutex;
};

void alert(NSString *message) {
  NSAlert *box = [[NSAlert alloc] init];
  box.messageText = @"White Balance";
  box.informativeText = message;
  [box runModal];
}

white_balance::Snapshot snapshot(Filter *filter) {
  obs_source_t *parent = nullptr;
  {
    std::lock_guard<std::mutex> lock(filter->mutex);
    if (filter->parent)
      parent = obs_source_get_ref(filter->parent);
  }
  if (!parent)
    throw std::runtime_error("The filter is not attached to a video source.");
  obs_source_frame *frame = obs_source_get_frame(parent);
  if (!frame) {
    obs_source_release(parent);
    throw std::runtime_error(
        "No camera frame is available. Version 0.1 supports asynchronous "
        "video sources such as Video Capture Device.");
  }

  white_balance::Snapshot shot;
  shot.width = frame->width;
  shot.height = frame->height;
  shot.stride = frame->width * 4;
  shot.bgra.resize(shot.stride * shot.height);
  video_scale_info src{};
  src.format = frame->format;
  src.width = frame->width;
  src.height = frame->height;
  src.range = frame->full_range ? VIDEO_RANGE_FULL : VIDEO_RANGE_PARTIAL;
  src.colorspace = frame->height >= 720 ? VIDEO_CS_709 : VIDEO_CS_601;
  video_scale_info dst{VIDEO_FORMAT_BGRA, frame->width, frame->height,
                       VIDEO_RANGE_FULL, src.colorspace};
  video_scaler_t *scaler = nullptr;
  bool ok = false;
  if (video_scaler_create(&scaler, &dst, &src, VIDEO_SCALE_BILINEAR) ==
      VIDEO_SCALER_SUCCESS) {
    uint8_t *output[MAX_AV_PLANES]{shot.bgra.data()};
    uint32_t lines[MAX_AV_PLANES]{static_cast<uint32_t>(shot.stride)};
    const uint8_t *input[MAX_AV_PLANES]{};
    for (std::size_t i = 0; i < MAX_AV_PLANES; ++i)
      input[i] = frame->data[i];
    ok = video_scaler_scale(scaler, output, lines, input, frame->linesize);
  }
  video_scaler_destroy(scaler);
  obs_source_release_frame(parent, frame);
  obs_source_release(parent);
  if (!ok)
    throw std::runtime_error("OBS could not convert the current camera frame.");
  return shot;
}

bool calibrate(obs_properties_t *, obs_property_t *, void *data) {
  auto *filter = static_cast<Filter *>(data);
  try {
    auto shot = snapshot(filter);
    obs_data_t *settings = obs_source_get_settings(filter->source);
    auto result = white_balance::showCalibrationDialog(
        shot, static_cast<std::size_t>(obs_data_get_int(settings, RADIUS)));
    if (result) {
      obs_data_set_double(settings, RED, result->gains.red);
      obs_data_set_double(settings, GREEN, result->gains.green);
      obs_data_set_double(settings, BLUE, result->gains.blue);
      auto summary = white_balance::formatCalibration(*result);
      obs_data_set_string(settings, SUMMARY, summary.c_str());
      obs_source_update(filter->source, settings);
      if (result->tooDark)
        alert(@"Calibration applied, but the sample is dark. Use a better-lit "
              "neutral card for more reliable results.");
      else if (result->nearClipping)
        alert(@"Calibration applied, but the sample is nearly clipped. Reduce "
              "exposure and recalibrate.");
    }
    obs_data_release(settings);
  } catch (const std::exception &error) {
    alert([NSString stringWithUTF8String:error.what()]);
  }
  return true;
}

const char *name(void *) { return obs_module_text("WhiteBalanceFilter"); }
void update(void *data, obs_data_t *settings) {
  auto *f = static_cast<Filter *>(data);
  f->red = obs_data_get_double(settings, RED);
  f->green = obs_data_get_double(settings, GREEN);
  f->blue = obs_data_get_double(settings, BLUE);
  f->strength = obs_data_get_double(settings, STRENGTH) / 100.0;
}
void defaults(obs_data_t *s) {
  obs_data_set_default_double(s, RED, 1);
  obs_data_set_default_double(s, GREEN, 1);
  obs_data_set_default_double(s, BLUE, 1);
  obs_data_set_default_double(s, STRENGTH, 100);
  obs_data_set_default_int(s, RADIUS, 12);
  obs_data_set_default_string(s, SUMMARY, "Not calibrated");
}
void *create(obs_data_t *settings, obs_source_t *source) {
  auto *f = new Filter;
  f->source = source;
  char *path = obs_module_file("white-balance.effect");
  char *errors = nullptr;
  obs_enter_graphics();
  f->effect = gs_effect_create_from_file(path, &errors);
  obs_leave_graphics();
  bfree(path);
  if (!f->effect) {
    blog(LOG_ERROR, "[White Balance] %s", errors ? errors : "shader error");
    bfree(errors);
    delete f;
    return nullptr;
  }
  bfree(errors);
  f->redParam = gs_effect_get_param_by_name(f->effect, RED);
  f->greenParam = gs_effect_get_param_by_name(f->effect, GREEN);
  f->blueParam = gs_effect_get_param_by_name(f->effect, BLUE);
  update(f, settings);
  return f;
}
void destroy(void *data) {
  auto *f = static_cast<Filter *>(data);
  {
    std::lock_guard<std::mutex> lock(f->mutex);
    if (f->parent)
      obs_source_release(f->parent);
  }
  obs_enter_graphics();
  gs_effect_destroy(f->effect);
  obs_leave_graphics();
  delete f;
}
void render(void *data, gs_effect_t *) {
  auto *f = static_cast<Filter *>(data);
  if (!obs_source_process_filter_begin(f->source, GS_RGBA,
                                       OBS_ALLOW_DIRECT_RENDERING))
    return;
  gs_effect_set_float(f->redParam, 1 + (f->red - 1) * f->strength);
  gs_effect_set_float(f->greenParam, 1 + (f->green - 1) * f->strength);
  gs_effect_set_float(f->blueParam, 1 + (f->blue - 1) * f->strength);
  obs_source_process_filter_end(f->source, f->effect, 0, 0);
}
void added(void *data, obs_source_t *source) {
  auto *f = static_cast<Filter *>(data);
  std::lock_guard<std::mutex> lock(f->mutex);
  f->parent = obs_source_get_ref(source);
}
void removed(void *data, obs_source_t *) {
  auto *f = static_cast<Filter *>(data);
  std::lock_guard<std::mutex> lock(f->mutex);
  if (f->parent) {
    obs_source_release(f->parent);
    f->parent = nullptr;
  }
}
obs_properties_t *properties(void *data) {
  auto *p = obs_properties_create();
  obs_properties_add_button2(p, "calibrate", obs_module_text("CaptureReference"),
                             calibrate, data);
  obs_properties_add_int_slider(p, RADIUS, obs_module_text("SampleRadius"), 2,
                                100, 1);
  obs_properties_add_float_slider(p, STRENGTH, obs_module_text("Strength"), 0,
                                  100, 1);
  auto *summary = obs_properties_add_text(
      p, SUMMARY, obs_module_text("Calibration"), OBS_TEXT_DEFAULT);
  obs_property_set_enabled(summary, false);
  for (auto pair : {std::pair{RED, "RedGain"}, std::pair{GREEN, "GreenGain"},
                    std::pair{BLUE, "BlueGain"}}) {
    auto *gain = obs_properties_add_float(p, pair.first,
                                          obs_module_text(pair.second), 0.25,
                                          4.0, 0.001);
    obs_property_set_enabled(gain, false);
  }
  return p;
}

obs_source_info makeInfo() {
  obs_source_info value{};
  value.id = "white_balance_filter";
  value.type = OBS_SOURCE_TYPE_FILTER;
  value.output_flags = OBS_SOURCE_VIDEO;
  value.get_name = name;
  value.create = create;
  value.destroy = destroy;
  value.get_defaults = defaults;
  value.get_properties = properties;
  value.update = update;
  value.video_render = render;
  value.filter_remove = removed;
  value.filter_add = added;
  return value;
}
obs_source_info info = makeInfo();
}  // namespace

bool obs_module_load(void) {
  obs_register_source(&info);
  return true;
}
