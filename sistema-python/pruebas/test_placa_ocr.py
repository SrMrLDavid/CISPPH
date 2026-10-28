import os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from placa_ocr import buscar_placa, LectorPlacas


class TestBuscarPlaca(unittest.TestCase):
    def test_formatos(self):
        self.assertEqual(buscar_placa(["ABC 123"]), "ABC-123")
        self.assertEqual(buscar_placa(["abc-123"]), "ABC-123")
        self.assertEqual(buscar_placa(["TUV 58D"]), "TUV-58D")      # moto

    def test_corrige_confusiones_del_ocr(self):
        self.assertEqual(buscar_placa(["A8C-1Z3"]), "ABC-123")
        self.assertEqual(buscar_placa(["KLM-21O"]), "KLM-210")

    def test_busca_entre_ruido(self):
        self.assertEqual(buscar_placa(["BOGOTA", "D.C.", "XYZ", "789"]), "XYZ-789")

    def test_sin_placa(self):
        self.assertIsNone(buscar_placa(["hola mundo"]))
        self.assertIsNone(buscar_placa([]))


class TestLector(unittest.TestCase):
    def test_lee_imagen_con_placa(self):
        try:
            import cv2, numpy as np
        except ImportError:
            self.skipTest("sin OpenCV")
        lector = LectorPlacas()
        if not lector.disponible:
            self.skipTest("sin EasyOCR ni Tesseract")
        img = np.full((480, 640, 3), 90, np.uint8)
        cv2.rectangle(img, (180, 300), (460, 380), (60, 210, 250), -1)
        cv2.rectangle(img, (180, 300), (460, 380), (0, 0, 0), 3)
        cv2.putText(img, "KLM 210", (205, 362), cv2.FONT_HERSHEY_DUPLEX, 2, (0, 0, 0), 4)
        self.assertEqual(lector.leer(img), "KLM-210")


if __name__ == "__main__":
    unittest.main()
