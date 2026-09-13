# Main.gd
# Top-level scene controller. Instantiates world, HUD, pause menu, upgrade menu.
# Handles input that affects game-wide state.
extends Node2D

@onready var world: Node2D = $World
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: Control = $PauseMenu
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# Hook up player signals when player is registered
	await get_tree().process_frame
	var p: Node2D = GameManager.get_player()
	if p != null:
		p.near_interactable.connect(_on_player_near_interactable)
		p.left_interactable.connect(_on_player_left_interactable)
	# Position camera on player
	_update_camera()


func _process(_delta: float) -> void:
	_update_camera()


func _update_camera() -> void:
	var p: Node2D = GameManager.get_player()
	if p == null:
		return
	# Smooth follow
	var target: Vector2 = p.position
	target.y -= 80.0  # camera offset slightly above player
	camera.position = camera.position.lerp(target, 0.15)
	camera.zoom = Vector2(1.0, 1.0)


func _on_player_near_interactable(prompt: String, _target: Node) -> void:
	hud.show_prompt(prompt)


func _on_player_left_interactable() -> void:
	hud.hide_prompt()


# ---------- Input ----------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrade_menu"):
		# Toggle upgrade menu via HUD button
		var menu := hud.get_node_or_null("Root/UpgradeMenu")
		if menu != null:
			if menu.visible:
				menu.hide_menu()
			else:
				menu.show_menu()
