extends SceneTree
## Stamina: that it drains, refills, runs out, and refuses to let a winded
## character run again until it has recovered.
##
## Driven by calling _tick_stamina directly with a fixed delta rather than by
## holding a key for eight real seconds. Headless runs uncapped, so waiting out
## a timer here measures the machine, not the game.

var _root: Node
var _p: Node
var _hud: Node
var _wait := 16
var _events := 0


func _ok(label: String, cond: bool) -> void:
	print("STAMINA %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_root = (load("res://demo_level.tscn") as PackedScene).instantiate()
	var intro := _root.get_node_or_null("Intro")
	if intro != null:
		intro.free()
	root.add_child(_root)


## One second of running or resting, in sixty steps, so the accumulation is the
## same shape it would be in play.
func _seconds(n: float, running: bool) -> void:
	for _i in int(n * 60.0):
		_p._tick_stamina(1.0 / 60.0, running)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	_p = _root.get_node("Player")
	_hud = _p.get_node("CanvasLayer")
	_p.stamina_changed.connect(func(_v: float, _w: bool) -> void: _events += 1)
	_p.velocity = Vector3.ZERO
	_p.set_stamina(1.0)
	_p._winded = false
	_p._winded_last = false

	_ok("starts full", _p.stamina == 1.0)
	_ok("and not winded", not _p._winded)

	# ---- draining ----
	_seconds(2.0, true)
	_ok("running spends it", _p.stamina < 1.0)
	_ok("and spends it at about the rate advertised",
		absf(_p.stamina - (1.0 - 2.0 / _p.SPRINT_SECONDS)) < 0.02)
	_ok("two seconds is not enough to empty it", not _p._winded)

	# ---- emptying ----
	_seconds(_p.SPRINT_SECONDS, true)
	_ok("running it out empties the tank", _p.stamina == 0.0)
	_ok("and leaves the character winded", _p._winded)
	# The point of the latch: a tap of the key right now must not start a run.
	_seconds(0.2, false)
	_ok("a little breath back is not enough to run again",
		not _p._sprint_wanted(true))
	_ok("and the tank is still below the threshold", _p.stamina < _p.WIND_BACK)

	# ---- recovering ----
	_seconds(_p.RECOVER_SECONDS, false)
	_ok("resting refills it", _p.stamina > _p.WIND_BACK)
	_ok("and clears the winded state", not _p._winded)
	_seconds(_p.RECOVER_SECONDS, false)
	_ok("it stops at full, and does not overfill", _p.stamina == 1.0)

	# ---- rest beats walking ----
	_p.set_stamina(0.5)
	_p.velocity = Vector3.ZERO
	_seconds(1.0, false)
	var rested: float = _p.stamina
	_p.set_stamina(0.5)
	_p.velocity = Vector3(3.4, 0.0, 0.0)
	_seconds(1.0, false)
	var walked: float = _p.stamina
	_ok("standing still recovers faster than walking", rested > walked)
	_p.velocity = Vector3.ZERO

	# ---- the bar ----
	_ok("the HUD has a stamina bar", _hud._stamina_box != null)
	_p.set_stamina(1.0)
	_p._winded = false
	_p._winded_last = false
	_seconds(0.1, false)
	_hud._tick_stamina(2.0)
	_ok("which is hidden at a full tank", _hud._stamina_box.modulate.a == 0.0)

	_p.set_stamina(1.0)
	_seconds(1.0, true)
	_hud._tick_stamina(2.0)
	_ok("and visible once it is being spent", _hud._stamina_box.modulate.a > 0.5)
	var wide: float = _hud._stamina_fill.size.x
	_seconds(2.0, true)
	_ok("the fill shrinks as it drains", _hud._stamina_fill.size.x < wide)

	_seconds(_p.SPRINT_SECONDS, true)
	_ok("the bar reports the winded state", _hud._stamina_winded)
	_ok("and stays up while winded even at rest", _hud._stamina_target == 1.0)

	# ---- no needless signal traffic ----
	_p.set_stamina(1.0)
	_p._winded = false
	_p._winded_last = false
	_seconds(0.5, false)
	var quiet := _events
	_seconds(1.0, false)
	_ok("a full tank at rest emits nothing", _events == quiet)

	return true
