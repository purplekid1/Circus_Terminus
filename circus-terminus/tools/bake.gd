extends SceneTree
## Bakes every CSG tree in the generated scenes down to plain MeshInstance3D.
##
##   godot --headless --path . --script tools/bake.gd
##
## CSG is a modelling tool, not a runtime one. The house was carrying ~215 live
## CSG trees -- the shell, the trim, every room group and one per instanced prop
## -- and the editor re-evaluates those on any change, which is what made it
## crawl. Baked, the same geometry is static meshes with trimesh collision.
##
## Prop scenes go first: once they are meshes, the mansion's instances of them
## are meshes too, so the mansion pass only has to deal with its own CSG.
##
## Node names and transforms are preserved, so every NodePath in the scene --
## the obstacle's blockers, the generator's light targets -- still resolves.

const MESH_DIR := "res://Meshes"
const SETTLE := 4     # frames to let CSG rebuild before reading it back

var _queue: Array = []
var _current: Node = null
var _current_path := ""
var _wait := 0
var _baked := 0
var _meshes := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))

	# BAKE_ONLY=res://Scenes/foo.tscn bakes that one scene and nothing else.
	# Needed once mansion.tscn is hand-arranged: the full sweep is harmless
	# there (it is already baked, finds no CSG and writes nothing) but there
	# is no reason to walk it, and a single-scene mode is the honest way to
	# say "rebuild this one thing".
	var only := OS.get_environment("BAKE_ONLY")
	if not only.is_empty():
		_queue.append(only)
		print("baking %s" % only)
		return

	# Items before props before the mansion, because each tier instances the
	# one above it: bake an item first and the prop that holds it inherits the
	# mesh rather than folding a second copy of the geometry into itself.
	for f in _scenes_in("res://Scenes/items"):
		_queue.append(f)
	for f in _scenes_in("res://Scenes/props"):
		_queue.append(f)
	_queue.append("res://Scenes/mansion.tscn")
	print("baking %d scenes" % _queue.size())


func _process(_delta: float) -> bool:
	if _current == null:
		if _queue.is_empty():
			print("baked %d scenes, %d meshes -> %s" % [_baked, _meshes, MESH_DIR])
			return true
		_current_path = _queue.pop_front()
		var ps := ResourceLoader.load(_current_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if ps == null:
			push_error("cannot load " + _current_path)
			return false
		_current = ps.instantiate()
		root.add_child(_current)
		_wait = SETTLE
		return false

	if _wait > 0:
		_wait -= 1
		return false

	var prefix := _current_path.get_file().get_basename()
	var n := 0
	var to_pack := _current
	if _current is CSGShape3D:
		# A prop scene IS the combiner, so there is no parent to swap it in.
		# Build a fresh root instead and pack that.
		var baked := _bake_root(_current as CSGShape3D, prefix)
		if baked != null:
			to_pack = baked
			n = 1
	else:
		n = _bake_tree(_current, _current, prefix)
	if n > 0:
		var packed := PackedScene.new()
		if packed.pack(to_pack) == OK:
			var err := ResourceSaver.save(packed, _current_path)
			if err != OK:
				push_error("save failed %s: %d" % [_current_path, err])
		print("  %-38s %d mesh(es)" % [_current_path.get_file(), n])
	_baked += 1
	_meshes += n
	_current.queue_free()
	_current = null
	return false


func _scenes_in(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	out.sort()
	return out


## Replaces every CSG *root* under `node` with a baked MeshInstance3D. A CSG
## root is a CSGShape3D whose parent is not itself CSG -- anything below that is
## a brush the root already folds in.
func _bake_tree(node: Node, owner_root: Node, prefix: String) -> int:
	var count := 0
	for child in node.get_children():
		# Leave instanced sub-scenes alone. A prop instance is a whole scene the
		# mansion points at; baking it here would inline 172 copies of geometry
		# the prop-scene pass has already turned into a single shared mesh.
		if child.scene_file_path != "":
			continue
		if child is CSGShape3D and not (node is CSGShape3D):
			if _bake_one(child as CSGShape3D, owner_root, prefix):
				count += 1
		else:
			count += _bake_tree(child, owner_root, prefix)
	return count


func _bake_one(csg: CSGShape3D, owner_root: Node, prefix: String) -> bool:
	var mesh := csg.bake_static_mesh()
	if mesh == null or mesh.get_surface_count() == 0:
		# Nothing in it. Rooms whose furniture is all instanced end up with an
		# empty combiner; leaving it would keep live CSG in a baked scene.
		if csg.get_child_count() == 0:
			csg.get_parent().remove_child(csg)
			csg.queue_free()
		return false

	var res_path := "%s/%s_%s.res" % [MESH_DIR, prefix, _slug(csg, owner_root)]
	var err := ResourceSaver.save(mesh, res_path)
	if err != OK:
		push_error("mesh save failed %s: %d" % [res_path, err])
		return false
	mesh.take_over_path(res_path)

	var mi := MeshInstance3D.new()
	mi.name = csg.name
	mi.transform = csg.transform
	mi.mesh = mesh

	# Trimesh collision, only where the CSG carried it. Rugs and ceiling
	# fittings are built without, so they stay non-colliding.
	if csg.use_collision:
		mi.add_child(_collider(mesh, "%s/%s_%s_col.res" % [MESH_DIR, prefix, _slug(csg, owner_root)]))

	var parent := csg.get_parent()
	var index := csg.get_index()
	parent.remove_child(csg)
	parent.add_child(mi)
	parent.move_child(mi, index)
	csg.queue_free()

	# pack() only writes nodes the scene root owns.
	mi.owner = owner_root
	for d in _descendants(mi):
		d.owner = owner_root
	return true


## Same as _bake_one, but for a CSG node that is a scene root: there is nothing
## to swap it into, so this returns a new root for the caller to pack.
func _bake_root(csg: CSGShape3D, prefix: String) -> MeshInstance3D:
	var mesh := csg.bake_static_mesh()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var res_path := "%s/%s.res" % [MESH_DIR, prefix]
	if ResourceSaver.save(mesh, res_path) != OK:
		push_error("mesh save failed " + res_path)
		return null
	mesh.take_over_path(res_path)

	var mi := MeshInstance3D.new()
	mi.name = csg.name
	mi.mesh = mesh
	if csg.use_collision:
		var body := _collider(mesh, "%s/%s_col.res" % [MESH_DIR, prefix])
		mi.add_child(body)
		body.owner = mi
		body.get_child(0).owner = mi
	return mi


## Trimesh collision saved beside the mesh. Inline, a chair's collision is a
## few hundred vertices of PackedVector3Array literal in the scene text.
func _collider(mesh: ArrayMesh, path: String) -> StaticBody3D:
	var shape := mesh.create_trimesh_shape()
	if ResourceSaver.save(shape, path) == OK:
		shape.take_over_path(path)
	var body := StaticBody3D.new()
	body.name = "Body"
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	body.add_child(col)
	return body


## Path from the scene root, flattened. Two nodes called "Steps" under different
## staircases would otherwise write to the same file and one would lose.
func _slug(n: Node, owner_root: Node) -> String:
	var p := String(owner_root.get_path_to(n))
	return p.replace("/", "_")


func _descendants(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out
