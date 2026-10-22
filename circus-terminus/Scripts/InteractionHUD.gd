extends CanvasLayer

## Shared with the journal's inventory grid -- see Scripts/ItemView.gd.
const ITEM_VIEW := preload("res://Scripts/ItemView.gd")


## The chip in the corner is 250x66, and the held-item frame 84 square --
## but those numbers live in Scenes/ui/hud.tscn now, on the nodes themselves.
## Only the size the turntable renders AT is still needed here, because it
## is passed to ItemView.make.
## The side of the held-item picture.
const HELD_VIEW := 84.0
## How fast it turns, in degrees a second. Slow: it is a held object catching
## the light, not a shop display.
const HELD_SPIN := 26.0
## How far back the corner view sits compared with the journal's framing. The
## icon_* settings on each item are tuned against the book's cells, which are
## bigger than this; at 1.0 a crowbar runs out of both sides.
const HELD_ZOOM := 1.55

@onready var player: CharacterBody3D = get_parent()
@onready var inventory: Inventory = player.get_node("Inventory")

# ---------------------------------------------------------------- the nodes
#
# Every one of these is AUTHORED IN Scenes/ui/hud.tscn. This script used to
# build all of it -- nineteen Controls, their anchors, their offsets, their
# fonts and their styleboxes -- in ten _build_* functions, which meant opening
# the HUD in the editor showed one CanvasLayer and nothing else: nothing to
# select, nothing to nudge, no way to see what the screen looked like without
# running the game. Exactly what gen_menu.sh already fixed for the title
# screen.
#
# What is left here is behaviour: what the labels SAY, when they appear, and
# the three things that genuinely cannot be authored -- the held item's 3D
# turntable, which is a shared factory (ItemView.make, used by the journal
# too), the tunnel shader's parameters, and the stamina fill's width.
@onready var _prompt: Label = $Prompt
@onready var _hidden_label: Label = $HiddenLabel
@onready var _held_name: Label = $HeldPanel/HeldName
@onready var _held_caption: Label = $HeldPanel/HeldCaption
@onready var _gear_label: Label = $GearLabel
@onready var _held_frame: Panel = $HeldFrame
@onready var _message: Label = $Message
@onready var _hint: Label = $Hint
@onready var _dialogue: Label = $Dialogue
@onready var _stamina_box: Control = $StaminaBox
@onready var _stamina_fill: Panel = $StaminaBox/Fill
@onready var _fade: ColorRect = $FadeLayer/Fade
@onready var _closing: Label = $FadeLayer/Closing
@onready var _tunnel: ColorRect = $Overlays/Tunnel
@onready var _flash: ColorRect = $Overlays/Flash

## The turntable inside the held-item frame. Built rather than authored: it is
## ItemView.make, the same factory the journal's inventory grid uses, and a
## second authored copy of a SubViewport and its lights is how the two views
## drift apart.
var _held_view: SubViewportContainer
var _held_spin: Node3D

## The tunnel's ShaderMaterial, taken off the authored ColorRect so its
## parameters can be driven.
var _tunnel_mat: ShaderMaterial

var _message_timer := 0.0

## The stamina bar: what it is fading towards and where it is now. It is hidden
## at a full tank -- a permanent bar in the corner is HUD furniture, and this
## game spends most of its time with nothing to report.
var _stamina_alpha := 0.0
var _stamina_target := 0.0
var _stamina_winded := false

## One writer for the black overlay. fade_out and fade_in both drive the same
## property, and a respawn runs them back to back -- without this the dying
## fade keeps darkening while the waking fade tries to lift it.
var _fade_tween: Tween

var _dialogue_queue: Array[String] = []
var _dialogue_timer := 0.0


func _ready() -> void:
	_build_held_view()
	_tunnel_mat = _tunnel.material as ShaderMaterial
	set_subtitle_size(player.subtitle_pixels())

	player.interactable_changed.connect(_on_interactable_changed)
	player.concealment_changed.connect(_on_concealment_changed)
	player.message_requested.connect(show_message)
	player.hint_changed.connect(show_hint)
	player.stamina_changed.connect(_on_stamina_changed)
	player.fade_requested.connect(fade_out)
	player.unfade_requested.connect(fade_in)
	player.flash_requested.connect(flash)
	player.tunnel_requested.connect(set_tunnel)
	player.line_spoken.connect(say)
	player.subtitle_size_changed.connect(set_subtitle_size)
	inventory.changed.connect(_refresh_held)
	inventory.selection_changed.connect(func(_i: int) -> void: _refresh_held())
	inventory.rejected.connect(_on_rejected)
	# The held-item caption names the book key, so it has to be redrawn when the
	# player picks up a pad and that key becomes a button.
	Controls.device_changed.connect(func(_pad: bool) -> void: _refresh_held())
	Controls.bindings_changed.connect(_refresh_held)

	_refresh_held()


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""

	_tick_dialogue(delta)
	_tick_stamina(delta)
	if _held_spin != null and is_instance_valid(_held_spin):
		_held_spin.rotate_y(deg_to_rad(HELD_SPIN) * delta)

	if not is_instance_valid(player.current_interactable):
		_prompt.text = ""
		return

	var target: Interactable = player.current_interactable

	var usable: bool = target.can_interact(player)
	_prompt.text = ("%s  %s" % [Controls.glyph("Interact"), target.get_prompt(player)]) if usable else target.get_prompt(player)
	_prompt.modulate = Color(1, 1, 1) if usable else Color(1, 0.55, 0.5)


