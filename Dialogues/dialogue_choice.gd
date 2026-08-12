extends Resource
class_name DialogueChoice

@export var choice_id: String = ""
@export var choice_text: String = "Вариант"
@export_group("Localization")
@export var choice_text_key: String = ""
@export_group("")
@export var next_line_id: String = ""
@export var next_dialogue: DialogueResource
@export var end_dialogue: bool = false
