extends SceneTree
## Walks the circus level's own path and checks a player still fits on it.
##
## The forest is GENERATED against that path, so a change to either can close
## the route without anybody noticing -- the trees are placed by a clearance
## rule, and a rule is exactly the kind of thing that is right everywhere
## except one corner.
var _n := 0
var _lvl: Node

## Read from the scene, not copied into it.
##
## This used to be a hand-maintained duplicate of the waypoints in
## tools/circus.awk -- which is the kind of duplication that is correct right
## up until somebody moves a waypoint and only one of the two copies follows.
## The generator emits them as Route/P00.. markers now and this reads those, so
## the probe is checking the path the level was actually built around.
var PATH: Array[Vector2] = []


func _read_path(lvl: Node) -> void:
	var route := lvl.get_node_or_null("Route")
	if route == null:
		push_error("probe_circus: no Route/ in the level -- re-run gen_circus.sh.")
		return
	var marks := route.get_children()
	# String(), NOT the bare StringName. Comparing two StringNames with < does
	# not sort them alphabetically in Godot -- it compares their internal
	# pointers, which is fast, arbitrary, and gave a route 130 m longer than the
	# real one because the waypoints came back shuffled.
	marks.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	for m: Node3D in marks:
		PATH.append(Vector2(m.position.x, m.position.z))

func _initialize() -> void:
	# LEVEL=res://x.tscn to walk a different one. There is only the circus level
	# now -- the fairground was cut and the walk runs to the big top instead --
	# but any level that emits a Route/ the same way can be checked with this.
	var which := OS.get_environment("LEVEL")
	if which.is_empty():
		which = "res://circus_level.tscn"
	_lvl = (load(which) as PackedScene).instantiate()
	print("CIRCUS ....  walking %s" % which)
	root.add_child(_lvl)

