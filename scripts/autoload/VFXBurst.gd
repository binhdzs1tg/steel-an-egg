extends Node3D
class_name VFXBurst
## A one-shot particle burst effect used for celebrations (hatch success, achievement, etc.).
## Built from GPUParticles3D; auto-frees after the burst duration.

@onready var particles: GPUParticles3D = null

@export var burst_color: Color = Color(1.0, 0.85, 0.3)
@export var burst_count: int = 60
@export var burst_lifetime: float = 1.5
@export var burst_speed: float = 4.0
@export var burst_size: float = 0.15
@export var gravity_y: float = -3.0


func _ready() -> void:
	_build()


func _build() -> void:
	particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = burst_count
	particles.lifetime = burst_lifetime
	particles.explosiveness = 1.0
	particles.randomness = 1.0
	particles.fixed_fps = 60
	particles.interp_to_end = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = burst_speed * 0.5
	mat.initial_velocity_max = burst_speed
	mat.gravity = Vector3(0, gravity_y, 0)
	mat.scale_min = burst_size * 0.5
	mat.scale_max = burst_size * 1.5
	mat.color = burst_color
	mat.hue_variation_min = -0.1
	mat.hue_variation_max = 0.1
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 1.5
	mat.turbulence_influence_min = 0.2
	mat.turbulence_influence_max = 1.0
	particles.process_material = mat

	# Mesh for particles (small spheres)
	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = burst_size
	draw_mesh.height = burst_size * 2.0
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = burst_color
	draw_mat.emission_enabled = true
	draw_mat.emission = burst_color
	draw_mat.emission_energy_multiplier = 1.5
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

	add_child(particles)

	# Auto-queue-free after lifetime
	await get_tree().create_timer(burst_lifetime + 0.5).timeout
	queue_free()


static func spawn_at(parent: Node, position: Vector3, color: Color, count: int = 60, size: float = 0.15, speed: float = 4.0, duration: float = 1.5) -> Node3D:
	var vfx := VFXBurst.new()
	vfx.set_script(preload("res://scripts/autoload/VFXBurst.gd"))
	vfx.position = position
	vfx.burst_color = color
	vfx.burst_count = count
	vfx.burst_size = size
	vfx.burst_speed = speed
	vfx.burst_lifetime = duration
	parent.add_child(vfx)
	return vfx
