extends Control

@onready var title_label: Label = $Panel/Margin/Scroll/VBox/Title
@onready var image_rect: TextureRect = $Panel/Margin/Scroll/VBox/Image
@onready var body_label: RichTextLabel = $Panel/Margin/Scroll/VBox/BodyText
@onready var choices_container: VBoxContainer = $Panel/Margin/Scroll/VBox/Choices
@onready var back_button: Button = $BackButton

const BATTLE_SETUP_SCRIPT := preload("res://battle_setup.gd")
const MISSION_HERO_PORTRAIT_SIZE := Vector2(84, 84)
const MISSION_HERO_HP_BAR_HEIGHT := 6.0
const MISSION_HERO_MAJESTY_BAR_HEIGHT := 5.0
const MISSION_HERO_BAR_GAP := 2.0

var _heroes_row: HBoxContainer = null
var _heroes_row_parent: Control = null
var _mission_hp_bars: Dictionary = {}
var _mission_majesty_bars: Dictionary = {}
var _mission_reward_overlay: Control = null
var _mission_stats_overlay: Control = null
var _mission_banner_overlay: Control = null
var _pending_finish_return_path: String = ""
## Взводится в _apply_outcome_mission_effects(), если счётчик отдыха только что
## пересёк свой порог провала — читается сразу после в _apply_outcome_effects().
var _rest_counter_forced_failure: bool = false

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	body_label.bbcode_enabled = true
	_prepare_layout()
	_build_mission_heroes_row()
	# Бой (последний в миссии) только что решил её исход — сразу показываем экран
	# победы/поражения вместо обычной сцены (см. battle_scene.gd::_return_to_mission_
	# after_battle/_return_to_mission_after_defeat).
	if MissionState.pending_mission_end_kind != MissionState.MissionEndKind.NONE:
		var was_victory: bool = MissionState.pending_mission_end_kind == MissionState.MissionEndKind.VICTORY
		MissionState.pending_mission_end_kind = MissionState.MissionEndKind.NONE
		_finish_mission(was_victory, true)
		return
	if MissionState.current_scene == null and MissionState.current_mission != null and not MissionState.current_mission.scenes.is_empty():
		MissionState.set_current_scene(MissionState.current_mission.scenes[0] as MissionSceneResource)
	_load_scene(MissionState.current_scene)

func _prepare_layout() -> void:
	image_rect.custom_minimum_size = Vector2(0, 120)
	image_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body_label.custom_minimum_size = Vector2(0, 360)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_container.size_flags_vertical = Control.SIZE_SHRINK_END
	# Портреты отряда раньше добавлялись последним элементом ВНУТРИ прокручиваемого
	# текста сцены — при сколько-нибудь длинном тексте/выборах их обрезало снизу
	# видимой области, пока не проскроллишь. Выносим прокрутку в обёртку и держим
	# портреты отдельным, всегда видимым элементом над ней (фиксированная «шапка»).
	var scroll: Control = $Panel/Margin/Scroll
	var margin: Control = $Panel/Margin
	margin.remove_child(scroll)
	var wrapper := VBoxContainer.new()
	wrapper.name = "MarginVBox"
	wrapper.add_theme_constant_override("separation", 10)
	margin.add_child(wrapper)
	wrapper.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_heroes_row_parent = wrapper

