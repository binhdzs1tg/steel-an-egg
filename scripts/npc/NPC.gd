extends CharacterBody3D
class_name NPC
## AI-controlled guardian that patrols, detects the player, chases, and attacks.
##
## States: IDLE -> PATROL -> DETECT -> CHASE -> ATTACK -> RETURN -> PATROL
## On hit: applies a temporary speed penalty to the player and pushes them back.
##
## PERF FIXES:
##   - Health/state Label3D text was re-assigned EVERY physics frame for EVERY
##     NPC (32 NPCs x 2 labels = 64 text-mesh regenerations per frame).
##     Labels now only update when the text actually changes, and hide
##     entirely when the NPC is far from the player.
##   - NPCs far from the player skip their AI state machine completely.
##   - A dead NPC used to keep running its AI while invisible; physics is now
##     disabled until respawn.

enum State { IDLE, PATROL, DETECT, CHASE, ATTACK, RETURN }

const STATE_NAMES: Array[String] = ["IDLE", "PATROL", "DETECT", "CHASE", "ATTACK", "RETURN"]
const FAR_DISTANCE: float = 90.0
const LABEL_VISIBILITY_DISTANCE: float = 60.0

var npc_id: String = ""
var npc_data: Dictionary = {}
var state: State = State.PATROL
var spawn_position: Vector3 = Vector3.ZERO
var patrol_target: Vector3 = Vector3.ZERO
var patrol_radius: float = 8.0
var detect_range: float = 12.0
var attack_range: float = 2.0
var attack_cooldown: float = 1.5
var speed: float = 10.0
var damage: int = 10
var hp: int = 100
var color: Color = Color(0.4, 0.5, 0.2)
var scale_factor: float = 1.0
var speed_penalty_on_hit: float = 0.5
var last_attack_time: float = 0.0
var detect_timer: float = 0.0

var body_mesh: MeshInstance3D
var health_bar: Label3D
var prompt_label: Label3D

var _last_health_text: String = ""
var _last_state_text: String = ""
var _labels_visible: bool = true


func _ready() -> void:
	_build_nodes()
	if not npc_id.is_empty():
		init_npc(npc_id)


