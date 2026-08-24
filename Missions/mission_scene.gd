extends Control

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var image_rect: TextureRect = $Panel/Margin/VBox/Image
@onready var body_label: RichTextLabel = $Panel/Margin/VBox/BodyText
@onready var choices_container: VBoxContainer = $Panel/Margin/VBox/Choices
@onready var back_button: Button = $BackButton

const BATTLE_SETUP_SCRIPT := preload("res://battle_setup.gd")
const MISSION_HERO_PORTRAIT_SIZE := Vector2(84, 84)
const MISSION_HERO_HP_BAR_HEIGHT := 6.0
const MISSION_HERO_MAJESTY_BAR_HEIGHT := 5.0
const MISSION_HERO_BAR_GAP := 2.0

var _heroes_row: HBoxContainer = null
var _mission_hp_bars: Dictionary = {}
var _mission_majesty_bars: Dictionary = {}
var _mission_reward_overlay: Control = null
var _pending_finish_return_path: String = ""

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	body_label.bbcode_enabled = true
	_prepare_layout()
	_build_mission_heroes_row()
	if MissionState.current_scene == null and MissionState.current_mission != null and not MissionState.current_mission.scenes.is_empty():
		MissionState.set_current_scene(MissionState.current_mission.scenes[0] as MissionSceneResource)
	_load_scene(MissionState.current_scene)

func _prepare_layout() -> void:
	image_rect.custom_minimum_size = Vector2(0, 120)
	image_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body_label.custom_minimum_size = Vector2(0, 360)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_container.size_flags_vertical = Control.SIZE_SHRINK_END

func _build_mission_heroes_row() -> void:
	if _heroes_row == null:
		_heroes_row = HBoxContainer.new()
		_heroes_row.name = "MissionHeroes"
		_heroes_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_heroes_row.add_theme_constant_override("separation", 10)
		_heroes_row.custom_minimum_size = Vector2(0, MISSION_HERO_PORTRAIT_SIZE.y + MISSION_HERO_HP_BAR_HEIGHT + MISSION_HERO_BAR_GAP + MISSION_HERO_MAJESTY_BAR_HEIGHT + 4.0)
		_heroes_row.size_flags_vertical = Control.SIZE_SHRINK_END
		$Panel/Margin/VBox.add_child(_heroes_row)
	for child in _heroes_row.get_children():
		child.queue_free()
	_mission_hp_bars.clear()
	_mission_majesty_bars.clear()
	for hero_path in MissionState.selected_heroes:
		var clean_path: String = str(hero_path).strip_edges()
		if clean_path == "":
			continue
		var res := CampaignState.load_character_resource(clean_path)
		if res == null:
			continue
		var hero_box := VBoxContainer.new()
		hero_box.custom_minimum_size = Vector2(MISSION_HERO_PORTRAIT_SIZE.x, MISSION_HERO_PORTRAIT_SIZE.y + MISSION_HERO_HP_BAR_HEIGHT + MISSION_HERO_BAR_GAP + MISSION_HERO_MAJESTY_BAR_HEIGHT + 4.0)
		hero_box.add_theme_constant_override("separation", 2)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = MISSION_HERO_PORTRAIT_SIZE
		portrait.size = MISSION_HERO_PORTRAIT_SIZE
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.tooltip_text = Localization.text_from(res, "unit_name_key", "unit_name", res.unit_name)
		portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		portrait.texture = _load_face_texture(clean_path)
		hero_box.add_child(portrait)
		var hp_bar := _make_mission_hp_bar()
		hp_bar.custom_minimum_size = Vector2(MISSION_HERO_PORTRAIT_SIZE.x, MISSION_HERO_HP_BAR_HEIGHT)
		hero_box.add_child(hp_bar)
		_mission_hp_bars[clean_path] = hp_bar
		var majesty_bar := _make_mission_majesty_bar()
		majesty_bar.custom_minimum_size = Vector2(MISSION_HERO_PORTRAIT_SIZE.x, MISSION_HERO_MAJESTY_BAR_HEIGHT)
		hero_box.add_child(majesty_bar)
		_mission_majesty_bars[clean_path] = majesty_bar
		_heroes_row.add_child(hero_box)
	_refresh_mission_hero_bars()

