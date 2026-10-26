extends CanvasLayer
class_name Interfaz

# CISPPH - Interfaz del sistema (todo por codigo, sin escenas extra): login, barra superior,
# tarjetas de los carriles de Entrada/Salida, y ventanas de Gestion de usuarios, Historial,
# Estado del parqueadero, Configuracion y Ayuda.

const RostroVista = preload("res://scripts/rostro_vista.gd")
const C_FONDO := Color("#121722")
const C_ACENTO := Color("#3ad0ff")
const C_OK := Color("#4cd964")
const C_AVISO := Color("#ffb347")
const C_MAL := Color("#ff5c5c")
const C_TEXTO := Color("#e8edf5")
const C_SUAVE := Color("#8e9ab0")

var principal: Node = null
var raiz: Control
var login_panel: Control
var hud: Control
var etiqueta_barra: Label
var etiqueta_stats: Label
var selector_modo: OptionButton
var toast: Label
var tarjetas: Dictionary = {}
var ventanas: Dictionary = {}
var inspecciones: Dictionary = {}
var notas: Dictionary = {}
var sub: Label
var sub_tween: Tween = null
var destello: ColorRect
var destello_tw: Tween = null
var boton_entrada: Button
var boton_salida: Button
var tema: Theme
var menu_panel: Control
var vineta_estres: TextureRect = null
var estres_valor: float = 0.0
var esperando_tecla: String = ""
var boton_tecla: Button = null


func _ready() -> void:
	layer = 10
	crear_tema()
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = tema
	add_child(raiz)
	crear_hud()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.8, 0.05, 0.05, 0.0))
	gr.set_color(1, Color(0.8, 0.05, 0.05, 1.0))
	gr.set_offset(0, 0.55)
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	vineta_estres = TextureRect.new()
	vineta_estres.texture = gt
	vineta_estres.set_anchors_preset(Control.PRESET_FULL_RECT)
	vineta_estres.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta_estres.stretch_mode = TextureRect.STRETCH_SCALE
	vineta_estres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta_estres.modulate.a = 0.0
	raiz.add_child(vineta_estres)
	crear_login()
	hud.visible = false
	crear_menu()


# ---------------------------------------------------------------------------------------------
# utilidades de UI
# ---------------------------------------------------------------------------------------------

func estilo(color: Color, radio: int = 8, borde: Color = Color(0, 0, 0, 0), grosor: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radio)
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func crear_tema() -> void:
	tema = Theme.new()
	tema.default_font_size = 13
	tema.set_color("font_color", "Label", C_TEXTO)
	tema.set_stylebox("panel", "PanelContainer", estilo(Color(C_FONDO, 0.93), 10, Color("#2b3550"), 1))
	tema.set_stylebox("normal", "Button", estilo(Color("#26324d"), 6))
	tema.set_stylebox("hover", "Button", estilo(Color("#33456b"), 6))
	tema.set_stylebox("pressed", "Button", estilo(Color("#1d6f93"), 6))
	tema.set_stylebox("disabled", "Button", estilo(Color("#1a2133"), 6))
	tema.set_color("font_color", "Button", C_TEXTO)
	tema.set_color("font_disabled_color", "Button", Color("#5b667c"))
	tema.set_stylebox("normal", "LineEdit", estilo(Color("#0c1019"), 5, Color("#2b3550"), 1))
	tema.set_color("font_color", "LineEdit", C_TEXTO)
	tema.set_stylebox("normal", "OptionButton", estilo(Color("#26324d"), 6))
	tema.set_stylebox("hover", "OptionButton", estilo(Color("#33456b"), 6))
	tema.set_stylebox("pressed", "OptionButton", estilo(Color("#1d6f93"), 6))
	tema.set_color("font_color", "CheckBox", C_TEXTO)
	tema.set_color("font_color", "RichTextLabel", C_TEXTO)
	tema.set_color("default_color", "RichTextLabel", C_TEXTO)


func etiqueta(texto: String, tam: int = 14, color: Color = C_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func boton(texto: String, accion: Callable, ancho: float = 0.0) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	if ancho > 0.0:
		b.custom_minimum_size.x = ancho
	b.pressed.connect(accion)
	return b


func campo(marcador: String, ancho: float = 200.0, secreto: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = marcador
	e.custom_minimum_size.x = ancho
	e.secret = secreto
	return e


func subtitulo(texto: String, segundos: float = 4.0) -> void:
	if sub == null:
		return
	sub.text = texto
	sub.modulate.a = 1.0
	if sub_tween != null and sub_tween.is_valid():
		sub_tween.kill()
	sub_tween = create_tween()
	sub_tween.tween_interval(segundos)
	sub_tween.tween_property(sub, "modulate:a", 0.0, 0.6)


func destello_policial(activo: bool) -> void:
	if destello == null:
		return
	if destello_tw != null:
		destello_tw.kill()
	destello.visible = activo
	if activo:
		destello_tw = create_tween().set_loops()
		destello_tw.tween_property(destello, "color", Color(0.9, 0.05, 0.05, 0.22), 0.3)
		destello_tw.tween_property(destello, "color", Color(0.05, 0.2, 1.0, 0.22), 0.3)


func mensaje(texto: String, color: Color = C_TEXTO) -> void:
	if toast == null:
		return
	toast.text = texto
	toast.add_theme_color_override("font_color", color)
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------------------------------------
# login
# ---------------------------------------------------------------------------------------------

func crear_login() -> void:
	login_panel = Control.new()
	login_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	login_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(login_panel)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	login_panel.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(400, 0)
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(etiqueta("CISPPH", 32, C_ACENTO))
	v.add_child(etiqueta("Control de Ingreso y Salida de Parqueaderos\nde Propiedad Horizontal", 14, C_SUAVE))
	v.add_child(HSeparator.new())
	v.add_child(etiqueta("Usuario"))
	var usuario := campo("usuario", 360)
	v.add_child(usuario)
	v.add_child(etiqueta("Contraseña"))
	var clave := campo("contraseña", 360, true)
	v.add_child(clave)
	var aviso := etiqueta("", 13, C_MAL)
	v.add_child(aviso)
	var estado_login: Array = [0, 0]   # intentos fallidos, bloqueado hasta (ms)
	var intentar := func() -> void:
		if Time.get_ticks_msec() < int(estado_login[1]):
			aviso.text = "Demasiados intentos. Espera unos segundos."
			return
		if Sistema.validar_login(usuario.text.strip_edges(), clave.text):
			estado_login[0] = 0
			Sistema.autenticado = true
			clave.text = ""
			aviso.text = ""
			login_panel.visible = false
			if principal != null and principal.mostrar_tareas:
				abrir_tareas_turno()
			else:
				comenzar_turno()
		else:
			estado_login[0] = int(estado_login[0]) + 1
			aviso.text = "Usuario o contraseña incorrectos (intento %d de 3)." % int(estado_login[0])
			if int(estado_login[0]) >= 3:
				estado_login[0] = 0
				estado_login[1] = Time.get_ticks_msec() + 15000
				aviso.text = "Tres intentos fallidos: acceso bloqueado 15 s (demostración del flujo del UML)."
			if principal != null:
				principal.audio.tocar("error")
	v.add_child(boton("Ingresar", intentar))
	clave.text_submitted.connect(func(_t: String) -> void: intentar.call())
	usuario.text_submitted.connect(func(_t: String) -> void: clave.grab_focus())
	v.add_child(etiqueta("Demostración académica · usuario inicial: admin / admin123\n(se puede cambiar en Configuración)", 12, C_SUAVE))
	usuario.text = "admin"
	clave.call_deferred("grab_focus")


func mostrar_login() -> void:
	menu_panel.visible = false
	login_panel.visible = true
	hud.visible = false


func expirar_sesion() -> void:
	Sistema.autenticado = false
	hud.visible = false
	cerrar_overlay()
	if principal != null:
		principal.mostrar_tareas = false
		principal.ultima_actividad = Time.get_ticks_msec() / 1000.0
	login_panel.visible = true
	mensaje("Sesión expirada por inactividad. Inicia sesión de nuevo.", C_AVISO)


func comenzar_turno() -> void:
	cerrar_ventana("tareas")
	hud.visible = true
	actualizar_barra()
	if principal != null:
		principal.iniciado = true
		principal.esc.cambiar_camara("seguridad")
	mensaje("Turno iniciado. Pulsa «Generar entrada» o deja el tráfico automático.", C_OK)


func cerrar_sesion() -> void:
	Sistema.autenticado = false
	hud.visible = false
	cerrar_overlay()
	login_panel.visible = false
	if principal != null:
		principal.iniciado = false
		principal.limpiar_para_menu()
		principal.esc.cambiar_camara("cine")
	mostrar_menu()


# ---------------------------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------------------------

func crear_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(hud)
	# barra superior
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.offset_left = 8
	barra.offset_right = -8
	barra.offset_top = 6
	hud.add_child(barra)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	barra.add_child(vb)
	var f1 := HBoxContainer.new()
	f1.add_theme_constant_override("separation", 8)
	vb.add_child(f1)
	f1.add_child(etiqueta("CISPPH", 18, C_ACENTO))
	etiqueta_barra = etiqueta("", 14)
	f1.add_child(etiqueta("|", 14, C_SUAVE))
	f1.add_child(etiqueta_barra)
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.custom_minimum_size.x = 4
	f1.add_child(relleno)
	etiqueta_stats = etiqueta("", 13, C_SUAVE)
	etiqueta_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta_stats.custom_minimum_size.x = 100
	etiqueta_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f1.add_child(boton("Usuarios", abrir_usuarios))
	f1.add_child(boton("Historial", abrir_historial))
	f1.add_child(boton("📹 Monitor", abrir_monitor))
	f1.add_child(boton("Parqueadero", abrir_parqueadero))
	f1.add_child(boton("Métricas", abrir_metricas))
	f1.add_child(boton("Config.", abrir_config))
	f1.add_child(boton("Ayuda", abrir_ayuda))
	f1.add_child(boton("Salir", cerrar_sesion))
	var f2 := HBoxContainer.new()
	f2.add_theme_constant_override("separation", 8)
	vb.add_child(f2)
	boton_entrada = boton("▶ Generar entrada (E)", func() -> void: principal.solicitar("Entrada"))
	boton_salida = boton("◀ Generar salida (S)", func() -> void: principal.solicitar("Salida"))
	f2.add_child(boton_entrada)
	f2.add_child(boton_salida)
	f2.add_child(etiqueta("Modo:", 13, C_SUAVE))
	selector_modo = OptionButton.new()
	selector_modo.add_item("Automático")
	selector_modo.add_item("Manual")
	selector_modo.item_selected.connect(func(i: int) -> void:
		Sistema.config["modo"] = "automatico" if i == 0 else "manual"
		Sistema.guardar())
	f2.add_child(selector_modo)
	f2.add_child(etiqueta("Velocidad:", 13, C_SUAVE))
	for f in [1.0, 2.0, 4.0]:
		f2.add_child(boton("×%d" % int(f), func() -> void: principal.fijar_velocidad(f), 40))
	var trafico := CheckBox.new()
	trafico.text = "Tráfico automático"
	trafico.button_pressed = true
	trafico.toggled.connect(func(b: bool) -> void: principal.trafico_auto = b)
	f2.add_child(trafico)
	var camauto := CheckBox.new()
	camauto.text = "Cámara automática"
	camauto.button_pressed = true
	camauto.toggled.connect(func(b: bool) -> void: principal.camara_auto = b)
	f2.add_child(camauto)
	vb.add_child(etiqueta_stats)
	# tarjetas de carril (derecha)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_left = -400
	col.offset_right = -8
	col.offset_top = 116
	col.offset_bottom = -34
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(col)
	for s in ["Entrada", "Salida"]:
		col.add_child(crear_tarjeta(s))
	destello = ColorRect.new()
	destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	destello.color = Color(0, 0, 0, 0)
	destello.visible = false
	raiz.add_child(destello)
	sub = etiqueta("", 20)
	sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub.offset_top = -160
	sub.offset_bottom = -70
	sub.offset_left = -420
	sub.offset_right = 420
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.modulate.a = 0.0
	raiz.add_child(sub)
	# pie y avisos
	toast = etiqueta("", 18)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_top = -72
	toast.offset_left = -400
	toast.offset_right = 400
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 6)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast)
	var pie := HBoxContainer.new()
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_left = 8
	pie.offset_right = -400
	pie.offset_top = -34
	pie.offset_bottom = -4
	pie.add_theme_constant_override("separation", 6)
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(pie)
	var nombres: Array = [["1 Garita", "garita"], ["2 Seguridad", "seguridad"], ["3 Aérea", "alta"], ["4 Libre", "libre"], ["6 Cine", "cine"], ["7 Puesto", "puesto"]]
	for n in nombres:
		var modo: String = n[1]
		pie.add_child(boton(str(n[0]), func() -> void:
			principal.camara_auto = false
			principal.esc.cambiar_camara(modo)))
	var ayuda_pie := etiqueta("E entrada · S salida · Enter permitir · Retroceso denegar · clic der. mira alrededor", 11, C_SUAVE)
	ayuda_pie.add_theme_constant_override("outline_size", 4)
	ayuda_pie.add_theme_color_override("font_outline_color", Color.BLACK)
	pie.add_child(ayuda_pie)


