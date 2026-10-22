extends SceneTree
## The "in hand" corner: the picture of whatever the player is carrying.
##
## The geometry assertions are here because of a real bug. The view's anchors
## were applied before it was parented, so a full-rect preset resolved against
## a zero-sized parent and left offsets that ADDED a width and a height: the
## container came out exactly twice the frame's size and the model rendered
## below it, off the bottom of the screen.

var _lvl: Node
var _hud: Node
var _inv: Node
var _wait := 14
var _stage := 0


func _ok(label: String, cond: bool) -> void:
	print("HELD %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	var intro := _lvl.get_node_or_null("Intro")
	if intro != null:
		intro.free()
	root.add_child(_lvl)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	var p := _lvl.get_node("Player")
	_hud = p.get_node("CanvasLayer")
	_inv = p.get_node("Inventory")

	if _stage == 0:
		_ok("the HUD has a held-item frame", _hud._held_frame != null)
		_ok("and a view inside it", _hud._held_view != null)
		_ok("empty hands show no frame", not _hud._held_frame.visible)
		_inv.add(load("res://Items/crowbar.tres"))
		_stage = 1
		_wait = 3
		return false

	if _stage == 1:
		_ok("picking something up shows the frame", _hud._held_frame.visible)
		_ok("and puts a model in the view", _hud._held_spin != null)

		var frame: Rect2 = _hud._held_frame.get_global_rect()
		var view: Rect2 = _hud._held_view.get_global_rect()
		# The bug: view was 168 square inside an 84 square frame.
		_ok("the view is the size of its frame", view.size.is_equal_approx(frame.size))
		_ok("and sits on top of it", view.position.is_equal_approx(frame.position))
		_ok("which is the size it was asked for",
			is_equal_approx(frame.size.x, _hud.HELD_VIEW))
		# Against the REAL viewport, not a hard-coded 1920x1080 -- headless runs
		# at whatever size it likes and the first version of this failed on that
		# rather than on anything being wrong.
		var screen: Rect2 = root.get_visible_rect()
		_ok("the whole thing is on screen", screen.encloses(frame))

		# The picture must not fall off the edge of its own viewport either --
		# that is what the extra framing distance is for.
		var sub := _hud._held_view.get_child(0) as SubViewport
		_ok("the viewport matches the view", sub.size == Vector2i(view.size))
		_ok("and it is pulled back further than the book's framing",
			_hud.HELD_ZOOM > 1.0)

		var turned: float = _hud._held_spin.rotation.y
		_hud._tick_stamina(0.0)
		_hud._process(0.5)
		_ok("the model turns", not is_equal_approx(_hud._held_spin.rotation.y, turned))

		_inv.drop_selected() if _inv.has_method("drop_selected") else _inv.remove_selected()
		_stage = 2
		_wait = 3
		return false

	_ok("putting it down clears the frame again", not _hud._held_frame.visible)
	return true
