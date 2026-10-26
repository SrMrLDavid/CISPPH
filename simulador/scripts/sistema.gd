extends Node

# CISPPH - Sistema global (autoload "Sistema").
# Datos y reglas del control de ingreso/salida. Sin nodos visuales: se puede portar a otro motor.
#
# Tablas (equivalentes a las del documento tecnico, que usa SQLite):
#   usuarios          -> `usuarios`      (id, rol, nombre, apellido, tipo_id, cedula, parqueadero, placa, rostro...)
#   entrada_salida    -> `movimientos`   (cada movimiento es un registro independiente = historial completo)
#   config            -> `config`        (usuario admin y hash SHA-256 de la contrasena, tiempo del aviso, modo)
# El "rostro" es un numero (la "huella facial" simulada); la comparacion usa la misma tolerancia 0.55
# del sistema Python original. NO hay reconocimiento facial real ni OCR real: es una simulacion didactica.

signal registro_creado(registro)
signal datos_cambiados

const RUTA_DATOS: String = "user://cispph_datos.json"
const RUTA_FOTOS: String = "user://cispph_fotos/"
const TOLERANCIA_ROSTRO: float = 0.55
const USUARIO_POR_DEFECTO: String = "admin"
const CLAVE_POR_DEFECTO: String = "admin123"
const TIPOS_ID: Array[String] = ["Cédula de Ciudadanía (CC)", "Cédula de Extranjería (CE)", "Pasaporte"]
const ROLES: Array[String] = ["residente", "trabajador", "visitante"]

var usuarios: Array = []
var movimientos: Array = []
var config: Dictionary = {}
var ocupacion: Dictionary = {}       # puesto -> id_usuario (0 = libre)
var siguiente_id_usuario: int = 1
var siguiente_id_movimiento: int = 1
var autenticado: bool = false
var persistir: bool = true
var puestos_residentes: Array[String] = []
var puestos_visitantes: Array[String] = []


func _ready() -> void:
	preparar_puestos()
	if not cargar():
		cargar_datos_iniciales()
		guardar()


# --- puestos -----------------------------------------------------------------------------------

func preparar_puestos() -> void:
	puestos_residentes.clear()
	puestos_visitantes.clear()
	# Escala reducida de demostracion: 15 puestos de visitantes (como en el caso del cliente) y 25 de residentes
	# (el caso describe 210 privados; aqui no se dibujan todos).
	for i in range(1, 26):
		puestos_residentes.append("R-%02d" % i)
	for i in range(1, 16):
		puestos_visitantes.append("V-%02d" % i)
	ocupacion.clear()
	for p in puestos_residentes + puestos_visitantes:
		ocupacion[p] = 0


func todos_los_puestos() -> Array[String]:
	var lista: Array[String] = []
	lista.append_array(puestos_visitantes)
	lista.append_array(puestos_residentes)
	return lista


func puestos_totales() -> int:
	return ocupacion.size()


func puestos_ocupados() -> int:
	var n: int = 0
	for p in ocupacion.keys():
		if int(ocupacion[p]) != 0:
			n += 1
	return n


# --- seguridad ---------------------------------------------------------------------------------

func hash_clave(clave: String) -> String:
	return clave.sha256_text()


func validar_login(usuario: String, clave: String) -> bool:
	var ok: bool = usuario == str(config.get("admin_user", "")) and hash_clave(clave) == str(config.get("admin_hash", ""))
	autenticado = ok
	return ok


func cambiar_clave(nueva: String) -> void:
	config["admin_hash"] = hash_clave(nueva)
	guardar()


# --- utilidades --------------------------------------------------------------------------------

func normalizar_placa(texto: String) -> String:
	var salida: String = ""
	for c in texto.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			salida += c
	return salida


func formato_placa(texto: String) -> String:
	var n: String = normalizar_placa(texto)
	if n.length() == 6:
		return n.substr(0, 3) + "-" + n.substr(3, 3)
	return n


func ahora_texto() -> String:
	return Time.get_datetime_string_from_system().replace("T", " ")


func nombre_completo(u: Dictionary) -> String:
	return (str(u.get("nombre", "")) + " " + str(u.get("apellido", ""))).strip_edges()


func usuario_por_id(id: int) -> Dictionary:
	for u in usuarios:
		if int((u as Dictionary)["id"]) == id:
			return u
	return {}


