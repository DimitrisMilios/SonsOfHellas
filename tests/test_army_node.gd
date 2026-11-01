class_name TestArmyNode
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_touch_target_dimensions(failures)
	test_army_data_binding(failures)
	test_stance_banner_update(failures)
	test_movement_range_circle_scaling(failures)
	test_zoc_radius(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_touch_target_dimensions(failures: Array[String]) -> void:
	var scene: PackedScene = load("res://scenes/ArmyNode.tscn")
	_assert(scene != null, "ArmyNode.tscn must be loadable", failures)
	if scene == null:
		return
		
	var node: ArmyNode = scene.instantiate() as ArmyNode
	node._ready()
	
	_assert(node.effective_box_size.x >= 44.0 and node.effective_box_size.y >= 44.0,
		"ArmyNode touch target must be >= 44x44px, got: %v" % node.effective_box_size, failures)
		
	node.free()

static func test_army_data_binding(failures: Array[String]) -> void:
	var node: ArmyNode = ArmyNode.new()
	node._ready()
	
	var army: ArmyData = ArmyData.new()
	army.army_id = "spartan_1st_legion"
	army.army_name = "Spartan Royal Guard"
	army.owner_faction_id = "sparta"
	army.current_action_points = 80.0
	army.max_action_points = 100.0
	
	var u1: UnitData = UnitData.new()
	u1.unit_id = "u1"
	u1.display_name = "Hoplite"
	army.add_unit(u1)
	
	var u2: UnitData = UnitData.new()
	u2.unit_id = "u2"
	u2.display_name = "Skirmisher"
	army.add_unit(u2)
	
	node.set_army_data(army)
	
	_assert(node.army_id == "spartan_1st_legion", "Army ID must match", failures)
	_assert(node.get_unit_count() == 2, "Unit count must be 2, got: " + str(node.get_unit_count()), failures)
	_assert(node.get_faction_color().r > node.get_faction_color().b, "Spartan faction color should be red-dominant", failures)
	_assert(node.label != null and node.label.text.contains("Spartan Royal Guard"), "Label must contain army name", failures)
	
	node.free()

static func test_stance_banner_update(failures: Array[String]) -> void:
	var node: ArmyNode = ArmyNode.new()
	node._ready()
	
	var army: ArmyData = ArmyData.new()
	army.army_id = "test_army"
	
	army.stance = ArmyData.Stance.FORCED_MARCH
	node.set_army_data(army)
	_assert(node.get_stance_name() == "Forced March", "Stance name should be 'Forced March', got: " + node.get_stance_name(), failures)
	
	army.stance = ArmyData.Stance.RAIDING
	node.set_army_data(army)
	_assert(node.get_stance_name() == "Raiding", "Stance name should be 'Raiding', got: " + node.get_stance_name(), failures)
	
	army.stance = ArmyData.Stance.ENCAMPMENT
	node.set_army_data(army)
	_assert(node.get_stance_name() == "Encampment", "Stance name should be 'Encampment', got: " + node.get_stance_name(), failures)
	
	army.stance = ArmyData.Stance.AMBUSH
	node.set_army_data(army)
	_assert(node.get_stance_name() == "Ambush", "Stance name should be 'Ambush', got: " + node.get_stance_name(), failures)
	
	army.stance = ArmyData.Stance.SIEGE
	node.set_army_data(army)
	_assert(node.get_stance_name() == "Siege", "Stance name should be 'Siege', got: " + node.get_stance_name(), failures)
	
	node.free()

static func test_movement_range_circle_scaling(failures: Array[String]) -> void:
	var node: ArmyNode = ArmyNode.new()
	node._ready()
	
	var army: ArmyData = ArmyData.new()
	army.max_action_points = 100.0
	
	# Full AP (100) -> Positive radius
	army.current_action_points = 100.0
	node.set_army_data(army)
	var full_radius: float = node.get_movement_circle_radius()
	_assert(full_radius > 0.0, "Full AP must produce positive movement radius", failures)
	
	# Half AP (50) -> Exactly half radius
	army.current_action_points = 50.0
	node.set_army_data(army)
	var half_radius: float = node.get_movement_circle_radius()
	_assert(absf(half_radius - (full_radius * 0.5)) < 0.1, 
		"50 AP should yield half radius (%f), got: %f" % [full_radius * 0.5, half_radius], failures)
	
	# Depleted AP (0) -> Zero radius
	army.current_action_points = 0.0
	node.set_army_data(army)
	var zero_radius: float = node.get_movement_circle_radius()
	_assert(zero_radius == 0.0, "Depleted AP (0) must reduce movement circle radius to exactly 0.0, got: " + str(zero_radius), failures)
	
	node.free()

static func test_zoc_radius(failures: Array[String]) -> void:
	var node: ArmyNode = ArmyNode.new()
	node._ready()
	
	var army: ArmyData = ArmyData.new()
	node.set_army_data(army)
	
	var zoc_rad: float = node.get_zoc_radius()
	_assert(zoc_rad >= 44.0, "Zone of Control radius must be >= 44.0px, got: " + str(zoc_rad), failures)
	
	node.free()
