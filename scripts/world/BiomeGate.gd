extends Area3D
class_name BiomeGate
## A trigger zone that, when the player enters, attempts to switch the active biome.
## If the player's speed is insufficient, shows a "locked" message.

@export var biome_id: String = "grassland"
@export var is_exit: bool = false  # if true, reverts to previous biome

var _triggered: bool = false


func _ready() -> void:
	# Build visual gate (two posts + a beam)
	_build_visual()
	# Connect body_entered
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_visual() -> void:
	var biome: Dictionary = DataRegistry.get_biome(biome_id)
	var color_str: String = biome.get("ground_color", "#FFFFFF")
	var c := Color.from_string(color_str, Color.WHITE)

	# Two posts
	for i in range(2):
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.3, 3.5, 0.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c.darkened(0.3)
		post.mesh = post_mesh
		post.material_override = mat
		post.position = Vector3(-2.5 + i * 5.0, 1.75, 0)
		add_child(post)

	# Beam
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(5.6, 0.4, 0.3)
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = c.lightened(0.2)
	mat2.emission_enabled = true
	mat2.emission = c
	mat2.emission_energy_multiplier = 0.5
	beam.mesh = beam_mesh
	beam.material_override = mat2
	beam.position = Vector3(0, 3.5, 0)
	add_child(beam)

	# Sign
	var sign := Label3D.new()
	sign.text = biome.get("name", biome_id)
	sign.position = Vector3(0, 4.2, 0)
	sign.pixel_size = 0.02
	sign.font_size = 32
	sign.outline_size = 8
	sign.outline_modulate = Color.BLACK
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)

	# Required speed label (shown when locked)
	var req_label := Label3D.new()
	req_label.name = "RequiredSpeedLabel"
	req_label.position = Vector3(0, 0.8, 0)
	req_label.pixel_size = 0.015
	req_label.font_size = 24
	req_label.outline_size = 6
	req_label.outline_modulate = Color.BLACK
	req_label.modulate = Color(1.0, 0.6, 0.4)
	req_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(req_label)

	# Collision shape for Area3D
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 4.0, 1.5)
	col.shape = shape
	add_child(col)


func _process(_delta: float) -> void:
	# Update the required speed label dynamically
	var label_node := get_node_or_null("RequiredSpeedLabel")
	if label_node is Label3D:
		var biome: Dictionary = DataRegistry.get_biome(biome_id)
		var required: int = int(biome.get("required_speed", 0))
		var unlocked: bool = biome_id in GameManager.get_data().get("unlocked_biomes", [])
		if unlocked:
			(label_node as Label3D).text = "ENTER"
			(label_node as Label3D).modulate = Color(0.6, 1.0, 0.6)
		else:
			(label_node as Label3D).text = "LOCKED — Speed %d" % required
			(label_node as Label3D).modulate = Color(1.0, 0.5, 0.4)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		GameManager.enter_biome(biome_id)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_triggered = false
