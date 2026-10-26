extends Node3D
class_name Persona3D

# CISPPH - Persona procedural de bajo poligono (cabeza grande, brazos y piernas que se mueven).
# Mira hacia +X local (igual que los vehiculos). Sin texturas ni modelos externos.
# roles: "civil", "guardia", "guardia_saliente", "policia", "ladron"

signal llego
signal termino

var rol: String = "civil"
var semilla: int = 1
var factor_tiempo: float = 1.0
var ruta: Array = []                 # Array de Vector3
var indice: int = 0
var velocidad: float = 1.7
var camina: bool = false
var _fase: float = 0.0
var _forcejeo: float = 0.0
var brazo_i: Node3D
var brazo_d: Node3D
var pierna_i: Node3D
var pierna_d: Node3D
var cuerpo: Node3D
var _mats: Dictionary = {}


func _mat(color: Color, rugosidad: float = 0.9) -> StandardMaterial3D:
	return Vehiculo3D.material(color, rugosidad)


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


func construir(sem: int, papel: String = "civil") -> void:
	semilla = sem
	rol = papel
	for h in get_children():
		h.queue_free()
	var tonos: Array[Color] = [Color("#f1c9a5"), Color("#d9a07a"), Color("#a9714c"), Color("#7a4a2e"), Color("#5a3622")]
	var pelos: Array[Color] = [Color("#15110f"), Color("#4a2c1a"), Color("#8a5a2b"), Color("#d9b45a"), Color("#bdbdbd")]
	var camisas: Array[Color] = [Color("#3a8f5c"), Color("#c0563b"), Color("#3b6fb0"), Color("#b08a3b"), Color("#8e5aa8"), Color("#4aa3a3")]
	var h: int = (semilla * 2654435761) & 0x7fffffff
	var piel: Color = tonos[h % tonos.size()]
	var pelo: Color = pelos[(h >> 4) % pelos.size()]
	var camisa: Color = camisas[(h >> 8) % camisas.size()]
	var pantalon := Color("#2a3142")
	var gorra: Color = Color(0, 0, 0, 0)
	match rol:
		"guardia":
			camisa = Color("#1f3a63")
			gorra = Color("#15213a")
		"guardia_saliente":
			camisa = Color("#4b5d3a")
			pantalon = Color("#2b3323")
			gorra = Color("#2b3323")
		"policia":
			camisa = Color("#2447a6")
			pantalon = Color("#161d33")
			gorra = Color("#12182c")
		"ladron":
			camisa = Color("#222222")
			pantalon = Color("#151515")
			gorra = Color("#111111")
	cuerpo = Node3D.new()
	add_child(cuerpo)
	# torso y cabeza (cabeza grande)
	_caja(cuerpo, Vector3(0.26, 0.56, 0.42), Vector3(0, 1.08, 0), camisa)
	var cabeza := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 10
	sm.rings = 6
	cabeza.mesh = sm
	cabeza.material_override = _mat(piel, 0.8)
	cabeza.position = Vector3(0, 1.56, 0)
	cabeza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cuerpo.add_child(cabeza)
	# cara
	_caja(cuerpo, Vector3(0.03, 0.05, 0.05), Vector3(0.19, 1.6, 0.075), Color("#111111"))
	_caja(cuerpo, Vector3(0.03, 0.05, 0.05), Vector3(0.19, 1.6, -0.075), Color("#111111"))
	_caja(cuerpo, Vector3(0.03, 0.025, 0.1), Vector3(0.19, 1.5, 0.0), Color("#7a2f2f"))
	if gorra.a > 0.0:
		_caja(cuerpo, Vector3(0.36, 0.09, 0.38), Vector3(0, 1.72, 0), gorra)
		_caja(cuerpo, Vector3(0.14, 0.03, 0.3), Vector3(0.24, 1.69, 0), gorra)
	elif (h >> 12) % 4 != 0:
		_caja(cuerpo, Vector3(0.34, 0.1, 0.36), Vector3(-0.01, 1.71, 0), pelo)
	# brazos (pivotes en los hombros)
	brazo_i = Node3D.new()
	brazo_i.position = Vector3(0, 1.3, 0.25)
	cuerpo.add_child(brazo_i)
	_caja(brazo_i, Vector3(0.12, 0.5, 0.12), Vector3(0, -0.25, 0), camisa)
	_caja(brazo_i, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.53, 0), piel)
	brazo_d = Node3D.new()
	brazo_d.position = Vector3(0, 1.3, -0.25)
	cuerpo.add_child(brazo_d)
	_caja(brazo_d, Vector3(0.12, 0.5, 0.12), Vector3(0, -0.25, 0), camisa)
	_caja(brazo_d, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.53, 0), piel)
	# piernas (pivotes en la cadera)
	pierna_i = Node3D.new()
	pierna_i.position = Vector3(0, 0.8, 0.1)
	cuerpo.add_child(pierna_i)
	_caja(pierna_i, Vector3(0.15, 0.78, 0.15), Vector3(0, -0.39, 0), pantalon)
	_caja(pierna_i, Vector3(0.26, 0.08, 0.17), Vector3(0.05, -0.78, 0), Color("#1a1a1a"))
	pierna_d = Node3D.new()
	pierna_d.position = Vector3(0, 0.8, -0.1)
	cuerpo.add_child(pierna_d)
	_caja(pierna_d, Vector3(0.15, 0.78, 0.15), Vector3(0, -0.39, 0), pantalon)
	_caja(pierna_d, Vector3(0.26, 0.08, 0.17), Vector3(0.05, -0.78, 0), Color("#1a1a1a"))
	# sombra falsa
	var sh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.7, 0.7)
	sh.mesh = pm
	sh.material_override = Vehiculo3D.material(Color(0, 0, 0, 0.35), 1.0, 0.0, 0.0, true)
	sh.position.y = 0.02
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)


