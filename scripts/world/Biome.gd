extends Node3D
class_name Biome
## A biome region in the world. Holds ground, sky, spawn points, NPCs, and gates.
## Each biome is positioned at a unique location so the player walks from one to the next.

@export var biome_id: String = "grassland"
@export var position_offset: Vector3 = Vector3.ZERO

var _spawn_points: Array = []
var _npcs: Array = []
var _gate: BiomeGate = null
var _ground: MeshInstance3D = null
var _env: WorldEnvironment = null


func _ready() -> void:
	_build_nodes()


func _build_nodes() -> void:
	var biome: Dictionary = DataRegistry.get_biome(biome_id)
	if biome.is_empty():
		push_warning("[Biome] No data for id: %s" % biome_id)
		return
	var size: int = int(biome.get("size", 80))

	# Ground plane
	_ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	var ground_color_str: String = biome.get("ground_color", "#558B2F")
	mat.albedo_color = Color.from_string(ground_color_str, Color(0.3, 0.5, 0.2))
	mat.roughness = 0.9
	plane.material = mat
	_ground.mesh = plane
	_ground.position = Vector3.ZERO
	add_child(_ground)

	# Static body for ground collision
	var ground_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 1.0, size)
	col.shape = shape
	col.position = Vector3(0, -0.5, 0)
	ground_body.add_child(col)
	add_child(ground_body)

	# WorldEnvironment (sky/fog)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var sky_color_str: String = biome.get("sky_color", "#87CEEB")
	sky_mat.sky_top_color = Color.from_string(sky_color_str, Color(0.4, 0.6, 0.9))
	sky_mat.sky_horizon_color = Color.from_string(sky_color_str, Color(0.7, 0.8, 0.9)).lightened(0.1)
	sky_mat.ground_bottom_color = Color.from_string(ground_color_str, Color(0.2, 0.4, 0.1)).darkened(0.4)
	sky_mat.ground_horizon_color = Color.from_string(ground_color_str, Color(0.3, 0.4, 0.2)).darkened(0.2)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var fog_color_str: String = biome.get("fog_color", "#FFFFFF")
	env.fog_enabled = float(biome.get("fog_density", 0.0)) > 0.01
	env.fog_light_color = Color.from_string(fog_color_str, Color.WHITE)
	env.fog_density = float(biome.get("fog_density", 0.0))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.from_string(biome.get("ambient_color", "#FFFFFF"), Color.WHITE)
	env.ambient_light_energy = float(biome.get("ambient_energy", 0.8))
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env = WorldEnvironment.new()
	_env.environment = env
	add_child(_env)

	# Directional light
	var dir_light := DirectionalLight3D.new()
	dir_light.light_energy = 1.0
	dir_light.position = Vector3(0, 30, 0)
	dir_light.rotation = Vector3(-0.7, 0.3, 0)
	dir_light.shadow_enabled = true
	add_child(dir_light)

	# Spawn points (placed in a circle around center)
	var spawn_count: int = int(biome.get("spawn_points", 5))
	for i in range(spawn_count):
		var sp := EggSpawnPoint.new()
		sp.set_script(preload("res://scripts/world/EggSpawnPoint.gd"))
		sp.biome_id = biome_id
		var angle := TAU * float(i) / float(spawn_count)
		var radius := size * 0.35
		sp.position = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		add_child(sp)
		_spawn_points.append(sp)

	# NPCs
	var npc_pool: Array = biome.get("npc_pool", [])
	var npc_count: int = int(biome.get("npc_count", 1))
	for i in range(npc_count):
		if npc_pool.is_empty():
			break
		var npc_entry: Dictionary = DataRegistry.roll_weighted(npc_pool)
		var npc_id: String = npc_entry.get("npc_id", "")
		if npc_id.is_empty():
			continue
		var npc_script := preload("res://scripts/npc/NPC.gd")
		var npc: NPC = NPC.new()
		npc.set_script(npc_script)
		npc.npc_id = npc_id
		var angle := TAU * float(i + spawn_count) / float(spawn_count + npc_count)
		var radius := size * 0.4
		npc.position = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		add_child(npc)
		await get_tree().process_frame
		if npc.has_method("init_npc"):
			npc.init_npc(npc_id)
		_npcs.append(npc)

	# Decorative trees / rocks (a few primitives scattered around)
	_build_decor(size)

	# Boundary gates to neighbouring biomes
	_build_gate(biome)


func _build_decor(size: int) -> void:
	# Add 10-15 small "trees" (cone + cylinder) around the biome
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id)
	var tree_count := 12
	for i in range(tree_count):
		var tree := Node3D.new()
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.1
		trunk_mesh.bottom_radius = 0.15
		trunk_mesh.height = 1.5
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position = Vector3(0, 0.75, 0)
		tree.add_child(trunk)
		var leaves := MeshInstance3D.new()
		var leaves_mesh := ConeMesh.new()
		leaves_mesh.radius = 0.8
		leaves_mesh.height = 1.8
		var leaves_mat := StandardMaterial3D.new()
		leaves_mat.albedo_color = Color(0.2, 0.5, 0.2)
		leaves.mesh = leaves_mesh
		leaves.material_override = leaves_mat
		leaves.position = Vector3(0, 2.0, 0)
		tree.add_child(leaves)
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(8.0, size * 0.45)
		tree.position = Vector3(cos(a) * r, 0, sin(a) * r)
		tree.rotation.y = rng.randf_range(0, TAU)
		var s := rng.randf_range(0.8, 1.3)
		tree.scale = Vector3(s, s, s)
		add_child(tree)


func _build_gate(biome: Dictionary) -> void:
	# Gate to next biome (determined by world layout)
	var next_biome: String = _get_next_biome_id(biome_id)
	if next_biome.is_empty():
		return
	_gate = BiomeGate.new()
	_gate.set_script(preload("res://scripts/world/BiomeGate.gd"))
	_gate.biome_id = next_biome
	# Place gate at the "north" edge of this biome
	var size: int = int(biome.get("size", 80))
	_gate.position = Vector3(0, 0.05, -size * 0.5 - 1.0)
	add_child(_gate)


# Layout: each biome is at a unique (x, z) offset so gates lead to the next biome
const BIOME_CHAIN := [
	"grassland", "forest", "desert", "snow",
	"volcano", "crystal_cave", "sky_island", "void"
]


func _get_next_biome_id(current: String) -> String:
	var idx: int = BIOME_CHAIN.find(current)
	if idx < 0 or idx + 1 >= BIOME_CHAIN.size():
		return ""
	return BIOME_CHAIN[idx + 1]
