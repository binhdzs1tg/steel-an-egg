extends Control
## QuestMenu
## Lists quests, their availability, completion status, and CLAIM buttons.

var content_container: VBoxContainer


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
        vbox.custom_minimum_size = Vector2(900, 640)
        vbox.add_theme_constant_override("separation", 12)
        outer.add_child(vbox)

        var title := Label.new()
        title.text = "QUESTS"
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 28)
        title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
        vbox.add_child(title)

        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(900, 540)
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vbox.add_child(scroll)

        content_container = VBoxContainer.new()
        content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_container.add_theme_constant_override("separation", 8)
        scroll.add_child(content_container)

        var close_btn := Button.new()
        close_btn.text = "Close (Q)"
        close_btn.custom_minimum_size = Vector2(200, 40)
        close_btn.pressed.connect(func(): visible = false)
        vbox.add_child(close_btn)

        QuestSystem.quest_updated.connect(_on_quest_updated)
        QuestSystem.quest_claimed.connect(_on_quest_updated.bind(""))


func _on_quest_updated(_id: String, _completed: bool) -> void:
        if visible:
                refresh()


func refresh() -> void:
        for c in content_container.get_children():
                c.queue_free()
        var quests: Array = DataRegistry.get_quests()
        var states: Array = QuestSystem.get_quest_states()
        for i in range(quests.size()):
                var q: Dictionary = quests[i]
                var s: Dictionary = states[i] if i < states.size() else {}
                var available: bool = QuestSystem.is_quest_available(q["id"])
                var complete: bool = QuestSystem.is_quest_complete(q["id"])
                var claimed: bool = QuestSystem.is_quest_claimed(q["id"])
                _add_quest_row(q, s, available, complete, claimed)


func _add_quest_row(q: Dictionary, state: Dictionary, available: bool, complete: bool, claimed: bool) -> void:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.1, 0.12, 0.18, 0.9) if available else Color(0.08, 0.08, 0.1, 0.85)
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.content_margin_left = 12
        style.content_margin_right = 12
        style.content_margin_top = 6
        style.content_margin_bottom = 8
        if claimed:
                style.border_color = Color(0.3, 0.5, 0.3)
        elif complete:
                style.border_color = Color(1.0, 0.85, 0.3)
        elif available:
                style.border_color = Color(0.4, 0.6, 0.8)
        else:
                style.border_color = Color(0.3, 0.3, 0.3)
        # PanelContainer wraps the whole row so the styled background actually
        # surrounds the content (the old sibling Panel inside a VBox collapsed).

        var row := VBoxContainer.new()
        row.add_theme_constant_override("separation", 2)

        var name_box := HBoxContainer.new()
        name_box.add_theme_constant_override("separation", 16)
        row.add_child(name_box)

        var name_lbl := Label.new()
        name_lbl.text = q.get("name", q["id"])
        name_lbl.add_theme_font_size_override("font_size", 16)
        if not available:
                name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
        elif claimed:
                name_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
        elif complete:
                name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
        else:
                name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
        name_box.add_child(name_lbl)

        var status_lbl := Label.new()
        if claimed:
                status_lbl.text = "[CLAIMED]"
                status_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
        elif complete:
                status_lbl.text = "[READY TO CLAIM]"
                status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        elif available:
                status_lbl.text = "[IN PROGRESS]"
                status_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
        else:
                status_lbl.text = "[LOCKED]"
                status_lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
        status_lbl.add_theme_font_size_override("font_size", 13)
        name_box.add_child(status_lbl)

        var desc_lbl := Label.new()
        desc_lbl.text = q.get("description", "")
        desc_lbl.add_theme_font_size_override("font_size", 12)
        desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
        desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(desc_lbl)

        # Objectives
        var obj_text := ""
        for o in state.get("objectives", []):
                var t: String = o.get("type", "")
                var cur: int = int(o.get("current", 0))
                var tgt: int = int(o.get("target", 1))
                obj_text += "%s: %d/%d   " % [t.replace("_", " ").capitalize(), cur, tgt]
        var obj_lbl := Label.new()
        obj_lbl.text = obj_text
        obj_lbl.add_theme_font_size_override("font_size", 11)
        obj_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
        row.add_child(obj_lbl)

        # Rewards + claim button on one line
        var rewards: Dictionary = q.get("rewards", {})
        var reward_text := "Rewards: "
        if rewards.has("money"):
                reward_text += "$%d  " % int(rewards["money"])
        if rewards.has("speed_xp"):
                reward_text += "+%d Speed XP" % int(rewards["speed_xp"])
        var reward_row := HBoxContainer.new()
        reward_row.add_theme_constant_override("separation", 16)
        var reward_lbl := Label.new()
        reward_lbl.text = reward_text
        reward_lbl.add_theme_font_size_override("font_size", 12)
        reward_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5))
        reward_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        reward_row.add_child(reward_lbl)

        # Claim button
        if complete and not claimed:
                var claim_btn := Button.new()
                claim_btn.text = "CLAIM"
                claim_btn.custom_minimum_size = Vector2(100, 32)
                claim_btn.pressed.connect(func(): QuestSystem.claim_quest(q["id"]))
                reward_row.add_child(claim_btn)
        row.add_child(reward_row)

        var panel := PanelContainer.new()
        panel.add_theme_stylebox_override("panel", style)
        panel.add_child(row)
        content_container.add_child(panel)
