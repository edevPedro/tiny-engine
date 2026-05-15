#include "log.h"

#include <stdarg.h>
#include <stdio.h>

static LogLevel g_min_level = LOG_INFO;

void log_set_level(LogLevel level) { g_min_level = level; }

void log_message(LogLevel level, const char *file, int line, const char *fmt, ...) {
  static const char *names[] = {"DEBUG", "INFO", "WARN", "ERROR"};
  static const char *colors[] = {
      "\x1b[90m", "\x1b[36m", "\x1b[33m", "\x1b[31m",
  };
  const char *reset = "\x1b[0m";

  if (level < g_min_level) {
    return;
  }

  fprintf(stderr, "%s[%s]%s %s:%d ", colors[level], names[level], reset, file, line);

  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);

  fputc('\n', stderr);
}
