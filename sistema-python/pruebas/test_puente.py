import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from puente_arduino import PuenteArduino


class Falsa:
    def __init__(self): self.enviado = []; self.entrada = [b"CARD,DEADBE01\n", b"OK ABRIR\n", b""]
    def write(self, b): self.enviado.append(b.decode())
    def readline(self): return self.entrada.pop(0) if self.entrada else b""
    def close(self): pass


class TestPuente(unittest.TestCase):
    def test_ordenes(self):
        f = Falsa(); p = PuenteArduino("x", conexion=f)
        p.abrir(); p.denegar(); p.mostrar("Bienvenido|Carlos", "R-01")
        self.assertEqual(f.enviado, ["ABRIR\n", "DENEGAR\n", "LCD,Bienvenido Carlo|R-01\n"])

    def test_lectura_de_tarjeta(self):
        p = PuenteArduino("x", conexion=Falsa())
        self.assertEqual(p.leer_tarjeta(), "DEADBE01")
        self.assertIsNone(p.leer_tarjeta())        # "OK ABRIR" no es una tarjeta
        self.assertIsNone(p.leer_tarjeta())        # sin datos


if __name__ == "__main__":
    unittest.main()
