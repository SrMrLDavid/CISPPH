"""
nucleo.py - Reglas de negocio y base de datos del sistema C.I.S.P.P.H. (Python).

Este módulo NO usa cámara, reconocimiento facial ni interfaz gráfica. Por eso se puede
probar en cualquier computador (ver pruebas/test_nucleo.py) y la interfaz
(parqueadero_pro.py) solo se ocupa de mostrar resultados y capturar datos.

Reglas implementadas (son propuestas del equipo; ver documentación del repositorio):
  * Categorías: No VIP (residente), VIS (visitante) y VIP (trato diferenciado).
  * Un usuario no puede entrar si ya está dentro, ni salir si ya está fuera.
  * Un visitante necesita una autorización vigente y ocupa un cupo del contador de
    puestos de visitantes (bien común: no se reserva a un apartamento).
  * Un trabajador fuera de su turno pasa a revisión del guarda.
  * Tres intentos fallidos seguidos bloquean el lector por unos segundos.
  * Cada decisión (permitida o denegada) queda en la tabla de auditoría.
NO se implementan tarifas, minutos de gracia ni cobros: el equipo aún no los define.
"""
from __future__ import annotations

import datetime
import hashlib
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

USUARIO_POR_DEFECTO = "admin"
CLAVE_POR_DEFECTO = "admin123"        # solo para demostración; cámbiela al instalar
TOLERANCIA_ROSTRO = 0.55
CUPO_VISITANTES_POR_DEFECTO = 15
INTENTOS_MAXIMOS = 3
SEGUNDOS_BLOQUEO = 15

ROLES = ("residente", "trabajador", "visitante")
TIPOS_ID_INICIALES = ("Cédula de Ciudadanía (CC)", "Cédula de Extranjería (CE)", "Pasaporte")

# Resultados posibles de una evaluación
AUTORIZADO, REVISAR, DENEGADO = "autorizado", "revisar", "denegado"


# ----------------------------------------------------------------------------- utilidades
def hash_password(clave: str) -> str:
    """Devuelve el resumen SHA-256 de la clave; la clave nunca se guarda en texto plano."""
    return hashlib.sha256(clave.encode("utf-8")).hexdigest()


def normalizar_placa(texto: str) -> str:
    """Pone la placa en mayúsculas y sin espacios ni guiones, para compararla sin errores de escritura."""
    return "".join(ch for ch in (texto or "").upper() if ch.isalnum())


def placas_coinciden(leida: str, registrada: str) -> bool:
    """True si la placa leída es la registrada (ignora mayúsculas, espacios y guiones)."""
    a, b = normalizar_placa(leida), normalizar_placa(registrada)
    return bool(a) and a == b


def ahora_texto(ahora: Optional[datetime.datetime] = None) -> str:
    return (ahora or datetime.datetime.now()).strftime("%Y-%m-%d %H:%M:%S")


def categoria_de(rol: str, vip: bool) -> str:
    """Categoría operativa (definición de trabajo, pendiente de ratificar)."""
    if vip:
        return "VIP"
    if rol == "residente":
        return "No VIP"
    if rol == "visitante":
        return "VIS"
    return "Sin categoría"


def en_turno(turno: str, hora: int) -> bool:
    """mañana 6-14, tarde 14-22, noche 22-6. Sin turno definido siempre es válido."""
    turno = (turno or "").lower()
    if turno == "mañana":
        return 6 <= hora < 14
    if turno == "tarde":
        return 14 <= hora < 22
    if turno == "noche":
        return hora >= 22 or hora < 6
    return True


# ----------------------------------------------------------------------------- base de datos
def conectar(ruta_db) -> sqlite3.Connection:
    conn = sqlite3.connect(ruta_db)
    conn.row_factory = sqlite3.Row
    return conn


