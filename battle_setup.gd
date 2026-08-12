extends Control

const GODS_DIR := "res://Gods/"
const LEFT_EDGE := 40.0
const RIGHT_EDGE := 1240.0
const SPAN_WIDTH := RIGHT_EDGE - LEFT_EDGE
const LOCATION_CARD_SIZE := Vector2(230, 96)
const LOCATION_ICON_SIZE := Vector2(150, 70)
const SLOT_SIZE := Vector2(120, 120)
const SLOT_ICON_SIZE := Vector2(98, 76)
const HERO_PICKER_CARD_SIZE := Vector2(96, 60)
const ENEMY_PICKER_CARD_SIZE := Vector2(122, 60)
const PICKER_ICON_SIZE := Vector2(44, 30)

const LOCATIONS := [
	{"name":"Хельхейм", "category":"Подземелье", "description":"Без описания", "id":"helheim", "background":"res://Background/Helheim.png", "fog":"res://Background/Helheim_fog.png", "enemy_dir":"res://Enemies/Dungeon/Hellheim/", "door":"res://Doors/Helheim_door.png", "door_open":"res://Doors/Helheim_door_open.png"},
	{"name":"Ад", "category":"Подземелье", "description":"Без описания", "id":"hell", "background":"res://Background/Hell.png", "fog":"", "enemy_dir":"res://Enemies/Dungeon/Hell/", "door":"res://Doors/Hell_Door (1).png", "door_open":"res://Doors/Hell_door_Open (1).png"},
	{"name":"Тоннели", "category":"Подземелье", "description":"Без описания", "id":"tunnels", "background":"res://Background/Tunnels.png", "fog":"", "enemy_dir":"res://Enemies/Dungeon/Tunnels/", "door":"res://Doors/Tunnels_door.png", "door_open":"res://Doors/tunnels_door_open.png"},
	{"name":"Облака", "category":"Небо", "description":"Без описания", "id":"clouds", "background":"res://Background/Clouds.png", "fog":"", "enemy_dir":"res://Enemies/Sky/Clouds/", "door":"res://Doors/Clouds_door.png", "door_open":"res://Doors/Clouds_door_open.png"},
	{"name":"Звезды", "category":"Небо", "description":"Без описания", "id":"stars", "background":"res://Background/Stars.png", "fog":"", "enemy_dir":"res://Enemies/Sky/Stars/", "door":"res://Doors/Stars_door.png", "door_open":"res://Doors/Starts_door_open.png"},
	{"name":"Горы", "category":"Небо", "description":"Без описания", "id":"mountains", "background":"res://Background/Peaks.png", "fog":"", "enemy_dir":"res://Enemies/Sky/Peaks/", "door":"res://Doors/Peaks_door.png", "door_open":"res://Doors/Peaks_door_open.png"},
	{"name":"Арена", "category":"Цивилизация", "description":"Без описания", "id":"arena", "background":"res://Background/Arena.png", "fog":"", "enemy_dir":"res://Enemies/Civilization/Arena/", "door":"res://Doors/Arena_door (1).png", "door_open":"res://Doors/Arena_door_open.png"},
	{"name":"Замок", "category":"Цивилизация", "description":"Без описания", "id":"castle", "background":"res://Background/Castle.png", "fog":"", "enemy_dir":"res://Enemies/Civilization/Castle/", "door":"res://Doors/Castle_door (1).png", "door_open":"res://Doors/Castle_door_open.png"},
	{"name":"Пустыня", "category":"Цивилизация", "description":"Без описания", "id":"desert", "background":"res://Background/Desert.png", "fog":"", "enemy_dir":"res://Enemies/Civilization/Desert/", "door":"res://Doors/Desert_door.png", "door_open":"res://Doors/Desert_door_open.png"},
	{"name":"Глубина", "category":"Море", "description":"Без описания", "id":"depths", "background":"res://Background/Deep.png", "fog":"", "enemy_dir":"res://Enemies/Sea/Depth/", "door":"res://Doors/Depth_door.png", "door_open":"res://Doors/Depth_door_open.png"},
	{"name":"Остров", "category":"Море", "description":"Без описания", "id":"island", "background":"res://Background/Islands.png", "fog":"", "enemy_dir":"res://Enemies/Sea/Islands/", "door":"res://Doors/islands_door.png", "door_open":"res://Doors/Islands_door_open.png"},
	{"name":"Корабли", "category":"Море", "description":"Без описания", "id":"ships", "background":"res://Background/Ships.png", "fog":"", "enemy_dir":"res://Enemies/Sea/Ships/", "door":"res://Doors/Ships_door.png", "door_open":"res://Doors/Ships_door_open.png"},
	{"name":"Джунгли", "category":"Лес", "description":"Без описания", "id":"jungle", "background":"res://Background/Jungle.png", "fog":"", "enemy_dir":"res://Enemies/Forest/Jungle/", "door":"res://Doors/Jungle_door.png", "door_open":"res://Doors/Jungle_door_open.png"},
	{"name":"Сад", "category":"Лес", "description":"Без описания", "id":"garden", "background":"res://Background/Garden.png", "fog":"", "enemy_dir":"res://Enemies/Forest/Garden/", "door":"res://Doors/Garden_door.png", "door_open":"res://Doors/Garden_door_open.png"},
	{"name":"Топь", "category":"Лес", "description":"Без описания", "id":"swamp", "background":"res://Background/Marsh.png", "fog":"", "enemy_dir":"res://Enemies/Forest/Marsh/", "door":"res://Doors/Marsh_door.png", "door_open":"res://Doors/Marsh_door_open.png"},
]

