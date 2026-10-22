class_name Readable
extends Interactable
## A thing that tells the player a fact, without telling them what it means.
##
## The safe combination is deliberately not written down anywhere. It is
## assembled from facts like these -- a stopped clock, a date on a portrait --
## plus a separate note saying which fact belongs on which dial. Neither half
## is any use alone, which is what makes it a puzzle rather than a errand.

@export_multiline var text := ""

## Needs the magnifying lens raised. Use for anything genuinely small.
@export var requires_lens := false
@export var unreadable_prompt := "Too fine to read"

@export var seconds_on_screen := 6.0

var read_already := false


func _lens_raised(player: Node) -> bool:
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
			player.say("Far too small to make out by eye.")
		return

	read_already = true
	player.show_message(text, seconds_on_screen)
	# Also into the notebook. The combination is assembled from four
	# separate facts read in four separate rooms, and asking the player to
	# hold all four in their head while they walk to the safe is asking
	# them to fetch a pen.
	if player.has_method("note"):
		player.note(prompt, text)
