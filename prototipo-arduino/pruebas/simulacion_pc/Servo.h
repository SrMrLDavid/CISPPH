#pragma once
#include "Arduino.h"
class Servo { public: void attach(int) {} void write(int a) { std::printf("  [servo] %d grados\n", a); } };
