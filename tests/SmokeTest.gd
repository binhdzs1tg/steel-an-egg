extends Node
## Headless smoke test. Instantiates the real Main scene, lets it boot, then
## drives the main gameplay systems and prints PASS/FAIL lines.
## Run with: godot --headless --path . res://tests/SmokeTest.tscn

var _fails: int = 0
var _checks: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("%s %s %s" % ["[PASS]" if ok else "[FAIL]", name, extra])


func _ready() -> void:
	print("=== SMOKE TEST START ===")
	# Boot the real game scene
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main := main_scene.instantiate()
	add_child(main)
	await _wait_frames(5)

	# --- World / player ---
	var player: Player = GameManager.player
	_check("player_spawned", player != null)
	_check("world_root_set", GameManager._world_root != null)
	_check("biomes_built", main.biomes.size() == 8, "count=%d" % main.biomes.size())

	# --- Ground bridges exist (terrain connectivity) ---
	var bridges := 0
	for child in main.get_children():
		if child is StaticBody3D:
			bridges += 1
	_check("ground_bridges_present", bridges >= 8, "static_bodies=%d" % bridges)

	# --- Single global sun + environment (perf fix) ---
	var suns := 0
	var envs := 0
	var counts := _count_nodes(main)
	suns = counts.x
	envs = counts.y
	_check("single_directional_light", suns == 1, "suns=%d" % suns)
	_check("single_world_environment", envs == 1, "envs=%d" % envs)

	# --- No real-time egg lights (perf fix) ---
	var egg_lights := _count_egg_lights(main)
	_check("eggs_have_no_omni_lights", egg_lights == 0, "lights=%d" % egg_lights)

	# --- Eggs spawned ---
	var counts2 := _count_eggs(main)
	_check("egg_spawn_points", counts2.x >= 40, "points=%d" % counts2.x)
	_check("eggs_spawned", counts2.y == counts2.x, "eggs=%d points=%d" % [counts2.y, counts2.x])

	# --- Data-driven pet roll (pets.json unwrap fix) ---
	var pet_def: Dictionary = DataRegistry.get_pet("chicken")
	_check("pet_data_unwrapped", not pet_def.is_empty(), "name=%s" % pet_def.get("name", "?"))
	_check("all_pets_count", DataRegistry.get_all_pets().size() == 30)

	# --- Economy: money + upgrade purchase ---
	Economy.add_money(10000)
	_check("add_money", Economy.get_money() >= 10000, "money=%d" % Economy.get_money())
	var ups := DataRegistry.get_all_upgrade_defs()
	_check("upgrade_defs_cached", ups.size() == 6, "defs=%d" % ups.size())
	var first_id: String = ups.keys()[0]
	var lvl_before := Economy.get_upgrade_level(first_id)
	var ok_buy := Economy.purchase_upgrade(first_id)
	_check("purchase_upgrade", ok_buy and Economy.get_upgrade_level(first_id) == lvl_before + 1)

	# --- Egg collection flow ---
	var egg_entry := {
		"uid": "test_egg_1", "egg_id": "grassland_basic", "name": "Basic Egg",
		"rarity": "Common", "value": 10, "hatch_time": 1.0, "pets": [],
		"mutation_chance": 0.0, "size_special_chance": 0.0, "color": "#FFFFFF"
	}
	_check("add_egg", GameManager.add_egg_to_inventory(egg_entry))
	_check("egg_in_inventory", GameManager.egg_inventory_count() == 1)
	GameManager.set_carrying_egg("test_egg_1")

	# --- Hatch flow (via station internals) ---
	var hatch_station: HatchStation = _find_hatch_station(main)
	_check("hatch_station_found", hatch_station != null)
	if hatch_station:
		hatch_station._start_hatch_from_inventory()
		_check("hatch_started", hatch_station.is_hatching)
		hatch_station.hatch_time_left = 0.05  # fast-forward
		await _wait_frames(40)
		_check("hatch_completed", not GameManager.get_pets().is_empty(),
			"pets=%d" % GameManager.get_pets().size())

	# --- NPC damage & death ---
	var npc: NPC = _find_npc(main)
	_check("npc_found", npc != null)
	if npc:
		npc.take_damage(999999)
		_check("npc_dies", npc.visible == false or npc.hp == 0)

	# --- Biome gate / enter biome ---
	GameManager.unlock_biome("forest")
	GameManager.enter_biome("forest")
	_check("enter_biome", GameManager.current_biome_id == "forest")

	# --- Save / load roundtrip ---
	SaveSystem.force_save()
	_check("save_written", FileAccess.file_exists("user://save.json"))
	var money_before: int = Economy.get_money()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	_check("save_parseable", typeof(parsed) == TYPE_DICTIONARY)
	_check("save_money_matches", int(parsed.get("money", -1)) == money_before)

	# --- AudioManager: looping music (perf fix) ---
	AudioManager.play_sfx("ui_click")
	AudioManager.play_sfx("ui_click")
	var music_stream: AudioStreamWAV = AudioManager._music_player.stream
	_check("music_is_looping_wav", music_stream != null and music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)

	# --- Pet display exists and is signal-driven ---
	var display: PetDisplayArea = _find_display(main)
	_check("pet_display_found", display != null)

	print("=== SMOKE TEST DONE: %d checks, %d fails ===" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _count_nodes(node: Node) -> Vector2i:
	var result := Vector2i.ZERO  # x = directional lights, y = world environments
	for child in node.get_children():
		if child is DirectionalLight3D:
			result.x += 1
		elif child is WorldEnvironment:
			result.y += 1
		result += _count_nodes(child)
	return result


func _count_egg_lights(node: Node) -> int:
	var lights := 0
	if node is Egg:
		for child in node.get_children():
			if child is OmniLight3D:
				lights += 1
	for child in node.get_children():
		lights += _count_egg_lights(child)
	return lights


func _count_eggs(node: Node) -> Vector2i:
	var result := Vector2i.ZERO  # x = spawn points, y = live eggs
	for child in node.get_children():
		if child is EggSpawnPoint:
			result.x += 1
			if child.current_egg != null:
				result.y += 1
		result += _count_eggs(child)
	return result


func _find_hatch_station(node: Node) -> HatchStation:
	for child in node.get_children():
		if child is HatchStation:
			return child
		var found := _find_hatch_station(child)
		if found:
			return found
	return null


func _find_npc(node: Node) -> NPC:
	for child in node.get_children():
		if child is NPC:
			return child
		var found := _find_npc(child)
		if found:
			return found
	return null


func _find_display(node: Node) -> PetDisplayArea:
	for child in node.get_children():
		if child is PetDisplayArea:
			return child
		var found := _find_display(child)
		if found:
			return found
	return null
