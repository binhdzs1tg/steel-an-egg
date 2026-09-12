extends Node3D
class_name PetVisual
## A purely visual representation of a Pet in the world.
## Built from primitive meshes based on the pet's `model_type`.
## Real pet data lives in GameManager.get_pets(); this is just for display.

var pet_data: Dictionary = {}
var model_type: String = "small_quad"
var base_color: Color = Color.WHITE
var scale_factor: float = 1.0
var mutation_color: Color = Color.WHITE
var size_scale: float = 1.0
var main_mesh: MeshInstance3D


func _ready() -> void:
	_build()


func set_pet_data(data: Dictionary) -> void:
	pet_data = data
	model_type = data.get("model_type", "small_quad")
	base_color = Color.from_string(data.get("color", "#FFFFFF"), Color.WHITE)
	scale_factor = float(data.get("scale", 1.0))
	mutation_color = Color.from_string(data.get("mutation_color", "#FFFFFF"), Color.WHITE)
	size_scale = float(data.get("size_scale", 1.0))
	if main_mesh == null:
		await ready
	_apply_visuals()


func _build() -> void:
	main_mesh = MeshInstance3D.new()
	add_child(main_mesh)
	_apply_visuals()


func _apply_visuals() -> void:
	if main_mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.7
	# Mutation tint
	if mutation_color != Color.WHITE:
		mat.emission_enabled = true
		mat.emission = mutation_color
		mat.emission_energy_multiplier = 0.6
	# Build mesh based on model_type
	match model_type:
		"small_bird", "bird_large":
			var m := SphereMesh.new()
			m.radius = 0.35
			m.height = 0.7
			main_mesh.mesh = m
		"small_quad", "medium_quad":
			var m := BoxMesh.new()
			m.size = Vector3(0.7, 0.5, 1.0)
			main_mesh.mesh = m
		"large_quad":
			var m := BoxMesh.new()
			m.size = Vector3(1.0, 0.8, 1.4)
			main_mesh.mesh = m
		"snake":
			var m := CapsuleMesh.new()
			m.radius = 0.25
			m.height = 2.0
			main_mesh.mesh = m
			main_mesh.rotation = Vector3(0, 0, PI / 2)
		"spirit":
			var m := SphereMesh.new()
			m.radius = 0.5
			m.height = 1.0
			main_mesh.mesh = m
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = base_color
			mat.albedo_color.a = 0.65
		"humanoid_small", "humanoid_large":
			var m := CapsuleMesh.new()
			m.radius = 0.35
			m.height = 1.4
			main_mesh.mesh = m
		"dragon":
			var m := BoxMesh.new()
			m.size = Vector3(1.2, 1.0, 2.0)
			main_mesh.mesh = m
		"small_bug":
			var m := BoxMesh.new()
			m.size = Vector3(0.5, 0.3, 0.7)
			main_mesh.mesh = m
		_:
			var m := SphereMesh.new()
			m.radius = 0.4
			main_mesh.mesh = m
	main_mesh.material_override = mat
	# Apply size_scale (combines pet base scale + size multiplier from DataRegistry)
	var final_scale := scale_factor * size_scale
	scale = Vector3(final_scale, final_scale, final_scale)


func _process(_delta: float) -> void:
	# Idle bob
	if main_mesh:
		main_mesh.position.y = 0.5 + sin(Time.get_ticks_msec() * 0.003) * 0.05
		main_mesh.rotation.y += _delta * 0.5
