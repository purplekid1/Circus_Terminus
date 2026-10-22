extends Node3D
## What happens when the player touches the book. Two of them, and you pick.
##
## BLAST  -- the book lifts off the desk, hangs, and goes off. The player is
##           thrown backwards into the wall, the camera rolls over as they go
##           down, and the picture cuts.
## ABSORB -- the book pulls instead of pushes. The room comes apart into
##           particles that stream into the pages, the screen whites out, and
##           the player falls down a tunnel and is spat out over the woods.
##
## Both land in the same place: black, then the next level. That is deliberate.
## They are two tellings of one event, not two branches -- whichever plays, the
## character wakes up outside a circus tent, so nothing downstream has to know
## which one it was.
##
## THE PLAYER IS UNDER FOCUS FOR THE WHOLE THING, which means
## PlayerController._physics_process returns before it touches velocity. Nothing
## here can use physics to move them; every movement is driven from this script,
## and the one place it matters -- being thrown backwards into a wall -- uses
## move_and_collide by hand so it stops on the masonry instead of through it.

enum Mode {
	## The book goes off in your face.
	BLAST,
	## The book takes you with it.
	ABSORB,
}

@export var mode: Mode = Mode.ABSORB

## The book itself. Its light and particles are driven directly.
@export var book_path: NodePath
## Where to go when the picture is black. Left empty, or pointing at a scene
## that does not exist yet, the sequence simply ends on black and says so --
## which is what you want while the next level is still being built.
@export_file("*.tscn") var next_level := ""

@export_group("Approach")
## Leaning over the book. Slow in, because it is curiosity.
@export var lean_distance := 0.34
## UP, not down. Leaning over something on a desk you rise and crane over it;
## this used to drop the eye 16 cm and the view ended up half desk, with the
## book at the bottom of frame instead of in the middle of it.
@export var lean_lift := 0.09
@export var lean_pitch := -10.0
## The beat at the bottom of the lean, where you are close enough to read it.
## Pulling away. Fast, and with overshoot on the tween, because it is alarm.
@export var jolt_time := 0.28
@export var jolt_rise := 0.1
@export var jolt_pitch := 35.0
## How far the eye rises WHILE the book does, spread over the whole of
## rise_time. The head following the book up is most of what ties the two
## movements into one event instead of two.
@export var head_lift := 0.18
## The book coming up off the desk and standing on its spine to face you.
@export var rise_height := 0.62
@export var rise_tilt := 72.0
@export var rise_time := 0.5
## Giving ground while it does.
##
## A SHUFFLE, NOT A DIVE. This was 1.1 m, which is a full pace and a half
## backwards -- the player was launched across the study and lost sight of the
## desk entirely. All this has to do is register surprise; the camera work does
## the rest, and a body that moves less than the view does reads as flinching
## rather than as fleeing.
@export var retreat_distance := 0.02

@export_group("Blast")
## How far the book climbs off the desk before it goes off, and how long it
## takes. Slow: the lift is the part that tells the player something is about
## to happen, and it is wasted if it is quick.
@export var lift_height := 1.5
## The pause at the top. Nothing moves. This is the whole trick.
## How far back the blast throws them, and over how long.
@export var throw_distance := 0.2
## How far the camera rolls as they go down, and how far the eye falls.
@export var roll_degrees := 90.0
@export var drop_height := 1.15
@export var black_out := 1.5

@export_group("Absorb")
## How long the pull lasts before the white-out.
## How much of the gap to the pages is closed. Not a distance in metres: the
## player can trigger this from anywhere they can reach the book, so the pull
## has to be measured against where they actually are. Just short of 1, because
## the white-out covers the last of it.
@export_range(0.0, 1.0) var pull_fraction := 0.88
## How long the tunnel runs, and how far down it you travel. Travel is in
## shader units -- see Scripts/tunnel.gdshader; about 10 a second reads as fast
## without the walls strobing.
@export var tunnel_travel := 46.0
## Where the tunnel puts you down. Exported because "the woods" is a place in
## the level, and the level moves.
@export var exit_point := Vector3(-27.0, 14.0, -22.0)

@onready var _anim: AnimationPlayer = $Anim

var _player: Node3D
var _book: Node3D
var _running := false
var _tunnel_amount := 0.0

