extends SceneTree
## The creature's four sounds, into Audio/sfx/.
##
##     godot --headless --path . --script tools/gen_stalker_sfx.gd
##
## THESE ARE SYNTHESISED and the ordinary effects are not, which is a
## deliberate split rather than an inconsistency. Doors and footsteps were
## replaced with library recordings because a real door already sounds like a
## door and nothing I build will beat one. There is no recording of a
## three-metre invisible thing, so the only way to get one is to describe it.
##
## The description, in order of how much it matters:
##
##   idle    the reason the whole mechanic is fair. The player cannot see it,
##           so they have to be able to HEAR that something is near before it
##           matters -- a slow wet breath and the odd joint popping, pitched
##           low so it carries through trees. It loops on the creature itself.
##   notice  an intake, rising. The sound of being decided about.
##   lose    the same shape falling, so the pair read as a question and an
##           answer without either needing to be a roar.
##   catch   a body hitting yours, and something above it screaming.
##
## Levelled to peak 0.72, the same as the library effects in tools/cut_sfx.gd,
## so the Sfx bus trim that was set for those still means something here. Peak
## is NOT the same as loudness -- see tools/bedlevels.gd for the crickets that
## taught us that -- so these are deliberately low and mid heavy, and the
## balance that actually matters is the volume_db at each play site.
##
## ONE THING THIS SCRIPT CANNOT DO IS SET THE LOOP. stalker_idle has to loop
## or every creature in the level goes silent nine seconds in, and that lives
## in Audio/sfx/stalker_idle.wav.import, not here:
##
##     edit/loop_mode=2
##
## 2, not 1. The WAV importer's list is "Detect, Disabled, Forward, ..." and
## is NOT the AudioStreamWAV.LoopMode enum, so 1 reads as Disabled and looks
## exactly like a typo that worked. Godot also will not re-import over a stale
## cache on a params-only change; delete .godot/imported/stalker_idle.wav-*
## first. tools/probe_hunt.gd runs longer than the clip specifically to catch
## this, because nothing else does -- there is no error, only silence.

const WAV := preload("res://tools/wavlib.gd")
const OUT := "res://Audio/sfx"
const RATE := 44100
## Matches cut_sfx.gd. Changing it here and not there is how a set of effects
## ends up quietly twice as loud as the rest of the game.
const TARGET := 0.72


func _initialize() -> void:
	var made := 0
	for entry: Array in [
		["stalker_idle", _idle(), true],
		["stalker_notice", _notice(), false],
		["stalker_lose", _lose(), false],
		["stalker_catch", _catch(), false],
	]:
		var name: String = entry[0]
		var s: PackedFloat32Array = entry[1]
		var looping: bool = entry[2]
		s = WAV.normalise(s, TARGET)
		if looping:
			# No end fades on a loop: the ends ARE the joint, and loopify has
			# already crossfaded them past each other.
			s = WAV.loopify(s, RATE, 0.75)
		else:
			s = WAV.trim_tail(s, RATE, -62.0)
			s = WAV.fade(s, RATE, 1.0, 14.0)
		WAV.write(ProjectSettings.globalize_path("%s/%s.wav" % [OUT, name]), s, RATE)
		print("  %-16s %5.2f s   peak %.2f" % [name, float(s.size()) / RATE, WAV.peak(s)])
		made += 1
	print("wrote %d creature sounds to %s" % [made, OUT])
	quit()


func _n(seconds: float) -> int:
	return int(RATE * seconds)


## The woods: big, soft-walled, and swallowing the high end. Every one of
## these is heard across a clearing, never in a room, so the tail runs longer
## than the house recipes but the wet mix stays as low as theirs -- open air
## returns very little, it just returns it late.
func _woods(s: PackedFloat32Array, wet: float) -> PackedFloat32Array:
	return WAV.reverb(s, RATE, 0.78, 2000.0, wet, 0.52)


# ------------------------------------------------------------------ the loop

