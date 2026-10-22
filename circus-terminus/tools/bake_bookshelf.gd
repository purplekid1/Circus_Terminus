extends SceneTree
## Bakes Models/bookshelf/BookShelf.fbx down to two meshes in Meshes/, and
## gives every one of its books its own colour on the way through.
##
## WHY BAKE IT. The model is 149 MeshInstance3Ds -- a shelf carcass and 148
## individual books, 37 to a shelf -- and each book carries two surfaces, a
## cover and a block of pages. Instanced as-is that is ~297 draw calls for one
## bookcase and sixteen of them stand in the house. Merged, it is THREE: the
## carcass, every cover, every page block.
##
## WHY VERTEX COLOURS. Every book in the model wears the same dark red
## Book_color material. Giving them different colours with materials would mean
## one material and one surface per colour, which puts the draw calls straight
## back. Instead each book's cover gets a tint written into its VERTEX COLOURS
## and Mat_bookspine multiplies that into a white albedo -- so all 148 covers
## stay one surface and one draw call, and no two books next to each other are
## the same colour.
##
## Re-run it if the model is ever re-exported:
##   godot --headless --path . --script tools/bake_bookshelf.gd
##
## It writes one books mesh per bookcase size, each with its own colour run, so
## a wall of bookcases does not repeat the same shelf three times.

const SRC := "res://Models/bookshelf/BookShelf.fbx"
const OUT_CASE := "res://Meshes/bookshelf_case.res"

## Seeds, one per bookcase size. Same geometry, different colour run.
const RUNS := {"low": 11, "med": 57, "tall": 103}

var _n := 0
var _r: Node3D


func _initialize() -> void:
	_r = (load(SRC) as PackedScene).instantiate()
	get_root().add_child(_r)


## The library palette. Muted cloth-and-board colours -- oxblood, forest,
## tan, navy, faded mauve, burnt leather, near-black, vellum -- with a little
## per-book drift on top so a run of the same hue does not read as a block.
func _colour(i: int, seed_v: int) -> Color:
	var base: Array[Color] = [
		Color(0.26, 0.135, 0.105), Color(0.115, 0.165, 0.135),
		Color(0.315, 0.245, 0.135), Color(0.125, 0.145, 0.225),
		Color(0.235, 0.185, 0.215), Color(0.315, 0.16, 0.065),
		Color(0.105, 0.12, 0.11), Color(0.235, 0.23, 0.18)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + i * 104729
	var c: Color = base[rng.randi() % base.size()]
	# Drift, so two neighbours that land on the same base still differ.
	var k := rng.randf_range(0.78, 1.28)
	var out := Color(
		clampf(c.r * k + rng.randf_range(-0.03, 0.03), 0.02, 1.0),
		clampf(c.g * k + rng.randf_range(-0.03, 0.03), 0.02, 1.0),
		clampf(c.b * k + rng.randf_range(-0.03, 0.03), 0.02, 1.0))
	# TO LINEAR. The palette above is written the way albedo_color is written,
	# in sRGB, but a vertex colour is fed to the shader as-is and the shader
	# works in linear. Skipping this renders every book about twice as bright
	# as it should be -- the whole case came out in pastels, a childrens
	# library rather than a shut-up house.
	return out.srgb_to_linear()


func _append(st: SurfaceTool, mi: MeshInstance3D, surface: int, tint: Color) -> void:
	var arr := mi.mesh.surface_get_arrays(surface)
	var vs := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var ns := arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var uv := arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var ix := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
	var xf := mi.transform
	for i in ix.size():
		var j := ix[i]
		st.set_color(tint)
		if ns.size() > j:
			st.set_normal(xf.basis * ns[j])
		if uv.size() > j:
			st.set_uv(uv[j])
		st.add_vertex(xf * vs[j])


func _process(_d: float) -> bool:
	_n += 1
	if _n < 6:
		return false

	var books: Array[MeshInstance3D] = []
	var shelf: MeshInstance3D = null
	for c in _r.get_children():
		var m := c as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		if m.name == "Shelf":
			shelf = m
		else:
			books.append(m)
	if shelf == null or books.is_empty():
		push_error("bake_bookshelf: expected a Shelf and some Books, got %d books" % books.size())
		return true

	# ---- the carcass, once
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(cs, shelf, 0, Color.WHITE)
	cs.index()
	var case_mesh := ArrayMesh.new()
	cs.commit(case_mesh)
	var err := ResourceSaver.save(case_mesh, OUT_CASE)
	print("bookshelf case -> %s  err=%d  verts=%d" % [OUT_CASE, err,
		(case_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])

	# ---- the books, once per size, with a different colour run each time
	for size: String in RUNS:
		var covers := SurfaceTool.new()
		covers.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pages := SurfaceTool.new()
		pages.begin(Mesh.PRIMITIVE_TRIANGLES)
		var i := 0
		for b in books:
			var tint := _colour(i, RUNS[size])
			# surface 0 is the cover, surface 1 the block of pages
			_append(covers, b, 0, tint)
			if b.mesh.get_surface_count() > 1:
				_append(pages, b, 1, Color.WHITE)
			i += 1
		covers.index()
		pages.index()
		var mesh := ArrayMesh.new()
		covers.commit(mesh)
		pages.commit(mesh)
		var path := "res://Meshes/bookshelf_books_%s.res" % size
		var e2 := ResourceSaver.save(mesh, path)
		print("  %-5s -> %s  err=%d  surfaces=%d  books=%d" % [size, path, e2,
			mesh.get_surface_count(), books.size()])
	return true
