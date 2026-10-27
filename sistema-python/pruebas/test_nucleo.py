"""Pruebas del núcleo de reglas. Ejecutar:  python -m unittest discover -s pruebas -v"""
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import nucleo as n


class BaseDatos(unittest.TestCase):
    def setUp(self):
        self.conn = n.conectar(":memory:")
        n.iniciar_db(self.conn)
        self.res = n.registrar_usuario(self.conn, nombre="Carlos", apellido="Rodríguez", cedula="1", placa="abc123", parqueadero="R-01")
        self.vis = n.registrar_usuario(self.conn, nombre="Juan", apellido="Pérez", cedula="2", placa="JKL012", rol="visitante", autorizado_por="Carlos Rodríguez")

    def tearDown(self):
        self.conn.close()

    def mover(self, uid, sentido, hora=12):
        d = n.evaluar_acceso(self.conn, uid, sentido, hora)
        n.registrar_movimiento(self.conn, uid, sentido, d)
        return d


class TestReglas(BaseDatos):
    def test_login_con_hash(self):
        self.assertTrue(n.validar_login(self.conn, "admin", "admin123"))
        self.assertFalse(n.validar_login(self.conn, "admin", "otra"))
        self.assertEqual(len(n.hash_password("x")), 64)

    def test_residente_entra_sale_y_no_repite(self):
        self.assertEqual(self.mover(self.res, "Entrada").resultado, n.AUTORIZADO)
        self.assertEqual(self.mover(self.res, "Entrada").resultado, n.DENEGADO)       # ya dentro
        self.assertEqual(self.mover(self.res, "Salida").resultado, n.AUTORIZADO)
        self.assertEqual(self.mover(self.res, "Salida").resultado, n.DENEGADO)        # ya fuera

    def test_salida_sin_entrada_denegada(self):
        self.assertEqual(n.evaluar_acceso(self.conn, self.res, "Salida").resultado, n.DENEGADO)

    def test_categorias(self):
        self.assertEqual(n.categoria_de("residente", False), "No VIP")
        self.assertEqual(n.categoria_de("visitante", False), "VIS")
        self.assertEqual(n.categoria_de("residente", True), "VIP")

    def test_visitante_asigna_puesto_y_libera(self):
        d = self.mover(self.vis, "Entrada")
        self.assertEqual((d.resultado, d.puesto), (n.AUTORIZADO, "V-01"))
        self.assertEqual(n.visitantes_libres(self.conn), 14)
        self.mover(self.vis, "Salida")
        self.assertEqual(n.visitantes_libres(self.conn), 15)

    def test_visitante_sin_autorizacion_pasa_a_revision(self):
        self.conn.execute("UPDATE usuarios SET autorizacion_activa = 0 WHERE id = ?", (self.vis,))
        self.assertEqual(n.evaluar_acceso(self.conn, self.vis, "Entrada").resultado, n.REVISAR)

    def test_guarda_puede_forzar_un_caso_en_revision(self):
        self.conn.execute("UPDATE usuarios SET autorizacion_activa = 0 WHERE id = ?", (self.vis,))
        d = n.evaluar_acceso(self.conn, self.vis, "Entrada", forzar=True)
        self.assertEqual((d.resultado, d.puesto), (n.AUTORIZADO, "V-01"))

    def test_sin_cupo_de_visitantes(self):
        self.conn.execute("UPDATE config SET valor = '1' WHERE clave = 'cupo_visitantes'")
        otro = n.registrar_usuario(self.conn, nombre="Ana", apellido="López", cedula="3", placa="MNO345", rol="visitante", autorizado_por="María")
        self.assertEqual(self.mover(self.vis, "Entrada").resultado, n.AUTORIZADO)
        d = self.mover(otro, "Entrada")
        self.assertEqual(d.resultado, n.DENEGADO)
        self.assertIn("libres", d.motivo)

    def test_vip_no_consume_cupo_por_defecto(self):
        self.conn.execute("UPDATE config SET valor = '0' WHERE clave = 'cupo_visitantes'")
        vip = n.registrar_usuario(self.conn, nombre="Luz", apellido="Díaz", cedula="4", placa="VIP001", parqueadero="R-09", vip=True)
        self.assertEqual(self.mover(vip, "Entrada").resultado, n.AUTORIZADO)
        self.conn.execute("UPDATE config SET valor = '1' WHERE clave = 'vip_consume_cupo'")
        self.mover(vip, "Salida")
        self.assertEqual(self.mover(vip, "Entrada").resultado, n.DENEGADO)

    def test_trabajador_fuera_de_turno(self):
        t = n.registrar_usuario(self.conn, nombre="Roberto", apellido="Sánchez", cedula="5", placa="PQR678", rol="trabajador", turno="mañana")
        self.assertEqual(n.evaluar_acceso(self.conn, t, "Entrada", 9).resultado, n.AUTORIZADO)
        self.assertEqual(n.evaluar_acceso(self.conn, t, "Entrada", 23).resultado, n.REVISAR)

    def test_denegados_quedan_en_auditoria(self):
        self.mover(self.res, "Entrada"); self.mover(self.res, "Entrada")
        estados = [f["estado"] for f in self.conn.execute("SELECT estado FROM entrada_salida ORDER BY id")]
        self.assertEqual(estados, ["Entrada", "Denegado"])

    def test_datos_obligatorios_y_duplicados(self):
        with self.assertRaises(ValueError):
            n.registrar_usuario(self.conn, nombre="", apellido="x", cedula="9", placa="AAA111", parqueadero="R-2")
        with self.assertRaises(ValueError):
            n.registrar_usuario(self.conn, nombre="a", apellido="b", cedula="1", placa="ZZZ999", parqueadero="R-2")
        with self.assertRaises(ValueError):
            n.registrar_usuario(self.conn, nombre="a", apellido="b", cedula="7", placa="abc123", parqueadero="R-2")


class TestBloqueo(unittest.TestCase):
    def test_tres_fallos_bloquean_y_se_libera(self):
        c = n.ControlIntentos(3, 15)
        for t in (0, 1):
            c.fallo(t)
        self.assertFalse(c.bloqueado(2))
        c.fallo(2)
        self.assertTrue(c.bloqueado(3))
        self.assertGreater(c.segundos_restantes(3), 0)
        self.assertFalse(c.bloqueado(18))

    def test_exito_reinicia(self):
        c = n.ControlIntentos(3, 15)
        c.fallo(0); c.fallo(1); c.exito(); c.fallo(2); c.fallo(3)
        self.assertFalse(c.bloqueado(4))


class TestMigracion(unittest.TestCase):
    def test_base_antigua_se_migra(self):
        conn = n.conectar(":memory:")
        conn.execute("CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, apellido TEXT NOT NULL, cedula TEXT UNIQUE NOT NULL, parqueadero TEXT NOT NULL, placa TEXT NOT NULL)")
        conn.execute("CREATE TABLE entrada_salida (id INTEGER PRIMARY KEY AUTOINCREMENT, id_usuario INTEGER NOT NULL, nombre_usuario TEXT NOT NULL, placa TEXT NOT NULL, estado TEXT NOT NULL, fecha TEXT NOT NULL)")
        conn.execute("INSERT INTO usuarios (nombre,apellido,cedula,parqueadero,placa) VALUES ('A','B','1','P-1','XYZ789')")
        n.iniciar_db(conn)
        fila = conn.execute("SELECT rol, vip FROM usuarios").fetchone()
        self.assertEqual((fila["rol"], fila["vip"]), ("residente", 0))


if __name__ == "__main__":
    unittest.main()