## The held item's turntable, dropped into the frame the scene authored.
##
## NOT AUTHORED, on purpose. It is ItemView.make -- the same factory the
## journal's inventory grid uses -- so that the item in your hand and the item
## in the book are lit and framed identically. A second authored copy of a
## SubViewport, its camera and its two lights is exactly how those two views
## drift apart.
func _build_held_view() -> void:
	_held_view = ITEM_VIEW.make(Vector2(HELD_VIEW, HELD_VIEW))
	_held_frame.add_child(_held_view)
	# PARENT FIRST, THEN ANCHOR. Applied before the node has a parent, a
	# full-rect preset resolves against a zero-sized parent and leaves offsets
	# that later ADD a full width and height -- the container came out 168 wide
	# inside an 84 wide frame, and the model rendered below it, off the bottom
	# of the screen.
	_held_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _refresh_held() -> void:
	var item: ItemData = inventory.get_selected()
	var count := inventory.count_at(inventory.selected)

	if item == null:
		_held_name.text = "empty hands"
		_held_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	elif count > 1:
		_held_name.text = "%s  x%d" % [item.display_name, count]
		_held_name.add_theme_color_override("font_color", item.color)
	else:
		_held_name.text = item.display_name
		_held_name.add_theme_color_override("font_color", item.color)

	_held_caption.text = "IN HAND  -  slot %d  -  %s book" % [inventory.selected + 1, Controls.glyph("Journal")]

	# The picture follows the selection. show_item hides the whole view when
	# there is nothing in hand, so an empty slot leaves the corner clean rather
	# than framing a void.
	if _held_view != null:
		_held_spin = ITEM_VIEW.show_item(_held_view, item, true, HELD_ZOOM)
		_held_frame.visible = _held_view.visible

	# The lens is the only thing on this line so far, and it earns the space:
	# it is carried rather than held, so nothing else on screen says you have
	# it or which key raises it.
	if inventory.equipment.is_empty():
		_gear_label.text = ""
	else:
		var parts := PackedStringArray()
		for gear in inventory.equipment:
			parts.append(gear.display_name)
		_gear_label.text = "%s  -  %s" % [", ".join(parts), Controls.glyph("Open_Magnify")]


func _on_interactable_changed(_target: Interactable) -> void:
	# _process fills in the text; this just clears it instantly on look-away
	# so the old prompt never lingers for a frame.
	if player.current_interactable == null:
		_prompt.text = ""


func _on_concealment_changed(is_concealed: bool) -> void:
	_hidden_label.visible = is_concealed


func _on_rejected(item: ItemData) -> void:
	show_message("No room for the %s. Open the book with %s and put something down with %s."
		% [item.display_name, Controls.glyph("Journal"), Controls.glyph("Drop")], 4.5)


func show_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


func set_subtitle_size(pixels: int) -> void:
	if _dialogue == null:
		return
	_dialogue.add_theme_font_size_override("font_size", pixels)
	_dialogue.offset_top = _dialogue.offset_bottom - 4.5 * pixels


## Queues a spoken line. Several fired at once play in order rather than the
## last one winning, which is what happens if you just assign the label.
func say(text: String) -> void:
	_dialogue_queue.append(text)


## Roughly reading speed, with a floor so short lines do not blink past.
func _hold_time(text: String) -> float:
	return clampf(1.4 + text.length() * 0.045, 2.0, 7.0)


func _tick_dialogue(delta: float) -> void:
	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer > 0.0:
			return
		_dialogue.text = ""

	if _dialogue_queue.is_empty():
		return

	var line: String = _dialogue_queue.pop_front()
	_dialogue.text = "“%s”" % line
	_dialogue_timer = _hold_time(line)


