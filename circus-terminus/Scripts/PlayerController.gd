extends CharacterBody3D

@onready var head: Node3D = $CollisionShape3D/Head
@onready var camera: Camera3D = $CollisionShape3D/Head/Camera3D
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var glass: Node3D = $CollisionShape3D/Head/Camera3D/Glass
@onready var glass_mesh: MeshInstance3D = $CollisionShape3D/Head/Camera3D/Glass/MeshInstance3D
@onready var glass_anim: AnimationPlayer = $CollisionShape3D/Head/Camera3D/Glass/MeshInstance3D/AnimationPlayer
@onready var interact_ray: RayCast3D = $CollisionShape3D/Head/Camera3D/InteractRay
@onready var headroom: ShapeCast3D = $Headroom
@onready var inventory: Inventory = $Inventory
@onready var flashlight: SpotLight3D = $CollisionShape3D/Head/Camera3D/Flashlight
@onready var journal: Journal = $Journal

signal interactable_changed(target: Interactable)
signal concealment_changed(is_concealed: bool)
## Transient line of text for the HUD: clue readings, safe hints, pickups.
signal message_requested(text: String, seconds: float)

## A line of controls that STAYS UP for as long as a set piece holds focus,
## rather than a message that times out. Somebody working through ten thousand
## combinations on a safe should not have to remember which key tries one,
## and a six-second prompt is gone long before the second guess.
signal hint_changed(text: String)

## Fires only when the value actually moves, so the HUD is not redrawn sixty
## times a second while the player stands still with a full tank.
signal stamina_changed(value: float, winded: bool)
## Fade the screen to black and optionally hold a closing line on top of it.
signal fade_requested(duration: float, closing_text: String)

## Back from black. Respawning after a stalker catches you is the first thing
## in the game that ever needed this.
signal unfade_requested(duration: float)

## Cutscene overlays: a full-screen flash, and the swirling tunnel. Signals
## rather than direct calls so a set piece never has to find the HUD, which is
## a CanvasLayer hanging off the player and not something a level node should
## be reaching into.
signal flash_requested(colour: Color, rise: float, hold: float, fall: float)
signal tunnel_requested(amount: float, travel: float)
## A line of the character's own dialogue. Queued and shown one at a time.
signal line_spoken(text: String)

## Emitted with the new size in PIXELS whenever `subtitle_size` changes, so
## the HUD that actually owns the label can resize it. Same shape as every
## other line here: the player holds the SETTING, the HUD holds the Control.
signal subtitle_size_changed(pixels: int)

## The shared settings store. Preloaded rather than reached by class_name so
## a stale class cache cannot break it, the same way Journal takes the
## keybinds panel.
const SETTINGS := preload("res://Scripts/Settings.gd")

const WALK_SPEED := 3.4
const SPRINT_SPEED := 5.0
const CROUCH_SPEED := 2.2

## Stamina, measured in seconds rather than points, because seconds are what
## the numbers have to be tuned against and a "100 point bar draining at 12 a
## second" is the same thing written so you cannot read it.
##
## Eight seconds at 5 m/s is forty metres -- the length of the house, or far
## enough to get from the treeline to the porch with nothing to spare. Long
## enough to escape something, short enough that it cannot be the way you
## travel.
const SPRINT_SECONDS := 8.0
## A full refill from empty takes rather longer than emptying it, so running is
## a decision and not a rhythm.
const RECOVER_SECONDS := 13.0
## Standing still recovers this much faster than walking does.
const REST_BONUS := 1.9
## How full the tank has to be before a winded character will run again. See
## _tick_stamina for why this latch exists at all.
const WIND_BACK := 0.3
const JUMP_VELOCITY := 4.5
## Radians of turn per pixel of mouse travel, before the player's own
## multiplier. Negative because screen Y grows downwards.
const MOUSE_SENSE := -0.003

## Settings. These do not live here -- they live in Scripts/Settings.gd, as
## statics -- and these are the names the rest of the game already reads.
##
## THE MENU HAS NO PLAYER, so a field of view owned by this node could not be
## offered before the game starts. Moving the values into a static store is
## what lets one settings page serve the title screen and the journal, and what
## lets a choice made on the menu survive change_scene_to_file into the level.
## Still not saved to disk: a slider that silently fails to persist is worse
## than one that obviously only lasts the session.
var look_sensitivity: float:
	get: return SETTINGS.look_sensitivity
	set(value): SETTINGS.look_sensitivity = value

