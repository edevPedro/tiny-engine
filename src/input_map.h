#ifndef ENGINE_INPUT_MAP_H
#define ENGINE_INPUT_MAP_H

/** @brief Maps GLFW keyboard key to engine/Lua key name. */
const char *input_map_key_name(int key);
/** @brief Maps GLFW gamepad button index to engine/Lua name. */
const char *input_map_gamepad_button_name(int idx);
/** @brief Maps GLFW gamepad axis index to engine/Lua name. */
const char *input_map_gamepad_axis_name(int idx);

/**
 * @brief Nomes para joystick bruto (sem Standard Gamepad).
 * @param index Indice em glfwGetJoystickButtons (0 .. button_count_total-1).
 * @param button_count_total Valor devolvido por glfwGetJoystickButtons (inclui 4*hat_count se
 *        GLFW_JOYSTICK_HAT_BUTTONS estiver ativo).
 * @param hat_count Valor devolvido por glfwGetJoystickHats.
 * @return dpad_* para porcoes virtuais do hat; caso contrario b0, b1, ...
 */
const char *input_map_gamepad_generic_button_name(int index, int button_count_total, int hat_count);

/**
 * @brief Nomes para eixos de joystick bruto: lx..rt para 0..5; depois a6, a7, ...
 * @param axis_count Total de eixos (informativo; pode ser 0).
 */
const char *input_map_gamepad_generic_axis_name(int axis_index, int axis_count);

#endif
