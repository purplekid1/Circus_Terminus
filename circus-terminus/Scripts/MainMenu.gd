extends Node3D
## The title screen: the drive in, seen from outside the car, looping forever.
##
## THE SCENE IS THE SCENE. Road, woods, car, camera, lights, music, menu -- all
## of it is authored in Scenes/menu.tscn and can be opened, selected and moved
## in the editor. This script only does the parts that are genuinely behaviour.
## It used to build the whole thing in _ready(), which meant the scene file
## contained one node and you could not see the title screen without running
## the game. Scenes/menu.tscn is written by tools/gen_menu.sh; read that before
## changing the layout, and note that re-running it overwrites hand edits.
##
## The car does not move. The world does. A camera actually travelling down a
## road needs the road to be finite, which means either a very long one that
## ends while somebody reads the keybinds page, or a seam to hide. Here the car
## and the camera both stand still and everything under `Scroll` is recycled:
## it travels from the fog line to just behind the shot and then wraps back, so
## the drive is endless and the whole background is about eighty objects.

const LEVEL := "res://demo_level.tscn"

## Metres of road held at once, and how far past the shot a piece runs before
## it wraps. BOTH MUST MATCH tools/gen_menu.sh, which lays the scenery out on
## the same figures -- a mismatch shows up as pieces popping into frame.
const SPAN := 210.0
const BEHIND := 16.0

## Road speed in metres per second. About 50 km/h -- fast enough that the verge
## streams, slow enough that the dashes read as dashes rather than a solid line.
const SPEED := 14.0

## Where the car sits, and where the camera sits relative to it. The scene file
## has the same numbers in the two nodes' transforms; these are what the
## per-frame weave and drift are measured from.
const CAR_X := 1.55
const CAR_Z := -17.0

## Behind the car, above it, and out to the left. Behind, so the headlamps
## light the road you are looking down rather than the lens; out to the left,
## so the car sits on the right of frame clear of the text.
##
## BEHIND IS +Z. The car is built facing -Z and the scenery streams from -Z to
## +Z past it, so the direction of travel is -Z and a camera at a NEGATIVE z
## offset is out in front of it looking back at its nose.
const CAM_EYE := Vector3(-3.35, 2.15, 7.60)
## A little above the roof line and some way up the road, so the car sits low
## in frame with the road running away under it rather than filling the shot.
const CAM_AIM := Vector3(0.55, 1.20, -6.50)

## Where the music settles, and how long it takes to get there. It starts near
## silence and comes up, because a title screen that opens at full volume the
## instant the window appears makes people reach for the volume key rather than
## the mouse.
const MUSIC_DB := -7.0
const MUSIC_FADE_IN := 2.4

## Leaving for the level, in four overlapping parts: the menu slides off to the
## left, the camera tilts up off the car, the picture fades, and the music goes
## with it. The music goes with the picture because the alternative is the
## track cutting off mid-bar on the scene change.
const LEAVE_PAN := 1.7
const LEAVE_FADE := 0.8
## The panel goes first and goes quickly -- it is getting out of the way of the
## shot, not performing.
const PANEL_SLIDE := 0.5
const PANEL_OFF := -1120.0

## Where the camera looks at the end of the pan, relative to the car -- above
## it and drawn back up the road, which swings the shot off the tail lights and
## up into the treetops. Steep, but nowhere near straight up: an aim that lands
## parallel to UP makes look_at() fail.
##
## 13, not the 24 this started at. At 24 the car was out of frame a third of
## the way through the move, which is not a camera leaving a car, it is a cut
## to the sky with a slow bit in front of it.
const LEAVE_AIM := Vector3(0.55, 13.0, -9.0)
## And it cranes a little as it tilts, so the move has some parallax in it
## rather than being a bare rotation about the lens.
const LEAVE_RISE := 1.1

@onready var _camera: Camera3D = $Camera3D
@onready var _car: Node3D = $Car
@onready var _scroll: Node3D = $Scroll
@onready var _music: AudioStreamPlayer = $Music
@onready var _panel: Control = $UI/Panel
@onready var _controls_sheet: Control = $UI/ControlsSheet
@onready var _settings_sheet: Control = $UI/SettingsSheet
@onready var _blackout: ColorRect = $UI/Blackout
@onready var _menu_box: VBoxContainer = $UI/Panel/Menu