func _build_nodes() -> void:
	# Body mesh (capsule)
	body_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.5, 0.2)
	mat.roughness = 0.8
	capsule.material = mat
	body_mesh.mesh = capsule
	body_mesh.position = Vector3(0, 0.9, 0)
	add_child(body_mesh)

	# Eyes (so the player can tell which way it faces)
	for i in range(2):
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.06
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color(1, 0.2, 0.2)
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(1, 0.2, 0.2)
		eye_mat.emission_energy_multiplier = 0.8
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(-0.15 + i * 0.3, 0.4, 0.35)
		body_mesh.add_child(eye)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	add_child(col)

	# Health bar (Label3D showing HP)
	var hb_label := Label3D.new()
	hb_label.name = "HealthBar"
	hb_label.position = Vector3(0, 2.2, 0)
	hb_label.pixel_size = 0.012
	hb_label.font_size = 28
	hb_label.outline_size = 6
	hb_label.outline_modulate = Color.BLACK
	hb_label.modulate = Color(1, 0.3, 0.3)
	hb_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(hb_label)
	health_bar = hb_label

	# State label
	prompt_label = Label3D.new()
	prompt_label.name = "StateLabel"
	prompt_label.position = Vector3(0, 2.6, 0)
	prompt_label.pixel_size = 0.012
	prompt_label.font_size = 24
	prompt_label.outline_size = 6
	prompt_label.outline_modulate = Color.BLACK
	prompt_label.modulate = Color(1, 1, 1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(prompt_label)


func init_npc(new_npc_id: String) -> void:
	npc_id = new_npc_id
	npc_data = DataRegistry.get_npc(npc_id)
	if npc_data.is_empty():
		push_warning("[NPC] No data for id: %s" % npc_id)
		return
	hp = int(npc_data.get("hp", 100))
	speed = float(npc_data.get("speed", 10))
	damage = int(npc_data.get("damage", 10))
	detect_range = float(npc_data.get("detect_range", 12))
	attack_range = float(npc_data.get("attack_range", 2))
	attack_cooldown = float(npc_data.get("attack_cooldown", 1.5))
	color = Color.from_string(npc_data.get("color", "#558B2F"), Color(0.4, 0.5, 0.2))
	scale_factor = float(npc_data.get("scale", 1.0))
	speed_penalty_on_hit = float(npc_data.get("speed_penalty", 0.5))
	# Apply visuals
	if body_mesh and body_mesh.mesh:
		var mat: StandardMaterial3D = body_mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = color
	scale = Vector3(scale_factor, scale_factor, scale_factor)
	spawn_position = position
	patrol_target = _random_patrol_point()
	_update_health_bar()


func _random_patrol_point() -> Vector3:
	var angle := randf() * TAU
	var r := randf() * patrol_radius
	return spawn_position + Vector3(cos(angle) * r, 0, sin(angle) * r)


func _physics_process(delta: float) -> void:
	if npc_data.is_empty():
		return
	var player_node := GameManager.player as Player
	if player_node == null:
		state = State.IDLE
		_update_state_label()
		return
	var to_player: Vector3 = player_node.global_position - global_position
	var dist: float = to_player.length()

	# Skip the whole AI state machine when the player is far away.
	if dist > FAR_DISTANCE:
		velocity = Vector3.ZERO
		_set_labels_visible(false)
		return
	_set_labels_visible(true)

	# State machine
	match state:
		State.IDLE:
			state = State.PATROL
			patrol_target = _random_patrol_point()
		State.PATROL:
			if dist < detect_range:
				state = State.DETECT
				detect_timer = 0.4
			else:
				_move_toward(patrol_target, speed * 0.4, delta)
				if global_position.distance_to(patrol_target) < 1.0:
					patrol_target = _random_patrol_point()
		State.DETECT:
			detect_timer -= delta
			# Stop briefly, "notice" player
			velocity = Vector3.ZERO
			if detect_timer <= 0:
				state = State.CHASE
		State.CHASE:
			if dist < attack_range:
				state = State.ATTACK
				last_attack_time = 0.0
			elif dist > detect_range * 1.5:
				state = State.RETURN
			else:
				_move_toward(player_node.global_position, speed, delta)
		State.ATTACK:
			if dist > attack_range * 1.2:
				state = State.CHASE
			else:
				last_attack_time += delta
				if last_attack_time >= attack_cooldown:
					last_attack_time = 0.0
					_perform_attack(player_node)
		State.RETURN:
			_move_toward(spawn_position, speed * 0.8, delta)
			if global_position.distance_to(spawn_position) < 1.0:
				state = State.PATROL
				patrol_target = _random_patrol_point()
			elif dist < detect_range:
				state = State.DETECT
				detect_timer = 0.4
	_update_health_bar()
	_update_state_label()
	move_and_slide()


func _set_labels_visible(visible_now: bool) -> void:
	if visible_now == _labels_visible:
		return
	_labels_visible = visible_now
	if health_bar:
		health_bar.visible = visible_now
	if prompt_label:
		prompt_label.visible = visible_now


func _move_toward(target: Vector3, move_speed: float, delta: float) -> void:
	var dir := (target - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	# Face direction
	if dir.length() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)


func _perform_attack(p: Node) -> void:
	# Push player back and apply speed penalty (visual: flash)
	AudioManager.play_sfx("damage")
	if p.has_method("apply_speed_penalty"):
		p.apply_speed_penalty(speed_penalty_on_hit, 1.0)
	else:
		# Fallback: just apply knockback
		var knockback: Vector3 = (p.global_position - global_position).normalized() * 8.0
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity += knockback
	NotificationSystem.notify("Hit by %s! -%d speed for 2s" % [npc_data.get("name", "Guardian"), damage], "damage", 1.5)
	# Spawn damage VFX on the player
	if GameManager.player:
		VFXBurst.spawn_at(GameManager.player.get_parent(), GameManager.player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.3), 25, 0.1, 3.0, 0.6)
	# Knockback
	if p is Player:
		var knockback2: Vector3 = (p.global_position - global_position)
		knockback2.y = 0
		knockback2 = knockback2.normalized() * 6.0
		p.velocity += knockback2


func _update_health_bar() -> void:
	if health_bar:
		var text := "%d HP" % hp
		if text != _last_health_text:
			_last_health_text = text
			health_bar.text = text


func _update_state_label() -> void:
	if prompt_label:
		var text := STATE_NAMES[state]
		if text != _last_state_text:
			_last_state_text = text
			prompt_label.text = text


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	_update_health_bar()
	if hp <= 0:
		# Respawn after delay
		_die()


func _die() -> void:
	visible = false
	state = State.IDLE
	hp = int(npc_data.get("hp", 100))
	position = spawn_position
	velocity = Vector3.ZERO
	# Stop AI while dead (previously kept patrolling invisibly).
	set_physics_process(false)
	# Respawn timer
	await get_tree().create_timer(20.0).timeout
	if not is_inside_tree():
		return
	visible = true
	set_physics_process(true)