var invert_look: bool:
	get: return SETTINGS.invert_look
	set(value): SETTINGS.invert_look = value

var head_bob_enabled: bool:
	get: return SETTINGS.head_bob
	set(value): SETTINGS.head_bob = value

## How big spoken lines are drawn, as the journal's dropdown offers it.
##
## MEDIUM IS WHAT THEY HAVE ALWAYS BEEN -- 20 px -- so an existing save, and
## anyone who never opens the setting, sees exactly what they saw before.
## Small and Large are a size either side of it, far enough apart to be worth
## choosing between and not so far that the line stops fitting its box.
enum SubtitleSize {SMALL, MEDIUM, LARGE}

const SUBTITLE_PX := {
	SubtitleSize.SMALL: 15,
	SubtitleSize.MEDIUM: 20,
	SubtitleSize.LARGE: 27,
}

var subtitle_size: SubtitleSize:
	get: return SETTINGS.subtitle_size as SubtitleSize
	set(value):
		SETTINGS.subtitle_size = value
		subtitle_size_changed.emit(subtitle_pixels())


## The chosen size in pixels. The HUD reads this once when it builds the
## label -- it cannot rely on the signal alone, because the setting may well
## have been chosen before the HUD existed to hear about it.
func subtitle_pixels() -> int:
	return SUBTITLE_PX[subtitle_size]


## Capsule heights. The collision shape is re-centred as it shrinks so the
## player's feet stay put instead of the whole body sinking through the floor.
## Read from whatever capsule the scene authors, so resizing the player in
## the editor is not silently overwritten on every run.
var stand_height := 2.0
var crouch_height := 0.85

## Crouch height as a fraction of standing height.
const CROUCH_RATIO := 0.45
const CROUCH_LERP := 12.0

## Eye height above the collision shape centre, likewise taken from the scene.
## The head has to come down with the capsule, not ride on top of it, or at
## crouch height the camera sits above the capsule and pokes through a desk.
var stand_head := 0.616
var crouch_head := 0.305

## How far below the crouched capsule top the eye sits.
const CROUCH_EYE_DROP := 0.12

## How long the vision effect takes to bleed in once the glass is up.
const VISION_FADE_IN := 0.25
const VISION_FADE_OUT := 0.15

## Head bob when the player walks
const BOB_FREQ = 3.0
const BOB_AMP = 0.08
var t_bob = 0.0

## item sway around when camera moves
const LOOK_SWAY_AMOUNT := 0.01
const LOOK_SWAY_MAX := 0.04
const SWAY_SMOOTH_SPEED := 8.0

var mouse_input := Vector2.ZERO
@onready var defualt_glass_pos: Vector3 = glass.transform.origin

## The nine slot actions, in the order the journal draws the grid. The bindings
## themselves live in Scripts/Controls.gd, which is the only thing that writes
## the Input Map; this is just the reading order.
const SLOT_ACTIONS := [
	"Slot_1", "Slot_2", "Slot_3",
	"Slot_4", "Slot_5", "Slot_6",
	"Slot_7", "Slot_8", "Slot_9",
]

# 89 not 90: at exactly straight up/down the yaw read below hits gimbal lock.
var max_look := deg_to_rad(89.0)

var crouching := false
var sprinting := false

## Hold to run, or press once to keep running. Off by default because the
## character is meant to be reluctant, and because a toggle that survives into
## a room you wanted to enter quietly is a bug as far as the player is
## concerned. The settings page flips it, chiefly for pad users -- holding L3
## down for a hundred metres is unpleasant.
## What has actually been pushed to a node, so _sync_settings can tell a
## change from a no-op. Not the setting: the setting is in Settings.
var _applied_fov := -1.0
var _applied_torch := -1.0
var _applied_subtitle := -1

var sprint_toggle: bool:
	get: return SETTINGS.sprint_toggle
	set(value): SETTINGS.sprint_toggle = value

## Only meaningful while sprint_toggle is on. Cleared whenever the reasons to
## run stop applying, so it can never survive a crouch, a cutscene or a pause.
var _sprint_latched := false

## 0.0 to 1.0, full at the start. Public so the HUD and the save can read it.
var stamina := 1.0
## True from the moment the tank empties until it has WIND_BACK back in it.
var _winded := false
var _winded_last := false

