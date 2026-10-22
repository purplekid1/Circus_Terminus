extends SceneTree
## Synthesises the game's sound effects into Audio/sfx/.
##
##     godot --headless --path . --script tools/gen_sfx.gd
##
## These are BUILT, not recorded, for the same reason the geometry is: there is
## no recording of them in the project and no ffmpeg on this machine to cut one
## with. The upside is that every sound is a sentence about what the object
## physically does, and when one is wrong you argue with the sentence and
## re-run, rather than going to look for a different .wav.
##
## The vocabulary is small on purpose:
##   a hit     = noise through an attack-decay envelope
##   a body    = that hit rung through a resonator at the object's own pitch
##   a room    = reverb, sized to where the object lives
##   a creak   = friction, which is many tiny hits at a sliding pitch
##   an engine = a pulse train at the firing rate, plus hum, plus intake noise
##
## KEEP THE RESONATOR Q LOW unless the thing really is a tube. A high Q is a
## pure tone that rings for a tenth of a second, and it is what made the indoor
## footsteps sound like pipes hitting the floor -- see the note on the house
## recipe in cut_footsteps.gd, and measure with tools/ringtime.gd.

const WAV := preload("res://tools/wavlib.gd")
## NOT Audio/sfx any more. The synthesised effects were replaced with library
## recordings -- see tools/cut_sfx.gd -- and this script is kept because the
## engine and creak recipes are worth having, not because the game uses them.
## Writing to the live folder would quietly overwrite the real ones.
const OUT := "res://Audio/sfx_synth"
const RATE := 44100


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var made := 0
	for entry: Array in [
		["door_open", _door_open()],
		["door_close", _door_close()],
		["door_locked", _door_locked()],
		["gate_open", _gate_open()],
		["interact", _interact()],
		["pickup", _pickup()],
		["drop", _drop()],
		["generator_start", _generator_start()],
		["generator_loop", _generator_loop()],
		["generator_stop", _generator_stop()],
		["car_loop", _car_loop()],
	]:
		var name: String = entry[0]
		var s: PackedFloat32Array = entry[1]
		s = WAV.normalise(s, 0.86)
		# A loop must not be faded at its ends -- that is the joint, and a fade
		# there is the dip the crossfade in loopify exists to avoid.
		if not name.ends_with("_loop"):
			s = WAV.trim_tail(s, RATE, -62.0)
			s = WAV.fade(s, RATE, 1.0, 12.0)
		WAV.write(ProjectSettings.globalize_path("%s/%s.wav" % [OUT, name]), s, RATE)
		print("  %-17s %6.2f s   peak %.2f" % [name, float(s.size()) / RATE, WAV.peak(s)])
		made += 1

	print("wrote %d sound effects to %s" % [made, OUT])
	quit()


func _n(seconds: float) -> int:
	return int(RATE * seconds)


# --------------------------------------------------------------------- doors

## Friction, then the leaf swinging. The creak slides UP as the hinge turns:
## the contact patch shortens as the door opens, and short things ring higher.
func _door_open() -> PackedFloat32Array:
	var n := _n(1.15)
	var rough := WAV.apply(WAV.noise(n, 11), WAV.ad(n, RATE, 0.02, 1.1, 1.4))

	# Stick-slip. Friction is not steady -- it grabs and lets go, many times a
	# second. Without this modulation the creak is a smooth hiss and reads as
	# wind rather than as wood under load.
	var grab := WAV.low_pass(WAV.noise(n, 12), RATE, 9.0)
	for i in n:
		rough[i] *= 0.35 + 1.4 * absf(grab[i])

	var creak := WAV.sweep_resonator(rough, RATE, 210.0, 520.0, 9.0)
	creak = WAV.peaking(creak, RATE, 1400.0, 1.2, 3.0)

	# The leaf itself, a low note under the friction.
	var body := WAV.apply(WAV.noise(n, 13), WAV.ad(n, RATE, 0.01, 0.5, 2.0))
	body = WAV.resonator(body, RATE, 92.0, 5.0)

	var out := WAV.mix(creak, body, 0.55)
	out = WAV.low_pass(out, RATE, 7000.0)
	return WAV.reverb(out, RATE, 0.55, 2600.0, 0.16, 0.38)


