extends CharacterBody3D
class_name Player
## Player character with 3 camera modes:
##   1. Third-person classic — right mouse button to free-rotate around player
##   2. Shift-lock — hold Shift; camera locks behind shoulder, crosshair appears,
##      mouse moves the player's facing directly
##   3. First-person — scroll wheel forward past min distance to enter;
##      camera sits inside the head, body hidden, weapon/hands visible
##
## Carries an egg if GameManager.carrying_egg_id is set (visualised above head).
##
## The node tree is constructed in code so the script is fully self-contained.

signal interaction_prompt_changed(text: String, visible: bool)
signal camera_mode_changed(mode: int)

# Camera modes
enum CameraMode {
        THIRD_PERSON_CLASSIC,
        THIRD_PERSON_SHIFT_LOCK,
        FIRST_PERSON,
}

const WALK_SPEED: float = 4.5
const RUN_SPEED: float = 7.5
const JUMP_VELOCITY: float = 9.0
const ACCEL_GROUND: float = 12.0
const ACCEL_AIR: float = 4.0
const CARRY_SPEED_PENALTY: float = 0.7
const ROTATE_LERP: float = 12.0

var spring_arm: SpringArm3D
var model: Node3D
var carry_anchor: Marker3D
var head_anchor: Marker3D
var interact_prompt_label: Label3D
var camera: Camera3D
var collision_shape: CollisionShape3D
var body_mesh: MeshInstance3D
var egg_visual: MeshInstance3D
# Crosshair visibility is owned by HUD (which listens to camera_mode_changed)

var camera_mode: CameraMode = CameraMode.THIRD_PERSON_CLASSIC
var mouse_captured: bool = false
var right_mouse_held: bool = false
var camera_yaw: float = 0.0
var camera_pitch: float = -0.35
var camera_distance: float = 6.0
var camera_distance_target: float = 6.0
const MIN_CAMERA_DISTANCE: float = 0.4
const MAX_CAMERA_DISTANCE: float = 9.0
const FIRST_PERSON_THRESHOLD: float = 0.6

var is_carrying: bool = false
var current_speed_value: float = 16.0
var interaction_target: Node = null
var speed_penalty_active: bool = false
var speed_penalty_factor: float = 1.0
var speed_penalty_timer: float = 0.0
var camera_shake_amount: float = 0.0
var camera_shake_timer: float = 0.0


func _ready() -> void:
        _build_nodes()
        GameManager.set_player(self)
        GameManager.carrying_egg_changed.connect(_on_carrying_changed)
        Economy.speed_changed.connect(_on_speed_changed)
        _on_speed_changed(Economy.get_speed_level(), Economy.get_speed_xp(), Economy.get_speed_xp_needed())
        _apply_camera_mode()
        egg_visual.visible = false
        interact_prompt_label.visible = false


