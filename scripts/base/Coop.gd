# Coop.gd
# Where the player deposits carried eggs. Each deposited egg starts the hatch timer.
# When timer expires, the egg becomes a pet and starts generating income.
extends Area2D

const HATCH_SLOTS_DEFAULT := 3
const SLOT_SIZE := 80
const SLOT_SPACING := 12
const SLOT_ROW_MAX := 4

signal egg_deposited(egg_id: String, slot: int)
signal egg_hatched(egg_id: String, pet_id: String)
signal slot_layout_changed(slots: Array)

# Each slot: {egg_id, hatch_time_remaining, is_hatched, pet_id}
var _slots: Array[Dictionary] = []
var _slot_visuals: Array[Node] = []


func _ready() -> void:
	add_to_group("coop")
	body_entered.connect(_on_body_entered)
	_init_slots()
	_build_visual()


func _init_slots() -> void:
	_slots.clear()
	var count: int = Economy.get_max_pet_slots()
	for i in range(count):
		_slots.append({
			"egg_id": "",
			"hatch_time_remaining": 0.0,
			"is_hatched": false,
			"pet_id": "",
		})


func _build_visual() -> void:
	# Clear existing visuals
	for v in _slot_visuals:
		if is_instance_valid(v):
			v.queue_free()
	_slot_visuals.clear()
	# Draw coop building backdrop
	var bg := Polygon2D.new()
	var w := 480.0
	var h := 280.0
	bg.polygon = PackedVector2Array([
		Vector2(-w/2, -h/2), Vector2(w/2, -h/2),
		Vector2(w/2, h/2), Vector2(-w/2, h/2)
	])
	bg.color = Color(0.4, 0.32, 0.20, 0.85)
	bg.z_index = -2
	add_child(bg)
	_slot_visuals.append(bg)

	# Draw roof
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-w/2 - 30, -h/2), Vector2(w/2 + 30, -h/2),
		Vector2(w/2 - 10, -h/2 - 60), Vector2(-w/2 + 10, -h/2 - 60)
	])
	roof.color = Color(0.55, 0.25, 0.15, 0.95)
	roof.z_index = -1
	add_child(roof)
	_slot_visuals.append(roof)

	# Label
	var label := Label.new()
	label.text = "CHUỒNG"
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.add_theme_font_size_override("font_size", 24)
	label.position = Vector2(-60, -h/2 - 35)
	label.z_index = 3
	add_child(label)
	_slot_visuals.append(label)

	# Draw hatch slots
	var count: int = _slots.size()
	var rows := ceil(count / float(SLOT_ROW_MAX))
	for i in range(count):
		var row := i / SLOT_ROW_MAX
		var col := i % SLOT_ROW_MAX
		var row_count: int = min(SLOT_ROW_MAX, count - row * SLOT_ROW_MAX)
		var row_width: float = row_count * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
		var x: float = -row_width / 2.0 + col * (SLOT_SIZE + SLOT_SPACING) + SLOT_SIZE / 2.0
		var y: float = -40 + row * (SLOT_SIZE + SLOT_SPACING)
		var slot_node := _make_slot_visual(i, Vector2(x, y))
		add_child(slot_node)
		_slot_visuals.append(slot_node)


