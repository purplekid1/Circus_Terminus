class_name Journal
extends CanvasLayer

## The item pictures are shared with the HUD's "in hand" corner.
const ITEM_VIEW := preload("res://Scripts/ItemView.gd")
## The pause menu, drawn as the character's own notebook.
##
## Four tabs across the top -- NOTES, ITEMS, CONTROLS, SETTINGS -- on a leather board
## with two ruled pages and a ring binder down the middle. Opening it pauses
## the tree and frees the mouse; nothing else in the game runs while it is up.
##
## The items page is the inventory. Every filled cell renders the item's ACTUAL
## model in a little 3D viewport rather than showing an icon, which is why
## Scenes/items/ exists at all: one model does the pickup on the floor, the
## thing that spawns when you drop it, and the picture in the book. There is no
## icon atlas to keep in step with the models, and an item can never look like
## two different objects.
##
## Built in code, like InteractionHUD, because the whole thing is nine cells
## and a few labels generated from data -- a .tscn of it would be a hundred
## nodes nobody can diff.

const TAB_NOTES := 0
const TAB_ITEMS := 1
const TAB_CONTROLS := 2
const TAB_SETTINGS := 3
const TAB_NAMES := ["NOTES", "ITEMS", "CONTROLS", "SETTINGS"]

## Preloaded rather than referenced by class_name: the panel is shared with
## the main menu, and a preload cannot be broken by a stale class cache.
const KEYBINDS_PANEL := preload("res://Scripts/KeybindsPanel.gd")
## Likewise shared with the main menu, for the same reason: one page of
## settings, shown in two places.
const SETTINGS_PANEL := preload("res://Scripts/SettingsPanel.gd")

const BOOK_SIZE := Vector2(1180, 820)
const CELL := 116
const CELL_GAP := 10

# Paper, ink and leather. Warm and low-contrast: the book is lit by the same
# dying torch as everything else, and a bright white page would read as a
# browser window pasted over the game.
const INK := Color(0.16, 0.13, 0.10)
const INK_SOFT := Color(0.35, 0.30, 0.24)
const INK_RED := Color(0.55, 0.15, 0.10)
const PAPER := Color(0.867, 0.835, 0.745)
const PAPER_EDGE := Color(0.76, 0.72, 0.62)
const RULE := Color(0.62, 0.60, 0.55, 0.55)
const LEATHER := Color(0.13, 0.095, 0.072)

@onready var player: CharacterBody3D = get_parent()
@onready var inventory: Inventory = player.get_node("Inventory")

var open := false
var tab := TAB_ITEMS

var _root: Control
var _book: Control
var _tab_labels: Array[Label] = []
var _pages: Array[Control] = []

var _cells: Array[Panel] = []
var _cell_counts: Array[Label] = []
var _cell_views: Array[SubViewportContainer] = []
var _cell_items: Array[ItemData] = []
var _cell_crosses: Array[Label] = []

var _hero_view: SubViewport
var _hero_holder: Node3D
var _hero_name: Label
var _hero_body: Label
var _hero_spin := 0.0
var _hero_drag := false

var _notes_box: VBoxContainer
var _equip_line: Label
var _notes: Array[Dictionary] = []

var _settings_page: Control
var _settings_built := false

var _controls_page: Control
var _controls_built := false
var _hint: Label

## Set while the keybinds panel is armed and waiting for a press. The panel
## takes the whole keyboard while that is true, this book included.
var _binding_capture := false


func _ready() -> void:
	# The whole point of a pause menu is that it runs while the tree does not.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build()
	_root.visible = false
	inventory.changed.connect(_refresh)
	inventory.selection_changed.connect(func(_i: int) -> void: _refresh())


# ------------------------------------------------------------------ opening

func toggle() -> void:
	set_open(not open)


func set_open(value: bool) -> void:
	if value == open:
		return
	open = value
	_root.visible = open
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

	# The crosshair HUD is not part of the book and reads as a bug behind it:
	# an "in hand" chip in the corner saying the same thing the open page says,
	# over the top of a menu that has paused the game.
	var hud := player.get_node_or_null("CanvasLayer") as CanvasLayer
	if hud != null:
		hud.visible = not open

	if open:
		_refresh()


## Adds an entry to the notes page. Called by the player, which readables and
## clues route through, so anything the character learns is written down once
## and the same text is there an hour later when they have forgotten it.
func add_note(title: String, body: String) -> void:
	for note in _notes:
		if note["title"] == title:
			return
	_notes.append({"title": title, "body": body})
	_rebuild_notes()