func _build_nodes() -> void:
        # Collision shape (capsule)
        collision_shape = CollisionShape3D.new()
        var capsule := CapsuleShape3D.new()
        capsule.radius = 0.45
        capsule.height = 1.7
        collision_shape.shape = capsule
        collision_shape.name = "CollisionShape3D"
        add_child(collision_shape)

        # Model (visual avatar)
        model = Node3D.new()
        model.name = "Model"
        add_child(model)

        # Body mesh — stylized humanoid built from primitives
        body_mesh = _build_avatar_body()
        body_mesh.name = "Body"
        model.add_child(body_mesh)

        # Head anchor (for 1P camera placement)
        head_anchor = Marker3D.new()
        head_anchor.name = "HeadAnchor"
        head_anchor.position = Vector3(0, 1.55, 0)
        add_child(head_anchor)

        # Carry anchor (egg floats above head when carrying)
        carry_anchor = Marker3D.new()
        carry_anchor.name = "CarryAnchor"
        carry_anchor.position = Vector3(0, 1.5, 0)
        add_child(carry_anchor)

        # Egg visual (initially hidden)
        egg_visual = MeshInstance3D.new()
        egg_visual.name = "EggVisual"
        var egg_mesh := SphereMesh.new()
        egg_mesh.radius = 0.18
        egg_mesh.height = 0.36
        var egg_mat := StandardMaterial3D.new()
        egg_mat.albedo_color = Color(1.0, 0.95, 0.8)
        egg_mat.roughness = 0.6
        egg_mesh.material = egg_mat
        egg_visual.mesh = egg_mesh
        egg_visual.visible = false
        carry_anchor.add_child(egg_visual)

        # SpringArm3D (handles camera collision)
        spring_arm = SpringArm3D.new()
        spring_arm.name = "SpringArm3D"
        spring_arm.spring_length = 6.0
        spring_arm.collision_mask = 1
        spring_arm.position = Vector3(0, 1.5, 0)
        add_child(spring_arm)

        # Camera
        camera = Camera3D.new()
        camera.name = "Camera3D"
        camera.fov = 70.0
        spring_arm.add_child(camera)

        # Interaction prompt label3D
        interact_prompt_label = Label3D.new()
        interact_prompt_label.name = "InteractPrompt"
        interact_prompt_label.position = Vector3(0, 2.2, 0)
        interact_prompt_label.pixel_size = 0.012
        interact_prompt_label.font_size = 32
        interact_prompt_label.outline_size = 6
        interact_prompt_label.outline_modulate = Color.BLACK
        interact_prompt_label.modulate = Color.WHITE
        interact_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        add_child(interact_prompt_label)


func _build_avatar_body() -> MeshInstance3D:
        var root := MeshInstance3D.new()
        var capsule_mesh := CapsuleMesh.new()
        capsule_mesh.radius = 0.35
        capsule_mesh.height = 1.4
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.3, 0.6, 0.9)
        mat.roughness = 0.7
        root.mesh = capsule_mesh
        root.material_override = mat
        root.position = Vector3(0, 0.7, 0)

        # Head as a child sphere
        var head := MeshInstance3D.new()
        var head_mesh := SphereMesh.new()
        head_mesh.radius = 0.28
        var head_mat := StandardMaterial3D.new()
        head_mat.albedo_color = Color(0.95, 0.78, 0.6)
        head_mat.roughness = 0.8
        head.mesh = head_mesh
        head.material_override = head_mat
        head.position = Vector3(0, 0.9, 0)
        root.add_child(head)

        # Simple eyes (two small dark spheres on the front of the head)
        for i in range(2):
                var eye := MeshInstance3D.new()
                var eye_mesh := SphereMesh.new()
                eye_mesh.radius = 0.04
                var eye_mat := StandardMaterial3D.new()
                eye_mat.albedo_color = Color(0.05, 0.05, 0.05)
                eye.mesh = eye_mesh
                eye.material_override = eye_mat
                eye.position = Vector3(-0.1 + i * 0.2, 0.0, 0.25)
                head.add_child(eye)

        return root


func _on_speed_changed(_level: int, _xp: int, _needed: int) -> void:
        current_speed_value = Economy.get_speed_value()


func _on_carrying_changed(carrying: bool) -> void:
        is_carrying = carrying
        egg_visual.visible = carrying
        if carrying:
                var t := create_tween()
                t.tween_property(egg_visual, "scale", Vector3(1.15, 1.15, 1.15), 0.15)
                t.tween_property(egg_visual, "scale", Vector3.ONE, 0.1)


