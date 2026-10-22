extends SceneTree
## The way into the big top: a switch on the canvas, and a door that falls.
##
## This is the last thing in the level and the only way past the end of it, so
## every failure here is total -- the walk ends at a wall and the demo stops in
## a field. None of it is loud: a switch wired to nothing throws and clunks and
## looks exactly like a player who has not worked something out yet.
##
## It used to live in the fairground, which has been cut. The door came with it
## because it was always the better ending: you walk 500 m of woods toward a
## tent, and then you get into the tent.

var _stage := 0
var _wait := 14
var _hold := 0.0
var _lvl: Node
var _player: Node
var _door: FallDoor
var _switch: Lever
var _passes := 0
var _fails := 0


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
	print("DOOR %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_lvl = (load("res://circus_level.tscn") as PackedScene).instantiate()
	root.add_child(_lvl)
	# Takes the camera and holds the controls for eight seconds.
	var wake := _lvl.get_node_or_null("WakeUp")
	if wake != null:
		wake.free()


func _process(delta: float) -> bool:
	if _hold > 0.0:
		_hold -= delta
		return false
	if _wait > 0:
		_wait -= 1
		return false

	match _stage:
		0: _test_shut()
		1: _test_throw()
		2:
			# The fall is a tween and the dust is on a timer -- both are wall
			# clock, and a headless frame here is well under a millisecond, so
			# counting frames would wait no time at all.
			_hold = 2.0
		3: _test_landed()
		_:
			print("DOOR ....  %d passed, %d failed" % [_passes, _fails])
			return true
	_stage += 1
	return false


func _test_shut() -> void:
	_player = _lvl.get_node_or_null("Player")
	_door = _lvl.get_node_or_null("BigTopDoor") as FallDoor
	_switch = _lvl.get_node_or_null("DoorSwitch") as Lever
	_ok("the level has a player", _player != null)
	_ok("and a door at the big top", _door != null)
	_ok("and a switch on the canvas", _switch != null)
	if _door == null or _switch == null:
		return

	_ok("the door starts up", not _door.is_down)
	var pivot := _door.get_node_or_null("Pivot") as Node3D
	_ok("and standing upright", pivot != null and absf(pivot.rotation.x) < 0.01)

	var solid := false
	for node in _door.find_children("*", "CollisionShape3D", true, false):
		if not (node as CollisionShape3D).disabled:
			solid = true
	_ok("and blocking the way in", solid)

	# A NodePath typed into a generator by hand. Get it wrong and the switch
	# throws, clunks, and does nothing at all.
	var aimed := false
	for path in _switch.targets:
		if _switch.get_node_or_null(path) == _door:
			aimed = true
	_ok("and the switch is wired to it", aimed)

	# The door has to be at the END of the walk, not somewhere off it. The
	# route and the door are set in two different files.
	var route := _lvl.get_node_or_null("Route")
	if route != null and route.get_child_count() > 0:
		var marks: Array[Node] = route.get_children()
		marks.sort_custom(func(a: Node, b: Node) -> bool:
			return String(a.name) < String(b.name))
		var last: Vector3 = (marks[marks.size() - 1] as Node3D).global_position
		_ok("and the walk ends at it (%.0f m past the door)" % (_door.global_position.z - last.z),
			absf(last.x - _door.global_position.x) < 6.0
			and last.z < _door.global_position.z
			and absf(last.z - _door.global_position.z) < 20.0)


func _test_throw() -> void:
	if _door == null or _switch == null:
		return
	_switch.interact(_player)
	_ok("throwing the switch drops the door", _door.is_down)

	# Everything else out here is built for something three metres tall and is
	# deliberately out of reach. The one switch the player must use cannot be.
	_ok("and the switch was within reach (%.1f m up)" % _switch.global_position.y,
		_switch.global_position.y > 0.6 and _switch.global_position.y < 2.4)


func _test_landed() -> void:
	if _door == null:
		return
	var pivot := _door.get_node_or_null("Pivot") as Node3D
	_ok("the door went over", pivot != null and pivot.rotation.x < deg_to_rad(-80.0))

	# CharacterBody3D here has no step-up, so a panel lying flat is a 0.35 m
	# wall the player stops dead against. Once down it has to stop being
	# collision at all.
	var solid := false
	for node in _door.find_children("*", "CollisionShape3D", true, false):
		if not (node as CollisionShape3D).disabled:
			solid = true
	_ok("and stopped being something to walk into", not solid)

	var dust := _door.get_node_or_null("Dust")
	var grit := _door.get_node_or_null("Grit")
	_ok("and it threw dust", dust != null and dust.emitting)
	_ok("and debris with it", grit != null and grit.emitting)