func _build_mission_heroes_row() -> void:
	if _heroes_row == null:
		_heroes_row = HBoxContainer.new()
		_heroes_row.name = "MissionHeroes"
		_heroes_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_heroes_row.add_theme_constant_override("separation", 10)
		_heroes_row.custom_minimum_size = Vector2(0, MISSION_HERO_PORTRAIT_SIZE.y + MISSION_HERO_HP_BAR_HEIGHT + MISSION_HERO_BAR_GAP + MISSION_HERO_MAJESTY_BAR_HEIGHT + 4.0)
		_heroes_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_heroes_row_parent.add_child(_heroes_row)
		_heroes_row_parent.move_child(_heroes_row, 0)
	for child in _heroes_row.get_children():
		child.queue_free()
	_mission_hp_bars.clear()
	_mission_majesty_bars.clear()
	# Pos1 (индекс 0) — ближайшая к врагам позиция на поле боя, т.е. самая ПРАВАЯ.
	# Отображаем в том же порядке, что и на экране выбора отряда (mission_select.gd/
	# battle_setup.gd), иначе портреты здесь оказываются зеркально перевёрнуты.
	var selected_heroes: Array = MissionState.selected_heroes
	for visual_index in range(selected_heroes.size()):
		var hero_index: int = selected_heroes.size() - 1 - visual_index
		var hero_path = selected_heroes[hero_index]
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
	bg.bg_color = Color(0.2, 0.2, 0.15, 0.6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 1.0, 0.6, 1.0)
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
	var flag_outcomes = _res_prop(choice, "flag_outcomes", null)
	if flag_outcomes is Dictionary and not flag_outcomes.is_empty():
		for flag_name in flag_outcomes.keys():
			if MissionState.mission_flags.get(str(flag_name), false):
				return flag_outcomes[flag_name]
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
		if reward == null:
			continue
		if reward.kind == Reward.Kind.ESSENCE or reward.kind == Reward.Kind.CURRENCY:
			var icon_bbcode := _reward_icon_bbcode(reward.resource)
			if icon_bbcode != "":
				parts.append("%s x%d" % [icon_bbcode, int(reward.amount)])
			else:
				var display_name := reward.display_name() if reward.resource == null else _reward_display_name(reward.resource)
				parts.append("%s x%d" % [display_name, int(reward.amount)])
		else:
			var display_name := reward.display_name() if reward.resource == null else _reward_display_name(reward.resource)
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
	_rest_counter_forced_failure = false
	_apply_outcome_mission_effects(outcome)
	if bool(_res_prop(outcome, "end_mission_as_failure", false)) or _rest_counter_forced_failure:
		_finish_mission(false, true)
		return
	# Перезапустить текущую сцену (циклы вроде "Отдохнуть ещё немного" → та же сцена
	# заново). MissionState.current_scene уже указывает на эту сцену — Godot не
	# позволяет .tres ссылаться на самого себя через ext_resource (next_scene), поэтому
	# цикл реализован кодом, а не данными: просто не меняем current_scene и перезагружаем.
	if bool(_res_prop(outcome, "restart_current_scene", false)):
		get_tree().reload_current_scene()
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
	var set_flag: String = str(_res_prop(outcome, "set_mission_flag", ""))
	if set_flag != "":
		MissionState.mission_flags[set_flag] = true
	var heal_percent: int = int(_res_prop(outcome, "hero_heal_percent", 0))
	if heal_percent != 0:
		CombatManager.pending_mission_hero_heal_percent += heal_percent
	var forgetting_delta: float = float(_res_prop(outcome, "hero_forgetting_delta", 0.0))
	if forgetting_delta != 0.0:
		_apply_forgetting_to_mission_heroes(forgetting_delta)
	if bool(_res_prop(outcome, "rum_spell_whole_team_next_battle", false)):
		CombatManager.pending_rum_spell_whole_team = true
	var random_hero_buffs: Array = _array_prop(outcome, "target_random_hero_buffs")
	if not random_hero_buffs.is_empty():
		_apply_random_or_preferred_hero_buffs(random_hero_buffs, _res_prop(outcome, "target_random_hero_preferred_god", null))
	var random_hp_delta: int = int(_res_prop(outcome, "random_hero_hp_percent_delta", 0))
	if random_hp_delta != 0:
		_apply_random_mission_hero_hp_delta(random_hp_delta)
	var team_hp_delta: int = int(_res_prop(outcome, "hero_hp_percent_delta", 0))
	if team_hp_delta != 0:
		_apply_team_mission_hero_hp_delta(team_hp_delta)
	var fantasy_delta: int = int(_res_prop(outcome, "fantasy_delta", 0))
	if fantasy_delta != 0:
		CombatManager.pending_mission_fantasy_delta += fantasy_delta
	var thoughts_delta: int = int(_res_prop(outcome, "thoughts_delta", 0))
	if thoughts_delta != 0:
		CampaignState.add_currency_amount(CampaignState.THOUGHTS_PATH, thoughts_delta)
	var max_fantasy_bonus_delta: int = int(_res_prop(outcome, "max_fantasy_bonus_delta", 0))
	if max_fantasy_bonus_delta != 0:
		CampaignState.library_max_fantasy_bonus = maxi(0, CampaignState.library_max_fantasy_bonus + max_fantasy_bonus_delta)
	var majesty_delta: int = int(_res_prop(outcome, "hero_majesty_delta", 0))
	if majesty_delta != 0:
		MissionState.add_majesty_to_selected_heroes(majesty_delta)
	var perm_debuff_unit: String = str(_res_prop(outcome, "permanent_enemy_debuff_unit_name", ""))
	var perm_debuff_accuracy: int = int(_res_prop(outcome, "permanent_enemy_debuff_accuracy", 0))
	if perm_debuff_unit != "" and perm_debuff_accuracy != 0:
		CampaignState.add_permanent_enemy_accuracy_debuff(perm_debuff_unit, perm_debuff_accuracy)
	var immediate_target_god: Resource = _res_prop(outcome, "target_god_immediate", null) as Resource
	if immediate_target_god != null:
		var immediate_target_path: String = str(_res_prop(immediate_target_god, "resource_path", ""))
		if immediate_target_path != "" and not CampaignState.is_god_dead(immediate_target_path):
			var immediate_hp_delta: int = int(_res_prop(outcome, "target_god_immediate_hp_percent_delta", 0))
			var immediate_majesty_delta: int = int(_res_prop(outcome, "target_god_immediate_majesty_delta", 0))
			if immediate_hp_delta != 0:
				var immediate_max_hp: int = CampaignState.get_god_max_hp(immediate_target_path)
				var immediate_hp_amount: int = int(round(float(immediate_max_hp) * float(immediate_hp_delta) / 100.0))
				if immediate_hp_amount == 0:
					immediate_hp_amount = 1 if immediate_hp_delta > 0 else -1
				CampaignState.set_god_current_hp(immediate_target_path, CampaignState.get_god_current_hp(immediate_target_path) + immediate_hp_amount, immediate_max_hp)
			if immediate_majesty_delta != 0:
				MissionState.add_hero_majesty(immediate_target_path, immediate_majesty_delta)
	var hero_buffs_until_mission_end: bool = bool(_res_prop(outcome, "hero_buffs_until_mission_end", false))
	for buff in _array_prop(outcome, "hero_buffs"):
		if buff != null:
			if hero_buffs_until_mission_end:
				CombatManager.mission_team_buffs.append(buff)
			else:
				CombatManager.pending_mission_hero_buffs.append(buff)
	for buff in _array_prop(outcome, "enemy_buffs"):
		if buff != null:
			CombatManager.pending_mission_enemy_buffs.append(buff)
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
	var nemesis_god: Resource = _res_prop(outcome, "nemesis_buff_god", null) as Resource
	var nemesis_majesty: int = int(_res_prop(outcome, "nemesis_buff_majesty", 0))
	var nemesis_stat_entry: Resource = _res_prop(outcome, "nemesis_buff_stat", null) as Resource
	var nemesis_location_id: String = str(_res_prop(outcome, "nemesis_buff_location_id", "")).strip_edges()
	if nemesis_god != null and nemesis_location_id != "" and (nemesis_majesty != 0 or nemesis_stat_entry != null):
		var nemesis_god_path: String = str(_res_prop(nemesis_god, "resource_path", ""))
		if nemesis_god_path != "":
			var nemesis_buff_stat: int = int(nemesis_stat_entry.stat) if nemesis_stat_entry != null else -1
			var nemesis_buff_value: int = int(nemesis_stat_entry.value) if nemesis_stat_entry != null else 0
			CampaignState.add_pending_nemesis_buff(nemesis_location_id, nemesis_god_path, nemesis_majesty, nemesis_buff_stat, nemesis_buff_value)
	_apply_rest_counter_effects(outcome)

