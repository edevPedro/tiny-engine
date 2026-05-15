#include "input_map.h"

#include <assert.h>
#include <string.h>

#include <GLFW/glfw3.h>

int main(void) {
  const char *k;

  k = input_map_key_name(GLFW_KEY_A);
  assert(k != NULL && strcmp(k, "a") == 0);

  k = input_map_key_name(GLFW_KEY_9);
  assert(k != NULL && strcmp(k, "9") == 0);

  k = input_map_key_name(GLFW_KEY_LEFT);
  assert(k != NULL && strcmp(k, "left") == 0);

  k = input_map_key_name(GLFW_KEY_F1);
  assert(k == NULL);

  k = input_map_gamepad_button_name(GLFW_GAMEPAD_BUTTON_A);
  assert(k != NULL && strcmp(k, "a") == 0);

  k = input_map_gamepad_axis_name(GLFW_GAMEPAD_AXIS_LEFT_X);
  assert(k != NULL && strcmp(k, "lx") == 0);

  k = input_map_gamepad_generic_button_name(0, 14, 1);
  assert(k != NULL && strcmp(k, "b0") == 0);
  k = input_map_gamepad_generic_button_name(10, 14, 1);
  assert(k != NULL && strcmp(k, "dpad_up") == 0);
  k = input_map_gamepad_generic_button_name(11, 14, 1);
  assert(k != NULL && strcmp(k, "dpad_right") == 0);

  k = input_map_gamepad_generic_axis_name(0, 4);
  assert(k != NULL && strcmp(k, "lx") == 0);
  k = input_map_gamepad_generic_axis_name(7, 8);
  assert(k != NULL && strcmp(k, "a7") == 0);

  return 0;
}
