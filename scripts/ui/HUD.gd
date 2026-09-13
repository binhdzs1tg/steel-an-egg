extends CanvasLayer
## HUD
## In-game heads-up display. Shows: money, speed level, current biome, egg inventory count,
## active pet slots, the activity log, and toast notifications.
## Also opens the Inventory / Collection / Upgrades / Quests menus on key press.

const NOTIFICATION_DURATION_DEFAULT: float = 2.5

var money_label: Label
var speed_label: Label
var biome_label: Label
var eggs_label: Label
var pets_label: Label
var crosshair_status_label: Label
var income_label: Label
var notification_container: VBoxContainer
var log_container: VBoxContainer
var mode_label: Label

var inventory_menu: Control
var collection_menu: Control
var upgrade_menu: Control
var quest_menu: Control
var crosshair: Control

var _notifications: Array = []


func _setup_ui() -> void:
        # Top bar (left): Money, Income, Speed, Biome
        var top_bar := HBoxContainer.new()
        top_bar.name = "TopBar"
        top_bar.position = Vector2(20, 20)
        top_bar.size = Vector2(800, 40)
        top_bar.add_theme_constant_override("separation", 24)
        add_child(top_bar)

        money_label = Label.new()
        money_label.name = "MoneyLabel"
        money_label.text = "$0"
        money_label.add_theme_font_size_override("font_size", 24)
        money_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
        money_label.add_theme_color_override("font_outline_color", Color.BLACK)
        money_label.add_theme_constant_override("outline_size", 6)
        top_bar.add_child(money_label)

        income_label = Label.new()
        income_label.text = "+0/s"
        income_label.add_theme_font_size_override("font_size", 18)
        income_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
        income_label.add_theme_color_override("font_outline_color", Color.BLACK)
        income_label.add_theme_constant_override("outline_size", 4)
        top_bar.add_child(income_label)

        speed_label = Label.new()
        speed_label.text = "SPD Lv.1"
        speed_label.add_theme_font_size_override("font_size", 18)
        speed_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
        speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
        speed_label.add_theme_constant_override("outline_size", 4)
        top_bar.add_child(speed_label)

        biome_label = Label.new()
        biome_label.text = "Grassland"
        biome_label.add_theme_font_size_override("font_size", 18)
        biome_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
        biome_label.add_theme_color_override("font_outline_color", Color.BLACK)
        biome_label.add_theme_constant_override("outline_size", 4)
        top_bar.add_child(biome_label)

        # Top-right: egg/pet counts
        var counts_box := HBoxContainer.new()
        counts_box.position = Vector2(700, 20)
        counts_box.size = Vector2(560, 40)
        counts_box.add_theme_constant_override("separation", 24)
        add_child(counts_box)

        eggs_label = Label.new()
        eggs_label.text = "Eggs: 0/5"
        eggs_label.add_theme_font_size_override("font_size", 18)
        eggs_label.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
        eggs_label.add_theme_color_override("font_outline_color", Color.BLACK)
        eggs_label.add_theme_constant_override("outline_size", 4)
        counts_box.add_child(eggs_label)

        pets_label = Label.new()
        pets_label.text = "Active Pets: 0/3"
        pets_label.add_theme_font_size_override("font_size", 18)
        pets_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
        pets_label.add_theme_color_override("font_outline_color", Color.BLACK)
        pets_label.add_theme_constant_override("outline_size", 4)
        counts_box.add_child(pets_label)

        # Camera mode indicator (bottom-left)
        mode_label = Label.new()
        mode_label.position = Vector2(20, 656)
        mode_label.text = "[3P Classic] Hold RMB to rotate | Shift to lock | Scroll in for 1P"
        mode_label.add_theme_font_size_override("font_size", 13)
        mode_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
        mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
        mode_label.add_theme_constant_override("outline_size", 4)
        add_child(mode_label)

        # Bottom-center: controls help (compact)
        var help_label := Label.new()
        help_label.position = Vector2(20, 678)
        help_label.text = "WASD Move | Space Jump | E Interact | I Inventory | C Collection | U Upgrades | Q Quests"
        help_label.add_theme_font_size_override("font_size", 12)
        help_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
        help_label.add_theme_color_override("font_outline_color", Color.BLACK)
        help_label.add_theme_constant_override("outline_size", 4)
        add_child(help_label)

        # Notification container (center-right, stacks downward)
        notification_container = VBoxContainer.new()
        notification_container.name = "Notifications"
        notification_container.position = Vector2(960, 80)
        notification_container.size = Vector2(300, 400)
        notification_container.add_theme_constant_override("separation", 8)
        add_child(notification_container)

        # Log container (bottom-left, above help)
        log_container = VBoxContainer.new()
        log_container.name = "Log"
        log_container.position = Vector2(20, 460)
        log_container.size = Vector2(380, 180)
        log_container.add_theme_constant_override("separation", 2)
        add_child(log_container)

        var log_title := Label.new()
        log_title.text = "Activity Log"
        log_title.add_theme_font_size_override("font_size", 14)
        log_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
        log_title.add_theme_color_override("font_outline_color", Color.BLACK)
        log_title.add_theme_constant_override("outline_size", 3)
        log_container.add_child(log_title)

        # Menus
        _build_menus()

        # Crosshair (centered, hidden by default — shown in shift-lock / 1P modes)
        crosshair = Control.new()
        crosshair.name = "Crosshair"
        crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
        crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
        crosshair.visible = false
        add_child(crosshair)
        # Build crosshair from 5 ColorRects (dot + 4 bars)
        var dot := ColorRect.new()
        dot.color = Color(1, 1, 1, 0.9)
        dot.size = Vector2(4, 4)
        dot.set_anchors_preset(Control.PRESET_CENTER)
        dot.position = Vector2(-2, -2)
        crosshair.add_child(dot)
        for i in range(4):
                var bar := ColorRect.new()
                bar.color = Color(1, 1, 1, 0.9)
                bar.size = Vector2(2, 10) if i in [0, 1] else Vector2(10, 2)
                bar.set_anchors_preset(Control.PRESET_CENTER)
                match i:
                        0: bar.position = Vector2(-1, -16)  # top
                        1: bar.position = Vector2(-1, 6)     # bottom
                        2: bar.position = Vector2(-16, -1)   # left
                        3: bar.position = Vector2(6, -1)     # right
                crosshair.add_child(bar)

        # Speed XP bar (bottom-center)
        var xp_bar_script: GDScript = preload("res://scripts/ui/SpeedXPBar.gd")
        var xp_bar: Control = xp_bar_script.new() as Control
        xp_bar.name = "SpeedXPBar"
        add_child(xp_bar)
        xp_bar._setup_ui()

        # Minimap (bottom-left, above log)
        var minimap_script: GDScript = preload("res://scripts/ui/Minimap.gd")
        var minimap: Control = minimap_script.new() as Control
        minimap.name = "Minimap"
        add_child(minimap)
        minimap._setup_ui()

        # Pause menu (Esc) - sibling CanvasLayer
        var pause_script: GDScript = preload("res://scripts/ui/PauseMenu.gd")
        var pause_menu: CanvasLayer = pause_script.new() as CanvasLayer
        pause_menu.name = "PauseMenu"
        pause_menu.visible = false
        add_child(pause_menu)
        pause_menu._setup_ui()

        # Hook signals
        Economy.money_changed.connect(_on_money_changed)
        Economy.speed_changed.connect(_on_speed_changed)
        Economy.pet_income_changed.connect(_on_income_changed)
        GameManager.biome_changed.connect(_on_biome_changed)
        GameManager.egg_inventory_changed.connect(_on_inventory_changed)
        GameManager.pet_inventory_changed.connect(_on_pet_inventory_changed)
        GameManager.player_ready.connect(_on_player_ready)
        Collection.collection_updated.connect(_on_inventory_changed)

        # If player was already spawned before HUD connected, hook it now
        if GameManager.player:
                _on_player_ready(GameManager.player)

        # Initial refresh
        _refresh_all()