func crear_tarjeta(sentido: String) -> Control:
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var t := {"panel": panel}
	t["titulo"] = etiqueta("", 15, C_ACENTO)
	v.add_child(t["titulo"])
	var cuerpo := VBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 4)
	v.add_child(cuerpo)
	t["cuerpo"] = cuerpo
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	cuerpo.add_child(fila)
	var texs: Array = []
	for k in ["Placa delantera", "Placa trasera", "Rostro (cámara)"]:
		var col := VBoxContainer.new()
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(108, 68)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		var fondo := ColorRect.new()
		fondo.color = Color("#0a0d14")
		fondo.custom_minimum_size = Vector2(108, 68)
		fondo.add_child(tr)
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.add_child(fondo)
		col.add_child(etiqueta(str(k), 10, C_SUAVE))
		fila.add_child(col)
		texs.append(tr)
	t["texs"] = texs
	var fila2 := HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 8)
	cuerpo.add_child(fila2)
	var cap := RostroVista.new()
	cap.custom_minimum_size = Vector2(66, 66)
	var reg := RostroVista.new()
	reg.custom_minimum_size = Vector2(66, 66)
	var c1 := VBoxContainer.new()
	c1.add_child(cap)
	c1.add_child(etiqueta("Capturado", 10, C_SUAVE))
	var c2 := VBoxContainer.new()
	c2.add_child(reg)
	c2.add_child(etiqueta("Registrado", 10, C_SUAVE))
	fila2.add_child(c1)
	fila2.add_child(c2)
	t["cap"] = cap
	t["reg"] = reg
	t["reg_caja"] = c2
	t["info"] = etiqueta("", 12)
	(t["info"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(t["info"] as Label).custom_minimum_size.x = 170
	fila2.add_child(t["info"])
	t["banner"] = etiqueta("", 15)
	(t["banner"] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cuerpo.add_child(t["banner"])
	t["detalle"] = etiqueta("", 12, C_SUAVE)
	(t["detalle"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(t["detalle"] as Label).custom_minimum_size.x = 340
	(t["detalle"] as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(t["detalle"])
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 4)
	cuerpo.add_child(botones)
	t["b_permitir"] = boton("Permitir", func() -> void: principal.permitir(sentido))
	t["b_denegar"] = boton("Denegar", func() -> void: principal.denegar(sentido))
	t["b_citofono"] = boton("Citófono", func() -> void:
		if principal.apagon:
			principal.preguntar(sentido)
		else:
			principal.citofono(sentido))
	t["b_inspeccion"] = boton("🔍 Inspeccionar", func() -> void: abrir_inspeccion(sentido))
	t["b_registrar"] = boton("Registrar", func() -> void: abrir_registro_visitante())
	(t["b_registrar"] as Button).tooltip_text = "Registrar visitante"
	for k in ["b_inspeccion", "b_permitir", "b_denegar", "b_citofono", "b_registrar"]:
		botones.add_child(t[k])
	tarjetas[sentido] = t
	refrescar_carril(sentido)
	return panel


func refrescar_carril(sentido: String) -> void:
	if not tarjetas.has(sentido) or principal == null:
		return
	var t: Dictionary = tarjetas[sentido]
	var L: Dictionary = principal.carriles[sentido]
	var flecha: String = "▶ ENTRADA" if sentido == "Entrada" else "◀ SALIDA"
	var cuerpo: Control = t["cuerpo"]
	if L.is_empty():
		(t["titulo"] as Label).text = flecha + " — carril libre"
		cuerpo.visible = false
		cerrar_ventana("insp_" + sentido)
		inspecciones.erase(sentido)
		return
	cuerpo.visible = true
	var caso: Dictionary = L["caso"]
	var estado: String = str(L["estado"])
	var ev: Dictionary = L["eval"]
	var titulo: String = flecha
	if estado == "llegando":
		titulo += " — vehículo en camino…"
	elif estado == "esperando" and ev.is_empty():
		titulo += " — capturando fotos…"
	elif estado == "esperando":
		titulo += " — esperando decisión"
	else:
		titulo += " — en movimiento"
	(t["titulo"] as Label).text = titulo
	var imgs: Dictionary = L["imgs"]
	var claves: Array = ["placa_delantera", "placa_trasera", "rostro"]
	for i in range(3):
		var tr: TextureRect = (t["texs"] as Array)[i]
		tr.texture = ImageTexture.create_from_image(imgs[claves[i]]) if imgs.has(claves[i]) else null
	var hay: bool = not ev.is_empty()
	(t["cap"] as Control).visible = hay
	(t["reg_caja"] as Control).visible = hay
	(t["info"] as Label).visible = hay
	(t["banner"] as Label).visible = hay
	(t["detalle"] as Label).visible = true
	var detalle: String = "Caso simulado: " + str(caso["etiqueta"])
	if not hay:
		(t["b_registrar"] as Button).visible = false
		(t["detalle"] as Label).text = detalle
		for k in ["b_inspeccion", "b_permitir", "b_denegar", "b_citofono", "b_registrar"]:
			(t[k] as Button).disabled = true
		return
	(t["cap"] as Node).call("fijar", int(caso["rostro"]))
	var u: Dictionary = ev["usuario"]
	(t["reg"] as Node).call("fijar", int(u["rostro"]) if not u.is_empty() else 0)
	(t["reg_caja"] as Control).modulate.a = 1.0 if not u.is_empty() else 0.25
	var txt: String = "Placa: %s" % Sistema.formato_placa(str(caso["placa_delantera"]))
	if str(caso["placa_trasera"]) != str(caso["placa_delantera"]):
		txt += " (tras.: %s)" % Sistema.formato_placa(str(caso["placa_trasera"]))
	var cond: Dictionary = caso["conductor"]
	if not cond.is_empty():
		txt += "\nConduce: %s %s (%s)" % [str(cond["nombre"]), str(cond["apellido"]), str(cond["cedula"])]
	if u.is_empty():
		txt += "\nTitular: no registrado"
	else:
		txt += "\n%s — %s · %s" % [Sistema.nombre_completo(u), str(u["rol"]), Sistema.categoria_de(u)]
		txt += "\nDistancia facial: %.2f (tolerancia %.2f)" % [float(ev["distancia"]), Sistema.TOLERANCIA_ROSTRO]
	if str(ev["puesto"]) != "":
		txt += "\nPuesto: " + str(ev["puesto"])
	(t["info"] as Label).text = txt
	var res: String = str(ev["resultado"])
	var banner: Label = t["banner"]
	if res == "autorizado":
		banner.text = "AUTORIZADO"
		banner.add_theme_color_override("font_color", C_OK)
	elif res == "revisar":
		banner.text = "REVISAR (decide el guardia)"
		banner.add_theme_color_override("font_color", C_AVISO)
	else:
		banner.text = "DENEGADO"
		banner.add_theme_color_override("font_color", C_MAL)
	if float(L["cuenta"]) >= 0.0:
		banner.text += "  · %d s" % int(ceil(float(L["cuenta"])))
	detalle = str(ev["motivo"]) + "\n" + detalle
	var cito: Dictionary = caso["citofono"]
	if bool(L["citofono_visto"]) and not cito.is_empty():
		detalle += "\n📞 " + str(cito["texto"])
	(t["detalle"] as Label).text = detalle
	var esperando: bool = estado == "esperando"
	(t["b_inspeccion"] as Button).disabled = not esperando
	if esperando and res == "revisar" and not bool(L.get("insp_auto", false)):
		L["insp_auto"] = true
		abrir_inspeccion(sentido)
	elif esperando:
		llenar_inspeccion(sentido)
	else:
		cerrar_ventana("insp_" + sentido)
		inspecciones.erase(sentido)
	(t["b_permitir"] as Button).disabled = not principal.puede_permitir(sentido)
	(t["b_denegar"] as Button).disabled = not esperando
	(t["b_citofono"] as Button).disabled = not (esperando and not cito.is_empty()) or bool(L["citofono_visto"])
	(t["b_citofono"] as Button).text = "Citófono"
	if principal.apagon:
		(t["b_citofono"] as Button).text = "🗣 Preguntar"
		(t["b_citofono"] as Button).disabled = not esperando or L.has("pregunta")
		(t["reg_caja"] as Control).visible = false
		var txa: String = "Placa vista: %s" % Sistema.formato_placa(str(caso["placa_delantera"]))
		if str(caso["placa_trasera"]) != str(caso["placa_delantera"]):
			txa += " (tras.: %s)" % Sistema.formato_placa(str(caso["placa_trasera"]))
		if not cond.is_empty():
			txa += "\nDice ser: %s %s (%s)" % [str(cond["nombre"]), str(cond["apellido"]), str(cond["cedula"])]
		txa += "\nSin base de datos."
		(t["info"] as Label).text = txa
		banner.text = "SISTEMA CAÍDO — decide tú"
		banner.add_theme_color_override("font_color", C_AVISO)
		var dap: String = "Sin energía: no hay verificación del sistema, ni citófono."
		if L.has("pregunta") and float(L["pregunta"]) > 0.0:
			dap += "\n[esperando confirmación… %d s]" % int(ceil(float(L["pregunta"])))
		elif str(L.get("pregunta_resp", "")) != "":
			dap += "\n🗣 " + str(L["pregunta_resp"])
		(t["detalle"] as Label).text = dap
	var desconocido: bool = u.is_empty() and sentido == "Entrada"
	(t["b_registrar"] as Button).visible = false
	(t["b_registrar"] as Button).disabled = not (esperando and desconocido and bool(L["citofono_visto"]) and bool(cito.get("responde", false)))


func fijar_estres(v: float) -> void:
	if vineta_estres == null:
		return
	vineta_estres.modulate.a = clampf(v / 100.0, 0.0, 1.0) * 0.55
	estres_valor = v


func actualizar_barra() -> void:
	if principal == null:
		return
	var h: float = principal.esc.hora_dia
	etiqueta_barra.text = "Hora simulada %02d:%02d" % [int(h), int((h - floor(h)) * 60.0)]
	var s: Dictionary = Sistema.estadisticas()
	etiqueta_stats.text = "Dentro %d · Libres %d/%d · Reg. %d · Denegados %d" % [s["vehiculos_dentro"], s["parqueaderos_disponibles"], s["parqueaderos_totales"], s["total_registros"], s["denegados"]]
	var din: int = principal.dinero()
	var v_libres: int = 0
	for pv in Sistema.puestos_visitantes:
		if int(Sistema.ocupacion[pv]) == 0:
			v_libres += 1
	etiqueta_stats.text += " · Visitantes libres %d/%d" % [v_libres, Sistema.puestos_visitantes.size()]
	etiqueta_stats.text += " · 💰 " + principal.formato_dinero(din)
	etiqueta_stats.text += " · Estrés %d%%" % int(estres_valor)
	if principal.apagon:
		etiqueta_stats.text += " · ⚡ SIN ENERGÍA"
	if principal.decisiones > 0:
		etiqueta_stats.text += " · Aciertos %d/%d" % [principal.aciertos, principal.decisiones]
	var i: int = 0 if str(Sistema.config.get("modo", "automatico")) == "automatico" else 1
	if selector_modo.selected != i:
		selector_modo.select(i)


# ---------------------------------------------------------------------------------------------
# ventanas modales
# ---------------------------------------------------------------------------------------------

func abrir_overlay(titulo: String, ancho: float = 980.0, alto: float = 600.0, clave: String = "", desplazable: bool = true) -> VBoxContainer:
	# Ventana flotante: se arrastra por la barra de titulo, se redimensiona por los bordes y no bloquea el resto del programa.
	var k: String = clave if clave != "" else titulo
	cerrar_ventana(k)
	var w := Window.new()
	w.title = titulo
	w.theme = tema
	w.min_size = Vector2i(420, 260)
	w.wrap_controls = false
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tam := Vector2i(int(minf(ancho, vp.x - 30.0)), int(minf(alto, vp.y - 70.0)))
	w.size = tam
	var desfase: int = (ventanas.size() % 5) * 28
	w.position = Vector2i(maxi(10, int((vp.x - tam.x) * 0.5) - 150 + desfase), 40 + desfase)
	var fondo := PanelContainer.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.add_child(fondo)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if desplazable:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		fondo.add_child(sc)
		sc.add_child(v)
	else:
		fondo.add_child(v)
	w.close_requested.connect(func() -> void: cerrar_ventana(k))
	ventanas[k] = w
	add_child(w)
	return v


func cerrar_ventana(clave: String) -> void:
	if ventanas.has(clave):
		var w: Window = ventanas[clave]
		ventanas.erase(clave)
		if is_instance_valid(w):
			w.queue_free()


func cerrar_overlay() -> void:
	for k in ventanas.keys():
		cerrar_ventana(str(k))


func tipos_id() -> Array:
	var r: Array = []
	r.append_array(Sistema.TIPOS_ID)
	for t in Sistema.config.get("tipos_id_extra", []):
		r.append(str(t))
	return r


func fila_form(grid: GridContainer, nombre: String, control: Control) -> Array:
	var l := etiqueta(nombre, 13, C_SUAVE)
	grid.add_child(l)
	grid.add_child(control)
	return [l, control]


# --- gestion de usuarios ----------------------------------------------------------------------

func abrir_usuarios() -> void:
	var v := abrir_overlay("Gestión de usuarios", 980.0, 600.0, "usuarios", false)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 300
	v.add_child(tabs)
	tabs.add_child(pestana_registrar())
	tabs.set_tab_title(0, "Registrar")
	tabs.add_child(pestana_consultar())
	tabs.set_tab_title(1, "Consultar / actualizar / eliminar")


func selector_tipos(opcion_nueva: bool = true) -> OptionButton:
	var ob := OptionButton.new()
	for t in tipos_id():
		ob.add_item(str(t))
	if opcion_nueva:
		ob.add_item("➕ Agregar nuevo tipo…")
	return ob


func pestana_registrar() -> Control:
	var sc := ScrollContainer.new()
	sc.name = "Registrar"
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var rol := OptionButton.new()
	for r in Sistema.ROLES:
		rol.add_item(str(r).capitalize())
	fila_form(grid, "Rol", rol)
	var nombre := campo("Nombres", 300)
	fila_form(grid, "Nombres", nombre)
	var apellido := campo("Apellidos", 300)
	fila_form(grid, "Apellidos", apellido)
	var tipo := selector_tipos()
	fila_form(grid, "Tipo de documento", tipo)
	var nuevo_tipo := campo("Nombre del nuevo tipo de documento", 300)
	var f_nuevo := fila_form(grid, "Nuevo tipo", nuevo_tipo)
	var cedula := campo("Número de documento", 300)
	fila_form(grid, "Documento", cedula)
	var placa := campo("Ej. ABC-123", 300)
	fila_form(grid, "Placa del vehículo", placa)
	var puesto := campo("Ej. R-09", 300)
	var f_puesto := fila_form(grid, "Parqueadero asignado", puesto)
	var apto := campo("Ej. A-101", 300)
	var f_apto := fila_form(grid, "Apartamento", apto)
	var cargo := campo("Ej. mantenimiento", 300)
	var f_cargo := fila_form(grid, "Cargo", cargo)
	var turno := OptionButton.new()
	turno.add_item("mañana")
	turno.add_item("tarde")
	var f_turno := fila_form(grid, "Turno", turno)
	var auth := campo("Residente que autoriza", 300)
	var f_auth := fila_form(grid, "Autorizado por", auth)
	var motivo := campo("Motivo de la visita", 300)
	var f_motivo := fila_form(grid, "Motivo", motivo)
	var vip := CheckBox.new()
	vip.text = "VIP (trato diferenciado; definición de trabajo, sin tarifa ni prioridad)"
	fila_form(grid, "Categoría VIP", vip)
	var motivo_vip := campo("Ej. Miembro del Consejo de Administración", 300)
	fila_form(grid, "Motivo VIP", motivo_vip)
	var semilla: Array = [randi() % 1000000]
	var rostro := RostroVista.new()
	rostro.custom_minimum_size = Vector2(90, 90)
	rostro.call("fijar", semilla[0])
	var fila_rostro := HBoxContainer.new()
	fila_rostro.add_child(rostro)
	fila_rostro.add_child(boton("Nuevo rostro de registro", func() -> void:
		semilla[0] = randi() % 1000000
		rostro.call("fijar", semilla[0])))
	fila_rostro.add_child(etiqueta("  Foto de registro simulada (caricatura generada; no se usan fotos reales).", 12, C_SUAVE))
	fila_form(grid, "Rostro", fila_rostro)
	var aviso := etiqueta("", 14)
	var ajustar := func(_i: int = 0) -> void:
		var r: String = Sistema.ROLES[rol.selected]
		for par in [f_puesto, f_apto]:
			(par[0] as Control).visible = r == "residente" or r == "visitante" if par == f_apto else r == "residente"
			(par[1] as Control).visible = (par[0] as Control).visible
		for par in [f_cargo, f_turno]:
			(par[0] as Control).visible = r == "trabajador"
			(par[1] as Control).visible = r == "trabajador"
		for par in [f_auth, f_motivo]:
			(par[0] as Control).visible = r == "visitante"
			(par[1] as Control).visible = r == "visitante"
		var nuevo: bool = tipo.selected == tipo.item_count - 1
		(f_nuevo[0] as Control).visible = nuevo
		(f_nuevo[1] as Control).visible = nuevo
	rol.item_selected.connect(ajustar)
	tipo.item_selected.connect(ajustar)
	ajustar.call()
	v.add_child(aviso)
	v.add_child(boton("📥 Cargar datos del conductor que está en la garita (entrada)", func() -> void:
		var d: Dictionary = principal.datos_garita()
		if d.is_empty():
			aviso.text = "No hay ningún vehículo esperando en la garita de entrada."
			aviso.add_theme_color_override("font_color", C_AVISO)
			return
		rol.select(2)
		nombre.text = str(d["nombre"])
		apellido.text = str(d["apellido"])
		var ix: int = tipos_id().find(str(d["tipo_id"]))
		if ix >= 0:
			tipo.select(ix)
		cedula.text = str(d["cedula"])
		placa.text = str(d["placa"])
		apto.text = str(d.get("apto", ""))
		auth.text = str(d.get("autorizado_por", ""))
		motivo.text = str(d.get("motivo", "visita"))
		semilla[0] = int(principal.carriles["Entrada"]["caso"]["rostro"])
		rostro.call("fijar", semilla[0])
		ajustar.call()
		aviso.text = "✔ Datos del conductor cargados. Verifica con su documento y registra."
		aviso.add_theme_color_override("font_color", C_OK)))
	v.add_child(boton("Registrar usuario", func() -> void:
		var tipo_txt: String = ""
		if tipo.selected == tipo.item_count - 1:
			tipo_txt = nuevo_tipo.text.strip_edges()
			if tipo_txt == "":
				aviso.text = "Escribe el nombre del nuevo tipo de documento."
				aviso.add_theme_color_override("font_color", C_MAL)
				return
			var extra: Array = Sistema.config.get("tipos_id_extra", [])
			if not extra.has(tipo_txt) and not Sistema.TIPOS_ID.has(tipo_txt):
				extra.append(tipo_txt)
			Sistema.config["tipos_id_extra"] = extra
		else:
			tipo_txt = str(tipos_id()[tipo.selected])
		var r: String = Sistema.ROLES[rol.selected]
		var datos: Dictionary = {"rol": r, "nombre": nombre.text.strip_edges(), "apellido": apellido.text.strip_edges(), "tipo_id": tipo_txt,
			"cedula": cedula.text.strip_edges(), "placa": placa.text.strip_edges(), "rostro": semilla[0]}
		if r == "residente":
			datos["parqueadero"] = puesto.text.strip_edges()
			datos["apto"] = apto.text.strip_edges()
		elif r == "trabajador":
			datos["cargo"] = cargo.text.strip_edges()
			datos["turno"] = turno.get_item_text(turno.selected)
		else:
			datos["apto"] = apto.text.strip_edges()
			datos["autorizado_por"] = auth.text.strip_edges()
			datos["motivo"] = motivo.text.strip_edges()
			datos["autorizacion_activa"] = true
		if vip.button_pressed:
			datos["vip"] = true
			datos["motivo_vip"] = motivo_vip.text.strip_edges()
		var res: Dictionary = Sistema.registrar_usuario(datos)
		if bool(res["ok"]):
			principal.reevaluar_todos()
			aviso.text = "✔ Usuario registrado: %s (ID %d)." % [Sistema.nombre_completo(res["usuario"]), int(res["usuario"]["id"])]
			aviso.add_theme_color_override("font_color", C_OK)
			for e in [nombre, apellido, cedula, placa, puesto, apto, cargo, auth, motivo, nuevo_tipo]:
				(e as LineEdit).text = ""
			semilla[0] = randi() % 1000000
			rostro.call("fijar", semilla[0])
		else:
			aviso.text = "✘ " + str(res["error"])
			aviso.add_theme_color_override("font_color", C_MAL)))
	return sc


func pestana_consultar() -> Control:
	var h := HBoxContainer.new()
	h.name = "Consultar"
	h.add_theme_constant_override("separation", 12)
	var izq := VBoxContainer.new()
	izq.custom_minimum_size.x = 380
	h.add_child(izq)
	var buscar := campo("Buscar por nombre, documento, placa o puesto", 380)
	izq.add_child(buscar)
	var lista := ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size.y = 380
	izq.add_child(lista)
	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(der)
	var ids: Array = []
	var llenar := func(_t: String = "") -> void:
		lista.clear()
		ids.clear()
		var q: String = buscar.text.strip_edges().to_lower()
		for u in Sistema.usuarios:
			var d: Dictionary = u
			var pajar: String = ("%s %s %s %s %s" % [Sistema.nombre_completo(d), d["cedula"], d["placa"], d.get("parqueadero", ""), d["rol"]]).to_lower()
			if q == "" or pajar.contains(q):
				var estado: String = "dentro" if Sistema.esta_dentro(int(d["id"])) else "fuera"
				lista.add_item("%s · %s · %s · %s" % [Sistema.nombre_completo(d), str(d["rol"]), str(d["placa"]), estado])
				ids.append(int(d["id"]))
	buscar.text_changed.connect(llenar)
	llenar.call()
	var mostrar := func(idx: int) -> void:
		for c in der.get_children():
			c.queue_free()
		var d: Dictionary = Sistema.usuario_por_id(int(ids[idx]))
		if d.is_empty():
			return
		var cabecera := HBoxContainer.new()
		var rv := RostroVista.new()
		rv.custom_minimum_size = Vector2(90, 90)
		rv.call("fijar", int(d["rostro"]))
		cabecera.add_child(rv)
		var info := etiqueta("ID %d · %s\n%s (%s) · Doc: %s %s\nRegistrado: %s · Última novedad: %s (%s)\nEstado: %s%s" % [int(d["id"]), Sistema.nombre_completo(d), str(d["rol"]).capitalize(), Sistema.categoria_de(d), str(d["tipo_id"]), str(d["cedula"]), str(d.get("fecha_registro", "")), str(d.get("novedad", "")), str(d.get("fecha_novedad", "")), "dentro" if Sistema.esta_dentro(int(d["id"])) else "fuera", (" · puesto " + Sistema.puesto_de(int(d["id"]))) if Sistema.esta_dentro(int(d["id"])) else ""], 13)
		cabecera.add_child(info)
		der.add_child(cabecera)
		var grid := GridContainer.new()
		grid.columns = 2
		der.add_child(grid)
		var e_nombre := campo("", 280)
		e_nombre.text = str(d["nombre"])
		fila_form(grid, "Nombres", e_nombre)
		var e_apellido := campo("", 280)
		e_apellido.text = str(d["apellido"])
		fila_form(grid, "Apellidos", e_apellido)
		var e_placa := campo("", 280)
		e_placa.text = str(d["placa"])
		fila_form(grid, "Placa", e_placa)
		var e_apto := campo("", 280)
		e_apto.text = str(d.get("apto", ""))
		fila_form(grid, "Apartamento", e_apto)
		var e_puesto := campo("", 280)
		e_puesto.text = str(d.get("parqueadero", ""))
		if str(d["rol"]) == "residente":
			fila_form(grid, "Parqueadero", e_puesto)
		var e_turno := campo("", 280)
		e_turno.text = str(d.get("turno", ""))
		if str(d["rol"]) == "trabajador":
			fila_form(grid, "Turno (mañana/tarde)", e_turno)
		var e_auth := CheckBox.new()
		e_auth.text = "Autorización vigente"
		e_auth.button_pressed = bool(d.get("autorizacion_activa", false))
		if str(d["rol"]) == "visitante":
			fila_form(grid, "Visita", e_auth)
		var e_vip := CheckBox.new()
		e_vip.text = "VIP (definición de trabajo)"
		e_vip.button_pressed = bool(d.get("vip", false))
		fila_form(grid, "Categoría VIP", e_vip)
		var e_motivo_vip := campo("Motivo VIP", 280)
		e_motivo_vip.text = str(d.get("motivo_vip", ""))
		fila_form(grid, "Motivo VIP", e_motivo_vip)
		der.add_child(etiqueta("Vehículos registrados:", 13, C_ACENTO))
		for ve in Sistema.vehiculos_de(d):
			der.add_child(etiqueta("• %s — %s" % [str((ve as Dictionary)["placa"]), Sistema.describir_vehiculo(ve)], 12))
		var fv := HBoxContainer.new()
		fv.add_theme_constant_override("separation", 6)
		var v_placa := campo("Placa nueva", 110)
		var v_tipo := OptionButton.new()
		for tp in ["sedan", "suv", "hatchback", "camioneta", "moto"]:
			v_tipo.add_item(str(Sistema.NOMBRES_TIPO[tp]))
		var v_color := OptionButton.new()
		var hexes: Array = Sistema.NOMBRES_COLOR.keys()
		for hx in hexes:
			v_color.add_item(str(Sistema.NOMBRES_COLOR[hx]))
		fv.add_child(v_placa)
		fv.add_child(v_tipo)
		fv.add_child(v_color)
		var aviso := etiqueta("", 13)
		fv.add_child(boton("Agregar vehículo", func() -> void:
			var tipos_k: Array = ["sedan", "suv", "hatchback", "camioneta", "moto"]
			var r: Dictionary = Sistema.agregar_vehiculo(int(d["id"]), v_placa.text, str(tipos_k[v_tipo.selected]), str(hexes[v_color.selected]))
			if bool(r["ok"]):
				lista.item_selected.emit(idx)
			else:
				aviso.text = "✘ " + str(r["error"])
				aviso.add_theme_color_override("font_color", C_MAL)))
		der.add_child(fv)
		der.add_child(aviso)
		var botones := HBoxContainer.new()
		der.add_child(botones)
		botones.add_child(boton("Guardar cambios", func() -> void:
			var cambios: Dictionary = {"nombre": e_nombre.text.strip_edges(), "apellido": e_apellido.text.strip_edges(), "placa": e_placa.text.strip_edges(), "apto": e_apto.text.strip_edges()}
			var otra: Dictionary = Sistema.buscar_por_placa(e_placa.text)
			if not otra.is_empty() and int(otra["id"]) != int(d["id"]):
				aviso.text = "✘ Esa placa ya pertenece a otro usuario."
				aviso.add_theme_color_override("font_color", C_MAL)
				return
			if str(d["rol"]) == "residente":
				var p: String = e_puesto.text.strip_edges().to_upper()
				if not (Sistema.ocupacion.has(p) and p.begins_with("R-")) or Sistema.puesto_asignado_a_otro(p, int(d["id"])):
					aviso.text = "✘ Parqueadero inválido o asignado a otro residente."
					aviso.add_theme_color_override("font_color", C_MAL)
					return
				cambios["parqueadero"] = p
			if str(d["rol"]) == "trabajador":
				cambios["turno"] = e_turno.text.strip_edges()
			if str(d["rol"]) == "visitante":
				cambios["autorizacion_activa"] = e_auth.button_pressed
			cambios["vip"] = e_vip.button_pressed
			cambios["motivo_vip"] = e_motivo_vip.text.strip_edges()
			Sistema.actualizar_usuario(int(d["id"]), cambios)
			aviso.text = "✔ Usuario actualizado."
			aviso.add_theme_color_override("font_color", C_OK)
			llenar.call()))
		var confirmar: Array = [false]
		var b_el := Button.new()
		b_el.text = "Eliminar usuario"
		b_el.focus_mode = Control.FOCUS_NONE
		b_el.pressed.connect(func() -> void:
			if not confirmar[0]:
				confirmar[0] = true
				b_el.text = "¿Seguro? Pulsa otra vez para eliminar"
				return
			Sistema.eliminar_usuario(int(d["id"]))
			for c in der.get_children():
				c.queue_free()
			llenar.call())
		botones.add_child(b_el)
	lista.item_selected.connect(mostrar)
	return h


# --- registrar visitante desde la garita --------------------------------------------------------

func abrir_registro_visitante() -> void:
	var L: Dictionary = principal.carriles["Entrada"]
	if L.is_empty():
		return
	var caso: Dictionary = L["caso"]
	var d: Dictionary = principal.datos_garita()
	var v := abrir_overlay("Registrar visitante (vehículo no registrado)", 600.0, 560.0, "regvis")
	v.add_child(etiqueta("Datos que presentó el conductor en la garita — verifícalos con su documento antes de registrar.", 13, C_ACENTO))
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	var rv := RostroVista.new()
	rv.custom_minimum_size = Vector2(80, 80)
	rv.call("fijar", int(caso["rostro"]))
	cab.add_child(rv)
	cab.add_child(etiqueta("Placa: %s\nVehículo: %s\nDocumento presentado: %s %s" % [str(d["placa"]), Sistema.describir_vehiculo(caso["vehiculo"]), str(d["tipo_id"]), str(d["cedula"])], 13))
	v.add_child(cab)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	v.add_child(grid)
	var nombre := campo("Nombres", 300)
	nombre.text = str(d["nombre"])
	fila_form(grid, "Nombres", nombre)
	var apellido := campo("Apellidos", 300)
	apellido.text = str(d["apellido"])
	fila_form(grid, "Apellidos", apellido)
	var tipo := selector_tipos(false)
	var ix: int = tipos_id().find(str(d["tipo_id"]))
	if ix >= 0:
		tipo.select(ix)
	fila_form(grid, "Tipo de documento", tipo)
	var cedula := campo("Número de documento", 300)
	cedula.text = str(d["cedula"])
	fila_form(grid, "Documento", cedula)
	var apto := campo("", 300)
	apto.text = str(d.get("apto", ""))
	fila_form(grid, "Apartamento visitado", apto)
	var auth := campo("Residente que autoriza", 300)
	auth.text = str(d.get("autorizado_por", ""))
	fila_form(grid, "Autorizado por", auth)
	var motivo := campo("Motivo", 300)
	motivo.text = str(d.get("motivo", "visita")) if str(d.get("motivo", "")) != "" else "visita"
	fila_form(grid, "Motivo", motivo)
	var aviso := etiqueta("", 13)
	v.add_child(aviso)
	v.add_child(boton("Registrar y reevaluar", func() -> void:
		var datos: Dictionary = {"nombre": nombre.text.strip_edges(), "apellido": apellido.text.strip_edges(), "tipo_id": str(tipos_id()[tipo.selected]),
			"cedula": cedula.text.strip_edges(), "apto": apto.text.strip_edges(), "autorizado_por": auth.text.strip_edges(), "motivo": motivo.text.strip_edges()}
		var res: Dictionary = principal.registrar_visitante("Entrada", datos)
		if bool(res["ok"]):
			cerrar_ventana("regvis")
			mensaje("Visitante registrado. Revisa el resultado y decide.", C_OK)
		else:
			aviso.text = "✘ " + str(res["error"])
			aviso.add_theme_color_override("font_color", C_MAL)))


# --- inspeccion del guardia ---------------------------------------------------------------------

func abrir_inspeccion(sentido: String) -> void:
	var clave: String = "insp_" + sentido
	var v := abrir_overlay("Inspección — " + ("ENTRADA" if sentido == "Entrada" else "SALIDA"), 940.0, 600.0, clave)
	inspecciones[sentido] = v
	if not principal.carriles[sentido].is_empty():
		principal.carriles[sentido]["uso_inspeccion"] = true
	llenar_inspeccion(sentido)


func filas_visuales(caso: Dictionary, L: Dictionary) -> Array:
	var filas: Array = []
	var pd: String = str(caso["placa_delantera"])
	var pt: String = str(caso["placa_trasera"])
	filas.append({"t": "Placa delantera vista", "e": "info", "d": Sistema.formato_placa(pd)})
	filas.append({"t": "Placa trasera vs delantera", "e": "ok" if pd == pt else "mal", "d": "Coinciden." if pd == pt else "No coinciden: trasera %s." % Sistema.formato_placa(pt)})
	filas.append({"t": "Vehículo visto", "e": "info", "d": Sistema.describir_vehiculo(caso["vehiculo"])})
	var c: Dictionary = caso["conductor"]
	filas.append({"t": "Conductor (documento que presenta)", "e": "info", "d": "%s %s · %s %s" % [str(c.get("nombre", "?")), str(c.get("apellido", "")), str(c.get("tipo_id", "")), str(c.get("cedula", ""))]})
	if L.has("pregunta") and float(L["pregunta"]) > 0.0:
		filas.append({"t": "Consulta", "e": "info", "d": "[esperando confirmación… %d s]" % int(ceil(float(L["pregunta"])))})
	elif str(L.get("pregunta_resp", "")) != "":
		filas.append({"t": "Respuesta de la consulta", "e": "info", "d": str(L["pregunta_resp"])})
	else:
		filas.append({"t": "Consulta", "e": "info", "d": "Aún no has preguntado."})
	return filas


func llenar_inspeccion(sentido: String) -> void:
	if not inspecciones.has(sentido):
		return
	var v: VBoxContainer = inspecciones[sentido]
	if not is_instance_valid(v):
		inspecciones.erase(sentido)
		return
	for c in v.get_children():
		c.queue_free()
	var info: Dictionary = principal.inspeccion(sentido)
	if info.is_empty():
		v.add_child(etiqueta("No hay un vehículo en revisión en este carril.", 14, C_SUAVE))
		return
	var L: Dictionary = principal.carriles[sentido]
	var caso: Dictionary = info["caso"]
	var u: Dictionary = info["titular"]
	var cond: Dictionary = info["conductor"]
	# banner
	var res: String = str(info["resultado"])
	var banner := etiqueta("", 16)
	var ap: bool = principal.apagon
	if ap:
		banner.text = "SISTEMA CAÍDO: sin base de datos ni citófono. Decide con lo que ves; si dudas, envía a preguntar."
		banner.add_theme_color_override("font_color", C_AVISO)
	elif res == "autorizado":
		banner.text = "El sistema propone: AUTORIZADO"
		banner.add_theme_color_override("font_color", C_OK)
	elif res == "revisar":
		banner.text = "El sistema NO decide: REVISAR — " + str(info["motivo"])
		banner.add_theme_color_override("font_color", C_AVISO)
	else:
		banner.text = "El sistema propone: DENEGADO — " + str(info["motivo"])
		banner.add_theme_color_override("font_color", C_MAL)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.custom_minimum_size.x = 600
	v.add_child(banner)
	# fotos
	var fotos := HBoxContainer.new()
	fotos.add_theme_constant_override("separation", 8)
	var imgs: Dictionary = L["imgs"]
	for par in [["placa_delantera", "Placa delantera"], ["placa_trasera", "Placa trasera"], ["rostro", "Cámara del conductor"]]:
		var col := VBoxContainer.new()
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(176, 110)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		if imgs.has(par[0]):
			tr.texture = ImageTexture.create_from_image(imgs[par[0]])
		col.add_child(tr)
		col.add_child(etiqueta(str(par[1]), 11, C_SUAVE))
		fotos.add_child(col)
	v.add_child(fotos)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)
	# izquierda: personas
	var izq := VBoxContainer.new()
	izq.custom_minimum_size.x = 330
	cols.add_child(izq)
	izq.add_child(etiqueta("QUIEN CONDUCE (presenta documento)", 13, C_ACENTO))
	var f1 := HBoxContainer.new()
	f1.add_theme_constant_override("separation", 8)
	var r1 := RostroVista.new()
	r1.custom_minimum_size = Vector2(84, 84)
	r1.call("fijar", int(caso["rostro"]))
	f1.add_child(r1)
	var t1 := etiqueta("%s %s\n%s %s\n%s" % [str(cond.get("nombre", "?")), str(cond.get("apellido", "")), str(cond.get("tipo_id", "")), str(cond.get("cedula", "")), ("Apto: " + str(cond["apto"])) if str(cond.get("apto", "")) != "" else ""], 13)
	f1.add_child(t1)
	izq.add_child(f1)
	izq.add_child(HSeparator.new())
	izq.add_child(etiqueta("TITULAR DE LA PLACA (en la base de datos)", 13, C_ACENTO))
	if ap:
		izq.add_child(etiqueta("Sin acceso a la base de datos (sistema caído).", 13, C_AVISO))
	elif u.is_empty():
		izq.add_child(etiqueta("Placa no registrada: no hay titular.", 13, C_AVISO))
	else:
		var f2 := HBoxContainer.new()
		f2.add_theme_constant_override("separation", 8)
		var r2 := RostroVista.new()
		r2.custom_minimum_size = Vector2(84, 84)
		r2.call("fijar", int(u["rostro"]))
		f2.add_child(r2)
		var extra: String = ""
		if str(u["rol"]) == "residente":
			extra = "\nApto %s · Parqueadero %s" % [str(u.get("apto", "")), str(u.get("parqueadero", ""))]
		elif str(u["rol"]) == "trabajador":
			extra = "\n%s · turno %s" % [str(u.get("cargo", "")), str(u.get("turno", ""))]
		else:
			extra = "\nVisita a %s (%s)" % [str(u.get("autorizado_por", "?")), str(u.get("motivo", ""))]
		f2.add_child(etiqueta("%s\n%s · %s %s%s" % [Sistema.nombre_completo(u), str(u["rol"]).capitalize(), str(u["tipo_id"]), str(u["cedula"]), extra], 13))
		izq.add_child(f2)
		izq.add_child(etiqueta("Vehículos registrados del titular:", 12, C_SUAVE))
		for ve in info["vehiculos"]:
			izq.add_child(etiqueta("• %s — %s" % [str((ve as Dictionary)["placa"]), Sistema.describir_vehiculo(ve)], 12))
	# derecha: comprobaciones
	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(der)
	der.add_child(etiqueta("COMPROBACIONES", 13, C_ACENTO))
	for fila in (filas_visuales(caso, L) if ap else info["filas"]):
		var f: Dictionary = fila
		var marca: String = "✔" if str(f["e"]) == "ok" else ("✘" if str(f["e"]) == "mal" else "ℹ")
		var col: Color = C_OK if str(f["e"]) == "ok" else (C_MAL if str(f["e"]) == "mal" else C_SUAVE)
		var fh := HBoxContainer.new()
		var m := etiqueta(marca, 15, col)
		m.custom_minimum_size.x = 22
		fh.add_child(m)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(etiqueta(str(f["t"]), 13, col))
		var dl := etiqueta(str(f["d"]), 12, C_TEXTO)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 340
		tv.add_child(dl)
		fh.add_child(tv)
		der.add_child(fh)
	var acc := VBoxContainer.new()
	acc.add_theme_constant_override("separation", 6)
	acc.add_child(HSeparator.new())
	acc.add_child(etiqueta("Decide el guardia (el modo automático nunca decide los casos en REVISAR):", 13, C_SUAVE))
	var nota := campo("Nota del guardia (opcional): queda en el historial", 600)
	nota.text = str(notas.get(sentido, ""))
	nota.text_changed.connect(func(t: String) -> void: notas[sentido] = t)
	acc.add_child(nota)
	var bt := HBoxContainer.new()
	bt.add_theme_constant_override("separation", 8)
	acc.add_child(bt)
	var cito: Dictionary = caso["citofono"]
	var b_cito := boton("📞 Llamar por citófono", func() -> void:
		if principal.apagon:
			principal.preguntar(sentido)
		else:
			principal.citofono(sentido))
	b_cito.disabled = cito.is_empty() or bool(L["citofono_visto"]) or str(L["estado"]) != "esperando"
	if ap:
		b_cito.text = "🗣 Enviar a preguntar (10 s)"
		b_cito.disabled = L.has("pregunta") or str(L["estado"]) != "esperando"
	bt.add_child(b_cito)
	var b_p := boton("✔ Permitir (bajo mi responsabilidad)", func() -> void:
		principal.permitir(sentido, "Guardia", nota.text)
		notas.erase(sentido))
	b_p.disabled = not principal.puede_permitir(sentido)
	bt.add_child(b_p)
	bt.add_child(boton("✘ Negar / detener a la persona", func() -> void:
		principal.denegar(sentido, "Guardia", nota.text)
		notas.erase(sentido)))
	if u.is_empty() and sentido == "Entrada":
		var b_r := boton("➕ Registrar visitante", func() -> void: abrir_registro_visitante())
		b_r.disabled = not (bool(L["citofono_visto"]) and bool(cito.get("responde", false)))
		b_r.tooltip_text = "Se habilita cuando el residente confirma por citófono"
		bt.add_child(b_r)
	v.add_child(acc)
	v.move_child(acc, 1)


# --- historial --------------------------------------------------------------------------------

func abrir_historial() -> void:
	var v := abrir_overlay("Historial de accesos", 1100.0, 600.0, "historial", false)
	var barra := HBoxContainer.new()
	v.add_child(barra)
	var filtro := OptionButton.new()
	for t in ["Todos", "Entrada", "Salida", "Denegado"]:
		filtro.add_item(t)
	barra.add_child(etiqueta("Filtro: ", 13, C_SUAVE))
	barra.add_child(filtro)
	var buscar := campo("Buscar (nombre, placa, puesto, detalle)", 360)
	barra.add_child(buscar)
	var contador := etiqueta("", 13, C_SUAVE)
	barra.add_child(contador)
	var arbol := Tree.new()
	arbol.columns = 11
	arbol.column_titles_visible = true
	arbol.hide_root = true
	arbol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arbol.custom_minimum_size.y = 200
	var titulos: Array = ["ID", "Fecha", "Usuario", "Placa", "Clasificación", "Categoría", "Estado", "Puesto", "Sim.", "Registrado por", "Detalle"]
	var anchos: Array = [40, 150, 170, 80, 90, 80, 80, 60, 40, 130, 380]
	for i in range(titulos.size()):
		arbol.set_column_title(i, str(titulos[i]))
		arbol.set_column_custom_minimum_width(i, int(anchos[i]))
		arbol.set_column_expand(i, i == 10)
	v.add_child(arbol)
	var fotos := HBoxContainer.new()
	fotos.custom_minimum_size.y = 120
	v.add_child(fotos)
	var datos_fila: Array = []
	var llenar := func(_x: Variant = null) -> void:
		arbol.clear()
		datos_fila.clear()
		var raiz_t: TreeItem = arbol.create_item()
		var q: String = buscar.text.strip_edges().to_lower()
		var f: String = filtro.get_item_text(filtro.selected)
		var n: int = 0
		for i in range(Sistema.movimientos.size() - 1, -1, -1):
			var m: Dictionary = Sistema.movimientos[i]
			if f != "Todos" and str(m["estado"]) != f:
				continue
			var pajar: String = ("%s %s %s %s" % [m["nombre"], m["placa"], m["puesto"], m["detalle"]]).to_lower()
			if q != "" and not pajar.contains(q):
				continue
			var it: TreeItem = arbol.create_item(raiz_t)
			var vals: Array = [str(m["id"]), str(m["fecha"]), str(m["nombre"]), str(m["placa"]), str(m["clasificacion"]), str(m.get("categoria", "—")), str(m["estado"]), str(m["puesto"]), "%02d h" % int(m.get("hora_sim", 0)), str(m.get("registrado_por", "—")), str(m["detalle"])]
			for c in range(vals.size()):
				it.set_text(c, str(vals[c]))
			var col: Color = C_MAL if str(m["estado"]) == "Denegado" else (C_OK if str(m["estado"]) == "Entrada" else C_AVISO)
			it.set_custom_color(5, col)
			it.set_metadata(0, datos_fila.size())
			datos_fila.append(m)
			n += 1
			if n >= 600:
				break
		contador.text = "  %d registros mostrados (de %d)" % [n, Sistema.movimientos.size()]
	filtro.item_selected.connect(llenar)
	buscar.text_changed.connect(llenar)
	llenar.call()
	arbol.item_selected.connect(func() -> void:
		for c in fotos.get_children():
			c.queue_free()
		var it: TreeItem = arbol.get_selected()
		if it == null:
			return
		var m: Dictionary = datos_fila[int(it.get_metadata(0))]
		var lista: Array = m.get("fotos", [])
		if lista.is_empty():
			fotos.add_child(etiqueta("Este registro no tiene fotos (dato inicial o carga manual).", 13, C_SUAVE))
		for ruta in lista:
			if FileAccess.file_exists(str(ruta)):
				var img := Image.load_from_file(str(ruta))
				if img != null:
					var tr := TextureRect.new()
					tr.texture = ImageTexture.create_from_image(img)
					tr.custom_minimum_size = Vector2(180, 112)
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_SCALE
					tr.tooltip_text = str(ruta).get_file()
					fotos.add_child(tr))


# --- estado del parqueadero ---------------------------------------------------------------------

func abrir_parqueadero() -> void:
	var v := abrir_overlay("Estado del parqueadero", 980.0, 560.0)
	var s: Dictionary = Sistema.estadisticas()
	v.add_child(etiqueta("Ocupados: %d · Libres: %d · Total: %d (V-01…V-15 visitantes · R-01…R-25 residentes · escala reducida de demostración)" % [s["parqueaderos_ocupados"], s["parqueaderos_disponibles"], s["parqueaderos_totales"]], 14, C_SUAVE))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for p in Sistema.todos_los_puestos():
		var id: int = int(Sistema.ocupacion[p])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 52)
		var u: Dictionary = Sistema.usuario_por_id(id) if id != 0 else {}
		b.text = "%s\n%s" % [p, "LIBRE" if id == 0 else str(u.get("placa", "?"))]
		b.tooltip_text = "Libre" if id == 0 else "%s (%s)" % [Sistema.nombre_completo(u), str(u.get("rol", ""))]
		var base: Color = Color("#1f5c3a") if id == 0 else Color("#7a2a2a")
		if str(p).begins_with("V-"):
			base = Color("#1f4f6e") if id == 0 else Color("#7a4a1f")
		b.add_theme_stylebox_override("normal", estilo(base, 6))
		b.add_theme_stylebox_override("hover", estilo(base.lightened(0.15), 6))
		b.add_theme_stylebox_override("pressed", estilo(base, 6))
		grid.add_child(b)
	v.add_child(etiqueta("Verde/azul: libre · Rojo/naranja: ocupado (pasa el cursor para ver quién).", 12, C_SUAVE))


# --- configuracion -----------------------------------------------------------------------------

func abrir_config() -> void:
	var v := abrir_overlay("Configuración", 760.0, 560.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var modo := OptionButton.new()
	modo.add_item("Automático (el sistema decide; el guardia solo revisa los dudosos)")
	modo.add_item("Manual (el guardia decide todos los casos)")
	modo.select(0 if str(Sistema.config.get("modo", "automatico")) == "automatico" else 1)
	modo.item_selected.connect(func(i: int) -> void:
		Sistema.config["modo"] = "automatico" if i == 0 else "manual"
		Sistema.guardar()
		actualizar_barra())
	fila_form(grid, "Modo de operación", modo)
	var popup := SpinBox.new()
	popup.min_value = 1
	popup.max_value = 10
	popup.value = float(Sistema.config.get("popup_segundos", 3))
	popup.suffix = "s"
	popup.value_changed.connect(func(x: float) -> void:
		Sistema.config["popup_segundos"] = int(x)
		Sistema.guardar())
	fila_form(grid, "Segundos del aviso automático", popup)
	var cal := OptionButton.new()
	for t in ["Baja (sin brillo ni niebla)", "Media", "Alta (con sombras)"]:
		cal.add_item(t)
	cal.select(principal.esc.calidad)
	cal.item_selected.connect(func(i: int) -> void: principal.esc.aplicar_calidad(i))
	fila_form(grid, "Calidad gráfica", cal)
	var snd := CheckBox.new()
	snd.text = "Sonido activado"
	snd.button_pressed = not principal.audio.silencio
	snd.toggled.connect(func(b: bool) -> void: principal.audio.silencio = not b)
	fila_form(grid, "Sonido", snd)
	var hora := HSlider.new()
	hora.min_value = 0
	hora.max_value = 23.99
	hora.step = 0.25
	hora.value = principal.esc.hora_dia
	hora.custom_minimum_size.x = 300
	hora.value_changed.connect(func(x: float) -> void:
		principal.esc.hora_dia = x
		principal.esc.fijar_hora(x)
		actualizar_barra())
	fila_form(grid, "Hora simulada (afecta turnos de trabajadores)", hora)
	var apag := CheckBox.new()
	apag.button_pressed = principal.apagones_aleatorios
	apag.toggled.connect(func(b: bool) -> void: principal.apagones_aleatorios = b)
	fila_form(grid, "Apagones aleatorios (evento de estrés)", apag)
	var fcx := CheckBox.new()
	fcx.button_pressed = principal.fallas_conexion
	fcx.toggled.connect(func(b: bool) -> void: principal.fallas_conexion = b)
	fila_form(grid, "Error de conexión ocasional (excepción del UML, ~7 %)", fcx)
	var exp := SpinBox.new()
	exp.min_value = 0
	exp.max_value = 60
	exp.step = 1
	exp.value = principal.expira_min
	exp.suffix = " min (0 = no expira)"
	exp.value_changed.connect(func(x: float) -> void: principal.expira_min = x)
	fila_form(grid, "Sesión expira por inactividad (demostración)", exp)
	v.add_child(boton("⚡ Provocar un apagón ahora (demostración)", func() -> void: principal.provocar_apagon()))
	v.add_child(HSeparator.new())
	v.add_child(etiqueta("Cambiar contraseña del administrador", 15, C_ACENTO))
	var g2 := GridContainer.new()
	g2.columns = 2
	v.add_child(g2)
	var actual := campo("contraseña actual", 260, true)
	fila_form(g2, "Actual", actual)
	var nueva := campo("mínimo 6 caracteres", 260, true)
	fila_form(g2, "Nueva", nueva)
	var repite := campo("repite la nueva", 260, true)
	fila_form(g2, "Confirmar", repite)
	var aviso := etiqueta("", 13)
	v.add_child(aviso)
	v.add_child(boton("Cambiar contraseña", func() -> void:
		if not Sistema.validar_login(str(Sistema.config["admin_user"]), actual.text):
			aviso.text = "✘ La contraseña actual no es correcta."
			aviso.add_theme_color_override("font_color", C_MAL)
		elif nueva.text.length() < 6:
			aviso.text = "✘ La nueva contraseña debe tener al menos 6 caracteres."
			aviso.add_theme_color_override("font_color", C_MAL)
		elif nueva.text != repite.text:
			aviso.text = "✘ La confirmación no coincide."
			aviso.add_theme_color_override("font_color", C_MAL)
		else:
			Sistema.cambiar_clave(nueva.text)
			aviso.text = "✔ Contraseña actualizada (se guarda como hash SHA-256)."
			aviso.add_theme_color_override("font_color", C_OK)
			actual.text = ""
			nueva.text = ""
			repite.text = ""))
	v.add_child(HSeparator.new())
	var confirmar: Array = [false]
	var b_reset := Button.new()
	b_reset.text = "Reiniciar datos de demostración (borra usuarios nuevos e historial)"
	b_reset.focus_mode = Control.FOCUS_NONE
	b_reset.pressed.connect(func() -> void:
		if not confirmar[0]:
			confirmar[0] = true
			b_reset.text = "¿Seguro? Pulsa otra vez para reiniciar todo"
			return
		Sistema.reiniciar_datos()
		principal.sincronizar_estacionados()
		cerrar_ventana("Configuración")
		mensaje("Datos reiniciados a los de demostración.", C_AVISO))
	v.add_child(b_reset)


# --- ayuda -------------------------------------------------------------------------------------

func abrir_ayuda() -> void:
	var v := abrir_overlay("Ayuda", 900.0, 600.0)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size.x = 850
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text = AYUDA
	sc.add_child(t)


const AYUDA := """[b]Novedades v4[/b]
Apagón (aleatorio o desde Config.): se van las luces, el sistema automático y las cámaras dejan de funcionar y no hay citófono. Decides tú con lo que ves y puedes [b]enviar a preguntar[/b] (10 s, «[esperando confirmación]»). La barra muestra el estrés, que sube mientras dura el apagón con vehículos esperando. El botón [b]📹 Monitor[/b] abre cámaras fijas que giran e inclinan (botones o arrastrando).

[b]Novedades v3[/b]
Menú inicial (Iniciar, Mapas, Ajustes, Salir), cinemática de inicio (Esc la salta), tareas del turno en el PC, conductores que bajan del vehículo y caminan al edificio, robo con policía, dinero del turno (valores de juego) y tecla 7 = puesto del guarda en primera persona (clic derecho mira alrededor). Los controles se pueden cambiar en Ajustes.

[b]Qué es esto[/b]
Simulador del sistema CISPPH (control de ingreso y salida de parqueaderos de propiedad horizontal). Todo ocurre en un solo escenario 3D: calle, garita con dos barreras (entrada y salida) y parqueadero de 40 puestos en circuito (V-01…V-15 visitantes, R-01…R-25 residentes; el caso del cliente describe 210 privados y 15 de visitantes, aquí se dibuja una escala reducida).

[b]Cómo se usa[/b]
1. Inicia sesión (admin / admin123 la primera vez).
2. Pulsa «Generar entrada» o «Generar salida» (o deja el tráfico automático). Llega un vehículo, se detiene en la garita y el sistema toma 3 fotos simuladas: placa delantera, placa trasera y rostro del conductor.
3. El sistema compara la placa con la base de datos y el rostro con el del titular (distancia facial simulada; tolerancia 0.55) y propone AUTORIZADO, REVISAR o DENEGADO.
4. Modo [b]Automático[/b]: los casos claros (todo coincide) y los denegados por regla (p. ej. ya está dentro) se ejecutan solos tras unos segundos. Los casos en [b]REVISAR[/b] (rostro distinto, vehículo distinto al registrado, placa no registrada, placa trasera distinta, fuera de turno…) [b]nunca se deciden solos[/b]: se abre la ventana de [b]Inspección[/b]. Modo [b]Manual[/b]: el guardia decide todo.
5. [b]Inspección[/b] (ventana flotante: se arrastra y se redimensiona): muestra las fotos, quién conduce y su documento, el titular de la placa con sus vehículos registrados, y una lista de comprobaciones ✔/✘ (placas, vehículo visto vs registrado, rostro vs titular, a quién corresponde el rostro en la base, estado, turno, autorización, cupo). Con [b]Citófono[/b] llamas al residente. Luego decides: [b]Permitir (bajo mi responsabilidad)[/b] o [b]Negar / detener a la persona[/b]; puedes dejar una nota que queda en el historial. Si el vehículo no está registrado y el residente confirma, usa [b]Registrar visitante[/b]: el formulario ya trae nombre, documento, apartamento y residente que autoriza.
   Tras decidir un caso dudoso, la simulación te dice si acertaste (solo para práctica; un sistema real no lo sabría) y la barra muestra tus aciertos.
6. Cada decisión queda en el [b]Historial[/b] con sus fotos. El estado de los 40 puestos está en [b]Parqueadero[/b].

[b]Casos que simula[/b]
Residente (con su coche principal o con otro de sus vehículos registrados) · trabajador (turno con la hora simulada: mañana 06–14, tarde 14–22) · visitante autorizado · placa del residente con otra persona al volante (a veces un familiar, a veces un impostor) · placa del residente en un vehículo distinto al registrado (cambio de carro o placa clonada) · vehículo no registrado · usuario que ya figura dentro · placa trasera distinta de la delantera · salida normal · salida con otra persona al volante (familiar autorizado o posible robo).

[b]Cámaras[/b]  1 Garita · 2 Seguridad · 3 Aérea · 4 Libre (clic derecho gira, rueda acerca) · 6 Cine · o «Cámara automática» que sigue al vehículo.

[b]Ventanas[/b]  Todas las ventanas (Usuarios, Historial, Inspección…) se arrastran por la barra de título, se agrandan o achican por los bordes y pueden estar varias abiertas.

[b]Teclas[/b]  E entrada · S salida · Enter permitir · Retroceso denegar.

[b]Límites (honestos)[/b]
La lectura de placa y el reconocimiento facial son [b]simulados[/b] (didácticos): no hay OCR ni reconocimiento facial real. Los rostros son caricaturas generadas, no fotos de personas. Tarifas, minutos de gracia y clasificación VIS/VIP/No VIP [b]no están implementados[/b] porque el equipo aún no los ha validado.
"""


# ---------------------------------------------------------------------------------------------
# menu inicial (v3)
# ---------------------------------------------------------------------------------------------

const TEXTO_QUE_ES := """[b]¿Qué es CISPPH?[/b]
C.I.S.P.P.H. significa [i]Control de Ingreso y Salida para Parqueaderos de Propiedad Horizontal[/i].

[b]Quiénes somos[/b]
Equipo de estudiantes de la Escuela Tecnológica Instituto Técnico Central (ETITC), materia Diseño de Software I, con el docente José Del Carmen Ortega Castro:
• Luis David Caicedo Rodríguez (Product Owner)
• Edisson David Vargas Castiblanco (Scrum Master)
• Javier Santiago Pérez Tobon (Desarrollador)

[b]Esto es un simulador[/b]
Es una herramienta didáctica para explicar y probar las ideas del proyecto; [b]no es el sistema final[/b] ni usa datos reales. Los personajes, placas, rostros y el dinero del juego son inventados. Los valores de multas y recompensas son marcadores del juego, no reglas del proyecto.

[b]Caso ilustrativo[/b]
El simulador toma como caso de ejemplo el conjunto «Robles del Norte P.H.» (Suba, Bogotá): 3 torres, 180 apartamentos, 2 guardias 24 h y control manual con talonario. Los datos del caso son ilustrativos. Por escala, aquí se simulan 25 puestos de residentes y 15 de visitantes (el caso describe 210 y 15). Las categorías No VIP (residente), VIS (visitante) y VIP (consejo, administración, proveedores autorizados) son una [i]definición de trabajo pendiente de ratificar[/i]: no tienen tarifas ni prioridades definidas.

[b]Problema que se quiere atender[/b]
Según el análisis preliminar del equipo (todavía una hipótesis que se debe validar), en muchos parqueaderos de propiedad horizontal el registro es manual y la verificación depende del guarda, lo que puede causar demoras, errores al anotar placas, dificultad para verificar autorizaciones, pérdida de trazabilidad, dificultad para consultar el historial y poco control de visitantes."""



func crear_menu() -> void:
	menu_panel = Control.new()
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(menu_panel)
	var vel := ColorRect.new()
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	vel.color = Color(0.03, 0.05, 0.09, 0.55)
	vel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(vel)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(centro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	centro.add_child(v)
	var t := etiqueta("CISPPH", 64, C_ACENTO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := etiqueta("SIMULADOR DEL GUARDA DE SEGURIDAD", 16, C_SUAVE)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var esp := Control.new()
	esp.custom_minimum_size.y = 24
	v.add_child(esp)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(fila)
	var defs: Array = [
		["play", "INICIAR", "Nuevo turno", C_OK, func() -> void: iniciar_desde_menu()],
		["map", "MAPAS", "Escenarios", C_ACENTO, func() -> void: abrir_mapas()],
		["gear", "AJUSTES", "Opciones", C_AVISO, func() -> void: abrir_ajustes()],
		["power", "SALIR", "Cerrar juego", C_MAL, func() -> void: get_tree().quit()]]
	for d in defs:
		var ic := IconoMenu.new()
		ic.configurar(str(d[0]), str(d[1]), str(d[2]), d[3])
		ic.pulsado.connect(d[4])
		fila.add_child(ic)
	var pie := etiqueta("Proyecto académico · ETITC · Diseño de Software I", 12, C_SUAVE)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pie)
	# tarjeta pequena tipo "anuncio" abajo a la derecha; al pulsarla se agranda
	var ad := PanelContainer.new()
	ad.name = "Anuncio"
	ad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ad.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ad.offset_right = -14
	ad.offset_bottom = -14
	menu_panel.add_child(ad)
	var av := VBoxContainer.new()
	ad.add_child(av)
	var cab := HBoxContainer.new()
	av.add_child(cab)
	var bi := IconoMenu.new()
	bi.configurar("info", "", "", C_ACENTO, 26, 26)
	cab.add_child(bi)
	var bt := Button.new()
	bt.text = "¿Qué es CISPPH?  ▴"
	bt.flat = true
	bt.focus_mode = Control.FOCUS_NONE
	cab.add_child(bt)
	var alternar := func() -> void:
		abrir_que_es()
	bt.pressed.connect(alternar)
	bi.pulsado.connect(alternar)
	menu_panel.visible = true


func abrir_que_es() -> void:
	var v := abrir_overlay("¿Qué es CISPPH?", 560.0, 520.0, "about")
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size.x = 500
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text = TEXTO_QUE_ES
	v.add_child(t)


func _texto_metricas() -> Dictionary:
	var filas: Array = principal.metricas
	var ok: Array = []
	var fallas: int = 0
	var guardia: int = 0
	var auto: int = 0
	var aciertos: int = 0
	var evaluadas: int = 0
	var con_insp: int = 0
	for m in filas:
		if str(m["decision"]) == "no registrada":
			fallas += 1
			continue
		ok.append(float(m["segundos"]))
		if str(m["origen"]) == "Guardia":
			guardia += 1
			if bool(m["inspeccion"]):
				con_insp += 1
		else:
			auto += 1
		if str(m["acierto"]) != "":
			evaluadas += 1
			if str(m["acierto"]) == "sí":
				aciertos += 1
	var suma: float = 0.0
	var mn: float = 0.0
	var mx: float = 0.0
	for x in ok:
		suma += float(x)
	if ok.size() > 0:
		mn = float(ok.min())
		mx = float(ok.max())
	var prom: float = suma / float(ok.size()) if ok.size() > 0 else 0.0
	return {"n": ok.size(), "prom": prom, "min": mn, "max": mx, "guardia": guardia, "auto": auto,
		"fallas": fallas, "aciertos": aciertos, "evaluadas": evaluadas, "insp": con_insp}


func _tabla_validacion() -> String:
	var m: Dictionary = _texto_metricas()
	var fecha: String = Time.get_date_string_from_system()
	var t: String = "## Registro de validación del prototipo (borrador generado por el simulador)\n\n"
	t += "| Fecha | Tarea probada | Participante / perfil | Hallazgo | Cambio | Estado |\n|---|---|---|---|---|---|\n"
	t += "| %s | Decidir permitir/denegar acceso en la garita simulada (%d decisiones) | (completar) | Tiempo medio de decisión %.1f s (mín %.1f, máx %.1f); incluye el tiempo de reflexión de la persona, no mide el RNF-003 | (completar) | Pendiente de revisar |\n" % [fecha, int(m["n"]), float(m["prom"]), float(m["min"]), float(m["max"])]
	t += "| %s | Consultar la inspección antes de decidir | (completar) | %d de %d decisiones del guardia usaron la inspección | (completar) | Pendiente de revisar |\n" % [fecha, int(m["insp"]), int(m["guardia"])]
	t += "| %s | Manejo de error de conexión (excepción del UML) | (completar) | %d errores simulados; la operación no se registró y se reintentó | (completar) | Pendiente de revisar |\n" % [fecha, int(m["fallas"])]
	t += "\nNota: los datos provienen de una sesión del simulador, no de usuarios reales. El participante, el cambio y el estado deben completarse por el equipo.\n"
	return t


func abrir_metricas() -> void:
	var v := abrir_overlay("Métricas de la sesión", 760.0, 560.0, "metricas")
	var m: Dictionary = _texto_metricas()
	v.add_child(etiqueta("Resumen de la sesión actual", 16, C_ACENTO))
	v.add_child(etiqueta("Decisiones registradas: %d (guardia %d · automáticas %d) · errores de conexión simulados: %d" % [int(m["n"]), int(m["guardia"]), int(m["auto"]), int(m["fallas"])], 13))
	v.add_child(etiqueta("Tiempo de decisión: promedio %.1f s · mínimo %.1f s · máximo %.1f s" % [float(m["prom"]), float(m["min"]), float(m["max"])], 13))
	v.add_child(etiqueta("Casos dudosos evaluados: %d · aciertos del guardia: %d" % [int(m["evaluadas"]), int(m["aciertos"])], 13))
	v.add_child(etiqueta("Aviso: el tiempo medido incluye lo que tarda la persona en pensar y leer; no es el tiempo de registro del sistema (RNF-003, umbral propuesto ≤ 3 s, sin validar).", 12, C_SUAVE))
	v.add_child(HSeparator.new())
	v.add_child(etiqueta("Borrador para la tabla de validación del prototipo (§11.1 de la guía)", 14, C_ACENTO))
	var te := TextEdit.new()
	te.text = _tabla_validacion()
	te.editable = true
	te.custom_minimum_size = Vector2(700, 220)
	v.add_child(te)
	var aviso := etiqueta("", 12, C_OK)
	v.add_child(boton("Guardar CSV y Markdown en la carpeta de datos", func() -> void:
		var f := FileAccess.open("user://metricas_sesion.csv", FileAccess.WRITE)
		if f != null:
			f.store_line("fecha,sentido,categoria,caso,decision,origen,segundos,uso_inspeccion,acierto")
			for r in principal.metricas:
				f.store_line("%s,%s,%s,\"%s\",%s,%s,%s,%s,%s" % [r["fecha"], r["sentido"], r["categoria"], str(r["caso"]).replace("\"", "'"), r["decision"], r["origen"], r["segundos"], r["inspeccion"], r["acierto"]])
			f.close()
		var g := FileAccess.open("user://registro_validacion.md", FileAccess.WRITE)
		if g != null:
			g.store_string(te.text)
			g.close()
		aviso.text = "Guardado en: " + ProjectSettings.globalize_path("user://")))
	v.add_child(boton("Copiar la tabla al portapapeles", func() -> void:
		DisplayServer.clipboard_set(te.text)
		aviso.text = "Copiado."))
	v.add_child(aviso)


func mostrar_menu() -> void:
	login_panel.visible = false
	hud.visible = false
	menu_panel.visible = true


func iniciar_desde_menu() -> void:
	menu_panel.visible = false
	if principal != null:
		principal.empezar_turno_desde_menu()
	else:
		mostrar_login()


func abrir_mapas() -> void:
	var v := abrir_overlay("Mapas", 640.0, 430.0, "mapas")
	v.add_child(etiqueta("Escenarios del simulador", 16, C_ACENTO))
	var lista: Array = [
		["Conjunto residencial", "Disponible. Es el escenario de las versiones anteriores: garita con dos barreras, citófono y 40 puestos.", true],
		["Centro comercial", "No disponible. Está fuera del alcance de los documentos del proyecto (propiedad horizontal) y sus tarifas y tiquetes no están definidos; solo se haría si el equipo define esas reglas.", false],
		["Parqueadero en altura", "No disponible todavía. Propuesta: «Sótanos de Robles del Norte» (2 niveles), que sí encaja con el caso; falta que el equipo lo apruebe.", false]]
	for m in lista:
		var p := PanelContainer.new()
		v.add_child(p)
		var h := VBoxContainer.new()
		p.add_child(h)
		h.add_child(etiqueta(("✔ " if bool(m[2]) else "🔒 ") + str(m[0]), 15, C_OK if bool(m[2]) else C_SUAVE))
		var d := etiqueta(str(m[1]), 13, C_TEXTO)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 560
		h.add_child(d)


func abrir_ajustes() -> void:
	var v := abrir_overlay("Ajustes / Opciones", 700.0, 640.0, "ajustes")
	var A: Dictionary = Ajustes.valores
	v.add_child(etiqueta("Sonido", 16, C_ACENTO))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	v.add_child(g)
	var deslizador := func(nombre: String, clave: String, mn: float, mx: float, aplicar_ya: bool) -> void:
		g.add_child(etiqueta(nombre, 13))
		var s := HSlider.new()
		s.min_value = mn
		s.max_value = mx
		s.step = 0.05
		s.value = float(A[clave])
		s.custom_minimum_size.x = 300
		s.value_changed.connect(func(x: float) -> void:
			A[clave] = x
			if aplicar_ya:
				Ajustes.aplicar(self)
			Ajustes.guardar())
		g.add_child(s)
	deslizador.call("Volumen general", "vol_general", 0.0, 1.0, true)
	deslizador.call("Volumen de efectos", "vol_efectos", 0.0, 1.0, false)
	v.add_child(HSeparator.new())
	v.add_child(etiqueta("Gráficos", 16, C_ACENTO))
	v.add_child(etiqueta("Preajustes: «Equipo antiguo» baja calidad y resolución para PCs modestos.", 12, C_SUAVE))
	var pre := HBoxContainer.new()
	v.add_child(pre)
	var aplicar_pre := func(cal: int, esc3: float, vhs: bool, tenso: bool) -> void:
		A["calidad"] = cal
		A["escala3d"] = esc3
		A["vhs"] = vhs
		A["tenso"] = tenso
		A["vhs_fuerza"] = 0.6
		Ajustes.aplicar(self)
		if principal != null:
			principal.esc.aplicar_calidad(cal)
			principal.filtro.aplicar()
		Ajustes.guardar()
		abrir_ajustes()
	pre.add_child(boton("Equipo antiguo", func() -> void: aplicar_pre.call(0, 0.5, false, false)))
	pre.add_child(boton("Equilibrado", func() -> void: aplicar_pre.call(1, 1.0, false, false)))
	pre.add_child(boton("Atmosférico (VHS + tenso)", func() -> void: aplicar_pre.call(1, 0.75, true, true)))
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 12)
	v.add_child(g2)
	g2.add_child(etiqueta("Calidad", 13))
	var cal := OptionButton.new()
	for n in ["Baja", "Media", "Alta"]:
		cal.add_item(n)
	cal.select(int(A["calidad"]))
	cal.item_selected.connect(func(i: int) -> void:
		A["calidad"] = i
		if principal != null:
			principal.esc.aplicar_calidad(i)
		Ajustes.guardar())
	g2.add_child(cal)
	g2.add_child(etiqueta("Resolución 3D", 13))
	var s2 := HSlider.new()
	s2.min_value = 0.5
	s2.max_value = 1.0
	s2.step = 0.05
	s2.value = float(A["escala3d"])
	s2.custom_minimum_size.x = 300
	s2.value_changed.connect(func(x: float) -> void:
		A["escala3d"] = x
		Ajustes.aplicar(self)
		Ajustes.guardar())
	g2.add_child(s2)
	g2.add_child(etiqueta("Pantalla completa", 13))
	var fs := CheckBox.new()
	fs.button_pressed = bool(A["pantalla_completa"])
	fs.toggled.connect(func(b: bool) -> void:
		A["pantalla_completa"] = b
		Ajustes.aplicar(self)
		Ajustes.guardar())
	g2.add_child(fs)
	g2.add_child(etiqueta("Sensibilidad de cámara", 13))
	var s3 := HSlider.new()
	s3.min_value = 0.3
	s3.max_value = 2.0
	s3.step = 0.05
	s3.value = float(A["sens_camara"])
	s3.custom_minimum_size.x = 300
	s3.value_changed.connect(func(x: float) -> void:
		A["sens_camara"] = x
		Ajustes.guardar())
	g2.add_child(s3)
	g2.add_child(etiqueta("Ambiente tenso (más oscuro y con niebla)", 13))
	var te := CheckBox.new()
	te.button_pressed = bool(A["tenso"])
	te.toggled.connect(func(b: bool) -> void:
		A["tenso"] = b
		if principal != null:
			principal.esc.fijar_hora(principal.esc.hora_dia)
		Ajustes.guardar())
	g2.add_child(te)
	g2.add_child(etiqueta("Estilo cámara de seguridad (VHS)", 13))
	var vh := CheckBox.new()
	vh.button_pressed = bool(A["vhs"])
	vh.toggled.connect(func(b: bool) -> void:
		A["vhs"] = b
		if principal != null and principal.filtro != null:
			principal.filtro.aplicar()
		Ajustes.guardar())
	g2.add_child(vh)
	g2.add_child(etiqueta("Intensidad del filtro", 13))
	var s4 := HSlider.new()
	s4.min_value = 0.1
	s4.max_value = 1.0
	s4.step = 0.05
	s4.value = float(A["vhs_fuerza"])
	s4.custom_minimum_size.x = 300
	s4.value_changed.connect(func(x: float) -> void:
		A["vhs_fuerza"] = x
		if principal != null and principal.filtro != null:
			principal.filtro.aplicar()
		Ajustes.guardar())
	g2.add_child(s4)
	v.add_child(HSeparator.new())
	v.add_child(etiqueta("Controles (pulsa una tecla para cambiarla)", 16, C_ACENTO))
	var g3 := GridContainer.new()
	g3.columns = 2
	g3.add_theme_constant_override("h_separation", 12)
	v.add_child(g3)
	for a in Ajustes.ACCIONES:
		var id: String = str(a[0])
		g3.add_child(etiqueta(str(a[1]), 13))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.x = 180
		b.text = Ajustes.nombre_tecla(int(A["teclas"][id]))
		b.pressed.connect(func() -> void:
			if boton_tecla != null and is_instance_valid(boton_tecla):
				boton_tecla.text = Ajustes.nombre_tecla(int(A["teclas"][esperando_tecla]))
			esperando_tecla = id
			boton_tecla = b
			b.text = "Pulsa una tecla…")
		g3.add_child(b)
	v.add_child(boton("Restaurar valores por defecto", func() -> void:
		Ajustes.valores = Ajustes.por_defecto()
		Ajustes.aplicar(self)
		Ajustes.guardar()
		abrir_ajustes()))


func _input(e: InputEvent) -> void:
	# captura de tecla para reasignar controles
	if esperando_tecla != "" and e is InputEventKey and e.pressed and not e.echo:
		get_viewport().set_input_as_handled()
		if e.keycode != KEY_ESCAPE:
			Ajustes.valores["teclas"][esperando_tecla] = int(e.keycode)
			Ajustes.registrar_acciones()
			Ajustes.guardar()
		if boton_tecla != null and is_instance_valid(boton_tecla):
			boton_tecla.text = Ajustes.nombre_tecla(int(Ajustes.valores["teclas"][esperando_tecla]))
		esperando_tecla = ""
		boton_tecla = null


func abrir_tareas_turno() -> void:
	# Pantalla del PC al empezar el turno: resumen breve de tareas.
	var v := abrir_overlay("PC de la garita · Tareas del turno", 620.0, 470.0, "tareas", false)
	v.add_child(etiqueta("TAREAS DEL TURNO", 18, C_ACENTO))
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size = Vector2(560, 260)
	t.text = "[b]1.[/b] Revisar cada vehículo que llega: placa delantera, placa trasera y rostro del conductor.\n[b]2.[/b] Dejar pasar lo autorizado y atender lo dudoso con la [b]inspección[/b].\n[b]3.[/b] Si el conductor no es el dueño o la placa no cuadra: permitir bajo riesgo propio, negar, o negar y detener a la persona.\n[b]4.[/b] Registrar visitantes con sus datos y llamar al citófono cuando haga falta.\n[b]5.[/b] Vigilar el parqueadero con las cámaras (tecla 7: puesto en primera persona).\n\n[b]Dinero del turno:[/b] detener a un ladrón paga; dejar salir a uno o negar a alguien legítimo cuesta una multa. (Valores de juego, no reglas del proyecto.)"
	v.add_child(t)
	v.add_child(boton("Comenzar turno", comenzar_turno))


# ---------------------------------------------------------------------------------------------
# monitor de camaras (v4)
# ---------------------------------------------------------------------------------------------

func abrir_monitor() -> void:
	var v := abrir_overlay("Monitor de cámaras de seguridad", 760.0, 560.0, "monitor", false)
	var m := MonitorCamaras.new()
	m.iniciar(principal)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(m)
