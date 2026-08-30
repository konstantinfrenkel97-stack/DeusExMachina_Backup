extends Node
## Автозагружаемый синглтон (CampaignState).
## Хранит глобальное состояние кампании: доступных богов,
## сокровищницу (артефакты) и доступные миссии.
##
## Все массивы — пути к .tres файлам, чтобы любой экран мог загрузить
## ресурс по необходимости. Содержимое меняется по ходу игры
## (открытие новых богов, получение трофеев, разблокировка миссий).

# ════════════════════════════════════════════════════════════
#  Ростер кампании
# ════════════════════════════════════════════════════════════

## Доступные боги (пути к CharacterResource .tres).
## Сигнал: состав ростера изменился (добавлен/удалён бог).
## Экран кампании слушает его и автоматически обновляет сетку портретов.
signal roster_changed

var available_gods: Array[String] = []

## Сокровищница — собранные артефакты (пути к ItemResource .tres).
var treasury: Array[String] = []

## Доступные миссии (пути к MissionResource .tres).
var available_missions: Array[String] = []
## Пройденные миссии (пути к MissionResource .tres). Повторное прохождение
## награду за завершение миссии не даёт — см. complete_mission().
var completed_missions: Array[String] = []
var pages: int = 0

## Сюжетные флаги вступления. Одноразовые, без отката назад.
var before_first_battle_played: bool = false
var first_battle_completed: bool = false
var before_doors_played: bool = false

## Локации, чью дверь уже открыл соответствующий бог (выбор "Открыть дверь" в его
## диалоге). Хранится как отображаемое имя локации — то же, что в
## Doors/doors.gd::LOCATIONS_CLOCKWISE / LOCATION_DOORS.
var opened_locations: Array[String] = []

## Папка бога (Gods/<Folder>/...) → локация, которую он открывает.
const GOD_FOLDER_TO_LOCATION := {
	"Loki": "Хельхейм",
	"Hades": "Ад",
	"Thor": "Тоннели",
	"Chernobog": "Облака",
	"Odin": "Звезды",
	"Zeus": "Горы",
	"Koschei": "Топь",
	"Duna": "Сад",
	"Shiva": "Джунгли",
	"Osiris": "Пустыня",
	"Set": "Арена",
	"Morgan": "Замок",
	"Samdi": "Корабли",
	"Poseidon": "Глубина",
	"Susanoo": "Острова",
}

## Локация → путь к её миссии "Welcome_to_<локация>". Локации без записи здесь
## ещё не имеют авторизованной миссии — дверь всё равно откроется, но входа
## пока не будет (см. Doors/doors.gd::_on_location_selected).
const LOCATION_TO_WELCOME_MISSION := {
	"Хельхейм": "res://Missions/Helheim/welcome_to_helheim_mission.tres",
	"Ад": "res://Missions/Hell/welcome_to_hell.tres",
	"Тоннели": "res://Missions/Tunnels/welcome_to_tunnels.tres",
	"Облака": "res://Missions/Clouds/welcome_to_clouds.tres",
	"Острова": "res://Missions/Islands/welcome_to_islands.tres",
	"Звезды": "res://Missions/Stars/welcome_to_stars.tres",
	"Пустыня": "res://Missions/Desert/welcome_to_desert.tres",
	"Арена": "res://Missions/Arena/welcome_to_arena.tres",
	"Замок": "res://Missions/Castle/welcome_to_castle.tres",
	"Корабли": "res://Missions/Ships/welcome_to_ships.tres",
	"Горы": "res://Missions/Peaks/welcome_to_mountains.tres",
	"Топь": "res://Missions/Marsh/welcome_to_swamp.tres",
	"Сад": "res://Missions/Garden/welcome_to_garden.tres",
	"Глубина": "res://Missions/Depth/welcome_to_depths.tres",
	"Джунгли": "res://Missions/Jungle/welcome_to_jungle.tres",
}

func open_location(location: String) -> void:
	var clean := location.strip_edges()
	if clean != "" and not opened_locations.has(clean):
		opened_locations.append(clean)