func _build_menus() -> void:
        inventory_menu = preload("res://scripts/ui/InventoryMenu.gd").new()
        inventory_menu.name = "InventoryMenu"
        add_child(inventory_menu)
        inventory_menu._setup_ui()
        inventory_menu.visible = false

        collection_menu = preload("res://scripts/ui/CollectionMenu.gd").new()
        collection_menu.name = "CollectionMenu"
        add_child(collection_menu)
        collection_menu._setup_ui()
        collection_menu.visible = false

        upgrade_menu = preload("res://scripts/ui/UpgradeMenu.gd").new()
        upgrade_menu.name = "UpgradeMenu"
        add_child(upgrade_menu)
        upgrade_menu._setup_ui()
        upgrade_menu.visible = false

        quest_menu = preload("res://scripts/ui/QuestMenu.gd").new()
        quest_menu.name = "QuestMenu"
        add_child(quest_menu)
        quest_menu._setup_ui()
        quest_menu.visible = false


func _unhandled_input(event: InputEvent) -> void:
        if event.is_action_pressed("inventory"):
                _toggle_menu(inventory_menu)
        elif event.is_action_pressed("collection"):
                _toggle_menu(collection_menu)
        elif event.is_action_pressed("upgrades"):
                _toggle_menu(upgrade_menu)
        elif event.is_action_pressed("quests"):
                _toggle_menu(quest_menu)
        elif event.is_action_pressed("pause"):
                # Toggle pause menu
                var pause := get_node_or_null("PauseMenu")
                if pause:
                        if pause.visible:
                                pause._on_resume()
                        else:
                                _close_all_menus()
                                pause.visible = true
                                get_tree().paused = true
                                AudioManager.play_sfx("ui_click")


