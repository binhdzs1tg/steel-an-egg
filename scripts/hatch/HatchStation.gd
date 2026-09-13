extends Node3D
class_name HatchStation
## Hatch Station at the Base. Player interacts with a carried egg to start hatching.
## Spawns an EggVisual that animates through the 7 stages (idle -> shake -> glow -> crack -> open -> pet -> message).

signal hatch_started(egg_uid: String)
signal hatch_complete(pet_data: Dictionary)

@onready var station_prompt: Label3D = null
@onready var egg_holder: Marker3D = null
@onready var effect_light: OmniLight3D = null

var is_hatching: bool = false
var current_hatch_egg: Dictionary = {}
var hatch_time_left: float = 0.0
var hatch_total: float = 0.0
var stage: int = 0

var visual_egg: MeshInstance3D
var visual_pet: PetVisual


func _ready() -> void:
        _build_nodes()


func _build_nodes() -> void:
        # Station base
        var base_mesh := MeshInstance3D.new()
        var base_box := BoxMesh.new()
        base_box.size = Vector3(2.0, 0.2, 2.0)
        var base_mat := StandardMaterial3D.new()
        base_mat.albedo_color = Color(0.5, 0.45, 0.4)
        base_mesh.mesh = base_box
        base_mesh.material_override = base_mat
        add_child(base_mesh)

        # Pillar
        var pillar := MeshInstance3D.new()
        var pillar_mesh := CylinderMesh.new()
        pillar_mesh.radius = 0.2
        pillar_mesh.height = 1.2
        var pillar_mat := StandardMaterial3D.new()
        pillar_mat.albedo_color = Color(0.4, 0.35, 0.3)
        pillar.mesh = pillar_mesh
        pillar.material_override = pillar_mat
        pillar.position = Vector3(0, 0.7, 0)
        add_child(pillar)

        # Egg holder
        egg_holder = Marker3D.new()
        egg_holder.position = Vector3(0, 1.5, 0)
        add_child(egg_holder)

        # Effect light
        effect_light = OmniLight3D.new()
        effect_light.light_color = Color.WHITE
        effect_light.light_energy = 0.0
        effect_light.omni_range = 5.0
        effect_light.position = Vector3(0, 1.5, 0)
        add_child(effect_light)

        # Prompt label
        station_prompt = Label3D.new()
        station_prompt.position = Vector3(0, 2.5, 0)
        station_prompt.pixel_size = 0.015
        station_prompt.font_size = 28
        station_prompt.outline_size = 6
        station_prompt.outline_modulate = Color.BLACK
        station_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        station_prompt.text = "Hatch Station"
        station_prompt.visible = true
        add_child(station_prompt)

        # Collision for interaction (Area3D)
        var area := Area3D.new()
        area.name = "InteractionArea"
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(2.5, 2.5, 2.5)
        col.shape = shape
        area.add_child(col)
        add_child(area)
        # Connect via direct body signal — but Area3D is parented to HatchStation; we'll just rely on the player's raycast hit on this node.
        # Static body for raycast target
        var static_body := StaticBody3D.new()
        var s_col := CollisionShape3D.new()
        var s_shape := BoxShape3D.new()
        s_shape.size = Vector3(2.0, 2.0, 2.0)
        s_col.shape = s_shape
        s_col.position = Vector3(0, 1.0, 0)
        static_body.add_child(s_col)
        add_child(static_body)


func _process(delta: float) -> void:
        if is_hatching:
                hatch_time_left -= delta
                _update_stage()
                # Animate egg
                if visual_egg:
                        match stage:
                                0:
                                        visual_egg.rotation.y += delta * 0.5
                                1:
                                        visual_egg.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.05
                                        visual_egg.rotation.y += delta * 1.5
                                2:
                                        visual_egg.rotation.y += delta * 2.5
                                        effect_light.light_energy = lerpf(effect_light.light_energy, 1.5, delta * 4.0)
                                3:
                                        visual_egg.rotation.y += delta * 4.0
                                        effect_light.light_energy = lerpf(effect_light.light_energy, 2.5, delta * 6.0)
                                        if not _crack_sound_played:
                                                _crack_sound_played = true
                                                AudioManager.play_sfx("hatch_crack")
                                4:
                                        visual_egg.scale = visual_egg.scale.lerp(Vector3(1.3, 1.3, 1.3), delta * 2.0)
                                5:
                                        if visual_egg:
                                                visual_egg.visible = false
                                        if visual_pet == null:
                                                _spawn_pet_visual()
                if hatch_time_left <= 0:
                        _complete_hatch()


