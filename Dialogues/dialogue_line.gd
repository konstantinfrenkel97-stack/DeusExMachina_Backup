extends Resource
class_name DialogueLine

const LAYOUT_AUTO := 0
const LAYOUT_LEFT := 1
const LAYOUT_RIGHT := 2

@export var line_id: String = ""
@export var speaker_name: String = ""
@export_multiline var text: String = ""
@export_group("Localization")
@export var speaker_name_key: String = ""
@export var text_key: String = ""
@export_group("")
@export var sprite: Texture2D
@export var mirror_layout: bool = false
@export_enum("Авто", "Слева", "Справа") var layout_mode: int = LAYOUT_AUTO
@export_range(0.0, 400.0, 1.0, "or_greater") var portrait_scale_percent: float = 0.0 # 0 = авто из профиля, 100 = обычный размер.
@export var next_line_id: String = ""
@export var next_dialogue: DialogueResource
@export var choices: Array[DialogueChoice] = []
