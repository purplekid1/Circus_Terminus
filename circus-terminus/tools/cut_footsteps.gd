extends SceneTree
## Cuts Audio/source/footsteps_raw.wav into single footfalls, then bakes each
## one three times over -- once per surface the player walks on.
##
##     godot --headless --path . --script tools/cut_footsteps.gd
##
## The recording is one continuous take of somebody walking: fifteen footfalls
## about 0.69 s apart, peaking at -24 dBFS. It cannot be used as-is. A looping
## take gives every step the same length and the same cadence no matter how
## fast the player is moving, and at that level it sits under the ambience.
##
## WHY THREE SETS RATHER THAN ONE SET THROUGH A FILTER AT RUNTIME. A bus effect
## can make a sound duller, and duller is not what a different floor is. Boards
## ring at 180 Hz and gravel does not; a cellar answers back off the far wall
## 60 ms later and a lawn has nothing to answer with. Those are different
## sounds, so they are baked as different files. The runtime filtering is saved
## for the ambience, where "the same thing heard through a wall" IS the effect.

const WAV := preload("res://tools/wavlib.gd")

const SRC := "res://Audio/source/footsteps_raw.wav"
const OUT := "res://Audio/steps"

## Fraction of the file's loudest moment that counts as the start of a step.
const ONSET_FRAC := 0.15
## No second onset within this long.
##
## 0.30, NOT THE 0.12 THIS STARTED AT. These are boots, and a boot lands heel
## first and then toe about 0.12 s later. At the old lockout the detector called
## that two footsteps and cut 48 "steps" out of 29, half of them a toe-slap with
## no heel in front of it. The real gap between footfalls in this take is
## 0.65-0.82 s, so a third of a second merges the heel and the toe without any
## chance of merging two steps.
const LOCKOUT := 0.30

## A little of the room before the transient. Cutting exactly on the peak
## removes the attack, which is the part that makes it read as a foot.
const PRE := 0.012
## How far the tail is followed before it is called finished, and the floor it
## has to fall below -- relative to that step's own peak, because the steps are
## not all the same loudness.
const MAX_TAIL := 0.55
const TAIL_FLOOR := 0.035
## The decay hunt does not begin until this far in, and a dip has to stay quiet
## this long to count as the end. Both are sized around the heel-to-toe gap: a
## boot goes quiet in between, and a shorter window ends the slice there and
## throws the toe away.
const TAIL_AFTER := 0.20
const TAIL_QUIET := 0.07

## The expander that follows the normalise. Anything below a fortieth of full
## scale is room tone rather than shoe, and gets pushed down twice as far as it
## already is.
const GATE_AT := 0.040
const GATE_RATIO := 2.5

## Every surface is normalised to roughly the same peak so that walking from
## the lawn into the hall is a change of character, not a change of volume.
## The differences that remain are deliberate: stone is loudest, carpet and
## furniture eat the house, outdoors has nothing to reflect off.

