#include "lua_bindings.h"

#include "renderer.h"

#include <lauxlib.h>
#include <stdio.h>

static const char *k_renderer_key = "engine_renderer";

static struct Renderer *get_renderer(lua_State *L) {
  struct Renderer *renderer = NULL;
  lua_getfield(L, LUA_REGISTRYINDEX, k_renderer_key);
  renderer = (struct Renderer *)lua_touserdata(L, -1);
  lua_pop(L, 1);
  return renderer;
}

static int l_rect(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  float x = (float)luaL_checknumber(L, 1);
  float y = (float)luaL_checknumber(L, 2);
  float w = (float)luaL_checknumber(L, 3);
  float h = (float)luaL_checknumber(L, 4);
  if (renderer) {
    renderer_draw_rect(renderer, x, y, w, h);
  }
  return 0;
}

static int l_rectc(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  float x = (float)luaL_checknumber(L, 1);
  float y = (float)luaL_checknumber(L, 2);
  float w = (float)luaL_checknumber(L, 3);
  float h = (float)luaL_checknumber(L, 4);
  float red = (float)luaL_checknumber(L, 5);
  float green = (float)luaL_checknumber(L, 6);
  float blue = (float)luaL_checknumber(L, 7);
  float alpha = (float)luaL_optnumber(L, 8, 1.0);

  if (renderer) {
    renderer_draw_rect_color(renderer, x, y, w, h, red, green, blue, alpha);
  }
  return 0;
}

static int l_png(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  float x = (float)luaL_checknumber(L, 1);
  float y = (float)luaL_checknumber(L, 2);
  const char *path = luaL_checkstring(L, 3);
  if (renderer) {
    renderer_draw_png(renderer, x, y, path);
  }
  return 0;
}

static int l_begin2d(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  if (renderer) {
    renderer_begin_2d(renderer);
  }
  return 0;
}

static int l_cam3d(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  float x = (float)luaL_checknumber(L, 1);
  float y = (float)luaL_checknumber(L, 2);
  float z = (float)luaL_checknumber(L, 3);
  float yaw = (float)luaL_checknumber(L, 4);
  float pitch = (float)luaL_checknumber(L, 5);
  float fov = (float)luaL_optnumber(L, 6, 60.0);
  if (renderer) {
    renderer_set_camera_3d(renderer, x, y, z, yaw, pitch, fov);
  }
  return 0;
}

static int l_sprite3d(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  float x = (float)luaL_checknumber(L, 1);
  float y = (float)luaL_checknumber(L, 2);
  float z = (float)luaL_checknumber(L, 3);
  const char *path = luaL_checkstring(L, 4);
  float size = (float)luaL_optnumber(L, 5, 1.0);
  if (renderer) {
    renderer_draw_png_3d(renderer, x, y, z, path, size);
  }
  return 0;
}

static int l_quad3d(lua_State *L) {
  struct Renderer *renderer = get_renderer(L);
  float x1 = (float)luaL_checknumber(L, 1);
  float y1 = (float)luaL_checknumber(L, 2);
  float z1 = (float)luaL_checknumber(L, 3);
  float x2 = (float)luaL_checknumber(L, 4);
  float y2 = (float)luaL_checknumber(L, 5);
  float z2 = (float)luaL_checknumber(L, 6);
  float x3 = (float)luaL_checknumber(L, 7);
  float y3 = (float)luaL_checknumber(L, 8);
  float z3 = (float)luaL_checknumber(L, 9);
  float x4 = (float)luaL_checknumber(L, 10);
  float y4 = (float)luaL_checknumber(L, 11);
  float z4 = (float)luaL_checknumber(L, 12);
  float red = (float)luaL_checknumber(L, 13);
  float green = (float)luaL_checknumber(L, 14);
  float blue = (float)luaL_checknumber(L, 15);
  float alpha = (float)luaL_optnumber(L, 16, 1.0);
  if (renderer) {
    renderer_draw_quad_3d(renderer,
                          x1,
                          y1,
                          z1,
                          x2,
                          y2,
                          z2,
                          x3,
                          y3,
                          z3,
                          x4,
                          y4,
                          z4,
                          red,
                          green,
                          blue,
                          alpha);
  }
  return 0;
}

void lua_bindings_register(lua_State *L, struct Renderer *renderer) {
  lua_pushlightuserdata(L, renderer);
  lua_setfield(L, LUA_REGISTRYINDEX, k_renderer_key);

  lua_pushcfunction(L, l_rect);
  lua_setglobal(L, "rect");

  lua_pushcfunction(L, l_rectc);
  lua_setglobal(L, "rectc");

  lua_pushcfunction(L, l_png);
  lua_setglobal(L, "png");

  lua_pushcfunction(L, l_begin2d);
  lua_setglobal(L, "begin2d");

  lua_pushcfunction(L, l_cam3d);
  lua_setglobal(L, "cam3d");

  lua_pushcfunction(L, l_sprite3d);
  lua_setglobal(L, "sprite3d");

  lua_pushcfunction(L, l_quad3d);
  lua_setglobal(L, "quad3d");
}

void lua_bindings_call_tick(lua_State *L) {
  lua_getglobal(L, "tick");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return;
  }
  if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
    const char *err = lua_tostring(L, -1);
    fprintf(stderr, "Lua tick() error: %s\n", err ? err : "unknown");
    lua_pop(L, 1);
  }
}

void lua_bindings_call_key(lua_State *L, const char *key, int is_pressed) {
  lua_getglobal(L, "key");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return;
  }

  lua_pushstring(L, key);
  lua_pushboolean(L, is_pressed);
  if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
    const char *err = lua_tostring(L, -1);
    fprintf(stderr, "Lua key() error: %s\n", err ? err : "unknown");
    lua_pop(L, 1);
  }
}

void lua_bindings_call_gamepad_button(lua_State *L, const char *button, int is_pressed) {
  lua_getglobal(L, "gamepad_button");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return;
  }

  lua_pushstring(L, button);
  lua_pushboolean(L, is_pressed);
  if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
    const char *err = lua_tostring(L, -1);
    fprintf(stderr, "Lua gamepad_button() error: %s\n", err ? err : "unknown");
    lua_pop(L, 1);
  }
}

void lua_bindings_call_gamepad_axis(lua_State *L, const char *axis, float value) {
  lua_getglobal(L, "gamepad_axis");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return;
  }

  lua_pushstring(L, axis);
  lua_pushnumber(L, value);
  if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
    const char *err = lua_tostring(L, -1);
    fprintf(stderr, "Lua gamepad_axis() error: %s\n", err ? err : "unknown");
    lua_pop(L, 1);
  }
}

void lua_bindings_call_mouse(lua_State *L, float dx, float dy) {
  lua_getglobal(L, "mouse");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return;
  }

  lua_pushnumber(L, dx);
  lua_pushnumber(L, dy);
  if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
    const char *err = lua_tostring(L, -1);
    fprintf(stderr, "Lua mouse() error: %s\n", err ? err : "unknown");
    lua_pop(L, 1);
  }
}

void lua_bindings_call_mouse_button(lua_State *L, const char *button, int is_pressed) {
  lua_getglobal(L, "mouse_button");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return;
  }

  lua_pushstring(L, button);
  lua_pushboolean(L, is_pressed);
  if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
    const char *err = lua_tostring(L, -1);
    fprintf(stderr, "Lua mouse_button() error: %s\n", err ? err : "unknown");
    lua_pop(L, 1);
  }
}
