extends Node

# CISPPH - Controlador del simulador: une el escenario 3D, los vehiculos, el sistema (Sistema),
# el generador de casos, el audio y la interfaz. Maneja DOS carriles ("Entrada" y "Salida"),
# cada uno con su maquina de estados:
#   libre -> llegando -> esperando (foto + reconocimiento) -> decidido -> pasando -> libre
# Alcance honesto: la placa y el rostro son simulados (no hay OCR ni reconocimiento facial real).

const VEL_LLEGADA: float = 7.0
const VEL_PARQUEO: float = 5.5
const VEL_RETROCESO: float = 6.5
const PASO_PEATON: float = 2.6
# Valores de JUEGO (no son reglas de negocio ni tarifas del proyecto: son marcadores para practicar; el equipo puede cambiarlos).
const PAGO_CASO_DUDOSO: int = 20000        # decidir bien un caso en REVISAR
const PAGO_NORMAL: int = 1000              # dejar pasar un vehiculo en regla
const MULTA_IRREGULAR_PERMITIDO: int = 50000   # dejar pasar un robo/suplantacion
const MULTA_NEGAR_LEGITIMO: int = 10000        # negar a una persona legitima

var esc: Escenario3D
var ui: Interfaz
var audio: AudioSim
var gen: GeneradorCasos
var carriles: Dictionary = {"Entrada": {}, "Salida": {}}
var estacionados: Dictionary = {}        # id_usuario -> Vehiculo3D
var en_transito: Dictionary = {}         # id_usuario -> Vehiculo3D (entrando a su puesto)
var velocidad: float = 1.0
var trafico_auto: bool = true
var camara_auto: bool = true
var temporizador_trafico: float = 6.0
var tiempo_ui: float = 0.0
var iniciado: bool = false
var filtro: FiltroVHS = null
var apagon: bool = false
var a_mano: bool = false                # trabajar como hoy: sin el sistema (sin veredicto ni citofono), decide el guardia
var fallas_conexion: bool = true      # excepcion del UML: error de conexion ocasional (la operacion no se registra)
var prob_falla: float = 0.07
var expira_min: float = 0.0           # 0 = la sesion no expira por inactividad
var ultima_actividad: float = 0.0
var metricas: Array = []              # una fila por decision del guarda o automatica
var apagon_restante: float = 0.0
var apagones_aleatorios: bool = true
var proximo_apagon: float = 150.0
var estres: float = 0.0
var mostrar_tareas: bool = true
var intro_activa: bool = false
var saltar_intro: bool = false
var aciertos: int = 0
var decisiones: int = 0


func _ready() -> void:
	Ajustes.cargar()
	Ajustes.aplicar(self)
	gen = GeneradorCasos.new()
	esc = Escenario3D.new()
	add_child(esc)
	audio = AudioSim.new()
	add_child(audio)
	filtro = FiltroVHS.new()
	add_child(filtro)
	ui = Interfaz.new()
	add_child(ui)
	ui.principal = self
	ui.refrescar_carril("Entrada")
	ui.refrescar_carril("Salida")
	Sistema.datos_cambiados.connect(sincronizar_estacionados)
	sincronizar_estacionados()
	esc.hora_dia = float(Sistema.config.get("hora_sim", 17.5))
	esc.fijar_hora(esc.hora_dia)
	esc.cambiar_camara("cine")
	ui.mostrar_menu()


func hora_int() -> int:
	return int(esc.hora_dia) % 24


# ---------------------------------------------------------------------------------------------
# vehiculos estacionados (reflejan Sistema.ocupacion)
# ---------------------------------------------------------------------------------------------

func crear_vehiculo(caso_o_usuario: Dictionary, placa_del: String, placa_tras: String, rostro: int, veh: Dictionary) -> Vehiculo3D:
	var v := Vehiculo3D.new()
	v.construir({"tipo": veh.get("tipo", "sedan"), "color": veh.get("color", "#c0392b"), "placa_delantera": placa_del,
		"placa_trasera": placa_tras, "rostro": rostro, "neon": (rostro % 7) == 0})
	v.factor_tiempo = velocidad
	esc.add_child(v)
	return v


func sincronizar_estacionados() -> void:
	# Quita autos de usuarios que ya no estan dentro y agrega los que faltan (al iniciar o reiniciar datos).
	for id in estacionados.keys():
		var sigue: bool = Sistema.esta_dentro(int(id)) and Sistema.puesto_de(int(id)) != ""
		var en_uso: bool = false
		for k in carriles.keys():
			var L: Dictionary = carriles[k]
			if not L.is_empty() and L.get("auto") == estacionados[id]:
				en_uso = true
		if not sigue and not en_uso:
			(estacionados[id] as Node).queue_free()
			estacionados.erase(id)
	for u in Sistema.usuarios_dentro():
		var d: Dictionary = u
		var id: int = int(d["id"])
		if estacionados.has(id) or en_transito.has(id) or Sistema.puesto_de(id) == "":
			continue
		var enlazado: bool = false
		for k in carriles.keys():
			var L2: Dictionary = carriles[k]
			if not L2.is_empty() and int((L2["caso"]["usuario"] as Dictionary).get("id", -1)) == id:
				enlazado = true
		if enlazado:
			continue
		var v := crear_vehiculo(d, str(d["placa"]), str(d["placa"]), int(d["rostro"]), d.get("vehiculo", Sistema.vehiculo_para(id)))
		var pose: Dictionary = esc.pose_puesto(Sistema.puesto_de(id))
		v.position = pose["p"]
		v.rotation.y = float(pose["h"])
		v.mostrar_conductor(false)
		estacionados[id] = v


# ---------------------------------------------------------------------------------------------
# solicitudes (boton, trafico automatico)
# ---------------------------------------------------------------------------------------------

func carril_libre(sentido: String) -> bool:
	return (carriles[sentido] as Dictionary).is_empty()


func solicitar(sentido: String) -> bool:
	if not carril_libre(sentido):
		ui.mensaje("El carril de %s está ocupado." % sentido.to_lower(), Color("#ffb347"))
		return false
	var caso: Dictionary = gen.generar(sentido)
	if caso.is_empty():
		ui.mensaje("No hay vehículos dentro que puedan salir.", Color("#ffb347"))
		return false
	return iniciar_caso(sentido, caso)


