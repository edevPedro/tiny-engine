#ifndef ENGINE_CORE_H
#define ENGINE_CORE_H

/** @brief Opaque engine handle. */
typedef struct Engine Engine;

/**
 * @brief Runtime configuration used to create the engine.
 */
typedef struct EngineConfig {
  /** Path to main Lua script. */
  const char *script_path;
  /** Window title text. */
  const char *window_title;
  /** Window width in pixels. */
  int width;
  /** Window height in pixels. */
  int height;
  /** Enable FPS display in title bar. */
  int show_fps;
  /** Enable VSync. */
  int vsync;
  /** Max frames before auto-exit (0 = disabled). */
  int max_frames;
} EngineConfig;

/** @brief Creates and initializes engine instance. */
Engine *engine_create(const EngineConfig *config);
/** @brief Runs the main loop until exit. */
int engine_run(Engine *engine);
/** @brief Releases all engine resources. */
void engine_destroy(Engine *engine);

#endif