func buscar_por_placa(placa: String) -> Dictionary:
	# Busca la placa principal del usuario y tambien las de sus vehiculos adicionales.
	var n: String = normalizar_placa(placa)
	for u in usuarios:
		var d: Dictionary = u
		if not bool(d.get("activo", true)):
			continue
		if normalizar_placa(str(d["placa"])) == n:
			return d
		for v in d.get("vehiculos", []):
			if normalizar_placa(str((v as Dictionary)["placa"])) == n:
				return d
	return {}


# Vehiculo registrado ({tipo, color}) para una placa de este usuario (la principal o una adicional).
func vehiculo_registrado(u: Dictionary, placa: String) -> Dictionary:
	var n: String = normalizar_placa(placa)
	for v in u.get("vehiculos", []):
		if normalizar_placa(str((v as Dictionary)["placa"])) == n:
			return {"tipo": str(v["tipo"]), "color": str(v["color"]), "placa": formato_placa(str(v["placa"]))}
	var base: Dictionary = u.get("vehiculo", vehiculo_para(int(u["id"])))
	return {"tipo": str(base["tipo"]), "color": str(base["color"]), "placa": formato_placa(str(u["placa"]))}


const NOMBRES_COLOR: Dictionary = {"#c0392b": "rojo", "#2c3e50": "azul oscuro", "#e67e22": "naranja", "#1abc9c": "turquesa", "#f1c40f": "amarillo",
	"#7f8c8d": "gris", "#8e44ad": "morado", "#ecf0f1": "blanco", "#2980b9": "azul", "#111418": "negro", "#27ae60": "verde"}
const NOMBRES_TIPO: Dictionary = {"sedan": "sedán", "suv": "camioneta SUV", "hatchback": "hatchback", "camioneta": "camioneta pick-up", "moto": "moto"}


func describir_vehiculo(v: Dictionary) -> String:
	var tipo: String = str(NOMBRES_TIPO.get(str(v.get("tipo", "")), str(v.get("tipo", "?"))))
	var color: String = str(NOMBRES_COLOR.get(str(v.get("color", "")).to_lower(), "de otro color"))
	return "%s %s" % [tipo, color]


func vehiculos_de(u: Dictionary) -> Array:
	var r: Array = [vehiculo_registrado(u, str(u["placa"]))]
	for v in u.get("vehiculos", []):
		r.append(vehiculo_registrado(u, str((v as Dictionary)["placa"])))
	return r


func agregar_vehiculo(id: int, placa: String, tipo: String, color: String) -> Dictionary:
	var u: Dictionary = usuario_por_id(id)
	if u.is_empty():
		return {"ok": false, "error": "Usuario no encontrado."}
	if normalizar_placa(placa) == "":
		return {"ok": false, "error": "Escribe la placa."}
	if not buscar_por_placa(placa).is_empty():
		return {"ok": false, "error": "Esa placa ya está registrada."}
	var lista: Array = u.get("vehiculos", [])
	lista.append({"placa": formato_placa(placa), "tipo": tipo, "color": color})
	u["vehiculos"] = lista
	u["novedad"] = "ACTUALIZACIÓN"
	u["fecha_novedad"] = ahora_texto()
	guardar()
	datos_cambiados.emit()
	return {"ok": true, "error": ""}


# Busca en toda la base a quien corresponde un rostro (simulado: solo coincide el mismo numero).
func identificar_rostro(rostro: int) -> Dictionary:
	var mejor: Dictionary = {}
	var mejor_d: float = TOLERANCIA_ROSTRO
	for u in usuarios:
		var d: float = distancia_rostro(int((u as Dictionary)["rostro"]), rostro)
		if d <= mejor_d:
			mejor_d = d
			mejor = u
	return mejor


func residente_de_apto(apto: String) -> Dictionary:
	for u in usuarios:
		if str((u as Dictionary).get("rol", "")) == "residente" and str((u as Dictionary).get("apto", "")).to_upper() == apto.to_upper():
			return u
	return {}


func buscar_por_cedula(cedula: String) -> Dictionary:
	for u in usuarios:
		if str((u as Dictionary)["cedula"]) == cedula:
			return u
	return {}


