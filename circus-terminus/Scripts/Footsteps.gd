extends Node
## The player's own footsteps, picked from whichever surface they are standing
## on and fired in time with the head bob.
##
## TIMED OFF DISTANCE, NOT OFF A CLOCK. PlayerController accumulates `t_bob` as
## delta * horizontal speed, so it is metres walked, and a step is emitted every
## time that crosses a stride. Sprinting therefore speeds the cadence up and
## crouching slows it down for free, with no per-speed timers to keep in step
## with the movement code. A clock-driven version has to be retuned every time
## a speed constant moves, and drifts out of phase with the bob in between.
##
## The stride is one full bob cycle, and the step lands at the BOTTOM of it --
## the moment the camera is lowest is the moment the foot is down. Seeing the
## dip and hearing the foot at slightly different times is one of those faults
## nobody can name but everybody notices.

const SETS := ["out", "house", "cellar"]
## How many to look for before giving up. Not how many there are -- the count
## depends on the recording, and hard-coding it means a re-cut with more
## footfalls in it silently goes on using the first fifteen. Loading stops at
## the first gap, so the real number is whatever is on disk.
const MAX_PER_SET := 128

## How many can ring at once. The cellar steps are 866 ms long and the sprint
## cadence is about 420 ms, so three overlap down there; four leaves a spare so
## that a step is never cut off by the next one stealing its player.
const VOICES := 5

## Metres per footfall, and where in the bob cycle the foot lands. TAU / BOB_FREQ
## is one bob cycle -- about 2.1 m -- which at walking speed is a step every
## 0.62 s. PHASE is 3*PI/2 because that is where sin() is at its minimum, and
## _headbob puts the camera's lowest point there.
const PHASE := TAU * 0.75

## Loudness by gait, in dB against the file. Crouching is most of the stealth
## in this game, so it has to be properly quieter and not just slightly.
const DB_WALK := -20.0
const DB_SPRINT := -15.0
const DB_CROUCH := -25.0

## Random spread per step, so fifteen files do not start sounding like fifteen
## files. Small: a footstep that changes pitch by a semitone sounds like a
## different person each time.
const PITCH_SPREAD := 0.06
const DB_SPREAD := 1.5

@export var player_path := NodePath("..")

var _player: CharacterBody3D
var _banks := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last_index := -1
var _step := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as CharacterBody3D
	if _player == null:
		push_warning("Footsteps: no player at %s -- no steps will play." % player_path)
		set_process(false)
		return

	for _name: String in SETS:
		var bank: Array[AudioStream] = []
		for i in MAX_PER_SET:
			var path := "res://Audio/steps/%s_%02d.wav" % [_name, i]
			# Stop at the first gap rather than trying every index. The set is
			# however many files the cut produced.
			if not ResourceLoader.exists(path):
				break
			var s := load(path) as AudioStream
			if s != null:
				bank.append(s)
		if bank.is_empty():
			push_warning("Footsteps: no '%s' files in res://Audio/steps -- " % _name
				+ "run tools/cut_footsteps.gd.")
		_banks[_name] = bank

	@warning_ignore("static_called_on_instance")
	var bus := Sound.bus("Steps")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_voices.append(p)

	# Whatever the player is standing in when the level opens. Without this the
	# first step after a load is always the outdoor one, even in the cellar.
	_step = _stride_index()


func _process(_delta: float) -> void:
	if not _player.is_on_floor():
		# Airborne: hold the count where it is so landing does not fire the
		# three steps' worth of stride that accumulated during the jump.
		_step = _stride_index()
		return
	var now := _stride_index()
	if now == _step:
		return
	# Only ever one step per frame, however far the player was teleported.
	_step = now
	_play()


## Which stride the player is currently in. Floors the bob phase, offset so the
## boundary falls on the bottom of the bob rather than on the zero crossing.
func _stride_index() -> int:
	return floori((_player.t_bob * _player.BOB_FREQ - PHASE) / TAU)


func _play() -> void:
	var bank: Array = _banks.get(Sound.settings()["steps"], [])
	if bank.is_empty():
		return

	# Never the same file twice running. With fifteen to choose from a plain
	# random pick repeats about once every seven steps, and a repeat is the one
	# thing that gives away that these are samples.
	var index := _rng.randi_range(0, bank.size() - 1)
	if index == _last_index:
		index = (index + 1 + _rng.randi_range(0, bank.size() - 2)) % bank.size()
	_last_index = index

	var db := DB_WALK
	if _player.crouching:
		db = DB_CROUCH
	elif _player.sprinting:
		db = DB_SPRINT

	var voice := _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = bank[index]
	voice.pitch_scale = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	voice.volume_db = db + _rng.randf_range(-DB_SPREAD, DB_SPREAD)
	voice.play()
