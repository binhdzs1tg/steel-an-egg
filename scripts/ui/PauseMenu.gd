# PauseMenu.gd
# Pause menu: shows when player presses ESC. Has Resume, Save, Settings, Quit options.
extends Control

@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var title: Label = $Panel/Title


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume)
	save_button.pressed.connect(_on_save)
	quit_button.pressed.connect(_on_quit)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_on_resume()
		else:
			show_menu()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	visible = true
	GameManager.pause_game()
	AudioManager.sfx_ui_click()


func hide_menu() -> void:
	visible = false
	GameManager.resume_game()


func _on_resume() -> void:
	AudioManager.sfx_ui_click()
	hide_menu()


func _on_save() -> void:
	AudioManager.sfx_ui_click()
	if SaveSystem.save_game():
		NotificationSystem.success("Game đã được lưu!")
	else:
		NotificationSystem.error("Lỗi khi lưu game!")


func _on_quit() -> void:
	AudioManager.sfx_ui_click()
	# Save before quitting
	SaveSystem.save_game()
	get_tree().quit()
