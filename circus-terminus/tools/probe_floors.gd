extends SceneTree
## Every solid surface under a handful of points, top to bottom, so the audio
## zones can be split on real floor slabs rather than guessed heights.
var _n := 0

func _initialize() -> void:
	root.add_child((load("res://demo_level.tscn") as PackedScene).instantiate())

func _process(_d: float) -> bool:
	_n += 1
	if _n < 6:
		return false
	var space := root.world_3d.direct_space_state
	var spots := {
		"lawn north": Vector2(0, -80),
		"drive": Vector2(12, -20),
		"hall": Vector2(0, -60),
		"east room": Vector2(12, -68),
		"west room": Vector2(-12, -56),
		"south room": Vector2(0, -45),
		"storm pit": Vector2(-10, -79),
	}
	for label: String in spots:
		var xz: Vector2 = spots[label]
		var y := 20.0
		var stack := ""
		var skip := []
		for _i in 12:
			var from := Vector3(xz.x, y, xz.y)
			var q := PhysicsRayQueryParameters3D.create(from, Vector3(xz.x, -12.0, xz.y))
			q.exclude = skip
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			stack += "%.2f " % hit["position"].y
			y = hit["position"].y - 0.02
			if y < -11.0:
				break
		print("%-11s  %s" % [label, stack])
	return true
