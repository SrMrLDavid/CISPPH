extends Node3D
class_name Escenario3D

# CISPPH - Escenario 3D UNICO del conjunto residencial (todo procedural, sin modelos externos).
# Un solo lugar: calle de acceso -> garita con dos carriles y barreras -> parqueadero en circuito
# (carril de entrada, giro al fondo, carril de salida). 40 puestos: V-01..V-15 y R-01..R-25.
# Estetica inspirada en Need for Speed (Carbon / Most Wanted): atardecer naranja, brillo suave,
# asfalto oscuro, neones y farolas. Pensado para tarjetas graficas muy modestas: sin sombras por
# defecto, pocas luces reales, materiales compartidos y arboles con MultiMesh.
#
# Convenio de ejes: +X hacia el interior del conjunto, +Y arriba. Carril de ENTRADA en z=+2.8 y de SALIDA
# en z=-2.8 (conduccion por la derecha: el conductor, a la izquierda, queda del lado de la garita).

signal barrera_cambiada(carril: String, abierta: bool)

const ANCHO_CARRIL: float = 3.2
const Z_ENTRADA: float = 2.8
const Z_SALIDA: float = -2.8
const X_PARADA: float = 0.0
const X_BARRERA: float = 3.1
const X_FONDO: float = 66.0
const LADO_PUESTO: float = 8.0
const SEPARACION_PUESTOS: float = 2.6
const X_PRIMER_PUESTO: float = 9.0
const RADIO_GIRO: float = 3.0
const PUERTAS_X: Array = [14.0, 34.0, 54.0]
const SIGNO_Z: float = 1.0           # +1: entrada en z=+2.8 (ver cabecera)

var camara: Camera3D = null
var sol: DirectionalLight3D = null
var entorno: Environment = null
var modo_camara: String = "cine"
var objetivo_camara: Node3D = null
var hora_dia: float = 17.5
var calidad: int = 1                 # 0 baja, 1 media, 2 alta
var barreras: Dictionary = {}        # "entrada"/"salida" -> {pivote, luz, abierta}
var luces_calle: Array[MeshInstance3D] = []
var luces_reales: Array[OmniLight3D] = []
var material_ventanas: StandardMaterial3D = null
var sub_captura: SubViewport = null
var cam_captura: Camera3D = null
var orbita_yaw: float = 0.6
var orbita_pitch: float = 0.45
var orbita_dist: float = 34.0
var orbita_objetivo: Vector3 = Vector3(22, 1, 0)
var tiempo_cine: float = 0.0
var apagon_k: float = 0.0           # 0 = hay luz, 1 = apagon total
var _tw_apagon: Tween = null
var puestos_pos: Dictionary = {}     # puesto -> {fila, x}
var guardia: Node3D = null
var pantalla_garita: MeshInstance3D = null
var leds_lpr: Array[MeshInstance3D] = []
var _pos_camara_deseada: Vector3 = Vector3.ZERO
var _fija_pos: Vector3 = Vector3.ZERO
var _fija_mira: Vector3 = Vector3.ZERO
var fp_yaw: float = 0.0
var fp_pitch: float = 0.0
var _mira_deseada: Vector3 = Vector3.ZERO


func _ready() -> void:
	mapear_puestos()
	crear_entorno()
	crear_suelo()
	crear_marcas_y_puestos()
	crear_garita()
	crear_barreras()
	crear_edificios()
	crear_arboles()
	crear_farolas()
	crear_carteles()
	crear_camaras_lpr()
	crear_captura()
	crear_camara()
	fijar_hora(hora_dia)
	aplicar_calidad(calidad)


# ---------------------------------------------------------------------------------------------------
# utilidades de construccion
# ---------------------------------------------------------------------------------------------------

