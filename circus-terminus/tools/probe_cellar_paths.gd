extends SceneTree
## Floods the cellar floor and reports what can be reached from just inside the
## cellar door -- with the iron gate shut, and with it open.
##
## Then proves there is only ONE route to the generator, by blocking each
## doorway on that route in turn: if every one of them disconnects the
## generator, the route has no alternative. A second path would keep the
## generator reachable with any single doorway blocked.
var _n := 0
var _lvl: Node

const STEP := 0.25
const X0 := -16.6
const X1 := 16.6
const Z0 := -33.6
const Z1 := -11.0

## Just inside the cellar door, on the cellar floor.
const SEED := Vector2(-10.0, -33.0)

## The places worth asking about, in mansion-local x/z.
const PLACES := {
	"the generator": Vector2(11.0, -18.0),
	"the coal heap": Vector2(15.0, -31.3),
	"the stairs up to the house": Vector2(12.0, -30.0),
	"the west crates": Vector2(-13.0, -25.0),
	"the barrels (the KEY)": Vector2(-15.6, -23.6),
	"the work bench": Vector2(16.4, -13.0),
}

## Every doorway in the cellar, as a box to plug: centre x/z, half-size, and
## whether it is expected to be ON the route to the generator.
##
## The gate is NOT on that route and must not be. It stands between the cellar
## and the stairs up to the house, so blocking it should leave the generator
## reachable -- otherwise the player would need the key before they could turn
## the lights on, and the key is only findable with the lights on.
const DOORWAYS := {
	"the iron gate (0, -31)": [0.0, -30.99, 0.9, 2.4, false],
	"the west cross door (-9, -22)": [-9.0, -22.0, 0.9, 0.9, true],
	"the mid door (0, -14)": [0.0, -14.0, 0.9, 0.9, true],
}

var _space: PhysicsDirectSpaceState3D
var _origin: Vector3
var _y := 0.0
var _block := []
var _stage := 0


func _process(_d: float) -> bool:
	_n += 1
	if _n < 6:
		return false
	var m := _lvl.get_node("Mansion") as Node3D
	_origin = m.global_position
	_space = _lvl.get_world_3d().direct_space_state
	_y = _origin.y - 2.0

	if _stage == 0:
		print("Flooding the cellar from just inside the cellar door %v." % SEED)
		print("")
		print("--- with the iron gate SHUT (the player has no key yet) ---")
		var shut := _flood()
		_report(shut)
		_plan(shut)
		# Only the swinging leaf is removed, not the whole assembly: the gate's
		# two fixed side panels are part of the wall now and have to stay.
		var gate := m.get_node_or_null("CellarGate")
		if gate != null and gate.has_node("Hinge"):
			gate.get_node("Hinge").free()
		_stage = 1
		_n = 0
		return false

	if _stage == 1:
		print("")
		print("--- with the gate OPEN ---")
		var seen := _flood()
		_report(seen)
		print("")
		print("--- is there a second route to the generator? ---")
		print("Blocking one doorway at a time. If the generator goes out of")
		print("reach every time, the route through it has no alternative.")
		for label: String in DOORWAYS:
			var d: Array = DOORWAYS[label]
			_block = [d]
			var s := _flood()
			var got: bool = s.has(_key(PLACES["the generator"].x, PLACES["the generator"].y))
			var on_route: bool = d[4]
			# On the route: blocking it MUST disconnect the generator, or there
			# is a second way round. Off the route: it must NOT.
			var ok := got != on_route
			print("   CELLAR %s  block %-30s generator %s" %
				["PASS" if ok else "FAIL", label,
				"still reachable" if got else "unreachable"])
		_block = []
		return true

	return false


func _initialize() -> void:
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	root.add_child(_lvl)


func _report(seen: Dictionary) -> void:
	for label: String in PLACES:
		var p: Vector2 = PLACES[label]
		print("   %-28s %s" % [label, "reachable" if seen.has(_key(p.x, p.y)) else "NOT reachable"])


func _key(x: float, z: float) -> String:
	return "%d,%d" % [roundi(x / STEP), roundi(z / STEP)]


func _flood() -> Dictionary:
	var seen := {}
	var queue := [Vector2(SEED.x, SEED.y)]
	seen[_key(SEED.x, SEED.y)] = true
	while not queue.is_empty():
		var c: Vector2 = queue.pop_back()
		for d: Vector2 in [Vector2(STEP, 0), Vector2(-STEP, 0),
				Vector2(0, STEP), Vector2(0, -STEP)]:
			var n := c + d
			if n.x < X0 or n.x > X1 or n.y < Z0 or n.y > Z1:
				continue
			var k := _key(n.x, n.y)
			if seen.has(k):
				continue
			if not _open(n.x, n.y):
				continue
			seen[k] = true
			queue.append(n)
	return seen


func _open(x: float, z: float) -> bool:
	for b: Array in _block:
		if absf(x - b[0]) <= b[2] and absf(z - b[1]) <= b[3]:
			return false
	var c := Vector3(_origin.x + x, _y, _origin.z + z)
	var reach := STEP * 0.75
	for axis: Vector3 in [Vector3(reach, 0, 0), Vector3(0, 0, reach)]:
		if not _space.intersect_ray(
				PhysicsRayQueryParameters3D.create(c - axis, c + axis)).is_empty():
			return false
	return true


## Prints the flooded set as a plan. '+' is reached, '.' is open but cut off,
## '#' is solid. The fastest way to find where a seal leaks.
func _plan(seen: Dictionary) -> void:
	var z := -33.5
	while z <= -11.0:
		var line := "z=%6.1f " % z
		var x := -16.5
		while x <= 16.5:
			var k := _key(x, z)
			if seen.has(k):
				line += "+"
			else:
				line += "." if _open(x, z) else "#"
			x += 0.5
		print(line)
		z += 1.0
	print("        " + "x = -16.5 .. 16.5 in 0.5 m steps")
