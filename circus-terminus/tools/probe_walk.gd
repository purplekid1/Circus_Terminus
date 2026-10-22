extends SceneTree
## Walkability probe. Rays down on a grid, keeps every surface it finds in each
## column, joins the ones the player could actually step between, and floods
## from the spawn.
##
## IT IS MULTI-LAYER, and that is the whole point. The first version kept only
## the topmost hit per column, which meant it never saw the cellar at all: a
## ray from above stops on the ground-floor slab. It therefore reported the
## house as fully reachable while `Surroundings/Ground` -- a 620 m plate at
## y -0.22, three metres above the cellar floor and a third of a metre below
## the ground storey -- was lying straight across the flight of stairs out of
## the cellar, with the result that the player could not get into the house at
## all. A probe that cannot see under a floor cannot check a building.
##
##   godot --headless --path . --script tools/probe_walk.gd

## Grid pitch. It has to be finer than the shallowest thing the player can
## climb: at 0.5 m a three-riser stoop rises 0.17 per cell, which is
## indistinguishable from a wall, and the probe called the front door
## unreachable the moment the steps went in.
const STEP := 0.2

## Steepest surface the player can walk up, as a rise per STEP. 0.18 over 0.2
## is 42 degrees, just under move_and_slide's default floor limit. A STEP is
## never a step-up: CharacterBody3D has none, so anything vertical is a wall
## and only the slope between samples can be climbed.
const RISE := 0.18
const DROP := 2.5

## Clear space a surface needs above it before the player can stand on it.
## The capsule is 1.75; the margin is for the head bob and the crouch lerp.
const HEADROOM := 1.85

## Vertical band searched, and the most surfaces kept in one column. Six covers
## cellar floor, ground storey, landing, first floor, roof.
const TOP := 8.0
const BOTTOM := -6.0
const MAX_LAYERS := 6

## Frames to let the scene settle. The doors are opened at OPEN_AT and the
## probe runs at zero, so several physics steps separate the two.
const SETTLE := 24
const OPEN_AT := 12

var _root: Node = null
var _wait := SETTLE

## The player capsule is standing on the spawn, so a ray cast from above lands
## on IT rather than on the pavement and the probe decides the spawn has no
## floor. Every query excludes it.
var _exclude: Array[RID] = []

## The player's own girth, read off player.tscn rather than typed here, and
## reused for every clearance test.
##
## It is only the UPPER BODY -- from KNEE up to the top of the head. The full
## capsule, with its lower hemisphere down at ankle height, called every cell
## within a radius of a KERB unstandable, because a body resting on the grass
## really does overlap the 29 cm step beside it. That turned every kerb in the
## level into a wall and left the player marooned on the footpath. Vertical
## movement is the RISE test's job; this shape is here for one thing, which is
## gaps too narrow to walk through -- door leaves, fence rails, the bars of a
## gate.
const KNEE := 0.35
var _probe_shape := PhysicsShapeQueryParameters3D.new()
var _probe_lift := 1.0

## Places the demo needs the player to be able to reach, with the height of the
## floor they are on -- a point alone is ambiguous now that the probe knows
## about more than one storey.
const PLACES := {
	"the road, at the gate": Vector3(0, 0.34, 0.0),
	"the front door": Vector3(0, 0.35, -37.0),
	"the east deck, front": Vector3(19, 0.35, -45.0),
	"the east deck, middle": Vector3(19, 0.35, -58.0),
	"the east deck, back": Vector3(19, 0.35, -72.0),
	"the back deck": Vector3(4, 0.35, -77.5),
	"the lawn behind the pit": Vector3(-10, 0.05, -85.0),
	"the bottom of the storm steps": Vector3(-10, -3.25, -76.5),
	"the cellar, by the generator": Vector3(9, -3.25, -59.5),
	"the cellar, by the coal": Vector3(13, -3.25, -68.0),
	"halfway up the cellar stairs": Vector3(12, -2.67, -73.5),
	"the head of the cellar stairs": Vector3(12, 0.35, -67.95),
	"the entrance hall": Vector3(0, 0.35, -45.0),
	"the kitchen": Vector3(-10, 0.35, -60.0),
}


