class_name Obstacle
extends Interactable
## Something in the way that a tool will shift -- debris across a staircase,
## a nailed board, a jammed shutter.
##
## Gates progress on having found a tool rather than a key, so the house has
## more than one kind of lock in it.

signal cleared(player: Node)

## ItemData.id that must be in the SELECTED slot to shift this.
@export var tool_id := ""
@export var need_tool_prompt := "Wedged fast"

## Where the wreckage ends up, relative to where it started.
@export var shift := Vector3(0, -3, 0)
@export var shift_time := 1.0

## Collision to switch off once it is out of the way.
@export var blockers: Array[NodePath] = []

@export var cleared_lines: Array[String] = []

var is_cleared := false


func _has_tool(player: Node) -> bool:
	if tool_id.is_empty():
		return true
	var inventory: Inventory = player.inventory if "inventory" in player else null
	return inventory != null and inventory.selected_is(tool_id)


func available(player: Node) -> bool:
	if not enabled or is_cleared:
		return false
	return _has_tool(player)


func describe(player: Node) -> String:
	if is_cleared:
		return ""
	if not _has_tool(player):
		return need_tool_prompt
	return prompt


func interact(player: Node) -> void:
	var first_try := not examined
	super(player)

	if is_cleared:
		return
	if not _has_tool(player):
		if first_try:
			player.say("Not shifting that with my hands.")
		return

	is_cleared = true

	# Collision goes first: the tween is cosmetic, and the player should not
	# have to wait for wreckage to finish sliding before they can walk.
	for path in blockers:
		var blocker := get_node_or_null(path)
		if blocker is CollisionShape3D:
			(blocker as CollisionShape3D).set_deferred("disabled", true)
		elif blocker is CollisionObject3D:
			(blocker as CollisionObject3D).set_deferred("process_mode", PROCESS_MODE_DISABLED)

	var slide := create_tween()
	slide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slide.tween_property(self, "position", position + shift, shift_time)

	for line in cleared_lines:
		player.say(line)
	cleared.emit(player)
