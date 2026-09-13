# Biome.gd
# A single biome region in the world. Contains its background, decorations,
# and spawns eggs + guardian for that biome.
extends Node2D

signal biome_entered(biome_id: String)

@export var biome_id: String = ""

var _data: Dictionary = {}
var _bg: ColorRect = null
var _label: Label = null
var _entered: bool = false

# Spawning positions are computed in _ready based on biome bounds
var _spawned_eggs: Array[Node] = []
var _guardian: Node = null


func _ready() -> void:
	_data = DataRegistry.get_biome(biome_id)
	if _data.is_empty():
		push_error("[Biome] No data for id: %s" % biome_id)
		return
	_apply_visual()
	_spawn_eggs()
	_spawn_guardian()


func _apply_visual() -> void:
	# Background rectangle covering the biome area
	var y_start: float = float(_data["y_start"])
	var y_end: float = float(_data["y_end"])
	var height: float = abs(y_end - y_start)
	var width: float = 2000.0  # world width
	_bg = ColorRect.new()
	_bg.color = DataRegistry.color_from_hex(_data["bg_color"])
	_bg.size = Vector2(width, height)
	_bg.position = Vector2(-width / 2.0, y_start)
	_bg.z_index = -10
	add_child(_bg)
	# Subtle ground texture (alternating stripes)
	_add_ground_stripe(y_start, y_end, width)
	# Decorations
	_add_decorations(y_start, y_end, width)
	# Biome name label (faded, at top of biome)
	_label = Label.new()
	_label.text = _data["name"]
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_label.add_theme_font_size_override("font_size", 28)
	_label.position = Vector2(-150, y_start + 30)
	_label.z_index = 5
	add_child(_label)
	# Trigger area (when player enters biome)
	var trigger := Area2D.new()
	var trigger_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	trigger_shape.shape = rect
	trigger.add_child(trigger_shape)
	trigger.position = Vector2(0, (y_start + y_end) / 2.0)
	trigger.z_index = -5
	add_child(trigger)
	trigger.body_entered.connect(_on_player_entered)


func _add_ground_stripe(y_start: float, y_end: float, width: float) -> void:
	# Add subtle horizontal stripes every 200 px for visual variety
	var accent: Color = DataRegistry.color_from_hex(_data["accent_color"])
	accent.a = 0.15
	var y := y_start
	while y < y_end:
		var stripe := ColorRect.new()
		stripe.color = accent
		stripe.size = Vector2(width, 4)
		stripe.position = Vector2(-width / 2.0, y)
		stripe.z_index = -9
		add_child(stripe)
		y += 200.0


func _add_decorations(y_start: float, y_end: float, width: float) -> void:
	var deco_color: Color = DataRegistry.color_from_hex(_data["accent_color"])
	deco_color.a = 0.6
	var rng := RandomNumberGenerator.new()
	rng.seed = (biome_id.hash() & 0xFFFFFFFF)
	# Add 12 decoration blobs per biome
	var count: int = 12
	for i in range(count):
		var x: float = rng.randf_range(-width / 2.0 + 50, width / 2.0 - 50)
		var y: float = rng.randf_range(y_start + 50, y_end - 50)
		var deco := Polygon2D.new()
		var size: float = rng.randf_range(12, 28)
		var pts := PackedVector2Array()
		var n := 8
		for j in range(n):
			var a := TAU * float(j) / float(n)
			pts.append(Vector2(cos(a) * size, sin(a) * size))
		deco.polygon = pts
		deco.color = deco_color
		deco.position = Vector2(x, y)
		deco.z_index = -1
		add_child(deco)


func _spawn_eggs() -> void:
	var egg_ids: Array = DataRegistry.get_eggs_in_biome(biome_id)
	if egg_ids.is_empty():
		return
	var y_start: float = float(_data["y_start"])
	var y_end: float = float(_data["y_end"])
	var rng := RandomNumberGenerator.new()
	rng.seed = (biome_id.hash() ^ 0xABCDEF) & 0xFFFFFFFF
	# Spread eggs across biome width and height
	for i in range(egg_ids.size()):
		var eid: String = egg_ids[i]
		var egg_scene: PackedScene = preload("res://scenes/Egg.tscn")
		var egg: Node = egg_scene.instantiate()
		egg.egg_id = eid
		# Place egg in random spot within biome (avoid edges)
		var x: float = rng.randf_range(-600, 600)
		var y: float = rng.randf_range(y_start + 200, y_end - 200)
		egg.position = Vector2(x, y)
		add_child(egg)
		_spawned_eggs.append(egg)


func _spawn_guardian() -> void:
	var guardian_data: Dictionary = DataRegistry.get_guardian_for_biome(biome_id)
	if guardian_data.is_empty():
		return
	var g_scene: PackedScene = preload("res://scenes/Guardian.tscn")
	var g: Node = g_scene.instantiate()
	g.guardian_id = guardian_data["id"]
	var y_mid: float = (float(_data["y_start"]) + float(_data["y_end"])) / 2.0
	g.position = Vector2(0, y_mid)
	g.patrol_center = Vector2(0, y_mid)
	add_child(g)
	_guardian = g


func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _entered:
		return
	_entered = true
	biome_entered.emit(biome_id)
	NotificationSystem.info("Vào khu vực: %s" % _data["name"])
	if _guardian != null and _guardian.has_method("get_state_name"):
		pass


func get_data() -> Dictionary:
	return _data


func get_eggs() -> Array:
	return _spawned_eggs


# ---------- Save/Load ----------
func serialize() -> Dictionary:
	var eggs_state: Array = []
	for e in _spawned_eggs:
		if e.has_method("serialize"):
			eggs_state.append(e.serialize())
	var guardian_state: Dictionary = {}
	if _guardian != null and _guardian.has_method("serialize"):
		guardian_state = _guardian.serialize()
	return {
		"biome_id": biome_id,
		"eggs": eggs_state,
		"guardian": guardian_state,
	}


func deserialize(data: Dictionary) -> void:
	var eggs_state: Array = data.get("eggs", [])
	for state in eggs_state:
		var eid: String = state.get("egg_id", "")
		for e in _spawned_eggs:
			if e.egg_id == eid and e.has_method("deserialize"):
				e.deserialize(state)
				break
	if _guardian != null and _guardian.has_method("deserialize"):
		_guardian.deserialize(data.get("guardian", {}))
