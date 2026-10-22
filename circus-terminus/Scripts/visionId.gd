extends CSGBox3D

func _ready() -> void:
	if is_in_group("enemy"):
		material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.0, 1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if is_in_group("interactable"):
		material = StandardMaterial3D.new()
		material.albedo_color = Color(0.0, 1.0, 1.0, 1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if is_in_group("items"):
		material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 1.0, 0.0, 1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
