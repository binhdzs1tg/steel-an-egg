extends Node3D
class_name Treadmill
## The Treadmill at the base. Players run on it to gain Speed XP actively.
## Higher Treadmill upgrade levels = faster XP gain.
## Also passively generates XP (handled by Economy.tick).

var prompt_label: Label3D
var activation_area: Area3D
var is_being_used: bool = false
var use_time_left: float = 0.0
const USE_DURATION: float = 5.0  # seconds of XP burst per interact


func _ready() -> void:
	_build_nodes()


func _build_nodes() -> void:
	# Base platform
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(2.0, 0.2, 4.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	mat.roughness = 0.6
	base.mesh = base_mesh
	base.material_override = mat
	add_child(base)

	# Side rails
	for i in range(2):
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.2, 0.5, 4.0)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.8, 0.8, 0.85)
		rail.mesh = rail_mesh
		rail.material_override = rmat
		rail.position = Vector3(-1.0 + i * 2.0, 0.35, 0)
		add_child(rail)

	# Belt (animated texture-less; just a moving dark stripe)
	var belt := MeshInstance3D.new()
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(1.6, 0.05, 3.8)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.1, 0.1, 0.1)
	bmat.roughness = 0.9
	belt.mesh = belt_mesh
	belt.material_override = bmat
	belt.position = Vector3(0, 0.15, 0)
	belt.name = "Belt"
	add_child(belt)

	# Static body for player to stand on
	var static_body := StaticBody3D.new()
	var s_col := CollisionShape3D.new()
	var s_shape := BoxShape3D.new()
	s_shape.size = Vector3(2.0, 0.2, 4.0)
	s_col.shape = s_shape
	s_col.position = Vector3(0, 0.1, 0)
	static_body.add_child(s_col)
	add_child(static_body)

	# Activation area
	activation_area = Area3D.new()
	activation_area.name = "ActivationArea"
	var a_col := CollisionShape3D.new()
	var a_shape := BoxShape3D.new()
	a_shape.size = Vector3(2.0, 1.5, 4.0)
	a_col.shape = a_shape
	a_col.position = Vector3(0, 0.8, 0)
	activation_area.add_child(a_col)
	add_child(activation_area)
	activation_area.body_entered.connect(_on_body_entered)
	activation_area.body_exited.connect(_on_body_exited)

	# Prompt label
	prompt_label = Label3D.new()
	prompt_label.position = Vector3(0, 2.0, 0)
	prompt_label.pixel_size = 0.012
	prompt_label.font_size = 28
	prompt_label.outline_size = 6
	prompt_label.outline_modulate = Color.BLACK
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.text = "Treadmill"
	add_child(prompt_label)


func _process(delta: float) -> void:
	# Animate belt
	var belt := get_node_or_null("Belt")
	if belt:
		# Move a virtual stripe by adjusting belt position offset; simpler: just rotate via texture offset won't work without texture. Skip animation.
		pass
	# If player is on the treadmill and pressing forward, grant XP
	if is_being_used and use_time_left > 0:
		use_time_left -= delta
		var lvl := Economy.get_upgrade_level("treadmill")
		if lvl > 0:
			var xp_table: Array = [1, 2, 4, 7, 12, 20, 33, 55, 90, 150, 250, 415, 690, 1150, 1900, 3150, 5200, 8600, 14200, 23500]
			var xp_per_sec: int = 0
			if lvl - 1 < xp_table.size():
				xp_per_sec = int(xp_table[lvl - 1])
			else:
				xp_per_sec = int(xp_table[-1])
			# Triple XP when actively training
			Economy.add_speed_xp(int(xp_per_sec * 3.0 * delta))
	else:
		# Check if player is on it but didn't interact; show prompt
		pass
	if use_time_left <= 0:
		is_being_used = false
	# Update prompt
	if is_being_used:
		prompt_label.text = "TRAINING... %.1fs" % use_time_left
	else:
		var lvl := Economy.get_upgrade_level("treadmill")
		if lvl == 0:
			prompt_label.text = "Treadmill (Buy upgrade)"
		else:
			prompt_label.text = "Treadmill Lv.%d — [E] Train" % lvl


func get_prompt_text() -> String:
	var lvl := Economy.get_upgrade_level("treadmill")
	if lvl == 0:
		return "Buy Treadmill upgrade first"
	return "Train (+%d Speed XP/s)" % [3 * _get_xp_rate_for_level(lvl)]


func _get_xp_rate_for_level(lvl: int) -> int:
	var xp_table: Array = [1, 2, 4, 7, 12, 20, 33, 55, 90, 150, 250, 415, 690, 1150, 1900, 3150, 5200, 8600, 14200, 23500]
	if lvl - 1 < xp_table.size():
		return int(xp_table[lvl - 1])
	return int(xp_table[-1])


func interact(_player: Node) -> void:
	var lvl := Economy.get_upgrade_level("treadmill")
	if lvl == 0:
		NotificationSystem.notify("Buy Treadmill upgrade first!", "warning", 2.0)
		return
	is_being_used = true
	use_time_left = USE_DURATION
	NotificationSystem.notify("Training on Treadmill!", "info", 1.5)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		# Show hint
		pass


func _on_body_exited(body: Node) -> void:
	if body is Player:
		# Don't stop training when leaving; let timer run out
		pass
