extends SceneTree
## Every collider in the project, measured against the thing it is supposed to
## be the shape of.
##
##     godot --headless --path . --script tools/probe_hitboxes.gd
##
## A hitbox that is too BIG is the one players actually notice: an invisible
## wall in front of a switch, a chair you cannot walk past, a doorway that
## catches your shoulder. A hitbox that is too SMALL is quieter but worse in
## its own way -- you fall through a step, or a thing you are clearly looking
## at refuses to be looked at.
##
## Two numbers, because neither alone is enough. A 3x ratio on a 2 cm plaque is
## nothing; a 1.4x ratio on a 9 m door is most of a metre of invisible wall. So
## a scene is only reported when the ratio AND the absolute overhang are both
## past the limits below.

## How much bigger than its mesh a collider may be before it is worth saying so.
const RATIO := 1.35
## And how many metres of that, so tiny parts stay quiet.
const SLACK := 0.25

## Scenes where the collider is legitimately not the shape of the mesh, with
## the reason. A probe that reports four known-fine things every run teaches
## everyone to ignore its output, which is worse than having no probe.
const EXPECTED := {
	"mansion.tscn":
		"a whole level, not an object -- the two boxes measure different things",
	"player.tscn":
		"the mesh is the glass held in front of the camera; the collider is the body",
	"steps_porch.tscn":
		"a deliberately thick ramp buried under the treads, because "
		+ "CharacterBody3D has no step-up and stairs need a slope to walk on",
	"steps_cellar.tscn":
		"same buried ramp as the porch steps",
	"stalker.tscn":
		"a character capsule: round, where the creature is flat",
}

var _bad := 0
var _skipped := 0
var _checked := 0


func _initialize() -> void:
	var files: Array[String] = []
	_find("res://Scenes", files)
	files.sort()
	print("HITBOX ....  %d scenes" % files.size())
	for path in files:
		_check(path)
	print("HITBOX %s  %d colliders checked, %d worth a look, %d known-fine"
		% ["PASS" if _bad == 0 else "FAIL", _checked, _bad, _skipped])
	quit(1 if _bad > 0 else 0)


func _find(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := dir.path_join(name)
			if d.current_is_dir():
				_find(full, out)
			elif name.ends_with(".tscn"):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _check(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	# CSG needs a frame in the tree to build its meshes, but these are small
	# scenes and the AABBs we want come straight off the shapes and meshes.
	get_root().add_child(root)

	var mesh := _mesh_box(root)
	var col := _collider_box(root)
	if mesh.size != Vector3.ZERO and col.size != Vector3.ZERO:
		_checked += 1
		var r := Vector3(
			col.size.x / maxf(mesh.size.x, 0.01),
			col.size.y / maxf(mesh.size.y, 0.01),
			col.size.z / maxf(mesh.size.z, 0.01))
		var worst: float = maxf(maxf(r.x, r.y), r.z)
		var over: Vector3 = col.size - mesh.size
		var most: float = maxf(maxf(over.x, over.y), over.z)
		if worst > RATIO and most > SLACK:
			if EXPECTED.has(path.get_file()):
				_skipped += 1
			else:
				_bad += 1
				print("HITBOX OVER  %-26s mesh %s  collider %s  (+%.2f m)"
					% [path.get_file(), _v(mesh.size), _v(col.size), most])

	root.free()


func _v(s: Vector3) -> String:
	return "%.2f/%.2f/%.2f" % [s.x, s.y, s.z]


## The transform from `root` down to `node`, accumulated.
##
## NOT node.transform. That is the node's own local transform and it misses
## every parent in between, so a mesh sitting under a scaled holder is measured
## in the MODEL'S units rather than the prop's. The bookcases are built that
## way -- a `Model` node carries the scale and the yaw, and the carcass and the
## books hang off it -- and this probe read them as 6.44 m wide and called a
## correct collider two metres short. Every other prop has its meshes directly
## under the root, which is why that went unnoticed.
func _chain(node: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root:
		var n3 := walk as Node3D
		if n3 != null:
			xf = n3.transform * xf
		walk = walk.get_parent()
	return xf


func _mesh_box(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var g := c as MeshInstance3D
		if g.mesh == null:
			continue
		var a: AABB = _chain(g, n) * g.get_aabb()
		box = a if first else box.merge(a)
		first = false
	for c in n.find_children("*", "CSGShape3D", true, false):
		var g := c as CSGShape3D
		var a: AABB = _chain(g, n) * g.get_aabb()
		box = a if first else box.merge(a)
		first = false
	# A MULTIMESH IS NOT A MeshInstance3D. The forests are one
	# MultiMeshInstance3D apiece, so without this the probe measured the
	# surroundings as a 14 m ground plate and then flagged the 32 m trunk
	# colliders standing in trees it could not see as eighteen metres too
	# tall. MultiMesh.get_aabb() already spans every instance.
	for c in n.find_children("*", "MultiMeshInstance3D", true, false):
		var g := c as MultiMeshInstance3D
		if g.multimesh == null:
			continue
		# READ OFF THE BUFFER, not through the API. In a headless run there is
		# no rendering server, so BOTH MultiMesh.get_aabb() and
		# get_instance_transform() come back empty or identity -- the trees are
		# there, the renderer just is not. The buffer is a plain resource
		# property and holds twelve floats an instance, the three ROWS of a
		# 3x4 matrix. Basis() takes COLUMNS, hence the transpose.
		var mm := g.multimesh
		var base: AABB = mm.mesh.get_aabb() if mm.mesh != null else AABB()
		var chain := _chain(g, n)
		var buf := mm.buffer
		for i in mm.instance_count:
			var o := i * 12
			if o + 11 >= buf.size():
				break
			var xf := Transform3D(
				Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]),
					Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
					Vector3(buf[o + 2], buf[o + 6], buf[o + 10])),
				Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			var a: AABB = (chain * xf) * base
			box = a if first else box.merge(a)
			first = false
	return AABB() if first else box


func _collider_box(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if cs.shape == null or cs.disabled:
			continue
		var a: AABB = _chain(cs, n) * cs.shape.get_debug_mesh().get_aabb()
		box = a if first else box.merge(a)
		first = false
	return AABB() if first else box