func _input(event: InputEvent) -> void:
	if not open:
		return

	# The keybinds panel is waiting for a press. It wants Tab and Q as much as
	# this book does -- they are exactly the keys people rebind -- so stand
	# down entirely until it is finished.
	if _binding_capture:
		return

	if event.is_action_pressed("Pause") or event.is_action_pressed("Journal"):
		set_open(false)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("Journal_Next"):
		_select_tab(wrapi(tab + 1, 0, TAB_NAMES.size()))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("Journal_Prev"):
		_select_tab(wrapi(tab - 1, 0, TAB_NAMES.size()))
		get_viewport().set_input_as_handled()
		return

	if tab != TAB_ITEMS:
		return

	var moved := true
	if event.is_action_pressed("Move_Left") or event.is_action_pressed("ui_left"):
		inventory.step(-1, 0)
	elif event.is_action_pressed("Move_Right") or event.is_action_pressed("ui_right"):
		inventory.step(1, 0)
	elif event.is_action_pressed("Move_Forward") or event.is_action_pressed("ui_up"):
		inventory.step(0, -1)
	elif event.is_action_pressed("Move_Backward") or event.is_action_pressed("ui_down"):
		inventory.step(0, 1)
	elif event.is_action_pressed("Drop"):
		player.drop_held()
	else:
		moved = false
	if moved:
		get_viewport().set_input_as_handled()

	# Drag the hero render to turn the item over. Reaching for the mouse is
	# the natural move once the cursor is already free, and it is the cheapest
	# way to let someone read the label on the far side of a fuse.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_hero_drag = event.pressed
	elif event is InputEventMouseMotion and _hero_drag:
		_hero_spin -= event.relative.x * 0.01


func _process(delta: float) -> void:
	if not open:
		return
	if not _hero_drag:
		_hero_spin += delta * 0.5
	if _hero_holder != null:
		_hero_holder.rotation.y = _hero_spin


# ------------------------------------------------------------------ chrome

## The book itself: board, two pages, gutter shadow and rings. One _draw pass
## rather than a pile of nested ColorRects, because the shadow either side of
## the gutter is a gradient and the ruled lines are forty hairlines -- both are
## a single call here and a node each otherwise.
class Paper extends Control:
	var ink_rule: Color
	var paper: Color
	var paper_edge: Color
	var leather: Color

	## Height of the leather strip along the top. The tabs sit in it, clear of
	## the paper and clear of the ring binder -- centred over the pages they
	## landed on top of the middle ring, which looked like a printing error.
	const HEADER := 58.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var margin := 26.0

		# board
		draw_rect(Rect2(Vector2.ZERO, size), leather)
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), leather.lightened(0.12), false, 2.0)

		var page := Rect2(margin, margin + HEADER, w - margin * 2.0, h - margin * 2.0 - HEADER)

		# the block of pages under the top one, as three offset slivers
		for i in 3:
			var off := float(3 - i) * 2.5
			draw_rect(Rect2(page.position + Vector2(off, off), page.size), paper_edge)
		draw_rect(page, paper)

		# ruled lines, skipping the gutter
		var gutter := w * 0.5
		var line_y := page.position.y + 54.0
		while line_y < page.end.y - 22.0:
			draw_line(Vector2(page.position.x + 30.0, line_y),
					  Vector2(gutter - 46.0, line_y), ink_rule, 1.0)
			draw_line(Vector2(gutter + 46.0, line_y),
					  Vector2(page.end.x - 30.0, line_y), ink_rule, 1.0)
			line_y += 30.0

		# Gutter: the paper curving down into the spine. Darkest AT the spine
		# and fading out over 46px either side -- the first version peaked in
		# the middle of the falloff and read as a pale stripe, which is the
		# opposite of a fold.
		for i in 46:
			var t := float(i) / 46.0
			var a := (1.0 - t) * (1.0 - t) * 0.42
			draw_line(Vector2(gutter - i, page.position.y),
					  Vector2(gutter - i, page.end.y), Color(0, 0, 0, a), 1.0)
			draw_line(Vector2(gutter + i, page.position.y),
					  Vector2(gutter + i, page.end.y), Color(0, 0, 0, a), 1.0)

		# ring binder
		var rings := 4
		for i in rings:
			var cy := page.position.y + page.size.y * (i + 0.5) / rings
			draw_arc(Vector2(gutter, cy), 17.0, 0.0, TAU, 20, Color(0.55, 0.53, 0.50), 4.0)
			draw_arc(Vector2(gutter, cy), 17.0, 0.0, TAU, 20, Color(0.25, 0.24, 0.23), 1.5)

		# a stain in one corner, so the page is not a clean rectangle
		draw_circle(Vector2(page.end.x - 90.0, page.end.y - 60.0), 34.0, Color(0.55, 0.44, 0.28, 0.10))
		draw_circle(Vector2(page.end.x - 78.0, page.end.y - 72.0), 20.0, Color(0.55, 0.44, 0.28, 0.10))


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var paper := Paper.new()
	paper.ink_rule = RULE
	paper.paper = PAPER
	paper.paper_edge = PAPER_EDGE
	paper.leather = LEATHER
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.custom_minimum_size = BOOK_SIZE
	paper.size = BOOK_SIZE
	paper.position = -BOOK_SIZE * 0.5
	paper.pivot_offset = BOOK_SIZE * 0.5
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(paper)
	_book = paper

	# The page is laid out at a fixed 1180x820 and then scaled to fit, rather
	# than anchored and stretched. Anchoring would let the ruled lines, the
	# ring spacing and the grid drift apart from each other at different
	# aspect ratios; scaling keeps the book one object that happens to be
	# bigger on a bigger screen, which is what a book does.
	_fit_book()
	get_viewport().size_changed.connect(_fit_book)

	_build_tabs()
	_pages.append(_build_notes_page())
	_pages.append(_build_items_page())
	_pages.append(_build_controls_page())
	_pages.append(_build_settings_page())
	_select_tab(TAB_ITEMS)

	# The footer names two controls by their bindings, so it has to be redrawn
	# when either of them moves -- and when the player picks up a pad, because
	# glyph() answers for whichever device they are holding.
	Controls.bindings_changed.connect(_refresh_hint)
	Controls.device_changed.connect(func(_pad: bool) -> void: _refresh_hint())