func _initialize() -> void:
	var ps: PackedScene = load("res://demo_level.tscn")
	_root = ps.instantiate()
	root.add_child(_root)


func _process(_d: float) -> bool:
	# Opening happens SEVERAL FRAMES BEFORE the probe runs. Moving a
	# Node3D only queues the new transform; it does not reach the physics
	# server until a physics step has been taken, so opening a gate and
	# raycasting in the same call measures the gate in its old position --
	# which is why opening the cellar gate changed the flood by exactly
	# nothing, twice.
	if _wait == OPEN_AT:
		_open_doors()
	if _wait > 0:
		_wait -= 1
		return false

	var player := _root.get_node_or_null("Player")
	if player != null:
		_exclude = [(player as CollisionObject3D).get_rid()]

	# Take the capsule from the player scene, so resizing the character in the
	# editor cannot leave this probe testing a body the game no longer has.
	var authored := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	var capsule := CapsuleShape3D.new()
	capsule.radius = authored.radius
	capsule.height = authored.height - KNEE
	_probe_shape.shape = capsule
	_probe_shape.margin = 0.0
	_probe_lift = KNEE + capsule.height * 0.5

	var space := _root.get_viewport().world_3d.direct_space_state
	var x0 := -30.0
	var z0 := -90.0
	var cols := int(60.0 / STEP)
	var rows := int(100.0 / STEP)

	# cell -> sorted Array[float] of standable surface heights.
	var layers := {}
	var surfaces := 0
	for i in cols:
		for j in rows:
			var found := _column(space, x0 + i * STEP, z0 + j * STEP)
			if not found.is_empty():
				layers[Vector2i(i, j)] = found
				surfaces += found.size()

	# Flood from the spawn, over (cell, layer) pairs rather than cells.
	# SEED="the head of the cellar stairs" starts somewhere else instead, which
	# is how you ask "what does the INSIDE of the house connect to" without
	# having to be able to get into it first.
	var from_place := OS.get_environment("SEED")
	var start: Vector3 = PLACES.get(from_place, Vector3(-0.05, 0.34, 0.11))
	var spawn := _nearest(layers, x0, z0, start)
	if spawn.x < 0:
		print("WALK the spawn has no floor under it")
		return true

	# `seen` maps each reached step to the step it was reached FROM, so a route
	# can be read back. Finding out that somewhere is reachable is only half of
	# it; the useful half is by what path, which is how the buried ground plate
	# turned up in the first place.
	var seen := {spawn: spawn}
	var queue := [spawn]
	while not queue.is_empty():
		var here: Vector3i = queue.pop_front()
		var cell := Vector2i(here.x, here.y)
		var y: float = layers[cell][here.z]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + d
			if not layers.has(next):
				continue
			var stack: Array = layers[next]
			for k in stack.size():
				var step: Vector3i = Vector3i(next.x, next.y, k)
				if seen.has(step):
					continue
				var dy: float = stack[k] - y
				if dy > RISE or dy < -DROP:
					continue
				seen[step] = here
				queue.append(step)

	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for s in seen:
		var wx: float = x0 + (s as Vector3i).x * STEP
		var wz: float = z0 + (s as Vector3i).y * STEP
		lo = Vector2(minf(lo.x, wx), minf(lo.y, wz))
		hi = Vector2(maxf(hi.x, wx), maxf(hi.y, wz))
	print("WALK %d columns, %d standable surfaces, %d reachable"
		% [layers.size(), surfaces, seen.size()])
	print("WALK reachable region x %.1f..%.1f  z %.1f..%.1f" % [lo.x, hi.x, lo.y, hi.y])

	var bad := 0
	for name in PLACES:
		var target: Vector3 = PLACES[name]
		var step := _nearest(layers, x0, z0, target)
		var mark := "cut off  "
		if step.x < 0:
			mark = "no floor "
			bad += 1
		elif seen.has(step):
			mark = "REACHABLE"
		else:
			bad += 1
		print("WALK   %s  %s" % [mark, name])
	print("WALK %s" % ("PASS -- every named place is reachable" if bad == 0
		else "FAIL -- %d place(s) the player cannot get to" % bad))

	if OS.get_environment("MAP") != "":
		_print_map(layers, seen, x0, z0, cols, rows)

	# TRACE="the entrance hall" prints the route the flood actually took.
	var want := OS.get_environment("TRACE")
	if want != "" and PLACES.has(want):
		_print_route(layers, seen, x0, z0, _nearest(layers, x0, z0, PLACES[want]), want)
	return true


