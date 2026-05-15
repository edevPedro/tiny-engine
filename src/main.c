#include "engine.h"
#include "log.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static void print_usage(const char *argv0) {
  fprintf(stderr,
          "Usage: %s [--fps] [--vsync] [--title <title>] [--debug] [--max-frames N] <script.lua>\n",
          argv0);
}

int main(int argc, char **argv) {
  EngineConfig config;
  config.script_path = NULL;
  config.window_title = "engine";
  config.width = 640;
  config.height = 480;
  config.show_fps = 0;
  config.vsync = 0;
  config.max_frames = 0;

  log_set_level(LOG_INFO);

  for (int i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--fps") == 0) {
      config.show_fps = 1;
    } else if (strcmp(argv[i], "--vsync") == 0) {
      config.vsync = 1;
    } else if (strcmp(argv[i], "--debug") == 0) {
      log_set_level(LOG_DEBUG);
    } else if (strcmp(argv[i], "--max-frames") == 0) {
      if (i + 1 >= argc) {
        print_usage(argv[0]);
        return 1;
      }
      config.max_frames = atoi(argv[++i]);
      if (config.max_frames < 0) {
        config.max_frames = 0;
      }
    } else if (strcmp(argv[i], "--title") == 0) {
      if (i + 1 >= argc) {
        print_usage(argv[0]);
        return 1;
      }
      config.window_title = argv[++i];
    } else if (argv[i][0] == '-') {
      fprintf(stderr, "Unknown option: %s\n", argv[i]);
      print_usage(argv[0]);
      return 1;
    } else {
      config.script_path = argv[i];
    }
  }

  if (!config.script_path) {
    print_usage(argv[0]);
    return 1;
  }

  Engine *engine = engine_create(&config);
  if (!engine) {
    return 1;
  }

  int rc = engine_run(engine);
  engine_destroy(engine);
  return rc;
}
