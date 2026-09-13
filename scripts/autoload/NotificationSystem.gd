# NotificationSystem.gd
# Singleton that manages floating toast notifications shown to the player.
# Notifications are queued and shown one at a time, sliding in from top.
extends Node

const MAX_VISIBLE := 3
const LIFETIME := 3.0
const SLIDE_DURATION := 0.25

var _root: Control = null
var _container: VBoxContainer = null
var _active: Array[Dictionary] = []
var _queue: Array[Dictionary] = []


func set_root(root: Control) -> void:
        _root = root
        if _container == null:
                _container = VBoxContainer.new()
                _container.name = "NotificationContainer"
                _container.set_anchors_preset(Control.PRESET_CENTER_TOP)
                _container.position = Vector2(0, 12)
                _container.alignment = BoxContainer.ALIGNMENT_BEGIN
                _container.add_theme_constant_override("separation", 6)
                _root.add_child(_container)


func notify(text: String, color: Color = Color.WHITE, icon: String = "") -> void:
        var item := {
                "text": text,
                "color": color,
                "icon": icon,
                "timestamp": Time.get_ticks_msec(),
        }
        _queue.append(item)
        _process_queue()


func info(text: String) -> void:
        notify(text, Color(0.85, 0.92, 1.0))


func success(text: String) -> void:
        notify(text, Color(0.7, 1.0, 0.7))


func warning(text: String) -> void:
        notify(text, Color(1.0, 0.85, 0.4))


func error(text: String) -> void:
        notify(text, Color(1.0, 0.4, 0.4))


func _process_queue() -> void:
        if _container == null:
                return
        while _queue.size() > 0 and _active.size() < MAX_VISIBLE:
                var item: Dictionary = _queue.pop_front()
                _show_item(item)


func _show_item(item: Dictionary) -> void:
        var panel := Panel.new()
        panel.custom_minimum_size = Vector2(360, 48)
        panel.modulate.a = 0.0

        # Style
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
        style.border_color = item["color"]
        style.set_border_width_all(2)
        style.set_corner_radius_all(6)
        style.set_content_margin_all(10)
        panel.add_theme_stylebox_override("panel", style)

        var label := Label.new()
        label.text = item["text"]
        label.add_theme_color_override("font_color", item["color"])
        label.add_theme_font_size_override("font_size", 14)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.size_flags_vertical = Control.SIZE_EXPAND_FILL
        panel.add_child(label)

        _container.add_child(panel)
        _active.append({"panel": panel, "expires": Time.get_ticks_msec() + int(LIFETIME * 1000)})

        # Slide in
        var tween := create_tween()
        tween.tween_property(panel, "modulate:a", 1.0, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        var pos_off := panel.position
        pos_off.y -= 12
        panel.position = pos_off
        tween.parallel().tween_property(panel, "position:y", pos_off.y + 12, SLIDE_DURATION)


func _process(_delta: float) -> void:
        if _active.is_empty():
                return
        var now := Time.get_ticks_msec()
        var expired: Array[int] = []
        for i in range(_active.size()):
                if now >= _active[i]["expires"]:
                        expired.append(i)
        if expired.is_empty():
                return
        # Remove expired (in reverse to keep indices valid)
        expired.reverse()
        for i in expired:
                var panel: Panel = _active[i]["panel"]
                _active.remove_at(i)
                var tween := create_tween()
                tween.tween_property(panel, "modulate:a", 0.0, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                var pos := panel.position
                tween.parallel().tween_property(panel, "position:y", pos.y - 12, SLIDE_DURATION)
                tween.tween_callback(panel.queue_free)

        # Process queue now that slots opened
        _process_queue()