func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 54)
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.offset_left = -340
	row.offset_right = 340
	row.offset_top = 14
	row.offset_bottom = 50
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_book.add_child(row)

	for index in TAB_NAMES.size():
		var label := Label.new()
		label.text = TAB_NAMES[index]
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				_select_tab(index))
		row.add_child(label)
		_tab_labels.append(label)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_left = -440
	_hint.offset_right = 440
	_hint.offset_top = -46
	_hint.offset_bottom = -20
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", INK_SOFT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_hint)
	_refresh_hint()


## The footer used to have "[Q] / [E]" typed into it, which stopped being true
## the moment either was rebound. It asks Controls now, like everything else
## that prints a control.
func _refresh_hint() -> void:
	if _hint == null:
		return
	_hint.text = "%s / %s  turn to another section        %s  close" % [
		Controls.glyph("Journal_Prev"),
		Controls.glyph("Journal_Next"),
		Controls.glyph("Pause"),
	]


func _fit_book() -> void:
	if _book == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var factor := minf(vp.y * 0.94 / BOOK_SIZE.y, vp.x * 0.88 / BOOK_SIZE.x)
	_book.scale = Vector2.ONE * factor


func _select_tab(index: int) -> void:
	tab = index
	for i in _tab_labels.size():
		var on := i == index
		# Gilt on leather, not ink on paper: the tabs live on the board above
		# the pages now, so they need to read against a dark background.
		_tab_labels[i].add_theme_color_override(
			"font_color", Color(0.88, 0.80, 0.58) if on else Color(0.55, 0.50, 0.42)
		)
		_tab_labels[i].add_theme_font_size_override("font_size", 24 if on else 20)
	for i in _pages.size():
		_pages[i].visible = i == index
	if index == TAB_ITEMS:
		_refresh()
	elif index == TAB_CONTROLS:
		_fill_controls()
	elif index == TAB_SETTINGS:
		_fill_settings()

	# Hand the keyboard focus to the first thing on the page. Without it the
	# settings sliders and the keybind rows are mouse-only -- a pad can turn
	# to the page and then do nothing on it, which is worse than not having
	# the page. Deferred because the page it lands on may have been built by
	# the two calls above, one frame ago.
	if index == TAB_ITEMS:
		# The items grid is driven by the movement keys, not by focus, and a
		# focused button left over from the settings page would eat them.
		var held := get_viewport().gui_get_focus_owner()
		if held != null:
			held.release_focus()
	else:
		_focus_first.call_deferred(_pages[index])


## Depth-first for the first control that will take focus. The pages are built
## out of nested containers, so "the first child" is a VBox nine times out of
## ten.
func _focus_first(page: Control) -> void:
	if page == null or not page.visible:
		return
	var found := _find_focusable(page)
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


## A page-sized transparent Control the tabs switch between.
func _new_page() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	_book.add_child(page)
	return page


