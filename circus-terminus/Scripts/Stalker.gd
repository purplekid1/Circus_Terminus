class_name Stalker
extends CharacterBody3D
## The thing in the woods. Patrols a loop, hunts what it notices, and is
## invisible unless you are looking at it through the glass.
##
## THE RULE THE WHOLE LEVEL TEACHES: you cannot see it, so you have to look
## for it, and looking costs you -- the lens narrows and slows you. Everything
## here exists to make "raise the glass, find it, put the glass down, move"
## into a loop the player runs on their own without being told to.
##
## It is in the group "enemy", so VisionTags hangs the red tag overlay on it
## automatically. Its own materials are nearly transparent; see stalker.tscn.
##
## AWARENESS, not a state flag, is the thing the player is actually playing
## against. It fills while you are exposed and drains while you are not, so a
## half-second in the open is survivable and standing still in the open is not.
## States are bookkeeping on top of it.

signal awareness_changed(value: float)
signal state_changed(state: int)
## The player has been touched. The Hunt director handles what that means --
## this node does not know about fades or checkpoints.
signal caught_player(who: Node3D)
## First time this one ever notices anybody, for the teaching line.
signal first_contact

enum State { PATROL, SUSPICIOUS, HUNT, RETURNING }

## Markers to walk, in name order, as a closed loop. Sorted with String(), not
## the bare StringName -- comparing two StringNames with < compares their
## internal pointers, not their text, and silently shuffles the route.
@export var route: NodePath

@export_group("Movement")
@export var patrol_speed := 1.5
## Deliberately UNDER the player's 5.0 sprint. Running buys you distance but
## costs stamina, so the escape is "sprint until you can break line of sight",
## not "hold shift forever". An enemy faster than the player removes the
## decision and just punishes you for being seen.
@export var hunt_speed := 4.6
@export var turn_rate := 3.2
## How long it will dwell at a patrol marker, sweeping its head.
@export var dwell := 2.2

@export_group("Senses")
@export var sight_range := 26.0
## Half-angle. 55 means a 110-degree cone, which is wide enough to be
## frightening and narrow enough that flanking is a real answer.
@export var sight_angle := 55.0
## Sprinting is audible through trees; this ignores the cone and line of sight.
@export var hearing_range := 18.0
@export var catch_distance := 1.4
## Seconds of full exposure, at close range, to go from unnoticed to hunted.
@export var notice_time := 1.1
## Seconds of no exposure to drain all the way back down.
@export var forget_time := 3.0

@export_group("Leash")
## It will not follow you out of its own stretch of the woods. Past this from
## the middle of its patrol it breaks off and walks home, which is what makes
## the level a series of territories rather than one long chase.
@export var leash_radius := 55.0

var state: int = State.PATROL
var awareness := 0.0

var _marks: Array[Node3D] = []
var _target := 0
var _home := Vector3.ZERO
var _player: Node3D = null
var _last_seen := Vector3.ZERO
var _dwell_left := 0.0
var _look_yaw := 0.0
var _met_anyone := false
## Time since the body last made real progress, so a stalker wedged against a
## trunk gives up on that marker instead of pushing at it forever.
var _stuck := 0.0
var _was := Vector3.ZERO

@onready var _eye: Node3D = $Eye if has_node("Eye") else self
@onready var _voice: AudioStreamPlayer3D = get_node_or_null("Voice")
## One writer for the breathing. A state change landing during another one
## would otherwise leave two tweens pulling the same pitch in opposite
## directions, which is the same bug the page light had.
var _voice_tween: Tween


func _ready() -> void:
	add_to_group("enemy")
	# The scene file declares the group too, but a stalker built from code is
	# only in it as of this line, which is after VisionTags saw it go in.
	# By node path, not by the autoload name: --script tool runs compile before
	# autoloads register, and a bare VisionTags would fail to resolve there.
	var tags := get_node_or_null("/root/VisionTags")
	if tags != null:
		tags.tag(self)
	_read_route()
	_was = global_position
	_look_yaw = rotation.y