## Three events, not one: the swing, the leaf meeting the frame, the latch
## dropping. A door close that is a single thud sounds like a dropped box.
func _door_close() -> PackedFloat32Array:
	var swing := WAV.apply(WAV.noise(_n(0.5), 21), WAV.ad(_n(0.5), RATE, 0.04, 0.34, 1.2))
	swing = WAV.sweep_resonator(swing, RATE, 430.0, 190.0, 7.0)

	var thud := WAV.apply(WAV.noise(_n(0.5), 22), WAV.ad(_n(0.5), RATE, 0.001, 0.26, 2.6))
	thud = WAV.resonator(thud, RATE, 78.0, 5.0)
	thud = WAV.mix(thud, WAV.resonator(thud, RATE, 165.0, 6.0), 0.5)

	var latch := WAV.apply(WAV.noise(_n(0.14), 23), WAV.ad(_n(0.14), RATE, 0.0005, 0.05, 3.0))
	latch = WAV.high_pass(latch, RATE, 1800.0)
	latch = WAV.resonator(latch, RATE, 3100.0, 8.0)

	var out := WAV.gain(swing, 0.5)
	out = WAV.mix(out, thud, 1.0, _n(0.34))
	out = WAV.mix(out, latch, 0.45, _n(0.40))
	return WAV.reverb(out, RATE, 0.55, 2400.0, 0.18, 0.40)


## Handle down, handle up, and nothing happens. This has to read differently
## from a door opening or the player will simply press again.
func _door_locked() -> PackedFloat32Array:
	var out := WAV.silence(_n(0.7))
	for beat: Array in [[0.0, 1.0], [0.16, 0.8], [0.30, 0.55]]:
		var at: float = beat[0]
		var level: float = beat[1]
		var k := _n(0.10)
		var click := WAV.apply(WAV.noise(k, 31 + int(at * 100.0)),
			WAV.ad(k, RATE, 0.0005, 0.035, 3.2))
		click = WAV.high_pass(click, RATE, 900.0)
		click = WAV.resonator(click, RATE, 2400.0, 7.0)
		out = WAV.mix(out, click, level, _n(at))

	# The dull bar behind the rattle: the leaf moving two millimetres and
	# stopping against the bolt.
	var stop := WAV.apply(WAV.noise(_n(0.3), 39), WAV.ad(_n(0.3), RATE, 0.002, 0.16, 2.2))
	stop = WAV.resonator(stop, RATE, 110.0, 5.0)
	out = WAV.mix(out, stop, 0.6, _n(0.30))
	return WAV.reverb(out, RATE, 0.5, 2200.0, 0.14, 0.36)


## Iron rather than wood: higher, longer, and it rings on after it has stopped
## moving. This is the one place a slightly higher Q is honest, because bars
## genuinely are tubes.
func _gate_open() -> PackedFloat32Array:
	var n := _n(1.4)
	var rough := WAV.apply(WAV.noise(n, 41), WAV.ad(n, RATE, 0.02, 1.3, 1.2))
	var grab := WAV.low_pass(WAV.noise(n, 42), RATE, 7.0)
	for i in n:
		rough[i] *= 0.3 + 1.6 * absf(grab[i])
	var creak := WAV.sweep_resonator(rough, RATE, 380.0, 940.0, 13.0)

	var ring := WAV.apply(WAV.noise(_n(0.9), 43), WAV.ad(_n(0.9), RATE, 0.001, 0.7, 1.6))
	ring = WAV.resonator(ring, RATE, 1650.0, 18.0)
	ring = WAV.mix(ring, WAV.resonator(ring, RATE, 2480.0, 15.0), 0.6)

	var out := WAV.mix(creak, ring, 0.26, _n(0.1))
	return WAV.reverb(out, RATE, 0.9, 2000.0, 0.26, 0.52)


