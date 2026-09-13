extends RigidBody3D
class_name Egg
## An egg in the world. Players interact to pick up.
##
## Each egg instance references a template id from data/eggs.json.
## On pick-up: spawned egg -> inventory entry (with a UID).
##
## PERF FIX: the per-egg OmniLight3D was removed. With 50+ eggs in the world,
## 50 real-time point lights destroyed the fill-rate in the Forward+ renderer.
## Rarity glow is now conveyed purely through the emissive material.

signal collected(egg: Node)

@onready var mesh_instance: MeshInstance3D = null
@onready var prompt_label: Label3D = null
@onready var pickup_area: Area3D = null

var egg_id: String = ""
var egg_data: Dictionary = {}
var is_collected: bool = false
var bob_phase: float = 0.0
var _egg_mat: StandardMaterial3D = null


func _ready() -> void:
	_build_nodes()
	contact_monitor = true
	max_contacts_reported = 1
	gravity_scale = 0.0  # eggs float in place
	freeze = true  # static; we don't want physics bouncing
	bob_phase = randf() * TAU


func _build_nodes() -> void:
	# Egg mesh
	mesh_instance = MeshInstance3D.new()
	var egg_mesh := SphereMesh.new()
	egg_mesh.radius = 0.25
	egg_mesh.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.93, 0.7)
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.4, 0.2)
	mat.emission_energy_multiplier = 0.8
	egg_mesh.material = mat
	_egg_mat = mat
	mesh_instance.mesh = egg_mesh
	add_child(mesh_instance)

	# Prompt label
	prompt_label = Label3D.new()
	prompt_label.text = "[E] Collect Egg"
	prompt_label.position = Vector3(0, 0.6, 0)
	prompt_label.pixel_size = 0.012
	prompt_label.font_size = 28
	prompt_label.outline_size = 6
	prompt_label.outline_modulate = Color.BLACK
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.visible = false
	add_child(prompt_label)

	# Collision shape (small sphere)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	col.shape = shape
	add_child(col)

	# Pickup area (Area3D)
	pickup_area = Area3D.new()
	pickup_area.name = "PickupArea"
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 0.6
	area_col.shape = area_shape
	pickup_area.add_child(area_col)
	add_child(pickup_area)


func set_egg_id(new_egg_id: String) -> void:
	egg_id = new_egg_id
	egg_data = DataRegistry.get_egg(egg_id)
	if egg_data.is_empty():
		push_warning("[Egg] No data for id: %s" % egg_id)
		return
	# Apply color
	var color_str: String = egg_data.get("color", "#FFF3E0")
	var c := Color.from_string(color_str, Color(1, 0.93, 0.7))
	if _egg_mat:
		_egg_mat.albedo_color = c
		_egg_mat.emission = c * 0.4
	# Rarity glow via emissive material (no real lights — see PERF note above).
	var rarity: String = egg_data.get("rarity", "Common")
	var rarity_info: Dictionary = DataRegistry.get_rarity_info(rarity)
	if _egg_mat:
		if bool(rarity_info.get("glow", false)):
			_egg_mat.emission_energy_multiplier = 1.6
		else:
			_egg_mat.emission_energy_multiplier = 0.8


func _process(delta: float) -> void:
	# Bob and rotate
	bob_phase += delta * 2.0
	var bob := sin(bob_phase) * 0.08
	mesh_instance.position.y = 0.5 + bob
	mesh_instance.rotate_y(delta * 0.6)
	if prompt_label.visible:
		prompt_label.position.y = 0.9 + bob


func get_prompt_text() -> String:
	return "Collect %s" % egg_data.get("name", "Egg")


func interact(player: Node) -> void:
	if is_collected:
		return
	if not GameManager.can_carry_more_eggs():
		NotificationSystem.notify("EGG INVENTORY FULL", "warning", 2.0)
		return
	is_collected = true
	# Build inventory entry
	var entry := {
		"uid": "%s_%d" % [egg_id, Time.get_ticks_msec()],
		"egg_id": egg_id,
		"name": egg_data.get("name", "Egg"),
		"rarity": egg_data.get("rarity", "Common"),
		"value": int(egg_data.get("value", 0)),
		"hatch_time": float(egg_data.get("hatch_time", 8.0)),
		"pets": egg_data.get("pets", []),
		"mutation_chance": float(egg_data.get("mutation_chance", 0.0)),
		"size_special_chance": float(egg_data.get("size_special_chance", 0.0)),
		"color": egg_data.get("color", "#FFFFFF"),
	}
	GameManager.add_egg_to_inventory(entry)
	GameManager.set_carrying_egg(entry["uid"])
	NotificationSystem.notify("Egg Collected: %s" % entry["name"], "egg", 2.0)
	collected.emit(self)
	# Notify spawn point that this egg is gone
	var parent_node := get_parent()
	if parent_node and parent_node.has_method("_on_egg_taken"):
		parent_node._on_egg_taken()
	# Visual: hide and queue free
	visible = false
	queue_free()
