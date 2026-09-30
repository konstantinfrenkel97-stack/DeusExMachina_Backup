extends RefCounted
class_name CampaignMap

## Карта храма: фон, кликабельные комнаты (маски/многоугольники), подсветка при наведении и обучения, нижняя панель.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

func _build_campaign_background() -> void:
	_screen._campaign_background_rect = TextureRect.new()
	_screen._campaign_background_rect.texture = load(CampaignScreen.CAMPAIGN_BACKGROUND_PATH) as Texture2D
	_screen._campaign_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen._campaign_background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_screen._campaign_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_background_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_screen.add_child(_screen._campaign_background_rect)
	_layout_campaign_map.call_deferred()

func _build_campaign_room_hit_layer() -> void:
	_screen._campaign_room_hit_layer = Control.new()
	_screen._campaign_room_hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_room_hit_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen._campaign_room_hit_layer.z_index = 20
	_screen.add_child(_screen._campaign_room_hit_layer)

	_screen._campaign_hover_fill = TextureRect.new()
	_screen._campaign_hover_fill.visible = false
	_screen._campaign_hover_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen._campaign_hover_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_screen._campaign_hover_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_room_hit_layer.add_child(_screen._campaign_hover_fill)

	_screen._campaign_hover_label_panel = PanelContainer.new()
	_screen._campaign_hover_label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_hover_label_panel.visible = false
	var hover_label_style := StyleBoxFlat.new()
	hover_label_style.bg_color = CampaignScreen.GOD_DETAIL_BG_COLOR
	hover_label_style.set_corner_radius_all(8)
	hover_label_style.content_margin_left = 16.0
	hover_label_style.content_margin_right = 16.0
	hover_label_style.content_margin_top = 6.0
	hover_label_style.content_margin_bottom = 6.0
	hover_label_style.border_width_left = 1
	hover_label_style.border_width_top = 1
	hover_label_style.border_width_right = 1
	hover_label_style.border_width_bottom = 1
	hover_label_style.border_color = CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR
	_screen._campaign_hover_label_panel.add_theme_stylebox_override("panel", hover_label_style)
	_screen._campaign_room_hit_layer.add_child(_screen._campaign_hover_label_panel)

	_screen._campaign_hover_label = Label.new()
	_screen._campaign_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._campaign_hover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen._campaign_hover_label.add_theme_font_size_override("font_size", 24)
	_screen._campaign_hover_label.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_COLOR)
	_screen._campaign_hover_label_panel.add_child(_screen._campaign_hover_label)
	_layout_campaign_map.call_deferred()

func _build_campaign_bottom_bar() -> void:
	_screen._campaign_bottom_bar = ColorRect.new()
	_screen._campaign_bottom_bar.color = Color.BLACK
	_screen._campaign_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_bottom_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen._campaign_bottom_bar.z_index = 30
	_screen.add_child(_screen._campaign_bottom_bar)

	# Круглая золотая кнопка "?" слева, сразу над чёрной областью снизу — позиция
	# считается в _layout_campaign_bottom_bar() (там уже есть top/viewport_size).
	_screen._help_button = HelpButtonFactory.create()
	_screen._help_button.name = "HelpButton"
	_screen._help_button.z_index = 40
	_screen._help_button.pressed.connect(func(): _screen.help.show_topics())
	_screen.add_child(_screen._help_button)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 10)
	_screen._campaign_bottom_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	_screen._roster._build_currency_bar(row)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var pages_box := HBoxContainer.new()
	pages_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pages_box.add_theme_constant_override("separation", 8)
	row.add_child(pages_box)

	var pages_title := Label.new()
	pages_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_title.text = "Страницы"
	pages_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pages_title.add_theme_font_size_override("font_size", 22)
	pages_box.add_child(pages_title)

	_screen._campaign_pages_label = Label.new()
	_screen._campaign_pages_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._campaign_pages_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen._campaign_pages_label.add_theme_font_size_override("font_size", 22)
	pages_box.add_child(_screen._campaign_pages_label)
	_screen._roster._refresh_pages()