func iniciar_caso(sentido: String, caso: Dictionary) -> bool:
	if not carril_libre(sentido):
		return false
	var L: Dictionary = {"caso": caso, "estado": "llegando", "eval": {}, "imgs": {}, "fotos": [], "cuenta": -1.0, "citofono_visto": false, "ruta": []}
	if sentido == "Entrada":
		var v: Vehiculo3D = crear_vehiculo(caso, str(caso["placa_delantera"]), str(caso["placa_trasera"]), int(caso["rostro"]), caso["vehiculo"])
		v.encender_luces(esc.hora_dia > 18.0 or esc.hora_dia < 6.0)
		L["auto"] = v
		carriles[sentido] = L
		v.llego.connect(_en_garita.bind(sentido), CONNECT_ONE_SHOT)
		v.seguir(esc.ruta_llegada_entrada(), VEL_LLEGADA)
		audio.tocar("motor")
	else:
		var u: Dictionary = caso["usuario"]
		var id: int = int(u["id"])
		var puesto: String = Sistema.puesto_de(id)
		var v2: Vehiculo3D = estacionados.get(id)
		if v2 == null:
			sincronizar_estacionados()
			v2 = estacionados.get(id)
		if v2 == null:
			ui.mensaje("No se encontró el vehículo en el parqueadero.", Color("#ff6b6b"))
			return false
		estacionados.erase(id)
		# El caso describe el vehiculo REAL que esta estacionado (placa y aspecto), no otro.
		caso["placa_delantera"] = v2.placa_delantera
		caso["placa_trasera"] = v2.placa_delantera
		caso["vehiculo"] = {"tipo": v2.tipo, "color": "#" + v2.color_pintura.to_html(false)}
		v2.rostro = int(caso["rostro"])
		v2.mostrar_conductor(false)
		L["auto"] = v2
		L["puesto"] = puesto
		carriles[sentido] = L
		v2.encender_luces(esc.hora_dia > 18.0 or esc.hora_dia < 6.0)
		_secuencia_salida(L, v2, puesto)
	if camara_auto and sentido == "Entrada":
		esc.objetivo_camara = (L["auto"] as Node3D)
		esc.cambiar_camara("seguir")
	ui.refrescar_carril(sentido)
	return true


func crear_persona(semilla: int, rol: String = "civil") -> Persona3D:
	var p := Persona3D.new()
	p.construir(semilla, rol)
	p.factor_tiempo = velocidad
	esc.add_child(p)
	return p


# Baja al conductor del vehiculo recien estacionado y lo manda caminando al edificio (desaparece al entrar).
func bajar_conductor(v: Vehiculo3D) -> void:
	if v.conductor_nodo == null or not v.conductor_nodo.visible:
		return
	v.mostrar_conductor(false)
	var ruta: Array = esc.ruta_peaton_a_edificio(v)
	var p: Persona3D = crear_persona(v.rostro)
	p.position = ruta[0]
	p.llego.connect(func() -> void: p.queue_free(), CONNECT_ONE_SHOT)
	p.caminar(ruta, PASO_PEATON)


# Salida: la persona sale del edificio, camina hasta su vehiculo y se sube (si es un ladron, forcejea antes).
func _secuencia_salida(L: Dictionary, v: Vehiculo3D, puesto: String) -> void:
	var caso: Dictionary = L["caso"]
	var ladron: bool = str(caso["escenario"]) == "salida_conductor_distinto" and not bool(caso["legitimo"])
	var ruta: Array = esc.ruta_peaton_desde_edificio(v)
	var p: Persona3D = crear_persona(int(caso["rostro"]), "ladron" if ladron else "civil")
	L["persona"] = p
	if ladron:
		p.position = ruta[3]
		ruta = ruta.slice(4)
	else:
		p.position = ruta[0]
	if camara_auto:
		esc.objetivo_camara = p
		esc.cambiar_camara("seguir")
	p.caminar(ruta, PASO_PEATON)
	await p.llego
	if not is_instance_valid(p) or carriles["Salida"] != L:
		return
	if ladron:
		ui.subtitulo("Alguien intenta subirse al vehículo de otra persona…", 4.0)
		if camara_auto:
			esc.cambiar_camara("robo")
		p.forcejear(5.5)
		await p.termino
		if not is_instance_valid(p) or carriles["Salida"] != L:
			return
	p.queue_free()
	L.erase("persona")
	v.mostrar_conductor(true)
	audio.tocar("motor")
	if camara_auto:
		esc.objetivo_camara = v
		esc.cambiar_camara("seguir")
	v.llego.connect(_salida_paso2.bind(), CONNECT_ONE_SHOT)
	v.seguir(esc.ruta_retroceso_puesto(puesto), VEL_RETROCESO, true)


# Salida denegada a un ladron: alarma, el ladron baja del vehiculo, llega el dueno y la policia se lleva a la persona.
func _mirar(p: Node3D, hacia: Vector3) -> void:
	var d: Vector3 = hacia - p.position
	p.rotation.y = atan2(-d.z, d.x)


