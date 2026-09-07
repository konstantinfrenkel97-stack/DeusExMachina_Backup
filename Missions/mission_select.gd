extends Control

@export var mission_path: String = ""

const SLOT_SIZE := Vector2(200, 200)
const CARD_SIZE := Vector2(200, 200)
const GRID_COLUMNS := 5
const GRID_ROWS := 3
const GRID_CELL_COUNT := GRID_COLUMNS * GRID_ROWS
const DEFAULT_RETURN_SCENE_PATH := "res://main_menu.tscn"
const PANEL_PADDING := 8.0
const HEADER_HEIGHT := 64.0
const REQUIRED_HEIGHT := 18.0
const BUTTON_SIZE := Vector2(132, 32)
const SLOT_GAP := 8.0
const GRID_GAP := 8.0
const SLOTS_TOP := 98.0
const GRID_TOP_GAP := 10.0

@onready var title_label: Label = $Title
@onready var grid: GridContainer = $Scroll/Grid
@onready var back_button: Button = $BackButton

var mission: MissionResource = null
var _selected_scene = null
var _selected_heroes: Array[String] = ["", "", "", ""]
var _slot_buttons: Array[Button] = []
var _god_buttons: Array[Button] = []
var _god_button_paths: Array[String] = []
var _selected_slot_index: int = -1
var _selected_god_path: String = ""
var _drag_path: String = ""
var _drag_source_slot: int = -1
var _drag_preview: TextureRect = null
var _prep_panel: PanelContainer = null
var _prep_root: Control = null
var _prep_text: Label = null
var _start_button: Button = null
var _required_label: Label = null
var _required_god_path: String = ""
var _show_mission_list: bool = false

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.offset_top = 8
	title_label.offset_bottom = 42
	_reset_back_button_position()
	$Scroll.offset_top = 48
	$Scroll.offset_bottom = -20
	var requested_path: String = MissionState.requested_mission_path.strip_edges()
	if requested_path != "":
		mission_path = requested_path
		_load_and_open_mission(mission_path)
		return
	_show_mission_list = true
	title_label.text = "Выбор миссии"
	_build_mission_list()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _prep_panel != null:
		_layout_prep_panel()


func _reset_back_button_position() -> void:
	back_button.offset_left = 20
	back_button.offset_top = 8
	back_button.offset_right = 160
	back_button.offset_bottom = 42

func _window_scale() -> float:
	var transform_scale: Vector2 = get_viewport().get_screen_transform().get_scale()
	var scale_value: float = min(transform_scale.x, transform_scale.y)
	if scale_value >= 1.0:
		return scale_value
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0.0 or window_size.y <= 0.0:
		return 1.0
	var scale_x: float = window_size.x / viewport_size.x
	var scale_y: float = window_size.y / viewport_size.y
	scale_value = min(scale_x, scale_y)
	if scale_value < 1.0:
		return 1.0
	return scale_value

func _canvas_value(visible_value: float) -> float:
	return visible_value / _window_scale()

func _canvas_size(visible_size: Vector2) -> Vector2:
	return visible_size / _window_scale()

func _canvas_font_size(visible_size: int) -> int:
	var scaled: int = int(round(float(visible_size) / _window_scale()))
	if scaled < 8:
		return 8
	return scaled
func _build_buttons() -> void:
	for child in grid.get_children():
		child.queue_free()
	if mission == null:
		return
	if mission.scenes.is_empty() or mission.scenes[0] == null:
		title_label.text = "%s\nВ миссии нет первой сцены" % title_label.text
		return
	call_deferred("_open_mission_prep", mission.scenes[0])

func _build_mission_list() -> void:
	for child in grid.get_children():
		child.queue_free()
	grid.columns = 2
	var paths: Array[String] = _get_available_mission_paths()
	if paths.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Нет доступных миссий"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(empty_label)
		return
	for path in paths:
		grid.add_child(_make_mission_button(path))

func _get_available_mission_paths() -> Array[String]:
	var result: Array[String] = []
	for path in CampaignState.available_missions:
		var clean_path: String = str(path).strip_edges()
		if clean_path != "" and ResourceLoader.exists(clean_path) and not result.has(clean_path):
			result.append(clean_path)
	if not result.is_empty():
		return result
	_collect_mission_paths_from_dir("res://Missions", result)
	result.sort()
	return result