static func apply_location_to_combat_manager(location_id: String) -> bool:
	if location_id.strip_edges() == "":
		return false
	for loc in LOCATIONS:
		if str(loc["id"]) == location_id:
			CombatManager.selected_location_name = str(loc["name"])
			CombatManager.selected_location_description = str(loc["description"])
			CombatManager.selected_location_id = str(loc["id"])
			CombatManager.selected_location_category = str(loc["category"])
			CombatManager.selected_background = str(loc["background"])
			CombatManager.selected_fog_background = str(loc["fog"])
			return true
	return false

var available_heroes: Array[String] = []
var available_enemies: Array[String] = []
var _resource_name_cache: Dictionary = {}
var _resource_texture_cache: Dictionary = {}
var _location_buttons: Array[Button] = []
var _hero_slot_buttons: Array[Button] = []
var _enemy_slot_buttons: Array[Button] = []
var _current_location_index := -1
var _current_slot_is_enemy := false
var _current_slot_index := -1
var _enemies_locked := false
var _heroes_locked := false
var _status_label: Label
var _hero_picker_panel: PanelContainer
var _enemy_picker_panel: PanelContainer
var _hero_picker_grid: GridContainer
var _enemy_picker_grid: GridContainer
var _start_button: Button

func _ready() -> void:
	_prepare_selection_state()
	_scan_directory_for_resources(GODS_DIR, available_heroes)
	available_heroes.sort_custom(func(a: String, b: String) -> bool: return _get_name_from_resource(a, a) < _get_name_from_resource(b, b))
	_build_ui()
	_apply_mission_location_if_needed()
	_rebuild_hero_picker()
	_rebuild_enemy_picker()
	_update_all()

