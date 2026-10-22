extends Node3D
## The opening cutscene: a few shots of the house from the road, a title, and
## then the camera hands over to the player standing at the gate.
##
## Shots are authored as child Node3D markers IN PAIRS -- Shot0A/Shot0B is one
## shot, the camera cutting to A and drifting to B. A single chain of markers
## with the camera walking down it was the first version and it had no cuts in
## it at all, which is the difference between a cutscene and a slow pan.
##
## The whole thing is skippable from the first frame. An intro you cannot skip
## is a punishment for dying, and this one plays every time the scene loads.

## One line per shot, shown while that shot is on screen.
@export var lines: PackedStringArray = []

## What each shot is pointed at, in world space, one per shot. The markers
## carry POSITIONS ONLY and the camera is aimed here instead, because aiming a
## marker by hand means typing a nine-number basis and getting it wrong; a
## point in the world is three numbers you can read off the map.
@export var look_targets: PackedVector3Array = []

## Used for any shot with no entry in look_targets.
@export var default_target := Vector3.ZERO

## The car the character arrives in. Set it and the cutscene opens on the
## drive up instead of on a static plate of the house.
##
## It is started and then LET RUN: the car and the camera are on separate
## clocks and neither waits for the other. Cutting a shot mid-approach is
## normal film grammar, and gating the edit on the car arriving would mean
## every retimed shot needed the drive retimed with it.
@export var car_path: NodePath

## Seconds to hold on black before the car's lights appear. Nothing reads as
## "you have arrived somewhere remote" like three seconds of nothing.
@export var cold_open := 1.4

@export var title := "CIRCUS TERMINUS"
@export var subtitle := ""

@export var shot_time := 5.0
## Black between shots. Short: long enough to read as a cut, not as a loading
## pause.
@export var cut_time := 0.35
@export var hand_over_time := 1.6

## Letterbox depth is 110 px and lives in Scenes/ui/intro_overlay.tscn now --
## on the two bars, and in the "hand_over" animation that retracts them. It was
## a constant here when this file built the overlay by hand.

## Metres the camera drifts on top of the A-to-B move, along its own forward
## axis. A shot that only translates between two fixed points still reads as
## static if both points are far away; a constant creep does not.
@export var push_in := 0.35

signal finished

## The letterbox, the fade, the title, the line and the skip hint. It used to
## be ninety lines of Control construction down at the bottom of this file;
## it is Scenes/ui/intro_overlay.tscn now, and the fades are ANIMATIONS on it
## rather than tweens built here.
const OVERLAY := preload("res://Scenes/ui/intro_overlay.tscn")

@onready var _camera: Camera3D = $Camera3D

var _shots: Array[Array] = []
var _player: Node3D
var _hud: CanvasLayer
var _overlay: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _fade: ColorRect
var _title: Label
var _line: Label
var _skip: Label

## Cuts and the hand-over. A SECOND player carries the title, because the
## title rides over the first shot's fade-in and one AnimationPlayer can only
## play one thing at a time.
var _anim: AnimationPlayer
var _title_anim: AnimationPlayer

var _running := false
var _skipped := false


func _ready() -> void:
	_collect_shots()
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		queue_free()
		return
	_hud = _player.get_node_or_null("CanvasLayer")

	_build_overlay()
	_run()


## Pairs up children called Shot<n>A / Shot<n>B. Anything unpaired is skipped
## rather than played as a still, because a half-authored shot is a mistake and
## silently showing it would hide the mistake.
func _collect_shots() -> void:
	var index := 0
	while true:
		var a := get_node_or_null("Shot%dA" % index) as Node3D
		var b := get_node_or_null("Shot%dB" % index) as Node3D
		if a == null or b == null:
			break
		var target: Vector3 = (
			look_targets[index] if index < look_targets.size() else default_target
		)
		_shots.append([_pose(a.global_position, target), _pose(b.global_position, target)])
		index += 1


