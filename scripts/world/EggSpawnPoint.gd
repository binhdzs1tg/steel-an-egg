extends Node3D
class_name EggSpawnPoint
## A location where eggs spawn. Respawns after a delay.

@export var biome_id: String = "grassland"
@export var respawn_time: float = 15.0

var current_egg: Egg = null
var respawn_timer: float = 0.0
var is_active: bool = true


func _ready() -> void:
	spawn_egg()


func _process(delta: float) -> void:
	if current_egg == null and is_active:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			spawn_egg()


func spawn_egg() -> void:
	if current_egg != null:
		return
	var biome: Dictionary = DataRegistry.get_biome(biome_id)
	var pool: Array = biome.get("egg_pool", [])
	if pool.is_empty():
		return
	var picked: Dictionary = DataRegistry.roll_weighted(pool)
	var egg_id: String = picked.get("egg_id", "")
	if egg_id.is_empty():
		return
	var egg_scene := preload("res://scripts/egg/Egg.gd")
	var egg: Egg = Egg.new()  # type:ignore
	egg.set_script(egg_scene)
	egg.position = Vector3.ZERO  # spawn at this point's local origin
	add_child(egg)
	# Wait a frame for _ready to run on the egg
	await get_tree().process_frame
	if egg and egg.has_method("set_egg_id"):
		egg.set_egg_id(egg_id)
	current_egg = egg


func _on_egg_taken() -> void:
	current_egg = null
	respawn_timer = respawn_time


func deactivate() -> void:
	is_active = false
	if current_egg:
		current_egg.queue_free()
		current_egg = null


func activate() -> void:
	is_active = true
	if current_egg == null:
		spawn_egg()
