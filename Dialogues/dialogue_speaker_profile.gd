extends Resource
class_name DialogueSpeakerProfile

@export var speaker_name: String = ""
@export var aliases: Array[String] = []
@export var default_sprite_path: String = ""
@export var default_mirror_layout: bool = true
@export var auto_fill_sprite: bool = true
@export var auto_fill_layout: bool = true
@export_range(10.0, 400.0, 1.0, "or_greater") var default_portrait_scale_percent: float = 100.0

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
