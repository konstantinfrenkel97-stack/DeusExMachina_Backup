extends Control
## Сцена выбора локаций (открывается кнопкой «Ворота» из кампании).
## Локации расположены по кругу, начиная с верхней, по часовой стрелке, равноудалённо.
## «Назад» (внизу слева) и правый клик возвращают в кампанию.

const CAMPAIGN_SCENE := "res://Campaign/campaign_screen.tscn"
const MISSION_SELECT_SCENE := "res://Missions/mission_select.tscn"
const WELCOME_TO_HELHEIM_MISSION_PATH := "res://Missions/welcome_to_helheim_mission.tres"

# Локации по кругу по часовой стрелке, начиная с самой верхней.
const LOCATIONS_CLOCKWISE: Array[String] = [
	"Звезды", "Облака", "Острова", "Корабли", "Глубина",
	"Хельхейм", "Ад", "Тоннели", "Топь", "Сад",
	"Джунгли", "Пустыня", "Замок", "Арена", "Горы",
]

# Иконка-дверь (закрытая) для каждой локации.
const LOCATION_DOORS := {
	"Звезды": "res://Doors/Stars_door.png",
	"Облака": "res://Doors/Clouds_door.png",
	"Острова": "res://Doors/islands_door.png",
	"Корабли": "res://Doors/Ships_door.png",
	"Глубина": "res://Doors/Depth_door.png",
	"Хельхейм": "res://Doors/Helheim_door.png",
	"Ад": "res://Doors/Hell_Door (1).png",
	"Тоннели": "res://Doors/Tunnels_door.png",
	"Топь": "res://Doors/Marsh_door.png",
	"Сад": "res://Doors/Garden_door.png",
	"Джунгли": "res://Doors/Jungle_door.png",
	"Пустыня": "res://Doors/Desert_door.png",
	"Замок": "res://Doors/Castle_door (1).png",
	"Арена": "res://Doors/Arena_door (1).png",
	"Горы": "res://Doors/Peaks_door.png",
}


func _ready() -> void:
	_build_locations()


func _build_locations() -> void:
	var vp := get_viewport().get_visible_rect().size
	var center := vp * 0.5
	# Овал (эллипс): шире по горизонтали, чтобы 15 дверей не наезжали друг на друга.
	var rx := vp.x * 0.42
	var ry := vp.y * 0.36
	var count := LOCATIONS_CLOCKWISE.size()
	var step := TAU / float(count) # равноудалённое расположение
	for i in range(count):
		var loc := LOCATIONS_CLOCKWISE[i]
		var theta := step * float(i) # 0 = самая верхняя локация, далее по часовой
		var pos := Vector2(center.x + rx * sin(theta), center.y - ry * cos(theta))
		var btn := Button.new()
		btn.text = "" # только иконка-дверь, без текста
		btn.tooltip_text = loc
		btn.flat = true # без рамки кнопки — видна только дверь
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(92, 110)
		btn.position = pos - btn.custom_minimum_size * 0.5
		var door_path: String = LOCATION_DOORS.get(loc, "")
		if door_path != "":
			btn.icon = load(door_path) as Texture2D
		btn.pressed.connect(_on_location_selected.bind(loc))
		add_child(btn)

	# Кнопка «Назад» в нижнем левом углу.
	var back := Button.new()
	back.text = "← Назад"
	back.custom_minimum_size = Vector2(170, 56)
	back.position = Vector2(24, vp.y - 80)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_go_back)
	add_child(back)


## Возврат в кампанию.
func _go_back() -> void:
	get_tree().change_scene_to_file(CAMPAIGN_SCENE)


## Правый клик = назад.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_go_back()
		get_viewport().set_input_as_handled()


## Выбор локации. Пока заглушка; позже — открытие доступных миссий этой локации.
func _on_location_selected(location: String) -> void:
	if location == "Хельхейм":
		_launch_mission_from_path(WELCOME_TO_HELHEIM_MISSION_PATH)
		return
	print("Выбрана локация: ", location)

func _launch_mission_from_path(path: String) -> void:
	if path.strip_edges() == "" or not ResourceLoader.exists(path):
		push_warning("Не найдена миссия: " + path)
		return
	MissionState.requested_mission_path = path
	MissionState.return_scene_path = "res://Doors/doors.tscn"
	get_tree().change_scene_to_file(MISSION_SELECT_SCENE)