func caja(pos: Vector3, tam: Vector3, color: Color, rugosidad: float = 0.9, emision: float = 0.0, padre: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = Vehiculo3D.material(color, rugosidad, 0.0, emision)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(padre if padre != null else self).add_child(mi)
	return mi


func cilindro(pos: Vector3, radio: float, alto: float, color: Color, rugosidad: float = 0.8, padre: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radio
	cm.bottom_radius = radio
	cm.height = alto
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = Vehiculo3D.material(color, rugosidad)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(padre if padre != null else self).add_child(mi)
	return mi


func rotulo(texto: String, pos: Vector3, tam_px: int, color: Color, en_suelo: bool = false, giro_y: float = 0.0, pixel: float = 0.01) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tam_px
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.shaded = false
	l.double_sided = true
	l.position = pos
	if en_suelo:
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.rotation.y = giro_y
	else:
		l.rotation.y = giro_y
	add_child(l)
	return l


func punto(x: float, z: float, dx: float, dz: float) -> Dictionary:
	# Punto de ruta con su rumbo (el eje z se refleja segun SIGNO_Z).
	# Las rutas se escriben en "coordenadas base" (entrada = -Z); el mundo real es el espejo (entrada = +Z).
	var zz: float = -z
	var ddz: float = -dz
	return {"p": Vector3(x, 0.0, zz), "h": atan2(-ddz, dx)}


# ---------------------------------------------------------------------------------------------------
# entorno, cielo, hora
# ---------------------------------------------------------------------------------------------------

func crear_entorno() -> void:
	var cielo := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = cielo
	entorno = Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = sky
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.tonemap_exposure = 1.0
	entorno.glow_enabled = true
	entorno.glow_intensity = 0.7
	entorno.glow_bloom = 0.12
	entorno.glow_hdr_threshold = 0.9
	entorno.fog_enabled = true
	entorno.fog_density = 0.004
	entorno.adjustment_enabled = true
	entorno.adjustment_contrast = 1.12
	entorno.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = entorno
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.shadow_enabled = false
	sol.directional_shadow_max_distance = 80.0
	add_child(sol)


# claves: hora, cielo_arriba, cielo_horizonte, suelo_horizonte, sol_color, sol_energia, sol_elev, ambiente, niebla, exposicion
const CLAVES_DIA: Array = [
	[0.0, "#050914", "#101a33", "#0a0d16", "#6f86c8", 0.45, -40.0, 0.9, "#0b1226", 1.05],
	[5.5, "#1b2a55", "#d8734a", "#2a2230", "#ff9a5a", 0.6, 4.0, 0.7, "#6a4a58", 0.95],
	[8.0, "#4f86c9", "#cfd9e6", "#4a4f56", "#fff2dc", 1.3, 35.0, 1.0, "#aebbd0", 1.0],
	[13.0, "#3d7bd0", "#bcd3ec", "#555a60", "#ffffff", 1.6, 70.0, 1.15, "#b8cbe3", 1.0],
	[17.0, "#3c5c9a", "#f0a060", "#4a3d3a", "#ffb870", 1.3, 12.0, 0.9, "#d08a62", 1.0],
	[18.5, "#23305e", "#ff6a3a", "#2a2028", "#ff8a4a", 0.7, 2.0, 0.7, "#b8583c", 1.0],
	[20.5, "#0b1330", "#2a3360", "#0e111c", "#7c90d6", 0.45, -20.0, 0.9, "#141c38", 1.05],
	[24.0, "#050914", "#101a33", "#0a0d16", "#6f86c8", 0.45, -40.0, 0.9, "#0b1226", 1.05]
]


func fijar_hora(h: float) -> void:
	hora_dia = fposmod(h, 24.0)
	var a: Array = CLAVES_DIA[0]
	var b: Array = CLAVES_DIA[1]
	for i in range(CLAVES_DIA.size() - 1):
		if hora_dia >= float((CLAVES_DIA[i] as Array)[0]) and hora_dia <= float((CLAVES_DIA[i + 1] as Array)[0]):
			a = CLAVES_DIA[i]
			b = CLAVES_DIA[i + 1]
			break
	var t: float = inverse_lerp(float(a[0]), float(b[0]), hora_dia)
	var cielo: ProceduralSkyMaterial = entorno.sky.sky_material
	cielo.sky_top_color = Color(str(a[1])).lerp(Color(str(b[1])), t)
	cielo.sky_horizon_color = Color(str(a[2])).lerp(Color(str(b[2])), t)
	cielo.ground_horizon_color = Color(str(a[3])).lerp(Color(str(b[3])), t)
	cielo.ground_bottom_color = cielo.ground_horizon_color.darkened(0.5)
	cielo.sun_angle_max = 25.0
	var col_sol: Color = Color(str(a[4])).lerp(Color(str(b[4])), t)
	sol.light_color = col_sol
	sol.light_energy = lerpf(float(a[5]), float(b[5]), t)
	var elev: float = lerpf(float(a[6]), float(b[6]), t)
	sol.rotation_degrees = Vector3(-maxf(elev, 4.0), -60.0, 0.0)
	sol.visible = elev > -2.0
	entorno.ambient_light_energy = lerpf(float(a[7]), float(b[7]), t)
	entorno.fog_light_color = Color(str(a[8])).lerp(Color(str(b[8])), t)
	entorno.tonemap_exposure = lerpf(float(a[9]), float(b[9]), t)
	var noche: float = clampf(inverse_lerp(17.5, 20.5, hora_dia), 0.0, 1.0) if hora_dia > 12.0 else clampf(inverse_lerp(6.5, 4.5, hora_dia), 0.0, 1.0)
	for l in luces_calle:
		l.material_override = Vehiculo3D.material(Color("#ffd9a0"), 0.3, 0.0, 0.2 + noche * 3.0)
	if material_ventanas != null:
		material_ventanas.emission_energy_multiplier = 0.15 + noche * 1.6
	for o in luces_reales:
		o.visible = noche > 0.3 and calidad >= 1
		o.light_energy = noche * 1.4
	var tk: float = 1.0 if bool(Ajustes.valores.get("tenso", false)) else 0.0
	entorno.fog_density = 0.004 + 0.006 * tk
	if tk > 0.0:
		entorno.ambient_light_energy *= 0.6
		entorno.tonemap_exposure *= 0.88
	if apagon_k > 0.0:
		entorno.ambient_light_energy *= lerpf(1.0, 0.25, apagon_k)
		entorno.tonemap_exposure *= lerpf(1.0, 0.6, apagon_k)
		sol.light_energy *= lerpf(1.0, 0.3, apagon_k)
		for l in luces_calle:
			l.material_override = Vehiculo3D.material(Color("#ffd9a0"), 0.3, 0.0, lerpf(0.2 + noche * 3.0, 0.0, apagon_k))
		if material_ventanas != null:
			material_ventanas.emission_energy_multiplier = lerpf(0.15 + noche * 1.6, 0.02, apagon_k)
		for o in luces_reales:
			o.light_energy = noche * 1.4 * (1.0 - apagon_k)
			o.visible = o.visible and apagon_k < 0.95
		if pantalla_garita != null:
			pantalla_garita.visible = apagon_k < 0.5


# Apagon: las luces bajan en ~1.5 s (o suben al volver la energia).
func poner_apagon(si: bool) -> void:
	if _tw_apagon != null and _tw_apagon.is_valid():
		_tw_apagon.kill()
	_tw_apagon = create_tween()
	_tw_apagon.tween_method(func(k: float) -> void:
		apagon_k = k
		fijar_hora(hora_dia), apagon_k, 1.0 if si else 0.0, 1.5)


func aplicar_calidad(nivel: int) -> void:
	calidad = clampi(nivel, 0, 2)
	sol.shadow_enabled = calidad >= 2
	entorno.glow_enabled = calidad >= 1
	entorno.fog_enabled = calidad >= 1
	fijar_hora(hora_dia)


# ---------------------------------------------------------------------------------------------------
# suelo, calle, parqueadero
# ---------------------------------------------------------------------------------------------------

func plano(pos: Vector3, tam: Vector2, color: Color, rugosidad: float = 0.95) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = tam
	mi.mesh = pm
	mi.material_override = Vehiculo3D.material(color, rugosidad)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func crear_suelo() -> void:
	plano(Vector3(0, -0.06, 0), Vector2(400, 300), Color("#1d2a22"))                    # pasto/tierra de fondo
	plano(Vector3(-52, 0.0, 0), Vector2(104, 8.8), Color("#25272c"), 0.6)             # calle de acceso
	plano(Vector3(34, 0.0, 0), Vector2(72, 30), Color("#2a2c31"), 0.6)                # parqueadero asfaltado
	plano(Vector3(-52, 0.0, 17), Vector2(104, 26), Color("#2c3a30"))                  # antejardin lado norte
	plano(Vector3(-52, 0.0, -17), Vector2(104, 26), Color("#2c3a30"))
	# andenes
	for lado in [-1.0, 1.0]:
		caja(Vector3(-50.0, 0.08, 5.4 * float(lado)), Vector3(100, 0.16, 1.6), Color("#7d7f84"))
	# separador central dentro del conjunto
	caja(Vector3(34.0, 0.1, 0.0), Vector3(60, 0.2, 1.6), Color("#8f9296"))
	caja(Vector3(34.0, 0.21, 0.0), Vector3(59.2, 0.04, 1.0), Color("#3e5b3a"))
	# portico de piso (zona de la garita)
	caja(Vector3(0.0, 0.05, 0.0), Vector3(8.0, 0.1, 9.0), Color("#3a3d44"), 0.7)
	# muros perimetrales
	var limites: Array = [-2.0, 12.8, 15.2, 32.8, 35.2, 52.8, 55.2, 70.0]
	for lado in [-1.0, 1.0]:
		for i in range(0, limites.size(), 2):
			var x0: float = float(limites[i])
			var x1: float = float(limites[i + 1])
			caja(Vector3((x0 + x1) * 0.5, 0.9, 15.5 * float(lado)), Vector3(x1 - x0, 1.8, 0.4), Color("#8d7f6e"))
		for dx in PUERTAS_X:
			# marco de la puerta peatonal y puerta del vestibulo del edificio
			caja(Vector3(float(dx) - 1.3, 1.1, 15.5 * float(lado)), Vector3(0.2, 2.2, 0.5), Color("#555a62"))
			caja(Vector3(float(dx) + 1.3, 1.1, 15.5 * float(lado)), Vector3(0.2, 2.2, 0.5), Color("#555a62"))
			caja(Vector3(float(dx), 2.3, 15.5 * float(lado)), Vector3(2.8, 0.2, 0.5), Color("#555a62"))
			caja(Vector3(float(dx), 1.1, (19.45) * float(lado)), Vector3(1.6, 2.2, 0.12), Color("#ffd9a0"), 0.4, 0.8)
	caja(Vector3(70.2, 0.9, 0.0), Vector3(0.4, 1.8, 31), Color("#8d7f6e"))


func mapear_puestos() -> void:
	puestos_pos.clear()
	# Fila A (junto al carril de entrada): V-01..V-15 y R-01..R-05. Fila B (junto a la salida): R-06..R-25.
	for i in range(20):
		var x: float = X_PRIMER_PUESTO + float(i) * SEPARACION_PUESTOS
		var nombreA: String = "V-%02d" % (i + 1) if i < 15 else "R-%02d" % (i - 14)
		puestos_pos[nombreA] = {"fila": "A", "x": x}
		puestos_pos["R-%02d" % (i + 6)] = {"fila": "B", "x": x}


func crear_marcas_y_puestos() -> void:
	var blanco := Color("#e8e8e8")
	var amarillo := Color("#e0b422")
	# rayas centrales discontinuas de las calles de entrada
	for i in range(0, 20):
		caja(Vector3(-4.0 - float(i) * 5.0, 0.02, 0.0), Vector3(2.4, 0.01, 0.12), amarillo)
	# bordes
	for lado in [-1.0, 1.0]:
		caja(Vector3(-50.0, 0.02, 4.1 * float(lado)), Vector3(100, 0.01, 0.1), blanco)
	# linea de pare en cada carril
	caja(Vector3(-2.6, 0.02, Z_ENTRADA * SIGNO_Z), Vector3(0.35, 0.01, ANCHO_CARRIL), blanco)
	caja(Vector3(-2.6, 0.02, Z_SALIDA * SIGNO_Z), Vector3(0.35, 0.01, ANCHO_CARRIL), blanco)
	rotulo("ENTRADA", Vector3(-9.0, 0.03, Z_ENTRADA * SIGNO_Z), 90, Color("#7cff9c"), true, -PI * 0.5, 0.012)
	rotulo("SALIDA", Vector3(-9.0, 0.03, Z_SALIDA * SIGNO_Z), 90, Color("#ff9c7c"), true, PI * 0.5, 0.012)
	# lineas de puestos
	for fila in ["A", "B"]:
		var zc: float = LADO_PUESTO * SIGNO_Z * (1.0 if fila == "A" else -1.0)
		for i in range(21):
			var x: float = X_PRIMER_PUESTO + float(i) * SEPARACION_PUESTOS - SEPARACION_PUESTOS * 0.5
			caja(Vector3(x, 0.02, zc), Vector3(0.08, 0.01, 5.0), blanco)
		caja(Vector3(X_PRIMER_PUESTO + 9.5 * SEPARACION_PUESTOS - SEPARACION_PUESTOS * 0.5, 0.15, zc + (2.7 if fila == "A" else -2.7) * SIGNO_Z), Vector3(20 * SEPARACION_PUESTOS, 0.3, 0.3), Color("#565a62"))
	for nombre in puestos_pos.keys():
		var info: Dictionary = puestos_pos[nombre]
		var zc2: float = LADO_PUESTO * SIGNO_Z * (1.0 if str(info["fila"]) == "A" else -1.0)
		var color: Color = Color("#7ad7ff") if str(nombre).begins_with("V-") else Color("#f0f0f0")
		rotulo(str(nombre), Vector3(float(info["x"]), 0.03, zc2 + (-1.8 if str(info["fila"]) == "A" else 1.8) * SIGNO_Z), 48, color, true, 0.0, 0.0075)
	# flechas del circuito
	for x in [14.0, 30.0, 46.0]:
		rotulo("▶", Vector3(x, 0.03, Z_ENTRADA * SIGNO_Z), 140, Color("#d8d8d8"), true, -PI * 0.5, 0.012)
		rotulo("◀", Vector3(x + 7.0, 0.03, Z_SALIDA * SIGNO_Z), 140, Color("#d8d8d8"), true, PI * 0.5, 0.012)


# ---------------------------------------------------------------------------------------------------
# garita, barreras, carteles
# ---------------------------------------------------------------------------------------------------

func crear_garita() -> void:
	var raiz := Node3D.new()
	raiz.name = "Garita"
	raiz.position = Vector3(-0.5, 0.0, 0.0)
	add_child(raiz)
	var pared := Color("#d9d2c4")
	caja(Vector3(0, 0.12, 0), Vector3(3.6, 0.24, 2.3), Color("#5c5e66"), 0.8, 0.0, raiz)
	# paredes con ventanales: columnas en las esquinas y vidrio al frente/atras
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			caja(Vector3(1.7 * float(sx), 1.35, 1.05 * float(sz)), Vector3(0.2, 2.2, 0.2), pared, 0.8, 0.0, raiz)
	caja(Vector3(0, 0.55, 1.05), Vector3(3.6, 0.8, 0.12), pared, 0.8, 0.0, raiz)
	caja(Vector3(0, 0.55, -1.05), Vector3(3.6, 0.8, 0.12), pared, 0.8, 0.0, raiz)
	for sz in [-1.0, 1.0]:
		var vidrio := caja(Vector3(0, 1.7, 1.05 * float(sz)), Vector3(3.3, 1.2, 0.05), Color(0.35, 0.55, 0.7, 0.35), 0.1, 0.0, raiz)
		vidrio.material_override = Vehiculo3D.material(Color(0.35, 0.55, 0.7, 0.35), 0.1, 0.0, 0.0, true)
	caja(Vector3(-1.75, 1.35, 0), Vector3(0.12, 2.2, 2.0), pared, 0.8, 0.0, raiz)
	# techo
	caja(Vector3(0, 2.55, 0), Vector3(4.6, 0.2, 3.4), Color("#2c3340"), 0.7, 0.0, raiz)
	caja(Vector3(0, 2.7, 0), Vector3(4.7, 0.06, 3.5), Color("#e8a23a"), 0.5, 0.35, raiz)
	# escritorio y pantalla
	caja(Vector3(0.1, 0.75, 0.0), Vector3(2.4, 0.08, 0.7), Color("#3b2f26"), 0.8, 0.0, raiz)
	pantalla_garita = caja(Vector3(0.1, 1.15, 0.0), Vector3(0.8, 0.45, 0.04), Color("#3ad0ff"), 0.3, 1.2, raiz)
	caja(Vector3(-1.0, 1.15, 0.0), Vector3(0.5, 0.35, 0.04), Color("#7cff9c"), 0.3, 0.9, raiz)
	# guardia (persona sentada frente al monitor, mirando hacia el carril de entrada)
	caja(Vector3(0.1, 0.4, -0.6), Vector3(0.45, 0.08, 0.45), Color("#222831"), 0.8, 0.0, raiz)
	var g := Persona3D.new()
	g.construir(1, "guardia")
	g.position = Vector3(0.1, 0.0, -0.62)
	g.rotation.y = -PI * 0.5
	raiz.add_child(g)
	g.sentar(true)
	guardia = g
	# luz interior
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 2.0, 0)
	luz.omni_range = 7.0
	luz.light_color = Color("#ffe3b0")
	luz.light_energy = 0.0
	raiz.add_child(luz)
	luces_reales.append(luz)


func crear_barreras() -> void:
	for carril in ["entrada", "salida"]:
		var z_lane: float = (Z_ENTRADA if carril == "entrada" else Z_SALIDA) * SIGNO_Z
		var z_poste: float = z_lane - (ANCHO_CARRIL * 0.5 + 0.35) * signf(z_lane)   # poste en el borde exterior
		var z_poste_int: float = signf(z_lane) * (ANCHO_CARRIL * 0.5 + 0.15) + z_lane   # no se usa
		z_poste_int = z_poste_int
		var z_borde: float = z_lane + signf(z_lane) * (ANCHO_CARRIL * 0.5 + 0.35)
		var raiz := Node3D.new()
		raiz.name = "Barrera_" + carril
		raiz.position = Vector3(X_BARRERA * (1.0 if carril == "entrada" else -1.0), 0.0, z_borde)
		add_child(raiz)
		caja(Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.5), Color("#2d3138"), 0.7, 0.0, raiz)
		var luz_estado := caja(Vector3(0, 1.18, 0), Vector3(0.28, 0.12, 0.28), Color("#ff3030"), 0.3, 2.0, raiz)
		var pivote := Node3D.new()
		pivote.position = Vector3(0, 0.95, 0)
		raiz.add_child(pivote)
		# brazo hacia el centro de la calzada (direccion -signo(z_lane)), rayado rojo/blanco
		var dir: float = -signf(z_lane)
		var largo: float = ANCHO_CARRIL + 0.7
		for i in range(6):
			var c: Color = Color("#f4f4f4") if i % 2 == 0 else Color("#d62b2b")
			caja(Vector3(0, 0, dir * (0.25 + float(i) * largo / 6.0 + largo / 12.0)), Vector3(0.1, 0.12, largo / 6.0), c, 0.5, 0.0, pivote)
		barreras[carril] = {"pivote": pivote, "luz": luz_estado, "abierta": false, "dir": dir}