func _collect_mission_paths_from_dir(dir_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if file_name.begins_with("."):
			continue
		var path: String = "%s/%s" % [dir_path, file_name]
		if dir.current_is_dir():
			_collect_mission_paths_from_dir(path, result)
		elif file_name.get_extension().to_lower() == "tres":
			var loaded: Resource = load(path)
			if loaded is MissionResource and not result.has(path):
				result.append(path)
	dir.list_dir_end()

func _make_mission_button(path: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.text = _get_mission_button_text(path)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_load_and_open_mission.bind(path))
	return button

func _get_mission_button_text(path: String) -> String:
	var loaded: Resource = load(path)
	if loaded is MissionResource:
		var mission_res := loaded as MissionResource
		var display_name: String = Localization.text_from(mission_res, "mission_name_key", "mission_name", mission_res.mission_name)
		if display_name.strip_edges() != "":
			return display_name
	return path.get_file().get_basename()

func _load_and_open_mission(path: String) -> void:
	mission_path = path.strip_edges()
	mission = null
	_required_god_path = ""
	if mission_path != "" and ResourceLoader.exists(mission_path):
		var loaded: Resource = load(mission_path)
		if loaded is MissionResource:
			mission = loaded as MissionResource
	if mission == null:
		title_label.text = "Миссия не найдена:\n%s" % mission_path
		_build_buttons()
		return
	if CampaignState.is_mission_completed(mission_path):
		# Полноэкранная панель подготовки отряда (mouse_filter = STOP) могла остаться
		# от предыдущей миссии — если её не убрать, она перехватывает вообще все клики
		# и ПКМ, и с экрана невозможно выйти никак.
		if _prep_panel != null and is_instance_valid(_prep_panel):
			_prep_panel.queue_free()
		_prep_panel = null
		_prep_root = null
		_reset_back_button_position()
		for child in grid.get_children():
			child.queue_free()
		title_label.text = "Миссия уже пройдена"
		mission = null
		return
	title_label.text = Localization.text_from(mission, "mission_name_key", "mission_name", mission.mission_name)
	_required_god_path = mission.get_required_god_path()
	_build_buttons()
func _open_mission_prep(scene) -> void:
	_selected_scene = scene
	_selected_heroes = ["", "", "", ""]
	_selected_slot_index = -1
	_selected_god_path = ""
	_clear_drag()
	if _prep_panel != null:
		_prep_panel.queue_free()
	_build_prep_panel(scene)
	_update_prep_ui()

func _build_prep_panel(scene) -> void:
	_prep_panel = PanelContainer.new()
	_prep_panel.name = "MissionPrep"
	_prep_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prep_panel.offset_left = 12
	_prep_panel.offset_top = 36
	_prep_panel.offset_right = -12
	_prep_panel.offset_bottom = -8
	_prep_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_prep_panel)
	add_child(_prep_panel)

	_prep_root = Control.new()
	_prep_root.name = "PrepRoot"
	_prep_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prep_root.offset_left = 0
	_prep_root.offset_top = 0
	_prep_root.offset_right = 0
	_prep_root.offset_bottom = 0
	_prep_panel.add_child(_prep_root)

	_prep_text = Label.new()
	_prep_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prep_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_prep_text.add_theme_font_size_override("font_size", _canvas_font_size(14))
	# Текст сцены уже показывается на экране первого выбора (mission_scene.tscn),
	# здесь, на экране выбора богов, он пока не дублируется.
	_prep_root.add_child(_prep_text)

	_required_label = Label.new()
	_required_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_required_label.add_theme_font_size_override("font_size", _canvas_font_size(14))
	_required_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_root.add_child(_required_label)

	_start_button = Button.new()
	_start_button.text = "Вперед"
	_start_button.custom_minimum_size = _canvas_size(BUTTON_SIZE)
	# Размер кнопки в _layout_prep_panel() берётся из back_button.size напрямую
	# (нескейленные canvas-единицы), а не из _canvas_size(BUTTON_SIZE) — значит и
	# шрифт должен браться из back_button, а не через _canvas_font_size(), иначе
	# при window_scale > 1 текст оказывается мельче, чем позволяет размер кнопки.
	_start_button.add_theme_font_size_override("font_size", back_button.get_theme_font_size("font_size"))
	_start_button.pressed.connect(_start_selected_mission)
	_prep_root.add_child(_start_button)

	# Слева направо на экране = задняя позиция → передняя (та же логика, что и в
	# battle_setup.gd), т.к. на самом поле боя Pos1 — правая (ближняя к врагам)
	# позиция героев, а Pos4 — левая. Массив индексируется hero_index (= позиции
	# боя), а не порядком слева направо, поэтому дальше по коду ничего менять не нужно.
	_slot_buttons.clear()
	_slot_buttons.resize(4)
	for visual_index in range(4):
		var hero_index := 3 - visual_index
		var slot := _make_square_button(true)
		slot.gui_input.connect(_on_slot_gui_input.bind(hero_index))
		_prep_root.add_child(slot)
		_slot_buttons[hero_index] = slot

	_god_buttons.clear()
	_god_button_paths.clear()
	var available := _get_available_god_paths()
	for i in range(GRID_CELL_COUNT):
		var path: String = available[i] if i < available.size() else ""
		var god_button := _make_square_button(false)
		god_button.gui_input.connect(_on_god_gui_input.bind(i))
		_prep_root.add_child(god_button)
		_god_buttons.append(god_button)
		_god_button_paths.append(path)

	call_deferred("_layout_prep_panel")

