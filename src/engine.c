#include "engine.h"

#include "input_map.h"
#include "joystick.h"
#include "log.h"
#include "lua_bindings.h"
#include "renderer.h"
#include "sdl_gyro.h"

#include <glad/gl.h>
#include <GLFW/glfw3.h>

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define ENGINE_GENERIC_BTN_CAP 64
#define ENGINE_GENERIC_AXIS_CAP 16

struct Engine {
  EngineConfig config;
  int glfw_initialized;
  unsigned char gamepad_buttons[15];
  float gamepad_axes[6];
  unsigned char generic_buttons[ENGINE_GENERIC_BTN_CAP];
  float generic_axes[ENGINE_GENERIC_AXIS_CAP];
  int generic_btn_count;
  int generic_axis_count;
  GLFWwindow *window;
  Renderer *renderer;
  lua_State *L;
  double last_mouse_x;
  double last_mouse_y;
  int mouse_initialized;
};

static void poll_gamepad(Engine *engine) {
  GLFWgamepadstate state;
  if (!glfwJoystickIsGamepad(GLFW_JOYSTICK_1)) {
    return;
  }
  if (!glfwGetGamepadState(GLFW_JOYSTICK_1, &state)) {
    return;
  }

  const char *gamepad_label = glfwGetGamepadName(GLFW_JOYSTICK_1);
  if (!gamepad_label) {
    gamepad_label = glfwGetJoystickName(GLFW_JOYSTICK_1);
  }

  for (int i = 0; i <= GLFW_GAMEPAD_BUTTON_LAST; ++i) {
    unsigned char pressed = state.buttons[i] == GLFW_PRESS ? 1u : 0u;
    if (pressed != engine->gamepad_buttons[i]) {
      const char *name = input_map_gamepad_button_name(i);
      if (name) {
        LOGI("gamepad \"%s\" %s %s", gamepad_label ? gamepad_label : "(null)", name,
             pressed ? "press" : "release");
        lua_bindings_call_gamepad_button(engine->L, name, (int)pressed);
      } else if (pressed) {
        LOGI("gamepad \"%s\" unmapped_button index=%d", gamepad_label ? gamepad_label : "(null)", i);
      }
      engine->gamepad_buttons[i] = pressed;
    }
  }

  for (int i = 0; i <= GLFW_GAMEPAD_AXIS_LAST; ++i) {
    float value = state.axes[i];
    float prev = engine->gamepad_axes[i];
    float diff = value - prev;
    if (diff < 0.0f) {
      diff = -diff;
    }
    if (diff >= 0.02f) {
      const char *name = input_map_gamepad_axis_name(i);
      if (name) {
        lua_bindings_call_gamepad_axis(engine->L, name, value);
      }
      engine->gamepad_axes[i] = value;
    }
  }
}

static void poll_generic_joystick(Engine *engine) {
  int hat_count = 0;
  (void)glfwGetJoystickHats(GLFW_JOYSTICK_1, &hat_count);

  int btn_count = 0;
  const unsigned char *buttons = glfwGetJoystickButtons(GLFW_JOYSTICK_1, &btn_count);
  if (!buttons || btn_count <= 0) {
    btn_count = 0;
  }
  if (btn_count > ENGINE_GENERIC_BTN_CAP) {
    btn_count = ENGINE_GENERIC_BTN_CAP;
  }

  int axis_count = 0;
  const float *axes = glfwGetJoystickAxes(GLFW_JOYSTICK_1, &axis_count);
  if (!axes || axis_count <= 0) {
    axis_count = 0;
  }
  if (axis_count > ENGINE_GENERIC_AXIS_CAP) {
    axis_count = ENGINE_GENERIC_AXIS_CAP;
  }

  if (engine->generic_btn_count != btn_count || engine->generic_axis_count != axis_count) {
    memset(engine->generic_buttons, 0, sizeof(engine->generic_buttons));
    memset(engine->generic_axes, 0, sizeof(engine->generic_axes));
    engine->generic_btn_count = btn_count;
    engine->generic_axis_count = axis_count;
  }

  const char *label = glfwGetJoystickName(GLFW_JOYSTICK_1);

  for (int i = 0; i < btn_count; ++i) {
    unsigned char pressed = buttons[i] == GLFW_PRESS ? 1u : 0u;
    if (pressed != engine->generic_buttons[i]) {
      const char *name = input_map_gamepad_generic_button_name(i, btn_count, hat_count);
      if (name) {
        LOGI("gamepad(generic) \"%s\" %s %s", label ? label : "(null)", name,
             pressed ? "press" : "release");
        lua_bindings_call_gamepad_button(engine->L, name, (int)pressed);
      }
      engine->generic_buttons[i] = pressed;
    }
  }

  for (int i = 0; i < axis_count; ++i) {
    float value = axes[i];
    float prev = engine->generic_axes[i];
    float diff = value - prev;
    if (diff < 0.0f) {
      diff = -diff;
    }
    if (diff >= 0.02f) {
      const char *name = input_map_gamepad_generic_axis_name(i, axis_count);
      if (name) {
        LOGI("gamepad(generic) \"%s\" %s %f", label ? label : "(null)", name, value);
        lua_bindings_call_gamepad_axis(engine->L, name, value);
      }
      engine->generic_axes[i] = value;
    }
  }
}

