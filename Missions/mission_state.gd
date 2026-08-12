extends Node

var current_mission: MissionResource = null
var current_scene: MissionSceneResource = null
var current_scene_index: int = -1
var next_scene_after_battle: MissionSceneResource = null
var selected_heroes: Array[String] = ["", "", "", ""]
var requested_mission_path: String = ""
var return_scene_path: String = ""
var hero_majesty: Dictionary = {}
var granted_rewards: Array[Dictionary] = []

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
