extends Resource
class_name SpellResource

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.res", "*.tres") var icon_path: String = ""

@export var spell_name: String = "Заклинание"
@export_multiline var description: String = ""
@export_group("Localization")
@export var spell_name_key: String = ""
@export var description_key: String = ""
@export_group("")
@export var fantasy_cost: int = 0
@export var required_location_id: String = ""

@export var target_type: String = "Enemy"  # Возможные значения: Enemy, Ally, Self, All_Enemies, All_Allies, Any, Position
@export var targetable_positions: Array[bool] = [true, true, true, true]

@export var effect_types: Array[String] = []
@export var effect_values: Dictionary = {}
@export var effect_durations: Dictionary = {}

# Прямой урон (без модификатора, фиксированное значение)
@export var flat_damage: int = 0
@export_enum("Physical", "Pure") var damage_type: String = "Pure"

func get_icon_texture() -> Texture2D:
	if icon_path.strip_edges() == "":
		return null
	if not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D

func get_display_name() -> String:
	return Localization.t(spell_name_key, spell_name)

func get_display_description() -> String:
	return Localization.t(description_key, description)
