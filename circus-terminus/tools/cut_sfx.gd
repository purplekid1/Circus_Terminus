extends SceneTree
## Cuts the downloaded sound effects down to one usable event each and levels
## them, writing Audio/sfx/*.wav.
##
##     godot --headless --path . --script tools/cut_sfx.gd
##
## The sources are library recordings, and library recordings are not game
## assets. They open with a second of room before anything happens, several of
## them contain three takes of the same event back to back, and they arrive at
## wildly different levels -- the ones here range from -12 dBFS to -0.06 dBFS
## peak. Dropped into the game as-is, one door is inaudible and the next one
## makes you jump.
##
## So: find where the event actually starts, take ONE of it, trim the room off
## the end, and put them all at the same peak. The per-file numbers below are
## the only hand-tuning; everything else is measured from the file.
##
## The long ones -- the generator, the car and the three ambience beds -- are
## NOT cut here. They stay as mp3 and loop natively, because they are minutes
## long, a seam in them comes round rarely, and decoding three minutes of audio
## in real time to save nothing is a poor trade.

const WAV := preload("res://tools/wavlib.gd")
const IN := "res://Audio/source/dl"
const OUT := "res://Audio/sfx"

## Everything lands here, so that no single effect jumps out of the mix. The
## Sfx bus does the actual quieting -- see default_bus_layout.tres.
const TARGET := 0.72

## name, seconds to keep from the first onset, and how hard a rise counts as
## that onset (a fraction of the file's own peak).
##
## `keep` is what stops a three-take library file from playing all three. Where
## the whole recording is one event it is simply longer than the file.
const FILES := [
	{"name": "door_open", "keep": 3.2, "onset": 0.05},
	{"name": "door_close", "keep": 2.8, "onset": 0.08},
	# Three goes at the handle in six seconds. One is plenty -- the player will
	# press again themselves if they want to hear it twice.
	{"name": "door_locked", "keep": 1.9, "onset": 0.12},
	{"name": "gate_open", "keep": 4.5, "onset": 0.06},
	{"name": "pickup", "keep": 0.6, "onset": 0.05},
	# Eight seconds, several takes.
	{"name": "drop", "keep": 1.3, "onset": 0.12},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("%-13s %9s %9s %9s %9s" % ["effect", "source", "kept", "src peak", "out peak"])

	for f: Dictionary in FILES:
		var name: String = f["name"]
		var w := WAV.read(ProjectSettings.globalize_path("%s/%s.wav" % [IN, name]))
		if w.is_empty():
			push_error("cut_sfx: no %s.wav -- run decode_mp3.gd on it first." % name)
			continue
		var s: PackedFloat32Array = w["samples"]
		var rate: int = w["rate"]
		var was := float(s.size()) / rate
		var src_peak := WAV.peak(s)

		var start := _first_onset(s, rate, f["onset"])
		var length := mini(int(rate * float(f["keep"])), s.size() - start)
		s = s.slice(start, start + length)

		# Whatever room is left on the end after the event has died away.
		s = WAV.trim_tail(s, rate, -48.0)
		s = WAV.normalise(s, TARGET)
		# A long out-fade, because these are cut mid-decay rather than at a
		# natural end, and a hard stop on a reverb tail is a click.
		s = WAV.fade(s, rate, 2.0, 40.0)

		WAV.write(ProjectSettings.globalize_path("%s/%s.wav" % [OUT, name]), s, rate)
		print("%-13s %8.2fs %8.2fs %9.3f %9.3f" % [
			name, was, float(s.size()) / rate, src_peak, WAV.peak(s)])

	print("wrote %d effects to %s" % [FILES.size(), OUT])
	quit()


## Where the event starts: the first moment the envelope crosses `frac` of the
## file's own peak, backed off a little so the attack is not clipped off.
##
## Relative to the file's peak rather than an absolute level, because these
## come from different libraries at different levels and a fixed threshold
## finds the first breath in a quiet file and misses the hit in a loud one.
func _first_onset(s: PackedFloat32Array, rate: int, frac: float) -> int:
	var env := WAV.envelope(s, int(rate * 0.005))
	var thresh := WAV.peak(env) * frac
	for i in env.size():
		if env[i] > thresh:
			return maxi(i - int(rate * 0.02), 0)
	return 0
