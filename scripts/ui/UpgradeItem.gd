# UpgradeItem.gd
# A single upgrade row in the UpgradeMenu.
extends Control

signal buy_pressed(uid: String)

@onready var name_label: Label = $HBox/Info/NameLabel
@onready var desc_label: Label = $HBox/Info/DescLabel
@onready var level_label: Label = $HBox/LevelLabel
@onready var cost_label: Label = $HBox/BuyButton/CostLabel
@onready var buy_button: Button = $HBox/BuyButton


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)


func set_data(uid: String, display_name: String, description: String, level: int, max_level: int, cost: int) -> void:
	name_label.text = display_name
	desc_label.text = description
	level_label.text = "Lv %d / %d" % [level, max_level]
	if cost < 0:
		cost_label.text = "MAX"
		buy_button.disabled = true
		buy_button.text = "MAX"
	else:
		cost_label.text = "%d $" % cost
		buy_button.disabled = false
		buy_button.text = "Mua"
	set_meta("upgrade_id", uid)


func _on_buy_pressed() -> void:
	var uid: String = get_meta("upgrade_id", "")
	if uid != "":
		buy_pressed.emit(uid)
