extends SceneTree
const WAV := preload("res://tools/wavlib.gd")
func _initialize() -> void:
	var w := WAV.read(ProjectSettings.globalize_path("res://Audio/source/footsteps_raw.wav"))
	var s: PackedFloat32Array = w["samples"]
	var rate: int = w["rate"]
	var env := WAV.envelope(s, int(rate * 0.005))
	for frac: float in [0.06, 0.10, 0.15, 0.25]:
		var th := WAV.peak(env) * frac
		var lock := int(rate * 0.12)
		var hits := PackedInt32Array()
		var last := -lock
		for i in env.size():
			if env[i] > th and i - last > lock:
				hits.append(i)
				last = i
		var gaps := ""
		var mn := 99.0
		var mx := 0.0
		for i in range(1, hits.size()):
			var g := float(hits[i] - hits[i - 1]) / rate
			mn = minf(mn, g)
			mx = maxf(mx, g)
			if i <= 14:
				gaps += "%.2f " % g
		print("%2.0f%% -> %d onsets   gaps %.2f..%.2f   first: %s" % [
			frac * 100.0, hits.size(), mn, mx, gaps])
	quit()
