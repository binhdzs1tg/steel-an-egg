# Egg.gd
# An egg sitting in a biome. When player approaches and presses E, the egg is "stolen"
# (player starts carrying it, egg disappears). Egg respawns after a delay.
extends Area2D

signal egg_stolen(egg_id: String)
signal egg_respawned(egg_id: String)

@export var egg_id: String = ""
@export var respawn_time: float = 60.0
@export var is_available: bool = true

var _egg_data: Dictionary = {}
var _respawn_timer: float = 0.0
var _pulse_t: float = 0.0

@onready var sprite: Polygon2D = $EggSprite
@onready var glow: Polygon2D = $GlowSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("egg")
	_egg_data = DataRegistry.get_egg(egg_id)
	if not _egg_data.is_empty():
		_apply_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _apply_visual() -> void:
	var color: Color = DataRegistry.color_from_hex(_egg_data.get("color", "#fff8dc"))
	var size: float = float(_egg_data.get("size", 18)) * 0.5
	sprite.color = color
	sprite.polygon = _make_egg_polygon(size)
	glow.color = Color(color.r, color.g, color.b, 0.25)
	glow.polygon = _make_egg_polygon(size * 1.6)
	# Update collision shape to match egg size
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = size * 1.5


func _process(delta: float) -> void:
	if not is_available:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	# Pulse glow
	_pulse_t += delta * 2.0
	var s: float = 1.0 + sin(_pulse_t) * 0.08
	glow.scale = Vector2(s, s)
	sprite.scale = Vector2(1.0 + sin(_pulse_t * 1.5) * 0.04, 1.0 + cos(_pulse_t * 1.5) * 0.04)


# ---------- Interaction API (called by Player) ----------
func get_interact_prompt(player: Node) -> String:
	if not is_available:
		return ""
	if GameManager.is_carrying_egg():
		return ""
	return "BẤM [E] ĐỂ TRỘM TRỨNG!"


func interact(player: Node) -> void:
	if not is_available:
		return
	if GameManager.is_carrying_egg():
		NotificationSystem.warning("Bạn đang mang trứng rồi! Mang về căn cứ trước.")
		return
	# Steal!
	is_available = false
	sprite.visible = false
	glow.visible = false
	collision_shape.set_deferred("disabled", true)
	_respawn_timer = respawn_time
	egg_stolen.emit(egg_id)
	# Player carries it
	player.carry_egg(egg_id)
	# Notify
	AudioManager.sfx_steal()
	var egg_name: String = _egg_data.get("name", "Trứng")
	NotificationSystem.success("Đã trộm: %s" % egg_name)
	# Trigger nearby guardian chase
	_notify_guardians()
	SaveSystem.mark_dirty()


func _on_body_entered(body: Node) -> void:
	# Body is the player. We don't auto-steal; player must press E.
	pass


func _on_body_exited(body: Node) -> void:
	pass


# ---------- Respawn ----------
func _respawn() -> void:
	is_available = true
	sprite.visible = true
	glow.visible = true
	collision_shape.set_deferred("disabled", false)
	egg_respawned.emit(egg_id)


# ---------- Guardian notification ----------
func _notify_guardians() -> void:
	var biome_id: String = _egg_data.get("biome_id", "")
	var world: Node2D = GameManager.get_world()
	if world == null:
		return
	var guardians: Array = world.get_tree().get_nodes_in_group("guardian")
	for g in guardians:
		if g.has_method("on_egg_stolen"):
			g.on_egg_stolen(self)


# ---------- Helpers ----------
func _make_egg_polygon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 16
	for i in range(n):
		var angle: float = TAU * float(i) / float(n)
		var x: float = cos(angle) * radius * 0.85
		var y: float = sin(angle) * radius * 1.15
		pts.append(Vector2(x, y))
	return pts


func get_egg_value() -> int:
	return int(_egg_data.get("value", 0))


func get_egg_data() -> Dictionary:
	return _egg_data


# ---------- Save/Load ----------
func serialize() -> Dictionary:
	return {
		"egg_id": egg_id,
		"is_available": is_available,
		"respawn_timer": _respawn_timer,
	}


func deserialize(data: Dictionary) -> void:
	is_available = bool(data.get("is_available", true))
	_respawn_timer = float(data.get("respawn_timer", 0.0))
	if not is_available:
		sprite.visible = false
		glow.visible = false
		collision_shape.set_deferred("disabled", true)
