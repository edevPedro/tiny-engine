#include "renderer.h"

#include "log.h"

#include <glad/gl.h>

#include <math.h>

#include <spng.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-macro-identifier"
#endif
#include <khash.h>
#if defined(__clang__)
#pragma clang diagnostic pop
#endif

typedef struct Texture {
  GLuint id;
  int width;
  int height;
} Texture;

KHASH_MAP_INIT_STR(texmap, Texture)

struct Renderer {
  int width;
  int height;
  GLuint solid_program;
  GLuint texture_program;
  GLuint solid3d_program;
  GLuint vbo;
  float projection[16];
  khash_t(texmap) *textures;

  int has_3d;
  float cam_x, cam_y, cam_z;
  float cam_yaw, cam_pitch;
  float cam_fov, cam_near, cam_far;
  float view_proj[16];
};

enum {
  ATTR_POS = 0,
  ATTR_UV = 1,
};

static const char *k_solid_vert =
    "#version 120\n"
    "attribute vec2 a_pos;\n"
    "uniform mat4 u_proj;\n"
    "void main() {\n"
    "  gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);\n"
    "}\n";

static const char *k_solid_frag =
    "#version 120\n"
    "uniform vec4 u_color;\n"
    "void main() {\n"
    "  gl_FragColor = u_color;\n"
    "}\n";

static const char *k_texture_vert =
    "#version 120\n"
    "attribute vec2 a_pos;\n"
    "attribute vec2 a_uv;\n"
    "varying vec2 v_uv;\n"
    "uniform mat4 u_proj;\n"
    "void main() {\n"
    "  v_uv = a_uv;\n"
    "  gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);\n"
    "}\n";

static const char *k_texture_frag =
    "#version 120\n"
    "varying vec2 v_uv;\n"
    "uniform sampler2D u_tex;\n"
    "void main() {\n"
    "  gl_FragColor = texture2D(u_tex, v_uv);\n"
    "}\n";

static const char *k_solid3d_vert =
    "#version 120\n"
    "attribute vec3 a_pos;\n"
    "uniform mat4 u_mvp;\n"
    "void main() {\n"
    "  gl_Position = u_mvp * vec4(a_pos, 1.0);\n"
    "}\n";

static const char *k_solid3d_frag =
    "#version 120\n"
    "uniform vec4 u_color;\n"
    "void main() {\n"
    "  gl_FragColor = u_color;\n"
    "}\n";

static GLuint compile_shader(GLenum type, const char *src) {
  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &src, NULL);
  glCompileShader(shader);

  GLint ok = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char buffer[1024];
    GLsizei len = 0;
    glGetShaderInfoLog(shader, (GLsizei)sizeof(buffer), &len, buffer);
    LOGE("Shader compile failed: %.*s", (int)len, buffer);
    glDeleteShader(shader);
    return 0;
  }
  return shader;
}

static GLuint link_program(const char *vert_src, const char *frag_src, int textured) {
  GLuint vs = compile_shader(GL_VERTEX_SHADER, vert_src);
  GLuint fs = compile_shader(GL_FRAGMENT_SHADER, frag_src);
  if (!vs || !fs) {
    if (vs) {
      glDeleteShader(vs);
    }
    if (fs) {
      glDeleteShader(fs);
    }
    return 0;
  }

  GLuint program = glCreateProgram();
  glAttachShader(program, vs);
  glAttachShader(program, fs);
  glBindAttribLocation(program, ATTR_POS, "a_pos");
  if (textured) {
    glBindAttribLocation(program, ATTR_UV, "a_uv");
  }
  glLinkProgram(program);

  glDeleteShader(vs);
  glDeleteShader(fs);

  GLint ok = 0;
  glGetProgramiv(program, GL_LINK_STATUS, &ok);
  if (!ok) {
    char buffer[1024];
    GLsizei len = 0;
    glGetProgramInfoLog(program, (GLsizei)sizeof(buffer), &len, buffer);
    LOGE("Program link failed: %.*s", (int)len, buffer);
    glDeleteProgram(program);
    return 0;
  }
  return program;
}

