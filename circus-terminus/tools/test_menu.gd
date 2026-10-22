extends SceneTree
## Boots the title screen, walks the keybinds sheet, and then presses "Drive
## on", so the whole departure cannot quietly stop working.
##
## The departure is checked BY THE CLOCK, not by counting frames. Headless runs
## uncapped, so a frame is worth an unpredictable slice of a second while the
## tweens run on real time; a test that waits "thirty frames" is waiting for an
## unknown interval and reports whatever it happens to catch.

var _menu: Node = null
var _stage := 0
var _wait := 8
var _elapsed := 0.0

## The camera's forward vector before "Drive on" is pressed, so the departure
## tilt can be shown to have actually moved it.
var _forward := Vector3.ZERO


func _ok(label: String, cond: bool) -> void:
	print("MENU %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	var ps: PackedScene = load("res://Scenes/menu.tscn")
	_menu = ps.instantiate()
	root.add_child(_menu)


func _process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	if _stage == 0:
		_ok("the drive is built", _menu._movers.size() > 100)
		_ok("the road moves", _menu._travelled > 0.0)
		_ok("the car is in the shot", _menu._car != null)
		_ok("its lamps are lit", _menu._car.get_node("HeadBeamL").visible)
		# CarArrival collects wheels from Body's children, and Body used to be
		# EMPTY -- every brush was written to the scene root -- so nothing ever
		# turned, in the intro either. Body is the hand-modelled car now and its
		# four wheels are ONE mesh, so there is no child named "Wheel" to
		# collect, and nothing to gain by splitting one out: they are smooth
		# 32-segment revolves with no spokes, no tread and no lug nuts, so a
		# turning wheel is pixel-identical to a still one. What still has to
		# hold is that the model arrived under Body at all -- an empty Body is
		# the bug this has always been here to catch.
		_ok("the car model is under Body", _menu._car.get_node("Body").get_child_count() >= 4)
		_ok("four entries", _menu._buttons.size() == 4)
		_ok("and Settings is one of them",
			_menu.get_node_or_null("UI/Panel/Menu/Settings") != null)
		_ok("the settings sheet starts hidden", not _menu._settings_sheet.visible)
		# The rows are SettingsPanel, the same Control the journal's page uses.
		_ok("with the shared panel on it",
			_menu.get_node_or_null("UI/SettingsSheet/Rows") != null)
		_ok("the keybinds sheet starts hidden", not _menu._controls_sheet.visible)
		_ok("the music is playing", _menu._music.playing)
		_ok("and it loops", (_menu._music.stream as AudioStream).loop)
		_ok("and starts quiet, then comes up", _menu._music.volume_db < _menu.MUSIC_DB)
		_ok("the menu panel is on screen", _menu._panel.position.x == 0.0)
		_menu._show_controls(true)
		_ok("the keybinds sheet opens", _menu._controls_sheet.visible)

		# THE POINT OF THE WHOLE EXERCISE: a settings page on the title screen,
		# where there is no player to hang a field of view on. The rows write to
		# Scripts/Settings.gd, which survives the change of scene into the level.
		var store := preload("res://Scripts/Settings.gd")
		var before: float = store.look_sensitivity
		_menu._show_sheet(_menu._settings_sheet, true)
		_ok("the settings sheet opens", _menu._settings_sheet.visible)
		var rows: Control = _menu.get_node("UI/SettingsSheet/Rows")
		var slider := _first_slider(rows)
		_ok("it built its rows", slider != null)
		if slider != null:
			# Three quarters along its own range, whatever that range is --
			# the first row is Look sensitivity and it clamps at 3.0, so a
			# round number picked here just gets swallowed.
			var want: float = slider.min_value + (slider.max_value - slider.min_value) * 0.75
			slider.value = want
			_ok("and a row writes straight to the shared store",
				absf(store.look_sensitivity - want) < 0.001)
		_menu._show_sheet(_menu._settings_sheet, false)
		_ok("and it closes again", not _menu._settings_sheet.visible)
		_ok("with focus back on the entry that opened it",
			_menu.get_node("UI/Panel/Menu/Settings").has_focus())
		store.look_sensitivity = before
		_stage = 1
		_wait = 4
		return false

	if _stage == 1:
		# The title screen stands the car still and scrolls the road past it, so
		# what has to be true is that the car has been TOLD it is rolling. That
		# is what used to spin the wheels and what still drives the engine note.
		_ok("the car is being driven", _menu._car._driving and _menu._car._rolled > 0.0)
		_ok("something on the sheet has focus",
			_menu._find_focusable(_menu._controls_sheet) != null)
		_menu._show_controls(false)
		_ok("and it closes again", not _menu._controls_sheet.visible)

		_ok("the level exists", ResourceLoader.exists(_menu.LEVEL))
		var level := (load(_menu.LEVEL) as PackedScene).instantiate()
		_ok("and instantiates", level != null)
		level.free()

		_forward = -(_menu._camera.global_transform.basis.z as Vector3)
		_menu._start_game()
		_ok("pressing play starts the departure", _menu._leaving)
		_ok("and greys the entries out", _menu._buttons[0].disabled)
		_menu._start_game()
		_ok("a second press is ignored", _menu._leaving)
		_stage = 2
		return false

	_elapsed += delta

	# Partway through the tilt, and before the fade is due to start.
	if _stage == 2 and _elapsed > 0.6:
		_ok("the camera is panning", _menu._leave_pan > 0.0)
		_ok("and the panel has slid off to the left", _menu._panel.position.x < -200.0)
		var now: Vector3 = -_menu._camera.global_transform.basis.z
		_ok("and is looking further up than it was", now.y > _forward.y + 0.05)
		# The point of the whole exercise: the pan happens BEFORE the fade, not
		# underneath it. If this starts failing, the two have been collapsed
		# back on top of each other and the move is being thrown away.
		_ok("and the screen has not begun to fade", _menu._blackout.color.a == 0.0)
		_stage = 3
		return false

	# After the tilt has landed.
	if _stage == 3 and _elapsed > _menu.LEAVE_PAN + 0.15:
		_ok("the pan finishes", _menu._leave_pan > 0.99)
		_ok("and then the screen fades", _menu._blackout.color.a > 0.0)
		_ok("and the music goes with it", _menu._music.volume_db < _menu.MUSIC_DB)
		return true

	return false


## The first HSlider anywhere under `from`. The settings rows are built by
## SettingsPanel at _ready, so the test cannot know their node names -- only
## that there had better be some.
func _first_slider(from: Node) -> HSlider:
	for child in from.get_children():
		if child is HSlider:
			return child as HSlider
		var deeper := _first_slider(child)
		if deeper != null:
			return deeper
	return null