func _process(_delta: float) -> void:
	_refresh_mission_hero_bars()

func _make_mission_hp_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = "Здоровье"
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.02, 0.02, 1.0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _make_mission_majesty_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = "Величие"
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.62, 0.05, 1.0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _refresh_mission_hero_bars() -> void:
	_refresh_mission_hero_hp_bars()
	_refresh_mission_hero_majesty_bars()

func _refresh_mission_hero_hp_bars() -> void:
	for hero_path_variant in _mission_hp_bars.keys():
		var hero_path := str(hero_path_variant)
		var bar := _mission_hp_bars[hero_path_variant] as ProgressBar
		if bar == null:
			continue
		var max_hp := CampaignState.get_god_max_hp(hero_path)
		bar.max_value = maxi(1, max_hp)
		bar.value = CampaignState.get_god_current_hp(hero_path)

func _refresh_mission_hero_majesty_bars() -> void:
	for hero_path_variant in _mission_majesty_bars.keys():
		var hero_path := str(hero_path_variant)
		var bar := _mission_majesty_bars[hero_path_variant] as ProgressBar
		if bar == null:
			continue
		bar.max_value = 100.0
		bar.value = MissionState.get_hero_majesty(hero_path)

func _load_face_texture(path: String) -> Texture2D:
	var res := CampaignState.load_character_resource(path)
	if res != null and res.face_sprite.strip_edges() != "" and ResourceLoader.exists(res.face_sprite):
		return load(res.face_sprite) as Texture2D
	if res != null and res.sprite_path.strip_edges() != "" and ResourceLoader.exists(res.sprite_path):
		return load(res.sprite_path) as Texture2D
	return null
func _load_scene(scene) -> void:
	_build_mission_heroes_row()
	for child in choices_container.get_children():
		child.queue_free()
	if scene == null:
		title_label.text = "Сцена не задана"
		body_label.text = ""
		image_rect.visible = false
		return
	title_label.text = Localization.text_from(scene, "scene_title_key", "scene_title", str(_res_prop(scene, "scene_title", "")))
	var scene_image = _res_prop(scene, "image", null)
	if scene_image != null:
		image_rect.texture = scene_image
		image_rect.visible = true
	else:
		image_rect.texture = null
		image_rect.visible = false
	body_label.text = Localization.text_from(scene, "body_text_key", "body_text", str(_res_prop(scene, "body_text", "")))
	for choice in _array_prop(scene, "choices"):
		if choice == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 54)
		btn.add_theme_font_size_override("font_size", 20)
		btn.text = _choice_display_text(choice)
		if not _is_choice_available(choice):
			btn.disabled = true
		btn.pressed.connect(_on_choice_pressed.bind(choice))
		choices_container.add_child(btn)

func _choice_display_text(choice) -> String:
	var base_text: String = Localization.text_from(choice, "choice_text_key", "choice_text", str(_res_prop(choice, "choice_text", "")))
	var notes: Array[String] = []
	var required_god = _res_prop(choice, "required_god", null)
	if required_god != null:
		var god_name: String = Localization.text_from(required_god, "unit_name_key", "unit_name", str(_res_prop(required_god, "unit_name", "")))
		if god_name.strip_edges() != "":
			notes.append("нужен %s" % god_name)
	var stat_check: StatCheck = _res_prop(choice, "stat_check", null) as StatCheck
	if stat_check != null:
		notes.append("проверка: %s %d%%" % [stat_check.display_stat(), _stat_check_success_percent(stat_check)])
	if notes.is_empty():
		return base_text
	return "%s (%s)" % [base_text, "; ".join(notes)]


func _stat_check_success_percent(stat_check: StatCheck) -> int:
	var avg: float = stat_check.team_average(CampaignState.available_gods)
	var stat_bonus: int = int(avg * stat_check.coefficient)
	var needed_roll: int = int(stat_check.difficulty) - MissionState.pending_check_difficulty_delta - stat_bonus
	var success_outcomes: int = 101 - needed_roll
	var chance: float = clampf(float(success_outcomes) / 101.0, 0.0, 1.0)
	return int(round(chance * 100.0))


