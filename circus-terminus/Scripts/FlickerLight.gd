@tool
extends OmniLight3D
## Dying-bulb flicker for a practical light.
##
## Two sine waves at unrelated frequencies plus occasional hard dropouts. A
## single sine reads as a pulse and the eye locks onto the loop immediately;
## the incommensurate pair never repeats audibly and the dropouts are what
## actually sell "this bulb is about to die".
##
## @tool so the flicker previews in the editor viewport while you light the
## scene. It restores base_energy on exit, so it never bakes a random value
## into the saved scene.

@export var base_energy := 2.4:
	set(value):
		base_energy = value
		light_energy = value

## Depth of the continuous wobble, as a fraction of base_energy.
@export_range(0.0, 1.0) var flicker_depth := 0.3

## Expected dropouts per second.
@export_range(0.0, 5.0) var dropout_rate := 0.45

## How far the light drops during a dropout, as a fraction of base_energy.
@export_range(0.0, 1.0) var dropout_depth := 0.85

## Seconds a dropout lasts.
@export var dropout_length := 0.09

var _time := 0.0
var _dropout_until := -1.0


func _ready() -> void:
	# Desync multiple lights in the same scene.
	_time = randf() * 100.0


func _exit_tree() -> void:
	light_energy = base_energy


func _process(delta: float) -> void:
	_time += delta

	# 3.1 and 7.7 share no common period, so the pattern never visibly loops.
	var wobble := 0.5 * (sin(_time * 3.1) + sin(_time * 7.7)) * 0.5 + 0.5
	var energy := base_energy * (1.0 - flicker_depth * wobble)

	if _time < _dropout_until:
		energy *= 1.0 - dropout_depth
	elif randf() < dropout_rate * delta:
		_dropout_until = _time + dropout_length

	light_energy = energy