var _travelled := 0.0
## [node, its phase along the loop]. Read off the scene: whatever z a piece was
## authored at IS its offset, because z is what gets overwritten every frame.
var _movers: Array = []
var _buttons: Array[Button] = []
var _sway := 0.0

## Set once "Drive on" has been pressed, so a second press cannot start a
## second scene change over the top of the first.
var _leaving := false

## 0 while the menu is up, 1 once the departure tilt has finished. Tweened by
## _start_game and read by _aim_camera.
var _leave_pan := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for piece in _scroll.get_children():
		_movers.append([piece, fposmod((piece as Node3D).position.z, SPAN)])

	for child in _menu_box.get_children():
		if child is Button:
			_buttons.append(child as Button)

	_car.set_lights(true)
	# Wheels at road speed. The car is not going anywhere, but the tyres have
	# to agree with the tarmac or the whole thing reads as a tow.
	_car.roll(SPEED)

	var up := create_tween()
	up.tween_property(_music, "volume_db", MUSIC_DB, MUSIC_FADE_IN)

	# Focus the first entry, so the menu can be driven from a pad from the
	# first frame without anybody touching the mouse.
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

	_aim_camera(0.0)

	# Quitting while the music plays makes the engine print "1 resources still
	# in use at exit". That is Godot's own shutdown ordering, not anything here:
	# a bare scene containing nothing but one AudioStreamPlayer does it too, and
	# the same scene with play() removed does not. Left alone deliberately.


# ------------------------------------------------------------------ driving

func _process(delta: float) -> void:
	_travelled += SPEED * delta

	for entry in _movers:
		var piece: Node3D = entry[0]
		# Runs from the fog line to BEHIND metres past the shot, then wraps.
		piece.position.z = fposmod(entry[1] + _travelled, SPAN) - SPAN + BEHIND

	_sway += delta

	# A slow weave within the lane, so the car is being DRIVEN rather than
	# railed. Two sines at unrelated periods, because one on its own is a
	# pendulum and everybody can see it coming back.
	var lean := sin(_sway * 0.37) * 0.42 + sin(_sway * 0.13) * 0.22
	_car.position.x = CAR_X + lean
	# It yaws INTO the drift, the way a car that is being steered does. A car
	# sliding sideways with its nose straight ahead reads as a bug.
	_car.rotation_degrees.y = -lean * 2.4
	_car.rotation_degrees.z = lean * 1.1
	# Engine shake and the road under the tyres. Small: this is a saloon on
	# tarmac, not a tractor.
	_car.position.y = sin(_sway * 21.0) * 0.004 + sin(_sway * 7.3) * 0.008

	_aim_camera(_sway)


## Where the camera sits and what it looks at, given a time.
func _aim_camera(t: float) -> void:
	# A slow handheld drift on three periods that do not divide into each
	# other, so the loop never lands back where it started while anyone is
	# watching.
	var drift := Vector3(
		sin(t * 0.21) * 0.45,
		sin(t * 0.17) * 0.16,
		sin(t * 0.13) * 0.80
	)
	# Hung off the car's NOMINAL place in the lane, not its actual one. Hung
	# off the actual one the camera weaves with the car, the two are locked
	# solid, and the drift within the lane stops reading as driving at all.
	# The aim DOES follow the car, so the shot pans a little as it wanders --
	# which is what an operator tracking a car looks like.
	#
	# _leave_pan carries the departure tilt, 0 while the menu is up and 1 once
	# "Drive on" has swung the camera to the sky. It is folded in HERE rather
	# than tweened onto the camera transform, because this runs every frame and
	# a tween on the transform would spend the whole move being overwritten by
	# the next line.
	_camera.position = (Vector3(CAR_X, 0.0, CAR_Z) + CAM_EYE + drift
		+ Vector3(0.0, LEAVE_RISE * _leave_pan, 0.0))
	_camera.look_at(_car.position + CAM_AIM.lerp(LEAVE_AIM, _leave_pan), Vector3.UP)


# ----------------------------------------------------------------------- ui
# Wired to the buttons by [connection] lines in menu.tscn, not by connect()
# calls here -- the point of the scene holding the menu is that the wiring is
# visible in the editor too.

