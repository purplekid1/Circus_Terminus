class_name Lever
extends Interactable
## A two-position lever that drives other nodes.
##
## Targets are wired by NodePath rather than by connecting the signal in the
## editor, because .tscn signal connections are exactly the kind of thing that
## gets lost when a scene is re-saved. A path in an exported array survives.

signal toggled(is_on: bool)

@export var is_on := false
@export var on_angle := 45.0
@export var off_angle := 135.0
@export var throw_time := 0.25

@export_group("Targets")
## Each target gets, in order of preference: set_powered(bool) if it has one,
## then unlock() when switching on for a Door, then plain visibility.
@export var targets: Array[NodePath] = []

@onready var _handle: Node3D = $Handle

var _throw: Tween


func _ready() -> void:
	_handle.rotation.x = deg_to_rad(on_angle if is_on else off_angle)
	# Push the starting state out so targets match the lever on load.
	_drive_targets()


func describe(_player: Node) -> String:
	return "%s %s" % ["Turn off" if is_on else "Turn on", prompt]


func interact(player: Node) -> void:
	super(player)
	is_on = not is_on

	if _throw:
		_throw.kill()
	_throw = create_tween()
	_throw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_throw.tween_property(
		_handle, "rotation:x", deg_to_rad(on_angle if is_on else off_angle), throw_time
	)

	_drive_targets()
	toggled.emit(is_on)


func _drive_targets() -> void:
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			continue

		if target.has_method("set_powered"):
			target.set_powered(is_on)
		elif target is Door:
			if is_on:
				(target as Door).unlock()
		elif target is Node3D:
			(target as Node3D).visible = is_on
