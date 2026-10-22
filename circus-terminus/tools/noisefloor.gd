extends SceneTree
## How much hiss sits under each footstep set. A step is a transient followed by
## a decay; anything still going in the last quarter of the file that is not
## clearly decaying is background, and after a 15x normalisation of a quiet
## source there can be a lot of it.

const WAV := preload("res://tools/wavlib.gd")

func _initialize() -> void:
	print("%-8s %9s %10s %12s %13s" %
		["set", "peak dBFS", "tail RMS", "tail hiss>2k", "attack air>2k"])
	for name: String in ["out", "house", "cellar"]:
		var pk := 0.0
		var tail := 0.0
		var hiss := 0.0
		var air := 0.0
		var n := 0
		for i in 128:
			var w := WAV.read(ProjectSettings.globalize_path(
				"res://Audio/steps/%s_%02d.wav" % [name, i]))
			if w.is_empty():
				# The set is however many files the cut produced -- 15 for the
				# first recording, 29 for this one. Stop at the first gap.
				break
			var s: PackedFloat32Array = w["samples"]
			var rate: int = w["rate"]
			n += 1
			var p := WAV.peak(s)
			pk = maxf(pk, p)
			# Last quarter.
			# Brightness belongs in the ATTACK. Measuring it over the whole file
			# under-reports a set whose grit decays in 30 ms -- which is the
			# point of the decay -- so the two windows are measured separately:
			# air in the first 60 ms, hiss in the last quarter.
			var head := s.slice(0, mini(int(rate * 0.06), s.size()))
			air += _rms(_hp4(head, rate, 2000.0)) / maxf(_rms(head), 1e-9)
			var last := s.slice(int(s.size() * 0.75))
			var r := _rms(last)
			tail += r
			hiss += _rms(_hp4(last, rate, 2000.0))
		tail /= n
		air /= n
		hiss /= n
		print("%-8s %9.1f %10.1f %11.1f %12.1f%%" % [name,
			linear_to_db(maxf(pk, 1e-9)), linear_to_db(maxf(tail, 1e-9)),
			linear_to_db(maxf(hiss, 1e-9)), 100.0 * air])
	quit()

func _rms(s: PackedFloat32Array) -> float:
	var e := 0.0
	for v in s:
		e += v * v
	return sqrt(e / maxf(float(s.size()), 1.0))

func _hp4(s: PackedFloat32Array, rate: int, hz: float) -> PackedFloat32Array:
	var o := s
	for _i in 4:
		o = WAV.high_pass(o, rate, hz)
	return o
