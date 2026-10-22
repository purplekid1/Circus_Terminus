class_name HidingSpot
extends Interactable
## A closet or similar space the player climbs inside.
##
## Distinct from ConcealArea: that one hides you where you already are, this
## one takes the player somewhere and locks down movement until they climb
## back out. Interact again from inside to leave.

signal entered(player: Node)
signal exited(player: Node)

## Where the player stands while hidden.
@export var inside_point: NodePath
## Where they are put back down on the way out. Falls back to wherever they
## were standing when they climbed in.
@export var exit_point: NodePath
## Optional door that shuts behind them.
@export var door: NodePath
@export var exit_prompt := "Climb out"
## How far the door is left open while someone is inside. Fully shut means
## the player stares at the back of a panel; a gap lets them watch the room,
## which is the entire point of hiding.
@export var door_ajar_angle := 14.0

var occupant: Node = null

var _return_to := Vector3.ZERO


func describe(player: Node) -> String:
	if occupant == player:
		return exit_prompt
	return prompt


func available(player: Node) -> bool:
	if not enabled:
		return false
	# Occupied by someone else -- no room.
	return occupant == null or occupant == player


func interact(player: Node) -> void:
	if occupant == player:
		_release(player)
	else:
		_stow(player)
	super(player)


func _stow(player: Node) -> void:
	var inside := get_node_or_null(inside_point) as Node3D
	if inside == null:
		push_warning("HidingSpot '%s' has no inside_point; ignoring." % name)
		return

	_return_to = (player as Node3D).global_position
	occupant = player
	player.enter_hiding(self)
	(player as Node3D).global_position = inside.global_position

	_swing_door(door_ajar_angle)
	entered.emit(player)


func _release(player: Node) -> void:
	var exit := get_node_or_null(exit_point) as Node3D
	var destination := exit.global_position if exit != null else _return_to

	_swing_door(90.0)
	occupant = null
	(player as Node3D).global_position = destination
	player.exit_hiding()
	exited.emit(player)


func _swing_door(degrees: float) -> void:
	var leaf := get_node_or_null(door) as Door
	if leaf != null:
		leaf.swing_to(degrees)