_COLUMNAS_USUARIOS = {
    "tipo_id": "TEXT DEFAULT 'CC'", "fotos_rutas": "TEXT DEFAULT ''", "encodings": "BLOB",
    "fecha_registro": "TEXT DEFAULT ''", "novedad": "TEXT DEFAULT ''", "fecha_novedad": "TEXT DEFAULT ''",
    "rol": "TEXT DEFAULT 'residente'", "vip": "INTEGER DEFAULT 0", "cargo": "TEXT DEFAULT ''",
    "turno": "TEXT DEFAULT ''", "autorizado_por": "TEXT DEFAULT ''", "motivo": "TEXT DEFAULT ''",
    "autorizacion_activa": "INTEGER DEFAULT 0",
}
_COLUMNAS_MOVIMIENTOS = {
    "categoria": "TEXT DEFAULT ''", "puesto": "TEXT DEFAULT ''", "detalle": "TEXT DEFAULT ''",
    "registrado_por": "TEXT DEFAULT ''",
}


def _migrar(conn: sqlite3.Connection, tabla: str, columnas: dict) -> None:
    existentes = {fila[1] for fila in conn.execute(f"PRAGMA table_info({tabla})")}
    for nombre, definicion in columnas.items():
        if nombre not in existentes:
            conn.execute(f"ALTER TABLE {tabla} ADD COLUMN {nombre} {definicion}")


def iniciar_db(conn: sqlite3.Connection) -> None:
    """Crea las tablas si no existen y agrega las columnas nuevas a bases de datos anteriores."""
    conn.execute("""CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, apellido TEXT NOT NULL,
        cedula TEXT UNIQUE NOT NULL, parqueadero TEXT NOT NULL, placa TEXT NOT NULL)""")
    _migrar(conn, "usuarios", _COLUMNAS_USUARIOS)
    conn.execute("""CREATE TABLE IF NOT EXISTS entrada_salida (
        id INTEGER PRIMARY KEY AUTOINCREMENT, id_usuario INTEGER NOT NULL, nombre_usuario TEXT NOT NULL,
        placa TEXT NOT NULL, estado TEXT NOT NULL, fecha TEXT NOT NULL,
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id))""")
    _migrar(conn, "entrada_salida", _COLUMNAS_MOVIMIENTOS)
    conn.execute("""CREATE TABLE IF NOT EXISTS tipos_identificacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT, nombre_tipo TEXT UNIQUE NOT NULL)""")
    if conn.execute("SELECT COUNT(*) FROM tipos_identificacion").fetchone()[0] == 0:
        conn.executemany("INSERT INTO tipos_identificacion (nombre_tipo) VALUES (?)",
                         [(t,) for t in TIPOS_ID_INICIALES])
    conn.execute("CREATE TABLE IF NOT EXISTS config (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)")
    por_defecto = {"admin_user": USUARIO_POR_DEFECTO, "admin_hash": hash_password(CLAVE_POR_DEFECTO),
                   "cupo_visitantes": str(CUPO_VISITANTES_POR_DEFECTO), "vip_consume_cupo": "0"}
    for clave, valor in por_defecto.items():
        conn.execute("INSERT OR IGNORE INTO config (clave, valor) VALUES (?, ?)", (clave, valor))
    conn.commit()


def leer_config(conn: sqlite3.Connection, clave: str, defecto: str = "") -> str:
    fila = conn.execute("SELECT valor FROM config WHERE clave = ?", (clave,)).fetchone()
    return fila[0] if fila else defecto


def validar_login(conn: sqlite3.Connection, usuario: str, clave: str) -> bool:
    return (usuario == leer_config(conn, "admin_user", USUARIO_POR_DEFECTO)
            and hash_password(clave) == leer_config(conn, "admin_hash"))


# ----------------------------------------------------------------------------- intentos fallidos
class ControlIntentos:
    """Bloquea el lector tras INTENTOS_MAXIMOS fallos seguidos (regla tomada de Galindo y Hernández, 2020)."""

    def __init__(self, maximos: int = INTENTOS_MAXIMOS, segundos: int = SEGUNDOS_BLOQUEO):
        self.maximos, self.segundos = maximos, segundos
        self.fallos = 0
        self._hasta: Optional[float] = None

    def bloqueado(self, ahora: float) -> bool:
        if self._hasta is not None and ahora >= self._hasta:
            self._hasta, self.fallos = None, 0
        return self._hasta is not None

    def segundos_restantes(self, ahora: float) -> int:
        return max(0, int(round((self._hasta or ahora) - ahora)))

    def fallo(self, ahora: float) -> None:
        self.fallos += 1
        if self.fallos >= self.maximos:
            self._hasta = ahora + self.segundos

    def exito(self) -> None:
        self.fallos = 0