## The magnifying glass is found on the kitchen counter. Until the player
## picks it up the lens cannot be raised at all, so the demo can teach the
## mechanic at the moment it becomes useful.
##
## It is equipment, never cargo: it does not take an inventory cell, cannot be
## dropped, and has no slot to select. The player is told once that [Q] raises
## it and the crosshair reminds them whenever something is too small to read.
var has_magnifier := false
var vision := false
var vision_busy := false

## Torch. Off at the start -- the first thing the character does on the porch
## is find the switch, and a torch that is already on takes that beat away.
var torch_on := false
var torch_energy: float:
	get: return SETTINGS.torch_energy
	set(value): SETTINGS.torch_energy = value

## Set while the player is inside a HidingSpot. Movement is frozen; looking
## around still works, so you can watch the room through the slats.
var hiding := false
var hiding_spot: HidingSpot = null

var current_interactable: Interactable = null

## Set while a set piece owns the camera and the controls -- currently the
## safe. Distinct from `hiding`: hiding keeps free look so you can watch the
## room, focus hands input wholesale to the thing being operated.
var focus_target: Node = null

var _vision_amount := 0.0
var _vision_tween: Tween
const HIGHLIGHT := preload("res://Vision/highlight.tres")

var _highlit: Array[GeometryInstance3D] = []
var _highlit_overlays: Array[Material] = []
var _conceal_areas: Array[ConcealArea] = []
var _was_concealed := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# The lens survives a change of level -- see Scripts/Carry.gd. Restored
	# silently: the character did not just find it, they walked in holding it.
	if Carry.has_magnifier:
		grant_magnifier(false)

	# The shape is a sub-resource shared by every instance of this scene, so
	# resize a private copy rather than mutating the one on disk.
	body_shape.shape = body_shape.shape.duplicate()

	# Adopt whatever was authored in the scene as "standing", instead of
	# forcing a hard-coded size and silently undoing edits made in the editor.
	var capsule := body_shape.shape as CapsuleShape3D
	if capsule != null:
		stand_height = capsule.height
		crouch_height = stand_height * CROUCH_RATIO
	stand_head = head.position.y
	crouch_head = crouch_height * 0.5 - CROUCH_EYE_DROP
	_size_headroom_probe()

	_apply_crouch(0.0, true)

	interact_ray.add_exception(self)
	headroom.add_exception(self)

	glass.visible = false
	_set_vision_amount(0.0)
	_clear_lens()

	# SEED THE SHARED SETTING FROM THE SCENE, ONCE. This used to read the
	# authored light straight into torch_energy, which is a static now -- so
	# every level load would stamp the scene's brightness back over whatever
	# was chosen on the title screen, and the setting would appear to forget
	# itself exactly when the player crossed from the house into the woods.
	if not SETTINGS.torch_seeded:
		SETTINGS.torch_energy = flashlight.light_energy
		SETTINGS.torch_seeded = true
	camera.fov = SETTINGS.fov
	_applied_fov = SETTINGS.fov
	_applied_torch = SETTINGS.torch_energy
	_applied_subtitle = SETTINGS.subtitle_size
	set_torch(false)

	# Occlusion culling, forced on here as well as in project.godot. The house
	# is full of rooms you cannot see into, and without this the renderer was
	# submitting the whole building every frame. It lives in project.godot,
	# which the editor rewrites wholesale from its own in-memory copy and has
	# dropped entries from before -- so, like the input map, anything the game
	# needs is also set from code.
	RenderingServer.viewport_set_use_occlusion_culling(
		get_viewport().get_viewport_rid(), true
	)



## Sizes the stand-up probe from the actual capsule, sweeping exactly the band
## between the crouched top and the standing top. Hard-coded numbers here went
## stale the moment the capsule was resized in the editor.
func _size_headroom_probe() -> void:
	var capsule := body_shape.shape as CapsuleShape3D
	var radius: float = (capsule.radius if capsule != null else 0.3) * 0.9

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	headroom.shape = sphere

	var crouched_top := crouch_height - stand_height * 0.5
	var standing_top := stand_height * 0.5
	headroom.position.y = crouched_top
	headroom.target_position = Vector3(
		0.0, maxf(standing_top - radius - crouched_top, 0.01), 0.0
	)


