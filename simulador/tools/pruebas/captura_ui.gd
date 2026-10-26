extends Node
var dir: String = "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/"
func _ready() -> void:
	call_deferred("correr")
func foto(n: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "ui_" + n + ".png")
func correr() -> void:
	var S: Node = get_tree().root.get_node("Sistema")
	S.persistir = false
	S.cargar_datos_iniciales()
	var P: Node = load("res://scenes/principal.tscn").instantiate()
	get_tree().root.add_child(P)
	await get_tree().process_frame
	await foto("login")
	P.ui.login_panel.visible = false
	P.ui.hud.visible = true
	P.iniciado = true
	P.esc.cambiar_camara("seguridad")
	P.fijar_velocidad(5.0)
	P.iniciar_caso("Entrada", P.gen.caso_base("Entrada", "x", "Prueba: placa correcta, conductor distinto", S.usuario_por_id(1)))
	var c: Dictionary = P.carriles["Entrada"]
	c["caso"]["rostro"] = int(c["caso"]["rostro"]) + 7919
	for i in 600:
		await get_tree().process_frame
		if not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty():
			break
	await foto("hud")
	P.ui.abrir_usuarios()
	await foto("usuarios")
	P.ui.abrir_historial()
	await foto("historial")
	P.ui.abrir_config()
	await foto("config")
	P.ui.abrir_ayuda()
	await foto("ayuda")
	get_tree().quit()
