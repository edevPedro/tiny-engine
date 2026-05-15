#ifndef ENGINE_SDL_GYRO_H
#define ENGINE_SDL_GYRO_H

struct lua_State;

/** Inicializa SDL (sub-sistema gamecontroller) e tenta abrir o primeiro pad com giroscópio. */
void sdl_gyro_init(void);

/** Fecha o gamecontroller SDL e liberta o sub-sistema. */
void sdl_gyro_shutdown(void);

/**
 * Atualiza eventos SDL, (re)abre o comando se necessário e envia gyro_x/y/z (rad/s) para Lua
 * via gamepad_axis quando o sensor estiver disponível.
 */
void sdl_gyro_poll(struct lua_State *L);

#endif