func _is_choice_available(choice) -> bool:
	var required_god = _res_prop(choice, "required_god", null)
	if required_god == null:
		return true
	var god_path := str(_res_prop(required_god, "resource_path", ""))
	return god_path == "" or CampaignState.available_gods.has(god_path)

func _on_choice_pressed(choice) -> void:
	if _res_prop(choice, "stat_check", null) != null or _res_prop(choice, "outcome", null) != null or _res_prop(choice, "success_outcome", null) != null or _res_prop(choice, "failure_outcome", null) != null:
		var outcome = _pick_outcome(choice)
		_present_outcome(outcome, choice)
		return
	_handle_legacy(choice)

func _pick_outcome(choice):
	var stat_check = _res_prop(choice, "stat_check", null)
	if stat_check != null:
		var avg: float = stat_check.team_average(CampaignState.available_gods)
		var difficulty_delta: int = MissionState.pending_check_difficulty_delta
		MissionState.pending_check_difficulty_delta = 0
		var success: bool = stat_check.is_success(avg, difficulty_delta)
		print("[Миссия] Проверка %s: среднее %.1f -> %s" % [stat_check.display_stat(), avg, "УСПЕХ" if success else "ПРОВАЛ"])
		return _res_prop(choice, "success_outcome", null) if success else _res_prop(choice, "failure_outcome", null)
	return _res_prop(choice, "outcome", null)

func _present_outcome(outcome, choice) -> void:
	var lines: Array[String] = []
	var stat_check = _res_prop(choice, "stat_check", null)
	if stat_check != null:
		lines.append("[b]Проверка: %s[/b]" % stat_check.display_stat())
	var result_text: String = Localization.text_from(outcome, "result_text_key", "result_text", str(_res_prop(outcome, "result_text", "")))
	if result_text != "":
		lines.append(result_text)
	var rewards_text := _outcome_rewards_text(outcome)
	if rewards_text != "":
		lines.append(rewards_text)
	if lines.is_empty():
		_apply_outcome_effects(outcome)
		return
	for child in choices_container.get_children():
		child.queue_free()
	body_label.text = "\n".join(lines)
	var cont := Button.new()
	cont.text = "Продолжить"
	cont.custom_minimum_size = Vector2(0, 54)
	cont.add_theme_font_size_override("font_size", 20)
	cont.pressed.connect(_apply_outcome_effects.bind(outcome))
	choices_container.add_child(cont)

func _outcome_rewards_text(outcome) -> String:
	var parts: Array[String] = []
	for reward_value in _array_prop(outcome, "rewards"):
		var reward := reward_value as Reward
		if reward == null or reward.resource == null:
			continue
		var display_name := _reward_display_name(reward.resource)
		if reward.kind == Reward.Kind.ESSENCE or reward.kind == Reward.Kind.CURRENCY:
			parts.append("%s x%d" % [display_name, int(reward.amount)])
		else:
			parts.append(display_name)
	if parts.is_empty():
		return ""
	return "[b]Получено:[/b] %s" % ", ".join(parts)


func _apply_outcome_effects(outcome) -> void:
	if outcome == null:
		_advance_or_finish_mission()
		return
	for reward in _array_prop(outcome, "rewards"):
		_grant_and_record_reward(reward)
	_apply_outcome_mission_effects(outcome)
	if bool(_res_prop(outcome, "end_mission_as_failure", false)):
		_finish_mission(false)
		return
	var next_scene = _res_prop(outcome, "next_scene", null) as MissionSceneResource
	var battle = _res_prop(outcome, "battle", null)
	if battle != null:
		MissionState.next_scene_after_battle = next_scene
		_launch_battle(battle)
		return
	if next_scene != null:
		MissionState.set_current_scene(next_scene)
		get_tree().reload_current_scene()
		return
	_advance_or_finish_mission()
