class_name TestProvinceNode
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_touch_target_dimensions(failures)
	test_province_data_binding(failures)
	test_unrest_indicator_visibility(failures)
	test_settlement_tier_levels(failures)
	test_faction_border_color(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_touch_target_dimensions(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/ProvinceNode.tscn")
	_assert(scene != null, "ProvinceNode.tscn must be loadable", failures)
	if scene == null:
		return
		
	var node: ProvinceNode = scene.instantiate() as ProvinceNode
	node._ready()
	
	var diameter: float = node.effective_touch_radius * 2.0
	_assert(diameter >= 44.0, 
		"ProvinceNode touch target diameter must be >= 44px, got: %f" % diameter, failures)
		
	node.free()

static func test_province_data_binding(failures: Array[String]) -> void:
	var node: ProvinceNode = ProvinceNode.new()
	node._ready()
	
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "prov_corinth"
	prov.province_name = "Corinth"
	prov.owner_faction_id = "athens"
	prov.settlement_level = 3
	prov.public_order = 45.0
	prov.map_position = Vector2(250, 180)
	
	node.set_province_data(prov)
	
	_assert(node.province_id == "prov_corinth", "Province ID must match", failures)
	_assert(node.position == Vector2(250, 180), "Node position must match map position", failures)
	_assert(node.get_settlement_tier() == 3, "Settlement tier must be 3", failures)
	_assert(node.get_settlement_tier_name() == "City", "Settlement level 3 name must be 'City', got: " + node.get_settlement_tier_name(), failures)
	_assert(node.label != null and node.label.text.contains("Corinth"), "Label must contain province name", failures)
	
	node.free()

static func test_unrest_indicator_visibility(failures: Array[String]) -> void:
	var node: ProvinceNode = ProvinceNode.new()
	node._ready()
	
	var prov: ProvinceData = ProvinceData.new()
	prov.province_id = "prov_sparta"
	prov.public_order = 50.0
	prov.consecutive_unrest_turns = 0
	prov.unrest_pressure = 0
	
	node.set_province_data(prov)
	_assert(not node.has_unrest_alert(), "Unrest alert must be false when PO > 0 and unrest turns == 0", failures)
	
	# Negative public order triggers unrest alert
	prov.public_order = -10.0
	node.set_province_data(prov)
	_assert(node.has_unrest_alert(), "Unrest alert must be true when public order < 0", failures)
	
	# Consecutive unrest turns triggers unrest alert even if PO just recovered
	prov.public_order = 5.0
	prov.consecutive_unrest_turns = 1
	node.set_province_data(prov)
	_assert(node.has_unrest_alert(), "Unrest alert must be true when consecutive_unrest_turns > 0", failures)
	
	node.free()

static func test_settlement_tier_levels(failures: Array[String]) -> void:
	var node: ProvinceNode = ProvinceNode.new()
	node._ready()
	
	var prov: ProvinceData = ProvinceData.new()
	var expected_names: Dictionary = {
		1: "Fort",
		2: "Town",
		3: "City",
		4: "Metropolis",
		5: "Citadel"
	}
	
	for lvl: int in range(1, 6):
		prov.settlement_level = lvl
		node.set_province_data(prov)
		var actual: String = node.get_settlement_tier_name()
		_assert(actual == expected_names[lvl], 
			"Settlement level %d should be '%s', got '%s'" % [lvl, expected_names[lvl], actual], failures)
	
	node.free()

static func test_faction_border_color(failures: Array[String]) -> void:
	var node: ProvinceNode = ProvinceNode.new()
	node._ready()
	
	var prov_sparta: ProvinceData = ProvinceData.new()
	prov_sparta.owner_faction_id = "sparta"
	node.set_province_data(prov_sparta)
	var sparta_col: Color = node.get_faction_color()
	_assert(sparta_col.r > sparta_col.b, "Sparta faction color should be red-dominant", failures)
	
	var prov_athens: ProvinceData = ProvinceData.new()
	prov_athens.owner_faction_id = "athens"
	node.set_province_data(prov_athens)
	var athens_col: Color = node.get_faction_color()
	_assert(athens_col.b > athens_col.r, "Athens faction color should be blue-dominant", failures)
	
	node.free()