func _layout_prep_panel() -> void:
	if _prep_panel == null or _prep_root == null:
		return
	var panel_size: Vector2 = _prep_panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var panel_padding: float = _canvas_value(PANEL_PADDING)
	var header_height: float = _canvas_value(HEADER_HEIGHT)
	var required_height: float = _canvas_value(REQUIRED_HEIGHT)
	# Совпадает по размеру с back_button (а не с константой BUTTON_SIZE), чтобы
	# «Вперёд» и «Назад» визуально были одной и той же кнопкой по размеру.
	var button_size: Vector2 = back_button.size
	var slot_size: Vector2 = _canvas_size(SLOT_SIZE)
	var card_size: Vector2 = _canvas_size(CARD_SIZE)
	var slot_gap: float = _canvas_value(SLOT_GAP)
	var grid_gap: float = _canvas_value(GRID_GAP)
	var grid_top_gap: float = _canvas_value(GRID_TOP_GAP)
	var content_width: float = panel_size.x - panel_padding * 2.0
	var body_width: float = content_width - button_size.x - _canvas_value(12.0)
	_prep_text.position = Vector2(panel_padding, panel_padding)
	_prep_text.size = Vector2(max(_canvas_value(180.0), body_width), header_height)
	_start_button.position = Vector2(panel_size.x - panel_padding - button_size.x, panel_padding)
	_start_button.size = button_size
	_required_label.position = Vector2(panel_padding, panel_padding + header_height + _canvas_value(4.0))
	_required_label.size = Vector2(content_width, required_height)
	# «Назад» — обычно отдельная плавающая кнопка над рамкой панели подготовки;
	# пока рамка открыта, переносим её внутрь, к левому краю, на ту же высоту,
	# что и «Вперёд» справа (panel_padding от верхнего края панели).
	back_button.position = _prep_panel.position + Vector2(panel_padding, panel_padding)

	var slot_row_width: float = slot_size.x * 4.0 + slot_gap * 3.0
	var cards_row_width: float = card_size.x * float(GRID_COLUMNS) + grid_gap * float(GRID_COLUMNS - 1)
	var square_block_height: float = slot_size.y + grid_top_gap + card_size.y * float(GRID_ROWS) + grid_gap * float(GRID_ROWS - 1)
	var text_bottom: float = panel_padding + header_height + required_height + _canvas_value(12.0)
	var slots_y: float = max(text_bottom, panel_size.y - square_block_height - panel_padding)
	var slot_start_x: float = float(floor((panel_size.x - slot_row_width) * 0.5))
	for hero_index in range(_slot_buttons.size()):
		var slot: Button = _slot_buttons[hero_index]
		var visual_index := 3 - hero_index
		slot.position = Vector2(slot_start_x + visual_index * (slot_size.x + slot_gap), slots_y)
		slot.size = slot_size

	var cards_start_x: float = float(floor((panel_size.x - cards_row_width) * 0.5))
	var cards_start_y: float = slots_y + slot_size.y + grid_top_gap
	for i in range(_god_buttons.size()):
		var card: Button = _god_buttons[i]
		var col: int = i % GRID_COLUMNS
		var row: int = int(i / GRID_COLUMNS)
		card.position = Vector2(cards_start_x + col * (card_size.x + grid_gap), cards_start_y + row * (card_size.y + grid_gap))
		card.size = card_size

