extends SceneTree
const WAV := preload("res://tools/wavlib.gd")

func _initialize() -> void:
	var files := ["res://Audio/source/footsteps_raw.wav",
		"res://Audio/steps/out_03.wav", "res://Audio/steps/house_03.wav",
		"res://Audio/steps/cellar_03.wav"]
	var edges := [60.0, 120.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0]
	var head := "%-26s" % "file"
	for e: float in edges:
		head += "%7.0f" % e
	print(head + "%7s" % "top")
	for path: String in files:
		var w := WAV.read(ProjectSettings.globalize_path(path))
		if w.is_empty():
			continue
		var s: PackedFloat32Array = w["samples"]
		var rate: int = w["rate"]
		var tot := maxf(_energy(s), 1e-12)
		var line := "%-26s" % path.get_file()
		var prev := PackedFloat32Array()
		for e: float in edges:
			var lp := _lp4(s, rate, e)
			var band := _energy(lp) / tot
			line += "%6.1f%%" % (100.0 * band)
			prev = lp
		line += "%6.1f%%" % (100.0 * _energy(_hp4(s, rate, 8000.0)) / tot)
		print(line)
	quit()

func _energy(s: PackedFloat32Array) -> float:
	var e := 0.0
	for v in s: e += v * v
	return e

func _lp4(s: PackedFloat32Array, rate: int, hz: float) -> PackedFloat32Array:
	var o := s
	for _i in 4: o = WAV.low_pass(o, rate, hz)
	return o

func _hp4(s: PackedFloat32Array, rate: int, hz: float) -> PackedFloat32Array:
	var o := s
	for _i in 4: o = WAV.high_pass(o, rate, hz)
	return o
