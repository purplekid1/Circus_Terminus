class_name Safe
extends Interactable
## A combination safe with three spinning dials.
##
## Interacting locks the player into a fixed camera bolted to the safe and
## hands them the dials. That framing is deliberate: it takes the twitchy
## first-person camera away during a puzzle that is about reading numbers, and
## it stops the player wandering off mid-combination with the enemy nearby.
##
## The combination itself is never shown. It is assembled from Clue nodes
## scattered around the floor, each holding one digit.

signal opened(player: Node)
signal wrong_code

## Three digits, as a string. Clues elsewhere in the level should add up to it.
@export var combination := "407"

## Handed over when the safe opens.
@export var contents: ItemData

## Degrees of dial rotation per digit. Ten digits over a full turn.
@export var degrees_per_digit := 36.0

@export var swing_time := 0.9
@export var open_angle := -105.0

@onready var _focus_camera: Camera3D = $FocusCamera
@onready var _door_pivot: Node3D = $DoorPivot
@onready var _dials: Array[Node] = $DoorPivot/Dials.get_children()

var is_open := false
var occupant: Node = null

var _digits: Array[int] = [0, 0, 0]
var _selected := 0

## Each ring's running angle in degrees, NOT derived from the digit.
##
## A dial turned from 9 to 0 has moved one notch forward. Recomputing the
## angle from the digit would send it 324 degrees the other way, which is both
## wrong and, at a tenth of a second, a visible blur.
var _angles: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	_refresh_dials()


func available(player: Node) -> bool:
	if not enabled or is_open:
		return false
	return occupant == null or occupant == player


func describe(_player: Node) -> String:
	if is_open:
		return ""
	return prompt


func interact(player: Node) -> void:
	if is_open:
		return
	occupant = player
	_selected = 0
	_refresh_dials()
	_focus_camera.current = true
	player.begin_focus(self)
	_show_hint()
	# The line names keys, so it has to be redrawn if the player rebinds one or
	# puts a pad down mid-puzzle. Both are one-shot connections for the length
	# of this visit; _release takes them off again.
	if not Controls.bindings_changed.is_connected(_show_hint):
		Controls.bindings_changed.connect(_show_hint)
	if not Controls.device_changed.is_connected(_on_device_changed):
		Controls.device_changed.connect(_on_device_changed)
	super(player)


## The controls, kept on screen for as long as the dials are up. This was a
## six-second show_message, which is fine for "you found a key" and useless for
## a puzzle somebody might sit in front of for several minutes -- by the second
## guess the instructions were long gone.
func _show_hint() -> void:
	if occupant == null or not is_instance_valid(occupant):
		return
	occupant.show_hint(
		"%s / %s  pick a dial      %s / %s  turn it      %s  try it      %s  step back" % [
			Controls.glyph("Move_Left"), Controls.glyph("Move_Right"),
			Controls.glyph("Move_Forward"), Controls.glyph("Move_Backward"),
			Controls.glyph("Interact"), Controls.glyph("Back"),
		]
	)


func _on_device_changed(_pad: bool) -> void:
	_show_hint()


## Called by PlayerController while this safe holds focus. Returning nothing;
## the player simply stops routing input here once focus ends.
func handle_focus_input(event: InputEvent) -> void:
	if event.is_action_pressed("Move_Left") or event.is_action_pressed("ui_left"):
		_selected = wrapi(_selected - 1, 0, _digits.size())
		_refresh_dials()
	elif event.is_action_pressed("Move_Right") or event.is_action_pressed("ui_right"):
		_selected = wrapi(_selected + 1, 0, _digits.size())
		_refresh_dials()
	elif event.is_action_pressed("Move_Forward") or event.is_action_pressed("ui_up"):
		_turn(1)
	elif event.is_action_pressed("Move_Backward") or event.is_action_pressed("ui_down"):
		_turn(-1)
	elif event.is_action_pressed("Interact"):
		_submit()
	# Back is the way out. Pause and ui_cancel still work, because a player who
	# has rebound Back to something they cannot find should not be trapped at
	# the dials -- which is exactly the state this whole change came out of.
	elif (event.is_action_pressed("Back") or event.is_action_pressed("Pause")
			or event.is_action_pressed("ui_cancel")):
		_release()