func _apply_outcome_mission_effects(outcome) -> void:
	var heal_percent: int = int(_res_prop(outcome, "hero_heal_percent", 0))
	if heal_percent != 0:
		CombatManager.pending_mission_hero_heal_percent += heal_percent
	var fantasy_delta: int = int(_res_prop(outcome, "fantasy_delta", 0))
	if fantasy_delta != 0:
		CombatManager.pending_mission_fantasy_delta += fantasy_delta
	var majesty_delta: int = int(_res_prop(outcome, "hero_majesty_delta", 0))
	if majesty_delta != 0:
		MissionState.add_majesty_to_selected_heroes(majesty_delta)
	var hero_buffs_until_mission_end: bool = bool(_res_prop(outcome, "hero_buffs_until_mission_end", false))
	for buff in _array_prop(outcome, "hero_buffs"):
		if buff != null:
			if hero_buffs_until_mission_end:
				CombatManager.mission_team_buffs.append(buff)
			else:
				CombatManager.pending_mission_hero_buffs.append(buff)
	for buff in _array_prop(outcome, "strongest_hero_buffs"):
		if buff != null:
			CombatManager.mission_strongest_hero_buffs.append(buff)
	if bool(_res_prop(outcome, "skip_helheim_fog_first_round", false)):
		CombatManager.pending_helheim_skip_fog_rounds += 1
	var check_difficulty_delta: int = int(_res_prop(outcome, "next_check_difficulty_delta", 0))
	if check_difficulty_delta != 0:
		MissionState.pending_check_difficulty_delta += check_difficulty_delta
	var target_god: Resource = _res_prop(outcome, "target_god", null) as Resource
	if target_god != null:
		var target_path: String = str(_res_prop(target_god, "resource_path", ""))
		if target_path != "":
			var target_buffs: Array = _array_prop(outcome, "target_buffs")
			var target_buffs_until_mission_end: bool = bool(_res_prop(outcome, "target_buffs_until_mission_end", false))
			var target_hp_delta: int = int(_res_prop(outcome, "target_current_hp_percent_delta", 0))
			var target_majesty_delta: int = int(_res_prop(outcome, "target_majesty_delta", 0))
			if target_hp_delta != 0 or target_majesty_delta != 0 or (not target_buffs_until_mission_end and target_buffs.size() > 0):
				CombatManager.pending_mission_target_effects.append({
					"resource_path": target_path,
					"current_hp_percent_delta": target_hp_delta,
					"majesty_delta": target_majesty_delta,
					"buffs": ([] if target_buffs_until_mission_end else target_buffs)
				})
			if target_buffs_until_mission_end and target_buffs.size() > 0:
				CombatManager.mission_target_buffs.append({
					"resource_path": target_path,
					"buffs": target_buffs
				})

func _launch_battle(battle) -> void:
	_prepare_direct_battle(battle)
	get_tree().change_scene_to_file("res://battle_scene.tscn")

func _prepare_direct_battle(battle) -> void:
	CombatManager.selected_heroes = ["", "", "", ""]
	for i in range(min(4, CombatManager.mission_heroes.size())):
		var hero_path: String = CombatManager.mission_heroes[i]
		if hero_path != "" and not CombatManager.mission_dead_heroes.has(hero_path):
			CombatManager.selected_heroes[i] = hero_path
	CombatManager.selected_enemies = ["", "", "", ""]
	var formation = _res_prop(battle, "formation", null)
	if formation != null:
		var enemies: Array[String] = formation.get_enemy_paths()
		for i in range(min(4, enemies.size())):
			CombatManager.selected_enemies[i] = enemies[i]
		CombatManager.pending_formation_enemies = enemies
	CombatManager.pending_enemy_modifiers = _array_prop(battle, "enemy_modifiers")
	CombatManager.pending_hero_modifiers = _array_prop(battle, "hero_modifiers")
	var location_id := str(_res_prop(battle, "location_id", ""))
	if location_id == "":
		_apply_mission_location()
		location_id = CombatManager.pending_location_id
	else:
		CombatManager.pending_location_id = location_id
	BATTLE_SETUP_SCRIPT.apply_location_to_combat_manager(location_id)
	CombatManager.is_mission_battle = true
	_apply_forgetting_to_selected_heroes()

