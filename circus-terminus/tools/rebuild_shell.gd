extends SceneTree
## Bakes Scenes/_shell_rebuild.tscn straight over the mansion's shell meshes.
##
## Driven by tools/rebuild_shell.sh -- see that script for why this exists
## rather than just running bake.gd. In short: mansion.tscn has been arranged
## by hand and must not be rewritten, but the building it sits inside is two
## nodes pointing at two mesh files, and those can be replaced underneath it.
##
## The output paths are FIXED, not derived from node names, because they have
## to match what mansion.tscn already references.

const SCENE := "res://Scenes/_shell_rebuild.tscn"
const SETTLE := 6      # frames for CSG to evaluate before reading it back

const TARGETS := {
	"Shell": "res://Meshes/mansion_Shell",
	"Exterior": "res://Meshes/mansion_Exterior",
}

var _root: Node = null
var _wait := 0


func _initialize() -> void:
	var ps := ResourceLoader.load(SCENE, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if ps == null:
		push_error("cannot load " + SCENE)
		quit(1)
		return
	_root = ps.instantiate()
	root.add_child(_root)
	_wait = SETTLE


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	for name in TARGETS:
		var csg := _root.get_node_or_null(name) as CSGShape3D
		if csg == null:
			push_error("no CSG node called " + name)
			continue
		var mesh := csg.bake_static_mesh()
		if mesh == null or mesh.get_surface_count() == 0:
			push_error("nothing baked for " + name)
			continue

		var base: String = TARGETS[name]
		_save(mesh, base + ".res", name + " mesh")
		if csg.use_collision:
			_save(mesh.create_trimesh_shape(), base + "_col.res", name + " collision")

	quit()
	return true


## take_over_path so anything already holding the old resource in this run
## picks up the new one rather than silently keeping a stale copy.
func _save(res: Resource, path: String, what: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s: %d" % [path, err])
		return
	res.take_over_path(path)
	print("  %-20s -> %s" % [what, path])