func _unhandled_input(event: InputEvent) -> void:
	# The journal eats its own input while it is up, and pausing the tree stops
	# this running at all -- but the frame the book opens still arrives here.
	if journal.open:
		return

	# A set piece owns the controls: hand it everything and do nothing else, so
	# the player cannot walk away or swing the lens mid-puzzle.
	#
	# THIS HAS TO COME BEFORE THE JOURNAL CHECK, and used to come after. Escape
	# and Tab were swallowed here and opened the book, so the branch in
	# Safe.handle_focus_input that lets go of the dials could never run -- and
	# since the safe's only other exit is cracking it, a player who walked up to
	# it without the combination was stuck there for good.
	if focus_target != null:
		if is_instance_valid(focus_target) and focus_target.has_method("handle_focus_input"):
			focus_target.handle_focus_input(event)
		else:
			end_focus()
		return

	if event.is_action_pressed("Journal") or event.is_action_pressed("Pause"):
		journal.set_open(true)
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sense := MOUSE_SENSE * look_sensitivity
		head.rotation.y += event.relative.x * sense
		head.rotation.x = clamp(
			head.rotation.x + event.relative.y * (-sense if invert_look else sense),
			-max_look, max_look
		)

		mouse_input = event.relative

	if event.is_action_pressed("Interact"):
		_try_interact()

	if event.is_action_pressed("Crouch"):
		_toggle_crouch()

	if event.is_action_pressed("Open_Magnify") and has_magnifier:
		toggle_vision()

	if event.is_action_pressed("Flashlight"):
		set_torch(not torch_on)

	if event.is_action_pressed("Drop"):
		drop_held()

	# Hold-to-run needs nothing here -- _physics_process reads the button
	# directly. Only the toggle has a state to flip, and it flips on the press
	# alone; the release is not interesting and must not be, because the
	# release is the event that goes missing.
	if sprint_toggle and event.is_action_pressed("Sprint"):
		_sprint_latched = not _sprint_latched

	for slot in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[slot]):
			inventory.select(slot)


# Rendering reads transforms at the end of the frame, so the lens has to be
# published from _process, not _physics_process, or it lags the camera.
func _process(delta: float) -> void:
	_sync_settings()
	_pad_look(delta)
	_publish_lens()
	_scan_for_interactable()
	_update_concealment()


## Pushes the two settings that have to reach a NODE.
##
## Most of them are read where they are used -- look_sensitivity straight out
## of the store every time the mouse moves -- but a field of view lives on the
## camera and a torch brightness lives on a light, and something has to put
## them there. POLLED rather than pushed because the settings page writes to
## Settings and knows nothing about this node: it is shown on the title
## screen, where there is no player to tell.
##
## Three float compares a frame. The alternative is a signal on a static,
## which GDScript does not have.
func _sync_settings() -> void:
	if _applied_fov != SETTINGS.fov:
		_applied_fov = SETTINGS.fov
		camera.fov = SETTINGS.fov
	if _applied_torch != SETTINGS.torch_energy:
		_applied_torch = SETTINGS.torch_energy
		if flashlight.visible:
			flashlight.light_energy = SETTINGS.torch_energy
	if _applied_subtitle != SETTINGS.subtitle_size:
		_applied_subtitle = SETTINGS.subtitle_size
		subtitle_size_changed.emit(subtitle_pixels())


## The right stick, polled rather than event-driven. A stick held still sends
## no events, so looking around with one has to be sampled every frame or the
## camera stops the instant the player stops pushing harder.
##
## In _process, like the mouse path it mirrors: rendering reads transforms at
## the end of the frame, and turning the head on the physics tick makes the
## view judder against a monitor running faster than 60.
func _pad_look(delta: float) -> void:
	if journal.open or focus_target != null:
		return
	var look := Controls.pad_look(delta)
	if look == Vector2.ZERO:
		return

	head.rotation.y -= look.x * look_sensitivity
	var pitch := look.y * look_sensitivity
	head.rotation.x = clamp(
		head.rotation.x - (-pitch if invert_look else pitch), -max_look, max_look
	)
	# Feed the lens sway the same way mouse motion does, so the glass leads the
	# camera on a pad too. Scaled to the pixels-of-mouse-travel the sway curve
	# was tuned against.
	mouse_input += Vector2(look.x, look.y) / -MOUSE_SENSE


# --------------------------------------------------------------- interaction

