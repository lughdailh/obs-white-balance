#import <AppKit/AppKit.h>

#include <obs.h>
#include <obs-module.h>

#include <cstdio>

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 4) {
      std::fprintf(stderr,
                   "usage: plugin-smoke <graphics-module> <plugin> <data>\n");
      return 2;
    }

    [NSApplication sharedApplication];
    if (!obs_startup("en-US", nullptr, nullptr)) {
      std::fprintf(stderr, "obs_startup failed\n");
      return 3;
    }

    obs_video_info video{};
    video.graphics_module = argv[1];
    video.fps_num = 30;
    video.fps_den = 1;
    video.base_width = 640;
    video.base_height = 360;
    video.output_width = 640;
    video.output_height = 360;
    video.output_format = VIDEO_FORMAT_RGBA;
    video.colorspace = VIDEO_CS_709;
    video.range = VIDEO_RANGE_FULL;
    video.scale_type = OBS_SCALE_BILINEAR;

    const int videoResult = obs_reset_video(&video);
    if (videoResult != OBS_VIDEO_SUCCESS) {
      std::fprintf(stderr, "obs_reset_video failed: %d\n", videoResult);
      obs_shutdown();
      return 4;
    }

    obs_module_t *module = nullptr;
    const int openResult = obs_open_module(&module, argv[2], argv[3]);
    if (openResult != MODULE_SUCCESS || !module) {
      std::fprintf(stderr, "obs_open_module failed: %d\n", openResult);
      obs_shutdown();
      return 5;
    }
    if (!obs_init_module(module)) {
      std::fprintf(stderr, "obs_init_module failed\n");
      obs_shutdown();
      return 6;
    }

    obs_source_t *filter =
        obs_source_create_private("white_balance_filter", "smoke-test", nullptr);
    if (!filter) {
      std::fprintf(stderr, "white_balance_filter creation failed\n");
      obs_shutdown();
      return 7;
    }

    obs_source_release(filter);
    obs_shutdown();
    return 0;
  }
}