## name, and the recipe. Read this as a sentence: what the floor does to a shoe.
## THE SOURCE IS A MIDRANGE THUD. Measure it before touching these numbers:
## 53% of its energy sits between 250 Hz and 1 kHz, only 4% above 2 kHz, and
## almost nothing below 120 Hz. That is why the recipes are as aggressive as
## they are. A first pass used gentle, sensible-looking values -- a 6 dB lift
## here, a 3 dB cut there -- and measured out almost identical to the raw file,
## because it was politely adjusting bands the recording has no content in.
## To make one take sound like three floors you have to scoop the band it
## actually lives in and build the new character somewhere else.
##
## name, and the recipe. Read each as a sentence: what the floor does to a shoe.
const SURFACES := [
	{
		"name": "out",
		## Gravel, cold wet grass, open air. No boom -- there is nothing outside
		## to resonate -- so the low end goes, the source's own thud is scooped
		## out, and the character is rebuilt as scatter: band-limited noise
		## shaped by the hit, which is what loose material moving under a sole
		## actually is. Pitched up slightly so it lands lighter.
		##
		## SCATTER WAS 0.85 AND HAD NO DECAY, and that is what "a ton of
		## background sound" in the outdoor steps was: noise running for the
		## whole 160 ms tail, measuring 30 dB more high-frequency energy than
		## the other two sets. It is 0.30 now and dies over 45 ms, so the grit
		## is on the impact where it belongs. The 3 kHz lift came down with it
		## -- at +8 it was amplifying the same noise a second time.
		"pitch": 0.94,
		"hp": 200.0,
		"lp": 13000.0,
		"eq": [[700.0, 1.0, -4.0], [3000.0, 0.8, 4.5]],
		"ring": [],
		"scatter": [0.60, 2200.0, 9500.0, 0.028],
		"slap": [],
		"verb": [0.30, 4000.0, 0.05, 0.15],
		"gain": 0.85,
	},
	{
		"name": "house",
		## Boots on parquet in a furnished room -- and the recording IS boots on
		## parquet, so the floor is already in it. Very little is done here
		## beyond putting a room around the take.
		##
		## THERE WERE TWO HIGH-Q RESONATORS HERE, at 150 Hz and 330 Hz, built to
		## make a wooden floor out of a recording that had no wood in it. Against
		## a source that is already wood they stacked straight on top: 68% of
		## every step's energy ended up inside a narrow band at 150 Hz, ringing
		## for 325 ms. That is not a floorboard, it is a struck pipe, and that is
		## what it sounded like. tools/ringtime.gd measures exactly this, and it
		## is worth re-running after any change to the resonances.
		"pitch": 1.0,
		"hp": 45.0,
		"lp": 6200.0,
		"eq": [[165.0, 0.9, -1.5], [900.0, 1.0, -2.5], [2600.0, 1.0, -2.0]],
		"ring": [],
		"scatter": [],
		"slap": [],
		"verb": [0.45, 2800.0, 0.18, 0.30],
		"gain": 0.82,
	},
	{
		"name": "cellar",
		## Bare stone, hard parallel walls, nothing in the room to absorb
		## anything. Dull on top because there is no soft material to scatter
		## into, heavy underneath, and it answers back: the slapback at 68 ms is
		## the far wall about eleven metres off, with the reverb behind it doing
		## the rest of the room. Pitched down so the same boot lands heavier down
		## here than it does upstairs.
		##
		## The weight is filtering and the slapback, NOT a resonator. There was a
		## high-Q ring at 85 Hz here doing the same pipe trick as the house set,
		## more quietly -- 35% of the energy in one narrow band.
		"pitch": 1.08,
		"hp": 30.0,
		"lp": 3400.0,
		"eq": [[90.0, 1.0, 4.5], [240.0, 1.2, 2.0], [700.0, 1.0, -3.5]],
		"ring": [],
		"scatter": [],
		"slap": [0.068, 0.50, 2000.0],
		"verb": [1.15, 1600.0, 0.45, 0.68],
		"gain": 0.80,
	},
]


func _initialize() -> void:
	var w := WAV.read(SRC)
	if w.is_empty():
		quit(1)
		return
	var src: PackedFloat32Array = w["samples"]
	var rate: int = w["rate"]
	print("source: %.2f s, %d Hz, peak %.3f" % [float(src.size()) / rate, rate, WAV.peak(src)])

	var cuts := _find_steps(src, rate)
	print("found %d footfalls" % cuts.size())
	if cuts.is_empty():
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# Wipe first. The number of footfalls changes with the source -- this take
	# yields 29 where the last one yielded 15 -- and files left over from a
	# previous run are still loadable, so the game would go on playing steps cut
	# from a recording that is no longer in the project.
	var dir := DirAccess.open(ProjectSettings.globalize_path(OUT))
	var wiped := 0
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".wav") or f.ends_with(".wav.import"):
				dir.remove(f)
				wiped += 1
	if wiped > 0:
		print("cleared %d old files" % wiped)

	var written := 0
	for recipe: Dictionary in SURFACES:
		var lengths := 0.0
		for i in cuts.size():
			var s: PackedFloat32Array = cuts[i]
			s = _apply(s, rate, recipe, i)
			var path := "%s/%s_%02d.wav" % [OUT, recipe["name"], i]
			WAV.write(ProjectSettings.globalize_path(path), s, rate)
			lengths += float(s.size()) / rate
			written += 1
		print("  %-7s %2d files, mean %.0f ms"
			% [recipe["name"], cuts.size(), 1000.0 * lengths / cuts.size()])

	print("wrote %d files to %s" % [written, OUT])
	quit()