func _secuencia_policia(v: Vehiculo3D, caso: Dictionary = {}) -> void:
	v.mostrar_conductor(false)
	var ladron: Persona3D = crear_persona(v.rostro, "ladron")
	ladron.position = v.to_global(Vector3(0.2, 0.0, -(v.ancho_total() * 0.5 + 0.55)))
	ladron.position.y = 0.0
	var escena: Vector3 = ladron.position
	var poli: Persona3D = crear_persona(4242, "policia")
	poli.position = Vector3(-16.0, 0.0, -5.4)
	var dueno: Persona3D = null
	var u: Dictionary = caso.get("usuario", {})
	if not u.is_empty():
		dueno = crear_persona(int(u["rostro"]), "civil")
		dueno.position = Vector3(14.0, 0.0, -19.0)
	audio.tocar("sirena")
	ui.destello_policial(true)
	# seguro: las luces nunca quedan encendidas mas de 60 s
	get_tree().create_timer(60.0).timeout.connect(func() -> void: ui.destello_policial(false))
	if camara_auto:
		esc.camara_fija(Vector3(-8.5, 1.8, -8.0), escena + Vector3(-2.5, 1.0, 0.5), false)
	ui.subtitulo("Alarma: intento de robo. La policía acude a la garita.", 4.5)
	var llegada: Vector3 = escena + Vector3(-1.0, 0.0, -0.9)
	poli.caminar([Vector3(-6.0, 0.0, -5.4), llegada], 3.2)
	if dueno != null:
		dueno.caminar([Vector3(14.0, 0.0, -13.6), Vector3(10.0, 0.0, -12.0), Vector3(3.5, 0.0, -9.0), escena + Vector3(2.4, 0.0, -1.6)], 2.6)
	await poli.llego
	_mirar(poli, escena)
	ladron.parar()
	_mirar(ladron, poli.position)
	ui.subtitulo("Policía: «Alto ahí. Queda detenido por intento de robo.»", 3.5)
	if dueno != null:
		await dueno.llego
		_mirar(dueno, escena)
		ui.subtitulo("Dueño del vehículo: «¡Ese es mi vehículo! Gracias por detenerlo.»", 3.5)
	await get_tree().create_timer(2.5 / maxf(velocidad, 0.1)).timeout
	var fuga: Array = [Vector3(-8.0, 0.0, -5.7), Vector3(-26.0, 0.0, -5.7)]
	var fuga_p: Array = [Vector3(-8.0, 0.0, -5.0), Vector3(-26.0, 0.0, -5.0)]
	ladron.caminar(fuga, 1.9)
	poli.caminar(fuga_p, 1.9)
	if camara_auto:
		esc.camara_fija(Vector3(-5.0, 2.0, -2.0), Vector3(-18.0, 1.1, -5.4), false)
	ui.subtitulo("La policía se lleva a la persona detenida.", 4.0)
	await ladron.llego
	for pp in [ladron, poli]:
		if is_instance_valid(pp):
			pp.queue_free()
	ui.destello_policial(false)
	if dueno != null and is_instance_valid(dueno):
		ui.subtitulo("El dueño regresa al edificio mientras el vehículo vuelve a su puesto.", 3.5)
		dueno.caminar([Vector3(3.5, 0.0, -9.0), Vector3(10.0, 0.0, -12.0), Vector3(14.0, 0.0, -13.6), Vector3(14.0, 0.0, -19.0)], 2.6)
		await dueno.llego
		if is_instance_valid(dueno):
			dueno.queue_free()
	if camara_auto and iniciado:
		esc.cambiar_camara("seguridad")


func _salida_paso2() -> void:
	var L: Dictionary = carriles["Salida"]
	if L.is_empty():
		return
	var v: Vehiculo3D = L["auto"]
	v.llego.connect(_en_garita.bind("Salida"), CONNECT_ONE_SHOT)
	var ruta: Array = esc.ruta_hacia_salida(str(L["puesto"]))
	L["ruta"] = ruta
	v.seguir(ruta, VEL_LLEGADA)


# ---------------------------------------------------------------------------------------------
# en la garita: fotos + reconocimiento
# ---------------------------------------------------------------------------------------------

func _en_garita(sentido: String) -> void:
	var L: Dictionary = carriles[sentido]
	if L.is_empty():
		return
	L["estado"] = "esperando"
	var v: Vehiculo3D = L["auto"]
	v.detener()
	if camara_auto:
		esc.cambiar_camara("garita" if sentido == "Entrada" else "seguridad")
	audio.tocar("lectura")
	var caso: Dictionary = L["caso"]
	var imgs: Dictionary = {}
	for tipo in ["placa_delantera", "placa_trasera", "rostro"]:
		imgs[tipo] = await esc.capturar(v, tipo)
		audio.tocar("obturador")
	if carriles[sentido] != L:
		return
	L["imgs"] = imgs
	L["fotos"] = guardar_fotos(sentido, imgs)
	var ev: Dictionary = evaluar_caso(sentido, caso)
	L["eval"] = ev
	L["t_listo"] = Time.get_ticks_msec()
	audio.tocar("ok" if str(ev["resultado"]) == "autorizado" else ("error" if str(ev["resultado"]) == "denegado" else "alerta"))
	var modo: String = str(Sistema.config.get("modo", "automatico"))
	if modo == "automatico" and str(ev["resultado"]) != "revisar" and not sin_sistema():
		L["cuenta"] = float(Sistema.config.get("popup_segundos", 3))
	ui.refrescar_carril(sentido)


func evaluar_caso(sentido: String, caso: Dictionary) -> Dictionary:
	var veh: Dictionary = caso["vehiculo"] if sentido == "Entrada" else {}
	var ev: Dictionary = Sistema.evaluar_acceso(sentido, str(caso["placa_delantera"]), int(caso["rostro"]), hora_int(), veh)
	if str(caso["placa_trasera"]) != str(caso["placa_delantera"]) and str(ev["resultado"]) != "denegado":
		ev["resultado"] = "revisar"
		ev["motivo"] = "La placa trasera (%s) no coincide con la delantera (%s)." % [Sistema.formato_placa(str(caso["placa_trasera"])), Sistema.formato_placa(str(caso["placa_delantera"]))]
	return ev


