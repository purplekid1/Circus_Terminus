class_name SafeCode
extends Node
## Rolls the safe combination fresh for every playthrough, and rewrites the
## three things the house uses to tell the player what it is.
##
## THE PUZZLE IS NOT MINE -- it was already in the mansion, and it is a good
## one. A note pinned to the wall, in handwriting too small to read without the
## glass, says:
##
##     "In order, left to right: the hour the clock died. The last figure on
##      the newest portrait. And however many marks she cut into the bureau."
##
## So the three dials come from three different objects in three different
## rooms, and the note is the only thing that says which order they go in. The
## player needs the lens to read the note, has to notice which portrait is the
## newest, and has to count.
##
## What was broken was one link: the bureau's `reveals` named a tally sheet
## that had never been built, so the third dial existed nowhere in the world
## and the safe could not be opened by fair means. That is fixed in
## Scenes/bureau.tscn, and everything here exists to keep the other two
## honest once the numbers stopped being constants.
##
## WHY IT IS ROLLED AT RUNTIME. A fixed combination is looked up once and known
## forever. Rolling it means the clock, the portraits and the tally have to be
## read every time -- which is the only thing that keeps the lens mattering on
## a second playthrough.
##
## THE ONE RULE HERE: every number this picks must be written back into all
## three sources AND into the safe. A clue that disagrees with the lock is
## worse than no clue, because the player will trust it and conclude the
## puzzle is broken. tools/test_code.tscn checks all four agree.

## The Safe whose combination this sets.
@export var safe: NodePath

@export_group("The three sources, in dial order")
## Dial one: "the hour the clock died".
@export var clock: NodePath
## Dial two: "the last figure on the newest portrait". Oldest first -- the last
## one in this list is the one the text calls the newest.
@export var portraits: Array[NodePath] = []
## Dial three: "however many marks she cut into the bureau".
@export var tally: NodePath

@export_group("Wording")
## One per portrait, in the same order. Each takes its year.
@export var portrait_lines: PackedStringArray = PackedStringArray([
	"A sour-looking man in a high collar. Brass plate underneath: %d.",
	"A woman with her hand on a globe. The plate reads %d.",
	"A girl, painted last of the three. %d, and the paint is barely aged.",
])
@export var clock_line := "The hands have stopped. Twenty past %s, and the case is cold."
@export_multiline var tally_line := (
	"Cut into the inside of the lid, over and over, with something sharp:\n\n    %s")

## Spelled out, the way the original clock text read. Index 0 is unused.
@export var hour_words: PackedStringArray = PackedStringArray([
	"", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
])

@export_group("The dates")
@export var earliest := 1841
@export var latest := 1979
## Minimum gap between portraits, so "the newest" is never a squint.
@export var min_gap := 13

## What the safe ended up wanting. Read by the tests.
var code := ""
## The hour on the clock, the years on the portraits, the marks in the bureau.
var hour := 0
var years: Array[int] = []
var marks := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Dial one. 1 to 9: a clock reading ten, eleven or twelve does not give
	# one figure, and zero is not an hour.
	hour = rng.randi_range(1, 9)

	# Dial two comes off the newest portrait, so roll the years first and take
	# it from them rather than the other way round.
	years = _roll_years(rng, maxi(_live(portraits).size(), 1))

	# Dial three. At least one, because counting no marks at all is not a
	# puzzle, it is an empty drawer.
	marks = rng.randi_range(1, 9)

	code = "%d%d%d" % [hour, years[years.size() - 1] % 10, marks]

	var box := get_node_or_null(safe)
	if box != null:
		box.set("combination", code)
	else:
		push_warning("SafeCode: no safe at '%s'. The clues are written and " % safe
			+ "nothing is listening to them.")

	_write(clock, clock_line % hour_words[hour])

	var plates := _live(portraits)
	for i in plates.size():
		var line: String = portrait_lines[i] if i < portrait_lines.size() else "%d."
		plates[i].set("text", line % years[i])

	_write(tally, tally_line % _marks_as_scratches(marks))


## Sets whatever the node reads out. Readable keeps its copy in `text`, Clue in
## `note`; this writes whichever the node actually has rather than caring which
## kind it is.
func _write(path: NodePath, body: String) -> void:
	var node := get_node_or_null(path)
	if node == null:
		push_warning("SafeCode: nothing at '%s' to write a clue into." % path)
		return
	if node.get("note") != null:
		node.set("note", body)
	else:
		node.set("text", body)


## Marks to be counted, not a number to be read. Spaced out, and grouped in
## fives the way anybody keeping a count actually cuts them.
func _marks_as_scratches(count: int) -> String:
	var out := ""
	for i in count:
		if i > 0:
			out += "     " if i % 5 == 0 else "  "
		out += "|"
	return out


## Node paths that actually resolve. A portrait deleted from the scene must not
## leave a digit in the combination that exists nowhere in the house.
func _live(paths: Array[NodePath]) -> Array[Node]:
	var out: Array[Node] = []
	for p in paths:
		var n := get_node_or_null(p)
		if n != null:
			out.append(n)
	return out


## `count` years, oldest first, each at least `min_gap` from the others.
func _roll_years(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var out: Array[int] = []
	var guard := 0
	while out.size() < count and guard < 500:
		guard += 1
		var y := rng.randi_range(earliest, latest)
		var ok := true
		for had: int in out:
			if absi(had - y) < min_gap:
				ok = false
		if ok:
			out.append(y)
	out.sort()
	return out