func _read_route() -> void:
	_marks.clear()
	if route.is_empty() or not has_node(route):
		_home = global_position
		return
	var holder := get_node(route)
	var kids := holder.get_children()
	kids.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	var sum := Vector3.ZERO
	for k: Node in kids:
		if k is Node3D:
			_marks.append(k)
			sum += (k as Node3D).global_position
	_home = sum / maxf(float(_marks.size()), 1.0) if not _marks.is_empty() \
		else global_position


## The player, found once and cached. Group lookup rather than a NodePath so a
## respawned or re-instanced player is picked up without re-wiring the scene.
func _find_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var found := get_tree().get_first_node_in_group("player")
	_player = found as Node3D
	return _player


# ---------------------------------------------------------------- the senses

## Where its eyes are. Sight is traced from head height, not from the origin
## between its feet, or it would be looking through the ground.
func eye_position() -> Vector3:
	return _eye.global_position if _eye != self \
		else global_position + Vector3.UP * 2.6


## 0 when the player is invisible to it this instant, 1 when they are as
## exposed as they can be. Everything the player can DO about being seen goes
## through this one function, which is why it returns a number and not a bool.
func exposure_of(who: Node3D) -> float:
	if who == null:
		return 0.0

	# Hiding in a closet or crouched under a desk is absolute. No amount of
	# proximity beats it -- otherwise cover stops being a decision.
	if who.has_method("is_concealed") and who.is_concealed():
		return 0.0

	var to: Vector3 = who.global_position - global_position
	var flat := Vector2(to.x, to.z)
	var range_to := flat.length()
	if range_to > sight_range:
		return 0.0

	var facing := -global_transform.basis.z
	var cone := Vector2(facing.x, facing.z).normalized()
	var toward := flat.normalized() if range_to > 0.001 else cone
	var cos_half: float = cos(deg_to_rad(sight_angle))
	var dot := cone.dot(toward)
	if dot < cos_half:
		return 0.0

	if not _can_see(who):
		return 0.0

	# Near the middle of the cone and close up is worst. Both terms are eased
	# so the edge of detection is a gradient rather than a tripwire.
	var by_range := 1.0 - smoothstep(0.0, sight_range, range_to)
	var by_angle := smoothstep(cos_half, 1.0, dot) * 0.6 + 0.4

	var by_pose := 1.0
	if who.get("crouching"):
		by_pose *= 0.45
	var moving := 0.0
	if who.get("velocity") != null:
		moving = Vector2(who.velocity.x, who.velocity.z).length()
	if who.get("sprinting"):
		by_pose *= 2.0
	elif moving < 0.2:
		# Standing still reads as part of the wood. Not enough to save you in
		# the open, enough to make freezing worth trying.
		by_pose *= 0.6
	# A lit torch in a black forest is the single loudest thing about you.
	if who.get("torch_on"):
		by_pose *= 1.7

	return clampf(by_range * by_angle * by_pose, 0.0, 2.0)


## Sprinting carries. No cone, no line of sight -- this is the reason to walk.
func hears(who: Node3D) -> bool:
	if who == null or not who.get("sprinting"):
		return false
	if who.has_method("is_concealed") and who.is_concealed():
		return false
	return global_position.distance_to(who.global_position) < hearing_range


func _can_see(who: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := eye_position()
	var to: Vector3 = who.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, to)
	# Its own capsule sits between its eye and everything else.
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	# Anything the ray lands on that is not the player is cover.
	var what: Object = hit.get("collider")
	return what == who