func _toggle_menu(menu: Control) -> void:
        var was_visible := menu.visible
        _close_all_menus()
        if not was_visible:
                menu.visible = true
                if menu.has_method("refresh"):
                        menu.refresh()


func _close_all_menus() -> void:
        if inventory_menu:
                inventory_menu.visible = false
        if collection_menu:
                collection_menu.visible = false
        if upgrade_menu:
                upgrade_menu.visible = false
        if quest_menu:
                quest_menu.visible = false


func _on_player_ready(_p: Node) -> void:
        if GameManager.player:
                GameManager.player.camera_mode_changed.connect(_on_camera_mode_changed)
                _on_camera_mode_changed(GameManager.player.camera_mode)


func _on_camera_mode_changed(mode: int) -> void:
        # Show crosshair only in shift-lock or first-person
        crosshair.visible = (mode == 1 or mode == 2)
        var text: String = ""
        match mode:
                0:  # THIRD_PERSON_CLASSIC
                        text = "[3P Classic] Hold RMB to rotate | Shift to lock | Scroll in for 1P"
                1:  # SHIFT_LOCK
                        text = "[Shift Lock] Mouse moves your facing | Release Shift to exit"
                2:  # FIRST_PERSON
                        text = "[1P First-Person] Scroll out to exit | Mouse to look"
        mode_label.text = text


# ---------- Refresh helpers ----------
func _refresh_all() -> void:
        _on_money_changed(Economy.get_money())
        _on_speed_changed(Economy.get_speed_level(), Economy.get_speed_xp(), Economy.get_speed_xp_needed())
        _on_income_changed(Economy.get_pet_income_per_second())
        _on_biome_changed(GameManager.current_biome_id)
        _on_inventory_changed()
        _on_pet_inventory_changed()


func _on_money_changed(amount: int) -> void:
        money_label.text = "$%s" % _format_number(amount)


func _on_speed_changed(level: int, xp: int, needed: int) -> void:
        speed_label.text = "SPD Lv.%d (%d/%d)" % [level, xp, needed]


func _on_income_changed(per_second: int) -> void:
        income_label.text = "+$%s/s" % _format_number(per_second)


func _on_biome_changed(biome_id: String) -> void:
        var biome: Dictionary = DataRegistry.get_biome(biome_id)
        biome_label.text = biome.get("name", biome_id)


func _on_inventory_changed() -> void:
        var count: int = GameManager.egg_inventory_count()
        var cap: int = Economy.get_egg_storage_cap()
        eggs_label.text = "Eggs: %d/%d" % [count, cap]


func _on_pet_inventory_changed() -> void:
        var active: int = GameManager.get_active_pets().size()
        var cap: int = Economy.get_active_pet_slots()
        pets_label.text = "Active Pets: %d/%d" % [active, cap]


