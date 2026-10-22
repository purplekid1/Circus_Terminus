extends SceneTree
## The demo's last beat: walking into the study makes the character notice the
## book, and touching the book is what ends the demo.
##
## It used to end on an Area3D across the study door, so the demo was over the
## moment you looked into the room and you never reached the object the whole
## level points at.

var _lvl: Node
var _p: Node
var _book: Node
var _wait := 12
var _stage := 0
var _said: Array[String] = []
var _faded := false
var _closing := ""


func _ok(label: String, cond: bool) -> void:
	print("ENDING %s  %s" % ["PASS" if cond else "FAIL", label])


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

	if _stage == 0:
		_p = _lvl.get_node("Player")
		_book = _lvl.get_node("Mansion/Grimoire")
		_p.end_focus()
		_p.line_spoken.connect(func(t: String) -> void: _said.append(t))
		_p.fade_requested.connect(func(_d2: float, t: String) -> void:
			_faded = true
			_closing = t)

		_ok("the book is in the level", _book != null)
		_ok("and it is the thing that ends the demo", _book.ends_demo)

		var trigger := _lvl.get_node("Mansion/StudyEnd")
		_ok("the study trigger is a dialogue line now, not the ending",
			trigger.get_script().resource_path.ends_with("DialogueTrigger.gd"))
		_ok("and it has something to say about the book", trigger.lines.size() > 0)

		# Out of the study first, and reset the trigger.
		#
		# THIS TEST DOES NOT OWN THE SPAWN. The player starts wherever the level
		# says, and that moves -- it is currently parked at the desk, which is
		# inside this very trigger, so the line fired at load before anything was
		# listening and "walking in" could never be observed. Setting up its own
		# precondition costs three lines and makes the test independent of where
		# somebody happens to be debugging from.
		var trig := _lvl.get_node("Mansion/StudyEnd")
		_p.global_position = _lvl.get_node("Mansion").global_position + Vector3(0, 5.1, -12)
		trig._spoken = false
		_said.clear()
		_stage = 4
		_wait = 4
		return false

	if _stage == 4:
		# And now walk in.
		_p.global_position = _lvl.get_node("Mansion").global_position + Vector3(0, 5.1, -25)
		_stage = 1
		_wait = 10
		return false

	if _stage == 1:
		_ok("walking in makes the character notice it", not _said.is_empty())
		_ok("but does NOT end the demo", not _faded)
		_ok("the book is still there to be reached", _book.available(_p))

		_book.interact(_p)
		_ok("touching it turns a page", _book._page > 0)
		_ok("and starts the ending", _book._ending)
		_ok("the prompt goes at once", not _book.available(_p))
		# A second press must not stack a second fade.
		_book.interact(_p)
		_ok("a second touch is ignored", _book._page <= 1)
		_ok("and the fade has not begun yet", not _faded)
		_stage = 2
		return false

	if _stage == 2:
		if not _faded:
			return false
		_ok("then the demo ends", _faded)
		# NO CLOSING CARD any more. The book hands over to BookEnding, which runs
		# a cutscene and then changes level -- "END OF DEMO" belonged to the
		# version where touching the book simply faded out. The cutscenes
		# themselves are covered by tools/test_cutscene.gd.
		var cut := _lvl.get_node_or_null("Mansion/BookEnding")
		_ok("by handing over to the cutscene", cut != null)
		_ok("which took the controls", _p.focus_target == cut)
		return true

	return false
