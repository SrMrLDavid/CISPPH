extends Node3D
class_name Vehiculo3D

# CISPPH - Vehiculo 3D procedural de pocos poligonos (sin archivos de modelo).
# Eje local: +X = frente, +Y = arriba, Z = ancho. Cuerpo y cabina se extruyen desde un perfil lateral.
# Incluye: ruedas que giran, luces (delanteras/traseras/freno), placas legibles (Label3D), conductor
# visible tras el vidrio y un neon opcional bajo el chasis (guino a Need for Speed).

signal llego

static var _materiales: Dictionary = {}

const PERFILES: Dictionary = {
	"sedan": {"largo": 4.5, "ancho": 1.82, "rueda": 0.34, "eje": 1.38,
		"cuerpo": [[-2.25, 0.34], [2.25, 0.34], [2.3, 0.62], [2.05, 0.84], [0.95, 0.94], [-1.9, 0.94], [-2.3, 0.82]],
		"cabina": [[-1.3, 0.94], [-0.72, 1.42], [0.5, 1.42], [1.15, 0.94]]},
	"suv": {"largo": 4.6, "ancho": 1.9, "rueda": 0.38, "eje": 1.4,
		"cuerpo": [[-2.3, 0.42], [2.3, 0.42], [2.35, 0.8], [2.1, 1.02], [1.2, 1.1], [-2.0, 1.1], [-2.35, 0.95]],
		"cabina": [[-2.0, 1.1], [-1.9, 1.7], [0.7, 1.7], [1.3, 1.1]]},
	"hatchback": {"largo": 3.9, "ancho": 1.74, "rueda": 0.32, "eje": 1.2,
		"cuerpo": [[-1.95, 0.34], [1.95, 0.34], [2.0, 0.6], [1.8, 0.82], [0.8, 0.92], [-1.8, 0.92], [-2.0, 0.78]],
		"cabina": [[-1.85, 0.92], [-1.4, 1.46], [0.4, 1.46], [1.0, 0.92]]},
	"camioneta": {"largo": 5.2, "ancho": 1.95, "rueda": 0.4, "eje": 1.6,
		"cuerpo": [[-2.6, 0.45], [2.6, 0.45], [2.65, 0.85], [2.4, 1.08], [1.5, 1.14], [0.2, 1.14], [0.2, 0.95], [-2.6, 0.95]],
		"cabina": [[0.2, 1.14], [0.3, 1.75], [1.3, 1.75], [1.75, 1.14]]},
}

var tipo: String = "sedan"
var color_pintura: Color = Color("#c0392b")
var placa_delantera: String = "ABC-123"
var placa_trasera: String = "ABC-123"
var rostro: int = 1
var con_neon: bool = false
var perfil: Dictionary = {}
var ruedas: Array[Node3D] = []
var luces_frenos: Array[MeshInstance3D] = []
var luces_frente: Array[MeshInstance3D] = []
var faros: Array[SpotLight3D] = []
var neon: MeshInstance3D = null
var conductor_nodo: Node3D = null

# movimiento
var ruta: Array = []                 # [{p: Vector3, h: float}]
var indice: int = 0
var paso: int = 1                    # +1 recorre hacia delante, -1 recorre al reves (marcha atras)
var velocidad: float = 6.0
var velocidad_actual: float = 0.0
var se_mueve: bool = false
var factor_tiempo: float = 1.0
var _giro_rueda: float = 0.0
var frenando: bool = false


static func material(color: Color, rugosidad: float = 0.7, metal: float = 0.0, emision: float = 0.0, transparente: bool = false) -> StandardMaterial3D:
	var clave: String = "%s_%.2f_%.2f_%.2f_%s" % [color.to_html(true), rugosidad, metal, emision, str(transparente)]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emision > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emision
	if transparente:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiales[clave] = m
	return m


static func malla_extruida(puntos: Array, ancho: float) -> ArrayMesh:
	var poli := PackedVector2Array()
	for p in puntos:
		poli.append(Vector2(float(p[0]), float(p[1])))
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poli)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mitad: float = ancho * 0.5
	for lado in [-1.0, 1.0]:
		for i in range(0, tri.size(), 3):
			for k in range(3):
				var v: Vector2 = poli[tri[i + k]]
				st.add_vertex(Vector3(v.x, v.y, mitad * float(lado)))
	for i in range(poli.size()):
		var a: Vector2 = poli[i]
		var b: Vector2 = poli[(i + 1) % poli.size()]
		var a1 := Vector3(a.x, a.y, -mitad)
		var a2 := Vector3(a.x, a.y, mitad)
		var b1 := Vector3(b.x, b.y, -mitad)
		var b2 := Vector3(b.x, b.y, mitad)
		for v3 in [a1, b1, b2, a1, b2, a2]:
			st.add_vertex(v3)
	st.generate_normals()
	return st.commit()