# ----------------------------------------------------------------------------- reglas de acceso
@dataclass
class Decision:
    resultado: str          # autorizado | revisar | denegado
    motivo: str
    categoria: str = ""
    puesto: str = ""


def ultimo_estado(conn: sqlite3.Connection, id_usuario: int) -> Optional[str]:
    """Último movimiento PERMITIDO del usuario ('Entrada' o 'Salida'); None si no tiene."""
    fila = conn.execute("SELECT estado FROM entrada_salida WHERE id_usuario = ? AND estado IN ('Entrada','Salida') "
                        "ORDER BY id DESC LIMIT 1", (id_usuario,)).fetchone()
    return fila[0] if fila else None


def puestos_visitantes_ocupados(conn: sqlite3.Connection) -> set:
    """Puestos V-xx que hoy ocupa algún visitante (su último movimiento permitido es una entrada)."""
    ocupados = set()
    for u in conn.execute("SELECT id FROM usuarios WHERE rol = 'visitante'"):
        fila = conn.execute("SELECT estado, puesto FROM entrada_salida WHERE id_usuario = ? "
                            "AND estado IN ('Entrada','Salida') ORDER BY id DESC LIMIT 1", (u["id"],)).fetchone()
        if fila and fila["estado"] == "Entrada" and fila["puesto"]:
            ocupados.add(fila["puesto"])
    return ocupados


def cupo_visitantes(conn: sqlite3.Connection) -> int:
    return int(leer_config(conn, "cupo_visitantes", str(CUPO_VISITANTES_POR_DEFECTO)))


def visitantes_libres(conn: sqlite3.Connection) -> int:
    return max(0, cupo_visitantes(conn) - len(puestos_visitantes_ocupados(conn)))


def _puesto_visitante_libre(conn: sqlite3.Connection) -> str:
    ocupados = puestos_visitantes_ocupados(conn)
    for n in range(1, cupo_visitantes(conn) + 1):
        codigo = f"V-{n:02d}"
        if codigo not in ocupados:
            return codigo
    return ""


def evaluar_acceso(conn: sqlite3.Connection, id_usuario: int, sentido: str, hora: Optional[int] = None,
                   forzar: bool = False) -> Decision:
    """Decide si el usuario identificado puede entrar o salir. sentido: 'Entrada' | 'Salida'.

    forzar=True lo usa el guarda cuando decide permitir un caso marcado «revisar»: se omiten solo las
    comprobaciones de autorización y de turno; ya dentro/fuera y el cupo siguen aplicándose."""
    if sentido not in ("Entrada", "Salida"):
        raise ValueError("sentido debe ser 'Entrada' o 'Salida'")
    u = conn.execute("SELECT * FROM usuarios WHERE id = ?", (id_usuario,)).fetchone()
    if u is None:
        return Decision(DENEGADO, "Usuario no registrado.")
    nombre = f"{u['nombre']} {u['apellido']}"
    rol = u["rol"] or "residente"
    cat = categoria_de(rol, bool(u["vip"]))
    ultimo = ultimo_estado(conn, id_usuario)
    if sentido == "Entrada" and ultimo == "Entrada":
        return Decision(DENEGADO, f"{nombre} ya se encuentra DENTRO.", cat)
    if sentido == "Salida" and ultimo != "Entrada":
        return Decision(DENEGADO, f"{nombre} ya está FUERA o no registró entrada.", cat)
    if sentido == "Salida":
        fila = conn.execute("SELECT puesto FROM entrada_salida WHERE id_usuario = ? AND estado = 'Entrada' "
                            "ORDER BY id DESC LIMIT 1", (id_usuario,)).fetchone()
        return Decision(AUTORIZADO, "Salida permitida.", cat, (fila["puesto"] if fila else "") or u["parqueadero"])
    # --- entrada
    hora = datetime.datetime.now().hour if hora is None else hora
    if rol == "visitante" and not u["autorizacion_activa"] and not forzar:
        return Decision(REVISAR, "La autorización de la visita no está vigente.", cat)
    if rol == "trabajador" and not en_turno(u["turno"], hora) and not forzar:
        return Decision(REVISAR, f"Trabajador fuera de su turno ({u['turno']}).", cat)
    usa_cupo = rol == "visitante" or (bool(u["vip"]) and leer_config(conn, "vip_consume_cupo", "0") == "1")
    if usa_cupo:
        puesto = _puesto_visitante_libre(conn)
        if not puesto:
            return Decision(DENEGADO, "No hay puestos de visitantes libres.", cat)
        return Decision(AUTORIZADO, "Entrada permitida.", cat, puesto)
    return Decision(AUTORIZADO, "Entrada permitida.", cat, u["parqueadero"] if rol == "residente" else "")


