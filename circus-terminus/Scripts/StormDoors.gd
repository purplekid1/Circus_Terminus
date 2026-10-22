class_name StormDoors
extends Interactable
## The pair of doors in the ground outside the house, over the cellar steps.
##
## Two leaves, not one. They were a single 3x4 metre slab on one hinge, which
## is why they read as a hatch: nothing that size opens in one piece, and the
## eye knows it. A pair meeting on the centre line is what a bulkhead over a
## flight of cellar steps actually looks like, and it is also the only way to
## get them open in a space this size without the leaf sweeping halfway
## across the garden.
##
## Door.gd cannot drive this -- it owns exactly one `$Hinge` -- so this is its
## own Interactable. The two behave as one door: one prompt, one press, both
## leaves.

signal opened
signal closed

## Degrees each leaf lifts. The west one goes negative, the east one positive,
## so they fall away from each other.
@export var open_angle := 104.0
@export var swing_time := 1.3
@export var start_open := false

## They have been shut a long time. The first haul is slower and heavier than
## every one after it, which is most of what sells them as rusted.
@export var first_open_time := 2.4

var is_open := false

@onready var _west: Node3D = $HingeWest
@onready var _east: Node3D = $HingeEast

var _swing: Tween
var _hauled := false


func _ready() -> void:
	is_open = start_open
	var a := deg_to_rad(open_angle) if is_open else 0.0
	_west.rotation.y = -a
	_east.rotation.y = a


func describe(_player: Node) -> String:
	return "Let them down" if is_open else "Haul them open"


func interact(player: Node) -> void:
	super(player)
	set_open(not is_open)


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value

	var seconds := swing_time
	if value and not _hauled:
		seconds = first_open_time
		_hauled = true

	if _swing:
		_swing.kill()
	_swing = create_tween()
	# Physics-stepped, like Door.gd: the leaves are AnimatableBody3D with the
	# player standing on top of them as often as not.
	_swing.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# Opening is a heave that runs out of momentum; closing is gravity, so it
	# accelerates and lands.
	if value:
		_swing.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_swing.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var a := deg_to_rad(open_angle) if is_open else 0.0
	_swing.tween_property(_west, "rotation:y", -a, seconds)
	_swing.parallel().tween_property(_east, "rotation:y", a, seconds)

	if is_open:
		opened.emit()
	else:
		closed.emit()
