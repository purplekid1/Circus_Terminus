extends Node
## Autoload. Hangs the vision tag overlay on anything in a tagged group.
##
## Add objects to the groups "enemy", "items" or "interactable" and they show
## up through the lens as red / yellow / blue. Nothing else is needed; the
## overlay is invisible until the player raises the glass.
##
## Toggling vision itself lives in PlayerController, which owns the lens.

const TAGS := {
	"enemy": preload("res://Vision/tag_enemy.tres"),
	"items": preload("res://Vision/tag_item.tres"),
	"interactable": preload("res://Vision/tag_interactable.tres"),
}

## The key colour each tag writes for the lens to decode. One pure channel
## each: red -> enemy, green -> item, blue -> interactable. The lens maps
## those to the colours the player actually sees.
##
## These live here rather than as shader_parameter entries in the .tres files
## because the Godot editor re-saves ShaderMaterial resources from its own
## in-memory copy and has repeatedly stripped those entries, which silently
## dropped every tag back to the shader default and un-tagged the whole game.
## Code is the one place the editor cannot rewrite.
const TAG_KEYS := {
	"enemy": Vector3(1.0, 0.0, 0.0),
	"items": Vector3(0.0, 1.0, 0.0),
	"interactable": Vector3(0.0, 0.0, 1.0),
}


func _ready() -> void:
	_apply_keys()
	refresh_tags()
	# Re-tag whatever spawns later.
	get_tree().node_added.connect(_on_node_added)


## Tells every tag material where the lens is, as a screen-space ellipse:
## centre in .xy, radii in .zw, all in screen UV. Outside it the tags discard,
## which is what keeps their key colour from ever reaching the player's eye.
##
## Called by PlayerController each frame. Materials rather than a global
## uniform on purpose -- see the note in vision_tag.gdshader.
func set_lens(lens: Vector4) -> void:
	for material: ShaderMaterial in TAGS.values():
		material.set_shader_parameter("vision_lens", lens)


## Tag one node right now. A node that joins a tagged group in its own _ready
## is not in that group yet when node_added fires -- instantiation is strictly
## earlier -- so anything that tags itself from code has to come back and say
## so. Scene-declared groups do not need this; code-created ones do.
func tag(node: Node) -> void:
	for group in TAGS:
		if node.is_in_group(group):
			_apply(node, TAGS[group])
			return


func refresh_tags() -> void:
	for group in TAGS:
		for node in get_tree().get_nodes_in_group(group):
			_apply(node, TAGS[group])


func _apply_keys() -> void:
	for group in TAGS:
		(TAGS[group] as ShaderMaterial).set_shader_parameter("tag_key", TAG_KEYS[group])


func _on_node_added(node: Node) -> void:
	# ANYTHING DERIVING FROM Interactable IS ONE, whether or not the scene
	# remembered to say so.
	#
	# Group membership declared in a .tscn is lost every time a node is rebuilt
	# or the scene is re-saved by hand, and losing it is completely silent --
	# the thing simply stops appearing in the lens, with no error anywhere and
	# nothing in the source that looks wrong. Twenty-one of the mansion's
	# twenty-seven interactables were in the group and the stair debris was
	# not, which is exactly how that failure presents. Interactable._enter_tree
	# also does this; the two are deliberately redundant, because which of them
	# runs first is a Godot ordering detail and neither is expensive.
	if node is Interactable and not node.is_in_group("items") and not node.is_in_group("interactable"):
		node.add_to_group("interactable")

	for group in TAGS:
		if node.is_in_group(group):
			_apply(node, TAGS[group])
			return

	# GEOMETRY THAT TURNS UP LATE, under something already tagged.
	#
	# A pickup carries a placeholder box in its scene, and in _ready it throws
	# that away and instantiates the real item model. That happens strictly
	# after this signal fired for the pickup itself, so the model arrives with
	# no overlay and the item stops showing up in the lens -- fourteen meshes,
	# none of them tagged. Walking up to find a tagged ancestor catches that,
	# and every other case of a node building its own visuals.
	if node is GeometryInstance3D:
		var parent := node.get_parent()
		while parent != null:
			for group in TAGS:
				if parent.is_in_group(group):
					(node as GeometryInstance3D).material_overlay = TAGS[group]
					return
			parent = parent.get_parent()


# GeometryInstance3D, not MeshInstance3D: CSG shapes are the former but not
# the latter, so checking for MeshInstance3D silently skipped every CSG box.
func _apply(node: Node, material: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_overlay = material
	for child in node.get_children():
		_apply(child, material)
