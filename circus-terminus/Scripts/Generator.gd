class_name Generator
extends Interactable
## The basement generator. Starting it is what gives the house power.
##
## Everything it drives is listed by NodePath rather than wired through editor
## signal connections, which do not survive a scene being re-saved. Targets
## get set_powered(bool) if they have it, otherwise they are simply shown.

signal powered_on(player: Node)

@export var running := false

## Nodes switched on when the generator catches -- the house lighting rig,
## powered props, anything gated behind having the lights.
@export var targets: Array[NodePath] = []

## Needs this item in the selected slot before it will turn over. Leave empty
## for a generator that only needs a hand on the crank.
@export var fuel_id := ""
@export var fuel_prompt := "Out of fuel"

@export var start_lines: Array[String] = [
	"There it goes.",
]
@export var no_fuel_lines: Array[String] = [
	"Dry. There has to be a can down here somewhere.",
]

@onready var _hum: Node3D = get_node_or_null("Hum")


func _ready() -> void:
	# Push the starting state out so the house matches the generator on load.
	_drive_targets()


func _has_fuel(player: Node) -> bool:
	if fuel_id.is_empty():
		return true
	var inventory: Inventory = player.inventory if "inventory" in player else null
	return inventory != null and inventory.selected_is(fuel_id)


func available(player: Node) -> bool:
	if not enabled or running:
		return false
	return _has_fuel(player)


func describe(player: Node) -> String:
	if running:
		return "Running"
	if not _has_fuel(player):
		return fuel_prompt
	return prompt


func interact(player: Node) -> void:
	var first_try := not examined
	super(player)

	if running:
		return

	if not _has_fuel(player):
		if first_try:
			for line in no_fuel_lines:
				player.say(line)
		return

	running = true
	_start_loop()
	# The fuel goes into the tank, not back in the bag.
	if not fuel_id.is_empty() and "inventory" in player:
		player.inventory.drop_selected()
	_drive_targets()
	for line in start_lines:
		player.say(line)
	powered_on.emit(player)


func _drive_targets() -> void:
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			continue
		if target.has_method("set_powered"):
			target.set_powered(running)
		elif target is Node3D:
			(target as Node3D).visible = running

	if _hum != null:
		_hum.visible = running


## The running bed: a looping player that lives on the generator for as long as
## it is turning. Started a beat after the crank so the two do not talk over
## each other, and audible much further away than a door -- a generator running
## in a cellar is how the player knows the lights are on before they see them.
const LOOP_IN := 1.9
const LOOP_DB := -14.0
const LOOP_RANGE := 34.0
## How far below pitch it starts, and how long it takes to get up to speed.
const SPIN_FROM := 0.55
const SPIN_UP := 2.2

var _loop: AudioStreamPlayer3D


func _start_loop() -> void:
	if _loop != null and is_instance_valid(_loop):
		return
	var stream := Sound.sfx("generator_loop")
	if stream == null:
		return

	_loop = AudioStreamPlayer3D.new()
	_loop.stream = stream
	@warning_ignore("static_called_on_instance")
	_loop.bus = Sound.bus("Sfx")
	_loop.max_distance = LOOP_RANGE
	_loop.unit_size = 6.0
	_loop.volume_db = -80.0
	# Starts slow and low and comes up to speed. There is no separate start
	# recording -- this IS the start: a diesel that is already running, played
	# back below pitch and allowed to climb. It costs one tween and sounds like
	# the same machine, which a synthesised crank never quite did.
	_loop.pitch_scale = SPIN_FROM
	add_child(_loop)
	_loop.play()
	var up := create_tween()
	up.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(_loop, "pitch_scale", 1.0, SPIN_UP)
	up.parallel().tween_property(_loop, "volume_db", LOOP_DB, LOOP_IN)


## For whatever eventually turns it off again. Nothing does yet, but a machine
## that can only ever start is a machine somebody will have to come back to.
func stop_running() -> void:
	if not running:
		return
	running = false
	_drive_targets()
	if _loop != null and is_instance_valid(_loop):
		var dying := _loop
		_loop = null
		# And dying is the same move backwards: it falls off pitch as it fades.
		var t := create_tween()
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(dying, "pitch_scale", SPIN_FROM, 1.6)
		t.parallel().tween_property(dying, "volume_db", -80.0, 1.6)
		t.tween_callback(dying.queue_free)
