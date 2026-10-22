extends RefCounted
## A little 3D view of one carried item, lit and framed from the item's own
## settings.
##
## This is here because two places need the same picture: the journal's
## inventory grid, and the "in hand" corner of the HUD. It was written for the
## journal first and lifted out when the HUD needed it -- an item has to look
## the same in the book as it does in your hand, and two copies of the framing
## code would drift the first time anyone touched one of them.
##
## The framing comes off ItemData: icon_distance, icon_yaw, icon_pitch and
## icon_lift. They are per item because a crowbar and a key do not read at the
## same distance or the same angle.

## An empty view: its own little world with a camera, two lights and a holder
## to hang the model on. `own_world_3d` matters -- without it the item is lit
## by the night sky of the level and comes out black.
static func make(view_size: Vector2) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = view_size
	container.size = view_size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.size = view_size
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.disable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = 35.0
	camera.near = 0.01
	camera.far = 12.0
	viewport.add_child(camera)

	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.light_energy = 2.4
	key.light_color = Color(1.0, 0.95, 0.86)
	key.rotation_degrees = Vector3(-38, -42, 0)
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = 0.7
	fill.light_color = Color(0.68, 0.76, 0.95)
	fill.rotation_degrees = Vector3(-14, 128, 0)
	viewport.add_child(fill)

	var holder := Node3D.new()
	holder.name = "Holder"
	viewport.add_child(holder)

	return container


## Points the view's camera at an item and puts its model under the holder.
## Returns the holder when `spin` is asked for, so the caller can turn it.
## `distance_scale` pulls the camera back without touching the item's own
## settings. Those are tuned against the journal's cells; the HUD corner is
## smaller, and a crowbar framed for the book runs straight out of it.
static func show_item(container: SubViewportContainer, item: ItemData,
		spin: bool, distance_scale := 1.0) -> Node3D:
	var viewport := container.get_child(0) as SubViewport
	var holder := viewport.get_node("Holder") as Node3D
	var camera := viewport.get_node("Camera") as Camera3D

	for child in holder.get_children():
		child.queue_free()

	if item == null or item.model == null:
		container.visible = false
		return null
	container.visible = true

	var model := item.model.instantiate() as Node3D
	# Lift the model so its mass, not its base, sits on the camera's axis.
	model.position = Vector3(0.0, -item.icon_lift, 0.0)
	holder.add_child(model)

	holder.rotation = Vector3(0.0, deg_to_rad(item.icon_yaw), 0.0)

	var pitch := deg_to_rad(item.icon_pitch)
	var dist: float = item.icon_distance * distance_scale
	camera.position = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)

	return holder if spin else null