func is_location_opened(location: String) -> bool:
	return opened_locations.has(location.strip_edges())

const MIN_GOD_LEVEL := 1
const MAX_GOD_LEVEL := 6
const ULTIMATE_UPGRADE_LEVEL := 6

const CURRENCY_RESOURCE_PATHS: Array[String] = [
	"res://Essence/essence_power.tres",
	"res://Essence/essence_death.tres",
	"res://Essence/essence_nature.tres",
	"res://Essence/essence_chaos.tres",
	"res://Essence/essence_strength.tres",
	"res://Essence/thoughts.tres",
]

# ════════════════════════════════════════════════════════════
#  Бесконечная библиотека
# ════════════════════════════════════════════════════════════

const THOUGHTS_PATH := "res://Essence/thoughts.tres"

## "Читать книги" — постоянный бонус к максимальной фантазии (не сбрасывается
## между боями, копится на всю игру; можно покупать многократно).
var library_max_fantasy_bonus: int = 0
const LIBRARY_READ_COST := 1000
const LIBRARY_READ_FANTASY_BONUS := 5

## "Осмыслять сюжет" — уровень улучшения заклинания (путь к SpellResource -> сколько
## раз улучшено). 2 уровня: 1-й — 700 мыслей, 2-й — 1500 мыслей + 1 эссенция (любая).
var spell_upgrade_levels: Dictionary = {}
const SPELL_UPGRADE_LEVEL_1_COST := 700
const SPELL_UPGRADE_LEVEL_2_COST := 1500
const MAX_SPELL_UPGRADE_LEVEL := 2
const SPELL_UPGRADE_ESSENCE_PATHS := [
	"res://Essence/essence_strength.tres",
	"res://Essence/essence_nature.tres",
	"res://Essence/essence_power.tres",
	"res://Essence/essence_chaos.tres",
	"res://Essence/essence_death.tres",
]

## Покупает том книг: -1000 мыслей, +5 к максимальной фантазии до конца игры.
func read_library_books() -> bool:
	if not spend_currency_amounts({THOUGHTS_PATH: LIBRARY_READ_COST}):
		return false
	library_max_fantasy_bonus += LIBRARY_READ_FANTASY_BONUS
	return true

func get_spell_upgrade_level(spell_path: String) -> int:
	return int(spell_upgrade_levels.get(spell_path, 0))

func can_upgrade_spell(spell_path: String) -> bool:
	return get_spell_upgrade_level(spell_path) < MAX_SPELL_UPGRADE_LEVEL

## Первая эссенция (любого типа), которой у игрока есть хотя бы 1 штука. "" если нет ни одной.
func _pick_available_essence_path() -> String:
	for path in SPELL_UPGRADE_ESSENCE_PATHS:
		if get_currency_amount(path) >= 1:
			return path
	return ""

## Стоимость СЛЕДУЮЩЕГО уровня улучшения: {"thoughts": int, "essence_path": String}.
## essence_path == "" — эссенция не нужна (1-й уровень) или её вообще нет в наличии (2-й).
func get_spell_upgrade_next_cost(spell_path: String) -> Dictionary:
	var next_level := get_spell_upgrade_level(spell_path) + 1
	if next_level == 1:
		return {"thoughts": SPELL_UPGRADE_LEVEL_1_COST, "essence_path": ""}
	return {"thoughts": SPELL_UPGRADE_LEVEL_2_COST, "essence_path": _pick_available_essence_path()}

## Улучшает заклинание на 1 уровень. Возвращает false, если уже на максимуме или не
## хватает ресурсов (мыслей и/или эссенции) — тогда ничего не списывается.
func upgrade_spell(spell_path: String) -> bool:
	if spell_path.strip_edges() == "" or not can_upgrade_spell(spell_path):
		return false
	var next_level := get_spell_upgrade_level(spell_path) + 1
	var costs: Dictionary = {THOUGHTS_PATH: SPELL_UPGRADE_LEVEL_1_COST if next_level == 1 else SPELL_UPGRADE_LEVEL_2_COST}
	if next_level == 2:
		var essence_path := _pick_available_essence_path()
		if essence_path == "":
			return false
		costs[essence_path] = 1
	if not spend_currency_amounts(costs):
		return false
	spell_upgrade_levels[spell_path] = next_level
	return true

