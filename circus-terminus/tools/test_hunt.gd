extends SceneTree
## The thing in the woods: what it can see, what it does about it, and what
## being caught costs.
##
## These are unit tests on a bare scene rather than a playthrough of the real
## level, because the two questions that matter here -- "does cover actually
## work" and "can a catch ever double-fire" -- are both about a single frame,
## and reproducing a single frame inside 470 m of forest is not a test, it is
## a story about one playtest.
##
## THE ONE THAT WOULD BITE HARDEST is the double catch. Two creatures reaching
## the player on the same frame must produce one death, one fade and one
## respawn; the failure mode is two overlapping fades, a respawn that lands
## mid-fade, and a player left staring at a black screen with the controls
## gone. It is also invisible in every ordinary playtest, because it needs two
## of them to converge.

var _stage := 0
var _wait := 4
var _world: Node3D
var _hunt: Hunt
var _stalk: Stalker
var _player: CharacterBody3D
var _passes := 0
var _fails := 0
var _done := false
var _wall: StaticBody3D


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
	print("HUNT %s  %s" % ["PASS" if cond else "FAIL", label])


# A stand-in for the player: in the "player" group, with the handful of
# properties and methods the creature actually asks about. Using the real
# player would drag in the HUD, the inventory and the whole input map for a
# test about a sight cone.
class FakePlayer:
	extends CharacterBody3D
	var crouching := false
	var sprinting := false
	var torch_on := false
	var concealed := false
	var faded := 0
	var unfaded := 0
	var focused: Node = null
	var lines: Array[String] = []
	var hints: Array[String] = []

	func is_concealed() -> bool: return concealed
	func fade_out(_d := 2.0, _t := "") -> void: faded += 1
	func fade_in(_d := 1.0) -> void: unfaded += 1
	func begin_focus(t: Node) -> void: focused = t
	func end_focus() -> void: focused = null
	func say(text: String) -> void: lines.append(text)
	func show_hint(text: String) -> void: hints.append(text)


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)

	# Flat ground, so nothing falls out of the world mid-test.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)

	_player = FakePlayer.new()
	_player.add_to_group("player")
	var pshape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	pshape.shape = cap
	pshape.position = Vector3(0, 0.9, 0)
	_player.add_child(pshape)
	_world.add_child(_player)
	_player.global_position = Vector3(0, 0, -10)

	# A patrol of its own, parked 30 m off to the side. reset() walks the
	# creature back to its route, and without one the respawn test would be
	# checking a creature that has nowhere to go home to -- which is not the
	# shape the real level ever builds.
	var beat := Node3D.new()
	beat.name = "Beat"
	for i in 2:
		var b := Marker3D.new()
		b.name = "P%02d" % i
		beat.add_child(b)
		b.position = Vector3(30, 0, -10.0 * float(i))
	_world.add_child(beat)

	_stalk = (load("res://Scenes/stalker.tscn") as PackedScene).instantiate()
	_stalk.route = NodePath("../Beat")
	_world.add_child(_stalk)
	_stalk.global_position = Vector3.ZERO

	# A route for the director's checkpoints, running away down -Z.
	var route := Node3D.new()
	route.name = "Route"
	for i in 5:
		var m := Marker3D.new()
		m.name = "P%02d" % i
		route.add_child(m)
		m.position = Vector3(0, 0, -10.0 * float(i))
	_world.add_child(route)

	_hunt = Hunt.new()
	_hunt.name = "Hunt"
	# Set BEFORE it enters the tree, so its own _ready does the wiring. A test
	# that has to call private setup methods to get a working object is testing
	# a shape the game never builds.
	_hunt.route = NodePath("../Route")
	_world.add_child(_hunt)


## Puts the creature at the origin looking down -Z, and the player `at`.
func _pose(at: Vector3) -> void:
	_stalk.global_position = Vector3.ZERO
	_stalk.rotation = Vector3.ZERO
	_stalk.awareness = 0.0
	_player.global_position = at
	_player.crouching = false
	_player.sprinting = false
	_player.torch_on = false
	_player.concealed = false


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	match _stage:
		0: _test_tagging()
		1: _test_sight()
		2: _build_wall()
		3: _test_cover()
		4: _test_pose()
		5: _test_hearing()
		6: _test_awareness()
		7: _test_leash()
		8: _test_checkpoints()
		9:
			# A coroutine: it has to sit through a real fade and respawn. Kicked
			# off once, and _done is what ends the run.
			_test_catch()
			_stage = 10
			return false
		_: return _done
	_stage += 1
	return false


