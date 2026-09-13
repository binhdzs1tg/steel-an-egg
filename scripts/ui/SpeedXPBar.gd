extends Control
## SpeedXPBar
## A small floating bar at the bottom-center of the screen showing Speed XP progress.

var bg: Panel
var fill: ColorRect
var label: Label
var level_label: Label
var _fill_tween: Tween


func _setup_ui() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

        # Container at bottom-center
        var container := Control.new()
        container.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(container)

        # Speed icon label (left)
        level_label = Label.new()
        level_label.text = "SPD Lv.1"
        level_label.add_theme_font_size_override("font_size", 14)
        level_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
        level_label.add_theme_color_override("font_outline_color", Color.BLACK)
        level_label.add_theme_constant_override("outline_size", 4)
        level_label.position = Vector2(760, 678)
        container.add_child(level_label)

        # Background bar
        bg = Panel.new()
        bg.position = Vector2(830, 682)
        bg.size = Vector2(360, 18)
        var bg_style := StyleBoxFlat.new()
        bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
        bg_style.border_width_left = 1
        bg_style.border_width_right = 1
        bg_style.border_width_top = 1
        bg_style.border_width_bottom = 1
        bg_style.border_color = Color(0.3, 0.4, 0.5)
        bg_style.corner_radius_top_left = 4
        bg_style.corner_radius_top_right = 4
        bg_style.corner_radius_bottom_left = 4
        bg_style.corner_radius_bottom_right = 4
        bg.add_theme_stylebox_override("panel", bg_style)
        container.add_child(bg)

        # Fill bar (animated)
        fill = ColorRect.new()
        fill.position = Vector2(2, 2)
        fill.size = Vector2(0, 14)
        fill.color = Color(0.4, 0.85, 1.0)
        bg.add_child(fill)

        # Label showing XP numbers
        label = Label.new()
        label.text = "0 / 100 XP"
        label.add_theme_font_size_override("font_size", 11)
        label.add_theme_color_override("font_color", Color.WHITE)
        label.add_theme_color_override("font_outline_color", Color.BLACK)
        label.add_theme_constant_override("outline_size", 3)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.position = Vector2(0, 1)
        label.size = Vector2(360, 16)
        bg.add_child(label)

        # Hook signal
        Economy.speed_changed.connect(_on_speed_changed)
        _on_speed_changed(Economy.get_speed_level(), Economy.get_speed_xp(), Economy.get_speed_xp_needed())


func _on_speed_changed(level: int, xp: int, needed: int) -> void:
        if level_label:
                level_label.text = "SPD Lv.%d" % level
        if label:
                label.text = "%d / %d XP" % [xp, needed]
        if fill:
                var pct: float = float(xp) / float(max(1, needed))
                var target_w: float = max(0.0, pct * 356.0)
                # PERF FIX: reuse ONE tween. The old code created a new tween on
                # every signal (60x/s when speed XP was applied per-frame),
                # leaking dozens of live tweens and stuttering the UI.
                if _fill_tween and _fill_tween.is_valid():
                        _fill_tween.kill()
                _fill_tween = create_tween()
                _fill_tween.tween_property(fill, "size:x", target_w, 0.15)
