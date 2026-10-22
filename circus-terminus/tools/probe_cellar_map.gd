extends SceneTree
## Prints a plan of the cellar at chest height: what is solid, what is open,
## and where the door, the stairs and the generator are.
##
## Door LEAVES are removed before the scan. A closed door reads as a wall, so
## with them in place you cannot tell an opening from masonry, which is exactly
## the question this is for.
##
##     DOORS=1   keep the door leaves in place instead
var _n := 0
var _lvl: Node

const X0 := -18.0
const X1 := 16.0
const Z0 := -43.0
const Z1 := -10.0
const STEP := 0.5


func _initialize() -> void:
	_lvl = (load("res://demo_level.tscn") as PackedScene).instantiate()
	root.add_child(_lvl)


func _process(_d: float) -> bool:
	_n += 1
	if _n < 6:
		return false
	var m := _lvl.get_node("Mansion") as Node3D
	var o := m.global_position

	if OS.get_environment("DOORS") != "1":
		for n: String in ["CellarDoor", "CellarGate", "StormDoor"]:
			var d := m.get_node_or_null(n)
			if d != null:
				d.free()

	var marks := {}
	for n: String in ["CellarDoor", "Generator"]:
		var node := m.get_node_or_null(n) as Node3D
		if node != null:
			marks[_cell(node.position.x, node.position.z)] = "D" if n == "CellarDoor" else "G"
	# The stairwell down from the house, from gen_shell.sh's CutCellarWell.
	marks[_cell(12.0, -30.0)] = "S"

	var space: PhysicsDirectSpaceState3D = _lvl.get_world_3d().direct_space_state
	var y := o.y - 2.0

	print("cellar plan at y=%.2f (mansion-local metres). '#' solid, '.' open." % y)
	print("D cellar door   S stairs from the house   G generator")
	var head := "        "
	var x := X0
	while x <= X1:
		head += ("|" if int(round(x)) % 5 == 0 else " ")
		x += STEP
	print(head)

	var z := Z0
	while z <= Z1:
		var line := "z=%6.1f " % z
		x = X0
		while x <= X1:
			var key := _cell(x, z)
			if marks.has(key):
				line += marks[key]
			else:
				line += "." if _open(space, o, x, z, y) else "#"
			x += STEP
		print(line)
		z += 1.0

	var foot := "        "
	x = X0
	while x <= X1:
		foot += ("%d" % absi(int(round(x)) / 5 % 10) if int(round(x)) % 5 == 0 else " ")
		x += STEP
	print(foot + "   (x, tens marked every 5 m)")
	return true


func _cell(x: float, z: float) -> String:
	return "%d,%d" % [roundi(x / STEP), roundi(z)]


## A cell is solid if a short ray CROSSING it hits something, in either
## direction. 
##
## Not a shape query. intersect_shape against the baked trimesh gave a plan
## that was inverted along the mid wall -- solid inside the doorways and open
## through the masonry -- while plain rays across the same walls matched
## gen_shell.sh to the centimetre. Rays are what this house answers honestly.
##
## The ray spans the cell rather than starting at its centre, because a ray
## that begins inside a concave shape does not reliably report a hit.
func _open(space: PhysicsDirectSpaceState3D, o: Vector3, x: float, z: float,
		y: float) -> bool:
	var c := Vector3(o.x + x, y, o.z + z)
	var reach := STEP * 0.7
	for axis: Vector3 in [Vector3(reach, 0, 0), Vector3(0, 0, reach)]:
		if not space.intersect_ray(
				PhysicsRayQueryParameters3D.create(c - axis, c + axis)).is_empty():
			return false
	return true
