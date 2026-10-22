class_name Door
extends Interactable
## A swinging door. Optionally locked behind an inventory item.
##
## The panel hangs off a Hinge child, so this node stays put at the frame and
## only the hinge rotates. The panel itself is an AnimatableBody3D rather than
## a StaticBody3D: a static body swinging into the player would leave them
## stuck inside the geometry, an animatable one pushes them out of the way.

signal opened
signal closed
signal unlocked

@export var open_angle := 95.0
@export var swing_time := 0.5
@export var start_open := false

@export_group("Lock")
@export var locked := false
## ItemData.id the player must have in the SELECTED slot. Empty means the
## lock can only be opened by something else calling unlock().
@export var key_id := ""
@export var locked_prompt := "Locked"
## Take the key when it is used. Off by default so a key stays a keepsake.
@export var consume_key := false

var is_open := false

@onready var _hinge: Node3D = $Hinge

var _swing: Tween


func _ready() -> void:
	is_open = start_open
	_hinge.rotation.y = deg_to_rad(open_angle) if is_open else 0.0


## Refuses while locked without the key, so the HUD greys the line out and
## drops the [E] hint rather than promising something Interact will not do.
func available(player: Node) -> bool:
	if not enabled:
		return false
	return not locked or _has_key(player)


func describe(player: Node) -> String:
	if locked and not _has_key(player):
		# No key id at all means nothing will ever open it -- the front door of
		# the mansion. Saying "needs a key" there would send the player hunting
		# for one that does not exist.
		if key_id.is_empty():
			return locked_prompt
		return "%s - needs %s" % [locked_prompt, _key_name()]
	if locked:
		return "Unlock"
	return "Close" if is_open else "Open"


func interact(player: Node) -> void:
	# super() first: it flips `examined`, which is what turns the crosshair
	# from a bare name into the real state from here on.
	super(player)

	if locked:
		if not _has_key(player):
			# It refuses, and it has to SOUND like a refusal -- see the note in
			# gen_sfx.gd. available() already greys the prompt out, but a player
			# who presses anyway deserves an answer.
			_sound_play("door_locked", self, -4.0)
			return
		locked = false
		unlocked.emit()
		if consume_key:
			_inventory(player).drop_selected()
		# Fall through: unlocking also swings it, so one press is one action.

	set_open(not is_open)


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value

	# Barred iron and a panelled door are not the same object. The gate carries
	# a key_id and its own prompt; anything with bars in it gets the iron one.
	var iron := prompt.to_lower().contains("gate")
	if is_open:
		_sound_play("gate_open" if iron else "door_open", self, -5.0)
	else:
		_sound_play("door_close", self, -5.0)

	if _swing:
		_swing.kill()
	_swing = create_tween()
	# Physics-stepped, because the panel is an AnimatableBody3D with
	# sync_to_physics on. Driving it from the idle frame makes it jitter
	# against the player and stop pushing them cleanly.
	_swing.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_swing.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swing.tween_property(
		_hinge, "rotation:y", deg_to_rad(open_angle) if is_open else 0.0, swing_time
	)

	if is_open:
		opened.emit()
	else:
		closed.emit()


## Swings to an explicit angle without touching the open/closed flag. Hiding
## spots use it to pull the door to a peeking gap rather than fully shut, so
## the player can still watch the room instead of staring at the back of a
## closed panel.
func swing_to(degrees: float) -> void:
	if _swing:
		_swing.kill()
	_swing = create_tween()
	_swing.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_swing.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_hinge, "rotation:y", deg_to_rad(degrees), swing_time)


## Lets a lever or a script open the lock without an item.
func unlock() -> void:
	if not locked:
		return
	locked = false
	unlocked.emit()


func _has_key(player: Node) -> bool:
	if key_id.is_empty():
		return false
	var inventory := _inventory(player)
	return inventory != null and inventory.selected_is(key_id)


func _inventory(player: Node) -> Inventory:
	if player != null and "inventory" in player:
		return player.inventory
	return null


func _key_name() -> String:
	# Falls back to the raw id so a missing item resource is still legible.
	return key_id.capitalize() if not key_id.is_empty() else "a key"


## Plays through the Sound autoload, looked up by node path rather than named
## directly.
##
## Door has no class_name, but Lever does and it names Door as a type, so any
## tool script that mentions a Lever drags this file into a --script compile --
## and autoloads are not registered in that context, which made the bare name a
## compile error that took the whole fairground test suite down with it. Same
## reason as the note in Scripts/Stalker.gd.
func _sound_play(effect: String, where: Node3D, db := 0.0) -> void:
	var sound := get_node_or_null("/root/Sound")
	if sound != null:
		sound.play_at(effect, where, db)