func _heading(parent: Control, text: String, x: float, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# ------------------------------------------------------------------- items

func _build_items_page() -> Control:
	var page := _new_page()
	_heading(page, "ITEMS", 96, 150)

	var grid := GridContainer.new()
	grid.columns = Inventory.COLS
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	grid.position = Vector2(96, 198)
	page.add_child(grid)

	for index in Inventory.SLOT_COUNT:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(CELL, CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				inventory.select(index))
		grid.add_child(cell)
		_cells.append(cell)

		var view := _make_item_view(Vector2(CELL - 12, CELL - 12))
		view.position = Vector2(6, 6)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(view)
		_cell_views.append(view)
		_cell_items.append(null)

		# The pencil cross that means "nothing here", hidden as soon as the
		# cell has something in it.
		var cross := Label.new()
		cross.set_anchors_preset(Control.PRESET_FULL_RECT)
		cross.text = "✕"
		cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cross.add_theme_font_size_override("font_size", 40)
		cross.add_theme_color_override("font_color", Color(INK_SOFT, 0.28))
		cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cross)
		_cell_crosses.append(cross)

		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -38
		count.offset_top = -30
		count.offset_right = -8
		count.offset_bottom = -4
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 17)
		count.add_theme_color_override("font_color", INK_RED)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(count)
		_cell_counts.append(count)

	_equip_line = Label.new()
	_equip_line.position = Vector2(96, 208 + (CELL + CELL_GAP) * Inventory.ROWS + 14)
	_equip_line.size = Vector2(420, 60)
	_equip_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equip_line.add_theme_font_size_override("font_size", 16)
	_equip_line.add_theme_color_override("font_color", INK_SOFT)
	_equip_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_equip_line)

	# ---- right page: the selected item, big ----
	_heading(page, "IN HAND", BOOK_SIZE.x * 0.5 + 96, 150)

	var hero := _make_item_view(Vector2(440, 320))
	hero.position = Vector2(BOOK_SIZE.x * 0.5 + 70, 190)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(hero)
	_hero_view = hero.get_child(0) as SubViewport

	_hero_name = Label.new()
	_hero_name.position = Vector2(BOOK_SIZE.x * 0.5 + 70, 524)
	_hero_name.size = Vector2(440, 40)
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name.add_theme_font_size_override("font_size", 30)
	_hero_name.add_theme_color_override("font_color", INK)
	_hero_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_hero_name)

	_hero_body = Label.new()
	_hero_body.position = Vector2(BOOK_SIZE.x * 0.5 + 70, 576)
	_hero_body.size = Vector2(440, 170)
	_hero_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_body.add_theme_font_size_override("font_size", 18)
	_hero_body.add_theme_color_override("font_color", INK_SOFT)
	_hero_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_hero_body)

	return page


## A transparent 3D viewport with its own little studio in it: two lights and
## a camera, no environment. own_world_3d matters -- without it the viewport
## renders the mansion, and a key in the journal is lit by whatever room the
## player happened to pause in.
func _make_item_view(view_size: Vector2) -> SubViewportContainer:
	return ITEM_VIEW.make(view_size)


## Points a view's camera at an item and puts its model under the turntable.
## Returns the holder so the caller can keep spinning it.
func _show_in_view(container: SubViewportContainer, item: ItemData, spin: bool) -> Node3D:
	return ITEM_VIEW.show_item(container, item, spin)


func _refresh() -> void:
	if _cells.is_empty():
		return

	for index in Inventory.SLOT_COUNT:
		var item: ItemData = inventory.slots[index]
		var is_selected := index == inventory.selected

		_cells[index].add_theme_stylebox_override("panel", _cell_box(is_selected, item != null))

		var count := inventory.count_at(index)
		_cell_counts[index].text = str(count) if count > 1 else ""
		_cell_crosses[index].visible = item == null

		if item != _cell_items[index]:
			_show_in_view(_cell_views[index], item, false)
			_cell_items[index] = item

	var held: ItemData = inventory.get_selected()
	_hero_holder = _show_in_view(_hero_view.get_parent() as SubViewportContainer, held, true)
	_hero_name.text = held.display_name if held != null else ""
	_hero_body.text = held.description if held != null else "Nothing in that pocket."

	if inventory.equipment.is_empty():
		_equip_line.text = ""
	else:
		var names := PackedStringArray()
		for gear in inventory.equipment:
			names.append(gear.display_name)
		_equip_line.text = "Carried loose:  %s" % ", ".join(names)


## Cells are drawn as pencil boxes on the page, not as UI panels: a filled one
## gets a stronger line, the selected one gets a double line, and an empty one
## gets the faint cross the player already knows means "nothing here".
func _cell_box(is_selected: bool, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.80, 0.77, 0.68, 0.55 if filled else 0.25)
	style.border_color = INK if is_selected else INK_SOFT
	style.set_border_width_all(3 if is_selected else 1)
	style.set_corner_radius_all(2)
	return style


