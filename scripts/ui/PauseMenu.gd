extends CanvasLayer
## PauseMenu
## Full-screen overlay shown when the player presses Esc.
## Provides: Resume, Save, Settings, Reset Save, Quit.

var bg_panel: Panel
var title_label: Label
var save_button: Button
var settings_button: Button
var reset_button: Button
var quit_button: Button
var resume_button: Button

var settings_menu: Control


func _setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	var outer := CenterContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 480)
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)

	title_label = Label.new()
	title_label.text = "PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(title_label)

	resume_button = _make_button("Resume (Esc)", true)
	resume_button.pressed.connect(_on_resume)
	vbox.add_child(resume_button)

	save_button = _make_button("Save Game", false)
	save_button.pressed.connect(_on_save)
	vbox.add_child(save_button)

	settings_button = _make_button("Settings", false)
	settings_button.pressed.connect(_on_open_settings)
	vbox.add_child(settings_button)

	reset_button = _make_button("Reset Save (Danger)", false)
	reset_button.pressed.connect(_on_reset_save)
	reset_button.modulate = Color(1, 0.6, 0.6)
	vbox.add_child(reset_button)

	quit_button = _make_button("Quit to Desktop", false)
	quit_button.pressed.connect(_on_quit)
	vbox.add_child(quit_button)

	# Build the settings menu as a sibling (initially hidden)
	settings_menu = preload("res://scripts/ui/SettingsMenu.gd").new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)
	settings_menu._setup_ui()
	settings_menu.visible = false


func _make_button(text: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 44)
	btn.add_theme_font_size_override("font_size", 16)
	if primary:
		btn.modulate = Color(1.0, 0.95, 0.7)
	return btn


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_on_resume()


func _on_resume() -> void:
	AudioManager.play_sfx("ui_click")
	if settings_menu and settings_menu.visible:
		settings_menu.visible = false
	visible = false
	get_tree().paused = false


func _on_save() -> void:
	AudioManager.play_sfx("upgrade_buy")
	SaveSystem.force_save()
	NotificationSystem.notify("Game saved!", "info", 1.5)


func _on_open_settings() -> void:
	AudioManager.play_sfx("ui_click")
	if settings_menu:
		settings_menu.visible = true
		settings_menu.refresh()


func _on_reset_save() -> void:
	AudioManager.play_sfx("damage")
	# Confirmation via simple two-tap: change label
	if reset_button.text == "Reset Save (Danger)":
		reset_button.text = "Click again to confirm reset"
		reset_button.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(reset_button):
			reset_button.text = "Reset Save (Danger)"
			reset_button.modulate = Color(1, 0.6, 0.6)
	else:
		SaveSystem.delete_save()
		NotificationSystem.notify("Save reset. Restart game.", "warning", 3.0)
		# Reload the scene
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_quit() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().paused = false
	get_tree().quit()


func _on_pause_toggled(paused: bool) -> void:
	visible = paused
	if paused:
		get_tree().paused = true