func _on_drive_pressed() -> void:
	_start_game()


func _on_controls_pressed() -> void:
	_show_controls(true)


func _on_settings_pressed() -> void:
	_show_sheet(_settings_sheet, true)


func _on_leave_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_sheet(_controls_sheet, false)


func _on_settings_back_pressed() -> void:
	_show_sheet(_settings_sheet, false)


## Focus follows the sheet, both ways. A pad opening a page and finding
## nothing selected cannot get back out of it, and a pad closing one and
## finding nothing selected cannot start the game.
##
## The entry that opened the sheet is the one focus returns to, found by
## looking it up rather than by index: there are four entries now and the
## hard-coded _buttons[1] this used to use put the cursor on "Controls" after
## closing the settings page.
func _show_sheet(sheet: Control, on: bool) -> void:
	sheet.visible = on
	if on:
		_focus_first.call_deferred(sheet)
		return
	var opener := _opener_for(sheet)
	if opener != null:
		opener.grab_focus()
	elif not _buttons.is_empty():
		_buttons[0].grab_focus()


## The menu entry whose name matches the sheet's, so "SettingsSheet" comes
## back to "Settings".
func _opener_for(sheet: Control) -> Button:
	var want := String(sheet.name).trim_suffix("Sheet")
	for button in _buttons:
		if String(button.name) == want:
			return button
	return null


## Kept because test_menu.gd and any older caller still say _show_controls.
func _show_controls(on: bool) -> void:
	_show_sheet(_controls_sheet, on)


func _focus_first(from: Control) -> void:
	var found := _find_focusable(from)
	if found != null:
		found.grab_focus()


func _find_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.visible:
				return control
			var deeper := _find_focusable(control)
			if deeper != null:
				return deeper
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("Pause"):
		return
	for sheet: Control in [_controls_sheet, _settings_sheet]:
		if sheet.visible:
			_show_sheet(sheet, false)
			get_viewport().set_input_as_handled()
			return


## Slides the menu off to the left, tilts the camera up off the car, then fades
## the picture and the music out together, then hands over to the level.
##
## The fade is DELAYED rather than run alongside the pan from the start. Begun
## together, the screen is half black before the camera has left the tail
## lights and the move is wasted; begun strictly after, there is a beat of
## nothing at the top of the tilt. It starts a little before the pan lands, so
## the last thing anyone sees is sky going dark.
##
## The wait at the end is not politeness. change_scene_to_file() takes effect
## at the end of the frame, so without it the track stops dead mid-bar at the
## same instant the road disappears, and the drive in opens on the tail of a
## chord that has been guillotined.
func _start_game() -> void:
	if _leaving:
		return
	_leaving = true
	for button in _buttons:
		button.disabled = true

	var hold := LEAVE_PAN - LEAVE_FADE * 0.6

	var out := create_tween()
	# EASE_IN, so the shot holds on the car and then accelerates away from it.
	# Eased both ends the move is already at speed almost immediately and the
	# subject is gone before anyone has registered that the camera is moving.
	out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(self, "_leave_pan", 1.0, LEAVE_PAN)
	# The panel leaves first and on its own faster curve, so the shot is clear
	# before the camera starts climbing.
	out.parallel().tween_property(_panel, "position:x", PANEL_OFF, PANEL_SLIDE) \
		.set_trans(Tween.TRANS_CUBIC)
	out.parallel().tween_property(_blackout, "color:a", 2.0, LEAVE_FADE) \
		.set_delay(hold).set_trans(Tween.TRANS_LINEAR)
	out.parallel().tween_property(_music, "volume_db", -60.0, LEAVE_FADE) \
		.set_delay(hold).set_trans(Tween.TRANS_LINEAR)
	await out.finished
	# The menu can be torn down while that await is pending -- the player hits
	# Alt-F4, or a test quits -- and resuming into change_scene_to_file on a
	# node that is no longer in the tree is an error nobody will read.
	if not is_inside_tree():
		return

	# A new game is a new character. Without this the second playthrough in a
	# session starts with the lens already in hand, and the whole first act of
	# the house -- finding it -- is silently skipped.
	Carry.reset()
	get_tree().change_scene_to_file(LEVEL)
