# Sistema de control de acceso con reconocimiento facial (Python) — CISPPH

Programa de escritorio para la portería de **Robles del Norte P.H.**.
Funciona como una portería completa con solo un computador y su cámara: la pluma y la pantalla de mensajes aparecen en la ventana, y el Arduino es opcional. Una cámara reconoce el rostro, el sistema consulta las reglas del conjunto y decide: **Autorizado**, **Revisar** (decide el guarda) o **Denegado**. Todo queda registrado.

> **Estado honesto:** las reglas (`nucleo.py`) y el puente con Arduino tienen pruebas automáticas que pasan (52 pruebas). **No se ha probado** en este entorno la ventana (CustomTkinter), la cámara real, `face_recognition`/dlib ni el Arduino físico. Eso se valida en el computador del equipo.

## Archivos
| Archivo | Para qué sirve |
|---|---|
| `parqueadero_pro.py` | Ventana del sistema (login, cámara, registro, historial). Es el programa que se ejecuta. |
| `nucleo.py` | Reglas y base de datos (SQLite) sin pantalla ni cámara: por eso se puede probar. |
| `porteria.py` | Pluma y pantalla (LCD) virtuales de la portería; repiten sus órdenes en el Arduino si está conectado. |
| `placa_ocr.py` | Lee la placa de la imagen de la cámara (EasyOCR o Tesseract) y la acomoda al formato ABC-123 o ABC-12D. |
| `puente_arduino.py` | Envía órdenes al Arduino por cable USB (abrir pluma, avisar, mostrar texto). Opcional. |
| `pruebas/` | Pruebas automáticas: `python -m unittest discover -s pruebas` |

## Instalación (Windows, en este orden)
```
pip install customtkinter Pillow opencv-python Click "setuptools<81" pyserial easyocr
pip install dlib-bin --no-deps
pip install face-recognition --no-deps
pip install face-recognition-models --force-reinstall
python parqueadero_pro.py
```
Usuario de demostración: `admin` / `admin123` (cámbielo antes de cualquier uso real).

## Sin cámara, sin luz o sin reconocimiento facial
- El programa **abre aunque `face_recognition` no se haya podido instalar**; en ese caso avisa en la consola y se opera con *Ingreso manual*.
- En *Operación*, escriba la **cédula o la placa** en «Ingreso manual» y pulse *Validar manual*: se aplican las mismas reglas (dentro/fuera, cupo de visitantes, autorización, turno, revisión del guarda, bloqueo tras 3 intentos).
- Sin reconocimiento facial también se puede **registrar** a una persona (sin fotos).
- El interruptor **Contingencia** marca en el historial los movimientos hechos durante una emergencia.

## Reportes
En *Estado Parqueadero*: escriba «Desde» y «Hasta» (AAAA-MM-DD, vacío = sin límite) y pulse *Resumen* (entradas, salidas, denegados, casos permitidos por el guarda, por categoría) o *Exportar CSV* (carpeta `reportes/`, abre en Excel).

## Arduino (opcional)
1. Cargue `prototipo-arduino/cispph/cispph.ino` en el Arduino UNO.
2. Averigüe el puerto (Administrador de dispositivos → Puertos; p. ej. `COM3`).
3. Ejecute con la variable: `set CISPPH_ARDUINO_PORT=COM3` y luego `python parqueadero_pro.py`.
Sin la variable, el sistema funciona igual con la pluma y la pantalla virtuales de la ventana.

## Uso como portería (solo PC y cámara)
1. Ingrese con el usuario y la clave.
2. En *Operación* elija la cámara y el punto de control (Entrada o Salida).
3. La placa se lee sola con la cámara al validar (o con el botón *Leer placa con la cámara*); también puede escribirla. Si no coincide con la registrada a esa persona, el caso pasa a revisión del guarda.
   Cámara: sirve cualquier cámara USB, y también una cámara IP o el celular con una app de cámara, pegando su dirección (rtsp:// o http://) en el campo de la ventana.
4. Pulse *Validar Rostro*. Si todo coincide, la pluma virtual se levanta 3 s y la pantalla saluda; si no, muestra ACCESO DENEGADO con el motivo.

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
