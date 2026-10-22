extends Node3D
## Coming round on the forest floor, and getting up.
##
## Runs the moment the level opens, before the player has any control. The point
## is continuity: the last thing they saw was falling, so the first thing they
## see has to be the ground, from the height of somebody lying on it.
##
## THE EYES OPEN BEFORE THE BODY MOVES. Two slow blinks against black, then the
## head turns, and only then does the character push up onto their feet. Getting
## that order wrong -- standing first and fading in after -- turns waking up into
## a loading screen.
##
## Like BookEnding, this holds focus for its whole length, which means
## PlayerController._physics_process returns before it touches velocity. The
## camera is driven from here; nothing is physical until control is handed back.
##
## THE CHOREOGRAPHY IS IN THE ANIMATOR. `Anim` is an instance of
## Scenes/anim/wake.tscn and it owns the whole running order -- when each blink
## fires, how long the head turn takes, the curve the body rises on, when the
## stagger lands and when control comes back. This script owns only the shape of
## the poses: how far down the eye starts, how far the head turns, how big the
## stagger is. Retiming the scene is a job for the animation panel; changing
## what "flat on the floor" means is a job for the inspector.
##
## THE THREE FLOATS BELOW ARE WRITTEN BY THE ANIMATION, not by anything here.
## Each runs 0 -> 1 across its own phase and its setter turns that into a camera
## pose, measured from the rest pose the controller expects. That split is what
## lets the curves live in a .tscn at all: a keyframe cannot know where this
## player's eye sits, and the inspector should not have to care what easing the
## body rises on.
##
## ONE WRITER AT A TIME. `stand` writes the whole camera transform and `sway`
## writes only the roll, so while the body is still coming up `sway` keeps its
## hands off -- otherwise it would write the roll flat on every frame and cancel
## the very thing `stand` is easing out.

## Where the eye starts, relative to its normal standing place: down on the
## floor and rolled onto one side.
@export var down_height := -0.78
@export var down_roll := 64.0
@export var down_pitch := -38.0

## The blinks. Each one is a fade from black and back, and the second is longer
## than the first because that is how coming round works. These are the
## FLASH durations -- when each blink fires is a key in the animation.
@export var blink_a := 0.5
@export var blink_gap := 0.45
@export var blink_b := 1.1

## How far the head turns while still on the floor.
@export var look_yaw := 26.0

## A stagger at the top, because nobody who has just fallen out of the sky
## arrives steady.
@export var sway_degrees := 4.5

## Said while they are still on the ground. Empty lines are skipped.
@export var lines: PackedStringArray = []

## Handed over to at the end. Left empty, control simply returns to the player.
@export var objective := ""

@export var player_path := NodePath("../Player")

@onready var _anim: AnimationPlayer = $Anim

var _player: Node3D
var _cam: Node3D
var _eye0 := Vector3.ZERO
var _rot0 := Vector3.ZERO
var _done := false


## Turning the head on the ground before trying to move it. Written by the
## animation; the sine is here rather than in the keys so the turn is one
## smooth there-and-back whatever the curve does.
var look := 0.0:
	set(value):
		look = value
		if _cam == null:
			return
		_cam.rotation_degrees.y = _rot0.y + sin(value * PI) * look_yaw

## Getting up. The roll comes out over the first half and the height arrives
## over the whole of it, so the body rights itself before it rises.
var stand := 0.0:
	set(value):
		stand = value
		if _cam == null:
			return
		var roll := 1.0 - minf(value * 1.8, 1.0)
		_cam.position = _eye0 + Vector3(0.0, down_height * (1.0 - value), 0.0)
		_cam.rotation_degrees = Vector3(
			_rot0.x + down_pitch * (1.0 - value) * (1.0 - value),
			_rot0.y,
			_rot0.z + down_roll * roll)

## The stagger at the top. See the note on one writer at a time: until `stand`
## has finished, the roll belongs to it.
var sway := 0.0:
	set(value):
		sway = value
		if _cam == null or stand < 1.0:
			return
		_cam.rotation_degrees.z = _rot0.z + sin(value * TAU) * sway_degrees * (1.0 - value)


func _ready() -> void:
	# One frame, so the player's own _ready has run and its camera exists.
	await get_tree().process_frame
	_play()


## The focus sink. PlayerController hands every event to whatever holds focus
## and drops focus outright if the holder cannot take it, which would give the
## controls back in the middle of this.
func handle_focus_input(_event: InputEvent) -> void:
	pass


func _play() -> void:
	_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		push_warning("WakeUp: no player at %s -- skipping." % player_path)
		return

	_cam = _player.camera
	_eye0 = _cam.position
	_rot0 = _cam.rotation_degrees

	_player.begin_focus(self)
	# Flat on the ground, cheek down. The animation writes the same pose on its
	# first frame; this is here so there is never a frame of standing upright
	# between focus being taken and the player starting.
	_cam.position = _eye0 + Vector3(0.0, down_height, 0.0)
	_cam.rotation_degrees = _rot0 + Vector3(down_pitch, 0.0, down_roll)

	_anim.play(&"wake")


# ------------------------------------------------- called from the animation
# All four of these are method-track keys in Scenes/anim/wake.tscn, at the
# frames they belong to. Nothing else should call them.

func _blink_one() -> void:
	_player.flash(Color(0, 0, 0, 1), 0.01, blink_a, blink_a * 0.8)


func _blink_two() -> void:
	_player.flash(Color(0, 0, 0, 1), 0.12, blink_gap, blink_b)


func _speak() -> void:
	for line: String in lines:
		if not line.is_empty() and _player.has_method("say"):
			_player.say(line)


func _finish() -> void:
	# Put the camera back exactly where the controller expects it, or the head
	# bob will start from wherever this left off and never recover.
	_cam.position = _eye0
	_cam.rotation_degrees = _rot0

	_player.end_focus()
	_done = true

	if not objective.is_empty() and _player.has_method("show_message"):
		_player.show_message(objective, 7.0)