func construir(datos: Dictionary) -> void:
	tipo = str(datos.get("tipo", "sedan"))
	color_pintura = Color(str(datos.get("color", "#c0392b")))
	placa_delantera = str(datos.get("placa_delantera", "ABC-123"))
	placa_trasera = str(datos.get("placa_trasera", placa_delantera))
	rostro = int(datos.get("rostro", 1))
	con_neon = bool(datos.get("neon", false))
	for hijo in get_children():
		hijo.queue_free()
	conductor_nodo = null
	_destino_mallas = null
	ruedas.clear()
	luces_frenos.clear()
	luces_frente.clear()
	faros.clear()
	if tipo == "moto":
		construir_moto()
	else:
		construir_auto()
	add_child(crear_sombra())


var _destino_mallas: Node3D = null


func nueva_malla(malla: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(_destino_mallas if _destino_mallas != null else self).add_child(mi)
	return mi


func construir_auto() -> void:
	perfil = PERFILES.get(tipo, PERFILES["sedan"])
	var largo: float = float(perfil["largo"])
	var ancho: float = float(perfil["ancho"])
	var pintura: StandardMaterial3D = material(color_pintura, 0.32, 0.55)
	nueva_malla(malla_extruida(perfil["cuerpo"], ancho), pintura)
	var vidrio: StandardMaterial3D = material(Color(0.12, 0.2, 0.3, 0.55), 0.1, 0.2, 0.0, true)
	var cab := nueva_malla(malla_extruida(perfil["cabina"], ancho * 0.86), vidrio)
	cab.name = "Cabina"
	# techo pintado (placa fina sobre la cabina)
	var cabina: Array = perfil["cabina"]
	var techo_y: float = float((cabina[1] as Array)[1])
	var techo_x0: float = float((cabina[1] as Array)[0])
	var techo_x1: float = float((cabina[2] as Array)[0])
	var techo := BoxMesh.new()
	techo.size = Vector3(techo_x1 - techo_x0, 0.06, ancho * 0.86)
	nueva_malla(techo, pintura, Vector3((techo_x0 + techo_x1) * 0.5, techo_y + 0.02, 0.0))
	# parachoques
	var negro: StandardMaterial3D = material(Color("#15171a"), 0.9)
	for lado in [-1.0, 1.0]:
		var pc := BoxMesh.new()
		pc.size = Vector3(0.2, 0.22, ancho * 0.98)
		nueva_malla(pc, negro, Vector3(largo * 0.5 * float(lado) + 0.04 * float(lado), 0.42, 0.0))
	# ruedas
	var radio: float = float(perfil["rueda"])
	var eje: float = float(perfil["eje"])
	for ex in [-1.0, 1.0]:
		for ez in [-1.0, 1.0]:
			var rueda := Node3D.new()
			rueda.position = Vector3(eje * float(ex), radio, (ancho * 0.5 - 0.1) * float(ez))
			var cil := CylinderMesh.new()
			cil.top_radius = radio
			cil.bottom_radius = radio
			cil.height = 0.26
			cil.radial_segments = 14
			var neumatico := MeshInstance3D.new()
			neumatico.mesh = cil
			neumatico.material_override = material(Color("#101214"), 0.95)
			neumatico.rotation.x = PI * 0.5
			neumatico.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rueda.add_child(neumatico)
			var llanta := CylinderMesh.new()
			llanta.top_radius = radio * 0.62
			llanta.bottom_radius = radio * 0.62
			llanta.height = 0.28
			llanta.radial_segments = 6
			var ll := MeshInstance3D.new()
			ll.mesh = llanta
			ll.material_override = material(Color("#c9ced6"), 0.3, 0.9)
			ll.rotation.x = PI * 0.5
			ll.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rueda.add_child(ll)
			add_child(rueda)
			ruedas.append(rueda)
	# luces
	var y_luz: float = float((perfil["cuerpo"] as Array)[3][1]) - 0.2
	for lado_z in [-1.0, 1.0]:
		var faro := BoxMesh.new()
		faro.size = Vector3(0.06, 0.13, 0.4)
		luces_frente.append(nueva_malla(faro, material(Color("#fff3c4"), 0.2, 0.0, 2.2), Vector3(largo * 0.5 + 0.08, y_luz, (ancho * 0.5 - 0.3) * float(lado_z))))
		var piloto := BoxMesh.new()
		piloto.size = Vector3(0.06, 0.13, 0.42)
		luces_frenos.append(nueva_malla(piloto, material(Color("#ff2a2a"), 0.3, 0.0, 0.8), Vector3(-largo * 0.5 - 0.08, y_luz, (ancho * 0.5 - 0.3) * float(lado_z))))
	# placas
	poner_placa(placa_delantera, Vector3(largo * 0.5 + 0.1, 0.63, 0.0), 1.0)
	poner_placa(placa_trasera, Vector3(-largo * 0.5 - 0.1, 0.66, 0.0), -1.0)
	poner_conductor(float((cabina[1] as Array)[0]) + 0.5, ancho)
	if con_neon:
		poner_neon(largo, ancho)


func construir_moto() -> void:
	perfil = {"largo": 2.1, "ancho": 0.8}
	var pintura: StandardMaterial3D = material(color_pintura, 0.3, 0.6)
	var negro: StandardMaterial3D = material(Color("#15171a"), 0.9)
	var cuerpo := BoxMesh.new()
	cuerpo.size = Vector3(1.0, 0.4, 0.34)
	nueva_malla(cuerpo, pintura, Vector3(0.0, 0.62, 0.0))
	var tanque := BoxMesh.new()
	tanque.size = Vector3(0.5, 0.26, 0.38)
	nueva_malla(tanque, pintura, Vector3(0.28, 0.9, 0.0))
	var asiento := BoxMesh.new()
	asiento.size = Vector3(0.55, 0.12, 0.34)
	nueva_malla(asiento, negro, Vector3(-0.3, 0.88, 0.0))
	var manillar := BoxMesh.new()
	manillar.size = Vector3(0.1, 0.08, 0.7)
	nueva_malla(manillar, negro, Vector3(0.7, 1.15, 0.0))
	for ex in [-0.78, 0.82]:
		var rueda := Node3D.new()
		rueda.position = Vector3(ex, 0.32, 0.0)
		var cil := CylinderMesh.new()
		cil.top_radius = 0.32
		cil.bottom_radius = 0.32
		cil.height = 0.16
		cil.radial_segments = 14
		var n := MeshInstance3D.new()
		n.mesh = cil
		n.material_override = material(Color("#101214"), 0.95)
		n.rotation.x = PI * 0.5
		rueda.add_child(n)
		add_child(rueda)
		ruedas.append(rueda)
	var faro := BoxMesh.new()
	faro.size = Vector3(0.06, 0.14, 0.2)
	luces_frente.append(nueva_malla(faro, material(Color("#fff3c4"), 0.2, 0.0, 2.2), Vector3(0.88, 1.0, 0.0)))
	var piloto := BoxMesh.new()
	piloto.size = Vector3(0.06, 0.1, 0.2)
	luces_frenos.append(nueva_malla(piloto, material(Color("#ff2a2a"), 0.3, 0.0, 0.8), Vector3(-0.86, 0.85, 0.0)))
	poner_placa(placa_delantera, Vector3(0.9, 0.72, 0.0), 1.0, 0.7)
	poner_placa(placa_trasera, Vector3(-0.92, 0.7, 0.0), -1.0, 0.9)
	# piloto
	poner_persona(Vector3(-0.2, 1.3, 0.0), 0.9)


func poner_placa(texto: String, pos: Vector3, sentido: float, escala: float = 1.0) -> void:
	var raiz := Node3D.new()
	raiz.position = pos
	raiz.rotation.y = 0.0 if sentido > 0.0 else PI
	var cuadro := BoxMesh.new()
	cuadro.size = Vector3(0.02, 0.17 * escala, 0.5 * escala)
	var fondo := MeshInstance3D.new()
	fondo.mesh = cuadro
	fondo.material_override = material(Color("#f2c200"), 0.5)
	fondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(fondo)
	var rotulo := Label3D.new()
	rotulo.text = texto
	rotulo.font_size = 64
	rotulo.pixel_size = 0.0021 * escala
	rotulo.modulate = Color("#111111")
	rotulo.outline_size = 0
	rotulo.double_sided = false
	rotulo.shaded = false
	rotulo.position = Vector3(0.015, 0.0, 0.0)
	rotulo.rotation.y = PI * 0.5
	rotulo.name = "TextoPlaca"
	raiz.add_child(rotulo)
	add_child(raiz)


func poner_conductor(x: float, ancho: float) -> void:
	poner_persona(Vector3(x, 0.92, -ancho * 0.22), 1.0)


func mostrar_conductor(si: bool) -> void:
	if conductor_nodo != null:
		conductor_nodo.visible = si


func poner_persona(pos: Vector3, escala: float) -> void:
	# El conductor vive en un nodo propio para poder "bajarlo" del vehiculo (se oculta y aparece una Persona3D).
	conductor_nodo = Node3D.new()
	add_child(conductor_nodo)
	_destino_mallas = conductor_nodo
	var tonos: Array[Color] = [Color("#f1c9a5"), Color("#d9a07a"), Color("#a9714c"), Color("#7a4a2e"), Color("#5a3622")]
	var pelos: Array[Color] = [Color("#15110f"), Color("#4a2c1a"), Color("#8a5a2b"), Color("#d9b45a"), Color("#bdbdbd")]
	var h: int = (rostro * 2654435761) & 0x7fffffff
	var piel: Color = tonos[h % tonos.size()]
	var pelo: Color = pelos[(h >> 4) % pelos.size()]
	var cabeza := SphereMesh.new()
	cabeza.radius = 0.13 * escala
	cabeza.height = 0.26 * escala
	cabeza.radial_segments = 8
	cabeza.rings = 4
	nueva_malla(cabeza, material(piel, 0.8), pos + Vector3(0.0, 0.3 * escala, 0.0))
	var cabello := SphereMesh.new()
	cabello.radius = 0.14 * escala
	cabello.height = 0.14 * escala
	cabello.radial_segments = 8
	cabello.rings = 3
	nueva_malla(cabello, material(pelo, 0.9), pos + Vector3(-0.01, 0.4 * escala, 0.0))
	var torso := BoxMesh.new()
	torso.size = Vector3(0.22 * escala, 0.38 * escala, 0.38 * escala)
	nueva_malla(torso, material(Color("#3a4a6a"), 0.9), pos + Vector3(0.0, 0.0, 0.0))
	_destino_mallas = null


func poner_neon(largo: float, ancho: float) -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(largo * 0.9, ancho * 1.05)
	var colores: Array[Color] = [Color("#16e0ff"), Color("#ff2bd6"), Color("#7cff3a")]
	var c: Color = colores[(rostro >> 3) % colores.size()]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon = nueva_malla(plano, m, Vector3(0.0, 0.06, 0.0))


func crear_sombra() -> MeshInstance3D:
	var plano := PlaneMesh.new()
	plano.size = Vector2(float(perfil.get("largo", 4.4)) * 1.12, float(perfil.get("ancho", 1.8)) * 1.25)
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0, 0, 0, 0.7))
	degradado.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = degradado
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = plano
	mi.material_override = m
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Sombra"
	return mi


