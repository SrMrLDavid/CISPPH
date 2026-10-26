extends Control
class_name IconoMenu

# CISPPH - Boton "azulejo" del menu con icono dibujado por codigo (engranaje, play, mapa, salida, info).
# Sin imagenes ni fuentes de iconos: se ve igual en cualquier equipo.

signal pulsado

var tipo: String = "play"
var texto: String = ""
var subtexto: String = ""
var color: Color = Color("#3ad0ff")
var desactivado: bool = false
var _hover: float = 0.0
var _hover_objetivo: float = 0.0
var _giro: float = 0.0


func configurar(t: String, titulo: String, sub: String, c: Color, ancho: float = 190.0, alto: float = 170.0) -> void:
	tipo = t
	texto = titulo
	subtexto = sub
	color = c
	custom_minimum_size = Vector2(ancho, alto)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover_objetivo = 0.0 if desactivado else 1.0)
	mouse_exited.connect(func() -> void: _hover_objetivo = 0.0)


func _gui_input(e: InputEvent) -> void:
	if desactivado:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pulsado.emit()


func _process(delta: float) -> void:
	_hover = move_toward(_hover, _hover_objetivo, delta * 6.0)
	if tipo == "gear":
		_giro += delta * (0.25 + _hover * 2.2)
	if _hover > 0.0 or tipo == "gear":
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var base := Color("#111826")
	var borde: Color = color.lerp(Color.WHITE, _hover * 0.4)
	if desactivado:
		borde = Color("#3a4152")
	var sb := StyleBoxFlat.new()
	sb.bg_color = base.lerp(color.darkened(0.55), _hover * 0.7)
	sb.set_corner_radius_all(18)
	sb.border_color = borde
	sb.set_border_width_all(2 + int(_hover * 2.0))
	sb.shadow_color = Color(color, 0.35 * _hover)
	sb.shadow_size = int(18 * _hover)
	draw_style_box(sb, r)
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var rad: float = minf(size.x, size.y) * 0.24 * (1.0 + _hover * 0.08)
	var col: Color = Color("#5b667c") if desactivado else borde
	match tipo:
		"play":
			draw_arc(c, rad * 1.12, 0, TAU, 40, col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.4, -rad * 0.62), c + Vector2(rad * 0.7, 0), c + Vector2(-rad * 0.4, rad * 0.62)]), col)
		"gear":
			var dientes: int = 8
			for i in range(dientes):
				var a: float = _giro + TAU * float(i) / float(dientes)
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var p0: Vector2 = c + d * rad * 0.8
				var p1: Vector2 = c + d * rad * 1.22
				draw_colored_polygon(PackedVector2Array([p0 + n * rad * 0.2, p1 + n * rad * 0.14, p1 - n * rad * 0.14, p0 - n * rad * 0.2]), col)
			draw_arc(c, rad * 0.85, 0, TAU, 40, col, rad * 0.3)
			draw_circle(c, rad * 0.32, base)
		"power":
			draw_arc(c, rad * 0.95, deg_to_rad(-60), deg_to_rad(240), 36, col, 4.0)
			draw_line(c + Vector2(0, -rad * 1.1), c + Vector2(0, -rad * 0.1), col, 4.0)
		"map":
			var w: float = rad * 0.7
			var h: float = rad * 1.05
			var xs: Array = [-1.5, -0.5, 0.5, 1.5]
			for i in range(3):
				var x0: float = float(xs[i]) * w
				var x1: float = float(xs[i + 1]) * w
				var dy: float = -h * 0.12 if i % 2 == 0 else h * 0.12
				var cc: Color = col.darkened(0.2 * float(i % 2))
				draw_colored_polygon(PackedVector2Array([c + Vector2(x0, -h * 0.5 + dy), c + Vector2(x1, -h * 0.5 - dy), c + Vector2(x1, h * 0.5 - dy), c + Vector2(x0, h * 0.5 + dy)]), Color(cc, 0.85))
			draw_circle(c + Vector2(w * 0.3, -h * 0.1), rad * 0.2, Color("#ff5c5c"))
		"info":
			draw_arc(c, rad * 1.0, 0, TAU, 40, col, 3.0)
			draw_circle(c + Vector2(0, -rad * 0.45), rad * 0.11, col)
			draw_line(c + Vector2(0, -rad * 0.15), c + Vector2(0, rad * 0.55), col, 5.0)
	var f := ThemeDB.fallback_font
	var y0: float = size.y * 0.78
	var tw: Vector2 = f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	draw_string(f, Vector2((size.x - tw.x) * 0.5, y0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#5b667c") if desactivado else Color.WHITE)
	if subtexto != "":
		var sw: Vector2 = f.get_string_size(subtexto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(f, Vector2((size.x - sw.x) * 0.5, y0 + 22), subtexto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8e9ab0"))
