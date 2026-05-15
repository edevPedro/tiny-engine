#ifndef ENGINE_LOG_H
#define ENGINE_LOG_H

typedef enum LogLevel {
  LOG_DEBUG = 0,
  LOG_INFO,
  LOG_WARN,
  LOG_ERROR
} LogLevel;

void log_set_level(LogLevel level);
void log_message(LogLevel level, const char *file, int line, const char *fmt, ...);

#define LOGD(...) log_message(LOG_DEBUG, __FILE__, __LINE__, __VA_ARGS__)
#define LOGI(...) log_message(LOG_INFO, __FILE__, __LINE__, __VA_ARGS__)
#define LOGW(...) log_message(LOG_WARN, __FILE__, __LINE__, __VA_ARGS__)
#define LOGE(...) log_message(LOG_ERROR, __FILE__, __LINE__, __VA_ARGS__)

#endif
