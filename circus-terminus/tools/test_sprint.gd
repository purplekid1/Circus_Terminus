extends SceneTree
## Sprint. It is derived every frame from conditions that are all true NOW,
## and these are the cases the old toggle-on-press-and-on-release version got
## wrong: a release swallowed by a menu, and a crouch taken mid-run.

var _root: Node = null
var _wait := 16

func _initialize() -> void:
	var ps: PackedScene = load("res://demo_level.tscn")
	_root = ps.instantiate()
	# The opening cutscene takes the player's controls, and "a set piece owns
	# the controls" is one of the things that stops a sprint. Without this the
	# test is measuring the intro.
	var intro := _root.get_node_or_null("Intro")
	if intro != null:
		intro.free()
	root.add_child(_root)

func _ok(label: String, cond: bool) -> void:
	print("SPRINT %s  %s" % ["PASS" if cond else "FAIL", label])

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	var p := _root.get_node("Player")
	p.sprint_toggle = false

	Input.action_release("Sprint")
	_ok("still by default", not p._sprint_wanted(false))

	Input.action_press("Sprint")
	_ok("held but standing still is not running", not p._sprint_wanted(false))
	_ok("held and moving is running", p._sprint_wanted(true))

	p.crouching = true
	_ok("crouched is never running", not p._sprint_wanted(true))
	p.crouching = false

	p.focus_target = p
	_ok("a set piece has the controls, so no running", not p._sprint_wanted(true))
	p.focus_target = null
	_ok("and it comes straight back", p._sprint_wanted(true))

	# The old bug: the release arrives while something else owns input, so the
	# toggle never sees it and the player sprints for the rest of the session.
	Input.action_release("Sprint")
	_ok("a swallowed release cannot leave it stuck", not p._sprint_wanted(true))

	# Toggle mode.
	p.sprint_toggle = true
	p._sprint_latched = true
	_ok("latched and moving is running", p._sprint_wanted(true))
	_ok("latched and stopped is not", not p._sprint_wanted(false))
	_ok("and stopping clears the latch", not p._sprint_latched)

	p._sprint_latched = true
	p.crouching = true
	_ok("crouching clears the latch", not p._sprint_wanted(true) and not p._sprint_latched)

	return true
