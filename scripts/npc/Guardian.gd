# Guardian.gd
# Enemy AI: patrols around its biome until an egg is stolen, then chases the player.
# If close enough, attacks (causes player to drop egg).
# Returns to patrol if player escapes chase_radius.
extends CharacterBody2D

signal guardian_chase_started(guardian_id: String)
signal guardian_chase_ended(guardian_id: String)
signal guardian_attacked(guardian_id: String)

@export var guardian_id: String = ""
@export var patrol_center: Vector2 = Vector2.ZERO
@export var patrol_radius: float = 200.0

enum State { IDLE, PATROL, CHASE, RETURN, STUNNED }

var _data: Dictionary = {}
var _state: int = State.PATROL
var _stun_timer: float = 0.0
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_wait: float = 0.0
var _chase_lost_timer: float = 0.0
const CHASE_LOSE_TIME := 2.0

@onready var sprite: Polygon2D = $BodySprite
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var state_label: Label = $StateLabel


func _ready() -> void:
	add_to_group("guardian")
	_data = DataRegistry.get_guardian(guardian_id)
	if _data.is_empty():
		push_error("[Guardian] No data for id: %s" % guardian_id)
		return
	_apply_visual()
	if patrol_center == Vector2.ZERO:
		patrol_center = position
	_pick_new_patrol_target()
	attack_area.body_entered.connect(_on_attack_body_entered)


func _apply_visual() -> void:
	var color: Color = DataRegistry.color_from_hex(_data.get("color", "#ff0000"))
	var size: float = float(_data.get("size", 30)) * 0.5
	sprite.color = color
	sprite.polygon = _make_blob_polygon(size)
	# Eye
	var eye: Polygon2D = $Eye
	if eye != null:
		eye.color = DataRegistry.color_from_hex(_data.get("beak_color", "#ffffff"))
	# Update detection radius
	var dr: float = float(_data.get("detection_radius", 220))
	if detection_area != null:
		for c in detection_area.get_children():
			if c is CollisionShape2D and c.shape is CircleShape2D:
				(c.shape as CircleShape2D).radius = dr
	# Update attack radius
	var ar: float = float(_data.get("attack_radius", 30))
	if attack_area != null:
		for c in attack_area.get_children():
			if c is CollisionShape2D and c.shape is CircleShape2D:
				(c.shape as CircleShape2D).radius = ar
	# Hide state label by default
	if state_label != null:
		state_label.visible = false


func _physics_process(delta: float) -> void:
	if GameManager.is_paused():
		return

	if _state == State.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_state = State.PATROL
			_pick_new_patrol_target()
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		return

	var player: Node2D = GameManager.get_player()
	if player == null:
		return

	var to_player: Vector2 = player.position - position
	var dist: float = to_player.length()

	match _state:
		State.PATROL:
			_patrol_state(delta, dist, to_player)
		State.CHASE:
			_chase_state(delta, dist, to_player)
		State.RETURN:
			_return_state(delta)

	move_and_slide()
	_update_visual_facing(to_player)


# ---------- State handlers ----------
func _patrol_state(delta: float, dist_to_player: float, to_player: Vector2) -> void:
	var chase_speed: float = float(_data.get("chase_speed", 140))
	# Detect player carrying egg nearby
	if GameManager.is_carrying_egg() and dist_to_player < float(_data.get("detection_radius", 220)):
		# Auto-chase if player is carrying egg within detection
		_start_chase()
		return
	# Move toward patrol target
	var to_target: Vector2 = _patrol_target - position
	if to_target.length() < 12.0:
		_patrol_wait -= delta
		if _patrol_wait <= 0.0:
			_pick_new_patrol_target()
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	else:
		var base_speed: float = float(_data.get("base_speed", 80))
		velocity = velocity.move_toward(to_target.normalized() * base_speed, 500.0 * delta)


