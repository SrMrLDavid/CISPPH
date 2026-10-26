extends Node
# Captura el menu, ajustes, about y fotogramas de la intro (Xvfb).
const SP := "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/"
func shot(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(SP + n + ".png")
func _ready() -> void:
	var P: Node = load("res://scripts/principal.gd").new()
	add_child(P)
	await get_tree().create_timer(1.5).timeout
	await shot("m1_menu")
	P.ui.abrir_que_es()
	await get_tree().create_timer(0.5).timeout
	await shot("m2_about")
	P.ui.abrir_ajustes()
	await get_tree().create_timer(0.8).timeout
	await shot("m3_ajustes")
	P.ui.cerrar_overlay()
	P.ui.abrir_mapas()
	await get_tree().create_timer(0.6).timeout
	await shot("m4_mapas")
	P.ui.cerrar_overlay()
	P.ui.iniciar_desde_menu()
	var t: Array = [2.0, 4.0, 3.0, 4.0, 3.0]
	var i: int = 0
	for s in t:
		await get_tree().create_timer(s).timeout
		i += 1
		await shot("m5_intro%d" % i)
	print("intro_activa=", P.intro_activa, " login=", P.ui.login_panel.visible)
	await get_tree().create_timer(6.0).timeout
	print("intro_activa=", P.intro_activa, " login=", P.ui.login_panel.visible)
	await shot("m6_login")
	get_tree().quit()