func _process(_d: float) -> bool:
	_n += 1
	if _n < 8:
		return false
	_open_the_puzzles()
	_read_path(_lvl)
	if PATH.size() < 2:
		print("CIRCUS FAIL  the level has a route to walk")
		return true
	print("CIRCUS ....  %d waypoints, %.0f m of walking" % [PATH.size(), _length()])
	var space: PhysicsDirectSpaceState3D = _lvl.get_world_3d().direct_space_state

	# A knee-up capsule, the same shape probe_walk.gd settled on: the lower
	# hemisphere of a full one catches on every kerb and reports a blockage
	# that a player walks over without noticing.
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	# The player stands on the spawn, and its own capsule is not an obstacle to
	# itself. Without this the first waypoint always reports blocked.
	var me := _lvl.get_node_or_null("Player") as CollisionObject3D
	if me != null:
		q.exclude = [me.get_rid()]

	var blocked := 0
	var checked := 0
	var worst := ""
	for i in PATH.size() - 1:
		var a: Vector2 = PATH[i]
		var b: Vector2 = PATH[i + 1]
		var steps := maxi(int(a.distance_to(b) / 1.5), 1)
		for s in steps + 1:
			var p: Vector2 = a.lerp(b, float(s) / steps)
			checked += 1
			q.transform = Transform3D(Basis(), Vector3(p.x, 1.15, p.y))
			var hits := space.intersect_shape(q, 4)
			if not hits.is_empty():
				blocked += 1
				var who := ""
				for h: Dictionary in hits:
					var n: Node = h["collider"]
					who += " " + String(n.get_parent().name) + "/" + String(n.name)
				print("   blocked at (%.0f, %.0f) by%s" % [p.x, p.y, who])
				if worst == "":
					worst = "%.0f, %.0f" % [p.x, p.y]
	print("CIRCUS %s  the path is walkable end to end (%d of %d points clear)"
		% ["PASS" if blocked == 0 else "FAIL", checked - blocked, checked])
	if blocked > 0:
		print("   first blockage near x=%s" % worst)

	# The ground has to be under every one of them, or the route is a bridge
	# over nothing.
	var holes := 0
	for i in PATH.size():
		var p: Vector2 = PATH[i]
		var from := Vector3(p.x, 6.0, p.y)
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -12, 0)))
		if hit.is_empty():
			holes += 1
	print("CIRCUS %s  every waypoint has ground under it" % ["PASS" if holes == 0 else "FAIL"])

	# The tent is scenery in both levels, not a room. What matters is that it is
	# VISIBLE from the walk, because it is the only thing telling the player
	# which way to go.
	#
	# Aimed at the TOP of it, from a waypoint a third of the way along, and both
	# of those matter. The coordinates used to be hard-coded for the circus
	# level, which quietly made this meaningless in the fairground; and once the
	# fairground was fenced with 5.5 m hoarding, a ray at the BASE of the tent
	# hit a fence and reported the landmark missing -- when what the player
	# actually steers by is the roof standing over the top of everything.
	#
	# The AABB rather than the node position: these are baked meshes, whose
	# vertices are in world coordinates and whose node sits at the origin.
	var hit_tent := true
	var tent_node := _lvl.get_node_or_null("Tent") as MeshInstance3D
	if tent_node != null and PATH.size() > 3:
		var box := tent_node.get_aabb()
		var peak := box.position + Vector3(box.size.x * 0.5, box.size.y * 0.85, box.size.z * 0.5)
		# From ANY waypoint in the back half of the walk, not from one chosen
		# point. Both levels deliberately hide the tent early -- the circus
		# opens in dense forest with no sight lines at all, and being unable to
		# see it there is the design, not a fault. What has to be true is that
		# somewhere on the way in it comes into view and stays the thing the
		# player steers by.
		hit_tent = false
		for w in range(PATH.size() / 2, PATH.size()):
			# PATH is a plan, so it is Vector2 -- x and z, no height.
			var at: Vector2 = PATH[w]
			var eye := Vector3(at.x, 1.6, at.y)
			var seen := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, peak))
			if seen.is_empty() or String(seen["collider"].get_parent().name).contains("Tent"):
				hit_tent = true
				break
	print("CIRCUS %s  the tent can be seen from the walk" % ["PASS" if hit_tent else "FAIL"])

	var player := _lvl.get_node_or_null("Player")
	print("CIRCUS %s  the level has a player" % ["PASS" if player != null else "FAIL"])
	return true


func _length() -> float:
	var d := 0.0
	for i in PATH.size() - 1:
		d += PATH[i].distance_to(PATH[i + 1])
	return d


## Solves the level before walking it.
##
## The question this probe asks is "can the player get from one end to the
## other", and the honest version of that question is "once they have done what
## the level asks". The fairground turnstile is a wall until it is paid, and a
## probe that walked into it would report a blockage every run and train
## everyone to ignore the output -- which is the failure mode that makes a
## check worse than no check at all.
##
## It is still worth walking WITH them open rather than skipping the section,
## because what this actually catches is geometry: a gate leaf that slides into
## a pier, a barrier that lifts halfway, a lever bank standing in the road.
func _open_the_puzzles() -> void:
	var opened := 0
	for node in _lvl.get_children():
		opened += _open_one(node)
	if opened > 0:
		print("CIRCUS ....  opened %d gate(s) first -- see _open_the_puzzles" % opened)


func _open_one(node: Node) -> int:
	var n := 0
	if node.has_method("open") and node.get("is_open") != null:
		node.open(null, true)
		n += 1
	# A door that falls rather than opening. Put flat directly rather than
	# through drop(), because drop() is a tween and the probe reaches the
	# doorway long before a 0.85 second fall has got anywhere.
	if node is FallDoor:
		var door := node as FallDoor
		door.is_down = true
		door._set_collision(false)
		var pivot := door.get_node_or_null("Pivot") as Node3D
		if pivot != null:
			pivot.rotation.x = deg_to_rad(door.fall_angle)
		n += 1
	for child in node.get_children():
		n += _open_one(child)
	return n