var _god_state_overrides: Dictionary = {}
var _default_currency_amounts: Dictionary = {}
var _currency_amounts: Dictionary = {}

func _ready() -> void:
	_capture_default_currency_amounts()
	reset_currency_amounts()

# ════════════════════════════════════════════════════════════
#  API для управления ростером
# ════════════════════════════════════════════════════════════

## Добавить бога в ростер кампании (без дубликатов).
func add_god(path: String) -> void:
	if path.strip_edges() != "" and not available_gods.has(path):
		available_gods.append(path)
		roster_changed.emit()

## Убрать бога из ростера.
func remove_god(path: String) -> void:
	available_gods.erase(path)
	roster_changed.emit()

## Добавить артефакт в сокровищницу. Один и тот же путь можно добавить несколько
## раз — treasury допускает дубликаты (количество копий = сколько раз путь встречается);
## см. Campaign/campaign_screen.gd::_populate_treasury для группировки по количеству.
func add_item(path: String) -> void:
	if path.strip_edges() != "":
		treasury.append(path)

## Убрать одну копию артефакта из сокровищницы (если их несколько — убирается одна).
func remove_item(path: String) -> void:
	treasury.erase(path)

## Добавить миссию в список доступных (без дубликатов).
func add_mission(path: String) -> void:
	if path.strip_edges() != "" and not available_missions.has(path):
		available_missions.append(path)

## Убрать миссию из списка доступных.
func remove_mission(path: String) -> void:
	available_missions.erase(path)


func get_pages() -> int:
	return pages


func set_pages(value: int) -> void:
	pages = maxi(0, value)


func add_pages(amount: int) -> void:
	pages = maxi(0, pages + amount)

## Очищает всё состояние кампании (новая игра).
func reset_all() -> void:
	available_gods.clear()
	treasury.clear()
	available_missions.clear()
	completed_missions.clear()
	pages = 0
	before_first_battle_played = false
	first_battle_completed = false
	before_doors_played = false
	opened_locations.clear()
	clear_god_state_overrides()
	reset_currency_amounts()
	library_max_fantasy_bonus = 0
	spell_upgrade_levels.clear()
	roster_changed.emit()

func clear_god_state_overrides() -> void:
	_god_state_overrides.clear()

func get_god_state(path: String) -> Dictionary:
	if path.strip_edges() == "":
		return _default_god_state()
	return _normalize_god_state(_god_state_overrides.get(path, {}))

func set_god_state(path: String, forgetting_level: float, is_dead: bool, level: int = 1, upgraded_abilities: Array = [], creation_essence_paths: Array = [], current_hp: int = -1, equipment_paths: Array = []) -> void:
	if path.strip_edges() == "":
		return
	var previous_state := _normalize_god_state(_god_state_overrides.get(path, {}))
	var stored_hp := current_hp
	if stored_hp < 0:
		stored_hp = int(previous_state.get("current_hp", -1))
	var stored_equipment_paths := _normalize_equipment_paths(equipment_paths)
	if equipment_paths.is_empty():
		stored_equipment_paths = _normalize_equipment_paths(previous_state.get("equipment_paths", []))
	_god_state_overrides[path] = {
		"forgetting_level": clampf(forgetting_level, 0.0, 5.0),
		"is_dead": is_dead,
		"level": clampi(level, MIN_GOD_LEVEL, MAX_GOD_LEVEL),
		"upgraded_abilities": _to_string_array(upgraded_abilities),
		"creation_essence_paths": _unique_string_array(creation_essence_paths),
		"current_hp": stored_hp,
		"equipment_paths": stored_equipment_paths,
	}

func is_god_dead(path: String) -> bool:
	return bool(get_god_state(path).get("is_dead", false))