## A plan of the estate, one character per metre, looking down.
##
##   #  somewhere the player can get to
##   .  standable, but walled off from the spawn
##   (blank) nowhere to stand at all
##
## Worth more than any number of named waypoints when something has gone
## wrong: the shape of the reachable blob shows you WHICH side of the house
## the wall is on, and a corridor one character wide is a corridor the player
## will get stuck in.
func _print_map(layers: Dictionary, seen: Dictionary, x0: float, z0: float,
		cols: int, rows: int) -> void:
	var per := int(1.0 / STEP)          # cells per printed character
	var reach := {}
	for s in seen:
		reach[Vector2i((s as Vector3i).x / per, (s as Vector3i).y / per)] = true
	print("WALK map, 1 char = 1 m, x %.0f..%.0f left to right:" % [x0, x0 + cols * STEP])
	for j in range(rows / per - 1, -1, -1):
		var line := ""
		for i in cols / per:
			if reach.has(Vector2i(i, j)):
				line += "#"
			elif layers.has(Vector2i(i * per, j * per)):
				line += "."
			else:
				line += " "
		print("WALK %7.1f |%s|" % [z0 + j * per * STEP, line])


func _print_route(layers: Dictionary, seen: Dictionary, x0: float, z0: float,
		target: Vector3i, name: String) -> void:
	if target.x < 0 or not seen.has(target):
		print("WALK   no route to %s to print" % name)
		return
	var path: Array = []
	var cur := target
	while seen[cur] != cur:
		path.append(cur)
		cur = seen[cur]
	path.append(cur)
	path.reverse()
	print("WALK route to %s -- %d steps, every 10th:" % [name, path.size()])
	for i in range(0, path.size(), 10):
		var p: Vector3i = path[i]
		print("WALK     (%7.2f, %6.2f, %7.2f)"
			% [x0 + p.x * STEP, layers[Vector2i(p.x, p.y)][p.z], z0 + p.y * STEP])


## Every surface in one column that the player could stand on, bottom to top.
## Keeps going past each hit rather than stopping at the first, which is the
## difference between seeing a house and seeing its roof.
##
## Standing room is decided by the gap to the NEXT SURFACE UP in this same
## column, not by a second ray fired upwards. The ray version has to start
## slightly clear of the surface it just found or it re-hits it, and that skip
## walks straight over anything thinner than the skip: the level's Lawn is
## 10 cm thick and sits interpenetrating the surroundings' ground plate, so a
## ray launched 12 cm above the plate began ABOVE the lawn, found nothing, and
## the probe happily flooded a hundred metres along a slab that is buried under
## the grass. Comparing layers costs nothing and cannot be fooled that way.
func _column(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Array:
	var found: Array = []
	var y := TOP
	for _n in MAX_LAYERS:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, y, z), Vector3(x, BOTTOM, z))
		q.exclude = _exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var surface: float = hit["position"].y
		found.append(surface)
		# Step down past it. 5 cm, because two faces of one thin slab are
		# closer together than that and we want the underside skipped.
		y = surface - 0.05
		if y <= BOTTOM:
			break

	# found is top-down. Keep a surface when there is room to stand on it: the
	# topmost always qualifies on the vertical test, the rest need HEADROOM
	# before the one above. Then confirm with the CAPSULE, because a point has
	# no width and the player does.
	var out: Array = []
	for k in found.size():
		if k > 0 and found[k - 1] - found[k] < HEADROOM:
			continue
		if _capsule_fits(space, x, found[k], z):
			out.append(found[k])
	out.reverse()          # bottom-up, so the index is stable
	return out


