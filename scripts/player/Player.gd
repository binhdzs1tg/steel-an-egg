# Player.gd
# Top-down 2D player controller with WASD movement, run toggle, egg-carrying state,
# and proximity-based interact detection (handled via Area2D).
extends CharacterBody2D

signal speed_changed(value: float)
signal egg_carried_changed(carried: bool)
signal near_interactable(prompt: String, target: Node)
signal left_interactable()

# --- Movement ---
@export var base_speed: float = 140.0
@export var run_multiplier: float = 1.6
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var step_sfx_distance: float = 64.0

# --- State ---
var is_running: bool = false
var is_carrying_egg: bool = false
var facing: Vector2 = Vector2.DOWN
var _step_distance_accumulator: float = 0.0
var _current_interactable: Node = null
var _invuln_timer: float = 0.0
const INVULN_DURATION := 1.5

# --- Visuals ---
@onready var body_sprite: Polygon2D = $BodySprite
@onready var shadow: Polygon2D = $Shadow
@onready var egg_visual: Node2D = $EggVisual
@onready var interact_area: Area2D = $InteractArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
        add_to_group("player")
        interact_area.area_entered.connect(_on_interact_area_entered)
        interact_area.area_exited.connect(_on_interact_area_exited)
        interact_area.body_entered.connect(_on_interact_body_entered)
        interact_area.body_exited.connect(_on_interact_body_exited)
        GameManager.register_player(self)
        egg_visual.visible = false


func _physics_process(delta: float) -> void:
        if GameManager.is_paused():
                return
        
        # Input vector
        var input_vec := Vector2.ZERO
        if Input.is_action_pressed("move_up"):
                input_vec.y -= 1.0
        if Input.is_action_pressed("move_down"):
                input_vec.y += 1.0
        if Input.is_action_pressed("move_left"):
                input_vec.x -= 1.0
        if Input.is_action_pressed("move_right"):
                input_vec.x += 1.0
        
        input_vec = input_vec.normalized()
        
        # Run toggle (Shift)
        is_running = Input.is_action_pressed("run")
        
        # Compute target speed
        # speed_level upgrade: base 100, +15 per level → +15% speed per level
        var lvl: int = Economy.get_upgrade_level("speed_level")
        var speed_upgrade_mult: float = 1.0 + lvl * 0.15
        var target_speed: float = base_speed * speed_upgrade_mult
        if is_running:
                target_speed *= run_multiplier
        
        # Carry penalty
        if is_carrying_egg:
                var penalty: float = Economy.get_upgrade_value("carry_capacity")
                # base 0.85, +0.03 per level → reduces penalty
                # penalty is the multiplier applied to target_speed when carrying
                target_speed *= penalty
        
        # Acceleration / Friction
        if input_vec != Vector2.ZERO:
                velocity = velocity.move_toward(input_vec * target_speed, acceleration * delta)
                if input_vec.y < 0:
                        facing = Vector2.UP
                elif input_vec.y > 0:
                        facing = Vector2.DOWN
                elif input_vec.x < 0:
                        facing = Vector2.LEFT
                elif input_vec.x > 0:
                        facing = Vector2.RIGHT
                # Footstep sfx
                _step_distance_accumulator += velocity.length() * delta
                if _step_distance_accumulator >= step_sfx_distance:
                        _step_distance_accumulator = 0.0
                        AudioManager.sfx_step()
                # Animation
                if anim_player != null:
                        if not anim_player.is_playing() or anim_player.current_animation != "walk":
                                anim_player.play("walk")
        else:
                velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
                if anim_player != null and anim_player.current_animation == "walk":
                        anim_player.play("idle")
        
        # Update visual facing
        _update_visuals()
        
        move_and_slide()
        
        # Interact key (E)
        if Input.is_action_just_pressed("interact") and _current_interactable != null:
                _attempt_interact()
        
        # Invulnerability timer (after being caught)
        if _invuln_timer > 0.0:
                _invuln_timer -= delta
                # Flash
                body_sprite.modulate.a = 0.5 + sin(_invuln_timer * 30.0) * 0.3


func _update_visuals() -> void:
        # Flip sprite based on facing.x
        if facing.x < 0:
                body_sprite.scale.x = -1.0
        elif facing.x > 0:
                body_sprite.scale.x = 1.0


