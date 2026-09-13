extends Node
## GameManager
## High-level game orchestrator. Knows the player, current biome, current mode.
## Other systems ask GameManager for the player node / camera / current biome.

signal player_ready(player: Node)
signal biome_changed(biome_id: String)
signal pet_inventory_changed()
signal egg_inventory_changed()
signal carrying_egg_changed(is_carrying: bool)

var player: CharacterBody3D = null
var camera_controller: Node = null
var current_biome_id: String = "grassland"
var carrying_egg_id: String = ""  # the egg currently being carried (instance id, not template)
var interaction_target: Node = null

var _data: Dictionary = {}
var _egg_instances: Dictionary = {}  # instance_id -> egg node
var _pet_instances: Dictionary = {}
var _world_root: Node3D = null


func _ready() -> void:
        _data = SaveSystem.get_data()
        # Hook achievement checks whenever money / pets change
        Economy.money_changed.connect(_on_money_changed)


func set_world_root(root: Node3D) -> void:
        _world_root = root


func set_player(p: CharacterBody3D) -> void:
        player = p
        player_ready.emit(p)


func set_camera_controller(c: Node) -> void:
        camera_controller = c


func get_data() -> Dictionary:
        return _data


# ---------- Biome ----------
func enter_biome(biome_id: String) -> void:
        if not (biome_id in _data.get("unlocked_biomes", [])):
                NotificationSystem.notify("AREA LOCKED", "locked", 2.0)
                var biome: Dictionary = DataRegistry.get_biome(biome_id)
                var required: int = int(biome.get("required_speed", 0))
                NotificationSystem.notify("Requires Speed %d" % required, "info", 2.0)
                return
        if current_biome_id == biome_id:
                return
        current_biome_id = biome_id
        biome_changed.emit(biome_id)
        QuestSystem.increment_objective("enter_biome", 1, biome_id)


func unlock_biome(biome_id: String) -> void:
        var unlocked: Array = _data.get("unlocked_biomes", [])
        if biome_id in unlocked:
                return
        unlocked.append(biome_id)
        _data["unlocked_biomes"] = unlocked
        SaveSystem.mark_dirty()
        NotificationSystem.notify("AREA UNLOCKED: %s" % DataRegistry.get_biome(biome_id).get("name", biome_id), "unlock", 4.0)
        AudioManager.play_sfx("unlock_biome")
        AchievementSystem.set_stat("biomes_unlocked", unlocked.size())


# Called when player crosses biome boundaries (handled by BiomeGate triggers)
func try_unlock_biome_by_speed() -> void:
        var current_speed := Economy.get_speed_level()
        for biome_id in DataRegistry.get_all_biomes().keys():
                var biome: Dictionary = DataRegistry.get_biome(biome_id)
                var required: int = int(biome.get("required_speed", 0))
                if current_speed >= required and not (biome_id in _data.get("unlocked_biomes", [])):
                        unlock_biome(biome_id)


# ---------- Egg inventory ----------
func get_egg_inventory() -> Array:
        return _data.get("egg_inventory", [])


func egg_inventory_count() -> int:
        return get_egg_inventory().size()


func can_carry_more_eggs() -> bool:
        return egg_inventory_count() < Economy.get_egg_storage_cap()


func add_egg_to_inventory(egg_data: Dictionary) -> bool:
        var inv: Array = get_egg_inventory()
        if inv.size() >= Economy.get_egg_storage_cap():
                NotificationSystem.notify("EGG INVENTORY FULL", "warning", 2.0)
                AudioManager.play_sfx("egg_pickup_fail")
                return false
        inv.append(egg_data)
        _data["egg_inventory"] = inv
        SaveSystem.mark_dirty()
        egg_inventory_changed.emit()
        AchievementSystem.increment_stat("eggs_collected", 1)
        QuestSystem.increment_objective("collect_egg", 1)
        AudioManager.play_sfx("egg_collect")
        return true


func remove_egg_from_inventory(egg_uid: String) -> Dictionary:
        var inv: Array = get_egg_inventory()
        for i in range(inv.size()):
                if inv[i].get("uid", "") == egg_uid:
                        var removed: Dictionary = inv[i]
                        inv.remove_at(i)
                        _data["egg_inventory"] = inv
                        SaveSystem.mark_dirty()
                        egg_inventory_changed.emit()
                        return removed
        return {}