func ancho_total() -> float:
	return float(perfil.get("ancho", 1.8))


func largo_total() -> float:
	return float(perfil.get("largo", 4.4))


func encender_luces(encendidas: bool) -> void:
	for l in luces_frente:
		l.material_override = material(Color("#fff3c4"), 0.2, 0.0, 2.6 if encendidas else 0.15)


func ver_frenos(activo: bool) -> void:
	if activo == frenando:
		return
	frenando = activo
	for l in luces_frenos:
		l.material_override = material(Color("#ff2a2a"), 0.3, 0.0, 3.2 if activo else 0.8)


# --- movimiento -----------------------------------------------------------------------------------

func seguir(nueva_ruta: Array, vel: float, hacia_atras: bool = false) -> void:
	ruta = nueva_ruta
	velocidad = vel
	paso = -1 if hacia_atras else 1
	indice = ruta.size() - 1 if hacia_atras else 0
	if ruta.is_empty():
		llego.emit()
		return
	var primero: Dictionary = ruta[indice]
	position = primero["p"]
	rotation.y = float(primero["h"])
	siguiente_punto()
	se_mueve = true


func siguiente_punto() -> void:
	indice += paso


func detener() -> void:
	se_mueve = false
	velocidad_actual = 0.0
	ver_frenos(true)


