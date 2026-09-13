# Base.gd
# Player's home area. Safe zone. Contains coop (egg hatch slots), treadmill (speed trainer),
# and the deposit area. When player carrying egg enters coop zone, they can deposit.
extends Node2D

const TREADMILL_X := -350.0
const TREADMILL_Y := 0.0
const COOP_X := 350.0
const COOP_Y := 0.0

var _coop: Node = null
var _treadmill: Node = null
var _safe_zone: Area2D = null


func _ready() -> void:
	add_to_group("base")
	# Spawn treadmill
	var treadmill_scene := preload("res://scenes/Treadmill.tscn")
	_treadmill = treadmill_scene.instantiate()
	_treadmill.position = Vector2(TREADMILL_X, TREADMILL_Y)
	add_child(_treadmill)
	# Spawn coop
	var coop_scene := preload("res://scenes/Coop.tscn")
	_coop = coop_scene.instantiate()
	_coop.position = Vector2(COOP_X, COOP_Y)
	add_child(_coop)
	# Add safe-zone visual marker (background)
	_draw_base_area()


func _draw_base_area() -> void:
	# A nice green patch that signals "safe zone"
	var safe_color := Color(0.85, 0.78, 0.55, 0.4)
	var rect := ColorRect.new()
	rect.color = safe_color
	rect.size = Vector2(1600, 800)
	rect.position = Vector2(-800, -400)
	rect.z_index = -8
	add_child(rect)
	# Label
	var label := Label.new()
	label.text = "CĂN CỨ NGƯỜI CHƠI"
	label.add_theme_color_override("font_color", Color(0.3, 0.25, 0.15))
	label.add_theme_font_size_override("font_size", 36)
	label.position = Vector2(-160, -360)
	label.z_index = 5
	add_child(label)
	# Safe zone collision (guardians can't enter)
	var safe_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(1600, 800)
	shape.shape = rect_shape
	safe_area.add_child(shape)
	safe_area.position = Vector2.ZERO
	safe_area.collision_mask = 0
	safe_area.collision_layer = 0
	safe_area.monitoring = false
	add_child(safe_area)
	_safe_zone = safe_area


func get_coop() -> Node:
	return _coop


func get_treadmill() -> Node:
	return _treadmill