func _make_slot_visual(idx: int, pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	node.name = "Slot%d" % idx
	# Empty slot marker (dashed circle)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 16
	for i in range(n):
		if i % 2 == 0:
			var a1 := TAU * float(i) / float(n)
			var a2 := TAU * float((i + 1)) / float(n)
			pts.append(Vector2(cos(a1), sin(a1)) * (SLOT_SIZE / 2.0 - 4))
			pts.append(Vector2(cos(a2), sin(a2)) * (SLOT_SIZE / 2.0 - 4))
	ring.polygon = pts
	ring.color = Color(0.3, 0.3, 0.3, 0.5)
	node.add_child(ring)
	return node


func _process(delta: float) -> void:
	if GameManager.is_paused():
		return
	# Update hatching for all slots
	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		if slot["is_hatched"] or slot["egg_id"] == "":
			continue
		slot["hatch_time_remaining"] = float(slot["hatch_time_remaining"]) - delta
		if float(slot["hatch_time_remaining"]) <= 0.0:
			_hatch_slot(i)


func _hatch_slot(idx: int) -> void:
	var slot: Dictionary = _slots[idx]
	if slot["egg_id"] == "":
		return
	var egg_data: Dictionary = DataRegistry.get_egg(slot["egg_id"])
	var pet_id: String = egg_data.get("pet_id", "")
	if pet_id == "":
		return
	slot["is_hatched"] = true
	slot["pet_id"] = pet_id
	Economy.register_pet(pet_id)
	egg_hatched.emit(slot["egg_id"], pet_id)
	NotificationSystem.success("Trứng đã nở! Sinh vật mới: %s" % DataRegistry.get_pet(pet_id).get("name", "?"))
	AudioManager.sfx_hatch()
	SaveSystem.mark_dirty()


# ---------- Interaction API ----------
func get_interact_prompt(player: Node) -> String:
	if not GameManager.is_carrying_egg():
		return ""
	if not Economy.has_free_pet_slot():
		return "Chuồng đầy! Mở rộng chuồng để có thêm chỗ."
	return "BẤM [E] ĐỂ ĐẶT TRỨNG VÀO CHUỒNG!"


func interact(player: Node) -> void:
	if not GameManager.is_carrying_egg():
		return
	if not Economy.has_free_pet_slot():
		NotificationSystem.warning("Chuồng không còn chỗ trống! Mở rộng chuồng để nuôi thêm.")
		return
	var egg_id: String = GameManager.get_carried_egg_id()
	if egg_id == "":
		return
	# Find first empty slot
	var idx: int = -1
	for i in range(_slots.size()):
		if _slots[i]["egg_id"] == "":
			idx = i
			break
	if idx == -1:
		NotificationSystem.warning("Không tìm thấy slot trống!")
		return
	var egg_data: Dictionary = DataRegistry.get_egg(egg_id)
	# Apply hatch speed upgrade
	var hatch_speed_mult: float = Economy.get_upgrade_value("hatch_speed")
	# hatch_speed_mult goes from 1.0 → 0.2 (lower is faster)
	var hatch_time: float = float(egg_data.get("hatch_time", 60.0)) * hatch_speed_mult
	_slots[idx] = {
		"egg_id": egg_id,
		"hatch_time_remaining": hatch_time,
		"is_hatched": false,
		"pet_id": "",
	}
	egg_deposited.emit(egg_id, idx)
	slot_layout_changed.emit(_slots.duplicate(true))
	# Player drops the egg
	player.deposit_egg()
	# Reward with money equal to egg value
	var value: int = int(egg_data.get("value", 0))
	Economy.add_money(value)
	NotificationSystem.success("Cất trứng thành công! +%d$" % value)
	AudioManager.sfx_deposit()
	SaveSystem.mark_dirty()
	# Rebuild visual to show egg in slot
	_build_visual_for_slot(idx)


func _build_visual_for_slot(idx: int) -> void:
	# Find the slot node and add an egg sprite
	var slot_node: Node = _slot_visuals[3 + idx] if _slot_visuals.size() > 3 + idx else null
	if slot_node == null:
		return
	# Remove existing egg child if any
	for c in slot_node.get_children():
		if c is Polygon2D:
			c.queue_free()
	var slot: Dictionary = _slots[idx]
	if slot["egg_id"] == "":
		return
	var egg_data: Dictionary = DataRegistry.get_egg(slot["egg_id"])
	var color: Color = DataRegistry.color_from_hex(egg_data.get("color", "#fff8dc"))
	var egg_sprite := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 12
	var r: float = 22.0
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r * 0.85, sin(a) * r * 1.15))
	egg_sprite.polygon = pts
	egg_sprite.color = color
	slot_node.add_child(egg_sprite)

	if slot["is_hatched"]:
		# Show pet visual (color + larger)
		var pet_color: Color = DataRegistry.color_from_hex(DataRegistry.get_pet(slot["pet_id"]).get("color", "#ffffff"))
		var pet_sprite := Polygon2D.new()
		var pet_pts := PackedVector2Array()
		for i in range(8):
			var a := TAU * float(i) / float(8)
			pet_pts.append(Vector2(cos(a) * 16, sin(a) * 16))
		pet_sprite.polygon = pet_pts
		pet_sprite.color = pet_color
		pet_sprite.position = Vector2(0, 8)
		slot_node.add_child(pet_sprite)


func _on_body_entered(body: Node) -> void:
	# Player walked into coop area. They still need to press E to deposit.
	pass


# ---------- Save/Load ----------
func serialize() -> Dictionary:
	return {
		"slots": _slots.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	var loaded_slots: Array = data.get("slots", [])
	_init_slots()
	for i in range(min(loaded_slots.size(), _slots.size())):
		_slots[i] = loaded_slots[i].duplicate(true)
	# Re-register pets from loaded slots
	for s in _slots:
		if s["is_hatched"] and s["pet_id"] != "":
			Economy.register_pet(s["pet_id"])
	_build_visual()
	for i in range(_slots.size()):
		_build_visual_for_slot(i)
