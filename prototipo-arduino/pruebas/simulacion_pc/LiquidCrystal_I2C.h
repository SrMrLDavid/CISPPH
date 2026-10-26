#pragma once
#include "Arduino.h"
class LiquidCrystal_I2C { std::string l[2]; int fila = 0;
 public: LiquidCrystal_I2C(int, int, int) {} void init() {} void backlight() {}
  void clear() { l[0].clear(); l[1].clear(); }
  void setCursor(int, int f) { fila = f; }
  void print(const char *s) { l[fila] = s; if (fila == 1) std::printf("  [LCD] %-16s | %s\n", l[0].c_str(), l[1].c_str()); } };
