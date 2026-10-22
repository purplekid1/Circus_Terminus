extends Node
## Walks the REAL player body along a list of waypoints with move_and_slide,
## and reports whether it arrives.
##
## This is the ground truth the grid probe only approximates. probe_walk.gd
## floods a grid of samples and has to guess at things the engine actually
## decides -- sliding along a wall, riding up a slope, squeezing past a door
## leaf that is standing open. When the two disagree, this is the one that is
## right.
##
## The player's own _physics_process is switched off and the body driven
## directly, because the alternative is synthesising input events and hoping
## the camera is pointing the way we think.
##
## ROUTE=cellar godot --path . tools/route.tscn

const SPEED := 3.4
const GRAVITY := 18.0
## How long to spend trying to reach one waypoint before giving up on it.
const PATIENCE := 6.0

## Named journeys. Each is a start and then the corners to walk round.
const ROUTES := {
	# Straight at the hatch from the south lawn. FAILS on the stone coping,
	# which stands 0.15 proud of the grass.
	"cellar": [
		Vector3(-10.0, 0.5, -86.0),
		Vector3(-10.0, 0.5, -84.0),
		Vector3(-10.0, 0.5, -82.0),     # over the coping, onto the ramp
		Vector3(-10.0, -2.0, -79.0),    # down the ramp
		Vector3(-10.0, -3.2, -77.0),    # the pit floor
		Vector3(-10.6, -3.2, -75.0),    # through the cellar door
	],
	# From the back deck, round to the open hatch. FAILS at the deck edge: the
	# east leaf stands up across it when the doors are open.
	"deck-to-cellar": [
		Vector3(4.0, 0.6, -77.5),
		Vector3(-10.0, 0.6, -77.5),
		Vector3(-10.0, 0.6, -79.2),
		Vector3(-10.0, 0.4, -80.4),
	],
	# Straight at the pit from the east lawn. FAILS on the pit wall, which
	# stands 0.20 proud of the grass.
	"east-into-pit": [
		Vector3(-5.0, 0.5, -81.5),
		Vector3(-7.0, 0.5, -81.5),
		Vector3(-9.0, 0.5, -81.5),
		Vector3(-10.0, -3.2, -78.0),
	],
	# Up out of the cellar into the house. This is the one the surroundings
	# ground plate used to block; it PASSES now.
	"stairs": [
		Vector3(12.0, -3.2, -74.0),     # the foot of the cellar stairs
		Vector3(12.0, -2.0, -72.0),
		Vector3(12.0, -1.0, -70.0),
		Vector3(12.0, 0.4, -68.0),      # the head, through the gate
		# Stops here. The landing at the head is only 0.8 m deep -- the back
		# passage wall is at z -67.5 -- and where it goes from there is a
		# question for the flood, which reaches the whole ground floor from
		# this point:  SEED="the head of the cellar stairs" MAP=1 probe_walk
	],
}

var _player: CharacterBody3D
var _targets: Array
var _at := 0
var _spent := 0.0
var _done := false


func _ready() -> void:
	var level := (load("res://demo_level.tscn") as PackedScene).instantiate()
	add_child(level)
	var intro := level.get_node_or_null("Intro")
	if intro != null:
		intro.free()

	for path in ["Gate", "Gate2", "Mansion/StormDoor", "Mansion/CellarGate"]:
		var door := level.get_node_or_null(path)
		if door == null or not door.has_method("set_open"):
			continue
		if "locked" in door:
			door.locked = false
		door.set_open(true)

	_player = level.get_node("Player")
	_player.set_physics_process(false)
	_player.set_process(false)

	var which := OS.get_environment("ROUTE")
	_targets = ROUTES.get(which, ROUTES["cellar"])
	_player.global_position = _targets[0]
	_at = 1
	print("ROUTE walking '%s' from %v" % [which, _targets[0]])


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _at >= _targets.size():
		print("ROUTE PASS  arrived, ending at %v" % _player.global_position)
		_finish()
		return

	var goal: Vector3 = _targets[_at]
	var here := _player.global_position
	var flat := Vector3(goal.x - here.x, 0.0, goal.z - here.z)

	if flat.length() < 0.35:
		print("ROUTE   reached waypoint %d %v  (body at %v)" % [_at, goal, here])
		_at += 1
		_spent = 0.0
		return

	_spent += delta
	if _spent > PATIENCE:
		print("ROUTE FAIL  stuck short of waypoint %d %v" % [_at, goal])
		print("ROUTE       the body got as far as %v" % here)
		_finish()
		return

	var dir := flat.normalized()
	_player.velocity.x = dir.x * SPEED
	_player.velocity.z = dir.z * SPEED
	if _player.is_on_floor():
		_player.velocity.y = 0.0
	else:
		_player.velocity.y -= GRAVITY * delta
	_player.move_and_slide()


func _finish() -> void:
	_done = true
	get_tree().quit()
