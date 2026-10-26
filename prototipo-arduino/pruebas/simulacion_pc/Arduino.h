// Sustituto mínimo de Arduino.h para compilar y ejecutar el sketch en un PC (NO es la API real completa).
#pragma once
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <deque>
#define HIGH 1
#define LOW 0
#define OUTPUT 1
#define INPUT_PULLUP 2
#define F(x) x
extern uint32_t g_ms; extern int g_sentido; extern std::deque<char> g_entrada;
inline void pinMode(int, int) {}
inline void digitalWrite(int, int v) { if (v == HIGH) std::printf("  [buzzer]\n"); }
inline int digitalRead(int) { return g_sentido; }
inline uint32_t millis() { return g_ms; }
inline void delay(uint32_t ms) { g_ms += ms; }
struct SerialSim {
  void begin(int) {}
  void println(const char *s) { std::printf("SERIAL> %s\n", s); }
  int available() { return (int)g_entrada.size(); }
  int read() { char c = g_entrada.front(); g_entrada.pop_front(); return c; }
};
extern SerialSim Serial;
