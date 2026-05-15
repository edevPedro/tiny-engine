#include "sdl_gyro.h"

#include "log.h"
#include "lua_bindings.h"

#include <SDL.h>
#include <lua.h>

#include <math.h>

static SDL_GameController *s_controller;
static int s_subsystem_ok;
static int s_logged_sensor;
static int s_logged_open_fail;
static float s_prev_gx;
static float s_prev_gy;
static float s_prev_gz;

#define GYRO_EPS 0.0004f

static void sdl_gyro_try_open(void) {
  if (s_controller) {
    return;
  }

  int n = SDL_NumJoysticks();
  for (int i = 0; i < n; ++i) {
    if (!SDL_IsGameController(i)) {
      continue;
    }
    SDL_GameController *gc = SDL_GameControllerOpen(i);
    if (!gc) {
      continue;
    }
    const char *name = SDL_GameControllerName(gc);
    if (SDL_GameControllerHasSensor(gc, SDL_SENSOR_GYRO)) {
      if (SDL_GameControllerSetSensorEnabled(gc, SDL_SENSOR_GYRO, SDL_TRUE) < 0) {
        LOGW("SDL: giroscópio não ativado (%s): %s", name ? name : "(null)", SDL_GetError());
        SDL_GameControllerClose(gc);
        continue;
      }
      s_controller = gc;
      LOGI("SDL: giroscópio ativo no comando \"%s\"", name ? name : "(null)");
      return;
    }
    if (!s_logged_sensor) {
      LOGI("SDL: comando \"%s\" sem sensor de giroscópio (API SDL)", name ? name : "(null)");
      s_logged_sensor = 1;
    }
    SDL_GameControllerClose(gc);
  }

  if (n > 0 && !s_logged_open_fail) {
    LOGI("SDL: nenhum SDL_GameController com giroscópio aberto (pads=%d)", n);
    s_logged_open_fail = 1;
  }
}

void sdl_gyro_init(void) {
  /* HIDAPI ajuda DS4/PS5 em vários SO; o motor já usa GLFW para o mesmo dispositivo. */
  SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI, "1");
  SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_PS4, "1");
  SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI_PS4_RUMBLE, "1");

  if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) < 0) {
    LOGW("SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER): %s", SDL_GetError());
    return;
  }
  s_subsystem_ok = 1;
  sdl_gyro_try_open();
}

void sdl_gyro_shutdown(void) {
  if (s_controller) {
    SDL_GameControllerClose(s_controller);
    s_controller = NULL;
  }
  if (s_subsystem_ok) {
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
    s_subsystem_ok = 0;
  }
  s_logged_sensor = 0;
  s_logged_open_fail = 0;
}

void sdl_gyro_poll(lua_State *L) {
  if (!s_subsystem_ok || !L) {
    return;
  }

  SDL_PumpEvents();

  if (!s_controller) {
    sdl_gyro_try_open();
  }

  if (!s_controller) {
    return;
  }

  if (!SDL_GameControllerGetAttached(s_controller)) {
    SDL_GameControllerClose(s_controller);
    s_controller = NULL;
    s_logged_open_fail = 0;
    return;
  }

  if (!SDL_GameControllerHasSensor(s_controller, SDL_SENSOR_GYRO)) {
    return;
  }

  float data[3];
  if (SDL_GameControllerGetSensorData(s_controller, SDL_SENSOR_GYRO, data, 3) < 0) {
    return;
  }

  float gx = data[0];
  float gy = data[1];
  float gz = data[2];

  if (fabsf(gx - s_prev_gx) >= GYRO_EPS) {
    lua_bindings_call_gamepad_axis(L, "gyro_x", gx);
    s_prev_gx = gx;
  }
  if (fabsf(gy - s_prev_gy) >= GYRO_EPS) {
    lua_bindings_call_gamepad_axis(L, "gyro_y", gy);
    s_prev_gy = gy;
  }
  if (fabsf(gz - s_prev_gz) >= GYRO_EPS) {
    lua_bindings_call_gamepad_axis(L, "gyro_z", gz);
    s_prev_gz = gz;
  }
}