func barrera_abierta(carril: String) -> bool:
	return bool((barreras[carril] as Dictionary)["abierta"])


func mover_barrera(carril: String, abrir: bool, rapido: bool = false) -> void:
	var info: Dictionary = barreras[carril]
	info["abierta"] = abrir
	var pivote: Node3D = info["pivote"]
	var dir: float = float(info["dir"])
	# El brazo se extiende a lo largo de z; girar sobre X lo levanta.
	var objetivo: float = (-dir * deg_to_rad(82.0)) if abrir else 0.0
	var tw := create_tween()
	tw.tween_property(pivote, "rotation:x", objetivo, 0.15 if rapido else 0.9).set_trans(Tween.TRANS_SINE)
	var luz: MeshInstance3D = info["luz"]
	luz.material_override = Vehiculo3D.material(Color("#33ff66") if abrir else Color("#ff3030"), 0.3, 0.0, 2.0)
	barrera_cambiada.emit(carril, abrir)


func crear_carteles() -> void:
	# Portico de bienvenida con el nombre del conjunto
	var z_ext: float = 6.2
	for lado in [-1.0, 1.0]:
		caja(Vector3(5.4, 2.4, z_ext * float(lado)), Vector3(0.7, 4.8, 0.7), Color("#6c6256"), 0.8)
	caja(Vector3(5.4, 4.9, 0.0), Vector3(0.8, 0.9, 13.4), Color("#2b2f3a"), 0.6)
	rotulo("ROBLES DEL NORTE · P.H.", Vector3(5.82, 4.9, 0.0), 78, Color("#ffd27a"), false, PI * 0.5, 0.012)
	rotulo("ROBLES DEL NORTE · P.H.", Vector3(4.98, 4.9, 0.0), 78, Color("#ffd27a"), false, -PI * 0.5, 0.012)
	rotulo("ENTRADA", Vector3(5.82, 3.9, Z_ENTRADA * SIGNO_Z), 60, Color("#7cff9c"), false, PI * 0.5, 0.012)
	rotulo("SALIDA", Vector3(5.82, 3.9, Z_SALIDA * SIGNO_Z), 60, Color("#ff9c7c"), false, PI * 0.5, 0.012)
	rotulo("PARE", Vector3(-2.6, 2.4, Z_ENTRADA * SIGNO_Z + 1.8), 44, Color("#ff4040"), false, -PI * 0.5, 0.01)
	rotulo("MÁX 10 km/h", Vector3(-14.0, 2.6, 6.2 * SIGNO_Z), 46, Color("#ffffff"), false, -PI * 0.5, 0.01)


