extends Control
## Сцена выбора локаций (открывается кнопкой «Ворота» из кампании).
## Локации расположены по кругу, начиная с верхней, по часовой стрелке, равноудалённо.
## «Назад» (внизу слева) и правый клик возвращают в кампанию.

const CAMPAIGN_SCENE := "res://Campaign/campaign_screen.tscn"
const MISSION_CHOICE_SCENE := "res://Doors/mission_choice_screen.tscn"

# Локации по кругу по часовой стрелке, начиная с самой верхней.
const LOCATIONS_CLOCKWISE: Array[String] = [
	"Облака", "Глубина", "Острова", "Пустыня", "Арена",
	"Замок", "Корабли", "Тоннели", "Хельхейм", "Ад",
	"Джунгли", "Топь", "Сад", "Горы", "Звезды",
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

# Иконка-дверь (открытая) для каждой локации — показывается вместо закрытой,
# как только соответствующий бог согласился открыть дверь в своём диалоге
# (CampaignState.is_location_opened). Имена файлов — как есть на диске
# (в паре мест с опечатками в исходных ассетах).
const LOCATION_DOORS_OPEN := {
	"Звезды": "res://Doors/Starts_door_open.png",
	"Облака": "res://Doors/Clouds_door_open.png",
	"Острова": "res://Doors/Islands_door_open.png",
	"Корабли": "res://Doors/Ships_door_open.png",
	"Глубина": "res://Doors/Depth_door_open.png",
	"Хельхейм": "res://Doors/Helheim_door_open.png",
	"Ад": "res://Doors/Hell_door_Open (1).png",
	"Тоннели": "res://Doors/tunnels_door_open.png",
	"Топь": "res://Doors/Marsh_door_open.png",
	"Сад": "res://Doors/Garden_door_open.png",
	"Джунгли": "res://Doors/Jungle_door_open.png",
	"Пустыня": "res://Doors/Desert_door_open.png",
	"Замок": "res://Doors/Castle_door_open.png",
	"Арена": "res://Doors/Arena_door_open.png",
	"Горы": "res://Doors/Peaks_door_open.png",
}


func _ready() -> void:
	_build_locations()


func _build_locations() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Задний фон под дверями — карта мира.
	var bg := TextureRect.new()
	bg.name = "WorldBackground"
	bg.texture = load("res://Background/World.png") as Texture2D
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
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
		if CampaignState.is_location_opened(loc):
			door_path = LOCATION_DOORS_OPEN.get(loc, door_path)
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


## Выбор локации. Дверь должна быть открыта (см. CampaignState.is_location_opened),
## иначе — ничего не происходит. Открывает экран выбора миссии локации (фон +
## кнопка «Назад»; кнопка запуска миссии появится там позже).
func _on_location_selected(location: String) -> void:
	if not CampaignState.is_location_opened(location):
		print("Дверь ещё закрыта: ", location)
		return
	MissionState.pending_location = location
	get_tree().change_scene_to_file(MISSION_CHOICE_SCENE)
