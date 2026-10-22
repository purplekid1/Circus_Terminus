extends SceneTree
## Measures where the house and the cellar actually are, so the audio zone
## volumes can be authored from the geometry rather than from guesses.

var _ran := false

func _initialize() -> void:
	var level := (load("res://demo_level.tscn") as PackedScene).instantiate()
	root.add_child(level)


func _process(_delta: float) -> bool:
	var level := root.get_child(root.get_child_count() - 1)
	var m := level.get_node("Mansion")
	print("Mansion at %v" % m.position)
	var whole := _aabb(m, null)
	print("whole mansion  %v .. %v" % [whole.position, whole.end])
	for name: String in ["Cellar", "CellarPit", "Shell", "Basement", "Ground"]:
		var n := _find(m, name)
		if n == null:
			continue
		var b := _aabb(n, null)
		print("%-12s %v .. %v" % [name, b.position, b.end])
	# Top-level children, to see how the house is divided up.
	var names := []
	for c in m.get_children():
		names.append(c.name)
	print("mansion children: %s" % ", ".join(names))
	return true


func _find(from: Node, want: String) -> Node:
	if from.name == want:
		return from
	for c in from.get_children():
		var r := _find(c, want)
		if r != null:
			return r
	return null


func _aabb(node: Node, acc) -> AABB:
	var out: AABB = acc if acc != null else AABB()
	var first := acc == null
	for c in node.get_children():
		var sub := _aabb(c, out if not first else null)
		if sub.size != Vector3.ZERO or sub.position != Vector3.ZERO:
			out = sub if first else out.merge(sub)
			first = false
	if node is VisualInstance3D:
		var b: AABB = (node as VisualInstance3D).get_aabb()
		var g := (node as Node3D).global_transform
		var w := AABB(g * b.position, Vector3.ZERO)
		for i in 8:
			w = w.expand(g * b.get_endpoint(i))
		out = w if first else out.merge(w)
	return out