## Счётчик отдыха (см. MissionOutcome — поля rest_counter_*). Порядок важен: сперва
## прибавляем delta, потом проверяем порог провала, и только если он НЕ сработал —
## учитываем reset/штраф инициативы (провал сам всё равно "сбрасывает" миссию).
func _apply_rest_counter_effects(outcome) -> void:
	var delta: int = int(_res_prop(outcome, "rest_counter_delta", 0))
	if delta != 0:
		MissionState.rest_counter += delta
	var threshold: int = int(_res_prop(outcome, "rest_counter_fail_threshold", 0))
	if threshold > 0 and MissionState.rest_counter >= threshold:
		var fail_dialogue: String = str(_res_prop(outcome, "rest_counter_fail_dialogue_path", "")).strip_edges()
		if fail_dialogue != "":
			MissionState.pending_campaign_dialogue_path = fail_dialogue
		_rest_counter_forced_failure = true
		return
	if bool(_res_prop(outcome, "apply_rest_counter_initiative_penalty", false)):
		var penalty := MissionState.rest_counter
		if penalty > 0:
			var initiative_debuff := BuffEntry.new()
			initiative_debuff.stat = BuffEntry.Stat.INITIATIVE
			initiative_debuff.value = -penalty
			initiative_debuff.duration = 1
			CombatManager.pending_mission_hero_buffs.append(initiative_debuff)
		MissionState.rest_counter = 0
	elif bool(_res_prop(outcome, "rest_counter_reset", false)):
		MissionState.rest_counter = 0

