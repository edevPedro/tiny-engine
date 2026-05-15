#include "joystick.h"

#include "log.h"

#include <GLFW/glfw3.h>

#include <stdio.h>
#include <string.h>

#define JOY_MAP_MAX_BUTTONS 64
#define JOY_MAP_MAX_HATS 8
#define JOY_MAP_MAX_AXES 16
#define AXIS_LOG_EPS 0.08f

static unsigned char prev_buttons[GLFW_JOYSTICK_LAST + 1][JOY_MAP_MAX_BUTTONS];
static int prev_button_count[GLFW_JOYSTICK_LAST + 1];
static int prev_valid[GLFW_JOYSTICK_LAST + 1];

static unsigned char prev_hats[GLFW_JOYSTICK_LAST + 1][JOY_MAP_MAX_HATS];
static int prev_hat_count[GLFW_JOYSTICK_LAST + 1];
static int prev_hat_valid[GLFW_JOYSTICK_LAST + 1];

static float prev_axes[GLFW_JOYSTICK_LAST + 1][JOY_MAP_MAX_AXES];
static int prev_axis_count[GLFW_JOYSTICK_LAST + 1];
static int prev_axis_valid[GLFW_JOYSTICK_LAST + 1];

static unsigned char layout_logged[GLFW_JOYSTICK_LAST + 1];

static void format_hat(unsigned char v, char *buf, size_t buf_sz) {
  if (v == GLFW_HAT_CENTERED) {
    snprintf(buf, buf_sz, "centered");
    return;
  }
  size_t n = 0;
  if (v & GLFW_HAT_UP) {
    n += (size_t)snprintf(buf + n, buf_sz - n, "up");
  }
  if (v & GLFW_HAT_RIGHT) {
    n += (size_t)snprintf(buf + n, buf_sz - n, n ? "|right" : "right");
  }
  if (v & GLFW_HAT_DOWN) {
    n += (size_t)snprintf(buf + n, buf_sz - n, n ? "|down" : "down");
  }
  if (v & GLFW_HAT_LEFT) {
    n += (size_t)snprintf(buf + n, buf_sz - n, n ? "|left" : "left");
  }
  if (n == 0) {
    snprintf(buf, buf_sz, "0x%02x", (unsigned)v);
  }
}

static void joystick_clear_prev(int jid) {
  memset(prev_buttons[jid], 0, sizeof(prev_buttons[jid]));
  prev_button_count[jid] = 0;
  prev_valid[jid] = 0;
  memset(prev_hats[jid], 0, sizeof(prev_hats[jid]));
  prev_hat_count[jid] = 0;
  prev_hat_valid[jid] = 0;
  memset(prev_axes[jid], 0, sizeof(prev_axes[jid]));
  prev_axis_count[jid] = 0;
  prev_axis_valid[jid] = 0;
  layout_logged[jid] = 0;
}

static void joystick_event_callback(int jid, int event) {
  if (event == GLFW_CONNECTED) {
    const char *name = glfwGetJoystickName(jid);
    int is_gamepad = glfwJoystickIsGamepad(jid);
    LOGI("joystick connected: jid=%d name=%s gamepad=%s", jid, name ? name : "(null)",
         is_gamepad ? "yes" : "no");
    joystick_clear_prev(jid);
  } else if (event == GLFW_DISCONNECTED) {
    LOGI("joystick disconnected: jid=%d", jid);
    joystick_clear_prev(jid);
  }
}

void joystick_register_callbacks(void) {
  glfwSetJoystickCallback(joystick_event_callback);
  int found = 0;
  for (int jid = GLFW_JOYSTICK_1; jid <= GLFW_JOYSTICK_LAST; ++jid) {
    if (!glfwJoystickPresent(jid)) {
      continue;
    }
    found += 1;
    const char *name = glfwGetJoystickName(jid);
    int is_gamepad = glfwJoystickIsGamepad(jid);
    LOGI("joystick already present: jid=%d name=%s gamepad=%s", jid, name ? name : "(null)",
         is_gamepad ? "yes" : "no");
    joystick_clear_prev(jid);
  }
#if defined(__APPLE__)
  if (found == 0) {
    LOGW("GLFW nao enumerou nenhum joystick. No macOS 13+, isso costuma ser permissao "
         "Input Monitoring (Ajustes > Privacidade e Seguranca > Monitoramento de Entrada): "
         "adicione Terminal, Cursor ou build/bin/engine. O navegador usa outra API e pode "
         "funcionar mesmo quando GLFW/IOHID nao ve o controle.");
  }
#endif
}

