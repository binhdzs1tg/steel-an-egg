# HUD.gd
# Top-level UI overlay: shows Speed, Money, Day, prompts, minimap, control hints.
extends CanvasLayer

@onready var speed_label: Label = $Root/BottomBar/SpeedPanel/SpeedValue
@onready var money_label: Label = $Root/BottomBar/MoneyPanel/MoneyValue
@onready var day_label: Label = $Root/TopBar/DayLabel
@onready var prompt_label: Label = $Root/Center/PromptLabel
@onready var chase_indicator: Label = $Root/Center/ChaseIndicator
@onready var carry_indicator: Label = $Root/TopBar/CarryIndicator
@onready var run_button: Button = $Root/BottomBar/RunButton
@onready var upgrade_button: Button = $Root/TopBar/UpgradeButton
@onready var minimap: Control = $Root/Minimap

var _is_running: bool = false


func _ready() -> void:
	NotificationSystem.set_root($Root)
	Economy.money_changed.connect(_on_money_changed)
	Economy.income_tick.connect(_on_income_tick)
	GameManager.day_tick.connect(_on_day_tick)
	GameManager.carried_egg_changed.connect(_on_carried_egg_changed)
	GameManager.game_state_changed.connect(_on_game_state_changed)

	run_button.pressed.connect(_on_run_button_pressed)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)

	# Update once at start
	_update_speed_label()
	_update_money_label()
	_update_day_label()

	prompt_label.visible = false
	chase_indicator.visible = false


func _process(_delta: float) -> void:
	_update_speed_label()
	# Show run button state
	run_button.modulate = Color(1, 1, 1, 1.0 if _is_running else 0.5)


func _update_speed_label() -> void:
	var p: Node2D = GameManager.get_player()
	if p == null:
		return
	var v: float = p.get_current_speed()
	speed_label.text = "%d" % int(v)


func _update_money_label() -> void:
	money_label.text = "%d $" % Economy.get_money()


func _update_day_label() -> void:
	day_label.text = "Ngày %d" % GameManager.current_day


func _on_money_changed(_new: int) -> void:
	_update_money_label()


func _on_income_tick(_amount: int) -> void:
	# Subtle flash on money label
	_update_money_label()
	money_label.modulate = Color(0.7, 1.0, 0.7, 1.0)
	var t := create_tween()
	t.tween_property(money_label, "modulate", Color.WHITE, 0.3)


func _on_day_tick(day: int) -> void:
	_update_day_label()
	NotificationSystem.info("Ngày mới: Ngày %d" % day)


func _on_carried_egg_changed(egg_id: String) -> void:
	carry_indicator.visible = egg_id != ""
	if egg_id != "":
		var data: Dictionary = DataRegistry.get_egg(egg_id)
		carry_indicator.text = "🥚 Đang mang: %s" % data.get("name", "Trứng")
	else:
		carry_indicator.text = ""


func _on_game_state_changed(state: int) -> void:
	# Toggle chase indicator visibility
	chase_indicator.visible = (state == GameManager.GameState.CHASE or
		(state == GameManager.GameState.CARRYING and _has_nearby_chasing_guardian()))


func _has_nearby_chasing_guardian() -> bool:
	var p: Node2D = GameManager.get_player()
	if p == null:
		return false
	var guardians: Array = get_tree().get_nodes_in_group("guardian")
	for g in guardians:
		if g.has_method("get_state_name") and g.get_state_name() == "CHASE":
			return true
	return false


func _on_run_button_pressed() -> void:
	_is_running = not _is_running
	# We can't directly set is_running on player (it's input-driven), but we can hint
	AudioManager.sfx_ui_click()


func _on_upgrade_button_pressed() -> void:
	AudioManager.sfx_ui_click()
	# Show the upgrade menu
	var menu := $Root/UpgradeMenu
	menu.show_menu()


# ---------- Public API ----------
func show_prompt(text: String) -> void:
	if text == "":
		prompt_label.visible = false
		return
	prompt_label.text = text
	prompt_label.visible = true
	prompt_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(prompt_label, "modulate:a", 1.0, 0.15)


func hide_prompt() -> void:
	var t := create_tween()
	t.tween_property(prompt_label, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): prompt_label.visible = false)


func show_chase_warning() -> void:
	chase_indicator.visible = true
	chase_indicator.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(chase_indicator, "modulate:a", 1.0, 0.2)


func hide_chase_warning() -> void:
	var t := create_tween()
	t.tween_property(chase_indicator, "modulate:a", 0.0, 0.2)
	t.tween_callback(func(): chase_indicator.visible = false)
