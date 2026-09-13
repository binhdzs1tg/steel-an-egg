extends Control
## SettingsMenu
## Volume sliders (music + SFX), camera shake toggle, effects quality dropdown, language select.

var bg_panel: Panel
var content: VBoxContainer
var close_button: Button

var music_slider: HSlider
var sfx_slider: HSlider
var music_value_label: Label
var sfx_value_label: Label
var camera_shake_check: CheckBox
var effects_quality_dropdown: OptionButton
var language_dropdown: OptionButton


func _setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.98)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	var outer := CenterContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 560)
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(title)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	vbox.add_child(content)

	# Music volume
	_add_section_label("Music Volume")
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 12)
	content.add_child(music_row)
	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.custom_minimum_size = Vector2(360, 24)
	music_slider.value_changed.connect(_on_music_changed)
	music_row.add_child(music_slider)
	music_value_label = Label.new()
	music_value_label.custom_minimum_size = Vector2(80, 24)
	music_value_label.add_theme_font_size_override("font_size", 13)
	music_value_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	music_row.add_child(music_value_label)

	# SFX volume
	_add_section_label("SFX Volume")
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 12)
	content.add_child(sfx_row)
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.custom_minimum_size = Vector2(360, 24)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(sfx_slider)
	sfx_value_label = Label.new()
	sfx_value_label.custom_minimum_size = Vector2(80, 24)
	sfx_value_label.add_theme_font_size_override("font_size", 13)
	sfx_value_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	sfx_row.add_child(sfx_value_label)

	# Camera shake
	_add_section_label("Camera Shake")
	camera_shake_check = CheckBox.new()
	camera_shake_check.toggled.connect(_on_camera_shake_toggled)
	content.add_child(camera_shake_check)

	# Effects quality
	_add_section_label("Effects Quality")
	effects_quality_dropdown = OptionButton.new()
	effects_quality_dropdown.add_item("Low")
	effects_quality_dropdown.add_item("Medium")
	effects_quality_dropdown.add_item("High")
	effects_quality_dropdown.item_selected.connect(_on_effects_quality_selected)
	content.add_child(effects_quality_dropdown)

	# Language
	_add_section_label("Language")
	language_dropdown = OptionButton.new()
	language_dropdown.add_item("Vietnamese (vi)")
	language_dropdown.add_item("English (en)")
	language_dropdown.item_selected.connect(_on_language_selected)
	content.add_child(language_dropdown)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(200, 36)
	close_button.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		visible = false)
	vbox.add_child(close_button)

	refresh()


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	content.add_child(label)


func refresh() -> void:
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	var mv: float = float(settings.get("music_volume", 0.7))
	var sv: float = float(settings.get("sfx_volume", 0.8))
	music_slider.set_value_no_signal(mv)
	sfx_slider.set_value_no_signal(sv)
	music_value_label.text = "%d%%" % int(mv * 100)
	sfx_value_label.text = "%d%%" % int(sv * 100)
	camera_shake_check.set_pressed_no_signal(bool(settings.get("camera_shake", true)))
	var eq: String = settings.get("effects_quality", "high")
	var eq_idx := 2 if eq == "high" else (1 if eq == "medium" else 0)
	effects_quality_dropdown.select(eq_idx)
	var lang: String = settings.get("language", "vi")
	language_dropdown.select(0 if lang == "vi" else 1)


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	music_value_label.text = "%d%%" % int(value * 100)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	sfx_value_label.text = "%d%%" % int(value * 100)
	# Play a click to preview
	AudioManager.play_sfx("ui_click")


func _on_camera_shake_toggled(enabled: bool) -> void:
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	settings["camera_shake"] = enabled
	data["settings"] = settings
	SaveSystem.mark_dirty()


func _on_effects_quality_selected(idx: int) -> void:
	var names := ["low", "medium", "high"]
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	settings["effects_quality"] = names[idx]
	data["settings"] = settings
	SaveSystem.mark_dirty()


func _on_language_selected(idx: int) -> void:
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	settings["language"] = "vi" if idx == 0 else "en"
	data["settings"] = settings
	SaveSystem.mark_dirty()