## Everything the animation's setters need, captured once at the top of each
## phase. A keyframe cannot know where this player's eye is or which way the
## book has to turn to face them, so the script works that out and the
## animation only ever says how far along the move is.
var _cam: Node3D
var _cam3: Camera3D
var _toward := Vector3.ZERO
var _away := Vector3.ZERO
var _book_y0 := 0.0
var _face_yaw := 0.0
var _blast_eye0 := Vector3.ZERO
var _back_dir := Vector3.ZERO
var _book_lift_y0 := 0.0
var _absorb_eye0 := Vector3.ZERO
var _travel_to := Vector3.ZERO
var _fov0 := 75.0
var _inrush: GPUParticles3D
var _spin := 0.0
var _glow_from := 0.0
var _glow_target := 0.0
## Phase gates, so only one track writes the tunnel or the player's position at
## a time -- see the notes on `tunnel_run` and `fall`.
var _after_whiteout := false
var _after_spit := false
var _flaring := false
## Where the eye was before the lean started. Every camera move in the sequence
## is measured from here, so they compose instead of each one resetting.
var _eye0 := Vector3.ZERO
var _pitch0 := 0.0
## The page light has exactly one tween at a time. _brighten winds it up and
## _burst puts it out, and with both running unguarded the wind-up held the
## light at 11 while the burn-out was trying to take it to nothing.


func _ready() -> void:
	set_process(false)


## Called by the Grimoire when it is touched. Returns immediately; the sequence
## runs on its own from here.
func play(player: Node) -> void:
	if _running:
		return
	_running = true
	_player = player as Node3D
	_book = get_node_or_null(book_path) as Node3D
	if _player == null:
		push_warning("BookEnding: no player -- nothing to play to.")
		return

	# THE BOOK'S LIGHT IS OURS FROM HERE. Grimoire._process recomputes
	# light_energy from its breathing curve every frame, so without this the
	# flare and the burn-out are both overwritten a frame after they are set and
	# the book glows gently through its own explosion. Done here rather than
	# relying on the caller having set a flag, because whoever starts this
	# sequence should not have to know that.
	if _book != null:
		_book.set_process(false)

		# Seed the glow at whatever the book was already showing. The `glow`
		# track writes from its first frame, and without this it would lerp up
		# from zero and blink the page light out before the flare starts.
		_glow_from = _glow_now()
		_glow_target = _glow_from

	# It already holds focus from the Grimoire, but take it again in case this
	# is being driven from a test or a debug key.
	if _player.has_method("begin_focus") and _player.focus_target == null:
		_player.begin_focus(self)
	if _player.has_method("set_torch"):
		_player.set_torch(false)

	# The part that is the same whichever way it goes: you bend over the book to
	# look at it, and then something happens and you flinch.
	await _approach()

	if mode == Mode.BLAST:
		await _blast()
	else:
		await _absorb()

	_leave()


# ------------------------------------------------------------------ approach

## Leaning in, then jolting back.
##
## This is THE ESTABLISHING BEAT and it is worth the two seconds. Without it the
## book simply detonates the instant you press the key, and the player reads it
## as a trap rather than as something they leaned over and disturbed. The lean
## is slow and the recoil is fast, which is the whole difference between
## curiosity and alarm -- the same movement at the same speed in both directions
## reads as a machine.
func _approach() -> void:
	_cam = _player.camera
	_cam3 = _cam as Camera3D
	_eye0 = _cam.position
	_pitch0 = _cam.rotation_degrees.x

	_toward = Vector3.ZERO
	if _book != null:
		_toward = (_book.global_position - _cam.global_position).normalized()
		_book_y0 = _book.position.y
		var to_player := _player.global_position - _book.global_position
		# PLUS PI. The pages face local +Y while the book is flat, and tilting by
		# -rise_tilt about X swings that normal round to local -Z -- so aiming
		# local +Z at the player, which is what atan2(x, z) gives you, stands the
		# book up with its BACK to them. Measured at exactly 180 degrees out
		# before this was added.
		_face_yaw = atan2(to_player.x, to_player.z) + PI

	# Backwards, on the floor, so it collides -- there is a desk and a wall in
	# this room.
	_away = -(_player.global_transform.basis.z as Vector3)
	_away.y = 0.0
	_away = _away.normalized()

	_anim.play(&"approach")
	await _anim.animation_finished


