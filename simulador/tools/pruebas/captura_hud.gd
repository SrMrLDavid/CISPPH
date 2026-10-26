extends Node
const SP := "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/"
func _ready() -> void:
	var P: Node = load("res://scripts/principal.gd").new()
	add_child(P)
	await get_tree().create_timer(1.0).timeout
	P.ui.menu_panel.visible = false
	Sistema.autenticado = true
	P.ui.comenzar_turno()
	P.apagones_aleatorios = false
	P.fallas_conexion = false
	Ajustes.valores["tenso"] = true
	Ajustes.valores["vhs"] = true
	P.filtro.aplicar()
	P.provocar_apagon()
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png(SP + "hud1.png")
	get_tree().quit()
