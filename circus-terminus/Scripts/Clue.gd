class_name Clue
extends Interactable
## One digit of the safe combination, hidden somewhere in the house.
##
## By default a clue is unreadable without the magnifying lens raised. That is
## what gives the glass a reason to exist beyond the tag overlay: the player
## has to actually stop, raise it, and read.
##
## Clicking without the lens is allowed on purpose -- that click is how the
## player finds out the writing is too fine to read, and is the nudge towards
## the glass.

signal read_out(dial_index: int, digit: int)

## Which dial of the safe this digit belongs to, left to right.
@export_range(0, 2) var dial_index := 0

@export_range(0, 9) var digit := 0

## Needs the lens raised to read. Turn off for a clue meant to be plainly
## legible, like a note pinned in the open.
@export var requires_lens := true

@export_multiline var note := "The %d%s dial reads %d."

@export var unreadable_prompt := "Too fine to read"

## Spoken the first time the player squints at it without the lens.
@export var squint_lines: Array[String] = [
	"There's something written here, but it's far too small.",
]

@export var seconds_on_screen := 5.0

var solved := false


func _lens_raised(player: Node) -> bool:
	# vision_busy covers the flip animation, so a clue cannot be read through
	# a lens that is still swinging up.
	return "vision" in player and player.vision and not player.vision_busy


func available(player: Node) -> bool:
	if not enabled:
		return false
	return not requires_lens or _lens_raised(player)


func describe(player: Node) -> String:
	if requires_lens and not _lens_raised(player):
		return unreadable_prompt
	return prompt


func interact(player: Node) -> void:
	var first_try := not examined
	super(player)

	if requires_lens and not _lens_raised(player):
		if first_try:
			for line in squint_lines:
				player.say(line)
		return

	solved = true
	var reading := _compose()
	player.show_message(reading, seconds_on_screen)
	# A digit read in the cellar is no use if it has gone by the time the
	# player reaches the safe two floors up, so it goes in the notebook too.
	if player.has_method("note"):
		player.note(prompt, reading)
	read_out.emit(dial_index, digit)


func _compose() -> String:
	if not note.contains("%"):
		return note
	return note % [dial_index + 1, _ordinal_suffix(dial_index + 1), digit]


func _ordinal_suffix(value: int) -> String:
	match value:
		1: return "st"
		2: return "nd"
		3: return "rd"
		_: return "th"
