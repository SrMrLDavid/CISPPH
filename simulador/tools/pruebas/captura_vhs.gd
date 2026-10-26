extends Node
const SP := "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/"
func _ready() -> void:
	var P: Node = load("res://scripts/principal.gd").new()
	add_child(P)
	await get_tree().create_timer(1.0).timeout
	Ajustes.valores["vhs"] = true
	Ajustes.valores["vhs_fuerza"] = 0.8
	P.filtro.aplicar()
	P.esc.cambiar_camara("seguridad")
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(SP + "vhs1.png")
	get_tree().quit()
