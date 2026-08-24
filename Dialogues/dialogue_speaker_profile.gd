extends Resource
class_name DialogueSpeakerProfile

@export var speaker_name: String = ""
@export var aliases: Array[String] = []
@export var default_sprite_path: String = ""
@export var default_mirror_layout: bool = true
@export var auto_fill_sprite: bool = true
@export var auto_fill_layout: bool = true
@export_range(10.0, 400.0, 1.0, "or_greater") var default_portrait_scale_percent: float = 100.0
## Персонаж, чьи ползунки "Размер спрайта в диалогах" / "Вертикальное положение
## спрайта в диалогах" (character_resource.gd) нужно использовать. Если задан —
## перекрывает default_portrait_scale_percent.
@export var character: CharacterResource = null

func get_portrait_scale_percent() -> float:
	if character != null:
		return character.dialogue_sprite_scale_percent
	return default_portrait_scale_percent

func get_portrait_y_offset_percent() -> float:
	if character != null:
		return character.dialogue_sprite_y_offset_percent
	return 0.0

func matches(name: String) -> bool:
	var clean_name := name.strip_edges().to_lower()
	if speaker_name.strip_edges().to_lower() == clean_name:
		return true
	for alias in aliases:
		if alias.strip_edges().to_lower() == clean_name:
			return true
	return false

func load_default_sprite() -> Texture2D:
	var path := default_sprite_path.strip_edges()
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