# ---------- Notifications ----------
func show_notification(text: String, icon: String, duration: float) -> void:
        # Cap concurrent toasts: drop the oldest when flooding (previously the
        # container could stack unbounded and cover the screen).
        while notification_container.get_child_count() >= 6:
                var oldest := notification_container.get_child(0)
                notification_container.remove_child(oldest)
                oldest.queue_free()
        var toast := Panel.new()
        toast.custom_minimum_size = Vector2(280, 36)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
        style.corner_radius_top_left = 8
        style.corner_radius_top_right = 8
        style.corner_radius_bottom_left = 8
        style.corner_radius_bottom_right = 8
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_color = _icon_color(icon)
        toast.add_theme_stylebox_override("panel", style)
        notification_container.add_child(toast)

        var hbox := HBoxContainer.new()
        hbox.add_theme_constant_override("separation", 8)
        hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
        hbox.offset_left = 8
        hbox.offset_right = -8
        hbox.offset_top = 4
        hbox.offset_bottom = -4
        toast.add_child(hbox)

        var icon_label := Label.new()
        icon_label.text = _icon_text(icon)
        icon_label.add_theme_font_size_override("font_size", 18)
        hbox.add_child(icon_label)

        var msg_label := Label.new()
        msg_label.text = text
        msg_label.add_theme_font_size_override("font_size", 14)
        msg_label.add_theme_color_override("font_color", _icon_color(icon).lightened(0.2))
        msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
        msg_label.add_theme_constant_override("outline_size", 3)
        msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hbox.add_child(msg_label)

        # Auto-remove after duration
        var tween := create_tween()
        tween.tween_interval(duration)
        tween.tween_property(toast, "modulate:a", 0.0, 0.4)
        tween.tween_callback(toast.queue_free)


func _icon_color(icon: String) -> Color:
        match icon:
                "money": return Color(0.95, 0.85, 0.3)
                "egg": return Color(1, 0.85, 0.6)
                "pet": return Color(0.85, 0.6, 1.0)
                "speed": return Color(0.5, 0.85, 1.0)
                "upgrade": return Color(0.7, 1.0, 0.6)
                "warning": return Color(1.0, 0.5, 0.4)
                "locked": return Color(0.9, 0.4, 0.4)
                "unlock": return Color(0.4, 1.0, 0.6)
                "quest": return Color(1.0, 0.8, 0.4)
                "reward": return Color(1.0, 0.9, 0.5)
                "achievement": return Color(1.0, 0.85, 0.3)
                "damage": return Color(1.0, 0.3, 0.3)
                "info", _: return Color(0.85, 0.9, 1.0)


func _icon_text(icon: String) -> String:
        match icon:
                "money": return "$"
                "egg": return "E"
                "pet": return "P"
                "speed": return ">"
                "upgrade": return "+"
                "warning": return "!"
                "locked": return "X"
                "unlock": return "V"
                "quest": return "?"
                "reward": return "*"
                "achievement": return "T"
                "damage": return "*"
                _: return ">"


func add_log(text: String) -> void:
        var entry := Label.new()
        entry.text = "- %s" % text
        entry.add_theme_font_size_override("font_size", 11)
        entry.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
        entry.add_theme_color_override("font_outline_color", Color.BLACK)
        entry.add_theme_constant_override("outline_size", 3)
        log_container.add_child(entry)
        # Keep last 6 entries
        while log_container.get_child_count() > 7:  # 1 title + 6 entries
                var oldest := log_container.get_child(1)
                log_container.remove_child(oldest)
                oldest.queue_free()
        # Fade in
        entry.modulate.a = 0.0
        var t := create_tween()
        t.tween_property(entry, "modulate:a", 1.0, 0.2)


func _format_number(n: int) -> String:
        # 1,234,567 -> "1.23M"
        if n < 1000:
                return str(n)
        if n < 1_000_000:
                return "%.2fK" % (float(n) / 1000.0)
        if n < 1_000_000_000:
                return "%.2fM" % (float(n) / 1_000_000.0)
        return "%.2fB" % (float(n) / 1_000_000_000.0)
