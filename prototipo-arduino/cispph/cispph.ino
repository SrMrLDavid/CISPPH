/**
 * C.I.S.P.P.H. — Prototipo de garita con Arduino UNO.
 *
 * Funciones: lee una tarjeta RFID (MFRC522), consulta las reglas de cispph_core.h,
 * abre una pluma con un servo, muestra el resultado en una LCD I2C 16x2, avisa con un
 * buzzer y emite cada movimiento por el puerto serie como línea CSV.
 *
 * Sentido del movimiento: interruptor en SENTIDO_PIN (HIGH = ENTRADA, LOW = SALIDA).
 *
 * Modo sin lector: descomente SIMULACION_SERIAL para escribir el UID (8 dígitos hex) por el
 * monitor serie. Sirve para probar la lógica sin el MFRC522 (p. ej. en un simulador en línea).
 *
 * Librerías (Gestor de bibliotecas): MFRC522 (Miguel Balboa), LiquidCrystal I2C (Frank de
 * Brabander), Servo (incluida con el IDE).
 * Estado: la lógica de reglas está probada en PC; este sketch NO se ha probado en hardware.
 */
// #define SIMULACION_SERIAL

#include <Servo.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "cispph_core.h"
#ifndef SIMULACION_SERIAL
#include <SPI.h>
#include <MFRC522.h>
#endif

using namespace cispph;

// ---- Pines --------------------------------------------------------------------------------
const uint8_t PIN_SERVO = 9;
const uint8_t PIN_BUZZER = 8;
const uint8_t PIN_SENTIDO = 4;   // interruptor con resistencia interna a positivo
const uint8_t PIN_RST = 7;
const uint8_t PIN_SS = 10;       // MOSI 11, MISO 12, SCK 13 (SPI de hardware)

// ---- Parámetros ----------------------------------------------------------------------------
const uint8_t ANGULO_CERRADO = 0;
const uint8_t ANGULO_ABIERTO = 90;
const uint16_t TIEMPO_ABIERTO_MS = 3000;
const uint8_t PUESTOS_VISITANTES = 5;
const uint32_t BLOQUEO_MS = 30000;

// ---- Objetos --------------------------------------------------------------------------------
Servo pluma;
LiquidCrystal_I2C lcd(0x27, 16, 2);   // algunas pantallas usan la dirección 0x3F
ControlAcceso control(PUESTOS_VISITANTES, BLOQUEO_MS);
#ifndef SIMULACION_SERIAL
MFRC522 lector(PIN_SS, PIN_RST);
#endif

// Tarjetas de ejemplo (UID ficticios). Reemplácelos por los de sus tarjetas.
const uint8_t UID_RESIDENTE[LONG_UID] = {0xDE, 0xAD, 0xBE, 0x01};
const uint8_t UID_VISITANTE[LONG_UID] = {0xDE, 0xAD, 0xBE, 0x02};
const uint8_t UID_VIP[LONG_UID] = {0xDE, 0xAD, 0xBE, 0x03};

void pitar(uint8_t veces, uint16_t ms) {
  for (uint8_t i = 0; i < veces; ++i) {
    digitalWrite(PIN_BUZZER, HIGH); delay(ms);
    digitalWrite(PIN_BUZZER, LOW); delay(ms);
  }
}

void mostrar(const char *l1, const char *l2) {
  lcd.clear(); lcd.setCursor(0, 0); lcd.print(l1);
  lcd.setCursor(0, 1); lcd.print(l2);
}

void pantallaEspera() {
  char l2[17];
  snprintf(l2, sizeof l2, "Visit. %u/%u", control.visitantes_ocupados(), control.puestos_visitantes());
  mostrar("Acerque tarjeta", l2);
}

void procesar(const uint8_t uid[LONG_UID]) {
  Sentido s = digitalRead(PIN_SENTIDO) == HIGH ? Sentido::ENTRADA : Sentido::SALIDA;
  uint32_t ahora = millis();
  Resultado r = control.evaluar(uid, s, ahora);

  char csv[64];
  ControlAcceso::linea_csv(csv, sizeof csv, ahora, uid, s, r);
  Serial.println(csv);                       // bitácora: ms,uid,sentido,decision,categoria,ocupados

  mostrar(ControlAcceso::texto(r.decision), ControlAcceso::texto(r.categoria));
  if (r.decision == Decision::AUTORIZADO) {
    pitar(1, 120);
    pluma.write(ANGULO_ABIERTO);
    delay(TIEMPO_ABIERTO_MS);
    pluma.write(ANGULO_CERRADO);
  } else {
    pitar(3, 120);
    delay(1500);
  }
  pantallaEspera();
}

void setup() {
  Serial.begin(9600);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_SENTIDO, INPUT_PULLUP);
  pluma.attach(PIN_SERVO); pluma.write(ANGULO_CERRADO);
  lcd.init(); lcd.backlight();
#ifndef SIMULACION_SERIAL
  SPI.begin(); lector.PCD_Init();
#endif
  control.registrar(UID_RESIDENTE, Categoria::NO_VIP);
  control.registrar(UID_VISITANTE, Categoria::VIS);
  control.registrar(UID_VIP, Categoria::VIP);
  Serial.println(F("ms,uid,sentido,decision,categoria,visitantes_ocupados"));
  pantallaEspera();
}

#ifdef SIMULACION_SERIAL
// Lee 8 dígitos hexadecimales (p. ej. DEADBE01) seguidos de salto de línea.
bool leerUid(uint8_t uid[LONG_UID]) {
  static char buf[9]; static uint8_t n = 0;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      bool ok = (n == 8); n = 0;
      if (!ok) return false;
      for (uint8_t i = 0; i < LONG_UID; ++i) {
        char par[3] = {buf[2 * i], buf[2 * i + 1], 0};
        uid[i] = (uint8_t)strtol(par, nullptr, 16);
      }
      return true;
    }
    if (n < 8) buf[n++] = c;
  }
  return false;
}
#else
bool leerUid(uint8_t uid[LONG_UID]) {
  if (!lector.PICC_IsNewCardPresent() || !lector.PICC_ReadCardSerial()) return false;
  if (lector.uid.size < LONG_UID) { lector.PICC_HaltA(); return false; }
  for (uint8_t i = 0; i < LONG_UID; ++i) uid[i] = lector.uid.uidByte[i];
  lector.PICC_HaltA();
  return true;
}
#endif

void loop() {
  uint8_t uid[LONG_UID];
  if (leerUid(uid)) procesar(uid);
}
