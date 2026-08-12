extends Node

const TEST_MISSION_PATH := "res://Missions/test_campaign_mission.tres"
const HEROES := [
	"res://Gods/Duna/Duna.tres",
	"res://Gods/Morgan/Morgan.tres",
	"res://Gods/Susanoo/Susanoo.tres",
	"res://Gods/Samdi/Samdi.tres",
	"res://Gods/Thor/thor.tres",
	"res://Gods/Odin/Odin.tres"
]

func _ready() -> void:
	CampaignState.available_gods.clear()
	for path in HEROES:
		CampaignState.available_gods.append(path)
	MissionState.requested_mission_path = TEST_MISSION_PATH
	var mission = load(TEST_MISSION_PATH)
	MissionState.current_mission = mission
	MissionState.current_scene = mission.get("scenes")[0]

	var select_scene: PackedScene = load("res://Missions/mission_select.tscn")
	var select_node: Node = select_scene.instantiate()
	add_child(select_node)
	await get_tree().process_frame
	select_node.call("_open_mission_prep", mission.get("scenes")[0])
	await get_tree().process_frame
	var image1 := get_viewport().get_texture().get_image()
	image1.save_png("D:/dOCS/test/_mission_prep_check.png")
	print("prep_saved")
	select_node.queue_free()
	await get_tree().process_frame

	var scene_scene: PackedScene = load("res://Missions/mission_scene.tscn")
	var scene_node: Node = scene_scene.instantiate()
	add_child(scene_node)
	await get_tree().process_frame
	var choices = scene_node.get_node("Panel/Margin/VBox/Choices") as VBoxContainer
	print("choice_children=", choices.get_child_count())
	var image2 := get_viewport().get_texture().get_image()
	image2.save_png("D:/dOCS/test/_mission_scene_check.png")
	print("scene_saved")
	get_tree().quit()