var _crack_sound_played: bool = false


func _update_stage() -> void:
        var progress := 1.0 - (hatch_time_left / hatch_total)
        var new_stage := clampi(int(progress * 6.0), 0, 6)
        if new_stage != stage:
                stage = new_stage


func get_prompt_text() -> String:
        if is_hatching:
                return "Hatching... %.1fs" % max(0.0, hatch_time_left)
        if GameManager.carrying_egg_id.is_empty():
                return "Hatch Station (carry an egg here)"
        return "Hatch Egg"


func interact(player: Node) -> void:
        if is_hatching:
                NotificationSystem.notify("Already hatching!", "info", 1.0)
                return
        if GameManager.carrying_egg_id.is_empty():
                NotificationSystem.notify("No egg to hatch. Collect one first!", "info", 2.0)
                return
        _start_hatch_from_inventory()


func _start_hatch_from_inventory() -> void:
        var egg_uid := GameManager.carrying_egg_id
        var egg_entry: Dictionary = GameManager.remove_egg_from_inventory(egg_uid)
        if egg_entry.is_empty():
                NotificationSystem.notify("Could not find that egg!", "warning", 1.5)
                return
        GameManager.set_carrying_egg("")
        current_hatch_egg = egg_entry
        hatch_total = float(egg_entry.get("hatch_time", 10.0))
        hatch_time_left = hatch_total
        stage = 0
        is_hatching = true
        # Create egg visual at holder
        visual_egg = MeshInstance3D.new()
        var egg_mesh := SphereMesh.new()
        egg_mesh.radius = 0.3
        egg_mesh.height = 0.6
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.from_string(egg_entry.get("color", "#FFFFFF"), Color.WHITE)
        mat.roughness = 0.4
        mat.emission_enabled = true
        mat.emission = Color.from_string(egg_entry.get("color", "#FFFFFF"), Color.WHITE) * 0.3
        egg_mesh.material = mat
        visual_egg.mesh = egg_mesh
        egg_holder.add_child(visual_egg)
        hatch_started.emit(egg_uid)
        NotificationSystem.notify("Hatching %s..." % egg_entry.get("name", "Egg"), "info", 1.5)
        AudioManager.play_sfx("hatch_start")


func _spawn_pet_visual() -> void:
        # Pre-roll the pet now so visual matches the result
        var pet_data := _roll_pet_from_egg(current_hatch_egg)
        visual_pet = PetVisual.new()
        visual_pet.set_script(preload("res://scripts/pet/PetVisual.gd"))
        visual_pet.position = Vector3(0, 1.0, 0)
        add_child(visual_pet)
        await get_tree().process_frame
        # Build visual data
        var visual_data := {
                "model_type": pet_data.get("model_type", "small_quad"),
                "color": pet_data.get("color", "#FFFFFF"),
                "scale": pet_data.get("scale", 1.0),
                "mutation_color": pet_data.get("mutation_color", "#FFFFFF"),
                "size_scale": pet_data.get("size_scale", 1.0),
        }
        visual_pet.set_pet_data(visual_data)
        # Save pet for actual game effect
        _pending_pet_data = pet_data


var _pending_pet_data: Dictionary = {}