func _layout_campaign_map() -> void:
	if _screen._campaign_background_rect == null or not is_instance_valid(_screen._campaign_background_rect):
		return
	var viewport_size: Vector2 = _screen.get_viewport().get_visible_rect().size
	var background_size: Vector2 = _get_campaign_background_display_size()
	var background_height: float = background_size.y
	var bottom_bar_top: float = _get_campaign_bottom_bar_top(viewport_size, background_height)
	_screen._campaign_background_rect.offset_left = 0.0
	_screen._campaign_background_rect.offset_top = 0.0
	_screen._campaign_background_rect.offset_right = 0.0
	_screen._campaign_background_rect.offset_bottom = background_height
	_layout_campaign_bottom_bar(viewport_size, bottom_bar_top)
	if _screen._campaign_room_hit_layer == null or not is_instance_valid(_screen._campaign_room_hit_layer):
		return
	_screen._campaign_room_hit_layer.offset_left = 0.0
	_screen._campaign_room_hit_layer.offset_top = 0.0
	_screen._campaign_room_hit_layer.offset_right = viewport_size.x
	_screen._campaign_room_hit_layer.offset_bottom = background_height
	if _screen._campaign_hover_fill != null and is_instance_valid(_screen._campaign_hover_fill):
		_screen._campaign_hover_fill.position = Vector2.ZERO
		_screen._campaign_hover_fill.size = Vector2(viewport_size.x, background_height)
	if _screen._tutorial_room_highlight != null and is_instance_valid(_screen._tutorial_room_highlight):
		_screen._tutorial_room_highlight.position = Vector2.ZERO
		_screen._tutorial_room_highlight.size = Vector2(viewport_size.x, background_height)
	_update_campaign_hover(_screen.get_viewport().get_mouse_position())

func _get_campaign_bottom_bar_top(viewport_size: Vector2, background_height: float) -> float:
	var natural_top: float = clampf(background_height, 0.0, viewport_size.y)
	if viewport_size.y - natural_top >= CampaignScreen.CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT:
		return natural_top
	return maxf(0.0, viewport_size.y - CampaignScreen.CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT)

func _layout_campaign_bottom_bar(viewport_size: Vector2, top: float) -> void:
	if _screen._campaign_bottom_bar == null or not is_instance_valid(_screen._campaign_bottom_bar):
		return
	_screen._campaign_bottom_bar.offset_left = 0.0
	_screen._campaign_bottom_bar.offset_top = top
	_screen._campaign_bottom_bar.offset_right = viewport_size.x
	_screen._campaign_bottom_bar.offset_bottom = viewport_size.y
	if _screen._help_button != null and is_instance_valid(_screen._help_button):
		_screen._help_button.position = Vector2(16.0, top - HelpButtonFactory.DIAMETER - 10.0)

func _campaign_room_input_is_blocked() -> bool:
	if _screen._active_tutorial_hints > 0:
		return true
	if _screen._creation_overlay != null and is_instance_valid(_screen._creation_overlay):
		return true
	if _screen._scales_overlay != null and is_instance_valid(_screen._scales_overlay):
		return true
	if _screen._library_overlay != null and is_instance_valid(_screen._library_overlay):
		return true
	if _screen._memory_well_overlay != null and is_instance_valid(_screen._memory_well_overlay):
		return true
	if _screen._god_overlay != null and is_instance_valid(_screen._god_overlay):
		return true
	if _screen._dialog_overlay != null and is_instance_valid(_screen._dialog_overlay):
		return true
	if _screen._menu_popup != null and is_instance_valid(_screen._menu_popup) and _screen._menu_popup.visible:
		return true
	return false

