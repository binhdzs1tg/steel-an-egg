# DataRegistry.gd
# Singleton autoload that loads all JSON data files at startup
# and provides lookup APIs to other systems.
extends Node

# --- Data containers (read-only after _ready) ---
var biomes: Dictionary = {}            # id -> biome dict
var biomes_by_index: Array = []         # sorted list of biome dicts
var eggs: Dictionary = {}              # id -> egg dict
var eggs_by_biome: Dictionary = {}     # biome_id -> Array[egg_id]
var guardians: Dictionary = {}         # id -> guardian dict
var guardians_by_biome: Dictionary = {} # biome_id -> guardian_id
var pets: Dictionary = {}              # id -> pet dict
var pets_by_egg: Dictionary = {}       # egg_id -> pet_id
var upgrades: Dictionary = {}          # id -> upgrade dict


func _ready() -> void:
	_load_biomes()
	_load_eggs()
	_load_guardians()
	_load_pets()
	_load_upgrades()
	print("[DataRegistry] Loaded %d biomes, %d eggs, %d guardians, %d pets, %d upgrades" % [
		biomes.size(), eggs.size(), guardians.size(), pets.size(), upgrades.size()
	])


# ---------- Loaders ----------
func _load_biomes() -> void:
	var path := "res://data/biomes.json"
	var data: Variant = _load_json(path)
	if data == null:
		push_error("[DataRegistry] Failed to load biomes.json")
		return
	for b in data.get("biomes", []):
		var id: String = b["id"]
		biomes[id] = b
		biomes_by_index.append(b)
	# Sort by index for deterministic ordering
	biomes_by_index.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))


func _load_eggs() -> void:
	var data: Variant = _load_json("res://data/eggs.json")
	if data == null:
		push_error("[DataRegistry] Failed to load eggs.json")
		return
	for e in data.get("eggs", []):
		var id: String = e["id"]
		eggs[id] = e
		var bid: String = e["biome_id"]
		if not eggs_by_biome.has(bid):
			eggs_by_biome[bid] = []
		eggs_by_biome[bid].append(id)


func _load_guardians() -> void:
	var data: Variant = _load_json("res://data/guardians.json")
	if data == null:
		push_error("[DataRegistry] Failed to load guardians.json")
		return
	for g in data.get("guardians", []):
		var id: String = g["id"]
		guardians[id] = g
		guardians_by_biome[g["biome_id"]] = id


func _load_pets() -> void:
	var data: Variant = _load_json("res://data/pets.json")
	if data == null:
		push_error("[DataRegistry] Failed to load pets.json")
		return
	for p in data.get("pets", []):
		var id: String = p["id"]
		pets[id] = p
		pets_by_egg[p["egg_id"]] = id


func _load_upgrades() -> void:
	var data: Variant = _load_json("res://data/upgrades.json")
	if data == null:
		push_error("[DataRegistry] Failed to load upgrades.json")
		return
	for u in data.get("upgrades", []):
		upgrades[u["id"]] = u


# ---------- Lookup API ----------
func get_biome(id: String) -> Dictionary:
	return biomes.get(id, {})

func get_biome_by_index(idx: int) -> Dictionary:
	if idx < 0 or idx >= biomes_by_index.size():
		return {}
	return biomes_by_index[idx]

func get_biome_count() -> int:
	return biomes_by_index.size()

func get_egg(id: String) -> Dictionary:
	return eggs.get(id, {})

func get_eggs_in_biome(biome_id: String) -> Array:
	return eggs_by_biome.get(biome_id, [])

func get_guardian(id: String) -> Dictionary:
	return guardians.get(id, {})

func get_guardian_for_biome(biome_id: String) -> Dictionary:
	var gid: String = guardians_by_biome.get(biome_id, "")
	return guardians.get(gid, {})

func get_pet(id: String) -> Dictionary:
	return pets.get(id, {})

func get_pet_for_egg(egg_id: String) -> Dictionary:
	var pid: String = pets_by_egg.get(egg_id, "")
	return pets.get(pid, {})

func get_upgrade(id: String) -> Dictionary:
	return upgrades.get(id, {})

func get_all_upgrades() -> Dictionary:
	return upgrades


# ---------- Helpers ----------
func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[DataRegistry] Missing file: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[DataRegistry] Cannot open: %s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[DataRegistry] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data


# ---------- Color/Type helpers ----------
func color_from_hex(hex: String) -> Color:
	# Accepts "#rrggbb" or "rrggbb"
	var s := hex.lstrip("#")
	if s.length() != 6:
		return Color.WHITE
	var r := s.substr(0, 2).hex_to_int() / 255.0
	var g := s.substr(2, 2).hex_to_int() / 255.0
	var b := s.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)