func _apply_random_mission_hero_hp_delta(percent_delta: int) -> void:
	var candidates: Array[String] = []
	for hero_path in CombatManager.mission_heroes:
		var path: String = str(hero_path).strip_edges()
		if path == "" or CombatManager.mission_dead_heroes.has(path):
			continue
		if CampaignState.get_god_current_hp(path) <= 0:
			continue
		candidates.append(path)
	if candidates.is_empty():
		return
	var target_path: String = candidates[randi_range(0, candidates.size() - 1)]
	var max_hp: int = CampaignState.get_god_max_hp(target_path)
	var delta: int = int(round(float(max_hp) * float(percent_delta) / 100.0))
	if delta == 0:
		delta = 1 if percent_delta > 0 else -1
	CampaignState.set_god_current_hp(target_path, CampaignState.get_god_current_hp(target_path) + delta, max_hp)

## Немедленно меняет HP ВСЕХ живых богов миссии на percent_delta% от их max HP каждого
## (см. MissionOutcome.hero_hp_percent_delta). В отличие от hero_heal_percent — не ждёт
## следующего боя, применяется сразу (напр. ожог от лавы вне боя).
func _apply_team_mission_hero_hp_delta(percent_delta: int) -> void:
	for hero_path in CombatManager.mission_heroes:
		var path: String = str(hero_path).strip_edges()
		if path == "" or CombatManager.mission_dead_heroes.has(path):
			continue
		if CampaignState.get_god_current_hp(path) <= 0:
			continue
		var max_hp: int = CampaignState.get_god_max_hp(path)
		var delta: int = int(round(float(max_hp) * float(percent_delta) / 100.0))
		if delta == 0:
			delta = 1 if percent_delta > 0 else -1
		CampaignState.set_god_current_hp(path, CampaignState.get_god_current_hp(path) + delta, max_hp)

## Немедленно меняет уровень забвения у всех живых богов миссии (см.
## MissionOutcome.hero_forgetting_delta). Не привязано к следующему бою —
## применяется сразу, чтобы работать и когда миссия оканчивается поражением.
func _apply_forgetting_to_mission_heroes(amount: float) -> void:
	for hero_path in MissionState.selected_heroes:
		var clean_path: String = str(hero_path).strip_edges()
		if clean_path == "" or CampaignState.is_god_dead(clean_path):
			continue
		CampaignState.add_god_forgetting(clean_path, amount)

## Баффы одному случайному живому богу отряда миссии на весь оставшийся отряд миссии
## (см. MissionOutcome.target_random_hero_buffs). Если preferred_god задан и он есть
## в отряде — выбирается именно он вместо случайного бога.
func _apply_random_or_preferred_hero_buffs(buffs: Array, preferred_god) -> void:
	if buffs.is_empty():
		return
	var candidates: Array[String] = []
	for hero_path in CombatManager.mission_heroes:
		var path: String = str(hero_path).strip_edges()
		if path == "" or CombatManager.mission_dead_heroes.has(path):
			continue
		if CampaignState.get_god_current_hp(path) <= 0:
			continue
		candidates.append(path)
	if candidates.is_empty():
		return
	var target_path: String = ""
	if preferred_god != null:
		var preferred_path: String = str(_res_prop(preferred_god, "resource_path", "")).strip_edges()
		if preferred_path != "" and candidates.has(preferred_path):
			target_path = preferred_path
	if target_path == "":
		target_path = candidates[randi_range(0, candidates.size() - 1)]
	CombatManager.mission_target_buffs.append({
		"resource_path": target_path,
		"buffs": buffs,
	})

func _launch_battle(battle) -> void:
	_prepare_direct_battle(battle)
	SceneTransition.change_scene_with_fade("res://battle_scene.tscn")

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

