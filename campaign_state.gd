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
var pages: int = 0

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

## Добавить артефакт в сокровищницу (без дубликатов).
func add_item(path: String) -> void:
	if path.strip_edges() != "" and not treasury.has(path):
		treasury.append(path)

## Убрать артефакт из сокровищницы.
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
	pages = 0
	clear_god_state_overrides()
	reset_currency_amounts()
	roster_changed.emit()

func clear_god_state_overrides() -> void:
	_god_state_overrides.clear()

func get_god_state(path: String) -> Dictionary:
	if path.strip_edges() == "":
		return _default_god_state()
	return _normalize_god_state(_god_state_overrides.get(path, {}))

func set_god_state(path: String, forgetting_level: float, is_dead: bool, level: int = 1, upgraded_abilities: Array = [], creation_essence_paths: Array = [], current_hp: int = -1) -> void:
	if path.strip_edges() == "":
		return
	var previous_state := _normalize_god_state(_god_state_overrides.get(path, {}))
	var stored_hp := current_hp
	if stored_hp < 0:
		stored_hp = int(previous_state.get("current_hp", -1))
	_god_state_overrides[path] = {
		"forgetting_level": clampf(forgetting_level, 0.0, 5.0),
		"is_dead": is_dead,
		"level": clampi(level, MIN_GOD_LEVEL, MAX_GOD_LEVEL),
		"upgraded_abilities": _to_string_array(upgraded_abilities),
		"creation_essence_paths": _unique_string_array(creation_essence_paths),
		"current_hp": stored_hp,
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
	return max_value

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
		clampi(value, 0, maxi(1, max_value))
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
		_to_string_array(state.get("creation_essence_paths", []))
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
		_unique_string_array(essence_paths)
	)

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
			int(state.get("current_hp", -1))
		)

func _default_god_state() -> Dictionary:
	return {
		"forgetting_level": 0.0,
		"is_dead": false,
		"level": MIN_GOD_LEVEL,
		"upgraded_abilities": [],
		"creation_essence_paths": [],
		"current_hp": -1,
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
	}

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


