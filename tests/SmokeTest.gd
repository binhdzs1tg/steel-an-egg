# SmokeTest.gd
# Headless smoke test that verifies data loading, game systems initialization,
# and basic mechanics without needing rendering.
# Run: godot --headless --script res://tests/SmokeTest.gd
extends SceneTree

var _pass: int = 0
var _fail: int = 0
var _errors: Array[String] = []
var _err_capture: Array[String] = [""]


func _init() -> void:
	print("=== Steal An Egg Simulator — Smoke Test ===")
	_run_tests()
	print("\n=== Results: %d passed, %d failed ===" % [_pass, _fail])
	if _errors.size() > 0:
		print("\nFailures:")
		for e in _errors:
			print("  - %s" % e)
	quit(0 if _fail == 0 else 1)


func _run_tests() -> void:
	# Test 1: DataRegistry loads all JSON files
	_test("DataRegistry loads biomes", func():
		var biomes: Array = DataRegistry.biomes_by_index
		_assert_eq(biomes.size(), 5, "Expected 5 biomes, got %d" % biomes.size())
	)
	_test("DataRegistry loads eggs", func():
		var count: int = DataRegistry.eggs.size()
		_assert_eq(count, 13, "Expected 13 eggs, got %d" % count)
	)
	_test("DataRegistry loads guardians", func():
		var count: int = DataRegistry.guardians.size()
		_assert_eq(count, 5, "Expected 5 guardians, got %d" % count)
	)
	_test("DataRegistry loads pets", func():
		var count: int = DataRegistry.pets.size()
		_assert_eq(count, 12, "Expected 12 pets, got %d" % count)
	)
	_test("DataRegistry loads upgrades", func():
		var count: int = DataRegistry.upgrades.size()
		_assert_eq(count, 5, "Expected 5 upgrades, got %d" % count)
	)
        
	# Test 2: Biome ordering
	_test("Biomes ordered by index", func():
		for i in range(DataRegistry.biomes_by_index.size() - 1):
			var a: int = int(DataRegistry.biomes_by_index[i]["index"])
			var b: int = int(DataRegistry.biomes_by_index[i + 1]["index"])
			_assert_true(a < b, "Biome indices out of order at %d" % i)
	)
        
	# Test 3: Eggs belong to valid biomes
	_test("Eggs reference valid biomes", func():
		for eid in DataRegistry.eggs.keys():
			var e: Dictionary = DataRegistry.eggs[eid]
			var bid: String = e["biome_id"]
			_assert_true(DataRegistry.biomes.has(bid), "Egg %s has unknown biome %s" % [eid, bid])
	)
        
	# Test 4: Pets reference valid eggs
	_test("Pets reference valid eggs", func():
		for pid in DataRegistry.pets.keys():
			var p: Dictionary = DataRegistry.pets[pid]
			var eid: String = p["egg_id"]
			_assert_true(DataRegistry.eggs.has(eid), "Pet %s references unknown egg %s" % [pid, eid])
	)
        
	# Test 5: Guardians reference valid biomes
	_test("Guardians reference valid biomes", func():
		for gid in DataRegistry.guardians.keys():
			var g: Dictionary = DataRegistry.guardians[gid]
			var bid: String = g["biome_id"]
			_assert_true(DataRegistry.biomes.has(bid), "Guardian %s has unknown biome %s" % [gid, bid])
	)
        
	# Test 6: Each biome has a guardian
	_test("Each biome has a guardian", func():
		for bid in DataRegistry.biomes.keys():
			_assert_true(DataRegistry.guardians_by_biome.has(bid), "Biome %s has no guardian" % bid)
	)
        
	# Test 7: Economy default state
	_test("Economy default money is 0", func():
		_assert_eq(Economy.get_money(), 0, "Default money should be 0")
	)
	_test("Economy default upgrade levels are 0", func():
		for uid in DataRegistry.upgrades.keys():
			_assert_eq(Economy.get_upgrade_level(uid), 0, "Upgrade %s should start at level 0" % uid)
	)
        
	# Test 8: Economy can add/spend money
	_test("Economy add_money works", func():
		Economy.add_money(100)
		_assert_eq(Economy.get_money(), 100, "Money should be 100 after add")
		Economy.add_money(-50)
		_assert_eq(Economy.get_money(), 50, "Money should be 50 after subtract")
	)
        
	# Test 9: Upgrade cost progression
	_test("Upgrade cost multiplies per level", func():
		var lvl: int = Economy.get_upgrade_level("speed_level")
		var cost0: int = Economy.get_upgrade_cost("speed_level")
		Economy.upgrade_levels["speed_level"] = 1
		var cost1: int = Economy.get_upgrade_cost("speed_level")
		_assert_true(cost1 > cost0, "Upgrade cost should increase with level")
		Economy.upgrade_levels["speed_level"] = lvl  # reset
	)
        
	# Test 10: Pet slots
	_test("Default pet slots = 3", func():
		_assert_eq(Economy.get_max_pet_slots(), 3, "Default coop_size = 3 slots")
	)
        
	# Test 11: Color parsing
	_test("Color parsing #rrggbb", func():
		var c: Color = DataRegistry.color_from_hex("#ff8800")
		_assert_eq(round(c.r * 255), 255, "R should be 255")
		_assert_eq(round(c.g * 255), 136, "G should be 136")
		_assert_eq(round(c.b * 255), 0, "B should be 0")
	)
        
	# Test 12: Save system can serialize/deserialize
	_test("SaveSystem roundtrip", func():
		var state: Dictionary = Economy.serialize()
		Economy.add_money(500)
		_assert_eq(Economy.get_money(), 550, "Money should be 550 after +500")
		Economy.deserialize(state)
		_assert_eq(Economy.get_money(), 50, "Money should restore to 50 after deserialize")
	)
        
	print("")


func _test(name: String, fn: Callable) -> void:
	print("  [RUN] %s" % name)
	var err_msg: String = ""
	# Run fn, capture any error message it raises via _assert_*
	_err_capture.clear()
	_err_capture.append("")
	fn.call()
	if _err_capture[0] != "":
		err_msg = _err_capture[0]
	if err_msg == "":
		_pass += 1
		print("  [PASS] %s" % name)
	else:
		_fail += 1
		_errors.append("%s: %s" % [name, err_msg])
		print("  [FAIL] %s — %s" % [name, err_msg])


func _assert_eq(actual, expected, msg: String) -> void:
	if actual != expected:
		_err_capture[0] = msg + " (got %s, expected %s)" % [str(actual), str(expected)]


func _assert_true(cond: bool, msg: String) -> void:
	if not cond:
		_err_capture[0] = msg


func _assert_not_null(v, msg: String) -> void:
	if v == null:
		_err_capture[0] = msg
