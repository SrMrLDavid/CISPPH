extends RefCounted
class_name GeneradorCasos

# CISPPH - Genera los casos de acceso que llegan a la garita (cada caso es una situacion con un defecto posible que el sistema o el guardia
# deben detectar). Todo es simulado: la "lectura" de placa es el texto de la placa del vehiculo y el
# "reconocimiento facial" compara los numeros de rostro (ver Sistema.distancia_rostro).
#
# Caso: {sentido, escenario, etiqueta, usuario (titular de la placa; {} si no esta registrada),
#        placa_delantera, placa_trasera, rostro (int del conductor), vehiculo {tipo,color} (el que se ve),
#        conductor {nombre, apellido, tipo_id, cedula, apto, motivo, registrado_id} (quien presenta documento),
#        citofono {apto, residente, responde, texto}, legitimo (bool: la "verdad" de la simulacion, solo se
#        usa para dar retroalimentacion al guardia DESPUES de decidir)}

var rng := RandomNumberGenerator.new()

const NOMBRES: Array = ["Camilo", "Valentina", "Julián", "Paula", "Mateo", "Natalia", "Sebastián", "Laura", "Diego", "Carolina", "Santiago", "Juliana", "Andrés", "Mónica", "Esteban", "Luisa"]
const APELLIDOS: Array = ["Ramírez", "Torres", "Gómez", "Herrera", "Vargas", "Castro", "Ortiz", "Rojas", "Mejía", "Cárdenas", "Peña", "Suárez", "Ríos", "Parra"]
const APTOS: Array = ["A-101", "B-205", "C-302", "A-203", "B-104", "C-401", "A-302", "B-303"]


func _init(semilla: int = 0) -> void:
	if semilla == 0:
		rng.randomize()
	else:
		rng.seed = semilla


func placa_aleatoria() -> String:
	var letras: String = "ABCDEFGHJKLMNPRSTUVWXYZ"
	var s: String = ""
	for i in range(3):
		s += letras[rng.randi() % letras.length()]
	return "%s-%03d" % [s, rng.randi() % 1000]


func placa_libre() -> String:
	for i in range(50):
		var p: String = placa_aleatoria()
		if Sistema.buscar_por_placa(p).is_empty():
			return p
	return "ZZZ-999"


func elegir(lista: Array) -> Dictionary:
	if lista.is_empty():
		return {}
	return lista[rng.randi() % lista.size()]


func con_rol(rol: String, dentro: bool) -> Array:
	var r: Array = []
	for u in Sistema.usuarios:
		var d: Dictionary = u
		if str(d["rol"]) == rol and bool(d.get("activo", true)) and Sistema.esta_dentro(int(d["id"])) == dentro:
			r.append(d)
	return r


func cedula_aleatoria() -> String:
	var s: String = str(1 + rng.randi() % 9)
	for i in range(8):
		s += str(rng.randi() % 10)
	return s


func persona_de(u: Dictionary) -> Dictionary:
	return {"nombre": str(u["nombre"]), "apellido": str(u["apellido"]), "tipo_id": str(u["tipo_id"]), "cedula": str(u["cedula"]),
		"apto": str(u.get("apto", "")), "motivo": "", "registrado_id": int(u["id"])}


func persona_aleatoria(apellido: String = "", apto: String = "") -> Dictionary:
	var ap: String = apellido if apellido != "" else str(APELLIDOS[rng.randi() % APELLIDOS.size()])
	var tipo: String = Sistema.TIPOS_ID[0] if rng.randf() < 0.85 else Sistema.TIPOS_ID[rng.randi() % Sistema.TIPOS_ID.size()]
	return {"nombre": str(NOMBRES[rng.randi() % NOMBRES.size()]), "apellido": ap, "tipo_id": tipo, "cedula": cedula_aleatoria(),
		"apto": apto if apto != "" else str(APTOS[rng.randi() % APTOS.size()]), "motivo": "visita", "registrado_id": 0}


