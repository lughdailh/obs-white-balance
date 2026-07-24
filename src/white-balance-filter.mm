#import <AppKit/AppKit.h>
#include <obs-module.h>
#include "calibration-math.hpp"
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
constexpr const char *SUMMARY = "calibration_summary";

struct Filter {
  obs_source_t *source = nullptr;
  gs_effect_t *effect = nullptr;
  gs_eparam_t *redParam = nullptr;
  gs_eparam_t *greenParam = nullptr;
  gs_eparam_t *blueParam = nullptr;
  float red = 1, green = 1, blue = 1, strength = 1;
};

void alert(NSString *message) {
  NSAlert *box = [[NSAlert alloc] init];
  box.messageText = @"White Balance";
  box.informativeText = message;
  [box runModal];
}

bool calibrate(obs_properties_t *, obs_property_t *, void *data) {
  auto *filter = static_cast<Filter *>(data);
  if (!filter) {
    alert(@"The White Balance filter could not be created.");
    return false;
  }

  obs_source_t *source = obs_source_get_ref(filter->source);
  const bool wasEnabled = obs_source_enabled(source);
  obs_source_set_enabled(source, false);
  NSColorSampler *sampler = [[NSColorSampler alloc] init];
  [sampler showSamplerWithSelectionHandler:^(NSColor *selectedColor) {
    (void)sampler;
    obs_source_set_enabled(source, wasEnabled);
    if (selectedColor) {
      NSColor *srgb =
          [selectedColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
      CGFloat red = 0;
      CGFloat green = 0;
      CGFloat blue = 0;
      CGFloat alpha = 0;
      [srgb getRed:&red green:&green blue:&blue alpha:&alpha];
      const auto result = white_balance::calibrateRgb(
          {static_cast<double>(red), static_cast<double>(green),
           static_cast<double>(blue)});
      obs_data_t *settings = obs_source_get_settings(source);
      obs_data_set_double(settings, RED, result.gains.red);
      obs_data_set_double(settings, GREEN, result.gains.green);
      obs_data_set_double(settings, BLUE, result.gains.blue);
      auto summary = white_balance::formatCalibration(result);
      obs_data_set_string(settings, SUMMARY, summary.c_str());
      obs_source_update(source, settings);
      obs_data_release(settings);
      if (result.tooDark)
        alert(@"Calibration applied, but the sample is dark. Use a better-lit "
              "neutral card for more reliable results.");
      else if (result.nearClipping)
        alert(@"Calibration applied, but the sample is nearly clipped. Reduce "
              "exposure and recalibrate.");
    }
    obs_source_release(source);
  }];
  return false;
}

const char *name(void *) { return obs_module_text("WhiteBalanceFilter"); }
void update(void *data, obs_data_t *settings) {
  auto *f = static_cast<Filter *>(data);
  if (!f || !settings)
    return;

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
  obs_data_set_default_string(s, SUMMARY, "Not calibrated");
}
void *create(obs_data_t *settings, obs_source_t *source) {
  auto *f = new Filter;
  f->source = source;
  char *path = obs_module_file("white-balance.effect");
  if (!path) {
    blog(LOG_ERROR, "[White Balance] Could not find white-balance.effect");
    delete f;
    return nullptr;
  }

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
  if (!f->redParam || !f->greenParam || !f->blueParam) {
    blog(LOG_ERROR, "[White Balance] Shader parameters are missing");
    obs_enter_graphics();
    gs_effect_destroy(f->effect);
    obs_leave_graphics();
    delete f;
    return nullptr;
  }

  update(f, settings);
  return f;
}
void destroy(void *data) {
  auto *f = static_cast<Filter *>(data);
  if (!f)
    return;

  obs_enter_graphics();
  gs_effect_destroy(f->effect);
  obs_leave_graphics();
  delete f;
}

void render(void *data, gs_effect_t *) {
  auto *f = static_cast<Filter *>(data);
  if (!f || !f->effect)
    return;

  if (!obs_source_process_filter_begin(f->source, GS_RGBA,
                                       OBS_ALLOW_DIRECT_RENDERING))
    return;
  gs_effect_set_float(f->redParam, 1 + (f->red - 1) * f->strength);
  gs_effect_set_float(f->greenParam, 1 + (f->green - 1) * f->strength);
  gs_effect_set_float(f->blueParam, 1 + (f->blue - 1) * f->strength);
  obs_source_process_filter_end(f->source, f->effect, 0, 0);
}
obs_properties_t *properties(void *data) {
  auto *p = obs_properties_create();
  obs_properties_add_button2(p, "calibrate", obs_module_text("CaptureReference"),
                             calibrate, data);
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
  return value;
}
obs_source_info info = makeInfo();
}  // namespace

bool obs_module_load(void) {
  obs_register_source(&info);
  return true;
}
