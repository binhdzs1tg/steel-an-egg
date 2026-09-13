# SaveSystem.gd
# Singleton that handles save/load to user://save.json
# Provides both autosave (every 10s) and explicit save_game()/load_game().
extends Node

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 10.0

var _autosave_timer: float = 0.0
var _dirty: bool = false


func _ready() -> void:
	# Attempt to load existing save on startup
	load_game()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		_dirty = false
		save_game()


func mark_dirty() -> void:
	_dirty = true


func save_game() -> bool:
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"economy": Economy.serialize(),
		"player": _serialize_player(),
		"world": _serialize_world(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] Failed to open save file for write: %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(save_data, "  "))
	f.close()
	_dirty = false
	print("[SaveSystem] Game saved to %s" % SAVE_PATH)
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveSystem] No save file found, starting fresh.")
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[SaveSystem] Cannot open save file for read")
		return false
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[SaveSystem] JSON parse error: %s" % json.get_error_message())
		return false
	var data: Dictionary = json.data
	# Defer player/world restore — they may not be instantiated yet.
	# We store the loaded data on GameManager so the world/player can pull from it.
	if data.has("economy"):
		Economy.deserialize(data["economy"])
	if data.has("player"):
		GameManager.set_pending_player_state(data["player"])
	if data.has("world"):
		GameManager.set_pending_world_state(data["world"])
	print("[SaveSystem] Save loaded.")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_dirty = false
	print("[SaveSystem] Save deleted.")


# ---------- Helpers ----------
func _serialize_player() -> Dictionary:
	var p: Node = GameManager.get_player()
	if p == null or not p.has_method("serialize"):
		return {}
	return p.serialize()


func _serialize_world() -> Dictionary:
	var w: Node = GameManager.get_world()
	if w == null or not w.has_method("serialize"):
		return {}
	return w.serialize()