## Slices the take into one array per footfall, each already normalised and
## faded so the surface passes start from a clean, level hit.
func _find_steps(src: PackedFloat32Array, rate: int) -> Array:
	var env := WAV.envelope(src, int(rate * 0.005))
	var thresh := WAV.peak(env) * ONSET_FRAC
	var lockout := int(rate * LOCKOUT)

	var onsets := PackedInt32Array()
	var last := -lockout
	for i in env.size():
		if env[i] > thresh and i - last > lockout:
			onsets.append(i)
			last = i

	var pre := int(rate * PRE)
	var out := []
	for k in onsets.size():
		var start := maxi(onsets[k] - pre, 0)
		# Never run into the next footfall, however long the tail is.
		var limit := int(rate * MAX_TAIL)
		if k + 1 < onsets.size():
			limit = mini(limit, onsets[k + 1] - int(rate * 0.02) - start)
		limit = mini(limit, src.size() - start)

		# Follow the decay: stop once the envelope has been under this step's
		# own floor for a moment, rather than padding every slice to MAX_TAIL
		# with room tone.
		var hit_peak := 0.0
		for i in range(start, start + limit):
			hit_peak = maxf(hit_peak, env[i])
		var floor_at := hit_peak * TAIL_FLOOR
		var length := limit
		var quiet := 0
		for i in range(start + int(rate * TAIL_AFTER), start + limit):
			quiet = quiet + 1 if env[i] < floor_at else 0
			if quiet > int(rate * TAIL_QUIET):
				length = i - start
				break

		var slice := src.slice(start, start + length)
		slice = WAV.normalise(slice, 0.9)
		# Then pull the floor back down. Normalising by 15x lifted the room
		# tone with the footstep; this puts it back where it was without
		# touching the hit or its decay.
		slice = WAV.gate(slice, rate, GATE_AT, GATE_RATIO, 1.0, 60.0)
		out.append(WAV.fade(slice, rate, 2.0, 18.0))
	return out


func _apply(s: PackedFloat32Array, rate: int, r: Dictionary, index: int) -> PackedFloat32Array:
	if r["pitch"] != 1.0:
		s = WAV.resample(s, r["pitch"])
	s = WAV.high_pass(s, rate, r["hp"])
	s = WAV.low_pass(s, rate, r["lp"])
	for band: Array in r["eq"]:
		s = WAV.peaking(s, rate, band[0], band[1], band[2])
	var rg: Array = r["ring"]
	if not rg.is_empty():
		s = WAV.ring(s, rate, rg, 0.32)
	var sc: Array = r["scatter"]
	if not sc.is_empty():
		# Seeded off the step index so the grit differs from step to step but
		# the build is still reproducible.
		s = WAV.scatter(s, rate, sc[0], sc[1], sc[2], 1000 + index, sc[3])
	var sl: Array = r["slap"]
	if not sl.is_empty():
		s = WAV.slapback(s, rate, sl[0], sl[1], sl[2])
	var v: Array = r["verb"]
	s = WAV.reverb(s, rate, v[0], v[1], v[2], v[3])
	s = WAV.normalise(s, r["gain"])
	s = WAV.trim_tail(s, rate, -60.0)
	return WAV.fade(s, rate, 1.0, 25.0)
