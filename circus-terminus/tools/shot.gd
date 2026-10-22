extends Node
## Loads a scene, optionally drops a camera at SHOT_CAM looking at SHOT_AT,
## lets it settle and writes a PNG.
##
## The opening cutscene is removed first: it takes the camera and fades to
## black, so every shot of the level came out as a black frame with "[Space]
## skip" in the corner.

var _frames := 0
var _camera: Camera3D
## Held down every frame by SHOT_STAMINA rather than set once. Setting it in
## _ready does not survive to the capture: the shot waits fifty frames and the
## first of those are slow enough that physics runs several seconds of catch-up
## in them, which is long enough for the tank to refill and the bar to hide
## itself again -- correctly.
var _player: Node
## Held every frame, like SHOT_STAMINA, because the HUD is redrawn constantly.
var _tunnel := Vector2.ZERO

func _ready() -> void:
	var ps: PackedScene = load(OS.get_environment("SHOT_SCENE"))
	var scene := ps.instantiate()
	add_child(scene)

	# Anything that opens on black and takes the camera. Both the arrival
	# cutscene and the circus wake-up do, so every shot of either level came out
	# as a black frame until they were freed.
	for blocker: String in ["Intro", "WakeUp"]:
		var node := scene.get_node_or_null(blocker)
		if node != null:
			node.free()

	# SHOT_STAMINA drains the player's tank before the shot, so the stamina bar
	# is actually on screen. It is hidden at a full one, which is right in play
	# and useless for looking at it.
	if OS.get_environment("SHOT_STAMINA") != "":
		_player = scene.get_node_or_null("Player")
		if _player != null:
			_player.end_focus()
			# The HUD starts hidden and Intro._hand_over is what reveals it, so
			# freeing the intro above leaves every shot of the interface empty.
			var hud := _player.get_node_or_null("CanvasLayer")
			if hud != null:
				hud.visible = true

			# SHOT_TUNNEL=<amount>,<travel> holds the cutscene tunnel on screen so
			# a shader nobody can unit-test can at least be looked at.
			var tun := OS.get_environment("SHOT_TUNNEL")
			if tun != "":
				var bits := tun.split(",")
				_tunnel = Vector2(float(bits[0]), float(bits[1]))

			# SHOT_ITEM puts something in the player's hand, so the held-item
			# corner has something to draw.
			var want := OS.get_environment("SHOT_ITEM")
			if want != "":
				var data := load("res://Items/%s.tres" % want) as Resource
				if data != null:
					_player.get_node("Inventory").add(data)

	var cam := OS.get_environment("SHOT_CAM")
	if cam == "":
		return
	var p := cam.split(",")
	var t := OS.get_environment("SHOT_AT").split(",")
	_camera = Camera3D.new()
	var fov := OS.get_environment("SHOT_FOV")
	_camera.fov = float(fov) if fov != "" else 60.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	_camera.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)

	# SHOT_LIGHT=1 clips a lamp to the camera. The cellar and the pit are
	# genuinely pitch black at night, which is right for the game and useless
	# for looking at geometry.
	if OS.get_environment("SHOT_LIGHT") != "":
		var lamp := OmniLight3D.new()
		lamp.light_energy = 12.0
		lamp.omni_range = 26.0
		_camera.add_child(lamp)

## SHOT_DROP=<seconds> throws every wall switch in the scene and then waits
## that long before capturing, so the falling door can be photographed
## mid-collapse with its dust up. Without it the only picture of the biggest
## thing in the level is of it standing still.
var _dropped := false
var _drop_wait := 0.0


func _process(delta: float) -> void:
	if OS.get_environment("SHOT_DROP") != "" and not _dropped:
		_dropped = true
		_drop_wait = float(OS.get_environment("SHOT_DROP"))
		# Interactable.interact() speaks to the player, so it needs a real one.
		var who := get_tree().get_first_node_in_group("player")
		for node in get_tree().get_nodes_in_group("interactable"):
			if node is Lever and not (node as Lever).targets.is_empty():
				(node as Lever).interact(who)
	if _drop_wait > 0.0:
		_drop_wait -= delta
		_frames = 0
		return

	_frames += 1
	if _player != null:
		_player.set_stamina(float(OS.get_environment("SHOT_STAMINA")))
		if _tunnel != Vector2.ZERO:
			_player.tunnel(_tunnel.x, _tunnel.y)
	if _camera != null:
		_camera.current = true
	if _frames < 50:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	print("SHOT written")
	get_tree().quit()
