extends Node

var current_mission: MissionResource = null
var current_scene: MissionSceneResource = null
var current_scene_index: int = -1
var next_scene_after_battle: MissionSceneResource = null
var selected_heroes: Array[String] = ["", "", "", ""]
var requested_mission_path: String = ""
var return_scene_path: String = ""
## Локация (русское имя, как в Doors/doors.gd), выбранная на экране «Ворота» —
## читается экраном Doors/mission_choice_screen.gd для показа её фона.
var pending_location: String = ""
## Путь к миссии, которая только что была завершена (для одноразовых реакций
## на экране кампании — например, диалог после конкретной миссии).
## Устанавливается в mission_scene.gd перед clear_mission_run(), читается и
## сбрасывается тем экраном, который на это реагирует.
var last_completed_mission_path: String = ""
## Путь к диалогу, который надо показать на экране кампании один раз после
## возврата туда (напр. реплика Мифа при провале миссии из-за пересыпа на пляже).
## Тем же приёмом, что last_completed_mission_path — намеренно НЕ сбрасывается в
## clear_mission_run(), читается и сбрасывается экраном кампании.
var pending_campaign_dialogue_path: String = ""
var hero_majesty: Dictionary = {}
var granted_rewards: Array[Dictionary] = []
## Одноразовая скидка сложности для СЛЕДУЮЩЕЙ проверки характеристики в миссии.
## Устанавливается эффектом сцены (напр. "жульничество"), сбрасывается сразу при использовании.
var pending_check_difficulty_delta: int = 0
## Флаги внутри текущего прохождения миссии (String -> true). Сцена может выставить
## флаг через MissionOutcome.set_mission_flag, а более поздняя сцена — прочитать его
## через MissionChoice.flag_outcomes, чтобы выбрать другой итог. Сбрасываются при
## старте и при завершении миссии — флаги не переживают саму миссию.
var mission_flags: Dictionary = {}
## Общий "счётчик отдыха" для сцен-циклов вроде "Отдохнуть ещё немного" (см.
## MissionOutcome.rest_counter_delta и mission_scene.gd::_apply_outcome_mission_effects).
## Мисси-скоуп: сбрасывается вместе с остальным прохождением.
var rest_counter: int = 0
## Статистика урона/лечения за миссию, по каждому богу отряда — для итогового экрана
## после завершения миссии (см. mission_scene.gd::_show_mission_stats_summary).
## hero_path -> {"dealt": int, "taken": int, "healed": int}. Копится во всех боях
## миссии, сбрасывается вместе с остальным прохождением.
var hero_battle_stats: Dictionary = {}
## Взводится battle_scene.gd перед возвратом на mission_scene.tscn, когда бой был
## ПОСЛЕДНИМ действием миссии (победа без дальнейших сцен, или поражение — после
## поражения дальше сцены миссии не идут). mission_scene.gd::_ready() проверяет этот
## флаг первым делом и, если он взведён, сразу показывает итоговый экран победы/
## поражения вместо обычной сцены — не переживает сохранение, одноразовый сигнал.
enum MissionEndKind { NONE, VICTORY, DEFEAT }
var pending_mission_end_kind: int = MissionEndKind.NONE

func start_mission(mission_res: MissionResource, heroes: Array[String]) -> bool:
	if mission_res == null or mission_res.scenes.is_empty():
		return false
	current_mission = mission_res
	current_scene_index = 0
	current_scene = mission_res.scenes[0] as MissionSceneResource
	next_scene_after_battle = null
	selected_heroes = heroes.duplicate()
	hero_majesty.clear()
	granted_rewards.clear()
	pending_check_difficulty_delta = 0
	mission_flags.clear()
	rest_counter = 0
	hero_battle_stats.clear()
	pending_mission_end_kind = MissionEndKind.NONE
	for hero_path in selected_heroes:
		var clean_path: String = str(hero_path).strip_edges()
		if clean_path != "":
			hero_majesty[clean_path] = 0
	requested_mission_path = mission_res.resource_path
	return current_scene != null

