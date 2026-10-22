class_name Interactable
extends Node3D
## Base class for anything the player can look at and press Interact on.
##
## The player raycasts from the camera, hits a collider, then walks up the
## tree looking for one of these. That means the collision shape can live
## anywhere under the interactable -- on a door panel that swings, on a
## StaticBody, on several bodies at once -- without the player needing to
## know the layout.
##
## Put the node in the "interactable" group and the vision lens will tag it
## blue as well, so the glass doubles as a way to find them in the dark.
##
## Knowledge is earned, not given. Until the player has actually tried a
## thing, the crosshair shows only its plain name -- "Front door" -- and the
## thing always accepts a click. Trying it is what reveals that it is bolted,
## needs a key, or is empty. That keeps the player exploring by hand instead
## of reading the state of the whole house off the HUD from across a room.

signal interacted(player: Node)


## Joins the "interactable" group, so the vision lens can find it.
##
## IN CODE, NOT IN EACH SCENE. A group declared in a .tscn is lost every time
## the node is rebuilt or the scene is re-saved by hand, and losing it is
## completely silent: the thing simply stops appearing through the glass, with
## no error and nothing in the source that looks wrong. Six of the mansion's
## twenty-seven interactables had lost it that way, the debris across the
## stairs among them.
##
## In _enter_tree rather than _ready because five subclasses override _ready
## and cannot all be relied on to call super(). Nothing overrides _enter_tree.
##
## Pickups are exempt. They are already in "items", and the lens showing them
## yellow rather than blue is the more useful thing to know about them.
func _enter_tree() -> void:
	if not is_in_group("items"):
		add_to_group("interactable")
## Emitted the first time this is tried, so a level can react to discovery.
signal examined_first_time(player: Node)

@export var prompt := "Use"

## Turn off for interactables that are scenery until something enables them.
@export var enabled := true

## Spoken once, the first time the player tries this. Gives the character a
## reaction to what they just found out.
@export var examine_lines: Array[String] = []

## True once the player has tried this at least once.
var examined := false


## Final: subclasses override describe() instead. Before the first try this
## deliberately hides everything the player has not earned yet.
func get_prompt(player: Node) -> String:
	if not examined:
		return prompt
	return describe(player)


## What the crosshair says once the player knows what this is. Subclasses
## override this to report state -- "Locked", "Open", "Close", "Empty".
func describe(_player: Node) -> String:
	return prompt


## Final: subclasses override available() instead. An unexamined thing always
## accepts a click, because refusing before the player has tried it would
## leak the very information the click is supposed to reveal.
func can_interact(player: Node) -> bool:
	if not enabled:
		return false
	if not examined:
		return true
	return available(player)


## Whether this can actually be used, once the player knows about it.
func available(_player: Node) -> bool:
	return enabled


## Subclasses override this. Call super() to keep the signal firing and the
## examined bookkeeping correct.
func interact(player: Node) -> void:
	# The tick that every interaction makes. Deliberately almost nothing -- it
	# fires on doors, books, safes, search spots and pickups alike, and anything
	# with character in it would wear out within a minute. Things that make a
	# real noise of their own play it over the top of this.
	# NO GENERIC INTERACTION SOUND. There was one, and it was wrong: it fired on
	# doors, books, safes, search spots and pickups alike, which meant the sound
	# you heard most often in the whole game was the one carrying the least
	# information. Things that should make a noise make their own.
	if not examined:
		examined = true
		examined_first_time.emit(player)
		_speak(player)
	interacted.emit(player)


func _speak(player: Node) -> void:
	if examine_lines.is_empty() or not player.has_method("say"):
		return
	for line in examine_lines:
		player.say(line)
