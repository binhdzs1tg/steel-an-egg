extends Control
## InventoryMenu
## Modal overlay showing the player's egg inventory. Each egg can be selected for hatching.

var bg_panel: Panel
var title_label: Label
var content_container: VBoxContainer
var close_button: Button
var stats_label: Label


func _setup_ui() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_STOP

        bg_panel = Panel.new()
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

        title_label = Label.new()
        title_label.text = "EGG INVENTORY"
        title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title_label.add_theme_font_size_override("font_size", 28)
        title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
        vbox.add_child(title_label)

        # Header bar with stats
        stats_label = Label.new()
        stats_label.name = "Stats"
        stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        stats_label.add_theme_font_size_override("font_size", 14)
        stats_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
        vbox.add_child(stats_label)

        # Scrollable list
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(900, 460)
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vbox.add_child(scroll)

        content_container = VBoxContainer.new()
        content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_container.add_theme_constant_override("separation", 6)
        scroll.add_child(content_container)

        close_button = Button.new()
        close_button.text = "Close (I)"
        close_button.custom_minimum_size = Vector2(200, 40)
        close_button.pressed.connect(func(): visible = false)
        vbox.add_child(close_button)

        GameManager.egg_inventory_changed.connect(refresh)


func refresh() -> void:
        for c in content_container.get_children():
                c.queue_free()
        var inv: Array = GameManager.get_egg_inventory()
        var cap: int = Economy.get_egg_storage_cap()
        if stats_label:
                stats_label.text = "%d / %d eggs (carry limit %d)" % [inv.size(), cap, cap]

        if inv.is_empty():
                var empty := Label.new()
                empty.text = "No eggs collected. Walk up to an egg in the world and press E."
                empty.add_theme_font_size_override("font_size", 16)
                empty.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
                content_container.add_child(empty)
                return

        for egg in inv:
                var rarity_info: Dictionary = DataRegistry.get_rarity_info(egg.get("rarity", "Common"))
                var style := StyleBoxFlat.new()
                style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
                style.corner_radius_top_left = 6
                style.corner_radius_top_right = 6
                style.corner_radius_bottom_left = 6
                style.corner_radius_bottom_right = 6
                style.border_width_left = 2
                style.border_width_right = 2
                style.border_width_top = 2
                style.border_width_bottom = 2
                style.border_color = Color.from_string(rarity_info.get("color", "#FFFFFF"), Color.WHITE)
                # PanelContainer gives the row an actual visible background
                # (the old bare Panel inside an HBox collapsed to zero size).
                var panel := PanelContainer.new()
                panel.add_theme_stylebox_override("panel", style)
                var inner := HBoxContainer.new()
                inner.add_theme_constant_override("separation", 16)
                panel.add_child(inner)

                var name_lbl := Label.new()
                name_lbl.text = "%s [%s]" % [egg.get("name", "Egg"), egg.get("rarity", "?")]
                name_lbl.add_theme_font_size_override("font_size", 16)
                name_lbl.add_theme_color_override("font_color", Color.from_string(rarity_info.get("color", "#FFFFFF"), Color.WHITE))
                name_lbl.custom_minimum_size = Vector2(500, 40)
                name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                inner.add_child(name_lbl)

                var value_lbl := Label.new()
                value_lbl.text = "Value $%d | Hatch %.0fs" % [int(egg.get("value", 0)), float(egg.get("hatch_time", 8.0))]
                value_lbl.add_theme_font_size_override("font_size", 13)
                value_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
                value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                value_lbl.custom_minimum_size = Vector2(280, 40)
                inner.add_child(value_lbl)

                var drop_btn := Button.new()
                drop_btn.text = "Drop"
                drop_btn.custom_minimum_size = Vector2(80, 32)
                drop_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                drop_btn.pressed.connect(_drop_egg.bind(egg.get("uid", "")))
                inner.add_child(drop_btn)

                content_container.add_child(panel)


func _drop_egg(uid: String) -> void:
        GameManager.remove_egg_from_inventory(uid)
        NotificationSystem.notify("Egg dropped", "info", 1.5)