# ---------- Interaction ----------
func _on_interact_area_entered(area: Area2D) -> void:
        var owner_node: Node = area.get_parent()
        if owner_node.has_method("get_interact_prompt"):
                _current_interactable = owner_node
                near_interactable.emit(owner_node.get_interact_prompt(self), owner_node)


func _on_interact_area_exited(area: Area2D) -> void:
        if _current_interactable == area.get_parent():
                _current_interactable = null
                left_interactable.emit()


func _on_interact_body_entered(body: Node) -> void:
        if body.has_method("get_interact_prompt"):
                _current_interactable = body
                near_interactable.emit(body.get_interact_prompt(self), body)


func _on_interact_body_exited(body: Node) -> void:
        if _current_interactable == body:
                _current_interactable = null
                left_interactable.emit()


func _attempt_interact() -> void:
        if _current_interactable == null:
                return
        if not _current_interactable.has_method("interact"):
                return
        _current_interactable.interact(self)
        AudioManager.sfx_ui_click()


# ---------- Egg carrying ----------
func carry_egg(egg_id: String) -> void:
        GameManager.set_carried_egg(egg_id)
        is_carrying_egg = true
        egg_visual.visible = true
        # Update egg visual color/size from data
        var egg_data: Dictionary = DataRegistry.get_egg(egg_id)
        if not egg_data.is_empty():
                var color: Color = DataRegistry.color_from_hex(egg_data.get("color", "#fff8dc"))
                var size: float = float(egg_data.get("size", 18)) * 0.5
                # Update EggVisual children
                var sprite: Polygon2D = egg_visual.get_node_or_null("EggSprite")
                if sprite != null:
                        sprite.polygon = _make_egg_polygon(size)
                        sprite.color = color
        egg_carried_changed.emit(true)
        AudioManager.sfx_steal()
        _invuln_timer = INVULN_DURATION


func drop_egg() -> void:
        GameManager.set_carried_egg("")
        is_carrying_egg = false
        egg_visual.visible = false
        egg_carried_changed.emit(false)


func deposit_egg() -> void:
        # Called when player deposits egg at base/coop
        drop_egg()
        AudioManager.sfx_deposit()


# ---------- Damage ----------
func take_hit() -> void:
        if _invuln_timer > 0.0:
                return
        if not is_carrying_egg:
                return
        # Drop the egg and lose it
        AudioManager.sfx_caught()
        drop_egg()
        NotificationSystem.error("Bạn bị bắt! Trứng bị rơi mất!")
        # Brief knockback/invuln
        _invuln_timer = INVULN_DURATION
        velocity = -velocity.normalized() * 200.0


# ---------- Save/Load ----------
func serialize() -> Dictionary:
        return {
                "position": [position.x, position.y],
                "facing": [facing.x, facing.y],
                "is_carrying_egg": is_carrying_egg,
                "carried_egg_id": GameManager.get_carried_egg_id(),
        }


func deserialize(data: Dictionary) -> void:
        var pos_arr: Array = data.get("position", [0, 0])
        position = Vector2(pos_arr[0], pos_arr[1])
        var fac_arr: Array = data.get("facing", [0, 1])
        facing = Vector2(fac_arr[0], fac_arr[1])
        if bool(data.get("is_carrying_egg", false)):
                var eid: String = data.get("carried_egg_id", "")
                if eid != "":
                        carry_egg(eid)


# ---------- Helpers ----------
func get_current_speed() -> float:
        return velocity.length()


func _make_egg_polygon(radius: float) -> PackedVector2Array:
        var pts := PackedVector2Array()
        var n := 16
        for i in range(n):
                var angle: float = TAU * float(i) / float(n)
                # Make it slightly egg-shaped (taller)
                var x: float = cos(angle) * radius * 0.85
                var y: float = sin(angle) * radius * 1.15
                pts.append(Vector2(x, y))
        return pts


# Public: callable by Treadmill to apply speed boost temporary
func apply_speed_boost(multiplier: float, duration: float) -> void:
        # We just emit a notification; the multiplier is applied via upgrade purchase.
        NotificationSystem.info("Tập luyện tốc độ! +%.0f%% tốc độ" % ((multiplier - 1.0) * 100.0))
