"""Pruebas de la búsqueda manual, la contingencia y los reportes. Ejecutar:  python -m unittest discover -s pruebas -v"""
import csv, sys, tempfile, unittest, datetime
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import nucleo as n


class Base(unittest.TestCase):
    def setUp(self):
        self.conn = n.conectar(":memory:"); n.iniciar_db(self.conn)
        self.res = n.registrar_usuario(self.conn, nombre="Carlos", apellido="Rodríguez", cedula="1001", placa="abc123", parqueadero="R-01")
        self.vis = n.registrar_usuario(self.conn, nombre="Juan", apellido="Pérez", cedula="2002", placa="JKL012", rol="visitante", autorizado_por="Carlos")
        self.addCleanup(self.conn.close)

    def mover(self, uid, sentido, fecha, detalle=""):
        d = n.evaluar_acceso(self.conn, uid, sentido, 12)
        n.registrar_movimiento(self.conn, uid, sentido, d, detalle=detalle or "", ahora=datetime.datetime.strptime(fecha, "%Y-%m-%d %H:%M:%S"))


class TestBusquedaManual(Base):
    def test_por_cedula_y_por_placa_en_cualquier_formato(self):
        self.assertEqual(n.buscar_usuario(self.conn, "1001")["id"], self.res)
        self.assertEqual(n.buscar_usuario(self.conn, "abc-123")["id"], self.res)
        self.assertEqual(n.buscar_usuario(self.conn, " jkl 012 ")["id"], self.vis)

    def test_no_encontrado_o_vacio(self):
        self.assertIsNone(n.buscar_usuario(self.conn, "999"))
        self.assertIsNone(n.buscar_usuario(self.conn, ""))
        self.assertIsNone(n.buscar_usuario(self.conn, "   "))


class TestContingencia(Base):
    def test_se_activa_y_se_desactiva(self):
        self.assertFalse(n.contingencia_activa(self.conn))
        n.fijar_contingencia(self.conn, True); self.assertTrue(n.contingencia_activa(self.conn))
        n.fijar_contingencia(self.conn, False); self.assertFalse(n.contingencia_activa(self.conn))


class TestReportes(Base):
    def setUp(self):
        super().setUp()
        self.mover(self.res, "Entrada", "2026-11-01 08:00:00")
        self.mover(self.res, "Salida", "2026-11-01 18:00:00")
        self.mover(self.vis, "Entrada", "2026-11-03 10:00:00")
        self.mover(self.res, "Salida", "2026-11-04 09:00:00")      # ya está fuera → denegado

    def test_rango_de_fechas(self):
        self.assertEqual(n.rango_fechas("2026-11-01", "2026-11-02"), ("2026-11-01 00:00:00", "2026-11-02 23:59:59"))
        self.assertEqual(n.rango_fechas("", ""), ("", ""))
        for malo in (("01/11/2026", ""), ("2026-13-40", ""), ("2026-11-05", "2026-11-01")):
            with self.assertRaises(ValueError):
                n.rango_fechas(*malo)

    def test_historial_filtrado(self):
        self.assertEqual(len(n.historial(self.conn)), 4)
        self.assertEqual(len(n.historial(self.conn, "2026-11-01", "2026-11-01")), 2)
        self.assertEqual(len(n.historial(self.conn, "2026-11-02")), 2)
        self.assertEqual(len(n.historial(self.conn, "", "2026-11-02")), 2)

    def test_resumen(self):
        r = n.resumen_periodo(self.conn)
        self.assertEqual((r["entradas"], r["salidas"], r["denegados"], r["total"]), (2, 1, 1, 4))
        self.assertEqual(r["por_categoria"]["No VIP"], 3); self.assertEqual(r["por_categoria"]["VIS"], 1)
        self.assertEqual(r["visitantes_libres"], 14)         # el visitante ocupa V-01
        r1 = n.resumen_periodo(self.conn, "2026-11-01", "2026-11-01")
        self.assertEqual((r1["entradas"], r1["salidas"], r1["denegados"]), (1, 1, 0))

    def test_resumen_cuenta_permitidos_por_el_guarda(self):
        self.mover(self.vis, "Salida", "2026-11-05 10:00:00", detalle="Salida permitida. (permitido por el guarda)")
        self.assertEqual(n.resumen_periodo(self.conn)["permitidos_por_guarda"], 1)

    def test_exportar_csv_abre_en_excel_y_filtra(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = Path(d) / "h.csv"
            self.assertEqual(n.exportar_historial_csv(self.conn, ruta, "2026-11-01", "2026-11-01"), 2)
            crudo = ruta.read_bytes()
            self.assertTrue(crudo.startswith(b"\xef\xbb\xbf"))            # BOM para que Excel lea las tildes
            filas = list(csv.reader(ruta.read_text(encoding="utf-8-sig").splitlines(), delimiter=";"))
            self.assertEqual(filas[0][0], "Fecha y hora"); self.assertEqual(len(filas), 3)
            self.assertIn("Carlos Rodríguez", filas[1][2])

    def test_exportar_con_fecha_mala_no_crea_archivo(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = Path(d) / "h.csv"
            with self.assertRaises(ValueError):
                n.exportar_historial_csv(self.conn, ruta, "mañana", "")
            self.assertFalse(ruta.exists())


class TestNovedades(Base):
    def test_registrar_y_listar_por_fecha(self):
        n.registrar_novedad(self.conn, "Intento de robo", "Sacó una llave y quiso forzar la pluma", "abc-123",
                            ahora=datetime.datetime(2026, 11, 2, 22, 0))
        n.registrar_novedad(self.conn, "Falla de equipo", "La cámara se apagó", ahora=datetime.datetime(2026, 11, 9, 8, 0))
        self.assertEqual(len(n.listar_novedades(self.conn)), 2)
        solo = n.listar_novedades(self.conn, "2026-11-01", "2026-11-05")
        self.assertEqual(len(solo), 1); self.assertEqual(solo[0]["placa"], "ABC123")
        self.assertEqual(n.resumen_periodo(self.conn, "2026-11-01", "2026-11-05")["novedades"], 1)

    def test_validaciones(self):
        with self.assertRaises(ValueError):
            n.registrar_novedad(self.conn, "Inventada", "algo")
        with self.assertRaises(ValueError):
            n.registrar_novedad(self.conn, "Otra", "   ")

    def test_exportar_novedades(self):
        n.registrar_novedad(self.conn, "Otra", "Prueba", ahora=datetime.datetime(2026, 11, 2, 9, 0))
        with tempfile.TemporaryDirectory() as d:
            ruta = Path(d) / "n.csv"
            self.assertEqual(n.exportar_novedades_csv(self.conn, ruta), 1)
            self.assertIn("Prueba", ruta.read_text(encoding="utf-8-sig"))


if __name__ == "__main__":
    unittest.main()