func _apply_forgetting_to_selected_heroes() -> void:
	for hero_path in CombatManager.selected_heroes:
		if hero_path.strip_edges() == "":
			continue
		if CampaignState.is_god_dead(hero_path):
			continue
		CampaignState.add_god_forgetting(hero_path, 0.5)

func _prepare_legacy_direct_battle(formation) -> void:
	CombatManager.selected_heroes = ["", "", "", ""]
	for i in range(min(4, CombatManager.mission_heroes.size())):
		var hero_path: String = CombatManager.mission_heroes[i]
		if hero_path != "" and not CombatManager.mission_dead_heroes.has(hero_path):
			CombatManager.selected_heroes[i] = hero_path
	if formation != null:
		var enemies: Array[String] = formation.get_enemy_paths()
		CombatManager.selected_enemies = ["", "", "", ""]
		for i in range(min(4, enemies.size())):
			CombatManager.selected_enemies[i] = enemies[i]
	BATTLE_SETUP_SCRIPT.apply_location_to_combat_manager(CombatManager.pending_location_id)
	_apply_forgetting_to_selected_heroes()
func _handle_legacy(choice) -> void:
	var effects := str(_res_prop(choice, "effects", ""))
	if effects.strip_edges() != "":
		print("[Миссия] Эффект «%s»:\n%s" % [str(_res_prop(choice, "choice_text", "Вариант")), effects])
	var next_scene = _res_prop(choice, "next_scene", null) as MissionSceneResource
	var formation = _res_prop(choice, "formation", null)
	if formation != null:
		MissionState.next_scene_after_battle = next_scene
		CombatManager.pending_formation_enemies = formation.get_enemy_paths()
		_apply_mission_location()
		CombatManager.is_mission_battle = true
		_prepare_legacy_direct_battle(formation)
		get_tree().change_scene_to_file("res://battle_scene.tscn")
		return
	if bool(_res_prop(choice, "launch_battle", false)):
		MissionState.next_scene_after_battle = next_scene
		_apply_mission_location()
		CombatManager.is_mission_battle = true
		_prepare_legacy_direct_battle(formation)
		get_tree().change_scene_to_file("res://battle_scene.tscn")
		return
	if next_scene != null:
		MissionState.set_current_scene(next_scene)
		get_tree().reload_current_scene()
		return
	_advance_or_finish_mission()
func _apply_mission_location() -> void:
	if MissionState.current_mission != null:
		CombatManager.pending_location_id = MissionState.current_mission.get_location_id()

func _advance_or_finish_mission() -> void:
	if MissionState.advance_to_next_scene():
		get_tree().reload_current_scene()
		return
	_finish_mission()

func _finish_mission(show_rewards: bool = true) -> void:
	var return_path := MissionState.return_scene_path.strip_edges()
	if return_path == "":
		return_path = "res://Campaign/campaign_screen.tscn"
	_pending_finish_return_path = return_path
	if MissionState.current_mission != null:
		MissionState.last_completed_mission_path = MissionState.current_mission.resource_path
	if show_rewards:
		_show_mission_reward_summary()
		return
	_complete_mission_return()
func _grant_and_record_reward(reward_value) -> void:
	var reward := reward_value as Reward
	if reward == null:
		return
	reward.grant()
	MissionState.record_reward(reward)

func _show_mission_reward_summary() -> void:
	if _mission_reward_overlay != null and is_instance_valid(_mission_reward_overlay):
		return
	var overlay := ColorRect.new()
	overlay.name = "MissionRewardSummary"
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_mission_reward_overlay = overlay

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_top = -260
	panel.offset_right = 380
	panel.offset_bottom = 260
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Награды миссии"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 340)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_populate_reward_summary(content)

	var ok_button := Button.new()
	ok_button.text = "Продолжить"
	ok_button.custom_minimum_size = Vector2(0, 58)
	ok_button.add_theme_font_size_override("font_size", 24)
	ok_button.pressed.connect(_complete_mission_return)
	root.add_child(ok_button)