func _scan_for_interactable() -> void:
	# While a set piece owns the camera the crosshair is meaningless.
	if focus_target != null:
		if current_interactable != null:
			current_interactable = null
			interactable_changed.emit(null)
		return

	# A pickup frees itself the instant it is taken, which leaves this holding
	# a dead instance. Clear it before anything downstream reads it.
	if current_interactable != null and not is_instance_valid(current_interactable):
		current_interactable = null
		interactable_changed.emit(null)

	var found: Interactable = null

	# While stowed, the only thing reachable is the spot itself -- otherwise
	# you could reach through the closet wall and open the room's doors.
	if hiding:
		found = hiding_spot
	elif interact_ray.is_colliding():
		found = _find_interactable(interact_ray.get_collider())

	if found != null and not found.can_interact(self):
		# Keep it as the target so the HUD can explain why it will not open.
		pass

	if found != current_interactable:
		current_interactable = found
		_apply_highlight(found)
		interactable_changed.emit(found)


## Rims whatever is under the crosshair, so interactable things announce
## themselves instead of hiding among the furniture.
##
## The previous overlay is saved and put back, because tagged objects already
## carry the vision-lens overlay in that same slot. While the lens is up the
## highlight is skipped entirely and the tag colours own the look.
func _apply_highlight(target: Interactable) -> void:
	_clear_highlight()
	if target == null or vision or vision_busy:
		return
	_collect_highlight(target)


func _collect_highlight(node: Node) -> void:
	if node is GeometryInstance3D:
		var geo := node as GeometryInstance3D
		_highlit.append(geo)
		_highlit_overlays.append(geo.material_overlay)
		geo.material_overlay = HIGHLIGHT
	for child in node.get_children():
		_collect_highlight(child)


func _clear_highlight() -> void:
	for index in _highlit.size():
		var geo := _highlit[index]
		if is_instance_valid(geo):
			geo.material_overlay = _highlit_overlays[index]
	_highlit.clear()
	_highlit_overlays.clear()


## Colliders hang below the interactable (a door's swinging panel, a pickup's
## body), so walk up until one turns up.
##
## Disabled ones are stepped over rather than stopping the search: a closet's
## own door is an Interactable nested inside the hiding spot, and stopping
## there would mean looking at the closet offered you a door that does
## nothing instead of the option to climb in.
func _find_interactable(from: Object) -> Interactable:
	var node := from as Node
	while node != null:
		if node is Interactable and (node as Interactable).enabled:
			return node
		node = node.get_parent()
	return null


func _try_interact() -> void:
	if current_interactable == null:
		return
	if not current_interactable.can_interact(self):
		return
	current_interactable.interact(self)

	# Taking a pickup destroys it; drop the reference in the same frame rather
	# than letting a freed object survive until the next scan.
	if not is_instance_valid(current_interactable):
		current_interactable = null
		interactable_changed.emit(null)


## Called by the magnifier pickup in the kitchen.
##
## `announce` is false when the lens was carried in from the last level rather
## than found here. The player already knows they have it; being told again on
## every level boundary makes the message mean nothing when it does matter.
func grant_magnifier(announce := true) -> void:
	has_magnifier = true
	Carry.has_magnifier = true
	if not announce:
		return
	show_message("Magnifying glass in hand.  %s raises it." % Controls.glyph("Open_Magnify"), 5.0)
	note("The glass", ("Found on the kitchen counter. Raise it with %s. Fine writing is "
		+ "legible through it, and it picks things out in the dark that the eye does not.")
		% Controls.glyph("Open_Magnify"))


# --------------------------------------------------------------------- torch

func set_torch(on: bool) -> void:
	torch_on = on
	flashlight.visible = on
	if on:
		flashlight.light_energy = torch_energy


## Lets the settings page change the brightness without turning the torch on.
func set_torch_energy(value: float) -> void:
	torch_energy = value
	if torch_on:
		flashlight.light_energy = value


# ---------------------------------------------------------------- dropping