func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventMouseButton:
                if event.button_index == MOUSE_BUTTON_RIGHT:
                        right_mouse_held = event.pressed
                        if event.pressed and camera_mode != CameraMode.FIRST_PERSON:
                                _enter_mode(CameraMode.THIRD_PERSON_CLASSIC)
                                mouse_captured = true
                                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                        else:
                                if camera_mode == CameraMode.THIRD_PERSON_CLASSIC:
                                        mouse_captured = false
                                        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
                        camera_distance_target = maxf(MIN_CAMERA_DISTANCE, camera_distance_target - 0.8)
                        _check_first_person_entry()
                if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
                        camera_distance_target = minf(MAX_CAMERA_DISTANCE, camera_distance_target + 0.8)
                        if camera_mode == CameraMode.FIRST_PERSON:
                                _enter_mode(CameraMode.THIRD_PERSON_CLASSIC)
                                camera_distance_target = 2.0
                                mouse_captured = false
                                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if event is InputEventMouseMotion:
                var sensitivity := 0.0035
                if camera_mode == CameraMode.FIRST_PERSON or camera_mode == CameraMode.THIRD_PERSON_SHIFT_LOCK or right_mouse_held:
                        camera_yaw -= event.relative.x * sensitivity
                        camera_pitch = clamp(camera_pitch - event.relative.y * sensitivity, -1.4, 0.9)
        if event is InputEventKey and event.physical_keycode == KEY_SHIFT:
                if event.pressed:
                        if camera_mode != CameraMode.FIRST_PERSON:
                                _enter_mode(CameraMode.THIRD_PERSON_SHIFT_LOCK)
                                mouse_captured = true
                                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                else:
                        if camera_mode == CameraMode.THIRD_PERSON_SHIFT_LOCK:
                                _enter_mode(CameraMode.THIRD_PERSON_CLASSIC)
                                mouse_captured = false
                                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if event.is_action_pressed("interact"):
                _try_interact()


func _check_first_person_entry() -> void:
        if camera_distance_target <= FIRST_PERSON_THRESHOLD and camera_mode != CameraMode.FIRST_PERSON:
                _enter_mode(CameraMode.FIRST_PERSON)
                mouse_captured = true
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _enter_mode(mode: CameraMode) -> void:
        camera_mode = mode
        _apply_camera_mode()
        camera_mode_changed.emit(mode)


func _apply_camera_mode() -> void:
        match camera_mode:
                CameraMode.THIRD_PERSON_CLASSIC:
                        model.visible = true
                CameraMode.THIRD_PERSON_SHIFT_LOCK:
                        model.visible = true
                CameraMode.FIRST_PERSON:
                        model.visible = false


func _physics_process(delta: float) -> void:
        # Update camera shake (decays over time)
        if camera_shake_timer > 0.0:
                camera_shake_timer -= delta
                if camera_shake_timer <= 0.0:
                        camera_shake_amount = 0.0
        # Update speed penalty timer
        if speed_penalty_active:
                speed_penalty_timer -= delta
                if speed_penalty_timer <= 0.0:
                        speed_penalty_active = false
                        speed_penalty_factor = 1.0

        # Gravity
        if not is_on_floor():
                velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 24.0) * delta

        # Movement input
        var input_vec := InputMapHelper.get_move_vector()
        var speed: float = WALK_SPEED
        if input_vec.length() > 0.1:
                speed = current_speed_value * 0.5
                if Input.is_key_pressed(KEY_CTRL):
                        speed = current_speed_value

        if is_carrying:
                speed *= CARRY_SPEED_PENALTY

        # Apply speed penalty (from NPC hits)
        if speed_penalty_active:
                speed *= speed_penalty_factor

        # Camera-relative movement direction
        var cam_basis := _get_camera_basis()
        var forward := -cam_basis.z
        forward.y = 0
        forward = forward.normalized()
        var right := cam_basis.x
        right.y = 0
        right = right.normalized()
        var wish_dir := (forward * -input_vec.y + right * input_vec.x)
        wish_dir = wish_dir.normalized() if wish_dir.length() > 0.01 else Vector3.ZERO

        var target_velocity := wish_dir * speed
        target_velocity.y = velocity.y

        var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
        velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
        velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

        if InputMapHelper.is_jump_pressed() and is_on_floor():
                velocity.y = JUMP_VELOCITY

        move_and_slide()

        # Rotate model
        if camera_mode != CameraMode.THIRD_PERSON_SHIFT_LOCK:
                if wish_dir.length() > 0.01:
                        var target_yaw := atan2(wish_dir.x, wish_dir.z)
                        model.rotation.y = lerp_angle(model.rotation.y, target_yaw, ROTATE_LERP * delta)
        else:
                model.rotation.y = lerp_angle(model.rotation.y, camera_yaw, ROTATE_LERP * delta)

        _update_camera(delta)
        _update_interaction()

        if is_carrying:
                var bob := sin(Time.get_ticks_msec() * 0.005) * 0.05
                carry_anchor.position.y = 1.5 + bob


