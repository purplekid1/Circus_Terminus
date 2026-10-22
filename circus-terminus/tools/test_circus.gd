extends SceneTree
## The circus level's opening: waking up on the floor, getting to your feet,
## and finding the glass.
##
## The thing most likely to go wrong here is a SOFTLOCK. WakeUp takes the
## controls before the player has ever had them, and if it fails partway -- or
## if it hands back a camera it left rolled onto its side -- the level is
## unplayable and nothing else reports it.

var _lvl: Node
var _player: Node
var _wake: Node
var _wait := 10
var _stage := 0
var _elapsed := 0.0
var _eye0 := Vector3.ZERO
var _rot0 := Vector3.ZERO


func _ok(label: String, cond: bool) -> void:
	print("CIRCUS %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_lvl = (load("res://circus_level.tscn") as PackedScene).instantiate()
	root.add_child(_lvl)


func _process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	if _stage == 0:
		_player = _lvl.get_node("Player")
		_wake = _lvl.get_node("WakeUp")
		_ok("the level opens with a wake-up", _wake != null)
		# Shorten it so the test does not sit through seven seconds of blinking.
		# The running order is KEYFRAMES now -- Scenes/anim/wake.tscn -- so the
		# way to hurry it is to run the animation faster, which also keeps the
		# phases in proportion. The blink exports survive because they are flash
		# durations handed to the HUD, not gaps in the edit.
		_wake.blink_a = 0.02
		_wake.blink_gap = 0.02
		_wake.blink_b = 0.04
		(_wake.get_node("Anim") as AnimationPlayer).speed_scale = 60.0
		_stage = 1
		return false

	if _stage == 1:
		# It has to have taken the controls. A wake-up the player can walk out
		# of is not a wake-up.
		_ok("it takes the controls before the player has them",
			_player.focus_target == _wake)
		_eye0 = _player.camera.position
		_rot0 = _player.camera.rotation_degrees
		_ok("and starts them on the floor", _rot0.z > 20.0 or _eye0.y < -0.3)
		_stage = 2
		_elapsed = 0.0
		return false

	if _stage == 2:
		_elapsed += delta
		if not _wake._done and _elapsed < 6.0:
			return false
		_ok("the character gets up", _wake._done)
		_ok("and the controls come back", _player.focus_target == null)
		# The camera MUST be put back exactly, or the head bob starts from
		# wherever the animation left off and never recovers.
		_ok("with the camera level again",
			absf(_player.camera.rotation_degrees.z) < 0.01)
		_ok("and at standing height",
			absf(_player.camera.position.y - _eye0.y) > 0.3
			or absf(_eye0.y) < 0.01)

		# The lens has to be findable, and close.
		var glass := _lvl.get_node_or_null("Magnifier")
		_ok("the glass is in the level", glass != null)
		if glass != null:
			var d: float = glass.global_position.distance_to(_player.global_position)
			_ok("and it is where he fell, not across the map", d < 8.0)
			_ok("and it grants the lens", glass.grants_magnifier)

		# The way out.
		#
		# This used to be a LevelExit that handed over to a fairground level at
		# z -82, two thirds of the way down the walk. The fairground is gone --
		# it was a second place grafted onto the front of the first, and the
		# player had to cross a fair to reach the circus they had spent 500 m
		# walking toward. The way out is now the door into the big top, at the
		# actual end. tools/test_door.gd covers what it does.
		var door := _lvl.get_node_or_null("BigTopDoor")
		_ok("the level has a way out", door != null)
		_ok("and a switch to open it with", _lvl.get_node_or_null("DoorSwitch") != null)

		# And the objective is visible from where you stand up: the tent is the
		# only thing telling the player which way to walk.
		var tent := _lvl.get_node_or_null("Tent")
		_ok("the tent exists to walk towards", tent != null)
		return true

	return false
