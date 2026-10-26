extends Node

# Prueba de punta a punta del simulador (requiere render: usar xvfb-run). Verifica la logica y el
# flujo de los vehiculos, no la apariencia. Salida: lineas OK/FALLO y un codigo de salida.
var fallos: int = 0
var dir_cap: String = "/tmp/claude-0/-home-claude/b0655028-f712-5b83-9477-06ad29451f53/scratchpad/"
var P: Node
var raiz_esc: Node


func chk(cond: bool, nombre: String) -> void:
	if cond:
		print("OK    ", nombre)
	else:
		print("FALLO ", nombre)
		fallos += 1


func esperar(cond: Callable, maximo: float = 90.0) -> bool:
	var t: float = 0.0
	while t < maximo:
		if cond.call():
			return true
		await get_tree().process_frame
		t += 1.0 / 30.0
	return false


# Espera a que el carril quede libre; si el caso queda en REVISAR, actua como guardia (permite si puede, si no deniega).
func resolver(sen: String) -> bool:
	var t: int = 0
	while t < 9000:
		var L: Dictionary = P.carriles[sen]
		if L.is_empty():
			return true
		if str(L["estado"]) == "esperando" and not (L["eval"] as Dictionary).is_empty() and float(L["cuenta"]) < 0.0 and str(L["eval"]["resultado"]) == "revisar":
			if P.puede_permitir(sen) and t % 2 == 0:
				P.permitir(sen)
			else:
				P.denegar(sen)
		await get_tree().process_frame
		t += 1
	return false


func _ready() -> void:
	call_deferred("correr")