func _populate_reward_summary(content: VBoxContainer) -> void:
	var currency_totals: Dictionary = {}
	var item_paths: Array[String] = []
	var god_paths: Array[String] = []
	for entry_value in MissionState.granted_rewards:
		var entry := entry_value as Dictionary
		if entry == null:
			continue
		var kind: int = int(entry.get("kind", -1))
		var resource_path: String = str(entry.get("resource_path", "")).strip_edges()
		var amount: int = int(entry.get("amount", 1))
		if resource_path == "":
			continue
		match kind:
			Reward.Kind.ESSENCE, Reward.Kind.CURRENCY:
				currency_totals[resource_path] = int(currency_totals.get(resource_path, 0)) + amount
			Reward.Kind.ITEM:
				item_paths.append(resource_path)
			Reward.Kind.GOD:
				god_paths.append(resource_path)
	if currency_totals.is_empty() and item_paths.is_empty() and god_paths.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Наград нет"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		content.add_child(empty_label)
		return
	for path_value in currency_totals.keys():
		var resource_path: String = str(path_value)
		var resource := load(resource_path) as Resource
		_add_reward_row(content, resource, int(currency_totals[path_value]), true)
	for item_path in item_paths:
		var item := load(item_path) as Resource
		_add_reward_row(content, item, 1, false)
	for god_path in god_paths:
		var god := CampaignState.load_character_resource(god_path)
		_add_reward_row(content, god, 1, false)

func _add_reward_row(content: VBoxContainer, resource: Resource, amount: int, show_amount: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 84)
	content.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.size = Vector2(72, 72)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _reward_icon_from_resource(resource)
	icon_rect.tooltip_text = _reward_tooltip(resource)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(icon_rect)

	var text_label := Label.new()
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 24)
	var display_name := _reward_display_name(resource)
	text_label.text = "%s x%d" % [display_name, amount] if show_amount else display_name
	row.add_child(text_label)

func _reward_icon_from_resource(resource: Resource) -> Texture2D:
	if resource == null:
		return null
	var icon_value = _res_prop(resource, "icon", null)
	if icon_value is Texture2D:
		return icon_value
	for prop in ["icon_path", "face_sprite", "sprite_path"]:
		var image_path: String = str(_res_prop(resource, prop, "")).strip_edges()
		if image_path != "" and ResourceLoader.exists(image_path):
			return load(image_path) as Texture2D
	return null

func _reward_display_name(resource: Resource) -> String:
	if resource == null:
		return "Награда"
	for prop in ["name", "item_name", "unit_name", "display_name"]:
		var value: String = str(_res_prop(resource, prop, "")).strip_edges()
		if value != "":
			return value
	var path := resource.resource_path
	if path != "":
		return path.get_file().get_basename()
	return "Награда"

func _reward_tooltip(resource: Resource) -> String:
	if resource == null:
		return ""
	var lines: Array[String] = []
	var display_name := _reward_display_name(resource)
	if display_name != "":
		lines.append(display_name)
	var type_name: String = ""
	if resource.has_method("get_type_name"):
		type_name = str(resource.call("get_type_name"))
	if type_name != "":
		lines.append(type_name)
	var description: String = str(_res_prop(resource, "description", "")).strip_edges()
	if description != "":
		lines.append(description)
	if resource.has_method("get_bonuses_text"):
		var bonuses: String = str(resource.call("get_bonuses_text")).strip_edges()
		if bonuses != "":
			lines.append(bonuses)
	return "\n".join(lines)

func _complete_mission_return() -> void:
	if _mission_reward_overlay != null and is_instance_valid(_mission_reward_overlay):
		_mission_reward_overlay.queue_free()
		_mission_reward_overlay = null
	var return_path := _pending_finish_return_path.strip_edges()
	if return_path == "":
		return_path = "res://Campaign/campaign_screen.tscn"
	MissionState.clear_mission_run()
	CombatManager.reset_mission()
	get_tree().change_scene_to_file(return_path)
func _res_prop(resource, prop: String, default_value = null):
	if resource == null:
		return default_value
	var value = resource.get(prop)
	return default_value if value == null else value

func _array_prop(resource, prop: String) -> Array:
	var value = _res_prop(resource, prop, [])
	return value if value is Array else []

func _on_back_pressed() -> void:
	_finish_mission(false)