# --------------------------------------------------------------------- hands

## A soft, short tick. This fires on everything the player touches, so it has
## to be nearly nothing: a sound you only notice when it is missing.
func _interact() -> PackedFloat32Array:
	var k := _n(0.10)
	var tick := WAV.apply(WAV.noise(k, 51), WAV.ad(k, RATE, 0.0008, 0.04, 3.0))
	tick = WAV.band(tick, RATE, 900.0, 4200.0)
	tick = WAV.mix(tick, WAV.resonator(tick, RATE, 1450.0, 5.0), 0.5)
	return WAV.reverb(tick, RATE, 0.4, 3000.0, 0.10, 0.24)


## Cloth and a small hard thing: the hand closing, then the object settling
## into the bag.
func _pickup() -> PackedFloat32Array:
	var n := _n(0.45)
	var cloth := WAV.apply(WAV.noise(n, 61), WAV.ad(n, RATE, 0.01, 0.18, 1.6))
	cloth = WAV.band(cloth, RATE, 1400.0, 7000.0)

	var chime := WAV.apply(WAV.noise(_n(0.3), 62), WAV.ad(_n(0.3), RATE, 0.001, 0.20, 2.0))
	chime = WAV.resonator(chime, RATE, 2050.0, 14.0)
	chime = WAV.mix(chime, WAV.resonator(chime, RATE, 3070.0, 12.0), 0.45)

	var out := WAV.mix(WAV.gain(cloth, 0.7), chime, 0.5, _n(0.04))
	return WAV.reverb(out, RATE, 0.45, 2800.0, 0.12, 0.28)


## The same event the other way round: a duller thing arriving on a floor.
func _drop() -> PackedFloat32Array:
	var n := _n(0.4)
	var thud := WAV.apply(WAV.noise(n, 71), WAV.ad(n, RATE, 0.001, 0.14, 2.6))
	thud = WAV.resonator(thud, RATE, 150.0, 6.0)
	thud = WAV.mix(thud, WAV.resonator(thud, RATE, 340.0, 7.0), 0.4)

	var scuff := WAV.apply(WAV.noise(_n(0.2), 72), WAV.ad(_n(0.2), RATE, 0.004, 0.09, 2.0))
	scuff = WAV.band(scuff, RATE, 1200.0, 5000.0)

	var out := WAV.mix(thud, scuff, 0.3, _n(0.02))
	return WAV.reverb(out, RATE, 0.5, 2400.0, 0.14, 0.32)


# ------------------------------------------------------------------ machines

## One firing stroke of a small engine: a hard pulse into a resonant body.
func _stroke(seed: int, pitch: float, hardness: float) -> PackedFloat32Array:
	var k := _n(0.09)
	var fire := WAV.apply(WAV.noise(k, seed), WAV.ad(k, RATE, 0.0006, 0.030, 2.4))
	fire = WAV.resonator(fire, RATE, pitch, 6.0)
	fire = WAV.mix(fire, WAV.resonator(fire, RATE, pitch * 2.6, 8.0), hardness)
	return fire


