class_name VFXPool
extends Node2D

const POOL_SIZE: int = 6
const MIN_ZOOM_THRESHOLD: float = 0.6

const EFFECT_BUDGETS: Dictionary = {
	"march_dust": 12,
	"siege_smoke": 16,
	"battle_sparks": 12
}

var emitters: Array[CPUParticles2D] = []

func _init() -> void:
	name = "VFXPool"
	_init_pool()

func _ready() -> void:
	set_process(false)

func _init_pool() -> void:
	for i in range(POOL_SIZE):
		var emitter: CPUParticles2D = CPUParticles2D.new()
		emitter.name = "Emitter_%d" % i
		emitter.emitting = false
		emitter.one_shot = true
		emitter.amount = 12
		emitter.lifetime = 0.5
		emitter.explosiveness = 0.8
		add_child(emitter)
		emitters.append(emitter)

## Returns the maximum particle budget for a given effect type.
func get_effect_particle_count(effect_type: String) -> int:
	return EFFECT_BUDGETS.get(effect_type, 12)

## Plays a cosmetic effect from the pre-allocated pool if resources and zoom allow.
func play_effect(
	effect_type: String,
	world_pos: Vector2,
	current_zoom: float = 1.0,
	visible_rect: Rect2 = Rect2()
) -> bool:
	# 1. Zoom culling: skip below threshold
	if current_zoom < MIN_ZOOM_THRESHOLD:
		return false

	# 2. Frustum culling: skip if outside visible camera bounds
	if visible_rect.size != Vector2.ZERO and not visible_rect.has_point(world_pos):
		return false

	# 3. Find an inactive emitter from the pool
	var emitter: CPUParticles2D = _get_available_emitter()
	if emitter == null:
		# Pool exhausted: drop effect cleanly (cosmetic only)
		return false

	_configure_emitter(emitter, effect_type)
	emitter.position = world_pos
	emitter.restart()
	emitter.emitting = true
	return true

func _get_available_emitter() -> CPUParticles2D:
	for e: CPUParticles2D in emitters:
		if not e.emitting:
			return e
	return null

func _configure_emitter(emitter: CPUParticles2D, effect_type: String) -> void:
	var budget: int = get_effect_particle_count(effect_type)
	emitter.amount = budget

	match effect_type:
		"march_dust":
			emitter.one_shot = true
			emitter.lifetime = 0.45
			emitter.explosiveness = 0.6
			emitter.spread = 45.0
			emitter.initial_velocity_min = 15.0
			emitter.initial_velocity_max = 30.0
			emitter.color = Color(0.76, 0.70, 0.55, 0.6)
		"siege_smoke":
			emitter.one_shot = false
			emitter.lifetime = 1.2
			emitter.explosiveness = 0.1
			emitter.spread = 20.0
			emitter.gravity = Vector2(0, -25.0)
			emitter.initial_velocity_min = 10.0
			emitter.initial_velocity_max = 20.0
			emitter.color = Color(0.3, 0.3, 0.3, 0.7)
		"battle_sparks":
			emitter.one_shot = true
			emitter.lifetime = 0.35
			emitter.explosiveness = 0.95
			emitter.spread = 180.0
			emitter.initial_velocity_min = 40.0
			emitter.initial_velocity_max = 80.0
			emitter.color = Color(1.0, 0.85, 0.2, 0.9)
		_:
			emitter.one_shot = true
			emitter.lifetime = 0.5
			emitter.explosiveness = 0.8
			emitter.color = Color.WHITE
