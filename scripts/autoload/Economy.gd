# Economy.gd
# Singleton that manages player progression: money, upgrade levels, upgrade costs.
# Talks to SaveSystem to persist state.
extends Node

signal money_changed(new_amount: int)
signal upgrade_changed(id: String, new_level: int)
signal pet_added(pet_id: String)
signal income_tick(amount: int)

# --- State ---
var money: int = 0
var upgrade_levels: Dictionary = {}    # id -> int level

# --- Income tracking ---
var _owned_pets: Array[String] = []     # list of pet IDs currently owned
var _income_accumulator: float = 0.0


func _ready() -> void:
	# Default upgrade levels
	for uid in DataRegistry.get_all_upgrades().keys():
		upgrade_levels[uid] = 0


# ---------- Money ----------
func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func get_money() -> int:
	return money


# ---------- Upgrades ----------
func get_upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


func get_upgrade_cost(id: String) -> int:
	var u: Dictionary = DataRegistry.get_upgrade(id)
	if u.is_empty():
		return 999999
	var lvl: int = get_upgrade_level(id)
	if lvl >= int(u["max_level"]):
		return -1  # maxed
	var base: int = int(u["base_cost"])
	var mult: float = float(u["cost_multiplier"])
	return int(base * pow(mult, lvl))


func get_upgrade_value(id: String) -> float:
	var u: Dictionary = DataRegistry.get_upgrade(id)
	if u.is_empty():
		return 0.0
	var lvl: int = get_upgrade_level(id)
	var base_v: float = float(u["base_value"])
	var inc: float = float(u["increment_per_level"])
	return base_v + inc * lvl


func buy_upgrade(id: String) -> bool:
	var cost: int = get_upgrade_cost(id)
	if cost < 0:
		return false  # maxed
	if not spend_money(cost):
		return false
	upgrade_levels[id] = get_upgrade_level(id) + 1
	upgrade_changed.emit(id, get_upgrade_level(id))
	return true


# ---------- Pets (income source) ----------
func register_pet(pet_id: String) -> void:
	if not _owned_pets.has(pet_id):
		_owned_pets.append(pet_id)
		pet_added.emit(pet_id)


func unregister_pet(pet_id: String) -> void:
	_owned_pets.erase(pet_id)


func get_pet_count() -> int:
	return _owned_pets.size()


func get_owned_pets() -> Array:
	return _owned_pets.duplicate()


# ---------- Income tick ----------
func _process(delta: float) -> void:
	if _owned_pets.is_empty():
		return
	var income_per_sec: float = 0.0
	var income_mult: float = get_upgrade_value("income_multiplier")
	for pid in _owned_pets:
		var p: Dictionary = DataRegistry.get_pet(pid)
		if p.is_empty():
			continue
		income_per_sec += float(p["income_per_min"]) / 60.0 * income_mult
	_income_accumulator += income_per_sec * delta
	while _income_accumulator >= 1.0:
		money += 1
		income_tick.emit(1)
		_income_accumulator -= 1.0
		# Only emit money_changed when accumulator hits 1 to avoid spamming
		money_changed.emit(money)


# ---------- Pet slots ----------
func get_max_pet_slots() -> int:
	# base 3 slots + 2 per level of coop_size upgrade
	return int(get_upgrade_value("coop_size"))


func has_free_pet_slot() -> bool:
	return _owned_pets.size() < get_max_pet_slots()


# ---------- Save/Load ----------
func serialize() -> Dictionary:
	return {
		"money": money,
		"upgrade_levels": upgrade_levels.duplicate(true),
		"owned_pets": _owned_pets.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	money = int(data.get("money", 0))
	var ul: Dictionary = data.get("upgrade_levels", {})
	upgrade_levels.clear()
	for uid in DataRegistry.get_all_upgrades().keys():
		upgrade_levels[uid] = int(ul.get(uid, 0))
	_owned_pets.clear()
	for pid in data.get("owned_pets", []):
		_owned_pets.append(pid)
	money_changed.emit(money)
