extends CanvasLayer
class_name FiltroVHS

# CISPPH - Filtro opcional "camara de seguridad / VHS" (grano, lineas, aberracion cromatica, vineta, color apagado).
# Es un solo shader sobre la imagen 3D (capa por debajo de la interfaz). Se activa en Ajustes > Graficos.
# Estetica inspirada en el "terror de baja fidelidad"; aqui solo es un filtro, no cambia modelos ni texturas.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float fuerza : hint_range(0.0, 1.0) = 0.6;
uniform float tiempo = 0.0;

float azar(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + tiempo) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 + r2 * 0.08 * fuerza);                       // lente: leve curvatura
	float desfase = (0.0012 + r2 * 0.006) * fuerza;                   // aberracion cromatica
	float rojo = texture(pantalla, uv + vec2(desfase, 0.0)).r;
	float verde = texture(pantalla, uv).g;
	float azul = texture(pantalla, uv - vec2(desfase, 0.0)).b;
	vec3 col = vec3(rojo, verde, azul);
	float gris = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gris), 0.35 * fuerza);                        // colores apagados
	col = mix(col, col * vec3(0.9, 1.04, 0.98), fuerza);              // tinte verdoso en sombras
	col = (col - 0.5) * (1.0 + 0.12 * fuerza) + 0.5;
	float lineas = 0.5 + 0.5 * sin(SCREEN_UV.y * 900.0);              // lineas horizontales
	col *= 1.0 - 0.10 * fuerza * lineas;
	col += (azar(SCREEN_UV * 900.0) - 0.5) * 0.14 * fuerza;           // grano
	float barrido = smoothstep(0.0, 0.02, fract(SCREEN_UV.y * 0.6 - tiempo * 0.05)) * 0.02 * fuerza;
	col += barrido;
	col *= 1.0 - smoothstep(0.35, 0.85, length(c) * 1.25) * 0.55 * fuerza;   // vineta
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { col = vec3(0.0); }
	COLOR = vec4(col, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var etiqueta_rec: Label
var hora_texto: String = "--:--"
var activo: bool = false
var _t: float = 0.0


func _init() -> void:
	layer = 5


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	add_child(rect)
	etiqueta_rec = Label.new()
	etiqueta_rec.position = Vector2(26, 128)
	etiqueta_rec.add_theme_font_size_override("font_size", 20)
	etiqueta_rec.add_theme_color_override("font_color", Color("#e8e8e8"))
	etiqueta_rec.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta_rec.add_theme_constant_override("outline_size", 6)
	etiqueta_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(etiqueta_rec)
	aplicar()


func aplicar() -> void:
	activo = bool(Ajustes.valores.get("vhs", false))
	rect.visible = activo
	etiqueta_rec.visible = activo
	mat.set_shader_parameter("fuerza", float(Ajustes.valores.get("vhs_fuerza", 0.6)))


func _process(delta: float) -> void:
	if not activo:
		return
	_t += delta
	mat.set_shader_parameter("tiempo", fmod(_t, 100.0))
	var parpadeo: String = "●" if int(_t * 1.5) % 2 == 0 else "  "
	etiqueta_rec.text = "%s REC  CAM-01   %s" % [parpadeo, hora_texto]