func crear_camaras_lpr() -> void:
	# Mastiles con camara de placa y camara facial (decorativos; las capturas reales las hace la camara virtual).
	for carril in ["entrada", "salida"]:
		var z_lane: float = (Z_ENTRADA if carril == "entrada" else Z_SALIDA) * SIGNO_Z
		var z_poste: float = z_lane + signf(z_lane) * (ANCHO_CARRIL * 0.5 + 0.5)
		cilindro(Vector3(2.2, 1.4, z_poste), 0.07, 2.8, Color("#444a55"))
		caja(Vector3(2.15, 2.7, z_poste - signf(z_lane) * 0.15), Vector3(0.35, 0.18, 0.18), Color("#1b1f27"), 0.5)
		caja(Vector3(2.15, 2.25, z_poste - signf(z_lane) * 0.15), Vector3(0.3, 0.16, 0.16), Color("#1b1f27"), 0.5)
		var led := caja(Vector3(2.35, 2.7, z_poste - signf(z_lane) * 0.15), Vector3(0.05, 0.05, 0.05), Color("#ff2020"), 0.3, 3.0)
		leds_lpr.append(led)


# ---------------------------------------------------------------------------------------------------
# edificios, arboles, farolas
# ---------------------------------------------------------------------------------------------------

func textura_ventanas(semilla: int) -> ImageTexture:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color("#3a3f4a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	for fila in range(14):
		for col in range(6):
			var encendida: bool = rng.randf() < 0.45
			var c: Color = Color("#ffe3a0") if encendida else Color("#171c26")
			img.fill_rect(Rect2i(4 + col * 10, 4 + fila * 9, 6, 6), c)
	return ImageTexture.create_from_image(img)


func crear_edificios() -> void:
	material_ventanas = StandardMaterial3D.new()
	var tex: ImageTexture = textura_ventanas(7)
	material_ventanas.albedo_texture = tex
	material_ventanas.emission_enabled = true
	material_ventanas.emission_texture = tex
	material_ventanas.emission_energy_multiplier = 0.4
	material_ventanas.uv1_scale = Vector3(3.0, 1.0, 1.0)
	material_ventanas.roughness = 0.9
	var torres: Array = [[14.0, 5.0], [34.0, 6.0], [54.0, 5.0]]
	var i: int = 0
	for t in torres:
		for lado in [-1.0, 1.0]:
			var alto: float = 18.0 + float((i * 7) % 5) * 3.0
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(12.0, alto, 7.0)
			mi.mesh = bm
			mi.material_override = material_ventanas
			mi.position = Vector3(float(t[0]), alto * 0.5, (13.0 + 8.0 * 0.5) * float(lado) + 6.0 * float(lado))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			caja(Vector3(float(t[0]), alto + 0.2, mi.position.z), Vector3(12.4, 0.4, 7.4), Color("#3b3f48"))
			i += 1
	# locales y casas frente a la calle de acceso
	var colores: Array[Color] = [Color("#9a6a54"), Color("#6f7f93"), Color("#a99a6d"), Color("#7a5f86"), Color("#5f8a78")]
	for k in range(9):
		for lado in [-1.0, 1.0]:
			var ancho: float = 9.0
			var alto2: float = 5.0 + float((k * 3 + (1 if lado > 0 else 0)) % 4) * 2.0
			caja(Vector3(-12.0 - float(k) * 11.0, alto2 * 0.5, (11.0 + 3.0) * float(lado) + 5.0 * float(lado)), Vector3(ancho, alto2, 7.0), colores[(k + (1 if lado > 0 else 0)) % colores.size()], 0.9)
			var vent := caja(Vector3(-12.0 - float(k) * 11.0, alto2 * 0.5 + 0.5, (11.0 + 3.0) * float(lado) + 5.0 * float(lado) - 3.55 * float(lado)), Vector3(ancho * 0.7, 1.3, 0.08), Color("#ffd9a0"), 0.4, 0.5)
			luces_calle.append(vent)


func crear_arboles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var troncos := MultiMeshInstance3D.new()
	var copas := MultiMeshInstance3D.new()
	var mt := MultiMesh.new()
	var mc := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mc.transform_format = MultiMesh.TRANSFORM_3D
	var cil := CylinderMesh.new()
	cil.top_radius = 0.15
	cil.bottom_radius = 0.22
	cil.height = 2.0
	cil.radial_segments = 5
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 1.5
	cono.height = 3.6
	cono.radial_segments = 6
	mt.mesh = cil
	mc.mesh = cono
	var spots: Array[Vector2] = []
	for k in range(14):
		spots.append(Vector2(-10.0 - float(k) * 7.0, 8.0 * SIGNO_Z))
		spots.append(Vector2(-14.0 - float(k) * 7.0, -8.0 * SIGNO_Z))
	for k in range(9):
		spots.append(Vector2(8.0 + float(k) * 7.0, 13.2))
		spots.append(Vector2(8.0 + float(k) * 7.0, -13.2))
	mt.instance_count = spots.size()
	mc.instance_count = spots.size()
	for i in range(spots.size()):
		var s: float = rng.randf_range(0.8, 1.3)
		mt.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(spots[i].x, 1.0 * s, spots[i].y)))
		mc.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(spots[i].x, 3.3 * s, spots[i].y)))
	troncos.multimesh = mt
	copas.multimesh = mc
	troncos.material_override = Vehiculo3D.material(Color("#5a3d27"), 0.95)
	copas.material_override = Vehiculo3D.material(Color("#2f6a3a"), 0.95)
	troncos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(troncos)
	add_child(copas)


