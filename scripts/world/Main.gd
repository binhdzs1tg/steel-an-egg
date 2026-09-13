extends Node3D
class_name Main
## World root. Builds all biomes at fixed positions, places the Base at origin,
## spawns the Player at the Base, and runs the per-frame tick for GameManager.
##
## PERF / GRAPHICS FIXES:
##   - ONE DirectionalLight3D (with shadow) for the whole world. Previously every
##     biome spawned its own shadow-casting sun (8 shadow maps = huge GPU cost).
##   - ONE WorldEnvironment. Previously every biome created its own environment
##     (8 competing environments made the whole world render with the LAST one,
##     i.e. the Void biome's near-black sky — the "everything is dark" bug).
##     The atmosphere (sky / fog / ambient) now smoothly transitions to the
##     biome the player enters.
##   - Ground bridges are built between the Base, every biome, and the next
##     biome so the player can walk the whole chain without falling into the
##     void (the biomes are disjoint islands floating 100+ units apart).

const BIOME_SPACING: float = 220.0  # distance between biome centers
const BIOME_CHAIN: Array = [
	"grassland", "forest", "desert", "snow",
	"volcano", "crystal_cave", "sky_island", "void"
]
const BRIDGE_WIDTH: float = 12.0

var base_node: Node3D
var player: CharacterBody3D
var biomes: Dictionary = {}  # biome_id -> Biome node

var _env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _atmo_tween: Tween


func _ready() -> void:
	GameManager.set_world_root(self)
	# Single global sky + sun first so biomes render correctly from frame one.
	_build_global_environment()

	# Build the base first
	base_node = Node3D.new()
	base_node.set_script(preload("res://scripts/base/Base.gd"))
	base_node.position = Vector3(0, 0, 0)
	add_child(base_node)

	# Build all biomes in a row along -Z axis
	for i in range(BIOME_CHAIN.size()):
		var biome_id: String = BIOME_CHAIN[i]
		var biome := Node3D.new()
		biome.set_script(preload("res://scripts/world/Biome.gd"))
		biome.biome_id = biome_id
		biome.position = Vector3(0, 0, -BIOME_SPACING * (i + 1))
		add_child(biome)
		biomes[biome_id] = biome

	# Connect the world with walkable ground bridges (terrain fix).
	_build_ground_bridges()

	# Spawn the player at the base
	player = CharacterBody3D.new()
	player.set_script(preload("res://scripts/player/Player.gd"))
	player.position = Vector3(0, 1.0, 3.0)
	add_child(player)

	# Build the UI (HUD is a CanvasLayer built programmatically)
	var hud_script: GDScript = preload("res://scripts/ui/HUD.gd")
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	hud.name = "HUD"
	add_child(hud)
	hud._setup_ui()

	# Connect notifications to HUD
	NotificationSystem.notification_raised.connect(_on_notification)
	NotificationSystem.log_message.connect(_on_log_message)

	# Atmosphere follows the biome the player enters
	GameManager.biome_changed.connect(_on_biome_changed)
	_apply_atmosphere("grassland", 0.0)

	# Try unlock biomes by initial speed
	GameManager.try_unlock_biome_by_speed()
	print("[Main] World ready. Biomes: %d, Player at %s" % [biomes.size(), player.position])


func _process(delta: float) -> void:
	GameManager.tick(delta)


