extends Control
## The rebinding table, as one reusable Control.
##
## It is shown in two places that look nothing alike -- ink on the journal's
## CONTROLS page, and pale text over the windscreen on the main menu -- so the
## colours and sizes are properties rather than constants, and the caller sets
## them before adding it to the tree.
##
## It draws itself from InputMap every time anything changes, rather than
## patching the rows it thinks moved. Fifteen rows is nothing to rebuild, and
## a table rebuilt from the map cannot disagree with the map.

## Emitted while a row is waiting for a press, so a host that has its own
## keyboard handling can stand down. The panel takes input in _input at a
## higher priority than anything in _unhandled_input regardless, but the
## journal reads Tab in _input too and both would fire.
signal listening_changed(listening: bool)

## The autoload's SCRIPT, for its two static helpers. It cannot be reached by
## class_name -- naming the class Controls would collide with the autoload
## singleton of the same name -- so the script is preloaded instead.
const CONTROLS := preload("res://Scripts/Controls.gd")

@export var ink := Color(0.16, 0.13, 0.10)
@export var ink_soft := Color(0.35, 0.30, 0.24)
@export var ink_accent := Color(0.55, 0.15, 0.10)

## Column geometry. The label column is wide because "Skip the cutscene" is
## the longest string in the table and wrapping one row would misalign the
## whole page.
@export var label_width := 374.0
@export var column_width := 224.0
@export var row_height := 27.0
@export var font_size := 16

## Whether to list the controls that CANNOT be moved -- the sticks, the mouse,
## the number row. The main menu shows them, because a page that lists only
## the rebindable half makes the pad look half-supported. The journal does not:
## the book page is 1180x820 and three more rows push the reset button off the
## paper, so it says the same thing in its footer instead.
@export var show_fixed := true

## Shown under the table. Kept as a property because the journal says "click
## a binding" and the menu, which can be driven entirely from a pad, does not
## want to say "click" at all.
@export var footer := "Click a binding, then press the key or button you want."

var _rows: VBoxContainer
var _listening_action := ""
var _listening_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	Controls.bindings_changed.connect(_rebuild)


func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(column)

	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", 0)
	heads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heads)
	_head(heads, "", label_width)
	_head(heads, "KEYBOARD", column_width)
	_head(heads, "CONTROLLER", column_width)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_rows)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	column.add_child(bottom)

	var reset := Button.new()
	reset.text = "  Put everything back  "
	reset.pressed.connect(func() -> void: Controls.reset_all())
	bottom.add_child(reset)

	var note := Label.new()
	note.text = footer
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", ink_soft)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(note)

	_rebuild()


func _head(parent: Control, text: String, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 18)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(ink_soft, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _rebuild() -> void:
	if _rows == null:
		return
	# remove_child before queue_free: queue_free is deferred, so freeing alone
	# leaves the old rows parented for the rest of the frame and the rebuilt
	# table draws on top of its own previous contents.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	for section in Controls.SECTIONS:
		_section(section)
		for row in Controls.BINDINGS:
			if row[2] == section:
				_binding_row(row[0], row[1])

	# Listed but not rebindable -- see the note on movement in Controls.gd.
	if show_fixed:
		_section("Always")
		_fixed_row("Look around", "Mouse", "Right stick")
		_fixed_row("Walk", "W A S D", "Left stick")
		_fixed_row("Choose a slot", "1 - 9", "D-pad, in the book")


func _section(text: String) -> void:
	var label := Label.new()
	label.text = text.to_upper()
	label.custom_minimum_size.y = row_height + 9
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", ink_accent)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(label)


func _binding_row(action: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_rows.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_width, row_height)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size + 1)
	label.add_theme_color_override("font_color", ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	row.add_child(_binding_button(action, false))
	row.add_child(_binding_button(action, true))

	# Only offered where it would do something. A row showing its defaults has
	# nothing to undo, and a column of greyed-out buttons is noise.
	if not Controls.is_default(action):
		var revert := Button.new()
		revert.text = "  undo  "
		revert.flat = true
		revert.add_theme_font_size_override("font_size", 13)
		revert.pressed.connect(func() -> void: Controls.reset_action(action))
		row.add_child(revert)


func _binding_button(action: String, pad: bool) -> Button:
	var button := Button.new()
	var bound := Controls.binding_name(action, pad)
	button.text = bound if not bound.is_empty() else "--"
	button.custom_minimum_size = Vector2(column_width, row_height)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(func() -> void: _start_listening(action, button))
	return button


func _fixed_row(label_text: String, key: String, pad: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(row)

	var widths := [label_width, column_width, column_width]
	var colours := [ink, ink_soft, ink_soft]
	var texts := [label_text, key, pad]
	for i in 3:
		var label := Label.new()
		label.text = texts[i]
		label.custom_minimum_size = Vector2(widths[i], row_height)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", colours[i])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)


# ----------------------------------------------------------------- capture

func is_listening() -> bool:
	return not _listening_action.is_empty()


func _start_listening(action: String, button: Button) -> void:
	_listening_action = action
	_listening_button = button
	button.text = "press it..."
	button.add_theme_color_override("font_color", ink_accent)
	listening_changed.emit(true)


func _stop_listening() -> void:
	if _listening_action.is_empty():
		return
	_listening_action = ""
	_listening_button = null
	listening_changed.emit(false)
	_rebuild()


## While a row is armed this eats EVERYTHING. Not "everything except the keys
## the menu uses" -- the keys the menu uses are exactly the keys people want
## to bind, and a capture that quietly refuses Tab is a capture that looks
## broken.
func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return
	get_viewport().set_input_as_handled()

	# Releases arrive here too, and the release of the very click that armed
	# the row would otherwise cancel it one frame later.
	var pressed := false
	if event is InputEventKey:
		var key := event as InputEventKey
		pressed = key.pressed and not key.echo
	elif event is InputEventJoypadButton:
		pressed = (event as InputEventJoypadButton).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if not pressed:
		return

	# Escape backs out. is_bindable() refuses it for the same reason: a player
	# who has bound Escape to crouch cannot leave this page.
	#
	# Called on CONTROLS, the script, rather than on `Controls`, the autoload.
	# Both work, but these two are static and a static belongs to the type --
	# reaching it through an instance is what STATIC_CALLED_ON_INSTANCE is
	# warning about. `rebind` below is an instance method and stays on the
	# singleton, because it writes to the singleton's state.
	if event is InputEventKey and CONTROLS.is_escape(event as InputEventKey):
		_stop_listening()
		return

	if not CONTROLS.is_bindable(event):
		return

	Controls.rebind(_listening_action, event)
	_stop_listening()