## Whether the player's actual capsule fits standing on this surface.
##
## THIS IS NOT OPTIONAL. A flood over bare points walks through anything wider
## than nothing: it strolled through the BOLTED FRONT DOOR, because the leaf is
## 1.30 m in a 1.75 m opening and the 0.45 m either side of it is a hole as far
## as a dimensionless point is concerned. The player is 0.59 m across and has
## never been able to get through there. Every gap in the house is like that --
## door leaves, balusters, the bars of the cellar gate -- so a probe without a
## body in it says the level is wide open when it is not.
func _capsule_fits(space: PhysicsDirectSpaceState3D, x: float, y: float, z: float) -> bool:
	_probe_shape.transform = Transform3D(Basis(), Vector3(x, y + _probe_lift, z))
	_probe_shape.exclude = _exclude
	return space.intersect_shape(_probe_shape, 1).is_empty()


## The (cell, layer) nearest a world point. Returns (-1, -1, -1) when there is
## no standable surface within half a metre of the height asked for.
func _nearest(layers: Dictionary, x0: float, z0: float, at: Vector3) -> Vector3i:
	var cell := Vector2i(int(round((at.x - x0) / STEP)), int(round((at.z - z0) / STEP)))
	if not layers.has(cell):
		return Vector3i(-1, -1, -1)
	var stack: Array = layers[cell]
	var best := -1
	var best_gap := 0.6
	for k in stack.size():
		var gap: float = absf(stack[k] - at.y)
		if gap < best_gap:
			best_gap = gap
			best = k
	return Vector3i(cell.x, cell.y, best) if best >= 0 else Vector3i(-1, -1, -1)


## The things the player legitimately opens. This probe is about GEOMETRY, not
## puzzle state -- a bolted front door is a design decision and should not read
## as a level that cannot be finished. The doors left shut (front, back, study)
## are the ones that are meant to be.
func _open_doors() -> void:
	_open("Gate")
	_open("Gate2")
	_open("Mansion/StormDoor")
	# SHUT_GATE=1 leaves the cellar gate locked, which is how the level starts.
	# Everything past it should then be unreachable -- that is the check that
	# the gate really is the only way up out of the cellar, rather than a
	# decoration with a hole in the wall beside it.
	if OS.get_environment("SHUT_GATE") == "":
		_open("Mansion/CellarGate")


func _open(path: String) -> void:
	var node := _root.get_node_or_null(path)
	if node == null:
		return
	if node.has_method("set_open"):
		# StormDoors has no lock at all; only Door does.
		if "locked" in node:
			node.locked = false
		node.set_open(true)
		# The tween that swings it runs on the physics step, and this probe
		# never takes one, so put the hinge where it will end up.
		for child in node.get_children():
			if not child.name.begins_with("Hinge"):
				continue
			var angle: float = deg_to_rad(node.open_angle)
			child.rotation.y = -angle if child.name == "HingeWest" else angle
			# AND PUSH IT TO THE PHYSICS SERVER. Rotating a Node3D only moves
			# the render transform until the next physics frame; without this
			# the leaf was still shut as far as every raycast was concerned,
			# and opening the gate changed the flood by exactly nothing.
			for body in _bodies(child):
				body.force_update_transform()


func _bodies(node: Node) -> Array:
	var out: Array = []
	if node is CollisionObject3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_bodies(child))
	return out