# ------------------------------------------------------------------ the mind

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0

	var who := _find_player()
	_sense(delta, who)

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.SUSPICIOUS:
			_do_suspicious(delta)
		State.HUNT:
			_do_hunt(delta, who)
		State.RETURNING:
			_do_returning(delta)

	move_and_slide()

	# Progress check. move_and_slide will happily grind against a trunk at
	# full speed forever, and a stalker stuck on scenery is worse than no
	# stalker at all -- the player learns the woods are safe.
	#
	# Measured as speed actually achieved, not distance moved, so it does not
	# depend on the physics tick length.
	var made := global_position.distance_to(_was) / maxf(delta, 0.0001)
	_was = global_position
	if made < 0.15 and not _dwelling():
		_stuck += delta
	else:
		_stuck = 0.0


## Standing still on purpose is not being stuck.
func _dwelling() -> bool:
	return _dwell_left > 0.0


func _sense(delta: float, who: Node3D) -> void:
	var seen := exposure_of(who) if who != null else 0.0
	var heard := hears(who) if who != null else false

	var before := awareness
	if seen > 0.0:
		awareness += delta * seen / maxf(notice_time, 0.05)
	elif heard:
		# Noise alone never gets you hunted. It gets you looked for, which is
		# how the player learns that running is survivable but not free.
		awareness = maxf(awareness, minf(awareness + delta * 0.5, 0.65))
		_last_seen = who.global_position
	else:
		awareness -= delta / maxf(forget_time, 0.05)
	awareness = clampf(awareness, 0.0, 1.0)

	if seen > 0.0:
		_last_seen = who.global_position

	if not is_equal_approx(before, awareness):
		awareness_changed.emit(awareness)

	if awareness >= 1.0 and state != State.HUNT:
		if not _met_anyone:
			_met_anyone = true
			first_contact.emit()
		_set_state(State.HUNT)
	elif awareness > 0.25 and state == State.PATROL:
		_set_state(State.SUSPICIOUS)
	elif awareness <= 0.0 and state == State.SUSPICIOUS:
		_set_state(State.RETURNING)


func _set_state(to: int) -> void:
	if state == to:
		return
	state = to
	_dwell_left = 0.0
	_stuck = 0.0
	state_changed.emit(to)
	_breathe(to)
	var sound := _sound()
	if sound == null:
		return
	match to:
		State.HUNT:
			sound.play_at("stalker_notice", self, -4.0, 60.0)
		State.RETURNING:
			sound.play_at("stalker_lose", self, -10.0, 45.0)


## Its breathing is the only readout the player gets on a thing they cannot
## see, so it has to change with what it is doing: quiet and level on patrol,
## quicker when it is looking, loud and high when it is coming. Tweened rather
## than set, so the change itself is a sound the player can react to.
func _breathe(to: int) -> void:
	if _voice == null or not is_inside_tree():
		return
	var db := -9.0
	var pitch := 1.0
	match to:
		State.SUSPICIOUS:
			db = -6.0
			pitch = 1.07
		State.HUNT:
			db = -2.5
			pitch = 1.20
	if _voice_tween != null and _voice_tween.is_valid():
		_voice_tween.kill()
	_voice_tween = create_tween().set_parallel(true)
	_voice_tween.tween_property(_voice, "volume_db", db, 0.35)
	_voice_tween.tween_property(_voice, "pitch_scale", pitch, 0.35)


# ---------------------------------------------------------------- the states

func _do_patrol(delta: float) -> void:
	if _marks.is_empty():
		_face(_look_yaw, delta)
		_drive(Vector3.ZERO, 0.0, delta)
		return

	if _dwell_left > 0.0:
		_dwell_left -= delta
		# Sweeping its head while it waits is what makes a patrol feel like
		# something looking rather than something commuting.
		_look_yaw += delta * 0.9
		_face(_look_yaw, delta)
		_drive(Vector3.ZERO, 0.0, delta)
		return

	var mark := _marks[_target].global_position
	if _flat_distance(mark) < 1.2 or _stuck > 2.5:
		_target = (_target + 1) % _marks.size()
		_dwell_left = dwell
		_stuck = 0.0
		_look_yaw = rotation.y
		return

	_step_toward(mark, patrol_speed, delta)


