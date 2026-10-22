class_name CarArrival
extends Node3D
## The car pulling up at the gate, for the opening cutscene.
##
## Not a vehicle. It is a prop on rails: Intro.gd calls arrive() and this
## slides it along the road, slows it into the kerb, kills the lights and
## opens a door's worth of sound and light. A VehicleBody3D would put the
## most scripted twenty seconds in the game at the mercy of the tyre friction
## model.
##
## Everything is driven off ONE curve -- the distance travelled -- so the
## wheels, the dust, the headlamp sweep and the brake lights cannot get out
## of step with each other however the timing is retuned.
##
## THE CHOREOGRAPHY IS IN THE ANIMATOR, not in here. Scenes/car.tscn has an
## AnimationPlayer with three animations on it and this script only starts
## them:
##
##   approach   the drive-up, one second long, the braking curve keyed into
##              it. `approach` below is the property it writes.
##   settle     the brake lights flaring as it comes to rest
##   shutdown   the beams dying, the dome lamp coming up for the driver and
##              then going out. It emits `arrived` and `door_closed` itself,
##              off a method track, at the frames those signals describe.
##
## What is left here is the things an animation cannot know: the PATH, which
## comes from start_point and stop_point and is different in every scene that
## uses the car, and the two timings the level exports. Scrubbing the arrival
## is a job for the animation panel now; retiming it is still a job for the
## inspector.
##
## Note that comments do not survive in a .tscn -- Godot rewrites the file on
## import and strips them -- which is why all of this is here and not next to
## the keyframes.

signal arrived
signal door_closed

## Where the car comes from and where it stops, in world space. Both are
## points ON the road; the car keeps its own height.
@export var start_point := Vector3(70.0, 0.0, 6.0)
@export var stop_point := Vector3(6.0, 0.0, 6.0)

## Seconds for the whole approach.
@export var travel_time := 7.5
## How long the lights stay on after it stops, before the driver kills them.
@export var idle_time := 2.2

## Where the car is along its approach: 0 at the far end of the road, 1 at the
## kerb. THE ANIMATOR WRITES THIS -- see the note at the top -- and the setter
## turns it into a world position between start_point and stop_point.
##
## It also does the roll bookkeeping, because the speed the wheels and the
## engine note want is the distance actually covered since the last frame, and
## this is the only place that knows it.
var approach := 0.0:
	set(value):
		approach = value
		if not is_inside_tree():
			return
		var before := global_position
		_place(value)
		_rolled = before.distance_to(global_position) / maxf(get_process_delta_time(), 0.0001)

@onready var _anim: AnimationPlayer = $Anim
@onready var _body: Node3D = $Body
@onready var _beam_l: SpotLight3D = $HeadBeamL
@onready var _beam_r: SpotLight3D = $HeadBeamR
@onready var _tail: OmniLight3D = $TailGlow
@onready var _cabin: OmniLight3D = $CabinGlow
@onready var _dust: GPUParticles3D = $Dust

var _wheels: Array[Node3D] = []
var _rolled := 0.0
var _driving := false

## True once the arrival has finished, or been skipped, whichever came first.
## Guards the two signals so they fire exactly once either way.
var _shut := false


func _ready() -> void:
	for n in _body.get_children():
		if n.name.begins_with("Wheel"):
			_wheels.append(n as Node3D)
	approach = 0.0
	_rolled = 0.0
	set_lights(false)


func _process(delta: float) -> void:
	# The engine follows _driving from here rather than from each of the three
	# places that set it -- arrive(), roll() and park() -- because a fourth will
	# be added one day and it will not be added to all three.
	_tick_engine()
	if not _driving:
		return
	# Spin the wheels off distance covered, not off time, so they stop dead
	# when the car does instead of freewheeling through the handbrake.
	for w in _wheels:
		w.rotate_x(_rolled / 0.36 * delta)


## Puts the car at `t` along the approach, 0 at the start, 1 at the kerb.
func _place(t: float) -> void:
	var here := start_point.lerp(stop_point, t)
	global_position = Vector3(here.x, global_position.y, here.z)
	# Point it down the road. looking_at wants a target, and at t=1 the two
	# points coincide, so aim at the stop point from wherever we are -- with
	# a fallback for the last frame.
	var dir := stop_point - start_point
	if dir.length_squared() > 0.001:
		look_at(global_position + dir.normalized(), Vector3.UP)


