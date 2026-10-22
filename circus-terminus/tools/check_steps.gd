extends SceneTree
## Proves the three surface sets are actually different sounds rather than the
## same sound at three volumes.
##
## The metrics are chosen to survive a transient. A first attempt measured
## "time to fall 20 dB from the peak" and reported 18 ms for all three sets --
## which is true and useless, because that is the heel hitting the floor and
## every floor does that fast. What separates them is what happens AFTERWARDS,
## so the tail is measured as a share of total energy past a fixed 150 ms, and
## brightness with a 4-pole split rather than a 6 dB/octave one that leaks the
## whole midrange into the "low" bucket.

const WAV := preload("res://tools/wavlib.gd")


func _initialize() -> void:
	print("%-8s %3s %7s %6s %9s %9s %9s" %
		["set", "n", "len ms", "peak", "air>2k", "body<250", "tail>150ms"])
	for name: String in ["out", "house", "cellar"]:
		var n := 0
		var len_ms := 0.0
		var pk := 0.0
		var air := 0.0
		var body := 0.0
		var tail := 0.0
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
			len_ms += 1000.0 * s.size() / rate
			pk = maxf(pk, WAV.peak(s))

			var tot := maxf(_energy(s), 1e-12)
			air += _energy(_hp4(s, rate, 2000.0)) / tot
			body += _energy(_lp4(s, rate, 250.0)) / tot

			var at := mini(int(rate * 0.15), s.size())
			tail += _energy(s.slice(at)) / tot
		print("%-8s %3d %7.0f %6.2f %8.1f%% %8.1f%% %8.1f%%" %
			[name, n, len_ms / n, pk, 100.0 * air / n, 100.0 * body / n, 100.0 * tail / n])
	quit()


func _energy(s: PackedFloat32Array) -> float:
	var e := 0.0
	for v in s:
		e += v * v
	return e


## Four cascaded one-poles: 24 dB/octave, steep enough that "above 2 kHz"
## actually means above 2 kHz.
func _lp4(s: PackedFloat32Array, rate: int, hz: float) -> PackedFloat32Array:
	var out := s
	for _i in 4:
		out = WAV.low_pass(out, rate, hz)
	return out


func _hp4(s: PackedFloat32Array, rate: int, hz: float) -> PackedFloat32Array:
	var out := s
	for _i in 4:
		out = WAV.high_pass(out, rate, hz)
	return out