func crear_farolas() -> void:
	var xs: Array[float] = []
	for k in range(9):
		xs.append(-8.0 - float(k) * 12.0)
	for k in range(5):
		xs.append(12.0 + float(k) * 13.0)
	for x in xs:
		for lado in [-1.0, 1.0]:
			if x > 0.0 and lado > 0.0 and false:
				continue
			var z: float = 5.6 * float(lado) if x < 0.0 else 4.3 * float(lado)
			cilindro(Vector3(x, 3.0, z), 0.06, 6.0, Color("#3a3f48"))
			caja(Vector3(x, 6.0, z - 0.7 * float(lado)), Vector3(0.1, 0.1, 1.4), Color("#3a3f48"))
			var cabeza := caja(Vector3(x, 5.92, z - 1.3 * float(lado)), Vector3(0.7, 0.12, 0.35), Color("#ffd9a0"), 0.3, 0.2)
			luces_calle.append(cabeza)
	# luces reales (pocas): zona de garita
	for pos in [Vector3(-6.0, 5.0, 0.0), Vector3(8.0, 5.0, 0.0), Vector3(30.0, 5.0, 0.0)]:
		var o := OmniLight3D.new()
		o.position = pos
		o.omni_range = 18.0
		o.light_color = Color("#ffd9a0")
		o.light_energy = 0.0
		add_child(o)
		luces_reales.append(o)