## Leaning in: face closer to the page. Written by the animation.
var lean := 0.0:
	set(value):
		lean = value
		if _cam == null:
			return
		_cam.position = _eye0 + _toward * lean_distance * value + Vector3(0.0, lean_lift * value, 0.0)
		_cam.rotation_degrees.x = _pitch0 - lean_pitch * value


## The flinch and the head-lift, off ONE clock.
##
## They cannot be two tracks on the camera -- they would each stamp on the
## other every frame -- so the slow one is the track and the fast one is a
## curve read off it. jolt_time and rise_time survive as exports because what
## they set here is the RATIO between the two, not a duration: the animation
## owns how long the whole move takes.
var lift := 0.0:
	set(value):
		lift = value
		if _cam == null:
			return
		var span := maxf(rise_time, jolt_time)
		var j := _back_out(clampf(value * span / maxf(jolt_time, 0.001), 0.0, 1.0))
		var back := 1.0 - j
		_cam.position = (_eye0 + _toward * lean_distance * back
			+ Vector3(0.0, lean_lift * back + jolt_rise * j + head_lift * value, 0.0))
		_cam.rotation_degrees.x = _pitch0 - lean_pitch * back + jolt_pitch * j


## The book coming up off the desk and standing on its spine, pages toward the
## player. It has been lying flat for the whole game; standing it up is what
## makes it an object with intent rather than a prop.
var book_rise := 0.0:
	set(value):
		book_rise = value
		if _book == null:
			return
		_book.position.y = _book_y0 + rise_height * value
		_book.rotation.y = _face_yaw * value
		_book.rotation.x = deg_to_rad(-rise_tilt) * value


## Giving ground. move_and_collide rather than a position write, because the
## study has a desk and a wall in it.
var retreat := 0.0:
	set(value):
		retreat = value
		var body := _player as CharacterBody3D
		if body != null:
			body.move_and_collide(-_away * (retreat_distance * value))


## The focus sink. PlayerController hands every event to whatever holds focus
## and DROPS focus outright if the holder cannot take it, which would give the
## controls back in the middle of the sequence.
func handle_focus_input(_event: InputEvent) -> void:
	pass


# --------------------------------------------------------------------- blast

func _blast() -> void:
	_blast_eye0 = _cam.position
	if _book != null:
		_book_lift_y0 = _book.position.y

	# Thrown backwards. move_and_collide by hand rather than a track on the
	# position, because the study has a wall behind the desk and a straight
	# interpolation would put the player inside it.
	_back_dir = -(_player.global_transform.basis.z as Vector3)
	_back_dir.y = 0.0
	_back_dir = _back_dir.normalized()

	_anim.play(&"blast")
	await _anim.animation_finished


## The climb to where it goes off. THE PAUSE AFTER IT IS THE TRICK -- nothing
## moves and nothing is loud, and the player has just enough time to wonder
## whether that was all of it. That pause is the gap between this track ending
## and the `_go_off` key.
var book_lift := 0.0:
	set(value):
		book_lift = value
		if _book != null:
			_book.position.y = _book_lift_y0 + lift_height * value


## Off their feet. Over the top and down: the eye pitches up as they leave the
## floor, then drops as they land.
var throw := 0.0:
	set(value):
		throw = value
		if _cam == null:
			return
		var body := _player as CharacterBody3D
		if body != null:
			body.move_and_collide(-_back_dir * (throw_distance * value))
		_cam.rotation_degrees.z = roll_degrees * value
		_cam.position = _blast_eye0 + Vector3(0.0, -drop_height * value * value, 0.0)


## The book going off, and the page light in ABSOLUTE watts rather than as a
## ramp between two ends: a flash that overshoots to 34 and burns down to
## nothing is a shape, and a shape belongs in keyframes.
var flare := 0.0:
	set(value):
		flare = value
		if _book == null or not _flaring:
			return
		var light := _book.get_node_or_null("PageLight") as OmniLight3D
		if light != null:
			light.light_energy = value


## It goes off.
func _go_off() -> void:
	_flaring = true
	_player.flash(Color(1, 0.94, 0.82, 1), 0.04, 0.12, 1.1)
	if _book != null:
		_burst()


## Out cold. The picture goes before the movement has quite finished, which is
## what makes it read as losing consciousness rather than as a cut.
func _black() -> void:
	_player.fade_out(black_out, "")


