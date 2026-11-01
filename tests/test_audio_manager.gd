class_name TestAudioManager
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_audio_manager_fixed_pools(failures)
	test_priority_channel_stealing(failures)
	test_retrigger_rate_limiting(failures)
	test_audio_ducking_single_tween(failures)
	test_os_lifecycle_pause(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_audio_manager_fixed_pools(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/AudioManager.gd") as GDScript
	_assert(script != null, "AudioManager.gd must exist", failures)
	if script == null:
		return
		
	var mgr: Node = script.new()
	_assert(mgr.get("sfx_players").size() == 8, "AudioManager must have exactly 8 SFX players, got: %d" % mgr.get("sfx_players").size(), failures)
	_assert(mgr.get("music_players").size() == 2, "AudioManager must have exactly 2 Music players, got: %d" % mgr.get("music_players").size(), failures)
	_assert(mgr.get("ui_players").size() == 2, "AudioManager must have exactly 2 UI players, got: %d" % mgr.get("ui_players").size(), failures)
	
	# Verify all players are non-positional AudioStreamPlayer
	for p: Variant in mgr.get("sfx_players"):
		_assert(p is AudioStreamPlayer, "Player must be non-positional AudioStreamPlayer", failures)
	
	mgr.free()

static func test_priority_channel_stealing(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/AudioManager.gd") as GDScript
	if script == null:
		return
	var mgr: Node = script.new()
	
	# Fill all 8 SFX channels with Priority 1 (Ambient one-shot)
	for i in range(8):
		var ok: bool = mgr.play_sfx("amb_%d" % i, 1)
		_assert(ok, "Channel %d should accept priority 1 sound" % i, failures)
		
	# Attempt to play a new Priority 1 sound when full -> Must be dropped
	var ok_p1_drop: bool = mgr.play_sfx("amb_extra", 1)
	_assert(not ok_p1_drop, "Equal priority sound when full of same priority should be dropped", failures)
	
	# Attempt to play Priority 2 (Battle) sound -> Must steal lowest-priority/oldest active channel
	var ok_p2_steal: bool = mgr.play_sfx("battle_clash", 2)
	_assert(ok_p2_steal, "Priority 2 sound must steal an active priority 1 channel", failures)
	
	# Attempt to play Priority 3 (UI / Critical) -> Must steal
	var ok_p3_steal: bool = mgr.play_sfx("critical_horn", 3)
	_assert(ok_p3_steal, "Priority 3 sound must succeed and steal available channel", failures)
	
	mgr.free()

static func test_retrigger_rate_limiting(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/AudioManager.gd") as GDScript
	if script == null:
		return
	var mgr: Node = script.new()
	
	# First play should succeed
	var ok1: bool = mgr.play_sfx("ui_click", 3)
	_assert(ok1, "First sound play should succeed", failures)
	
	# Second immediate play within 60ms window must be dropped
	var ok2: bool = mgr.play_sfx("ui_click", 3)
	_assert(not ok2, "Immediate retrigger of same sound ID within 60ms must be suppressed", failures)
	
	mgr.free()

static func test_audio_ducking_single_tween(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/AudioManager.gd") as GDScript
	if script == null:
		return
	var mgr: Node = script.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(mgr)
	
	# Initiate ducking on Ambience and Music
	mgr.duck(["Ambience", "Music"], -6.0, 0.15, 0.5, 0.6)
	_assert(mgr.is_bus_ducked("Ambience"), "Ambience bus should be marked as ducked", failures)
	
	# Secondary ducking call should replace, not stack
	mgr.duck(["Ambience"], -10.0, 0.1, 0.2, 0.4)
	_assert(mgr.get_duck_count("Ambience") == 1, "Only one duck tween per bus should be active", failures)
	
	mgr.queue_free()

static func test_os_lifecycle_pause(failures: Array[String]) -> void:
	var script: GDScript = load("res://scripts/core/AudioManager.gd") as GDScript
	if script == null:
		return
	var mgr: Node = script.new()
	
	# Simulate OS pause
	mgr.on_application_paused()
	_assert(mgr.is_muted_on_pause, "Master bus and audio should be muted on application pause", failures)
	
	# Simulate OS resume
	mgr.on_application_resumed()
	_assert(not mgr.is_muted_on_pause, "Audio should be unmuted on application resume", failures)
	
	mgr.free()
