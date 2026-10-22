extends SceneTree
## The subtitle size setting, from the journal's dropdown to the label.
##
## Three things have to line up and none of them shouts when it does not: the
## player holds the setting, a signal carries it, and the HUD owns the Control
## that actually changes size. A dropdown wired to nothing looks exactly like a
## dropdown wired to something.
##
## The last pair of assertions are the ones that earn their place. MEDIUM has
## to be what subtitles have always been -- 20 px -- or every existing player
## gets a silent resize they did not ask for; and the BOX has to grow with the
## font, because the line is word-wrapped into a fixed height and a large
## subtitle that wraps to one more row than it used to just loses it.

var _player: Node
var _hud: CanvasLayer
var _dialogue: Label
var _n := 0
var _pass := 0
var _fail := 0
var _heard: Array[int] = []


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	print("SUBS %s  %s" % ["PASS" if cond else "FAIL", label])


func _process(_d: float) -> bool:
	_n += 1
	if _n == 1:
		_player = (load("res://Scenes/player.tscn") as PackedScene).instantiate()
		get_root().add_child(_player)
		return false
	if _n < 4:
		return false

	_hud = _player.get_node_or_null("CanvasLayer") as CanvasLayer
	_ok("the player has a HUD", _hud != null)
	if _hud == null:
		return true
	_dialogue = _hud.get("_dialogue") as Label
	_ok("with a subtitle label on it", _dialogue != null)
	if _dialogue == null:
		return true

	# The three sizes the journal offers, in the journal's own order.
	_ok("SMALL is 0, MEDIUM 1, LARGE 2",
		int(_player.SubtitleSize.SMALL) == 0
		and int(_player.SubtitleSize.MEDIUM) == 1
		and int(_player.SubtitleSize.LARGE) == 2)
	_ok("it starts on MEDIUM", int(_player.get("subtitle_size")) == int(_player.SubtitleSize.MEDIUM))
	# 20 px is what they were before the setting existed. If this ever has to
	# change, it is a deliberate decision and not a tidy-up.
	_ok("and MEDIUM is the 20 px they always were", _player.subtitle_pixels() == 20)
	_ok("the label was built at that size",
		_dialogue.get_theme_font_size("font_size") == 20)

	var was_top: float = _dialogue.offset_top
	var was_bottom: float = _dialogue.offset_bottom

	_player.subtitle_size_changed.connect(func(px: int) -> void: _heard.append(px))

	# --- large
	_player.set("subtitle_size", _player.SubtitleSize.LARGE)
	_ok("choosing Large announces a bigger size", _heard.size() == 1 and _heard[0] > 20)
	_ok("and the label actually grows",
		_dialogue.get_theme_font_size("font_size") == _player.subtitle_pixels())
	_ok("the box grows with it", _dialogue.offset_top < was_top)
	_ok("but stays pinned to the same bottom edge",
		absf(_dialogue.offset_bottom - was_bottom) < 0.01)

	# --- small
	_player.set("subtitle_size", _player.SubtitleSize.SMALL)
	_ok("choosing Small announces a smaller one", _heard.size() == 2 and _heard[1] < 20)
	_ok("and the label shrinks",
		_dialogue.get_theme_font_size("font_size") == _player.subtitle_pixels())
	_ok("with the box back inside where Medium had it", _dialogue.offset_top > was_top)

	# --- back to medium
	_player.set("subtitle_size", _player.SubtitleSize.MEDIUM)
	_ok("and Medium returns it exactly",
		_dialogue.get_theme_font_size("font_size") == 20
		and absf(_dialogue.offset_top - was_top) < 0.01)

	# A line still arrives while a size is set -- the resize must not have
	# taken the label out of the speaking path.
	_player.say("Ground. Wet ground, and pine.")
	_hud.call("_tick_dialogue", 0.016)
	_ok("and it still speaks", not _dialogue.text.is_empty())

	print("SUBS ....  %d passed, %d failed" % [_pass, _fail])
	return true