def registrar_movimiento(conn: sqlite3.Connection, id_usuario: int, sentido: str, decision: Decision,
                         registrado_por: str = "Guardia", detalle: str = "",
                         ahora: Optional[datetime.datetime] = None) -> int:
    """Guarda en la auditoría una decisión. Las denegadas se guardan con estado 'Denegado'."""
    u = conn.execute("SELECT nombre, apellido, placa FROM usuarios WHERE id = ?", (id_usuario,)).fetchone()
    nombre = f"{u['nombre']} {u['apellido']}" if u else "Desconocido"
    placa = u["placa"] if u else ""
    estado = sentido if decision.resultado == AUTORIZADO else "Denegado"
    cur = conn.execute(
        "INSERT INTO entrada_salida (id_usuario, nombre_usuario, placa, estado, fecha, categoria, puesto, detalle, registrado_por) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (id_usuario, nombre, placa, estado, ahora_texto(ahora), decision.categoria, decision.puesto,
         detalle or decision.motivo, registrado_por))
    conn.commit()
    return cur.lastrowid


def registrar_usuario(conn: sqlite3.Connection, **d) -> int:
    """Crea un usuario. Campos obligatorios: nombre, apellido, cedula, placa. Devuelve el id."""
    for campo in ("nombre", "apellido", "cedula", "placa"):
        if not str(d.get(campo, "")).strip():
            raise ValueError(f"Falta el campo obligatorio: {campo}")
    rol = d.get("rol", "residente")
    if rol not in ROLES:
        raise ValueError("rol inválido")
    if rol == "residente" and not str(d.get("parqueadero", "")).strip():
        raise ValueError("El residente necesita un parqueadero asignado")
    if rol == "visitante" and not str(d.get("autorizado_por", "")).strip():
        raise ValueError("El visitante necesita quién lo autoriza")
    if conn.execute("SELECT 1 FROM usuarios WHERE cedula = ?", (d["cedula"],)).fetchone():
        raise ValueError("Esa cédula ya existe")
    if conn.execute("SELECT 1 FROM usuarios WHERE placa = ?", (d["placa"].upper(),)).fetchone():
        raise ValueError("Esa placa ya está registrada")
    ahora = ahora_texto()
    cur = conn.execute(
        "INSERT INTO usuarios (nombre, apellido, tipo_id, cedula, parqueadero, placa, rol, vip, cargo, turno, "
        "autorizado_por, motivo, autorizacion_activa, fecha_registro, novedad, fecha_novedad) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (d["nombre"], d["apellido"], d.get("tipo_id", "Cédula de Ciudadanía (CC)"), d["cedula"],
         d.get("parqueadero", "") or "", d["placa"].upper(), rol, 1 if d.get("vip") else 0, d.get("cargo", ""),
         d.get("turno", ""), d.get("autorizado_por", ""), d.get("motivo", ""),
         1 if (rol == "visitante" and d.get("autorizacion_activa", True)) else 0, ahora, "REGISTRO", ahora))
    conn.commit()
    return cur.lastrowid
