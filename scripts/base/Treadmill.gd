# Treadmill.gd
# Player stands on the treadmill to gain Speed XP over time.
# Each second on the treadmill grants +1 Speed XP. Every 100 XP = +1 speed level (refunds money cost).
extends Area2D

signal speed_xp_gained(amount: int)

const XP_PER_SECOND := 5.0
const COIN_PER_TICK := 1
const TICK_INTERVAL := 1.0

var _player_on: Node = null
var _xp_accumulator: float = 0.0
var _tick_timer: float = 0.0
var _on_treadmill: bool = false

@onready var body_sprite: Polygon2D = $BodySprite
@onready var belt_sprite: Polygon2D = $BeltSprite
@onready var prompt_label: Label = $PromptLabel
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("treadmill")
	prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _on_treadmill and _player_on != null and not GameManager.is_paused():
		_xp_accumulator += XP_PER_SECOND * delta
		_tick_timer += delta
		if _tick_timer >= TICK_INTERVAL:
			_tick_timer = 0.0
			_grant_speed_xp(int(_xp_accumulator))
			_xp_accumulator = 0.0
		# Visual feedback: belt scrolling
		belt_sprite.position.x = fmod(belt_sprite.position.x - 80.0 * delta, 40.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on = body
		_on_treadmill = true
		prompt_label.visible = true
		prompt_label.text = "Đang tập luyện... +Speed XP/s"
		NotificationSystem.info("Đang tập luyện tốc độ!")


func _on_body_exited(body: Node) -> void:
	if body == _player_on:
		_player_on = null
		_on_treadmill = false
		prompt_label.visible = false


func _grant_speed_xp(amount: int) -> void:
	# Each second of treadmill = small XP that auto-applies to speed_level when threshold met
	# For simplicity: grant money-based speed level upgrade indirectly:
	# Every 5 ticks (5 sec on treadmill) = +1 free speed_level upgrade slot
	# We simulate this by reducing the next speed_level cost by giving player coins
	Economy.add_money(COIN_PER_TICK * amount)
	speed_xp_gained.emit(amount)
	if amount > 0:
		AudioManager.sfx_step()


# ---------- Interaction API ----------
func get_interact_prompt(player: Node) -> String:
	return "ĐỨNG TRÊN MÁY CHẠY ĐỂ TĂNG SPEED"


func interact(player: Node) -> void:
	# Standing on it auto-applies XP, no interact needed
	NotificationSystem.info("Đứng trên máy chạy +Speed XP")