# Lista de comprobaciones para la ventana de inspeccion del guardia.
# Cada fila: {t: titulo, e: "ok"|"mal"|"info", d: detalle}
func inspeccion(sentido: String) -> Dictionary:
	var L: Dictionary = carriles[sentido]
	if L.is_empty() or (L["eval"] as Dictionary).is_empty():
		return {}
	var caso: Dictionary = L["caso"]
	var ev: Dictionary = L["eval"]
	var u: Dictionary = ev["usuario"]
	var filas: Array = []
	var del: String = Sistema.formato_placa(str(caso["placa_delantera"]))
	var tras: String = Sistema.formato_placa(str(caso["placa_trasera"]))
	filas.append({"t": "Placa delantera = trasera", "e": "ok" if del == tras else "mal", "d": "Delantera %s · trasera %s" % [del, tras]})
	if u.is_empty():
		filas.append({"t": "Placa en la base de datos", "e": "mal", "d": "%s no está registrada." % del})
	else:
		filas.append({"t": "Placa en la base de datos", "e": "ok", "d": "Titular: %s (%s%s)" % [Sistema.nombre_completo(u), str(u["rol"]), (", apto " + str(u["apto"])) if str(u.get("apto", "")) != "" else ""]})
		var cat: String = Sistema.categoria_de(u)
		filas.append({"t": "Categoría (definición de trabajo)", "e": "info", "d": cat + ((" — " + str(u.get("motivo_vip", ""))) if cat == "VIP" else "") + ". Sin reglas de tarifa, prioridad ni cupo reservado (no definidas)."})
		var reg: Dictionary = Sistema.vehiculo_registrado(u, str(caso["placa_delantera"]))
		if sentido == "Entrada":
			var igual: bool = str(reg["tipo"]) == str(caso["vehiculo"]["tipo"]) and str(reg["color"]).to_lower() == str(caso["vehiculo"]["color"]).to_lower()
			filas.append({"t": "Vehículo = registrado para esa placa", "e": "ok" if igual else "mal", "d": "Se ve: %s · Registrado: %s" % [Sistema.describir_vehiculo(caso["vehiculo"]), Sistema.describir_vehiculo(reg)]})
		else:
			filas.append({"t": "Vehículo que sale", "e": "info", "d": "%s (registrado: %s)" % [Sistema.describir_vehiculo(caso["vehiculo"]), Sistema.describir_vehiculo(reg)]})
		var dist: float = float(ev["distancia"])
		filas.append({"t": "Rostro = titular de la placa", "e": "ok" if dist <= Sistema.TOLERANCIA_ROSTRO else "mal", "d": "Distancia %.2f (tolerancia %.2f)" % [dist, Sistema.TOLERANCIA_ROSTRO]})
	var quien: Dictionary = Sistema.identificar_rostro(int(caso["rostro"]))
	if quien.is_empty():
		filas.append({"t": "Rostro en la base de datos", "e": "mal", "d": "El conductor no corresponde a nadie registrado."})
	elif not u.is_empty() and int(quien["id"]) == int(u["id"]):
		filas.append({"t": "Rostro en la base de datos", "e": "ok", "d": "Es el propio titular."})
	else:
		filas.append({"t": "Rostro en la base de datos", "e": "mal" if not u.is_empty() else "info", "d": "Corresponde a %s (%s%s), no al titular de la placa." % [Sistema.nombre_completo(quien), str(quien["rol"]), (", apto " + str(quien["apto"])) if str(quien.get("apto", "")) != "" else ""]})
	if not u.is_empty():
		var id: int = int(u["id"])
		var dentro: bool = Sistema.esta_dentro(id)
		if sentido == "Entrada":
			filas.append({"t": "Estado del titular", "e": "mal" if dentro else "ok", "d": "Figura DENTRO (ya entró)." if dentro else "Figura fuera."})
		else:
			filas.append({"t": "Estado del titular", "e": "ok" if dentro else "mal", "d": ("Figura dentro, puesto %s." % Sistema.puesto_de(id)) if dentro else "No registra entrada."})
		if sentido == "Entrada":
			if str(u["rol"]) == "trabajador":
				var en: bool = Sistema.en_turno(u, hora_int())
				filas.append({"t": "Turno del trabajador", "e": "ok" if en else "mal", "d": "Turno %s · hora simulada %02d h" % [str(u.get("turno", "")), hora_int()]})
			if str(u["rol"]) == "visitante":
				var au: bool = bool(u.get("autorizacion_activa", false))
				filas.append({"t": "Autorización de la visita", "e": "ok" if au else "mal", "d": ("Vigente, autorizada por %s (%s)" % [str(u.get("autorizado_por", "?")), str(u.get("motivo", ""))]) if au else "No vigente."})
			var pl: String = Sistema.puesto_libre_para(u)
			filas.append({"t": "Cupo", "e": "ok" if pl != "" else "mal", "d": ("Puesto asignado: " + pl) if pl != "" else "No hay puesto libre para su zona."})
	var cito: Dictionary = caso["citofono"]
	if bool(L["citofono_visto"]) and not cito.is_empty():
		filas.append({"t": "Citófono", "e": "ok" if bool(cito["responde"]) else "mal", "d": str(cito["texto"])})
	elif not cito.is_empty():
		filas.append({"t": "Citófono", "e": "info", "d": "Aún no se ha llamado. Pulsa «Llamar por citófono»."})
	return {"filas": filas, "titular": u, "conductor": caso["conductor"], "vehiculos": Sistema.vehiculos_de(u) if not u.is_empty() else [], "motivo": ev["motivo"], "resultado": ev["resultado"], "caso": caso}


func guardar_fotos(sentido: String, imgs: Dictionary) -> Array:
	DirAccess.make_dir_recursive_absolute(Sistema.RUTA_FOTOS)
	var marca: String = str(Time.get_ticks_msec())
	var rutas: Array = []
	for k in imgs.keys():
		var ruta: String = "%s%s_%s_%s.png" % [Sistema.RUTA_FOTOS, sentido.to_lower(), marca, k]
		(imgs[k] as Image).save_png(ruta)
		rutas.append(ruta)
	return rutas


# ---------------------------------------------------------------------------------------------
# decisiones
# ---------------------------------------------------------------------------------------------

func puede_permitir(sentido: String) -> bool:
	var L: Dictionary = carriles[sentido]
	if L.is_empty() or str(L["estado"]) != "esperando":
		return false
	var ev: Dictionary = L["eval"]
	if ev.is_empty() or (ev["usuario"] as Dictionary).is_empty():
		return false
	if str(ev["resultado"]) == "autorizado":
		return true
	if str(ev["resultado"]) != "revisar":
		return false
	# "revisar": el guardia puede autorizar si la persona existe y no esta duplicada
	var id: int = int((ev["usuario"] as Dictionary)["id"])
	if sentido == "Entrada":
		return not Sistema.esta_dentro(id) and Sistema.puesto_libre_para(ev["usuario"]) != ""
	return Sistema.esta_dentro(id)


