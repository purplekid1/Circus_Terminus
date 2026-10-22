extends SceneTree
## Pulls the pine's ArrayMesh out of the FBX import and saves it as
## Meshes/pine.res, so a MultiMesh can point at it.
##
## A MultiMesh needs a Mesh RESOURCE. The mesh inside Models/pine/Pine_4m.fbx
## lives in the imported .scn and has no path of its own, so there is nothing
## for a .tscn to reference. This copies it out once. Re-run it if the model is
## ever re-exported.
var _n := 0
var _r: Node3D
func _initialize() -> void:
	_r = (load("res://Models/pine/Pine_4m.fbx") as PackedScene).instantiate()
	get_root().add_child(_r)
func _process(_d: float) -> bool:
	_n += 1
	if _n < 6:
		return false
	var mi := _r.find_child("pine4m", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		push_error("no pine4m mesh")
		return true
	var src := mi.mesh
	# Re-emit as a plain ArrayMesh so the saved resource carries no import
	# baggage, and strip the material: the MultiMeshInstance3D wears
	# Mat_foliage as a material_override instead, so the whole forest is one
	# material and one draw call.
	# TRIM THE BARE TRUNK SPIRE. The model has ~0.5 m of naked pole standing
	# above its topmost fronds. On one 4 m tree that is a detail; the circus
	# forest asks for 1436 of them at 11-16 m, where the stub becomes a 1.5 m
	# spike and reads in silhouette as a flat slab floating over every tree.
	#
	# Done HERE, on the extracted copy, and not in the .fbx: the model is the
	# author's and gets overwritten on every re-export. Delete this block and
	# re-run to get the spire back.
	#
	# The crown is found by ignoring anything within TRUNK_R of the axis, which
	# is the trunk itself, and taking the highest frond that is left. Triangles
	# with ALL THREE vertices above that line are dropped; a triangle straddling
	# it is kept, so the cut cannot open a hole in the foliage.
	const TRUNK_R := 0.35
	var crown := -INF
	for s0 in src.get_surface_count():
		for v: Vector3 in (src.surface_get_arrays(s0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if Vector2(v.x, v.z).length() > TRUNK_R:
				crown = maxf(crown, v.y)

	var out := ArrayMesh.new()
	var dropped := 0
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var vs := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var ix := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ns := arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var uv := arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		for i in range(0, ix.size(), 3):
			var a := ix[i]
			var b := ix[i + 1]
			var c := ix[i + 2]
			if vs[a].y > crown and vs[b].y > crown and vs[c].y > crown:
				dropped += 1
				continue
			for j in [a, b, c]:
				if ns.size() > j:
					st.set_normal(ns[j])
				if uv.size() > j:
					st.set_uv(uv[j])
				st.add_vertex(vs[j])
		st.index()
		st.generate_normals() if ns.is_empty() else st.deindex()
		st.index()
		st.commit(out)
	print("crown top at y %.3f, dropped %d triangles of trunk spire" % [crown, dropped])
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v: Vector3 in (out.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		lo = lo.min(v); hi = hi.max(v)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Meshes"))
	var err := ResourceSaver.save(out, "res://Meshes/pine.res")
	print("saved Meshes/pine.res  err=%d  surfaces=%d  verts=%d" % [
		err, out.get_surface_count(),
		(out.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	print("  bounds  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f  (height %.3f, base %.3f)"
		% [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, hi.y - lo.y, lo.y])
	return true
