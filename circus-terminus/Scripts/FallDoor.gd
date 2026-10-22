class_name FallDoor
extends Node3D
## A door that does not open. It comes off its hinges and goes flat.
##
## Driven by a Lever through set_powered(), so the switch on the wall does not
## need to know anything about it beyond the NodePath.
##
## THE FALL ITSELF IS AN ANIMATION, not code. Scenes/fall_door.tscn carries an
## AnimationPlayer whose "fall" animation turns the pivot and, on two method
## tracks, calls _burst() for the dust and _landed() when it hits. That used to
## be a tween plus an await on a timer, which meant the timing between the door
## and the dust -- the thing that actually sells it -- lived as a number buried
## in an export where nobody could see it or drag it.
##
## WHY IT IS NOT BAKED GEOMETRY. Everything else in the fairground is CSG that
## tools/bake.gd melts into one mesh, and a baked mesh keeps its vertices in
## WORLD coordinates -- its node sits at the origin and rotating it swings the
## geometry through an arc centred on the middle of the level. That is survivable
## for a gate that slides, which is why TokenGate slides. It is fatal for
## something that has to turn about its own bottom edge. So this door is built
## out of real nodes: the hinge is this node, Pivot turns about it, and the
## panel hangs off Pivot already offset by half its height.
##
## WHY THE COLLISION GOES AWAY AT THE END. A panel lying flat is still 0.35 m
## thick, and CharacterBody3D in this project has no step-up -- the player would
## walk up to the fallen door and stop dead against it, which is a worse bug
## than the door never falling. Once it is down it is scenery.

signal fell

## Kept for the fallback path and for the tests; the animation is 0.85 s long
## and this has to agree with it.
@export var fall_time := 0.85
## Slightly past flat, so it lands and stays rather than easing to a halt at
## exactly horizontal, which reads as being lowered on a wire.
@export var fall_angle := -94.0
## Held shut until something throws the switch. A door that can be pushed over
## by walking into it is not a puzzle.
@export var starts_up := true

@export_group("The moment it lands")
@export var dust: NodePath
@export var grit: NodePath
## How far into the fall the dust goes off. Not at the end: the cloud wants to
## be already rising as the panel hits, or it reads as an afterthought.
@export_range(0.0, 1.0) var dust_at := 0.82
@export var lines: Array[String] = [
	"It did not open. It came down.",
]

@onready var _pivot: Node3D = $Pivot
@onready var _anim: AnimationPlayer = get_node_or_null("Anim")

var is_down := false

## No tween any more -- the AnimationPlayer owns the motion, and is_down stops
## a second throw restarting it.


func _ready() -> void:
	if not starts_up and _anim != null and _anim.has_animation("down"):
		_anim.play("down")
	elif _pivot != null:
		_pivot.rotation.x = 0.0 if starts_up else deg_to_rad(fall_angle)
	is_down = not starts_up
	if is_down:
		_set_collision(false)


## What Lever calls. Only ever one way -- you cannot put it back up.
func set_powered(on: bool) -> void:
	if on:
		drop()


func drop() -> void:
	if is_down or _pivot == null:
		return
	is_down = true

	if _anim != null and _anim.has_animation("fall"):
		_anim.play("fall")
	else:
		# No AnimationPlayer in the scene: put it down rather than leaving the
		# only way out of the level standing shut.
		push_warning("FallDoor: no 'fall' animation; dropping it without one.")
		_pivot.rotation.x = deg_to_rad(fall_angle)
		_burst()
		_landed()


## Called BY THE ANIMATION, from a method track placed just before the panel
## lands, so the cloud is already coming up as it arrives. It used to wait on a
## timer for a fraction of fall_time; the animation knows when better than a
## multiplier does.
func _burst() -> void:
	if not is_inside_tree():
		return

	for path in [dust, grit]:
		var node := get_node_or_null(path)
		if node == null:
			continue
		# CPUParticles3D and GPUParticles3D both take this, and neither one
		# restarts on its own once emitting has been set true and run out.
		node.set("restart_on_emitting", false)
		node.call("restart")
		node.set("emitting", true)

	var sound := get_node_or_null("/root/Sound")
	if sound != null:
		sound.play_at("door_fall", self, -1.0, 70.0)


func _landed() -> void:
	_set_collision(false)
	fell.emit()
	var who := get_tree().get_first_node_in_group("player")
	if who != null and who.has_method("say"):
		for line: String in lines:
			who.say(line)


func _set_collision(on: bool) -> void:
	for node in find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = not on
