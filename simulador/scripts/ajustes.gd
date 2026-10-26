extends RefCounted
class_name Ajustes

# CISPPH - Ajustes del jugador (sonido, graficos, controles). Se guardan en user://cispph_ajustes.cfg.

const RUTA: String = "user://cispph_ajustes.cfg"
# [id, etiqueta, tecla por defecto]
const ACCIONES: Array = [
	["entrada", "Generar entrada", KEY_E], ["salida", "Generar salida", KEY_S],
	["permitir", "Permitir", KEY_ENTER], ["denegar", "Denegar / detener persona", KEY_BACKSPACE],
	["cam_garita", "Cámara garita", KEY_1], ["cam_seguridad", "Cámara seguridad", KEY_2],
	["cam_aerea", "Cámara aérea", KEY_3], ["cam_libre", "Cámara libre", KEY_4],
	["cam_seguir", "Seguir vehículo", KEY_5], ["cam_cine", "Cámara cine", KEY_6],
	["cam_puesto", "Puesto del guarda (1.ª persona)", KEY_7], ["saltar", "Saltar cinemática", KEY_ESCAPE]
]

static var valores: Dictionary = {}


static func por_defecto() -> Dictionary:
	var teclas: Dictionary = {}
	for a in ACCIONES:
		teclas[str(a[0])] = int(a[2])
	return {"vol_general": 0.8, "vol_efectos": 1.0, "calidad": 1, "pantalla_completa": false, "escala3d": 1.0,
		"sens_camara": 1.0, "vhs": false, "tenso": false, "vhs_fuerza": 0.6, "retro": true, "teclas": teclas}


static func cargar() -> void:
	valores = por_defecto()
	var cf := ConfigFile.new()
	if cf.load(RUTA) != OK:
		return
	for k in valores.keys():
		if k == "teclas":
			for a in ACCIONES:
				valores["teclas"][str(a[0])] = int(cf.get_value("teclas", str(a[0]), int(a[2])))
		else:
			valores[k] = cf.get_value("ajustes", str(k), valores[k])


static func guardar() -> void:
	var cf := ConfigFile.new()
	for k in valores.keys():
		if k == "teclas":
			for a in valores["teclas"].keys():
				cf.set_value("teclas", str(a), int(valores["teclas"][a]))
		else:
			cf.set_value("ajustes", str(k), valores[k])
	cf.save(RUTA)


static func registrar_acciones() -> void:
	for a in ACCIONES:
		var id: String = "cispph_" + str(a[0])
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var ev := InputEventKey.new()
		ev.keycode = int(valores["teclas"][str(a[0])]) as Key
		InputMap.action_add_event(id, ev)


static func nombre_tecla(codigo: int) -> String:
	return OS.get_keycode_string(codigo as Key)


static func aplicar(nodo: Node) -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, float(valores["vol_general"]))))
	var win := nodo.get_window()
	if win != null:
		win.mode = Window.MODE_FULLSCREEN if bool(valores["pantalla_completa"]) else Window.MODE_WINDOWED
		var vp := nodo.get_viewport()
		if vp != null:
			vp.scaling_3d_scale = clampf(float(valores["escala3d"]), 0.4, 1.0)
	registrar_acciones()