func permitir(sentido: String, origen: String = "Guardia", nota: String = "") -> void:
	if not puede_permitir(sentido):
		ui.mensaje("Este caso no se puede permitir (usa Denegar o registra al visitante).", Color("#ff6b6b"))
		return
	var L: Dictionary = carriles[sentido]
	if origen == "Guardia" and _falla_conexion():
		return
	var ev: Dictionary = L["eval"]
	var u: Dictionary = ev["usuario"]
	_anotar_metrica(sentido, L, "permitido", origen)
	var detalle: String = "Acceso permitido (automático)." if origen == "Automático" else "Permitido por el guardia."
	if str(ev["resultado"]) == "revisar":
		detalle = "Permitido manualmente tras revisión: " + str(ev["motivo"])
	var caso0: Dictionary = L["caso"]
	detalle += texto_conductor(caso0, u)
	if nota.strip_edges() != "":
		detalle += " Nota del guardia: " + nota.strip_edges()
	var puesto: String = str(ev["puesto"])
	if sentido == "Entrada" and puesto == "":
		puesto = Sistema.puesto_libre_para(u)
	if sentido == "Salida":
		puesto = Sistema.puesto_de(int(u["id"]))
	var caso: Dictionary = L["caso"]
	Sistema.registrar_movimiento(sentido, u, str(caso["placa_delantera"]), "permitido", detalle, puesto, L["fotos"], hora_int(), origen)
	L["estado"] = "pasando"
	L["cuenta"] = -1.0
	if origen == "Guardia" and (str(ev["resultado"]) == "revisar" or sin_sistema()):
		retroalimentar(caso, true)
	elif str(ev["resultado"]) == "autorizado":
		mover_dinero(PAGO_NORMAL)
	var v: Vehiculo3D = L["auto"]
	var carril: String = "entrada" if sentido == "Entrada" else "salida"
	esc.mover_barrera(carril, true)
	audio.tocar("barrera")
	audio.tocar("ok")
	v.ver_frenos(false)
	if sentido == "Entrada":
		L["id_usuario"] = int(u["id"])
		en_transito[int(u["id"])] = v
		v.llego.connect(_entrada_estacionado.bind(v, int(u["id"])), CONNECT_ONE_SHOT)
		v.seguir(esc.ruta_estacionar(puesto), VEL_PARQUEO)
		L["puesto"] = puesto
	else:
		v.llego.connect(_salio.bind(v), CONNECT_ONE_SHOT)
		v.seguir(esc.ruta_salir_a_la_calle(), VEL_LLEGADA)
	ui.refrescar_carril(sentido)


func denegar(sentido: String, origen: String = "Guardia", nota: String = "") -> void:
	var L: Dictionary = carriles[sentido]
	if L.is_empty() or str(L["estado"]) != "esperando":
		return
	if origen == "Guardia" and _falla_conexion():
		return
	var ev: Dictionary = L["eval"]
	var caso: Dictionary = L["caso"]
	_anotar_metrica(sentido, L, "denegado", origen)
	var detalle: String = ("Denegado (automático): " if origen == "Automático" else "Denegado por el guardia: ") + str(ev["motivo"])
	detalle += texto_conductor(caso, ev["usuario"])
	if nota.strip_edges() != "":
		detalle += " Nota del guardia: " + nota.strip_edges()
	if origen == "Guardia" and (str(ev["resultado"]) == "revisar" or sin_sistema()):
		retroalimentar(caso, false)
	Sistema.registrar_movimiento(sentido, ev["usuario"], str(caso["placa_delantera"]), "denegado", detalle, "", L["fotos"], hora_int(), origen)
	audio.tocar("error")
	L["estado"] = "pasando"
	L["denegado"] = true
	L["cuenta"] = -1.0
	var v: Vehiculo3D = L["auto"]
	v.ver_frenos(false)
	if sentido == "Entrada":
		v.llego.connect(_retirado.bind(v), CONNECT_ONE_SHOT)
		v.seguir(esc.ruta_llegada_entrada(), 8.0, true)
	else:
		# la salida denegada regresa en reversa por donde vino y vuelve a su puesto
		var ruta: Array = L["ruta"]
		var puesto: String = str(L["puesto"])
		if str(caso["escenario"]) == "salida_conductor_distinto" and not bool(caso["legitimo"]):
			_secuencia_policia(v, caso)
		v.llego.connect(_regresa_a_puesto.bind(v, puesto), CONNECT_ONE_SHOT)
		v.seguir(ruta, VEL_RETROCESO, true)
	ui.refrescar_carril(sentido)


func texto_conductor(caso: Dictionary, titular: Dictionary) -> String:
	var c: Dictionary = caso["conductor"]
	if c.is_empty() or (not titular.is_empty() and int(c.get("registrado_id", 0)) == int(titular["id"])):
		return ""
	return " Conductor que presentó documento: %s %s (%s %s)." % [str(c["nombre"]), str(c["apellido"]), str(c["tipo_id"]), str(c["cedula"])]


# Retroalimentacion didactica: la simulacion SI conoce si el caso era legitimo; el sistema real no.
func dinero() -> int:
	return int(Sistema.config.get("dinero", 0))


func mover_dinero(cantidad: int) -> void:
	Sistema.config["dinero"] = dinero() + cantidad
	Sistema.guardar()
	audio.tocar("dinero" if cantidad >= 0 else "multa")


static func formato_dinero(n: int) -> String:
	var t: String = str(absi(n))
	var r: String = ""
	while t.length() > 3:
		r = "." + t.substr(t.length() - 3) + r
		t = t.substr(0, t.length() - 3)
	return ("-$" if n < 0 else "$") + t + r


func retroalimentar(caso: Dictionary, permitio: bool) -> void:
	var legit: bool = bool(caso.get("legitimo", true))
	decisiones += 1
	var acierto: bool = permitio == legit
	if acierto:
		aciertos += 1
	var txt: String
	var delta: int = 0
	if legit and permitio:
		txt = "✔ Correcto: era un caso legítimo."
		delta = PAGO_CASO_DUDOSO
	elif legit and not permitio:
		txt = "✘ Se negó el acceso a una persona legítima (reclamo)."
		delta = -MULTA_NEGAR_LEGITIMO
	elif not legit and permitio:
		txt = "✘ Se dejó pasar un caso irregular (posible suplantación o robo): multa."
		delta = -MULTA_IRREGULAR_PERMITIDO
	else:
		txt = "✔ Correcto: era un caso irregular."
		delta = PAGO_CASO_DUDOSO
	mover_dinero(delta)
	ui.mensaje("%s  %s" % [txt, ("+" if delta >= 0 else "") + formato_dinero(delta)], Color("#4cd964") if acierto else Color("#ff5c5c"))


func _regresa_a_puesto(v: Vehiculo3D, puesto: String) -> void:
	var info: Dictionary = esc.puestos_pos[puesto]
	var xs: float = float(info["x"])
	var arco: Array = esc.arco_entrada_A(xs) if str(info["fila"]) == "A" else esc.arco_entrada_B(xs)
	v.llego.connect(_vuelve_estacionado.bind(v), CONNECT_ONE_SHOT)
	v.seguir(arco, VEL_PARQUEO)


func _vuelve_estacionado(v: Vehiculo3D) -> void:
	var L: Dictionary = carriles["Salida"]
	if not L.is_empty() and L["auto"] == v:
		var id: int = int((L["caso"]["usuario"] as Dictionary)["id"])
		estacionados[id] = v
		bajar_conductor(v)
		carriles["Salida"] = {}
		ui.refrescar_carril("Salida")


