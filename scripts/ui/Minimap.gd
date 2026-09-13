# Minimap.gd
# Top-right minimap: shows player position (dot), base (square), biomes (colored bands),
# and any nearby chasing guardians (red triangles).
extends Control

const MAP_WIDTH := 200.0
const MAP_HEIGHT := 280.0
const WORLD_HEIGHT := 8000.0   # rough total world height (y range -7000..+800)
const WORLD_WIDTH := 2000.0

var _player_dot: Polygon2D = null
var _base_marker: Polygon2D = null
var _guardian_markers: Array[Polygon2D] = []
var _biome_bands: Array[ColorRect] = []


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_build_background()


func _build_background() -> void:
	# Frame
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	style.border_color = Color(0.4, 0.4, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	
	# Biome bands
	for i in range(DataRegistry.get_biome_count()):
		var bd: Dictionary = DataRegistry.get_biome_by_index(i)
		var band := ColorRect.new()
		band.color = DataRegistry.color_from_hex(bd["bg_color"])
		band.color.a = 0.6
		var y_start: float = float(bd["y_start"])
		var y_end: float = float(bd["y_end"])
		# Map world y to minimap y. World y is negative going up.
		# We want top of minimap = highest world y (most negative)
		var min_y: float = (y_start - (-7000.0)) / WORLD_HEIGHT * MAP_HEIGHT
		var max_y: float = (y_end - (-7000.0)) / WORLD_HEIGHT * MAP_HEIGHT
		band.position = Vector2(4, min_y)
		band.size = Vector2(MAP_WIDTH - 8, max_y - min_y)
		add_child(band)
		_biome_bands.append(band)
		
		# Biome label
		var lbl := Label.new()
		lbl.text = bd["name"]
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.position = Vector2(8, min_y + 2)
		add_child(lbl)
	
	# Base marker (square at y=0)
	_base_marker = Polygon2D.new()
	_base_marker.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])
	_base_marker.color = Color(0.4, 1.0, 0.4)
	_base_marker.position = _world_to_map(Vector2(0, 0))
	add_child(_base_marker)
	
	# Player dot
	_player_dot = Polygon2D.new()
	var n := 8
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * 4, sin(a) * 4))
	_player_dot.polygon = pts
	_player_dot.color = Color(1.0, 1.0, 0.4)
	add_child(_player_dot)


func _process(_delta: float) -> void:
	var p: Node2D = GameManager.get_player()
	if p == null:
		return
	_player_dot.position = _world_to_map(p.position)
	
	# Update guardian markers (we re-create them each frame for simplicity)
	for m in _guardian_markers:
		m.queue_free()
	_guardian_markers.clear()
	
	var guardians: Array = get_tree().get_nodes_in_group("guardian")
	for g in guardians:
		var marker := Polygon2D.new()
		var pts := PackedVector2Array()
		pts.append(Vector2(0, -4))
		pts.append(Vector2(-3, 3))
		pts.append(Vector2(3, 3))
		marker.polygon = pts
		var is_chasing: bool = g.has_method("get_state_name") and g.get_state_name() == "CHASE"
		marker.color = Color(1.0, 0.2, 0.2) if is_chasing else Color(0.6, 0.6, 0.6, 0.6)
		marker.position = _world_to_map(g.position)
		add_child(marker)
		_guardian_markers.append(marker)


func _world_to_map(world_pos: Vector2) -> Vector2:
	# Map world (x: ±1000, y: -7000..+800) to minimap (0..MAP_WIDTH, 0..MAP_HEIGHT)
	var x_ratio: float = clamp(world_pos.x / WORLD_WIDTH, -0.5, 0.5) + 0.5
	var y_ratio: float = (world_pos.y - (-7000.0)) / WORLD_HEIGHT
	y_ratio = clamp(y_ratio, 0.0, 1.0)
	return Vector2(x_ratio * MAP_WIDTH, y_ratio * MAP_HEIGHT)
