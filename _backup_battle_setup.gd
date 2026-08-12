extends Control

const GODS_DIR = "res://Gods/"
const ENEMIES_DIR = "res://Enemies/"

@onready var character_menu = $CharacterMenu
@onready var hero_buttons = [
	$VBoxContainer/HeroRow/HeroPos1,
	$VBoxContainer/HeroRow/HeroPos2,
	$VBoxContainer/HeroRow/HeroPos3,
	$VBoxContainer/HeroRow/HeroPos4
]
@onready var enemy_buttons = [
	$VBoxContainer/EnemyRow/EnemyPos1,
	$VBoxContainer/EnemyRow/EnemyPos2,
	$VBoxContainer/EnemyRow/EnemyPos3,
	$VBoxContainer/EnemyRow/EnemyPos4
]
@onready var location_button = $VBoxContainer/LocationButton

var available_heroes: Array[String] = []
var available_enemies: Array[String] = []

# Кэш имён ресурсов: path → unit_name (избегает повторных load())
var _resource_name_cache: Dictionary = {}

var current_clicking_is_enemy: bool = false
var current_clicking_index: int = 0

# Формат: [display_name, category, description, location_id, background_path, fog_background_path]
# background_path и fog_background_path — пути к картинкам фона (пусто = нет фона)
const LOCATIONS = [
	# ─── Подземелье ───
	[
		"Хельхейм", "Подземелье",
		"30% шанс туманного раунда: герои получают -20 к урону на 1 раунд",
		"helheim", "res://Background/Helheim.png", "res://Background/Helheim_fog.png"
	],
	[
		"Тартар", "Подземелье",
		"Боги теряют 5 величия, игрок теряет 5 маны каждый раунд",
		"tartar", "res://Background/Tartar.png", ""
	],
	[
		"Тоннели", "Подземелье",
		"Если текущая броня выше 50%, регенерация 7% на 1 ход",
		"tunnels", "res://Background/Tunnels.png", ""
	],
	# ─── Небо ───
	[
		"Облака", "Небо",
		"После попадания по врагу (не богу): +10 уклонения на 1 ход (складывается)",
		"clouds", "res://Background/Clouds.png", ""
	],
	[
		"Звёзды", "Небо",
		"Враги получают бонусы по позициям: броня / реген / удача / урон",
		"stars", "res://Background/Stars.png", ""
	],
	[
		"Горы", "Небо",
		"Тут не место для малышни",
		"mountains", "res://Background/Mountatins.png", ""
	],
	# ─── Цивилизация ───
	[
		"Арена", "Цивилизация",
		"Все юниты (союзники и враги) наносят +20% урона",
		"arena", "res://Background/Arena.png", ""
	],
	[
		"Замок", "Цивилизация",
		"Заклинания стоят x1.5 маны, но можно применить 2 за ход",
		"castle", "res://Background/Castle.png", ""
	],
	[
		"Пустыня", "Цивилизация",
		"Все (союзники и враги) получают 10 чистого урона в начале раунда",
		"desert", "res://Background/Desert.png", ""
	],
	# ─── Море ───
	[
		"Глубина", "Море",
		"Нечётный: урон при смене позиции. Чётный: восстановление HP",
		"depths", "", ""
	],
	[
		"Остров", "Море",
		"Герои теряют -1 инициативу каждый раунд (до 0)",
		"island", "", ""
	],
	[
		"Корабли", "Море",
		"Уникальное заклинание «Ром»: -20 точности, +20 удачи",
		"ships", "res://Background/Ships.png", ""
	],
	# ─── Лес ───
	[
		"Джунгли", "Лес",
		"Критический урон x3 вместо x2",
		"jungle", "", ""
	],
	[
		"Сад", "Лес",
		"При наложении дебаффа на союзника: +15 чистого урона",
		"garden", "", ""
	],
	[
		"Топь", "Лес",
		"Бог на первой позиции теряет инициативу и броню (суммируется)",
		"swamp", "", ""
	],
	# ─── Прочее ───
	[
		"Дом", "Прочее",
		"Без эффектов",
		"home", "", ""
	],
	[
		"Книга", "Прочее",
		"Без эффектов",
		"book", "", ""
	],
]
var current_location_index: int = 0