## Puts the held item back in the world, on the floor in front of the player.
##
## Raycast down from a point a step ahead rather than dropping at the feet: at
## the feet the item lands inside the player capsule and cannot be picked back
## up until they walk away from it, which reads as having lost it.
func drop_held() -> void:
	var item: ItemData = inventory.get_selected()
	if item == null:
		return
	Sound.play_ui("drop", -13.0)

	var origin := global_position + Vector3(0.0, 0.9, 0.0)
	var ahead := -Basis(Vector3.UP, head.global_rotation.y).z
	var target := origin + ahead * 0.85

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(target, target + Vector3.DOWN * 3.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var landing: Vector3 = hit["position"] if hit else global_position

	inventory.take_selected()

	var where := Transform3D(Basis(Vector3.UP, head.global_rotation.y + randf_range(-0.6, 0.6)), landing)
	Pickup.drop(item, get_parent(), where)
	show_message("Put down the %s." % item.display_name, 2.5)


# ----------------------------------------------------------------- journal

## Writes a line into the notebook. Readables and clues call this through
## show_message, so anything worth remembering is still there an hour later.
func note(title: String, body: String) -> void:
	journal.add_note(title, body)


# -------------------------------------------------------------------- focus

## Hands control to a set piece, which must expose handle_focus_input(event)
## and call end_focus() when it is finished.
func begin_focus(target: Node) -> void:
	focus_target = target
	velocity = Vector3.ZERO
	sprinting = false


func end_focus() -> void:
	focus_target = null
	# The set piece is gone, so its control hint goes with it. Left alone it
	# hangs on screen over ordinary play.
	hint_changed.emit("")
	# Whatever camera the set piece made current, take it back.
	camera.current = true


## Puts a persistent line of controls on screen. Set pieces call this when they
## take focus and again whenever the bindings change under them.
func show_hint(text: String) -> void:
	hint_changed.emit(text)


# ------------------------------------------------------------------ message

func show_message(text: String, seconds := 4.0) -> void:
	message_requested.emit(text, seconds)


## Puts a line in the character's mouth. Queued, so several can be fired at
## once and they play in order instead of stamping over each other.
func say(text: String) -> void:
	line_spoken.emit(text)


## Fades the screen out. Used to close the demo when the study is entered.
func fade_out(duration := 2.0, closing_text := "") -> void:
	fade_requested.emit(duration, closing_text)


func fade_in(duration := 1.0) -> void:
	unfade_requested.emit(duration)


## A blown-out frame. The hold is what makes it an explosion rather than a
## camera flash.
func flash(colour := Color(1, 1, 1, 1), rise := 0.05, hold := 0.1, fall := 0.9) -> void:
	flash_requested.emit(colour, rise, hold, fall)


## The tunnel, driven frame by frame by whoever is running the sequence.
## `amount` is how present it is, `travel` is how far down it you are.
func tunnel(amount: float, travel: float) -> void:
	tunnel_requested.emit(amount, travel)


# ------------------------------------------------------------------- hiding

func enter_hiding(spot: HidingSpot) -> void:
	hiding = true
	hiding_spot = spot
	velocity = Vector3.ZERO
	# Stop the capsule catching on the closet geometry while stowed.
	body_shape.disabled = true
	_update_concealment()


func exit_hiding() -> void:
	hiding = false
	hiding_spot = null
	body_shape.disabled = false
	_update_concealment()


func is_concealed() -> bool:
	if hiding:
		return true
	for area in _conceal_areas:
		if not area.requires_crouch or crouching:
			return true
	return false


func enter_conceal(area: ConcealArea) -> void:
	if not _conceal_areas.has(area):
		_conceal_areas.append(area)


func exit_conceal(area: ConcealArea) -> void:
	_conceal_areas.erase(area)


func _update_concealment() -> void:
	var now := is_concealed()
	if now != _was_concealed:
		_was_concealed = now
		concealment_changed.emit(now)


# ------------------------------------------------------------------- crouch

func _toggle_crouch() -> void:
	if hiding:
		# Crouch doubles as "get me out of here".
		hiding_spot.interact(self)
		return

	if crouching and not _has_headroom():
		return
	crouching = not crouching
	if crouching:
		_sprint_latched = false


# ------------------------------------------------------------------- sprint

## Whether the character is running THIS frame. Derived, every frame, from
## things that are all true right now -- never accumulated.
##
## It used to be a bool toggled by both the press and the release of the same
## button, which is two ways to get it wrong and it got it wrong both ways.
## Toggling on the release meant anything that swallowed the release left the
## player sprinting for the rest of the session: opening the book, a cutscene
## taking focus, a hiding spot -- all of which return out of _unhandled_input
## before the Sprint branch is reached. And the crouch guard returned early
## *before* flipping, so crouching mid-run and standing up again left the flag
## set with no button held.
##
## Reading the button instead means there is no state to get stuck. The toggle
## variant still has one, but it is cleared here on every condition that ends
## a run, so it cannot outlive the run either.
func _sprint_wanted(moving: bool) -> bool:
	if crouching or hiding or focus_target != null or not moving:
		_sprint_latched = false
		return false
	# Out of breath. Holding the button does nothing until enough has come back
	# to be worth spending -- see _winded.
	if _winded:
		_sprint_latched = false
		return false
	if sprint_toggle:
		return _sprint_latched
	return Input.is_action_pressed("Sprint")


## Spends and refills the tank, and decides when the character is winded.
##
## THE WINDED LATCH IS THE WHOLE DESIGN. Without it, stamina hitting zero lets
## the player tap the key again the instant one frame's worth has regenerated,
## which gives a juddering half-run that is faster than walking and makes the
## bar flicker at the bottom of its range. Once empty, sprinting is refused
## outright until the tank is back to WIND_BACK, so running out has a cost you
## can feel and the bar has something to show you while it recovers.
func _tick_stamina(delta: float, running: bool) -> void:
	var before := stamina
	if running:
		stamina = maxf(stamina - delta / SPRINT_SECONDS, 0.0)
		if stamina <= 0.0:
			_winded = true
	else:
		# Standing still gets its breath back faster than walking does. Nothing
		# recovers while crouched and moving -- creeping is work.
		var rate := 1.0 / RECOVER_SECONDS
		if Vector2(velocity.x, velocity.z).length() < 0.1:
			rate *= REST_BONUS
		stamina = minf(stamina + delta * rate, 1.0)
		if _winded and stamina >= WIND_BACK:
			_winded = false

	if absf(stamina - before) > 0.0001 or _winded != _winded_last:
		_winded_last = _winded
		stamina_changed.emit(stamina, _winded)


## Assigns the tank and tells anyone listening. Anything outside this file that
## wants to move the value uses this rather than writing `stamina` directly --
## a bare assignment emits nothing, so the bar goes on showing whatever it last
## heard. That is how a full tank ended up with the bar still on screen.
func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, 1.0)
	_winded = _winded and stamina < WIND_BACK
	_winded_last = _winded
	stamina_changed.emit(stamina, _winded)


