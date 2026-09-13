extends Node
## DataRegistry
## Singleton that loads and caches all JSON game data at boot.
## Provides fast look-up helpers for eggs, pets, biomes, upgrades, etc.

signal data_loaded

var _eggs: Dictionary = {}
var _pets: Dictionary = {}
var _biomes: Dictionary = {}
var _npcs: Dictionary = {}
var _upgrades: Dictionary = {}
var _quests: Array = []
var _achievements: Array = []
var _sizes: Dictionary = {}
var _mutations: Dictionary = {}
var _rarities: Dictionary = {}
var _speed_xp_table: Array = []
var _achievement_rarity_order: Dictionary = {}
var _rarity_tier_order: Dictionary = {}

var _loaded: bool = false


func _ready() -> void:
        load_all_data()


func load_all_data() -> void:
        _eggs = _load_json("res://data/eggs.json")
        _pets = _load_json("res://data/pets.json")
        var biomes_data := _load_json("res://data/biomes.json")
        _biomes = biomes_data.get("biomes", {})
        _npcs = biomes_data.get("npcs", {})
        _upgrades = _load_json("res://data/upgrades.json")
        var quests_data := _load_json("res://data/quests.json")
        _quests = quests_data.get("quests", [])
        _achievements = _load_json("res://data/achievements.json").get("achievements", [])
        var pet_attrs := _load_json("res://data/pet_attributes.json")
        _sizes = pet_attrs.get("sizes", {})
        _mutations = pet_attrs.get("mutations", {})
        var level_data: Dictionary = pet_attrs.get("level_table", {})
        _speed_xp_table = level_data.get("xp_to_next", [])
        _rarities = _eggs.get("rarities", {})
        _eggs = _eggs.get("eggs", _eggs)
        _achievement_rarity_order = _load_json("res://data/achievements.json").get("rarity_tier_order", {})
        _rarity_tier_order = _achievement_rarity_order
        _loaded = true
        data_loaded.emit()
        print("[DataRegistry] Loaded %d eggs, %d pets, %d biomes, %d upgrades, %d quests, %d achievements" % [
                _eggs.size(), _pets.size(), _biomes.size(), _upgrades.size(), _quests.size(), _achievements.size()
        ])


func _load_json(path: String) -> Dictionary:
        if not FileAccess.file_exists(path):
                push_warning("[DataRegistry] Missing file: %s" % path)
                return {}
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
                push_error("[DataRegistry] Cannot open: %s" % path)
                return {}
        var text := file.get_as_text()
        file.close()
        var result: Variant = JSON.parse_string(text)
        if result == null:
                push_error("[DataRegistry] Invalid JSON in: %s" % path)
                return {}
        return result


# ---------- Accessors ----------
func get_egg(egg_id: String) -> Dictionary:
        return _eggs.get(egg_id, {})

func get_all_eggs() -> Dictionary:
        return _eggs

func get_pet(pet_id: String) -> Dictionary:
        return _pets.get(pet_id, {})

func get_all_pets() -> Dictionary:
        return _pets

func get_biome(biome_id: String) -> Dictionary:
        return _biomes.get(biome_id, {})

func get_all_biomes() -> Dictionary:
        return _biomes

func get_npc(npc_id: String) -> Dictionary:
        return _npcs.get(npc_id, {})

func get_upgrade(upgrade_id: String) -> Dictionary:
        return _upgrades.get(upgrade_id, {})

func get_upgrade_def(upgrade_id: String) -> Dictionary:
        # 'upgrades' wraps definitions under 'upgrades' key
        var u: Dictionary = _upgrades.get("upgrades", {})
        return u.get(upgrade_id, {})

func get_quests() -> Array:
        return _quests

func get_achievements() -> Array:
        return _achievements

func get_size_info(size_name: String) -> Dictionary:
        return _sizes.get(size_name, {"multiplier": 1.0, "color": "#FFFFFF"})

func get_mutation_info(mut_name: String) -> Dictionary:
        return _mutations.get(mut_name, {"multiplier": 1.0, "color": "#FFFFFF"})

func get_rarity_info(rarity_name: String) -> Dictionary:
        return _rarities.get(rarity_name, {"color": "#FFFFFF", "multiplier": 1.0})

func get_speed_xp_for_level(level: int) -> int:
        # level is 1-indexed; returns XP needed to go from `level` to `level+1`
        if level - 1 < _speed_xp_table.size():
                return int(_speed_xp_table[level - 1])
        # extrapolate beyond table
        return int(_speed_xp_table[-1] * pow(1.5, level - _speed_xp_table.size()))

func get_rarity_tier(rarity_name: String) -> int:
        return int(_rarity_tier_order.get(rarity_name, 0))

# ---------- Rolls ----------
func roll_weighted(entries: Array, weight_key: String = "weight") -> Dictionary:
        var total: float = 0.0
        for e in entries:
                total += float(e.get(weight_key, 1.0))
        if total <= 0.0:
                return {}
        var roll: float = randf() * total
        var acc: float = 0.0
        for e in entries:
                acc += float(e.get(weight_key, 1.0))
                if roll <= acc:
                        return e
        return entries.back() if entries.size() > 0 else {}

func roll_size() -> String:
        var entries: Array = []
        for key in _sizes.keys():
                var info: Dictionary = _sizes[key]
                entries.append({"name": key, "weight": info.get("rarity", 0.0)})
        var picked: Dictionary = roll_weighted(entries)
        return picked.get("name", "Normal")

func roll_mutation(mutation_chance: float = 0.0) -> String:
        # If a mutation is rolled, pick weighted from mutations (excluding Normal)
        # but treat Normal as the fallback that absorbs the rest of the probability mass.
        var roll := randf()
        if roll > mutation_chance:
                return "Normal"
        var entries: Array = []
        for key in _mutations.keys():
                if key == "Normal":
                        continue
                var info: Dictionary = _mutations[key]
                entries.append({"name": key, "weight": info.get("rarity", 0.0)})
        if entries.is_empty():
                return "Normal"
        var picked: Dictionary = roll_weighted(entries)
        return picked.get("name", "Normal")

func roll_special_size(size_special_chance: float = 0.0) -> String:
        # Same idea: 70% chance to be Normal unless special triggered
        var roll := randf()
        if roll > size_special_chance:
                return "Normal"
        var entries: Array = []
        for key in _sizes.keys():
                if key == "Normal":
                        continue
                var info: Dictionary = _sizes[key]
                entries.append({"name": key, "weight": info.get("rarity", 0.0)})
        if entries.is_empty():
                return "Normal"
        var picked: Dictionary = roll_weighted(entries)
        return picked.get("name", "Normal")

func is_loaded() -> bool:
        return _loaded
