extends SceneTree
## The big top door coming down, and the switch that drops it.
##
##     godot --headless --path . --script tools/gen_door_sfx.gd
##
## Synthesised rather than downloaded for the same reason the creature is: what
## is wanted here is not "a door" but a nine-metre braced door coming off its
## hinges onto dirt, and there is no library recording of that. The ordinary
## doors in the house are library files, and should stay that way.
##
## Levelled to peak 0.72, the same as everything else in Audio/sfx -- see the
## note in tools/cut_sfx.gd. Changing it here and not there is how one set of
## effects ends up quietly twice as loud as the rest of the game.

const WAV := preload("res://tools/wavlib.gd")
const OUT := "res://Audio/sfx"
const RATE := 44100
const TARGET := 0.72


func _initialize() -> void:
	var made := 0
	for entry: Array in [
		["door_fall", _door_fall()],
		["lever", _lever()],
	]:
		var name: String = entry[0]
		var s: PackedFloat32Array = entry[1]
		s = WAV.normalise(s, TARGET)
		s = WAV.trim_tail(s, RATE, -62.0)
		s = WAV.fade(s, RATE, 1.0, 14.0)
		WAV.write(ProjectSettings.globalize_path("%s/%s.wav" % [OUT, name]), s, RATE)
		print("  %-12s %5.2f s   peak %.2f" % [name, float(s.size()) / RATE, WAV.peak(s)])
		made += 1
	print("wrote %d door sounds to %s" % [made, OUT])
	quit()


func _n(seconds: float) -> int:
	return int(RATE * seconds)


## Nine metres of braced timber hitting dirt.
##
## Four things happen at once and the order of them is what makes it read as
## heavy rather than loud:
##
##   the crack   the boards flexing past their limit -- fast, bright, first
##   the slam    the flat of the panel hitting, which is the actual event
##   the body    what a big hollow thing does after it lands
##   the settle  planks knocking, a half second late, at random
##
## A single loud hit with no settle sounds like a gunshot. The tail is what
## says the thing that fell was made of parts.
func _door_fall() -> PackedFloat32Array:
	var n := _n(2.6)

	# The slam: broadband, killed off fast, then held down low. This is the
	# frequency range a heavy flat surface actually puts into the ground.
	var slam := WAV.apply(WAV.noise(n, 2291), WAV.ad(n, RATE, 0.002, 0.34, 2.6))
	slam = WAV.low_pass(slam, RATE, 520.0)

	# The floor taking it. A short pitch drop is what gives an impact its size.
	var body := WAV.apply(WAV.sweep(n, RATE, 78.0, 34.0), WAV.ad(n, RATE, 0.004, 0.52, 2.2))

	# The crack of the boards, bright and over in a tenth of a second.
	var crack := WAV.apply(WAV.noise(n, 6607), WAV.ad(n, RATE, 0.0006, 0.085, 3.4))
	crack = WAV.band(crack, RATE, 700.0, 4200.0)

	var out := WAV.mix(slam, body, 0.95)
	out = WAV.mix(out, crack, 0.55)

	# The settle: five smaller knocks, scattered over the next second and a bit,
	# each one a plank dropping onto the one under it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 40404
	for i in 5:
		var m := _n(0.22)
		var knock := WAV.apply(WAV.noise(m, rng.randi()), WAV.ad(m, RATE, 0.001, 0.09, 3.0))
		knock = WAV.resonator(knock, RATE, rng.randf_range(110.0, 240.0), 2.2)
		out = WAV.mix(out, knock, rng.randf_range(0.18, 0.42), _n(rng.randf_range(0.28, 1.5)))

	# Outdoors and large: a long tail at a very low wet mix. Open air returns
	# almost nothing, it just returns it late.
	return WAV.reverb(out, RATE, 0.85, 1800.0, 0.16, 0.55)


## A knife switch being thrown. Two pieces of iron meeting, with the spring.
func _lever() -> PackedFloat32Array:
	var n := _n(0.45)
	var hit := WAV.apply(WAV.noise(n, 1777), WAV.ad(n, RATE, 0.0006, 0.055, 3.2))
	# Low Q on both. A high one is a tuned pipe, which is the mistake that made
	# the indoor footsteps sound like plumbing -- see cut_footsteps.gd.
	hit = WAV.ring(hit, RATE, [[340.0, 3.0, 0.5], [880.0, 2.4, 0.3]], 0.25)
	var spring := WAV.apply(WAV.noise(n, 9021), WAV.ad(n, RATE, 0.004, 0.13, 2.0))
	spring = WAV.band(spring, RATE, 1400.0, 5200.0)
	return WAV.mix(hit, spring, 0.22)
