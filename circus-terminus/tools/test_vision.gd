extends Node
## Everything the magnifying glass is supposed to pick out actually carries a
## tag, and everything interactable is in the group that gets one.
##
## RUN IT AS A SCENE, not with --script:
##
##     godot --headless --path . tools/test_vision.tscn
##
## and that is not a style choice. A --script SceneTree adds its level before
## the autoloads have finished starting, so VisionTags' refresh_tags() sweeps a
## tree that is already complete and everything looks tagged no matter what.
## The real game loads autoloads FIRST and the main scene after, so tagging
## rests entirely on the node_added signal -- which is the path that broke, and
## the path a --script test cannot see. Both bugs this file covers passed a
## --script check while being completely broken in the game.

var _n := 0
var _passes := 0
var _fails := 0


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
	print("VISION %s  %s" % ["PASS" if cond else "FAIL", label])


func _ready() -> void:
	add_child((load("res://demo_level.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> void:
	_n += 1
	# Let every pickup build its model; that happens in _ready and is the whole
	# reason this is hard.
	if _n < 40:
		return

	var items := get_tree().get_nodes_in_group("items")
	var inter := get_tree().get_nodes_in_group("interactable")
	_ok("the level has items in it", items.size() > 0)
	_ok("and interactable things", inter.size() > 0)

	# A pickup throws away the placeholder box its scene carries and
	# instantiates the real item model, in _ready -- after VisionTags tagged
	# the placeholder. Miss that and the item has a dozen meshes and no
	# overlay on any of them, and it is invisible through the glass.
	var lit := _count(items)
	_ok("every mesh of every item is tagged (%d of %d)" % [lit[0], lit[1]],
		lit[1] > 0 and lit[0] == lit[1])

	# Group membership written into a .tscn is lost whenever the scene is
	# rebuilt or re-saved, silently. Interactable puts itself in the group in
	# _enter_tree so a scene cannot forget.
	var missing: Array[String] = []
	_collect_ungrouped(get_tree().current_scene, missing)
	_ok("nothing interactable is missing from a tagged group (%s)"
		% ("none" if missing.is_empty() else ", ".join(missing)), missing.is_empty())

	var ilit := _count(inter)
	_ok("and every interactable mesh is tagged (%d of %d)" % [ilit[0], ilit[1]],
		ilit[1] > 0 and ilit[0] == ilit[1])

	print("VISION ....  %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _count(nodes: Array) -> Array:
	var tagged := 0
	var total := 0
	for n: Node in nodes:
		for c in n.find_children("*", "GeometryInstance3D", true, false):
			total += 1
			if (c as GeometryInstance3D).material_overlay != null:
				tagged += 1
	return [tagged, total]


func _collect_ungrouped(node: Node, out: Array[String]) -> void:
	if node == null:
		return
	if node is Interactable and not node.is_in_group("interactable") \
			and not node.is_in_group("items"):
		out.append(node.name)
	for child in node.get_children():
		_collect_ungrouped(child, out)
