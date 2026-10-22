extends Node
## The safe combination, and the three things in the house that tell you it.
##
##     godot --headless --path . tools/test_code.tscn
##
## THE CENTRAL TEST HERE SOLVES THE PUZZLE THE WAY A PLAYER WOULD: it reads the
## pinned note for the order, reads the hour off the clock, finds the newest
## portrait and takes the last figure of its year, counts the marks in the
## bureau, and then checks that what it worked out actually opens the safe.
##
## That is the only assertion that really matters, because the failure it
## guards against is the nastiest kind: a clue that DISAGREES with the lock.
## The player trusts it, tries it, it does not work, and they conclude the game
## is broken. Four separate places write these numbers now and nothing else
## would notice them drifting apart.
##
## What was actually broken: the bureau's `reveals` named "Lid/TallyClue" and
## no such node had ever been built, so the third dial existed nowhere in the
## world at all and the safe could not be opened by fair means.

var _n := 0
var _passes := 0
var _fails := 0


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
	print("CODE %s  %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	add_child((load("res://demo_level.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> void:
	_n += 1
	if _n < 40:
		return
	var scene := get_tree().current_scene

	var setter := scene.find_child("SafeCode", true, false) as SafeCode
	var vault := scene.find_child("Vault", true, false)
	_ok("something rolls the combination", setter != null)
	_ok("and there is a safe to roll it for", vault != null)
	if setter == null or vault == null:
		_finish()
		return

	_ok("the code is three digits (%s)" % setter.code, setter.code.length() == 3)
	_ok("and the safe is set to it", vault.combination == setter.code)
	_ok("and it is not the old hard-coded 407", vault.combination != "407")

	var rolls: Dictionary = {}
	for i in 40:
		rolls[_roll_once()] = true
	_ok("and it changes from run to run (%d in 40 rolls)" % rolls.size(), rolls.size() > 5)

	# ---- the pinned note, which is the only thing giving the order ----------
	var note := scene.find_child("SafeNote", true, false)
	_ok("the note on the wall is still there", note != null)
	if note != null:
		var t: String = note.text.to_lower()
		_ok("and it needs the glass", note.requires_lens)
		_ok("and it names the clock", t.contains("clock"))
		_ok("and the newest portrait", t.contains("portrait") and t.contains("newest"))
		_ok("and the marks in the bureau", t.contains("bureau") and t.contains("marks"))

	# ---- now solve it the way a player does --------------------------------
	var clock := scene.find_child("ClockFace", true, false)
	var first := -1
	if clock != null:
		for h in range(1, setter.hour_words.size()):
			if clock.text.to_lower().contains(setter.hour_words[h]):
				first = h
	_ok("the hour can be read off the clock (%d)" % first, first >= 1 and first <= 9)

	# The newest portrait, found by comparing the years on them rather than by
	# trusting the order they are listed in.
	var newest := -1
	var found := 0
	for name: String in ["PortraitA", "PortraitB", "PortraitC"]:
		var p := scene.find_child(name, true, false)
		if p == null:
			continue
		found += 1
		var y := _year_in(p.text)
		if y > newest:
			newest = y
	_ok("all three portraits are hung", found == 3)
	_ok("and the newest carries a year (%d)" % newest, newest >= 1800 and newest <= 1999)
	# Unambiguous: two portraits sharing the newest year would make the second
	# dial a coin toss.
	var ties := 0
	for name: String in ["PortraitA", "PortraitB", "PortraitC"]:
		var p := scene.find_child(name, true, false)
		if p != null and _year_in(p.text) == newest:
			ties += 1
	_ok("and only one of them is the newest", ties == 1)

	var tallied := scene.find_child("TallyClue", true, false)
	var third := -1
	if tallied != null:
		third = tallied.note.count("|")
	_ok("the marks in the bureau can be counted (%d)" % third, third >= 1 and third <= 9)

	# THE ONE THAT MATTERS.
	var worked_out := "%d%d%d" % [first, newest % 10, third]
	_ok("what the house tells you actually opens the safe (%s vs %s)"
		% [worked_out, vault.combination], worked_out == vault.combination)

	# ---- and the link that was missing entirely ----------------------------
	_ok("the bureau has the tally sheet the scene asks for", tallied != null)
	if tallied != null:
		_ok("which starts hidden", not tallied.visible)
		_ok("and disabled until the bureau is opened", not tallied.enabled)
	var bureau := scene.find_child("Bureau", true, false)
	if bureau != null:
		var named := false
		for path in bureau.reveals:
			if bureau.get_node_or_null(path) == tallied:
				named = true
		_ok("and the bureau actually points at it", named)

	_finish()


## The first four-digit year in a line of prose.
func _year_in(text: String) -> int:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
			if digits.length() == 4:
				return digits.to_int()
		else:
			digits = ""
	return -1


func _roll_once() -> String:
	var s := SafeCode.new()
	add_child(s)
	var out: String = s.code
	s.queue_free()
	return out


func _finish() -> void:
	print("CODE ....  %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