# ---------- Global environment ----------
func _build_global_environment() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Glow disabled: an 8x fullscreen post-processing pass for a low-poly
	# primitive world is not worth the GPU cost (was enabled per-biome before).
	env.glow_enabled = false
	env.fog_enabled = false

	_env = WorldEnvironment.new()
	_env.name = "GlobalEnvironment"
	_env.environment = env
	add_child(_env)

	# One global sun with shadows (previously one per biome).
	_sun = DirectionalLight3D.new()
	_sun.name = "GlobalSun"
	_sun.light_energy = 1.1
	_sun.rotation = Vector3(-0.7, 0.3, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 150.0
	add_child(_sun)


func _on_biome_changed(biome_id: String) -> void:
	_apply_atmosphere(biome_id, 0.8)


func _apply_atmosphere(biome_id: String, duration: float) -> void:
	var biome: Dictionary = DataRegistry.get_biome(biome_id)
	if biome.is_empty():
		return
	var ground_color := Color.from_string(biome.get("ground_color", "#558B2F"), Color(0.3, 0.5, 0.2))
	var sky_color := Color.from_string(biome.get("sky_color", "#87CEEB"), Color(0.4, 0.6, 0.9))
	var fog_color := Color.from_string(biome.get("fog_color", "#FFFFFF"), Color.WHITE)
	var fog_density := float(biome.get("fog_density", 0.0))
	var ambient_color := Color.from_string(biome.get("ambient_color", "#FFFFFF"), Color.WHITE)
	var ambient_energy := float(biome.get("ambient_energy", 0.8))

	if _atmo_tween and _atmo_tween.is_valid():
		_atmo_tween.kill()
	if duration <= 0.0:
		_sky_mat.sky_top_color = sky_color
		_sky_mat.sky_horizon_color = sky_color.lightened(0.1)
		_sky_mat.ground_bottom_color = ground_color.darkened(0.4)
		_sky_mat.ground_horizon_color = ground_color.darkened(0.2)
		_env.environment.fog_enabled = fog_density > 0.01
		_env.environment.fog_light_color = fog_color
		_env.environment.fog_density = fog_density
		_env.environment.ambient_light_color = ambient_color
		_env.environment.ambient_light_energy = ambient_energy
	else:
		_atmo_tween = create_tween().set_parallel(true)
		_atmo_tween.tween_property(_sky_mat, "sky_top_color", sky_color, duration)
		_atmo_tween.tween_property(_sky_mat, "sky_horizon_color", sky_color.lightened(0.1), duration)
		_atmo_tween.tween_property(_sky_mat, "ground_bottom_color", ground_color.darkened(0.4), duration)
		_atmo_tween.tween_property(_sky_mat, "ground_horizon_color", ground_color.darkened(0.2), duration)
		_atmo_tween.tween_property(_env.environment, "fog_light_color", fog_color, duration)
		_atmo_tween.tween_property(_env.environment, "fog_density", fog_density, duration)
		_atmo_tween.tween_property(_env.environment, "ambient_light_color", ambient_color, duration)
		_atmo_tween.tween_property(_env.environment, "ambient_light_energy", ambient_energy, duration)
		_atmo_tween.chain().tween_callback(func() -> void:
			_env.environment.fog_enabled = fog_density > 0.01)


# ---------- Ground bridges (terrain connectivity fix) ----------
func _build_ground_bridges() -> void:
	# Bridge Base (origin, radius 8) <-> grassland (center z=-220, size 80)
	# Grassland spans z in [-260, -180]; base edge at z=-8.
	_make_bridge(Vector3(0, 0, (-8.0 + -180.0) * 0.5), 172.0, _biome_ground_color("grassland"))
	# Bridge each biome to the next one.
	for i in range(BIOME_CHAIN.size() - 1):
		var cur: Dictionary = DataRegistry.get_biome(BIOME_CHAIN[i])
		var nxt: Dictionary = DataRegistry.get_biome(BIOME_CHAIN[i + 1])
		if cur.is_empty() or nxt.is_empty():
			continue
		var cur_size := float(cur.get("size", 80))
		var nxt_size := float(nxt.get("size", 80))
		var cur_center_z := -BIOME_SPACING * (i + 1)
		var nxt_center_z := -BIOME_SPACING * (i + 2)
		# Gap from the south edge of biome i+1 to the north edge of biome i.
		var from_z := nxt_center_z + nxt_size * 0.5
		var to_z := cur_center_z - cur_size * 0.5
		var length := to_z - from_z
		if length <= 0.0:
			continue
		_make_bridge(Vector3(0, 0, (from_z + to_z) * 0.5), length, _biome_ground_color(BIOME_CHAIN[i]))


func _biome_ground_color(biome_id: String) -> Color:
	var biome: Dictionary = DataRegistry.get_biome(biome_id)
	return Color.from_string(biome.get("ground_color", "#558B2F"), Color(0.3, 0.5, 0.2))


func _make_bridge(center: Vector3, length: float, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BRIDGE_WIDTH, 0.2, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.15)
	mat.roughness = 0.95
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = center + Vector3(0, -0.1, 0)
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BRIDGE_WIDTH, 1.0, length)
	col.shape = shape
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	body.position = center
	add_child(body)


func _on_notification(text: String, icon: String, duration: float) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, icon, duration)


func _on_log_message(text: String) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("add_log"):
		hud.add_log(text)