## A camera pose at `pos` aimed at `target`. Falls back to an unrotated pose
## if the two coincide, which looking_at would otherwise assert on.
func _pose(pos: Vector3, target: Vector3) -> Transform3D:
	if pos.is_equal_approx(target):
		return Transform3D(Basis(), pos)
	return Transform3D(Basis(), pos).looking_at(target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	_check_skip(event)


## Focus sink. PlayerController hands every event to whatever currently holds
## focus and DROPS focus outright if the holder has no handle_focus_input, so
## this has to exist even though all it does is listen for the skip -- without
## it the first key press would hand the controls back mid-cutscene.
func handle_focus_input(event: InputEvent) -> void:
	_check_skip(event)


func _check_skip(event: InputEvent) -> void:
	if not _running or _skipped:
		return
	var pressed: bool = (
		event.is_action_pressed("Skip")
		or event.is_action_pressed("Interact")
		or event.is_action_pressed("Pause")
		or event.is_action_pressed("Journal")
		or (event is InputEventMouseButton and event.pressed)
	)
	if pressed:
		_skipped = true
		get_viewport().set_input_as_handled()


func _run() -> void:
	_running = true
	_skipped = false

	# The player keeps existing -- their capsule is where the cutscene ends and
	# gameplay begins -- but they must not be able to walk out of shot.
	if _player.has_method("begin_focus"):
		_player.begin_focus(self)
	if _hud != null:
		_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_camera.current = true
	_fade.color.a = 1.0

	var car := get_node_or_null(car_path)
	if car != null and car.has_method("arrive"):
		# Deliberately not awaited -- see car_path.
		car.arrive()

	if cold_open > 0.0:
		await get_tree().create_timer(cold_open).timeout

	for index in _shots.size():
		if _skipped:
			break
		await _play_shot(index)

	# A skip has to leave the world in the state the cutscene would have left
	# it in, or the player walks out to a car still rolling down the road with
	# its lights on.
	if _skipped and car != null and car.has_method("park"):
		car.park()

	await _hand_over()


func _play_shot(index: int) -> void:
	var from: Transform3D = _shots[index][0]
	var to: Transform3D = _shots[index][1]

	_camera.global_transform = from
	_line.text = lines[index] if index < lines.size() else ""
	_line.modulate.a = 0.0

	# Fade up out of the cut. "cut_in" is authored in units of cut_time -- the
	# fade is one unit long and the line takes two -- so playing it at
	# 1/cut_time is what makes the export mean seconds. Not awaited: the shot
	# starts moving underneath it.
	_anim.speed_scale = 1.0 / maxf(cut_time, 0.01)
	_anim.play(&"cut_in")

	# The title rides the first shot only. It is keyed at the default five
	# second shot and scaled to whatever shot_time actually is, so a longer
	# opening shot holds the title longer instead of leaving it hanging.
	if index == 0:
		_title_anim.speed_scale = 5.0 / maxf(shot_time, 0.01)
		_title_anim.play(&"title")

	var elapsed := 0.0
	while elapsed < shot_time and not _skipped:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / shot_time, 0.0, 1.0)
		# ease in-out on the interpolation itself rather than on a tween, so
		# the loop can still be cut short by a skip on any frame
		var e := t * t * (3.0 - 2.0 * t)
		_camera.global_transform = from.interpolate_with(to, e)
		_camera.global_position -= _camera.global_transform.basis.z * push_in * e
		await get_tree().process_frame

	_anim.speed_scale = 1.0 / maxf(cut_time, 0.01)
	_anim.play(&"cut_out")
	await _anim.animation_finished


## Black, then the player's own camera comes up out of it.
func _hand_over() -> void:
	_fade.color.a = 1.0
	_title.modulate.a = 0.0
	_line.text = ""

	if _player.has_method("end_focus"):
		_player.end_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _hud != null:
		_hud.visible = true

	# One unit long, so the export sets the seconds. The skip hint is keyed to
	# go at 0.1875 of it, which is the 0.3 s it always took against the 1.6 s
	# default -- it fades with the bars rather than on its own clock now.
	_anim.speed_scale = 1.0 / maxf(hand_over_time, 0.01)
	_anim.play(&"hand_over")
	await _anim.animation_finished

	_running = false
	_overlay.queue_free()
	finished.emit()
	queue_free()


# ----------------------------------------------------------------- overlay

## Instances Scenes/ui/intro_overlay.tscn and takes hold of the bits that get
## written to. Everything about how it LOOKS -- anchors, offsets, font sizes,
## the letterbox depth -- lives in that scene now, and everything about how it
## MOVES lives in the two AnimationPlayers on it. What is left here is the two
## pieces of text that are not known until runtime.
func _build_overlay() -> void:
	_overlay = OVERLAY.instantiate()
	add_child(_overlay)

	_fade = _overlay.get_node("Fade")
	_bar_top = _overlay.get_node("BarTop")
	_bar_bottom = _overlay.get_node("BarBottom")
	_title = _overlay.get_node("Title")
	_line = _overlay.get_node("Line")
	_skip = _overlay.get_node("Skip")
	_anim = _overlay.get_node("Anim")
	_title_anim = _overlay.get_node("TitleAnim")

	_title.text = title if subtitle.is_empty() else "%s\n%s" % [title, subtitle]
	_skip.text = "%s skip" % Controls.glyph("Skip")