func set_carrying_egg(egg_instance_id: String) -> void:
        carrying_egg_id = egg_instance_id
        carrying_egg_changed.emit(not egg_instance_id.is_empty())


# ---------- Pet inventory ----------
func get_pets() -> Array:
        return _data.get("pets", [])


func add_pet(pet_data: Dictionary) -> void:
        var pets: Array = get_pets()
        pet_data["uid"] = _gen_uid()
        pets.append(pet_data)
        _data["pets"] = pets
        SaveSystem.mark_dirty()
        pet_inventory_changed.emit()
        AchievementSystem.increment_stat("pets_hatched", 1)
        # Collection updates
        var was_new: bool = Collection.register_pet(pet_data.get("pet_id", ""))
        Collection.register_size(pet_data.get("size", "Normal"))
        Collection.register_mutation(pet_data.get("mutation", "Normal"))
        if was_new:
                AchievementSystem.set_stat("unique_pets", Collection.get_pet_collection().size())
        # Rarity stats
        var rarity_tier := DataRegistry.get_rarity_tier(pet_data.get("rarity", "Common"))
        var stats: Dictionary = _data.get("stats", {})
        if rarity_tier > int(stats.get("highest_pet_rarity_tier", 0)):
                stats["highest_pet_rarity_tier"] = rarity_tier
                _data["stats"] = stats
                AchievementSystem.check_all()
        if pet_data.get("rarity", "") == "Secret":
                AchievementSystem.increment_stat("secret_pets", 1)
        if DataRegistry.get_size_info(pet_data.get("size", "Normal")).get("multiplier", 1.0) >= 2.0:
                AchievementSystem.increment_stat("huge_pets", 1)
        if pet_data.get("mutation", "Normal") != "Normal":
                AchievementSystem.increment_stat("mutations_found", 1)
        QuestSystem.increment_objective("hatch_pet", 1)
        var rarity: String = pet_data.get("rarity", "Common")
        if DataRegistry.get_rarity_tier(rarity) >= DataRegistry.get_rarity_tier("Rare"):
                QuestSystem.increment_objective("obtain_rarity", 1, "", rarity)


func toggle_pet_active(pet_uid: String) -> void:
        var pets: Array = get_pets()
        var active_count := 0
        for p in pets:
                if bool(p.get("active", false)):
                        active_count += 1
        for p in pets:
                if p.get("uid", "") == pet_uid:
                        var currently_active := bool(p.get("active", false))
                        if currently_active:
                                p["active"] = false
                        else:
                                if active_count >= Economy.get_active_pet_slots():
                                        NotificationSystem.notify("Pet slots full", "warning", 1.5)
                                        return
                                p["active"] = true
                        _data["pets"] = pets
                        SaveSystem.mark_dirty()
                        pet_inventory_changed.emit()
                        return


func get_active_pets() -> Array:
        var result: Array = []
        for p in get_pets():
                if bool(p.get("active", false)):
                        result.append(p)
        return result


# ---------- UID helper ----------
var _uid_counter: int = 0
func _gen_uid() -> String:
        _uid_counter += 1
        return "%d_%d" % [Time.get_ticks_msec(), _uid_counter]


# ---------- Money change hook ----------
func _on_money_changed(_amount: int) -> void:
        AchievementSystem.set_stat("lifetime_earned", Economy.get_lifetime_earned())


# ---------- Tick ----------
func tick(delta: float) -> void:
        Economy.tick_income(delta)
        # Treadmill passive XP
        var treadmill_level := Economy.get_upgrade_level("treadmill")
        if treadmill_level > 0:
                var xp_table: Array = [1, 2, 4, 7, 12, 20, 33, 55, 90, 150, 250, 415, 690, 1150, 1900, 3150, 5200, 8600, 14200, 23500]
                var xp_per_sec: int = 0
                if treadmill_level - 1 < xp_table.size():
                        xp_per_sec = int(xp_table[treadmill_level - 1])
                else:
                        xp_per_sec = int(xp_table[-1])
                Economy.add_speed_xp(int(xp_per_sec * delta))
        # Try unlock biomes by speed
        try_unlock_biome_by_speed()
        # Achievement check (cheap)
        AchievementSystem.check_all()
