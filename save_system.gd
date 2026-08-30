extends Node
## Автозагружаемый синглтон (SaveSystem).
## Сохраняет и загружает состояние кампании в формате JSON.
## Файлы сохранений хранятся в user://saves/.
##
## Сохраняемое состояние:
##   • CampaignState: available_gods, treasury, available_missions, completed_missions
##   • CombatManager: is_mission_battle, mission_heroes, mission_heroes_set,
##                    mission_dead_heroes
##   • MissionState: путь к текущей миссии (current_mission)
##   • Боги: forgetting_level и is_dead для каждого бога из ростера

const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".json"
const SAVE_VERSION := 3


# ════════════════════════════════════════════════════════════
#  Публичный API
# ════════════════════════════════════════════════════════════

## Сохраняет текущее состояние игры в указанный слот.
func save_game(slot_name: String) -> bool:
	_ensure_dir()
	var safe_name := _sanitize_slot_name(slot_name)
	if safe_name == "":
		push_error("SaveSystem: пустое имя слота")
		return false
	var data := _collect_state()
	var path := SAVE_DIR + safe_name + SAVE_EXTENSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: не удалось открыть файл для записи: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Загружает состояние игры из указанного слота.
func load_game(slot_name: String) -> bool:
	var data: Variant = _read_save(_sanitize_slot_name(slot_name))
	if data == null:
		push_error("SaveSystem: не удалось прочитать сохранение: " + slot_name)
		return false
	_apply_state(data)
	return true


