extends Node3D
class_name Biome
## A biome region in the world. Holds ground, spawn points, NPCs, and gates.
## Each biome is positioned at a unique location so the player walks from one to the next.
##
## PERF FIXES:
##   - No per-biome WorldEnvironment / DirectionalLight anymore. The world uses
##     a single global environment + sun owned by Main (8 biome environments and
##     8 shadow-casting suns used to fight each other and tank the FPS).
##   - Decorative trees are rendered with MultiMeshInstance3D (2 draw calls per
##     biome instead of 24+) and share one cached material.

@export var biome_id: String = "grassland"
@export var position_offset: Vector3 = Vector3.ZERO

# Layout: each biome is at a unique (x, z) offset so gates lead to the next biome
const BIOME_CHAIN := [
	"grassland", "forest", "desert", "snow",
	"volcano", "crystal_cave", "sky_island", "void"
]

static var _shared_mats: Dictionary = {}

var _spawn_points: Array = []
var _npcs: Array = []
var _gate: BiomeGate = null
var _ground: MeshInstance3D = null


static func _shared_mat(key: String, color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	if not _shared_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_shared_mats[key] = m
	return _shared_mats[key]


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

	# Spawn points (placed in a circle around center)
	var spawn_count: int = int(biome.get("spawn_points", 5))
	for i in range(spawn_count):
		var sp := EggSpawnPoint.new()
		sp.biome_id = biome_id
		var angle := TAU * float(i) / float(spawn_count)
		var radius := size * 0.35
		sp.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
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
		var npc: NPC = NPC.new()
		npc.npc_id = npc_id
		var angle := TAU * float(i + spawn_count) / float(spawn_count + npc_count)
		var radius := size * 0.4
		npc.position = Vector3(cos(angle) * radius, 0.9, sin(angle) * radius)
		add_child(npc)
		_npcs.append(npc)

	# Decorative trees / rocks (MultiMesh — cheap to render)
	_build_decor(size)

	# Boundary gates to neighbouring biomes
	_build_gate(biome)


func _build_decor(size: int) -> void:
	# 14 trees (trunk + leaves) rendered as two MultiMeshes = 2 draw calls.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id)
	var tree_count := 14

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.1
	trunk_mesh.bottom_radius = 0.15
	trunk_mesh.height = 1.5
	trunk_mesh.material = _shared_mat("tree_trunk", Color(0.4, 0.25, 0.1))

	var leaves_mesh := CylinderMesh.new()
	leaves_mesh.top_radius = 0.0
	leaves_mesh.bottom_radius = 0.8
	leaves_mesh.height = 1.8
	leaves_mesh.material = _shared_mat("tree_leaves", Color(0.2, 0.5, 0.2))

	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	trunk_mm.instance_count = tree_count

	var leaves_mm := MultiMesh.new()
	leaves_mm.transform_format = MultiMesh.TRANSFORM_3D
	leaves_mm.mesh = leaves_mesh
	leaves_mm.instance_count = tree_count

	for i in range(tree_count):
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(8.0, size * 0.45)
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		var yaw := rng.randf_range(0, TAU)
		var s := rng.randf_range(0.8, 1.3)
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s, s, s))
		trunk_mm.set_instance_transform(i, Transform3D(basis, pos + Vector3(0, 0.75 * s, 0)))
		leaves_mm.set_instance_transform(i, Transform3D(basis, pos + Vector3(0, 2.0 * s, 0)))

	var trunk_inst := MultiMeshInstance3D.new()
	trunk_inst.multimesh = trunk_mm
	add_child(trunk_inst)
	var leaves_inst := MultiMeshInstance3D.new()
	leaves_inst.multimesh = leaves_mm
	add_child(leaves_inst)


func _build_gate(biome: Dictionary) -> void:
	# Gate to next biome (determined by world layout)
	var next_biome: String = _get_next_biome_id(biome_id)
	if next_biome.is_empty():
		return
	_gate = BiomeGate.new()
	_gate.biome_id = next_biome
	# Place gate at the "north" edge of this biome
	var size: int = int(biome.get("size", 80))
	_gate.position = Vector3(0, 0.05, -size * 0.5 - 1.0)
	add_child(_gate)


func _get_next_biome_id(current: String) -> String:
	var idx: int = BIOME_CHAIN.find(current)
	if idx < 0 or idx + 1 >= BIOME_CHAIN.size():
		return ""
	return BIOME_CHAIN[idx + 1]
