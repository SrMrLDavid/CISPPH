"""
Prueba de integración del flujo de reconocimiento de parqueadero_pro.py SIN cámara, SIN interfaz y SIN
face_recognition: se sustituyen esas librerías por simulaciones y se ejecuta el método real
ejecutar_reconocimiento contra una base de datos temporal.
NO prueba el dibujo de la interfaz (eso requiere pantalla y las librerías reales).
Ejecutar:  python -m unittest discover -s pruebas -v
"""
import os, pickle, sys, tempfile, types, unittest
from pathlib import Path
from unittest import mock

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))
os.environ["CISPPH_HOME"] = tempfile.mkdtemp()

# --- simulaciones de librerías pesadas
cv2 = types.ModuleType("cv2"); cv2.COLOR_BGR2RGB = 4; cv2.cvtColor = lambda f, c: f
ctk = mock.MagicMock(); ctk.CTk = type("CTk", (), {})
pil = types.ModuleType("PIL"); pil.Image = mock.MagicMock()
fr = types.ModuleType("face_recognition")
fr.face_locations = lambda rgb: [(0, 0, 1, 1)]
fr.face_encodings = lambda rgb, loc: [rgb]                     # el "rostro" es el propio fotograma
fr.compare_faces = lambda conocidos, actual, tolerance=0.5: [c == actual for c in conocidos]
tk = types.ModuleType("tkinter"); tk.messagebox = mock.MagicMock(); tk.messagebox.askyesno = mock.MagicMock(return_value=True)
for nombre, mod in {"cv2": cv2, "customtkinter": ctk, "PIL": pil, "PIL.Image": pil.Image, "face_recognition": fr,
                    "tkinter": tk, "tkinter.messagebox": tk.messagebox, "numpy": mock.MagicMock()}.items():
    sys.modules[nombre] = mod
import parqueadero_pro as pp   # noqa: E402
import nucleo                  # noqa: E402