func _ready():
	CombatManager.clear_selection()
	
	_scan_directory_for_resources(GODS_DIR, available_heroes)
	_scan_directory_for_resources(ENEMIES_DIR, available_enemies)
	
	for i in range(4):
		hero_buttons[i].pressed.connect(_on_position_clicked.bind(false, i))
		enemy_buttons[i].pressed.connect(_on_position_clicked.bind(true, i))
	character_menu.id_pressed.connect(_on_character_selected)
	
	# Кнопка выбора локации
	if location_button:
		location_button.pressed.connect(_on_location_button_pressed)
		# Локация по умолчанию — «Дом» (без эффектов)
		var home_idx = 0
		for i in range(LOCATIONS.size()):
			if LOCATIONS[i][3] == "home":
				home_idx = i
				break
		var default_loc = LOCATIONS[home_idx]
		location_button.text = "Локация: %s (%s)" % [default_loc[0], default_loc[1]]
		CombatManager.selected_location_name = default_loc[0]
		CombatManager.selected_location_description = default_loc[2]
		CombatManager.selected_location_id = default_loc[3]
		CombatManager.selected_location_category = default_loc[1]
		CombatManager.selected_background = default_loc[4]
		CombatManager.selected_fog_background = default_loc[5]
	
	$VBoxContainer/StartBattleButton.pressed.connect(_on_start_battle_pressed)
	_update_button_texts()
	_update_start_button()

# ─── Выбор локации ───────────────────────────────────────────

func _on_location_button_pressed():
	var menu = PopupMenu.new()
	add_child(menu)
	
	# Пункт «Случайная локация» (id = -1)
	menu.add_item("🎲 Случайная локация", -1)
	menu.add_separator()
	
	# Подменю по категориям
	var categories_order = ["Подземелье", "Небо", "Цивилизация", "Море", "Лес", "Прочее"]
	var submenus = {}
	for cat in categories_order:
		var sub = PopupMenu.new()
		sub.name = cat
		menu.add_child(sub)
		submenus[cat] = sub
		menu.add_submenu_item(cat, cat)
	
	# Заполняем подменю локациями
	for i in range(LOCATIONS.size()):
		var loc = LOCATIONS[i]
		var sub = submenus.get(loc[1])
		if sub:
			sub.add_item("%s — %s" % [loc[0], loc[2]], i)
	
	# Обработчик «Случайная локация»
	menu.id_pressed.connect(func(id):
		if id == -1:
			# Выбираем случайную локацию
			var rand_idx = randi() % LOCATIONS.size()
			current_location_index = rand_idx
			var loc = LOCATIONS[rand_idx]
			location_button.text = "Локация: %s (%s)" % [loc[0], loc[1]]
			CombatManager.selected_background = loc[4]
			CombatManager.selected_location_name = loc[0]
			CombatManager.selected_location_description = loc[2]
			CombatManager.selected_location_id = loc[3]
			CombatManager.selected_location_category = loc[1]
			CombatManager.selected_fog_background = loc[5]
			menu.queue_free()
			return
	)
	
	# Подключаем обработчик выбора для каждого подменю
	for cat in categories_order:
		submenus[cat].id_pressed.connect(func(id):
			current_location_index = id
			var loc = LOCATIONS[id]
			location_button.text = "Локация: %s (%s)" % [loc[0], loc[1]]
			CombatManager.selected_background = loc[4]
			CombatManager.selected_location_name = loc[0]
			CombatManager.selected_location_description = loc[2]
			CombatManager.selected_location_id = loc[3]
			CombatManager.selected_location_category = loc[1]
			CombatManager.selected_fog_background = loc[5]
			menu.queue_free()
		)
	
	menu.position = get_viewport().get_mouse_position()
	menu.popup()

# ─── Сканирование ресурсов ───────────────────────────────────

func _scan_directory_for_resources(path: String, array_to_fill: Array[String]):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_scan_directory_for_resources(path + file_name + "/", array_to_fill)
			else:
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
					var clean_path = path + file_name.replace(".remap", "")
					var res = load(clean_path)
					if res is CharacterResource:
						array_to_fill.append(clean_path)
						# Кэшируем имя сразу при сканировании
						_resource_name_cache[clean_path] = res.unit_name
			file_name = dir.get_next()

# ─── Выбор персонажей ────────────────────────────────────────

