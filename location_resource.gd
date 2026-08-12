extends Resource
class_name LocationResource

## Ресурс локации (поля боя).
## Каждая локация определяет бэкграунд и боевой эффект.

@export var location_name: String = "Локация"
@export_multiline var description: String = ""
@export_group("Localization")
@export var location_name_key: String = ""
@export var description_key: String = ""
@export_group("")
@export var background_path: String = ""           # Путь к картинке фона (пусто = нет фона)
@export var fog_background_path: String = ""        # Путь к туманному фону (Хельхейм)
@export var battle_effect: String = ""              # ID эффекта (как в CombatManager)

func get_display_name() -> String:
	return Localization.t(location_name_key, location_name)

func get_display_description() -> String:
	return Localization.t(description_key, description)