static void poll_joystick_lua(Engine *engine) {
  if (!glfwJoystickPresent(GLFW_JOYSTICK_1)) {
    memset(engine->generic_buttons, 0, sizeof(engine->generic_buttons));
    memset(engine->generic_axes, 0, sizeof(engine->generic_axes));
    engine->generic_btn_count = -1;
    engine->generic_axis_count = -1;
    return;
  }

  if (glfwJoystickIsGamepad(GLFW_JOYSTICK_1)) {
    engine->generic_btn_count = -1;
    engine->generic_axis_count = -1;
    poll_gamepad(engine);
    return;
  }

  poll_generic_joystick(engine);
}

static void glfw_error_callback(int code, const char *description) {
  LOGE("GLFW error %d: %s", code, description);
}

static void key_callback(GLFWwindow *window, int key, int scancode, int action, int mods) {
  (void)scancode;
  (void)mods;

  Engine *engine = (Engine *)glfwGetWindowUserPointer(window);
  if (!engine || !engine->L) {
    return;
  }

  if (action != GLFW_PRESS && action != GLFW_RELEASE) {
    return;
  }

  if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
    glfwSetWindowShouldClose(window, GLFW_TRUE);
  }

  const char *name = input_map_key_name(key);
  if (name) {
    lua_bindings_call_key(engine->L, name, action == GLFW_PRESS);
  }
}

static void framebuffer_size_callback(GLFWwindow *window, int width, int height) {
  (void)window;
  glViewport(0, 0, width, height);
}

static void cursor_pos_callback(GLFWwindow *window, double xpos, double ypos) {
  Engine *engine = (Engine *)glfwGetWindowUserPointer(window);
  if (!engine || !engine->L) {
    return;
  }

  if (!engine->mouse_initialized) {
    engine->last_mouse_x = xpos;
    engine->last_mouse_y = ypos;
    engine->mouse_initialized = 1;
    return;
  }

  float dx = (float)(xpos - engine->last_mouse_x);
  float dy = (float)(ypos - engine->last_mouse_y);
  engine->last_mouse_x = xpos;
  engine->last_mouse_y = ypos;

  if (dx != 0.0f || dy != 0.0f) {
    lua_bindings_call_mouse(engine->L, dx, dy);
  }
}

static void mouse_button_callback(GLFWwindow *window, int button, int action, int mods) {
  (void)mods;
  Engine *engine = (Engine *)glfwGetWindowUserPointer(window);
  if (!engine || !engine->L) {
    return;
  }
  if (action != GLFW_PRESS && action != GLFW_RELEASE) {
    return;
  }

  const char *name = NULL;
  switch (button) {
    case GLFW_MOUSE_BUTTON_LEFT:
      name = "left";
      break;
    case GLFW_MOUSE_BUTTON_RIGHT:
      name = "right";
      break;
    case GLFW_MOUSE_BUTTON_MIDDLE:
      name = "middle";
      break;
    default:
      return;
  }

  lua_bindings_call_mouse_button(engine->L, name, action == GLFW_PRESS);
}