## Sweeps the volume the standing capsule would occupy but the crouched one
## does not. A single upward ray would miss a desk the player is only half
## under, and they would stand up inside it.
func _has_headroom() -> bool:
	headroom.force_shapecast_update()
	return not headroom.is_colliding()


func _apply_crouch(delta: float, snap := false) -> void:
	var capsule := body_shape.shape as CapsuleShape3D
	if capsule == null:
		return

	var target_height: float = crouch_height if crouching else stand_height
	# Keep the soles of the feet at the same height as the capsule shrinks.
	var target_offset := (target_height - stand_height) * 0.5

	var target_head: float = crouch_head if crouching else stand_head

	var weight: float = 1.0 if snap else clamp(delta * CROUCH_LERP, 0.0, 1.0)
	capsule.height = lerp(capsule.height, target_height, weight)
	body_shape.position.y = lerp(body_shape.position.y, target_offset, weight)
	head.position.y = lerp(head.position.y, target_head, weight)


# -------------------------------------------------------------------- vision

## Runs as its own coroutine so the await never stalls _physics_process.
func toggle_vision() -> void:
	if vision_busy:
		return
	vision_busy = true
	vision = not vision

	if vision:
		glass.visible = true
		glass_anim.play("Put_up")
		await glass_anim.animation_finished
		_fade_vision(1.0, VISION_FADE_IN)
	else:
		_fade_vision(0.0, VISION_FADE_OUT)
		await get_tree().create_timer(VISION_FADE_OUT).timeout
		glass_anim.play_backwards("Put_up")
		await glass_anim.animation_finished
		glass.visible = false

	vision_busy = false


func _fade_vision(target: float, duration: float) -> void:
	if _vision_tween:
		_vision_tween.kill()
	_vision_tween = create_tween()
	_vision_tween.tween_method(_set_vision_amount, _vision_amount, target, duration)


func _set_vision_amount(amount: float) -> void:
	_vision_amount = amount
	# Tag colours and the crosshair highlight share the overlay slot; the lens
	# wins while it is up.
	if amount > 0.01 and not _highlit.is_empty():
		_clear_highlight()
	RenderingServer.global_shader_parameter_set("vision_mode", amount)