# ---------------------------------------------------------------------------------------------------
# rutas
# ---------------------------------------------------------------------------------------------------

func pose_puesto(puesto: String) -> Dictionary:
	# Posicion y rumbo finales de un vehiculo estacionado.
	var info: Dictionary = puestos_pos[puesto]
	if str(info["fila"]) == "A":
		var p: Dictionary = punto(float(info["x"]), -LADO_PUESTO, 0.0, -1.0)
		return p
	return punto(float(info["x"]), LADO_PUESTO, 0.0, 1.0)


func ruta_llegada_entrada() -> Array:
	# Desde la calle (x=-80) hasta detenerse en la garita.
	var r: Array = []
	for x in [-80.0, -60.0, -40.0, -25.0, -14.0, -6.0, X_PARADA]:
		r.append(punto(float(x), -Z_ENTRADA, 1.0, 0.0))
	return r


func ruta_llegada_salida() -> Array:
	# Tramo final del carril de salida hacia la garita (x decreciente hasta X_PARADA).
	var r: Array = []
	for x in [20.0, 12.0, 6.0, X_PARADA]:
		r.append(punto(float(x), -Z_SALIDA, -1.0, 0.0))
	return r


func ruta_estacionar(puesto: String) -> Array:
	# Desde la garita (entrada) hasta el puesto, retomando el circuito.
	var info: Dictionary = puestos_pos[puesto]
	var xs: float = float(info["x"])
	var r: Array = []
	var zl: float = -Z_ENTRADA            # carril de entrada en coordenadas base (z negativo = fila A)
	for x in [X_PARADA, 6.0]:
		r.append(punto(float(x), zl, 1.0, 0.0))
	if str(info["fila"]) == "A":
		r.append_array(arco_entrada_A(xs))
	else:
		# recorre el circuito completo: fondo, vuelta y entrada a la fila B desde el carril de salida
		r.append(punto(xs - 20.0, zl, 1.0, 0.0))
		r.append(punto(X_FONDO - 8.0, zl, 1.0, 0.0))
		r.append_array(giro_fondo())
		r.append_array(arco_entrada_B(xs))
	return r