func get_god_forgetting_level(path: String) -> float:
	return float(get_god_state(path).get("forgetting_level", 0.0))

func get_god_level(path: String) -> int:
	return int(get_god_state(path).get("level", MIN_GOD_LEVEL))

func get_god_max_hp(path: String) -> int:
	var resource := load_character_resource(path)
	if resource == null:
		return 1
	var max_value := maxi(1, resource.max_hp + int(resource.get_total_level_bonus().get("max_hp", 0)))
	if not resource.is_enemy and resource.forgetting_level > 0.0:
		max_value = maxi(1, int(float(max_value) * resource.get_forgetting_multiplier()))
	# Экипировка — как и в Combatant._init(), плюсуется после "забвения" и им не масштабируется.
	for item in [resource.equipped_weapon, resource.equipped_armor, resource.equipped_trinket]:
		if item != null:
			max_value += item.bonus_max_hp
	return maxi(1, max_value)

func get_god_current_hp(path: String) -> int:
	var max_value := get_god_max_hp(path)
	var stored_hp := int(get_god_state(path).get("current_hp", -1))
	if stored_hp < 0:
		return max_value
	return clampi(stored_hp, 0, max_value)

func set_god_current_hp(path: String, value: int, max_override: int = -1) -> void:
	if path.strip_edges() == "":
		return
	var state := get_god_state(path)
	var max_value := max_override if max_override > 0 else get_god_max_hp(path)
	set_god_state(
		path,
		float(state.get("forgetting_level", 0.0)),
		bool(state.get("is_dead", false)),
		int(state.get("level", MIN_GOD_LEVEL)),
		_to_string_array(state.get("upgraded_abilities", [])),
		_to_string_array(state.get("creation_essence_paths", [])),
		clampi(value, 0, maxi(1, max_value)),
		_to_string_array(state.get("equipment_paths", []))
	)
	roster_changed.emit()

func set_god_level(path: String, level: int) -> void:
	var state := get_god_state(path)
	set_god_state(
		path,
		float(state.get("forgetting_level", 0.0)),
		bool(state.get("is_dead", false)),
		level,
		_to_string_array(state.get("upgraded_abilities", [])),
		_to_string_array(state.get("creation_essence_paths", [])),
		int(state.get("current_hp", -1)),
		_to_string_array(state.get("equipment_paths", []))
	)
	roster_changed.emit()

func increase_god_level(path: String, amount: int = 1) -> int:
	var new_level := clampi(get_god_level(path) + amount, MIN_GOD_LEVEL, MAX_GOD_LEVEL)
	set_god_level(path, new_level)
	return new_level

func get_god_upgrade_slots(path: String) -> int:
	return get_god_level(path)

func get_god_upgraded_abilities(path: String) -> Array[String]:
	return _to_string_array(get_god_state(path).get("upgraded_abilities", []))

func set_god_creation_essences(path: String, essence_paths: Array) -> void:
	var state := get_god_state(path)
	set_god_state(
		path,
		float(state.get("forgetting_level", 0.0)),
		bool(state.get("is_dead", false)),
		int(state.get("level", MIN_GOD_LEVEL)),
		_to_string_array(state.get("upgraded_abilities", [])),
		_unique_string_array(essence_paths),
		int(state.get("current_hp", -1)),
		_to_string_array(state.get("equipment_paths", []))
	)

func get_god_equipment_paths(path: String) -> Array[String]:
	return _normalize_equipment_paths(get_god_state(path).get("equipment_paths", []))

func get_god_equipment_path(path: String, slot_type: int) -> String:
	var equipment_paths := get_god_equipment_paths(path)
	if slot_type < 0 or slot_type >= equipment_paths.size():
		return ""
	return equipment_paths[slot_type]

