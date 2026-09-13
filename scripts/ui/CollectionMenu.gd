extends Control
## CollectionMenu
## Shows the Pet Index, Size Index, Mutation Index, and Biome Index with progress bars.

var bg_panel: Panel
var content_container: VBoxContainer
var close_button: Button


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
        vbox.custom_minimum_size = Vector2(900, 640)
        vbox.add_theme_constant_override("separation", 12)
        outer.add_child(vbox)

        var title := Label.new()
        title.text = "COLLECTION INDEX"
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 28)
        title.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
        vbox.add_child(title)

        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(900, 540)
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vbox.add_child(scroll)

        content_container = VBoxContainer.new()
        content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_container.add_theme_constant_override("separation", 24)
        scroll.add_child(content_container)

        close_button = Button.new()
        close_button.text = "Close (C)"
        close_button.custom_minimum_size = Vector2(200, 40)
        close_button.pressed.connect(func(): visible = false)
        vbox.add_child(close_button)

        Collection.collection_updated.connect(refresh)


func refresh() -> void:
        for c in content_container.get_children():
                c.queue_free()

        # Pet Index
        _add_section_header("PET INDEX", Collection.get_pet_index_progress())
        var all_pets: Dictionary = DataRegistry.get_all_pets()
        var discovered_pets: Array = Collection.get_pet_collection()
        for pet_id in all_pets.keys():
                var pet: Dictionary = all_pets[pet_id]
                var is_discovered: bool = pet_id in discovered_pets
                _add_pet_row(pet, is_discovered)

        # Size Index
        _add_section_header("SIZE INDEX", Collection.get_size_index_progress())
        for size_name in ["Tiny", "Small", "Normal", "Large", "Huge", "Titanic"]:
                var is_discovered: bool = Collection.has_size(size_name) or size_name == "Normal"
                var info: Dictionary = DataRegistry.get_size_info(size_name)
                _add_attribute_row(size_name, "x%.2f" % float(info.get("multiplier", 1.0)), info.get("color", "#FFFFFF"), is_discovered)

        # Mutation Index
        _add_section_header("MUTATION INDEX", Collection.get_mutation_index_progress())
        for mut_name in ["Normal", "Golden", "Diamond", "Rainbow", "Shadow", "Galaxy", "Void"]:
                var is_discovered: bool = Collection.has_mutation(mut_name) or mut_name == "Normal"
                var info: Dictionary = DataRegistry.get_mutation_info(mut_name)
                _add_attribute_row(mut_name, "x%.2f" % float(info.get("multiplier", 1.0)), info.get("color", "#FFFFFF"), is_discovered)

        # Biome Index
        _add_section_header("BIOME INDEX", {"discovered": GameManager.get_data().get("unlocked_biomes", []).size(), "total": 8})
        var biomes: Dictionary = DataRegistry.get_all_biomes()
        var unlocked: Array = GameManager.get_data().get("unlocked_biomes", [])
        for biome_id in biomes.keys():
                var biome: Dictionary = biomes[biome_id]
                var is_unlocked: bool = biome_id in unlocked
                _add_biome_row(biome, is_unlocked)


func _add_section_header(title_text: String, progress: Dictionary) -> void:
        var container := VBoxContainer.new()
        container.add_theme_constant_override("separation", 6)
        content_container.add_child(container)
        var header := HBoxContainer.new()
        header.add_theme_constant_override("separation", 16)
        container.add_child(header)
        var h := Label.new()
        h.text = title_text
        h.add_theme_font_size_override("font_size", 20)
        h.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
        header.add_child(h)
        var p := Label.new()
        p.text = "%d / %d" % [int(progress.get("discovered", 0)), int(progress.get("total", 0))]
        p.add_theme_font_size_override("font_size", 16)
        p.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
        header.add_child(p)


func _add_pet_row(pet: Dictionary, is_discovered: bool) -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        row.custom_minimum_size = Vector2(860, 32)
        var name_text: String = pet.get("name", "???") if is_discovered else "??? (undiscovered)"
        var rarity: String = pet.get("rarity", "Common")
        var rarity_info: Dictionary = DataRegistry.get_rarity_info(rarity)
        var color := Color.from_string(rarity_info.get("color", "#FFFFFF"), Color.WHITE)
        if not is_discovered:
                color = color.darkened(0.6)
        var name_lbl := Label.new()
        name_lbl.text = "%s [%s]" % [name_text, rarity if is_discovered else "?"]
        name_lbl.add_theme_font_size_override("font_size", 14)
        name_lbl.add_theme_color_override("font_color", color)
        name_lbl.custom_minimum_size = Vector2(500, 28)
        name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(name_lbl)
        var income_text := "+$%d/s" % int(pet.get("base_income", 0)) if is_discovered else "???"
        var income_lbl := Label.new()
        income_lbl.text = income_text
        income_lbl.add_theme_font_size_override("font_size", 13)
        income_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
        income_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(income_lbl)
        content_container.add_child(row)


func _add_attribute_row(name_str: String, multiplier_text: String, color_hex: String, is_discovered: bool) -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        row.custom_minimum_size = Vector2(860, 28)
        var color := Color.from_string(color_hex, Color.WHITE)
        if not is_discovered:
                color = Color(0.3, 0.3, 0.3)
        var swatch := ColorRect.new()
        swatch.color = color
        swatch.custom_minimum_size = Vector2(24, 24)
        row.add_child(swatch)
        var name_lbl := Label.new()
        name_lbl.text = "???" if not is_discovered else name_str
        name_lbl.add_theme_font_size_override("font_size", 14)
        name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
        name_lbl.custom_minimum_size = Vector2(400, 28)
        name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(name_lbl)
        var mult_lbl := Label.new()
        mult_lbl.text = multiplier_text if is_discovered else "???"
        mult_lbl.add_theme_font_size_override("font_size", 13)
        mult_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
        mult_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(mult_lbl)
        content_container.add_child(row)


func _add_biome_row(biome: Dictionary, is_unlocked: bool) -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        row.custom_minimum_size = Vector2(860, 32)
        var name_text: String = biome.get("name", "???")
        var required: int = int(biome.get("required_speed", 0))
        var name_lbl := Label.new()
        name_lbl.text = "%s — %s" % [name_text, ("UNLOCKED" if is_unlocked else "Requires Speed %d" % required)]
        name_lbl.add_theme_font_size_override("font_size", 14)
        name_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if is_unlocked else Color(0.85, 0.6, 0.6))
        name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(name_lbl)
        content_container.add_child(row)