func _burst() -> void:
	# The book's own emitters, turned up and thrown outward. Reusing them rather
	# than spawning a new system means the burst comes from exactly where the
	# glow has been coming from all along.
	for _name: String in ["Motes", "Embers"]:
		var p := _book.get_node_or_null(_name) as GPUParticles3D
		if p == null:
			continue
		p.amount_ratio = 1.0
		p.emitting = true
		var mat := p.process_material as ParticleProcessMaterial
		if mat != null:
			mat = mat.duplicate() as ParticleProcessMaterial
			mat.gravity = Vector3.ZERO
			mat.radial_accel_min = 26.0
			mat.radial_accel_max = 54.0
			mat.initial_velocity_min = 8.0
			mat.initial_velocity_max = 18.0
			p.process_material = mat
		p.restart()
	# The flare itself is the `flare` track in the "blast" animation -- a
	# light curve is exactly the kind of thing that belongs in the animator,
	# and it used to be two chained tweens here.


# -------------------------------------------------------------------- absorb

func _absorb() -> void:
	_absorb_eye0 = _cam.position
	_fov0 = _cam3.fov if _cam3 != null else 75.0
	_after_whiteout = false
	_after_spit = false
	_spin = randf_range(-1.0, 1.0)

	# INTO THE PAGES, NOT AT THE FLOOR UNDER THEM. The book's origin sits at its
	# base, so aiming the pull at global_position drags the eye toward a point
	# below the open pages and the player goes under the book rather than into
	# it. The page light is the thing actually glowing, so that is the target.
	#
	# And ALL THE WAY, as a fraction of the real gap rather than a fixed number
	# of metres. Measured, the book was 2.77 m off when the pull began and the
	# old flat 0.85 m left the player still 1.92 m short when the screen went
	# white -- pulled a little, then teleported, which is not the same thing as
	# being swallowed.
	_travel_to = (_page_point() - _cam.global_position) * pull_fraction

	_anim.play(&"absorb")
	await _anim.animation_finished


## Dragged toward the pages, with the view narrowing as it goes. A camera that
## only moves reads as walking; one that narrows reads as being pulled.
var pull := 0.0:
	set(value):
		pull = value
		if _cam == null:
			return
		_cam.position = _absorb_eye0 + _travel_to * value
		if _cam3 != null:
			_cam3.fov = _fov0 - 26.0 * value
		# The tunnel bleeds in underneath before the flash, so the white-out
		# resolves INTO something rather than arriving at it.
		_tunnel_amount = value * 0.35
		_player.tunnel(_tunnel_amount, 0.0)


## Down the tunnel. Travel accelerates, so it feels like falling rather than
## being carried.
##
## ONE WRITER. `pull` owns the tunnel until the white-out, so this keeps its
## hands off until then -- otherwise its first frame would slam the tunnel to
## full while the camera is still being dragged in.
var tunnel_run := 0.0:
	set(value):
		tunnel_run = value
		if not _after_whiteout:
			return
		_player.tunnel(1.0, tunnel_travel * value * value)


## And the tunnel clearing once they are through it.
var tunnel_clear := 0.0:
	set(value):
		tunnel_clear = value
		if not _after_spit:
			return
		_player.tunnel(1.0 - value, tunnel_travel)


## Falling, tumbling. Ends on the ground and cuts hard -- no slow fade, because
## hitting the ground is not a gentle event.
var fall := 0.0:
	set(value):
		fall = value
		if not _after_spit or _cam == null:
			return
		_player.global_position = exit_point.lerp(
			exit_point - Vector3(0.0, exit_point.y - 1.2, 0.0), value)
		_cam.rotation_degrees.z = 55.0 * _spin * value
		_cam.rotation_degrees.x = -40.0 * value


func _absorb_begin() -> void:
	_glow_to(11.0)
	_inrush = _make_inrush()


## The white-out. Long hold: this is the cut, and everything behind it changes
## while the screen is white.
func _whiteout() -> void:
	_player.flash(Color(1, 1, 1, 1), 0.12, 0.35, 1.4)
	if _inrush != null:
		_inrush.emitting = false
	_glow_to(0.0)
	_after_whiteout = true


## Spat out over the woods. The player is moved before the tunnel clears, so
## the change of place happens behind the effect.
func _spit_out() -> void:
	_player.global_position = exit_point
	if _cam3 != null:
		_cam3.fov = _fov0
	_cam.position = _absorb_eye0
	_after_spit = true


