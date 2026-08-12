extends Resource
class_name DialogueResource

@export var dialogue_id: String = ""
@export var dialogue_name: String = "Диалог"
@export_group("Localization")
@export var dialogue_name_key: String = ""
@export_group("")
@export var start_line_id: String = ""
@export var lines: Array[DialogueLine] = []

func get_start_index() -> int:
	if lines.is_empty():
		return -1
	if start_line_id.strip_edges() == "":
		return 0
	var index := find_line_index(start_line_id)
	return index if index != -1 else 0

func find_line_index(line_id: String) -> int:
	if line_id.strip_edges() == "":
		return -1
	for i in range(lines.size()):
		var line := lines[i]
		if line != null and line.line_id == line_id:
			return i
	return -1