# Distancia entre dos "huellas faciales" simuladas: la misma persona queda entre 0.15 y 0.38 y una
# persona distinta entre 0.62 y 0.90, de forma determinista (mismo par = mismo resultado).
func distancia_rostro(a: int, b: int) -> float:
	var h: int = (a * 73856093 ^ b * 19349663 ^ 0x5bd1e995) & 0x7fffffff
	var ruido: float = float(h % 1000) / 1000.0
	if a == b:
		return 0.15 + ruido * 0.23
	return 0.62 + ruido * 0.28


func rostro_coincide(a: int, b: int) -> bool:
	return distancia_rostro(a, b) <= TOLERANCIA_ROSTRO


func ultimo_estado(id_usuario: int) -> String:
	for i in range(movimientos.size() - 1, -1, -1):
		var m: Dictionary = movimientos[i]
		if int(m["id_usuario"]) == id_usuario and (str(m["estado"]) == "Entrada" or str(m["estado"]) == "Salida"):
			return str(m["estado"])
	return ""


func esta_dentro(id_usuario: int) -> bool:
	return ultimo_estado(id_usuario) == "Entrada"


func puesto_de(id_usuario: int) -> String:
	for p in ocupacion.keys():
		if int(ocupacion[p]) == id_usuario:
			return str(p)
	return ""


func usuarios_dentro() -> Array:
	var lista: Array = []
	for u in usuarios:
		if esta_dentro(int((u as Dictionary)["id"])):
			lista.append(u)
	return lista


# --- puestos: asignacion ----------------------------------------------------------------------

# Categoria operativa (DEFINICION DE TRABAJO, pendiente de ratificar por el Consejo): No VIP = residente con parqueadero
# privado; VIS = visitante; VIP = trato diferenciado (Consejo, administracion, proveedores/emergencias autorizados).
# No implica tarifa, prioridad ni cupo reservado: esas reglas NO estan definidas.
func categoria_de(u: Dictionary) -> String:
	if u.is_empty():
		return "Sin categoría"
	if bool(u.get("vip", false)):
		return "VIP"
	var r: String = str(u.get("rol", ""))
	if r == "residente":
		return "No VIP"
	if r == "visitante":
		return "VIS"
	return "Sin categoría"


func puesto_libre_para(u: Dictionary) -> String:
	if str(u.get("rol", "")) == "visitante":
		for p in puestos_visitantes:
			if int(ocupacion[p]) == 0:
				return p
		return ""
	var propio: String = str(u.get("parqueadero", ""))
	if ocupacion.has(propio) and propio.begins_with("R-") and int(ocupacion[propio]) == 0:
		return propio
	for p in puestos_residentes:
		if int(ocupacion[p]) == 0 and not puesto_asignado_a_otro(p, int(u["id"])):
			return p
	return ""


func puesto_asignado_a_otro(puesto: String, id_usuario: int) -> bool:
	for u in usuarios:
		var d: Dictionary = u
		if int(d["id"]) != id_usuario and str(d.get("parqueadero", "")) == puesto and str(d.get("rol", "")) != "visitante":
			return true
	return false


# --- evaluacion de un acceso ------------------------------------------------------------------
# sentido: "Entrada" | "Salida"; hora: 0..23 (hora simulada, para turnos).
# Devuelve: {resultado: "autorizado"|"revisar"|"denegado", clasificacion, usuario, distancia, motivo, puesto}