func _entrada_estacionado(v: Vehiculo3D, id: int) -> void:
	en_transito.erase(id)
	estacionados[id] = v
	bajar_conductor(v)
	var L: Dictionary = carriles["Entrada"]
	if not L.is_empty() and L["auto"] == v:
		carriles["Entrada"] = {}
		ui.refrescar_carril("Entrada")


func _salio(v: Vehiculo3D) -> void:
	v.queue_free()
	var L: Dictionary = carriles["Salida"]
	if not L.is_empty() and L["auto"] == v:
		carriles["Salida"] = {}
		ui.refrescar_carril("Salida")


func _retirado(v: Vehiculo3D) -> void:
	v.queue_free()
	var L: Dictionary = carriles["Entrada"]
	if not L.is_empty() and L["auto"] == v:
		carriles["Entrada"] = {}
		ui.refrescar_carril("Entrada")


# True cuando el guardia no tiene el sistema: por un apagon o porque eligio trabajar a mano.
func sin_sistema() -> bool:
	return apagon or a_mano


func citofono(sentido: String) -> void:
	var L: Dictionary = carriles[sentido]
	if L.is_empty() or str(L["estado"]) != "esperando":
		return
	if apagon:
		ui.mensaje("Sin energía: el citófono no funciona. Usa «Enviar a preguntar».", Color("#ffb347"))
		return
	if a_mano:
		ui.mensaje("Trabajando a mano: no hay citófono del sistema. Usa «Enviar a preguntar».", Color("#ffb347"))
		return
	L["citofono_visto"] = true
	L["cuenta"] = -1.0
	audio.tocar("lectura")
	ui.refrescar_carril(sentido)


# Apagon: otro guarda va a preguntar en persona (10 s reales de espera).
func preguntar(sentido: String) -> void:
	var L: Dictionary = carriles[sentido]
	if not sin_sistema() or L.is_empty() or str(L["estado"]) != "esperando" or L.has("pregunta"):
		return
	L["pregunta"] = 10.0
	L["pregunta_resp"] = ""
	L["cuenta"] = -1.0
	audio.tocar("lectura")
	ui.refrescar_carril(sentido)


func _respuesta_pregunta(L: Dictionary) -> String:
	var cito: Dictionary = (L["caso"] as Dictionary)["citofono"]
	if cito.is_empty():
		return "El otro guarda volvió: no había a quién consultar en este caso."
	return "El otro guarda volvió. " + str(cito["texto"])


func _apagon_tick(dt: float, delta: float) -> void:
	# preguntas en curso
	for sentido in ["Entrada", "Salida"]:
		var L: Dictionary = carriles[sentido]
		if L.is_empty() or not L.has("pregunta") or float(L["pregunta"]) <= 0.0:
			continue
		var antes: int = int(ceil(float(L["pregunta"])))
		L["pregunta"] = float(L["pregunta"]) - delta
		if float(L["pregunta"]) <= 0.0:
			L["pregunta"] = -1.0
			L["pregunta_resp"] = _respuesta_pregunta(L)
			L["citofono_visto"] = true
			audio.tocar("ok")
			ui.refrescar_carril(sentido)
		elif int(ceil(float(L["pregunta"]))) != antes:
			ui.refrescar_carril(sentido)
	# duracion del apagon
	if apagon:
		apagon_restante -= dt
		if apagon_restante <= 0.0:
			restablecer_luz()


func provocar_apagon() -> void:
	if apagon or not iniciado or intro_activa:
		return
	apagon = true
	apagon_restante = 75.0
	esc.poner_apagon(true)
	audio.tocar("error")
	var cam_antes: String = esc.modo_camara
	for sentido in ["Entrada", "Salida"]:
		var L: Dictionary = carriles[sentido]
		if not L.is_empty():
			L["cuenta"] = -1.0
	intro_activa = true   # congela atajos durante la escena
	saltar_intro = false
	esc.cambiar_camara("seguridad")
	ui.subtitulo("¡Se fue la luz! Las pantallas se apagan.", 3.0)
	await _pausa_intro(2.8)
	ui.subtitulo("El sistema automático dejó de funcionar. Sin citófono ni cámaras: decide con lo que ves.", 4.0)
	await _pausa_intro(3.5)
	intro_activa = false
	saltar_intro = false
	if camara_auto:
		esc.cambiar_camara(cam_antes if cam_antes != "garita" else "seguridad")
	for sentido in ["Entrada", "Salida"]:
		ui.refrescar_carril(sentido)
	ui.actualizar_barra()


func restablecer_luz() -> void:
	if not apagon:
		return
	apagon = false
	esc.poner_apagon(false)
	ui.subtitulo("Volvió la luz. El sistema se reinicia.", 3.5)
	audio.tocar("ok")
	proximo_apagon = randf_range(240.0, 400.0)
	reevaluar_todos()
	var modo: String = str(Sistema.config.get("modo", "automatico"))
	for sentido in ["Entrada", "Salida"]:
		var L: Dictionary = carriles[sentido]
		if not L.is_empty() and str(L["estado"]) == "esperando" and not (L["eval"] as Dictionary).is_empty():
			if modo == "automatico" and str((L["eval"] as Dictionary)["resultado"]) != "revisar":
				L["cuenta"] = float(Sistema.config.get("popup_segundos", 3))
		ui.refrescar_carril(sentido)
	ui.actualizar_barra()


# Registro de un visitante desde la garita (vehiculo desconocido cuyo residente lo confirmo por citofono).
func registrar_visitante(sentido: String, datos: Dictionary) -> Dictionary:
	var L: Dictionary = carriles[sentido]
	if L.is_empty() or sentido != "Entrada" or str(L["estado"]) != "esperando":
		return {"ok": false, "error": "No hay un vehículo esperando en la entrada."}
	var caso: Dictionary = L["caso"]
	datos["rol"] = "visitante"
	datos["placa"] = str(caso["placa_delantera"])
	datos["rostro"] = int(caso["rostro"])
	datos["vehiculo"] = caso["vehiculo"]
	datos["autorizacion_activa"] = true
	var res: Dictionary = Sistema.registrar_usuario(datos)
	if not bool(res["ok"]):
		return res
	caso["usuario"] = res["usuario"]
	caso["conductor"]["registrado_id"] = int(res["usuario"]["id"])
	var ev: Dictionary = evaluar_caso(sentido, caso)
	L["eval"] = ev
	ui.refrescar_carril(sentido)
	return res


