extends SceneTree
## The two book cutscenes. Driven at speed rather than in real time: the
## exported durations are shortened before either is played, so the test
## measures the SHAPE of the sequence instead of sitting through nine seconds
## of it twice.
##
## What matters here is that each one holds the controls for its whole length,
## touches the things it claims to touch, and hands back a black screen. A
## cutscene that leaves the player mid-flash with the controls still taken is a
## softlock, and it is the failure mode these are most likely to have.

var _lvl: Node
var _player: Node
var _book: Node
var _ending: Node
var _wait := 14
var _stage := 0
var _elapsed := 0.0

var _flashes := 0
var _tunnel_seen := 0.0
var _tunnel_travel := 0.0
var _faded := false
var _start_pos := Vector3.ZERO
var _book_y0 := 0.0
var _book_tilt0 := 0.0
## The closest the eye ever gets to the pages during the absorb, sampled every
## frame. The pull used to stop nearly two metres short and the white-out did
## the rest, which read as being dragged under the book rather than into it.
var _closest := 999.0


func _ok(label: String, cond: bool) -> void:
	print("CUT %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	var intro := _lvl.get_node_or_null("Intro")
	if intro != null:
		intro.free()
	root.add_child(_lvl)


func _hook() -> void:
	_flashes = 0
	_tunnel_seen = 0.0
	_tunnel_travel = 0.0
	_faded = false
	_player.flash_requested.connect(
		func(_c: Color, _r: float, _h: float, _f: float) -> void: _flashes += 1)
	_player.tunnel_requested.connect(func(a: float, t: float) -> void:
		_tunnel_seen = maxf(_tunnel_seen, a)
		_tunnel_travel = maxf(_tunnel_travel, t))
	_player.fade_requested.connect(
		func(_d: float, _t: String) -> void: _faded = true)


## Shortens everything so a sequence runs in well under a second.
##
## It used to set a dozen *_time exports. Those are KEYFRAMES now -- the whole
## running order lives in Scenes/anim/book_ending.tscn -- so the way to hurry
## an animation-driven cutscene is to run its animation faster, which is also
## the only way that keeps the phases in proportion to each other. 60x turns
## the 2.7 s approach into 45 ms and the 8.6 s absorb into 145 ms.
##
## black_out survives as an export because it is a FADE duration handed to the
## HUD, not a gap in the edit.
const HURRY := 60.0

func _hurry() -> void:
	(_ending.get_node("Anim") as AnimationPlayer).speed_scale = HURRY
	_ending.black_out = 0.05
	# Nowhere to go: the point is the sequence, not the level change, and a
	# scene swap mid-test takes the whole thing away.
	_ending.next_level = ""


func _process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	# Sampled every frame while the absorb runs, so the closest approach is
	# caught wherever in the sequence it happens.
	if _stage == 1 and _book != null and _player != null:
		var pages: Node3D = _book.get_node_or_null("PageLight")
		if pages != null:
			_closest = minf(_closest,
				_player.camera.global_transform.origin.distance_to(pages.global_position))

	if _stage == 0:
		_player = _lvl.get_node("Player")
		_book = _lvl.get_node("Mansion/Grimoire")
		_ending = _lvl.get_node("Mansion/BookEnding")
		_player.end_focus()

		_ok("the level has a book ending", _ending != null)
		_ok("the book points at it", _book.ending_path != NodePath(""))
		_ok("and it knows which book", _ending.get_node(_ending.book_path) == _book)
		_ok("the tunnel shader exists",
			ResourceLoader.exists("res://Scripts/tunnel.gdshader"))
		_ok("the HUD can flash", _player.get_node("CanvasLayer")._flash != null)
		_ok("and has a tunnel layer", _player.get_node("CanvasLayer")._tunnel != null)
		_ok("which starts hidden", not _player.get_node("CanvasLayer")._tunnel.visible)

		_hurry()
		_hook()
		_book_y0 = _book.position.y
		_book_tilt0 = _book.rotation.x

		# ---- ABSORB ----
		#
		# STAND WHERE SOMEBODY WHO JUST TOUCHED THE BOOK WOULD BE STANDING.
		#
		# This used to run from wherever the player spawn happened to be, and
		# then measure how close the pull got. That measures the LEVEL, not the
		# cutscene: the spawn gets parked next to whatever is being worked on
		# and moved back later, and when it was eight metres from the desk this
		# failed with the sequence working perfectly. A cutscene test should
		# set up its own preconditions.
		_stand_at_the_book()
		_ending.mode = 1
		_start_pos = _player.global_position
		_ending.play(_player)
		_ok("absorb takes the controls", _player.focus_target == _ending)
		_stage = 1
		_elapsed = 0.0
		return false

	if _stage == 1:
		_elapsed += delta
		if _elapsed < 1.2:
			# It must NOT hand the controls back partway through.
			if _player.focus_target == null and not _faded:
				_ok("absorb keeps the controls until the end", false)
				_stage = 2
			return false
		# The approach, which both endings share: you lean in, it reacts, the
		# book comes up off the desk and stands on its spine facing you.
		_ok("the book comes up off the desk", _book.position.y > _book_y0 + 0.2)
		_ok("and stands up", absf(_book.rotation.x - _book_tilt0) > 0.5)
		# FACING THE PLAYER, not away. The pages face local +Y flat, and the tilt
		# swings that to local -Z -- so the yaw needs a PI on it. Without that the
		# book stood up with its back turned, at exactly 180 degrees out, and the
		# only way to see it is to measure the normal.
		var normal: Vector3 = _book.global_transform.basis.y
		var to_player: Vector3 = _player.global_position - _book.global_position
		normal.y = 0.0
		to_player.y = 0.0
		_ok("with the pages toward you, not the back of it",
			normal.normalized().dot(to_player.normalized()) > 0.7)
		# INTO the pages, not under them. The book origin is at its base, so a
		# pull aimed there drags the eye below the open pages; this aims at the
		# page light and closes most of the real gap rather than a flat 0.85 m.
		_ok("the pull actually reaches the book (closest %.2f m)" % _closest, _closest < 0.7)
		_ok("absorb whites the screen out", _flashes > 0)
		_ok("and runs the tunnel", _tunnel_seen > 0.9)
		_ok("travelling down it", _tunnel_travel > 1.0)
		_ok("it moves the player somewhere else",
			_player.global_position.distance_to(_start_pos) > 5.0)
		_ok("and ends on black", _faded)
		_ok("with the tunnel cleared away",
			not _player.get_node("CanvasLayer")._tunnel.visible)
		_stage = 2
		return false

	if _stage == 2:
		# Reset for the second one.
		_player.get_node("CanvasLayer").clear_overlays()
		_player.global_position = _start_pos
		_player.camera.rotation_degrees = Vector3.ZERO
		_player.end_focus()
		_ending._running = false
		_hook()

		_ending.mode = 0
		_start_pos = _player.global_position
		_ending.play(_player)
		_ok("blast takes the controls", _player.focus_target == _ending)
		_stage = 3
		_elapsed = 0.0
		return false

	if _stage == 3:
		_elapsed += delta
		# 1.8, not 1.0: the burn-out tween runs 0.86 s and starts after the
		# approach and the lift, so a shorter window caught the light on its way
		# down rather than out.
		if _elapsed < 1.8:
			return false
		_ok("blast flashes", _flashes > 0)
		_ok("but never runs the tunnel -- that is the other one",
			_tunnel_seen < 0.01)
		_ok("it rolls the camera over", absf(_player.camera.rotation_degrees.z) > 10.0)
		_ok("throws the player back", _player.global_position.distance_to(_start_pos) > 0.3)
		# The blast is allowed to throw you across the room. The APPROACH is not:
		# that one is a flinch, and it was launching the player a pace and a half
		# backwards until it was cut to a shuffle.
		_ok("but the flinch before it is only a shuffle",
			_ending.retreat_distance < 0.5)
		_ok("and ends on black", _faded)
		# The book should have been left mid-air and dark, not tidied up.
		var light: OmniLight3D = _book.get_node("PageLight")
		_ok("the book burns out", light.light_energy < 1.0)
		return true

	return false


## Puts the player an arm's length from the book, on the floor, which is the
## only place the absorb is ever triggered from in play. Direction does not
## matter -- the book yaws to face whoever set it off.
func _stand_at_the_book() -> void:
	var at: Vector3 = _book.global_position
	at.y = _player.global_position.y
	_player.global_position = at + Vector3(0.0, 0.0, 1.1)
	_player.velocity = Vector3.ZERO
