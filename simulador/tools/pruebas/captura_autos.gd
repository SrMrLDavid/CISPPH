extends SceneTree
var salida: String = "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/autos.png"
func _initialize() -> void:
	call_deferred("correr")
func correr() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#d98a4a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9aa7c0")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 60, 0)
	sol.light_color = Color("#ffcf9a")
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(60, 60)
	suelo.mesh = pl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#2a2c31")
	suelo.material_override = m
	raiz.add_child(suelo)
	var tipos: Array = ["sedan", "suv", "hatchback", "camioneta", "moto"]
	var colores: Array = ["#c0392b", "#2980b9", "#f1c40f", "#27ae60", "#8e44ad"]
	for i in range(5):
		var v := Vehiculo3D.new()
		v.construir({"tipo": tipos[i], "color": colores[i], "placa_delantera": "ABC-12%d" % i, "rostro": 100 + i, "neon": i % 2 == 0})
		v.position = Vector3(float(i) * 6.0 - 12.0, 0, 0)
		v.rotation.y = 0.0
		raiz.add_child(v)
	var cam := Camera3D.new()
	cam.position = Vector3(-4, 4.5, 14)
	raiz.add_child(cam)
	cam.look_at(Vector3(-1, 0.8, 0))
	cam.current = true
	for i in range(6):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(salida)
	quit(0)
