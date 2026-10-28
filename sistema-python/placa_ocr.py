"""
placa_ocr.py - Lectura de placas colombianas desde una imagen de cualquier cámara.

Usa un lector de texto (OCR) que se elige solo, en este orden:
  1. EasyOCR   (pip install easyocr)      - más preciso, usa una red neuronal; es pesado.
  2. Tesseract (pip install pytesseract + programa Tesseract instalado) - más liviano.
Si no hay ninguno instalado, el sistema sigue funcionando y la placa se escribe a mano.

Formatos reconocidos: carro ABC-123 y moto ABC-12D. La lectura es una ayuda: el guarda siempre
puede corregirla, y si la placa no coincide con la de la persona identificada el caso pasa a revisión.
La parte que interpreta el texto (buscar_placa) no necesita cámara y tiene pruebas automáticas.
"""
from __future__ import annotations

import re
from typing import Iterable, Optional

# En una placa las 3 primeras posiciones son letras; la 4.ª y 5.ª son números; la 6.ª es número (carro) o letra (moto)
_A_LETRA = {"0": "O", "1": "I", "5": "S", "8": "B", "2": "Z", "6": "G", "4": "A"}
_A_NUMERO = {"O": "0", "Q": "0", "D": "0", "I": "1", "L": "1", "S": "5", "B": "8", "Z": "2", "G": "6"}


def _limpiar(texto: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", (texto or "").upper())


def _interpretar(seis: str) -> Optional[str]:
    """Corrige confusiones típicas del OCR (0/O, 1/I, 5/S, 8/B) según la posición. Devuelve 'ABC-123' o None."""
    if len(seis) != 6:
        return None
    letras = "".join(_A_LETRA.get(c, c) if not c.isalpha() else c for c in seis[:3])
    if not letras.isalpha():
        return None
    n1 = "".join(_A_NUMERO.get(c, c) if not c.isdigit() else c for c in seis[3:5])
    if not n1.isdigit():
        return None
    ultimo = seis[5]
    if ultimo in "OQIL":                                   # letras que el OCR confunde con 0 y 1: se asume carro
        ultimo = {"O": "0", "Q": "0", "I": "1", "L": "1"}[ultimo]
    if ultimo.isdigit():
        return f"{letras}-{n1}{ultimo}"                    # carro: ABC-123
    if ultimo.isalpha():
        return f"{letras}-{n1}{ultimo}"                    # moto: ABC-12D
    return None


def buscar_placa(textos: Iterable[str]) -> Optional[str]:
    """Busca una placa en los fragmentos de texto que devolvió el OCR. Devuelve 'ABC-123' o None.
    Primero busca placas que ya vienen bien escritas; solo si no hay, intenta corregir confusiones del OCR."""
    textos = list(textos)
    candidatos = [_limpiar(t) for t in textos] + [_limpiar("".join(textos))]
    for c in candidatos:
        m = re.search(r"[A-Z]{3}\d{2}(?:\d|[A-HJKMNPR-Z])", c)
        if m:
            return f"{m.group(0)[:3]}-{m.group(0)[3:]}"
    for c in candidatos:
        for i in range(0, max(0, len(c) - 5)):
            p = _interpretar(c[i:i + 6])
            if p and _forma_valida(p):
                return p
    return None


def _forma_valida(p: str) -> bool:
    return bool(re.fullmatch(r"[A-Z]{3}-\d{3}|[A-Z]{3}-\d{2}[A-Z]", p))


class LectorPlacas:
    """Envuelve el OCR disponible. Se crea una sola vez (cargar EasyOCR tarda unos segundos)."""

    def __init__(self):
        self.motor: Optional[str] = None
        self._easy = None
        self._tess = None
        try:
            import easyocr                                   # noqa: F401
            self._easy = easyocr.Reader(["en"], gpu=False, verbose=False)
            self.motor = "easyocr"
            return
        except Exception:
            pass
        try:
            import pytesseract
            pytesseract.get_tesseract_version()
            self._tess = pytesseract
            self.motor = "tesseract"
        except Exception:
            self.motor = None

    @property
    def disponible(self) -> bool:
        return self.motor is not None

    def leer(self, frame_bgr) -> Optional[str]:
        """Recibe un fotograma de OpenCV (BGR) y devuelve la placa encontrada o None."""
        if not self.disponible or frame_bgr is None:
            return None
        import cv2
        for img in self._variantes(frame_bgr, cv2):
            textos = self._ocr(img)
            p = buscar_placa(textos)
            if p:
                return p
        return None

    def _ocr(self, img) -> list:
        try:
            if self.motor == "easyocr":
                return [t for _, t, conf in self._easy.readtext(img) if conf > 0.2]
            cfg = "--psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"
            return [self._tess.image_to_string(img, config=cfg), self._tess.image_to_string(img, config=cfg.replace("--psm 7", "--psm 6"))]
        except Exception:
            return []

    @staticmethod
    def _variantes(frame, cv2):
        """Imágenes a probar: recortes que parecen una placa (rectángulo ancho) y, al final, el cuadro completo."""
        gris = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        bordes = cv2.Canny(cv2.bilateralFilter(gris, 9, 75, 75), 60, 180)
        cont, _ = cv2.findContours(bordes, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
        cajas = []
        for c in cont:
            x, y, w, h = cv2.boundingRect(c)
            if w > 60 and h > 15 and 1.8 < w / h < 6.5:
                cajas.append((w * h, x, y, w, h))
        for _, x, y, w, h in sorted(cajas, reverse=True)[:4]:
            rec = gris[max(0, y - 4):y + h + 4, max(0, x - 4):x + w + 4]
            rec = cv2.resize(rec, None, fx=2.5, fy=2.5, interpolation=cv2.INTER_CUBIC)
            yield cv2.threshold(rec, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
            yield rec
        yield cv2.resize(gris, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_CUBIC)
