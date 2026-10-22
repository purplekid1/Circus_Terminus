class_name Cabinet
extends Interactable
## A cabinet, bureau or drawer. Optionally locked, and what it holds can be an
## item, something revealed in place, or both.
##
## Revealing in place matters for clues: a tally scratched inside a bureau
## should not be readable through the closed lid, and should not become a
## floating pickup either.

signal opened(player: Node)

@export var locked := false
@export var key_id := ""
@export var locked_prompt := "Locked"

## Take the key once it has done its job, so a one-shot key does not squat in
## a slot for the rest of the game.
@export var consume_key := false

## Handed to the player on opening.
@export var contents: ItemData

## Shown and enabled on opening -- a clue inside, a note, a keepsake.
@export var reveals: Array[NodePath] = []

## Node swung open. Usually a lid or a door panel.
@export var lid: NodePath
@export var open_angle := -100.0
@export var swing_time := 0.6

@export var empty_prompt := "Empty"

var is_open := false


func _has_key(player: Node) -> bool:
	if key_id.is_empty():
		return false
	var inventory: Inventory = player.inventory if "inventory" in player else null
	return inventory != null and inventory.selected_is(key_id)


func available(player: Node) -> bool:
	if not enabled or is_open:
		return false
	return not locked or _has_key(player)


func describe(player: Node) -> String:
	if is_open:
		return empty_prompt
	if locked and not _has_key(player):
		return locked_prompt
	return prompt


func interact(player: Node) -> void:
	var first_try := not examined
	super(player)

	if is_open:
		return

	if locked:
		if not _has_key(player):
			if first_try:
				player.say("Locked. Small keyhole -- there will be a key for it.")
			return
		locked = false
		if consume_key and "inventory" in player:
			player.inventory.drop_selected()

	is_open = true

	var leaf := get_node_or_null(lid) as Node3D
	if leaf != null:
		var swing := create_tween()
		swing.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		swing.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		swing.tween_property(leaf, "rotation:y", deg_to_rad(open_angle), swing_time)

	for path in reveals:
		var hidden := get_node_or_null(path)
		if hidden is Node3D:
			(hidden as Node3D).visible = true
		if hidden is Interactable:
			(hidden as Interactable).enabled = true

	if contents != null and "inventory" in player:
		if player.inventory.add(contents):
			player.show_message("Took the %s." % contents.display_name, 3.0)
		else:
			player.show_message(
				"The %s is in here, but your hands are full." % contents.display_name, 4.0
			)

	opened.emit(player)