## Вступительная миссия не должна наказывать забвением — это ознакомительный бой.
const _FIRST_BATTLE_MISSION_PATH := "res://Missions/First_battle.tres"

func _apply_forgetting_to_selected_heroes() -> void:
	if MissionState.current_mission != null and MissionState.current_mission.resource_path == _FIRST_BATTLE_MISSION_PATH:
		return
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
		SceneTransition.change_scene_with_fade("res://battle_scene.tscn")
		return
	if bool(_res_prop(choice, "launch_battle", false)):
		MissionState.next_scene_after_battle = next_scene
		_apply_mission_location()
		CombatManager.is_mission_battle = true
		_prepare_legacy_direct_battle(formation)
		SceneTransition.change_scene_with_fade("res://battle_scene.tscn")
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

## victory — исход миссии (влияет на надпись «Победа»/«Поражение» и на бонус
## завершения). show_summary=false — тихий выход без итоговых экранов (сейчас
## только при добровольном выходе из миссии кнопкой «Назад»).
func _finish_mission(victory: bool = true, show_summary: bool = true) -> void:
	var return_path := MissionState.return_scene_path.strip_edges()
	if return_path == "":
		return_path = "res://Campaign/campaign_screen.tscn"
	_pending_finish_return_path = return_path
	if MissionState.current_mission != null:
		var finished_mission_path := MissionState.current_mission.resource_path
		MissionState.last_completed_mission_path = finished_mission_path
		if victory and CampaignState.complete_mission(finished_mission_path):
			MissionState.granted_rewards.append({
				"kind": Reward.Kind.CURRENCY,
				"resource_path": CampaignState.THOUGHTS_PATH,
				"amount": CampaignState.MISSION_COMPLETION_THOUGHTS_REWARD,
			})
	if show_summary:
		_show_mission_result_banner(victory)
		return
	_complete_mission_return()
func _grant_and_record_reward(reward_value) -> void:
	var reward := reward_value as Reward
	if reward == null:
		return
	var resolved_resource := reward.resolve_resource()
	if resolved_resource == null:
		return
	reward.grant_resolved(resolved_resource)
	MissionState.record_resolved_reward(reward, resolved_resource)

## Экран-заставка «Победа»/«Поражение» при завершении миссии (см. _finish_mission) —
## первый из итоговых экранов. Клик/тап где угодно закрывает и открывает награды.
func _show_mission_result_banner(victory: bool) -> void:
	if _mission_banner_overlay != null and is_instance_valid(_mission_banner_overlay):
		return
	var overlay := ColorRect.new()
	overlay.name = "MissionResultBanner"
	overlay.color = Color(0.0, 0.0, 0.0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_mission_banner_input)
	add_child(overlay)
	_mission_banner_overlay = overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var banner_path := "res://UI/Victory_Russian.png" if victory else "res://UI/Defeat_Russian.png"
	var img := TextureRect.new()
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(banner_path):
		img.texture = load(banner_path) as Texture2D
	img.custom_minimum_size = Vector2(760, 500)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(img)

	var hint := Label.new()
	hint.text = "Нажмите, чтобы продолжить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)

func _on_mission_banner_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _mission_banner_overlay != null and is_instance_valid(_mission_banner_overlay):
		_mission_banner_overlay.queue_free()
		_mission_banner_overlay = null
	_show_mission_reward_summary()

## Экран статистики миссии — урон нанесён/получен/исцелён за всю миссию по каждому
## богу отряда (MissionState.hero_battle_stats). Последний из итоговых экранов, после
## наград (см. _finish_mission).
func _show_mission_stats_summary() -> void:
	if _mission_stats_overlay != null and is_instance_valid(_mission_stats_overlay):
		return
	var overlay := ColorRect.new()
	overlay.name = "MissionStatsSummary"
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_mission_stats_overlay = overlay

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
	title.text = "Статистика миссии"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 340)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_populate_mission_stats_summary(content)

	var ok_button := Button.new()
	ok_button.text = "Далее"
	ok_button.custom_minimum_size = Vector2(0, 58)
	ok_button.add_theme_font_size_override("font_size", 24)
	ok_button.pressed.connect(_on_mission_stats_continue_pressed)
	root.add_child(ok_button)

