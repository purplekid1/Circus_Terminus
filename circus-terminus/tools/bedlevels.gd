extends SceneTree
## Every ambience bed at unity, measured two ways: plain RMS, and the energy in
## 2-6 kHz where the ear is most sensitive.
##
## SET LEVELS BY THE SECOND NUMBER. Two beds at the same RMS are not equally
## loud if one of them is crickets: the outdoor bed carries 40% of its energy in
## that band against 0.2% for the house room tone, so matching them by RMS makes
## the crickets roughly 20 dB too loud. That is exactly the mistake this tool
## was written to stop repeating.
var _cap: AudioEffectCapture
var _p: AudioStreamPlayer
var _at := 0
var _n := 0
var _armed := false
const BEDS := ["amb_outside", "amb_house", "amb_cellar", "menu_theme"]

func _initialize() -> void:
	_cap = AudioEffectCapture.new(); _cap.buffer_length = 1.0
	AudioServer.add_bus_effect(0, _cap)
	_p = AudioStreamPlayer.new(); _p.bus = "Master"; _p.volume_db = 0.0
	root.add_child(_p)

func _process(_d: float) -> bool:
	if not _p.playing:
		_p.stream = load("res://Audio/%s.mp3" % BEDS[_at])
		_p.play(25.0)
		return false
	_n += 1
	if not _armed and _n > 25:
		_cap.clear_buffer(); _armed = true; _n = 0
		return false
	if not _armed or _n < 25: return false

	var buf := _cap.get_buffer(mini(_cap.get_frames_available(), 22050))
	var mono := PackedFloat32Array(); mono.resize(buf.size())
	for i in buf.size(): mono[i] = (buf[i].x + buf[i].y) * 0.5
	var wav := preload("res://tools/wavlib.gd")
	var band := wav.high_pass(wav.low_pass(mono, 44100, 6000.0), 44100, 2000.0)
	print("%-13s rms %6.1f dBFS    2-6kHz %6.1f dBFS    share %4.1f%%" % [BEDS[_at],
		linear_to_db(maxf(_rms(mono), 1e-9)), linear_to_db(maxf(_rms(band), 1e-9)),
		100.0 * pow(_rms(band) / maxf(_rms(mono), 1e-9), 2.0)])
	_p.stop(); _at += 1; _n = 0; _armed = false
	return _at >= BEDS.size()

func _rms(s: PackedFloat32Array) -> float:
	var e := 0.0
	for v in s: e += v * v
	return sqrt(e / maxf(float(s.size()), 1.0))