func reevaluar_todos() -> void:
	for sentido in ["Entrada", "Salida"]:
		var L: Dictionary = carriles[sentido]
		if not L.is_empty() and str(L["estado"]) == "esperando" and not (L["eval"] as Dictionary).is_empty():
			L["eval"] = evaluar_caso(sentido, L["caso"])
			ui.refrescar_carril(sentido)


# Datos que el conductor presenta en la garita (para precargar formularios y no tener que inventarlos).
func datos_garita() -> Dictionary:
	var L: Dictionary = carriles["Entrada"]
	if L.is_empty():
		return {}
	var caso: Dictionary = L["caso"]
	var c: Dictionary = (caso["conductor"] as Dictionary).duplicate()
	c["placa"] = Sistema.formato_placa(str(caso["placa_delantera"]))
	var cito: Dictionary = caso["citofono"]
	c["autorizado_por"] = str(cito.get("residente", "")) if str(cito.get("residente", "")) != "Administración" else ""
	if str(c.get("apto", "")) == "" and not cito.is_empty():
		c["apto"] = str(cito.get("apto", ""))
	return c


# ---------------------------------------------------------------------------------------------
# bucle
# ---------------------------------------------------------------------------------------------

func fijar_velocidad(f: float) -> void:
	velocidad = f
	for id in estacionados.keys():
		(estacionados[id] as Vehiculo3D).factor_tiempo = f
	for k in carriles.keys():
		var L: Dictionary = carriles[k]
		if not L.is_empty():
			(L["auto"] as Vehiculo3D).factor_tiempo = f


func _process(delta: float) -> void:
	if not iniciado:
		return
	var dt: float = delta * velocidad
	esc.hora_dia = fposmod(esc.hora_dia + dt / 25.0, 24.0)   # 1 hora simulada = 25 s reales
	if filtro != null:
		filtro.hora_texto = "%02d:%02d" % [int(esc.hora_dia), int((esc.hora_dia - floor(esc.hora_dia)) * 60.0)]
	Sistema.config["hora_sim"] = esc.hora_dia
	tiempo_ui += delta
	if expira_min > 0.0 and Time.get_ticks_msec() / 1000.0 - ultima_actividad > expira_min * 60.0:
		iniciado = false
		ui.expirar_sesion()
		return
	_apagon_tick(dt, delta)
	# estres: sube con autos esperando durante el apagon y baja con calma
	var esperando: int = 0
	for k2 in carriles.keys():
		if not (carriles[k2] as Dictionary).is_empty() and str((carriles[k2] as Dictionary)["estado"]) == "esperando":
			esperando += 1
	if sin_sistema():
		estres = minf(100.0, estres + (0.4 + 1.2 * esperando) * dt)
	else:
		estres = maxf(0.0, estres - 3.0 * dt)
	ui.fijar_estres(estres)
	if apagones_aleatorios and not apagon:
		proximo_apagon -= dt
		if proximo_apagon <= 0.0:
			provocar_apagon()
	if tiempo_ui > 0.5:
		tiempo_ui = 0.0
		esc.fijar_hora(esc.hora_dia)
		ui.actualizar_barra()
	# cuenta atras del modo automatico
	for sentido in ["Entrada", "Salida"]:
		var L: Dictionary = carriles[sentido]
		if L.is_empty():
			continue
		if float(L["cuenta"]) >= 0.0 and str(L["estado"]) == "esperando" and not sin_sistema():
			L["cuenta"] = float(L["cuenta"]) - dt
			if float(L["cuenta"]) <= 0.0:
				L["cuenta"] = -1.0
				if str(L["eval"]["resultado"]) == "autorizado":
					permitir(sentido, "Automático")
				else:
					denegar(sentido, "Automático")
			else:
				ui.refrescar_carril(sentido)
		# barreras: se cierran cuando el vehiculo ya paso
		if str(L["estado"]) == "pasando" and is_instance_valid(L["auto"]):
			var x: float = (L["auto"] as Node3D).position.x
			if sentido == "Entrada" and x > 7.0 and esc.barrera_abierta("entrada"):
				esc.mover_barrera("entrada", false)
				audio.tocar("barrera")
			if sentido == "Salida" and x < -7.0 and esc.barrera_abierta("salida"):
				esc.mover_barrera("salida", false)
				audio.tocar("barrera")
			var liberar: bool = false
			if sentido == "Entrada":
				liberar = (x > 12.0 and not bool(L.get("denegado", false))) or (x < -25.0 and bool(L.get("denegado", false)))
			elif not bool(L.get("denegado", false)):
				liberar = x < -15.0
			if liberar:
				carriles[sentido] = {}
				ui.refrescar_carril(sentido)
	# trafico automatico
	if trafico_auto:
		temporizador_trafico -= dt
		if temporizador_trafico <= 0.0:
			temporizador_trafico = randf_range(10.0, 18.0)
			var sentido2: String = "Entrada" if randf() < 0.6 or Sistema.usuarios_dentro().is_empty() else "Salida"
			if carril_libre(sentido2):
				solicitar(sentido2)


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey or evento is InputEventMouseButton:
		ultima_actividad = Time.get_ticks_msec() / 1000.0


func _unhandled_key_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if intro_activa:
		if evento.is_action("cispph_saltar"):
			saltar_intro = true
		return
	if not iniciado:
		return
	if evento.is_action("cispph_cam_garita"): esc.cambiar_camara("garita")
	elif evento.is_action("cispph_cam_seguridad"): esc.cambiar_camara("seguridad")
	elif evento.is_action("cispph_cam_aerea"): esc.cambiar_camara("alta")
	elif evento.is_action("cispph_cam_libre"): esc.cambiar_camara("libre")
	elif evento.is_action("cispph_cam_puesto"): esc.cambiar_camara("puesto")
	elif evento.is_action("cispph_cam_seguir"):
		var L: Dictionary = carriles["Entrada"] if not (carriles["Entrada"] as Dictionary).is_empty() else carriles["Salida"]
		if not L.is_empty():
			esc.objetivo_camara = L["auto"]
			esc.cambiar_camara("seguir")
	elif evento.is_action("cispph_cam_cine"): esc.cambiar_camara("cine")
	elif evento.is_action("cispph_entrada"): solicitar("Entrada")
	elif evento.is_action("cispph_salida"): solicitar("Salida")
	elif evento.is_action("cispph_permitir"): permitir("Entrada" if puede_permitir("Entrada") else "Salida")
	elif evento.is_action("cispph_denegar"): denegar("Entrada" if str((carriles["Entrada"] as Dictionary).get("estado", "")) == "esperando" else "Salida")