func _chase_state(delta: float, dist_to_player: float, to_player: Vector2) -> void:
	var chase_radius: float = float(_data.get("chase_radius", 400))
	if dist_to_player > chase_radius:
		# Player escaped
		_chase_lost_timer += delta
		if _chase_lost_timer >= CHASE_LOSE_TIME:
			_end_chase()
		# Continue moving toward last known position
		velocity = velocity.move_toward(to_player.normalized() * float(_data.get("chase_speed", 140)) * 0.5, 700.0 * delta)
		return
	_chase_lost_timer = 0.0
	var chase_speed: float = float(_data.get("chase_speed", 140))
	velocity = velocity.move_toward(to_player.normalized() * chase_speed, 900.0 * delta)


func _return_state(delta: float) -> void:
	var to_center: Vector2 = patrol_center - position
	if to_center.length() < 24.0:
		_state = State.PATROL
		_pick_new_patrol_target()
		return
	var base_speed: float = float(_data.get("base_speed", 80))
	velocity = velocity.move_toward(to_center.normalized() * base_speed, 600.0 * delta)


# ---------- Combat ----------
func _on_attack_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _state == State.CHASE:
		if body.has_method("take_hit"):
			body.take_hit()
			guardian_attacked.emit(guardian_id)
			# Brief stun after attack
			_state = State.STUNNED
			_stun_timer = 1.0
			velocity = -velocity.normalized() * 100.0
			_end_chase()


# ---------- Chase control ----------
func _start_chase() -> void:
	if _state == State.CHASE:
		return
	_state = State.CHASE
	_chase_lost_timer = 0.0
	guardian_chase_started.emit(guardian_id)
	AudioManager.sfx_alert()


func _end_chase() -> void:
	if _state != State.CHASE:
		return
	_state = State.RETURN
	_chase_lost_timer = 0.0
	guardian_chase_ended.emit(guardian_id)


# Called by Egg when an egg in this guardian's biome is stolen
func on_egg_stolen(egg: Node) -> void:
	# Only react if the stolen egg is in our biome
	var egg_data: Dictionary = egg.get_egg_data() if egg.has_method("get_egg_data") else {}
	var egg_biome: String = egg_data.get("biome_id", "")
	var my_biome: String = _data.get("biome_id", "")
	if egg_biome != my_biome:
		return
	_start_chase()


# ---------- Patrol helpers ----------
func _pick_new_patrol_target() -> void:
	var angle: float = randf() * TAU
	var r: float = randf() * patrol_radius
	_patrol_target = patrol_center + Vector2(cos(angle), sin(angle)) * r
	_patrol_wait = randf_range(0.5, 2.0)


# ---------- Visuals ----------
func _update_visual_facing(to_player: Vector2) -> void:
	# Move eye toward player direction (a bit)
	if _state == State.CHASE:
		sprite.scale = Vector2(1.1, 1.1)
	else:
		sprite.scale = Vector2(1.0, 1.0)
	# Flip sprite based on velocity x
	if velocity.x < 0:
		sprite.scale.x = -abs(sprite.scale.x)
	elif velocity.x > 0:
		sprite.scale.x = abs(sprite.scale.x)


# ---------- Helpers ----------
func _make_blob_polygon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 12
	for i in range(n):
		var angle: float = TAU * float(i) / float(n)
		var r: float = radius * (1.0 + sin(angle * 3.0) * 0.08)
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts


func get_state_name() -> String:
	match _state:
		State.IDLE: return "IDLE"
		State.PATROL: return "PATROL"
		State.CHASE: return "CHASE"
		State.RETURN: return "RETURN"
		State.STUNNED: return "STUNNED"
		_: return "?"


# ---------- Save/Load ----------
func serialize() -> Dictionary:
	return {
		"guardian_id": guardian_id,
		"position": [position.x, position.y],
		"state": _state,
		"patrol_center": [patrol_center.x, patrol_center.y],
	}


func deserialize(data: Dictionary) -> void:
	var pos_arr: Array = data.get("position", [0, 0])
	position = Vector2(pos_arr[0], pos_arr[1])
	var pc_arr: Array = data.get("patrol_center", [0, 0])
	patrol_center = Vector2(pc_arr[0], pc_arr[1])
	_state = int(data.get("state", State.PATROL))
