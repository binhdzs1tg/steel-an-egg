extends Node3D
class_name Main
## World root. Builds all biomes at fixed positions, places the Base at origin,
## spawns the Player at the Base, and runs the per-frame tick for GameManager.

const BIOME_SPACING: float = 220.0  # distance between biome centers
const BIOME_CHAIN: Array = [
	"grassland", "forest", "desert", "snow",
	"volcano", "crystal_cave", "sky_island", "void"
]

var base_node: Node3D
var player: CharacterBody3D
var biomes: Dictionary = {}  # biome_id -> Biome node


func _ready() -> void:
	GameManager.set_world_root(self)
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

	# Try unlock biomes by initial speed
	GameManager.try_unlock_biome_by_speed()
	print("[Main] World ready. Biomes: %d, Player at %s" % [biomes.size(), player.position])


func _process(delta: float) -> void:
	GameManager.tick(delta)


func _on_notification(text: String, icon: String, duration: float) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, icon, duration)


func _on_log_message(text: String) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("add_log"):
		hud.add_log(text)