func _on_mission_stats_continue_pressed() -> void:
	if _mission_stats_overlay != null and is_instance_valid(_mission_stats_overlay):
		_mission_stats_overlay.queue_free()
		_mission_stats_overlay = null
	_complete_mission_return()

func _populate_mission_stats_summary(content: VBoxContainer) -> void:
	var hero_paths: Array[String] = []
	for hero_path_value in MissionState.selected_heroes:
		var clean_path: String = str(hero_path_value).strip_edges()
		if clean_path != "" and not hero_paths.has(clean_path):
			hero_paths.append(clean_path)
	if hero_paths.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Нет данных"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		content.add_child(empty_label)
		return

	# Максимумы по каждой категории — чтобы полоски были сопоставимы между богами
	# (у кого больше всех урона нанёс — у того полоска полная).
	var max_dealt := 1
	var max_taken := 1
	var max_healed := 1
	for hero_path in hero_paths:
		var entry: Dictionary = MissionState.hero_battle_stats.get(hero_path, {})
		max_dealt = maxi(max_dealt, int(entry.get("dealt", 0)))
		max_taken = maxi(max_taken, int(entry.get("taken", 0)))
		max_healed = maxi(max_healed, int(entry.get("healed", 0)))

	for hero_path in hero_paths:
		var entry: Dictionary = MissionState.hero_battle_stats.get(hero_path, {})
		_add_hero_stats_row(content, hero_path, int(entry.get("dealt", 0)), int(entry.get("taken", 0)), int(entry.get("healed", 0)), max_dealt, max_taken, max_healed)

func _add_hero_stats_row(content: VBoxContainer, hero_path: String, dealt: int, taken: int, healed: int, max_dealt: int, max_taken: int, max_healed: int) -> void:
	var god := CampaignState.load_character_resource(hero_path)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if god != null:
		var face_path: String = str(_res_prop(god, "face_sprite", "")).strip_edges()
		if face_path != "" and ResourceLoader.exists(face_path):
			portrait.texture = load(face_path) as Texture2D
	row.add_child(portrait)

	var bars_col := VBoxContainer.new()
	bars_col.add_theme_constant_override("separation", 4)
	bars_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bars_col)

	var name_label := Label.new()
	name_label.text = str(_res_prop(god, "unit_name", "?")) if god != null else "?"
	name_label.add_theme_font_size_override("font_size", 20)
	bars_col.add_child(name_label)

	_add_stat_bar(bars_col, "Урон нанесён", dealt, max_dealt, Color(0.95, 0.72, 0.15))
	_add_stat_bar(bars_col, "Урон получен", taken, max_taken, Color(0.85, 0.25, 0.2))
	_add_stat_bar(bars_col, "Исцелено", healed, max_healed, Color(0.3, 0.8, 0.35))

func _add_stat_bar(parent: VBoxContainer, label_text: String, value: int, max_value: int, fill_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.17, 0.8)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	row.add_child(value_label)

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
	ok_button.pressed.connect(_on_mission_reward_continue_pressed)
	root.add_child(ok_button)

func _on_mission_reward_continue_pressed() -> void:
	if _mission_reward_overlay != null and is_instance_valid(_mission_reward_overlay):
		_mission_reward_overlay.queue_free()
		_mission_reward_overlay = null
	_show_mission_stats_summary()

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

## BBCode-иконка ресурса (эссенция/мысли) для текста итога вместо текстового названия.
## Пусто, если у ресурса нет иконки — тогда вызывающий код показывает текст как раньше.
func _reward_icon_bbcode(resource: Resource) -> String:
	if resource == null:
		return ""
	var icon_value = _res_prop(resource, "icon", null)
	if icon_value is Texture2D:
		var icon_path: String = (icon_value as Texture2D).resource_path
		if icon_path != "" and ResourceLoader.exists(icon_path):
			return "[img width=24 height=24]%s[/img]" % icon_path
	return ""

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
	if _mission_banner_overlay != null and is_instance_valid(_mission_banner_overlay):
		_mission_banner_overlay.queue_free()
		_mission_banner_overlay = null
	if _mission_reward_overlay != null and is_instance_valid(_mission_reward_overlay):
		_mission_reward_overlay.queue_free()
		_mission_reward_overlay = null
	if _mission_stats_overlay != null and is_instance_valid(_mission_stats_overlay):
		_mission_stats_overlay.queue_free()
		_mission_stats_overlay = null
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
	_finish_mission(false, false)
