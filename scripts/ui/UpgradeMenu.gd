extends Control
## UpgradeMenu
## Lists all upgrades with their current level, cost, and a BUY button.

var content_container: VBoxContainer
var title_label: Label


func _setup_ui() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_STOP

        var bg_panel := Panel.new()
        bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        var bg_style := StyleBoxFlat.new()
        bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
        bg_panel.add_theme_stylebox_override("panel", bg_style)
        add_child(bg_panel)

        var outer := CenterContainer.new()
        outer.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(outer)

        var vbox := VBoxContainer.new()
        vbox.custom_minimum_size = Vector2(900, 600)
        vbox.add_theme_constant_override("separation", 12)
        outer.add_child(vbox)

        var title := Label.new()
        title.text = "UPGRADES  (Money: $%s)" % _fmt(Economy.get_money())
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 26)
        title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
        title.name = "Title"
        vbox.add_child(title)
        title_label = title

        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(900, 500)
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vbox.add_child(scroll)

        content_container = VBoxContainer.new()
        content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_container.add_theme_constant_override("separation", 8)
        scroll.add_child(content_container)

        var close_btn := Button.new()
        close_btn.text = "Close (U)"
        close_btn.custom_minimum_size = Vector2(200, 40)
        close_btn.pressed.connect(func(): visible = false)
        vbox.add_child(close_btn)

        Economy.money_changed.connect(_on_money_changed)
        Economy.upgrade_purchased.connect(refresh)


func _on_money_changed(_amount: int) -> void:
        if visible:
                refresh()


func refresh() -> void:
        for c in content_container.get_children():
                c.queue_free()
        # Update title with money
        if title_label:
                title_label.text = "UPGRADES  (Money: $%s)" % _fmt(Economy.get_money())
        # PERF FIX: use the cached DataRegistry accessor instead of re-opening
        # and re-parsing upgrades.json from disk on every refresh.
        var u: Dictionary = DataRegistry.get_all_upgrade_defs()
        for upgrade_id in u.keys():
                var def: Dictionary = u[upgrade_id]
                _add_upgrade_row(upgrade_id, def)


func _add_upgrade_row(upgrade_id: String, def: Dictionary) -> void:
        var level := Economy.get_upgrade_level(upgrade_id)
        var max_level := int(def.get("max_level", 1))
        var cost := Economy.get_upgrade_cost(upgrade_id)
        var can_afford := Economy.get_money() >= cost
        var is_max := level >= max_level

        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.content_margin_left = 12
        style.content_margin_top = 6
        style.content_margin_bottom = 6
        style.border_color = Color(0.3, 0.7, 0.5) if can_afford else Color(0.3, 0.3, 0.3)

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 16)

        var name_box := VBoxContainer.new()
        name_box.custom_minimum_size = Vector2(380, 50)
        row.add_child(name_box)

        var name_lbl := Label.new()
        name_lbl.text = def.get("name", upgrade_id)
        name_lbl.add_theme_font_size_override("font_size", 16)
        name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
        name_box.add_child(name_lbl)

        var desc_lbl := Label.new()
        desc_lbl.text = def.get("description", "")
        desc_lbl.add_theme_font_size_override("font_size", 12)
        desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
        name_box.add_child(desc_lbl)

        var level_lbl := Label.new()
        level_lbl.text = "Lv.%d/%d" % [level, max_level]
        level_lbl.add_theme_font_size_override("font_size", 14)
        level_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
        level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        level_lbl.custom_minimum_size = Vector2(120, 50)
        row.add_child(level_lbl)

        var cost_lbl := Label.new()
        cost_lbl.text = "$%s" % _fmt(cost) if not is_max else "MAX"
        cost_lbl.add_theme_font_size_override("font_size", 14)
        cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4) if can_afford else Color(0.6, 0.4, 0.4))
        cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cost_lbl.custom_minimum_size = Vector2(160, 50)
        row.add_child(cost_lbl)

        var buy_btn := Button.new()
        buy_btn.text = "MAX" if is_max else ("BUY" if can_afford else "Locked")
        buy_btn.disabled = is_max or not can_afford
        buy_btn.custom_minimum_size = Vector2(100, 36)
        buy_btn.pressed.connect(func(): Economy.purchase_upgrade(upgrade_id))
        row.add_child(buy_btn)

        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", style)
        panel.add_child(row)
        content_container.add_child(panel)


func _fmt(n: int) -> String:
        if n < 1000:
                return str(n)
        if n < 1_000_000:
                return "%.2fK" % (float(n) / 1000.0)
        if n < 1_000_000_000:
                return "%.2fM" % (float(n) / 1_000_000.0)
        return "%.2fB" % (float(n) / 1_000_000_000.0)
