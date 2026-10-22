extends SceneTree
## The lens survives a change of level.
##
## This is the one piece of state in the game that crosses a scene boundary,
## and the failure it guards against is total rather than cosmetic: the woods
## level is built entirely around looking at things through the glass, so
## arriving there without it is not a worse experience, it is an unwinnable
## one. Nothing else in the game would report that -- the level loads, the
## creatures patrol, and the player simply cannot see any of them.
##
## The other half is the reverse mistake. A new game has to CLEAR it, or the
## second playthrough in a session starts holding the lens and the whole first
## act of the house -- finding it -- is skipped with no error anywhere.

var _stage := 0
var _wait := 14
var _lvl: Node
var _passes := 0
var _fails := 0


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
	print("CARRY %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	# Whatever a previous test in the same process left behind.
	Carry.reset()


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	match _stage:
		0: _test_statics()
		1: _load_level()
		2: _test_fresh_player()
		3: _test_grant()
		4: _reload_level()
		5: _test_carried_player()
		6: _test_spare_pickup()
		_:
			print("CARRY ....  %d passed, %d failed" % [_passes, _fails])
			return true
	_stage += 1
	return false


func _test_statics() -> void:
	_ok("a new game starts without the lens", not Carry.has_magnifier)
	Carry.has_magnifier = true
	_ok("and the flag can be set", Carry.has_magnifier)
	Carry.reset()
	_ok("and a new game clears it again", not Carry.has_magnifier)


func _load_level() -> void:
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	var intro := _lvl.get_node_or_null("Intro")
	if intro != null:
		intro.free()
	root.add_child(_lvl)
	_wait = 8


func _test_fresh_player() -> void:
	var p := _lvl.get_node("Player")
	_ok("a player with nothing carried has no lens", not p.has_magnifier)


func _test_grant() -> void:
	var p := _lvl.get_node("Player")
	p.grant_magnifier()
	_ok("picking it up gives it to the player", p.has_magnifier)
	_ok("and records it for the next level", Carry.has_magnifier)


## Standing in for change_scene_to_file: tear the level down and build another.
## The point of the carry is that it outlives exactly this.
func _reload_level() -> void:
	_lvl.free()
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	var intro := _lvl.get_node_or_null("Intro")
	if intro != null:
		intro.free()
	root.add_child(_lvl)
	_wait = 8


func _test_carried_player() -> void:
	var p := _lvl.get_node("Player")
	_ok("the next level's player already has it", p.has_magnifier)


func _test_spare_pickup() -> void:
	# The woods put a spare lens where the player lands, so that starting that
	# level on its own is playable. When the real one was carried in, the spare
	# has to take itself away rather than sit there as a duplicate.
	var spare := (load("res://Scenes/pickup.tscn") as PackedScene).instantiate()
	spare.grants_magnifier = true
	_lvl.add_child(spare)
	_ok("and the spare one in the woods removes itself",
		spare.is_queued_for_deletion())

	Carry.reset()
	var kept := (load("res://Scenes/pickup.tscn") as PackedScene).instantiate()
	kept.grants_magnifier = true
	_lvl.add_child(kept)
	_ok("but it stays when there is no lens to carry",
		not kept.is_queued_for_deletion())