void joystick_poll_mapping_log(void) {
  for (int jid = GLFW_JOYSTICK_1; jid <= GLFW_JOYSTICK_LAST; ++jid) {
    if (!glfwJoystickPresent(jid)) {
      joystick_clear_prev(jid);
      continue;
    }

    /* Controles com mapeamento gamepad: logs legíveis vêm de poll_gamepad (engine.c). */
    if (glfwJoystickIsGamepad(jid)) {
      continue;
    }

    const char *dev = glfwGetJoystickName(jid);

    if (!layout_logged[jid]) {
      int ac = 0;
      int hc = 0;
      int bc = 0;
      glfwGetJoystickAxes(jid, &ac);
      glfwGetJoystickHats(jid, &hc);
      glfwGetJoystickButtons(jid, &bc);
      LOGI("joystick layout \"%s\" jid=%d axes=%d hats=%d buttons=%d (D-pad pode ser eixos "
           "extras ou ultimos 4*hats indices em buttons)",
           dev ? dev : "(null)", jid, ac, hc, bc);
      layout_logged[jid] = 1;
    }

    int axis_count = 0;
    const float *axes = glfwGetJoystickAxes(jid, &axis_count);
    if (axes && axis_count > 0) {
      if (axis_count > JOY_MAP_MAX_AXES) {
        axis_count = JOY_MAP_MAX_AXES;
      }
      if (!prev_axis_valid[jid] || prev_axis_count[jid] != axis_count) {
        memcpy(prev_axes[jid], axes, (size_t)axis_count * sizeof(float));
        prev_axis_count[jid] = axis_count;
        prev_axis_valid[jid] = 1;
      } else {
        for (int a = 0; a < axis_count; ++a) {
          float dv = axes[a] - prev_axes[jid][a];
          if (dv < 0.0f) {
            dv = -dv;
          }
          if (dv >= AXIS_LOG_EPS) {
            LOGI("joystick (axis) \"%s\" jid=%d axis_index=%d value=%.4f", dev ? dev : "(null)", jid, a,
                 axes[a]);
          }
        }
        memcpy(prev_axes[jid], axes, (size_t)axis_count * sizeof(float));
      }
    }

    int hat_count = 0;
    const unsigned char *hats = glfwGetJoystickHats(jid, &hat_count);
    if (hats && hat_count > 0) {
      if (hat_count > JOY_MAP_MAX_HATS) {
        hat_count = JOY_MAP_MAX_HATS;
      }
      if (!prev_hat_valid[jid] || prev_hat_count[jid] != hat_count) {
        memcpy(prev_hats[jid], hats, (size_t)hat_count);
        prev_hat_count[jid] = hat_count;
        prev_hat_valid[jid] = 1;
      } else {
        for (int h = 0; h < hat_count; ++h) {
          if (hats[h] != prev_hats[jid][h]) {
            char label[48];
            format_hat(hats[h], label, sizeof(label));
            LOGI("joystick (hat) \"%s\" jid=%d hat_index=%d %s (0x%02x)", dev ? dev : "(null)", jid, h,
                 label, (unsigned)hats[h]);
          }
        }
        memcpy(prev_hats[jid], hats, (size_t)hat_count);
      }
    }

    int count = 0;
    const unsigned char *buttons = glfwGetJoystickButtons(jid, &count);
    if (!buttons || count <= 0) {
      continue;
    }
    if (count > JOY_MAP_MAX_BUTTONS) {
      count = JOY_MAP_MAX_BUTTONS;
    }

    if (!prev_valid[jid] || prev_button_count[jid] != count) {
      memcpy(prev_buttons[jid], buttons, (size_t)count);
      prev_button_count[jid] = count;
      prev_valid[jid] = 1;
      continue;
    }

    for (int i = 0; i < count; ++i) {
      if (buttons[i] != prev_buttons[jid][i]) {
        LOGI("joystick (raw) \"%s\" jid=%d button_index=%d %s", dev ? dev : "(null)", jid, i,
             buttons[i] == GLFW_PRESS ? "press" : "release");
      }
    }
    memcpy(prev_buttons[jid], buttons, (size_t)count);
  }
}
