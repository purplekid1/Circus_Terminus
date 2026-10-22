extends SceneTree
## How long each set RINGS at its resonant pitch, and how tonal that ring is.
##
## A wooden floor thumps and is done. A pipe rings on at one pitch. The
## difference is measurable: band-pass at the resonance and time the decay, and
## compare that band's energy against the whole signal. A long decay in a narrow
## band IS the sound of a struck tube.

const WAV := preload("res://tools/wavlib.gd")

func _initialize() -> void:
	print("%-8s %10s %12s %14s" % ["set", "ring Hz", "decay -20dB", "band share"])
	for probe: Array in [["out", 150.0], ["house", 150.0], ["cellar", 85.0]]:
		var name: String = probe[0]
		var hz: float = probe[1]
		var decay := 0.0
		var share := 0.0
		var n := 0
		for i in 128:
			var path := ProjectSettings.globalize_path(
				"res://Audio/steps/%s_%02d.wav" % [name, i])
			if not FileAccess.file_exists(path):
				break
			var w := WAV.read(path)
			if w.is_empty():
				break
			var s: PackedFloat32Array = w["samples"]
			var rate: int = w["rate"]
			n += 1
			# Narrow band around the resonance, which is what a resonator puts
			# energy into and a broadband thump does not.
			var b := WAV.resonator(s, rate, hz, 12.0)
			share += _energy(b) / maxf(_energy(s), 1e-12)
			decay += _decay_ms(b, rate)
		print("%-8s %10.0f %9.0f ms %13.1f%%" % [name, hz, decay / n, 100.0 * share / n])
	quit()


func _energy(s: PackedFloat32Array) -> float:
	var e := 0.0
	for v in s:
		e += v * v
	return e


## From the band's loudest moment, how long to fall 20 dB.
func _decay_ms(s: PackedFloat32Array, rate: int) -> float:
	var env := WAV.envelope(s, int(rate * 0.004))
	var pk := WAV.peak(env)
	var at := 0
	for i in env.size():
		if env[i] >= pk:
			at = i
			break
	var target := pk * 0.1
	for i in range(at, env.size()):
		if env[i] < target:
			return 1000.0 * (i - at) / rate
	return 1000.0 * (env.size() - at) / rate
