# UpgradeMenu.gd
# Modal upgrade menu. Lists all upgrades from data, their current level, next cost,
# and a "Buy" button. Bigger menu covers center of screen.
extends Control

@onready var panel: Panel = $Panel
@onready var container: VBoxContainer = $Panel/ScrollContainer/VBox
@onready var title: Label = $Panel/Title
@onready var close_button: Button = $Panel/CloseButton
@onready var money_label: Label = $Panel/MoneyLabel

const ITEM_SCENE := preload("res://scenes/ui/UpgradeItem.tscn")


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close)
	Economy.money_changed.connect(func(_v): _update_money())


func show_menu() -> void:
	visible = true
	_build_items()
	_update_money()
	GameManager.pause_game()


func hide_menu() -> void:
	visible = false
	GameManager.resume_game()


func _update_money() -> void:
	money_label.text = "Số dư: %d $" % Economy.get_money()


func _build_items() -> void:
	# Clear existing items
	for c in container.get_children():
		c.queue_free()
	
	var upgrades: Dictionary = DataRegistry.get_all_upgrades()
	for uid in upgrades.keys():
		var u: Dictionary = upgrades[uid]
		var item: Control = ITEM_SCENE.instantiate()
		item.set_meta("upgrade_id", uid)
		container.add_child(item)
		# Hook up signals
		if item.has_signal("buy_pressed"):
			item.buy_pressed.connect(_on_item_buy_pressed)
		_refresh_item(item, uid)


func _refresh_item(item: Control, uid: String) -> void:
	var u: Dictionary = DataRegistry.get_upgrade(uid)
	var lvl: int = Economy.get_upgrade_level(uid)
	var cost: int = Economy.get_upgrade_cost(uid)
	var max_lvl: int = int(u["max_level"])
	item.set_data(uid, u.get("name", ""), u.get("description", ""), lvl, max_lvl, cost)


func _on_item_buy_pressed(uid: String) -> void:
	if Economy.buy_upgrade(uid):
		AudioManager.sfx_upgrade()
		NotificationSystem.success("Đã nâng cấp: %s" % DataRegistry.get_upgrade(uid).get("name", "?"))
		# Refresh all items (costs may have changed)
		for c in container.get_children():
			var meta: Variant = c.get_meta("upgrade_id", "")
			if meta != "":
				_refresh_item(c, meta)
		_update_money()
		# Special-case: if coop expansion increased, rebuild coop slots
		if uid == "coop_size":
			var base: Node = GameManager.get_world().get_base() if GameManager.get_world() != null else null
			if base != null and base.get_coop() != null and base.get_coop().has_method("_init_slots"):
				# Re-init coop slots WITHOUT losing existing pets
				# (handled by saving/loading in Coop.deserialize — we just expand capacity)
				pass
	else:
		AudioManager.sfx_error()
		NotificationSystem.warning("Không đủ tiền!")


func _on_close() -> void:
	AudioManager.sfx_ui_click()
	hide_menu()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("upgrade_menu"):
		hide_menu()
		get_viewport().set_input_as_handled()
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		hide_menu()
		get_viewport().set_input_as_handled()
