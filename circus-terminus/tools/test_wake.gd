extends SceneTree
## The wake-up, end to end.
##
## It used to be four tweens and four awaits inside WakeUp.gd; it is one
## animation on an AnimationPlayer now and the script only says what the poses
## mean. That move can fail QUIETLY -- a value track pointed at a property that
## has been renamed writes nothing and reports nothing, and a method track with
## a typo in it never fires -- so this opens the real level and watches the real
## camera all the way from face-down to hands back.
##
## The last assertion is the one that earns its place: the camera has to finish
## EXACTLY on the pose the controller expects, because head bob is applied as an
## offset from it and a cutscene that ends a centimetre low never recovers.

var _level: Node
var _player: Node3D
var _wake: Node3D
var _cam: Node3D
var _rest_pos := Vector3.ZERO
var _rest_rot := Vector3.ZERO

var _t := 0.0
var _stage := -1
var _pass := 0
var _fail := 0

var _saw_down := false
var _saw_look := false
var _saw_midrise := false
var _had_focus := false

## The animation is 6.8 s, plus a frame for the deferred method track.
const RUN := 7.2


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	print("WAKE %s  %s" % ["PASS" if cond else "FAIL", label])


## Deliberately not _initialize(): a node added to the root from there does not
## get _ready() before the loop starts.
func _process(delta: float) -> bool:
	_t += delta

	if _stage == -1:
		# The rest pose, from a player that no cutscene has touched.
		var fresh := (load("res://Scenes/player.tscn") as PackedScene).instantiate()
		get_root().add_child(fresh)
		var fc := fresh.get("camera") as Node3D
		_rest_pos = fc.position
		_rest_rot = fc.rotation_degrees
		fresh.queue_free()

		_level = (load("res://circus_level.tscn") as PackedScene).instantiate()
		get_root().add_child(_level)
		_player = _level.get_node_or_null("Player") as Node3D
		_wake = _level.get_node_or_null("WakeUp") as Node3D
		_ok("the level has a Player", _player != null)
		_ok("and a WakeUp", _wake != null)
		if _wake == null or _player == null:
			return true
		_ok("with an animator on it", _wake.get_node_or_null("Anim") != null)
		var anim := _wake.get_node("Anim") as AnimationPlayer
		_ok("carrying \"wake\"", anim.has_animation("wake"))
		_cam = _player.get("camera") as Node3D
		_stage = 0
		_t = 0.0
		return false

	if _stage == 0:
		# WakeUp waits a frame in _ready before it starts.
		if _t < 0.3:
			return false
		var anim := _wake.get_node("Anim") as AnimationPlayer
		_ok("the animation is running", anim.is_playing())
		_ok("and it took the controls", _player.get("focus_target") == _wake)
		_had_focus = _player.get("focus_target") == _wake
		_stage = 1
		return false

	if _stage == 1:
		# Sample the whole run rather than trusting any one frame.
		var drop: float = _cam.position.y - _rest_pos.y
		if drop < -0.5:
			_saw_down = true
		if absf(_cam.rotation_degrees.y - _rest_rot.y) > 4.0:
			_saw_look = true
		if drop < -0.08 and drop > -0.7 and absf(_cam.rotation_degrees.z - _rest_rot.z) < 40.0:
			_saw_midrise = true
		if _t < RUN:
			return false

		_ok("it started face down on the floor", _saw_down)
		_ok("the head turned before the body moved", _saw_look)
		_ok("and the body came up through the middle", _saw_midrise)
		var anim := _wake.get_node("Anim") as AnimationPlayer
		_ok("the animation has finished", not anim.is_playing())
		# The method track is the only thing that hands control back.
		_ok("the controls came back", _player.get("focus_target") == null)
		_ok("and it knows it is done", bool(_wake.get("_done")))
		_ok("the camera is back on its rest position",
			_cam.position.distance_to(_rest_pos) < 0.001)
		_ok("and its rest rotation",
			(_cam.rotation_degrees - _rest_rot).length() < 0.01)

		print("WAKE ....  %d passed, %d failed" % [_pass, _fail])
		return true

	return true