func correr() -> void:
	var S: Node = get_tree().root.get_node("Sistema")
	S.persistir = false
	S.cargar_datos_iniciales()
	var escena: PackedScene = load("res://scenes/principal.tscn")
	P = escena.instantiate()
	get_tree().root.add_child(P)
	await get_tree().process_frame
	await get_tree().process_frame
	P.ui.principal = P
	P.iniciado = true
	P.ui.login_panel.visible = false
	P.ui.hud.visible = true
	P.trafico_auto = false
	P.apagones_aleatorios = false
	P.fallas_conexion = false
	P.ui.menu_panel.visible = false
	P.fijar_velocidad(6.0)
	S.config["popup_segundos"] = 1
	S.config["modo"] = "automatico"
	chk(P.estacionados.size() == 3, "arranque: 3 vehiculos estacionados (usuarios 2,4,5 dentro)")
	var movs0: int = S.movimientos.size()

	# a) residente normal, modo automatico
	var u1: Dictionary = S.usuario_por_id(1)
	var c: Dictionary = P.gen.caso_base("Entrada", "residente_normal", "prueba", u1)
	chk(P.iniciar_caso("Entrada", c), "a) inicia caso de entrada")
	chk(await esperar(func() -> bool: return P.carriles["Entrada"].get("estado", "") == "esperando" and not (P.carriles["Entrada"]["eval"] as Dictionary).is_empty()), "a) llega a la garita y evalua")
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir_cap + "sim_garita.png")
	chk(str(P.carriles["Entrada"]["eval"]["resultado"]) == "autorizado", "a) resultado autorizado")
	chk(((P.carriles["Entrada"]["imgs"] as Dictionary).size()) == 3 and (P.carriles["Entrada"]["fotos"] as Array).size() == 3, "a) 3 fotos capturadas y guardadas")
	chk(await esperar(func() -> bool: return S.esta_dentro(1)), "a) modo automatico: permite solo")
	chk(S.puesto_de(1) == "R-01", "a) asigna R-01")
	chk(await esperar(func() -> bool: return P.estacionados.has(1)), "a) el auto llega a su puesto")
	chk(await esperar(func() -> bool: return P.carril_libre("Entrada")), "a) carril de entrada liberado")
	var v1: Node3D = P.estacionados[1]
	var pose: Dictionary = P.esc.pose_puesto("R-01")
	chk(v1.position.distance_to(pose["p"]) < 0.6, "a) auto estacionado en la posicion del puesto (dist %.2f)" % v1.position.distance_to(pose["p"]))
	chk(await esperar(func() -> bool: return not P.esc.barrera_abierta("entrada")), "a) la barrera se cierra tras pasar")

	# b) desconocido: revisar -> citofono -> denegar
	var cd: Dictionary = P.gen.caso_base("Entrada", "desconocido", "prueba", {})
	cd["citofono"] = {"apto": "A-101", "residente": "", "responde": false, "texto": "No"}
	P.iniciar_caso("Entrada", cd)
	await esperar(func() -> bool: return not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty())
	chk(str(P.carriles["Entrada"]["eval"]["resultado"]) == "revisar", "b) desconocido -> revisar")
	chk(not P.puede_permitir("Entrada"), "b) no se puede permitir un desconocido")
	P.citofono("Entrada")
	P.denegar("Entrada")
	chk(S.movimientos[S.movimientos.size() - 1]["estado"] == "Denegado", "b) denegado queda en historial")
	chk(await esperar(func() -> bool: return P.carril_libre("Entrada")), "b) el auto se retira y libera el carril")

	# c) registrar visitante desde la garita y permitir
	var cv: Dictionary = P.gen.caso_base("Entrada", "desconocido", "prueba", {})
	cv["citofono"] = {"apto": "B-205", "residente": "", "responde": true, "texto": "Si"}
	P.iniciar_caso("Entrada", cv)
	await esperar(func() -> bool: return not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty())
	var nu: int = S.usuarios.size()
	var res: Dictionary = P.registrar_visitante("Entrada", {"nombre": "Test", "apellido": "Visita", "tipo_id": S.TIPOS_ID[0], "cedula": "99887766", "apto": "B-205", "autorizado_por": "María González", "motivo": "prueba"})
	chk(bool(res["ok"]) and S.usuarios.size() == nu + 1, "c) registra visitante")
	chk(str(P.carriles["Entrada"]["eval"]["resultado"]) == "autorizado", "c) tras registrar queda autorizado (%s)" % str(P.carriles["Entrada"]["eval"]["motivo"]))
	P.permitir("Entrada")
	var idv: int = int(res["usuario"]["id"])
	chk(S.puesto_de(idv).begins_with("V-"), "c) visitante recibe puesto V-")
	chk(await esperar(func() -> bool: return P.estacionados.has(idv)), "c) visitante estaciona")
	chk(await esperar(func() -> bool: return P.carril_libre("Entrada")), "c) carril libre")

	# d) suplantacion en entrada: revisar y denegar manual
	var u3: Dictionary = S.usuario_por_id(3)
	var cs: Dictionary = P.gen.caso_base("Entrada", "suplantacion", "prueba", u3)
	cs["rostro"] = int(u3["rostro"]) + 7919
	P.iniciar_caso("Entrada", cs)
	await esperar(func() -> bool: return not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty())
	chk(str(P.carriles["Entrada"]["eval"]["resultado"]) == "revisar", "d) rostro distinto -> revisar")
	P.denegar("Entrada")
	await esperar(func() -> bool: return P.carril_libre("Entrada"))
	chk(not S.esta_dentro(3), "d) el suplantador no entra")

	# e) salida normal usuario 2 (modo manual)
	S.config["modo"] = "manual"
	var u2: Dictionary = S.usuario_por_id(2)
	P.iniciar_caso("Salida", P.gen.caso_base("Salida", "salida_normal", "prueba", u2))
	chk(await esperar(func() -> bool: return P.carriles["Salida"].get("estado", "") == "esperando" and not (P.carriles["Salida"]["eval"] as Dictionary).is_empty()), "e) vehiculo sale del puesto y llega a la garita de salida")
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir_cap + "sim_salida.png")
	await get_tree().create_timer(1.5).timeout
	chk(P.carriles["Salida"]["estado"] == "esperando", "e) modo manual: espera al guardia")
	chk(str(P.carriles["Salida"]["eval"]["resultado"]) == "autorizado", "e) salida autorizada")
	P.permitir("Salida")
	chk(not S.esta_dentro(2) and S.puesto_de(2) == "", "e) salida libera el puesto")
	chk(await esperar(func() -> bool: return P.carril_libre("Salida")), "e) carril de salida libre")

	# f) salida con otra persona -> denegar -> el auto vuelve a su puesto
	var u4: Dictionary = S.usuario_por_id(4)
	var cf: Dictionary = P.gen.caso_base("Salida", "salida_suplantacion", "prueba", u4)
	cf["rostro"] = int(u4["rostro"]) + 4421
	P.iniciar_caso("Salida", cf)
	await esperar(func() -> bool: return not (P.carriles["Salida"].get("eval", {}) as Dictionary).is_empty())
	chk(str(P.carriles["Salida"]["eval"]["resultado"]) == "revisar", "f) salida con otro conductor -> revisar")
	P.denegar("Salida")
	chk(await esperar(func() -> bool: return P.carril_libre("Salida") and P.estacionados.has(4)), "f) el auto regresa a su puesto")
	chk(S.esta_dentro(4), "f) sigue dentro")
	var pv: Node3D = P.estacionados[4]
	var pp: Dictionary = P.esc.pose_puesto(S.puesto_de(4))
	chk(pv.position.distance_to(pp["p"]) < 0.6, "f) auto de vuelta en el puesto (dist %.2f)" % pv.position.distance_to(pp["p"]))

	# g) placa trasera distinta
	var u6: Dictionary = S.usuario_por_id(6)
	var cg: Dictionary = P.gen.caso_base("Entrada", "placa_trasera_distinta", "prueba", u6)
	cg["placa_trasera"] = "ZZZ-000"
	P.iniciar_caso("Entrada", cg)
	await esperar(func() -> bool: return not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty())
	chk(str(P.carriles["Entrada"]["eval"]["resultado"]) == "revisar", "g) placa trasera distinta -> revisar")
	P.permitir("Entrada")
	chk(await esperar(func() -> bool: return S.esta_dentro(6)), "g) el guardia puede permitir tras revisar")
	await esperar(func() -> bool: return P.carril_libre("Entrada"))

	# j) residente con varios coches y placa clonada con inspeccion del guardia
	S.config["modo"] = "automatico"
	var u7: Dictionary = S.usuario_por_id(7)
	S.agregar_vehiculo(7, "FEL-909", "suv", "#27ae60")
	var cj: Dictionary = P.gen.caso_base("Entrada", "residente_normal", "prueba", u7)
	cj["placa_delantera"] = "FEL-909"
	cj["placa_trasera"] = "FEL-909"
	cj["vehiculo"] = {"tipo": "suv", "color": "#27ae60"}
	P.iniciar_caso("Entrada", cj)
	chk(await esperar(func() -> bool: return S.esta_dentro(7), 200.0), "j) segundo coche del residente entra solo en automatico")
	await resolver("Entrada")
	var u8: Dictionary = S.usuario_por_id(8)
	var ck: Dictionary = P.gen.caso_base("Entrada", "vehiculo_distinto", "prueba", u8)
	ck["vehiculo"] = {"tipo": "moto", "color": "#8e44ad"}
	ck["rostro"] = 777001
	ck["legitimo"] = false
	P.iniciar_caso("Entrada", ck)
	await esperar(func() -> bool: return not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty())
	await get_tree().process_frame
	await get_tree().process_frame
	chk(str(P.carriles["Entrada"]["eval"]["resultado"]) == "revisar", "j) placa con vehiculo distinto -> revisar (no se decide solo en automatico)")
	await get_tree().create_timer(1.5).timeout
	chk(P.carriles["Entrada"]["estado"] == "esperando", "j) en automatico el caso en REVISAR espera al guardia")
	chk(P.ui.ventanas.has("insp_Entrada"), "j) se abre la ventana de inspeccion")
	var info: Dictionary = P.inspeccion("Entrada")
	var malas: int = 0
	for fi in info["filas"]:
		if str(fi["e"]) == "mal":
			malas += 1
	chk(malas >= 2, "j) la inspeccion marca %d comprobaciones en rojo (vehiculo y rostro)" % malas)
	chk(not (info["vehiculos"] as Array).is_empty(), "j) muestra los vehiculos registrados del titular")
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir_cap + "sim_inspeccion.png")
	var acs: int = P.aciertos
	P.denegar("Entrada", "Guardia", "placa clonada")
	chk(P.aciertos == acs + 1 and P.decisiones >= 1, "j) retroalimentacion: denegar un caso irregular cuenta como acierto")
	chk(str(S.movimientos[S.movimientos.size() - 1]["detalle"]).contains("Nota del guardia: placa clonada"), "j) la nota del guardia queda en el historial")
	await resolver("Entrada")
	chk(not P.ui.ventanas.has("insp_Entrada"), "j) la ventana de inspeccion se cierra al decidir")
	# k) datos del conductor para registrar sin inventar
	var cu: Dictionary = P.gen.caso_base("Entrada", "desconocido", "prueba", {})
	cu["citofono"] = {"apto": "A-101", "residente": "Carlos Rodríguez", "responde": true, "texto": "Sí"}
	P.iniciar_caso("Entrada", cu)
	await esperar(func() -> bool: return not (P.carriles["Entrada"].get("eval", {}) as Dictionary).is_empty())
	var dg: Dictionary = P.datos_garita()
	chk(str(dg["nombre"]) != "" and str(dg["cedula"]).length() >= 8 and str(dg["placa"]) != "", "k) datos_garita trae nombre, documento y placa del conductor")
	chk(str(dg["autorizado_por"]) == "Carlos Rodríguez", "k) sugiere el residente que confirmo por citofono")
	P.citofono("Entrada")
	P.ui.abrir_registro_visitante()
	await get_tree().process_frame
	chk(P.ui.ventanas.has("regvis"), "k) la ventana de registro (flotante) se abre con datos precargados")
	P.denegar("Entrada")
	await resolver("Entrada")

	# l) robo en la salida: forcejeo con camara de robo, retener -> alarma y policia, el vehiculo vuelve vacio a su puesto
	S.config["modo"] = "automatico"
	var u6b: Dictionary = S.usuario_por_id(6)
	chk(S.esta_dentro(6) and P.estacionados.has(6), "l) el usuario 6 esta dentro con su vehiculo")
	var v6: Vehiculo3D = P.estacionados[6]
	chk(not v6.conductor_nodo.visible, "l) los conductores no se quedan sentados en los vehiculos estacionados")
	var cl: Dictionary = P.gen.caso_base("Salida", "salida_conductor_distinto", "prueba", u6b)
	cl["legitimo"] = false
	cl["rostro"] = 888001
	cl["conductor"] = P.gen.persona_aleatoria()
	P.iniciar_caso("Salida", cl)
	chk(await esperar(func() -> bool: return P.esc.modo_camara == "robo", 90.0), "l) camara de robo mientras forcejea")
	chk(await esperar(func() -> bool: return not (P.carriles["Salida"].get("eval", {}) as Dictionary).is_empty(), 90.0), "l) el ladron llega a la garita")
	chk(str(P.carriles["Salida"]["caso"]["placa_delantera"]) == v6.placa_delantera and str(P.carriles["Salida"]["caso"]["vehiculo"]["tipo"]) == v6.tipo, "l) el caso describe el vehiculo REAL (placa y tipo coinciden)")
	chk(str(P.carriles["Salida"]["eval"]["resultado"]) == "revisar", "l) conductor distinto -> revisar")
	var din0: int = P.dinero()
	P.denegar("Salida", "Guardia", "intento de robo")
	chk(P.dinero() == din0 + P.PAGO_CASO_DUDOSO, "l) retener a un ladron paga %d" % P.PAGO_CASO_DUDOSO)
	await get_tree().process_frame
	chk(P.ui.destello.visible, "l) alarma policial visible")
	P.ui.menu_panel.visible = false
	P.ui.cerrar_overlay()
	for i in range(6):
		await get_tree().create_timer(0.9).timeout
		get_viewport().get_texture().get_image().save_png(dir_cap + "policia_%d.png" % i)
	chk(await esperar(func() -> bool: return not P.ui.destello.visible and P.carril_libre("Salida") and P.estacionados.has(6), 200.0), "l) policia se lleva al ladron y el vehiculo vuelve a su puesto")
	chk(S.esta_dentro(6) and not v6.conductor_nodo.visible, "l) el vehiculo queda vacio y registrado como dentro")
	# m) dinero por multa
	var din1: int = P.dinero()
	var cm: Dictionary = P.gen.caso_base("Salida", "salida_conductor_distinto", "prueba", S.usuario_por_id(6))
	cm["legitimo"] = false
	cm["rostro"] = 888002
	P.iniciar_caso("Salida", cm)
	await esperar(func() -> bool: return not (P.carriles["Salida"].get("eval", {}) as Dictionary).is_empty(), 120.0)
	P.permitir("Salida", "Guardia", "")
	chk(P.dinero() == din1 - P.MULTA_IRREGULAR_PERMITIDO, "m) dejar salir a un ladron cuesta multa %s" % P.formato_dinero(P.MULTA_IRREGULAR_PERMITIDO))
	await resolver("Salida")
	await esperar(func() -> bool: return P.en_transito.is_empty(), 200.0)

	# h) casos aleatorios del generador (humo): que nada se atasque
	P.gen = GeneradorCasos.new(42)
	S.config["modo"] = "automatico"
	var hechos: int = 0
	for i in range(8):
		var sen: String = "Entrada" if i % 3 != 2 else "Salida"
		if P.solicitar(sen):
			if await resolver(sen):
				hechos += 1
	chk(hechos >= 5, "h) %d casos aleatorios completados sin atascos" % hechos)
	chk(S.movimientos.size() > movs0 + 5, "h) historial crece")
	# consistencia: cada usuario dentro tiene puesto y auto estacionado
	chk(await esperar(func() -> bool: return P.en_transito.is_empty(), 200.0), "h) los vehiculos en camino terminan de estacionar")
	var ok_cons: bool = true
	for uu in S.usuarios_dentro():
		var idc: int = int(uu["id"])
		if S.puesto_de(idc) == "" or not P.estacionados.has(idc):
			ok_cons = false
			print("   inconsistencia usuario ", idc, " puesto=", S.puesto_de(idc), " auto=", P.estacionados.has(idc))
	chk(ok_cons, "h) usuarios dentro <-> puestos <-> autos coherentes")
	chk(P.estacionados.size() == S.usuarios_dentro().size(), "h) cantidad de autos = usuarios dentro (%d vs %d)" % [P.estacionados.size(), S.usuarios_dentro().size()])
	# ventanas modales (no deben fallar)
	P.ui.abrir_usuarios()
	await get_tree().process_frame
	P.ui.abrir_historial()
	await get_tree().process_frame
	P.ui.abrir_parqueadero()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir_cap + "sim_parqueadero.png")
	P.ui.abrir_config()
	await get_tree().process_frame
	P.ui.abrir_ayuda()
	await get_tree().process_frame
	P.ui.cerrar_overlay()
	chk(true, "i) abrir/cerrar todas las ventanas sin error")
	# n) menu inicial, ajustes e intro
	P.ui.abrir_ajustes()
	await get_tree().process_frame
	P.ui.abrir_mapas()
	P.ui.abrir_que_es()
	await get_tree().process_frame
	chk(P.ui.ventanas.has("ajustes") and P.ui.ventanas.has("mapas") and P.ui.ventanas.has("about"), "n) ajustes, mapas y 'que es CISPPH' abren")
	P.ui.cerrar_overlay()
	P.ui.cerrar_sesion()
	chk(P.ui.menu_panel.visible and not P.ui.hud.visible and not P.iniciado, "n) cerrar sesion vuelve al menu")
	P.ui.iniciar_desde_menu()
	chk(await esperar(func() -> bool: return P.intro_activa, 5.0), "n) la cinematica de inicio arranca")
	await get_tree().create_timer(2.0).timeout
	P.saltar_intro = true
	chk(await esperar(func() -> bool: return not P.intro_activa and P.ui.login_panel.visible, 20.0), "n) saltar la intro lleva al inicio de sesion")
	chk(P.esc.guardia.visible and P.esc.modo_camara == "puesto", "n) tras la intro: guarda sentado y camara en primera persona")
	P.ui.login_panel.visible = false
	P.ui.abrir_tareas_turno()
	chk(P.ui.ventanas.has("tareas"), "n) se muestran las tareas del turno tras iniciar sesion")
	P.ui.comenzar_turno()
	chk(P.iniciado and P.ui.hud.visible and not P.ui.ventanas.has("tareas"), "n) comenzar turno activa el HUD")
	Ajustes.valores["teclas"]["entrada"] = KEY_Q
	Ajustes.registrar_acciones()
	var evq := InputEventKey.new()
	evq.keycode = KEY_Q
	evq.pressed = true
	chk(evq.is_action("cispph_entrada"), "n) una tecla reasignada dispara la accion")
	Ajustes.valores["teclas"]["entrada"] = KEY_E
	Ajustes.registrar_acciones()
	# o) apagon, sin citofono, enviar a preguntar, monitor de camaras
	P.trafico_auto = false
	P.fijar_velocidad(6.0)
	chk(await esperar(func() -> bool: return P.carril_libre("Entrada") and P.carril_libre("Salida") and P.en_transito.is_empty(), 120.0), "o) carriles libres antes del apagon")
	P.provocar_apagon()
	P.apagon_restante = 100000.0
	chk(P.apagon and P.esc.apagon_k >= 0.0, "o) comienza el apagon")
	chk(await esperar(func() -> bool: return not P.intro_activa and P.esc.apagon_k > 0.99, 15.0), "o) las luces bajan y termina la cinematica")
	P.solicitar("Entrada")
	chk(await esperar(func() -> bool: return str((P.carriles["Entrada"] as Dictionary).get("estado", "")) == "esperando" and not ((P.carriles["Entrada"] as Dictionary)["eval"] as Dictionary).is_empty(), 90.0), "o) llega un vehiculo durante el apagon")
	var LA: Dictionary = P.carriles["Entrada"]
	await get_tree().create_timer(5.0).timeout
	chk(float(LA["cuenta"]) < 0.0 and str(LA["estado"]) == "esperando", "o) en apagon no hay decision automatica")
	P.citofono("Entrada")
	chk(not bool(LA["citofono_visto"]), "o) el citofono no funciona sin energia")
	chk(P.ui.tarjetas["Entrada"]["banner"].text.begins_with("SISTEMA"), "o) la tarjeta muestra SISTEMA CAIDO")
	P.preguntar("Entrada")
	chk(LA.has("pregunta") and float(LA["pregunta"]) > 0.0, "o) enviar a preguntar inicia la espera de 10 s")
	chk(str(P.ui.tarjetas["Entrada"]["detalle"].text).contains("esperando confirmaci"), "o) se muestra [esperando confirmacion]")
	chk(await esperar(func() -> bool: return str(LA.get("pregunta_resp", "")) != "", 20.0), "o) llega la respuesta tras ~10 s")
	P.denegar("Entrada", "Guardia", "")
	chk(await esperar(func() -> bool: return P.carril_libre("Entrada"), 60.0), "o) el vehiculo se va tras la decision")
	var est0: float = P.estres
	chk(est0 > 0.0, "o) el estres sube durante el apagon (%.1f)" % est0)
	P.ui.abrir_monitor()
	await get_tree().process_frame
	var mon: Node = P.ui.ventanas["monitor"].find_children("*", "MonitorCamaras", true, false)[0]
	mon.orientar(0.12, 0.0)
	var y1: float = mon.yaw
	for i in range(30):
		mon.orientar(0.12, 0.0)
	chk(y1 > 0.0 and mon.yaw <= MonitorCamaras.LIMITE_YAW + 0.001, "o) el monitor gira y respeta el limite")
	chk(mon.aviso.visible, "o) con apagon el monitor muestra SIN SENAL")
	P.restablecer_luz()
	chk(await esperar(func() -> bool: return P.esc.apagon_k < 0.01, 10.0), "o) vuelve la luz")
	mon.refrescar()
	chk(not mon.aviso.visible, "o) el monitor recupera la senal")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir_cap + "sim_monitor.png")
	P.ui.cerrar_overlay()
	# p) v5: metricas, error de conexion, expiracion, categorias
	chk(P.metricas.size() > 0, "p) se registraron metricas de decision")
	var n0: int = P.metricas.size()
	P.fallas_conexion = true
	P.prob_falla = 1.0
	chk(P._falla_conexion(), "p) falla de conexion simulada")
	chk(str(P.metricas[P.metricas.size() - 1]["decision"]) == "no registrada" and P.metricas.size() == n0 + 1, "p) la falla queda anotada como no registrada")
	P.fallas_conexion = false
	P.ui.abrir_metricas()
	chk(P.ui._tabla_validacion().contains("Registro de validación"), "p) tabla de validacion generada")
	P.ui.cerrar_overlay()
	chk(S.categoria_de(S.usuarios[2]) == "VIP" or S.categoria_de(S.usuarios[0]) != "", "p) categoria_de responde")
	P.expira_min = 0.001
	P.ultima_actividad = 0.0
	P.iniciado = true
	await get_tree().create_timer(0.5).timeout
	chk(not P.iniciado and P.ui.login_panel.visible, "p) la sesion expira y vuelve al login")
	P.expira_min = 0.0
	print("FALLOS: ", fallos)
	get_tree().quit(1 if fallos > 0 else 0)