func show_message(text: String, seconds := 4.0) -> void:
	_message.text = text
	_message_timer = seconds


## Fades to black, then brings the closing line up underneath it.
func fade_out(duration := 2.5, closing_text := "") -> void:
	_message.text = ""
	_message_timer = 0.0

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, duration)
	if not closing_text.is_empty():
		_closing.text = closing_text
		_fade_tween.tween_property(_closing, "modulate:a", 1.0, 1.2)


## The other half of fade_out. Until respawning existed every fade in this
## game was the end of a scene, so nothing ever needed to come back.
func fade_in(duration := 1.0) -> void:
	_closing.text = ""
	_closing.modulate.a = 0.0
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, duration)


# ----------------------------------------------------------------- stamina

## Sits under the crosshair rather than off in a corner, because it is read
## while running and running is when the eye is dead centre. Narrow and low
## contrast: it is a glance, not a readout.
## The bar's SIZE is not here. It is whatever StaminaBox is in
## Scenes/ui/hud.tscn, and the fill measures itself against that -- widen the
## bar in the editor and the fill still fits it. A constant here would be a
## second opinion about the same rectangle.
## How far below the middle of the screen.
const STAMINA_DROP := 54.0
## Seconds to fade in and out. In is quicker than out -- you want to see it the
## moment it starts costing you, and you do not want it snatched away the
## instant you stop.
const STAMINA_FADE_IN := 6.0
const STAMINA_FADE_OUT := 1.6
## Below this the bar stays up even at rest, so a winded character is told why
## they cannot run.
const STAMINA_SHOW_BELOW := 0.995

const STAMINA_OK := Color(0.78, 0.76, 0.68)
## The winded colour. Not red -- nothing here is a health bar, and red reads as
## damage. This is the washed-out brown of the rest of the interface, dimmed.
const STAMINA_SPENT := Color(0.62, 0.34, 0.24)



func _on_stamina_changed(value: float, winded: bool) -> void:
	if _stamina_fill == null:
		return
	# Measured off the authored box, less the one-pixel inset each side.
	_stamina_fill.size.x = maxf((_stamina_box.size.x - 2.0) * value, 0.0)
	if winded != _stamina_winded:
		# TINTED, not restyled. The fill's stylebox is authored white in
		# Scenes/ui/hud.tscn and this colours it, so the bar's shape lives in
		# the scene and only the state it is in lives here. Building a fresh
		# StyleBoxFlat per state was the last thing keeping a _box() helper.
		_stamina_winded = winded
		_stamina_fill.modulate = STAMINA_SPENT if winded else STAMINA_OK
	# Up whenever there is something to say: spending it, or not yet recovered.
	_stamina_target = 1.0 if (value < STAMINA_SHOW_BELOW or winded) else 0.0


## Driven from _process rather than a Tween because the target flips often --
## every time the player taps sprint -- and restarting a tween on every flip
## costs more than a lerp does.
func _tick_stamina(delta: float) -> void:
	if _stamina_box == null:
		return
	var rate := STAMINA_FADE_IN if _stamina_target > _stamina_alpha else STAMINA_FADE_OUT
	_stamina_alpha = move_toward(_stamina_alpha, _stamina_target, delta * rate)
	_stamina_box.modulate.a = _stamina_alpha


# ------------------------------------------------------- cutscene overlays
# A white flash and the tunnel, both full-screen and both above everything
# else. They live here rather than in the cutscene that uses them because the
# fade rect is already here and three overlapping full-screen layers fighting
# over draw order is how you get a black screen nobody can explain.

# The shader itself is on the authored Tunnel rect in Scenes/ui/hud.tscn;
# _tunnel_mat, taken off it in _ready, is how its parameters get driven.


func flash(colour: Color, rise: float, hold: float, fall: float) -> void:
	if _flash == null:
		return
	_flash.color = Color(colour.r, colour.g, colour.b, 0.0)
	var t := create_tween()
	t.tween_property(_flash, "color:a", colour.a, maxf(rise, 0.001))
	t.tween_interval(hold)
	t.tween_property(_flash, "color:a", 0.0, maxf(fall, 0.001))


func set_tunnel(amount: float, travel: float) -> void:
	if _tunnel == null:
		return
	_tunnel.visible = amount > 0.001
	_tunnel_mat.set_shader_parameter("amount", amount)
	_tunnel_mat.set_shader_parameter("travel", travel)


## Everything off. Called when a cutscene is skipped or torn down, so a level
## change cannot leave a white sheet or a tunnel over the next scene.
func clear_overlays() -> void:
	if _flash != null:
		_flash.color.a = 0.0
	set_tunnel(0.0, 0.0)
