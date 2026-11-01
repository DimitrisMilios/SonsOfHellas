class_name TestMaterialLint
extends RefCounted

static func run_all_tests() -> Array[String]:
	var failures: Array[String] = []
	test_passive_nodes_material_lint(failures)
	test_passive_nodes_zero_process(failures)
	test_passive_nodes_no_area2d(failures)
	return failures

static func _assert(condition: bool, msg: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(msg)

static func test_passive_nodes_material_lint(failures: Array[String]) -> void:
	var scenes: Array[String] = [
		"res://scenes/ProvinceNode.tscn",
		"res://scenes/ArmyNode.tscn"
	]
	
	for path: String in scenes:
		var packed: PackedScene = load(path) as PackedScene
		_assert(packed != null, "Scene %s must exist" % path, failures)
		if packed == null:
			continue
			
		var inst: Node = packed.instantiate()
		_check_node_materials_recursive(inst, path, failures)
		inst.free()

static func _check_node_materials_recursive(node: Node, scene_path: String, failures: Array[String]) -> void:
	if node is CanvasItem:
		var ci: CanvasItem = node as CanvasItem
		_assert(ci.material == null, 
			"Node '%s' in '%s' must not have a custom material override (got: %s)" % [node.name, scene_path, str(ci.material)], failures)
	
	for child: Node in node.get_children():
		_check_node_materials_recursive(child, scene_path, failures)

static func test_passive_nodes_zero_process(failures: Array[String]) -> void:
	var p_node: ProvinceNode = ProvinceNode.new()
	_assert(not p_node.is_processing(), "ProvinceNode must have _process disabled", failures)
	p_node.free()
	
	var a_node: ArmyNode = ArmyNode.new()
	_assert(not a_node.is_processing(), "ArmyNode must have _process disabled", failures)
	a_node.free()

static func test_passive_nodes_no_area2d(failures: Array[String]) -> void:
	var p_node: Object = ProvinceNode.new()
	_assert(not (p_node is Area2D), "ProvinceNode should extend Node2D, not Area2D (centralized input routing)", failures)
	p_node.free()
	
	var a_node: Object = ArmyNode.new()
	_assert(not (a_node is Area2D), "ArmyNode should extend Node2D, not Area2D (centralized input routing)", failures)
	a_node.free()
