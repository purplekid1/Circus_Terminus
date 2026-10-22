class_name LeverLock
extends Node3D
## A bank of levers that has exactly one right answer, and the lights that come
## on when you find it.
##
## THE ANSWER IS NOT IN THE GAME ANYWHERE THE NAKED EYE CAN READ IT. It is
## stamped on a maker plate bolted to the ride, in print too fine to make out
## without the lens -- an ordinary Clue node with requires_lens on. That is the
## whole design of this puzzle: the player has had the glass since the house
## and has been using it to spot things in the dark. Here it has to be used to
## READ, which is the other half of what it was always for and the half nobody
## bothers with until something makes them.
##
## Four levers is 16 states, so guessing is possible and slow. That is the
## intended shape. A player who refuses to go and look can brute-force it in a
## couple of minutes and will feel every second; a player who finds the plate
## walks up and sets it. Neither is a dead end, which matters more than making
## the shortcut compulsory.
##
## WHY THE LIGHTS. Restoring power is the payoff that makes the midway worth
## having built: the place comes on around you, and the walk back out during
## the chase happens somewhere you have already seen lit. A gate that merely
## opened would be a smaller version of the ticket gate.

signal solved

## The levers, in the order the pattern reads.
@export var levers: Array[NodePath] = []
## One character per lever: "1" is thrown, "0" is not. Must match the plate.
@export var pattern := "1001"

@export_group("Payoff")
## Lights to bring up. Anything with a light_energy: omni, spot, directional.
@export var lamps: Array[NodePath] = []
@export var lamp_energy := 5.0
@export var lamp_time := 2.6
## Meshes that wear `dead_material` until the power comes on.
##
## The festoon bulbs are emissive GEOMETRY, not lights -- a run of them is one
## baked mesh, which is the only way to have four hundred bulbs at all. So
## without this they glow cheerfully over a midway with no power, which reads
## as a bug rather than as atmosphere. The override is dropped on solve, so the
## bulbs come back in the same moment the lamps do.
@export var dimmed: Array[NodePath] = []
@export var dead_material: Material
## Optional: something that moves out of the way as well. Slides, for the same
## reason TokenGate does -- baked meshes do not have their origin at a hinge.
@export var barrier: NodePath
@export var slide := Vector3(0.0, 6.4, 0.0)
@export var slide_time := 3.0

@export_group("What it says")
@export var solved_lines: Array[String] = [
	"Every bulb on the midway, all at once.",
	"Something under the ground started turning.",
]

var is_solved := false

var _levers: Array[Lever] = []
## One writer per lamp, and one for the barrier. Throwing the last lever twice
## in quick succession would otherwise start a second set of tweens on top of
## the first and land the lights at the wrong brightness.
var _tween: Tween
var _player: Node = null


func _ready() -> void:
	for path in levers:
		var node := get_node_or_null(path) as Lever
		if node == null:
			push_warning("LeverLock: '%s' is not a Lever; the bank is short one " % path
				+ "and the pattern can never be matched.")
			continue
		_levers.append(node)
		node.toggled.connect(_on_thrown)

	# Off until earned. Set here rather than in the scene so the level file
	# cannot disagree with the script about what "before" looks like.
	for path in lamps:
		var lamp := get_node_or_null(path) as Light3D
		if lamp != null:
			lamp.light_energy = 0.0
	for path in dimmed:
		var mesh := get_node_or_null(path) as GeometryInstance3D
		if mesh != null and dead_material != null:
			mesh.material_override = dead_material


func _on_thrown(_is_on: bool) -> void:
	if is_solved:
		return
	if _sound() != null:
		_sound().play_at("lever", self, -6.0, 30.0)
	if reads() == pattern:
		_solve()


## The bank as a string, in lever order. Public because the tests read it and
## because it is the one piece of state worth being able to print.
func reads() -> String:
	var s := ""
	for lever: Lever in _levers:
		s += "1" if lever.is_on else "0"
	return s


func _solve() -> void:
	if is_solved:
		return
	is_solved = true
	solved.emit()

	if _sound() != null:
		_sound().play_at("gate_open", self, -2.0, 60.0)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)

	for path in lamps:
		var lamp := get_node_or_null(path) as Light3D
		if lamp != null:
			# Not all at once and not all at the same rate: a midway coming
			# back on is a run of contactors closing, not a switch.
			_tween.tween_property(lamp, "light_energy", lamp_energy, lamp_time) \
				.set_delay(randf() * 0.9)

	# Not tweened: a material swap has nothing to interpolate. The bulbs snap
	# on, which is what a contactor closing actually looks like, and the lamps
	# swelling up underneath them carries the moment.
	for path in dimmed:
		var mesh := get_node_or_null(path) as GeometryInstance3D
		if mesh != null:
			mesh.material_override = null

	var gate := get_node_or_null(barrier) as Node3D
	if gate != null:
		_tween.tween_property(gate, "position", gate.position + slide, slide_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var who := _find_player()
	if who != null and who.has_method("say"):
		for line: String in solved_lines:
			who.say(line)


func _find_player() -> Node:
	if is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player")
	return _player


## See the note in Scripts/Stalker.gd about why this is not the bare name.
func _sound() -> Node:
	return get_node_or_null("/root/Sound")