func record_reward(reward: Reward) -> void:
	if reward == null or reward.resource == null:
		return
	granted_rewards.append({
		"kind": int(reward.kind),
		"resource_path": reward.resource.resource_path,
		"amount": int(reward.amount)
	})

func record_resolved_reward(reward: Reward, resolved_resource: Resource) -> void:
	if reward == null or resolved_resource == null:
		return
	granted_rewards.append({
		"kind": int(reward.kind),
		"resource_path": resolved_resource.resource_path,
		"amount": int(reward.amount)
	})

func get_hero_majesty(hero_path: String) -> int:
	var clean_path: String = hero_path.strip_edges()
	if clean_path == "":
		return 0
	return clampi(int(hero_majesty.get(clean_path, 0)), 0, 100)

func set_hero_majesty(hero_path: String, value: int) -> void:
	var clean_path: String = hero_path.strip_edges()
	if clean_path == "":
		return
	hero_majesty[clean_path] = clampi(value, 0, 100)

func add_hero_majesty(hero_path: String, delta: int) -> void:
	set_hero_majesty(hero_path, get_hero_majesty(hero_path) + delta)

func add_majesty_to_selected_heroes(delta: int) -> void:
	for hero_path in selected_heroes:
		var clean_path: String = str(hero_path).strip_edges()
		if clean_path != "":
			add_hero_majesty(clean_path, delta)

## Возвращает (создавая при необходимости) запись статистики бога hero_path.
## Словарь — по ссылке, поэтому правки через возвращённый объект сохраняются в hero_battle_stats.
func _hero_stats_entry(hero_path: String) -> Dictionary:
	var clean_path: String = hero_path.strip_edges()
	if clean_path == "":
		return {}
	if not hero_battle_stats.has(clean_path):
		hero_battle_stats[clean_path] = {"dealt": 0, "taken": 0, "healed": 0}
	return hero_battle_stats[clean_path]

func add_hero_damage_dealt(hero_path: String, amount: int) -> void:
	if amount <= 0:
		return
	var entry := _hero_stats_entry(hero_path)
	if entry.is_empty():
		return
	entry["dealt"] = int(entry.get("dealt", 0)) + amount

func add_hero_damage_taken(hero_path: String, amount: int) -> void:
	if amount <= 0:
		return
	var entry := _hero_stats_entry(hero_path)
	if entry.is_empty():
		return
	entry["taken"] = int(entry.get("taken", 0)) + amount

func add_hero_damage_healed(hero_path: String, amount: int) -> void:
	if amount <= 0:
		return
	var entry := _hero_stats_entry(hero_path)
	if entry.is_empty():
		return
	entry["healed"] = int(entry.get("healed", 0)) + amount

func set_current_scene(scene_res: MissionSceneResource) -> void:
	current_scene = scene_res
	if current_mission == null or scene_res == null:
		return
	var idx := current_mission.scenes.find(scene_res)
	if idx >= 0:
		current_scene_index = idx

func advance_to_next_scene() -> bool:
	if current_mission == null:
		return false
	current_scene_index += 1
	if current_scene_index >= 0 and current_scene_index < current_mission.scenes.size():
		current_scene = current_mission.scenes[current_scene_index] as MissionSceneResource
		return current_scene != null
	current_scene = null
	return false

func advance_after_battle() -> bool:
	if next_scene_after_battle != null:
		set_current_scene(next_scene_after_battle)
		next_scene_after_battle = null
		return current_scene != null
	next_scene_after_battle = null
	return advance_to_next_scene()

func clear_mission_run() -> void:
	current_mission = null
	current_scene = null
	current_scene_index = -1
	next_scene_after_battle = null
	selected_heroes = ["", "", "", ""]
	requested_mission_path = ""
	hero_majesty.clear()
	granted_rewards.clear()
	pending_check_difficulty_delta = 0
	mission_flags.clear()
	rest_counter = 0
	hero_battle_stats.clear()
	pending_mission_end_kind = MissionEndKind.NONE