func _campaign_click_hits_real_button() -> bool:
	var hovered := _screen.get_viewport().gui_get_hovered_control()
	while hovered != null:
		if _screen._roster_grid != null and is_instance_valid(_screen._roster_grid) and (_screen._roster_grid == hovered or _screen._roster_grid.is_ancestor_of(hovered)):
			return true
		if _screen._myth_face_slot != null and is_instance_valid(_screen._myth_face_slot) and (_screen._myth_face_slot == hovered or _screen._myth_face_slot.is_ancestor_of(hovered)):
			return true
		if hovered is Button:
			if _screen._campaign_room_hit_layer != null and is_instance_valid(_screen._campaign_room_hit_layer) and _screen._campaign_room_hit_layer.is_ancestor_of(hovered):
				return false
			return true
		hovered = hovered.get_parent() as Control
	return false

func _campaign_section_at_position(position: Vector2) -> String:
	var room: Dictionary = _campaign_room_at_position(position)
	if room.is_empty():
		return ""
	return str(room["section"])

func _campaign_room_at_position(position: Vector2) -> Dictionary:
	var bg_size: Vector2 = _get_campaign_background_display_size()
	if position.x < 0.0 or position.y < 0.0 or position.x > bg_size.x or position.y > bg_size.y:
		return {}
	for room in CampaignRoomDefs.rooms():
		var polygon: PackedVector2Array = _campaign_room_polygon(room, bg_size)
		if not _campaign_point_in_polygon(position, polygon):
			continue
		var mask_path: String = str(room.get("mask", ""))
		if mask_path != "" and not _campaign_mask_contains_point(mask_path, position, bg_size):
			continue
		return {"section": str(room["section"]), "rect": _campaign_polygon_bounds(polygon), "polygon": polygon, "mask": mask_path}
	return {}

## Возвращает Image маски подсветки комнаты (с кэшированием — маска грузится
## и разжимается только один раз за сессию).
func _get_room_mask_image(mask_path: String) -> Image:
	if mask_path == "":
		return null
	if _screen._campaign_room_mask_images.has(mask_path):
		return _screen._campaign_room_mask_images[mask_path]
	var image: Image = null
	var texture := load(mask_path) as Texture2D
	if texture != null:
		image = texture.get_image()
		if image != null and image.is_compressed():
			image.decompress()
	_screen._campaign_room_mask_images[mask_path] = image
	return image

## Точная проверка: попадает ли точка не просто в грубый многоугольник комнаты,
## а именно в непрозрачный пиксель самой картинки-маски (Campaign_Hover_*.png).
## Так кликабельная/наводимая зона совпадает с тем, что реально подсвечивается
## белым на экране, а не с более широким контуром _campaign_room_polygon.
func _campaign_mask_contains_point(mask_path: String, position: Vector2, bg_size: Vector2) -> bool:
	var image := _get_room_mask_image(mask_path)
	if image == null or bg_size.x <= 0.0 or bg_size.y <= 0.0:
		return true
	var image_size := image.get_size()
	if image_size.x <= 0 or image_size.y <= 0:
		return true
	var px := clampi(int(position.x / bg_size.x * image_size.x), 0, image_size.x - 1)
	var py := clampi(int(position.y / bg_size.y * image_size.y), 0, image_size.y - 1)
	return image.get_pixel(px, py).a > 0.05

