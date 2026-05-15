#ifndef ENGINE_RENDERER_H
#define ENGINE_RENDERER_H

/** @brief Opaque renderer handle. */
typedef struct Renderer Renderer;

/** @brief Creates renderer resources for a fixed screen size. */
Renderer *renderer_create(int screen_width, int screen_height);
/** @brief Destroys renderer resources. */
void renderer_destroy(Renderer *r);

/** @brief Starts a frame by clearing render target. */
void renderer_begin_frame(Renderer *r);
/** @brief Draws a solid white rectangle. */
void renderer_draw_rect(Renderer *r, float x, float y, float w, float h);
/** @brief Draws a solid RGBA rectangle. */
void renderer_draw_rect_color(Renderer *r,
                              float x,
                              float y,
                              float w,
                              float h,
                              float red,
                              float green,
                              float blue,
                              float alpha);
/** @brief Draws a PNG at native size. */
void renderer_draw_png(Renderer *r, float x, float y, const char *path);

/** @brief Switches to 2D orthographic mode (disables depth test, enables blending). */
void renderer_begin_2d(Renderer *r);

/** @brief Sets 3D camera parameters used by sprite3d rendering. */
void renderer_set_camera_3d(Renderer *r,
                            float x,
                            float y,
                            float z,
                            float yaw,
                            float pitch,
                            float fov_deg);

/** @brief Draws a billboard PNG sprite in 3D world space. */
void renderer_draw_png_3d(Renderer *r, float x, float y, float z, const char *path, float size);

/** @brief Draws a colored 3D quad using 4 points. */
void renderer_draw_quad_3d(Renderer *r,
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
                           float alpha);

#endif