# ------------------------------------------------------------------- notes

func _build_notes_page() -> Control:
	var page := _new_page()
	_heading(page, "NOTES", 96, 150)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(96, 200)
	scroll.size = Vector2(BOOK_SIZE.x - 250, BOOK_SIZE.y - 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_notes_box = VBoxContainer.new()
	_notes_box.add_theme_constant_override("separation", 18)
	_notes_box.custom_minimum_size.x = BOOK_SIZE.x - 270
	scroll.add_child(_notes_box)

	_rebuild_notes()
	return page


func _rebuild_notes() -> void:
	if _notes_box == null:
		return
	for child in _notes_box.get_children():
		child.queue_free()

	if _notes.is_empty():
		var empty := Label.new()
		empty.text = "Nothing written down yet."
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", INK_SOFT)
		_notes_box.add_child(empty)
		return

	for note in _notes:
		var title := Label.new()
		title.text = "-  %s" % note["title"]
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", INK)
		_notes_box.add_child(title)

		var body := Label.new()
		body.text = "    %s" % note["body"]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = BOOK_SIZE.x - 300
		body.add_theme_font_size_override("font_size", 17)
		body.add_theme_color_override("font_color", INK_SOFT)
		_notes_box.add_child(body)


# ---------------------------------------------------------------- controls

## The keybinds page. The table itself is KeybindsPanel, shared with the main
## menu -- the book and the menu are the same list of controls and keeping two
## copies of it meant rebinding Interact in one place and not the other.
##
## Built lazily like the settings page, because the panel reads the Input Map
## on construction and the Input Map is written by an autoload.
func _build_controls_page() -> Control:
	var page := _new_page()
	_heading(page, "CONTROLS", 96, 150)
	_controls_page = page
	return page


func _fill_controls() -> void:
	if _controls_built:
		return
	_controls_built = true

	var panel := KEYBINDS_PANEL.new()
	panel.ink = INK
	panel.ink_soft = INK_SOFT
	panel.ink_accent = INK_RED
	# Tighter than the main menu's copy of the same table. The book page is
	# 1180x820 and the menu is a whole screen, so the rows have to be shorter
	# and the columns narrower or the last section runs off the paper.
	# Laid out ACROSS THE SPREAD: the names of the controls on the left page,
	# the two binding columns on the right. A 300 px label column put both
	# columns straight over the ring binder, where the rings draw on top of
	# them. 520 pushes the first column clear of the gutter at 590.
	panel.label_width = 520.0
	panel.column_width = 190.0
	panel.row_height = 18.0
	panel.font_size = 14
	panel.show_fixed = false
	panel.footer = "Look with the mouse or the right stick.  Walk with WASD or the left stick.  1-9 picks a slot."
	panel.position = Vector2(92, 178)
	panel.size = Vector2(BOOK_SIZE.x - 190, BOOK_SIZE.y - 250)
	# While the panel is armed it swallows every key, this book's own Tab and
	# Escape included. _input here bails out rather than racing it.
	panel.listening_changed.connect(func(on: bool) -> void: _binding_capture = on)
	_controls_page.add_child(panel)


# ---------------------------------------------------------------- settings

## The page frame only. Its contents are filled the first time the tab is
## turned to, because every control on it is seeded from a value that lives on
## the player -- and the player's own @onready references do not exist yet
## while its children, this journal among them, are still readying.
func _build_settings_page() -> Control:
	var page := _new_page()
	_heading(page, "SETTINGS", 96, 150)
	_settings_page = page
	return page


func _fill_settings() -> void:
	if _settings_built:
		return
	_settings_built = true
	var page := _settings_page

	# The rows themselves are SettingsPanel, shared with the main menu -- the
	# book and the menu are the same list of settings, and keeping two copies
	# of it meant a slider existing in one and not the other. Only the ink
	# changes between them.
	var panel: Control = SETTINGS_PANEL.new()
	panel.ink = INK
	panel.ink_soft = INK_SOFT
	panel.position = Vector2(96, 210)
	panel.size = Vector2(BOOK_SIZE.x - 250, 460)
	page.add_child(panel)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	buttons.position = Vector2(96, BOOK_SIZE.y - 150)
	page.add_child(buttons)

	var resume := Button.new()
	resume.text = "  Close the book  "
	resume.pressed.connect(func() -> void: set_open(false))
	buttons.add_child(resume)

	var quit := Button.new()
	quit.text = "  Leave the house  "
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)