func _get_camera_basis() -> Basis:
        var yaw_q := Quaternion.from_euler(Vector3(0, camera_yaw, 0))
        var pitch_q := Quaternion.from_euler(Vector3(camera_pitch, 0, 0))
        return Basis(yaw_q * pitch_q)


func _update_camera(delta: float) -> void:
        camera_distance = lerp(camera_distance, camera_distance_target, 12.0 * delta)
        # Compute camera shake offset (decays over time)
        var shake_offset := Vector2.ZERO
        if camera_shake_amount > 0.01:
                shake_offset.x = (randf() * 2.0 - 1.0) * camera_shake_amount
                shake_offset.y = (randf() * 2.0 - 1.0) * camera_shake_amount
        match camera_mode:
                CameraMode.FIRST_PERSON:
                        camera.global_position = head_anchor.global_position
                        camera.rotation = Vector3(camera_pitch + shake_offset.y * 0.05, camera_yaw + shake_offset.x * 0.05, 0)
                        spring_arm.visible = false
                _:
                        spring_arm.visible = true
                        spring_arm.rotation = Vector3(camera_pitch + shake_offset.y * 0.05, camera_yaw + shake_offset.x * 0.05, 0)
                        spring_arm.spring_length = camera_distance


# Apply a temporary speed penalty (called by NPC when attacking)
func apply_speed_penalty(factor: float, duration: float) -> void:
        speed_penalty_active = true
        speed_penalty_factor = factor
        speed_penalty_timer = duration
        # Camera shake on hit (small)
        trigger_camera_shake(0.15, 0.4)


func trigger_camera_shake(amount: float, duration: float) -> void:
        # Check if camera shake is enabled in settings
        var settings: Dictionary = SaveSystem.get_data().get("settings", {})
        if not bool(settings.get("camera_shake", true)):
                return
        camera_shake_amount = amount
        camera_shake_timer = duration


func _update_interaction() -> void:
        var space_state := get_world_3d().direct_space_state
        var cam_pos: Vector3 = camera.global_position
        var cam_forward := -camera.global_transform.basis.z.normalized()
        var end := cam_pos + cam_forward * 4.0
        var query := PhysicsRayQueryParameters3D.create(cam_pos, end)
        query.collision_mask = 0b111111111
        query.exclude = [self]
        var result := space_state.intersect_ray(query)
        if result and not result.collider.is_queued_for_deletion() and result.collider.has_method("interact"):
                interaction_target = result.collider
                var prompt: String = "[E] " + (result.collider.get_prompt_text() if result.collider.has_method("get_prompt_text") else "Interact")
                interact_prompt_label.text = prompt
                interact_prompt_label.visible = true
                interaction_prompt_changed.emit(prompt, true)
        else:
                interaction_target = null
                interact_prompt_label.visible = false
                interaction_prompt_changed.emit("", false)


func _try_interact() -> void:
        if interaction_target and interaction_target.has_method("interact"):
                interaction_target.interact(self)


func get_camera() -> Camera3D:
        return camera


func get_camera_mode() -> CameraMode:
        return camera_mode
