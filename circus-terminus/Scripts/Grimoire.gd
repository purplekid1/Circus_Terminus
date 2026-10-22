class_name Grimoire
extends Interactable
## The book on the office desk, lying open and lit from inside its own pages.
##
## Everything else in the house is dead: the lights are out, the clock has
## stopped, the fires are cold. This is the one object that is visibly still
## doing something, which is the whole job it has to do -- the player should
## see the glow from the landing and walk towards it without being told to.
##
## Reading it is a Readable-style beat rather than a puzzle. Each press turns
## to the next passage, the page-light flares, and the passage goes into the
## notebook so the player is not made to stand here memorising it.

## Read in order, one per press, then it stops on the last one.
@export var passages: Array[String] = []

## Whether touching this book is the end of the demo.
##
## The demo used to end on an Area3D across the study door, which meant it was
## over the moment you put your head into the room -- you never reached the one
## object the whole level points at. Now the room only makes you want the book,
## and the book itself is the ending. That trigger is a DialogueTrigger now.
@export var ends_demo := false
## The cutscene that plays when this book is touched. Left unset, the book just
## fades to black on its own -- see _end_demo.
@export var ending_path: NodePath
## Long enough for the first passage to be read before the picture goes. The
## fade starts after it, not with it.
@export var end_after := 4.5
@export var fade_seconds := 3.0
@export var closing_text := "END OF DEMO"

## Set once the ending has been started, so a second press cannot stack a
## second fade on top of the first.
var _ending := false

## How the pages breathe when nobody is touching it.
@export var idle_energy := 1.5
@export var flare_energy := 5.5
@export var pulse_speed := 0.9
@export var pulse_depth := 0.28

@onready var _light: OmniLight3D = $PageLight
@onready var _motes: GPUParticles3D = $Motes
@onready var _embers: GPUParticles3D = $Embers

var _page := 0
var _time := 0.0
var _flare := 0.0


func _ready() -> void:
	_time = randf() * 10.0
	_light.light_energy = idle_energy


func _process(delta: float) -> void:
	# ONCE THE ENDING STARTS, THE LIGHT IS NOT OURS. The cutscene winds it up to
	# a flare and then puts it out, and this function recomputes light_energy
	# from scratch every frame -- so with both running the breathing simply
	# overwrote the blast a frame later and the book went on glowing gently
	# through its own explosion.
	if _ending:
		return

	_time += delta

	# Two beats at unrelated rates, the same trick FlickerLight uses: a single
	# sine reads as a pulsing prop and the eye locks onto the loop in seconds.
	var breath := 0.5 * (sin(_time * pulse_speed) + sin(_time * pulse_speed * 2.7)) * 0.5 + 0.5
	var energy := idle_energy * (1.0 - pulse_depth * breath)

	if _flare > 0.0:
		_flare = maxf(_flare - delta * 1.6, 0.0)
		energy = lerpf(energy, flare_energy, _flare)

	_light.light_energy = energy


func describe(_player: Node) -> String:
	if _page >= passages.size():
		return "Nothing else in it"
	return prompt


func available(_player: Node) -> bool:
	if _ending:
		return false
	# A book that ends the demo is always worth reaching for, even once the
	# passages have run out -- otherwise the prompt goes away on the object the
	# level exists to lead you to.
	return enabled and (ends_demo or _page < passages.size())


func interact(player: Node) -> void:
	super(player)
	# Guarded here as well as in available(), not only there. The interaction
	# scan checks available() first, but a press already in flight when the
	# ending starts still arrives, and turning another page underneath a fade
	# to black is not something the player can make sense of.
	if _ending:
		return
	# The flare and the passage still happen when this is the ending; only
	# the early return changes, because an ending book with nothing left to
	# read still has to end.
	if _page >= passages.size() and not ends_demo:
		return

	var text: String = passages[_page] if _page < passages.size() else ""
	_page = mini(_page + 1, passages.size())

	_flare = 1.0
	_motes.amount_ratio = 1.0
	_embers.emitting = true

	if not text.is_empty():
		player.show_message(text, 7.0)
	if player.has_method("note") and not text.is_empty():
		player.note("%s, page %d" % [prompt, _page], text)

	if ends_demo:
		_end_demo(player)


## Hands the ending to the player's own fade, after a beat long enough to read
## what the page said. Touching the book IS the end of the demo -- see the note
## on ends_demo.
func _end_demo(player: Node) -> void:
	if _ending:
		return
	_ending = true
	# The prompt goes immediately. Leaving "Read the book" floating over a fade
	# to black invites one more press that will never be answered.
	enabled = false

	# Hand over to the cutscene if there is one. It owns everything from here,
	# including the fade and the level change.
	#
	# IMMEDIATELY, with no wait. end_after used to run first, so there were four
	# and a half seconds of standing at the desk doing nothing between the press
	# and anything happening -- long enough that the player assumes the key did
	# not register and presses again. The cutscene has its own pacing and opens
	# on a slow lean, which is the beat that delay was trying to buy.
	var ending := get_node_or_null(ending_path)
	if ending != null and ending.has_method("play"):
		ending.play(player)
		return

	# No cutscene wired: the old behaviour, which is a plain fade out after a
	# pause long enough to read the last passage.
	await player.get_tree().create_timer(end_after).timeout
	if not is_instance_valid(player):
		return
	if not player.has_method("fade_out"):
		return
	if player.has_method("set_torch"):
		player.set_torch(false)
	player.fade_out(fade_seconds, closing_text)