func rostro_nuevo() -> int:
	return 5000 + rng.randi() % 900000


func citofono_de(u: Dictionary, apto: String, responde: bool, si: String, no: String) -> Dictionary:
	var anfitrion: Dictionary = u if (not u.is_empty() and str(u.get("rol", "")) == "residente") else Sistema.residente_de_apto(apto)
	var quien: String = Sistema.nombre_completo(anfitrion) if not anfitrion.is_empty() else "Administración"
	var lugar: String = str(anfitrion.get("apto", apto)) if not anfitrion.is_empty() else "Administración"
	return {"apto": lugar, "residente": quien, "responde": responde,
		"texto": "%s (%s): «%s»" % [quien, lugar, si if responde else no]}


func caso_base(sentido: String, escenario: String, etiqueta: String, u: Dictionary) -> Dictionary:
	var placa: String = str(u["placa"]) if not u.is_empty() else placa_libre()
	var rostro: int = int(u["rostro"]) if not u.is_empty() else rostro_nuevo()
	var veh: Dictionary = Sistema.vehiculo_registrado(u, placa) if not u.is_empty() else Sistema.vehiculo_para(rng.randi() % 100000 + 100)
	return {
		"sentido": sentido, "escenario": escenario, "etiqueta": etiqueta, "usuario": u,
		"placa_delantera": placa, "placa_trasera": placa, "rostro": rostro,
		"vehiculo": {"tipo": veh["tipo"], "color": veh["color"]},
		"conductor": persona_de(u) if not u.is_empty() else persona_aleatoria(),
		"citofono": {}, "legitimo": true
	}


func generar(sentido: String) -> Dictionary:
	if sentido == "Salida":
		return generar_salida()
	return generar_entrada()


func con_otro_vehiculo(u: Dictionary) -> Dictionary:
	# Un residente con varios vehículos llega con uno de ellos (todos estan registrados).
	var lista: Array = Sistema.vehiculos_de(u)
	var v: Dictionary = lista[rng.randi() % lista.size()]
	var c: Dictionary = caso_base("Entrada", "residente_normal", "Residente (usa su vehículo registrado %s)" % str(v["placa"]), u)
	c["placa_delantera"] = str(v["placa"])
	c["placa_trasera"] = str(v["placa"])
	c["vehiculo"] = {"tipo": v["tipo"], "color": v["color"]}
	return c