func arco_entrada_A(xs: float) -> Array:
	var r: Array = []
	var zl: float = -Z_ENTRADA
	r.append(punto(xs - RADIO_GIRO - 6.0, zl, 1.0, 0.0))
	r.append(punto(xs - RADIO_GIRO - 1.0, zl, 1.0, 0.0))
	var cx: float = xs - RADIO_GIRO
	var cz: float = zl - RADIO_GIRO
	for k in range(0, 9):
		var fi: float = deg_to_rad(90.0 - 90.0 * float(k) / 8.0)
		r.append(punto(cx + RADIO_GIRO * cos(fi), cz + RADIO_GIRO * sin(fi), sin(fi), -cos(fi)))
	r.append(punto(xs, -LADO_PUESTO + 1.0, 0.0, -1.0))
	r.append(punto(xs, -LADO_PUESTO, 0.0, -1.0))
	return r


func arco_entrada_B(xs: float) -> Array:
	var r: Array = []
	var zl: float = -Z_SALIDA                 # carril de salida en coordenadas base (z positivo)
	r.append(punto(xs + RADIO_GIRO + 6.0, zl, -1.0, 0.0))
	r.append(punto(xs + RADIO_GIRO + 1.0, zl, -1.0, 0.0))
	var cx: float = xs + RADIO_GIRO
	var cz: float = zl + RADIO_GIRO
	for k in range(0, 9):
		var fi: float = deg_to_rad(-90.0 - 90.0 * float(k) / 8.0)
		r.append(punto(cx + RADIO_GIRO * cos(fi), cz + RADIO_GIRO * sin(fi), sin(fi), -cos(fi)))
	r.append(punto(xs, LADO_PUESTO - 1.0, 0.0, 1.0))
	r.append(punto(xs, LADO_PUESTO, 0.0, 1.0))
	return r


func giro_fondo() -> Array:
	var r: Array = []
	for k in range(0, 13):
		var a: float = PI * float(k) / 12.0
		r.append(punto(X_FONDO + 2.8 * sin(a), -2.8 * cos(a) * 1.0 * -1.0 * -1.0, cos(a), sin(a)))
	return r


func ruta_hacia_salida(puesto: String) -> Array:
	# Despues de retroceder para salir del puesto: hasta detenerse en la garita de salida.
	var info: Dictionary = puestos_pos[puesto]
	var xs: float = float(info["x"])
	var r: Array = []
	if str(info["fila"]) == "A":
		# queda en el carril de entrada mirando hacia el fondo: sigue, da la vuelta y regresa por el carril de salida
		r.append(punto(xs - RADIO_GIRO, -Z_ENTRADA, 1.0, 0.0))
		r.append(punto(X_FONDO - 8.0, -Z_ENTRADA, 1.0, 0.0))
		r.append_array(giro_fondo())
	else:
		r.append(punto(xs + RADIO_GIRO, -Z_SALIDA, -1.0, 0.0))
	for x in [30.0, 20.0, 12.0, 6.0, X_PARADA]:
		if x < (xs + RADIO_GIRO if str(info["fila"]) == "B" else 1000.0):
			r.append(punto(float(x), -Z_SALIDA, -1.0, 0.0))
	return r


func ruta_retroceso_puesto(puesto: String) -> Array:
	# Es la ruta de estacionamiento del tramo final (arco + recta); se recorre al reves para salir.
	var info: Dictionary = puestos_pos[puesto]
	var xs: float = float(info["x"])
	if str(info["fila"]) == "A":
		return arco_entrada_A(xs)
	return arco_entrada_B(xs)


func ruta_salir_a_la_calle() -> Array:
	var r: Array = []
	for x in [X_PARADA, -6.0, -14.0, -30.0, -50.0, -80.0]:
		r.append(punto(float(x), -Z_SALIDA, -1.0, 0.0))
	return r


func ruta_continuar_entrada_a_calle() -> Array:
	return []


func puerta_cercana(x: float) -> float:
	var mejor: float = float(PUERTAS_X[0])
	for d in PUERTAS_X:
		if absf(float(d) - x) < absf(mejor - x):
			mejor = float(d)
	return mejor


# Ruta a pie (Array de Vector3) desde la puerta del conductor de un vehiculo ESTACIONADO hasta el vestibulo del edificio.
func ruta_peaton_a_edificio(auto: Vehiculo3D) -> Array:
	var ancho: float = auto.ancho_total()
	var largo: float = auto.largo_total()
	var zl: float = -(ancho * 0.5 + 0.55)
	var p0: Vector3 = auto.to_global(Vector3(0.2, 0.0, zl))
	var p1: Vector3 = auto.to_global(Vector3(largo * 0.5 + 1.1, 0.0, zl))
	var lado: float = 1.0 if auto.position.z > 0.0 else -1.0
	var dx: float = puerta_cercana(auto.position.x)
	p0.y = 0.0
	p1.y = 0.0
	return [p0, p1, Vector3(p1.x, 0.0, lado * 12.8), Vector3(dx, 0.0, lado * 13.6), Vector3(dx, 0.0, lado * 15.4), Vector3(dx, 0.0, lado * 19.0)]


func ruta_peaton_desde_edificio(auto: Vehiculo3D) -> Array:
	var r: Array = ruta_peaton_a_edificio(auto)
	r.reverse()
	return r


# ---------------------------------------------------------------------------------------------------
# camara
# ---------------------------------------------------------------------------------------------------

func crear_camara() -> void:
	camara = Camera3D.new()
	camara.fov = 62.0
	camara.far = 400.0
	camara.near = 0.1
	add_child(camara)
	camara.current = true
	cambiar_camara("cine")


func cambiar_camara(modo: String) -> void:
	modo_camara = modo


func camara_fija(pos: Vector3, mira: Vector3, instantanea: bool = false) -> void:
	_fija_pos = pos
	_fija_mira = mira
	modo_camara = "fija"
	if instantanea and camara != null:
		camara.position = pos
		_mira_deseada = mira


