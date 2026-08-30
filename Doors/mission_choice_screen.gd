extends Control
## Экран выбора миссии локации: открывается после клика по двери на экране «Ворота».
## Фон — картинка локации из Mission_choice_background.
##
## Области клика (кнопки запуска миссий) НЕ рисуются руками — они определяются
## автоматически по маске "Mission_choice_background - White/<фон>_white.png":
## дизайнер закрашивает белым те места на копии фона, где должна быть кнопка,
## скрипт при загрузке сцены находит белые пятна и ставит поверх них прозрачные
## кнопки нужного размера в нужном месте. Приветственная миссия локации
## (CampaignState.LOCATION_TO_WELCOME_MISSION) привязывается к трафарету, ближайшему
## к нижнему левому углу картинки (там обычно дверь входа) — см. _pick_welcome_region_index,
## там же особый случай для Замка (у него путь вьётся вверх, поэтому берётся самый
## нижний трафарет). Остальные трафареты пока не привязаны ни к одной миссии — клик
## по ним ничего не делает, пока миссия для них не будет создана.

const DOORS_SCENE := "res://Doors/doors.tscn"
const MISSION_SELECT_SCENE := "res://Missions/mission_select.tscn"
const WHITE_MASK_DIR := "res://Mission_choice_background - White/"

# Русское имя локации (как в Doors/doors.gd::LOCATIONS_CLOCKWISE) → фон выбора миссии.
const LOCATION_BACKGROUNDS := {
	"Хельхейм": "res://Mission_choice_background/Helheim_mission_choice_background.png",
	"Ад": "res://Mission_choice_background/hell_mission_choice_background.png",
	"Тоннели": "res://Mission_choice_background/Tunnels_mission_choice_background.png",
	"Облака": "res://Mission_choice_background/clouds_mission_choice_background.png",
	"Звезды": "res://Mission_choice_background/Stars_mission_choice_background.png",
	"Горы": "res://Mission_choice_background/Peaks_mission_choice_background.png",
	"Арена": "res://Mission_choice_background/Arena_mission_choice_background.png",
	"Замок": "res://Mission_choice_background/Castle_mission_choice_background.png",
	"Пустыня": "res://Mission_choice_background/Desert_mission_choice_background.png",
	"Глубина": "res://Mission_choice_background/Deep_mission_choice_background.png",
	"Острова": "res://Mission_choice_background/islands_mission_choice_background.png",
	"Корабли": "res://Mission_choice_background/Ships_mission_choice_background.png",
	"Джунгли": "res://Mission_choice_background/Jungle_mission_choice_background.png",
	"Сад": "res://Mission_choice_background/Garden_mission_choice_background.png",
	"Топь": "res://Mission_choice_background/Marsh_mission_choice_background.png",
}

# "Закрашено", если пиксель маски заметно отличается от того же пикселя исходного
# фона (а не "похож на белый по абсолютной яркости") — так стенсиль ловит закраску
# целиком, включая мягкие/полупрозрачные края кисти, и не зависит от того, каким
# именно цветом дизайнер красил. Порог — сумма разниц по r+g+b (каждый канал 0..1).
const DIFF_THRESHOLD := 0.20
# Грубый проход (поиск пятен целиком) — через шаг, ради скорости на всей картинке.
const COARSE_STEP := 4
const MIN_REGION_CELLS := 15
# Точный проход — по каждому пикселю, но только внутри bounding box уже найденного
# пятна (плюс небольшой запас), поэтому остаётся быстрым и при этом кликабельна
# ровно нарисованная фигура, без потери краёв из-за разреженной сетки.
const FINE_PADDING := COARSE_STEP * 2

var _bg_texture_rect: TextureRect = null


func _ready() -> void:
	_build_background()
	_build_back_button()
	call_deferred("_build_mission_click_regions")