func generar_entrada() -> Dictionary:
	var p: float = rng.randf()
	var u: Dictionary = {}
	var c: Dictionary = {}
	if p < 0.30:
		u = elegir(con_rol("residente", false))
		if not u.is_empty():
			return con_otro_vehiculo(u)
	if p < 0.38:
		u = elegir(con_rol("trabajador", false))
		if not u.is_empty():
			return caso_base("Entrada", "trabajador", "Trabajador (el turno se valida con la hora simulada)", u)
	if p < 0.50:
		u = elegir(con_rol("visitante", false))
		if not u.is_empty():
			c = caso_base("Entrada", "visitante", "Visitante con autorización", u)
			c["citofono"] = citofono_de({}, str(u.get("apto", "")), true, "Sí, esperamos esa visita, déjenla pasar.", "")
			return c
	if p < 0.60:
		u = elegir(con_rol("residente", false))
		if not u.is_empty():
			var legit: bool = rng.randf() < 0.45
			c = caso_base("Entrada", "conductor_distinto", "Placa del residente, pero conduce otra persona", u)
			c["rostro"] = rostro_nuevo()
			c["legitimo"] = legit
			c["conductor"] = persona_aleatoria(str(u["apellido"]) if legit else "", str(u.get("apto", "")))
			c["conductor"]["motivo"] = "familiar" if legit else "dice ser conocido"
			c["citofono"] = citofono_de(u, str(u.get("apto", "")), legit, "Sí, es mi familiar y va en mi vehículo, déjenlo pasar.", "No he prestado mi vehículo a nadie, no lo dejen entrar.")
			return c
	if p < 0.68:
		u = elegir(con_rol("residente", false))
		if not u.is_empty():
			var legit2: bool = rng.randf() < 0.5
			c = caso_base("Entrada", "vehiculo_distinto", "Placa del residente en un vehículo distinto al registrado", u)
			var otro: Dictionary = Sistema.vehiculo_para(rng.randi() % 100000 + 300)
			while str(otro["tipo"]) == str(c["vehiculo"]["tipo"]) and str(otro["color"]) == str(c["vehiculo"]["color"]):
				otro = Sistema.vehiculo_para(rng.randi() % 100000 + 300)
			c["vehiculo"] = {"tipo": otro["tipo"], "color": otro["color"]}
			c["legitimo"] = legit2
			if not legit2:
				c["rostro"] = rostro_nuevo()
				c["conductor"] = persona_aleatoria()
			c["citofono"] = citofono_de(u, str(u.get("apto", "")), legit2, "Sí, cambié de vehículo y se me olvidó actualizar el registro.", "Mi vehículo no es ese. Esa placa debe estar clonada, no lo dejen pasar.")
			return c
	if p < 0.82:
		c = caso_base("Entrada", "desconocido", "Vehículo no registrado", {})
		var apto: String = str(c["conductor"]["apto"])
		var responde: bool = rng.randf() < 0.5
		c["legitimo"] = responde
		c["citofono"] = citofono_de({}, apto, responde, "Sí, es un conocido, pueden registrarlo como visitante.", "No conozco a esa persona, no lo dejen pasar.")
		return c
	if p < 0.90:
		u = elegir(Sistema.usuarios_dentro())
		if not u.is_empty():
			c = caso_base("Entrada", "ya_dentro", "Usuario que ya figura dentro", u)
			c["legitimo"] = false
			return c
	if p < 0.95:
		u = elegir(con_rol("residente", false))
		if not u.is_empty():
			c = caso_base("Entrada", "placa_trasera_distinta", "Placa trasera distinta de la delantera", u)
			c["placa_trasera"] = placa_libre()
			c["legitimo"] = false
			return c
	u = elegir(con_rol("residente", false))
	if u.is_empty():
		return caso_base("Entrada", "desconocido", "Vehículo no registrado", {})
	return con_otro_vehiculo(u)


func generar_salida() -> Dictionary:
	var dentro: Array = Sistema.usuarios_dentro()
	if dentro.is_empty():
		return {}
	var u: Dictionary = elegir(dentro)
	var c: Dictionary = caso_base("Salida", "salida_normal", "Salida regular", u)
	if Sistema.puesto_de(int(u["id"])) != "":
		var v: Dictionary = Sistema.vehiculo_registrado(u, str(u["placa"]))
		c["vehiculo"] = {"tipo": v["tipo"], "color": v["color"]}
	if rng.randf() < 0.3:
		var legit: bool = rng.randf() < 0.4
		c["escenario"] = "salida_conductor_distinto"
		c["etiqueta"] = "Sale el vehículo con otra persona al volante"
		c["legitimo"] = legit
		if legit:
			c["rostro"] = rostro_nuevo()
			c["conductor"] = persona_aleatoria(str(u["apellido"]), str(u.get("apto", "")))
			c["conductor"]["motivo"] = "familiar"
		else:
			var otros: Array = []
			for x in Sistema.usuarios:
				if int((x as Dictionary)["id"]) != int(u["id"]):
					otros.append(x)
			var o: Dictionary = elegir(otros)
			if not o.is_empty() and rng.randf() < 0.6:
				c["rostro"] = int(o["rostro"])
				c["conductor"] = persona_de(o)
			else:
				c["rostro"] = rostro_nuevo()
				c["conductor"] = persona_aleatoria()
		c["citofono"] = citofono_de(u, str(u.get("apto", "")), legit, "Sí, lo autoricé para que saque el vehículo.", "No autoricé a nadie a sacar mi vehículo. Detengan a esa persona y que no salga con el vehículo.")
	return c