func evaluar_acceso(sentido: String, placa: String, rostro: int, hora: int, vehiculo: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"resultado": "denegado", "clasificacion": "otro", "usuario": {}, "distancia": 1.0, "motivo": "", "puesto": ""}
	var u: Dictionary = buscar_por_placa(placa)
	if u.is_empty():
		r["resultado"] = "revisar"
		r["motivo"] = "Placa no registrada: vehículo desconocido."
		return r
	r["usuario"] = u
	r["clasificacion"] = str(u["rol"])
	var d: float = distancia_rostro(int(u["rostro"]), rostro)
	r["distancia"] = d
	if d > TOLERANCIA_ROSTRO:
		r["resultado"] = "revisar"
		r["motivo"] = "El rostro del conductor no coincide con el titular de la placa (distancia %.2f > %.2f)." % [d, TOLERANCIA_ROSTRO]
		return r
	if not vehiculo.is_empty():
		var reg: Dictionary = vehiculo_registrado(u, placa)
		if str(reg["tipo"]) != str(vehiculo.get("tipo", reg["tipo"])) or str(reg["color"]).to_lower() != str(vehiculo.get("color", reg["color"])).to_lower():
			r["resultado"] = "revisar"
			r["motivo"] = "El vehículo observado (%s) no coincide con el registrado para esa placa (%s)." % [describir_vehiculo(vehiculo), describir_vehiculo(reg)]
			return r
	var id: int = int(u["id"])
	var ultimo: String = ultimo_estado(id)
	if sentido == "Entrada" and ultimo == "Entrada":
		r["motivo"] = "%s ya se encuentra DENTRO." % nombre_completo(u)
		return r
	if sentido == "Salida" and ultimo != "Entrada":
		r["motivo"] = "%s ya está FUERA o no registró entrada." % nombre_completo(u)
		return r
	if str(u["rol"]) == "visitante" and sentido == "Entrada" and not bool(u.get("autorizacion_activa", false)):
		r["resultado"] = "revisar"
		r["motivo"] = "La autorización de la visita no está vigente."
		return r
	if str(u["rol"]) == "trabajador" and sentido == "Entrada" and not en_turno(u, hora):
		r["resultado"] = "revisar"
		r["motivo"] = "Trabajador fuera de su turno (%s)." % str(u.get("turno", ""))
		return r
	if sentido == "Entrada":
		var puesto: String = puesto_libre_para(u)
		if puesto == "":
			r["motivo"] = "No hay puestos libres en la zona que corresponde."
			return r
		r["puesto"] = puesto
	else:
		r["puesto"] = puesto_de(id)
	r["resultado"] = "autorizado"
	r["motivo"] = "Acceso permitido."
	return r


func en_turno(u: Dictionary, hora: int) -> bool:
	var turno: String = str(u.get("turno", ""))
	if turno == "mañana":
		return hora >= 6 and hora < 14
	if turno == "tarde":
		return hora >= 14 and hora < 22
	return true


# --- registro de movimientos ------------------------------------------------------------------

func registrar_movimiento(sentido: String, u: Dictionary, placa: String, decision: String, detalle: String, puesto: String, fotos: Array, hora: int, origen: String = "Guardia") -> Dictionary:
	var id_u: int = int(u.get("id", 0))
	var nombre: String = nombre_completo(u) if not u.is_empty() else "Desconocido"
	var reg: Dictionary = {
		"id": siguiente_id_movimiento, "id_usuario": id_u, "nombre": nombre, "placa": formato_placa(placa),
		"estado": sentido if decision == "permitido" else "Denegado", "sentido": sentido, "fecha": ahora_texto(),
		"clasificacion": str(u.get("rol", "otro")), "categoria": categoria_de(u), "registrado_por": (origen if origen == "Automático" else "Guardia · " + str(config.get("admin_user", "?"))), "puesto": puesto, "detalle": detalle, "fotos": fotos, "hora_sim": hora
	}
	siguiente_id_movimiento += 1
	movimientos.append(reg)
	if decision == "permitido" and id_u != 0:
		if sentido == "Entrada" and puesto != "" and ocupacion.has(puesto):
			ocupacion[puesto] = id_u
		elif sentido == "Salida":
			var actual: String = puesto_de(id_u)
			if actual != "":
				ocupacion[actual] = 0
	guardar()
	registro_creado.emit(reg)
	datos_cambiados.emit()
	return reg


func registrar_usuario(datos: Dictionary) -> Dictionary:
	# Devuelve {ok, error, usuario}
	for clave in ["nombre", "apellido", "cedula", "placa", "tipo_id"]:
		if str(datos.get(clave, "")).strip_edges() == "":
			return {"ok": false, "error": "Todos los campos son obligatorios."}
	if not buscar_por_cedula(str(datos["cedula"])).is_empty():
		return {"ok": false, "error": "Esa cédula ya existe."}
	if not buscar_por_placa(str(datos["placa"])).is_empty():
		return {"ok": false, "error": "Esa placa ya está registrada."}
	var rol: String = str(datos.get("rol", "residente"))
	if rol == "residente":
		var p: String = str(datos.get("parqueadero", "")).to_upper()
		if not (ocupacion.has(p) and p.begins_with("R-")):
			return {"ok": false, "error": "El parqueadero debe ser un puesto de residente (R-01 a R-25)."}
		if puesto_asignado_a_otro(p, -1):
			return {"ok": false, "error": "Ese puesto ya está asignado a otro residente."}
		datos["parqueadero"] = p
	var u: Dictionary = datos.duplicate(true)
	u["id"] = siguiente_id_usuario
	siguiente_id_usuario += 1
	u["rol"] = rol
	u["placa"] = formato_placa(str(datos["placa"]))
	u["fecha_registro"] = ahora_texto()
	u["novedad"] = "REGISTRO"
	u["fecha_novedad"] = u["fecha_registro"]
	u["activo"] = true
	if not u.has("rostro"):
		u["rostro"] = randi()
	if not u.has("vehiculo"):
		u["vehiculo"] = vehiculo_para(int(u["id"]))
	usuarios.append(u)
	guardar()
	datos_cambiados.emit()
	return {"ok": true, "error": "", "usuario": u}