func _build_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var bg := TextureRect.new()
	bg.name = "Background"
	var bg_path: String = str(LOCATION_BACKGROUNDS.get(MissionState.pending_location, ""))
	if bg_path != "" and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path) as Texture2D
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Показываем изображение целиком, без обрезки (некоторые фоны почти квадратные,
	# а не 16:9 — при STRETCH_KEEP_ASPECT_COVERED у них обрезался бы верх/низ).
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_bg_texture_rect = bg


func _build_back_button() -> void:
	var back := Button.new()
	back.text = "← Назад"
	back.custom_minimum_size = Vector2(170, 56)
	var vp := get_viewport().get_visible_rect().size
	back.position = Vector2(24, vp.y - 80)
	back.add_theme_font_size_override("font_size", 20)
	back.z_index = 100
	back.pressed.connect(_go_back)
	add_child(back)


## Строит прозрачные кнопки поверх белых пятен маски (см. комментарий вверху файла).
## Кликабельна именно форма пятна (через BitMap), а не его прямоугольник — иначе
## клик рядом с нарисованной фигурой, но всё ещё внутри её bounding box, тоже
## засчитывался бы.
func _build_mission_click_regions() -> void:
	if _bg_texture_rect == null or _bg_texture_rect.texture == null:
		return
	var mask_path := _white_mask_path_for(MissionState.pending_location)
	if mask_path == "" or not ResourceLoader.exists(mask_path):
		return
	var mask_image := _load_pixel_image(mask_path)
	if mask_image == null:
		return
	var orig_path: String = str(LOCATION_BACKGROUNDS.get(MissionState.pending_location, ""))
	var orig_image := _load_pixel_image(orig_path)
	if orig_image == null:
		return
	if mask_image.get_width() != orig_image.get_width() or mask_image.get_height() != orig_image.get_height():
		push_warning("Маска и исходный фон разного размера — клик-области не построены: " + mask_path)
		return
	var regions := _detect_painted_regions(mask_image, orig_image)
	if regions.is_empty():
		return
	var tex_size: Vector2 = _bg_texture_rect.texture.get_size()
	var control_size: Vector2 = _bg_texture_rect.size
	var welcome_mission_path: String = str(CampaignState.LOCATION_TO_WELCOME_MISSION.get(MissionState.pending_location, ""))
	var welcome_index := _pick_welcome_region_index(regions, tex_size.y, MissionState.pending_location)
	for i in range(regions.size()):
		var region: Dictionary = regions[i]
		var img_rect: Rect2 = region["rect"]
		var screen_rect := _image_rect_to_screen_rect(img_rect, tex_size, control_size)
		var mission_path := welcome_mission_path if i == welcome_index else ""
		_add_click_region_button(screen_rect, region["bitmap"], mission_path)


## Выбирает, к какому трафарету привязать приветственную миссию локации.
## Правило по умолчанию — ближайший к нижнему левому углу картинки (там, где
## обычно дверь входа); для Замка отдельно — самый нижний трафарет (его путь
## вьётся вверх, а не идёт по диагонали от угла).
func _pick_welcome_region_index(regions: Array, image_height: float, location: String) -> int:
	if regions.is_empty():
		return -1
	if location == "Замок":
		var best_bottom := -1
		var best_bottom_y := -INF
		for i in range(regions.size()):
			var rect: Rect2 = regions[i]["rect"]
			var bottom_y: float = rect.position.y + rect.size.y
			if bottom_y > best_bottom_y:
				best_bottom_y = bottom_y
				best_bottom = i
		return best_bottom
	var best_corner := 0
	var best_dist := INF
	for i in range(regions.size()):
		var rect: Rect2 = regions[i]["rect"]
		var center: Vector2 = rect.position + rect.size * 0.5
		var dist: float = center.distance_to(Vector2(0.0, image_height))
		if dist < best_dist:
			best_dist = dist
			best_corner = i
	return best_corner


func _white_mask_path_for(location: String) -> String:
	var bg_path: String = str(LOCATION_BACKGROUNDS.get(location, ""))
	if bg_path == "":
		return ""
	return WHITE_MASK_DIR + bg_path.get_file().get_basename() + "_white.png"


## Загружает картинку как Image с прямым доступом к пикселям (декомпрессирует при необходимости).
func _load_pixel_image(path: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	return img


func _add_click_region_button(screen_rect: Rect2, mask: BitMap, mission_path: String) -> void:
	var btn := Button.new()
	btn.set_script(load("res://Doors/mask_click_button.gd"))
	btn.set("mask", mask)
	btn.flat = true
	btn.position = screen_rect.position
	btn.size = screen_rect.size
	btn.z_index = 50
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	if mission_path != "":
		btn.pressed.connect(_on_mission_region_pressed.bind(mission_path))
	else:
		btn.pressed.connect(_on_empty_region_pressed)
	add_child(btn)


func _on_mission_region_pressed(mission_path: String) -> void:
	if mission_path == "" or not ResourceLoader.exists(mission_path):
		push_warning("Не найдена миссия: " + mission_path)
		return
	MissionState.requested_mission_path = mission_path
	MissionState.return_scene_path = "res://Doors/mission_choice_screen.tscn"
	get_tree().change_scene_to_file(MISSION_SELECT_SCENE)


func _on_empty_region_pressed() -> void:
	print("Миссия для этой области ещё не создана.")


## Переводит прямоугольник в пиксельных координатах ИСХОДНОЙ картинки в координаты
## экрана — с учётом масштаба и отступов от STRETCH_KEEP_ASPECT_CENTERED.
func _image_rect_to_screen_rect(img_rect: Rect2, tex_size: Vector2, control_size: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2()
	var scale: float = min(control_size.x / tex_size.x, control_size.y / tex_size.y)
	var displayed_size: Vector2 = tex_size * scale
	var offset: Vector2 = (control_size - displayed_size) * 0.5
	return Rect2(offset + img_rect.position * scale, img_rect.size * scale)


## Находит закрашенные пятна: сначала грубо (по разреженной сетке, на всей картинке —
## только чтобы понять, где вообще есть пятна и какого они примерно размера), затем
## для каждого найденного пятна — точно, по каждому пикселю в его bounding box'е
## (с запасом), чтобы итоговая маска клика повторяла нарисованную фигуру, а не
## обрубала её края разреженной сеткой.
func _detect_painted_regions(mask_image: Image, orig_image: Image) -> Array:
	var w := mask_image.get_width()
	var h := mask_image.get_height()
	var coarse_boxes := _coarse_find_blobs(mask_image, orig_image, w, h)
	var regions: Array = []
	for bbox in coarse_boxes:
		var rx0: int = maxi(bbox.position.x - FINE_PADDING, 0)
		var ry0: int = maxi(bbox.position.y - FINE_PADDING, 0)
		var rx1: int = mini(bbox.position.x + bbox.size.x + FINE_PADDING, w)
		var ry1: int = mini(bbox.position.y + bbox.size.y + FINE_PADDING, h)
		var local_w := rx1 - rx0
		var local_h := ry1 - ry0
		if local_w <= 0 or local_h <= 0:
			continue
		var bitmap := BitMap.new()
		bitmap.create(Vector2i(local_w, local_h))
		var any_bit := false
		for y in range(ry0, ry1):
			for x in range(rx0, rx1):
				if _is_painted_pixel(mask_image, orig_image, x, y):
					bitmap.set_bit(x - rx0, y - ry0, true)
					any_bit = true
		if any_bit:
			regions.append({"rect": Rect2(rx0, ry0, local_w, local_h), "bitmap": bitmap})
	regions.sort_custom(func(a, b): return a["rect"].position.x < b["rect"].position.x)
	return regions


## Грубый проход по разреженной сетке (шаг COARSE_STEP) — только находит примерные
## bounding box'ы пятен через BFS; точная форма строится потом отдельно, см. выше.
func _coarse_find_blobs(mask_image: Image, orig_image: Image, w: int, h: int) -> Array:
	var cols := int(ceil(float(w) / COARSE_STEP))
	var rows := int(ceil(float(h) / COARSE_STEP))
	if cols <= 0 or rows <= 0:
		return []
	var visited: Array = []
	visited.resize(rows)
	for r in range(rows):
		var row: Array = []
		row.resize(cols)
		row.fill(false)
		visited[r] = row

	var is_painted_cell := func(gx: int, gy: int) -> bool:
		var px: int = mini(gx * COARSE_STEP, w - 1)
		var py: int = mini(gy * COARSE_STEP, h - 1)
		return _is_painted_pixel(mask_image, orig_image, px, py)

	var boxes: Array = []
	for gy in range(rows):
		for gx in range(cols):
			if visited[gy][gx]:
				continue
			if not is_painted_cell.call(gx, gy):
				visited[gy][gx] = true
				continue
			var queue: Array = [[gx, gy]]
			visited[gy][gx] = true
			var count := 0
			var min_gx := gx
			var max_gx := gx
			var min_gy := gy
			var max_gy := gy
			while not queue.is_empty():
				var cell: Array = queue.pop_front()
				var cx: int = cell[0]
				var cy: int = cell[1]
				count += 1
				min_gx = mini(min_gx, cx)
				max_gx = maxi(max_gx, cx)
				min_gy = mini(min_gy, cy)
				max_gy = maxi(max_gy, cy)
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = cx + d[0]
					var ny: int = cy + d[1]
					if nx >= 0 and nx < cols and ny >= 0 and ny < rows and not visited[ny][nx]:
						if is_painted_cell.call(nx, ny):
							visited[ny][nx] = true
							queue.append([nx, ny])
						else:
							visited[ny][nx] = true
			if count >= MIN_REGION_CELLS:
				var rx0 := min_gx * COARSE_STEP
				var ry0 := min_gy * COARSE_STEP
				var rx1 := mini((max_gx + 1) * COARSE_STEP, w)
				var ry1 := mini((max_gy + 1) * COARSE_STEP, h)
				boxes.append(Rect2i(rx0, ry0, rx1 - rx0, ry1 - ry0))
	return boxes


func _is_painted_pixel(mask_image: Image, orig_image: Image, x: int, y: int) -> bool:
	var mc := mask_image.get_pixel(x, y)
	var oc := orig_image.get_pixel(x, y)
	var diff: float = absf(mc.r - oc.r) + absf(mc.g - oc.g) + absf(mc.b - oc.b)
	return diff > DIFF_THRESHOLD


func _go_back() -> void:
	MissionState.pending_location = ""
	get_tree().change_scene_to_file(DOORS_SCENE)


## Правый клик = назад (тот же жест, что и на экране «Ворота»).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_go_back()
		get_viewport().set_input_as_handled()
