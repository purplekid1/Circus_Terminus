class_name Pickup
extends Interactable
## An item lying in the world. Interact to move it into the inventory.
##
## Put the node in the "items" group and the vision lens tags it yellow, so the
## glass is how you find loot in a dark room.
##
## The visual is the item's own model from Scenes/items/, instanced at runtime
## from ItemData.model. It used to be a box repainted with the item's slot
## colour, which is why every pickup in the house looked like the same green
## cube -- and why the colour is now only used for the glow, never for the
## mesh.

@export var item: ItemData

## Picking this up unlocks the magnifying lens for the rest of the game.
@export var grants_magnifier := false

## Idle motion. A dropped item settles and stops; one placed by the level
## keeps turning, because a pickup that never moves is furniture.
@export var spin_speed := 45.0
@export var bob_height := 0.05
@export var bob_speed := 1.6

## Lit from within at a fraction of the item's colour, so something small on a
## dark floor is findable without the mesh itself glowing like a lantern.
@export var glow_energy := 0.22

## Set by drop(): a dropped item lies still on the floor where you left it.
var resting := false

@onready var _visual: Node3D = $Visual

var _rest_y := 0.0
var _phase := 0.0
var _model: Node3D
var _glow: OmniLight3D


func _ready() -> void:
	# A lens the player walked in holding is not lying on the ground as well.
	# This is the safety net for the carry-over in Scripts/Carry.gd: the woods
	# put a spare one where the character lands, so that starting the circus
	# level on its own is still playable, and it has to take itself away again
	# when that is not the situation.
	if grants_magnifier and Carry.has_magnifier:
		queue_free()
		return

	_rest_y = _visual.position.y
	# Desync multiple pickups so a shelf of them does not pulse in lockstep.
	_phase = randf() * TAU
	_build_visual()


## Instances the item's model under Visual. Anything already authored there --
## the fallback box in pickup.tscn -- is dropped, so a scene that has not been
## given an ItemData yet still shows something rather than nothing.
func _build_visual() -> void:
	if item == null:
		return

	if item.model != null:
		for child in _visual.get_children():
			child.queue_free()
		_model = item.model.instantiate()
		_visual.add_child(_model)

	if glow_energy > 0.0:
		_glow = OmniLight3D.new()
		_glow.light_color = item.color
		_glow.light_energy = glow_energy
		_glow.omni_range = 0.85
		_glow.omni_attenuation = 2.0
		_glow.shadow_enabled = false
		_visual.add_child(_glow)

	# ASK TO BE TAGGED AGAIN, now that there is something to tag.
	#
	# The scene carries a placeholder box, and the lines above throw it away
	# and instantiate the real item model in its place. All of that happens in
	# _ready, which is strictly after VisionTags saw this node enter the tree
	# and tagged the placeholder -- so without this the item ends up with a
	# dozen meshes and not one of them carrying the lens overlay, and it stops
	# showing up through the glass entirely. No error, nothing wrong-looking in
	# the source; the item is simply invisible to the one tool the game is
	# built around.
	#
	# By node path rather than the bare autoload name: see Scripts/Stalker.gd.
	var tags := get_node_or_null("/root/VisionTags")
	if tags != null:
		tags.tag(self)


func _process(delta: float) -> void:
	if resting:
		return
	_phase += delta
	_visual.rotate_y(deg_to_rad(spin_speed) * delta)
	_visual.position.y = _rest_y + sin(_phase * bob_speed) * bob_height


func describe(_player: Node) -> String:
	return "Take %s" % (item.display_name if item != null else "item")


## Refuses once the bag is full, so the crosshair greys out and says why
## instead of letting the player press E at a key that will not come with them.
func available(player: Node) -> bool:
	if not enabled or item == null:
		return enabled
	if item.is_equipment:
		return true
	var inventory := _inventory(player)
	return inventory == null or not inventory.is_full() or _stacks_onto(inventory)


func _stacks_onto(inventory: Inventory) -> bool:
	if not item.stackable:
		return false
	for index in Inventory.SLOT_COUNT:
		if inventory.slots[index] == item and inventory.counts[index] < item.max_stack:
			return true
	return false


func interact(player: Node) -> void:
	super(player)
	if item == null:
		return

	var inventory := _inventory(player)
	if inventory == null or not inventory.add(item):
		return

	# Non-positional: this is the player's own hands, not something happening
	# across the room.
	var sound := _sound()
	if sound != null:
		sound.play_ui("pickup", -11.0)
	if item.is_equipment:
		player.show_message("Picked up the %s." % item.display_name, 3.0)
	if grants_magnifier and player.has_method("grant_magnifier"):
		player.grant_magnifier()
	queue_free()


func _inventory(player: Node) -> Inventory:
	return player.inventory if player != null and "inventory" in player else null


# --------------------------------------------------------------------- drop

const SCENE_PATH := "res://Scenes/pickup.tscn"

## Cached on first drop rather than preloaded. pickup.tscn has THIS script on
## its root, so a preload here is a cycle -- the script needs the scene, the
## scene needs the script -- and the resource loader resolves that by handing
## one of them back half-built.
static var _scene: PackedScene


## Puts `what` back into the world at `where`, parented under `parent`.
##
## Static, and it builds the whole node itself, because the alternative is for
## PlayerController to know the layout of pickup.tscn. Dropping is the inverse
## of taking and both belong in the same file.
static func drop(what: ItemData, parent: Node, where: Transform3D) -> Pickup:
	if what == null or parent == null:
		return null
	if _scene == null:
		_scene = load(SCENE_PATH) as PackedScene
	var node := _scene.instantiate() as Pickup
	node.item = what
	node.resting = true
	node.prompt = what.display_name
	# It has already been examined -- the player is the one who put it down --
	# so the crosshair says "Take the crowbar" rather than making them press E
	# to rediscover what it is.
	node.examined = true
	parent.add_child(node)
	node.global_transform = where
	return node


## The Sound autoload by node path rather than by its bare name.
##
## Pickup has no class_name of its own, but the fairground test names the
## ItemData and Inventory types it touches, which drags this file into a
## --script compile where autoloads are not registered yet. Same reason as the
## note in Scripts/Stalker.gd.
func _sound() -> Node:
	return get_node_or_null("/root/Sound")
