// Ejecuta cispph.ino en un PC con SIMULACION_SERIAL: escribe UIDs "por el monitor serie" y muestra la reacción.
#define SIMULACION_SERIAL
#include "Arduino.h"
uint32_t g_ms = 0; int g_sentido = HIGH; std::deque<char> g_entrada; SerialSim Serial;
#include "../../cispph/cispph.ino"
static void teclear(const char *t) { for (const char *p = t; *p; ++p) g_entrada.push_back(*p); g_entrada.push_back('\n'); }
int main() {
  setup();
  const char *guion[][2] = {{"E", "DEADBE01"}, {"E", "DEADBE02"}, {"S", "DEADBE02"}, {"E", "00000000"}, {"E", "00000000"}, {"E", "00000000"}, {"E", "DEADBE01"}};
  for (auto &p : guion) {
    g_sentido = p[0][0] == 'E' ? HIGH : LOW;
    std::printf("\n== %s %s\n", p[0][0] == 'E' ? "ENTRADA" : "SALIDA", p[1]);
    teclear(p[1]); loop(); g_ms += 100;
  }
  return 0;
}