Engine *engine_create(const EngineConfig *config) {
  if (!config || !config->script_path) {
    LOGE("Missing engine config or script path");
    return NULL;
  }

  Engine *engine = (Engine *)calloc(1, sizeof(*engine));
  if (!engine) {
    return NULL;
  }
  engine->config = *config;

  glfwSetErrorCallback(glfw_error_callback);
  if (!glfwInit()) {
    LOGE("Failed to initialize GLFW");
    engine_destroy(engine);
    return NULL;
  }
  engine->glfw_initialized = 1;

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
  glfwWindowHint(GLFW_DEPTH_BITS, 24);

  engine->window = glfwCreateWindow(
      engine->config.width, engine->config.height, engine->config.window_title, NULL, NULL);
  if (!engine->window) {
    engine_destroy(engine);
    return NULL;
  }

  glfwMakeContextCurrent(engine->window);
  glfwSwapInterval(engine->config.vsync ? 1 : 0);

  {
    int version = gladLoadGL((GLADloadfunc)glfwGetProcAddress);
    if (version == 0) {
      LOGE("Failed to initialize GLAD");
      engine_destroy(engine);
      return NULL;
    }
  }

  {
    int fbw = 0;
    int fbh = 0;
    glfwGetFramebufferSize(engine->window, &fbw, &fbh);
    glViewport(0, 0, fbw, fbh);
  }

#if defined(__APPLE__)
  /* Processa a fila de eventos antes de enumerar joysticks: no Cocoa o HID costuma
   * integrar-se ao run loop após a janela existir. */
  glfwPollEvents();
  glfwPollEvents();
#endif

  joystick_register_callbacks();
  sdl_gyro_init();

  engine->renderer = renderer_create(engine->config.width, engine->config.height);
  if (!engine->renderer) {
    engine_destroy(engine);
    return NULL;
  }

  engine->L = luaL_newstate();
  if (!engine->L) {
    engine_destroy(engine);
    return NULL;
  }
  luaL_openlibs(engine->L);
  lua_bindings_register(engine->L, engine->renderer);

  if (luaL_dofile(engine->L, engine->config.script_path) != LUA_OK) {
    const char *err = lua_tostring(engine->L, -1);
    LOGE("Failed to load script %s: %s", engine->config.script_path, err ? err : "unknown");
    lua_pop(engine->L, 1);
    engine_destroy(engine);
    return NULL;
  }

  glfwSetWindowUserPointer(engine->window, engine);
  glfwSetKeyCallback(engine->window, key_callback);
  glfwSetFramebufferSizeCallback(engine->window, framebuffer_size_callback);
  glfwSetCursorPosCallback(engine->window, cursor_pos_callback);
  glfwSetMouseButtonCallback(engine->window, mouse_button_callback);
  glfwSetInputMode(engine->window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

  return engine;
}

int engine_run(Engine *engine) {
  if (!engine) {
    return 1;
  }

  const double target_frametime = 1.0 / 60.0;
  double fps_last = glfwGetTime();
  int fps_frames = 0;
  int total_frames = 0;

  while (!glfwWindowShouldClose(engine->window)) {
    double frame_start = glfwGetTime();

    glfwPollEvents();
    joystick_poll_mapping_log();
    poll_joystick_lua(engine);
    sdl_gyro_poll(engine->L);
    renderer_begin_frame(engine->renderer);
    lua_bindings_call_tick(engine->L);
    glfwSwapBuffers(engine->window);

    fps_frames += 1;
    total_frames += 1;

    if (engine->config.max_frames > 0 && total_frames >= engine->config.max_frames) {
      glfwSetWindowShouldClose(engine->window, GLFW_TRUE);
    }

    if (engine->config.show_fps) {
      double now = glfwGetTime();
      if (now - fps_last >= 1.0) {
        double fps = (double)fps_frames / (now - fps_last);
        char title[256];
        snprintf(title, sizeof(title), "%s | %.1f FPS", engine->config.window_title, fps);
        glfwSetWindowTitle(engine->window, title);
        fps_last = now;
        fps_frames = 0;
      }
    }

    if (!engine->config.vsync) {
      double elapsed = glfwGetTime() - frame_start;
      if (elapsed < target_frametime) {
        double sleep_s = target_frametime - elapsed;
        struct timespec ts;
        ts.tv_sec = (time_t)sleep_s;
        ts.tv_nsec = (long)((sleep_s - (double)ts.tv_sec) * 1000000000.0);
        nanosleep(&ts, NULL);
      }
    }
  }

  return 0;
}

void engine_destroy(Engine *engine) {
  if (!engine) {
    return;
  }

  if (engine->L) {
    lua_close(engine->L);
    engine->L = NULL;
  }

  if (engine->renderer) {
    renderer_destroy(engine->renderer);
    engine->renderer = NULL;
  }

  if (engine->window) {
    glfwDestroyWindow(engine->window);
    engine->window = NULL;
  }

  sdl_gyro_shutdown();

  if (engine->glfw_initialized) {
    glfwTerminate();
    engine->glfw_initialized = 0;
  }

  free(engine);
}