func actualizar_usuario(id: int, cambios: Dictionary) -> bool:
	var u: Dictionary = usuario_por_id(id)
	if u.is_empty():
		return false
	for k in cambios.keys():
		u[k] = cambios[k]
	if u.has("placa"):
		u["placa"] = formato_placa(str(u["placa"]))
	u["novedad"] = "ACTUALIZACIÓN"
	u["fecha_novedad"] = ahora_texto()
	guardar()
	datos_cambiados.emit()
	return true


func eliminar_usuario(id: int) -> void:
	var p: String = puesto_de(id)
	if p != "":
		ocupacion[p] = 0
	for i in range(usuarios.size() - 1, -1, -1):
		if int((usuarios[i] as Dictionary)["id"]) == id:
			usuarios.remove_at(i)
	for i in range(movimientos.size() - 1, -1, -1):
		if int((movimientos[i] as Dictionary)["id_usuario"]) == id:
			movimientos.remove_at(i)
	guardar()
	datos_cambiados.emit()


func vehiculo_para(id: int) -> Dictionary:
	var tipos: Array = ["sedan", "suv", "hatchback", "camioneta", "moto"]
	var colores: Array = ["#c0392b", "#2c3e50", "#e67e22", "#1abc9c", "#f1c40f", "#7f8c8d", "#8e44ad", "#ecf0f1", "#2980b9", "#111418", "#27ae60"]
	var h: int = (id * 2654435761 + 977) & 0x7fffffff
	return {"tipo": tipos[h % tipos.size()], "color": colores[(h >> 5) % colores.size()]}


func estadisticas() -> Dictionary:
	var dentro: int = usuarios_dentro().size()
	var denegados: int = 0
	for m in movimientos:
		if str((m as Dictionary)["estado"]) == "Denegado":
			denegados += 1
	return {
		"total_registros": movimientos.size(), "usuarios": usuarios.size(), "vehiculos_dentro": dentro,
		"parqueaderos_ocupados": puestos_ocupados(), "parqueaderos_totales": puestos_totales(),
		"parqueaderos_disponibles": puestos_totales() - puestos_ocupados(), "denegados": denegados
	}


# --- datos de prueba (los de la bitacora del equipo + algunos mas) ------------------------------

