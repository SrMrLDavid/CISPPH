# Prototipo Arduino de la garita C.I.S.P.P.H.

Control de acceso con tarjeta RFID: lee una tarjeta, decide con las reglas de `cispph/cispph_core.h`, abre una pluma (servo), muestra el resultado en una pantalla LCD, avisa con un buzzer y emite cada movimiento por el puerto serie en CSV.

## Estado (léase primero)

| Parte | Estado |
|---|---|
| Reglas (`cispph_core.h`) | Probadas en PC: 23 pruebas, 0 fallos |
| Sketch (`cispph.ino`) | Ejecutado en una **simulación de PC** con sustitutos de las librerías; **no compilado con la cadena de Arduino ni probado en placa** |
| Cableado y librerías | Propuestos a partir del proyecto de referencia de SunFounder (s. f.); sin verificar con hardware |

## Materiales

Arduino UNO, módulo RFID MFRC522 con tarjetas, servo SG90 (pluma), pantalla LCD 16×2 con módulo I2C, buzzer activo, interruptor (sentido), protoboard y cables.

## Cableado propuesto

| Componente | Pin Arduino UNO |
|---|---|
| MFRC522 SDA(SS) / RST | 10 / 7 |
| MFRC522 MOSI / MISO / SCK | 11 / 12 / 13 |
| MFRC522 alimentación | 3,3 V y GND (**no 5 V**) |
| Servo (señal) | 9 (alimentar con 5 V y GND) |
| Buzzer | 8 |
| Interruptor de sentido | 4 y GND (abierto = ENTRADA, cerrado = SALIDA) |
| LCD I2C SDA / SCL | A4 / A5 (dirección 0x27; algunas usan 0x3F) |

## Cómo cargarlo

1. En el IDE de Arduino instale las bibliotecas **MFRC522** (Miguel Balboa) y **LiquidCrystal I2C** (Frank de Brabander).
2. Abra `cispph/cispph.ino` (la carpeta debe llamarse `cispph`).
3. Cambie los UID de ejemplo (`UID_RESIDENTE`, etc.) por los de sus tarjetas; el monitor serie muestra el UID de una tarjeta desconocida en la bitácora.
4. Seleccione *Arduino Uno* y cargue.

**Sin lector RFID:** descomente `#define SIMULACION_SERIAL` y escriba un UID de 8 dígitos hexadecimales (por ejemplo `DEADBE01`) en el monitor serie.

## Reglas y bitácora

Salida CSV: `ms,uid,sentido,decision,categoria,visitantes_ocupados`, por ejemplo `3340,DEADBE02,ENTRADA,AUTORIZADO,VIS,1`. Categorías, cupo de visitantes, bloqueo tras tres lecturas inválidas y la regla de no entrar/salir dos veces están documentadas en el encabezado de `cispph_core.h`. Si un VIP consume cupo es un parámetro pendiente de la administración (`vip_consume_cupo`, falso por defecto).

## Pruebas en PC

```bash
cd pruebas
g++ -std=c++11 -Wall -Wextra -Wpedantic -o test_core test_core.cpp && ./test_core        # reglas
cd simulacion_pc
g++ -std=c++17 -I. -o sim_pc main_pc.cpp && ./sim_pc                                      # sketch en PC
```

`simulacion_pc/salida_esperada.txt` contiene la salida de referencia. Los archivos de `simulacion_pc` son sustitutos mínimos de la API de Arduino, no la API real.

## Pendiente

Probar con hardware, medir el tiempo por registro (RNF-003), agregar persistencia en EEPROM y definir con la administración qué ocurre con VIP y visitantes sin cupo.

## Referencias

SunFounder. (s. f.). *RFID Access 6.0* [Documentación de proyecto Arduino]. https://docs.sunfounder.com/projects/summary-of-fun-projects/en/latest/arduino/rfid_access6.0.html

Galindo G., S. A., y Hernández G., H. D. (2020). Password-based vehicle access control system for parking lots designed and simulated in Verilog. *Tekhnê, 17*(1), 61–68. https://revistas.udistrital.edu.co/index.php/tekhne/article/view/19965
