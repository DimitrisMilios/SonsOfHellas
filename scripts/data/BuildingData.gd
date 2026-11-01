class_name BuildingData
extends Resource

enum Category {
	CIVIC,
	ECONOMIC,
	MILITARY,
	DEFENSIVE
}

@export_group("Identity")
@export var building_id: String = ""
@export var display_name: String = ""
@export_range(1, 5, 1) var tier: int = 1
@export var category: Category = Category.ECONOMIC

@export_group("Construction")
@export_range(0, 10000, 25) var build_cost: int = 200
@export_range(1, 20, 1) var build_time_turns: int = 2

@export_group("Province Bonuses")
@export_range(-500.0, 500.0, 5.0) var tax_bonus: float = 20.0
@export_range(-50.0, 50.0, 1.0) var growth_bonus: float = 2.0
@export_range(-20.0, 20.0, 1.0) var public_order_bonus: float = 4.0

@export_group("Recruitment Unlocks")
@export var unlocked_units: Array[UnitData] = []

func get_category_name() -> String:
	match category:
		Category.CIVIC:
			return "Civic"
		Category.ECONOMIC:
			return "Economic"
		Category.MILITARY:
			return "Military"
		Category.DEFENSIVE:
			return "Defensive"
		_:
			return "Unknown"