func cargar_datos_iniciales() -> void:
	usuarios.clear()
	movimientos.clear()
	siguiente_id_usuario = 1
	siguiente_id_movimiento = 1
	preparar_puestos()
	config = {"admin_user": USUARIO_POR_DEFECTO, "admin_hash": hash_clave(CLAVE_POR_DEFECTO), "popup_segundos": 3, "modo": "automatico", "hora_sim": 17.5}
	var base: Array = [
		["residente", "Carlos", "Rodríguez", "1020304050", "R-01", "ABC-123", "A-101", "", "", ""],
		["residente", "María", "González", "1030405060", "R-02", "DEF-456", "B-205", "", "", ""],
		["residente", "Pedro", "Martínez", "1040506070", "R-03", "GHI-789", "C-302", "", "", ""],
		["residente", "Sofía", "Cardona", "1050607080", "R-04", "KLM-210", "A-203", "", "", ""],
		["residente", "Andrés", "Salazar", "1060708090", "R-05", "NPR-334", "B-104", "", "", ""],
		["residente", "Daniela", "Quintero", "1070809010", "R-06", "TUV-581", "C-401", "", "", ""],
		["residente", "Felipe", "Montoya", "1080901020", "R-07", "XYZ-789", "A-302", "", "", ""],
		["residente", "Lucía", "Acosta", "1090102030", "R-08", "BCD-902", "B-303", "", "", ""],
		["trabajador", "Roberto", "Sánchez", "79123456", "", "PQR-678", "", "mantenimiento", "mañana", ""],
		["trabajador", "Laura", "Díaz", "52987654", "", "STU-901", "", "administración", "tarde", ""],
		["visitante", "Juan", "Pérez", "80112233", "", "JKL-012", "A-101", "", "", "Carlos Rodríguez|visita familiar"],
		["visitante", "Ana", "López", "1012345678", "", "MNO-345", "B-205", "", "", "María González|reparto"],
		["visitante", "Mauricio", "Ríos", "79445566", "", "ELV-310", "", "", "", "Administración|mantenimiento de ascensores"]
	]
	for b in base:
		var datos: Dictionary = {"rol": b[0], "nombre": b[1], "apellido": b[2], "tipo_id": TIPOS_ID[0], "cedula": b[3], "parqueadero": b[4], "placa": b[5], "apto": b[6], "cargo": b[7], "turno": b[8]}
		if str(b[9]) != "":
			var partes: PackedStringArray = str(b[9]).split("|")
			datos["autorizado_por"] = partes[0]
			datos["motivo"] = partes[1]
			datos["autorizacion_activa"] = true
		var res: Dictionary = registrar_usuario(datos)
		if not bool(res["ok"]):
			push_warning("CISPPH: dato inicial rechazado: " + str(res["error"]))
	# Categoria VIP de demostracion (definicion de trabajo): un miembro del Consejo y un proveedor autorizado
	actualizar_usuario(3, {"vip": true, "motivo_vip": "Miembro del Consejo de Administración"})
	actualizar_usuario(13, {"vip": true, "motivo_vip": "Proveedor autorizado por la administración"})
	# Vehiculos adicionales de demostracion (un residente puede tener varios coches)
	agregar_vehiculo(1, "CAR-777", "hatchback", "#2980b9")
	agregar_vehiculo(4, "SOF-204", "suv", "#ecf0f1")
	# Algunos residentes ya estan dentro al comenzar (historial coherente)
	for id in [2, 4, 5]:
		var u: Dictionary = usuario_por_id(id)
		registrar_movimiento("Entrada", u, str(u["placa"]), "permitido", "Dato inicial", str(u["parqueadero"]), [], 8)


# --- persistencia -------------------------------------------------------------------------------

func guardar() -> void:
	if not persistir:
		return
	var datos: Dictionary = {
		"version": 1, "config": config, "usuarios": usuarios, "movimientos": movimientos,
		"ocupacion": ocupacion, "sig_u": siguiente_id_usuario, "sig_m": siguiente_id_movimiento
	}
	var f := FileAccess.open(RUTA_DATOS, FileAccess.WRITE)
	if f == null:
		push_warning("CISPPH: no se pudo guardar " + RUTA_DATOS)
		return
	f.store_string(JSON.stringify(datos))
	f.close()


func cargar() -> bool:
	if not persistir or not FileAccess.file_exists(RUTA_DATOS):
		return false
	var f := FileAccess.open(RUTA_DATOS, FileAccess.READ)
	if f == null:
		return false
	var contenido: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (contenido is Dictionary) or int((contenido as Dictionary).get("version", 0)) != 1:
		return false
	var d: Dictionary = contenido
	config = d.get("config", {})
	usuarios = d.get("usuarios", [])
	movimientos = d.get("movimientos", [])
	siguiente_id_usuario = int(d.get("sig_u", usuarios.size() + 1))
	siguiente_id_movimiento = int(d.get("sig_m", movimientos.size() + 1))
	for u in usuarios:
		(u as Dictionary)["id"] = int((u as Dictionary)["id"])
		(u as Dictionary)["rostro"] = int((u as Dictionary)["rostro"])
	for m in movimientos:
		(m as Dictionary)["id"] = int((m as Dictionary)["id"])
		(m as Dictionary)["id_usuario"] = int((m as Dictionary)["id_usuario"])
	var oc: Variant = d.get("ocupacion", {})
	if oc is Dictionary:
		for p in (oc as Dictionary).keys():
			if ocupacion.has(p):
				ocupacion[p] = int((oc as Dictionary)[p])
	if not config.has("admin_hash"):
		return false
	return true


func reiniciar_datos() -> void:
	cargar_datos_iniciales()
	guardar()
	datos_cambiados.emit()
