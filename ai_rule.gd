extends Resource
class_name AIRule

@export var ability: AbilityResource
@export var condition_type: String = "always"
@export_range(0, 100) var probability: int = 100