func _on_position_clicked(is_enemy: bool, index: int):
	var selected_array = CombatManager.selected_enemies if is_enemy else CombatManager.selected_heroes
	# Проверяем, заблокирована ли позиция большим юнитом на позиции index - 1
	if index > 0 and selected_array[index - 1] != "":
		var prev_res = load(selected_array[index - 1]) as CharacterResource
		if prev_res and prev_res.is_large:
			return  # Позиция заблокирована — не открываем меню
	
	current_clicking_is_enemy = is_enemy
	current_clicking_index = index
	character_menu.clear()
	character_menu.add_item("[ Очистить слот ]", 0)
	var list = available_enemies if is_enemy else available_heroes
	for i in range(list.size()):
		var name = _get_name_from_resource(list[i], "???")
		character_menu.add_item(name, i + 1)
	character_menu.position = get_viewport().get_mouse_position()
	character_menu.popup()

func _on_character_selected(id: int):
	var list = available_enemies if current_clicking_is_enemy else available_heroes
	var selected_path = ""
	if id > 0:
		selected_path = list[id - 1]
	var selected_array = CombatManager.selected_enemies if current_clicking_is_enemy else CombatManager.selected_heroes
	
	# Если на текущей позиции был большой юнит — разблокируем позицию за ним
	var old_path = selected_array[current_clicking_index]
	if old_path != "":
		var old_res = load(old_path) as CharacterResource
		if old_res and old_res.is_large and current_clicking_index + 1 < 4:
			if selected_array[current_clicking_index + 1] == "":
				# Освобождаем заблокированную позицию (только если она пустая)
				pass  # Она уже пустая, ничего делать не надо
	
	selected_array[current_clicking_index] = selected_path
	
	# Если выбрали большого юнита — автоматически очищаем и блокируем позицию за ним
	if selected_path != "":
		var res = load(selected_path) as CharacterResource
		if res and res.is_large and current_clicking_index + 1 < 4:
			selected_array[current_clicking_index + 1] = ""  # Блокируем: очищаем слот за большим
	
	_update_button_texts()

func _update_button_texts():
	for i in range(4):
		# Проверяем, заблокирована ли позиция большим юнитом
		var hero_blocked = false
		var enemy_blocked = false
		if i > 0 and CombatManager.selected_heroes[i - 1] != "":
			var prev_res = load(CombatManager.selected_heroes[i - 1]) as CharacterResource
			if prev_res and prev_res.is_large:
				hero_blocked = true
		if i > 0 and CombatManager.selected_enemies[i - 1] != "":
			var prev_res = load(CombatManager.selected_enemies[i - 1]) as CharacterResource
			if prev_res and prev_res.is_large:
				enemy_blocked = true
		
		if hero_blocked:
			hero_buttons[i].text = "🔒 Занято (большой)"
			hero_buttons[i].disabled = true
		else:
			hero_buttons[i].text = _get_name_from_resource(CombatManager.selected_heroes[i], "Пустой Поз " + str(i+1))
			hero_buttons[i].disabled = false
		
		if enemy_blocked:
			enemy_buttons[i].text = "🔒 Занято (большой)"
			enemy_buttons[i].disabled = true
		else:
			enemy_buttons[i].text = _get_name_from_resource(CombatManager.selected_enemies[i], "Пустой Поз " + str(i+1))
			enemy_buttons[i].disabled = false
	_update_start_button()

## Обновляет состояние кнопки «В Бой» — неактивна без ≥1 бога и ≥1 врага.
func _update_start_button():
	var btn = $VBoxContainer/StartBattleButton
	if btn == null:
		return
	var has_hero = false
	var has_enemy = false
	for path in CombatManager.selected_heroes:
		if path != "":
			has_hero = true
			break
	for path in CombatManager.selected_enemies:
		if path != "":
			has_enemy = true
			break
	btn.disabled = not (has_hero and has_enemy)

func _get_name_from_resource(path: String, default: String) -> String:
	if path == "": return default
	# Сначала проверяем кэш — избегаем лишних load()
	if _resource_name_cache.has(path):
		return _resource_name_cache[path]
	var res = load(path) as CharacterResource
	if res:
		_resource_name_cache[path] = res.unit_name
		return res.unit_name
	return default

# ─── Запуск боя ──────────────────────────────────────────────

func _on_start_battle_pressed():
	get_tree().change_scene_to_file("res://battle_scene.tscn")
