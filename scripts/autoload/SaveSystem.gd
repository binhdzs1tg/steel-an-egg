extends Node
## SaveSystem
## Local JSON save with auto-save, backup, and version migration.
##
## Save files (in user://):
##   save.json         — primary save
##   save.backup.json  — previous save (used if primary is corrupt)
##
## Save schema is versioned. Migrations live in `_migrate_save()`.

signal save_loaded(data: Dictionary)
signal save_failed(reason: String)
signal saved()

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.backup.json"
const AUTOSAVE_INTERVAL: float = 30.0

var _autosave_timer: float = 0.0
var _dirty: bool = false
var _current: Dictionary = {}


func _ready() -> void:
	if not DirAccess.dir_exists_absolute("user://"):
		DirAccess.make_dir_recursive_absolute("user://")
	_current = load_save()
	autosave_loop_start()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		if _dirty:
			save_game()


# ---------- Public ----------
func get_data() -> Dictionary:
	return _current


func mark_dirty() -> void:
	_dirty = true


func load_save() -> Dictionary:
	var data: Dictionary = _try_load_path(SAVE_PATH)
	if data.is_empty():
		push_warning("[SaveSystem] Primary save missing/invalid; trying backup.")
		data = _try_load_path(BACKUP_PATH)
	if data.is_empty():
		print("[SaveSystem] No save found — starting fresh.")
		data = _default_save()
	else:
		data = _migrate_save(data)
	_current = data
	save_loaded.emit(data)
	return data


func save_game() -> bool:
	if _current.is_empty():
		return false
	# rotate backup
	if FileAccess.file_exists(SAVE_PATH):
		_move_file(SAVE_PATH, BACKUP_PATH)
	_current["saved_at"] = Time.get_unix_time_from_system()
	_current["save_version"] = SAVE_VERSION
	var json := JSON.stringify(_current, "  ")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Cannot write save.")
		return false
	file.store_string(json)
	file.close()
	_dirty = false
	saved.emit()
	return true


func force_save() -> void:
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	_current = _default_save()
	_dirty = true


# ---------- Internals ----------
func _try_load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return {}
	var result = JSON.parse_string(text)
	if typeof(result) != TYPE_DICTIONARY:
		push_warning("[SaveSystem] Corrupt save at %s" % path)
		return {}
	return result


func _move_file(from: String, to: String) -> void:
	var src := FileAccess.open(from, FileAccess.READ)
	if src == null:
		return
	var content := src.get_as_text()
	src.close()
	var dst := FileAccess.open(to, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(content)
	dst.close()


func _migrate_save(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("save_version", 1))
	# Example migration: v1 -> v2 would add new fields with defaults.
	# For now we just keep it forward-compatible by ensuring required keys exist.
	data["save_version"] = SAVE_VERSION
	_ensure_defaults(data)
	return data


func _ensure_defaults(d: Dictionary) -> void:
	if not d.has("money"):
		d["money"] = 0
	if not d.has("lifetime_earned"):
		d["lifetime_earned"] = 0
	if not d.has("lifetime_spent"):
		d["lifetime_spent"] = 0
	if not d.has("speed_level"):
		d["speed_level"] = 1
	if not d.has("speed_xp"):
		d["speed_xp"] = 0
	if not d.has("upgrades"):
		d["upgrades"] = {}
	if not d.has("egg_inventory"):
		d["egg_inventory"] = []
	if not d.has("pets"):
		d["pets"] = []
	if not d.has("active_pet_slots"):
		d["active_pet_slots"] = 3
	if not d.has("egg_storage"):
		d["egg_storage"] = 5
	if not d.has("unlocked_biomes"):
		d["unlocked_biomes"] = ["grassland"]
	if not d.has("collection"):
		d["collection"] = {"pets": [], "sizes": [], "mutations": []}
	if not d.has("achievements"):
		d["achievements"] = []
	if not d.has("quests"):
		d["quests"] = []
	if not d.has("stats"):
		d["stats"] = {
			"eggs_collected": 0,
			"pets_hatched": 0,
			"unique_pets": 0,
			"mutations_found": 0,
			"huge_pets": 0,
			"secret_pets": 0,
			"biomes_unlocked": 1,
			"highest_pet_rarity_tier": 0
		}
	if not d.has("settings"):
		d["settings"] = {
			"music_volume": 0.7,
			"sfx_volume": 0.8,
			"camera_shake": true,
			"effects_quality": "high",
			"language": "vi"
		}
	if not d.has("last_saved_time"):
		d["last_saved_time"] = Time.get_unix_time_from_system()


func _default_save() -> Dictionary:
	var d: Dictionary = {}
	_ensure_defaults(d)
	d["save_version"] = SAVE_VERSION
	d["created_at"] = Time.get_unix_time_from_system()
	return d


func autosave_loop_start() -> void:
	_autosave_timer = 0.0


# ---------- Offline earnings ----------
func get_offline_seconds(max_seconds: int = 1800) -> int:
	var last: float = float(_current.get("last_saved_time", 0.0))
	if last <= 0.0:
		return 0
	var now: float = Time.get_unix_time_from_system()
	var diff: int = int(now - last)
	return clampi(diff, 0, max_seconds)


func apply_offline_earnings(rate_per_second: float) -> int:
	var secs := get_offline_seconds()
	var earned := int(secs * rate_per_second)
	if earned > 0:
		_current["money"] = int(_current.get("money", 0)) + earned
		_current["lifetime_earned"] = int(_current.get("lifetime_earned", 0)) + earned
		mark_dirty()
	return earned