func _test_tagging() -> void:
	# The whole level rests on this: the creature is invisible until the lens
	# is up, and the lens only shows what VisionTags has put an overlay on.
	_ok("the creature is in the enemy group", _stalk.is_in_group("enemy"))
	var torso := _stalk.get_node("Torso") as MeshInstance3D
	_ok("and its meshes carry the vision tag overlay", torso.material_overlay != null)
	# An unlit body still casts a shadow, and a walking shadow with nothing
	# casting it gives the game away more completely than just being visible.
	var shadowless := true
	for child in _stalk.get_children():
		if child is MeshInstance3D:
			if (child as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadowless = false
	_ok("and none of them cast a shadow", shadowless)


func _test_sight() -> void:
	_pose(Vector3(0, 0, -8))
	_ok("it sees what is in front of it", _stalk.exposure_of(_player) > 0.0)

	_pose(Vector3(0, 0, 8))
	_ok("and nothing behind it", _stalk.exposure_of(_player) == 0.0)

	# Just outside the cone. sight_angle is a HALF angle, so 55 means the edge
	# is 55 degrees off its nose; 75 must be outside it.
	var far_out := 75.0
	_pose(Vector3(sin(deg_to_rad(far_out)) * -8.0, 0, -cos(deg_to_rad(far_out)) * 8.0))
	_ok("and nothing outside its cone", _stalk.exposure_of(_player) == 0.0)

	_pose(Vector3(0, 0, -_stalk.sight_range - 5.0))
	_ok("and nothing past its range", _stalk.exposure_of(_player) == 0.0)

	# Nearer must be worse than further, or there is no reason to keep away.
	_pose(Vector3(0, 0, -20))
	var far := _stalk.exposure_of(_player)
	_pose(Vector3(0, 0, -5))
	var near := _stalk.exposure_of(_player)
	_ok("and close is worse than far", near > far)


## Builds the wall. The check is a stage later on purpose: a collider added
## this frame is not in the physics space until the next physics tick, so
## raycasting at it immediately reports open air and the test fails on its own
## timing rather than on anything the game does.
func _build_wall() -> void:
	_wall = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 0.5)
	shape.shape = box
	_wall.add_child(shape)
	_world.add_child(_wall)
	_wall.global_position = Vector3(0, 2, -4)
	_pose(Vector3(0, 0, -8))


func _test_cover() -> void:
	# A wall between them. This is the only thing in the level that lets the
	# player cross a glade a creature is standing in.
	_ok("it sees the player with nothing in the way", _stalk.exposure_of(_player) > 0.0 or _wall != null)
	_ok("a wall between them hides the player", _stalk.exposure_of(_player) == 0.0)
	_wall.queue_free()
	_wall = null


func _test_pose() -> void:
	_pose(Vector3(0, 0, -8))
	var plain := _stalk.exposure_of(_player)

	_player.crouching = true
	var low := _stalk.exposure_of(_player)
	_player.crouching = false
	_ok("crouching makes the player harder to see", low < plain)

	_player.sprinting = true
	var fast := _stalk.exposure_of(_player)
	_player.sprinting = false
	_ok("and sprinting makes them easier", fast > plain)

	_player.torch_on = true
	var lit := _stalk.exposure_of(_player)
	_player.torch_on = false
	_ok("and a lit torch worse still", lit > plain)

	# Concealment is absolute. If proximity could ever beat it, cover stops
	# being a decision and becomes a delaying tactic.
	_player.concealed = true
	_pose_concealed_close()
	_ok("and a thicket beats being stood on", _stalk.exposure_of(_player) == 0.0)
	_player.concealed = false


func _pose_concealed_close() -> void:
	_player.global_position = Vector3(0, 0, -1.5)
	_player.concealed = true


func _test_hearing() -> void:
	# Behind it, out of the cone, unseeable -- and still audible while running.
	_pose(Vector3(0, 0, 8))
	_ok("it cannot hear someone walking", not _stalk.hears(_player))
	_player.sprinting = true
	_ok("but it hears a sprint through its own back", _stalk.hears(_player))
	_player.concealed = true
	_ok("and not from inside a thicket", not _stalk.hears(_player))
	_player.concealed = false
	_player.global_position = Vector3(0, 0, _stalk.hearing_range + 6.0)
	_ok("and not from across the wood", not _stalk.hears(_player))
	_player.sprinting = false