func set_god_equipment_path(path: String, slot_type: int, item_path: String) -> void:
	path = path.strip_edges()
	if path == "" or slot_type < 0 or slot_type > 2:
		return
	var state := get_god_state(path)
	var equipment_paths := _normalize_equipment_paths(state.get("equipment_paths", []))
	equipment_paths[slot_type] = item_path.strip_edges()
	set_god_state(
		path,
		float(state.get("forgetting_level", 0.0)),
		bool(state.get("is_dead", false)),
		int(state.get("level", MIN_GOD_LEVEL)),
		_to_string_array(state.get("upgraded_abilities", [])),
		_to_string_array(state.get("creation_essence_paths", [])),
		int(state.get("current_hp", -1)),
		equipment_paths
	)
	roster_changed.emit()

func get_item_equipped_god_path(item_path: String) -> String:
	item_path = item_path.strip_edges()
	if item_path == "":
		return ""
	for god_path in available_gods:
		var equipment_paths := get_god_equipment_paths(god_path)
		if equipment_paths.has(item_path):
			return god_path
	return ""

func get_god_upgrade_essence_paths(path: String) -> Array[String]:
	var state_paths := _to_string_array(get_god_state(path).get("creation_essence_paths", []))
	if not state_paths.is_empty():
		return state_paths
	var resource := load(path) as CharacterResource
	if resource == null:
		return []
	return _unique_string_array(resource.upgrade_essence_paths)

func get_god_ability_upgrade_error(path: String, ability_path: String, essence_path: String) -> String:
	path = path.strip_edges()
	ability_path = ability_path.strip_edges()
	essence_path = essence_path.strip_edges()
	if path == "" or not ResourceLoader.exists(path):
		return "Бог не найден"
	if not available_gods.has(path):
		return "Бог недоступен в кампании"
	if ability_path == "" or not ResourceLoader.exists(ability_path):
		return "Способность не найдена"
	var resource := load(path) as CharacterResource
	if resource == null:
		return "Ресурс бога не загрузился"
	var ability := _find_base_god_ability(resource, ability_path)
	if ability == null:
		return "Эта способность не принадлежит богу"
	if ability.upgraded_ability == null:
		return "У способности не прописана улучшенная версия"
	var upgraded := get_god_upgraded_abilities(path)
	if upgraded.has(ability_path):
		return "Способность уже улучшена"
	if upgraded.size() >= get_god_upgrade_slots(path):
		return "Нет свободного улучшения на текущем уровне"
	if _is_ultimate_ability(resource, ability_path) and get_god_level(path) < ULTIMATE_UPGRADE_LEVEL:
		return "Ультимативную способность можно улучшить только на 6 уровне"
	var allowed_essences := get_god_upgrade_essence_paths(path)
	if allowed_essences.is_empty():
		return "Не заданы эссенции для улучшения этого бога"
	if not allowed_essences.has(essence_path):
		return "Этой эссенцией нельзя улучшать этого бога"
	if get_currency_amount(essence_path) < 1:
		return "Недостаточно эссенции"
	return ""

func can_upgrade_god_ability(path: String, ability_path: String, essence_path: String) -> bool:
	return get_god_ability_upgrade_error(path, ability_path, essence_path) == ""

func upgrade_god_ability(path: String, ability_path: String, essence_path: String) -> bool:
	if not can_upgrade_god_ability(path, ability_path, essence_path):
		return false
	if not spend_currency_amounts({essence_path: 1}):
		return false
	var state := get_god_state(path)
	var upgraded := get_god_upgraded_abilities(path)
	upgraded.append(ability_path.strip_edges())
	set_god_state(
		path,
		float(state.get("forgetting_level", 0.0)),
		bool(state.get("is_dead", false)),
		int(state.get("level", MIN_GOD_LEVEL)),
		upgraded,
		_to_string_array(state.get("creation_essence_paths", []))
	)
	roster_changed.emit()
	return true

func apply_god_state(resource: CharacterResource, path_override: String = "") -> CharacterResource:
	if resource == null or resource.is_enemy:
		return resource
	var state_path := path_override.strip_edges()
	if state_path == "":
		state_path = resource.resource_path
	var state := get_god_state(state_path)
	resource.god_level = int(state.get("level", MIN_GOD_LEVEL))
	resource.forgetting_level = float(state.get("forgetting_level", 0.0))
	resource.is_dead = bool(state.get("is_dead", false))
	_apply_upgraded_abilities_to_resource(resource, state)
	_apply_equipment_to_resource(resource, state)
	return resource