func _complete_hatch() -> void:
        is_hatching = false
        hatch_time_left = 0.0
        # Reset crack sound flag
        _crack_sound_played = false
        # Show celebration notification
        var pet_data: Dictionary = _pending_pet_data
        if pet_data.is_empty():
                pet_data = _roll_pet_from_egg(current_hatch_egg)
        # Register pet in inventory
        GameManager.add_pet(pet_data)
        hatch_complete.emit(pet_data)
        # Notification
        var pet_name: String = pet_data.get("name", "Pet")
        var rarity: String = pet_data.get("rarity", "Common")
        var size_name: String = pet_data.get("size", "Normal")
        var mut_name: String = pet_data.get("mutation", "Normal")
        var display_name := pet_name
        if mut_name != "Normal":
                display_name = "%s %s" % [mut_name, pet_name]
        if size_name != "Normal":
                display_name = "%s %s" % [size_name, display_name]
        NotificationSystem.notify("NEW PET! %s" % display_name, "pet", 4.0)
        NotificationSystem.notify("Rarity: %s" % rarity, "info", 3.0)
        # Spawn VFX burst based on rarity
        var rarity_tier := DataRegistry.get_rarity_tier(rarity)
        var burst_color := Color.from_string(DataRegistry.get_rarity_info(rarity).get("color", "#FFFFFF"), Color.WHITE)
        var burst_count: int = 30 + rarity_tier * 20
        var burst_size: float = 0.12 + rarity_tier * 0.03
        var burst_speed: float = 3.0 + rarity_tier * 0.5
        var burst_duration: float = 1.0 + rarity_tier * 0.3
        VFXBurst.spawn_at(get_parent(), egg_holder.global_position, burst_color, burst_count, burst_size, burst_speed, burst_duration)
        # Camera shake based on rarity (rare+ only)
        if rarity_tier >= 3 and GameManager.player:
                GameManager.player.trigger_camera_shake(0.05 + rarity_tier * 0.04, 0.5 + rarity_tier * 0.2)
        # Play rarity-specific SFX
        match rarity:
                "Secret":
                        AudioManager.play_sfx("pet_appear_secret")
                "Mythic":
                        AudioManager.play_sfx("pet_appear_legendary")
                "Legendary":
                        AudioManager.play_sfx("pet_appear_legendary")
                "Epic":
                        AudioManager.play_sfx("pet_appear_rare")
                "Rare":
                        AudioManager.play_sfx("pet_appear_rare")
                _:
                        AudioManager.play_sfx("pet_appear_common")
        # Camera shake could be added here based on rarity
        # Reset visuals after 5 seconds
        await get_tree().create_timer(5.0).timeout
        if visual_pet:
                visual_pet.queue_free()
                visual_pet = null
        if visual_egg:
                visual_egg.queue_free()
                visual_egg = null
        effect_light.light_energy = 0.0
        current_hatch_egg = {}
        stage = 0


func _roll_pet_from_egg(egg_entry: Dictionary) -> Dictionary:
        var pet_pool: Array = egg_entry.get("pets", [])
        if pet_pool.is_empty():
                return {}
        var picked: Dictionary = DataRegistry.roll_weighted(pet_pool)
        var pet_id: String = picked.get("pet_id", "")
        var pet_def: Dictionary = DataRegistry.get_pet(pet_id)
        if pet_def.is_empty():
                return {}
        # Roll size & mutation
        var size_name := DataRegistry.roll_special_size(float(egg_entry.get("size_special_chance", 0.0)))
        var mut_name := DataRegistry.roll_mutation(float(egg_entry.get("mutation_chance", 0.0)))
        var size_info: Dictionary = DataRegistry.get_size_info(size_name)
        var mut_info: Dictionary = DataRegistry.get_mutation_info(mut_name)
        var pet_data := {
                "pet_id": pet_id,
                "name": pet_def.get("name", "Pet"),
                "rarity": pet_def.get("rarity", "Common"),
                "base_income": int(pet_def.get("base_income", 0)),
                "color": pet_def.get("color", "#FFFFFF"),
                "model_type": pet_def.get("model_type", "small_quad"),
                "scale": float(pet_def.get("scale", 1.0)),
                "size": size_name,
                "size_scale": float(size_info.get("multiplier", 1.0)),
                "mutation": mut_name,
                "mutation_color": mut_info.get("color", "#FFFFFF"),
                "mutation_multiplier": float(mut_info.get("multiplier", 1.0)),
                "level": 1,
                "xp": 0,
                "active": false,
                "hatched_at": Time.get_unix_time_from_system(),
        }
        return pet_data