## Breathing, and joints.
##
## The breath is noise banded low and swung by a slow envelope; the joints are
## sparse clicks at IRREGULAR spacing. Regular spacing is the whole difference
## between a creature and a machine, and a metronome in the woods would read as
## a dripping pipe.
func _idle() -> PackedFloat32Array:
	var n := _n(9.0)
	var out := WAV.silence(n)

	# ---- breath ----
	var air := WAV.band(WAV.noise(n, 4177), RATE, 70.0, 760.0)
	var swing := PackedFloat32Array()
	swing.resize(n)
	for i in n:
		var t := float(i) / RATE
		# Two periods that do not divide into each other, so the breathing
		# never settles into a rhythm you can count.
		var a := 0.5 + 0.5 * sin(TAU * t / 3.1 - PI * 0.5)
		var b := 0.5 + 0.5 * sin(TAU * t / 4.7)
		swing[i] = pow(a * 0.75 + b * 0.25, 2.0)
	out = WAV.mix(out, WAV.apply(air, swing), 1.0)

	# ---- joints ----
	# Each click is a tiny hit rung at a body pitch. Low Q: a high one is a
	# tuned pipe, which is exactly the mistake the indoor footsteps made.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var at := 0.4
	while at < 8.6:
		var len := _n(0.09)
		var tick := WAV.apply(WAV.noise(len, rng.randi()), WAV.ad(len, RATE, 0.0008, 0.05, 3.0))
		tick = WAV.resonator(tick, RATE, rng.randf_range(140.0, 260.0), 2.4)
		out = WAV.mix(out, tick, rng.randf_range(0.5, 1.1), _n(at))
		at += rng.randf_range(0.55, 1.9)

	return _woods(out, 0.10)


# --------------------------------------------------------------- the one-offs

## Being decided about: an intake that rises and does not resolve.
func _notice() -> PackedFloat32Array:
	var n := _n(1.0)
	var breath := WAV.apply(WAV.noise(n, 771), WAV.ad(n, RATE, 0.035, 0.62, 1.6))
	breath = WAV.sweep_resonator(breath, RATE, 190.0, 1250.0, 4.5)

	# Weight under it, so it is a large thing noticing and not a small one.
	var body := WAV.apply(WAV.sweep(n, RATE, 84.0, 232.0), WAV.ad(n, RATE, 0.05, 0.5, 2.0))

	return _woods(WAV.mix(WAV.gain(breath, 1.0), body, 0.42), 0.16)


## The same gesture falling. Deliberately quieter and more air than the notice:
## losing you is not an event, it is the absence of one.
func _lose() -> PackedFloat32Array:
	var n := _n(1.4)
	var breath := WAV.apply(WAV.noise(n, 3312), WAV.ad(n, RATE, 0.09, 1.0, 1.3))
	breath = WAV.sweep_resonator(breath, RATE, 660.0, 132.0, 3.2)
	var body := WAV.apply(WAV.sweep(n, RATE, 150.0, 62.0), WAV.ad(n, RATE, 0.12, 0.9, 1.8))
	return _woods(WAV.gain(WAV.mix(breath, body, 0.38), 0.72), 0.18)


## Contact. A soft heavy impact with something much sharper on top of it --
## the impact is what happened, the shriek is what it means.
func _catch() -> PackedFloat32Array:
	var n := _n(1.3)

	var thump := WAV.apply(WAV.noise(n, 5501), WAV.ad(n, RATE, 0.001, 0.16, 3.0))
	thump = WAV.low_pass(thump, RATE, 900.0)
	var floorboard := WAV.apply(WAV.sweep(n, RATE, 96.0, 44.0), WAV.ad(n, RATE, 0.002, 0.3, 2.4))

	var shriek := WAV.apply(WAV.noise(n, 8123), WAV.ad(n, RATE, 0.004, 0.42, 1.8))
	shriek = WAV.sweep_resonator(shriek, RATE, 420.0, 2050.0, 7.0)

	var out := WAV.mix(thump, floorboard, 0.85)
	out = WAV.mix(out, shriek, 0.62)
	return _woods(out, 0.15)