func _process(delta: float) -> void:
	if not se_mueve:
		return
	var dt: float = delta * factor_tiempo
	if indice < 0 or indice >= ruta.size():
		se_mueve = false
		velocidad_actual = 0.0
		ver_frenos(true)
		llego.emit()
		return
	var objetivo: Dictionary = ruta[indice]
	var destino: Vector3 = objetivo["p"]
	# distancia que falta hasta el final de la ruta (para frenar suave)
	var restante: float = position.distance_to(destino)
	var j: int = indice
	while j + paso >= 0 and j + paso < ruta.size():
		restante += (ruta[j]["p"] as Vector3).distance_to(ruta[j + paso]["p"])
		j += paso
	var vel_obj: float = minf(velocidad, maxf(0.9, sqrt(2.6 * restante) * 1.2))
	velocidad_actual = move_toward(velocidad_actual, vel_obj, 7.0 * dt)
	ver_frenos(velocidad_actual > vel_obj + 0.2)
	var paso_m: float = velocidad_actual * dt
	var distancia: float = position.distance_to(destino)
	if paso_m >= distancia:
		position = destino
		rotation.y = lerp_angle(rotation.y, float(objetivo["h"]), 1.0)
		siguiente_punto()
	else:
		position += (destino - position).normalized() * paso_m
		rotation.y = lerp_angle(rotation.y, float(objetivo["h"]), clampf(dt * 9.0, 0.0, 1.0))
	_giro_rueda += paso_m * float(paso) / maxf(0.3, float(perfil.get("rueda", 0.34))) * (1.0 if true else -1.0)
	for r in ruedas:
		r.rotation.z = -_giro_rueda