func _campaign_room_polygon(room: Dictionary, bg_size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var source_points: Array = room["points"]
	for source_point in source_points:
		var normalized_point: Vector2 = source_point
		points.append(Vector2(normalized_point.x * bg_size.x, normalized_point.y * bg_size.y))
	return points

func _campaign_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_pos: Vector2 = polygon[0]
	var max_pos: Vector2 = polygon[0]
	for point in polygon:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	return Rect2(min_pos, max_pos - min_pos)

func _campaign_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j: int = polygon.size() - 1
	for i in range(polygon.size()):
		var current: Vector2 = polygon[i]
		var previous: Vector2 = polygon[j]
		var crosses_y: bool = (current.y > point.y) != (previous.y > point.y)
		if crosses_y:
			var edge_x: float = (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
			if point.x < edge_x:
				inside = not inside
		j = i
	return inside

func _update_campaign_hover(position: Vector2) -> void:
	if _screen._campaign_room_hit_layer == null or not is_instance_valid(_screen._campaign_room_hit_layer):
		return
	if _screen._campaign_hover_fill == null or not is_instance_valid(_screen._campaign_hover_fill):
		return
	if _screen._campaign_hover_label_panel == null or not is_instance_valid(_screen._campaign_hover_label_panel):
		return
	if _campaign_room_input_is_blocked() or _campaign_click_hits_real_button():
		_clear_campaign_hover()
		return
	var room: Dictionary = _campaign_room_at_position(position)
	if room.is_empty():
		_clear_campaign_hover()
		return
	var section: String = str(room["section"])
	_screen._campaign_hover_section = section
	_screen._campaign_hover_fill.visible = true
	_screen._campaign_hover_fill.texture = load(str(room.get("mask", ""))) as Texture2D
	var room_rect: Rect2 = room.get("rect", Rect2())
	var bg_size: Vector2 = _get_campaign_background_display_size()
	_screen._campaign_hover_label.text = section
	# Ширина плашки — по фактической ширине текста (не по ширине зоны наведения,
	# та бывает у'же длинных названий вроде "Весы переосмысления" — раньше текст
	# из-за этого обрезался). Плашка также не должна вылезать за края экрана.
	var label_font := _screen._campaign_hover_label.get_theme_font("font")
	var label_font_size := _screen._campaign_hover_label.get_theme_font_size("font_size")
	var text_width: float = label_font.get_string_size(section, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size).x if label_font != null else 200.0
	var panel_width: float = minf(bg_size.x - 16.0, text_width + 32.0)
	var panel_height := 40.0
	_screen._campaign_hover_label_panel.size = Vector2(panel_width, panel_height)
	var panel_x: float = room_rect.position.x + room_rect.size.x * 0.5 - panel_width * 0.5
	panel_x = clampf(panel_x, 4.0, maxf(4.0, bg_size.x - panel_width - 4.0))
	var panel_y: float = maxf(0.0, room_rect.position.y - panel_height - 8.0)
	_screen._campaign_hover_label_panel.position = Vector2(panel_x, panel_y)
	_screen._campaign_hover_label_panel.visible = true

## Комната, единственно доступная сейчас в обучающей последовательности
## ("" = свободный режим, все комнаты доступны). Полностью выводится из уже
## существующего состояния — отдельного флага-стадии не требуется:
## opened_locations пусто И < REQUIRED_GODS_FOR_FIRST_BATTLE богов → только Сад творения;
## opened_locations пусто И богов достаточно → только Ворота (сначала чтобы дойти
## до First_battle, потом чтобы наткнуться на диалог "Миф не может открыть ворота");
## открыта хотя бы одна дверь → обучение полностью пройдено, свободный режим навсегда.
func _tutorial_locked_room_section() -> String:
	if not CampaignState.opened_locations.is_empty():
		return ""
	if CampaignState.available_gods.size() < CampaignScreen.REQUIRED_GODS_FOR_FIRST_BATTLE:
		return "Сад творения"
	return "Ворота"

## Как _tutorial_locked_room_section(), но для одной вещи — мигающей подсветки:
## как только показана подсказка "поговорите с богом", ворота перестают мигать
## (следующий шаг игрока — портрет бога в отряде, а не сама комната), хотя клик
## по воротам формально остаётся заблокирован (см. _tutorial_locked_room_section())
## до тех пор, пока дверь не откроет бог.
func _tutorial_highlighted_room_section() -> String:
	var section := _tutorial_locked_room_section()
	if section == "Ворота" and CampaignState.ask_a_god_hint_shown:
		return ""
	return section

func _room_mask_path(section: String) -> String:
	for room in CampaignRoomDefs.rooms():
		if str(room.get("section", "")) == section:
			return str(room.get("mask", ""))
	return ""

## Белый мигающий силуэт единственно доступной сейчас комнаты — та же техника
## маски по альфа-каналу, что и обычная подсветка при наведении курсора
## (_update_campaign_hover), но отдельный узел: висит постоянно (не только при
## наведении) и мигает по таймеру вместо реакции на мышь. Вызывается при любом
## изменении, которое может сдвинуть эту стадию (роcтер богов, открытие двери,
## изменение размера окна) — см. вызовы в _ready()/_refresh_roster()/
## _on_dialogue_choice_selected()/_layout_campaign_map().
func _update_tutorial_room_highlight() -> void:
	if _screen._tutorial_room_highlight_tween != null and _screen._tutorial_room_highlight_tween.is_valid():
		_screen._tutorial_room_highlight_tween.kill()
	_screen._tutorial_room_highlight_tween = null
	var section := _tutorial_highlighted_room_section()
	if section == "":
		if _screen._tutorial_room_highlight != null and is_instance_valid(_screen._tutorial_room_highlight):
			_screen._tutorial_room_highlight.visible = false
		return
	if _screen._campaign_room_hit_layer == null or not is_instance_valid(_screen._campaign_room_hit_layer):
		return
	var mask_path := _room_mask_path(section)
	if mask_path == "" or not ResourceLoader.exists(mask_path):
		return
	if _screen._tutorial_room_highlight == null or not is_instance_valid(_screen._tutorial_room_highlight):
		_screen._tutorial_room_highlight = TextureRect.new()
		_screen._tutorial_room_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_screen._tutorial_room_highlight.stretch_mode = TextureRect.STRETCH_SCALE
		_screen._tutorial_room_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen._campaign_room_hit_layer.add_child(_screen._tutorial_room_highlight)
		if _screen._campaign_hover_fill != null and is_instance_valid(_screen._campaign_hover_fill):
			_screen._tutorial_room_highlight.position = _screen._campaign_hover_fill.position
			_screen._tutorial_room_highlight.size = _screen._campaign_hover_fill.size
	_screen._tutorial_room_highlight.texture = load(mask_path) as Texture2D
	_screen._tutorial_room_highlight.visible = true
	_screen._tutorial_room_highlight.modulate = Color(1, 1, 1, 0.15)
	_screen._tutorial_room_highlight_tween = _screen.create_tween()
	_screen._tutorial_room_highlight_tween.set_loops()
	_screen._tutorial_room_highlight_tween.tween_property(_screen._tutorial_room_highlight, "modulate:a", 0.9, 1.0).set_trans(Tween.TRANS_SINE)
	_screen._tutorial_room_highlight_tween.tween_property(_screen._tutorial_room_highlight, "modulate:a", 0.15, 1.0).set_trans(Tween.TRANS_SINE)

func _clear_campaign_hover() -> void:
	_screen._campaign_hover_section = ""
	if _screen._campaign_hover_fill != null and is_instance_valid(_screen._campaign_hover_fill):
		_screen._campaign_hover_fill.visible = false
	if _screen._campaign_hover_label_panel != null and is_instance_valid(_screen._campaign_hover_label_panel):
		_screen._campaign_hover_label_panel.visible = false

func _get_campaign_background_display_size() -> Vector2:
	var viewport_size := _screen.get_viewport().get_visible_rect().size
	if _screen._campaign_background_rect == null or not is_instance_valid(_screen._campaign_background_rect):
		return viewport_size
	var texture := _screen._campaign_background_rect.texture
	if texture == null or texture.get_size().x <= 0.0:
		return viewport_size
	var tex_size := texture.get_size()
	return Vector2(viewport_size.x, viewport_size.x * tex_size.y / tex_size.x)