static void build_ortho(float out[16], float width, float height) {
  memset(out, 0, sizeof(float) * 16);
  out[0] = 2.0f / width;
  out[5] = -2.0f / height;
  out[10] = -1.0f;
  out[12] = -1.0f;
  out[13] = 1.0f;
  out[15] = 1.0f;
}

static void build_perspective(float out[16], float fov_deg, float aspect, float near, float far) {
  memset(out, 0, sizeof(float) * 16);
  float f = 1.0f / tanf(fov_deg * 0.5f * 3.14159265f / 180.0f);
  out[0] = f / aspect;
  out[5] = f;
  out[10] = (far + near) / (near - far);
  out[11] = -1.0f;
  out[14] = (2.0f * far * near) / (near - far);
}

static void build_lookat(float out[16], float ex, float ey, float ez, float tx, float ty, float tz, float ux, float uy, float uz) {
  float zx = ex - tx, zy = ey - ty, zz = ez - tz;
  float zl = sqrtf(zx * zx + zy * zy + zz * zz);
  if (zl > 0.0001f) { zx /= zl; zy /= zl; zz /= zl; }
  float xx = uy * zz - uz * zy;
  float xy = uz * zx - ux * zz;
  float xz = ux * zy - uy * zx;
  float xl = sqrtf(xx * xx + xy * xy + xz * xz);
  if (xl > 0.0001f) { xx /= xl; xy /= xl; xz /= xl; }
  float yx = zy * xz - zz * xy;
  float yy = zz * xx - zx * xz;
  float yz = zx * xy - zy * xx;
  out[0] = xx; out[1] = yx; out[2] = zx; out[3] = 0.0f;
  out[4] = xy; out[5] = yy; out[6] = zy; out[7] = 0.0f;
  out[8] = xz; out[9] = yz; out[10] = zz; out[11] = 0.0f;
  out[12] = -(xx * ex + xy * ey + xz * ez);
  out[13] = -(yx * ex + yy * ey + yz * ez);
  out[14] = -(zx * ex + zy * ey + zz * ez);
  out[15] = 1.0f;
}

static void multiply_mvp(float out[16], const float a[16], const float b[16]) {
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      float sum = 0.0f;
      for (int k = 0; k < 4; k++) sum += a[k * 4 + j] * b[i * 4 + k];
      out[i * 4 + j] = sum;
    }
  }
}

/** clip = MVP * (x,y,z,w); mesmo layout column-major que glUniformMatrix4fv no solid3d. */
static void mat4_mul_vec4_mvp(const float m[16], float x, float y, float z, float w, float clip[4]) {
  clip[0] = m[0] * x + m[4] * y + m[8] * z + m[12] * w;
  clip[1] = m[1] * x + m[5] * y + m[9] * z + m[13] * w;
  clip[2] = m[2] * x + m[6] * y + m[10] * z + m[14] * w;
  clip[3] = m[3] * x + m[7] * y + m[11] * z + m[15] * w;
}

static int load_png_texture(const char *path, Texture *out) {
  FILE *fp = fopen(path, "rb");
  if (!fp) {
    LOGE("Could not open PNG: %s", path);
    return 0;
  }

  spng_ctx *ctx = spng_ctx_new(0);
  if (!ctx) {
    fclose(fp);
    return 0;
  }

  int rc = spng_set_png_file(ctx, fp);
  if (rc != 0) {
    spng_ctx_free(ctx);
    fclose(fp);
    return 0;
  }

  struct spng_ihdr ihdr;
  rc = spng_get_ihdr(ctx, &ihdr);
  if (rc != 0) {
    spng_ctx_free(ctx);
    fclose(fp);
    return 0;
  }

  size_t image_size = 0;
  rc = spng_decoded_image_size(ctx, SPNG_FMT_RGBA8, &image_size);
  if (rc != 0) {
    spng_ctx_free(ctx);
    fclose(fp);
    return 0;
  }

  void *pixels = malloc(image_size);
  if (!pixels) {
    spng_ctx_free(ctx);
    fclose(fp);
    return 0;
  }

  rc = spng_decode_image(ctx, pixels, image_size, SPNG_FMT_RGBA8, 0);
  if (rc != 0) {
    free(pixels);
    spng_ctx_free(ctx);
    fclose(fp);
    return 0;
  }

  GLuint id = 0;
  glGenTextures(1, &id);
  glBindTexture(GL_TEXTURE_2D, id);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexImage2D(GL_TEXTURE_2D,
               0,
               GL_RGBA,
               (GLsizei)ihdr.width,
               (GLsizei)ihdr.height,
               0,
               GL_RGBA,
               GL_UNSIGNED_BYTE,
               pixels);
  glBindTexture(GL_TEXTURE_2D, 0);

  free(pixels);
  spng_ctx_free(ctx);
  fclose(fp);

  out->id = id;
  out->width = (int)ihdr.width;
  out->height = (int)ihdr.height;
  return 1;
}

