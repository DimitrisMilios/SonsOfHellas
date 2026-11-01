extends Node

## Centralized Mobile Audio Manager with fixed channel pooling,
## priority stealing, ducking, and OS lifecycle silencing.

const SFX_POOL_SIZE: int = 8
const MUSIC_POOL_SIZE: int = 2
const UI_POOL_SIZE: int = 2
const RETRIGGER_COOLDOWN_MS: int = 60
const MAX_CONCURRENT_SAME_SOUND: int = 2

var sfx_players: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []

# Channel metadata: player -> { "id": String, "priority": int, "started_at": int, "active": bool }
var _sfx_metadata: Dictionary = {}
var _last_play_time: Dictionary = {} # sound_id -> msec timestamp
var _duck_tweens: Dictionary = {}    # bus_name -> Tween
var _ducked_buses: Dictionary = {}   # bus_name -> bool

var is_muted_on_pause: bool = false

func _init() -> void:
	_ensure_buses()
	_create_pools()

func _ready() -> void:
	set_process(false)

func _ensure_buses() -> void:
	var required_buses: Array[String] = ["Music", "Ambience", "SFX", "UI"]
	for b_name: String in required_buses:
		if AudioServer.get_bus_index(b_name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, b_name)
			AudioServer.set_bus_send(idx, "Master")

func _create_pools() -> void:
	for i in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
		_sfx_metadata[p] = {"id": "", "priority": 0, "started_at": 0, "active": false}
		p.finished.connect(func() -> void:
			if _sfx_metadata.has(p):
				_sfx_metadata[p]["active"] = false
		)

	for i in range(MUSIC_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "MusicPlayer_%d" % i
		p.bus = "Music"
		add_child(p)
		music_players.append(p)

	for i in range(UI_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "UIPlayer_%d" % i
		p.bus = "UI"
		add_child(p)
		ui_players.append(p)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		on_application_paused()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		on_application_resumed()

## Plays an SFX using priority channel stealing and rate limits.
func play_sfx(sound_id: String, priority: int = 1, stream: AudioStream = null) -> bool:
	var now: int = Time.get_ticks_msec()

	# 1. Rate limiting: enforce 60ms cooldown for identical sound
	if _last_play_time.has(sound_id):
		if now - _last_play_time[sound_id] < RETRIGGER_COOLDOWN_MS:
			return false

	# 2. Concurrency limit: max 2 instances of same sound ID
	var active_instances: int = 0
	for p: AudioStreamPlayer in sfx_players:
		if _sfx_metadata[p]["active"] and _sfx_metadata[p]["id"] == sound_id:
			active_instances += 1
	if active_instances >= MAX_CONCURRENT_SAME_SOUND:
		return false

	# 3. Find candidate player (free or stolen)
	var target_player: AudioStreamPlayer = _acquire_sfx_player(priority)
	if target_player == null:
		return false # Dropped due to lack of channel with lower priority

	_last_play_time[sound_id] = now
	_sfx_metadata[target_player] = {
		"id": sound_id,
		"priority": priority,
		"started_at": now,
		"active": true
	}

	if stream != null:
		target_player.stream = stream
	target_player.play()
	return true

func _acquire_sfx_player(priority: int) -> AudioStreamPlayer:
	# Check for completely idle player first
	for p: AudioStreamPlayer in sfx_players:
		if not _sfx_metadata[p]["active"] and not p.playing:
			return p

	# Pool is full: find candidates with priority strictly lower than incoming priority
	var candidate: AudioStreamPlayer = null
	var lowest_priority: int = 0x7FFFFFFF
	var oldest_time: int = 0x7FFFFFFF

	for p: AudioStreamPlayer in sfx_players:
		var meta: Dictionary = _sfx_metadata[p]
		var p_priority: int = meta["priority"]
		var p_time: int = meta["started_at"]

		if p_priority < lowest_priority:
			lowest_priority = p_priority
			oldest_time = p_time
			candidate = p
		elif p_priority == lowest_priority and p_time < oldest_time:
			oldest_time = p_time
			candidate = p

	if candidate != null and lowest_priority < priority:
		candidate.stop()
		return candidate

	return null

## Smoothly ducks specified audio buses with a single tween.
func duck(bus_names: Array, db_reduction: float = -6.0, attack: float = 0.15, hold: float = 0.5, release: float = 0.6) -> void:
	_ensure_buses()
	for bus_name: Variant in bus_names:
		var b_str: String = str(bus_name)
		var bus_idx: int = AudioServer.get_bus_index(b_str)
		if bus_idx < 0:
			continue

		# Kill previous ducking tween to prevent stacking
		if _duck_tweens.has(b_str) and _duck_tweens[b_str] != null:
			if _duck_tweens[b_str] is Tween and is_instance_valid(_duck_tweens[b_str]):
				_duck_tweens[b_str].kill()
			_duck_tweens.erase(b_str)

		_ducked_buses[b_str] = true
		var base_vol: float = AudioServer.get_bus_volume_db(bus_idx)
		var ducked_vol: float = base_vol + db_reduction

		var tween: Tween = null
		if is_inside_tree():
			tween = create_tween()
		else:
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree != null and tree.root != null:
				tween = tree.create_tween()

		if tween != null:
			_duck_tweens[b_str] = tween

			tween.tween_method(func(val: float) -> void:
				AudioServer.set_bus_volume_db(bus_idx, val)
			, base_vol, ducked_vol, attack)

			tween.tween_interval(hold)

			tween.tween_method(func(val: float) -> void:
				AudioServer.set_bus_volume_db(bus_idx, val)
			, ducked_vol, base_vol, release)

			tween.tween_callback(func() -> void:
				_ducked_buses[b_str] = false
			)
		else:
			_duck_tweens[b_str] = RefCounted.new()

func is_bus_ducked(bus_name: String) -> bool:
	return _ducked_buses.get(bus_name, false)

func get_duck_count(bus_name: String) -> int:
	if _duck_tweens.has(bus_name) and _duck_tweens[bus_name] != null:
		return 1
	return 0

## Called on OS pause: silences all buses and pauses stream players.
func on_application_paused() -> void:
	is_muted_on_pause = true
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, true)

	for p: AudioStreamPlayer in sfx_players:
		if p.playing:
			p.stream_paused = true
	for p: AudioStreamPlayer in music_players:
		if p.playing:
			p.stream_paused = true
	for p: AudioStreamPlayer in ui_players:
		if p.playing:
			p.stream_paused = true

## Called on OS resume: unpauses and fades in Master bus volume.
func on_application_resumed() -> void:
	is_muted_on_pause = false
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)

	for p: AudioStreamPlayer in sfx_players:
		if p.stream_paused:
			p.stream_paused = false
	for p: AudioStreamPlayer in music_players:
		if p.stream_paused:
			p.stream_paused = false
	for p: AudioStreamPlayer in ui_players:
		if p.stream_paused:
			p.stream_paused = false