func sentar(si: bool) -> void:
	# Pose sentada: piernas hacia delante, cuerpo mas bajo (para el guarda en la garita).
	cuerpo.position.y = -0.38 if si else 0.0
	pierna_i.rotation.z = -PI * 0.5 if si else 0.0
	pierna_d.rotation.z = -PI * 0.5 if si else 0.0


func caminar(puntos: Array, vel: float = 1.7) -> void:
	ruta = puntos
	velocidad = vel
	indice = 0
	camina = true
	visible = true
	if ruta.is_empty():
		camina = false
		llego.emit()


func forcejear(segundos: float) -> void:
	_forcejeo = segundos
	camina = false


func parar() -> void:
	camina = false
	_forcejeo = 0.0
	_pose(0.0)


func _pose(a: float) -> void:
	brazo_i.rotation.z = a * 0.9
	brazo_d.rotation.z = -a * 0.9
	pierna_i.rotation.z = -a * 0.8
	pierna_d.rotation.z = a * 0.8


func _process(delta: float) -> void:
	var dt: float = delta * factor_tiempo
	if _forcejeo > 0.0:
		_forcejeo -= dt
		_fase += dt * 14.0
		# tironea la manija: un brazo adelante, el cuerpo se sacude
		brazo_i.rotation.z = -1.1 + sin(_fase) * 0.35
		brazo_d.rotation.z = 0.5 * sin(_fase * 0.7)
		cuerpo.rotation.z = sin(_fase * 0.5) * 0.08
		cuerpo.position.x = sin(_fase) * 0.03
		if _forcejeo <= 0.0:
			cuerpo.rotation.z = 0.0
			cuerpo.position.x = 0.0
			_pose(0.0)
			termino.emit()
		return
	if not camina:
		return
	if indice >= ruta.size():
		camina = false
		_pose(0.0)
		llego.emit()
		return
	var destino: Vector3 = ruta[indice]
	var a: Vector3 = Vector3(destino.x - position.x, 0.0, destino.z - position.z)
	var dist: float = a.length()
	var paso: float = velocidad * dt
	if dist <= paso or dist < 0.001:
		position = Vector3(destino.x, position.y, destino.z)
		indice += 1
	else:
		var dir: Vector3 = a / dist
		position += dir * paso
		var objetivo: float = atan2(-dir.z, dir.x)
		rotation.y = lerp_angle(rotation.y, objetivo, clampf(dt * 10.0, 0.0, 1.0))
	_fase += dt * velocidad * 5.0
	_pose(sin(_fase) * 0.8)
