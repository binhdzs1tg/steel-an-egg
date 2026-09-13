extends Control
## Minimap
## A small 2D top-down map in the corner showing: player, base, biome gates, nearby eggs.
##
## FIXES:
##   - The canvas was connected to draw() but queue_redraw() was never called,
##     so the minimap only rendered once and then froze (graphics bug).
##     It now redraws at 10 Hz — cheap and smooth enough for a minimap.
##   - Moved to the bottom-right corner; it used to overlap the Activity Log
##     (both were placed at position 20,460).
##   - Script preloads are cached in constants instead of re-resolving inside
##     the draw loop, and invalid/freed nodes are guarded.

const MAP_SIZE: float = 180.0
const WORLD_RADIUS: float = 120.0  # how many world units fit in the minimap radius
const REDRAW_INTERVAL: float = 0.1
const CHAIN: Array = ["grassland", "forest", "desert", "snow", "volcano", "crystal_cave", "sky_island", "void"]

const EGG_SPAWN_SCRIPT: GDScript = preload("res://scripts/world/EggSpawnPoint.gd")
const NPC_SCRIPT: GDScript = preload("res://scripts/npc/NPC.gd")

var bg: Panel
var canvas: Control
var _redraw_timer: float = 0.0


func _setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	bg = Panel.new()
	bg.position = Vector2(1060, 495)
	bg.size = Vector2(MAP_SIZE, MAP_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.2, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	var title := Label.new()
	title.text = "MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	title.position = Vector2(0, 4)
	title.size = Vector2(MAP_SIZE, 14)
	bg.add_child(title)

	# Drawing canvas
	canvas = Control.new()
	canvas.position = Vector2(8, 22)
	canvas.size = Vector2(MAP_SIZE - 16, MAP_SIZE - 30)
	canvas.draw.connect(_on_draw)
	bg.add_child(canvas)


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		canvas.queue_redraw()


func _on_draw() -> void:
	if not GameManager.player or not is_instance_valid(GameManager.player):
		return
	var center := canvas.size * 0.5
	# Draw radial ring
	canvas.draw_arc(center, center.x - 4, 0, TAU, 64, Color(0.4, 0.6, 0.9, 0.4), 1.5)
	# Crosshair at center
	canvas.draw_line(Vector2(center.x - 6, center.y), Vector2(center.x + 6, center.y), Color(0.4, 0.6, 0.9, 0.3), 1.0)
	canvas.draw_line(Vector2(center.x, center.y - 6), Vector2(center.x, center.y + 6), Color(0.4, 0.6, 0.9, 0.3), 1.0)

	var player_pos: Vector3 = GameManager.player.global_position

	# Draw base at center (since base is at world origin)
	canvas.draw_circle(center, 4, Color(0.6, 1.0, 0.6))

	# Draw biome gates (north of each biome)
	for biome_id in GameManager.get_data().get("unlocked_biomes", []):
		var idx: int = CHAIN.find(biome_id)
		if idx < 0:
			continue
		var biome_z: float = -220.0 * (idx + 1)
		var rel := Vector2(0, biome_z) - Vector2(player_pos.x, player_pos.z)
		rel = rel / WORLD_RADIUS * (center.x - 8)
		var mp := center + rel
		if mp.distance_to(center) > center.x - 4:
			# Clamp to edge
			mp = center + rel.normalized() * (center.x - 8)
		canvas.draw_circle(mp, 3, Color(1.0, 0.85, 0.3))

	# Draw nearby eggs (within WORLD_RADIUS)
	var world_root: Node = GameManager._world_root
	if world_root and is_instance_valid(world_root):
		for biome in world_root.get_children():
			if not is_instance_valid(biome):
				continue
			for sp in biome.get_children():
				if not is_instance_valid(sp) or sp.get_script() != EGG_SPAWN_SCRIPT:
					continue
				if sp.current_egg != null and is_instance_valid(sp.current_egg):
					var egg_world: Vector3 = sp.current_egg.global_position
					var rel := Vector2(egg_world.x, egg_world.z) - Vector2(player_pos.x, player_pos.z)
					var mp := center + rel / WORLD_RADIUS * (center.x - 8)
					if mp.distance_to(center) < center.x - 6:
						canvas.draw_circle(mp, 2, Color(1.0, 0.7, 0.4))

		# Draw NPCs (red dots) within range
		for biome in world_root.get_children():
			if not is_instance_valid(biome):
				continue
			for npc in biome.get_children():
				if not is_instance_valid(npc) or npc.get_script() != NPC_SCRIPT:
					continue
				var npc_world: Vector3 = npc.global_position
				var rel := Vector2(npc_world.x, npc_world.z) - Vector2(player_pos.x, player_pos.z)
				var mp := center + rel / WORLD_RADIUS * (center.x - 8)
				if mp.distance_to(center) < center.x - 6:
					var color: Color = Color(1.0, 0.3, 0.3)
					if npc.state == npc.State.CHASE:
						color = Color(1.0, 0.1, 0.1)
					elif npc.state == npc.State.ATTACK:
						color = Color(1.0, 0.0, 0.0)
					canvas.draw_circle(mp, 2.5, color)

	# Draw player at center (always)
	canvas.draw_circle(center, 4, Color(0.4, 0.85, 1.0))
	# Direction arrow
	var yaw: float = GameManager.player.rotation.y
	var dir := Vector2(sin(yaw), -cos(yaw))
	canvas.draw_line(center, center + dir * 8, Color(0.4, 0.85, 1.0), 2.0)
