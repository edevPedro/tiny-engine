#include "input_map.h"

#include <GLFW/glfw3.h>

#include <stdio.h>
#include <string.h>

const char *input_map_key_name(int key) {
  static char single[2];

  if (key >= GLFW_KEY_A && key <= GLFW_KEY_Z) {
    single[0] = (char)('a' + (key - GLFW_KEY_A));
    single[1] = '\0';
    return single;
  }

  if (key >= GLFW_KEY_0 && key <= GLFW_KEY_9) {
    single[0] = (char)('0' + (key - GLFW_KEY_0));
    single[1] = '\0';
    return single;
  }

  switch (key) {
    case GLFW_KEY_LEFT:
      return "left";
    case GLFW_KEY_RIGHT:
      return "right";
    case GLFW_KEY_UP:
      return "up";
    case GLFW_KEY_DOWN:
      return "down";
    case GLFW_KEY_SPACE:
      return "space";
    case GLFW_KEY_ENTER:
      return "enter";
    case GLFW_KEY_ESCAPE:
      return "escape";
    case GLFW_KEY_LEFT_SHIFT:
    case GLFW_KEY_RIGHT_SHIFT:
      return "shift";
    case GLFW_KEY_LEFT_CONTROL:
    case GLFW_KEY_RIGHT_CONTROL:
      return "ctrl";
    case GLFW_KEY_LEFT_ALT:
    case GLFW_KEY_RIGHT_ALT:
      return "alt";
    case GLFW_KEY_TAB:
      return "tab";
    case GLFW_KEY_BACKSPACE:
      return "backspace";
    case GLFW_KEY_DELETE:
      return "x";
    default:
      return NULL;
  }
}

const char *input_map_gamepad_button_name(int idx) {
  switch (idx) {
    case GLFW_GAMEPAD_BUTTON_A:
      return "a";
    case GLFW_GAMEPAD_BUTTON_B:
      return "b";
    case GLFW_GAMEPAD_BUTTON_X:
      return "x";
    case GLFW_GAMEPAD_BUTTON_Y:
      return "y";
    case GLFW_GAMEPAD_BUTTON_LEFT_BUMPER:
      return "lb";
    case GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER:
      return "rb";
    case GLFW_GAMEPAD_BUTTON_BACK:
      return "back";
    case GLFW_GAMEPAD_BUTTON_START:
      return "start";
    case GLFW_GAMEPAD_BUTTON_GUIDE:
      return "guide";
    case GLFW_GAMEPAD_BUTTON_LEFT_THUMB:
      return "ls";
    case GLFW_GAMEPAD_BUTTON_RIGHT_THUMB:
      return "rs";
    case GLFW_GAMEPAD_BUTTON_DPAD_UP:
      return "dpad_up";
    case GLFW_GAMEPAD_BUTTON_DPAD_RIGHT:
      return "dpad_right";
    case GLFW_GAMEPAD_BUTTON_DPAD_DOWN:
      return "dpad_down";
    case GLFW_GAMEPAD_BUTTON_DPAD_LEFT:
      return "dpad_left";
    default:
      return NULL;
  }
}

const char *input_map_gamepad_axis_name(int idx) {
  switch (idx) {
    case GLFW_GAMEPAD_AXIS_LEFT_X:
      return "lx";
    case GLFW_GAMEPAD_AXIS_LEFT_Y:
      return "ly";
    case GLFW_GAMEPAD_AXIS_RIGHT_X:
      return "rx";
    case GLFW_GAMEPAD_AXIS_RIGHT_Y:
      return "ry";
    case GLFW_GAMEPAD_AXIS_LEFT_TRIGGER:
      return "lt";
    case GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER:
      return "rt";
    default:
      return NULL;
  }
}

/*
 * Joystick sem mapeamento Standard Gamepad: glfwGetJoystickButtons inclui, por defeito,
 * 4 entradas por hat no fim do array (GLFW_JOYSTICK_HAT_BUTTONS). Partimos:
 *   indices [0, physical) -> nomes estaveis b0, b1, ...
 *   indices [physical, total) -> por hat: up, right, down, left (dpad_*).
 */
const char *input_map_gamepad_generic_button_name(int index, int button_count_total, int hat_count) {
  static char name_bufs[8][16];
  static unsigned name_rot;

  if (index < 0 || button_count_total <= 0) {
    return NULL;
  }

  int hat_virtual = hat_count * 4;
  if (hat_virtual > button_count_total) {
    hat_virtual = 0;
  }
  int physical = button_count_total - hat_virtual;
  if (physical < 0) {
    physical = 0;
  }

  if (index >= physical) {
    int h = index - physical;
    int hat_idx = h / 4;
    int dir = h % 4;
    if (hat_idx < 0 || hat_idx >= hat_count) {
      return NULL;
    }
    (void)hat_idx;
    switch (dir) {
      case 0:
        return "dpad_up";
      case 1:
        return "dpad_right";
      case 2:
        return "dpad_down";
      case 3:
        return "dpad_left";
      default:
        return NULL;
    }
  }

  unsigned slot = name_rot % 8;
  name_rot += 1;
  snprintf(name_bufs[slot], sizeof(name_bufs[slot]), "b%d", index);
  return name_bufs[slot];
}

const char *input_map_gamepad_generic_axis_name(int axis_index, int axis_count) {
  static char axis_bufs[4][16];
  static unsigned axis_rot;

  (void)axis_count;

  if (axis_index < 0) {
    return NULL;
  }

  switch (axis_index) {
    case 0:
      return "lx";
    case 1:
      return "ly";
    case 2:
      return "rx";
    case 3:
      return "ry";
    case 4:
      return "lt";
    case 5:
      return "rt";
    default:
      break;
  }

  unsigned slot = axis_rot % 4;
  axis_rot += 1;
  snprintf(axis_bufs[slot], sizeof(axis_bufs[slot]), "a%d", axis_index);
  return axis_bufs[slot];
}