## Возвращает список сохранений с метаданными.
## Каждый элемент: { "slot": String, "timestamp": String, "gods_count": int }
func get_save_slots() -> Array:
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			var slot := file_name.get_basename()
			var data: Variant = _read_save(slot)
			if data is Dictionary:
				result.append({
					"slot": slot,
					"timestamp": data.get("timestamp", "—"),
					"gods_count": data.get("campaign", {}).get("available_gods", []).size()
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return result


## Проверяет, есть ли хотя бы одно сохранение.
func has_saves() -> bool:
	return get_save_slots().size() > 0


## Удаляет сохранение.
func delete_save(slot_name: String) -> void:
	var path := SAVE_DIR + _sanitize_slot_name(slot_name) + SAVE_EXTENSION
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# ════════════════════════════════════════════════════════════
#  Внутренняя логика
# ════════════════════════════════════════════════════════════

## Собирает всё состояние игры в словарь для сериализации.
func _collect_state() -> Dictionary:
	var data := {}
	data["version"] = SAVE_VERSION
	data["timestamp"] = Time.get_datetime_string_from_system(false, true)

	# — Кампания —
	data["campaign"] = {
		"available_gods": CampaignState.available_gods.duplicate(),
		"treasury": CampaignState.treasury.duplicate(),
		"available_missions": CampaignState.available_missions.duplicate(),
		"completed_missions": CampaignState.completed_missions.duplicate(),
		"currencies": CampaignState.collect_currency_amounts(),
		"pages": CampaignState.get_pages(),
		"before_first_battle_played": CampaignState.before_first_battle_played,
		"first_battle_completed": CampaignState.first_battle_completed,
		"before_doors_played": CampaignState.before_doors_played,
		"opened_locations": CampaignState.opened_locations.duplicate(),
		"library_max_fantasy_bonus": CampaignState.library_max_fantasy_bonus,
		"spell_upgrade_levels": CampaignState.spell_upgrade_levels.duplicate(),
	}

	# — Состояние миссии (CombatManager) —
	data["mission"] = {
		"is_mission_battle": CombatManager.is_mission_battle,
		"mission_heroes": CombatManager.mission_heroes.duplicate(),
		"mission_heroes_set": CombatManager.mission_heroes_set,
		"mission_dead_heroes": CombatManager.mission_dead_heroes.duplicate(),
		"hero_majesty": MissionState.hero_majesty.duplicate(),
		"granted_rewards": MissionState.granted_rewards.duplicate(true),
	}

	# — Путь к текущей миссии —
	var mission_path := ""
	if MissionState.current_mission != null:
		mission_path = MissionState.current_mission.resource_path
	data["mission"]["current_mission_path"] = mission_path

	# — Состояние богов (forgetting_level, is_dead) —
	data["gods"] = CampaignState.collect_god_states(CampaignState.available_gods)

	return data


## Применяет загруженное состояние к синглтонам и ресурсам.
func _apply_state(data: Dictionary) -> void:
	CampaignState.clear_god_state_overrides()
	CampaignState.reset_currency_amounts()
	# — Кампания —
	var campaign: Dictionary = data.get("campaign", {})
	CampaignState.available_gods = _to_string_array(campaign.get("available_gods", []))
	CampaignState.treasury = _to_string_array(campaign.get("treasury", []))
	CampaignState.available_missions = _to_string_array(campaign.get("available_missions", []))
	CampaignState.completed_missions = _to_string_array(campaign.get("completed_missions", []))
	CampaignState.apply_currency_amounts(campaign.get("currencies", {}))
	CampaignState.set_pages(int(campaign.get("pages", 0)))
	CampaignState.before_first_battle_played = bool(campaign.get("before_first_battle_played", false))
	CampaignState.first_battle_completed = bool(campaign.get("first_battle_completed", false))
	CampaignState.before_doors_played = bool(campaign.get("before_doors_played", false))
	CampaignState.opened_locations = _to_string_array(campaign.get("opened_locations", []))
	CampaignState.library_max_fantasy_bonus = int(campaign.get("library_max_fantasy_bonus", 0))
	var loaded_spell_upgrades: Variant = campaign.get("spell_upgrade_levels", {})
	CampaignState.spell_upgrade_levels = (loaded_spell_upgrades as Dictionary) if loaded_spell_upgrades is Dictionary else {}

	# — Состояние миссии —
	var mission: Dictionary = data.get("mission", {})
	CombatManager.is_mission_battle = mission.get("is_mission_battle", false)
	CombatManager.mission_heroes = _to_string_array(mission.get("mission_heroes", ["", "", "", ""]))
	CombatManager.mission_heroes_set = mission.get("mission_heroes_set", false)
	CombatManager.mission_dead_heroes = _to_string_array(mission.get("mission_dead_heroes", []))
	MissionState.hero_majesty = mission.get("hero_majesty", {}).duplicate()
	MissionState.granted_rewards.clear()
	var saved_rewards_value: Variant = mission.get("granted_rewards", [])
	if saved_rewards_value is Array:
		for entry_value in saved_rewards_value:
			if entry_value is Dictionary:
				var reward_entry: Dictionary = entry_value
				MissionState.granted_rewards.append(reward_entry.duplicate(true))

	# — Текущая миссия —
	var mission_path: String = mission.get("current_mission_path", "")
	if mission_path != "" and ResourceLoader.exists(mission_path):
		MissionState.current_mission = load(mission_path)
	else:
		MissionState.current_mission = null
	MissionState.current_scene = null

	# — Восстановление богов —
	var gods_state: Dictionary = data.get("gods", {})
	CampaignState.apply_god_states(gods_state)


## Читает и парсит файл сохранения.
func _read_save(slot_name: String) -> Variant:
	var path := SAVE_DIR + slot_name + SAVE_EXTENSION
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("SaveSystem: ошибка парсинга JSON в " + path + ": " + json.get_error_message())
		return null
	return _migrate_save_data(json.data)


## Создаёт директорию для сохранений, если её нет.
func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Очищает имя слота: убирает недопустимые символы для файловой системы.
func _sanitize_slot_name(slot_name: String) -> String:
	var safe := slot_name.strip_edges()
	# Заменяем недопустимые символы на подчёркивание.
	safe = safe.replace("/", "_").replace("\\", "_").replace(":", "_")
	safe = safe.replace("*", "_").replace("?", "_").replace("\"", "_")
	safe = safe.replace("<", "_").replace(">", "_").replace("|", "_")
	return safe


## Преобразует массив (из JSON) в типизированный Array[String].
func _to_string_array(arr: Variant) -> Array[String]:
	var result: Array[String] = []
	if arr is Array:
		for item in arr:
			result.append(str(item))
	return result


func _migrate_save_data(data: Variant) -> Variant:
	if not (data is Dictionary):
		return null
	var normalized: Dictionary = data.duplicate(true)
	var version := int(normalized.get("version", 1))
	if version > SAVE_VERSION:
		push_error("SaveSystem: сохранение версии %d новее текущей версии %d." % [version, SAVE_VERSION])
		return null
	if version < 2:
		normalized["version"] = 2
		var campaign: Dictionary = normalized.get("campaign", {})
		if not campaign.has("currencies"):
			campaign["currencies"] = {}
		normalized["campaign"] = campaign
	if version < 3:
		normalized["version"] = 3
	return normalized
