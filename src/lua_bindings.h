#ifndef ENGINE_LUA_BINDINGS_H
#define ENGINE_LUA_BINDINGS_H

#include <lua.h>

struct Renderer;

/**
 * @brief Registers engine drawing functions in the Lua global scope.
 *
 * Exposes:
 * - rect(x, y, w, h)
 * - rectc(x, y, w, h, r, g, b [, a])
 * - png(x, y, src)
 */
void lua_bindings_register(lua_State *L, struct Renderer *renderer);

/** @brief Calls Lua global function tick() when present. */
void lua_bindings_call_tick(lua_State *L);

/** @brief Calls Lua global function key(name, pressed) when present. */
void lua_bindings_call_key(lua_State *L, const char *key, int is_pressed);

/** @brief Calls Lua global function gamepad_button(name, pressed) when present. */
void lua_bindings_call_gamepad_button(lua_State *L, const char *button, int is_pressed);

/** @brief Calls Lua global function gamepad_axis(name, value) when present. */
void lua_bindings_call_gamepad_axis(lua_State *L, const char *axis, float value);

/** @brief Calls Lua global function mouse(dx, dy) when present. */
void lua_bindings_call_mouse(lua_State *L, float dx, float dy);

/** @brief Calls Lua global function mouse_button(button, pressed) when present. */
void lua_bindings_call_mouse_button(lua_State *L, const char *button, int is_pressed);

#endif
