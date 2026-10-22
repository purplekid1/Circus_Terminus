extends SceneTree
## The player's HUD, now that it is a scene rather than ten _build_ functions.
##
## Scripts/InteractionHUD.gd used to call nineteen Controls into existence in
## _ready and set every anchor, offset, font and stylebox by hand. They are
## authored in Scenes/ui/hud.tscn now and the script only references them.
##
## THAT TRADE HAS A COST AND THIS IS THE INSURANCE. Layout in code is at least
## in one place and under review; layout in a scene can be nudged in the editor
## by accident and nothing complains. So the numbers that used to be constants
## in the script are pinned here instead -- if the chip moves, this says so.
##
## It also guards the join itself: a renamed node gives the script a null, and
## a null in a HUD does not crash, it just quietly stops drawing.

var _player: Node
var _hud: CanvasLayer
var _n := 0
var _pass := 0
var _fail := 0


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	print("HUD %s  %s" % ["PASS" if cond else "FAIL", label])


func _rect(node: Control) -> String:
	return "%.0f,%.0f,%.0f,%.0f" % [node.offset_left, node.offset_top,
		node.offset_right, node.offset_bottom]


func _at(path: String, want: String) -> void:
	var node := _hud.get_node_or_null(path) as Control
	if node == null:
		_ok("  %s exists" % path, false)
		return
	var got := _rect(node)
	_ok("  %s sits at %s" % [path, want], got == want)


func _process(_d: float) -> bool:
	_n += 1
	if _n == 1:
		_player = (load("res://Scenes/player.tscn") as PackedScene).instantiate()
		get_root().add_child(_player)
		return false
	if _n < 4:
		return false

	_hud = _player.get_node_or_null("CanvasLayer") as CanvasLayer
	_ok("the player carries a HUD", _hud != null)
	if _hud == null:
		return true
	# An instanced scene, not a script on a bare CanvasLayer. If this fails the
	# HUD has been put back into code.
	_ok("and it is an instanced scene", not _hud.scene_file_path.is_empty())

	# Every node the script reaches for. A rename here is silent at runtime:
	# the @onready is null and the label simply never draws.
	for path: String in ["Crosshair", "Prompt", "HiddenLabel", "HeldPanel",
			"HeldPanel/HeldName", "HeldPanel/HeldCaption", "GearLabel",
			"HeldFrame", "Message", "Hint", "Dialogue", "StaminaBox",
			"StaminaBox/Frame", "StaminaBox/Fill", "Overlays/Tunnel",
			"Overlays/Flash", "FadeLayer/Fade", "FadeLayer/Closing"]:
		_ok("  %s is there" % path, _hud.get_node_or_null(path) != null)

	# The geometry that used to be written in _build_held, _build_dialogue and
	# the rest, to the pixel.
	_at("Crosshair", "-2,-2,2,2")
	_at("HeldPanel", "-280,-96,-30,-30")
	_at("HeldFrame", "-374,-105,-290,-21")
	_at("GearLabel", "-400,-122,-30,-98")
	# Moved down the screen by hand in the editor, which is exactly the kind of
	# change this file is here to notice. Re-pinned rather than reverted.
	# set_subtitle_size derives the top edge from the bottom one, so -24 at the
	# 20 px medium size is what puts the top at -114.
	_at("Dialogue", "-470,-114,470,-24")
	_at("Message", "-430,-190,430,-110")
	_at("Hint", "-500,-104,500,-44")
	_at("StaminaBox", "-95,54,95,60")

	# Draw order. The fade has to cover the tunnel, or a fade to black during
	# the ending leaves the tunnel shader playing over the top of it.
	var overlays := _hud.get_node("Overlays") as CanvasLayer
	var fade_layer := _hud.get_node("FadeLayer") as CanvasLayer
	_ok("the tunnel sits on layer 98", overlays.layer == 98)
	_ok("and the fade above it on 100", fade_layer.layer == 100)
	_ok("the tunnel starts hidden", not _hud.get_node("Overlays/Tunnel").visible)
	_ok("with its shader already on it",
		(_hud.get_node("Overlays/Tunnel") as ColorRect).material is ShaderMaterial)

	# The one thing still built rather than authored: the turntable, which is
	# ItemView.make so that the hand and the book frame an item identically.
	_ok("the held view was dropped into its frame",
		_hud.get_node("HeldFrame").get_child_count() > 0)

	# The fill is TINTED now rather than restyled per state. Its stylebox is
	# authored white; modulate is what makes it bone or rust.
	var fill := _hud.get_node("StaminaBox/Fill") as Panel
	var ok_tint: Color = fill.modulate
	_hud.call("_on_stamina_changed", 0.5, true)
	_ok("a winded bar changes colour", fill.modulate != ok_tint)
	_ok("and narrows to the value", fill.size.x < 190.0)
	_hud.call("_on_stamina_changed", 1.0, false)
	_ok("and comes back when it recovers", fill.modulate == ok_tint)

	# The overlays still answer. These are the calls the ending makes.
	_hud.call("flash", Color(1, 1, 1, 1), 0.01, 0.01, 0.01)
	_hud.call("set_tunnel", 0.6, 4.0)
	_ok("set_tunnel shows the tunnel", _hud.get_node("Overlays/Tunnel").visible)
	_hud.call("clear_overlays")
	_ok("and clear_overlays puts it away", not _hud.get_node("Overlays/Tunnel").visible)

	# And it still speaks.
	_hud.call("say", "Wet ground, and pine.")
	_hud.call("_tick_dialogue", 0.016)
	_ok("say() still reaches the label",
		not (_hud.get_node("Dialogue") as Label).text.is_empty())

	print("HUD ....  %d passed, %d failed" % [_pass, _fail])
	return true