class TestFlujoReconocimiento(unittest.TestCase):
    def setUp(self):
        cn = nucleo.conectar(pp.DB_FILE); cn.execute("DELETE FROM entrada_salida"); cn.execute("DELETE FROM usuarios"); cn.commit(); nucleo.fijar_contingencia(cn, False)
        self.cn = cn
        self.addCleanup(cn.close)
        self.ids = {}
        for clave, rostro, extra in (("res", "R", dict(parqueadero="R-01")),
                                     ("vis", "V", dict(rol="visitante", autorizado_por="Carlos")),):
            uid = nucleo.registrar_usuario(cn, nombre=clave, apellido="X", cedula=clave, placa=clave.upper() + "111", **extra)
            cn.execute("UPDATE usuarios SET encodings = ? WHERE id = ?", (pickle.dumps([rostro]), uid)); cn.commit()
            self.ids[clave] = uid
        self.app = pp.AppAccesoVehicularFinal.__new__(pp.AppAccesoVehicularFinal)
        self.app.intentos = nucleo.ControlIntentos()
        self.app.puente = mock.MagicMock()
        self.app.video_worker = mock.MagicMock()
        self.app.combo_modo = mock.MagicMock()
        from porteria import Porteria
        self.app.porteria = Porteria(self.app.puente)
        self.app.lector_placas = None
        self.app.entry_placa = mock.MagicMock(); self.app.entry_placa.get.return_value = ""
        self.app.entry_manual = mock.MagicMock(); self.app.entry_manual.get.return_value = ""
        for nombre in ("log", "set_estado", "mostrar_popup_bienvenida", "actualizar_tabla_estado", "after", "_denegar"):
            setattr(self.app, nombre, mock.MagicMock())

    def reconocer(self, rostro, modo):
        self.app.video_worker.get_frame.return_value = rostro
        self.app.combo_modo.get.return_value = modo
        self.app._denegar.reset_mock(); self.app.puente.reset_mock()
        self.app.ejecutar_reconocimiento()

    def estados(self):
        return [f["estado"] for f in self.cn.execute("SELECT estado FROM entrada_salida ORDER BY id")]

    def test_entrada_permitida_abre_la_pluma(self):
        self.reconocer("R", "Entrada")
        self.app._denegar.assert_not_called(); self.app.puente.abrir.assert_called_once()
        self.assertEqual(self.estados(), ["Entrada"])

    def test_placa_distinta_pasa_a_revision_del_guarda(self):
        self.app.entry_placa.get.return_value = "ZZZ-999"
        with mock.patch.object(pp.messagebox, "askyesno", return_value=False) as pregunta:
            self.reconocer("R", "Entrada")
        pregunta.assert_called_once(); self.app.puente.abrir.assert_not_called()
        self.assertEqual(self.estados(), ["Denegado"])

    def test_placa_leida_sola_por_la_camara_distinta_va_a_revision(self):
        self.app.lector_placas = mock.MagicMock(disponible=True)
        self.app.lector_placas.leer.return_value = "ZZZ-999"
        with mock.patch.object(pp.messagebox, "askyesno", return_value=False) as pregunta:
            self.reconocer("R", "Entrada")
        pregunta.assert_called_once(); self.assertEqual(self.estados(), ["Denegado"])

    def test_placa_leida_sola_correcta_entra(self):
        self.app.lector_placas = mock.MagicMock(disponible=True)
        self.app.lector_placas.leer.return_value = "RES-111"
        self.reconocer("R", "Entrada")
        self.assertEqual(self.estados(), ["Entrada"])

    def test_placa_correcta_con_otro_formato_entra(self):
        self.app.entry_placa.get.return_value = "res 111"
        self.reconocer("R", "Entrada")
        self.app.puente.abrir.assert_called_once(); self.assertEqual(self.estados(), ["Entrada"])

    def test_doble_entrada_se_deniega_y_queda_registrada(self):
        self.reconocer("R", "Entrada"); self.reconocer("R", "Entrada")
        self.app._denegar.assert_called_once(); self.app.puente.abrir.assert_not_called()
        self.assertEqual(self.estados(), ["Entrada", "Denegado"])

    def test_visitante_recibe_puesto_v01(self):
        self.reconocer("V", "Entrada")
        fila = self.cn.execute("SELECT puesto, categoria FROM entrada_salida").fetchone()
        self.assertEqual((fila["puesto"], fila["categoria"]), ("V-01", "VIS"))

    def test_tres_rostros_desconocidos_bloquean_el_lector(self):
        for _ in range(3):
            self.reconocer("Z", "Entrada")
        self.reconocer("R", "Entrada")                          # válido, pero el lector está bloqueado
        self.assertIn("bloqueado", self.app._denegar.call_args[0][0].lower())
        self.assertEqual(self.estados(), [])

    def test_caso_en_revision_lo_decide_el_guarda(self):
        self.cn.execute("UPDATE usuarios SET autorizacion_activa = 0 WHERE id = ?", (self.ids["vis"],)); self.cn.commit()
        pp.messagebox.askyesno.return_value = False
        self.reconocer("V", "Entrada")
        self.assertEqual(self.estados(), ["Denegado"])
        pp.messagebox.askyesno.return_value = True
        self.reconocer("V", "Entrada")
        self.assertEqual(self.estados(), ["Denegado", "Entrada"])

    # --- ingreso manual (sin cámara)
    def manual(self, texto, modo="Entrada"):
        self.app.entry_manual.get.return_value = texto
        self.app.combo_modo.get.return_value = modo
        self.app._denegar.reset_mock(); self.app.puente.reset_mock()
        self.app.validar_manual()

    def test_manual_por_cedula_abre_la_pluma_y_queda_marcado(self):
        self.manual("res")
        self.app.puente.abrir.assert_called_once(); self.app._denegar.assert_not_called()
        fila = self.cn.execute("SELECT estado, detalle, registrado_por FROM entrada_salida").fetchone()
        self.assertEqual(fila["estado"], "Entrada"); self.assertIn("ingreso manual", fila["detalle"])
        self.assertIn("Guardia", fila["registrado_por"])

    def test_manual_por_placa_con_otro_formato(self):
        self.manual("vis-111")
        self.assertEqual(self.estados(), ["Entrada"])

    def test_manual_aplica_las_mismas_reglas_doble_entrada(self):
        self.manual("res"); self.manual("res")
        self.app._denegar.assert_called_once(); self.assertEqual(self.estados(), ["Entrada", "Denegado"])

    def test_manual_persona_inexistente_cuenta_como_intento_fallido(self):
        for _ in range(3):
            self.manual("no-existe")
        self.manual("res")
        self.assertIn("bloqueado", self.app._denegar.call_args[0][0].lower())
        self.assertEqual(self.estados(), [])

    def test_manual_en_contingencia_se_anota(self):
        nucleo.fijar_contingencia(self.cn, True)
        self.manual("res")
        self.assertIn("contingencia", self.cn.execute("SELECT detalle FROM entrada_salida").fetchone()["detalle"])

    def test_contingencia_el_guarda_confirma_cada_caso(self):
        nucleo.fijar_contingencia(self.cn, True)
        pp.messagebox.askyesno.reset_mock(); pp.messagebox.askyesno.return_value = False
        self.manual("res")                                   # normalmente entraría solo
        pp.messagebox.askyesno.assert_called_once(); self.assertEqual(self.estados(), ["Denegado"])
        pp.messagebox.askyesno.return_value = True
        self.manual("res")
        self.assertEqual(self.estados(), ["Denegado", "Entrada"])

    def test_citofono_se_sugiere_al_visitante_en_revision(self):
        self.cn.execute("UPDATE usuarios SET autorizacion_activa = 0 WHERE id = ?", (self.ids["vis"],)); self.cn.commit()
        pp.messagebox.askyesno.reset_mock(); pp.messagebox.askyesno.return_value = False
        self.manual("vis")
        self.assertIn("Carlos", pp.messagebox.askyesno.call_args[0][1])
        self.assertIn("Citófono", pp.messagebox.askyesno.call_args[0][1])

    def test_manual_visitante_sin_autorizacion_va_a_revision(self):
        self.cn.execute("UPDATE usuarios SET autorizacion_activa = 0 WHERE id = ?", (self.ids["vis"],)); self.cn.commit()
        pp.messagebox.askyesno.return_value = False
        self.manual("vis")
        self.assertEqual(self.estados(), ["Denegado"])


if __name__ == "__main__":
    unittest.main()
