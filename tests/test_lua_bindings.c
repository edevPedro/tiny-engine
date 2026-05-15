#include "lua_bindings.h"

#include <assert.h>
#include <math.h>
#include <string.h>

#include <lauxlib.h>
#include <lualib.h>

struct Renderer {
  int unused;
};

static int g_rect_calls = 0;
static int g_rectc_calls = 0;
static int g_png_calls = 0;
static float g_last_rect_x = 0.0f;
static float g_last_rect_y = 0.0f;
static float g_last_rect_w = 0.0f;
static float g_last_rect_h = 0.0f;
static float g_last_rectc_a = 0.0f;
static char g_last_png_path[128];

static int feq(float a, float b) {
  return fabsf(a - b) < 0.0001f;
}

void renderer_draw_rect(struct Renderer *r, float x, float y, float w, float h) {
  (void)r;
  g_rect_calls += 1;
  g_last_rect_x = x;
  g_last_rect_y = y;
  g_last_rect_w = w;
  g_last_rect_h = h;
}

void renderer_draw_rect_color(struct Renderer *r,
                              float x,
                              float y,
                              float w,
                              float h,
                              float red,
                              float green,
                              float blue,
                              float alpha) {
  (void)r;
  (void)x;
  (void)y;
  (void)w;
  (void)h;
  (void)red;
  (void)green;
  (void)blue;
  g_rectc_calls += 1;
  g_last_rectc_a = alpha;
}

void renderer_draw_png(struct Renderer *r, float x, float y, const char *path) {
  (void)r;
  (void)x;
  (void)y;
  g_png_calls += 1;
  strncpy(g_last_png_path, path, sizeof(g_last_png_path) - 1);
  g_last_png_path[sizeof(g_last_png_path) - 1] = '\0';
}

void renderer_begin_2d(struct Renderer *r) { (void)r; }
void renderer_set_camera_3d(struct Renderer *r, float x, float y, float z, float yaw, float pitch, float fov) {
  (void)r; (void)x; (void)y; (void)z; (void)yaw; (void)pitch; (void)fov;
}
void renderer_draw_png_3d(struct Renderer *r, float x, float y, float z, const char *path, float size) {
  (void)r; (void)x; (void)y; (void)z; (void)path; (void)size;
}
void renderer_draw_quad_3d(struct Renderer *r,
                           float x1,
                           float y1,
                           float z1,
                           float x2,
                           float y2,
                           float z2,
                           float x3,
                           float y3,
                           float z3,
                           float x4,
                           float y4,
                           float z4,
                           float red,
                           float green,
                           float blue,
                           float alpha) {
  (void)r;
  (void)x1; (void)y1; (void)z1;
  (void)x2; (void)y2; (void)z2;
  (void)x3; (void)y3; (void)z3;
  (void)x4; (void)y4; (void)z4;
  (void)red; (void)green; (void)blue; (void)alpha;
}

int main(void) {
  struct Renderer renderer = {0};
  lua_State *L = luaL_newstate();
  assert(L != NULL);
  luaL_openlibs(L);

  lua_bindings_register(L, &renderer);

  lua_getglobal(L, "rect");
  assert(lua_isfunction(L, -1));
  lua_pop(L, 1);

  lua_getglobal(L, "rectc");
  assert(lua_isfunction(L, -1));
  lua_pop(L, 1);

  lua_getglobal(L, "png");
  assert(lua_isfunction(L, -1));
  lua_pop(L, 1);

  assert(luaL_dostring(L, "rect(8,16,32,64)") == LUA_OK);
  assert(g_rect_calls == 1);
  assert(feq(g_last_rect_x, 8.0f));
  assert(feq(g_last_rect_y, 16.0f));
  assert(feq(g_last_rect_w, 32.0f));
  assert(feq(g_last_rect_h, 64.0f));

  assert(luaL_dostring(L, "rectc(1,2,3,4,0.1,0.2,0.3)") == LUA_OK);
  assert(g_rectc_calls == 1);
  assert(feq(g_last_rectc_a, 1.0f));

  assert(luaL_dostring(L, "rectc(1,2,3,4,0.1,0.2,0.3,0.4)") == LUA_OK);
  assert(g_rectc_calls == 2);
  assert(feq(g_last_rectc_a, 0.4f));

  assert(luaL_dostring(L, "png(10,20,'dvd.png')") == LUA_OK);
  assert(g_png_calls == 1);
  assert(strcmp(g_last_png_path, "dvd.png") == 0);

  assert(luaL_dostring(L,
                       "tick_count=0; key_last=''; key_pressed=false; gp_btn=''; gp_press=false; "
                       "gp_axis=''; gp_value=0;"
                       "function tick() tick_count=tick_count+1 end "
                       "function key(n,p) key_last=n; key_pressed=p end "
                       "function gamepad_button(n,p) gp_btn=n; gp_press=p end "
                       "function gamepad_axis(n,v) gp_axis=n; gp_value=v end") == LUA_OK);

  lua_bindings_call_tick(L);
  lua_getglobal(L, "tick_count");
  assert((int)lua_tointeger(L, -1) == 1);
  lua_pop(L, 1);

  lua_bindings_call_key(L, "left", 1);
  lua_getglobal(L, "key_last");
  assert(lua_isstring(L, -1));
  assert(lua_tostring(L, -1)[0] == 'l');
  lua_pop(L, 1);

  lua_bindings_call_gamepad_button(L, "a", 1);
  lua_getglobal(L, "gp_btn");
  assert(lua_isstring(L, -1));
  assert(lua_tostring(L, -1)[0] == 'a');
  lua_pop(L, 1);

  lua_bindings_call_gamepad_axis(L, "lx", 0.5f);
  lua_getglobal(L, "gp_axis");
  assert(lua_isstring(L, -1));
  assert(lua_tostring(L, -1)[0] == 'l');
  lua_pop(L, 1);

  lua_close(L);
  return 0;
}