## Turns the wheels at `speed` metres per second without going anywhere.
##
## For the title screen, where the car stands still and the road streams past
## it. Everything else drives off the distance actually covered -- see the
## header -- and this is the one case where there is no distance to cover but
## the tyres still have to agree with the tarmac.
func roll(speed: float) -> void:
	_rolled = speed
	_driving = speed > 0.0


func set_lights(on: bool) -> void:
	_beam_l.visible = on
	_beam_r.visible = on
	_tail.visible = on
	_tail.light_energy = 1.4 if on else 0.0


## Drives in and stops. Awaited by the intro, so the cutscene can hold on the
## car until it has actually come to rest.
func arrive() -> void:
	_shut = false
	_driving = true
	set_lights(true)
	_dust.emitting = true

	# "approach" is one second long whatever travel_time says, so that the
	# export still decides how long the drive takes without anyone having to
	# move a keyframe. Put the speed back afterwards: the other two animations
	# are timed in real seconds.
	_anim.speed_scale = 1.0 / maxf(travel_time, 0.01)
	_anim.play(&"approach")
	await _anim.animation_finished
	_anim.speed_scale = 1.0

	# brake lights flare as it settles, then the dust catches up and dies
	_driving = false
	_rolled = 0.0
	_anim.play(&"settle")
	_dust.emitting = false

	await get_tree().create_timer(idle_time).timeout

	# The rest of it -- beams out, dome lamp up, hold, dome lamp out -- is one
	# animation, and it emits both signals off its own method track.
	_anim.play(&"shutdown")
	await door_closed


## Snaps to the end state: parked at the kerb, everything off. The intro
## calls this when the player skips, so a skipped cutscene leaves the same
## world behind as a watched one rather than a car halfway down the road with
## its headlights still on.
func park() -> void:
	for t in get_tree().get_processed_tweens():
		t.kill()
	_anim.stop()
	_driving = false
	_dust.emitting = false
	_place(1.0)
	_rolled = 0.0
	set_lights(false)
	_cabin.light_energy = 0.0
	_beam_l.light_energy = 0.0
	_beam_r.light_energy = 0.0
	# Stopping the player means "shutdown" never reaches its method track, so
	# the signals have to be fired from here or a skipped cutscene leaves
	# arrive() awaiting one that is never coming.
	if not _shut:
		_shut = true
		arrived.emit()
		door_closed.emit()


## Both of these are called from the "shutdown" animation's method track, at
## the frames the signals belong to. Nothing else should call them.
func _announce_arrived() -> void:
	arrived.emit()


func _announce_closed() -> void:
	set_lights(false)
	_shut = true
	door_closed.emit()


# ---------------------------------------------------------------- the engine
# A looping bed that follows _driving. The car is a prop on rails rather than a
# vehicle (see the note at the top), so there is nothing to derive a pitch from
# except the speed it is being told to roll at -- which is exactly what the
# wheels already use.

const ENGINE_DB := -13.0
const ENGINE_RANGE := 48.0
## How far the pitch moves between idling and travelling. Small: this is a car
## approaching at a steady speed, not one being driven hard.
const ENGINE_PITCH := 0.18
const ENGINE_FADE := 0.6

var _engine: AudioStreamPlayer3D


func _engine_on() -> void:
	if _engine != null and is_instance_valid(_engine):
		return
	var stream := Sound.sfx("car_loop")
	if stream == null:
		return

	_engine = AudioStreamPlayer3D.new()
	_engine.stream = stream
	@warning_ignore("static_called_on_instance")
	_engine.bus = Sound.bus("Sfx")
	_engine.max_distance = ENGINE_RANGE
	_engine.unit_size = 9.0
	_engine.volume_db = -80.0
	add_child(_engine)
	_engine.play()
	create_tween().tween_property(_engine, "volume_db", ENGINE_DB, ENGINE_FADE)


func _engine_off() -> void:
	if _engine == null or not is_instance_valid(_engine):
		return
	var dying := _engine
	_engine = null
	var t := create_tween()
	t.tween_property(dying, "volume_db", -80.0, ENGINE_FADE)
	t.tween_callback(dying.queue_free)


func _tick_engine() -> void:
	if _driving:
		_engine_on()
		if _engine != null and is_instance_valid(_engine):
			# Faster wheels, slightly higher note.
			_engine.pitch_scale = 1.0 + ENGINE_PITCH * clampf(_rolled / 14.0, 0.0, 1.2)
	else:
		_engine_off()
