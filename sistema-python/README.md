# Sistema de control de acceso con reconocimiento facial (Python) — CISPPH

Programa de escritorio para la garita de **Robles del Norte P.H.** (conjunto ficticio del proyecto de clase).
Una cámara reconoce el rostro, el sistema consulta las reglas del conjunto y decide: **Autorizado**, **Revisar** (decide el guarda) o **Denegado**. Todo queda registrado.

> **Estado honesto:** las reglas (`nucleo.py`) y el puente con Arduino tienen pruebas automáticas que pasan (22 pruebas). **No se ha probado** en este entorno la ventana (CustomTkinter), la cámara real, `face_recognition`/dlib ni el Arduino físico. Eso se valida en el computador del equipo.

## Archivos
| Archivo | Para qué sirve |
|---|---|
| `parqueadero_pro.py` | Ventana del sistema (login, cámara, registro, historial). Es el programa que se ejecuta. |
| `nucleo.py` | Reglas y base de datos (SQLite) sin pantalla ni cámara: por eso se puede probar. |
| `puente_arduino.py` | Envía órdenes al Arduino por cable USB (abrir pluma, avisar, mostrar texto). Opcional. |
| `pruebas/` | Pruebas automáticas: `python -m unittest discover -s pruebas` |

## Instalación (Windows, en este orden)
```
pip install customtkinter Pillow opencv-python Click "setuptools<81" pyserial
pip install dlib-bin --no-deps
pip install face-recognition --no-deps
pip install face-recognition-models --force-reinstall
python parqueadero_pro.py
```
Usuario de demostración: `admin` / `admin123` (cámbielo antes de cualquier uso real).

## Arduino (opcional)
1. Cargue `prototipo-arduino/cispph/cispph.ino` en el Arduino UNO.
2. Averigüe el puerto (Administrador de dispositivos → Puertos; p. ej. `COM3`).
3. Ejecute con la variable: `set CISPPH_ARDUINO_PORT=COM3` y luego `python parqueadero_pro.py`.
Sin la variable, el sistema funciona igual pero sin pluma física.

Órdenes (una por línea, 9600 baudios): `ABRIR`, `DENEGAR`, `LCD,línea1|línea2`, `PING`. El Arduino responde `OK ...` o `PONG`.

## Arquitectura propuesta
Computador principal (cámaras + este programa + base de datos) → cable USB → Arduino (pluma, buzzer, pantalla). El computador y el Arduino se conectan a una **UPS** para seguir funcionando si falla la luz.
Autonomía de la UPS (fórmula, sin cifras inventadas): `horas ≈ (Wh de la batería × eficiencia) ÷ consumo en W`. Hay que medir el consumo real del equipo; llegar a 24 h depende de ese consumo y puede requerir baterías externas.

## Librerías y alternativas (candidatas; no todas probadas)
- Cámara y video: `opencv-python`. En Raspberry Pi: `picamera2`.
- Rostros: `face_recognition` (usa dlib). Umbral usado: 0.55.
- Placas: candidatas `easyocr`, `pytesseract`, Plate Recognizer (servicio), OpenALPR (licencia AGPL). **Sin evaluar.**
- Modelo de carro: **no evaluado**.
- Computador: PC o Raspberry Pi (la Pi puede ser lenta con dlib; sin probar).
- Arduino: `MFRC522`, `Servo`, `LiquidCrystal_I2C`; en el PC, `pyserial`.