static char *dup_string(const char *src) {
  size_t len = strlen(src);
  char *dst = (char *)malloc(len + 1);
  if (!dst) {
    return NULL;
  }
  memcpy(dst, src, len + 1);
  return dst;
}

static Texture *get_or_load_texture(Renderer *r, const char *path) {
  khint_t k = kh_get(texmap, r->textures, path);
  if (k != kh_end(r->textures)) {
    return &kh_value(r->textures, k);
  }

  Texture tex;
  if (!load_png_texture(path, &tex)) {
    return NULL;
  }

  int ret = 0;
  char *dup = dup_string(path);
  if (!dup) {
    glDeleteTextures(1, &tex.id);
    return NULL;
  }

  k = kh_put(texmap, r->textures, dup, &ret);
  if (ret < 0) {
    free(dup);
    glDeleteTextures(1, &tex.id);
    return NULL;
  }
  kh_value(r->textures, k) = tex;
  return &kh_value(r->textures, k);
}

Renderer *renderer_create(int screen_width, int screen_height) {
  Renderer *r = (Renderer *)calloc(1, sizeof(*r));
  if (!r) {
    return NULL;
  }

  r->width = screen_width;
  r->height = screen_height;
  build_ortho(r->projection, (float)screen_width, (float)screen_height);

  r->solid_program = link_program(k_solid_vert, k_solid_frag, 0);
  r->texture_program = link_program(k_texture_vert, k_texture_frag, 1);
  r->solid3d_program = link_program(k_solid3d_vert, k_solid3d_frag, 0);
  if (!r->solid_program || !r->texture_program || !r->solid3d_program) {
    renderer_destroy(r);
    return NULL;
  }

  glGenBuffers(1, &r->vbo);
  r->textures = kh_init(texmap);
  if (!r->textures) {
    renderer_destroy(r);
    return NULL;
  }

  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  return r;
}

void renderer_destroy(Renderer *r) {
  if (!r) {
    return;
  }

  if (r->textures) {
    for (khint_t k = kh_begin(r->textures); k != kh_end(r->textures); ++k) {
      if (!kh_exist(r->textures, k)) {
        continue;
      }
      Texture *t = &kh_value(r->textures, k);
      glDeleteTextures(1, &t->id);
      free((char *)kh_key(r->textures, k));
    }
    kh_destroy(texmap, r->textures);
  }

  if (r->vbo) {
    glDeleteBuffers(1, &r->vbo);
  }
  if (r->solid_program) {
    glDeleteProgram(r->solid_program);
  }
  if (r->texture_program) {
    glDeleteProgram(r->texture_program);
  }
  if (r->solid3d_program) {
    glDeleteProgram(r->solid3d_program);
  }

  free(r);
}

void renderer_begin_frame(Renderer *r) {
  (void)r;
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LESS);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  r->has_3d = 0;
}