func _do_suspicious(delta: float) -> void:
	# Walks to where it thinks you were, a little faster than its patrol.
	if _flat_distance(_last_seen) < 1.5 or _stuck > 2.0:
		_look_yaw += delta * 1.6
		_face(_look_yaw, delta)
		_drive(Vector3.ZERO, 0.0, delta)
		return
	_step_toward(_last_seen, patrol_speed * 1.6, delta)


func _do_hunt(delta: float, who: Node3D) -> void:
	if who == null:
		_set_state(State.RETURNING)
		return

	# Territory. It will not leave its own woods, however close you are.
	if _home.distance_to(global_position) > leash_radius:
		awareness = 0.0
		_set_state(State.RETURNING)
		return

	var reach := global_position.distance_to(who.global_position)
	if reach <= catch_distance:
		caught_player.emit(who)
		awareness = 0.0
		_set_state(State.RETURNING)
		return

	# Chases what it can see; chases the memory of you when it cannot. Losing
	# sight does not stop it, it only stops it updating -- which is what makes
	# breaking line of sight AND changing direction the actual escape.
	var goal: Vector3 = who.global_position if exposure_of(who) > 0.0 else _last_seen
	if _flat_distance(goal) < 1.0 and exposure_of(who) <= 0.0:
		_set_state(State.SUSPICIOUS)
		return
	_step_toward(goal, hunt_speed, delta)


func _do_returning(delta: float) -> void:
	if _marks.is_empty():
		_set_state(State.PATROL)
		return
	var mark := _marks[_target].global_position
	if _flat_distance(mark) < 1.5 or _stuck > 3.0:
		_set_state(State.PATROL)
		return
	_step_toward(mark, patrol_speed * 1.3, delta)


# --------------------------------------------------------------- the walking

func _flat_distance(to: Vector3) -> float:
	return Vector2(to.x - global_position.x, to.z - global_position.z).length()


func _step_toward(goal: Vector3, speed: float, delta: float) -> void:
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 0.001:
		_drive(Vector3.ZERO, 0.0, delta)
		return
	var dir := to.normalized()
	_face(atan2(-dir.x, -dir.z), delta)
	_drive(dir, speed, delta)


## Turns toward `yaw` at turn_rate rather than snapping, so its sight cone
## sweeps across the player instead of teleporting onto them.
func _face(yaw: float, delta: float) -> void:
	rotation.y = rotate_toward(rotation.y, yaw, turn_rate * delta)


func _drive(dir: Vector3, speed: float, delta: float) -> void:
	var want := dir * speed
	# Eased rather than set, so it leans into a turn instead of sliding.
	velocity.x = move_toward(velocity.x, want.x, speed * 4.0 * delta + 0.1)
	velocity.z = move_toward(velocity.z, want.z, speed * 4.0 * delta + 0.1)


## Back to its patrol with a clean slate, and standing where it belongs rather
## than where it killed you. The Hunt director calls this on respawn: waking up
## already hunted by the thing that just caught you is not a second chance.
func reset() -> void:
	awareness = 0.0
	velocity = Vector3.ZERO
	_stuck = 0.0
	_dwell_left = 0.0
	if not _marks.is_empty():
		global_position = _marks[_target].global_position
	_set_state(State.PATROL)
	awareness_changed.emit(0.0)


## The Sound autoload, by node path rather than by its bare name.
##
## Most of the game just writes `Sound.play_at(...)`, and gets away with it
## because those scripts are not compiled until a scene instantiates them, by
## which time the autoload exists. This file is different: it has a class_name,
## so the test tools name it as a type, which compiles it during a --script run
## -- and in that mode autoloads are not registered yet, so the bare identifier
## is a compile error that takes the whole test suite down with it.
func _sound() -> Node:
	return get_node_or_null("/root/Sound")