## The generator running, as a seamless loop. An exact number of firing strokes
## so the ends nearly meet, then loopify to hide whatever is left over.
func _generator_loop() -> PackedFloat32Array:
	# Twenty-one strokes at a tenth of a second is about eight a second: a slow,
	# labouring single-cylinder, not a lawnmower.
	var strokes := 21
	var period := 0.1
	var n := _n(strokes * period + 0.4)
	var out := WAV.silence(n)
	for i in strokes:
		# Never exactly on the beat. A perfectly regular engine is a metronome,
		# and this one is meant to be old and badly maintained.
		var jitter := sin(i * 2.3) * 0.004
		out = WAV.mix(out, _stroke(100 + i, 118.0 + sin(i * 1.7) * 4.0, 0.5),
			0.85, _n(i * period + jitter))

	# Hum off the alternator, and the casing buzzing with it.
	out = WAV.mix(out, WAV.tone(n, RATE, 50.0, "sine"), 0.22)
	out = WAV.mix(out, WAV.tone(n, RATE, 100.0, "saw"), 0.06)
	out = WAV.mix(out, WAV.band(WAV.noise(n, 199), RATE, 300.0, 3400.0), 0.10)

	out = WAV.low_pass(out, RATE, 5200.0)
	out = WAV.reverb(out, RATE, 0.9, 1800.0, 0.22, 0.48)
	return WAV.loopify(out, RATE, 0.25)


## Three slow turns that do not catch, one that does, then it settles.
func _generator_start() -> PackedFloat32Array:
	var out := WAV.silence(_n(2.6))
	for i in 3:
		var at := 0.10 + i * 0.42
		var crank := WAV.apply(WAV.noise(_n(0.34), 150 + i),
			WAV.ad(_n(0.34), RATE, 0.02, 0.26, 1.4))
		crank = WAV.sweep_resonator(crank, RATE, 150.0, 70.0, 6.0)
		out = WAV.mix(out, crank, 0.8, _n(at))

	out = WAV.mix(out, _stroke(180, 110.0, 0.6), 1.0, _n(1.45))
	for i in 9:
		out = WAV.mix(out, _stroke(190 + i, 100.0 + i * 2.2, 0.5),
			0.5 + 0.05 * i, _n(1.55 + i * 0.105))

	var hum := WAV.apply(WAV.tone(_n(1.1), RATE, 50.0, "sine"),
		WAV.ad(_n(1.1), RATE, 0.6, 2.0, 1.0))
	out = WAV.mix(out, hum, 0.20, _n(1.5))

	out = WAV.low_pass(out, RATE, 5200.0)
	return WAV.reverb(out, RATE, 0.9, 1800.0, 0.22, 0.48)


## Firing slower and slower, then one last half-turn, then nothing.
func _generator_stop() -> PackedFloat32Array:
	var out := WAV.silence(_n(1.9))
	var t := 0.0
	var step := 0.10
	for i in 8:
		out = WAV.mix(out, _stroke(300 + i, 118.0 - i * 7.0, 0.45),
			0.85 - 0.08 * i, _n(t))
		t += step
		step *= 1.22

	var hum := WAV.apply(WAV.tone(_n(1.0), RATE, 50.0, "sine"),
		WAV.ad(_n(1.0), RATE, 0.01, 0.8, 1.6))
	out = WAV.mix(out, hum, 0.18)

	out = WAV.low_pass(out, RATE, 4200.0)
	return WAV.reverb(out, RATE, 0.9, 1800.0, 0.22, 0.48)


## The car idling on the drive. Four cylinders, so a much faster and smoother
## stroke rate than the generator, with body and tyre noise underneath.
func _car_loop() -> PackedFloat32Array:
	var strokes := 30
	var period := 0.037
	var n := _n(strokes * period + 0.3)
	var out := WAV.silence(n)
	for i in strokes:
		out = WAV.mix(out, _stroke(400 + i, 74.0 + sin(i * 0.9) * 2.0, 0.28),
			0.7, _n(i * period))

	out = WAV.mix(out, WAV.tone(n, RATE, 27.0, "sine"), 0.35)
	out = WAV.mix(out, WAV.tone(n, RATE, 54.0, "saw"), 0.10)
	out = WAV.mix(out, WAV.band(WAV.noise(n, 499), RATE, 120.0, 1800.0), 0.16)

	out = WAV.low_pass(out, RATE, 3200.0)
	return WAV.loopify(out, RATE, 0.20)