func _turn(step: int) -> void:
	_digits[_selected] = wrapi(_digits[_selected] + step, 0, 10)
	_angles[_selected] -= step * degrees_per_digit
	_refresh_dials()


func _submit() -> void:
	if _entered() == combination:
		_open()
	else:
		wrong_code.emit()
		if occupant != null:
			occupant.show_message("The dials do not budge.", 2.0)


func _entered() -> String:
	var text := ""
	for digit in _digits:
		text += str(digit)
	return text


func _open() -> void:
	is_open = true
	var player := occupant

	# The wheel spins off first and the door follows it, because a vault door
	# that swings while its handwheel sits dead still reads as a cupboard.
	var wheel := _door_pivot.get_node_or_null("Leaf/Wheel") as Node3D
	if wheel != null:
		var turn := create_tween()
		turn.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		turn.tween_property(wheel, "rotation:z", -TAU, swing_time * 0.7)

	var swing := create_tween()
	swing.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swing.tween_interval(swing_time * 0.45)
	swing.tween_property(_door_pivot, "rotation:y", deg_to_rad(open_angle), swing_time)

	if contents != null and player != null and "inventory" in player:
		if player.inventory.add(contents):
			player.show_message("Took the %s." % contents.display_name, 3.0)
		else:
			# Refuse to silently eat the reward when all three slots are full.
			player.show_message(
				"The %s is inside, but your hands are full." % contents.display_name, 4.0
			)
			is_open = true

	_release()
	opened.emit(player)


func _release() -> void:
	# Taken off again so a safe standing in a level nobody is looking at does
	# not keep redrawing a hint for a player who walked away three rooms ago.
	if Controls.bindings_changed.is_connected(_show_hint):
		Controls.bindings_changed.disconnect(_show_hint)
	if Controls.device_changed.is_connected(_on_device_changed):
		Controls.device_changed.disconnect(_on_device_changed)
	var player := occupant
	occupant = null
	if player != null:
		# end_focus clears the hint, so there is nothing to take down here.
		player.end_focus()


## Turns each ring to its digit and lights the selected one.
##
## `Spin/Ring`, and `rotation.y`, both matter. The dial was a cylinder pitched
## -90 about X that this function spun by setting `rotation.z`; Godot composes
## Euler angles as Ry*Rx*Rz, so with a pitch already on X a Z angle turns the
## disc about its own sideways axis and it tumbled end over end like a flipped
## coin instead of turning in its own plane. Neither Euler channel is a true
## dial turn once a pitch is in the way.
##
## safe_dial.tscn therefore puts the pitch on a `Spin` node and leaves `Ring`
## square, so Ring's local Y IS the cylinder's axis and rotation.y spins it
## exactly the way a hand would. Do not put a rotation back on Ring.
func _refresh_dials() -> void:
	for index in _dials.size():
		var dial := _dials[index] as Node3D
		if dial == null:
			continue

		var ring := dial.get_node_or_null("Spin/Ring") as Node3D
		if ring != null:
			var target := deg_to_rad(_angles[index])
			if is_equal_approx(ring.rotation.y, target):
				pass
			else:
				# Tween rather than snap: the knurling and the ten graduations
				# are the only feedback that a digit changed at all, and they
				# have to be seen moving past the index mark to read as a dial.
				# The slight overshoot is the mechanism taking up its backlash.
				var spin := create_tween()
				spin.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				spin.tween_property(ring, "rotation:y", target, 0.16)

		var label := dial.get_node_or_null("Digit") as Label3D
		if label != null:
			label.text = str(_digits[index])
			# The selected dial is the only lit one, so there is never any
			# doubt about which one W/S is about to move.
			label.modulate = Color(1.0, 0.85, 0.3) if index == _selected else Color(0.55, 0.55, 0.55)
