extends SceneTree
## The sound effects: that they are all present, levelled to each other, and
## distinguishable from one another.
##
## These are library recordings now, cut and levelled by tools/cut_sfx.gd. The
## synthesised set they replaced is still in tools/gen_sfx.gd, writing to
## Audio/sfx_synth, and is not used by the game.
##
## The levelling assertion is the one that earns its place. The sources arrived
## between -12 dBFS and -0.06 dBFS peak; dropped in as they came, one door was
## inaudible and the next made you jump.

const WAV := preload("res://tools/wavlib.gd")

## Cut to .wav so they can be trimmed to a single event.
const ONE_SHOTS := ["door_open", "door_close", "door_locked", "gate_open",
	"pickup", "drop"]
## Left as .mp3 and looped from their import settings. Minutes long, so a seam
## comes round rarely and decoding them offline buys nothing.
const LOOPS := ["generator_loop", "car_loop"]

## What cut_sfx.gd normalises every one-shot to.
const TARGET := 0.72


func _ok(label: String, cond: bool) -> void:
	print("SFX %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	var missing: Array[String] = []
	for name: String in ONE_SHOTS:
		if not FileAccess.file_exists(ProjectSettings.globalize_path(
				"res://Audio/sfx/%s.wav" % name)):
			missing.append(name)
	for name: String in LOOPS:
		if not ResourceLoader.exists("res://Audio/sfx/%s.mp3" % name):
			missing.append(name)
	_ok("every effect is present", missing.is_empty())
	if not missing.is_empty():
		print("   missing: %s" % ", ".join(missing))
		quit(1)
		return

	# ---- one-shots ----
	var off: Array[String] = []
	var endless: Array[String] = []
	var silent: Array[String] = []
	for name: String in ONE_SHOTS:
		var s := _read(name)
		if s.is_empty():
			silent.append(name)
			continue
		# THE POINT OF cut_sfx.gd. Every one of these came off a different
		# library at a different level; they have to leave at the same one.
		if absf(WAV.peak(s) - TARGET) > 0.02:
			off.append(name)
		var secs := float(s.size()) / 44100.0
		# A one-shot that runs on is a cut that failed to find the end of the
		# event -- several of the sources hold three takes in a row.
		if secs > 5.0 or secs < 0.1:
			endless.append(name)
	_ok("none of them failed to read", silent.is_empty())
	_ok("they are all levelled to each other", off.is_empty())
	if not off.is_empty():
		print("   off level: %s" % ", ".join(off))
	_ok("and each is one event, not a whole take", endless.is_empty())
	if not endless.is_empty():
		print("   wrong length: %s" % ", ".join(endless))

	# A door opening and a door refusing must not sound alike, or the player
	# learns nothing from hearing one rather than the other.
	_ok("a locked door sounds unlike an opening one",
		absf(_centroid(_read("door_open")) - _centroid(_read("door_locked"))) > 80.0)
	# Pickup and drop are a matched pair and should still be told apart.
	_ok("picking up and putting down differ",
		absf(_centroid(_read("pickup")) - _centroid(_read("drop"))) > 40.0)
	# Nothing may start with a click: these are cut mid-recording.
	var clicky: Array[String] = []
	for name: String in ONE_SHOTS:
		var s := _read(name)
		if not s.is_empty() and absf(s[0]) > 0.02:
			clicky.append(name)
	_ok("none of them begins with a click", clicky.is_empty())

	# ---- loops ----
	for name: String in LOOPS:
		var stream := load("res://Audio/sfx/%s.mp3" % name) as AudioStream
		_ok("%s loads" % name, stream != null)
		if stream == null:
			continue
		# Without this the generator falls silent partway through the game and
		# never comes back -- a fault nobody finds in a thirty-second play.
		_ok("%s loops" % name, stream.get("loop") == true)
		_ok("%s is long enough not to be obvious" % name, stream.get_length() > 10.0)

	quit()


func _read(name: String) -> PackedFloat32Array:
	var w := WAV.read(ProjectSettings.globalize_path("res://Audio/sfx/%s.wav" % name))
	return w["samples"] if not w.is_empty() else PackedFloat32Array()


## Zero-crossing rate: a cheap, honest stand-in for brightness on broadband
## material, and it needs no FFT.
func _centroid(s: PackedFloat32Array) -> float:
	if s.is_empty():
		return 0.0
	var crossings := 0
	for i in range(1, s.size()):
		if (s[i] >= 0.0) != (s[i - 1] >= 0.0):
			crossings += 1
	return 0.5 * crossings * 44100.0 / float(s.size())