func actualizar_camara(delta: float) -> void:
	var pos: Vector3 = camara.position
	var mira: Vector3 = _mira_deseada
	match modo_camara:
		"cine":
			tiempo_cine += delta * 0.07
			var a: float = tiempo_cine
			pos = Vector3(8.0 + cos(a) * 26.0, 4.2 + sin(a * 1.7) * 1.2, sin(a) * 16.0)
			mira = Vector3(6.0, 1.2, 0.0)
		"garita":
			pos = Vector3(-5.0, 2.3, 1.9)
			mira = Vector3(0.6, 1.0, Z_ENTRADA * SIGNO_Z)
		"seguridad":
			pos = Vector3(-12.0, 22.0, 20.0 * SIGNO_Z)
			mira = Vector3(26.0, 0.0, 0.0)
		"alta":
			pos = Vector3(32.0, 52.0, 0.5)
			mira = Vector3(32.0, 0.0, 0.0)
		"libre":
			var dir := Vector3(cos(orbita_pitch) * cos(orbita_yaw), sin(orbita_pitch), cos(orbita_pitch) * sin(orbita_yaw))
			pos = orbita_objetivo + dir * orbita_dist
			mira = orbita_objetivo
		"fija":
			pos = _fija_pos
			mira = _fija_mira
		"puesto":
			# Primera persona: el guarda sentado en la garita. Clic derecho + mover el raton mira alrededor (limitado).
			pos = Vector3(-0.4, 1.5, -0.55)
			var dir2 := Vector3(sin(fp_yaw) * cos(fp_pitch), sin(fp_pitch), cos(fp_yaw) * cos(fp_pitch))
			mira = pos + dir2 * 5.0
		"robo":
			if objetivo_camara != null and is_instance_valid(objetivo_camara):
				var t: float = float(Time.get_ticks_msec()) / 1000.0 * 0.35
				var c: Vector3 = objetivo_camara.global_position
				pos = c + Vector3(cos(t) * 3.4, 1.35, sin(t) * 3.4)
				mira = c + Vector3(0, 1.0, 0)
			else:
				cambiar_camara("seguridad")
		"seguir":
			if objetivo_camara != null and is_instance_valid(objetivo_camara):
				var yaw: float = objetivo_camara.rotation.y
				var atras := Vector3(-cos(yaw), 0.0, sin(yaw))
				pos = objetivo_camara.global_position + atras * 8.0 + Vector3(0, 3.2, 0)
				mira = objetivo_camara.global_position + Vector3(0, 0.9, 0)
			else:
				cambiar_camara("seguridad")
	var k: float = clampf(delta * 3.0, 0.0, 1.0)
	if modo_camara == "libre":
		k = 1.0
	camara.position = camara.position.lerp(pos, k)
	_mira_deseada = _mira_deseada.lerp(mira, k)
	camara.look_at(_mira_deseada, Vector3.UP)


func _process(delta: float) -> void:
	if camara != null:
		actualizar_camara(delta)
	# parpadeo de los leds de las camaras LPR
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	for led in leds_lpr:
		led.visible = int(t * 2.0) % 2 == 0


func _unhandled_input(evento: InputEvent) -> void:
	if modo_camara == "puesto":
		if evento is InputEventMouseMotion and (evento.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			fp_yaw = clampf(fp_yaw + evento.relative.x * 0.004 * float(Ajustes.valores.get("sens_camara", 1.0)), -1.3, 1.3)
			fp_pitch = clampf(fp_pitch - evento.relative.y * 0.004 * float(Ajustes.valores.get("sens_camara", 1.0)), -0.5, 0.5)
		return
	if modo_camara != "libre":
		return
	if evento is InputEventMouseMotion and (evento.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		orbita_yaw -= evento.relative.x * 0.006
		orbita_pitch = clampf(orbita_pitch + evento.relative.y * 0.005, 0.05, 1.45)
	elif evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbita_dist = clampf(orbita_dist * 0.9, 5.0, 120.0)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbita_dist = clampf(orbita_dist * 1.1, 5.0, 120.0)


# ---------------------------------------------------------------------------------------------------
# camaras virtuales (capturas de placa y rostro)
# ---------------------------------------------------------------------------------------------------

func crear_captura() -> void:
	sub_captura = SubViewport.new()
	sub_captura.size = Vector2i(256, 160)
	sub_captura.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub_captura.transparent_bg = false
	add_child(sub_captura)
	cam_captura = Camera3D.new()
	cam_captura.fov = 48.0
	sub_captura.add_child(cam_captura)


# tipo: "placa_delantera" | "placa_trasera" | "rostro". Devuelve un Image 256x160.
func capturar(vehiculo: Vehiculo3D, tipo: String) -> Image:
	var largo: float = vehiculo.largo_total()
	var ancho: float = vehiculo.ancho_total()
	var desde: Vector3
	var hacia: Vector3
	match tipo:
		"placa_delantera":
			desde = vehiculo.to_global(Vector3(largo * 0.5 + 1.1, 0.62, 0.0))
			hacia = vehiculo.to_global(Vector3(largo * 0.5, 0.5, 0.0))
		"placa_trasera":
			desde = vehiculo.to_global(Vector3(-largo * 0.5 - 1.1, 0.68, 0.0))
			hacia = vehiculo.to_global(Vector3(-largo * 0.5, 0.55, 0.0))
		_:
			var x_cond: float = 0.4 if vehiculo.tipo != "moto" else -0.2
			desde = vehiculo.to_global(Vector3(x_cond + 0.75, 1.3, -ancho * 0.22 + 0.05))
			hacia = vehiculo.to_global(Vector3(x_cond, 1.3, -ancho * 0.22))
	cam_captura.global_position = desde
	cam_captura.look_at(hacia, Vector3.UP)
	cam_captura.fov = 40.0
	cam_captura.near = 0.05
	var glow_antes: bool = entorno.glow_enabled
	entorno.glow_enabled = false
	sub_captura.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sub_captura.get_texture().get_image()
	entorno.glow_enabled = glow_antes
	return img
