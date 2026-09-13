extends Node3D
class_name EggSpawnPoint
## A location where eggs spawn. Respawns after a delay.
##
## BUGFIX: a race condition could spawn two eggs on the same point when the
## respawn timer expired while a previous spawn_egg() await was still pending.
## `current_egg` is now reserved BEFORE the await so re-entrant calls fail.

@export var biome_id: String = "grassland"
@export var respawn_time: float = 15.0

var current_egg: Egg = null
var respawn_timer: float = 0.0
var is_active: bool = true
var _spawning: bool = false


func _ready() -> void:
        spawn_egg()


func _process(delta: float) -> void:
        if current_egg == null and is_active and not _spawning:
                respawn_timer -= delta
                if respawn_timer <= 0.0:
                        spawn_egg()


func spawn_egg() -> void:
        if current_egg != null or _spawning:
                return
        var biome: Dictionary = DataRegistry.get_biome(biome_id)
        var pool: Array = biome.get("egg_pool", [])
        if pool.is_empty():
                return
        var picked: Dictionary = DataRegistry.roll_weighted(pool)
        var picked_egg_id: String = picked.get("egg_id", "")
        if picked_egg_id.is_empty():
                return
        _spawning = true
        var egg: Egg = Egg.new()
        egg.position = Vector3.ZERO  # spawn at this point's local origin
        add_child(egg)
        # Reserve the slot immediately so a re-entrant call cannot double-spawn.
        current_egg = egg
        # Give the egg one frame to run _ready, then apply its template data.
        await get_tree().process_frame
        if is_instance_valid(egg) and not egg.is_collected:
                egg.set_egg_id(picked_egg_id)
        _spawning = false


func _on_egg_taken() -> void:
        current_egg = null
        respawn_timer = respawn_time


func deactivate() -> void:
        is_active = false
        if current_egg:
                if is_instance_valid(current_egg):
                        current_egg.queue_free()
                current_egg = null


func activate() -> void:
        is_active = true
        if current_egg == null:
                spawn_egg()