# ---------------------------------------------------------------------------------------------
# menu e introduccion (v3)
# ---------------------------------------------------------------------------------------------

# Excepcion de conexion (UML / RNF-005): avisa, no registra la operacion como exitosa y permite reintentar.
func _falla_conexion() -> bool:
	if not fallas_conexion or sin_sistema() or randf() > prob_falla:
		return false
	ui.mensaje("Error de conexión: la operación NO se registró. Puedes reintentar.", Color("#ff5c5c"))
	audio.tocar("error")
	metricas.append({"fecha": Time.get_datetime_string_from_system(), "sentido": "-", "categoria": "-", "caso": "falla de conexión simulada", "decision": "no registrada", "origen": "Guardia", "segundos": 0.0, "inspeccion": false, "acierto": "", "a_mano": a_mano})
	return true


func _anotar_metrica(sentido: String, L: Dictionary, decision: String, origen: String) -> void:
	var t0: int = int(L.get("t_listo", Time.get_ticks_msec()))
	var caso: Dictionary = L["caso"]
	var u: Dictionary = (L["eval"] as Dictionary).get("usuario", {})
	var acierto: String = ""
	var dudoso: bool = str((L["eval"] as Dictionary).get("resultado", "")) == "revisar" or sin_sistema()
	if origen == "Guardia" and dudoso:
		acierto = "sí" if (decision == "permitido") == bool(caso.get("legitimo", true)) else "no"
	metricas.append({"fecha": Time.get_datetime_string_from_system(), "sentido": sentido, "categoria": Sistema.categoria_de(u),
		"caso": str(caso.get("escenario", "")), "decision": decision, "origen": origen,
		"segundos": snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.1), "inspeccion": bool(L.get("uso_inspeccion", false)), "acierto": acierto, "a_mano": sin_sistema()})


func limpiar_para_menu() -> void:
	if apagon:
		apagon = false
		esc.poner_apagon(false)
	estres = 0.0
	# Al volver al menu no se borran los datos; solo se detiene el turno y se vacian los carriles.
	for k in carriles.keys():
		var L: Dictionary = carriles[k]
		if not L.is_empty() and is_instance_valid(L.get("auto")):
			(L["auto"] as Node).queue_free()
		carriles[k] = {}
		ui.refrescar_carril(str(k))
	ui.destello_policial(false)


func _pausa_intro(seg: float) -> void:
	var t: float = 0.0
	while t < seg and not saltar_intro:
		await get_tree().process_frame
		t += get_process_delta_time()


func empezar_turno_desde_menu() -> void:
	await intro_cinematica()
	ui.mostrar_login()


# Cinematica corta: el guarda llega en moto o carro, hace el cambio de turno y se sienta en el puesto.
func intro_cinematica() -> void:
	intro_activa = true
	saltar_intro = false
	ui.subtitulo("[Esc] para saltar la introducción", 3.0)
	esc.guardia.visible = false
	var en_moto: bool = randf() < 0.5
	var vh := Vehiculo3D.new()
	vh.construir({"tipo": "moto" if en_moto else "hatchback", "color": "#27ae60", "placa_delantera": "TRN-001", "placa_trasera": "TRN-001", "rostro": 3, "neon": false})
	esc.add_child(vh)
	vh.mostrar_conductor(true)
	var ruta: Array = []
	for x in [-70.0, -50.0, -34.0, -22.0, -14.0]:
		ruta.append(esc.punto(float(x), -Escenario3D.Z_ENTRADA, 1.0, 0.0))
	var llego: Array = [false]
	vh.llego.connect(func() -> void: llego[0] = true, CONNECT_ONE_SHOT)
	vh.seguir(ruta, 9.0)
	esc.objetivo_camara = vh
	esc.cambiar_camara("seguir")
	ui.subtitulo("Tarde del conjunto. Llegas para el turno de la tarde " + ("en tu moto." if en_moto else "en tu carro."), 4.5)
	var limite: float = 0.0
	while not llego[0] and not saltar_intro and limite < 14.0:
		await get_tree().process_frame
		limite += get_process_delta_time()
	var pos_ini: Vector3 = vh.position
	var nuevo: Persona3D = crear_persona(11, "guardia")
	var saliente: Persona3D = crear_persona(7, "guardia_saliente")
	var cita := Vector3(-2.4, 0.0, 4.3)
	saliente.position = cita + Vector3(1.4, 0.0, 0.0)
	saliente.rotation.y = PI
	nuevo.position = pos_ini + Vector3(0.0, 0.0, 1.4)
	vh.mostrar_conductor(false)
	if not saltar_intro:
		esc.camara_fija(Vector3(-9.0, 1.6, 2.4), Vector3(-1.4, 1.2, cita.z), false)
		nuevo.caminar([Vector3(-10.0, 0.0, cita.z), cita + Vector3(-1.1, 0.0, 0.0)], 2.2)
		await _pausa_intro(4.2)
		nuevo.parar()
		ui.subtitulo("Guarda saliente: «Buenas. Todo tranquilo. Dos visitantes registrados y una barrera algo lenta.»", 4.0)
		await _pausa_intro(4.2)
		ui.subtitulo("Guarda saliente: «Revisa placas y rostros con calma. Si algo no cuadra, inspecciona antes de abrir.»", 4.0)
		await _pausa_intro(4.2)
		ui.subtitulo("Tú: «Recibido. Yo me encargo del turno.»", 3.0)
		saliente.caminar([Vector3(8.0, 0.0, 6.2), Vector3(8.0, 0.0, 12.0)], 1.9)
		await _pausa_intro(3.2)
	# se retira el carro/moto de la entrada y la persona nueva "entra" a la garita
	vh.queue_free()
	nuevo.queue_free()
	saliente.queue_free()
	esc.guardia.visible = true
	esc.cambiar_camara("puesto")
	esc.fp_yaw = 0.0
	esc.fp_pitch = 0.0
	if not saltar_intro:
		ui.subtitulo("Te sientas frente al PC de la garita. Inicia sesión para ver tus tareas.", 4.0)
		await _pausa_intro(2.0)
	intro_activa = false
	saltar_intro = false