func load_character_resource(path: String) -> CharacterResource:
	var loaded := load(path) as CharacterResource
	if loaded == null:
		return null
	var resource := loaded.duplicate(true) as CharacterResource
	return apply_god_state(resource, path)

func add_god_forgetting(path: String, amount: float) -> Dictionary:
	var resource := load_character_resource(path)
	if resource == null:
		return {}
	var state := get_god_state(path)
	resource.add_forgetting(amount)
	set_god_state(
		path,
		resource.forgetting_level,
		resource.is_dead,
		int(state.get("level", MIN_GOD_LEVEL)),
		_to_string_array(state.get("upgraded_abilities", [])),
		_to_string_array(state.get("creation_essence_paths", []))
	)
	return get_god_state(path)

func collect_god_states(paths: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for path in paths:
		if path.strip_edges() == "":
			continue
		result[path] = get_god_state(path)
	return result

func apply_god_states(states: Dictionary) -> void:
	clear_god_state_overrides()
	for path_variant in states.keys():
		var path := str(path_variant)
		var state: Dictionary = _normalize_god_state(states[path_variant])
		set_god_state(
			path,
			float(state.get("forgetting_level", 0.0)),
			bool(state.get("is_dead", false)),
			int(state.get("level", MIN_GOD_LEVEL)),
			_to_string_array(state.get("upgraded_abilities", [])),
			_to_string_array(state.get("creation_essence_paths", [])),
			int(state.get("current_hp", -1)),
			_to_string_array(state.get("equipment_paths", []))
		)

func _default_god_state() -> Dictionary:
	return {
		"forgetting_level": 0.0,
		"is_dead": false,
		"level": MIN_GOD_LEVEL,
		"upgraded_abilities": [],
		"creation_essence_paths": [],
		"current_hp": -1,
		"equipment_paths": ["", "", ""],
	}

func _normalize_god_state(state_variant: Variant) -> Dictionary:
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	return {
		"forgetting_level": float(state.get("forgetting_level", 0.0)),
		"is_dead": bool(state.get("is_dead", false)),
		"level": clampi(int(state.get("level", MIN_GOD_LEVEL)), MIN_GOD_LEVEL, MAX_GOD_LEVEL),
		"upgraded_abilities": _to_string_array(state.get("upgraded_abilities", [])),
		"creation_essence_paths": _unique_string_array(state.get("creation_essence_paths", [])),
		"current_hp": int(state.get("current_hp", -1)),
		"equipment_paths": _normalize_equipment_paths(state.get("equipment_paths", [])),
	}

func _normalize_equipment_paths(value: Variant) -> Array[String]:
	var result: Array[String] = ["", "", ""]
	var raw_paths := _to_string_array(value)
	for i in range(mini(result.size(), raw_paths.size())):
		result[i] = raw_paths[i].strip_edges()
	return result

func _apply_equipment_to_resource(resource: CharacterResource, state: Dictionary) -> void:
	var equipment_paths := _normalize_equipment_paths(state.get("equipment_paths", []))
	resource.equipped_weapon = _load_item_or_null(equipment_paths[0])
	resource.equipped_armor = _load_item_or_null(equipment_paths[1])
	resource.equipped_trinket = _load_item_or_null(equipment_paths[2])

func _load_item_or_null(path: String) -> ItemResource:
	path = path.strip_edges()
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as ItemResource

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _unique_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for item in _to_string_array(value):
		var clean := item.strip_edges()
		if clean != "" and not result.has(clean):
			result.append(clean)
	return result

func _find_base_god_ability(resource: CharacterResource, ability_path: String) -> AbilityResource:
	for ability in resource.active_abilities:
		if ability != null and ability.resource_path == ability_path:
			return ability
	if resource.ultimate_ability != null and resource.ultimate_ability.resource_path == ability_path:
		return resource.ultimate_ability
	return null

func _is_ultimate_ability(resource: CharacterResource, ability_path: String) -> bool:
	return resource.ultimate_ability != null and resource.ultimate_ability.resource_path == ability_path

func _apply_upgraded_abilities_to_resource(resource: CharacterResource, state: Dictionary) -> void:
	var upgraded := _to_string_array(state.get("upgraded_abilities", []))
	if upgraded.is_empty():
		return
	for i in range(resource.active_abilities.size()):
		var ability := resource.active_abilities[i]
		if ability != null and upgraded.has(ability.resource_path) and ability.upgraded_ability != null:
			resource.active_abilities[i] = ability.upgraded_ability
	if resource.ultimate_ability != null and upgraded.has(resource.ultimate_ability.resource_path) and resource.ultimate_ability.upgraded_ability != null:
		resource.ultimate_ability = resource.ultimate_ability.upgraded_ability
func _capture_default_currency_amounts() -> void:
	if not _default_currency_amounts.is_empty():
		return
	for path in CURRENCY_RESOURCE_PATHS:
		var resource := load(path)
		if resource != null:
			_default_currency_amounts[path] = int(resource.get("amount"))

func get_currency_amount(path: String) -> int:
	_capture_default_currency_amounts()
	if not _currency_amounts.has(path):
		_currency_amounts[path] = int(_default_currency_amounts.get(path, 0))
	return int(_currency_amounts.get(path, 0))

func add_currency_amount(path: String, amount: int) -> void:
	if path.strip_edges() == "" or amount == 0:
		return
	_capture_default_currency_amounts()
	_currency_amounts[path] = maxi(0, get_currency_amount(path) + amount)
	_sync_currency_resource(path)

# ════════════════════════════════════════════════════════════
#  Прохождение миссий
# ════════════════════════════════════════════════════════════

## Разовая награда мыслями за завершение ЛЮБОЙ миссии (только при первом прохождении).
const MISSION_COMPLETION_THOUGHTS_REWARD := 700

func is_mission_completed(path: String) -> bool:
	return completed_missions.has(path.strip_edges())

## Отмечает миссию пройденной. При первом прохождении выдаёт разовую награду
## в MISSION_COMPLETION_THOUGHTS_REWARD мыслей, увеличивает счётчик страниц на 1
## и возвращает true; при повторном прохождении ничего не делает и возвращает false.
func complete_mission(path: String) -> bool:
	var clean_path := path.strip_edges()
	if clean_path == "" or completed_missions.has(clean_path):
		return false
	completed_missions.append(clean_path)
	add_currency_amount(THOUGHTS_PATH, MISSION_COMPLETION_THOUGHTS_REWARD)
	add_pages(1)
	return true

func spend_currency_amounts(costs: Dictionary) -> bool:
	for path_variant in costs.keys():
		var path := str(path_variant)
		var cost := int(costs[path_variant])
		if cost <= 0:
			continue
		if get_currency_amount(path) < cost:
			return false
	for path_variant in costs.keys():
		var path := str(path_variant)
		var cost := int(costs[path_variant])
		if cost <= 0:
			continue
		_currency_amounts[path] = get_currency_amount(path) - cost
		_sync_currency_resource(path)
	return true

func collect_currency_amounts() -> Dictionary:
	var amounts: Dictionary = {}
	for path in CURRENCY_RESOURCE_PATHS:
		amounts[path] = get_currency_amount(path)
	return amounts

func apply_currency_amounts(amounts: Dictionary) -> void:
	_capture_default_currency_amounts()
	for path in CURRENCY_RESOURCE_PATHS:
		_currency_amounts[path] = int(amounts.get(path, _default_currency_amounts.get(path, 0)))
		_sync_currency_resource(path)

func reset_currency_amounts() -> void:
	_capture_default_currency_amounts()
	_currency_amounts = _default_currency_amounts.duplicate(true)
	for path in CURRENCY_RESOURCE_PATHS:
		_sync_currency_resource(path)

func _sync_currency_resource(path: String) -> void:
	var resource := load(path)
	if resource != null:
		resource.set("amount", get_currency_amount(path))


