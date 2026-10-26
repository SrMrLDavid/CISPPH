extends Node
class_name AudioSim

# CISPPH - Sonidos sinteticos minimos (sin archivos): pitidos de lectura, aceptado, rechazado,
# obturador de la camara, motor de la barrera y motor de vehiculo. Ligero (muestras de pocos KB).

var reproductores: Dictionary = {}
var silencio: bool = false


func _ready() -> void:
	crear("lectura", [[880.0, 0.06], [1320.0, 0.08]], 0.25)
	crear("ok", [[660.0, 0.08], [880.0, 0.08], [1320.0, 0.14]], 0.3)
	crear("error", [[220.0, 0.18], [165.0, 0.28]], 0.35, true)
	crear("obturador", [[3000.0, 0.012], [0.0, 0.02], [1800.0, 0.02]], 0.4, true)
	crear("barrera", [[110.0, 0.6]], 0.15, true)
	crear("alerta", [[520.0, 0.12], [0.0, 0.05], [520.0, 0.12]], 0.3)
	crear("motor", [[70.0, 0.5]], 0.12, true)
	crear("sirena", [[700.0, 0.3], [900.0, 0.3], [700.0, 0.3], [900.0, 0.3], [700.0, 0.3], [900.0, 0.3]], 0.28, true)
	crear("dinero", [[1040.0, 0.06], [1560.0, 0.12]], 0.25)
	crear("multa", [[300.0, 0.12], [200.0, 0.2]], 0.3, true)


func crear(nombre: String, tonos: Array, volumen: float, cuadrada: bool = false) -> void:
	var tasa: int = 22050
	var datos := PackedByteArray()
	var fase: float = 0.0
	for t in tonos:
		var freq: float = float(t[0])
		var n: int = int(float(t[1]) * tasa)
		for i in range(n):
			var env: float = minf(1.0, minf(float(i) / 120.0, float(n - i) / 400.0))
			var v: float = 0.0
			if freq > 0.0:
				fase += freq / tasa
				var onda: float = sin(fase * TAU)
				if cuadrada:
					onda = signf(onda) * 0.6 + onda * 0.4
				v = onda * env * volumen
			var m: int = clampi(int(v * 32000.0), -32768, 32767)
			datos.append(m & 0xff)
			datos.append((m >> 8) & 0xff)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.data = datos
	var p := AudioStreamPlayer.new()
	p.stream = w
	add_child(p)
	reproductores[nombre] = p


func tocar(nombre: String) -> void:
	if silencio or not reproductores.has(nombre):
		return
	var p: AudioStreamPlayer = reproductores[nombre]
	p.volume_db = linear_to_db(maxf(0.0001, float(Ajustes.valores.get("vol_efectos", 1.0))))
	p.play()
