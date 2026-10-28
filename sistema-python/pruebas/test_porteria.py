import os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import nucleo
from porteria import Porteria, SEGUNDOS_PLUMA_ABIERTA


class Reloj:
    def __init__(self): self.t = 100.0
    def __call__(self): return self.t


class PuenteFalso:
    def __init__(self): self.ordenes = []
    def abrir(self): self.ordenes.append("abrir")
    def denegar(self): self.ordenes.append("denegar")
    def mostrar(self, a, b=""): self.ordenes.append(("lcd", a, b))


class PuenteRoto:
    def abrir(self): raise OSError("sin puerto")
    def denegar(self): raise OSError("sin puerto")
    def mostrar(self, a, b=""): raise OSError("sin puerto")


class TestPorteria(unittest.TestCase):
    def test_pluma_abre_y_se_cierra_sola(self):
        r = Reloj(); p = Porteria(reloj=r)
        self.assertFalse(p.pluma_abierta)
        p.abrir("Carlos Rodriguez")
        self.assertTrue(p.pluma_abierta)
        self.assertEqual(p.lcd, ("Bienvenido", "Carlos Rodriguez"))
        r.t += SEGUNDOS_PLUMA_ABIERTA + 0.1
        self.assertFalse(p.pluma_abierta)
        r.t += 2; p.revisar_tiempo()
        self.assertEqual(p.lcd, ("CISPPH", "Listo"))

    def test_denegar_cierra_y_muestra_motivo(self):
        r = Reloj(); p = Porteria(reloj=r)
        p.abrir("Ana"); p.denegar("Rostro no coincide con la base")
        self.assertFalse(p.pluma_abierta)
        self.assertEqual(p.lcd[0], "ACCESO DENEGADO")
        self.assertEqual(len(p.lcd[1]), 16)

    def test_reenvia_al_arduino_si_existe(self):
        pu = PuenteFalso(); p = Porteria(pu, reloj=Reloj())
        p.abrir("Ana"); p.denegar("x")
        self.assertIn("abrir", pu.ordenes); self.assertIn("denegar", pu.ordenes)

    def test_arduino_roto_no_detiene_la_porteria(self):
        p = Porteria(PuenteRoto(), reloj=Reloj())
        p.abrir("Ana")
        self.assertTrue(p.pluma_abierta)


class TestPlacas(unittest.TestCase):
    def test_coincidencia_ignora_formato(self):
        self.assertTrue(nucleo.placas_coinciden("abc 123", "ABC-123"))
        self.assertTrue(nucleo.placas_coinciden("ABC123", "ABC-123"))

    def test_distinta_o_vacia(self):
        self.assertFalse(nucleo.placas_coinciden("ABC-124", "ABC-123"))
        self.assertFalse(nucleo.placas_coinciden("", "ABC-123"))


if __name__ == "__main__":
    unittest.main()
