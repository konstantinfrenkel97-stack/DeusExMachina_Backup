extends SceneTree

const TEST_MISSION_PATH := "res://Missions/test_campaign_mission.tres"
const HEROES := [
	"res://Gods/Duna/Duna.tres",
	"res://Gods/Morgan/Morgan.tres",
	"res://Gods/Susanoo/Susanoo.tres",
	"res://Gods/Samdi/Samdi.tres",
	"res://Gods/Thor/thor.tres",
	"res://Gods/Odin/Odin.tres",
	"res://Gods/Zeus/Zeus.tres",
	"res://Gods/Osiris/Osiris.tres"
]

func _initialize() -> void:
	call_deferred("_run")

func _visible_rect(control: Control, scale_value: float) -> Rect2:
	return Rect2(control.global_position * scale_value, control.size * scale_value)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2048, 1152))
	await process_frame
	var campaign_state: Node = root.get_node("/root/CampaignState")
	var mission_state: Node = root.get_node("/root/MissionState")
	campaign_state.available_gods.clear()
	for path in HEROES:
		campaign_state.available_gods.append(path)
	mission_state.requested_mission_path = TEST_MISSION_PATH
	var mission = load(TEST_MISSION_PATH)
	var select_scene: PackedScene = load("res://Missions/mission_select.tscn")
	var select_node: Control = select_scene.instantiate()
	root.add_child(select_node)
	select_node.size = root.get_visible_rect().size
	await process_frame
	select_node.call("_open_mission_prep", mission.get("scenes")[0])
	await process_frame
	await process_frame
	var viewport_size: Vector2 = root.get_visible_rect().size
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var scale_value: float = min(window_size.x / viewport_size.x, window_size.y / viewport_size.y)
	var slots: Array = select_node.get("_slot_buttons")
	var gods: Array = select_node.get("_god_buttons")
	print("viewport=", viewport_size)
	print("window=", window_size)
	print("scale=", scale_value)
	print("slot_count=", slots.size())
	print("god_count=", gods.size())
	if slots.size() > 0:
		var slot0: Control = slots[0]
		var slot_last: Control = slots[slots.size() - 1]
		print("slot0_logical=", slot0.size, " slot0_visible=", _visible_rect(slot0, scale_value))
		print("slot_last_visible=", _visible_rect(slot_last, scale_value))
	if gods.size() > 0:
		var god0: Control = gods[0]
		var last: Control = gods[gods.size() - 1]
		var god0_visible: Rect2 = _visible_rect(god0, scale_value)
		var last_visible: Rect2 = _visible_rect(last, scale_value)
		print("god0_logical=", god0.size, " god0_visible=", god0_visible)
		print("god_last_visible=", last_visible)
		print("fits_visible_height=", last_visible.position.y + last_visible.size.y <= window_size.y)
		print("fits_visible_width=", last_visible.position.x + last_visible.size.x <= window_size.x)
	quit()