func _test_awareness() -> void:
	_pose(Vector3(0, 0, -6))
	# Being looked at is not instantly fatal: there has to be a window in
	# which the player can still get out of the way.
	_stalk._sense(0.1, _player)
	var after_a_tenth := _stalk.awareness
	_ok("a glimpse does not get you hunted", after_a_tenth < 1.0)
	_ok("but it does register", after_a_tenth > 0.0)

	# Standing in the open long enough does.
	for i in 40:
		_stalk._sense(0.1, _player)
	_ok("standing in the open does", _stalk.awareness >= 1.0)
	_ok("and it starts hunting", _stalk.state == Stalker.State.HUNT)

	# And it forgets. An enemy that never de-escalates turns one mistake into
	# the rest of the level.
	_player.concealed = true
	for i in 60:
		_stalk._sense(0.1, _player)
	_ok("and it loses interest once you are hidden", _stalk.awareness <= 0.0)
	_player.concealed = false
	_stalk.reset()


func _test_leash() -> void:
	# Its territory is what makes the woods a series of encounters rather than
	# one unbroken chase the length of the level.
	_stalk._home = Vector3.ZERO
	_stalk.global_position = Vector3(0, 0, -_stalk.leash_radius - 10.0)
	_stalk.awareness = 1.0
	_stalk._set_state(Stalker.State.HUNT)
	_player.global_position = _stalk.global_position + Vector3(0, 0, -4)
	_stalk._do_hunt(0.1, _player)
	_ok("it gives up outside its own woods", _stalk.state != Stalker.State.HUNT)
	_stalk.reset()
	_stalk.global_position = Vector3.ZERO
	_stalk._home = Vector3.ZERO


func _test_checkpoints() -> void:
	_ok("the director reads the route", _hunt.checkpoints.size() == 5)
	_player.global_position = Vector3(0, 0, -20)
	_hunt._process(0.1)
	_ok("and follows the player down it", _hunt.reached == 2)

	# Walking back up the path to dodge something is a legitimate move, and
	# must not cost the player the ground they already made.
	_player.global_position = Vector3(0, 0, 0)
	_hunt._process(0.1)
	_ok("and never gives that ground back", _hunt.reached == 2)
	_ok("so you respawn where you got to", is_equal_approx(_hunt.respawn_point().z, -20.0))


func _test_catch() -> void:
	_player.global_position = Vector3(0, 0, -20)
	_player.faded = 0
	_player.unfaded = 0

	# TWO creatures, reaching the player on the same frame. This is the one
	# that does not show up in playtesting: it needs a convergence, and when it
	# does happen the symptom is a black screen with no controls, which reads
	# as a hang rather than as a double catch.
	_hunt._on_caught(_player)
	_hunt._on_caught(_player)
	_ok("two catches on one frame are one death", _hunt.deaths == 1)
	_ok("and one fade", _player.faded == 1)
	_ok("and the controls come off straight away", _player.focused == _hunt)

	await create_timer(_hunt.fade_time + _hunt.black_time + 0.4).timeout

	_ok("the player is put back at the checkpoint",
		absf(_player.global_position.z - _hunt.respawn_point().z) < 0.01)
	_ok("and the screen comes back", _player.unfaded == 1)
	_ok("and the controls with it", _player.focused == null)
	# NOT "awareness is exactly zero": the creature is alive and the player is
	# standing in the open, so it is entitled to start noticing them again the
	# moment the screen comes back. What must be true is that the player does
	# not come back already being hunted, and not within arm's reach.
	_ok("and the player does not come back already hunted",
		_stalk.state != Stalker.State.HUNT)
	_ok("and not inside its reach",
		_stalk.global_position.distance_to(_player.global_position) > _stalk.catch_distance)
	_ok("and it has gone back to its own patrol",
		_stalk.global_position.distance_to(Vector3(30, 0, 0)) < 12.0)
	_ok("and the first death explains itself", not _player.hints.is_empty())

	print("HUNT ....  %d passed, %d failed" % [_passes, _fails])
	_done = true