func _prepare_selection_state() -> void:
	var formation_enemies: Array[String] = CombatManager.pending_formation_enemies.duplicate()
	var has_formation := false
	for path in formation_enemies:
		if path != "":
			has_formation = true
			break
	var saved_is_mission := CombatManager.is_mission_battle
	var saved_mission_set := CombatManager.mission_heroes_set
	var saved_mission_heroes := CombatManager.mission_heroes.duplicate()
	var saved_dead := CombatManager.mission_dead_heroes.duplicate()
	var saved_location_id := CombatManager.pending_location_id
	CombatManager.clear_selection()
	CombatManager.is_mission_battle = saved_is_mission
	CombatManager.mission_heroes_set = saved_mission_set
	CombatManager.mission_heroes = saved_mission_heroes
	CombatManager.mission_dead_heroes = saved_dead
	CombatManager.pending_location_id = saved_location_id
	if has_formation:
		_enemies_locked = true
		CombatManager.selected_enemies = formation_enemies
	if CombatManager.mission_heroes_set:
		_heroes_locked = true
		for i in range(4):
			var hero_path: String = CombatManager.mission_heroes[i]
			if hero_path != "" and not CombatManager.mission_dead_heroes.has(hero_path):
				CombatManager.selected_heroes[i] = hero_path

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back_button := Button.new()
	back_button.text = "Назад"
	back_button.position = Vector2(LEFT_EDGE, 8)
	back_button.size = Vector2(120, 34)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.position = Vector2(LEFT_EDGE, 26)
	_status_label.size = Vector2(SPAN_WIDTH, 20)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	add_child(_status_label)
	_build_locations()
	_build_slots()
	_build_picker_panels()
	_start_button = Button.new()
	_start_button.text = "В БОЙ!"
	_start_button.position = Vector2(1092, 8)
	_start_button.size = Vector2(148, 34)
	_start_button.pressed.connect(_on_start_battle_pressed)
	add_child(_start_button)

func _build_locations() -> void:
	var start_y := 50.0
	var h_gap := (SPAN_WIDTH - LOCATION_CARD_SIZE.x * 5.0) / 4.0
	var v_gap := 8.0
	for i in range(LOCATIONS.size()):
		var row := floori(i / 5.0)
		var col := i % 5
		var button := _make_location_button(i)
		button.position = Vector2(LEFT_EDGE + col * (LOCATION_CARD_SIZE.x + h_gap), start_y + row * (LOCATION_CARD_SIZE.y + v_gap))
		_location_buttons.append(button)
		add_child(button)

func _build_slots() -> void:
	var slot_y := 376.0
	var slot_gap := 8.0
	var group_width := SLOT_SIZE.x * 4.0 + slot_gap * 3.0
	var enemy_x := RIGHT_EDGE - group_width
	_hero_slot_buttons.resize(4)
	_enemy_slot_buttons.resize(4)
	for visual_index in range(4):
		var hero_index := 3 - visual_index
		var hero_button := _make_slot_button(false, hero_index)
		hero_button.position = Vector2(LEFT_EDGE + visual_index * (SLOT_SIZE.x + slot_gap), slot_y)
		_hero_slot_buttons[hero_index] = hero_button
		add_child(hero_button)
		var enemy_button := _make_slot_button(true, visual_index)
		enemy_button.position = Vector2(enemy_x + visual_index * (SLOT_SIZE.x + slot_gap), slot_y)
		_enemy_slot_buttons[visual_index] = enemy_button
		add_child(enemy_button)


