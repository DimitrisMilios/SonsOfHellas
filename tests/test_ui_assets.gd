class_name TestUIAssets
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_asset_existence(failures)
	test_asset_textures_loadable(failures)
	test_asset_dimensions_mobile_budget(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func get_expected_assets() -> Array[String]:
	return [
		"res://assets/ui/coin_drachma.png",
		"res://assets/ui/food_amphora.png",
		"res://assets/ui/sparta_shield.png",
		"res://assets/ui/athens_shield.png",
		"res://assets/ui/thebes_shield.png",
		"res://assets/ui/corinth_shield.png",
		"res://assets/map/settlement_fort.png",
		"res://assets/map/settlement_acropolis.png",
		"res://assets/map/hoplite_avatar.png",
		"res://assets/map/greece_terrain.png"
	]

static func test_asset_existence(failures: Array[String]) -> void:
	for path: String in get_expected_assets():
		_assert(ResourceLoader.exists(path) or FileAccess.file_exists(path),
			"Required asset must exist: %s" % path, failures)

static func test_asset_textures_loadable(failures: Array[String]) -> void:
	for path: String in get_expected_assets():
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			continue
		var tex: Resource = load(path)
		_assert(tex != null and (tex is Texture2D or tex is Image),
			"Asset must load as valid Texture2D/Image: %s" % path, failures)

static func test_asset_dimensions_mobile_budget(failures: Array[String]) -> void:
	for path: String in get_expected_assets():
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		var sz: Vector2 = tex.get_size()
		_assert(sz.x >= 32.0 and sz.y >= 32.0,
			"Asset %s too small: %s (minimum 32x32)" % [path, str(sz)], failures)
		_assert(sz.x <= 2048.0 and sz.y <= 2048.0,
			"Asset %s exceeds safe 2048x2048 mobile limit: %s" % [path, str(sz)], failures)
