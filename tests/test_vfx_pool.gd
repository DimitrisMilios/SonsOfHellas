class_name TestVFXPool
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_vfx_pool_initialization(failures)
	test_vfx_pool_exhaustion_drop(failures)
	test_vfx_zoom_culling(failures)
	test_vfx_frustum_culling(failures)
	test_vfx_particle_budgets(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_vfx_pool_initialization(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/world/VFXPool.gd") as GDScript
	_assert(script != null, "VFXPool.gd must exist", failures)
	if script == null:
		return
		
	var pool: Node = script.new()
	_assert(pool.has_method("play_effect"), "VFXPool must have play_effect method", failures)
	_assert(pool.get("POOL_SIZE") == 6 or pool.get("pool_size") == 6 or pool.get_children().size() == 6, 
		"VFXPool must maintain a pool of 6 emitters", failures)
	
	# Verify all emitters are CPUParticles2D, none are GPUParticles2D
	for child: Node in pool.get_children():
		_assert(child is CPUParticles2D, "VFXPool emitter must be CPUParticles2D", failures)
		_assert(not (child is GPUParticles2D), "GPUParticles2D is strictly banned on campaign map", failures)
	
	pool.free()

static func test_vfx_pool_exhaustion_drop(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/world/VFXPool.gd") as GDScript
	if script == null:
		return
	var pool: Node = script.new()
	
	# Exhaust all 6 emitters
	var spawned: int = 0
	for i in range(6):
		var ok: bool = pool.play_effect("march_dust", Vector2(100 + i * 10, 100), 1.0, Rect2(-1000, -1000, 5000, 5000))
		if ok:
			spawned += 1
			
	_assert(spawned == 6, "First 6 effects should be accepted, got: %d" % spawned, failures)
	
	# 7th effect must be dropped
	var ok_7th: bool = pool.play_effect("march_dust", Vector2(500, 500), 1.0, Rect2(-1000, -1000, 5000, 5000))
	_assert(not ok_7th, "7th effect must be dropped when pool is exhausted", failures)
	_assert(pool.get_children().size() == 6, "Pool size must strictly remain 6 (no runtime allocation)", failures)
	
	pool.free()

static func test_vfx_zoom_culling(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/world/VFXPool.gd") as GDScript
	if script == null:
		return
	var pool: Node = script.new()
	
	# Below zoom threshold (< 0.6)
	var ok_low_zoom: bool = pool.play_effect("march_dust", Vector2(100, 100), 0.5, Rect2(-1000, -1000, 5000, 5000))
	_assert(not ok_low_zoom, "Effect should be culled/dropped when zoom < 0.6", failures)
	
	# At or above zoom threshold (>= 0.6)
	var ok_normal_zoom: bool = pool.play_effect("march_dust", Vector2(100, 100), 1.0, Rect2(-1000, -1000, 5000, 5000))
	_assert(ok_normal_zoom, "Effect should play when zoom >= 0.6", failures)
	
	pool.free()

static func test_vfx_frustum_culling(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/world/VFXPool.gd") as GDScript
	if script == null:
		return
	var pool: Node = script.new()
	
	var visible_viewport: Rect2 = Rect2(0, 0, 1280, 720)
	
	# Outside viewport bounds
	var ok_offscreen: bool = pool.play_effect("siege_smoke", Vector2(2500, 3000), 1.0, visible_viewport)
	_assert(not ok_offscreen, "Off-screen effect must be culled/dropped before starting", failures)
	
	# Inside viewport bounds
	var ok_onscreen: bool = pool.play_effect("siege_smoke", Vector2(500, 300), 1.0, visible_viewport)
	_assert(ok_onscreen, "On-screen effect must be accepted", failures)
	
	pool.free()

static func test_vfx_particle_budgets(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/world/VFXPool.gd") as GDScript
	if script == null:
		return
	var pool: Node = script.new()
	
	_assert(pool.get_effect_particle_count("march_dust") <= 12, "March dust budget must be <= 12 particles", failures)
	_assert(pool.get_effect_particle_count("siege_smoke") <= 16, "Siege smoke budget must be <= 16 particles", failures)
	_assert(pool.get_effect_particle_count("battle_sparks") <= 12, "Battle sparks budget must be <= 12 particles", failures)
	
	pool.free()