func _make_location_button(index: int) -> Button:
	var loc: Dictionary = LOCATIONS[index]
	var button := Button.new()
	button.size = LOCATION_CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.toggle_mode = true
	button.pressed.connect(_on_location_pressed.bind(index))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2((LOCATION_CARD_SIZE.x - LOCATION_ICON_SIZE.x) * 0.5, 2)
	icon.size = LOCATION_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := Label.new()
	label.name = "Name"
	label.text = str(loc["name"])
	label.position = Vector2(4, 74)
	label.size = Vector2(LOCATION_CARD_SIZE.x - 8, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _make_slot_button(is_enemy: bool, index: int) -> Button:
	var button := Button.new()
	button.size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.toggle_mode = true
	button.pressed.connect(_on_slot_pressed.bind(is_enemy, index))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2((SLOT_SIZE.x - SLOT_ICON_SIZE.x) * 0.5, 6)
	icon.size = SLOT_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := Label.new()
	label.name = "Name"
	label.position = Vector2(4, 84)
	label.size = Vector2(SLOT_SIZE.x - 8, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _build_picker_panels() -> void:
	var slot_gap := 8.0
	var group_width := SLOT_SIZE.x * 4.0 + slot_gap * 3.0
	var enemy_x := RIGHT_EDGE - group_width
	var panel_y := 512.0
	var panel_size := Vector2(group_width, 198)

	_hero_picker_panel = _make_picker_panel(Vector2(LEFT_EDGE, panel_y), panel_size)
	add_child(_hero_picker_panel)
	_hero_picker_grid = _hero_picker_panel.get_node("Box/Grid") as GridContainer
	_hero_picker_grid.columns = 5

	_enemy_picker_panel = _make_picker_panel(Vector2(enemy_x, panel_y), panel_size)
	add_child(_enemy_picker_panel)
	_enemy_picker_grid = _enemy_picker_panel.get_node("Box/Grid") as GridContainer
	_enemy_picker_grid.columns = 4

func _make_picker_panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	box.add_child(grid)
	return panel

func _apply_mission_location_if_needed() -> void:
	if CombatManager.pending_location_id == "":
		return
	for i in range(LOCATIONS.size()):
		if LOCATIONS[i]["id"] == CombatManager.pending_location_id:
			_select_location(i, false)
			for button in _location_buttons:
				button.disabled = true
			break

func _on_location_pressed(index: int) -> void:
	_select_location(index, true)

func _select_location(index: int, clear_enemies: bool) -> void:
	if index < 0 or index >= LOCATIONS.size():
		return
	var changed := _current_location_index != index
	_current_location_index = index
	var loc: Dictionary = LOCATIONS[index]
	CombatManager.selected_location_name = str(loc["name"])
	CombatManager.selected_location_description = str(loc["description"])
	CombatManager.selected_location_id = str(loc["id"])
	CombatManager.selected_location_category = str(loc["category"])
	CombatManager.selected_background = str(loc["background"])
	CombatManager.selected_fog_background = str(loc["fog"])
	available_enemies.clear()
	_scan_directory_for_resources(str(loc["enemy_dir"]), available_enemies)
	available_enemies.sort_custom(func(a: String, b: String) -> bool: return _get_name_from_resource(a, a) < _get_name_from_resource(b, b))
	if clear_enemies and changed and not _enemies_locked:
		CombatManager.selected_enemies = ["", "", "", ""]
	_rebuild_enemy_picker()
	_update_all()

func _on_slot_pressed(is_enemy: bool, index: int) -> void:
	if is_enemy and (_enemies_locked or _is_enemy_slot_blocked(index)):
		return
	if not is_enemy and _heroes_locked and _is_mission_dead_slot(index):
		return
	_current_slot_is_enemy = is_enemy
	_current_slot_index = index
	_rebuild_hero_picker()
	_rebuild_enemy_picker()
	_update_all()

func _rebuild_hero_picker() -> void:
	_clear_grid(_hero_picker_grid)
	for path in _get_alive_heroes():
		_hero_picker_grid.add_child(_make_character_card(path, false))

func _rebuild_enemy_picker() -> void:
	_clear_grid(_enemy_picker_grid)
	for path in available_enemies:
		_enemy_picker_grid.add_child(_make_character_card(path, true))

func _clear_grid(grid: GridContainer) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()

func _make_character_card(path: String, is_enemy: bool) -> Button:
	var card_size := ENEMY_PICKER_CARD_SIZE if is_enemy else HERO_PICKER_CARD_SIZE
	var button := Button.new()
	button.custom_minimum_size = card_size
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.disabled = _current_slot_index != -1 and is_enemy == _current_slot_is_enemy and not _can_place_character(path, is_enemy, _current_slot_index)
	if is_enemy:
		button.pressed.connect(_select_enemy.bind(path))
	else:
		button.pressed.connect(_select_hero.bind(path))
	var icon := TextureRect.new()
	icon.position = Vector2((card_size.x - PICKER_ICON_SIZE.x) * 0.5, 2)
	icon.size = PICKER_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _get_character_texture(path)
	button.add_child(icon)
	var label := Label.new()
	label.text = _get_name_from_resource(path, "")
	label.position = Vector2(3, 32)
	label.size = Vector2(card_size.x - 6, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8 if is_enemy else 9)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _select_hero(path: String) -> void:
	if _current_slot_index == -1 or _current_slot_is_enemy:
		return
	_select_character(path)

func _select_enemy(path: String) -> void:
	if _current_slot_index == -1 or not _current_slot_is_enemy:
		return
	if _current_location_index == -1:
		return
	_select_character(path)

func _select_character(path: String) -> void:
	if _current_slot_index == -1:
		return
	if not _current_slot_is_enemy and _heroes_locked and path == "":
		return
	if path != "" and not _can_place_character(path, _current_slot_is_enemy, _current_slot_index):
		return
	var selected_array: Array[String] = CombatManager.selected_enemies if _current_slot_is_enemy else CombatManager.selected_heroes
	if not _current_slot_is_enemy and _heroes_locked and path != "":
		var displaced := selected_array[_current_slot_index]
		selected_array[_current_slot_index] = path
		for i in range(4):
			if i != _current_slot_index and selected_array[i] == path:
				selected_array[i] = displaced
				break
	else:
		selected_array[_current_slot_index] = path
	if _current_slot_is_enemy:
		_normalize_large_slots_in_array(selected_array)
	_rebuild_hero_picker()
	_rebuild_enemy_picker()
	_update_all()

func _can_place_character(path: String, is_enemy: bool, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 4:
		return false
	var selected_array: Array[String] = CombatManager.selected_enemies if is_enemy else CombatManager.selected_heroes
	var test_array: Array[String] = []
	for item in selected_array:
		test_array.append(item)
	test_array[slot_index] = path
	if is_enemy:
		_normalize_large_slots_in_array(test_array)
	var used_slots := 0
	for check_path in test_array:
		if check_path == "":
			continue
		var res := CampaignState.load_character_resource(check_path)
		used_slots += 2 if res != null and res.is_large else 1
	return used_slots <= 4

func _normalize_large_slots_in_array(slots: Array[String]) -> void:
	for i in range(1, 4):
		var prev_path: String = slots[i - 1]
		if prev_path == "":
			continue
		var prev_res := CampaignState.load_character_resource(prev_path)
		if prev_res != null and prev_res.is_large:
			slots[i] = ""
func _update_all() -> void:
	_update_location_buttons()
	_update_slots()
	_update_start_button()

func _update_location_buttons() -> void:
	for i in range(_location_buttons.size()):
		var button := _location_buttons[i]
		var loc: Dictionary = LOCATIONS[i]
		var icon := button.get_node("Icon") as TextureRect
		var door_path := str(loc.get("door_open", "")) if i == _current_location_index else str(loc.get("door", ""))
		icon.texture = _load_texture_or_null(door_path)
		button.button_pressed = i == _current_location_index
	if _current_location_index == -1:
		_status_label.text = ""
	else:
		var loc_now: Dictionary = LOCATIONS[_current_location_index]
		_status_label.text = "%s: %s (%s)" % ["Локация", loc_now["name"], loc_now["category"]]

func _update_slots() -> void:
	for i in range(4):
		_update_slot_button(_hero_slot_buttons[i], false, i)
		_update_slot_button(_enemy_slot_buttons[i], true, i)

func _update_slot_button(button: Button, is_enemy: bool, index: int) -> void:
	var selected_array: Array[String] = CombatManager.selected_enemies if is_enemy else CombatManager.selected_heroes
	var icon := button.get_node("Icon") as TextureRect
	var label := button.get_node("Name") as Label
	icon.texture = null
	button.disabled = false
	button.button_pressed = _current_slot_index == index and _current_slot_is_enemy == is_enemy
	if is_enemy and _is_enemy_slot_blocked(index):
		label.text = ""
		button.disabled = true
		return
	if is_enemy and _enemies_locked:
		button.disabled = true
	if is_enemy and _current_location_index == -1:
		label.text = ""
		return
	if not is_enemy and _is_mission_dead_slot(index):
		var dead_path: String = CombatManager.mission_heroes[index]
		label.text = "%s: %s" % ["Погиб", _get_name_from_resource(dead_path, "???")]
		button.disabled = true
		return
	var path := selected_array[index]
	if path == "":
		label.text = ""
		return
	label.text = _get_name_from_resource(path, "???")
	icon.texture = _get_character_texture(path)

func _is_enemy_slot_blocked(index: int) -> bool:
	if index <= 0:
		return false
	var prev_path: String = CombatManager.selected_enemies[index - 1]
	if prev_path == "":
		return false
	var prev_res := CampaignState.load_character_resource(prev_path)
	return prev_res != null and prev_res.is_large

func _is_mission_dead_slot(index: int) -> bool:
	if not _heroes_locked or index >= CombatManager.mission_heroes.size():
		return false
	var mission_path: String = CombatManager.mission_heroes[index]
	return mission_path != "" and CombatManager.mission_dead_heroes.has(mission_path)

func _update_start_button() -> void:
	var has_hero := false
	var has_enemy := false
	for path in CombatManager.selected_heroes:
		if path != "":
			has_hero = true
			break
	for path in CombatManager.selected_enemies:
		if path != "":
			has_enemy = true
			break
	_start_button.disabled = _current_location_index == -1 or not has_hero or not has_enemy

func _get_alive_heroes() -> Array[String]:
	var result: Array[String] = []
	if _heroes_locked:
		for hero_path in CombatManager.mission_heroes:
			if hero_path != "" and not CombatManager.mission_dead_heroes.has(hero_path):
				result.append(hero_path)
		return result
	for hero_path in available_heroes:
		if CombatManager.mission_dead_heroes.has(hero_path):
			continue
		var res := CampaignState.load_character_resource(hero_path)
		if res != null and res.is_dead:
			continue
		result.append(hero_path)
	return result

func _scan_directory_for_resources(path: String, array_to_fill: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			_scan_directory_for_resources(path + file_name + "/", array_to_fill)
		elif file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var clean_path := path + file_name.replace(".remap", "")
			var res := load(clean_path)
			if res is CharacterResource:
				array_to_fill.append(clean_path)
				_resource_name_cache[clean_path] = res.unit_name
		file_name = dir.get_next()
	dir.list_dir_end()

func _get_name_from_resource(path: String, default_name: String) -> String:
	if path == "":
		return default_name
	if _resource_name_cache.has(path):
		return str(_resource_name_cache[path])
	var res := CampaignState.load_character_resource(path)
	if res != null:
		_resource_name_cache[path] = res.unit_name
		return res.unit_name
	return default_name

func _get_character_texture(path: String) -> Texture2D:
	if _resource_texture_cache.has(path):
		return _resource_texture_cache[path]
	var res := CampaignState.load_character_resource(path)
	if res == null:
		return null
	var texture := _load_texture_or_null(res.face_sprite)
	if texture == null:
		texture = _load_texture_or_null(res.sprite_path)
	_resource_texture_cache[path] = texture
	return texture

func _load_texture_or_null(path: String) -> Texture2D:
	if path.strip_edges() == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _on_start_battle_pressed() -> void:
	if CombatManager.is_mission_battle and not CombatManager.mission_heroes_set:
		CombatManager.mission_heroes = CombatManager.selected_heroes.duplicate()
		CombatManager.mission_heroes_set = true
	if CombatManager.is_mission_battle:
		_apply_forgetting_to_heroes()
	get_tree().change_scene_to_file("res://battle_scene.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _apply_forgetting_to_heroes() -> void:
	for hero_path in CombatManager.selected_heroes:
		if hero_path.strip_edges() == "":
			continue
		if CampaignState.is_god_dead(hero_path):
			continue
		CampaignState.add_god_forgetting(hero_path, 0.5)
