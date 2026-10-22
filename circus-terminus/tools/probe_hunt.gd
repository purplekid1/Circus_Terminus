extends SceneTree
## Walks the creatures, the way tools/probe_circus.gd walks the player.
##
## The unit tests in tools/test_hunt.gd prove the RULES -- what it can see,
## what it does about it. They run on a bare plane, so what they cannot prove
## is the thing most likely to actually go wrong: that four of them, dropped
## into a real forest, can walk their real patrols without wedging against a
## trunk. A creature stuck on scenery is worse than no creature, because the
## player learns the woods are safe and the whole level goes slack.
##
## Also checks the thing a screenshot cannot tell you apart: a creature that is
## invisible because its material says so, and a creature that is invisible
## because it fell through the floor.

const SECONDS := 22.0
const LEVEL := "res://circus_level.tscn"

var _lvl: Node
var _stalkers: Array[Stalker] = []
var _start: Array[Vector3] = []
var _far: Array[float] = []
var _seen_marks: Array[Dictionary] = []
var _t := 0.0
var _warm := 8
var _passes := 0
var _fails := 0


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
	print("HUNTPROBE %s  %s" % ["PASS" if cond else "FAIL", label])


func _initialize() -> void:
	_lvl = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(_lvl)
	# Takes the camera and the controls, and holds the player still on the
	# floor for eight seconds. Nothing here needs it.
	var wake := _lvl.get_node_or_null("WakeUp")
	if wake != null:
		wake.free()


func _process(delta: float) -> bool:
	if _warm > 0:
		_warm -= 1
		if _warm == 0:
			# The player is the one thing that would turn this into a test of
			# how the creatures REACT rather than of whether they patrol. Park
			# it out of every sight cone. Done here and not in _initialize:
			# a node added to the tree this frame has no global transform yet.
			var p := _lvl.get_node_or_null("Player")
			if p != null:
				(p as Node3D).global_position = Vector3(0, 1, 400)
			for node in get_nodes_in_group("enemy"):
				if node is Stalker:
					var s := node as Stalker
					_stalkers.append(s)
					_start.append(s.global_position)
					_far.append(0.0)
					_seen_marks.append({})
		return false

	_t += delta
	for i in _stalkers.size():
		var s := _stalkers[i]
		_far[i] = maxf(_far[i], _start[i].distance_to(s.global_position))
		# Which of its own markers it has actually reached. Distance covered
		# alone would be satisfied by a creature grinding in a circle.
		for m in s._marks.size():
			if s.global_position.distance_to(s._marks[m].global_position) < 2.5:
				_seen_marks[i][m] = true

	if _t < SECONDS:
		return false

	_ok("the level has creatures in it", _stalkers.size() == 4)

	var below := 0
	var idle := 0
	var stuck := 0
	var one_mark := 0
	for i in _stalkers.size():
		var s := _stalkers[i]
		if s.global_position.y < -2.0:
			below += 1
			print("   %s fell through the world (y %.1f)" % [s.name, s.global_position.y])
		if _far[i] < 3.0:
			idle += 1
			print("   %s went nowhere (%.1f m in %.0f s)" % [s.name, _far[i], SECONDS])
		if s._stuck > 3.0:
			stuck += 1
			print("   %s is wedged (stuck for %.1f s) at (%.0f, %.0f)"
				% [s.name, s._stuck, s.global_position.x, s.global_position.z])
		if _seen_marks[i].size() < 2:
			one_mark += 1
			print("   %s reached %d of its %d markers"
				% [s.name, _seen_marks[i].size(), s._marks.size()])

	_ok("none of them fell through the floor", below == 0)
	_ok("all of them are walking", idle == 0)
	_ok("none of them is wedged against a tree", stuck == 0)
	_ok("and each one is getting round its patrol", one_mark == 0)

	# Invisible by material, not by absence. This is the check a screenshot
	# cannot make: an unspawned creature and a working one look identical.
	var tagged := 0
	var lit := 0
	for s: Stalker in _stalkers:
		for child in s.get_children():
			if child is MeshInstance3D:
				var m := child as MeshInstance3D
				if m.material_overlay != null:
					tagged += 1
				var mat := m.mesh.surface_get_material(0) as StandardMaterial3D
				if mat != null and mat.albedo_color.a > 0.2:
					lit += 1
	_ok("their meshes exist and carry the vision tag", tagged >= 4 * 7)
	_ok("and none of them is solid enough to see", lit == 0)

	# It has to be audible, or an invisible enemy is a coin toss.
	#
	# THE LOOP IS THE POINT OF THIS CHECK. The breath clip is under nine
	# seconds; if its import does not say Forward, every creature in the level
	# falls permanently silent nine seconds in and the only fair way to find
	# one disappears with no error anywhere. It has already happened once: the
	# WAV importer's loop_mode list is not the runtime enum, and its 1 means
	# Disabled, not Forward. This probe runs longer than the clip on purpose.
	var voices := 0
	var loops := 0
	for s: Stalker in _stalkers:
		var v := s.get_node_or_null("Voice") as AudioStreamPlayer3D
		if v == null:
			continue
		if v.playing:
			voices += 1
		var w := v.stream as AudioStreamWAV
		if w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			loops += 1
	_ok("their breath is set to loop", loops == _stalkers.size())
	_ok("and they are all still breathing past the end of the clip",
		voices == _stalkers.size() and _t > 10.0)

	print("HUNTPROBE ....  %d passed, %d failed" % [_passes, _fails])
	return true
