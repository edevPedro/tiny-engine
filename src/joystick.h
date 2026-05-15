#ifndef ENGINE_JOYSTICK_H
#define ENGINE_JOYSTICK_H

void joystick_register_callbacks(void);

/** Raw buttons + hats (D-pad POV); call each frame after glfwPollEvents. */
void joystick_poll_mapping_log(void);

#endif
