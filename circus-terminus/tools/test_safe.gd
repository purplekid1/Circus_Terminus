extends SceneTree
## The safe traps the player if there is no way back out of it, so this checks
## the way back out.
##
## It exists because there WAS no way out. Escape was handled by the journal
## before the safe ever saw it, and the safe's only other exit is cracking the
## combination -- so anyone who walked up to it early stayed there.

var _lvl: Node
var _player: Node
var _safe: Node
var _hud: Node
var _stage := 0
var _wait := 8
var _hint := ""
## Autoloads are not registered when --script compiles this, so `Controls`
## cannot be named directly -- fetched by node path once the tree is up.
var _controls: Node


func _ok(label: String, cond: bool) -> void:
	print("SAFE %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	root.add_child(_lvl)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	if _stage == 0:
		_player = _lvl.get_node("Player")
		_safe = _lvl.get_node("Mansion/Vault")
		_hud = _player.get_node("CanvasLayer")
		_controls = root.get_node("/root/Controls")
		_ok("the level has a safe", _safe != null)
		# The level opens in the arrival cutscene. It holds focus AND it eats
		# Escape as its skip key, so with it still running this test measured
		# the intro rather than the safe -- "Escape did not open the book"
		# passed because the cutscene swallowed the press. Stop it first.
		var intro := _lvl.get_node("Intro")
		intro._running = false
		intro._skipped = true
		_player.end_focus()
		_player.hint_changed.connect(func(t: String) -> void: _hint = t)

		_safe.interact(_player)
		_ok("using the safe takes focus", _player.focus_target == _safe)
		_ok("and puts the controls on screen", not _hint.is_empty())
		_ok("which name the step-back button",
			_hint.contains(_controls.glyph("Back")))
		_ok("and the HUD is showing them", _hud._hint.text == _hint)

		# The bug: Escape used to open the book instead of reaching the safe.
		_press("Pause")
		_ok("Escape does not open the book over the dials", not _player.journal.open)
		_ok("it steps back out of the safe", _player.focus_target == null)
		_ok("and takes the controls off screen", _hint.is_empty())

		_stage = 1
		return false

	if _stage == 1:
		# And again on the button the hint actually advertises.
		_safe.interact(_player)
		_ok("the safe can be used again", _player.focus_target == _safe)
		_press("Back")
		_ok("Back leaves the safe", _player.focus_target == null)
		_ok("the hint is cleared", _hint.is_empty())

		# Turning the dials still works, and does not leave by accident.
		_safe.interact(_player)
		var before: int = _safe._digits[0]
		_press("Move_Forward")
		_ok("the dials still turn", _safe._digits[0] != before)
		_ok("and turning one does not leave", _player.focus_target == _safe)
		_press("Back")

		_ok("the book still opens in ordinary play", _open_book())
		return true

	return false


## Feeds an action press through the same path a real key takes.
func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.push_input(ev)


func _open_book() -> bool:
	_press("Journal")
	var open: bool = _player.journal.open
	_player.journal.set_open(false)
	return open
