# World.gd
# Container for all biomes + the player's base area.
# Instantiates biome nodes for each biome in data registry.
extends Node2D

const BASE_Y := 0.0           # Player's base is around y=0
const PLAYGROUND_Y_START := -1000.0

var _biomes: Array[Node] = []
var _base: Node = null


func _ready() -> void:
	GameManager.register_world(self)
	_build_world()


func _build_world() -> void:
	# Spawn the player base first (y = 0)
	_spawn_base()
	# Spawn biomes in order
	var count: int = DataRegistry.get_biome_count()
	for i in range(count):
		var biome_data: Dictionary = DataRegistry.get_biome_by_index(i)
		if biome_data.is_empty():
			continue
		var biome_scene := preload("res://scenes/world/Biome.tscn")
		var biome = biome_scene.instantiate()
		biome.biome_id = biome_data["id"]
		biome.position = Vector2.ZERO
		add_child(biome)
		_biomes.append(biome)
	# Spawn the player (at base)
	_spawn_player()


func _spawn_base() -> void:
	var base_scene := preload("res://scenes/Base.tscn")
	_base = base_scene.instantiate()
	_base.position = Vector2(0, BASE_Y)
	add_child(_base)


func _spawn_player() -> void:
	var player_scene := preload("res://scenes/Player.tscn")
	var player: Node2D = player_scene.instantiate()
	player.position = Vector2(0, BASE_Y + 100)
	add_child(player)


# ---------- Helpers ----------
func get_biomes() -> Array:
	return _biomes


func get_base() -> Node:
	return _base


# ---------- Save/Load ----------
func serialize() -> Dictionary:
	var biomes_state: Array = []
	for b in _biomes:
		if b.has_method("serialize"):
			biomes_state.append(b.serialize())
	return {
		"biomes": biomes_state,
	}


func deserialize(data: Dictionary) -> void:
	var biomes_state: Array = data.get("biomes", [])
	for state in biomes_state:
		var bid: String = state.get("biome_id", "")
		for b in _biomes:
			if b.biome_id == bid and b.has_method("deserialize"):
				b.deserialize(state)
				break
