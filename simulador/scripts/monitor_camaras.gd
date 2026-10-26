extends VBoxContainer
class_name MonitorCamaras

# CISPPH - Monitor de camaras: vista de camaras fijas que se pueden ORIENTAR (girar/inclinar) pero no mover.
# Usa un SubViewport que comparte el mundo 3D; se refresca ~4 veces por segundo para no cargar equipos modestos.
# Sin energia (apagon) las camaras muestran "SIN SENAL".

const CAMARAS: Array = [
	["Entrada (LPR)", Vector3(-1.0, 3.4, 4.6), Vector3(-1, 0, 0)],
	["Salida", Vector3(-1.0, 3.4, -4.6), Vector3(1, 0, 0)],
	["Parqueadero fila A", Vector3(6.0, 4.0, 4.5), Vector3(1, 0, 0.0)],
	["Parqueadero fila B", Vector3(6.0, 4.0, -4.5), Vector3(1, 0, 0.0)],
	["Fondo del parqueadero", Vector3(64.0, 4.5, 0.0), Vector3(-1, 0, 0)],
	["Edificios (centro)", Vector3(30.0, 5.0, 0.0), Vector3(0, 0, 1)]]
const LIMITE_YAW: float = 1.2
const LIMITE_PITCH: float = 0.5

var principal: Node = null
var sub: SubViewport
var cam: Camera3D
var vista: TextureRect
var aviso: Label
var titulo: Label
var indice: int = 0
var yaw: float = 0.0
var pitch: float = -0.12
var _t: float = 0.0
var _arrastrando: bool = false


func iniciar(p: Node) -> void:
	principal = p
	add_theme_constant_override("separation", 6)
	sub = SubViewport.new()
	sub.size = Vector2i(640, 360)
	sub.world_3d = principal.esc.get_world_3d()
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sub)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 200.0
	sub.add_child(cam)
	titulo = Label.new()
	titulo.add_theme_font_size_override("font_size", 15)
	add_child(titulo)
	vista = TextureRect.new()
	vista.texture = sub.get_texture()
	vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vista.custom_minimum_size = Vector2(480, 270)
	vista.mouse_default_cursor_shape = Control.CURSOR_MOVE
	vista.gui_input.connect(_entrada_vista)
	add_child(vista)
	aviso = Label.new()
	aviso.text = "SIN SEÑAL — sin energía"
	aviso.add_theme_font_size_override("font_size", 28)
	aviso.add_theme_color_override("font_color", Color("#ff5c5c"))
	aviso.set_anchors_preset(Control.PRESET_CENTER)
	aviso.visible = false
	vista.add_child(aviso)
	var sel := HFlowContainer.new()
	sel.add_theme_constant_override("h_separation", 4)
	add_child(sel)
	for i in range(CAMARAS.size()):
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, str((CAMARAS[i] as Array)[0])]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: elegir(i))
		sel.add_child(b)
	var mando := HBoxContainer.new()
	mando.alignment = BoxContainer.ALIGNMENT_CENTER
	mando.add_theme_constant_override("separation", 6)
	add_child(mando)
	for par in [["◀ Izquierda", -0.12, 0.0], ["▲ Arriba", 0.0, 0.08], ["▼ Abajo", 0.0, -0.08], ["Derecha ▶", 0.12, 0.0]]:
		var b2 := Button.new()
		b2.text = str(par[0])
		b2.focus_mode = Control.FOCUS_NONE
		var dy: float = float(par[1])
		var dp: float = float(par[2])
		b2.pressed.connect(func() -> void: orientar(dy, dp))
		mando.add_child(b2)
	var rec := Button.new()
	rec.text = "⟲ Centrar"
	rec.focus_mode = Control.FOCUS_NONE
	rec.pressed.connect(func() -> void:
		yaw = 0.0
		pitch = -0.12
		refrescar())
	mando.add_child(rec)
	var nota := Label.new()
	nota.text = "La cámara está fija en su poste: solo gira. También puedes arrastrar sobre la imagen."
	nota.add_theme_font_size_override("font_size", 11)
	nota.add_theme_color_override("font_color", Color("#8e9ab0"))
	add_child(nota)
	elegir(0)


func elegir(i: int) -> void:
	indice = i
	yaw = 0.0
	pitch = -0.12
	refrescar()


func orientar(dy: float, dp: float) -> void:
	yaw = clampf(yaw + dy, -LIMITE_YAW, LIMITE_YAW)
	pitch = clampf(pitch + dp, -LIMITE_PITCH - 0.2, LIMITE_PITCH)
	refrescar()


func _entrada_vista(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = e.pressed
	elif e is InputEventMouseMotion and _arrastrando:
		orientar(e.relative.x * 0.006, -e.relative.y * 0.005)


func refrescar() -> void:
	var d: Array = CAMARAS[indice]
	cam.position = d[1]
	var base: Vector3 = d[2]
	var a: float = atan2(base.z, base.x) + yaw
	var dir := Vector3(cos(a) * cos(pitch), sin(pitch), sin(a) * cos(pitch))
	cam.look_at(cam.position + dir, Vector3.UP)
	titulo.text = "📹 Cámara %d · %s    (giro %d°, inclinación %d°)" % [indice + 1, str(d[0]), int(rad_to_deg(yaw)), int(rad_to_deg(pitch))]
	var sin_senal: bool = principal != null and principal.apagon
	aviso.visible = sin_senal
	vista.modulate = Color(0.1, 0.1, 0.1) if sin_senal else Color.WHITE
	if not sin_senal:
		sub.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		refrescar()
