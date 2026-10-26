extends Control

# Entrada 035 — Rostro ficticio procedural (caricatura). Se genera de un numero: mismo numero,
# misma cara. NO usa fotos ni rostros reales. Sirve para el conductor y para la foto del documento:
# si los numeros difieren, las caras difieren y el jugador puede notarlo.

var semilla: int = 1
var fondo: Color = Color("#2a3550")


func fijar(valor: int) -> void:
	semilla = valor
	queue_redraw()


func rasgo(indice: int, cantidad: int) -> int:
	var h: int = (semilla * 2654435761 + indice * 40503 + 12345) & 0x7fffffff
	h = (h ^ (h >> 15)) & 0x7fffffff
	return h % cantidad


func _draw() -> void:
	var t: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, t), fondo)
	var pieles: Array[Color] = [Color("#f1c9a5"), Color("#d9a07a"), Color("#a9714c"), Color("#7a4a2e"), Color("#5a3622")]
	var pelos: Array[Color] = [Color("#15110f"), Color("#4a2c1a"), Color("#8a5a2b"), Color("#d9b45a"), Color("#b5522a"), Color("#bdbdbd")]
	var piel: Color = pieles[rasgo(1, pieles.size())]
	var pelo: Color = pelos[rasgo(2, pelos.size())]
	var estilo: int = rasgo(3, 5)
	var gafas: bool = rasgo(4, 3) == 0
	var bigote: bool = rasgo(5, 4) == 0
	var forma: int = rasgo(6, 3)
	var ojos: int = rasgo(7, 3)
	var cx: float = t.x * 0.5
	var cy: float = t.y * 0.52
	var ancho: float = t.x * (0.30 + 0.04 * float(forma))
	var alto: float = t.y * 0.36
	# Hombros
	draw_rect(Rect2(cx - t.x * 0.34, t.y * 0.86, t.x * 0.68, t.y * 0.2), Color("#3a4a6a").lerp(piel, 0.1))
	draw_rect(Rect2(cx - t.x * 0.06, t.y * 0.78, t.x * 0.12, t.y * 0.1), piel.darkened(0.15))
	# Pelo trasero
	if estilo == 1 or estilo == 4:
		draw_rect(Rect2(cx - ancho - 4.0, cy - alto * 0.6, ancho * 2.0 + 8.0, alto * 1.7), pelo)
	# Cara
	draw_rect(Rect2(cx - ancho, cy - alto, ancho * 2.0, alto * 2.0), piel)
	# Pelo superior
	if estilo == 0:
		draw_rect(Rect2(cx - ancho, cy - alto - 6.0, ancho * 2.0, 18.0), pelo)
	elif estilo == 2:
		draw_rect(Rect2(cx - ancho - 3.0, cy - alto - 10.0, ancho * 2.0 + 6.0, 26.0), pelo)
	elif estilo == 3:
		draw_rect(Rect2(cx - ancho * 0.5, cy - alto - 4.0, ancho, 8.0), pelo)
	else:
		draw_rect(Rect2(cx - ancho, cy - alto - 4.0, ancho * 2.0, 14.0), pelo)
	# Ojos
	var oy: float = cy - alto * 0.2
	var tam_ojo: float = 5.0 + float(ojos) * 2.0
	for lado in [-1.0, 1.0]:
		draw_rect(Rect2(cx + float(lado) * ancho * 0.45 - tam_ojo * 0.5, oy, tam_ojo, tam_ojo * 0.7), Color.WHITE)
		draw_rect(Rect2(cx + float(lado) * ancho * 0.45 - 1.5, oy + 1.0, 3.0, 3.0), Color("#1a1210"))
	if gafas:
		for lado_g in [-1.0, 1.0]:
			draw_rect(Rect2(cx + float(lado_g) * ancho * 0.45 - 9.0, oy - 4.0, 18.0, 13.0), Color("#101820"), false, 2.0)
		draw_line(Vector2(cx - 6.0, oy + 2.0), Vector2(cx + 6.0, oy + 2.0), Color("#101820"), 2.0)
	# Nariz y boca
	draw_rect(Rect2(cx - 2.0, cy + 2.0, 4.0, 8.0), piel.darkened(0.18))
	draw_rect(Rect2(cx - ancho * 0.3, cy + alto * 0.5, ancho * 0.6, 3.0), Color("#7a3a3a"))
	if bigote:
		draw_rect(Rect2(cx - ancho * 0.4, cy + alto * 0.32, ancho * 0.8, 6.0), pelo)
