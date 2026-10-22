class_name Hunt
extends Node3D
## The director for the woods. Owns every Stalker in the level, decides what
## being caught costs, and says the lines that teach the rules.
##
## WHY A DIRECTOR AT ALL. Three things need to agree about a catch -- the fade,
## the respawn point, and resetting the creatures -- and each of them is a
## "one writer" problem. Two stalkers grabbing the player on the same frame
## must produce one death, not two overlapping fades. Everything goes through
## here so there is exactly one place that can happen.
##
## CHECKPOINTS are the Route markers the level already emits, so the walk and
## the punishment cannot disagree about where the level goes. You respawn at
## the last waypoint you got past, which is at most twenty seconds of lost
## ground -- enough to sting, not enough to make the player quit.

## The same Route/ node the probe walks.
@export var route: NodePath
## How far past a waypoint counts as having reached it.
@export var checkpoint_radius := 6.0
@export var fade_time := 1.1
@export var black_time := 1.4

@export_group("Teaching")
## Said the first time any stalker notices the player at all.
@export var first_contact_lines: PackedStringArray = PackedStringArray([
	"It turned. It has no face to turn, and it turned.",
])
## Said the first time the player is caught, when they are back on their feet.
@export var caught_lines: PackedStringArray = PackedStringArray([
	"Do not let it get close. Look for it, and go the other way.",
])
@export var caught_hint := "Raise the glass to find it. Crouch in the thickets."

signal player_caught(times: int)
signal checkpoint_reached(index: int)

var stalkers: Array[Stalker] = []
var checkpoints: Array[Vector3] = []
var reached := 0
var deaths := 0

var _player: Node3D = null
## One writer for the death sequence. A second catch mid-fade is dropped.
var _dying := false
var _said_hello := false


func _ready() -> void:
	_read_checkpoints()
	_collect_stalkers()
	for s: Stalker in stalkers:
		s.caught_player.connect(_on_caught)
		s.first_contact.connect(_on_first_contact)


func _read_checkpoints() -> void:
	checkpoints.clear()
	if route.is_empty() or not has_node(route):
		return
	var kids := get_node(route).get_children()
	# String(), not the bare StringName -- see the note in Stalker._read_route.
	kids.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	for k: Node in kids:
		if k is Node3D:
			checkpoints.append((k as Node3D).global_position)


## By group, not by walking the tree. stalker.tscn declares "enemy" in the
## scene file, so every stalker is in that group from the moment it is
## instantiated -- which is earlier than any _ready ordering I would otherwise
## have to reason about, and works whether or not they are children of this
## node. Filtered to Stalker because the group also carries scenery props.
func _collect_stalkers() -> void:
	stalkers.clear()
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Stalker:
			stalkers.append(node as Stalker)


func _find_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player


func _process(_delta: float) -> void:
	var who := _find_player()
	if who == null or checkpoints.is_empty():
		return
	# Only ever moves forward. Walking back up the path to dodge a stalker is
	# a legitimate move and must not cost you your checkpoint.
	while reached + 1 < checkpoints.size() \
			and who.global_position.distance_to(checkpoints[reached + 1]) < checkpoint_radius:
		reached += 1
		checkpoint_reached.emit(reached)


func respawn_point() -> Vector3:
	if checkpoints.is_empty():
		return Vector3.ZERO
	return checkpoints[clampi(reached, 0, checkpoints.size() - 1)]


func _on_first_contact() -> void:
	if _said_hello:
		return
	_said_hello = true
	var who := _find_player()
	if who != null and who.has_method("say"):
		for line: String in first_contact_lines:
			who.say(line)


func _on_caught(_who: Node3D) -> void:
	if _dying:
		return
	_dying = true
	deaths += 1
	player_caught.emit(deaths)
	_die()


func _die() -> void:
	var who := _find_player()
	if who == null:
		_dying = false
		return

	# Take the controls away first. Being able to walk during your own death
	# fade reads as a bug even when everything else is right.
	if who.has_method("begin_focus"):
		who.begin_focus(self)
	var sound := _sound()
	if sound != null:
		sound.play_at("stalker_catch", who, -2.0, 40.0)
	if who.has_method("fade_out"):
		who.fade_out(fade_time)

	await get_tree().create_timer(fade_time + black_time).timeout
	if not is_instance_valid(who):
		_dying = false
		return

	who.global_position = respawn_point() + Vector3.UP * 1.2
	if who.get("velocity") != null:
		who.velocity = Vector3.ZERO
	reset_stalkers()

	if who.has_method("fade_in"):
		who.fade_in(fade_time)
	if who.has_method("end_focus"):
		who.end_focus()
	if deaths == 1:
		if who.has_method("show_hint"):
			who.show_hint(caught_hint)
		if who.has_method("say"):
			for line: String in caught_lines:
				who.say(line)
	_dying = false


## Sends everything back to its patrol with a clean slate, so you do not
## respawn already being hunted by the thing that just killed you.
func reset_stalkers() -> void:
	for s: Stalker in stalkers:
		if not is_instance_valid(s):
			continue
		s.reset()


## The Sound autoload, by node path rather than by its bare name.
##
## Most of the game just writes `Sound.play_at(...)`, and gets away with it
## because those scripts are not compiled until a scene instantiates them, by
## which time the autoload exists. This file is different: it has a class_name,
## so the test tools name it as a type, which compiles it during a --script run
## -- and in that mode autoloads are not registered yet, so the bare identifier
## is a compile error that takes the whole test suite down with it.
func _sound() -> Node:
	return get_node_or_null("/root/Sound")
