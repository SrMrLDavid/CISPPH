"""
porteria.py - Pluma y pantalla de la portería, con o sin Arduino.

El sistema Python funciona como una portería completa usando solo el computador y su cámara:
  * La pluma (barrera) y la pantalla de 2 líneas (LCD) existen siempre como elementos virtuales
    que se dibujan en la ventana de Operación.
  * Si hay un Arduino conectado (puente_arduino.py), las mismas órdenes también se envían a la
    pluma y a la pantalla físicas. Si el Arduino falla, la portería virtual sigue funcionando.

Este módulo no usa cámara ni interfaz gráfica, por eso tiene pruebas automáticas (pruebas/test_porteria.py).
"""
from __future__ import annotations

import time
from typing import Callable, Optional

SEGUNDOS_PLUMA_ABIERTA = 3
ANCHO_LCD = 16


class Porteria:
    def __init__(self, puente=None, reloj: Callable[[], float] = time.monotonic):
        self.puente = puente
        self._reloj = reloj
        self._abierta_hasta = 0.0
        self._reposo_en = 0.0
        self.linea1 = ""
        self.linea2 = ""
        self.reposo()

    # ------------------------------------------------------------------ estado
    @property
    def pluma_abierta(self) -> bool:
        return self._reloj() < self._abierta_hasta

    @property
    def lcd(self) -> tuple:
        """Texto actual de la pantalla (dos líneas de 16 caracteres como máximo)."""
        return (self.linea1, self.linea2)

    def revisar_tiempo(self) -> None:
        """La interfaz la llama de forma periódica: la pluma se cierra sola y la pantalla vuelve al reposo."""
        if self._reposo_en and self._reloj() >= self._reposo_en:
            self.reposo()

    # ------------------------------------------------------------------ órdenes
    def mostrar(self, linea1: str, linea2: str = "") -> None:
        self.linea1 = (linea1 or "")[:ANCHO_LCD]
        self.linea2 = (linea2 or "")[:ANCHO_LCD]
        self._fisico("mostrar", self.linea1, self.linea2)

    def reposo(self) -> None:
        self._reposo_en = 0.0
        self.mostrar("CISPPH", "Listo")

    def abrir(self, nombre: str = "") -> None:
        ahora = self._reloj()
        self._abierta_hasta = ahora + SEGUNDOS_PLUMA_ABIERTA
        self._reposo_en = self._abierta_hasta + 1
        self.mostrar("Bienvenido", nombre)
        self._fisico("abrir")

    def denegar(self, motivo: str = "") -> None:
        self._abierta_hasta = 0.0
        self._reposo_en = self._reloj() + 4
        self.mostrar("ACCESO DENEGADO", motivo)
        self._fisico("denegar")

    def _fisico(self, orden: str, *args) -> None:
        if self.puente is None:
            return
        try:
            getattr(self.puente, orden)(*args)
        except Exception:      # un fallo del Arduino nunca debe detener la portería
            pass