## Hands the lens disc to both vision shaders as a screen-space ellipse:
## centre in .xy, radii in .zw, all in screen UV.
##
## The tag overlays paint a bright key colour that the lens decodes back into
## red / yellow / blue. That key must never be visible directly, so the tag
## shader discards everything outside this ellipse -- which is what keeps the
## effect inside the lens instead of taking over the whole screen. The lens
## shader uses the same ellipse for its own disc, so the two can never
## disagree about where the glass is.
func _publish_lens() -> void:
	if not glass.visible or glass_mesh.mesh == null:
		_clear_lens()
		return

	var aabb := glass_mesh.get_aabb()
	var xf := glass_mesh.global_transform
	var centre := xf * aabb.get_center()

	# unproject_position mirrors points behind the camera. Early in the flip
	# the lens genuinely is behind the eye, so bail rather than publish a
	# mask that is inside out.
	if camera.is_position_behind(centre):
		_clear_lens()
		return

	# How far the mesh reaches along the camera's own right and up axes. For
	# the tilted disc this is exactly its silhouette, so the ellipse lands on
	# the rim instead of bounding it loosely the way a corner fit would.
	var cam := camera.global_transform.basis
	var half := aabb.size * 0.5
	var edge_right := centre + cam.x * _extent_along(xf.basis, half, cam.x)
	var edge_up := centre + cam.y * _extent_along(xf.basis, half, cam.y)

	if camera.is_position_behind(edge_right) or camera.is_position_behind(edge_up):
		_clear_lens()
		return

	# Project rather than compute from fov, so this stays correct for any
	# fov, keep_aspect setting or viewport stretch.
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_centre := camera.unproject_position(centre) / viewport_size
	var radius_x := absf(camera.unproject_position(edge_right).x / viewport_size.x - screen_centre.x)
	var radius_y := absf(camera.unproject_position(edge_up).y / viewport_size.y - screen_centre.y)

	_set_lens(Vector4(screen_centre.x, screen_centre.y, radius_x, radius_y))


## Half-width of an oriented box along an arbitrary axis.
## Named box_basis, not basis: Node3D already has a basis property, and
## shadowing it in a CharacterBody3D script trips a GDScript warning.
func _extent_along(box_basis: Basis, half: Vector3, axis: Vector3) -> float:
	return (
		absf(axis.dot(box_basis.x * half.x))
		+ absf(axis.dot(box_basis.y * half.y))
		+ absf(axis.dot(box_basis.z * half.z))
	)


func _clear_lens() -> void:
	# Zero radii; both shaders read that as "there is no lens right now".
	_set_lens(Vector4(0.5, 0.5, 0.0, 0.0))


func _set_lens(lens: Vector4) -> void:
	var material := glass_mesh.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("vision_lens", lens)
	VisionTags.set_lens(lens)


# ------------------------------------------------------------------ movement

func _physics_process(delta: float) -> void:
	
	var target_x = -mouse_input.x * LOOK_SWAY_AMOUNT
	var target_y = mouse_input.y * LOOK_SWAY_AMOUNT
	
	target_x = clamp(target_x, -LOOK_SWAY_MAX, LOOK_SWAY_MAX)
	target_y = clamp(target_y, -LOOK_SWAY_MAX, LOOK_SWAY_MAX)
	
	var target_pos = defualt_glass_pos + Vector3(target_x, target_y, 0.0)
	
	glass.transform.origin = glass.transform.origin.lerp(target_pos, delta * SWAY_SMOOTH_SPEED)
	
	mouse_input = Vector2.ZERO
	
	_apply_crouch(delta)

	if hiding or focus_target != null:
		velocity = Vector3.ZERO
		# Still recovering. Shut in a wardrobe with something in the room is
		# exactly when you want your breath back, and the alternative -- a tank
		# frozen at whatever it held when you climbed in -- punishes hiding.
		_tick_stamina(delta, false)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor() and not crouching:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector(
		"Move_Left", "Move_Right", "Move_Forward", "Move_Backward"
	)

	# Yaw only. Using the full head basis makes you crawl when you look up or down,
	# because normalize() shrinks the horizontal part before y gets discarded.
	var direction := (
		Basis(Vector3.UP, head.global_rotation.y) * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	sprinting = _sprint_wanted(direction != Vector3.ZERO)
	_tick_stamina(delta, sprinting)

	var speed: float = CROUCH_SPEED if crouching else SPRINT_SPEED if sprinting else WALK_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	# Bob off HORIZONTAL speed. velocity.length() includes the fall, so walking
	# off the porch step used to spin the bob up to a sprint's cadence in
	# mid-air -- and the is_on_floor() guard does not catch it, because the
	# first frame of a step down is still on the floor.
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and ground_speed > 0.1 and head_bob_enabled:
		t_bob += delta * ground_speed
		camera.transform.origin = _headbob(t_bob)
	else:
		t_bob = 0.0
		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 0.6)
	move_and_slide()

func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
