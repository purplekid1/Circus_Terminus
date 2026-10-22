extends Control
## The settings rows, as one reusable Control.
##
## Shown in two places that look nothing alike -- ink on the journal's SETTINGS
## page, and pale text over the windscreen on the main menu -- so the colours
## and sizes are properties rather than constants, exactly as KeybindsPanel
## does it. Keeping two copies of this list meant a slider existing in the book
## and not on the menu, which is the state it was in.
##
## IT WRITES TO Settings, NOT TO THE PLAYER. The menu has no player, and a
## panel that needed one could not be shown there at all. The player watches
## those values and applies the two that have to reach a node -- field of view
## and torch brightness -- see PlayerController._sync_settings.

const SETTINGS := preload("res://Scripts/Settings.gd")

@export var ink := Color(0.16, 0.13, 0.10)
@export var ink_soft := Color(0.35, 0.30, 0.24)

@export var font_size := 19
@export var readout_size := 17
## The label column. Wide enough for "Hold to run (off: press once to keep
## running)" not to wrap, because one wrapped row misaligns the column.
@export var label_width := 260.0
@export var control_width := 320.0
@export var row_separation := 22


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", row_separation)
	add_child(box)

	_slider(box, "Look sensitivity", 0.2, 3.0, SETTINGS.look_sensitivity,
		func(v: float) -> void: SETTINGS.look_sensitivity = v)
	_slider(box, "Field of view", 60.0, 105.0, SETTINGS.fov,
		func(v: float) -> void: SETTINGS.fov = v)
	_slider(box, "Torch brightness", 0.5, 8.0, SETTINGS.torch_energy,
		func(v: float) -> void: SETTINGS.torch_energy = v)
	# Medium is the size subtitles have always been, so anyone who never opens
	# this sees no change at all.
	_option(box, "Subtitle size", PackedStringArray(["Small", "Medium", "Large"]),
		SETTINGS.subtitle_size,
		func(i: int) -> void: SETTINGS.subtitle_size = i)
	_checkbox(box, "Invert look", SETTINGS.invert_look,
		func(v: bool) -> void: SETTINGS.invert_look = v)
	_checkbox(box, "Head bob", SETTINGS.head_bob,
		func(v: bool) -> void: SETTINGS.head_bob = v)
	# Chiefly for pad users: holding L3 down for the length of the drive is
	# unpleasant in a way holding Shift is not.
	_checkbox(box, "Hold to run  (off: press once to keep running)",
		not SETTINGS.sprint_toggle,
		func(v: bool) -> void: SETTINGS.sprint_toggle = not v)


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = label_width
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	row.add_child(label)
	return row


func _slider(parent: Control, label_text: String, lo: float, hi: float,
		value: float, on_change: Callable) -> void:
	var row := _row(parent, label_text)

	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = (hi - lo) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(control_width, 24)
	row.add_child(slider)

	var readout := Label.new()
	readout.text = "%.2f" % value
	readout.custom_minimum_size.x = 80
	readout.add_theme_font_size_override("font_size", readout_size)
	readout.add_theme_color_override("font_color", ink_soft)
	row.add_child(readout)

	slider.value_changed.connect(func(v: float) -> void:
		readout.text = "%.2f" % v
		on_change.call(v))


## A labelled dropdown, on the same gutter as _slider so the page stays one
## column of labels and one of controls.
func _option(parent: Control, label_text: String, choices: PackedStringArray,
		selected: int, on_change: Callable) -> void:
	var row := _row(parent, label_text)

	var picker := OptionButton.new()
	for choice: String in choices:
		picker.add_item(choice)
	picker.selected = selected
	picker.custom_minimum_size = Vector2(control_width, 30)
	picker.add_theme_font_size_override("font_size", font_size - 1)
	picker.item_selected.connect(func(i: int) -> void: on_change.call(i))
	row.add_child(picker)


func _checkbox(parent: Control, label_text: String, value: bool,
		on_change: Callable) -> void:
	var box := CheckBox.new()
	box.text = label_text
	box.button_pressed = value
	box.add_theme_font_size_override("font_size", font_size)
	box.add_theme_color_override("font_color", ink)
	box.toggled.connect(func(v: bool) -> void: on_change.call(v))
	parent.add_child(box)
