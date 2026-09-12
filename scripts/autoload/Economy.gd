extends Node
## Economy
## Central place for: money, speed, upgrades, pet income, and offline earnings.
##
## All gameplay systems that need to know money / speed read from here.

signal money_changed(amount: int)
signal speed_changed(level: int, xp: int, xp_needed: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal pet_income_changed(per_second: int)

var _data: Dictionary = {}


func _ready() -> void:
	_data = SaveSystem.get_data()
	# Apply offline earnings on boot
	var rate := get_pet_income_per_second()
	if rate > 0:
		var earned := SaveSystem.apply_offline_earnings(rate)
		if earned > 0:
			print("[Economy] Offline earnings: $%d" % earned)
			await get_tree().create_timer(1.5).timeout
			NotificationSystem.notify("$%d offline earnings!" % earned, "money", 3.0)


# ---------- Money ----------
func get_money() -> int:
	return int(_data.get("money", 0))

func get_lifetime_earned() -> int:
	return int(_data.get("lifetime_earned", 0))

func get_lifetime_spent() -> int:
	return int(_data.get("lifetime_spent", 0))

func add_money(amount: int) -> void:
	if amount == 0:
		return
	_data["money"] = int(_data.get("money", 0)) + amount
	if amount > 0:
		_data["lifetime_earned"] = int(_data.get("lifetime_earned", 0)) + amount
		# Quest tracking: earn_money
		QuestSystem.progress_objective("earn_money", int(_data.get("lifetime_earned", 0)))
	SaveSystem.mark_dirty()
	money_changed.emit(get_money())

func spend_money(amount: int) -> bool:
	if get_money() < amount:
		return false
	_data["money"] = int(_data.get("money", 0)) - amount
	_data["lifetime_spent"] = int(_data.get("lifetime_spent", 0)) + amount
	SaveSystem.mark_dirty()
	money_changed.emit(get_money())
	return true


# ---------- Speed ----------
func get_speed_level() -> int:
	return int(_data.get("speed_level", 1))

func get_speed_xp() -> int:
	return int(_data.get("speed_xp", 0))

func get_speed_value() -> float:
	# Base 16 + 2 per level
	return 16.0 + 2.0 * (get_speed_level() - 1) + get_treadmill_bonus()

func get_treadmill_bonus() -> float:
	# Treadmill level adds to the displayed speed value (treated as effective speed)
	var lvl := get_upgrade_level("treadmill")
	return float(lvl) * 0.5

func get_speed_xp_needed() -> int:
	return DataRegistry.get_speed_xp_for_level(get_speed_level())

func add_speed_xp(amount: int) -> void:
	if amount <= 0:
		return
	var xp: int = get_speed_xp() + amount
	var needed: int = get_speed_xp_needed()
	while xp >= needed and get_speed_level() < 50:
		xp -= needed
		_data["speed_level"] = int(_data.get("speed_level", 1)) + 1
		NotificationSystem.notify("Speed Level Up! %d" % get_speed_level(), "speed", 2.0)
		QuestSystem.progress_objective("reach_speed", get_speed_level())
		needed = get_speed_xp_for_level(get_speed_level())
	_data["speed_xp"] = xp
	SaveSystem.mark_dirty()
	speed_changed.emit(get_speed_level(), get_speed_xp(), get_speed_xp_needed())


# ---------- Upgrades ----------
func get_upgrade_level(upgrade_id: String) -> int:
	var ups: Dictionary = _data.get("upgrades", {})
	return int(ups.get(upgrade_id, 0))

func get_upgrade_cost(upgrade_id: String) -> int:
	var def: Dictionary = DataRegistry.get_upgrade_def(upgrade_id)
	if def.is_empty():
		return 999999
	var base: int = int(def.get("base_cost", 100))
	var mult: float = float(def.get("cost_multiplier", 1.5))
	var level := get_upgrade_level(upgrade_id)
	return int(base * pow(mult, level))

func get_upgrade_max_level(upgrade_id: String) -> int:
	var def: Dictionary = DataRegistry.get_upgrade_def(upgrade_id)
	return int(def.get("max_level", 1))

func can_upgrade(upgrade_id: String) -> bool:
	if get_upgrade_level(upgrade_id) >= get_upgrade_max_level(upgrade_id):
		return false
	return get_money() >= get_upgrade_cost(upgrade_id)

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_upgrade(upgrade_id):
		return false
	var cost := get_upgrade_cost(upgrade_id)
	if not spend_money(cost):
		return false
	var ups: Dictionary = _data.get("upgrades", {})
	ups[upgrade_id] = int(ups.get(upgrade_id, 0)) + 1
	_data["upgrades"] = ups
	# Update derived caps
	if upgrade_id == "pet_slots":
		_data["active_pet_slots"] = get_pet_slots_for_level(get_upgrade_level("pet_slots"))
	elif upgrade_id == "egg_storage":
		_data["egg_storage"] = get_egg_storage_for_level(get_upgrade_level("egg_storage"))
	SaveSystem.mark_dirty()
	upgrade_purchased.emit(upgrade_id, get_upgrade_level(upgrade_id))
	NotificationSystem.notify("Upgraded %s to Lv.%d" % [upgrade_id.replace("_"," ").capitalize(), get_upgrade_level(upgrade_id)], "upgrade", 2.0)
	return true

func get_pet_slots_for_level(level: int) -> int:
	var def: Dictionary = DataRegistry.get_upgrade_def("pet_slots")
	var table: Array = def.get("slot_table", [3, 5, 8, 12, 20, 30, 40, 50])
	if level < table.size():
		return int(table[level])
	return int(table[-1])

func get_egg_storage_for_level(level: int) -> int:
	var def: Dictionary = DataRegistry.get_upgrade_def("egg_storage")
	var table: Array = def.get("slot_table", [5, 10, 20, 30, 50, 100, 150, 250])
	if level < table.size():
		return int(table[level])
	return int(table[-1])

func get_active_pet_slots() -> int:
	return int(_data.get("active_pet_slots", 3))

func get_egg_storage_cap() -> int:
	return int(_data.get("egg_storage", 5))

func get_income_boost_multiplier() -> float:
	var lvl := get_upgrade_level("income_boost")
	var def: Dictionary = DataRegistry.get_upgrade_def("income_boost")
	var base: float = float(def.get("base_value", 1.0))
	var per: float = float(def.get("value_per_level", 0.25))
	return base + per * lvl


# ---------- Pet income ----------
func get_pet_income_per_second() -> int:
	# Sum income of active pets, apply boost multiplier
	var pets: Array = _data.get("pets", [])
	var slots := get_active_pet_slots()
	var total: float = 0.0
	var active_count := 0
	for pet in pets:
		if active_count >= slots:
			break
		if bool(pet.get("active", false)):
			total += _compute_pet_income(pet)
			active_count += 1
	total *= get_income_boost_multiplier()
	return int(total)

func _compute_pet_income(pet: Dictionary) -> float:
	var base: int = int(pet.get("base_income", 0))
	var size_mult: float = float(DataRegistry.get_size_info(pet.get("size", "Normal")).get("multiplier", 1.0))
	var mut_mult: float = float(DataRegistry.get_mutation_info(pet.get("mutation", "Normal")).get("multiplier", 1.0))
	var lvl_mult: float = _pet_level_multiplier(int(pet.get("level", 1)))
	return float(base) * size_mult * mut_mult * lvl_mult

func _pet_level_multiplier(level: int) -> float:
	var attrs_path := "res://data/pet_attributes.json"
	# Hard-coded fallback matching pet_attributes.json
	var table := [1.0, 1.2, 1.5, 2.0, 3.0, 4.0, 5.5, 7.0, 9.0, 12.0]
	if level - 1 < table.size():
		return table[level - 1]
	return table[-1] * pow(1.5, level - table.size())

# Called by GameManager's process tick to accumulate income
var _income_accumulator: float = 0.0
func tick_income(delta: float) -> void:
	var rate := get_pet_income_per_second()
	if rate <= 0:
		return
	_income_accumulator += rate * delta
	while _income_accumulator >= 1.0:
		add_money(1)
		_income_accumulator -= 1.0
	pet_income_changed.emit(rate)
