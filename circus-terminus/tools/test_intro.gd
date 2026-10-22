extends SceneTree
## The opening cutscene's overlay and its hand-over.
##
## The letterbox, the fade, the title and the line used to be ninety lines of
## Control construction inside Intro.gd, and the fades were tweens built next to
## them. They are Scenes/ui/intro_overlay.tscn and two AnimationPlayers now.
## Both halves of that can fail silently: an instanced scene whose node names
## drifted gives a null on get_node, and a value track pointed at a Control that
## has been renamed writes nothing and says nothing.
##
## The cutscene is SKIPPED on the first frame, because what is being tested is
## the overlay and the hand-over, not the edit -- and a skip has to leave the
## same screen behind as a watched one, which is the assertion that matters.

var _level: Node
var _intro: Node
var _overlay: CanvasLayer
var _t := 0.0
var _stage := -1
var _pass := 0
var _fail := 0
var _finished := false

## Name and world position of every Intro camera marker, taken before the
## cutscene frees itself.
var _markers: Array = []


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
	print("INTRO %s  %s" % ["PASS" if cond else "FAIL", label])


func _process(delta: float) -> bool:
	_t += delta

	if _stage == -1:
		_level = (load("res://demo_level.tscn") as PackedScene).instantiate()
		get_root().add_child(_level)
		_intro = _level.get_node_or_null("Intro")
		_ok("the level has an Intro", _intro != null)
		if _intro == null:
			return true
		_intro.finished.connect(func() -> void: _finished = true)
		_stage = 0
		_t = 0.0
		return false

	if _stage == 0:
		# One frame for Intro._ready to build the overlay.
		if _t < 0.1:
			return false
		_overlay = _intro.get("_overlay") as CanvasLayer
		_ok("it instanced the overlay scene", _overlay != null)
		if _overlay == null:
			return true
		_ok("named IntroOverlay", _overlay.name == "IntroOverlay")
		for want: String in ["Fade", "BarTop", "BarBottom", "Title", "Line", "Skip", "Anim", "TitleAnim"]:
			_ok("  it has %s" % want, _overlay.get_node_or_null(want) != null)
		var anim := _overlay.get_node("Anim") as AnimationPlayer
		for want: String in ["cut_in", "cut_out", "hand_over"]:
			_ok("  \"%s\" is keyed" % want, anim.has_animation(want))
		_ok("  \"title\" is on its own player",
			(_overlay.get_node("TitleAnim") as AnimationPlayer).has_animation("title"))

		# The title text is the one thing still built in code.
		_ok("the title text was filled in",
			not (_overlay.get_node("Title") as Label).text.is_empty())
		_ok("and the letterbox starts closed",
			absf((_overlay.get_node("BarTop") as Control).offset_bottom - 110.0) < 0.01)
		_ok("on black", (_overlay.get_node("Fade") as ColorRect).color.a > 0.99)

		# The camera markers, TAKEN NOW. _hand_over frees the Intro on its way
		# out, so by the time the assertions run there is nothing left to ask.
		for marker in _intro.get_children():
			if marker is Marker3D:
				_markers.append([String(marker.name), (marker as Marker3D).global_position])

		# Skip it. Everything after this is the hand-over.
		_intro.set("_skipped", true)
		_stage = 1
		_t = 0.0
		return false

	# cold_open is 1.4 and hand_over_time 1.6, plus slack for the shot in flight.
	if _t < 9.0 and not _finished:
		return false

	# THE CAMERA MUST NOT OPEN INSIDE A TREE. The woods outside the wall are
	# a filled grid now, not a distant ring, and the two markers the first
	# shot uses sit on the far verge -- outside the road corridor unless that
	# corridor is deliberately cut wide enough for them. It was not, the first
	# time: the opening frame of the game was the inside of a trunk, and
	# nothing failed, because a camera inside geometry still renders.
	var trunks := _level.get_node_or_null("Surroundings/Treeline/Trunks")
	_ok("the woods have trunk colliders", trunks != null)
	if trunks != null:
		var worst := INF
		var worst_at := ""
		for entry in _markers:
			var at: Vector3 = entry[1]
			for shape in trunks.get_children():
				var cs := shape as CollisionShape3D
				var d := Vector2(cs.global_position.x - at.x,
					cs.global_position.z - at.z).length()
				if d < worst:
					worst = d
					worst_at = String(entry[0])
		_ok("and no camera marker stands in one (closest %.1f m, %s)"
			% [worst, worst_at], worst > 3.0)

	_ok("it finished", _finished)

	if is_instance_valid(_overlay):
		var bar := _overlay.get_node_or_null("BarTop") as Control
		var fade := _overlay.get_node_or_null("Fade") as ColorRect
		if bar != null:
			_ok("the letterbox opened all the way", absf(bar.offset_bottom) < 0.01)
		if fade != null:
			_ok("and the picture came up off black", fade.color.a < 0.01)
	else:
		# _hand_over frees the overlay on the way out, which is also correct.
		_ok("the overlay was cleaned up", true)
	var player := _level.get_node_or_null("Player")
	_ok("the controls went back to the player",
		player == null or player.get("focus_target") == null)

	print("INTRO ....  %d passed, %d failed" % [_pass, _fail])
	return true
