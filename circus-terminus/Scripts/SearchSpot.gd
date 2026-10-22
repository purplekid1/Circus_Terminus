class_name SearchSpot
extends Interactable
## Somewhere you can rummage: a crate, a heap of sacking, a workbench drawer.
##
## Most of them hold nothing. That is the point -- a single glowing pickup on
## the floor is not searching a cellar, it is collecting a cellar. Five places
## and one key means the player has to look at the room.
##
## THEY NEED LIGHT. Until the generator is running, every one of them answers
## "too dark to see anything in there", and the crosshair says so before the
## player presses anything. That is the whole reason the generator exists as a
## puzzle rather than as a light switch: the cellar is searchable only after
## you have made it searchable.
##
## The torch is deliberately NOT enough. It throws a cone at whatever you are
## pointing it at, and if that counted, the generator would be optional and
## the player would never find out what it was for.

signal searched(player: Node)

## What turns up. Leave null for a place that holds nothing, which most of
## them do.
@export var contents: ItemData

## The generator -- anything with a `running` property. Empty means this spot
## can be searched in the dark, which is right for the one or two outside.
@export var light_source: NodePath

@export var dark_prompt := "Too dark"
@export var empty_prompt := "Nothing in there"

## Said the first time the player tries it in the dark. Once each, because the
## character does not need to tell you five times that she cannot see.
@export var dark_lines: Array[String] = [
	"I can't see a thing in here.",
]

## Said when the search turns up nothing. One per spot, so working through the
## cellar is a sequence of small disappointments rather than the same line.
@export var empty_lines: Array[String] = []

## Said when it turns up the goods.
@export var found_lines: Array[String] = []

## Written into the notebook when this spot yields its contents.
@export var note_title := ""
@export var note_body := ""

## Nudged when searched, so a crate visibly shifts. Cheap, and it is the only
## feedback an empty container can give that it has been dealt with.
@export var shift: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var shift_time := 0.35

## Revealed on searching -- a clue scratched inside a lid, say.
@export var reveals: Array[NodePath] = []

var is_searched := false

## Set once the player has been told, in this spot, that it is too dark. Stops
## the same complaint firing every time they walk past in the dark.
var _complained := false


func has_light() -> bool:
	if light_source.is_empty():
		return true
	var source := get_node_or_null(light_source)
	return source != null and "running" in source and source.running


func available(_player: Node) -> bool:
	if not enabled:
		return false
	# Deliberately still true in the dark. Refusing outright would grey the
	# prompt out and the player would never learn WHY -- and "too dark" is
	# information they are supposed to go and act on.
	return not is_searched or has_light()


func describe(_player: Node) -> String:
	if not has_light():
		return dark_prompt
	if is_searched:
		return empty_prompt
	return prompt


func interact(player: Node) -> void:
	super(player)

	if not has_light():
		if not _complained:
			_complained = true
			for line in dark_lines:
				player.say(line)
		return

	if is_searched:
		return

	# Checked BEFORE anything commits. Shifting the crate and then refusing to
	# hand over what is under it leaves a searched-looking container the
	# player has to remember to come back to.
	if contents != null and "inventory" in player and not _can_take(player):
		player.show_message(
			"There is something in here, but your hands are full.", 4.0
		)
		return

	is_searched = true

	if shift != Vector3.ZERO:
		var nudge := create_tween()
		nudge.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		nudge.tween_property(self, "position", position + shift, shift_time)

	for path in reveals:
		var hidden := get_node_or_null(path)
		if hidden is Node3D:
			(hidden as Node3D).visible = true
		if hidden is Interactable:
			(hidden as Interactable).enabled = true

	if contents == null:
		for line in empty_lines:
			player.say(line)
		searched.emit(player)
		return

	if "inventory" in player and player.inventory.add(contents):
		player.show_message("Found the %s." % contents.display_name, 3.5)
		for line in found_lines:
			player.say(line)
		if not note_title.is_empty():
			player.note(note_title, note_body)
		# Taken, so a second look finds an empty crate rather than a second key.
		contents = null

	searched.emit(player)


## Whether the bag has room for `contents`. Mirrors Pickup's own test, which
## is the one Inventory.add() will actually apply.
func _can_take(player: Node) -> bool:
	var inventory: Inventory = player.inventory
	if inventory == null or contents.is_equipment or not inventory.is_full():
		return true
	if not contents.stackable:
		return false
	for index in Inventory.SLOT_COUNT:
		if inventory.slots[index] == contents and inventory.counts[index] < contents.max_stack:
			return true
	return false
