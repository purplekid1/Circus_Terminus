class_name TokenGate
extends Interactable
## The turnstile at the mouth of the fairground. Opens for brass tokens.
##
## This is the first thing the level asks of the player, and its real job is
## not the gate -- it is teaching them to sweep the place with the lens. The
## tokens are scattered through the entrance district in exactly the sort of
## dark clutter the naked eye slides over, and they tag yellow through the
## glass like every other item in the game. A player who walks straight down
## the midway finds none of them, reads "three brass tokens, I have one" off
## the gate, and works out the rest themselves.
##
## IT SLIDES, IT DOES NOT SWING. The leaf is a baked mesh whose vertices are
## in world coordinates, so its node origin is not at its hinge and rotating it
## would sweep it through an arc centred on the middle of the level. Sliding is
## a translation, which is origin-independent and therefore correct whatever
## the bake did with the geometry. It is also what a fairground hoarding
## actually does.

signal opened(player: Node)

## How many the gate wants. Three: enough that finding one is not the end of
## it, few enough that the player is not still hunting after ten minutes.
@export var tokens_needed := 3
## Matched against ItemData.id in the player inventory.
@export var token_id := "token"

@export_group("The leaf")
## The moving half, as its own node so the bake keeps it.
@export var leaf: NodePath
## Where the leaf ends up, relative to where it starts. Into the slot beside
## the left-hand pier -- see ticket_gate() in tools/fair.awk.
@export var slide := Vector3(-7.2, 0.0, 0.0)
@export var slide_time := 2.4

@export_group("What it says")
@export var locked_prompt := "Turnstile, chained"
@export var open_prompt := "Turnstile"
@export var paid_lines: Array[String] = [
	"Three tokens. The chain came off in my hand.",
]
@export var short_lines: Array[String] = [
	"Brass tokens. It wants three, and it is not interested in anything else.",
]

var is_open := false

## One writer for the leaf. Interacting twice while it is moving would start a
## second tween from a half-open position and land it short.
var _slide_tween: Tween


func _ready() -> void:
	prompt = locked_prompt


func describe(player: Node) -> String:
	if is_open:
		return open_prompt
	return "%s  (%d of %d)" % [locked_prompt, _tokens_held(player), tokens_needed]


func _tokens_held(player: Node) -> int:
	var inv := _inventory(player)
	if inv == null:
		return 0
	var n := 0
	for i in Inventory.SLOT_COUNT:
		if inv.slots[i] != null and inv.slots[i].id == token_id:
			n += inv.count_at(i)
	return n


func _inventory(player: Node) -> Inventory:
	if player == null or not ("inventory" in player):
		return null
	return player.inventory as Inventory


func interact(player: Node) -> void:
	if is_open:
		return

	var held := _tokens_held(player)
	if held < tokens_needed:
		# Say the count rather than "it is locked". The player needs to know
		# this is a collection problem, not a key they have not found yet.
		if player.has_method("say"):
			for line: String in short_lines:
				player.say(line)
			player.say("Three tokens. I have %d." % held)
		if _sound() != null:
			_sound().play_at("door_locked", self, -4.0)
		return

	_spend(player)
	open(player)
	if player.has_method("say"):
		for line: String in paid_lines:
			player.say(line)


## Takes exactly `tokens_needed` from the bag. Counted out one at a time
## because a slot can hold a stack and taking the slot would take the lot.
func _spend(player: Node) -> void:
	var inv := _inventory(player)
	if inv == null:
		return
	var left := tokens_needed
	for i in Inventory.SLOT_COUNT:
		while left > 0 and inv.slots[i] != null and inv.slots[i].id == token_id:
			inv.take_at(i)
			left -= 1


## `instant` skips the slide. Only tools/probe_circus.gd passes it: the probe
## opens every gate and then immediately walks through, and a 2.4 second tween
## has not moved the leaf a centimetre by the time it gets there.
func open(player: Node = null, instant := false) -> void:
	if is_open:
		return
	is_open = true
	prompt = open_prompt
	_set_collider(false)
	opened.emit(player)
	if _sound() != null and not instant:
		_sound().play_at("gate_open", self, -3.0, 40.0)

	var node := get_node_or_null(leaf) as Node3D
	if node == null:
		push_warning("TokenGate: leaf path '%s' resolves to nothing; the gate " % leaf
			+ "is open as far as the game is concerned but nothing moved.")
		return

	if instant:
		node.position += slide
		return

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property(node, "position", node.position + slide, slide_time)


## The gate has a collider of its own purely so there is something to POINT at
## -- the leaf is a baked mesh and the player raycast needs a body under a node
## carrying this script. It is sized and placed to sit INSIDE the leaf, so
## while the gate is shut it blocks nothing the leaf was not blocking anyway.
##
## When the leaf slides away it has to go too, or the open gateway keeps an
## invisible panel across it and the player walks into a wall they can see
## straight through. That was exactly what the route probe caught.
func _set_collider(on: bool) -> void:
	for node in find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = not on


## The Sound autoload by node path -- this file has a class_name, so the test
## tools name it as a type and compile it in a context where autoloads are not
## registered yet. See the same note in Scripts/Stalker.gd.
func _sound() -> Node:
	return get_node_or_null("/root/Sound")
