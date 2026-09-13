extends Node3D
class_name PetDisplayArea
## A showcase area at the Base where the player's most valuable pets are visually displayed.
## Updates automatically when the player's pet inventory changes.
##
## PERF FIX: the display used to be REBUILT every second on a timer even when
## nothing changed (freeing and re-instantiating every PetVisual + Label3D).
## It is now signal-driven: rebuilds only when pet_inventory_changed fires.
## The visual build is synchronous — PetVisual._ready() already ran during
## add_child(), so no per-pet "await process_frame" is needed.

var display_pets: Array = []  # Array of PetVisual nodes
var display_radius: float = 4.0
var max_displayed: int = 6
var _refresh_queued: bool = false


func _ready() -> void:
	_build_platform()
	_build_sign()
	GameManager.pet_inventory_changed.connect(_on_pet_inventory_changed)
	# Initial refresh
	call_deferred("_refresh_display")


func _build_platform() -> void:
	var platform := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = display_radius + 1.0
	mesh.bottom_radius = display_radius + 1.0
	mesh.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.4)
	mat.roughness = 0.6
	platform.mesh = mesh
	platform.material_override = mat
	add_child(platform)


func _build_sign() -> void:
	var sign := Label3D.new()
	sign.text = "PET DISPLAY"
	sign.position = Vector3(0, 3.5, 0)
	sign.pixel_size = 0.018
	sign.font_size = 36
	sign.outline_size = 8
	sign.outline_modulate = Color.BLACK
	sign.modulate = Color(0.85, 0.7, 1.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


func _process(delta: float) -> void:
	# Rotate the display slowly (cheap — keep, it's the point of the showcase)
	rotation.y += delta * 0.1


func _on_pet_inventory_changed() -> void:
	# Coalesce multiple signals in the same frame into a single rebuild.
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_display")


func _refresh_display() -> void:
	_refresh_queued = false
	# Clear existing
	for p in display_pets:
		if is_instance_valid(p):
			p.queue_free()
	display_pets.clear()

	# Pick top pets by income (most valuable)
	var pets: Array = GameManager.get_pets()
	if pets.is_empty():
		return

	# Compute income per pet and sort
	var scored: Array = []
	for p in pets:
		var base: int = int(p.get("base_income", 0))
		var size_mult: float = float(DataRegistry.get_size_info(p.get("size", "Normal")).get("multiplier", 1.0))
		var mut_mult: float = float(DataRegistry.get_mutation_info(p.get("mutation", "Normal")).get("multiplier", 1.0))
		var lvl_mult: float = 1.0 + 0.2 * (int(p.get("level", 1)) - 1)
		var income: float = float(base) * size_mult * mut_mult * lvl_mult
		scored.append({"pet": p, "income": income})
	scored.sort_custom(_compare_scored)

	# Display top N
	var count: int = min(max_displayed, scored.size())
	for i in range(count):
		var p: Dictionary = scored[i]["pet"]
		var visual := PetVisual.new()
		var angle := TAU * float(i) / float(count)
		var radius := display_radius
		visual.position = Vector3(cos(angle) * radius, 0.8, sin(angle) * radius)
		add_child(visual)
		# _ready() ran during add_child, so main_mesh exists — safe to apply now.
		var visual_data := {
			"model_type": p.get("model_type", "small_quad"),
			"color": p.get("color", "#FFFFFF"),
			"scale": float(p.get("scale", 1.0)),
			"mutation_color": p.get("mutation_color", "#FFFFFF"),
			"size_scale": float(p.get("size_scale", 1.0)),
		}
		visual.set_pet_data(visual_data)
		# Add floating label
		var lbl := Label3D.new()
		var pet_name: String = p.get("name", "Pet")
		var rarity: String = p.get("rarity", "Common")
		var rarity_info: Dictionary = DataRegistry.get_rarity_info(rarity)
		lbl.text = "%s [%s]" % [pet_name, rarity]
		lbl.position = Vector3(0, 1.5, 0)
		lbl.pixel_size = 0.012
		lbl.font_size = 22
		lbl.outline_size = 5
		lbl.outline_modulate = Color.BLACK
		lbl.modulate = Color.from_string(rarity_info.get("color", "#FFFFFF"), Color.WHITE)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		visual.add_child(lbl)
		display_pets.append(visual)


func _compare_scored(a: Dictionary, b: Dictionary) -> bool:
	return float(a["income"]) > float(b["income"])