func _make_square_button(is_slot: bool) -> Button:
	var button := Button.new()
	var button_size: Vector2 = _canvas_size(SLOT_SIZE if is_slot else CARD_SIZE)
	button.custom_minimum_size = button_size
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.toggle_mode = is_slot
	button.text = ""
	_apply_square_style(button)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = _canvas_value(10.0)
	icon.offset_top = _canvas_value(10.0)
	icon.offset_right = -_canvas_value(10.0)
	icon.offset_bottom = -_canvas_value(34.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var label := Label.new()
	label.name = "Name"
	label.anchor_left = 0.0
	label.anchor_top = 1.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = _canvas_value(8.0)
	label.offset_top = -_canvas_value(30.0)
	label.offset_right = -_canvas_value(8.0)
	label.offset_bottom = -_canvas_value(6.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", _canvas_font_size(12))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	return button
## Навy — та же палитра, что в остальном интерфейсе (кампания, подготовка к бою).
## Общий источник — Scripts/campaign_theme.gd (тот же campaign_screen.gd и battle_setup.gd).
const _PANEL_BG := CampaignTheme.PANEL_BG
const _BUTTON_BG := CampaignTheme.BUTTON_BG
const _BUTTON_BG_HOVER := CampaignTheme.BUTTON_BG_HOVER
const _BUTTON_BG_PRESSED := CampaignTheme.BUTTON_BG_PRESSED
const _BUTTON_BG_DISABLED := CampaignTheme.BUTTON_BG_DISABLED
const _ACCENT := CampaignTheme.ACCENT
const _ACCENT_DIM := CampaignTheme.ACCENT_DIM

func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.border_color = _ACCENT
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

func _apply_square_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _BUTTON_BG
	normal.border_color = _ACCENT_DIM
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate()
	hover.bg_color = _BUTTON_BG_HOVER
	hover.border_color = _ACCENT
	var pressed := normal.duplicate()
	pressed.bg_color = _BUTTON_BG_PRESSED
	pressed.border_color = _ACCENT
	var disabled := normal.duplicate()
	disabled.bg_color = _BUTTON_BG_DISABLED
	disabled.border_color = _ACCENT_DIM
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		if _selected_god_path != "":
			_place_god_in_slot(_selected_god_path, slot_index, -1)
		else:
			_selected_slot_index = slot_index
			var path: String = _selected_heroes[slot_index]
			if path != "":
				_begin_drag(path, slot_index)
		_update_prep_ui()
	elif _drag_path != "":
		_drop_drag_at_mouse()

func _on_god_gui_input(event: InputEvent, button_index: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var god_path: String = _god_button_paths[button_index]
	if god_path == "":
		return
	if event.pressed:
		if _selected_slot_index >= 0:
			_place_god_in_slot(god_path, _selected_slot_index, -1)
		else:
			_selected_god_path = god_path
			_begin_drag(god_path, -1)
		_update_prep_ui()
	elif _drag_path != "":
		_drop_drag_at_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if _selected_scene != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_mission_selection()
		get_viewport().set_input_as_handled()
		return
	if _drag_preview != null and event is InputEventMouseMotion:
		_drag_preview.global_position = get_global_mouse_position() - _drag_preview.size * 0.5
	if _drag_path != "" and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drop_drag_at_mouse()

func _begin_drag(god_path: String, source_slot: int) -> void:
	_drag_path = god_path
	_drag_source_slot = source_slot
	if _drag_preview != null:
		_drag_preview.queue_free()
	_drag_preview = TextureRect.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.custom_minimum_size = Vector2(120, 120)
	_drag_preview.size = Vector2(120, 120)
	_drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_preview.texture = _load_face_texture(god_path)
	_drag_preview.modulate.a = 0.75
	add_child(_drag_preview)
	_drag_preview.global_position = get_global_mouse_position() - _drag_preview.size * 0.5

func _drop_drag_at_mouse() -> void:
	var slot_index := _slot_at_mouse()
	if slot_index >= 0 and _drag_path != "":
		_place_god_in_slot(_drag_path, slot_index, _drag_source_slot)
	_clear_drag()
	_update_prep_ui()

func _slot_at_mouse() -> int:
	var pos := get_global_mouse_position()
	for i in range(_slot_buttons.size()):
		if _slot_buttons[i].get_global_rect().has_point(pos):
			return i
	return -1

func _clear_drag() -> void:
	_drag_path = ""
	_drag_source_slot = -1
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null

func _place_god_in_slot(god_path: String, target_slot: int, source_slot: int) -> void:
	if target_slot < 0 or target_slot >= _selected_heroes.size() or god_path == "":
		return
	var current_slot: int = _selected_heroes.find(god_path)
	var target_current: String = _selected_heroes[target_slot]
	if source_slot >= 0 and source_slot < _selected_heroes.size():
		_selected_heroes[source_slot] = target_current
		_selected_heroes[target_slot] = god_path
	elif current_slot >= 0 and current_slot != target_slot:
		_selected_heroes[current_slot] = target_current
		_selected_heroes[target_slot] = god_path
	else:
		_selected_heroes[target_slot] = god_path
	# Сбрасываем выбор слота после размещения — иначе следующий клик по любому
	# богу в ростере тут же перезаписывает только что заполненный слот.
	_selected_slot_index = -1
	_selected_god_path = ""
	_clear_drag()

func _cancel_mission_selection() -> void:
	_selected_scene = null
	_selected_heroes = ["", "", "", ""]
	_selected_slot_index = -1
	_selected_god_path = ""
	_clear_drag()
	if _prep_panel != null:
		_prep_panel.queue_free()
		_prep_panel = null
		_prep_root = null
		_reset_back_button_position()
	if _show_mission_list:
		title_label.text = "Выбор миссии"

func _start_selected_mission() -> void:
	if _selected_scene == null or not _can_start_mission():
		return
	CombatManager.reset_mission()
	CombatManager.mission_heroes = _selected_heroes.duplicate()
	CombatManager.mission_heroes_set = true
	CombatManager.selected_heroes = _selected_heroes.duplicate()
	if not MissionState.start_mission(mission, _selected_heroes):
		return
	get_tree().change_scene_to_file("res://Missions/mission_scene.tscn")

func _can_start_mission() -> bool:
	var has_hero := false
	for path in _selected_heroes:
		if str(path).strip_edges() != "":
			has_hero = true
			break
	if not has_hero:
		return false
	if _required_god_path != "" and not _selected_heroes.has(_required_god_path):
		return false
	return true

func _update_prep_ui() -> void:
	for i in range(_slot_buttons.size()):
		_update_slot_button(i)
	for i in range(_god_buttons.size()):
		var button: Button = _god_buttons[i]
		var path: String = _god_button_paths[i]
		if path == "":
			button.disabled = true
			_clear_character_button(button)
		else:
			button.disabled = _selected_heroes.has(path)
			_set_character_button(button, path)
	if _required_label != null:
		if _required_god_path != "":
			_required_label.text = "Нужен: %s" % _get_god_name(_required_god_path)
		else:
			_required_label.text = ""
	if _start_button != null:
		_start_button.disabled = not _can_start_mission()

func _update_slot_button(index: int) -> void:
	var button: Button = _slot_buttons[index]
	button.button_pressed = index == _selected_slot_index
	var path: String = _selected_heroes[index]
	if path == "":
		_clear_character_button(button)
		return
	_set_character_button(button, path)

func _set_character_button(button: Button, path: String) -> void:
	var icon := button.get_node("Icon") as TextureRect
	var label := button.get_node("Name") as Label
	icon.texture = _load_face_texture(path)
	label.text = _get_god_name(path)

func _clear_character_button(button: Button) -> void:
	var icon := button.get_node("Icon") as TextureRect
	var label := button.get_node("Name") as Label
	icon.texture = null
	label.text = ""

func _get_available_god_paths() -> Array[String]:
	var result: Array[String] = []
	for path in CampaignState.available_gods:
		var god_path := str(path)
		if god_path.strip_edges() == "":
			continue
		if CampaignState.is_god_dead(god_path):
			continue
		if not result.has(god_path):
			result.append(god_path)
	return result

func _get_god_name(path: String) -> String:
	var res := CampaignState.load_character_resource(path)
	if res != null and res.unit_name.strip_edges() != "":
		return res.unit_name
	return path.get_file().get_basename()

func _load_face_texture(path: String) -> Texture2D:
	var res := CampaignState.load_character_resource(path)
	if res != null and res.face_sprite.strip_edges() != "" and ResourceLoader.exists(res.face_sprite):
		return load(res.face_sprite) as Texture2D
	if res != null and res.sprite_path.strip_edges() != "" and ResourceLoader.exists(res.sprite_path):
		return load(res.sprite_path) as Texture2D
	return null

func _on_back_pressed() -> void:
	var return_path := MissionState.return_scene_path.strip_edges()
	if return_path == "":
		return_path = DEFAULT_RETURN_SCENE_PATH
	MissionState.requested_mission_path = ""
	get_tree().change_scene_to_file(return_path)