func _land() -> void:
	_player.tunnel(0.0, 0.0)
	_player.fade_out(0.18, "")


## The particles that stream into the pages. Made here rather than authored on
## the book, because they are emitted around the PLAYER and pulled inward -- it
## is the room coming apart, not the book giving something off.
func _make_inrush() -> GPUParticles3D:
	if _book == null:
		return null
	var p := GPUParticles3D.new()
	p.amount = 420
	p.lifetime = 1.5
	p.explosiveness = 0.0
	p.randomness = 0.8
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-14, -14, -14), Vector3(28, 28, 28))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 7.0
	mat.gravity = Vector3.ZERO
	# Negative radial acceleration is the whole effect: everything falls toward
	# the point the emitter is standing on, which is the book.
	mat.radial_accel_min = -22.0
	mat.radial_accel_max = -40.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 1.5
	mat.scale_min = 0.5
	mat.scale_max = 1.6
	mat.color = Color(1.0, 0.82, 0.45)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.78, 0.36, 0.0))
	ramp.set_color(1, Color(1.0, 0.96, 0.82, 1.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex
	p.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.vertex_color_use_as_albedo = true
	look.albedo_color = Color(1, 1, 1, 1)
	quad.material = look
	p.draw_pass_1 = quad

	_book.add_child(p)
	p.emitting = true
	return p


# --------------------------------------------------------------------- both

## Winds the page light and the emitters up over `over` seconds, which is the
## shared build-up: whichever way it goes, the book gets brighter first.
## Aims the page light at `to`. The ramp itself is a `glow` track in the
## animation; this only says where it is heading, so a key can start a flare or
## a burn-out without anything here knowing how long it takes.
func _glow_to(to: float) -> void:
	_glow_from = _glow_now()
	_glow_target = to
	if _book == null:
		return
	for _name: String in ["Motes", "Embers"]:
		var p := _book.get_node_or_null(_name) as GPUParticles3D
		if p != null:
			p.amount_ratio = 1.0
			p.emitting = true


func _glow_now() -> float:
	if _book == null:
		return 0.0
	var light := _book.get_node_or_null("PageLight") as OmniLight3D
	return light.light_energy if light != null else 0.0


## The page light, written by the animation between whatever it was and
## whatever `_glow_to` last asked for.
##
## ONE WRITER. Once the book goes off, `flare` owns the light and this stands
## down -- otherwise the two would fight over light_energy every frame and the
## explosion would flicker back to a gentle glow.
var glow := 0.0:
	set(value):
		glow = value
		if _book == null or _flaring:
			return
		var light := _book.get_node_or_null("PageLight") as OmniLight3D
		if light != null:
			light.light_energy = lerpf(_glow_from, _glow_target, value)


## Black screen, then the next level -- or a clear message if there is not one
## yet, which is better than a silent nothing while it is being built.
func _leave() -> void:
	_running = false
	if next_level.is_empty() or not ResourceLoader.exists(next_level):
		push_warning("BookEnding: next_level is '%s', which does not exist. "
			% next_level + "Ending on black.")
		return
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(next_level)


## A timer that survives the tree being torn down mid-sequence, which happens
## whenever a test quits or the player alt-F4s during the fade.
func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


## Back-out easing, as a plain function.
##
## Needed because the flinch and the head-lift share one tween -- see the note
## in _approach -- so the flinch cannot get its overshoot from Tween.TRANS_BACK
## and has to compute it. Overshoots past 1 and settles back, which is what
## makes a recoil read as a recoil rather than as a slide.
func _back_out(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var t := x - 1.0
	return 1.0 + c3 * t * t * t + c1 * t * t


## Where the pages are, as opposed to where the book's origin is.
##
## The origin sits at the base of the book -- the emitters and the page light
## are all authored above it -- so anything that aims at global_position aims
## slightly under the pages. The page light is the glow the player has been
## walking towards all level, so flying into that is both correct and what it
## looks like.
func _page_point() -> Vector3:
	if _book == null:
		return Vector3.ZERO
	var light := _book.get_node_or_null("PageLight") as Node3D
	if light != null:
		return light.global_position
	return _book.global_position + Vector3(0.0, 0.2, 0.0)
