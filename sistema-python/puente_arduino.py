"""
puente_arduino.py - Comunicación opcional entre el computador y el Arduino de la garita.

El computador (cámara, reconocimiento y base de datos) decide; el Arduino solo ejecuta: abre la pluma,
avisa con el buzzer y muestra texto en la pantalla. Protocolo de texto por puerto serie (9600 baudios,
una orden por línea):

    PC -> Arduino:  ABRIR | DENEGAR | LCD,<línea 1>|<línea 2> | PING
    Arduino -> PC:  OK <orden> | PONG | CARD,<UID en hexadecimal>

Requiere la librería pyserial (pip install pyserial). Si no hay Arduino conectado, el sistema funciona igual.
Uso:  puente = PuenteArduino("COM3")   # en Linux: "/dev/ttyUSB0"
"""
from __future__ import annotations

from typing import Optional


def listar_puertos() -> list:
    """Nombres de los puertos serie disponibles (requiere pyserial)."""
    from serial.tools import list_ports
    return [p.device for p in list_ports.comports()]


class PuenteArduino:
    def __init__(self, puerto: str, baudios: int = 9600, conexion=None):
        """`conexion` permite inyectar un objeto con write/readline (se usa en las pruebas)."""
        if conexion is None:
            import serial                                  # import tardío: pyserial es opcional
            conexion = serial.Serial(puerto, baudios, timeout=1)
        self.con = conexion

    def _enviar(self, orden: str) -> None:
        self.con.write((orden.strip() + "\n").encode("utf-8"))

    def abrir(self) -> None:
        """Pide abrir la pluma (el Arduino la cierra solo pasado su tiempo de espera)."""
        self._enviar("ABRIR")

    def denegar(self) -> None:
        self._enviar("DENEGAR")

    def mostrar(self, linea1: str, linea2: str = "") -> None:
        """Texto para la pantalla 16x2 (sin tildes ni el carácter «|»)."""
        limpio = lambda t: t.replace("|", " ").replace("\n", " ")[:16]
        self._enviar(f"LCD,{limpio(linea1)}|{limpio(linea2)}")

    def leer_tarjeta(self) -> Optional[str]:
        """Devuelve el UID leído por el Arduino (p. ej. 'DEADBE01') o None si no hubo línea CARD."""
        linea = self.con.readline().decode("utf-8", errors="ignore").strip()
        return linea[5:] if linea.startswith("CARD,") else None

    def cerrar(self) -> None:
        self.con.close()
