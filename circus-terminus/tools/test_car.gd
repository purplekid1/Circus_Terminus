extends SceneTree
## The arrival, end to end.
##
## The drive-up used to be four tweens and three awaits inside CarArrival.gd
## and nothing covered it; it is three animations on an AnimationPlayer now and
## the script only starts them. That move can fail QUIETLY in two ways a
## compile will not catch -- a value track pointed at a property or a node that
## has been renamed writes nothing and says nothing, and a method track with a
## typo in it never fires -- so this drives a real car down a real road and
## watches what the lamps actually do.
##
## Real time, not frame counts: the animations are timed in seconds.

var _car: Node3D
var _park_car: Node3D
var _t := 0.0
var _stage := -1
var _pass := 0
var _fail := 0

var _arrived := 0
var _closed := 0
var _saw_midway := false
var _saw_beams := false
var _saw_dust := false
var _saw_cabin := false
var _park_arrived := 0
var _park_closed := 0

## Short enough to keep the test quick. "shutdown" is a fixed 2.65 s and is not
## scaled by anything, so that is the floor on how fast this can run.
const TRAVEL := 0.5
const IDLE := 0.1
const STOP := Vector3(0, 0, -20)


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	print("CAR %s  %s" % ["PASS" if cond else "FAIL", label])


func _build() -> Node3D:
	var car := (load("res://Scenes/car.tscn") as PackedScene).instantiate()
	car.set("start_point", Vector3.ZERO)
	car.set("stop_point", STOP)
	car.set("travel_time", TRAVEL)
	car.set("idle_time", IDLE)
	get_root().add_child(car)
	return car


## Deliberately NOT _initialize(). A node added to the root from there does not
## get _ready() before the loop starts, so every @onready on the car is still
## null and set_lights() assigns to Nil. Build it on the first frame instead.
func _process(delta: float) -> bool:
	_t += delta

	if _stage == -1:
		_car = _build()
		_car.arrived.connect(func() -> void: _arrived += 1)
		_car.door_closed.connect(func() -> void: _closed += 1)
		_ok("it starts at start_point", _car.global_position.distance_to(Vector3.ZERO) < 0.01)
		_ok("and the animator is on it", _car.get_node_or_null("Anim") != null)
		var anim := _car.get_node("Anim") as AnimationPlayer
		for want in ["approach", "settle", "shutdown"]:
			_ok("\"%s\" is in the library" % want, anim.has_animation(want))
		_car.arrive()
		_stage = 0
		_t = 0.0
		return false

	if _stage == 0:
		# Everything the drive is supposed to look like, sampled while it runs.
		var a: float = _car.get("approach")
		if a > 0.05 and a < 0.95:
			_saw_midway = true
		if (_car.get_node("HeadBeamL") as SpotLight3D).visible:
			_saw_beams = true
		if (_car.get_node("Dust") as GPUParticles3D).emitting:
			_saw_dust = true
		if (_car.get_node("CabinGlow") as OmniLight3D).light_energy > 0.5:
			_saw_cabin = true
		if _t < TRAVEL + IDLE + 2.65 + 0.6:
			return false

		_ok("the animator moved it down the road", _saw_midway)
		_ok("it reached the kerb", absf(float(_car.get("approach")) - 1.0) < 0.001)
		_ok("and stopped on stop_point", _car.global_position.distance_to(STOP) < 0.05)
		_ok("the beams were lit on the way in", _saw_beams)
		_ok("and it kicked up dust", _saw_dust)
		_ok("the dust stopped when it did", not (_car.get_node("Dust") as GPUParticles3D).emitting)
		_ok("the dome lamp came on for the driver", _saw_cabin)
		# The method track is the only thing that emits these.
		_ok("`arrived` fired, once", _arrived == 1)
		_ok("`door_closed` fired, once", _closed == 1)
		_ok("the beams are out", (_car.get_node("HeadBeamL") as SpotLight3D).light_energy < 0.01)
		_ok("the tail is out", (_car.get_node("TailGlow") as OmniLight3D).light_energy < 0.01)
		_ok("the dome lamp is out", (_car.get_node("CabinGlow") as OmniLight3D).light_energy < 0.01)

		# A skipped cutscene has to leave the same world behind as a watched one.
		_park_car = _build()
		_park_car.arrived.connect(func() -> void: _park_arrived += 1)
		_park_car.door_closed.connect(func() -> void: _park_closed += 1)
		_park_car.arrive()
		_stage = 1
		_t = 0.0
		return false

	if _stage == 1:
		if _t < TRAVEL * 0.4:
			return false
		_ok("the skipped car was still on the road", float(_park_car.get("approach")) < 0.95)
		_park_car.park()
		_stage = 2
		_t = 0.0
		return false

	# One frame later, so anything deferred has landed.
	if _t < 0.1:
		return false
	_ok("park() snapped it to the kerb", _park_car.global_position.distance_to(STOP) < 0.05)
	_ok("and killed the beams", (_park_car.get_node("HeadBeamL") as SpotLight3D).light_energy < 0.01)
	_ok("and the dome lamp", (_park_car.get_node("CabinGlow") as OmniLight3D).light_energy < 0.01)
	_ok("and stopped the animator", not (_park_car.get_node("Anim") as AnimationPlayer).is_playing())
	# Without this a skipped cutscene leaves arrive() awaiting a signal that the
	# stopped animation is never going to send.
	_ok("a skip still announces `arrived`, once", _park_arrived == 1)
	_ok("and `door_closed`, once", _park_closed == 1)

	print("CAR ....  %d passed, %d failed" % [_pass, _fail])
	return true