void renderer_begin_2d(Renderer *r) {
  (void)r;
  /* Overlay 2D: sem teste de profundidade — senão o chão 3D bloqueia HUD/armas (z-buffer). */
  glDisable(GL_DEPTH_TEST);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

void renderer_draw_rect_color(Renderer *r,
                              float x,
                              float y,
                              float w,
                              float h,
                              float red,
                              float green,
                              float blue,
                              float alpha) {
  const float verts[] = {
      x, y, x + w, y, x + w, y + h,
      x, y, x + w, y + h, x, y + h,
  };

  glUseProgram(r->solid_program);
  GLint proj_loc = glGetUniformLocation(r->solid_program, "u_proj");
  GLint color_loc = glGetUniformLocation(r->solid_program, "u_color");
  glUniformMatrix4fv(proj_loc, 1, GL_FALSE, r->projection);
  glUniform4f(color_loc, red, green, blue, alpha);

  glBindBuffer(GL_ARRAY_BUFFER, r->vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

  glEnableVertexAttribArray(ATTR_POS);
  glVertexAttribPointer(ATTR_POS, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 2, (const void *)0);
  glDrawArrays(GL_TRIANGLES, 0, 6);
  glDisableVertexAttribArray(ATTR_POS);

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glUseProgram(0);
}

void renderer_draw_rect(Renderer *r, float x, float y, float w, float h) {
  renderer_draw_rect_color(r, x, y, w, h, 1.0f, 1.0f, 1.0f, 1.0f);
}

void renderer_draw_png(Renderer *r, float x, float y, const char *path) {
  Texture *t = get_or_load_texture(r, path);
  if (!t) {
    return;
  }

  const float x2 = x + (float)t->width;
  const float y2 = y + (float)t->height;

  const float verts[] = {
      x, y, 0.0f, 0.0f, x2, y, 1.0f, 0.0f, x2, y2, 1.0f, 1.0f,
      x, y, 0.0f, 0.0f, x2, y2, 1.0f, 1.0f, x, y2, 0.0f, 1.0f,
  };

  glUseProgram(r->texture_program);
  GLint proj_loc = glGetUniformLocation(r->texture_program, "u_proj");
  GLint tex_loc = glGetUniformLocation(r->texture_program, "u_tex");
  glUniformMatrix4fv(proj_loc, 1, GL_FALSE, r->projection);
  glUniform1i(tex_loc, 0);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, t->id);

  glBindBuffer(GL_ARRAY_BUFFER, r->vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

  glEnableVertexAttribArray(ATTR_POS);
  glVertexAttribPointer(ATTR_POS,
                        2,
                        GL_FLOAT,
                        GL_FALSE,
                        sizeof(float) * 4,
                        (const void *)(0 * sizeof(float)));

  glEnableVertexAttribArray(ATTR_UV);
  glVertexAttribPointer(ATTR_UV,
                        2,
                        GL_FLOAT,
                        GL_FALSE,
                        sizeof(float) * 4,
                        (const void *)(2 * sizeof(float)));

  glDrawArrays(GL_TRIANGLES, 0, 6);

  glDisableVertexAttribArray(ATTR_POS);
  glDisableVertexAttribArray(ATTR_UV);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glUseProgram(0);
}

void renderer_set_camera_3d(Renderer *r, float x, float y, float z, float yaw, float pitch, float fov_deg) {
  r->has_3d = 1;
  r->cam_x = x;
  r->cam_y = y;
  r->cam_z = z;
  r->cam_yaw = yaw;
  r->cam_pitch = pitch;
  r->cam_fov = fov_deg;
  r->cam_near = 0.1f;
  r->cam_far = 500.0f;

  float proj[16];
  float aspect = (float)r->width / (float)r->height;
  build_perspective(proj, fov_deg, aspect, r->cam_near, r->cam_far);

  float cz = cosf(pitch);
  float sz = sinf(pitch);
  float cy = cosf(yaw);
  float sy = sinf(yaw);
  float tx = x + cz * sy;
  float ty = y + sz;
  float tz = z + cz * cy;

  float view[16];
  build_lookat(view, x, y, z, tx, ty, tz, 0.0f, 1.0f, 0.0f);

  multiply_mvp(r->view_proj, proj, view);
}

void renderer_draw_png_3d(Renderer *r, float x, float y, float z, const char *path, float size) {
  if (!r->has_3d) {
    return;
  }

  Texture *t = get_or_load_texture(r, path);
  if (!t) {
    return;
  }

  float clip[4];
  mat4_mul_vec4_mvp(r->view_proj, x, y, z, 1.0f, clip);
  if (clip[3] <= 0.0f) {
    return;
  }

  float invw = 1.0f / clip[3];
  float ndc_x = clip[0] * invw;
  float ndc_y = clip[1] * invw;
  float sx = (ndc_x * 0.5f + 0.5f) * (float)r->width;
  float sy_screen = (1.0f - ndc_y) * 0.5f * (float)r->height;

  float dx = x - r->cam_x;
  float dy = y - r->cam_y;
  float dz = z - r->cam_z;
  float cp = cosf(r->cam_pitch);
  float sp = sinf(r->cam_pitch);
  float cy = cosf(r->cam_yaw);
  float sy = sinf(r->cam_yaw);
  float fwd_x = cp * sy;
  float fwd_y = sp;
  float fwd_z = cp * cy;
  float z_eye = dx * fwd_x + dy * fwd_y + dz * fwd_z;
  if (z_eye <= 0.05f) {
    return;
  }

  float f = 1.0f / tanf(r->cam_fov * 0.5f * 3.14159265f / 180.0f);
  float scale = size * f / z_eye;
  if (scale < 0.02f) {
    return;
  }

  float w = (float)t->width * scale;
  float h = (float)t->height * scale;
  float x0 = sx - w * 0.5f;
  float y0 = sy_screen - h * 0.5f;
  float x1 = x0 + w;
  float y1 = y0 + h;

  const float verts[] = {
      x0, y0, 0.0f, 0.0f,
      x1, y0, 1.0f, 0.0f,
      x1, y1, 1.0f, 1.0f,
      x0, y0, 0.0f, 0.0f,
      x1, y1, 1.0f, 1.0f,
      x0, y1, 0.0f, 1.0f,
  };

  glDisable(GL_DEPTH_TEST);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  glUseProgram(r->texture_program);
  GLint proj_loc = glGetUniformLocation(r->texture_program, "u_proj");
  GLint tex_loc = glGetUniformLocation(r->texture_program, "u_tex");
  glUniformMatrix4fv(proj_loc, 1, GL_FALSE, r->projection);
  glUniform1i(tex_loc, 0);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, t->id);

  glBindBuffer(GL_ARRAY_BUFFER, r->vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

  glEnableVertexAttribArray(ATTR_POS);
  glVertexAttribPointer(ATTR_POS,
                        2,
                        GL_FLOAT,
                        GL_FALSE,
                        sizeof(float) * 4,
                        (const void *)(0 * sizeof(float)));

  glEnableVertexAttribArray(ATTR_UV);
  glVertexAttribPointer(ATTR_UV,
                        2,
                        GL_FLOAT,
                        GL_FALSE,
                        sizeof(float) * 4,
                        (const void *)(2 * sizeof(float)));

  glDrawArrays(GL_TRIANGLES, 0, 6);

  glDisableVertexAttribArray(ATTR_POS);
  glDisableVertexAttribArray(ATTR_UV);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glUseProgram(0);
}

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
                           float alpha) {
  if (!r->has_3d) {
    return;
  }

  const float verts[] = {
      x1, y1, z1,
      x2, y2, z2,
      x3, y3, z3,
      x1, y1, z1,
      x3, y3, z3,
      x4, y4, z4,
  };

  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LESS);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  glUseProgram(r->solid3d_program);
  GLint mvp_loc = glGetUniformLocation(r->solid3d_program, "u_mvp");
  GLint color_loc = glGetUniformLocation(r->solid3d_program, "u_color");
  glUniformMatrix4fv(mvp_loc, 1, GL_FALSE, r->view_proj);
  glUniform4f(color_loc, red, green, blue, alpha);

  glBindBuffer(GL_ARRAY_BUFFER, r->vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

  glEnableVertexAttribArray(ATTR_POS);
  glVertexAttribPointer(ATTR_POS, 3, GL_FLOAT, GL_FALSE, sizeof(float) * 3, (const void *)0);
  glDrawArrays(GL_TRIANGLES, 0, 6);
  glDisableVertexAttribArray(ATTR_POS);

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glUseProgram(0);
}
