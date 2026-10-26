extends SceneTree
var dir: String = "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/"
func _initialize() -> void:
	call_deferred("correr")
func correr() -> void:
	var e := Escenario3D.new()
	root.add_child(e)
	await process_frame
	var v := Vehiculo3D.new()
	v.construir({"tipo": "sedan", "color": "#c0392b", "placa_delantera": "ABC-123", "placa_trasera": "ABC-123", "rostro": 100, "neon": true})
	e.add_child(v)
	var rr: Array = e.ruta_llegada_entrada()
	v.position = rr[rr.size() - 1]["p"]
	v.rotation.y = rr[rr.size() - 1]["h"]
	var v2 := Vehiculo3D.new()
	v2.construir({"tipo": "suv", "color": "#2980b9", "placa_delantera": "XYZ-987", "rostro": 101})
	e.add_child(v2)
	var pp: Dictionary = e.pose_puesto("R-05")
	v2.position = pp["p"]; v2.rotation.y = pp["h"]
	var v3 := Vehiculo3D.new()
	v3.construir({"tipo": "hatchback", "color": "#f1c40f", "placa_delantera": "QQQ-111", "rostro": 102})
	e.add_child(v3)
	pp = e.pose_puesto("R-20")
	v3.position = pp["p"]; v3.rotation.y = pp["h"]
	var modos := ["garita", "seguridad", "alta", "cine"]
	for m in modos:
		e.cambiar_camara(m)
		for i in 40: await process_frame
		get_root().get_viewport().get_texture().get_image().save_png(dir + "esc_" + m + ".png")
	var img: Image = await e.capturar(v, "placa_delantera")
	img.save_png(dir + "cap_placa.png")
	img = await e.capturar(v, "rostro")
	img.save_png(dir + "cap_rostro.png")
	quit()
