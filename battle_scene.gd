extends Node2D

const COMBATANT_VISUAL = preload("res://combatant_visual.tscn")
const STAT_ICON_TOOLTIP_BUTTON_SCRIPT := preload("res://stat_icon_tooltip_button.gd")
const UNIT_DISPLAY = preload("res://unit_display.tscn")
const ENEMY_TURN_DELAY_SEC = 1.2
const MAX_LOG_LINES = 80
const ABILITY_ICON_BUTTON_SIZE := Vector2(58.0, 58.0)
const BOTTOM_UI_MARGIN := 12.0
const BOTTOM_STATUS_STRIP_HEIGHT := 28.0
const ABILITY_BUTTON_GAP := 8.0
const ACTION_BUTTON_SIZE := ABILITY_ICON_BUTTON_SIZE
const HOVER_ABILITY_BUTTON_SIZE := Vector2(44.0, 44.0)
const ENEMY_ABILITY_ICON_PATHS := [
	"res://icons/Enemy_ability_1.png",
	"res://icons/Enemy_ability_2.png",
	"res://icons/Enemy_ability_3.png",
	"res://icons/Enemy_ability_4.png",
	"res://icons/Enemy_ability_5.png",
]
const WAIT_ICON_PATH := "res://Icons/Wait.png"
const END_TURN_ICON_PATH := "res://Icons/End_turn.png"
const STAT_ICON_BBCODE_SIZE := 22
const STAT_ICON_PATHS := {
	"health": "res://Icons/Stats/Health.png",
	"attack": "res://Icons/Stats/Attack.png",
	"armor": "res://Icons/Stats/Armor.png",
	"initiative": "res://Icons/Stats/Initiative.png",
	"accuracy": "res://Icons/Stats/Accuracy.png",
	"evasion": "res://Icons/Stats/Evasion.png",
	"luck": "res://Icons/Stats/Luck.png",
	"glory": "res://Icons/Stats/Glory.png",
	"fantasy": "res://Icons/fantasy_icon.png",
}
const STAT_ICON_TOOLTIPS := {
	"health": "Здоровье",
	"attack": "Атака",
	"armor": "Броня",
	"initiative": "Инициатива",
	"accuracy": "Точность",
	"evasion": "Уклонение",
	"luck": "Удача",
	"glory": "Величие",
	"fantasy": "Фантазия",
}
@onready var ability_panel = $BattleUI/AbilityPanel
@onready var slots = [
	$BattleUI/AbilityPanel/Slot1,
	$BattleUI/AbilityPanel/Slot2,
	$BattleUI/AbilityPanel/Slot3,
	$BattleUI/AbilityPanel/Slot4
]
@onready var slot_ult = $BattleUI/AbilityPanel/SlotUlt
@onready var tactical_button = $BattleUI/AbilityPanel/TacticalButton
@onready var skip_turn_button = $BattleUI/AbilityPanel/SkipTurnButton
@onready var status_label = $BattleUI/StatusLabel
@onready var combat_log_panel: PanelContainer = $BattleUI/CombatLogPanel
@onready var combat_log = $BattleUI/CombatLogPanel/CombatLog


var heroes_team = [null, null, null, null]
var enemies_team = [null, null, null, null]
var hero_visuals = [null, null, null, null]
var enemy_visuals = [null, null, null, null]

var waiting_for_target: bool = false
var _waiting_for_ultimate_target: bool = false
var selected_ability: AbilityResource = null
var selected_mark_position: int = -1  # позиция выбранная для марки

var turn_order = []
var active_unit: Combatant = null
var current_round: int = 1
var waiting_for_player: bool = false
var battle_running: bool = true
var _battle_ending: bool = false  # Предохранитель: возврат в меню запланирован ровно один раз
var wait_counter: int = 0

# Панель информации при наведении на юнита
var _hover_info_panel: PanelContainer
var _hover_label: RichTextLabel
var _hover_content: HBoxContainer
var _hover_ability_grid: GridContainer
var _pinned_hover_unit: Combatant = null

# ═══ Система заклинаний (очки фантазии) ═══
var max_fantasy: int = 20
var current_fantasy: int = 20
var available_spells: Array[SpellResource] = []
var spells_used_this_round: int = 0
var max_spells_per_round: int = 1
var _pending_spell_refund: bool = false  # Вырвать страницу (ур. 2): убийство возвращает использование заклинания
var _spell_panel: Control
var _fantasy_label: Label
var _spell_buttons: Array[Button] = []
var _waiting_for_spell_target: bool = false
var _selected_spell: SpellResource = null
## Если true (см. CombatManager.pending_rum_spell_whole_team) — заклинание «Ром»
## в этом бою применяется не только к выбранной цели, но и ко всей её команде.
var _rum_spell_whole_team_active: bool = false

# ═══ Баннер названия способности/заклинания (крупный текст сверху экрана) ═══
var _ability_banner: Label
var _ability_banner_tween: Tween

# ═══ Полоса очереди ходов вверху экрана (над баннером способности) ═══
var _turn_order_row: HBoxContainer
var _mark_nodes: Array = []
var _ability_actions_row: HBoxContainer
var _combat_log_lines: Array[String] = []
var _combat_log_collapsed: bool = true
var _combat_log_toggle_button: Button = null
var _help_overlay: Control = null
var _help_showing_topic: bool = false

# Позиционные марки вынесены в battle_marks.gd (класс BattleMarks).
# Состояние и логика доступны через объект `marks` (инициализируется в _ready()).
var marks: BattleMarks
# Эффекты локаций вынесены в battle_locations.gd (класс BattleLocations), тем же приёмом.
var locations: BattleLocations
# Общая система баффов/дебаффов (_apply_effect_to_target и т.п.) вынесена в
# battle_effects.gd (класс BattleEffects), тем же приёмом.
var effects: BattleEffects

# ═══ Состояние локационных эффектов ═══
var _is_fog_round: bool = false                  # Хельхейм: текущий раунд туманный
var _bg_sprite: Sprite2D = null                  # Узел бэкграунда (самый нижний слой)
var _bottom_backdrop: ColorRect = null              # Область под полем боя (в цвет интерфейса)
var _bottom_backdrop_border: ColorRect = null       # Золотая полоса-разделитель на верхнем крае
var _swamp_tracked_unit: Combatant = null        # Топь: юнит на первой позиции
var _swamp_consecutive_rounds: int = 0           # Топь: сколько ходов подряд юнит под эффектом локации (для пассивки Водяного)
var _swamp_grace_unit: Combatant = null          # Топь/Утопленница: юнит покинул позицию 1, но дебафф ещё держится
var _swamp_grace_turns_left: int = 0             # Топь/Утопленница: сколько ходов осталось до полного снятия

var _ra_sun_glory_active: bool = false           # Жрец Ра: «Слава солнцу» — урон Пустыни по врагам x2
var _enemy_graveyard: Array = []                 # Погибшие враги (для воскрешения Жрецом Анубиса)
var _hero_graveyard: Array = []                  # Погибшие герои (для воскрешения)
var _heroes_died_this_round: bool = false        # Замок: Рыцарь «Отважный удар»
var _enemies_died_this_round: bool = false       # Замок: Рыцарь «Отважный удар»

func _ready():
	randomize()
	Engine.time_scale = GameSettings.battle_speed
	_combat_log_collapsed = not GameSettings.combat_log_expanded_default
	# Бесконечная библиотека — "Читать книги" даёт постоянный бонус к максимальной фантазии.
	max_fantasy += CampaignState.library_max_fantasy_bonus
	current_fantasy = max_fantasy
	marks = BattleMarks.new(self)
	locations = BattleLocations.new(self)
	effects = BattleEffects.new(self)
	_create_background_node()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_background()
	_spawn_teams_from_resources()
	_connect_ui_buttons()
	_load_spells()
	_setup_hover_info_panel()
	_setup_ability_banner()
	_setup_turn_order_display()
	_setup_settings_button()
	_setup_combat_log_toggle_button()
	# Добавляется последней, чтобы гарантированно оказаться выше полосы очереди ходов
	# и прочих элементов верхней панели при наведении мыши (порядок узлов = порядок хит-теста).
	_setup_location_door_icon()
	if ability_panel:
		_hide_ability_controls()
	current_round = 0
	# Инициализация лимита заклинаний для локации
	max_spells_per_round = 2 if CombatManager.can_cast_two_spells() else 1
	_log_combat("Бой начался!")
	if CombatManager.selected_location_id != "":
		var effect_name = DataTables.get_battle_effect_name(CombatManager.selected_location_id)
		_log_combat("⚔ Локация: %s" % effect_name)
	locations._location_mountains_label()
	_apply_pending_mission_modifiers()
	_start_new_round()


## Возвращает глобальную скорость движка к норме при выходе из боя (см. GameSettings.battle_speed
## в _ready()) — иначе она "утекала" бы в меню и другие экраны после боя/сдачи.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Применяет модификаторы боя миссии (HP%, заряды пассивки, баффы) к врагам и героям.
func _apply_pending_mission_modifiers() -> void:
	_apply_modifier_list(CombatManager.pending_enemy_modifiers, enemies_team)
	_apply_modifier_list(CombatManager.pending_hero_modifiers, heroes_team)
	_apply_pending_mission_party_effects()
	_apply_pending_nemesis_buffs()
	_rum_spell_whole_team_active = CombatManager.pending_rum_spell_whole_team
	CombatManager.pending_rum_spell_whole_team = false
	CombatManager.pending_enemy_modifiers = []
	CombatManager.pending_hero_modifiers = []

## Немезис: если этот бой — против ближайшего непобеждённого немезида выбранной
## локации, применяет все отложенные баффы (CampaignState.pending_nemesis_buffs),
## зарегистрированные для этой пары (локация, бог), и снимает их из очереди —
## это одноразовые сюжетные бонусы, не повторяющиеся на будущих боях.
func _apply_pending_nemesis_buffs() -> void:
	if CampaignState.pending_nemesis_buffs.is_empty():
		return
	var location_id: String = CombatManager.selected_location_id
	if location_id == "":
		return
	var next_nemesis_path := CampaignState.get_next_nemesis_path(location_id)
	if next_nemesis_path == "":
		return
	var fighting_nemesis := false
	for enemy_value in enemies_team:
		var enemy: Combatant = enemy_value as Combatant
		if enemy != null and enemy.source_resource_path == next_nemesis_path:
			fighting_nemesis = true
			break
	if not fighting_nemesis:
		return
	var consumed: Array = []
	for entry_value in CampaignState.pending_nemesis_buffs:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("location_id", "")) != location_id:
			continue
		var god_path: String = str(entry.get("god_path", ""))
		var hero: Combatant = _find_hero_by_resource_path(god_path) if god_path != "" else null
		if hero == null or hero.current_hp <= 0:
			continue
		var majesty_delta: int = int(entry.get("majesty_delta", 0))
		if majesty_delta != 0:
			hero.modify_majesty(majesty_delta)
			_log_combat("✨ [Немезис] %s: %+d величия за грядущую встречу с немезидом." % [hero.unit_name, majesty_delta])
		var buff_stat: int = int(entry.get("buff_stat", -1))
		if buff_stat >= 0:
			_apply_mission_buff({"stat": buff_stat, "value": int(entry.get("buff_value", 0)), "duration": -1}, hero)
			_log_combat("✨ [Немезис] %s получает бафф перед встречей с немезидом." % hero.unit_name)
		consumed.append(entry)
	for entry in consumed:
		CampaignState.pending_nemesis_buffs.erase(entry)


func _apply_pending_mission_party_effects() -> void:
	var heal_percent: int = int(CombatManager.pending_mission_hero_heal_percent)
	if heal_percent != 0:
		for unit_value in heroes_team:
			var hero: Combatant = unit_value as Combatant
			if hero != null and hero.current_hp > 0:
				# Камень с мордочкой: +2% к любому вне-боевому лечению миссии (пляжи, привалы и т.п.).
				var hero_heal_percent := heal_percent
				if hero.has_item_effect("stone_face_bonus_heal"):
					hero_heal_percent += 2
				var heal_amount: int = int(float(hero.max_hp) * float(hero_heal_percent) / 100.0)
				if heal_amount != 0:
					hero.apply_stat_change("hp", heal_amount)
	var majesty_delta: int = int(CombatManager.pending_mission_hero_majesty_delta)
	if majesty_delta != 0:
		for unit_value in heroes_team:
			var hero: Combatant = unit_value as Combatant
			if hero != null and hero.current_hp > 0:
				hero.modify_majesty(majesty_delta)
	var fantasy_delta: int = int(CombatManager.pending_mission_fantasy_delta)
	if fantasy_delta != 0:
		current_fantasy = clampi(current_fantasy + fantasy_delta, 0, max_fantasy)
	for buff in CombatManager.pending_mission_hero_buffs:
		if buff == null:
			continue
		for unit_value in heroes_team:
			var hero: Combatant = unit_value as Combatant
			if hero != null and hero.current_hp > 0:
				_apply_mission_buff(buff, hero)
	for buff in CombatManager.pending_mission_enemy_buffs:
		if buff == null:
			continue
		for unit_value in enemies_team:
			var enemy: Combatant = unit_value as Combatant
			if enemy != null and enemy.current_hp > 0:
				_apply_mission_buff(buff, enemy)
	_apply_pending_mission_target_effects()
	var strongest: Combatant = _get_strongest_attack_hero()
	if strongest != null:
		for buff in CombatManager.mission_strongest_hero_buffs:
			if buff != null:
				_apply_mission_buff(buff, strongest)
	# Баффы на весь отряд, действующие до конца миссии (не очищаются здесь — применяются в каждом бою).
	for buff in CombatManager.mission_team_buffs:
		if buff == null:
			continue
		for unit_value in heroes_team:
			var team_buff_hero: Combatant = unit_value as Combatant
			if team_buff_hero != null and team_buff_hero.current_hp > 0:
				_apply_mission_buff(buff, team_buff_hero)
	# Баффы на конкретных богов, действующие до конца миссии (не очищаются здесь — применяются в каждом бою).
	for entry_value in CombatManager.mission_target_buffs:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var entry_path: String = str(entry.get("resource_path", ""))
		if entry_path == "":
			continue
		var entry_hero: Combatant = _find_hero_by_resource_path(entry_path)
		if entry_hero == null or entry_hero.current_hp <= 0:
			continue
		var entry_raw_buffs = entry.get("buffs", [])
		for buff in (entry_raw_buffs if entry_raw_buffs is Array else []):
			if buff != null:
				_apply_mission_buff(buff, entry_hero)
	CombatManager.pending_mission_hero_heal_percent = 0
	CombatManager.pending_mission_fantasy_delta = 0
	CombatManager.pending_mission_hero_majesty_delta = 0
	CombatManager.pending_mission_hero_buffs = []
	CombatManager.pending_mission_enemy_buffs = []
	CombatManager.pending_mission_target_effects = []

func _apply_pending_mission_target_effects() -> void:
	for effect_value in CombatManager.pending_mission_target_effects:
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		var target_path: String = str(effect.get("resource_path", ""))
		if target_path == "":
			continue
		var target: Combatant = _find_hero_by_resource_path(target_path)
		if target == null or target.current_hp <= 0:
			continue
		var hp_delta: int = int(effect.get("current_hp_percent_delta", 0))
		if hp_delta < 0:
			var damage_amount: int = int(float(target.current_hp) * float(abs(hp_delta)) / 100.0)
			if damage_amount > 0:
				target.apply_stat_change("hp", -damage_amount)
		elif hp_delta > 0:
			var heal_amount: int = int(float(target.max_hp) * float(hp_delta) / 100.0)
			if heal_amount > 0:
				target.apply_stat_change("hp", heal_amount)
		var target_majesty_delta: int = int(effect.get("majesty_delta", 0))
		if target_majesty_delta != 0:
			target.modify_majesty(target_majesty_delta)
		var raw_buffs = effect.get("buffs", [])
		var buffs: Array = raw_buffs if raw_buffs is Array else []
		for buff in buffs:
			if buff != null:
				_apply_mission_buff(buff, target)

func _find_hero_by_resource_path(path: String) -> Combatant:
	for unit_value in heroes_team:
		var hero: Combatant = unit_value as Combatant
		if hero != null and hero.source_resource_path == path:
			return hero
	return null


func _get_strongest_attack_hero() -> Combatant:
	var best: Combatant = null
	var best_damage: int = -999999
	for unit_value in heroes_team:
		var hero: Combatant = unit_value as Combatant
		if hero == null or hero.current_hp <= 0:
			continue
		if hero.damage > best_damage:
			best = hero
			best_damage = hero.damage
	return best


func _apply_modifier_list(mods: Array, team: Array) -> void:
	for m in mods:
		if m == null:
			continue
		var targets: Array = []
		if int(m.target_position) <= 0:
			targets = _get_living_team_members(team)
		else:
			var idx := int(m.target_position) - 1
			if idx >= 0 and idx < team.size() and team[idx] != null and team[idx].current_hp > 0:
				targets = [team[idx]]
		for unit in targets:
			if int(m.max_hp_delta) != 0:
				unit.max_hp = maxi(1, unit.max_hp + int(m.max_hp_delta))
				unit.current_hp = maxi(1, unit.current_hp + int(m.max_hp_delta))
			if int(m.hp_percent) > 0:
				unit.current_hp = maxi(1, int(unit.max_hp * int(m.hp_percent) / 100.0))
			if int(m.passive_charges) >= 0:
				unit.mission_charges = int(m.passive_charges)
			for b in m.buffs:
				if b != null:
					_apply_mission_buff(b, unit)
			if bool(m.disable_passive):
				unit.special_effect_type = ""
			if bool(m.bless_early_transform) and unit.special_effect_type == "novice_transformation":
				unit.special_effect_type = "novice_transformation_blessed"
				_log_combat("✨ [Благословение] %s получает благословение от своего кумира." % unit.unit_name)


## Бафф миссии на юнита (по enum BuffEntry.Stat: 0=урон,1=удача,2=точность,3=уклонение,4=броня,5=крит,6=инициатива,7=стан,8=регенерация,9=периодический урон).
## b — либо ресурс BuffEntry, либо словарь {"stat","value","duration"} (напр. из pending_nemesis_buffs).
func _apply_mission_buff(b, unit: Combatant) -> void:
	var stat: int = int(b.stat) if b is Resource else int(b.get("stat", 0))
	var val: int = int(b.value) if b is Resource else int(b.get("value", 0))
	var dur: int = int(b.duration) if b is Resource else int(b.get("duration", -1))
	var effect_stat: String = "mission_buff"
	match stat:
		0:
			unit.damage_modifier_flat += val
			effect_stat = "damage"
		1:
			unit.crit_modifier += val / 100.0
			effect_stat = "luck"
		2:
			unit.accuracy_modifier += val
			effect_stat = "accuracy"
		3:
			unit.evasion_modifier += val
			effect_stat = "evasion"
		4:
			unit.armor_modifier += val
			effect_stat = "armor"
		5:
			unit.crit_modifier += val / 100.0
			effect_stat = "crit"
		6:
			unit.initiative = maxi(0, unit.initiative + val)
			effect_stat = "initiative"
		7:
			unit.is_stunned = true
			effect_stat = "stun"
		8:
			effect_stat = "regeneration"
		9:
			effect_stat = "periodic_damage"
			var percent_flag: bool = bool(b.percent_of_max_hp) if b is Resource else bool(b.get("percent_of_max_hp", false))
			if percent_flag:
				val = int(unit.max_hp * val / 100.0)
	unit.active_effects.append({"stat": effect_stat, "value": val, "duration": dur, "source_ability": "Заклинание"})

## Обработка правого клика: ВСЕГДА отменяет текущее выделение (способность / заклинание / марка).
func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _handle_help_back():
			get_viewport().set_input_as_handled()
			return
		_cancel_selection()

## Отмена любого текущего выбора и возврат к панели действий игрока.
func _cancel_selection() -> void:
	var had_selection = waiting_for_target or _waiting_for_spell_target or _waiting_for_ultimate_target or selected_mark_position >= 0
	waiting_for_target = false
	_waiting_for_ultimate_target = false
	selected_ability = null
	_waiting_for_spell_target = false
	_selected_spell = null
	selected_mark_position = -1
	if had_selection:
		_update_target_highlights()
	if active_unit and waiting_for_player:
		_show_player_interface(active_unit)
	elif had_selection:
		_set_status("")

## Создаёт кнопку-шестерёнку (верхний левый угол) с меню: «Настройки» и «Сдаться».
func _setup_settings_button():
	var mb = MenuButton.new()
	mb.name = "SettingsButton"
	mb.text = "⚙"
	mb.position = Vector2(8, 2)
	mb.size = Vector2(40, 30)
	mb.z_index = 200
	mb.add_theme_font_size_override("font_size", 22)
	var popup = mb.get_popup()
	popup.add_item("Настройки", 0)
	popup.add_item("Помощь", 1)
	popup.add_item("Загрузить", 3)
	popup.add_item("Сдаться", 2)
	popup.id_pressed.connect(_on_settings_menu_item)
	$BattleUI.add_child(mb)

## Обработка пунктов меню настроек.
func _on_settings_menu_item(id: int) -> void:
	match id:
		0:
			_show_settings_panel()
		1:
			_show_help_topics()
		2:
			_surrender()
		3:
			_show_battle_load_dialog()

func _show_settings_panel() -> void:
	var panel := SettingsPanel.new()
	panel.close_requested.connect(panel.queue_free)
	panel.z_index = 1500
	$BattleUI.add_child(panel)

## Загрузка сохранения прямо из боя: список слотов (как в кампании/главном меню),
## после загрузки — переход на экран кампании (в бою нет смысла обновлять UI на месте).
func _show_battle_load_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.name = "BattleLoadOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.74)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1500
	$BattleUI.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Загрузить сохранение"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(460, 260)
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var slots := SaveSystem.get_save_slots()
	if slots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет сохранений"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 20)
		list.add_child(empty_lbl)
	else:
		for slot_info in slots:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var info_btn := Button.new()
			info_btn.text = "«%s»\n%s | Богов: %d" % [slot_info["slot"], slot_info["timestamp"], slot_info["gods_count"]]
			info_btn.add_theme_font_size_override("font_size", 16)
			info_btn.custom_minimum_size = Vector2(320, 50)
			info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

			var load_btn := Button.new()
			load_btn.text = "Загрузить"
			load_btn.custom_minimum_size = Vector2(110, 50)
			load_btn.add_theme_font_size_override("font_size", 16)

			row.add_child(info_btn)
			row.add_child(load_btn)
			list.add_child(row)

			var slot_name: String = slot_info["slot"]
			var do_load := func():
				var ok := SaveSystem.load_game(slot_name)
				if ok:
					get_tree().change_scene_to_file("res://Campaign/campaign_screen.tscn")
				else:
					push_warning("Не удалось загрузить: " + slot_name)
			load_btn.pressed.connect(do_load)
			info_btn.pressed.connect(load_btn.pressed.emit)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(overlay.queue_free)
	vb.add_child(cancel_btn)

func _help_topics() -> Dictionary:
	return {
		"Кампания": "На экране кампании выбираются разделы, открываются комнаты и запускаются миссии. Правый клик закрывает текущее окно или возвращает назад.",
		"Миссии": "В миссиях выбирается отряд богов, затем проходят сцены. Варианты могут требовать конкретного бога, проверять характеристику, выдавать награды или запускать бой.",
		"Бой": "Бой идет по очереди хода. Выберите способность или заклинание, затем цель. Если нужно отменить выбор, нажмите правую кнопку мыши.",
		"Способности": "Способности богов и врагов имеют позиции применения, цель, стоимость и эффекты. Наведение на кнопку показывает подробное описание.",
		"Заклинания": "Заклинания тратят фантазию. Некоторые доступны только в отдельных локациях. Лимит применений за раунд зависит от правил боя.",
		"Эффекты": "Баффы, дебаффы, стойки и уникальные метки отображаются иконками около персонажа. Наведение на иконку показывает активные эффекты."
	}


func _show_help_topics() -> void:
	_clear_help_overlay()
	_help_showing_topic = false
	_help_overlay = _make_help_overlay()
	var panel := _make_help_panel(_help_overlay)
	var root := _make_help_root(panel)
	var title := Label.new()
	title.text = "Помощь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	var topics := _help_topics()
	for topic_name in topics.keys():
		var btn := Button.new()
		btn.text = str(topic_name)
		btn.custom_minimum_size = Vector2(0, 54)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_show_help_topic.bind(str(topic_name), str(topics[topic_name])))
		root.add_child(btn)
	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(0, 54)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_clear_help_overlay)
	root.add_child(back_btn)


func _show_help_topic(topic_title: String, topic_text: String) -> void:
	_clear_help_overlay()
	_help_showing_topic = true
	_help_overlay = _make_help_overlay()
	var panel := _make_help_panel(_help_overlay)
	var root := _make_help_root(panel)
	var title := Label.new()
	title.text = topic_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = true
	text_label.custom_minimum_size = Vector2(720, 360)
	text_label.add_theme_font_size_override("normal_font_size", 24)
	text_label.text = topic_text
	root.add_child(text_label)
	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(0, 54)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_show_help_topics)
	root.add_child(back_btn)


func _make_help_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "HelpOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.74)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	$BattleUI.add_child(overlay)
	return overlay


func _make_help_panel(parent: Control) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 560)
	center.add_child(panel)
	return panel


func _make_help_root(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	return root


func _handle_help_back() -> bool:
	if _help_overlay == null or not is_instance_valid(_help_overlay):
		return false
	if _help_showing_topic:
		_show_help_topics()
	else:
		_clear_help_overlay()
	return true


func _clear_help_overlay() -> void:
	if _help_overlay != null and is_instance_valid(_help_overlay):
		_help_overlay.queue_free()
	_help_overlay = null
	_help_showing_topic = false


func _setup_combat_log_toggle_button() -> void:
	var ui_layer: Node = get_node_or_null("BattleUI")
	if ui_layer == null:
		return
	if _combat_log_toggle_button == null:
		var existing: Node = get_node_or_null("BattleUI/CombatLogToggleButton")
		if existing is Button:
			_combat_log_toggle_button = existing
		else:
			_combat_log_toggle_button = Button.new()
			_combat_log_toggle_button.name = "CombatLogToggleButton"
			ui_layer.add_child(_combat_log_toggle_button)
	_combat_log_toggle_button.size = Vector2(76.0, 30.0)
	_combat_log_toggle_button.custom_minimum_size = _combat_log_toggle_button.size
	_combat_log_toggle_button.z_index = 220
	_combat_log_toggle_button.focus_mode = Control.FOCUS_NONE
	_combat_log_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_combat_log_toggle_button.add_theme_font_size_override("font_size", 16)
	if not _combat_log_toggle_button.pressed.is_connected(_on_combat_log_toggle_pressed):
		_combat_log_toggle_button.pressed.connect(_on_combat_log_toggle_pressed)
	_apply_combat_log_collapsed_state()

func _on_combat_log_toggle_pressed() -> void:
	_combat_log_collapsed = not _combat_log_collapsed
	_apply_combat_log_collapsed_state()

func _apply_combat_log_collapsed_state() -> void:
	if combat_log_panel:
		combat_log_panel.visible = not _combat_log_collapsed
	if _combat_log_toggle_button:
		_combat_log_toggle_button.text = "Лог +" if _combat_log_collapsed else "Лог -"
		_position_combat_log_toggle_button()

func _position_combat_log_toggle_button() -> void:
	if _combat_log_toggle_button == null:
		return
	if _combat_log_collapsed or combat_log_panel == null:
		_combat_log_toggle_button.position = Vector2(56.0, 2.0)
	else:
		var panel_width: float = combat_log_panel.size.x
		if panel_width <= 0.0:
			panel_width = 400.0
		_combat_log_toggle_button.position = Vector2(combat_log_panel.position.x + panel_width + 8.0, combat_log_panel.position.y)
## Сдаться: немедленно окончить бой и вернуться в главное меню.
func _surrender() -> void:
	if GameSettings.confirm_before_surrender:
		_show_surrender_confirm()
		return
	_do_surrender()

func _do_surrender() -> void:
	battle_running = false
	_log_combat("Игрок сдался. Бой окончен.")
	get_tree().change_scene_to_file("res://main_menu.tscn")

## Диалог подтверждения сдачи (см. GameSettings.confirm_before_surrender).
func _show_surrender_confirm() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1500
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "Сдаться и завершить бой?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var yes_btn := Button.new()
	yes_btn.text = "Сдаться"
	yes_btn.custom_minimum_size = Vector2(140, 44)
	yes_btn.pressed.connect(func():
		overlay.queue_free()
		_do_surrender()
	)
	buttons.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Отмена"
	no_btn.custom_minimum_size = Vector2(140, 44)
	no_btn.pressed.connect(overlay.queue_free)
	buttons.add_child(no_btn)

	$BattleUI.add_child(overlay)
func _create_background_node():
	if has_node("Background"):
		var existing: Node = get_node("Background")
		if existing is Sprite2D:
			_bg_sprite = existing
			_bg_sprite.z_index = -100
			_bg_sprite.centered = false
			_create_bottom_backdrop()
			return
	_bg_sprite = Sprite2D.new()
	_bg_sprite.name = "Background"
	_bg_sprite.z_index = -100
	_bg_sprite.centered = false
	_bg_sprite.position = Vector2.ZERO
	add_child(_bg_sprite)
	move_child(_bg_sprite, 0)
	_create_bottom_backdrop()

func _create_bottom_backdrop() -> void:
	if _bottom_backdrop != null:
		_position_bottom_backdrop()
		return
	if has_node("BottomBlackBackdrop"):
		var root_existing: Node = get_node("BottomBlackBackdrop")
		if root_existing is ColorRect:
			_bottom_backdrop = root_existing
	elif has_node("BattleUI/BottomBlackBackdrop"):
		var ui_existing: Node = get_node("BattleUI/BottomBlackBackdrop")
		if ui_existing is ColorRect:
			_bottom_backdrop = ui_existing
	else:
		_bottom_backdrop = ColorRect.new()
		_bottom_backdrop.name = "BottomBlackBackdrop"
	if _bottom_backdrop.get_parent() != self:
		if _bottom_backdrop.get_parent():
			_bottom_backdrop.get_parent().remove_child(_bottom_backdrop)
		add_child(_bottom_backdrop)
	# Навy — тот же цвет, что и панели остального интерфейса (кампания, Библиотека, Сад, Весы).
	_bottom_backdrop.color = Color(0.09, 0.11, 0.20, 1.0)
	_bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_backdrop.z_index = -90
	if _bottom_backdrop_border == null:
		_bottom_backdrop_border = ColorRect.new()
		_bottom_backdrop_border.name = "BottomBackdropBorder"
	if _bottom_backdrop_border.get_parent() != self:
		if _bottom_backdrop_border.get_parent():
			_bottom_backdrop_border.get_parent().remove_child(_bottom_backdrop_border)
		add_child(_bottom_backdrop_border)
	_bottom_backdrop_border.color = Color(0.83, 0.72, 0.45, 1.0)
	_bottom_backdrop_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_backdrop_border.z_index = -89
	_position_bottom_backdrop()

func _position_bottom_backdrop() -> void:
	if _bottom_backdrop == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var frame_h: float = floor(vp_size.x * BACKGROUND_FRAME_RATIO)
	_bottom_backdrop.position = Vector2(0.0, frame_h)
	_bottom_backdrop.size = Vector2(vp_size.x, maxf(0.0, vp_size.y - frame_h))
	if _bottom_backdrop_border != null:
		_bottom_backdrop_border.position = Vector2(0.0, frame_h)
		_bottom_backdrop_border.size = Vector2(vp_size.x, 2.0)

func _on_viewport_size_changed() -> void:
	_fit_background()
	_position_bottom_backdrop()
	_position_bottom_ui_controls()
	_sync_status_bar_positions()
	_position_hover_info_panel()
	_position_combat_log_toggle_button()

func _apply_background():
	if _bg_sprite == null:
		return
	var bg_path: String = _resolve_location_background_path(CombatManager.selected_background)
	if bg_path == "":
		return
	var tex = load(bg_path)
	if tex:
		_bg_sprite.texture = tex
		_fit_background()

func _resolve_location_background_path(path: String) -> String:
	var cleaned := path.strip_edges()
	if cleaned != "" and ResourceLoader.exists(cleaned):
		return cleaned
	match CombatManager.selected_location_id:
		"helheim": return "res://Background/Helheim.png"
		"hell": return "res://Background/Hell.png"
		"tunnels": return "res://Background/Tunnels.png"
		"clouds": return "res://Background/Clouds.png"
		"stars": return "res://Background/Stars.png"
		"mountains": return "res://Background/Peaks.png"
		"arena": return "res://Background/Arena.png"
		"castle": return "res://Background/Castle.png"
		"desert": return "res://Background/Desert.png"
		"depths": return "res://Background/Deep.png"
		"island": return "res://Background/Islands.png"
		"ships": return "res://Background/Ships.png"
		"jungle": return "res://Background/Jungle.png"
		"garden": return "res://Background/Garden.png"
		"swamp": return "res://Background/Marsh.png"
		"book": return "res://Background/Book_background.png"
		_: return ""
func _swap_background(tex_path: String):
	if _bg_sprite == null:
		return
	if tex_path == "":
		_apply_background()
		return
	var tex = load(tex_path)
	if tex:
		_bg_sprite.texture = tex
		_fit_background()
const BACKGROUND_FRAME_RATIO := 798.0 / 1972.0

func _fit_background():
	if _bg_sprite == null or _bg_sprite.texture == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var tex_w: int = _bg_sprite.texture.get_width()
	var tex_h: int = _bg_sprite.texture.get_height()
	if tex_h <= 0 or tex_w <= 0 or vp_size.x <= 0:
		return
	var frame_w: float = vp_size.x
	var frame_h: float = frame_w * BACKGROUND_FRAME_RATIO
	_bg_sprite.centered = false
	_bg_sprite.position = Vector2.ZERO
	_bg_sprite.scale = Vector2(frame_w / float(tex_w), frame_h / float(tex_h))
	_position_bottom_backdrop()

# ══════════════════════════════════════════════
#  UI: КНОПКИ И СОЕДИНЕНИЯ
# ══════════════════════════════════════════════

func _connect_ui_buttons():
	_setup_ability_slot_buttons()
	for i in range(slots.size()):
		slots[i].pressed.connect(_on_ability_clicked.bind(i))
	slot_ult.pressed.connect(_on_ultimate_clicked)
	tactical_button.pressed.connect(_on_wait_button_pressed)
	skip_turn_button.pressed.connect(_on_skip_turn_pressed)


func _setup_ability_slot_buttons() -> void:
	ability_panel.columns = 5
	ability_panel.add_theme_constant_override("h_separation", int(ABILITY_BUTTON_GAP))
	ability_panel.add_theme_constant_override("v_separation", int(ABILITY_BUTTON_GAP))
	ability_panel.position = Vector2(16.0, _get_bottom_controls_top())
	ability_panel.size = Vector2(ABILITY_ICON_BUTTON_SIZE.x * 5.0 + ABILITY_BUTTON_GAP * 4.0, ABILITY_ICON_BUTTON_SIZE.y)
	for button in slots:
		_apply_ability_button_base_style(button)
	_apply_ability_button_base_style(slot_ult)
	_setup_ability_actions_row()


func _setup_ability_actions_row() -> void:
	if _ability_actions_row == null:
		_ability_actions_row = HBoxContainer.new()
		_ability_actions_row.name = "AbilityActionsRow"
		_ability_actions_row.add_theme_constant_override("separation", int(ABILITY_BUTTON_GAP))
		$BattleUI.add_child(_ability_actions_row)
	_move_button_to_actions_row(tactical_button)
	_move_button_to_actions_row(skip_turn_button)
	_ability_actions_row.position = Vector2(16.0, _get_bottom_controls_top() + ABILITY_ICON_BUTTON_SIZE.y + ABILITY_BUTTON_GAP)
	_ability_actions_row.size = Vector2(ACTION_BUTTON_SIZE.x * 2.0 + ABILITY_BUTTON_GAP, ACTION_BUTTON_SIZE.y)


func _move_button_to_actions_row(button: Button) -> void:
	if button.get_parent() != _ability_actions_row:
		if button.get_parent():
			button.get_parent().remove_child(button)
		_ability_actions_row.add_child(button)
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.size = ACTION_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true


func _set_action_button_icon(button: Button, icon_path: String, fallback_text: String) -> void:
	button.tooltip_text = fallback_text
	if ResourceLoader.exists(icon_path):
		button.icon = load(icon_path) as Texture2D
		button.text = ""
	else:
		button.icon = null
		button.text = fallback_text


func _apply_ability_button_base_style(button: Button) -> void:
	button.custom_minimum_size = ABILITY_ICON_BUTTON_SIZE
	button.size = ABILITY_ICON_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true


func _get_bottom_status_top() -> float:
	return floor(get_viewport_rect().size.x * BACKGROUND_FRAME_RATIO)

func _get_bottom_ui_top() -> float:
	return _get_bottom_status_top() + BOTTOM_UI_MARGIN

func _get_bottom_controls_top() -> float:
	return _get_bottom_status_top() + BOTTOM_STATUS_STRIP_HEIGHT


func _show_ability_controls() -> void:
	ability_panel.show()
	if _ability_actions_row:
		_ability_actions_row.show()


func _hide_ability_controls() -> void:
	ability_panel.hide()
	if _ability_actions_row:
		_ability_actions_row.hide()

func _position_bottom_ui_controls() -> void:
	var controls_top: float = _get_bottom_controls_top()
	if ability_panel:
		ability_panel.position = Vector2(16.0, controls_top)
		ability_panel.size = Vector2(ABILITY_ICON_BUTTON_SIZE.x * 5.0 + ABILITY_BUTTON_GAP * 4.0, ABILITY_ICON_BUTTON_SIZE.y)
	if _ability_actions_row:
		_ability_actions_row.position = Vector2(16.0, controls_top + ABILITY_ICON_BUTTON_SIZE.y + ABILITY_BUTTON_GAP)
		_ability_actions_row.size = Vector2(ACTION_BUTTON_SIZE.x * 2.0 + ABILITY_BUTTON_GAP, ACTION_BUTTON_SIZE.y)

func _spawn_teams_from_resources():
	# Загружаем героев
	for i in range(4):
		var hero_path = CombatManager.selected_heroes[i]
		if hero_path != "":
			var res = CampaignState.load_character_resource(hero_path)
			var hero = Combatant.new(res)
			# load_character_resource() дублирует ресурс (resource.duplicate()), а у
			# дубликата Godot всегда очищает resource_path — из-за этого source_resource_path
			# (выставляемый в Combatant._init() из resource.resource_path) у героев всегда
			# оказывался пустым, что тихо ломало статистику урона/лечения за миссию и поиск
			# героя по пути для баффов немезидов (_find_hero_by_resource_path). Проставляем
			# явно из исходного пути выбора.
			hero.source_resource_path = hero_path
			hero.current_hp = clampi(CampaignState.get_god_current_hp(hero_path), 0, hero.max_hp)
			if CombatManager.is_mission_battle:
				hero.current_majesty = MissionState.get_hero_majesty(hero_path)
			hero.is_enemy = false
			hero.position_index = i
			heroes_team[i] = hero
			hero.damage_taken.connect(_on_unit_damaged.bind(hero))
			hero.healed.connect(_on_unit_healed.bind(hero))
			hero.died.connect(_on_unit_died.bind(hero))
			hero.phoenix_feather_shield_triggered.connect(_on_phoenix_shield_triggered.bind(hero))
			
			var pos_node_name = "HeroPositions/Pos" + str(i + 1)
			if has_node(pos_node_name):
				_create_visual(hero, pos_node_name, hero_visuals, i)
			else:
				push_error("Узел не найден: " + pos_node_name)

	# Загружаем врагов
	for i in range(4):
		var enemy_path = CombatManager.selected_enemies[i]
		if enemy_path != "":
			var res = load(enemy_path) as CharacterResource
			var enemy = Combatant.new(res)
			enemy.is_enemy = true
			enemy.position_index = i
			var _perm_debuff: int = int(CampaignState.permanent_enemy_accuracy_debuffs.get(enemy.unit_name, 0))
			if _perm_debuff != 0:
				enemy.accuracy_modifier += _perm_debuff
			enemies_team[i] = enemy
			enemy.damage_taken.connect(_on_unit_damaged.bind(enemy))
			enemy.died.connect(_on_unit_died.bind(enemy))
			enemy.phoenix_feather_shield_triggered.connect(_on_phoenix_shield_triggered.bind(enemy))
			
			var pos_node_name = "EnemyPositions/Pos" + str(i + 1)
			if has_node(pos_node_name):
				_create_visual(enemy, pos_node_name, enemy_visuals, i)
			else:
				push_error("Узел не найден: " + pos_node_name)
	
	_compact_team(heroes_team)
	_compact_team(enemies_team)
	_trigger_battle_start_passives()
	_apply_kappa_auras()
	_update_all_visuals()

func _trigger_battle_start_passives():
	for hero in heroes_team:
		if hero and hero.special_effect_type == "osiris_majesty_aura":
			# Золотой саркофаг: удваивает величие от пассивки Осириса (15 → 30).
			var _osiris_aura_val = 30 if hero.has_item_effect("osiris_sarcophagus_double_aura") else 15
			_log_combat("✨ [Осирис] Все союзники получают %d величия." % _osiris_aura_val)
			for ally in heroes_team:
				if ally and ally.current_hp > 0:
					ally.modify_majesty(_osiris_aura_val)
	
	# Капитан: все другие союзники получают +2 инициативы
	for unit in enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "captain_ally_initiative":
			for ally in enemies_team:
				if ally and ally.current_hp > 0 and ally != unit:
					ally.initiative += 2
			_log_combat("🏴‍☠️ [Капитан] %s: все союзники получают +2 инициативы." % unit.unit_name)
			break
	
	# Сирена: +10 уклонения за каждого живого союзника
	_apply_siren_evasion_auras()

## Применяет позиционные ауры Каппа к нужному союзнику.
## Вызывается в начале каждого хода и после перемещений.
func _apply_kappa_auras():
	# Сначала сбрасываем все ауры Каппы (они пересчитываются каждый раз)
	for unit in heroes_team + enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "kappa_warrior_aura" or eid == "kappa_shaman_aura":
				var stat = Combatant._effect_get(unit.active_effects[i], "stat", "")
				var val  = Combatant._effect_get(unit.active_effects[i], "value", 0)
				unit.apply_stat_change(stat, -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	
	# Накладываем заново от живых Каппа-юнитов
	for team in [heroes_team, enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			match unit.special_effect_type:
				"kappa_warrior":
					var behind = _get_unit_at_position(team, unit.position_index + 1)
					if behind:
						var aura_val = 10
						behind.apply_stat_change("armor", aura_val)
						behind.active_effects.append({
							"stat": "armor", "value": aura_val,
							"duration": -1, "effect_id": "kappa_warrior_aura"
						})
				"kappa_shaman":
					var front = _get_unit_at_position(team, unit.position_index - 1)
					if front:
						front.apply_stat_change("armor", 10)
						front.active_effects.append({
							"stat": "armor", "value": 10,
							"duration": -1, "effect_id": "kappa_shaman_aura"
						})

func _get_unit_at_position(team: Array, pos: int) -> Combatant:
	if pos < 0 or pos > 3:
		return null
	if team[pos] and team[pos].current_hp > 0:
		return team[pos]
	return null

## Сирена: +10 уклонения за каждого живого союзника (пересчитывается)
func _apply_siren_evasion_auras():
	# Сначала снимаем старые ауры Сирены
	for unit in heroes_team + enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "siren_ally_evasion":
				var val = Combatant._effect_get(unit.active_effects[i], "value", 0)
				unit.apply_stat_change("evasion", -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	
	# Накладываем заново от живых Сирен
	for team in [heroes_team, enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type == "siren_ally_evasion":
				# Считаем количество живых союзников (включая саму Сирену)
				var alive_count = 0
				for ally in team:
					if ally and ally.current_hp > 0:
						alive_count += 1
				var aura_val = alive_count * 10
				unit.apply_stat_change("evasion", aura_val)
				unit.active_effects.append({
					"stat": "evasion", "value": aura_val, "duration": -1,
					"effect_id": "siren_ally_evasion", "source_ability": "Сирена"
				})
				_log_combat("🧜‍♀️ [Сирена] %s: +%d уклонения (%d союзников)." % [unit.unit_name, aura_val, alive_count])
		
## Наставник: все союзники получают +15 точности, пока Наставник жив (пересчитывается)
func _apply_mentor_accuracy_auras():
	# Сначала снимаем старые ауры Наставника
	for unit in heroes_team + enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "mentor_accuracy_aura":
				var val = Combatant._effect_get(unit.active_effects[i], "value", 0)
				unit.apply_stat_change("accuracy", -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	# Накладываем заново от живых Наставников
	for team in [heroes_team, enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type == "mentor_accuracy_aura":
				for ally in team:
					if ally and ally.current_hp > 0:
						ally.apply_stat_change("accuracy", 15)
						ally.active_effects.append({"stat": "accuracy", "value": 15, "duration": -1, "effect_id": "mentor_accuracy_aura", "source_ability": "Наставник"})

## Кентавр: «Подавляющий обстрел» — когда враг начинает ход, получает 0.6 урона от Кентавра
func _trigger_centaur_suppressive_fire(active_unit: Combatant):
	if active_unit == null or active_unit.current_hp <= 0:
		return
	var foe_team = heroes_team if active_unit.is_enemy else enemies_team
	for foe in foe_team:
		if foe == null or foe.current_hp <= 0 or foe.active_stance == null:
			continue
		if foe.active_stance.stance_effect_type == "centaur_suppressive_fire":
			var _sf_dmg = int(foe.damage * 0.6)
			if _sf_dmg > 0:
				var _sf_hp_before = active_unit.current_hp
				active_unit.take_damage(_sf_dmg)
				_log_combat("🏹 [Подавляющий обстрел] %s наносит %d урона %s за действие. HP: %d → %d" % [foe.unit_name, _sf_dmg, active_unit.unit_name, _sf_hp_before, active_unit.current_hp])
				if active_unit.current_hp <= 0:
					_log_combat("  → %s повержен подавляющим обстрелом!" % active_unit.unit_name)
					_on_unit_killed(active_unit)
					var _sf_team = heroes_team if active_unit.is_enemy == false else enemies_team
					_compact_team(_sf_team)
					_apply_kappa_auras()
			break  # срабатывает только один Кентавр за ход

## Оборотень: «Засада» — следующий враг (с точки зрения оборотня), совершивший
## действие, получает 150% урона оборотня. В отличие от «Подавляющего обстрела»
## Кентавра — одноразово: после срабатывания стойка снимается.
func _trigger_oboroten_ambush(active_unit: Combatant):
	if active_unit == null or active_unit.current_hp <= 0:
		return
	var foe_team = heroes_team if active_unit.is_enemy else enemies_team
	for foe in foe_team:
		if foe == null or foe.current_hp <= 0 or foe.active_stance == null:
			continue
		if foe.active_stance.stance_effect_type == "oboroten_ambush":
			var _oa_dmg = int(foe.damage * 1.5)
			if _oa_dmg > 0:
				var _oa_hp_before = active_unit.current_hp
				active_unit.take_damage(_oa_dmg)
				_log_combat("🐺 [Засада] %s наносит %d урона %s (150%% атаки). HP: %d → %d" % [foe.unit_name, _oa_dmg, active_unit.unit_name, _oa_hp_before, active_unit.current_hp])
				if active_unit.current_hp <= 0:
					_log_combat("  → %s повержен засадой оборотня!" % active_unit.unit_name)
					_on_unit_killed(active_unit)
					var _oa_team = heroes_team if not active_unit.is_enemy else enemies_team
					_compact_team(_oa_team)
					_apply_kappa_auras()
			foe.break_stance()
			break  # срабатывает только один оборотень за ход

## Новичок: на 3-м раунде превращается в Гладиатора (позиции 1-2) или Гоплита (позиции 3-4).
## target_type позволяет отдельно триггерить "благословлённых" (novice_transformation_blessed) —
## они превращаются на 2-м раунде, на 1 ход раньше обычных новичков (см. вызов ниже).
func _apply_novice_transformation(target_type: String = "novice_transformation"):
	var _nt_log: Array[String] = []
	for team in [heroes_team, enemies_team]:
		for i in range(team.size()):
			var unit = team[i]
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type != target_type:
				continue
			var pos = unit.position_index
			var form_path: String
			var form_name: String
			if pos <= 1:
				form_path = "res://Enemies/Civilization/Arena/Gladiator/Gladiator.tres"
				form_name = "Гладиатор"
			else:
				form_path = "res://Enemies/Civilization/Arena/Hoplite/Hoplite.tres"
				form_name = "Гоплит"
			var res = load(form_path) as CharacterResource
			if res == null:
				continue
			var new_unit = Combatant.new(res)
			new_unit.is_enemy = unit.is_enemy
			new_unit.position_index = pos
			# +20% HP / урон / точность
			new_unit.max_hp = int(new_unit.max_hp * 1.2)
			new_unit.current_hp = new_unit.max_hp
			new_unit.base_damage = int(new_unit.base_damage * 1.2)
			new_unit.base_accuracy = int(new_unit.base_accuracy * 1.2)
			new_unit.damage_taken.connect(_on_unit_damaged.bind(new_unit))
			new_unit.died.connect(_on_unit_died.bind(new_unit))
			new_unit.phoenix_feather_shield_triggered.connect(_on_phoenix_shield_triggered.bind(new_unit))
			# Удаляем визуал старого Новичка
			_remove_visual_for_unit(unit)
			# Заменяем слот команды
			team[i] = new_unit
			# Создаём визуал новому юниту
			_ensure_visual_for_unit(new_unit)
			_nt_log.append("🔄 [Трансформация] %s (линия %d) превращается в %s (+20%% HP/урон/точность)!" % [unit.unit_name, pos + 1, form_name])
	for line in _nt_log:
		_log_combat(line)
	if not _nt_log.is_empty():
		_apply_kappa_auras()
		_apply_mentor_accuracy_auras()

## Оборотень: начиная с 3-го раунда получает +30 уклонения, +30 удачи, +30 урона (единоразово, до конца боя)
func _apply_oboroten_round3_power():
	for team in [heroes_team, enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type != "oboroten_round3_power":
				continue
			var _already = false
			for e in unit.active_effects:
				if Combatant._effect_get(e, "effect_id", "") == "oboroten_round3_power":
					_already = true
					break
			if _already:
				continue
			unit.apply_stat_change("evasion", 30)
			unit.apply_stat_change("crit", 30)
			unit.apply_stat_change("damage", 30)
			unit.active_effects.append({"stat": "evasion", "value": 30, "duration": -1, "effect_id": "oboroten_round3_power", "source_ability": "Пассивка Оборотня"})
			unit.active_effects.append({"stat": "crit", "value": 30, "duration": -1, "effect_id": "oboroten_round3_power", "source_ability": "Пассивка Оборотня"})
			unit.active_effects.append({"stat": "damage", "value": 30, "duration": -1, "effect_id": "oboroten_round3_power", "source_ability": "Пассивка Оборотня"})
			_log_combat("🐺 [Оборотень] %s: с 3-го раунда +30 уклонения, +30 удачи, +30 урона." % unit.unit_name)

func _create_visual(combatant: Combatant, path: String, visuals_array: Array, index: int):
	var vis = COMBATANT_VISUAL.instantiate()
	get_node(path).add_child(vis)
	vis.setup(combatant)
	vis.unit_clicked.connect(_on_unit_selected)
	vis.unit_hovered.connect(_on_unit_hovered)
	vis.unit_unhovered.connect(_on_unit_unhovered)
	visuals_array[index] = vis

# ══════════════════════════════════════════════
#  ПРИЗЫВ ВАЛУНА (Туннели — Шаман)
# ══════════════════════════════════════════════
func _summon_boulder(summoner: Combatant, log_lines: Array):
	var team = enemies_team if summoner.is_enemy else heroes_team
	var visuals = enemy_visuals if summoner.is_enemy else hero_visuals
	var pos_prefix = "EnemyPositions" if summoner.is_enemy else "HeroPositions"
	var empty_pos = -1
	for i in range(4):
		if team[i] == null:
			empty_pos = i
			break
	if empty_pos == -1:
		log_lines.append("  → Нет свободной позиции для призыва Валуна!")
		return
	var res = load("res://Enemies/Dungeon/Tunnels/Bolder/Bolder.tres") as CharacterResource
	if res == null:
		log_lines.append("  → Ошибка загрузки ресурса Валуна!")
		return
	var boulder = Combatant.new(res)
	boulder.is_enemy = summoner.is_enemy
	boulder.position_index = empty_pos
	team[empty_pos] = boulder
	boulder.damage_taken.connect(_on_unit_damaged.bind(boulder))
	boulder.died.connect(_on_unit_died.bind(boulder))
	boulder.phoenix_feather_shield_triggered.connect(_on_phoenix_shield_triggered.bind(boulder))
	# Постоянная метка провокации
	boulder.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": -1, "effect_id": "provocation_mark", "source_ability": "Валун"})
	# Создать визуал
	var pos_node_name = pos_prefix + "/Pos" + str(empty_pos + 1)
	if has_node(pos_node_name):
		_create_visual(boulder, pos_node_name, visuals, empty_pos)
	_update_all_visuals()
	_recalculate_turn_order()
	log_lines.append("  → [Каменная стена] Призван Валун на позицию %d!" % (empty_pos + 1))

## Артефакт «Красивый камень»: пока есть свободное место в отряде героев, призывает союзного Булыжника.
func _summon_beautiful_stone_boulder() -> void:
	var empty_pos = -1
	for i in range(4):
		if heroes_team[i] == null:
			empty_pos = i
			break
	if empty_pos == -1:
		return
	var res = load("res://Enemies/Dungeon/Tunnels/Bolder/Bolder.tres") as CharacterResource
	if res == null:
		return
	res = res.duplicate()
	res.unit_name = "Булыжник"
	var boulder = Combatant.new(res)
	boulder.is_enemy = false
	boulder.position_index = empty_pos
	heroes_team[empty_pos] = boulder
	boulder.damage_taken.connect(_on_unit_damaged.bind(boulder))
	boulder.died.connect(_on_unit_died.bind(boulder))
	boulder.phoenix_feather_shield_triggered.connect(_on_phoenix_shield_triggered.bind(boulder))
	boulder.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": -1, "effect_id": "provocation_mark", "source_ability": "Красивый камень"})
	var pos_node_name = "HeroPositions/Pos" + str(empty_pos + 1)
	if has_node(pos_node_name):
		_create_visual(boulder, pos_node_name, hero_visuals, empty_pos)
	_update_all_visuals()
	_recalculate_turn_order()
	_log_combat("🪨 [Красивый камень] Призван союзный Булыжник на позицию %d!" % (empty_pos + 1))

# ══════════════════════════════════════════════
#  РАУНДЫ И ОЧЕРЕДЬ ХОДОВ
# ══════════════════════════════════════════════

func _start_new_round():
	if _check_battle_end():
		return


	# ═══ Туннели — Шаман: +20 брони, если не перемещался в прошлом раунде ═══
	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "shaman_no_move_armor":
			if current_round > 0 and not unit.moved_this_round:
				unit.apply_stat_change("armor", 20)
				unit.active_effects.append({"stat": "armor", "value": 20, "duration": 1, "effect_id": "shaman_no_move_armor", "source_ability": "Пассивка"})
				_log_combat("🛡️ [Каменная кожа] %s: +20 брони за отсутствие перемещений." % unit.unit_name)
	
	# ═══ Звёзды — Водолей: если не перемещался в прошлом раунде — +15 урона (навсегда) ═══
	for unit_aq in heroes_team + enemies_team:
		if unit_aq and unit_aq.current_hp > 0 and unit_aq.special_effect_type == "aquarius_no_move_attack":
			if current_round > 0 and not unit_aq.moved_this_round:
				effects._apply_buff_to_unit(unit_aq, "damage", 15, -1, "aquarius_no_move_attack", "Пассивка")
				_log_combat("💧 [Водолей] %s: +15 урона за отсутствие перемещений (навсегда)." % unit_aq.unit_name)

	# ═══ Сад — Альрауне: каждый ход восстанавливает 30% здоровья; периодический урон отключает пассивку ═══
	for unit_ar in heroes_team + enemies_team:
		if unit_ar and unit_ar.current_hp > 0 and unit_ar.special_effect_type == "alraune_regen":
			var _ar_poisoned = false
			for _ar_e in unit_ar.active_effects:
				if Combatant._effect_get(_ar_e, "stat", "") == "periodic_damage":
					_ar_poisoned = true
					break
			if _ar_poisoned:
				continue
			var _ar_heal = int(unit_ar.max_hp * 0.30)
			if _ar_heal > 0:
				var _ar_hp_b = unit_ar.current_hp
				unit_ar.apply_stat_change("hp", _ar_heal)
				_log_combat("🌿 [Альрауне] %s восстанавливает %d HP (%d → %d)." % [unit_ar.unit_name, _ar_heal, _ar_hp_b, unit_ar.current_hp])

	# ═══ Сад — Друид: в начале раунда все союзники восстанавливают 5% здоровья ═══
	for unit_dr in heroes_team + enemies_team:
		if unit_dr and unit_dr.current_hp > 0 and unit_dr.special_effect_type == "druid_regen_aura":
			var _dr_team = enemies_team if unit_dr.is_enemy else heroes_team
			for _dr_ally in _dr_team:
				if _dr_ally and _dr_ally.current_hp > 0:
					var _dr_heal = int(_dr_ally.max_hp * 0.05)
					if _dr_heal > 0:
						_dr_ally.apply_stat_change("hp", _dr_heal)
			_log_combat("🌻 [Друид] %s: все союзники восстанавливают 5%% HP." % unit_dr.unit_name)

	# ═══ Сад — Сатир: «Чарующая песня» — в начале раунда эффект дебаффа растёт на 5 ═══
	for unit_st in heroes_team + enemies_team:
		if unit_st and unit_st.current_hp > 0 and unit_st.active_stance and unit_st.active_stance.stance_effect_type == "satyr_charm":
			var _st_stacks = unit_st.get_meta("satyr_charm_stacks", 0) + 5
			unit_st.set_meta("satyr_charm_stacks", _st_stacks)
			var _st_foe_team = heroes_team if unit_st.is_enemy else enemies_team
			for _st_foe in _st_foe_team:
				if _st_foe and _st_foe.current_hp > 0:
					_st_foe.apply_stat_change("damage", -5)
					_st_foe.active_effects.append({"stat": "damage", "value": -5, "duration": -1, "effect_id": "satyr_charm", "source_ability": "Чарующая песня"})
					# Локация «Сад»: при дебаффе на героя — +15 чистого урона (как у обычных дебаффов).
					if CombatManager.selected_location_id == "garden" and not _st_foe.is_enemy:
						var _st_g_hp = _st_foe.current_hp
						_st_foe.take_damage(15)
						_log_combat("  → [Сад] %s получает 15 чистого урона за дебафф песни. HP: %d → %d" % [_st_foe.unit_name, _st_g_hp, _st_foe.current_hp])
				_log_combat("🎵 [Чарующая песня] %s: враги теряют ещё 5 атаки (всего -%d)." % [unit_st.unit_name, _st_stacks])

	# ═══ Предметы: пассивная регенерация фантазии в начале раунда ═══
	var _item_fantasy_regen: int = 0
	for hero_it in heroes_team:
		if hero_it and hero_it.current_hp > 0:
			for item_it in hero_it.get_equipped_items():
				_item_fantasy_regen += item_it.fantasy_regen_per_turn
	if _item_fantasy_regen != 0:
		var _fantasy_before: int = current_fantasy
		current_fantasy = clampi(current_fantasy + _item_fantasy_regen, 0, max_fantasy)
		if current_fantasy != _fantasy_before:
			_log_combat("✨ [Артефакты] Восстановление фантазии: %+d (%d → %d)." % [_item_fantasy_regen, _fantasy_before, current_fantasy])

	# ═══ Предметы: пассивная регенерация величия и HP в начале раунда ═══
	for hero_reg in heroes_team:
		if hero_reg == null or hero_reg.current_hp <= 0:
			continue
		var _item_majesty_regen: int = 0
		var _item_hp_regen_pct: float = 0.0
		for item_reg in hero_reg.get_equipped_items():
			_item_majesty_regen += item_reg.majesty_regen_per_turn
			_item_hp_regen_pct += item_reg.hp_regen_percent
		if _item_majesty_regen != 0:
			var _majesty_before: int = hero_reg.current_majesty
			hero_reg.modify_majesty(_item_majesty_regen)
			if hero_reg.current_majesty != _majesty_before:
				_log_combat("✨ [Артефакт] %s: величие %+d (%d → %d)." % [hero_reg.unit_name, _item_majesty_regen, _majesty_before, hero_reg.current_majesty])
		if _item_hp_regen_pct != 0.0:
			var _hp_regen_amount = int(hero_reg.max_hp * _item_hp_regen_pct / 100.0)
			if _hp_regen_amount > 0:
				var _hp_before_reg = hero_reg.current_hp
				hero_reg.apply_stat_change("hp", _hp_regen_amount)
				if hero_reg.current_hp != _hp_before_reg:
					_log_combat("✨ [Артефакт] %s восстанавливает %d HP (%d → %d)." % [hero_reg.unit_name, _hp_regen_amount, _hp_before_reg, hero_reg.current_hp])

	# ═══ Артефакт «Красивый камень»: свободное место в отряде героев — призыв Булыжника ═══
	for hero_bs in heroes_team:
		if hero_bs and hero_bs.current_hp > 0 and hero_bs.has_item_effect("beautiful_stone_summon_boulder"):
			_summon_beautiful_stone_boulder()
			break

	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0:
			unit.start_new_round()

	# Тик марок: сбрасываем triggered_units, уменьшаем rounds_left
	marks.tick()
	_apply_kappa_auras()
	_apply_siren_evasion_auras()
	_apply_mentor_accuracy_auras()
	
	# Шива: в начале раунда базовая удача принимает случайное значение от 0 до 30%
	# (Дамару поднимает верхнюю границу до 50%)
	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "shiva_random_luck":
			var _shiva_cap = 0.50 if unit.has_item_effect("shiva_damaru_luck_cap_50") else 0.30
			unit.base_crit_chance = randf() * _shiva_cap
			_log_combat("🎲 [Шива] %s: удача установлена на %d%%" % [unit.unit_name, int(unit.base_crit_chance * 100)])
	
	# ═══ АД — Страдающая душа: на позиции 1 получает +4 инициативы и +20 уклонения ═══
	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "soul_position_buff":
			if unit.position_index == 0:
				unit.apply_stat_change("initiative", 4)
				unit.apply_stat_change("evasion", 20)
				unit.active_effects.append({"stat": "initiative", "value": 4, "duration": 1, "effect_id": "soul_position", "source_ability": "Пассивка"})
				unit.active_effects.append({"stat": "evasion", "value": 20, "duration": 1, "effect_id": "soul_position", "source_ability": "Пассивка"})
				_log_combat("👻 [Страдающая душа] %s на позиции 1: +4 инициативы, +20 уклонения." % unit.unit_name)
	
	# ═══ ДЖУНГЛИ — Ракшас: пока жив, все противники теряют 10 удачи (aura) ═══
	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "rakshasa_crit_aura":
			var _ra_foes = heroes_team if unit.is_enemy else enemies_team
			for _ra_f in _ra_foes:
				if _ra_f != null and _ra_f.current_hp > 0:
					_ra_f.apply_stat_change("crit", -10)
					_ra_f.active_effects.append({"stat": "crit", "value": -10, "duration": 1, "effect_id": "rakshasa_aura", "source_ability": "Пассивка Ракшас"})
	# ═══ ДЖУНГЛИ — Ракшас: «Дисгармония» стойка — противники -10 удачи -10 точности пока активна ═══
	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0 and unit.active_stance != null and unit.active_stance.stance_effect_type == "rakshasa_disharmony":
			var _dh_foes = heroes_team if unit.is_enemy else enemies_team
			for _dh_f in _dh_foes:
				if _dh_f != null and _dh_f.current_hp > 0:
					_dh_f.apply_stat_change("crit", -10)
					_dh_f.apply_stat_change("accuracy", -10)
					_dh_f.active_effects.append({"stat": "crit", "value": -10, "duration": 1, "effect_id": "rakshasa_disharmony", "source_ability": "Дисгармония"})
					_dh_f.active_effects.append({"stat": "accuracy", "value": -10, "duration": 1, "effect_id": "rakshasa_disharmony", "source_ability": "Дисгармония"})
	# ═══ Асура: сброс временного переопределения удачи (asura_chaos) по истечении ═══
	for unit in heroes_team + enemies_team:
		if unit != null and unit.has_meta("asura_chaos_crit_turns"):
			var _ac_t = int(unit.get_meta("asura_chaos_crit_turns", 0)) - 1
			if _ac_t <= 0:
				unit.remove_meta("asura_chaos_crit_override")
				unit.remove_meta("asura_chaos_crit_turns")
			else:
				unit.set_meta("asura_chaos_crit_turns", _ac_t)

	# ═══ Замок — Мистический шут: +1% удачи за каждую недостающую единицу фантазии ═══
	for unit in heroes_team + enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "jester_fantasy_luck":
			# Удалить старый бонус удачи
			for _ji in range(unit.active_effects.size() - 1, -1, -1):
				if Combatant._effect_get(unit.active_effects[_ji], "effect_id", "") == "jester_fantasy_luck":
					var _old_val = Combatant._effect_get(unit.active_effects[_ji], "value", 0)
					unit.crit_modifier -= float(_old_val) / 100.0
					unit.active_effects.remove_at(_ji)
			var _missing_fantasy = maxi(0, max_fantasy - current_fantasy)
			if _missing_fantasy > 0:
				unit.apply_stat_change("crit", _missing_fantasy)
				unit.active_effects.append({"stat": "crit", "value": _missing_fantasy, "duration": -1, "effect_id": "jester_fantasy_luck", "source_ability": "jester_fantasy_luck"})
				_log_combat("🃏 [Шут] %s: +%d%% удачи за %d недостающей фантазии." % [unit.unit_name, _missing_fantasy, _missing_fantasy])
	
	# Сброс отслеживания смертей (Замок: Рыцарь «Отважный удар»)
	_heroes_died_this_round = false
	_enemies_died_this_round = false
	# Сброс заклинаний
	spells_used_this_round = 0
	max_spells_per_round = 2 if CombatManager.can_cast_two_spells() else 1
	
	wait_counter = 0
	current_round += 1
	# Новичок: благословлённый (метка Арены) превращается на 1 ход раньше обычного.
	if current_round == 2:
		_apply_novice_transformation("novice_transformation_blessed")
	# Новичок: на 3-м раунде превращается в Гладиатора/Гоплита
	if current_round == 3:
		_apply_novice_transformation()
		_apply_oboroten_round3_power()
	_build_turn_order()
	
	if turn_order.is_empty():
		return
	
	_log_combat("--- Раунд %d ---" % current_round)
	
	# ═══ ЭФФЕКТЫ ЛОКАЦИЙ (начало раунда) ═══
	locations._location_helheim()
	locations._location_hell()
	locations._location_tunnels()
	locations._location_desert()
	locations._location_stars()
	locations._location_depths_label()
	locations._location_island()
	locations._location_swamp()
	_update_all_visuals()
	
	if _check_battle_end():
		return
	
	call_deferred("_next_turn")

func _build_turn_order():
	turn_order.clear()
	for u in heroes_team + enemies_team:
		if u and u.current_hp > 0:
			turn_order.append(u)
	turn_order.sort_custom(func(a, b): return a.initiative > b.initiative)

func _recalculate_turn_order():
	_build_turn_order()
	turn_order = turn_order.filter(func(u): return not u.has_acted_this_round)

var _duna_turn_heal: int = 0

func _next_turn():
	if waiting_for_player or not battle_running:
		return
	
	while turn_order.size() > 0:
		var next_unit = turn_order[0]
		if next_unit == null or next_unit.current_hp <= 0 or next_unit.has_acted_this_round:
			turn_order.pop_front()
		else:
			break
	
	if turn_order.is_empty():
		if _check_battle_end():
			return
		_start_new_round()
		return
	
	active_unit = turn_order.pop_front()
	_duna_turn_heal = 0
	
	if active_unit.current_hp <= 0:
		call_deferred("_next_turn")
		return
	
	# ═══ Угорь: метка челюсти — отложенная атака 100% в начале след. хода ═══
	if active_unit.jaw_mark_target != null:
		var _jm_target = active_unit.jaw_mark_target
		active_unit.jaw_mark_target = null
		if _jm_target and _jm_target.current_hp > 0 and active_unit.current_hp > 0:
			var _jm_dmg = active_unit.damage
			var _jm_hp_b = _jm_target.current_hp
			_jm_target.take_damage(_jm_dmg)
			_log_combat("🦈 [Метка челюсти] %s наносит %d урона %s. HP: %d → %d" % [active_unit.unit_name, _jm_dmg, _jm_target.unit_name, _jm_hp_b, _jm_target.current_hp])
			if _jm_target.current_hp <= 0:
				_log_combat("  → %s повержен меткой челюсти!" % _jm_target.unit_name)
				_on_unit_killed(_jm_target)
				var _jm_team = heroes_team if not _jm_target.is_enemy else enemies_team
				_compact_team(_jm_team)
	
	# === Стойка с эффектом: проверяем stance_effect_type ===
	if active_unit.active_stance != null:
		var set = active_unit.active_stance.stance_effect_type
		if set == "thunder_wrath":
			_trigger_thunder_wrath(active_unit)
			active_unit.break_stance()
		elif set == "indigo_hunt_stance":
			_trigger_indigo_hunt_stance(active_unit)
			active_unit.break_stance()
		elif set == "filibuster_double_hit":
			_trigger_filibuster_double_hit(active_unit)
			active_unit.break_stance()
		elif set == "bombardment_stance":
			_trigger_bombardment_stance(active_unit)
			active_unit.break_stance()
		elif set == "set_true_king":
			_trigger_set_true_king(active_unit)
			active_unit.break_stance()
		elif set == "loki_ragnarok":
			_trigger_loki_ragnarok(active_unit)
			active_unit.break_stance()
		elif set == "koschei_immortal":
			# Бафф (броня + провокация) ставится при касте и держится, пока активна стойка;
			# снимается в combatant.break_stance().
			active_unit.break_stance()
		elif set == "odin_foresight":
			# Не прерываем стойку — баффы обновляются каждый ход, пока её не собьют движением/станом.
			_refresh_odin_foresight_aura(active_unit)
		elif set == "oni_flaming_rain":
			_trigger_oni_flaming_rain(active_unit)
			active_unit.break_stance()
		elif set == "titan_indestructible":
			active_unit.break_stance()
		elif set == "titan_born_to_battle":
			_trigger_titan_born_to_battle(active_unit)
			active_unit.break_stance()
		elif set == "immortal_my_battle_not_over":
			_trigger_immortal_my_battle_not_over(active_unit)
			active_unit.break_stance()
		elif set == "sphinx_statue_form":
			_trigger_sphinx_statue_form(active_unit)
			active_unit.break_stance()
		elif set == "scarab_bury_in_sand":
			_trigger_scarab_bury_in_sand(active_unit)
			active_unit.break_stance()
		elif set == "ra_sun_glory":
			_trigger_ra_sun_glory(active_unit)
			active_unit.break_stance()
		elif set == "nightmare_unforgettable":
			# Кошмар: в начале след хода получает щит от смерти (эффект на 1 ход)
			active_unit.active_effects.append({"stat": "invulnerable", "value": 0, "duration": 1, "effect_id": "nightmare_death_shield", "source_ability": "Незабываемый"})
			_log_combat("😈 [Кошмар] %s: щит от смерти активирован на 1 ход." % active_unit.unit_name)
			active_unit.break_stance()
		elif set == "lava_boar_heart":
			# Восстановление 10% HP + увеличение отскока пассивки на 5%
			var _lb_heal = int(active_unit.max_hp * 0.10)
			if _lb_heal > 0:
				var _lb_hp_before = active_unit.current_hp
				active_unit.apply_stat_change("hp", _lb_heal)
				_log_combat("🔥 [Горячее сердце] %s восстанавливает %d HP (%d → %d)." % [active_unit.unit_name, _lb_heal, _lb_hp_before, active_unit.current_hp])
			var _warm_stacks = 0
			for e in active_unit.active_effects:
				if Combatant._effect_get(e, "effect_id", "") == "lava_boar_warm_heart_stack":
					_warm_stacks += 1
			active_unit.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "lava_boar_warm_heart_stack"})
			_log_combat("🔥 [Горячее сердце] %s: отражение урона усилено (%d%%)." % [active_unit.unit_name, 10 + _warm_stacks * 5 + 5])
			active_unit.break_stance()
		elif set == "kirin_lightning_dodge":
			# +1 инициатива навсегда
			active_unit.apply_stat_change("initiative", 1)
			active_unit.active_effects.append({"stat": "initiative", "value": 1, "duration": -1, "effect_id": "kirin_lightning_init", "source_ability": "kirin_lightning_fast"})
			_log_combat("⚡ [Быстрый как молния] %s: +1 инициативы (итого %d)." % [active_unit.unit_name, active_unit.initiative])
			active_unit.break_stance()
		elif set == "novice_training":
			active_unit.break_stance()
		elif set == "hoplite_shield_wall":
			active_unit.break_stance()
		elif set == "centaur_suppressive_fire":
			active_unit.break_stance()
		elif set == "sea_power_stance":
			var _sp_team = enemies_team if active_unit.is_enemy else heroes_team
			for _sp_ally in _sp_team:
				if _sp_ally and _sp_ally.current_hp > 0:
					_sp_ally.apply_stat_change("damage", 20)
					_sp_ally.active_effects.append({"stat": "damage", "value": 20, "duration": 1, "effect_id": "sea_power_buff", "source_ability": "Сила моря"})
			_log_combat("🌊 [Сила моря] Все союзники %s: +20 урона на 1 ход." % active_unit.unit_name)
			active_unit.break_stance()
		elif set == "warrior_of_day_stance":
			active_unit.apply_stat_change("max_hp", 10)
			active_unit.current_hp += 10
			active_unit.apply_stat_change("armor", 10)
			active_unit.active_effects.append({"stat": "armor", "value": 10, "duration": 3, "effect_id": "warrior_of_day_armor", "source_ability": "Воин дня"})
			active_unit.apply_stat_change("evasion", 10)
			active_unit.active_effects.append({"stat": "evasion", "value": 10, "duration": 3, "effect_id": "warrior_of_day_evasion", "source_ability": "Воин дня"})
			_log_combat("☀ [Воин дня] %s: +10 макс. HP, +10 брони и +10 уклонения на 3 хода." % active_unit.unit_name)
			active_unit.break_stance()
		elif set == "warrior_of_night_stance":
			active_unit.apply_stat_change("damage", 10)
			active_unit.active_effects.append({"stat": "damage", "value": 10, "duration": 3, "effect_id": "warrior_of_night_damage", "source_ability": "Воин ночи"})
			active_unit.apply_stat_change("accuracy", 10)
			active_unit.active_effects.append({"stat": "accuracy", "value": 10, "duration": 3, "effect_id": "warrior_of_night_accuracy", "source_ability": "Воин ночи"})
			active_unit.apply_stat_change("crit", 10)
			active_unit.active_effects.append({"stat": "crit", "value": 10, "duration": 3, "effect_id": "warrior_of_night_crit", "source_ability": "Воин ночи"})
			_log_combat("🌙 [Воин ночи] %s: +10 урона, +10 точности и +10 удачи на 3 хода." % active_unit.unit_name)
			active_unit.break_stance()
		elif set == "pegasus_arrow_rain":
			var _ar_foe_team = heroes_team if active_unit.is_enemy else enemies_team
			for _ar_foe in _ar_foe_team:
				if _ar_foe and _ar_foe.current_hp > 0:
					var _ar_dmg = int(active_unit.damage * 0.8)
					var _ar_hp_b = _ar_foe.current_hp
					_ar_foe.take_damage(_ar_dmg)
					_log_combat("🏹 [Дождь стрел] %s наносит %d урона %s. HP: %d → %d" % [active_unit.unit_name, _ar_dmg, _ar_foe.unit_name, _ar_hp_b, _ar_foe.current_hp])
			active_unit.break_stance()
		# ═══ Замок — Шут: «Смертельный удар» — атака случайного врага на 60% HP ═══
		elif set == "jester_deadly_strike":
			var _ds_foe_team = heroes_team if active_unit.is_enemy else enemies_team
			var _ds_targets: Array = []
			for _ds_foe in _ds_foe_team:
				if _ds_foe and _ds_foe.current_hp > 0:
					_ds_targets.append(_ds_foe)
			if not _ds_targets.is_empty():
				var _ds_target = _ds_targets.pick_random()
				var _ds_dmg = int(_ds_target.current_hp * 0.6)
				var _ds_hp_b = _ds_target.current_hp
				_ds_target.take_damage(_ds_dmg)
				_log_combat("🃏 [Смертельный удар] %s наносит %d урона %s (60%% текущего HP). HP: %d → %d" % [active_unit.unit_name, _ds_dmg, _ds_target.unit_name, _ds_hp_b, _ds_target.current_hp])
				if _ds_target.current_hp <= 0:
					_log_combat("  → %s повержен смертельным ударом!" % _ds_target.unit_name)
					_ds_target.killed_by = active_unit
					_on_unit_killed(_ds_target)
					var _ds_team = heroes_team if not _ds_target.is_enemy else enemies_team
					_compact_team(_ds_team)
			active_unit.break_stance()
		# ═══ Замок — Волшебник: «Армагеддон» — 0.8 урона всем остальным юнитам ═══
		elif set == "wizard_armageddon":
			for _ag_unit in heroes_team + enemies_team:
				if _ag_unit and _ag_unit.current_hp > 0 and _ag_unit != active_unit:
					var _ag_dmg = int(active_unit.damage * 0.8)
					var _ag_hp_b = _ag_unit.current_hp
					_ag_unit.take_damage(_ag_dmg)
					_log_combat("☄️ [Армагеддон] %s наносит %d урона %s. HP: %d → %d" % [active_unit.unit_name, _ag_dmg, _ag_unit.unit_name, _ag_hp_b, _ag_unit.current_hp])
					if _ag_unit.current_hp <= 0:
						_log_combat("  → %s повержён Армагеддоном!" % _ag_unit.unit_name)
						_ag_unit.killed_by = active_unit
						_on_unit_killed(_ag_unit)
						var _ag_team = heroes_team if not _ag_unit.is_enemy else enemies_team
						_compact_team(_ag_team)
			active_unit.break_stance()
		# ═══ Замок — простые UntilNextTurn стойки: просто сброс ═══
		elif set == "princess_in_trouble":
			active_unit.break_stance()
		elif set == "knight_magic_supremacy":
			active_unit.break_stance()
		elif set == "guardsman_halt":
			active_unit.break_stance()
		# ═══ Туннели — Дварф-кузнец: «Ковать железо» — жетон ковки ═══
		elif set == "smith_forge":
			var _forge_tokens = active_unit.get_meta("smith_forge_tokens", 0) + 1
			active_unit.set_meta("smith_forge_tokens", _forge_tokens)
			_log_combat("🔨 [Ковать железо] %s: получен жетон ковки (всего: %d)." % [active_unit.unit_name, _forge_tokens])
			active_unit.break_stance()
		# ═══ Туннели — Великан воин: «Обрушить потолок» — 0.7 урона всем врагам + -10 брони ═══
		elif set == "giant_ceiling":
			var _gc_foe_team = heroes_team if active_unit.is_enemy else enemies_team
			for _gc_foe in _gc_foe_team:
				if _gc_foe and _gc_foe.current_hp > 0:
					var _gc_dmg = int(active_unit.damage * 0.7)
					var _gc_hp_b = _gc_foe.current_hp
					_gc_foe.take_damage(_gc_dmg)
					_log_combat("⛰️ [Обрушить потолок] %s наносит %d урона %s. HP: %d → %d" % [active_unit.unit_name, _gc_dmg, _gc_foe.unit_name, _gc_hp_b, _gc_foe.current_hp])
					_gc_foe.apply_stat_change("armor", -10)
					_gc_foe.active_effects.append({"stat": "armor", "value": -10, "duration": -1, "effect_id": "giant_ceiling_armor", "source_ability": "Обрушить потолок"})
					if _gc_foe.current_hp <= 0:
						_log_combat("  → %s повержен обрушенным потолком!" % _gc_foe.unit_name)
						_gc_foe.killed_by = active_unit
						_on_unit_killed(_gc_foe)
						var _gc_team = heroes_team if not _gc_foe.is_enemy else enemies_team
						_compact_team(_gc_team)
			active_unit.break_stance()
		
		# === Кентавр: «Подавляющий обстрел» — враг получивший ход, получает урон ===
	_trigger_centaur_suppressive_fire(active_unit)
	if active_unit.current_hp <= 0:
		call_deferred("_next_turn")
		return

	# === Оборотень: «Засада» — следующий враг, совершивший действие, получает урон ===
	_trigger_oboroten_ambush(active_unit)
	if active_unit.current_hp <= 0:
		call_deferred("_next_turn")
		return
	
	# === Марки: срабатывание "once" в начале хода владельца ===
	marks.trigger_once_for_caster(active_unit)
	
	# === Марки: срабатывание "persistent" в начале хода юнита стоящего на марке ===
	marks.trigger_persistent_for_unit(active_unit)
	
	# === Neverending Storm: удар 60% за каждую метку в начале хода ===
	_trigger_storm_marks(active_unit)
	
	# === Посейдон: лечение за каждый уникальный бафф в начале хода ===
	if active_unit.special_effect_type == "poseidon_buff_heal":
		_trigger_poseidon_heal(active_unit)

	# ═══ Перо феникса: -5% максимального здоровья в начале хода носителя ═══
	if active_unit.has_item_effect("phoenix_feather") and active_unit.current_hp > 0:
		var _pf_dmg = int(active_unit.max_hp * 0.05)
		if _pf_dmg > 0:
			var _pf_hp_b = active_unit.current_hp
			active_unit.take_damage(_pf_dmg)
			_log_combat("🔥 [Перо феникса] %s теряет %d HP в начале хода (%d → %d)." % [active_unit.unit_name, _pf_dmg, _pf_hp_b, active_unit.current_hp])

	# Марки могли убить владельца хода (например, персистентная марка на его позиции)
	# ещё до того, как ему дали действовать — без этой проверки waiting_for_player
	# взводился бы для уже мёртвого юнита, и все следующие ходы молча блокировались бы.
	if active_unit.current_hp <= 0:
		call_deferred("_next_turn")
		return

	# Подсветка HP-бара юнита, чей сейчас ход.
	_update_active_highlight()

	if active_unit.is_stunned:
		_log_combat("%s оглушён и пропускает ход." % active_unit.unit_name)
		call_deferred("_finish_unit_turn", active_unit)
		return

	# Снимок эффектов на начало хода: эффекты, наложенные на себя в этом ходе,
	# не должны терять длительность за ход наложения (правило «ход наложения не считается»).
	active_unit.snapshot_turn_start_effects()

	if _is_player_hero(active_unit):
		waiting_for_player = true
		_show_player_interface(active_unit)
	else:
		_log_combat("Ход врага: %s" % active_unit.unit_name)
		_run_enemy_turn(active_unit)

func _is_player_hero(unit: Combatant) -> bool:
	return not unit.is_enemy

func _is_on_enemies_team(unit: Combatant) -> bool:
	return unit.is_enemy

func _run_enemy_turn(monster: Combatant) -> void:
	if not battle_running or monster == null:
		return
	if monster.current_hp <= 0:
		call_deferred("_next_turn")
		return
	var decision = _get_ai_decision(monster)
	if decision.has("ability") and decision.ability and decision.has("target") and decision.target:
		var _used_ability: AbilityResource = decision.ability
		if _used_ability.majesty_cost > 0:
			monster.modify_majesty(-_effective_majesty_cost(monster, _used_ability))
		_use_ability(monster, decision.target, _used_ability)
	else:
		_log_combat("%s не нашёл подходящего действия и пропускает ход." % monster.unit_name)
	await get_tree().create_timer(ENEMY_TURN_DELAY_SEC).timeout
	if not battle_running:
		return
	_finish_unit_turn(monster)

func _show_player_interface(god: Combatant):
	waiting_for_target = false
	selected_ability = null
	var pos_label = " (линия %d)" % (god.position_index + 1)
	_log_combat("Ваш ход: %s%s" % [god.unit_name, pos_label])
	_show_ability_controls()
	
	var has_usable_ability = false
	for i in range(4):
		if i < god.active_abilities.size() and god.active_abilities[i] != null:
			var ability = god.active_abilities[i]
			_set_ability_button_content(slots[i], ability)
			slots[i].tooltip_text = _get_ability_tooltip(ability, god)
			slots[i].rich_tooltip_text = slots[i].tooltip_text
			slots[i].show()
			slots[i].disabled = not _is_ability_usable(god, ability)
			if not slots[i].disabled:
				has_usable_ability = true
		else:
			slots[i].text = "---"
			slots[i].icon = null
			slots[i].tooltip_text = ""
			slots[i].hide()
	if god.ultimate_ability and (god.active_abilities.is_empty() or god.ultimate_ability != god.active_abilities[0]):
		_set_ability_button_content(slot_ult, god.ultimate_ability)
		slot_ult.tooltip_text = _get_ability_tooltip(god.ultimate_ability, god)
		slot_ult.rich_tooltip_text = slot_ult.tooltip_text
		slot_ult.show()
		slot_ult.disabled = not _is_ability_usable(god, god.ultimate_ability)
		if not slot_ult.disabled:
			has_usable_ability = true
	else:
		slot_ult.icon = null
		slot_ult.hide()
		slot_ult.tooltip_text = ""
	
	tactical_button.show()
	_set_action_button_icon(tactical_button, WAIT_ICON_PATH, "Ждать")
	tactical_button.disabled = false
	skip_turn_button.show()
	_set_action_button_icon(skip_turn_button, END_TURN_ICON_PATH, "Пропустить ход")
	skip_turn_button.disabled = false

	# Панель заклинаний
	if _spell_panel:
		_spell_panel.show()
		_update_spell_ui()
	
	_set_status("")


## Пересчёт доступности кнопок способностей по текущей позиции/величию бога.
## Вызывается при любом изменении состояния боя (движение, заклинания, величие).
func _refresh_ability_buttons_availability(god: Combatant) -> void:
	if god == null or ability_panel == null:
		return
	for i in range(4):
		if i < god.active_abilities.size() and god.active_abilities[i] != null:
			var ability: AbilityResource = god.active_abilities[i]
			if slots[i].is_visible_in_tree():
				slots[i].disabled = not _is_ability_usable(god, ability)
	if god.ultimate_ability and (god.active_abilities.is_empty() or god.ultimate_ability != god.active_abilities[0]):
		if slot_ult.is_visible_in_tree():
			slot_ult.disabled = not _is_ability_usable(god, god.ultimate_ability)


func _set_ability_button_content(button: Button, ability: AbilityResource) -> void:
	if button.get_script() == null:
		button.set_script(STAT_ICON_TOOLTIP_BUTTON_SCRIPT)
	var icon := ability.get_icon_texture()
	button.icon = icon
	button.text = "" if icon != null else ability.get_display_name()


## Золотой трон: снижает стоимость «Узурпировать» на 20 величия.
func _effective_majesty_cost(user: Combatant, ability: AbilityResource) -> int:
	var cost = ability.majesty_cost
	if ability.ability_marker == "set_usurp" and user.has_item_effect("set_throne_usurp_discount"):
		cost = maxi(0, cost - 20)
	return cost

func _is_ability_usable(user: Combatant, ability: AbilityResource) -> bool:
	if ability == null:
		return false
	if ability.usable_from_positions.size() > user.position_index:
		if not ability.usable_from_positions[user.position_index]:
			return false
	if ability.majesty_cost > 0 and user.current_majesty < _effective_majesty_cost(user, ability):
		return false
	if ability.ability_marker == "set_usurp":
		return _has_set_usurp_target(user, ability)
	if ability.target_type == "Self" or ability.target_type == "Position":
		return true
	return _find_valid_target(ability) != null

func _set_status(text: String):
	if status_label:
		status_label.text = text

## Создаёт крупный баннер названия способности вверху по центру экрана.
## Текст не перехватывает клики (mouse_filter = IGNORE), поверх него
## рисуется чёрная обводка для читаемости на любом фоне.
func _setup_ability_banner():
	_ability_banner = Label.new()
	_ability_banner.name = "AbilityBanner"
	# Растягиваем на весь экран, текст центрируем по горизонтали и прижимаем к верху.
	_ability_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Сдвинуто вниз, чтобы не перекрывать полосу очереди ходов в самом верху.
	_ability_banner.offset_top = 38.0
	_ability_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Не блокируем клики по юнитам/кнопкам под баннером.
	_ability_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_banner.z_index = 50
	_ability_banner.add_theme_font_size_override("font_size", 46)
	_ability_banner.add_theme_color_override("font_color", Color(1.0, 0.96, 0.55))
	_ability_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_ability_banner.add_theme_constant_override("outline_size", 10)
	$BattleUI.add_child(_ability_banner)
	_ability_banner.hide()

## Показывает название способности крупным текстом вверху экрана.
## Текст держится дольше, затем плавно исчезает.
func _show_ability_banner(ability_name: String) -> void:
	if _ability_banner == null or ability_name == "":
		return
	_ability_banner.text = ability_name
	_ability_banner.modulate.a = 1.0
	_ability_banner.show()
	if _ability_banner_tween and _ability_banner_tween.is_valid():
		_ability_banner_tween.kill()
	_ability_banner_tween = create_tween()
	_ability_banner_tween.tween_interval(2.5)
	_ability_banner_tween.tween_property(_ability_banner, "modulate:a", 0.0, 0.5)
	_ability_banner_tween.tween_callback(_ability_banner.hide)

## Создаёт полосу очереди ходов в самом верху экрана: портреты-лица юнитов.
## Наведение на портрет подсвечивает соответствующего юнита на поле боя.
func _setup_turn_order_display():
	_turn_order_row = HBoxContainer.new()
	_turn_order_row.name = "TurnOrderRow"
	_turn_order_row.position = Vector2(0, 2)
	_turn_order_row.size = Vector2(1280, 64)
	_turn_order_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn_order_row.add_theme_constant_override("separation", 8)
	_turn_order_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_turn_order_row.z_index = 60
	$BattleUI.add_child(_turn_order_row)

## Перерисовывает иконки активных марок — каждая ровно над своей позицией на поле.
func _update_marks_display():
	for n in _mark_nodes:
		if is_instance_valid(n):
			var mark_parent: Node = n.get_parent()
			if mark_parent != null:
				mark_parent.remove_child(n)
			n.queue_free()
	_mark_nodes.clear()
	if marks == null:
		return
	for m in marks.position_marks:
		var team := str(m.get("team", ""))
		var pos := int(m.get("position", -1))
		if pos < 0 or pos > 3:
			continue
		var anchor := get_node_or_null(("HeroPositions/Pos%d" if team == "ally" else "EnemyPositions/Pos%d") % (pos + 1))
		if anchor == null:
			continue
		var icon_tex = m.get("icon", null)
		if icon_tex == null:
			icon_tex = load("res://icons/Buff_icon.png")
		if icon_tex == null:
			continue
		var marked_unit: Combatant = null
		var marked_team: Array = heroes_team if team == "ally" else enemies_team
		if pos < marked_team.size():
			marked_unit = marked_team[pos]
		var marked_visual: Node2D = _find_visual_for_unit(marked_unit, hero_visuals if team == "ally" else enemy_visuals)
		var mark_x: float = marked_visual.global_position.x if marked_visual != null else anchor.global_position.x
		var sprite := Sprite2D.new()
		sprite.texture = icon_tex
		var tex_size: Vector2 = icon_tex.get_size()
		var icon_px := 135.0
		if tex_size.x > 0 and tex_size.y > 0:
			var k := icon_px / maxf(tex_size.x, tex_size.y)
			sprite.scale = Vector2(k, k)
		# Марка рисуется над позицией меченого юнита на поле (не в нижней панели с баффами).
		var mark_y: float = anchor.global_position.y - 260.0
		if marked_visual != null:
			mark_y = marked_visual.global_position.y - 260.0
		sprite.position = Vector2(mark_x, mark_y)
		sprite.z_index = 100
		add_child(sprite)
		_mark_nodes.append(sprite)
		var rounds := int(m.get("rounds_left", 0))
		if rounds > 0:
			var lbl := Label.new()
			lbl.text = str(rounds)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.modulate = Color(1, 0.9, 0.5)
			lbl.position = sprite.position + Vector2(8, 5)
			lbl.z_index = 100
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$BattleUI.add_child(lbl)
			_mark_nodes.append(lbl)

var _marks_signature := ""

func _process(_delta: float) -> void:
	# Гарантированная синхронизация иконок марок: перерисовка при любом изменении
	# (установка/удаление/истечение/перезапись) независимо от точки вызова.
	if marks == null:
		return
	var sig := ""
	for m in marks.position_marks:
		sig += "%s:%d:%d;%s" % [str(m.get("team", "")), int(m.get("position", -1)), int(m.get("rounds_left", 0)), str(m.get("icon", null).resource_path if m.get("icon", null) != null else "")]
	if sig != _marks_signature:
		_marks_signature = sig
		_update_marks_display()

## Обновляет полосу очереди: портреты юнитов; текущий ходящий — крупнее с маркером ▶.
func _update_turn_order_display():
	if _turn_order_row == null:
		return
	# Портреты пересоздаются — гасим возможную «залипшую» подсветку наведения на поле.
	for v in hero_visuals + enemy_visuals:
		if v:
			v.set_hover(false)
	for child in _turn_order_row.get_children():
		child.queue_free()
	# Порядок: текущий ходящий первым, затем оставшиеся (живые, ещё не ходившие).
	if active_unit != null and active_unit.current_hp > 0 and not active_unit.has_acted_this_round:
		_add_turn_portrait(active_unit, true)
	for u in turn_order:
		if u != null and u.current_hp > 0 and not u.has_acted_this_round and u != active_unit:
			_add_turn_portrait(u, false)

## Добавляет один портрет юнита в полосу очереди (лицо; запасной — спрайт/имя).
## is_active — True для текущего ходящего (крупнее + маркер ▶).
func _add_turn_portrait(u: Combatant, is_active: bool) -> void:
	if is_active:
		var arrow := Label.new()
		arrow.text = "▶"
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		arrow.add_theme_color_override("font_outline_color", Color.BLACK)
		arrow.add_theme_constant_override("outline_size", 6)
		arrow.add_theme_font_size_override("font_size", 24)
		_turn_order_row.add_child(arrow)
	_turn_order_row.add_child(_make_turn_portrait(u, is_active))

## Создаёт узел-портрет юнита. Наведение курсора подсвечивает юнита на поле боя.
func _make_turn_portrait(u: Combatant, is_active: bool) -> Control:
	var tex: Texture2D = null
	if u.face_sprite != "":
		tex = load(u.face_sprite) as Texture2D
	if tex == null and u.sprite_path != "":
		tex = load(u.sprite_path) as Texture2D
	var psize := 58 if is_active else 46
	if tex == null:
		# Нет ни лица, ни спрайта — запасной вариант: имя.
		var lbl := Label.new()
		lbl.text = _short_unit_name(u.unit_name)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.tooltip_text = u.unit_name
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_active else Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.mouse_entered.connect(_on_turn_portrait_hovered.bind(u))
		lbl.mouse_exited.connect(_on_turn_portrait_unhovered.bind(u))
		return lbl
	var portrait := TextureRect.new()
	portrait.texture = tex
	portrait.custom_minimum_size = Vector2(psize, psize)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.tooltip_text = u.unit_name
	# Активный — в полный цвет; остальные слегка затемнены (чётче видно, чей ход).
	portrait.modulate = Color.WHITE if is_active else Color(0.75, 0.75, 0.75, 1.0)
	portrait.mouse_entered.connect(_on_turn_portrait_hovered.bind(u))
	portrait.mouse_exited.connect(_on_turn_portrait_unhovered.bind(u))
	return portrait

## Наведение на портрет в полосе очереди — подсветить юнита на поле боя.
func _on_turn_portrait_hovered(u: Combatant) -> void:
	var vis = _find_visual_for_unit(u, hero_visuals)
	if vis == null:
		vis = _find_visual_for_unit(u, enemy_visuals)
	if vis:
		vis.set_hover(true)

## Уход курсора с портрета — снять подсветку с юнита на поле боя.
func _on_turn_portrait_unhovered(u: Combatant) -> void:
	var vis = _find_visual_for_unit(u, hero_visuals)
	if vis == null:
		vis = _find_visual_for_unit(u, enemy_visuals)
	if vis:
		vis.set_hover(false)

## Сокращает имя юнита до 12 символов (для компактной полосы очереди ходов).
func _short_unit_name(full_name: String) -> String:
	if full_name.length() > 12:
		return full_name.substr(0, 11) + "…"
	return full_name

func _stat_icon_bbcode(stat_key: String, size: int = STAT_ICON_BBCODE_SIZE) -> String:
	var path: String = str(STAT_ICON_PATHS.get(stat_key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	var hint := str(STAT_ICON_TOOLTIPS.get(stat_key, ""))
	var img := "[img width=%d height=%d]%s[/img]" % [size, size, path]
	return "[hint=%s]%s[/hint]" % [hint, img] if hint != "" else img

func _stat_icon_or_text(stat_key: String, fallback: String) -> String:
	var icon := _stat_icon_bbcode(stat_key)
	return icon if icon != "" else fallback

func _escape_bbcode_text(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

func _replace_stat_words_with_icons(text: String) -> String:
	var result := text
	var replacements := [
		["Крит. шанс", "luck"],
		["Фантазии", "fantasy"], ["фантазии", "fantasy"], ["Фантазия", "fantasy"], ["фантазия", "fantasy"], ["фантазию", "fantasy"], ["фантазией", "fantasy"],
		["Здоровье", "health"], ["здоровья", "health"], ["здоровье", "health"], ["HP", "health"],
		["Инициатива", "initiative"], ["инициативы", "initiative"], ["инициативе", "initiative"], ["инициатива", "initiative"],
		["Точность", "accuracy"], ["точности", "accuracy"], ["точность", "accuracy"],
		["Уклонение", "evasion"], ["уклонения", "evasion"], ["уклонению", "evasion"], ["уклонение", "evasion"],
		["Величие", "glory"], ["величия", "glory"], ["величие", "glory"],
		["Броня", "armor"], ["брони", "armor"], ["броне", "armor"], ["броня", "armor"],
		["Крит", "luck"], ["криту", "luck"], ["удачи", "luck"], ["Удача", "luck"], ["удача", "luck"],
	]
	for item in replacements:
		var word := str(item[0])
		var key := str(item[1])
		var icon := _stat_icon_bbcode(key)
		if icon != "":
			result = result.replace(word, icon)
	return result

func _format_stat_icons_for_log(message: String) -> String:
	return _replace_stat_words_with_icons(_escape_bbcode_text(message))

func _log_combat(message: String):
	print(message)
	if combat_log == null:
		return
	combat_log.bbcode_enabled = true
	combat_log.hint_underlined = false
	combat_log.mouse_filter = Control.MOUSE_FILTER_STOP
	_combat_log_lines.append(_format_stat_icons_for_log(message))
	while _combat_log_lines.size() > MAX_LOG_LINES:
		_combat_log_lines.pop_front()
	combat_log.clear()
	combat_log.append_text("\n".join(_combat_log_lines) + "\n")

func _on_wait_button_pressed():
	if active_unit == null or active_unit.has_acted_this_round:
		return
	if not waiting_for_player or not _is_player_hero(active_unit):
		return
	_clear_pinned_unit_info()
	_hide_ability_controls()
	_defer_active_unit_turn()
	waiting_for_player = false
	waiting_for_target = false
	selected_ability = null
	call_deferred("_next_turn")

func _on_skip_turn_pressed():
	if active_unit == null:
		return
	if not waiting_for_player or not _is_player_hero(active_unit):
		return
	_hide_ability_controls()
	_log_combat("%s пропускает ход." % active_unit.unit_name)
	_finish_unit_turn(active_unit)

func _defer_active_unit_turn():
	var unit = active_unit
	turn_order.erase(unit)
	unit.wait_action()
	unit.round_wait_stamp = wait_counter
	wait_counter += 1
	
	# Кто ждал позже (больший номер) — ходит раньше среди «ждущих»
	var insert_at = turn_order.size()
	for i in range(turn_order.size()):
		var queued = turn_order[i]
		if queued.round_wait_stamp >= 0 and queued.round_wait_stamp < unit.round_wait_stamp:
			insert_at = i
			break
	turn_order.insert(insert_at, unit)
	
	_log_combat("%s ждёт — ход перенесён в конец очереди (позиция %d из %d)." % [
		unit.unit_name, insert_at + 1, turn_order.size()
	])

func _on_ability_clicked(ability_index: int):
	if active_unit == null:
		return
	if not waiting_for_player or not _is_player_hero(active_unit):
		return
	_waiting_for_ultimate_target = false
	selected_ability = active_unit.active_abilities[ability_index]
	if selected_ability == null:
		return
	if not _is_ability_usable(active_unit, selected_ability):
		return
	
	if selected_ability.target_type == "Self":
		_use_ability(active_unit, active_unit, selected_ability)
		_hide_ability_controls()
		_set_status("")
		_finish_unit_turn(active_unit)
		return
	
	if selected_ability.target_type == "Position":
		# Марка ставится на позицию, которую выберет игрок.
		waiting_for_target = true
		_hide_ability_controls()
		_set_status("Выберите позицию для марки: " + selected_ability.get_display_name())
		_update_target_highlights()
		return
	
	if selected_ability.target_type == "All_Enemies" or selected_ability.target_type == "All_Allies":
		var target = _find_valid_target(selected_ability)
		if target:
			_use_ability(active_unit, target, selected_ability)
			_hide_ability_controls()
			_set_status("")
			_finish_unit_turn(active_unit)
		return
	
	waiting_for_target = true
	_hide_ability_controls()
	_set_status("Выберите цель для: " + selected_ability.get_display_name())
	_update_target_highlights()

func _on_unit_selected(target: Combatant):
	if target != null:
		_pinned_hover_unit = target
		_show_unit_info_panel(target)
	if active_unit == null or not waiting_for_player or not _is_player_hero(active_unit):
		return
	# === Выбор цели для заклинания ===
	if _waiting_for_spell_target and _selected_spell != null:
		var can_target = _can_target_unit_for_spell(_selected_spell, target)
		if can_target:
			if _rum_spell_whole_team_active and _selected_spell.spell_name == "Ром":
				# Чарка рома взята с собой: заклинание бьёт не только цель, но и всю её команду.
				var rum_team: Array = enemies_team if target.is_enemy else heroes_team
				for rum_unit_value in rum_team:
					var rum_unit: Combatant = rum_unit_value as Combatant
					if rum_unit != null and rum_unit.current_hp > 0:
						_apply_spell_to_target(rum_unit, _selected_spell)
			else:
				_apply_spell_to_target(target, _selected_spell)
			_deduct_spell(_selected_spell)
			_update_spell_ui()
			_waiting_for_spell_target = false
			_selected_spell = null
			_set_status("")
			_update_target_highlights()
		else:
			_set_status("Нельзя выбрать эту цель для заклинания: %s" % _selected_spell.get_display_name())
		return
	
	if not waiting_for_target or selected_ability == null:
		return
	
	# === Марка на выбранную позицию (target_type = "Position") ===
	if selected_ability.target_type == "Position":
		var side_ok := false
		if selected_ability.mark_target_team == "ally":
			side_ok = _is_player_hero(target)
		else:
			side_ok = _is_on_enemies_team(target)
		if not side_ok or target.current_hp <= 0:
			_set_status("Марку можно поставить только на живого юнита нужной команды.")
			return
		waiting_for_target = false
		var mark_ab := selected_ability
		selected_ability = null
		_hide_ability_controls()
		_set_status("")
		marks.place_mark(active_unit, mark_ab, target.position_index)
		_update_marks_display()
		_finish_unit_turn(active_unit)
		return
	
	if not _can_user_target_unit(active_unit, target, selected_ability):
		_set_status("Эту цель нельзя выбрать для " + selected_ability.get_display_name())
		return
	
	waiting_for_target = false
	var used_ability := selected_ability
	selected_ability = null
	_hide_ability_controls()
	_set_status("")
	if _waiting_for_ultimate_target:
		_waiting_for_ultimate_target = false
		active_unit.modify_majesty(-_effective_majesty_cost(active_unit, used_ability))
		_use_ability(active_unit, target, used_ability)
		_restore_usurped_ultimate_after_use(active_unit, used_ability)
	else:
		_use_ability(active_unit, target, used_ability)
	_finish_unit_turn(active_unit)

func _on_ultimate_clicked():
	if active_unit == null or active_unit.ultimate_ability == null:
		return
	if not waiting_for_player or not _is_player_hero(active_unit):
		return
	# ═══ Мрачная сделка: блокировка ультимативной способности ═══
	var _ub_blocked = false
	for _ub_e in active_unit.active_effects:
		if Combatant._effect_get(_ub_e, "effect_id", "") == "ultimate_blocked":
			_ub_blocked = true
			break
	if _ub_blocked:
		_log_combat("⛔ [Мрачная сделка] %s: ультимативная способность заблокирована!" % active_unit.unit_name)
		return
	var ultimate := active_unit.ultimate_ability
	if not _is_ability_usable(active_unit, ultimate):
		return
	if _ultimate_requires_manual_target(ultimate):
		selected_ability = ultimate
		waiting_for_target = true
		_waiting_for_ultimate_target = true
		_hide_ability_controls()
		_set_status("Выберите цель для ульты: " + ultimate.name)
		_update_target_highlights()
		return
	var target = _find_valid_target(ultimate)
	if target:
		_hide_ability_controls()
		active_unit.modify_majesty(-_effective_majesty_cost(active_unit, ultimate))
		_use_ability(active_unit, target, ultimate)
		_restore_usurped_ultimate_after_use(active_unit, ultimate)
		_finish_unit_turn(active_unit)

func _ultimate_requires_manual_target(ability: AbilityResource) -> bool:
	return ability.target_type == "Enemy" or ability.target_type == "Ally"


## Проверка допустимости цели для заклинания (вынесена из _on_unit_selected,
## чтобы одной и той же логикой пользовались и разрешение выбора, и подсветка целей).
func _can_target_unit_for_spell(spell: SpellResource, target: Combatant) -> bool:
	if target == null or target.current_hp <= 0:
		return false
	var can_target = false
	if spell.target_type == "Any":
		# «Ром» и аналогичные — можно на любого живого юнита
		can_target = true
	else:
		if spell.target_type == "Enemy" and _is_on_enemies_team(target):
			can_target = true
		if spell.target_type == "Ally" and _is_player_hero(target):
			can_target = true
	if can_target:
		var tp = spell.targetable_positions
		# Крупный юнит занимает 2 клетки — достаточно совпадения по любой из них
		# (аналогично Combatant.can_be_targeted_at для способностей).
		var pos_ok = tp.size() > target.position_index and tp[target.position_index]
		if target.is_large and target.position_index + 1 < tp.size() and tp[target.position_index + 1]:
			pos_ok = true
		if not pos_ok:
			can_target = false
	return can_target

func _can_user_target_unit(user: Combatant, target: Combatant, ability: AbilityResource) -> bool:
	if user == null or target == null or ability == null or target.current_hp <= 0:
		return false
	if ability.target_type == "Enemy" and target.is_enemy == user.is_enemy:
		return false
	if ability.target_type == "Ally" and target.is_enemy != user.is_enemy:
		return false
	if ability.ability_marker == "set_usurp":
		if target == user or target.ultimate_ability == null:
			return false
	return _can_target_unit(target, ability)


func _has_set_usurp_target(user: Combatant, ability: AbilityResource) -> bool:
	if user == null:
		return false
	var team: Array = enemies_team if user.is_enemy else heroes_team
	for unit in team:
		if unit and unit != user and unit.current_hp > 0 and unit.ultimate_ability != null and _can_target_unit(unit, ability):
			return true
	return false


## Подсвечивает допустимые цели (красным — врагов, синим — союзников) во время выбора
## цели способности/ульты/заклинания, до того как игрок применит выбор. Снимает
## подсветку со всех, если сейчас цель не выбирается.
func _update_target_highlights() -> void:
	var mode := ""
	if waiting_for_target and selected_ability != null and active_unit != null:
		mode = "ability"
	elif _waiting_for_spell_target and _selected_spell != null:
		mode = "spell"
	for v in hero_visuals + enemy_visuals:
		if v == null or v.data == null:
			continue
		var unit: Combatant = v.data
		var highlight := ""
		if mode != "" and unit.current_hp > 0:
			var is_valid := false
			if mode == "ability":
				if selected_ability.target_type == "Position":
					if selected_ability.mark_target_team == "ally":
						is_valid = _is_player_hero(unit)
					else:
						is_valid = _is_on_enemies_team(unit)
				else:
					is_valid = _can_user_target_unit(active_unit, unit, selected_ability)
			else:
				is_valid = _can_target_unit_for_spell(_selected_spell, unit)
			if is_valid:
				highlight = "enemy" if unit.is_enemy else "ally"
		if v.has_method("set_target_highlight"):
			v.set_target_highlight(highlight)


func _restore_usurped_ultimate_after_use(unit: Combatant, used_ultimate: AbilityResource) -> void:
	if unit == null or not unit.has_usurped_ultimate:
		return
	if used_ultimate == unit.original_ultimate_ability:
		return
	unit.ultimate_ability = unit.original_ultimate_ability
	unit.has_usurped_ultimate = false
	_log_combat("%s возвращает ульту «%s»." % [unit.unit_name, unit.ultimate_ability.name])

func _finish_unit_turn(unit: Combatant):
	_clear_pinned_unit_info()
	if unit == null:
		waiting_for_player = false
		call_deferred("_next_turn")
		return
	# Идемпотентность: если для этого юнита ход уже завершался в этом раунде (гонка
	# между ожидающей AI-корутиной и случайным повторным кликом — см. баг-репорт про
	# "боги ходят сами"), повторный вызов не должен снова тикать эффекты/двигать очередь.
	if unit.has_acted_this_round:
		return
	unit.tick_effects()
	if unit.current_hp <= 0:
		_log_combat("☠ %s погибает от периодического урона в конце хода." % unit.unit_name)
		_on_unit_killed(unit)
		_compact_team(heroes_team if not unit.is_enemy else enemies_team)
	# ═══ Трезубец Посейдона: в конце хода +7 к случайной характеристике на 1 ход ═══
	if unit.current_hp > 0 and unit.has_item_effect("poseidon_trident_end_turn_buff"):
		var _pt_stats = ["damage", "armor", "accuracy", "evasion", "initiative"]
		var _pt_stat = _pt_stats.pick_random()
		unit.apply_stat_change(_pt_stat, 7)
		unit.active_effects.append({"stat": _pt_stat, "value": 7, "duration": 1, "effect_id": "poseidon_trident_buff", "source_ability": "Трезубец Посейдона"})
		_log_combat("🔱 [Трезубец Посейдона] %s получает +7 к «%s» на 1 ход." % [unit.unit_name, _pt_stat])
	# ═══ Туннели — Голем: в конце хода +5 урона, +3 брони (навсегда) ═══
	if unit.current_hp > 0 and unit.special_effect_type == "golem_end_turn_growth":
		var _g_mult = 2 if unit.has_meta("golem_double_passive") else 1
		unit.apply_stat_change("damage", 5 * _g_mult)
		unit.apply_stat_change("armor", 3 * _g_mult)
		if unit.has_meta("golem_double_passive"):
			unit.remove_meta("golem_double_passive")
			_log_combat("🪨 [Рост x2] %s: +%d урона, +%d брони («Вперёд» удвоил пассивку)." % [unit.unit_name, 5 * _g_mult, 3 * _g_mult])
		else:
			_log_combat("🪨 [Рост] %s: +5 урона, +3 брони (навсегда)." % unit.unit_name)
	# Дуна: в конце своего хода получает +урон на 1 ход = половина всего HP, восстановленного кому-либо за её ход
	if unit.current_hp > 0 and unit.special_effect_type == "duna_heal_damage" and _duna_turn_heal > 0:
		var _dh_buff = int(_duna_turn_heal / 2)
		if _dh_buff > 0:
			var _dh_duration = _compute_effect_duration(unit, unit, 3, false)
			unit.apply_stat_change("damage", _dh_buff)
			unit.active_effects.append({"stat": "damage", "value": _dh_buff, "duration": _dh_duration, "effect_id": "duna_heal_damage", "source_ability": "Пассивка Дуны"})
			_log_combat("🌿 [Дуна] %s восстановила %d HP за ход → +%d урона на %d хода." % [unit.unit_name, _duna_turn_heal, _dh_buff, _dh_duration])
		_duna_turn_heal = 0
	_update_all_visuals()
	unit.has_acted_this_round = true
	waiting_for_player = false
	waiting_for_target = false
	_waiting_for_spell_target = false
	_selected_spell = null
	_update_target_highlights()
	if _spell_panel:
		_spell_panel.hide()
	if _check_battle_end():
		return
	call_deferred("_next_turn")

func _find_valid_target(ability: AbilityResource) -> Combatant:
	if ability.target_type == "All_Enemies" or ability.target_type == "All_Allies":
		var all_targets = _get_all_targets(ability)
		return all_targets[0] if all_targets.size() > 0 else null
	
	if ability.target_type == "Self":
		return active_unit
	
	var team = enemies_team if (ability.target_type == "Enemy" or ability.target_type == "All_Enemies") else heroes_team
	for unit in team:
		if unit and unit.current_hp > 0 and _can_target_unit(unit, ability):
			return unit
	return null

func _can_target_unit(target: Combatant, ability: AbilityResource) -> bool:
	# Чернобог: союзники не могут выбрать его целью (пассивка «uncurseable»).
	# Белая маска снимает это ограничение.
	if target.special_effect_type == "chernobog_uncurseable" and not target.is_enemy \
			and not target.has_item_effect("chernobog_white_mask_allow_target"):
		if ability.target_type == "Ally" or ability.target_type == "All_Allies" or ability.mark_target_team == "ally":
			return false
	return Combatant.can_be_targeted_at(target, ability)
	
func _get_all_targets(ability: AbilityResource, attacker: Combatant = null) -> Array:
	var targets = []
	var is_enemy_target = (ability.target_type == "Enemy" or ability.target_type == "All_Enemies")
	var team: Array
	if attacker != null:
		# Команда определяется относительно атакующего
		if is_enemy_target:
			team = heroes_team if attacker.is_enemy else enemies_team
		else:
			team = enemies_team if attacker.is_enemy else heroes_team
	else:
		# Перспектива игрока (героя)
		team = enemies_team if is_enemy_target else heroes_team
	for u in team:
		if u and u.current_hp > 0 and _can_target_unit(u, ability):
			targets.append(u)
	return targets


func _enemy_ai_turn(monster: Combatant):
	var decision = _get_ai_decision(monster)
	if decision.has("ability") and decision.ability and decision.has("target") and decision.target:
		var _used_ability: AbilityResource = decision.ability
		if _used_ability.majesty_cost > 0:
			monster.modify_majesty(-_effective_majesty_cost(monster, _used_ability))
		_use_ability(monster, decision.target, _used_ability)
	else:
		_log_combat("%s не нашёл подходящего действия и пропускает ход." % monster.unit_name)
	_finish_unit_turn(monster)

## Fallback ИИ: выбирает случайную доступную способность и валидную цель.
## Используется когда у юнита нет ai_script или скрипт не зарегистрирован.
func _get_random_ai_decision(monster: Combatant) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		var valid: Array = []
		# Цели-враги (герои)
		for h in heroes_team:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				valid.append(h)
		# Цели-союзники (для Ally/All_Allies)
		if ab.target_type == "Ally" or ab.target_type == "All_Allies":
			valid.clear()
			for a in enemies_team:
				if a and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, ab):
					valid.append(a)
		if valid.size() > 0:
			return {"ability": ab, "target": valid.pick_random()}
	return {}

func _get_ai_decision(monster: Combatant) -> Dictionary:
	if monster.ai_script == null:
		return _get_random_ai_decision(monster)
	# Состояние локации Глубина: Бурные потоки = нечётный раунд (урон при перемещении)
	var is_raging: bool = (current_round % 2 == 1) and CombatManager.selected_location_id == "depths"
	match monster.ai_script.resource_path.get_file():
		"baldr_logic.gd":
			return BaldrLogic.get_decision(monster, heroes_team)
		"cyclops_logic.gd":
			return CyclopsLogic.get_decision(monster, heroes_team)
		"draugr_juggernaut_logic.gd":
			return DraugrJuggernautLogic.get_decision(monster, heroes_team)
		"draugr_raider_logic.gd":
			return DraugrRaiderLogic.get_decision(monster, heroes_team)
		"draugr_berserk_logic.gd":
			return DraugrBerserkLogic.get_decision(monster, heroes_team)
		"banshee_logic.gd":
			return BansheeLogic.get_decision(monster, heroes_team)
		"indigo_logic.gd":
			return IndigoLogic.get_decision(monster, heroes_team, _is_fog_round)
		"jotun_logic.gd":
			return JotunLogic.get_decision(monster, heroes_team)
		"cannon_logic.gd":
			return CannonLogic.get_decision(monster, heroes_team)
		"captain_logic.gd":
			return CaptainLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"siren_logic.gd":
			return SirenLogic.get_decision(monster, heroes_team)
		"filibuster_logic.gd":
			return FilibusterLogic.get_decision(monster, heroes_team)
		"sailor_logic.gd":
			return SailorLogic.get_decision(monster, heroes_team)
		"sailor_bomber_logic.gd":
			return SailorBomberLogic.get_decision(monster, heroes_team)
		"oni_warrior_logic.gd":
			return OniWarriorLogic.get_decision(monster, heroes_team)
		"oni_sorcerer_logic.gd":
			return OniSorcererLogic.get_decision(monster, heroes_team)
		"lernaean_lion_logic.gd":
			return LernaeanLionLogic.get_decision(monster, heroes_team)
		"armored_titan_logic.gd":
			return ArmoredTitanLogic.get_decision(monster, heroes_team)
		"attacking_titan_logic.gd":
			return AttackingTitanLogic.get_decision(monster, heroes_team)
		"immortal_logic.gd":
			return ImmortalLogic.get_decision(monster, heroes_team)
		"anubis_logic.gd":
			return AnubisLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"ra_logic.gd":
			return RaLogic.get_decision(monster, heroes_team)
		"mummy_logic.gd":
			return MummyLogic.get_decision(monster, heroes_team)
		"sphinx_logic.gd":
			return SphinxLogic.get_decision(monster, heroes_team)
		"scarab_logic.gd":
			return ScarabLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"kappa_warrior_logic.gd":
			return KappaWarriorLogic.get_decision(monster, heroes_team)
		"kappa_shaman_logic.gd":
			return KappaShamanLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"crab_collector_logic.gd":
			return CrabCollectorLogic.get_decision(monster, heroes_team)
		"saru_logic.gd":
			return SaruLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"naga_warrior_logic.gd":
			return NagaWarriorLogic.get_decision(monster, heroes_team)
		"naga_monk_logic.gd":
			return NagaMonkLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"rakshasa_logic.gd":
			return RakshasaLogic.get_decision(monster, heroes_team)
		"coatl_logic.gd":
			return CoatlLogic.get_decision(monster, heroes_team)
		"asura_logic.gd":
			return AsuraLogic.get_decision(monster, heroes_team)
		"medusa_logic.gd":
			return MedusaLogic.get_decision(monster, heroes_team)
		"lava_boar_logic.gd":
			return LavaBoarLogic.get_decision(monster, heroes_team)
		"kirin_logic.gd":
			return KirinLogic.get_decision(monster, heroes_team)
		"kikimora_logic.gd":
			return KikimoraLogic.get_decision(monster, heroes_team)
		"leshy_logic.gd":
			return LeshyLogic.get_decision(monster, heroes_team)
		"oboroten_logic.gd":
			return OborotenLogic.get_decision(monster, heroes_team)
		"troll_logic.gd":
			return TrollLogic.get_decision(monster, heroes_team)
		"utoplennitsa_logic.gd":
			return UtoplennitsaLogic.get_decision(monster, heroes_team)
		"vodyanoy_logic.gd":
			return VodyanoyLogic.get_decision(monster, heroes_team)
		"arena_random_logic.gd":
			return ArenaRandomLogic.get_decision(monster, heroes_team)
		"hell_random_logic.gd":
			return HellRandomLogic.get_decision(monster, heroes_team)
		"hellhound_logic.gd":
			return HellhoundLogic.get_decision(monster, heroes_team)
		"tormentor_logic.gd":
			return TormentorLogic.get_decision(monster, heroes_team)
		"succubus_logic.gd":
			return SuccubusLogic.get_decision(monster, heroes_team)
		"nightmare_logic.gd":
			return NightmareLogic.get_decision(monster, heroes_team)
		"devil_logic.gd":
			return DevilLogic.get_decision(monster, heroes_team)
		"mentor_logic.gd":
			return MentorLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"minotaur_logic.gd":
			return MinotaurLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"nanahue_logic.gd":
			return NanahueLogic.get_decision(monster, heroes_team)
		"merwarrior_logic.gd":
			return MerwarriorLogic.get_decision_depths(monster, heroes_team, is_raging)
		"mermaid_sorceress_logic.gd":
			return MermaidSorceressLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"seawitch_logic.gd":
			return SeaWitchLogic.get_decision_depths(monster, heroes_team, is_raging)
		"eel_logic.gd":
			return EelLogic.get_decision_depths(monster, heroes_team, is_raging)
		"triton_logic.gd":
			return TritonLogic.get_decision(monster, heroes_team)
		"golden_valkyrie_logic.gd":
			return GoldenValkyrieLogic.get_decision(monster, heroes_team)
		"silver_valkyrie_logic.gd":
			return SilverValkyrieLogic.get_decision(monster, heroes_team)
		"bird_knife_wings_logic.gd":
			return BirdKnifeWingsLogic.get_decision(monster, heroes_team)
		"cupid_logic.gd":
			return CupidLogic.get_decision(monster, heroes_team)
		"pegasus_logic.gd":
			return PegasusLogic.get_decision(monster, heroes_team)
		"griffin_logic.gd":
			return GriffinLogic.get_decision(monster, heroes_team)
		"princess_logic.gd":
			return PrincessLogic.get_decision(monster, heroes_team)
		"jester_logic.gd":
			return JesterLogic.get_decision(monster, heroes_team)
		"knight_logic.gd":
			return KnightLogic.get_decision(monster, heroes_team)
		"wizard_logic.gd":
			return WizardLogic.get_decision(monster, heroes_team)
		"guardsman_logic.gd":
			return GuardsmanLogic.get_decision_castle(monster, heroes_team, enemies_team, current_round)
		"inquisitor_logic.gd":
			return InquisitorLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"kobold_logic.gd":
			return KoboldLogic.get_decision(monster, heroes_team, enemies_team)
		"dwarf_shield_logic.gd":
			return DwarfShieldLogic.get_decision(monster, heroes_team)
		"dwarf_smith_logic.gd":
			return DwarfSmithLogic.get_decision(monster, heroes_team, enemies_team)
		"golem_logic.gd":
			return GolemLogic.get_decision(monster, heroes_team)
		"stone_giant_warrior_logic.gd":
			return StoneGiantWarriorLogic.get_decision(monster, heroes_team)
		"stone_giant_shaman_logic.gd":
			return StoneGiantShamanLogic.get_decision(monster, heroes_team)
		"boulder_logic.gd":
			return BoulderLogic.get_decision(monster, heroes_team)
		"libra_logic.gd":
			return LibraLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"virgo_logic.gd":
			return VirgoLogic.get_decision(monster, heroes_team)
		"aquarius_logic.gd":
			return AquariusLogic.get_decision(monster, heroes_team)
		"aries_logic.gd":
			return AriesLogic.get_decision(monster, heroes_team)
		"scorpio_logic.gd":
			return ScorpioLogic.get_decision(monster, heroes_team)
		"gemini_logic.gd":
			return GeminiLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"flower_fairy_logic.gd":
			return FlowerFairyLogic.get_decision(monster, heroes_team)
		"thorn_fairy_logic.gd":
			return ThornFairyLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"alraune_logic.gd":
			return AlrauneLogic.get_decision(monster, heroes_team)
		"druid_logic.gd":
			return DruidLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"unicorn_logic.gd":
			return UnicornLogic.get_decision_with_allies(monster, heroes_team, enemies_team)
		"satyr_logic.gd":
			return SatyrLogic.get_decision(monster, heroes_team)
		_:
			# Незарегистрированный ИИ — fallback на случайную доступную способность
			return _get_random_ai_decision(monster)


# ══════════════════════════════════════════════
#  ИСПОЛЬЗОВАНИЕ СПОСОБНОСТЕЙ
# ══════════════════════════════════════════════

func _use_ability(attacker: Combatant, defender: Combatant, ability: AbilityResource):
	attacker.refresh_passive_auras()
	if defender != null:
		defender.refresh_passive_auras()
	_show_ability_banner(ability.get_display_name())
	var log_lines: Array[String] = []
	log_lines.append("%s использует «%s»." % [attacker.unit_name, ability.name])
	var total_damage_dealt: int = 0
	var voodoo_effect_snapshot: Array = _snapshot_active_effects()

	# ═══ Сердце природы: каждый раз, когда Дуна применяет способность, бог с наименьшим
	# HP в её команде восстанавливает 10% от макс. здоровья ═══
	if attacker.has_item_effect("duna_heart_heal_lowest"):
		var _dh_team = enemies_team if attacker.is_enemy else heroes_team
		var _dh_lowest: Combatant = null
		for _dh_u in _dh_team:
			if _dh_u and _dh_u.current_hp > 0:
				if _dh_lowest == null or _dh_u.current_hp < _dh_lowest.current_hp:
					_dh_lowest = _dh_u
		if _dh_lowest != null:
			var _dh_heal = int(_dh_lowest.max_hp * 0.10)
			if _dh_heal > 0:
				var _dh_hp_before = _dh_lowest.current_hp
				_dh_lowest.apply_stat_change("hp", _dh_heal)
				log_lines.append("  → [Сердце природы] %s восстанавливает %d HP (%d → %d)." % [_dh_lowest.unit_name, _dh_heal, _dh_hp_before, _dh_lowest.current_hp])

	# ═══ Метка невинности: 50% перенаправление одиночной атаки на случайного союзника цели ═══
	if ability.target_type != "Self" and ability.target_type != "All_Enemies" and ability.target_type != "All_Allies":
		if attacker.is_enemy != defender.is_enemy and effects._has_innocence(defender):
			var innocence_team: Array = heroes_team if not defender.is_enemy else enemies_team
			var innocence_allies: Array = _get_living_team_members(innocence_team).filter(func(unit): return unit != defender)
			if not innocence_allies.is_empty() and randf() < 0.5:
				var redirected_target: Combatant = innocence_allies.pick_random()
				log_lines.append("  → [Метка невинности] %s перенаправляет атаку на %s!" % [defender.unit_name, redirected_target.unit_name])
				defender = redirected_target

	# ═══ Сатир: 50% шанс перенаправить атаку против него на другого союзника ═══
	if ability.target_type != "Self" and ability.target_type != "All_Enemies" and ability.target_type != "All_Allies":
		if attacker.is_enemy != defender.is_enemy and defender.special_effect_type == "satyr_redirect":
			var satyr_team: Array = heroes_team if not defender.is_enemy else enemies_team
			var satyr_allies: Array = _get_living_team_members(satyr_team).filter(func(unit): return unit != defender)
			if not satyr_allies.is_empty() and randf() < 0.5:
				var satyr_redirected: Combatant = satyr_allies.pick_random()
				log_lines.append("  → [Сатир] Атака перенаправлена с %s на %s!" % [defender.unit_name, satyr_redirected.unit_name])
				defender = satyr_redirected

	# ═══ Провокация: перенаправление одиночной атаки (только при атаке ВРАГА) ═══
	if ability.target_type != "Self" and ability.target_type != "All_Enemies" and ability.target_type != "All_Allies":
		if attacker.is_enemy != defender.is_enemy:
			var target_team = enemies_team if defender.is_enemy else heroes_team
			for ally in target_team:
				if ally and ally.current_hp > 0 and ally != defender and effects._has_provocation(ally):
					if randf() < 0.5:
						log_lines.append("  → [Провокация] %s перенаправляет атаку на себя!" % ally.unit_name)
						defender = ally
					break
	
	# 1. Self-эффекты (бафф на атакующего и т.п.)
	for effect in ability.effect_types:
		if effect == "neverending_storm_mark":
			attacker.active_effects.append({
				"stat": "neverending_storm_mark",
				"value": 1,
				"duration": -1,
				"effect_id": "neverending_storm_mark",
				"dispellable": false
			})
			log_lines.append("  → %s получает Метку Вечной Бури (стаки: %d)." % [
				attacker.unit_name,
				attacker.active_effects.filter(func(e): return Combatant._effect_get(e, "effect_id", "") == "neverending_storm_mark").size()
			])
		elif effect.begins_with("self_"):
			var note = effects._apply_effect_to_target(attacker, attacker, effect, ability)
			if note != "":
				log_lines.append("  → " + note)
			
	# 2. Определение списка целей
	var targets = []
	if ability.target_type == "Self":
		targets = [attacker]
	elif ability.target_type == "All_Enemies" or ability.target_type == "All_Allies":
		targets = _get_all_targets(ability, attacker)
	else:
		targets.append(defender)
		if ability.extra_targets_count > 0:
			var team = enemies_team if defender.is_enemy else heroes_team
			for i in range(ability.extra_targets_count):
				var next_pos = defender.position_index + i + 1
				for unit in team:
					if unit and unit.position_index == next_pos and unit.current_hp > 0:
						targets.append(unit)
						break

	# ═══ Посейдон: «ШТОРМ» — реверс позиций противников, независимо от попадания/промаха ═══
	if ability.ability_marker == "poseidon_storm":
		var storm_lines = _swap_enemy_positions(attacker)
		for sl in storm_lines:
			log_lines.append(sl)

	for target_idx in range(targets.size()):
		var target = targets[target_idx]
		if target == null or target.current_hp <= 0:
			continue

		var deals_damage = ability.damage_modifier > 0
		# Флибустьер «Я знаю что делаю» / Матрос с бомбой «Бомбардировка»: damage_modifier
		# здесь используется только отложенным триггером стойки (2/4 удара в начале след. хода) —
		# сам момент входа в стойку не должен наносить немедленный удар по цели.
		if ability.stance_effect_type == "filibuster_double_hit" or ability.stance_effect_type == "bombardment_stance":
			deals_damage = false
		# Применять ли эффекты/дебаффы по цели: на союзника (или себя) — всегда;
		# на врага — по проверке точности vs уклонения, даже если способность не наносит
		# урон напрямую (иначе дебафф накладывался бы гарантированно, минуя промах).
		# Наносящие урон способности сами проверяют попадание чуть ниже.
		var attack_landed: bool = not deals_damage
		if not deals_damage and target.is_enemy != attacker.is_enemy:
			attack_landed = CombatCalculator.check_hit(attacker.accuracy, target.evasion)
			if not attack_landed:
				log_lines.append("  → %s промахивается мимо %s." % [attacker.unit_name, target.unit_name])
		var is_crit_landed: bool = false

		if deals_damage:
			# Налётчик реагирует на саму попытку атаки, даже на промах
			var targeted_note = target.on_targeted_by_attack()
			if targeted_note != "":
				log_lines.append("  → " + targeted_note)

			
			# ═══ Реакция стоек титанов на направленную по ним атаку ═══
			if target.active_stance != null:
				var _tstance = target.active_stance.stance_effect_type
				if _tstance == "titan_indestructible":
					target.apply_stat_change("armor", 5)
					target.active_effects.append({"stat": "armor", "value": 5, "duration": 3, "effect_id": "titan_indestructible_armor", "source_ability": "Несокрушимый"})
					log_lines.append("  → [Несокрушимый] %s: +5 брони за атаку по нему (3 хода)." % target.unit_name)
				elif _tstance == "titan_born_to_battle":
					target.apply_stat_change("damage", 10)
					target.active_effects.append({"stat": "damage", "value": 10, "duration": 2, "effect_id": "titan_born_to_battle_damage", "source_ability": "Рождённый для битвы"})
					log_lines.append("  → [Рождённый для битвы] %s: +10 урона за атаку по нему (2 хода)." % target.unit_name)
				elif _tstance == "kirin_lightning_dodge":
					# +3 уклонения за каждую единицу разницы в инициативе с атакующим
					var _kdiff = absi(target.initiative - attacker.initiative)
					var _kev = 3 * _kdiff
					if _kev > 0:
						target.apply_stat_change("evasion", _kev)
						target.active_effects.append({"stat": "evasion", "value": _kev, "duration": 1, "effect_id": "kirin_lightning_dodge", "source_ability": "kirin_lightning_fast"})
						log_lines.append("  → [Быстрый как молния] %s: +%d уклонения за разницу инициатив (%d)." % [target.unit_name, _kev, _kdiff])
				elif _tstance == "hoplite_shield_wall":
					# Поднять щиты: 0.6 ответного урона атакующему
					var _hs_dmg = int(target.damage * 0.6)
					if _hs_dmg > 0 and attacker.current_hp > 0:
						var _hs_hp_before = attacker.current_hp
						attacker.take_damage(_hs_dmg)
						log_lines.append("  → [Поднять щиты] %s наносит %d ответного урона %s. HP: %d → %d" % [target.unit_name, _hs_dmg, attacker.unit_name, _hs_hp_before, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен ответным уроном!" % attacker.unit_name)
							_on_unit_killed(attacker, log_lines)
							var _hs_team = heroes_team if attacker.is_enemy == false else enemies_team
							_compact_team(_hs_team)
							_apply_kappa_auras()
	
				# ═══ Сад — Единорог: пассивка — атаковавший получает -15 точности на 2 хода (даже при промахе) ═══
				if target.special_effect_type == "unicorn_counter_accuracy" and attacker.current_hp > 0:
					attacker.apply_stat_change("accuracy", -15)
					attacker.active_effects.append({"stat": "accuracy", "value": -15, "duration": 2, "effect_id": "unicorn_counter_accuracy", "source_ability": "Пассивка Единорога"})
					log_lines.append("  → [Единорог] %s теряет 15 точности за атаку по %s (2 хода)." % [attacker.unit_name, target.unit_name])
	
				# ═══ Сад — Фея шипов: «Колючий куст» — атаковавший получает 30% урона владельца марки ═══
				for _tb_e in target.active_effects:
					if Combatant._effect_get(_tb_e, "stat", "") == "thorn_bush_mark":
						var _tb_owner = _tb_e.get("owner", null)
						if _tb_owner and _tb_owner.current_hp > 0 and attacker.current_hp > 0:
							var _tb_dmg = int(_tb_owner.damage * 0.3)
							if _tb_dmg > 0:
								var _tb_hp_b = attacker.current_hp
								attacker.take_damage(_tb_dmg)
								log_lines.append("  → [Колючий куст] %s получает %d ответного урона. HP: %d → %d" % [attacker.unit_name, _tb_dmg, _tb_hp_b, attacker.current_hp])
						break
	
				# Рассчитываем урон через централизованный калькулятор
			var dmg_result: Dictionary
			# ═══ Замок — Стражник: бонус против убийц союзников ═══
			var _gkb_applied = false
			if attacker.special_effect_type == "guardsman_killer_bonus" and target.has_killed_enemy:
				attacker.accuracy_modifier += 30
				attacker.crit_modifier += 0.15
				_gkb_applied = true
			if ability.never_miss or ability.ability_marker == "centaur_precise_shot" or ability.ability_marker == "wizard_magic_arrow":
				# Точный выстрел / Волшебная стрела — никогда не промахивается
				dmg_result = CombatCalculator.calculate_forced_hit_damage(attacker, target, ability)
			elif ability.ability_marker == "chernobog_terrifying_end" and float(attacker.current_hp) / float(maxi(1, attacker.max_hp)) < 0.50:
				# Чернобог «Ужасный конец»: чистый урон (damage_type Pure) + не промахивается при HP < 50%.
				# damage_type временно переключается на Pure только для этого расчёта — при HP >= 50%
				# способность обычная физическая (см. .tres, где damage_type больше не задан статически).
				var _prev_damage_type := ability.damage_type
				ability.damage_type = "Pure"
				dmg_result = CombatCalculator.calculate_forced_hit_damage(attacker, target, ability)
				ability.damage_type = _prev_damage_type
				log_lines.append("  → [Ужасный конец] %s в отчаянии (HP<50%%) — атака не промахнётся и наносит чистый урон!" % attacker.unit_name)
			else:
				dmg_result = CombatCalculator.calculate_ability_damage(attacker, target, ability)
			if _gkb_applied:
				attacker.accuracy_modifier -= 30
				attacker.crit_modifier -= 0.15
				log_lines.append("  → [Стражник] +30 точности и +15%% удачи против убийцы союзников." % [])
			
			if not dmg_result.is_hit:
				attack_landed = false
				_show_miss_popup(target)
				log_lines.append("  → %s промахивается по %s." % [attacker.unit_name, target.unit_name])
				# ═══ OnMiss: способность «Подлая заточка» и аналогичные ═══
				if "condition" in ability and ability.condition == "OnMiss":
					effects._apply_effect_to_target(attacker, attacker, ability.condition_effect, ability)
					log_lines.append("  → [Промах] %s: срабатывает эффект %s." % [attacker.unit_name, ability.condition_effect])
				# Сусаноо «Отражение»: контратакует и промахнувшихся по нему
				if target.active_stance != null and target.active_stance.stance_effect_type == "susanoo_reflection" and target.current_hp > 0 and attacker.current_hp > 0:
					var _refl_miss_result = CombatCalculator.calculate_fixed_damage(target, attacker, 0.4)
					if _refl_miss_result.is_hit:
						var _refl_miss_hp_b = attacker.current_hp
						attacker.take_damage(_refl_miss_result.final_damage)
						log_lines.append("  → [Отражение] %s контратакует %s на %d урона. HP: %d → %d" % [target.unit_name, attacker.unit_name, _refl_miss_result.final_damage, _refl_miss_hp_b, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен Отражением!" % attacker.unit_name)
							_on_unit_killed(attacker, log_lines)
							_compact_team(heroes_team if not attacker.is_enemy else enemies_team)
			else:
				attack_landed = true
				var is_crit: bool = dmg_result.is_crit
				is_crit_landed = is_crit
				var raw_damage: int = dmg_result.raw_damage
				var final_damage: int = dmg_result.final_damage
				
				# ═══ Туннели — Кобольд: +30% урона, если у цели больше HP чем у атакующего ═══
				if attacker.special_effect_type == "kobold_hp_advantage" and target.current_hp > attacker.current_hp:
					final_damage = int(final_damage * 1.3)
					log_lines.append("  → [Преимущество HP] +30%% урона (цель здоровее).")

				# ═══ Топь — Леший: наносит дополнительный урон за каждый дебафф на цели ═══
				if attacker.special_effect_type == "leshy_damage_per_debuff":
					var _lsh_debuffs = _count_debuffs_on_unit(target)
					if _lsh_debuffs > 0:
						var _lsh_bonus = int(raw_damage * 0.1 * _lsh_debuffs)
						if _lsh_bonus > 0:
							final_damage += _lsh_bonus
							log_lines.append("  → [Леший] +%d урона за %d дебафф(ов) на цели." % [_lsh_bonus, _lsh_debuffs])
				
				# ═══ Туннели — Дварф-щитовик: -50% урона от атакующих на позициях 3-4 ═══
				if target.special_effect_type == "dwarf_shield_back_protect" and attacker.position_index >= 2:
					final_damage = int(final_damage * 0.5)
					log_lines.append("  → [Защитник тыла] %s получает на 50%% меньше урона с задних позиций." % target.unit_name)
				
				# Сирена: «На дно» — +0.5 множитель урона за каждый дебафф на цели
				if ability.ability_marker == "siren_to_the_bottom":
					var debuff_count = _count_debuffs_on_unit(target)
					if debuff_count > 0:
						var bonus = int(attacker.damage * 0.5 * debuff_count)
						final_damage += bonus
						log_lines.append("  → [На дно] +%d бонусного урона за %d дебафф(ов)." % [bonus, debuff_count])
				
				# ════ АД: модификаторы урона пассивок Hell ════
				# Суккуб: «Ласка кнута» — +0.1 урона за каждый дебафф на цели
				if ability.ability_marker == "succubus_whip":
					var _sw_debuffs = _count_debuffs_on_unit(target)
					if _sw_debuffs > 0:
						var _sw_bonus = int(raw_damage * 0.1 * _sw_debuffs)
						final_damage += _sw_bonus
						log_lines.append("  → [Ласка кнута] +%d урона за %d дебафф(ов)." % [_sw_bonus, _sw_debuffs])
				# Дьявол: «Наказание для недостойных» — +0.8 урона если у цели 0 величия
				if ability.ability_marker == "devil_punishment" and target.current_majesty <= 0:
					var _dp_bonus = int(raw_damage * 0.8)
					final_damage += _dp_bonus
					log_lines.append("  → [Наказание для недостойных] +%d урона (0 величия)." % _dp_bonus)
				# Адская гончая: пассивка — +1% урона за каждый 1% недостающего HP цели
				if attacker.special_effect_type == "hellhound_missing_hp_damage":
					var _hh_missing_pct = float(target.max_hp - target.current_hp) / float(maxi(1, target.max_hp)) * 100.0
					if _hh_missing_pct > 0:
						var _hh_bonus = int(final_damage * _hh_missing_pct / 100.0)
						if _hh_bonus > 0:
							final_damage += _hh_bonus
							log_lines.append("  → [Гончая] +%d урона за %d%% недостающего HP цели." % [_hh_bonus, int(_hh_missing_pct)])
				# Кошмар: пассивка — +1% урона за каждое величие, которого не хватает противнику до 100
				if attacker.special_effect_type == "nightmare_majesty_damage":
					var _nm_missing = maxi(0, 100 - target.current_majesty)
					if _nm_missing > 0:
						var _nm_bonus = int(final_damage * _nm_missing / 100.0)
						if _nm_bonus > 0:
							final_damage += _nm_bonus
							log_lines.append("  → [Кошмар] +%d урона за %d недостающего величия." % [_nm_bonus, _nm_missing])
				# Суккуб: пассивка — -30% урона от богов (кроме Дуна/Моргана/Чернобог) к Суккубу
				if target.special_effect_type == "succubus_god_resist" and not attacker.is_enemy:
					# attacker — бог (герой). Список иммунных: Дуна, Моргана, Чернобог
					var _sr_name = attacker.unit_name
					if _sr_name != "Дуна" and _sr_name != "Моргана Лефей" and _sr_name != "Моргана" and _sr_name != "Чернобог":
						final_damage = int(final_damage * 0.7)
						log_lines.append("  → [Суккуб] -30%% урона от бога %s." % _sr_name)
				# Асура: пассивка — если атака не критическая, урон по Асуре -50%
				if target.special_effect_type == "asura_noncrit_reduce" and not is_crit:
					final_damage = int(final_damage * 0.5)
					log_lines.append("  → [Асура] -50%% урона (не крит).")
				# Ракшас: «Злобный удар» — если у цели <10% удачи, урон становится чистым
				if ability.ability_marker == "rakshasa_vicious_strike" and target.crit_chance < 0.10:
					final_damage = raw_damage
					log_lines.append("  → [Злобный удар] Урон чистый (удача цели %d%% < 10%%)." % int(target.crit_chance * 100))
			
			# ═══ Кирин: «Нисхождение с небес» — +10% урона за каждый бафф на цели (до развеяния) ═══
				if ability.ability_marker == "kirin_heaven_descent":
					var _hd_buffs = _count_buffs_on_unit(target)
					if _hd_buffs > 0:
						var _hd_bonus = int(raw_damage * 0.10 * _hd_buffs)
						final_damage += _hd_bonus
						log_lines.append("  → [Нисхождение с небес] +%d урона за %d бафф(ов) цели." % [_hd_bonus, _hd_buffs])
				
				# ═══ Кирин: пассивка — +5% урона за каждую единицу разницы инициатив с целью ═══
				if attacker.special_effect_type == "kirin_initiative_damage":
					var _kidiff = absi(attacker.initiative - target.initiative)
					if _kidiff > 0:
						var _kibonus = int(raw_damage * 0.05 * _kidiff)
						final_damage += _kibonus
						log_lines.append("  → [Кирин] +%d урона за разницу инициатив (%d)." % [_kibonus, _kidiff])
				
				# ═══ Кощей: «Непослушание» — урон = base * (1 + своя броня%) ═══
				if ability.ability_marker == "koschei_disobedience":
					var armor_bonus = int(attacker.damage * float(attacker.armor) / 100.0)
					if armor_bonus > 0:
						final_damage += armor_bonus
						log_lines.append("  → [Непослушание] +%d урона за %d%% собственной брони Кощея." % [armor_bonus, attacker.armor])
				
				# ═══ Кощей: «Кончик иглы» — +0.6 множитель за каждый потерянный заряд жизни ═══
				if ability.ability_marker == "koschei_needle_tip":
					var missing_charges = attacker.get_max_life_charges() - attacker.life_charges
					if missing_charges > 0:
						var needle_bonus = int(attacker.damage * 0.6 * missing_charges)
						final_damage += needle_bonus
						log_lines.append("  → [Кончик иглы] +%d урона за %d потерянных зарядов." % [needle_bonus, missing_charges])
				
				# ═══ Аид: «Прах к праху» — +10% урона за каждый дебафф на цели ═══
				if ability.ability_marker == "hades_ash_to_ash":
					var debuff_cnt = _count_debuffs_on_unit(target)
					if debuff_cnt > 0:
						var ash_bonus = int(raw_damage * 0.10 * debuff_cnt)
						final_damage += ash_bonus
						log_lines.append("  → [Прах к праху] +%d бонусного урона за %d дебафф(ов)." % [ash_bonus, debuff_cnt])
				
				# ═══ Аид: «В Тартар» — урон = недостающее_HP * 0.8 (заменяет обычный урон) ═══
				if ability.ability_marker == "hades_to_tartarus":
					var missing_hp = target.max_hp - target.current_hp
					final_damage = int(missing_hp * 0.8)
					log_lines.append("  → [В Тартар] Урон = %d (80%% от недостающего HP %d/%d)." % [final_damage, missing_hp, target.max_hp])
				
				# ═══ Они: «Крошить кости» — +20% крита, если активна ярость Они ═══
				if ability.ability_marker == "oni_crush_bones" and not is_crit:
					var _oni_rage_on = false
					for _eff in attacker.active_effects:
						if Combatant._effect_get(_eff, "effect_id", "") == "oni_rage_active":
							_oni_rage_on = true
							break
					if _oni_rage_on and randf() < 0.20:
						is_crit = true
						final_damage = int(final_damage * CombatManager.get_crit_multiplier())
						log_lines.append("  → [Крошить кости] Ярость Они! Критический удар (+20% шанс).")
					
				# ═══ Замок — Рыцарь: «Отважный удар» — крит, если союзник погиб в этом раунде ═══
				if ability.ability_marker == "knight_brave_strike" and not is_crit:
					var _bs_ally_died = _enemies_died_this_round if attacker.is_enemy else _heroes_died_this_round
					if _bs_ally_died:
						is_crit = true
						final_damage = int(final_damage * CombatManager.get_crit_multiplier())
						log_lines.append("  → [Отважный удар] Союзник пал в этом раунде — критический удар!")
				
				# ═══ Титан: «Тяжёлый удар» — +урон равен текущему проценту брони атакующего ═══
				if ability.ability_marker == "titan_heavy_hit":
					var _th_bonus = int(attacker.damage * float(attacker.armor) / 100.0)
					if _th_bonus > 0:
						final_damage += _th_bonus
						log_lines.append("  → [Тяжёлый удар] +%d урона за %d%% брони." % [_th_bonus, attacker.armor])
				
				# ═══ Бессмертный: «Клинок востока» — +20% урона, если щит смерти ещё не использован ═══
				if ability.ability_marker == "immortal_eastern_blade":
					var _imm_shield_used = false
					for _eff in attacker.active_effects:
						if Combatant._effect_get(_eff, "effect_id", "") == "immortal_shield_used":
							_imm_shield_used = true
							break
					if not _imm_shield_used:
						var _eb_bonus = int(final_damage * 0.20)
						final_damage += _eb_bonus
						log_lines.append("  → [Клинок востока] +20%% урона (щит активен): +%d." % _eb_bonus)
				
				# ═══ Мумия: «Пагубное касание» — +0.2 за каждый дебафф на цели ═══
				if ability.ability_marker == "mummy_corrupting_touch":
					var _ct_debuffs = _count_debuffs_on_unit(target)
					if _ct_debuffs > 0:
						var _ct_bonus = int(attacker.damage * 0.2 * _ct_debuffs)
						final_damage += _ct_bonus
						log_lines.append("  → [Пагубное касание] +%d урона за %d дебафф(ов)." % [_ct_bonus, _ct_debuffs])
				
				# ═══ Моргана: «Чёрная молния» — чистый урон, если заклинание использовано в этом ходе ═══
				if ability.ability_marker == "morgan_black_lightning" and spells_used_this_round > 0:
					final_damage = raw_damage
					log_lines.append("  → [Чёрная молния] Заклинание использовано — чистый урон!")
				
				# ═══ Пушка: урон по цепочке целей — 150% первой цели, 120% второй, 90% третьей и далее ═══
				if attacker.special_effect_type == "cannon_position_damage":
					var _cannon_mult = maxf(0.3, 1.5 - 0.3 * target_idx)
					final_damage = int(final_damage * _cannon_mult)
					log_lines.append("  → [Пушка] Цель %d по цепочке: урон %d%% (%d)." % [target_idx + 1, int(_cannon_mult * 100), final_damage])
				
				# ═══ Шива: «Доверься судьбе» — урон режется на случайный 0-30% ═══
				if ability.ability_marker == "shiva_trust_fate":
					var _sf_fate = randi_range(0, 30)
					final_damage = int(final_damage * (1.0 - _sf_fate / 100.0))
					attacker.set_meta("shiva_trust_fate_pct", _sf_fate)
					log_lines.append("  → [Доверься судьбе] Урон уменьшен на %d%%." % _sf_fate)
			
			# ═══ Неуязвимость: если на цели эффект invulnerable, урон = 0 ═══
				var _is_invuln = false
				for _inv in target.active_effects:
					if Combatant._effect_get(_inv, "stat", "") == "invulnerable":
						_is_invuln = true
						break
				if _is_invuln:
					final_damage = 0
					log_lines.append("  → %s неуязвим! Урон поглощён." % target.unit_name)
				
				# Флаг крита для всплывающего числа (крупнее и полностью красное).
				if is_crit:
					target.pending_crit = true
				target.take_damage(final_damage)
				total_damage_dealt += final_damage
				if final_damage > 0:
					var thor_heal_note = _trigger_thor_fight_me_heal(target)
					if thor_heal_note != "":
						log_lines.append("  → " + thor_heal_note)
				if ability.ability_marker == "kappa_spear_strike" and final_damage > 0 and target.current_hp > 0:
					var triggered_dot: int = 0
					for kappa_eff in target.active_effects:
						if Combatant._effect_get(kappa_eff, "stat", "") == "periodic_damage":
							triggered_dot += int(Combatant._effect_get(kappa_eff, "value", 0))
					if triggered_dot > 0:
						var kappa_hp_before: int = target.current_hp
						target.take_damage(triggered_dot)
						log_lines.append("  → [Удар копья] %s получает %d уже висящего периодического урона. HP: %d → %d" % [target.unit_name, triggered_dot, kappa_hp_before, target.current_hp])
						if target.current_hp <= 0:
							_on_unit_killed(target, log_lines)

				# ════ Реакции новых механик на полученный целью урон ════
				# Шива «Карма»: 50% урона обратно атакующему + копирование своих дебаффов на него
				if final_damage > 0 and target.active_stance != null and target.active_stance.stance_effect_type == "shiva_karma" and target.current_hp > 0:
					var _km_amt = int(final_damage * 0.5)
					if _km_amt > 0 and attacker.current_hp > 0:
						var _km_hp_b = attacker.current_hp
						attacker.take_damage(_km_amt)
						log_lines.append("  → [Карма] %s отражает %d урона в %s. HP: %d → %d" % [target.unit_name, _km_amt, attacker.unit_name, _km_hp_b, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен Кармой!" % attacker.unit_name)
							_on_unit_killed(attacker, log_lines)
							_compact_team(heroes_team if not attacker.is_enemy else enemies_team)
							if _check_battle_end():
								for line in log_lines:
									_log_combat(line)
								return
					if attacker.current_hp > 0:
						for _km_eff in target.active_effects:
							var _km_st = Combatant._effect_get(_km_eff, "stat", "")
							var _km_vl = Combatant._effect_get(_km_eff, "value", 0)
							if _km_vl < 0 or _km_st == "periodic_damage" or _km_st == "stun":
								attacker.active_effects.append(_km_eff.duplicate())
								if _km_st == "stun":
									attacker.is_stunned = true
									attacker.check_stance_interruption("stun")
						log_lines.append("  → [Карма] %s копирует свои дебаффы на %s." % [target.unit_name, attacker.unit_name])
				# Сусаноо «Отражение»: пока стойка активна, каждый атаковавший его получает 40% урона в ответ
				if final_damage > 0 and target.active_stance != null and target.active_stance.stance_effect_type == "susanoo_reflection" and target.current_hp > 0 and attacker.current_hp > 0:
					var _refl_result = CombatCalculator.calculate_fixed_damage(target, attacker, 0.4)
					if _refl_result.is_hit:
						var _refl_hp_b = attacker.current_hp
						attacker.take_damage(_refl_result.final_damage)
						log_lines.append("  → [Отражение] %s контратакует %s на %d урона. HP: %d → %d" % [target.unit_name, attacker.unit_name, _refl_result.final_damage, _refl_hp_b, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен Отражением!" % attacker.unit_name)
							_on_unit_killed(attacker, log_lines)
							_compact_team(heroes_team if not attacker.is_enemy else enemies_team)
							if _check_battle_end():
								for line in log_lines:
									_log_combat(line)
								return
				# Самди «Кукла вуду»: связанный (позади) юнит получает 50% урона и копии дебаффов меченой цели
				if final_damage > 0:
					for _vd_e in target.active_effects:
						if Combatant._effect_get(_vd_e, "effect_id", "") == "voodoo_marked":
							var _vlink = _vd_e.get("linked", null)
							if _vlink != null and _vlink.current_hp > 0 and _vlink != attacker:
								var _vd_dmg = int(final_damage * 0.5)
								if _vd_dmg > 0:
									var _vd_hp_b = _vlink.current_hp
									_vlink.take_damage(_vd_dmg)
									log_lines.append("  → [Кукла вуду] %s получает %d урона (50%% от %s). HP: %d → %d" % [_vlink.unit_name, _vd_dmg, target.unit_name, _vd_hp_b, _vlink.current_hp])
							break
				# Дуна «Защита из корней»: атакующий получает % урона шипами (пока активен эффект root_thorns)
				if final_damage > 0 and attacker.current_hp > 0:
					for _rt_e in target.active_effects:
						if Combatant._effect_get(_rt_e, "effect_id", "") == "root_thorns":
							var _rt_pct = int(Combatant._effect_get(_rt_e, "value", 40))
							var _rt_dmg = int(final_damage * _rt_pct / 100.0)
							if _rt_dmg > 0:
								var _rt_hp_b = attacker.current_hp
								attacker.take_damage(_rt_dmg)
								log_lines.append("  → [Защита из корней] %s получает %d ответного урона (%d%%). HP: %d → %d" % [attacker.unit_name, _rt_dmg, _rt_pct, _rt_hp_b, attacker.current_hp])
								if attacker.current_hp <= 0:
									log_lines.append("  → %s повержен шипами корней!" % attacker.unit_name)
									_on_unit_killed(attacker, log_lines)
									_compact_team(heroes_team if not attacker.is_enemy else enemies_team)
									if _check_battle_end():
										for line in log_lines:
											_log_combat(line)
										return
							break
				# Один «Стая воронов»: атаковавший меченую позицию получает +15 точности (1 ход)
				if final_damage > 0 and attacker.current_hp > 0:
					var _rv_marked = false
					for _rv_e in target.active_effects:
						if Combatant._effect_get(_rv_e, "effect_id", "") == "raven_marked":
							_rv_marked = true
							break
					if not _rv_marked and marks != null:
						# Эффекта нет (юнит сменился/истёк) — проверяем позиционную марку.
						for _rv_m in marks.position_marks:
							if str(_rv_m.get("team", "")) == "enemy" \
									and int(_rv_m.get("position", -1)) == target.position_index \
									and str(_rv_m.get("effect_type", "")) == "raven_mark_accuracy":
								_rv_marked = true
								break
					if _rv_marked:
						var _rva_duration = _compute_effect_duration(attacker, attacker, 1, false)
						attacker.apply_stat_change("accuracy", 15)
						attacker.active_effects.append({"stat": "accuracy", "value": 15, "duration": _rva_duration, "effect_id": "raven_accuracy", "source_ability": "Стая воронов"})
						log_lines.append("  → [Стая воронов] %s получает +15 точности за атаку меченой позиции (%d ход(ов))." % [attacker.unit_name, _rva_duration])
					# Тролль: применил атаку, но не нанёс урона (промах/неуязвимость) — самооглушение на 1 ход
					if final_damage <= 0 and attacker.current_hp > 0 \
							and attacker.special_effect_type == "troll_self_stun_on_no_damage" and not attacker.is_stunned:
						attacker.is_stunned = true
						var _tss_duration = _compute_effect_duration(attacker, attacker, 1, true)
						attacker.active_effects.append({"stat": "stun", "value": 1, "duration": _tss_duration, "effect_id": "troll_self_stun", "source_ability": "Пассивка тролля"})
						attacker.check_stance_interruption("stun")
						_notify_stun_applied(attacker)
						log_lines.append("  → [Тролль] %s не нанёс урона и оглушает себя (1 ход)." % attacker.unit_name)
					# Дуна «Растительный яд»: союзник с баффом яда накладывает DoT 20% от урона ДУНЫ на 4 хода при атаке
				if final_damage > 0 and target.current_hp > 0 and attacker.has_meta("plant_poison_attacker_dmg"):
					var _pp_has = false
					for _pp_e in attacker.active_effects:
						if Combatant._effect_get(_pp_e, "effect_id", "") == "plant_poison_buff":
							_pp_has = true
							break
					if _pp_has:
						var _pp_dot = int(attacker.get_meta("plant_poison_attacker_dmg") * 0.2)
						if _pp_dot > 0:
							target.active_effects.append({"stat": "periodic_damage", "value": _pp_dot, "duration": 4, "source_ability": "Растительный яд"})
							log_lines.append("  → [Растительный яд] %s получает периодический урон (%d) на 4 хода." % [target.unit_name, _pp_dot])
				# Шива «Цикл разрушения»: при действии противника — 0.7 урона, при крите — повтор удара
				if final_damage > 0 and not attacker.has_meta("_dc_guard"):
					var _dc_shiva = null
					var _dc_opp = heroes_team if attacker.is_enemy else enemies_team
					for _dc_u in _dc_opp:
						if _dc_u != null and _dc_u.current_hp > 0 and _dc_u.active_stance != null and _dc_u.active_stance.stance_effect_type == "shiva_destruction_cycle":
							_dc_shiva = _dc_u
							break
					if _dc_shiva != null:
						attacker.set_meta("_dc_guard", true)
						for _dc_n in range(2):
							if attacker.current_hp <= 0 or _check_battle_end():
								break
							var _dc_r = CombatCalculator.calculate_fixed_damage(_dc_shiva, attacker, 0.7)
							if not _dc_r.is_hit:
								log_lines.append("  → [Цикл разрушения] %s промахивается по %s." % [_dc_shiva.unit_name, attacker.unit_name])
								break
							var _dc_hp_b = attacker.current_hp
							attacker.take_damage(_dc_r.final_damage)
							log_lines.append("  → [Цикл разрушения] %s наносит %d урона %s%s." % [_dc_shiva.unit_name, _dc_r.final_damage, attacker.unit_name, " (крит!)" if _dc_r.is_crit else ""])
							if attacker.current_hp <= 0:
								log_lines.append("  → %s повержен Циклом разрушения!" % attacker.unit_name)
								_on_unit_killed(attacker, log_lines)
								_compact_team(heroes_team if not attacker.is_enemy else enemies_team)
								break
							if not _dc_r.is_crit:
								break
						attacker.remove_meta("_dc_guard")
	
				# ═══ Грифон: первый атакующий в раунде получает 100% урона (если удар не смертельный) ═══
				if final_damage > 0 and target.special_effect_type == "griffin_first_strike" and not target.griffin_first_strike_used and target.current_hp > 0 and attacker.current_hp > 0:
					target.griffin_first_strike_used = true
					var _gs_dmg = target.damage
					var _gs_hp_b = attacker.current_hp
					attacker.take_damage(_gs_dmg)
					log_lines.append("  → [Грифон] %s наносит %d ответного урона %s (первая атака). HP: %d → %d" % [target.unit_name, _gs_dmg, attacker.unit_name, _gs_hp_b, attacker.current_hp])
					if attacker.current_hp <= 0:
						log_lines.append("  → %s повержен ответным уроном Грифона!" % attacker.unit_name)
						_on_unit_killed(attacker, log_lines)
						var _gs_team = heroes_team if not attacker.is_enemy else enemies_team
						_compact_team(_gs_team)
						if _check_battle_end():
							for line in log_lines:
								_log_combat(line)
							return
				# ═══ Птица: при смерти от атаки наносит 0,8 урона убийце ═══
				if final_damage > 0 and target.current_hp <= 0 and target.special_effect_type == "bird_death_damage" and attacker.current_hp > 0:
					var _bd_dmg = int(target.damage * 0.8)
					var _bd_hp_b = attacker.current_hp
					attacker.take_damage(_bd_dmg)
					log_lines.append("  → [Птица] %s наносит %d урона %s перед смертью. HP: %d → %d" % [target.unit_name, _bd_dmg, attacker.unit_name, _bd_hp_b, attacker.current_hp])
					if attacker.current_hp <= 0:
						log_lines.append("  → %s повержен ответным уроном Птицы!" % attacker.unit_name)
						_on_unit_killed(attacker, log_lines)
						var _bd_team = heroes_team if not attacker.is_enemy else enemies_team
						_compact_team(_bd_team)
						if _check_battle_end():
							for line in log_lines:
								_log_combat(line)
							return
				
				# Джаггернаут и берсерк — только при реальном уроне
				if final_damage > 0:
					var hit_note = target.on_hit_by_attack()
					if hit_note != "":
						log_lines.append("  → " + hit_note)
					# ═══ Кикимора: «Неоценённая красота» — при получении урона всем противникам 0.2 урона ═══
					if target.active_stance != null and target.active_stance.stance_effect_type == "kikimora_beauty" and target.current_hp > 0:
						var _kk_dmg = int(target.damage * 0.2)
						if _kk_dmg > 0:
							var _kk_foes = heroes_team if target.is_enemy else enemies_team
							for _kk_foe in _kk_foes:
								if _kk_foe != null and _kk_foe.current_hp > 0:
									var _kk_hp_b = _kk_foe.current_hp
									_kk_foe.take_damage(_kk_dmg)
									log_lines.append("  → [Неоценённая красота] %s наносит %d урона %s. HP: %d → %d" % [target.unit_name, _kk_dmg, _kk_foe.unit_name, _kk_hp_b, _kk_foe.current_hp])
				# ═══ Звёзды — Весы: «Равновесие» — союзник получил урон → все враги получают 1/4 чистым ═══
					var _lb_team = enemies_team if target.is_enemy else heroes_team
					for _lb_ally in _lb_team:
						if _lb_ally == null or _lb_ally.current_hp <= 0 or _lb_ally == target:
							continue
						if _lb_ally.active_stance != null and _lb_ally.active_stance.stance_effect_type == "libra_balance":
							var _lb_reflect = int(final_damage / 4.0)
							if _lb_reflect > 0:
								var _lb_foe_team = heroes_team if _lb_ally.is_enemy else enemies_team
								for _lb_foe in _lb_foe_team:
									if _lb_foe != null and _lb_foe.current_hp > 0:
										var _lfb = _lb_foe.current_hp
										_lb_foe.take_damage(_lb_reflect)
										log_lines.append("  → [Равновесие] %s отражает %d чистого урона на %s. HP: %d → %d" % [_lb_ally.unit_name, _lb_reflect, _lb_foe.unit_name, _lfb, _lb_foe.current_hp])
								break
					# ═══ Угорь: 5% шанс контр-оглушения при получении урона (x2 если двигался) ═══
					if target.special_effect_type == "eel_counter_stun" and attacker.current_hp > 0:
						var _cs_chance = 0.05 * (2.0 if target.moved_this_round else 1.0)
						if randf() < _cs_chance:
							attacker.is_stunned = true
							attacker.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Пассивка Угря"})
							attacker.check_stance_interruption("stun")
							log_lines.append("  → [Угорь] %s: %s оглушён контратакой!" % [target.unit_name, attacker.unit_name])
					# ═══ Мумия: при попадании по ней атакующий теряет -5 макс. HP до конца боя (рассеиваемо) ═══
					if target.special_effect_type == "mummy_hit_max_hp_reduce" and attacker.current_hp > 0:
						attacker.max_hp = maxi(1, attacker.max_hp - 5)
						attacker.active_effects.append({"stat": "max_hp", "value": -5, "duration": -1, "effect_id": "mummy_curse_max_hp", "source_ability": "Аура мумии"})
						if attacker.current_hp > attacker.max_hp:
							attacker.current_hp = attacker.max_hp
						log_lines.append("  → [Мумия] %s: -5 макс. HP (итого %d) до конца боя." % [attacker.unit_name, attacker.max_hp])
					# ═══ Лавовый кабан: пассивка — при попадании атакующий получает урон (% от урона кабана) ═══
					if target.special_effect_type == "lava_boar_thorns" and attacker.current_hp > 0:
						var _th_pct = _lava_boar_thorns_percent(target)
						var _th_dmg = int(target.damage * _th_pct / 100.0)
						if _th_dmg > 0:
							var _th_hp_before = attacker.current_hp
							attacker.take_damage(_th_dmg)
							log_lines.append("  → [Горячее сердце] %s отражает %d урона (%d%%) на %s. HP: %d → %d" % [
								target.unit_name, _th_dmg, _th_pct, attacker.unit_name, _th_hp_before, attacker.current_hp])
							if attacker.current_hp <= 0:
								log_lines.append("  → %s повержен отражённым уроном!" % attacker.unit_name)
								_on_unit_killed(attacker, log_lines)
								var _th_team = heroes_team if attacker.is_enemy == false else enemies_team
								_compact_team(_th_team)
								_apply_kappa_auras()
				
				# Матрос с бомбой: при HP <20% — толкает вперёд на 2 (однократно)
				if target.special_effect_type == "sailor_bomber_low_hp" and target.current_hp > 0:
					if float(target.current_hp) / float(target.max_hp) < 0.20:
						var already_triggered = false
						for eff in target.active_effects:
							if Combatant._effect_get(eff, "effect_id", "") == "sailor_bomber_low_hp_triggered":
								already_triggered = true
								break
						if not already_triggered:
							var old_pos_bomber = target.position_index
							_apply_shift_effect(target, -2, false)
							target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "sailor_bomber_low_hp_triggered"})
							log_lines.append("  → [Матрос с бомбой] %s: HP <20%%, толкается вперёд (линия %d → %d)!" % [target.unit_name, old_pos_bomber + 1, target.position_index + 1])
				
				# ═══ Они: «Ярость Они» — при HP <50% активируется ярость (+5 инициативы, +15 урона) ═══
				if target.special_effect_type == "oni_rage" and target.current_hp > 0:
					if float(target.current_hp) / float(target.max_hp) < 0.50:
						var _oni_rage_on = false
						for _eff in target.active_effects:
							if Combatant._effect_get(_eff, "effect_id", "") == "oni_rage_active":
								_oni_rage_on = true
								break
						if not _oni_rage_on:
							target.apply_stat_change("initiative", 5)
							target.apply_stat_change("damage", 15)
							target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "oni_rage_active"})
							log_lines.append("  → [Ярость Они] %s: HP <50%%, ярость! +5 инициативы, +15 урона до конца боя." % target.unit_name)
				
				# Пассивка атакующего — Флибустьер: +10% удачи при крите
				if is_crit and attacker.special_effect_type == "filibuster_crit_luck" and final_damage > 0:
					attacker.crit_modifier += 0.10
					log_lines.append("  → [Флибустьер] %s: +10%% к удаче за крит (итого %d%%)" % [attacker.unit_name, int(attacker.crit_chance * 100)])
				
				# Пассивка атакующего — Сусаноо: +5% удачи за каждое попадание
				if attacker.special_effect_type == "susanoo_hit_crit" and final_damage > 0:
					attacker.crit_modifier += 0.05
					log_lines.append("  → [Сусаноо] +5%% к удаче (итого: %d%%)" % int(attacker.crit_chance * 100))
					# Тоцука-но цуруги: пассивка Сусаноо даёт ещё +2% удачи за стак
					if attacker.has_item_effect("susanoo_extra_luck_stack"):
						attacker.crit_modifier += 0.02
						log_lines.append("  → [Тоцука-но цуруги] +2%% к удаче (итого: %d%%)" % int(attacker.crit_chance * 100))

				# Копьё Гора: каждое попадание по противнику даёт +5 величия
				if final_damage > 0 and attacker.has_item_effect("horus_spear_majesty_on_hit"):
					var _hs_majesty_before = attacker.current_majesty
					attacker.modify_majesty(5)
					if attacker.current_majesty != _hs_majesty_before:
						log_lines.append("  → [Копьё Гора] %s получает 5 величия (итого: %d)." % [attacker.unit_name, attacker.current_majesty])

				# Молния Зевса: критические атаки наносят периодический урон (30% урона, 3 хода)
				if is_crit and final_damage > 0 and attacker.has_item_effect("zeus_lightning_crit_dot") and target.current_hp > 0:
					var _zl_dot = int(attacker.damage * 0.3)
					if _zl_dot > 0:
						var _zl_duration = _compute_effect_duration(attacker, target, 3, true)
						target.active_effects.append({"stat": "periodic_damage", "value": _zl_dot, "duration": _zl_duration, "source_ability": "Молния Зевса"})
						log_lines.append("  → [Молния Зевса] %s получает %d периодического урона на %d хода." % [target.unit_name, _zl_dot, _zl_duration])

				# Сокрушающий землю: критические удары наносят 50% урона соседним целям
				if is_crit and final_damage > 0 and attacker.has_item_effect("earth_crusher_crit_splash") and target.current_hp > 0:
					var _ec_team = enemies_team if target.is_enemy else heroes_team
					var _ec_splash = int(final_damage * 0.5)
					if _ec_splash > 0:
						for _ec_pos in [target.position_index - 1, target.position_index + 1]:
							for _ec_u in _ec_team:
								if _ec_u and _ec_u.current_hp > 0 and _ec_u.position_index == _ec_pos:
									var _ec_hp_before = _ec_u.current_hp
									_ec_u.take_damage(_ec_splash)
									log_lines.append("  → [Сокрушающий землю] %s получает %d урона (сплэш). HP: %d → %d" % [_ec_u.unit_name, _ec_splash, _ec_hp_before, _ec_u.current_hp])
									if _ec_u.current_hp <= 0:
										log_lines.append("  → %s повержен!" % _ec_u.unit_name)
										_ec_u.killed_by = attacker
										_on_unit_killed(_ec_u, log_lines)
										_compact_team(_ec_team)
										_apply_kappa_auras()
									break

				# Колесо сансары: у кого-то из команды атакующего есть артефакт — кто кританул, лечится
				# на 5% от нанесённого критического урона.
				if is_crit and final_damage > 0:
					var _sw_team = enemies_team if attacker.is_enemy else heroes_team
					for _sw_u in _sw_team:
						if _sw_u and _sw_u.current_hp > 0 and _sw_u.has_item_effect("samsara_wheel_crit_heal"):
							var _sw_heal = int(final_damage * 0.05)
							if _sw_heal > 0:
								attacker.apply_stat_change("hp", _sw_heal)
								log_lines.append("  → [Колесо сансары] %s восстанавливает %d HP от критического урона." % [attacker.unit_name, _sw_heal])
							break
				
				# Пассивка атакующего — Локи: крит = стан на цели (1 ход)
				if is_crit and attacker.special_effect_type == "loki_crit_stun" and target.current_hp > 0:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1})
					target.check_stance_interruption("stun")
					_notify_stun_applied(target)
					log_lines.append("  → [Локи] %s оглушён критическим ударом!" % target.unit_name)
				# ════ ДЖУНГЛИ: on_crit пассивки ════
				# Нага воин: «Удар хвостом» — при крите стан
				if is_crit and ability.ability_marker == "naga_tail_strike" and target.current_hp > 0 and not target.is_stunned:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Удар хвостом"})
					target.check_stance_interruption("stun")
					_notify_stun_applied(target)
					log_lines.append("  → [Удар хвостом] %s оглушён критом!" % target.unit_name)
				# Сару: пассивка — при любом крите все Сару получают +7% уклонения на 1 ход
				if is_crit:
					var _sr_team = heroes_team if attacker.is_enemy else enemies_team
					for _sr_u in _sr_team:
						if _sr_u != null and _sr_u.current_hp > 0 and _sr_u.special_effect_type == "saru_crit_evasion":
							_sr_u.apply_stat_change("evasion", 7)
							_sr_u.active_effects.append({"stat": "evasion", "value": 7, "duration": 1, "effect_id": "saru_crit_ev", "source_ability": "Пассивка Сару"})
							log_lines.append("  → [Сару] %s получает +7%% уклонения за крит (1 ход)." % _sr_u.unit_name)
				# Коатль: пассивка — при крите восстанавливает 5% HP
				if is_crit and attacker.special_effect_type == "coatl_crit_heal":
					var _ct_heal = int(attacker.max_hp * 0.05)
					if _ct_heal > 0:
						attacker.apply_stat_change("hp", _ct_heal)
						log_lines.append("  → [Коатль] %s восстанавливает %d HP за крит." % [attacker.unit_name, _ct_heal])
				# Асура: пассивка — если атака НЕ крит, урон по Асуре -50% (ниже в блоке урона)

				# ═══ Лавовый кабан: «Поднять на бивни» — при крите цель оглушается ═══
				if is_crit and ability.ability_marker == "lava_boar_tusk_lift" and target.current_hp > 0 and not target.is_stunned:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "lava_boar_tusk_lift"})
					target.check_stance_interruption("stun")
					_notify_stun_applied(target)
					log_lines.append("  → [Поднять на бивни] %s оглушён критическим ударом!" % target.unit_name)
				
				# ═══ Замок — Принцесса: «Истерика» — при крите цель оглушается ═══
				if is_crit and ability.ability_marker == "princess_hysteria" and target.current_hp > 0 and not target.is_stunned:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Истерика"})
					target.check_stance_interruption("stun")
					_notify_stun_applied(target)
					log_lines.append("  → [Истерика] %s оглушён критическим ударом!" % target.unit_name)
				
				# ═══ Гладиатор: «Танец клинков» — при крите 20% периодического урона на 2 хода ═══
				if is_crit and ability.ability_marker == "gladiator_blade_dance" and target.current_hp > 0:
					var _bd_dmg = int(target.max_hp * 0.20)
					if _bd_dmg > 0:
						target.active_effects.append({"stat": "periodic_damage", "value": _bd_dmg, "duration": 2, "source_ability": "Танец клинков"})
						log_lines.append("  → [Танец клинков] %s получает %d периодического урона на 2 хода (крит)." % [target.unit_name, _bd_dmg])
				
				# ═══ OnCrit: условие способности — срабатывает при критическом ударе ═══
				if is_crit and "condition" in ability and ability.condition == "OnCrit":
					if ability.ability_marker == "loki_replay":
						var behind_pos = target.position_index + 1
						var replay_team = enemies_team if target.is_enemy else heroes_team
						for behind_unit in replay_team:
							if behind_unit and behind_unit.current_hp > 0 and behind_unit.position_index == behind_pos:
								# 15% от урона Локи — периодический урон на юнит позади жертвы крита
								var pdmg = int(attacker.damage * 0.15)
								if pdmg > 0:
									behind_unit.active_effects.append({"stat": "periodic_damage", "value": pdmg, "duration": 2, "source_ability": "Переиграть"})
									log_lines.append("  → [Переиграть/Крит] %s (за %s) получает периодический урон (%d) на 2 хода." % [behind_unit.unit_name, target.unit_name, pdmg])
								break
					else:
						effects._apply_effect_to_target(attacker, attacker, ability.condition_effect, ability)
						log_lines.append("  → [Крит] %s: срабатывает условие %s." % [attacker.unit_name, ability.condition_effect])
				
				# ═══ Локация: Облака — после попадания по врагу (не богу) ═══
				if CombatManager.selected_location_id == "clouds" and target.is_enemy and final_damage > 0 and target.current_hp > 0:
					var _clouds_val = 20 if target.special_effect_type == "cupid_double_location" else 10
					target.apply_stat_change("evasion", _clouds_val)
					target.active_effects.append({
						"stat": "evasion", "value": _clouds_val, "duration": 1,
						"effect_id": "clouds_evasion", "source_ability": "Облака"
					})
					log_lines.append("  → [Облака] %s получает +%d уклонения на 1 ход (складывается)." % [target.unit_name, _clouds_val])
					effects._check_pegasus_ally_buff(target, log_lines)
				
				if final_damage > 0:
					var crit_text = " (крит!)" if is_crit else ""
					var armor_note = ""
					if ability.damage_type == "Physical" and final_damage < raw_damage:
						armor_note = " (броня %d%%)" % target.armor
					log_lines.append("  → %s получает %d урона%s%s. HP: %d → %d" % [
						target.unit_name, final_damage, crit_text, armor_note, dmg_result.hp_before, target.current_hp
					])
					# ═══ Сфинкс: «Загадка» — меченый атакующий, ранивший сфинкса ═══
					if target.special_effect_type == "sphinx_debuff_immune":
						var _riddle_on_attacker = false
						for _eff in attacker.active_effects:
							if Combatant._effect_get(_eff, "effect_id", "") == "sphinx_riddle":
								_riddle_on_attacker = true
								break
						if _riddle_on_attacker:
							_resolve_sphinx_riddle(attacker, target, log_lines)
				else:
					log_lines.append("  → %s: урон %d полностью поглощён броней (%d%%)." % [
						target.unit_name, raw_damage, target.armor
					])
		
		if "condition" in ability and ability.condition == "OnKill" and target.current_hp <= 0:
			effects._apply_effect_to_target(attacker, attacker, ability.condition_effect, ability)
		
		# ═══ Кощей: заряды жизни — при смерти восстановить 50% HP вместо гибели ═══
		if target.current_hp <= 0 and target.special_effect_type == "koschei_life_charges" and target.life_charges > 0:
			target.life_charges -= 1
			target.current_hp = int(target.max_hp * 0.5)
			target.active_effects.clear()
			log_lines.append("  → [Кощей] %s теряет 1 заряд жизни (осталось: %d). HP: %d → %d" % [
				target.unit_name, target.life_charges, 0, target.current_hp])
		# ═══ Бессмертный: щит смерти — впервые при HP=0 восстановить полное HP ═══
		elif target.current_hp <= 0 and target.special_effect_type == "immortal_death_shield":
			var _imm_used = false
			for _eff in target.active_effects:
				if Combatant._effect_get(_eff, "effect_id", "") == "immortal_shield_used":
					_imm_used = true
					break
			if not _imm_used:
				target.current_hp = target.max_hp
				target.active_effects.clear()
				target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "immortal_shield_used"})
				log_lines.append("  → [Щит смерти] %s: восстанавливает полное HP (%d) вместо гибели!" % [target.unit_name, target.current_hp])
		if target.current_hp <= 0:
			log_lines.append("  → %s повержен!" % target.unit_name)
			target.killed_by = attacker
			_on_unit_killed(target, log_lines)
			var team = heroes_team if target.is_enemy == false else enemies_team
			_compact_team(team)
			_apply_kappa_auras()
			
			if _check_battle_end():
				for line in log_lines:
					_log_combat(line)
				return
			
		# Эффекты/дебаффы и снос стоек применяются только при попадании
		# (для способностей без урона attack_landed всегда true).
		if attack_landed:
			if ability.breaks_enemy_stances:
				target.break_stance()
				
			for effect in ability.effect_types:
				if not effect.begins_with("self_"):
					var effect_note = effects._apply_effect_to_target(attacker, target, effect, ability, is_crit_landed)
					if effect_note != "":
						log_lines.append("  → " + effect_note)
		
		# ═══ Специфичные обработчики маркеров способностей богов ═══
		
		# Осирис: «Опаляющий свет» — 0.3 от урона Осириса периодического урона на 3 хода
		if ability.ability_marker == "osiris_scorching_light" and target.current_hp > 0:
			var _sl_dot = int(attacker.damage * 0.3)
			if _sl_dot > 0:
				var _sl_duration = _compute_effect_duration(attacker, target, 3, true)
				target.active_effects.append({"stat": "periodic_damage", "value": _sl_dot, "duration": _sl_duration, "source_ability": "Опаляющий свет"})
				log_lines.append("  → [Опаляющий свет] %s получает %d периодического урона на %d хода." % [target.unit_name, _sl_dot, _sl_duration])

		# Тор: «Удар молота» — если у цели больше 50 брони, ударить ещё раз
		if ability.ability_marker == "thor_hammer_strike" and target.current_hp > 0 and target.armor > 50:
			var hammer_repeat = CombatCalculator.calculate_ability_damage(attacker, target, ability)
			if hammer_repeat.is_hit:
				target.take_damage(hammer_repeat.final_damage)
				total_damage_dealt += hammer_repeat.final_damage
				log_lines.append("  → [Удар молота] Броня цели выше 50 — повторный удар: %d урона. HP: %d → %d" % [
					hammer_repeat.final_damage, hammer_repeat.hp_before, target.current_hp])
				if target.current_hp <= 0:
					log_lines.append("  → %s повержен!" % target.unit_name)
					_on_unit_killed(target, log_lines)
					var team_hammer = heroes_team if target.is_enemy == false else enemies_team
					_compact_team(team_hammer)
					_apply_kappa_auras()
					if _check_battle_end():
						for line in log_lines:
							_log_combat(line)
						return
			else:
				log_lines.append("  → [Удар молота] Броня цели выше 50 — повторный удар промахнулся.")

		# Сусаноо: «Танец меча» — исцеление 12% HP за каждое убийство этой способностью
		if ability.ability_marker == "susanoo_sword_dance" and target.current_hp <= 0:
			var sd_heal = int(attacker.max_hp * 0.12)
			if sd_heal > 0:
				var hp_before_sd = attacker.current_hp
				attacker.apply_stat_change("hp", sd_heal)
				log_lines.append("  → [Танец меча] %s исцеляется на %d HP за убийство. HP: %d → %d" % [
					attacker.unit_name, sd_heal, hp_before_sd, attacker.current_hp])
		
		# Сет: «Разорвать» — повторить удар за каждый бафф на цели.
		# Повторы идут за каждый бафф (и при промахах), но дебафф брони —
		# только за ПОПАВШИЕ повторные удары (-5 брони на 3 хода за попадание).
		if ability.ability_marker == "set_tear_apart" and target.current_hp > 0:
			var buff_count = _count_buffs_on_unit(target)
			var tear_hits := 0
			for repeat_i in range(buff_count):
				if target.current_hp <= 0:
					break
				var rep_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.3)
				if rep_result.is_hit:
					tear_hits += 1
					target.take_damage(rep_result.final_damage)
					log_lines.append("  → [Разорвать] Повтор #%d: %s получает %d урона. HP: %d → %d" % [
						repeat_i + 1, target.unit_name, rep_result.final_damage, rep_result.hp_before, target.current_hp])
					if target.current_hp <= 0:
						log_lines.append("  → %s повержен!" % target.unit_name)
						_on_unit_killed(target, log_lines)
						var team_t = heroes_team if target.is_enemy == false else enemies_team
						_compact_team(team_t)
						_apply_kappa_auras()
						if _check_battle_end():
							for line in log_lines:
								_log_combat(line)
							return
				else:
					log_lines.append("  → [Разорвать] Повтор #%d: промах по %s." % [repeat_i + 1, target.unit_name])
			if tear_hits > 0:
				var _ta_duration = _compute_effect_duration(attacker, target, 3, true)
				target.apply_stat_change("armor", -5 * tear_hits)
				target.active_effects.append({"stat": "armor", "value": -5 * tear_hits, "duration": _ta_duration, "effect_id": "set_tear_apart_armor", "source_ability": "Разорвать"})
				log_lines.append("  → [Разорвать] %s теряет %d брони на %d хода (%d попаданий из %d)." % [target.unit_name, 5 * tear_hits, _ta_duration, tear_hits, buff_count])

		# Сет: «В саркофаг» — оглушить союзника + неуязвимость до следующего хода Сета
		if ability.ability_marker == "set_sarcophagus":
			target.is_stunned = true
			var _sc_stun_duration = _compute_effect_duration(attacker, target, 1, true)
			var _sc_invul_duration = _compute_effect_duration(attacker, target, 1, false)
			target.active_effects.append({"stat": "stun", "value": 1, "duration": _sc_stun_duration, "effect_id": "sarcophagus_stun", "source_ability": "В саркофаг"})
			target.active_effects.append({"stat": "invulnerable", "value": 1, "duration": _sc_invul_duration, "effect_id": "sarcophagus_invul", "source_ability": "В саркофаг"})
			target.check_stance_interruption("stun")
			log_lines.append("  → [В саркофаг] %s оглушён и неуязвим до следующего хода Сета." % target.unit_name)
		
		# Сет: «Узурпировать» — заменить свою ульту на ульту выбранного союзника.
		if ability.ability_marker == "set_usurp":
			if target.ultimate_ability and target != attacker:
				var copied_ult: AbilityResource = target.ultimate_ability
				attacker.ultimate_ability = copied_ult
				attacker.has_usurped_ultimate = true
				log_lines.append("  → [Узурпировать] %s забирает ульту «%s» у %s." % [
					attacker.unit_name, copied_ult.name, target.unit_name])
			elif target == attacker:
				log_lines.append("  → [Узурпировать] Нельзя узурпировать собственную ульту.")
			else:
				log_lines.append("  → [Узурпировать] У %s нет ульты." % target.unit_name)
		
		# Локи: «Танец бога обмана» — +30 уклонения (2 хода), вперёд 1,
		# каждый враг -10 удачи (2 хода), за каждого врага +10 удачи (2 хода).
		if ability.ability_marker == "loki_trickster_dance":
			# +30 уклонения на 1 ход (+1, если у команды есть пассивка Одина)
			var _ltd_duration = _compute_effect_duration(attacker, attacker, 1, false)
			attacker.apply_stat_change("evasion", 30)
			attacker.active_effects.append({"stat": "evasion", "value": 30, "duration": _ltd_duration, "effect_id": "loki_trickster_evasion", "source_ability": "Танец бога обмана"})
			# Двинуть себя вперёд на 1
			if not attacker.is_large:
				var _td_old = attacker.position_index
				_apply_shift_effect(attacker, -1, _is_player_hero(attacker))
				log_lines.append("  → [Танец бога обмана] %s: вперёд 1 (линия %d → %d)." % [attacker.unit_name, _td_old + 1, attacker.position_index + 1])
			# Каждый враг -10 удачи; за каждого врага +10 удачи на 2 хода
			var trick_enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
			var trick_count = 0
			var _ltd_debuff_duration = 2
			for trick_target in trick_enemies:
				_ltd_debuff_duration = _compute_effect_duration(attacker, trick_target, 2, true)
				trick_target.apply_stat_change("crit", -10)
				trick_target.active_effects.append({"stat": "crit", "value": -10, "duration": _ltd_debuff_duration, "effect_id": "loki_trickster_debuff", "source_ability": "Танец бога обмана"})
				trick_count += 1
			if trick_count > 0:
				var _ltd_buff_duration = _compute_effect_duration(attacker, attacker, 2, false)
				attacker.apply_stat_change("crit", 10 * trick_count)
				attacker.active_effects.append({"stat": "crit", "value": 10 * trick_count, "duration": _ltd_buff_duration, "effect_id": "loki_trickster_buff", "source_ability": "Танец бога обмана"})
			log_lines.append("  → [Танец бога обмана] %s: +30 уклонения (2 хода), %d враг(ов) теряют по 10 удачи, +%d удачи (2 хода)." % [attacker.unit_name, trick_count, 10 * trick_count])
		
		# Кощей: «Чахнуть над златом» — восстановить 15 фантазии, снять дебаффы
		if ability.ability_marker == "koschei_hoard_gold":
			current_fantasy = mini(max_fantasy, current_fantasy + 15)
			effects._dispel_effects(attacker, "debuff")
			_update_spell_ui()
			log_lines.append("  → [Чахнуть над златом] %s восстанавливает 15 фантазии (итого: %d) и снимает дебаффы." % [
				attacker.unit_name, current_fantasy])
		
		# Кощей: «Назад!» — восстановить 1 заряд жизни + 20 брони
		if ability.ability_marker == "koschei_go_back":
			if attacker.life_charges < attacker.get_max_life_charges():
				attacker.life_charges += 1
				log_lines.append("  → [Назад!] %s восстанавливает 1 заряд жизни (осталось: %d)." % [
					attacker.unit_name, attacker.life_charges])
			else:
				log_lines.append("  → [Назад!] %s уже имеет максимум зарядов жизни." % attacker.unit_name)
			var _gb_duration = _compute_effect_duration(attacker, attacker, 1, false)
			attacker.apply_stat_change("armor", 20)
			attacker.active_effects.append({"stat": "armor", "value": 20, "duration": _gb_duration, "effect_id": "koschei_go_back_armor", "source_ability": "Назад!"})
			log_lines.append("  → [Назад!] %s получает +20 брони на %d ход(ов)." % [attacker.unit_name, _gb_duration])
		
		# Аид: «Касание смерти» — продлить все дебаффы на цели на 1 ход
		if ability.ability_marker == "hades_death_touch":
			for eff in target.active_effects:
				if Combatant._effect_get(eff, "duration", 0) > 0:
					var eff_stat = Combatant._effect_get(eff, "stat", "")
					if eff_stat != "stun" and eff_stat != "invulnerable" and eff_stat != "regeneration":
						if Combatant._effect_get(eff, "value", 0) < 0:
							eff["duration"] = eff.get("duration", 1) + 1
			log_lines.append("  → [Касание смерти] Дебаффы на %s продлены на 1 ход." % target.unit_name)
		
		# Аид: «Ловец душ» — потратить 15 фантазии, исцелить союзника на 15% HP
		if ability.ability_marker == "hades_soul_catcher":
			if current_fantasy >= 15:
				current_fantasy -= 15
				var sc_heal = int(target.max_hp * 0.15)
				if sc_heal > 0:
					var hp_before_sc = target.current_hp
					target.apply_stat_change("hp", sc_heal)
					log_lines.append("  → [Ловец душ] %s исцеляет %s на %d HP (%d → %d). Потрачено 15 фантазии." % [
						attacker.unit_name, target.unit_name, sc_heal, hp_before_sc, target.current_hp])
				_update_spell_ui()
			else:
				log_lines.append("  → [Ловец душ] Недостаточно фантазии (%d/15)." % current_fantasy)
		
		# Моргана: «Усыпление» — если 3+ дебаффа на цели, оглушить
		if ability.ability_marker == "morgan_sleep":
			var sleep_debuffs = _count_debuffs_on_unit(target)
			if sleep_debuffs >= 3 and target.current_hp > 0:
				target.is_stunned = true
				var _sl_stun_duration = _compute_effect_duration(attacker, target, 1, true)
				target.active_effects.append({"stat": "stun", "value": 1, "duration": _sl_stun_duration, "source_ability": "Усыпление"})
				target.check_stance_interruption("stun")
				log_lines.append("  → [Усыпление] %s: %d дебаффов → оглушение на %d ход(ов)!" % [target.unit_name, sleep_debuffs, _sl_stun_duration])
			else:
				log_lines.append("  → [Усыпление] %s: %d дебаффов (нужно 3 для оглушения)." % [target.unit_name, sleep_debuffs])
		
		# Моргана: «Тайная магия» — разрешить дополнительное заклинание в этом раунде
		if ability.ability_marker == "morgan_secret_magic":
			max_spells_per_round += 1
			log_lines.append("  → [Тайная магия] %s может использовать ещё одно заклинание в этом раунде." % attacker.unit_name)
		
		# Моргана: «Власть тьмы» — за каждый дебафф на цели: 3% периодического урона на 5 ходов
		if ability.ability_marker == "morgan_dark_dominion":
			var dd_debuffs = _count_debuffs_on_unit(target)
			if dd_debuffs > 0:
				var dd_dmg = int(target.max_hp * 0.03 * dd_debuffs)
				var dd_duration = _compute_effect_duration(attacker, target, 5, true)
				target.active_effects.append({"stat": "periodic_damage", "value": dd_dmg, "duration": dd_duration, "source_ability": "Власть тьмы"})
				log_lines.append("  → [Власть тьмы] %s получает %d периодического урона на %d ходов (%d дебаффов)." % [
					target.unit_name, dd_dmg, dd_duration, dd_debuffs])
		
		# ═══ Они: «По голове» — 15% шанс оглушить цель на 1 ход ═══
		if ability.ability_marker == "oni_head_blow" and target.current_hp > 0:
			if randf() < 0.15:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "По голове"})
				target.check_stance_interruption("stun")
				log_lines.append("  → [По голове] %s оглушён! (15%% шанс)." % target.unit_name)
		
		# ═══ Они: «Огненные ладони» — 0.4x периодический урон на 2 хода ═══
		if ability.ability_marker == "oni_fiery_palms" and target.current_hp > 0:
			var _fp_dmg = int(attacker.damage * 0.4)
			if _fp_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _fp_dmg, "duration": 2, "source_ability": "Огненные ладони"})
				log_lines.append("  → [Огненные ладони] %s получает %d периодического урона на 2 хода." % [target.unit_name, _fp_dmg])
		
		# ═══ Лев: «Львиный укус» — исцелить атакующего на половину нанесённого урона ═══
		if ability.ability_marker == "lion_bite" and total_damage_dealt > 0:
			var _lb_heal = int(total_damage_dealt / 2)
			if _lb_heal > 0:
				var _hp_before_lb = attacker.current_hp
				attacker.apply_stat_change("hp", _lb_heal)
				log_lines.append("  → [Львиный укус] %s исцеляется на %d HP (половина урона). HP: %d → %d" % [
					attacker.unit_name, _lb_heal, _hp_before_lb, attacker.current_hp])
		
		# ═══ Титан: «Могучий удар» — +5 урона до конца боя ═══
		if ability.ability_marker == "titan_mighty_hit":
			attacker.apply_stat_change("damage", 5)
			log_lines.append("  → [Могучий удар] %s: +5 урона до конца боя (итого: %d)." % [attacker.unit_name, attacker.damage])
		
		# ═══ Бессмертный: «Двигаться вместе с песком» — вперёд на 1 + уклонение ═══
		if ability.ability_marker == "immortal_sand_step":
			if not attacker.is_large:
				var _ss_old = attacker.position_index
				_apply_shift_effect(attacker, -1, _is_player_hero(attacker))
				log_lines.append("  → [Двигаться с песком] %s продвигается вперёд: линия %d → %d." % [attacker.unit_name, _ss_old + 1, attacker.position_index + 1])
			attacker.apply_stat_change("evasion", 20)
			attacker.active_effects.append({"stat": "evasion", "value": 20, "duration": 2, "effect_id": "immortal_sand_step", "source_ability": "Двигаться вместе с песком"})
			log_lines.append("  → [Двигаться с песком] %s: +20 уклонения на 2 хода." % attacker.unit_name)
		
		# ═══ Жрец Анубиса: «Волна скоробеев» — оттолкнуть на 2 + 10% периодического урона ═══
		if ability.ability_marker == "anubis_scarab_wave" and target.current_hp > 0:
			if not target.is_large:
				var _sw_old = target.position_index
				_apply_shift_effect(target, 2, _is_player_hero(target))
				log_lines.append("  → [Волна скоробеев] %s отталкивается назад: линия %d → %d." % [target.unit_name, _sw_old + 1, target.position_index + 1])
			var _sw_pdmg = int(target.max_hp * 0.10)
			if _sw_pdmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _sw_pdmg, "duration": 2, "source_ability": "Волна скоробеев"})
				log_lines.append("  → [Волна скоробеев] %s получает %d периодического урона на 2 хода." % [target.unit_name, _sw_pdmg])
		
		# ═══ Жрец Анубиса: «Отсрочка от смерти» — если у цели <40% HP: +40% HP и +15 урон/точность на 3 хода ═══
		if ability.ability_marker == "anubis_death_delay" and target.current_hp > 0:
			if float(target.current_hp) / float(target.max_hp) < 0.40:
				var _dd_heal = int(target.max_hp * 0.40)
				var _dd_hp_before = target.current_hp
				target.apply_stat_change("hp", _dd_heal)
				target.apply_stat_change("damage", 15)
				target.active_effects.append({"stat": "damage", "value": 15, "duration": 3, "effect_id": "anubis_death_delay_dmg", "source_ability": "Отсрочка от смерти"})
				target.apply_stat_change("accuracy", 15)
				target.active_effects.append({"stat": "accuracy", "value": 15, "duration": 3, "effect_id": "anubis_death_delay_acc", "source_ability": "Отсрочка от смерти"})
				log_lines.append("  → [Отсрочка от смерти] %s: восстановление %d HP (%d → %d), +15 урона и точности на 3 хода." % [target.unit_name, _dd_heal, _dd_hp_before, target.current_hp])
			else:
				log_lines.append("  → [Отсрочка от смерти] %s: HP выше 40%% — отсрочка не требуется." % target.unit_name)
		
		# ═══ Мумия: «Древнее проклятие» — метка на позиции: -2 урон и -2 броня до конца боя ═══
		if ability.ability_marker == "mummy_ancient_curse" and target.current_hp > 0:
			target.apply_stat_change("damage", -2)
			target.apply_stat_change("armor", -2)
			target.active_effects.append({"stat": "damage", "value": -2, "duration": -1, "effect_id": "mummy_ancient_curse_mark", "source_ability": "Древнее проклятие"})
			target.active_effects.append({"stat": "armor", "value": -2, "duration": -1, "effect_id": "mummy_ancient_curse_mark", "source_ability": "Древнее проклятие"})
			marks.add_position_mark({
				"caster": attacker, "team": "ally", "position": target.position_index,
				"type": "persistent", "rounds_left": 999,
				"damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "mummy_ancient_curse_mark", "effect_value": 2, "effect_duration": -1,
				"icon": ability.mark_icon,
				"triggered_units_this_round": [target]
			})
			log_lines.append("  → [Древнее проклятие] Метка на позиции %d: -2 урона и -2 брони до конца боя." % (target.position_index + 1))
		
		# ═══ Мумия: «Аура смерти» — -15% удачи цели на 2 хода ═══
		if ability.ability_marker == "mummy_death_aura" and target.current_hp > 0:
			target.apply_stat_change("crit", -15)
			target.active_effects.append({"stat": "crit", "value": -15, "duration": 2, "effect_id": "mummy_death_aura", "source_ability": "Аура смерти"})
			log_lines.append("  → [Аура смерти] %s: -15%% удачи на 2 хода." % target.unit_name)
		
		# ═══ Сфинкс: «Загадка» — марка загадки на цели ═══
		if ability.ability_marker == "sphinx_riddle" and target.current_hp > 0:
			target.active_effects.append({"stat": "riddle_mark", "value": 1, "duration": 2, "effect_id": "sphinx_riddle", "source_ability": "Загадка"})
			log_lines.append("  → [Загадка] %s под загадкой: ранит сфинкса или сдвинется — получит 90%% урона." % target.unit_name)

		# ════ АД: ability_marker обработчики юнитов локации Hell ════
		# Адская гончая: «Пылающие зубы» — периодический урон 0.3 на 3 хода
		if ability.ability_marker == "hellhound_teeth" and target.current_hp > 0:
			var _ht_dot = int(attacker.damage * 0.3)
			if _ht_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _ht_dot, "duration": 3, "source_ability": "Пылающие зубы"})
				effects._apply_tormentor_regen(attacker, _ht_dot, 3)
				log_lines.append("  → [Пылающие зубы] %s получает периодический урон (%d) на 3 хода." % [target.unit_name, _ht_dot])

		# Дварф кузнец: «Пламя горнила» — периодический урон 0.15 от урона на 2 хода
		if ability.ability_marker == "dwarf_smith_forge_flame" and target.current_hp > 0:
			var _df_dot = int(attacker.damage * 0.15)
			if _df_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _df_dot, "duration": 2, "source_ability": "Пламя горнила"})
				effects._apply_tormentor_regen(attacker, _df_dot, 2)
				log_lines.append("  → [Пламя горнила] %s получает периодический урон (%d) на 2 хода." % [target.unit_name, _df_dot])
		# Адская гончая: «Не бояться смерти» — -20 броня +20 урон на 3 хода
		if ability.ability_marker == "hellhound_no_fear":
			attacker.apply_stat_change("armor", -20)
			attacker.apply_stat_change("damage", 20)
			attacker.active_effects.append({"stat": "damage", "value": 20, "duration": 3, "effect_id": "hellhound_no_fear", "source_ability": "Не бояться смерти"})
			attacker.active_effects.append({"stat": "armor", "value": -20, "duration": 3, "effect_id": "hellhound_no_fear", "source_ability": "Не бояться смерти"})
			log_lines.append("  → [Не бояться смерти] %s: -20 брони, +20 урона на 3 хода." % attacker.unit_name)
		# Страдающая душа: «Лишь один путь» — вперёд 1 + лечение 15%
		if ability.ability_marker == "soul_one_path":
			var _sop_heal = int(attacker.max_hp * 0.15)
			if _sop_heal > 0:
				attacker.apply_stat_change("hp", _sop_heal)
				log_lines.append("  → [Лишь один путь] %s восстанавливает %d HP (15%%)." % [attacker.unit_name, _sop_heal])
		# Страдающая душа: «Услышь мой крик» — все враги +1 уровень забыванья
		if ability.ability_marker == "soul_hear_cry" and target == targets[0]:
			var _shc_foes = heroes_team if attacker.is_enemy else enemies_team
			for _shc_f in _shc_foes:
				if _shc_f != null and _shc_f.current_hp > 0:
					_shc_f.add_forget(1.0, "Услышь мой крик")
			log_lines.append("  → [Услышь мой крик] Все враги получают 1 уровень забыванья.")
		# Мучитель: «Зазубренный трезубец» — -10 броня 2 хода, DoT 0.3 2 хода, цель вперёд 1
		if ability.ability_marker == "tormentor_trident" and target.current_hp > 0:
			target.apply_stat_change("armor", -10)
			target.active_effects.append({"stat": "armor", "value": -10, "duration": 2, "effect_id": "tormentor_trident", "source_ability": "Зазубренный трезубец"})
			var _trt_dot = int(attacker.damage * 0.3)
			if _trt_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _trt_dot, "duration": 2, "source_ability": "Зазубренный трезубец"})
				effects._apply_tormentor_regen(attacker, _trt_dot, 2)
			if not target.is_large:
				_apply_shift_effect(target, -1, not target.is_enemy)
			log_lines.append("  → [Зазубренный трезубец] %s: -10 брони (2), DoT (%d) (2), вперёд 1." % [target.unit_name, _trt_dot])
		# Мучитель: «Лязг цепей» — DoT 0.1 4 хода, обе цели вперёд 1
		if ability.ability_marker == "tormentor_chains":
			var _ch_dot = int(attacker.damage * 0.1)
			if _ch_dot > 0:
				if target.current_hp > 0:
					target.active_effects.append({"stat": "periodic_damage", "value": _ch_dot, "duration": 4, "source_ability": "Лязг цепей"})
					effects._apply_tormentor_regen(attacker, _ch_dot, 4)
				for _ch_t in targets:
					if _ch_t != null and _ch_t.current_hp > 0 and not _ch_t.is_large:
						_apply_shift_effect(_ch_t, -1, not _ch_t.is_enemy)
			log_lines.append("  → [Лязг цепей] DoT (%d) на 4 хода, цели вперёд 1." % _ch_dot)
		# Мучитель: «Симфония боли» — союзники +3 атаки и +3 удачи за каждый дебафф на врагах
		if ability.ability_marker == "tormentor_symphony" and target == targets[0]:
			var _sym_foes = heroes_team if attacker.is_enemy else enemies_team
			var _sym_debuffs = 0
			for _sym_f in _sym_foes:
				if _sym_f == null or _sym_f.current_hp <= 0:
					continue
				for _sym_e in _sym_f.active_effects:
					if Combatant._effect_get(_sym_e, "stat", "") == "periodic_damage" or Combatant._effect_get(_sym_e, "value", 0) < 0:
						_sym_debuffs += 1
			var _sym_team = enemies_team if attacker.is_enemy else heroes_team
			for _sym_ally in _sym_team:
				if _sym_ally and _sym_ally.current_hp > 0:
					var _sym_dmg = 3 * _sym_debuffs
					var _sym_crt = 3 * _sym_debuffs
					if _sym_dmg > 0:
						_sym_ally.apply_stat_change("damage", _sym_dmg)
						_sym_ally.active_effects.append({"stat": "damage", "value": _sym_dmg, "duration": 1, "effect_id": "tormentor_symphony", "source_ability": "Симфония боли"})
					if _sym_crt > 0:
						_sym_ally.apply_stat_change("crit", _sym_crt)
						_sym_ally.active_effects.append({"stat": "crit", "value": _sym_crt, "duration": 1, "effect_id": "tormentor_symphony", "source_ability": "Симфония боли"})
			log_lines.append("  → [Симфония боли] %d дебаффов → союзники +%d урона, +%d удачи (1 ход)." % [_sym_debuffs, 3*_sym_debuffs, 3*_sym_debuffs])
		# Суккуб: «Пылающий поцелуй» — -15 уклонения и -15 атаки на 4 хода
		if ability.ability_marker == "succubus_kiss" and target.current_hp > 0:
			target.apply_stat_change("evasion", -15)
			target.apply_stat_change("damage", -15)
			target.active_effects.append({"stat": "evasion", "value": -15, "duration": 4, "effect_id": "succubus_kiss", "source_ability": "Пылающий поцелуй"})
			target.active_effects.append({"stat": "damage", "value": -15, "duration": 4, "effect_id": "succubus_kiss", "source_ability": "Пылающий поцелуй"})
			log_lines.append("  → [Пылающий поцелуй] %s: -15 уклонения, -15 атаки на 4 хода." % target.unit_name)
		# Суккуб: «Я выбираю тебя» — метка провокации на 3 хода
		if ability.ability_marker == "succubus_choose_you" and target.current_hp > 0:
			target.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": 3, "effect_id": "provocation_mark", "source_ability": "Я выбираю тебя"})
			log_lines.append("  → [Я выбираю тебя] %s получает метку провокации на 3 хода." % target.unit_name)
		# Кошмар: «Наступление ада» — вперёд 1 атакующего (доп. цель позади уже через extra_targets)
		if ability.ability_marker == "nightmare_hell_assault" and target == targets[0]:
			if not attacker.is_large:
				_apply_shift_effect(attacker, -1, not attacker.is_enemy)
			log_lines.append("  → [Наступление ада] %s: вперёд 1." % attacker.unit_name)
		# Кошмар: «Проникнуть в сны» — все враги теряют 10 величия
		if ability.ability_marker == "nightmare_dreams" and target == targets[0]:
			var _nd_foes = heroes_team if attacker.is_enemy else enemies_team
			for _nd_f in _nd_foes:
				if _nd_f != null and _nd_f.current_hp > 0:
					_nd_f.modify_majesty(-10)
			log_lines.append("  → [Проникнуть в сны] Все враги теряют 10 величия.")
		# Дьявол: «Адская гильотина» — марка once: в начале след хода дьявола сработает
		if ability.ability_marker == "devil_guillotine" and target.current_hp > 0:
			marks.add_position_mark({
				"caster": attacker, "team": "enemy", "position": target.position_index,
				"type": "once", "rounds_left": 1, "damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "devil_guillotine", "effect_value": 0, "effect_duration": 0,
				"icon": ability.mark_icon,
				"triggered_units_this_round": [], "_forget": 0.5
			})
			log_lines.append("  → [Адская гильотина] Марка на %s — сработает в начале след. хода дьявола." % target.unit_name)

		# ════ ДЖУНГЛИ: ability_marker обработчики ════
		# Сару: «Обезьяньи трюки» — снять баффы + сбить стойку
		if ability.ability_marker == "saru_tricks" and target.current_hp > 0:
			effects._dispel_effects(target, "buff")
			if target.active_stance != null:
				target.break_stance()
				log_lines.append("  → [Обезьяньи трюки] Стойка %s сбита." % target.unit_name)
			log_lines.append("  → [Обезьяньи трюки] С %s сняты все баффы." % target.unit_name)
		# Нага воин: «Бросок кобры» — вперёд 1 + DoT 0.3 на 2 хода
		if ability.ability_marker == "naga_cobra_throw" and target.current_hp > 0:
			if not attacker.is_large:
				_apply_shift_effect(attacker, -1, not attacker.is_enemy)
			var _nc_dot = int(attacker.damage * 0.3)
			if _nc_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _nc_dot, "duration": 2, "source_ability": "Бросок кобры"})
				log_lines.append("  → [Бросок кобры] %s получает периодический урон (%d) на 2 хода." % [target.unit_name, _nc_dot])
		# Нага монах: «Кармическое наказание» — все противники -12 точности -5 уклонения
		if ability.ability_marker == "naga_karma_punish" and target == targets[0]:
			var _kp_foes = heroes_team if attacker.is_enemy else enemies_team
			for _kp_f in _kp_foes:
				if _kp_f != null and _kp_f.current_hp > 0:
					_kp_f.apply_stat_change("accuracy", -12)
					_kp_f.apply_stat_change("evasion", -5)
					_kp_f.active_effects.append({"stat": "accuracy", "value": -12, "duration": 1, "effect_id": "naga_karma", "source_ability": "Кармическое наказание"})
					_kp_f.active_effects.append({"stat": "evasion", "value": -5, "duration": 1, "effect_id": "naga_karma", "source_ability": "Кармическое наказание"})
			log_lines.append("  → [Кармическое наказание] Все враги: -12 точности, -5 уклонения.")
		# Коатль: «Кислотное дыхание» — DoT 0.2 -10 броня на 2 хода (все цели)
		if ability.ability_marker == "coatl_acid_breath":
			var _ab_dot = int(attacker.damage * 0.2)
			for _ab_t in targets:
				if _ab_t != null and _ab_t.current_hp > 0:
					if _ab_dot > 0:
						_ab_t.active_effects.append({"stat": "periodic_damage", "value": _ab_dot, "duration": 2, "source_ability": "Кислотное дыхание"})
					_ab_t.apply_stat_change("armor", -10)
					_ab_t.active_effects.append({"stat": "armor", "value": -10, "duration": 2, "effect_id": "coatl_acid", "source_ability": "Кислотное дыхание"})
			if _ab_dot > 0:
				log_lines.append("  → [Кислотное дыхание] Цели получают периодический урон (%d) и -10 брони на 2 хода." % _ab_dot)
		# Коатль: «Ветра судьбы» — вперёд 1 + метка невинности 3 хода
		if ability.ability_marker == "coatl_winds":
			if not attacker.is_large:
				_apply_shift_effect(attacker, -1, not attacker.is_enemy)
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 3, "effect_id": "cupid_innocence", "source_ability": "Ветра судьбы"})
			log_lines.append("  → [Ветра судьбы] %s: вперёд 1, метка невинности на 3 хода." % attacker.unit_name)
		# Асура: «Проклятие отчаяния» — +1 к числу зарядов curse_pending
		if ability.ability_marker == "asura_curse":
			var _ac_cur = int(attacker.get_meta("asura_curse_pending", 0)) + 1
			attacker.set_meta("asura_curse_pending", _ac_cur)
			log_lines.append("  → [Проклятие отчаяния] %s: следующий «Удар хаоса» наложит DoT 0.4 на 5 ходов (зарядов: %d)." % [attacker.unit_name, _ac_cur])
		# Асура: «Удар хаоса» — меняет базовую удачу цели на 0-10 на 1 ход; если есть curse → DoT 0.4 на 5 ходов
		if ability.ability_marker == "asura_chaos_strike" and target.current_hp > 0:
			var _acs_new_crit = randf() * 0.10
			target.set_meta("asura_chaos_crit_override", _acs_new_crit)
			target.set_meta("asura_chaos_crit_turns", 1)
			var _ac_cur = int(attacker.get_meta("asura_curse_pending", 0))
			if _ac_cur > 0:
				var _ac_dot = int(attacker.damage * 0.4)
				if _ac_dot > 0:
					target.active_effects.append({"stat": "periodic_damage", "value": _ac_dot, "duration": 5, "source_ability": "Проклятие отчаяния"})
					log_lines.append("  → [Удар хаоса/Проклятие] %s получает периодический урон (%d) на 5 ходов." % [target.unit_name, _ac_dot])
				attacker.set_meta("asura_curse_pending", _ac_cur - 1)
			log_lines.append("  → [Удар хаоса] Удача %s установлена на %d%% на 1 ход." % [target.unit_name, int(_acs_new_crit * 100)])
		# Асура: «Чёрная полоса» — ставит meta для ИИ
		if ability.ability_marker == "asura_streak" and target.current_hp > 0:
			attacker.set_meta("asura_streak_active", true)
			log_lines.append("  → [Чёрная полоса] Марка на %s." % target.unit_name)

		# ═══ Золотой скоробей: «На удачу» — все союзники +30% удачи на 1 ход ═══
		if ability.ability_marker == "scarab_good_luck":
			var _gl_team = enemies_team if attacker.is_enemy else heroes_team
			for _gl_ally in _gl_team:
				if _gl_ally and _gl_ally.current_hp > 0:
					_gl_ally.apply_stat_change("crit", 30)
					_gl_ally.active_effects.append({"stat": "crit", "value": 30, "duration": 1, "effect_id": "scarab_good_luck", "source_ability": "На удачу"})
			log_lines.append("  → [На удачу] Все союзники: +30% удачи на 1 ход.")
		
		# ═══ Минотавр: «Устрашающий рёв» — союзники +10 урона / враги -10 урона на 3 хода ═══
		if ability.ability_marker == "minotaur_intimidating_roar":
			var _mr_ally_team = enemies_team if attacker.is_enemy else heroes_team
			var _mr_foe_team = heroes_team if attacker.is_enemy else enemies_team
			for _mr_ally in _mr_ally_team:
				if _mr_ally and _mr_ally.current_hp > 0:
					_mr_ally.apply_stat_change("damage", 10)
					_mr_ally.active_effects.append({"stat": "damage", "value": 10, "duration": 3, "effect_id": "minotaur_roar_buff", "source_ability": "Устрашающий рёв"})
			for _mr_foe in _mr_foe_team:
				if _mr_foe and _mr_foe.current_hp > 0:
					_mr_foe.apply_stat_change("damage", -10)
					_mr_foe.active_effects.append({"stat": "damage", "value": -10, "duration": 3, "effect_id": "minotaur_roar_debuff", "source_ability": "Устрашающий рёв"})
			log_lines.append("  → [Устрашающий рёв] Союзники +10 урона, враги -10 урона на 3 хода.")
		
		# ═══ Наставник: «Наказание» — все союзники +15 точности на 1 ход ═══
		if ability.ability_marker == "mentor_punishment":
			var _mp_team = enemies_team if attacker.is_enemy else heroes_team
			for _mp_ally in _mp_team:
				if _mp_ally and _mp_ally.current_hp > 0:
					_mp_ally.apply_stat_change("accuracy", 15)
					_mp_ally.active_effects.append({"stat": "accuracy", "value": 15, "duration": 1, "effect_id": "mentor_punishment", "source_ability": "Наказание"})
			log_lines.append("  → [Наказание] Все союзники: +15 точности на 1 ход.")
		
		# ═══ Нанауэ: «Драть плоть» — 0.5 периодического урона на 2 хода ═══
		if ability.ability_marker == "nanau_flesh_tear" and target.current_hp > 0:
			var _ft_dmg = int(attacker.damage * 0.5)
			if _ft_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _ft_dmg, "duration": 2, "source_ability": "Драть плоть"})
				log_lines.append("  → [Драть плоть] %s получает периодический урон (%d) на 2 хода." % [target.unit_name, _ft_dmg])
		
		# ═══ Нанауэ: «Поглотить» — отменяет периодический урон цели и лечит Нанауэ на 30% ═══
		if ability.ability_marker == "nanau_consume" and target.current_hp > 0:
			var _had_dot = false
			var _ci = 0
			while _ci < target.active_effects.size():
				if Combatant._effect_get(target.active_effects[_ci], "stat", "") == "periodic_damage":
					target.active_effects.remove_at(_ci)
					_had_dot = true
				else:
					_ci += 1
			if _had_dot:
				var _dev_heal = int(attacker.max_hp * 0.30)
				var _dev_hp_b = attacker.current_hp
				attacker.apply_stat_change("hp", _dev_heal)
				log_lines.append("  → [Поглотить] Периодический урон с %s снят. %s восстанавливает %d HP (%d → %d)." % [target.unit_name, attacker.unit_name, _dev_heal, _dev_hp_b, attacker.current_hp])
		
		# ═══ Морская ведьма: «Водоворот» — обмен позиций врагов 1↔4, 2↔3 (один раз за применение) ═══
		if ability.ability_marker == "seawitch_whirlpool" and (targets.is_empty() or target == targets[0]):
			var _wp_log = _swap_enemy_positions(attacker)
			for _wl in _wp_log:
				log_lines.append(_wl)
		
		# ═══ Морская ведьма: «Глубоководное проклятие» — DoT 0.3 на 5 ходов + позиционная марка на 2 хода ═══
		if ability.ability_marker == "seawitch_curse" and target.current_hp > 0:
			var _curs_dmg = int(attacker.damage * 0.3)
			if _curs_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _curs_dmg, "duration": 5, "source_ability": "Глубоководное проклятие"})
				log_lines.append("  → [Глубоководное проклятие] %s получает периодический урон (%d) на 5 ходов." % [target.unit_name, _curs_dmg])
			# Позиционная марка (persistent, 2 хода): повторно накладывает DoT на входящего.
			var _curse_mark = {
				"caster": attacker, "team": "ally", "position": target.position_index,
				"type": "persistent", "rounds_left": 2,
				"damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "seawitch_curse_dot", "effect_value": _curs_dmg, "effect_duration": 5,
				"icon": ability.mark_icon,
				"triggered_units_this_round": []
			}
			marks.add_position_mark(_curse_mark)
			log_lines.append("  → [Глубоководное проклятие] Марка на позиции %d на 2 хода." % (target.position_index + 1))
		
		# ═══ Морская ведьма: «Мрачная сделка» — +3 инициативы 2 хода + блок ульты 1 ход ═══
		if ability.ability_marker == "seawitch_dark_deal" and target.current_hp > 0:
			target.apply_stat_change("initiative", 3)
			target.active_effects.append({"stat": "initiative", "value": 3, "duration": 2, "effect_id": "seawitch_dark_deal_init", "source_ability": "Мрачная сделка"})
			target.ultimate_blocked = true
			target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 1, "effect_id": "ultimate_blocked", "source_ability": "Мрачная сделка"})
			log_lines.append("  → [Мрачная сделка] %s: +3 инициативы 2 хода, ультимативная способность заблокирована на 1 ход." % target.unit_name)
		
		# ═══ Угорь: «Двойной укус» — метка челюсти (отложенная атака в начале след. хода) ═══
		if ability.ability_marker == "eel_double_bite" and target.current_hp > 0:
			attacker.jaw_mark_target = target
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 1, "effect_id": "eel_jaw_mark", "source_ability": "Двойной укус"})
			log_lines.append("  → [Двойной укус] %s ставит метку челюсти на %s." % [attacker.unit_name, target.unit_name])

		# ═══ Посейдон: «Удар трезубцем» — +5% урона за каждый бафф на себе ═══
		if ability.ability_marker == "poseidon_trident_strike":
			var buff_count = _count_buffs_on_unit(attacker)
			var bonus_dmg = int(attacker.damage * 0.05 * buff_count)
			if bonus_dmg > 0 and target.current_hp > 0:
				target.take_damage(bonus_dmg)
				log_lines.append("  → [Удар трезубцем] +%d доп. урона за %d баффов. HP %s: %d." % [bonus_dmg, buff_count, target.unit_name, target.current_hp])

		# ═══ Самди: «Выпей со смертью» — периодический урон себе и цели ═══
		if ability.ability_marker == "samdi_drink_with_death":
			var dot_self = int(attacker.damage * 0.5)
			var dot_tgt = int(attacker.damage * 0.5)
			if dot_self > 0:
				var _dwd_self_duration = _compute_effect_duration(attacker, attacker, 2, true)
				attacker.active_effects.append({"stat": "periodic_damage", "value": dot_self, "duration": _dwd_self_duration, "source_ability": "Выпей со смертью"})
			if dot_tgt > 0 and target.current_hp > 0:
				var _dwd_tgt_duration = _compute_effect_duration(attacker, target, 2, true)
				target.active_effects.append({"stat": "periodic_damage", "value": dot_tgt, "duration": _dwd_tgt_duration, "source_ability": "Выпей со смертью"})
			log_lines.append("  → [Выпей со смертью] %s и %s получают периодический урон (%d) на 2 хода." % [attacker.unit_name, target.unit_name, dot_self])

		# ═══ Самди: «Веселье никогда не заканчивается» — все юниты +20 удачи +20 уклонения -30 точности -15 брони ═══
		if ability.ability_marker == "samdi_party" and target == targets[0]:
			for u in heroes_team + enemies_team:
				if u != null and u.current_hp > 0:
					var _sp_buff_duration = _compute_effect_duration(attacker, u, 2, false)
					var _sp_debuff_duration = _compute_effect_duration(attacker, u, 2, true)
					u.apply_stat_change("crit", 20); u.active_effects.append({"stat":"crit","value":20,"duration":_sp_buff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
					u.apply_stat_change("evasion", 20); u.active_effects.append({"stat":"evasion","value":20,"duration":_sp_buff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
					u.apply_stat_change("accuracy", -30); u.active_effects.append({"stat":"accuracy","value":-30,"duration":_sp_debuff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
					u.apply_stat_change("armor", -15); u.active_effects.append({"stat":"armor","value":-15,"duration":_sp_debuff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
			log_lines.append("  → [Веселье] Все юниты: +20 удачи, +20 уклонения, -30 точности, -15 брони на 2 хода.")
		
		# ═══ Самди: «Кукла вуду» — метка НА ЮНИТЕ (не позиционная марка): связывает цель с юнитом позади ═══
		if ability.ability_marker == "samdi_voodoo" and target.current_hp > 0:
			marks.apply_voodoo_mark(attacker, target, 2)
			log_lines.append("  → [Кукла вуду] Метка на %s: 50%% урона и дебаффы уходят юниту позади (2 хода)." % target.unit_name)

		# ═══ Шива: «Шквал кулаков» — 3 случайным противникам ═══
		if ability.ability_marker == "shiva_fist_flurry":
			var enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
			# 3 РАЗНЫХ случайных противника (если их достаточно) — без повторов, пока пул не исчерпан.
			var _ff_pool = enemies.duplicate()
			_ff_pool.shuffle()
			for _i in range(3):
				if enemies.is_empty() or _check_battle_end():
					break
				if _ff_pool.is_empty():
					_ff_pool = enemies.duplicate()
					_ff_pool.shuffle()
				var t = _ff_pool.pop_back()
				if t == null or t.current_hp <= 0:
					continue
				var d = CombatCalculator.calculate_fixed_damage(attacker, t, 0.6)
				if d.is_hit:
					_deal_damage(t, d.final_damage, d.is_crit)
					log_lines.append("  → [Шквал кулаков] %s получает %d урона%s." % [t.unit_name, d.final_damage, " (крит!)" if d.is_crit else ""])
				if t.current_hp <= 0:
					log_lines.append("  → %s повержен!" % t.unit_name)
					_on_unit_killed(t, log_lines)
					var _ff_team = heroes_team if not t.is_enemy else enemies_team
					_compact_team(_ff_team)
					enemies.erase(t)
			_update_all_visuals()

		# ═══ Шива: «Доверься судьбе» — лечение = (30 - fate)% (fate сохранён в meta при резке урона) ═══
		if ability.ability_marker == "shiva_trust_fate":
			var _tf_pct = int(attacker.get_meta("shiva_trust_fate_pct", 0))
			attacker.remove_meta("shiva_trust_fate_pct")
			var heal_amt = int(attacker.max_hp * (30 - _tf_pct) / 100.0)
			if heal_amt > 0:
				attacker.apply_stat_change("hp", heal_amt)
				log_lines.append("  → [Доверься судьбе] %s восстанавливает %d HP (%d%%)." % [attacker.unit_name, heal_amt, 30 - _tf_pct])

		# ═══ Шива: «Аватара» — вперёд 2 + 2 случайных из 6 вариантов на 3 хода ═══
		if ability.ability_marker == "shiva_avatar":
			_apply_shift_effect(attacker, -2, _is_player_hero(attacker))
			# 6 вариантов: stat-баффы и «лечение 10% HP» как полноценный вариант
			var _av_choices = [
				{"type": "stat", "stat": "damage", "value": 10},
				{"type": "stat", "stat": "crit", "value": 10},
				{"type": "stat", "stat": "evasion", "value": 10},
				{"type": "stat", "stat": "accuracy", "value": 10},
				{"type": "stat", "stat": "armor", "value": 10},
				{"type": "heal", "value": 10}
			]
			_av_choices.shuffle()
			for j in range(mini(2, _av_choices.size())):
				var c = _av_choices[j]
				if c["type"] == "stat":
					var _av_duration = _compute_effect_duration(attacker, attacker, 3, false)
					attacker.apply_stat_change(c["stat"], c["value"])
					attacker.active_effects.append({"stat": c["stat"], "value": c["value"], "duration": _av_duration, "effect_id": "shiva_avatar", "source_ability": "Аватара"})
				else:
					var _av_heal = int(attacker.max_hp * c["value"] / 100.0)
					if _av_heal > 0:
						attacker.apply_stat_change("hp", _av_heal)
						log_lines.append("  → [Аватара] Восстановление %d%% HP (%d)." % [c["value"], _av_heal])
			log_lines.append("  → [Аватара] %s: вперёд 2, 2 случайных эффекта на 3 хода." % attacker.unit_name)
			marks.check_on_move(attacker)
			_update_all_visuals()

		# ═══ Чернобог: «Я и есть боль» — -7% HP себе, +1 цель, 0.2 DoT 3 хода ═══
		if ability.ability_marker == "chernobog_i_am_pain":
			var self_dmg = int(attacker.max_hp * 0.07)
			attacker.take_damage(self_dmg)
			var dot = int(attacker.damage * 0.2)
			var _iap_duration = _compute_effect_duration(attacker, target, 3, true)
			if dot > 0 and target.current_hp > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": dot, "duration": _iap_duration, "source_ability": "Я и есть боль"})
			# Доп. цель — ровно 1 (не вся команда).
			var extra_candidates = []
			for et_c in _get_all_targets(ability, attacker):
				if et_c != null and et_c != target and et_c.current_hp > 0:
					extra_candidates.append(et_c)
			if extra_candidates.size() > 0:
				var et = extra_candidates[randi() % extra_candidates.size()]
				et.active_effects.append({"stat": "periodic_damage", "value": dot, "duration": _iap_duration, "source_ability": "Я и есть боль"})
				log_lines.append("  → [Я и есть боль] %s тоже получает периодический урон (%d) на %d хода." % [et.unit_name, dot, _iap_duration])
			log_lines.append("  → [Я и есть боль] %s теряет %d HP (7%%). %s получает DoT (%d) на %d хода." % [attacker.unit_name, self_dmg, target.unit_name, dot, _iap_duration])

		# ═══ Чернобог: «Торжество зла» — стирает величие других богов и бьёт врагов от стёртого величия ═══
		if ability.ability_marker == "chernobog_triumph_evil" and target == targets[0]:
			var total_lost: int = 0
			var allied_team: Array = enemies_team if attacker.is_enemy else heroes_team
			var opposing_team: Array = heroes_team if attacker.is_enemy else enemies_team
			for u in allied_team:
				if u != null and u != attacker and u.current_majesty > 0:
					var lost: int = u.current_majesty
					u.current_majesty = 0
					total_lost += lost
			var triumph_damage: int = int(attacker.damage * float(total_lost) / 100.0)
			log_lines.append("  → [Торжество зла] Другие боги потеряли %d величия. Урон по противникам: %d." % [total_lost, triumph_damage])
			if triumph_damage > 0:
				for enemy in opposing_team:
					if enemy != null and enemy.current_hp > 0:
						var hp_before_triumph: int = enemy.current_hp
						enemy.take_damage(triumph_damage)
						var dealt_triumph: int = maxi(0, hp_before_triumph - enemy.current_hp)
						total_damage_dealt += dealt_triumph
						log_lines.append("  → [Торжество зла] %s получает %d урона. HP: %d → %d" % [enemy.unit_name, dealt_triumph, hp_before_triumph, enemy.current_hp])
						if enemy.current_hp <= 0:
							log_lines.append("  → %s повержен!" % enemy.unit_name)
							enemy.killed_by = attacker
							_on_unit_killed(enemy, log_lines)
				var compact_team: Array = heroes_team if attacker.is_enemy else enemies_team
				_compact_team(compact_team)
				_apply_kappa_auras()
				if _check_battle_end():
					for line in log_lines:
						_log_combat(line)
					return
		# ═══ Дуна: «Торжество жизни» — полное лечение цели + баффы ═══
		if ability.ability_marker == "duna_life_celebration" and target.current_hp > 0:
			if attacker.special_effect_type == "duna_heal_damage":
				_duna_turn_heal += maxi(0, target.max_hp - target.current_hp)
			target.current_hp = target.max_hp
			target.apply_stat_change("damage", 10)
			target.active_effects.append({"stat":"damage","value":10,"duration":-1,"effect_id":"duna_life","source_ability":"Торжество жизни"})
			target.apply_stat_change("crit", 10)
			target.active_effects.append({"stat":"crit","value":10,"duration":-1,"effect_id":"duna_life","source_ability":"Торжество жизни"})
			target.apply_stat_change("armor", 10)
			target.active_effects.append({"stat":"armor","value":10,"duration":-1,"effect_id":"duna_life","source_ability":"Торжество жизни"})
			log_lines.append("  → [Торжество жизни] %s: полное HP, +10 урона/удачи/брони навсегда." % target.unit_name)
			_update_all_visuals()

		# ═══ Дуна: «Поглощение жизни» — лечение 50% от нанесённого урона ═══
		if ability.ability_marker == "duna_life_steal" and target.current_hp > 0:
			var heal = int(total_damage_dealt * 0.5)
			if heal > 0:
				var _ls_before = attacker.current_hp
				attacker.apply_stat_change("hp", heal)
				if attacker.special_effect_type == "duna_heal_damage":
					_duna_turn_heal += maxi(0, attacker.current_hp - _ls_before)
				log_lines.append("  → [Поглощение жизни] %s восстанавливает %d HP (50%% от урона)." % [attacker.unit_name, heal])
				_update_all_visuals()

		# ═══ Один: «Последняя битва» — снять все баффы с союзников и противников; за каждый бафф +7 урона до конца боя ═══
		if ability.ability_marker == "odin_last_battle" and target == targets[0]:
			for u in heroes_team + enemies_team:
				if u != null and u.current_hp > 0:
					var buff_count = 0
					for eff in u.active_effects:
						var eff_stat = eff.get("stat", "")
						var eff_val = eff.get("value", 0)
						if eff_val > 0 and eff_stat != "stun" and eff_stat != "periodic_damage":
							buff_count += 1
					effects._dispel_effects(u, "buff")
					if buff_count > 0 and u.is_enemy == false:
						u.damage_modifier_flat += buff_count * 7
						u.active_effects.append({"stat": "damage", "value": buff_count * 7, "duration": -1, "effect_id": "odin_last_battle", "source_ability": "Последняя битва"})
						log_lines.append("  → [Последняя битва] %s: снято %d баффов, +%d урона." % [u.unit_name, buff_count, buff_count * 7])
			log_lines.append("  → [Последняя битва] Все баффы сняты со всех юнитов.")
			_update_all_visuals()

		# ═══ Один: «Отец богов» — текущий союзник +1 инициативы и +10 брони на 2 хода (цикл по All_Allies) ═══
		if ability.ability_marker == "odin_father_of_gods" and target.current_hp > 0:
			var _fog_duration = _compute_effect_duration(attacker, target, 2, false)
			effects._apply_buff_to_unit(target, "initiative", 1, _fog_duration, "odin_father_of_gods", "Отец богов", log_lines)
			effects._apply_buff_to_unit(target, "armor", 10, _fog_duration, "odin_father_of_gods", "Отец богов", log_lines)
			if target == targets[0]:
				log_lines.append("  → [Отец богов] Все союзники получают +1 инициативы и +10 брони на %d ход(ов)." % _fog_duration)

		# ═══ Один: «Король Асгарда» — продлить свои баффы урона на 1 ход (бонус +5 урона — через self_buff_damage) ═══
		if ability.ability_marker == "odin_king_of_asgard" and target == targets[0]:
			var _koa_ext = 0
			for _koa_e in attacker.active_effects:
				# Исключаем бафф +5 урона, только что наложенный этим же применением способности —
				# иначе он продлевает сам себя (1 ход → 2 хода) вместо продления УЖЕ существовавших баффов.
				if Combatant._effect_get(_koa_e, "effect_id", "") == "self_buff_damage":
					continue
				if Combatant._effect_get(_koa_e, "stat", "") == "damage" and Combatant._effect_get(_koa_e, "value", 0) > 0 and Combatant._effect_get(_koa_e, "duration", 0) > 0:
					_koa_e["duration"] = Combatant._effect_get(_koa_e, "duration", 0) + 1
					_koa_ext += 1
			if _koa_ext > 0:
				log_lines.append("  → [Король Асгарда] %s: продлено %d бафф(ов) урона на 1 ход." % [attacker.unit_name, _koa_ext])

		# ═══ Дуна: «Растительный яд» — союзник наносит доп. DoT 20% на 4 хода (3 хода эффект) ═══
		if ability.ability_marker == "duna_plant_poison" and target.current_hp > 0:
			target.set_meta("plant_poison_attacker_dmg", attacker.damage)
			target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 3, "effect_id": "plant_poison_buff", "source_ability": "Растительный яд"})
			log_lines.append("  → [Растительный яд] %s теперь накладывает периодический урон при атаке (3 хода)." % target.unit_name)

		# ═══ Дуна: «Защита из корней» — союзник +20% брони, атакующие получают 40% урона (3 хода) ═══
		if ability.ability_marker == "duna_root_protection" and target.current_hp > 0:
			var _rp_bonus = int(target.base_armor * 0.2)
			var _rp_cast_duration = _compute_effect_duration(attacker, target, 3, false)
			target.armor_modifier += _rp_bonus
			target.active_effects.append({"stat": "armor", "value": _rp_bonus, "duration": _rp_cast_duration, "effect_id": "root_protection", "source_ability": "Защита из корней"})
			target.active_effects.append({"stat": "trigger_marker", "value": 40, "duration": _rp_cast_duration, "effect_id": "root_thorns", "source_ability": "Защита из корней"})
			log_lines.append("  → [Защита из корней] %s: +%d брони, шипы 40%% (%d хода)." % [target.unit_name, _rp_bonus, _rp_cast_duration])
			_update_all_visuals()
		
		# ═══ Угорь: «Оплетание» — сбивает стойку; если стойки не было — оглушает ═══
		if ability.ability_marker == "eel_entangle" and target.current_hp > 0:
			if target.active_stance != null:
				target.break_stance()
				log_lines.append("  → [Оплетание] Стойка %s сбита." % target.unit_name)
			else:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Оплетание"})
				target.check_stance_interruption("stun")
				log_lines.append("  → [Оплетание] %s оглушён (стойки не было)." % target.unit_name)
		
		# ═══ Замок — Рыцарь: «Изгнать зло» — снять все баффы; если >2 уникальных → стан ═══
		if ability.ability_marker == "knight_banish_evil" and target.current_hp > 0:
			var _be_buffs = _count_buffs_on_unit(target)
			effects._dispel_effects(target, "buff")
			log_lines.append("  → [Изгнать зло] Снято %d бафф(ов) с %s." % [_be_buffs, target.unit_name])
			if _be_buffs > 2 and not target.is_stunned:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Изгнать зло"})
				target.check_stance_interruption("stun")
				_notify_stun_applied(target)
				log_lines.append("  → [Изгнать зло] Более 2 баффов снято — %s оглушён!" % target.unit_name)

		# ═══ Замок — Шут: «Ядовитый кинжал» — периодический урон 20% на 5 ходов ═══
		if ability.ability_marker == "jester_poison_dagger" and target.current_hp > 0:
			var _pd_dmg = int(attacker.damage * 0.2)
			if _pd_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _pd_dmg, "duration": 5, "source_ability": "Ядовитый кинжал"})
				log_lines.append("  → [Ядовитый кинжал] %s получает периодический урон (%d) на 5 ходов." % [target.unit_name, _pd_dmg])

		# ═══ Замок — Волшебник: «Кольцо холода» — 50% шанс оглушения ═══
		if ability.ability_marker == "wizard_cold_ring" and target.current_hp > 0:
			if randf() < 0.50 and not target.is_stunned:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Кольцо холода"})
				target.check_stance_interruption("stun")
				_notify_stun_applied(target)
				log_lines.append("  → [Кольцо холода] %s оглушён! (50%% шанс)." % target.unit_name)

		# ═══ Замок — Инквизитор: «Аутодафе» — периодический урон + марка на 2 раунда ═══
		if ability.ability_marker == "inquisitor_auto_da_fe" and target.current_hp > 0:
			var _af_dmg = int(attacker.damage * 0.4)
			if _af_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _af_dmg, "duration": 3, "source_ability": "Аутодафе"})
				log_lines.append("  → [Аутодафе] %s получает периодический урон (%d) на 3 хода." % [target.unit_name, _af_dmg])
			# Позиционная марка (persistent, 2 раунда): повторно накладывает DoT
			marks.add_position_mark({
				"caster": attacker, "team": "ally", "position": target.position_index,
				"type": "persistent", "rounds_left": 2,
				"damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "inquisitor_auto_da_fe_dot", "effect_value": _af_dmg, "effect_duration": 3,
				"icon": ability.mark_icon,
				"triggered_units_this_round": []
			})
			log_lines.append("  → [Аутодафе] Марка на позиции %d на 2 раунда." % (target.position_index + 1))

		# ═══ Замок — Инквизитор: «Исповедь» — снять дебаффы, +5% HP за каждый ═══
		if ability.ability_marker == "inquisitor_confession" and target.current_hp > 0:
			var _cf_debuffs = _count_debuffs_on_unit(target)
			effects._dispel_effects(target, "debuff")
			if _cf_debuffs > 0:
				var _cf_heal = int(target.max_hp * 0.05 * _cf_debuffs)
				var _cf_hp_b = target.current_hp
				target.apply_stat_change("hp", _cf_heal)
				log_lines.append("  → [Исповедь] Снято %d дебафф(ов), восстановлено %d HP (%d → %d)." % [_cf_debuffs, _cf_heal, _cf_hp_b, target.current_hp])
			else:
				log_lines.append("  → [Исповедь] У %s нет дебаффов." % target.unit_name)

		# ═══ Замок — Инквизитор: «Священная кара» — +0.5 урона за погибшего союзника ═══
		if ability.ability_marker == "inquisitor_holy_judgment" and target.current_hp > 0:
			var _dead_allies = 0
			var _hj_team = enemies_team if attacker.is_enemy else heroes_team
			for _hj_unit in _hj_team:
				if _hj_unit and _hj_unit.current_hp <= 0:
					_dead_allies += 1
			if _dead_allies > 0:
				var _hj_bonus = int(attacker.damage * 0.5 * _dead_allies)
				var _hj_hp_b = target.current_hp
				target.take_damage(_hj_bonus)
				log_lines.append("  → [Священная кара] +%d урона за %d погибших союзников. HP: %d → %d" % [_hj_bonus, _dead_allies, _hj_hp_b, target.current_hp])
				if target.current_hp <= 0:
					log_lines.append("  → %s повержен!" % target.unit_name)
					target.killed_by = attacker
					_on_unit_killed(target, log_lines)
					var _hj_team2 = heroes_team if not target.is_enemy else enemies_team
					_compact_team(_hj_team2)

		# ═══ Тритон: «Морская кавалерия» — маркерный эффект для ИИ (+20 броня/+20 урон уже через effect_types) ═══
		if ability.ability_marker == "triton_cavalry":
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 3, "effect_id": "triton_cavalry", "source_ability": "Морская кавалерия"})
			log_lines.append("  → [Морская кавалерия] %s: +20 брони и +20 атаки на 3 хода." % attacker.unit_name)
			
			# ═══ Птица: «Острые крылья» — -5% брони цели на 4 хода ═══
			if ability.ability_marker == "bird_armor_shred" and target.current_hp > 0:
				var _shred = maxi(1, int(target.armor * 0.05))
				target.apply_stat_change("armor", -_shred)
				target.active_effects.append({"stat": "armor", "value": -_shred, "duration": 4, "effect_id": "bird_armor_shred", "source_ability": "Острые крылья"})
				log_lines.append("  → [Острые крылья] %s: -%d брони (5%%) на 4 хода." % [target.unit_name, _shred])
			
			# ═══ Птица: «Метать перья» — марка на позиции цели (0,7 урона, 2 хода) ═══
			if ability.ability_marker == "bird_feather_mark" and target.current_hp > 0:
				marks.add_position_mark({
					"caster": attacker, "team": "ally", "position": target.position_index,
					"type": "persistent", "rounds_left": 2,
					"damage_percent": 70.0, "damage_type": "Physical",
					"effect_type": "", "effect_value": 0, "effect_duration": 0,
					"icon": ability.mark_icon,
					"triggered_units_this_round": []
				})
				log_lines.append("  → [Метать перья] Марка на позиции %d (0,7 урона) на 2 хода." % (target.position_index + 1))
			
			# ═══ Купидон: «Я такой милый» — метка невинности (50% перенаправление) ═══
			if ability.ability_marker == "cupid_innocence" and target.current_hp > 0:
				target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "cupid_innocence", "source_ability": "Я такой милый"})
				log_lines.append("  → [Я такой милый] %s получает метку невинности (50%% перенаправление)." % target.unit_name)
			
			# ═══ Пегас: «Кара с небес» — +10 точности и +10 удачи навсегда ═══
			if ability.ability_marker == "pegasus_judgment":
				attacker.apply_stat_change("accuracy", 10)
				attacker.apply_stat_change("crit", 10)
				attacker.active_effects.append({"stat": "accuracy", "value": 10, "duration": -1, "effect_id": "pegasus_judgment_acc", "source_ability": "Кара с небес"})
				attacker.active_effects.append({"stat": "crit", "value": 10, "duration": -1, "effect_id": "pegasus_judgment_crit", "source_ability": "Кара с небес"})
				log_lines.append("  → [Кара с небес] %s: +10 точности и +10 удачи навсегда." % attacker.unit_name)
			
			# ═══ Грифон: «Пикировать» — марка на позиции цели (200% урона) ═══
			if ability.ability_marker == "griffin_dive" and target.current_hp > 0:
				marks.add_position_mark({
					"caster": attacker, "team": "ally", "position": target.position_index,
					"type": "once", "rounds_left": 2,
					"damage_percent": 200.0, "damage_type": "Physical",
					"effect_type": "", "effect_value": 0, "effect_duration": 0,
					"icon": ability.mark_icon,
					"triggered_units_this_round": []
				})
				log_lines.append("  → [Пикировать] Марка на позиции %d (200%% урона)." % (target.position_index + 1))
			
			# ═══ Грифон: «Небесное копье» — бонус урон за уклонение ═══
			if ability.ability_marker == "griffin_sky_spear" and target.current_hp > 0:
				var _ss_evasion = attacker.evasion
				var _ss_bonus = int(attacker.damage * _ss_evasion / 100.0)
				if _ss_bonus > 0:
					var _ss_hp_b = target.current_hp
					target.take_damage(_ss_bonus)
					log_lines.append("  → [Небесное копье] +%d урона (%d%% от уклонения). HP: %d → %d" % [_ss_bonus, _ss_evasion, _ss_hp_b, target.current_hp])
			
			# ═══ Пост-уроновые self-эффекты (зависят от нанесённого урона) ═══
		for effect in ability.effect_types:
			if effect == "self_damage_dealt_percent" and total_damage_dealt > 0:
				var pct = ability.effect_values.get("self_damage_dealt_percent", 0)
				var self_dmg = int(total_damage_dealt * pct / 100.0)
				if self_dmg > 0:
					attacker.take_damage(self_dmg)
					log_lines.append("  → %s получает %d ответного урона (%d%% от нанесённого)." % [attacker.unit_name, self_dmg, pct])
		
		if (not attacker.is_enemy or attacker.is_nemesis) and ability.majesty_gain > 0:
			if not _redirect_majesty_to_set_true_king(attacker, ability.majesty_gain, log_lines):
				attacker.modify_majesty(ability.majesty_gain)
				log_lines.append("  → %s получает %d величия." % [attacker.unit_name, ability.majesty_gain])
		
		# ═══ Туннели — Дварф-кузнец: «Улучшить снаряжение» — жетоны ковки удваивают эффект ═══
		if ability.ability_marker == "dwarf_smith_upgrade":
			var _ds_tokens = attacker.get_meta("smith_forge_tokens", 0)
			if _ds_tokens > 0:
				var _ds_extra = 5 * (int(pow(2, _ds_tokens)) - 1)
				target.apply_stat_change("armor", _ds_extra)
				target.apply_stat_change("damage", _ds_extra)
				target.active_effects.append({"stat": "armor", "value": _ds_extra, "duration": 2, "effect_id": "dwarf_smith_upgrade", "source_ability": "Улучшить снаряжение"})
				target.active_effects.append({"stat": "damage", "value": _ds_extra, "duration": 2, "effect_id": "dwarf_smith_upgrade", "source_ability": "Улучшить снаряжение"})
				log_lines.append("  → [Улучшить снаряжение] +%d брони, +%d урона (жетоны: %d)." % [_ds_extra, _ds_extra, _ds_tokens])
			# Пассивка кузнеца: +5 брони при баффе союзника
			attacker.apply_stat_change("armor", 5)
			attacker.active_effects.append({"stat": "armor", "value": 5, "duration": 2, "effect_id": "dwarf_smith_passive", "source_ability": "Пассивка"})
			log_lines.append("  → [Кузнец] %s: +5 брони за бафф союзника." % attacker.unit_name)
		
		# ═══ Туннели — Голем: «Вперёд» — пассивка роста сработает дважды ═══
		if ability.ability_marker == "golem_forward":
			attacker.set_meta("golem_double_passive", true)
			log_lines.append("  → [Вперёд] %s: рост пассивки удвоен в этом ходу." % attacker.unit_name)
		
		# ═══ Туннели — Шаман: «Каменная стена» — призыв Валуна ═══
		if ability.ability_marker == "shaman_stone_wall":
			attacker.set_meta("shaman_used_stone_wall", true)
			_summon_boulder(attacker, log_lines)
		
		# ═══════════════════════════════════════════════════════
		# ЗВЁЗДЫ — юниты зодиака (маркеры способностей)
		# ═══════════════════════════════════════════════════════

		# Скорпион: «Ядовитое жало» — периодический урон 0,4 на 3 хода
		if ability.ability_marker == "scorpio_poison_sting" and target.current_hp > 0:
			var _sps_dmg = int(attacker.damage * 0.4)
			if _sps_dmg > 0:
				var _sps_duration = _compute_effect_duration(attacker, target, 3, true)
				target.active_effects.append({"stat": "periodic_damage", "value": _sps_dmg, "duration": _sps_duration, "source_ability": "Ядовитое жало"})
				log_lines.append("  → [Ядовитое жало] %s получает периодический урон (%d) на %d хода." % [target.unit_name, _sps_dmg, _sps_duration])

		# Весы: «Дизбаланс» — доп. чистый урон за каждый 1% недостающего HP Весов
		if ability.ability_marker == "libra_imbalance" and target.current_hp > 0:
			var _lib_miss = float(attacker.max_hp - attacker.current_hp) / float(maxi(1, attacker.max_hp))
			var _lib_bonus = int(attacker.damage * _lib_miss)
			if _lib_bonus > 0:
				var _lib_hp_b = target.current_hp
				target.take_damage(_lib_bonus)
				log_lines.append("  → [Дизбаланс] +%d чистого урона (%d%% недостающего HP). HP: %d → %d" % [_lib_bonus, int(_lib_miss * 100), _lib_hp_b, target.current_hp])

		# ── Запускаемые один раз за применение способности ──
		var _stars_run_once = targets.is_empty() or target == targets[0]

		if _stars_run_once and _should_trigger_thor_hammer_of_lightning(attacker, ability):
			_trigger_thor_hammer_of_lightning(attacker, log_lines)

		# Скорпион: «Жестокость» — ВСЕМ юнитам +10 атаки и -10 брони на 1 ход
		if ability.ability_marker == "scorpio_cruelty" and _stars_run_once:
			for _cr_u in (enemies_team + heroes_team):
				if _cr_u == null or _cr_u.current_hp <= 0:
					continue
				var _cr_buff_duration = _compute_effect_duration(attacker, _cr_u, 1, false)
				var _cr_debuff_duration = _compute_effect_duration(attacker, _cr_u, 1, true)
				effects._apply_buff_to_unit(_cr_u, "damage", 10, _cr_buff_duration, "scorpio_cruelty", "Жестокость")
				_cr_u.apply_stat_change("armor", -10)
				_cr_u.active_effects.append({"stat": "armor", "value": -10, "duration": _cr_debuff_duration, "effect_id": "scorpio_cruelty", "source_ability": "Жестокость"})
			log_lines.append("  → [Жестокость] Все юниты: +10 урона, -10 брони (1 ход).")

		# Дева: «Звездопад» — все юниты +10 крита на 2 хода
		if ability.ability_marker == "virgo_starfall" and _stars_run_once:
			for _sf_u in (enemies_team + heroes_team):
				if _sf_u == null or _sf_u.current_hp <= 0:
					continue
				var _sf_duration = _compute_effect_duration(attacker, _sf_u, 2, false)
				effects._apply_buff_to_unit(_sf_u, "crit", 10, _sf_duration, "virgo_starfall", "Звездопад")
			log_lines.append("  → [Звездопад] Все юниты: +10 крита (2 хода).")

		# Дева: «Невинное касание» — теряет все свои баффы, +10 урона за каждый снятый эффект
		if ability.ability_marker == "virgo_innocent_touch" and _stars_run_once:
			var _it_count = _count_buffs_on_unit(attacker)
			effects._dispel_effects(attacker, "buff")
			var _it_bonus = _it_count * 10
			if _it_bonus > 0:
				var _it_duration = _compute_effect_duration(attacker, attacker, 2, false)
				effects._apply_buff_to_unit(attacker, "damage", _it_bonus, _it_duration, "virgo_innocent_touch", "Невинное касание")
			log_lines.append("  → [Невинное касание] %s теряет %d бафф(ов), +%d урона." % [attacker.unit_name, _it_count, _it_bonus])

		# Дева: «Как повелели звёзды» — союзники получают эффект своей клетки как бафф на 2 хода
		if ability.ability_marker == "virgo_stars_decree" and _stars_run_once:
			var _asd_team = enemies_team if attacker.is_enemy else heroes_team
			for _asd_i in range(_asd_team.size()):
				var _asd_u = _asd_team[_asd_i]
				if _asd_u == null or _asd_u.current_hp <= 0:
					continue
				locations._apply_star_cell_buff(_asd_u, _asd_i, 2)
			log_lines.append("  → [Как повелели звёзды] Союзники получают эффект своих клеток (2 хода).")

		# Близнецы: «Разделиться» — лечит 50% макс. HP, -50% урона до конца боя
		if ability.ability_marker == "gemini_split" and _stars_run_once:
			var _sp_heal = int(attacker.max_hp * 0.5)
			var _sp_hp_b = attacker.current_hp
			attacker.apply_stat_change("hp", _sp_heal)
			var _sp_dmg_down = maxi(1, int(attacker.base_damage * 0.5))
			attacker.damage_modifier_flat -= _sp_dmg_down
			attacker.active_effects.append({"stat": "damage", "value": -_sp_dmg_down, "duration": -1, "effect_id": "gemini_split", "source_ability": "Разделиться"})
			log_lines.append("  → [Разделиться] %s восстанавливает %d HP (%d → %d), -%d урона до конца боя." % [attacker.unit_name, _sp_heal, _sp_hp_b, attacker.current_hp, _sp_dmg_down])

		# ═══════════════════════════════════════════════════════
		# САД — маркеры способностей юнитов сада
		# ═══════════════════════════════════════════════════════

		# Цветочная фея: «Неудержимое цветение» — всем врагам регенерация 5% и периодический урон
		if ability.ability_marker == "flower_unstoppable_bloom":
			var _fb_foe_team = heroes_team if attacker.is_enemy else enemies_team
			var _fb_pdmg = int(attacker.damage * 0.15)
			for _fb_f in _fb_foe_team:
				if _fb_f and _fb_f.current_hp > 0:
					_fb_f.active_effects.append({"stat": "regeneration", "value": 5, "duration": 2, "effect_id": "flower_unstoppable_bloom", "source_ability": "Неудержимое цветение"})
					if _fb_pdmg > 0:
						_fb_f.active_effects.append({"stat": "periodic_damage", "value": _fb_pdmg, "duration": 2, "source_ability": "Неудержимое цветение"})
			log_lines.append("  → [Неудержимое цветение] Все противники: регенерация 5%% + периодический урон (%d) на 2 хода." % _fb_pdmg)

		# Фея шипов: «Чесоточный порошок» — периодический урон
		if ability.ability_marker == "thorn_itching_powder" and target and target.current_hp > 0:
			var _ip_pdmg = maxi(1, int(attacker.damage * 0.2))
			target.active_effects.append({"stat": "periodic_damage", "value": _ip_pdmg, "duration": 3, "source_ability": "Чесоточный порошок"})
			log_lines.append("  → [Чесоточный порошок] %s получает периодический урон (%d) на 3 хода." % [target.unit_name, _ip_pdmg])

		# Фея шипов: «Колючий куст» — марка на союзника (отражение 30% урона феи)
		if ability.ability_marker == "thorn_bush" and target and target.current_hp > 0:
			target.active_effects.append({"stat": "thorn_bush_mark", "value": 1, "duration": 3, "effect_id": "thorn_bush_mark", "source_ability": "Колючий куст", "owner": attacker})
			log_lines.append("  → [Колючий куст] %s под защитой: атаковавший получит 30%% урона феи шипов (3 хода)." % target.unit_name)

		# Альрауне: «Высасывание жизни» — лечение 30% от урона
		if ability.ability_marker == "alraune_life_drain" and target and target.current_hp >= 0:
			var _ld_heal = int(attacker.damage * ability.damage_modifier * 0.3)
			if _ld_heal > 0:
				var _ld_hp_b = attacker.current_hp
				attacker.apply_stat_change("hp", _ld_heal)
				log_lines.append("  → [Высасывание жизни] %s восстанавливает %d HP (%d → %d)." % [attacker.unit_name, _ld_heal, _ld_hp_b, attacker.current_hp])

		# Друид: «Стимулировать рост» — союзник +4 урона навсегда
		if ability.ability_marker == "druid_stimulate_growth" and target and target.current_hp > 0:
			effects._apply_buff_to_unit(target, "damage", 4, -1, "druid_stimulate_growth", "Стимулировать рост")
			log_lines.append("  → [Стимулировать рост] %s: +4 урона до конца боя." % target.unit_name)

		# Друид: «Гнев природы» — +1 к длительности всех дебаффов цели
		if ability.ability_marker == "druid_natures_wrath" and target and target.current_hp > 0:
			var _nw_cnt = 0
			for _nw_e in target.active_effects:
				var _nw_v = Combatant._effect_get(_nw_e, "value", 0)
				var _nw_d = Combatant._effect_get(_nw_e, "duration", -1)
				if _nw_v < 0 and _nw_d > 0 and Combatant._effect_get(_nw_e, "stat", "") != "stun":
					_nw_e["duration"] = _nw_d + 1
					_nw_cnt += 1
			log_lines.append("  → [Гнев природы] %s: длительность %d дебафф(ов) +1." % [target.unit_name, _nw_cnt])

		# Единорог: «Очищающий рог» — +15% урона за каждый дебафф (доп. чистый урон)
		if ability.ability_marker == "unicorn_cleansing_horn" and target and target.current_hp > 0:
			var _ch_debuffs = target._count_active_debuffs()
			if _ch_debuffs > 0:
				var _ch_bonus = int(attacker.damage * 0.15 * _ch_debuffs)
				if _ch_bonus > 0:
					var _ch_hp_b = target.current_hp
					target.take_damage(_ch_bonus)
					log_lines.append("  → [Очищающий рог] +%d чистого урона за %d дебафф(ов). HP: %d → %d" % [_ch_bonus, _ch_debuffs, _ch_hp_b, target.current_hp])
	
		# Единорог: «Кровь единорога» — потерять 10% HP, полностью вылечить союзника
		if ability.ability_marker == "unicorn_blood" and target and target.current_hp > 0:
			var _ub_cost = int(attacker.max_hp * 0.10)
			attacker.take_damage(_ub_cost)
			var _ub_hp_b = target.current_hp
			target.apply_stat_change("hp", target.max_hp)
			log_lines.append("  → [Кровь единорога] %s теряет %d HP, %s восстанавливает полное HP (%d → %d)." % [attacker.unit_name, _ub_cost, target.unit_name, _ub_hp_b, target.current_hp])

		# ═══ Бальдр: «Стрела в моём теле» — 100% чистого урона себе, снимает свои дебаффы,
		# за каждый снятый противники получают 5 урона ═══
		if ability.ability_marker == "baldr_arrow_in_my_body" and target == attacker and attacker.current_hp > 0:
			var _bal_self_dmg = int(attacker.damage)
			var _bal_hp_before = attacker.current_hp
			attacker.take_damage(_bal_self_dmg)
			log_lines.append("  → [Стрела в моём теле] %s получает %d чистого урона. HP: %d → %d" % [attacker.unit_name, _bal_self_dmg, _bal_hp_before, attacker.current_hp])
			if attacker.current_hp > 0:
				var _bal_debuff_count = _count_debuffs_on_unit(attacker)
				effects._dispel_effects(attacker, "debuff")
				if _bal_debuff_count > 0:
					var _bal_dmg_each = 5 * _bal_debuff_count
					log_lines.append("  → [Стрела в моём теле] %s снимает с себя %d дебафф(ов) — противники получают по %d урона." % [attacker.unit_name, _bal_debuff_count, _bal_dmg_each])
					for _bal_h in heroes_team:
						if _bal_h and _bal_h.current_hp > 0:
							var _bal_h_hp_b = _bal_h.current_hp
							_bal_h.take_damage(_bal_dmg_each)
							log_lines.append("    %s получает %d урона. HP: %d → %d" % [_bal_h.unit_name, _bal_dmg_each, _bal_h_hp_b, _bal_h.current_hp])
							if _bal_h.current_hp <= 0:
								_on_unit_killed(_bal_h, log_lines)
					_compact_team(heroes_team)
			else:
				_on_unit_killed(attacker, log_lines)
				_compact_team(enemies_team)
	
			# ═══ Стойка: войти в стойку после применения способности ═══
	if ability.is_stance:
		attacker.enter_stance(ability)
		log_lines.append("  → %s входит в стойку: %s." % [attacker.unit_name, ability.name])
		# Новичок: «Я только учусь» — +30 уклонения, пока активна стойка
		if ability.stance_effect_type == "novice_training":
			attacker.apply_stat_change("evasion", 30)
			attacker.active_effects.append({"stat": "evasion", "value": 30, "duration": 2, "effect_id": "novice_training", "source_ability": "Я только учусь"})
			log_lines.append("  → [Я только учусь] %s: +30 уклонения." % attacker.unit_name)
		# Гоплит: «Поднять щиты» — +20 брони, пока активна стойка
		elif ability.stance_effect_type == "hoplite_shield_wall":
			attacker.apply_stat_change("armor", 20)
			attacker.active_effects.append({"stat": "armor", "value": 20, "duration": 2, "effect_id": "hoplite_shield_armor", "source_ability": "Поднять щиты"})
			log_lines.append("  → [Поднять щиты] %s: +20 брони." % attacker.unit_name)
		# Золотая валькирия: «Воин дня» — +10 уклонения + распространение на серебряных валькирий
		elif ability.stance_effect_type == "warrior_of_day_stance":
			attacker.apply_stat_change("evasion", 10)
			attacker.active_effects.append({"stat": "evasion", "value": 10, "duration": 1, "effect_id": "warrior_of_day_stance", "source_ability": "Воин дня"})
			log_lines.append("  → [Воин дня] %s: +10 уклонения." % attacker.unit_name)
			_propagate_valkyrie_buff(attacker, "golden_valkyrie", "silver_valkyrie", "evasion", 10, 1, log_lines)
		# Серебрянная валькирия: «Воин ночи» — +10 уклонения + распространение на золотых валькирий
		elif ability.stance_effect_type == "warrior_of_night_stance":
			attacker.apply_stat_change("evasion", 10)
			attacker.active_effects.append({"stat": "evasion", "value": 10, "duration": 1, "effect_id": "warrior_of_night_stance", "source_ability": "Воин ночи"})
			log_lines.append("  → [Воин ночи] %s: +10 уклонения." % attacker.unit_name)
			_propagate_valkyrie_buff(attacker, "silver_valkyrie", "golden_valkyrie", "evasion", 10, 1, log_lines)
		# ═══ Замок — Принцесса: «В беде» — метка провокации + 20 уклонения ═══
		elif ability.stance_effect_type == "princess_in_trouble":
			attacker.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": 1, "effect_id": "provocation_mark", "source_ability": "В беде"})
			attacker.apply_stat_change("evasion", 20)
			attacker.active_effects.append({"stat": "evasion", "value": 20, "duration": 1, "effect_id": "princess_in_trouble", "source_ability": "В беде"})
			log_lines.append("  → [В беде] %s: метка провокации + 20 уклонения." % attacker.unit_name)
		# ═══ Замок — Рыцарь: «Сила превыше магии» — +15 брони + +2 к стоимости заклинаний ═══
		elif ability.stance_effect_type == "knight_magic_supremacy":
			attacker.apply_stat_change("armor", 15)
			attacker.active_effects.append({"stat": "armor", "value": 15, "duration": 1, "effect_id": "knight_magic_supremacy", "source_ability": "Сила превыше магии"})
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 1, "effect_id": "knight_magic_supremacy_cost", "source_ability": "Сила превыше магии"})
			log_lines.append("  → [Сила превыше магии] %s: +15 брони, +2 к стоимости заклинаний." % attacker.unit_name)
		# ═══ Замок — Стражник: «Стой кто идёт!» — все враги -20 уклонения ═══
		elif ability.stance_effect_type == "guardsman_halt":
			var _halt_foe_team = heroes_team if attacker.is_enemy else enemies_team
			for _halt_foe in _halt_foe_team:
				if _halt_foe and _halt_foe.current_hp > 0:
					_halt_foe.apply_stat_change("evasion", -20)
					_halt_foe.active_effects.append({"stat": "evasion", "value": -20, "duration": 1, "effect_id": "guardsman_halt", "source_ability": "Стой кто идёт!"})
			log_lines.append("  → [Стой кто идёт!] Все враги: -20 уклонения.")
		
		# Звёзды — Весы: «Равновесие» — стойка (реакция на урон союзника обрабатывается в блоке попадания)
		elif ability.stance_effect_type == "libra_balance":
			log_lines.append("  → [Равновесие] %s: пока союзники получают урон, враги страдают (1/4 чистым)." % attacker.unit_name)
		# Сад — Единорог: «Грациозная осанка» — +20 брони и +20 уклонения
		elif ability.stance_effect_type == "unicorn_grace":
			attacker.apply_stat_change("armor", 20)
			attacker.active_effects.append({"stat": "armor", "value": 20, "duration": -1, "effect_id": "unicorn_grace_armor", "source_ability": "Грациозная осанка"})
			attacker.apply_stat_change("evasion", 20)
			attacker.active_effects.append({"stat": "evasion", "value": 20, "duration": -1, "effect_id": "unicorn_grace_evasion", "source_ability": "Грациозная осанка"})
			log_lines.append("  → [Грациозная осанка] %s: +20 брони, +20 уклонения." % attacker.unit_name)
		# Сад — Сатир: «Чарующая песня» — все враги -5 атаки (эффект растёт в начале следующего раунда)
		elif ability.stance_effect_type == "satyr_charm":
			attacker.set_meta("satyr_charm_stacks", 0)
			log_lines.append("  → [Чарующая песня] %s: враги теряют по 5 атаки каждый раунд стойки." % attacker.unit_name)
		# Один: «Предвидеть» — все союзники +20 уклонения и +15 удачи на 1 ход (стойка, обновляется каждый ход)
		elif ability.stance_effect_type == "odin_foresight":
			_refresh_odin_foresight_aura(attacker)
		# Дуна: «В гармонии с природой» — назад 1, союзники иммунны к дебаффам
		elif ability.stance_effect_type == "duna_harmony":
			_apply_shift_effect(attacker, 1, _is_player_hero(attacker))
			var _hteam = heroes_team if not attacker.is_enemy else enemies_team
			for ally in _hteam:
				if ally and ally.current_hp > 0:
					ally.active_effects.append({"stat":"trigger_marker","value":0,"duration":-1,"effect_id":"duna_harmony_immune","source_ability":"В гармонии с природой"})
			log_lines.append("  → [В гармонии с природой] %s: назад 1. Союзники иммунны к негативным эффектам." % attacker.unit_name)
			marks.check_on_move(attacker)
			_update_all_visuals()
		# Шива: «Карма» — противник получает 50% урона + копирует дебаффы
		elif ability.stance_effect_type == "shiva_karma":
			log_lines.append("  → [Карма] %s: противники получают 50%% урона и копируют дебаффы." % attacker.unit_name)
		# Чернобог: «Надежды нет» — противники не могут получать баффы
		elif ability.stance_effect_type == "chernobog_no_hope":
			log_lines.append("  → [Надежды нет] %s: противники не могут получать баффы; попытка = 80%% урона." % attacker.unit_name)
		# Посейдон: «Штиль» — при движении противника 70% урона
		elif ability.stance_effect_type == "poseidon_calm":
			log_lines.append("  → [Штиль] %s: при движении противника — 70%% урона." % attacker.unit_name)
		# Шива: «Цикл разрушения» — реакция на действие + крит повтор + вперёд 2
		elif ability.stance_effect_type == "shiva_destruction_cycle":
			_apply_shift_effect(attacker, -2, _is_player_hero(attacker))
			log_lines.append("  → [Цикл разрушения] %s: вперёд 2. При действии врага — 0.7 урона. Крит — повтор." % attacker.unit_name)
			marks.check_on_move(attacker)
			_update_all_visuals()
		# ═══ Индиго: при использовании Охоты/Разорвать — снять все стаки «Взять след» ═══
	if ability.name == "Охота" or ability.name == "Разорвать":
		_remove_indigo_trail_buffs(attacker, log_lines)
	
	# ═══ Марка от ИИ (Пытка попугаем, Болотное царство и т.п.): разместить марку на позиции цели ═══
	if ability.mark_type_int > 0 and ability.target_type == "Enemy" and defender:
		var mark = {
			"caster": attacker,
			"team": "enemy" if defender.is_enemy else "ally",
			"position": defender.position_index,
			"type": ability.mark_type,
			"rounds_left": ability.mark_duration if ability.mark_type == "persistent" else 1,
			"damage_percent": ability.mark_damage_percent,
			"damage_type": ability.mark_damage_type,
			"effect_type": ability.mark_effect_type,
			"effect_value": ability.mark_effect_value,
			"effect_duration": ability.mark_effect_duration,
			"icon": ability.mark_icon,
			"triggered_units_this_round": []
		}
		marks.add_position_mark(mark)
		log_lines.append("  → %s накладывает марку «%s» на позицию %d на %d ход(ов)." % [
			attacker.unit_name, ability.name, defender.position_index + 1, ability.mark_duration])
		# Персистентная марка срабатывает сразу при наложении (но не чаще раза за раунд);
		# одноразовая (once) — только в начале следующего хода заклинателя.
		if ability.mark_type == "persistent" and defender.current_hp > 0:
			marks.apply_mark_to_unit(mark, defender, true)
			mark["triggered_units_this_round"].append(defender)
	# Марки прочих типов цели (Position у ИИ, Ally, Self и др.):
	# ставятся на позицию выбранной цели, на стороне этой цели.
	elif ability.mark_type_int > 0 and ability.target_type != "Enemy" and defender:
		var _pos_mark = {
			"caster": attacker,
			"team": "enemy" if defender.is_enemy else "ally",
			"position": defender.position_index,
			"type": ability.mark_type,
			"rounds_left": ability.mark_duration if ability.mark_type == "persistent" else 1,
			"damage_percent": ability.mark_damage_percent,
			"damage_type": ability.mark_damage_type,
			"effect_type": ability.mark_effect_type,
			"effect_value": ability.mark_effect_value,
			"effect_duration": ability.mark_effect_duration,
			"icon": ability.mark_icon,
			"triggered_units_this_round": []
		}
		marks.add_position_mark(_pos_mark)
		log_lines.append("  → %s накладывает марку «%s» на позицию %d на %d ход(ов)." % [
			attacker.unit_name, ability.name, defender.position_index + 1, _pos_mark["rounds_left"]])
		if ability.mark_type == "persistent" and defender.current_hp > 0:
			marks.apply_mark_to_unit(_pos_mark, defender, true)
			_pos_mark["triggered_units_this_round"].append(defender)
				
	_propagate_new_voodoo_debuffs(voodoo_effect_snapshot, log_lines)
	_update_marks_display()
	_update_all_visuals()
	for line in log_lines:
		_log_combat(line)

func _trigger_thunder_wrath(attacker: Combatant):
	var enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
	if enemies.is_empty():
		return
	_log_combat("⚡ %s обрушивает Гнев Бога Грома — 5 ударов!" % attacker.unit_name)
	for i in range(5):
		if _check_battle_end():
			return
		enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.3)
		if not dmg_result.is_hit:
			_log_combat("  [Удар %d] → Промах по %s." % [i + 1, target.unit_name])
			continue
		_deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_log_combat("  [Удар %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text, dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			var team = heroes_team if target.is_enemy == false else enemies_team
			_compact_team(team)
	_update_all_visuals()

func _trigger_indigo_hunt_stance(attacker: Combatant):
	var enemies = _get_living_team_members(heroes_team)  # attacker is enemy
	if enemies.is_empty():
		return
	
	# Фильтруем цели по targetable_positions стойки
	var valid: Array = []
	for e in enemies:
		if Combatant.can_be_targeted_at(e, attacker.active_stance):
			valid.append(e)
	if valid.is_empty():
		valid = enemies
	
	var target: Combatant = valid[randi() % valid.size()]
	var dmg_result = CombatCalculator.calculate_ability_damage(attacker, target, attacker.active_stance)
	
	if not dmg_result.is_hit:
		_log_combat("  → %s (стойка Охота) промахивается по %s." % [attacker.unit_name, target.unit_name])
		return
	
	_deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
	var crit_text = " (крит!)" if dmg_result.is_crit else ""
	_log_combat("  → %s (стойка Охота) наносит %d урона%s %s. HP: %d → %d" % [
		attacker.unit_name, dmg_result.final_damage, crit_text, target.unit_name,
		dmg_result.hp_before, target.current_hp
	])
	
	if target.current_hp <= 0:
		_log_combat("  → %s повержен!" % target.unit_name)
		_on_unit_killed(target)
		var team = heroes_team if target.is_enemy == false else enemies_team
		_compact_team(team)
	_update_all_visuals()

## Индиго: снимает все стаки «Взять след» (эффекты с source_ability == "Взять след"),
## reversing stat changes.
func _remove_indigo_trail_buffs(unit: Combatant, log_lines: Array):
	var removed_count = 0
	var i = 0
	while i < unit.active_effects.size():
		var eff = unit.active_effects[i]
		var src = Combatant._effect_get(eff, "source_ability", "")
		if src == "Взять след":
			var stat = Combatant._effect_get(eff, "stat", "")
			var val = Combatant._effect_get(eff, "value", 0)
			if stat != "" and val != 0:
				unit.apply_stat_change(stat, -val)
			unit.active_effects.remove_at(i)
			removed_count += 1
		else:
			i += 1
	if removed_count > 0:
		log_lines.append("  → %s: снято %d стак(ов) «Взять след»." % [unit.unit_name, removed_count])

## Флибустьер: стойка «Я знаю что делаю» — 2 удара по случайным врагам
## с использованием параметров стойки (damage_modifier). Не промахивается.
func _trigger_filibuster_double_hit(attacker: Combatant):
	var enemies = _get_living_team_members(heroes_team)  # attacker is enemy
	if enemies.is_empty():
		return
	var stance = attacker.active_stance
	_log_combat("🗡️ %s (стойка «Я знаю что делаю») наносит 2 удара!" % attacker.unit_name)
	for i in range(2):
		if _check_battle_end():
			return
		enemies = _get_living_team_members(heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_forced_hit_damage(attacker, target, stance)
		if not dmg_result.is_hit:
			_log_combat("  [Удар %d] → Промах по %s." % [i + 1, target.unit_name])
			continue
		_deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_log_combat("  [Удар %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text,
			dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			var team = heroes_team
			_compact_team(team)
	_update_all_visuals()

## Матрос с бомбой: стойка «Бомбардировка» — 4 удара по случайным врагам
## с использованием параметров стойки (damage_modifier = 0.5).
func _trigger_bombardment_stance(attacker: Combatant):
	var enemies = _get_living_team_members(heroes_team)  # attacker is enemy
	if enemies.is_empty():
		return
	var stance = attacker.active_stance
	_log_combat("💥 %s (стойка «Бомбардировка») обрушивает 4 удара!" % attacker.unit_name)
	for i in range(4):
		if _check_battle_end():
			return
		enemies = _get_living_team_members(heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_ability_damage(attacker, target, stance)
		if not dmg_result.is_hit:
			_log_combat("  [Удар %d] → Промах по %s." % [i + 1, target.unit_name])
			continue
		_deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_log_combat("  [Удар %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text,
			dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			var team = heroes_team
			_compact_team(team)
	_update_all_visuals()

func _redirect_majesty_to_set_true_king(unit: Combatant, amount: int, log_lines: Array) -> bool:
	if unit == null or amount <= 0 or unit.current_hp <= 0 or unit.is_enemy:
		return false
	var team = heroes_team if not unit.is_enemy else enemies_team
	for set_unit in team:
		if set_unit == null or set_unit == unit or set_unit.current_hp <= 0:
			continue
		if set_unit.active_stance != null and set_unit.active_stance.stance_effect_type == "set_true_king":
			set_unit.modify_majesty(amount)
			var heal_amount: int = maxi(1, int(unit.max_hp * 0.10))
			unit.apply_stat_change("hp", heal_amount)
			unit.apply_stat_change("armor", 10)
			var _stk_duration = _compute_effect_duration(set_unit, unit, 1, false)
			unit.active_effects.append({"stat": "armor", "value": 10, "duration": _stk_duration, "effect_id": "set_true_king_armor", "source_ability": "Настоящий король"})
			log_lines.append("  → [Настоящий король] %s перехватывает %d величия. %s получает +%d HP и +10 брони." % [set_unit.unit_name, amount, unit.unit_name, heal_amount])
			return true
	return false

## Сет: «Настоящий король» — союзники исцеляются на 10% HP, Сет получает 5 величия за каждого союзника.
## Один: «Предвидеть» — обновляет +20 уклонения/+15 удачи на 1 ход всем живым союзникам.
## Вызывается при касте и затем в начале каждого хода Одина, пока стойка не прервана
## (перемещением/станом — см. check_stance_interruption). Раньше баффы ставились с
## duration=-1 (навсегда, без снятия при разрыве стойки) — теперь они честно живут 1 ход
## и обновляются заново, пока стойка держится, а без обновления сами истекают.
func _refresh_odin_foresight_aura(attacker: Combatant) -> void:
	var _team = heroes_team if not attacker.is_enemy else enemies_team
	var _fe_duration = _compute_effect_duration(attacker, attacker, 1, false)
	for ally in _team:
		if ally == null or ally.current_hp <= 0:
			continue
		for _fid in ["odin_foresight_ev", "odin_foresight_cr"]:
			for i in range(ally.active_effects.size() - 1, -1, -1):
				var _fe = ally.active_effects[i]
				if Combatant._effect_get(_fe, "effect_id", "") == _fid:
					var _fst = Combatant._effect_get(_fe, "stat", "")
					var _fvl = Combatant._effect_get(_fe, "value", 0)
					ally.apply_stat_change(_fst, -_fvl)
					ally.active_effects.remove_at(i)
		ally.apply_stat_change("evasion", 20)
		ally.active_effects.append({"stat": "evasion", "value": 20, "duration": _fe_duration, "effect_id": "odin_foresight_ev", "source_ability": "Предвидеть"})
		ally.apply_stat_change("crit", 15)
		ally.active_effects.append({"stat": "crit", "value": 15, "duration": _fe_duration, "effect_id": "odin_foresight_cr", "source_ability": "Предвидеть"})
	_log_combat("  → [Предвидеть] Все союзники: +20 уклонения, +15 удачи на %d ход(ов)." % _fe_duration)

func _trigger_set_true_king(unit: Combatant):
	_log_combat("👑 [Сет] Настоящий король: стойка завершена.")
	_update_all_visuals()

## Локи: «Рагнарек» — все враги получают 0.5x урон, текущий шанс крита удваивается на 1 ход.
func _trigger_loki_ragnarok(attacker: Combatant):
	# Удвоить ТЕКУЩИЙ шанс крита: прибавить к modifier текущий crit_chance
	var _rg_cur = attacker.crit_chance
	attacker.crit_modifier += _rg_cur
	var _rg_duration = _compute_effect_duration(attacker, attacker, 1, false)
	attacker.active_effects.append({"stat": "crit_modifier", "value": _rg_cur, "duration": _rg_duration, "effect_id": "loki_ragnarok_crit", "source_ability": "Рагнарек"})
	_log_combat("🔥 [Локи] Рагнарек! Шанс крита удвоен: %d%% → %d%%." % [int(_rg_cur * 100), int(attacker.crit_chance * 100)])
	var enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
	if enemies.is_empty():
		_log_combat("🔥 [Локи] Рагнарек! Двойной крит, но целей нет.")
		return
	_log_combat("🔥 [Локи] Рагнарек! Все враги получают урон, крит x2!")
	for target in enemies:
		if _check_battle_end():
			return
		var dmg_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.5)
		if not dmg_result.is_hit:
			_log_combat("  → Промах по %s." % target.unit_name)
			continue
		_deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_log_combat("  → %s получает %d урона%s. HP: %d → %d" % [
			target.unit_name, dmg_result.final_damage, crit_text, dmg_result.hp_before, target.current_hp])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			var team = heroes_team if target.is_enemy == false else enemies_team
			_compact_team(team)
	_update_all_visuals()

## Кощей: «Неубиваемый» — +30 брони на 1 ход + метка провокации (весь эффект).
func _trigger_koschei_immortal(unit: Combatant):
	var _ki_duration = _compute_effect_duration(unit, unit, 1, false)
	unit.apply_stat_change("armor", 30)
	unit.active_effects.append({"stat": "armor", "value": 30, "duration": _ki_duration, "effect_id": "koschei_immortal_armor", "source_ability": "Неубиваемый"})
	unit.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": _ki_duration, "effect_id": "provocation_mark", "source_ability": "Неубиваемый"})
	_log_combat("💀 [Кощей] Неубиваемый! +30 брони и метка провокации на %d ход(ов)." % _ki_duration)
	_update_all_visuals()

## Бессмертный: «Мой бой не окончен» — восстановить щит смерти (если утрачен), иначе 20 периодического урона на 2 хода.
func _trigger_immortal_my_battle_not_over(unit: Combatant):
	var shield_used = false
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "immortal_shield_used":
			shield_used = true
			break
	if shield_used:
		var i = 0
		while i < unit.active_effects.size():
			if Combatant._effect_get(unit.active_effects[i], "effect_id", "") == "immortal_shield_used":
				unit.active_effects.remove_at(i)
			else:
				i += 1
		_log_combat("🛡️ [Бессмертный] %s: «Мой бой не окончен» — щит смерти восстановлен!" % unit.unit_name)
	else:
		unit.active_effects.append({"stat": "periodic_damage", "value": 20, "duration": 2, "source_ability": "Мой бой не окончен"})
		_log_combat("🛡️ [Бессмертный] %s: щит ещё цел — получает 20 периодического урона на 2 хода." % unit.unit_name)
	_update_all_visuals()

## Жрец Ра: «Слава солнцу» — отступить на 2 линии, союзники +10 уклонения, урон Пустыни по врагам x2.
func _trigger_ra_sun_glory(unit: Combatant):
	# Отступление на 2 линии назад
	if not unit.is_large:
		_apply_shift_effect(unit, 2, _is_player_hero(unit))
	# +10 уклонения себе и всем живым союзникам на 2 хода
	var team = enemies_team if unit.is_enemy else heroes_team
	for ally in team:
		if ally and ally.current_hp > 0:
			ally.apply_stat_change("evasion", 10)
			ally.active_effects.append({"stat": "evasion", "value": 10, "duration": 2, "effect_id": "ra_sun_glory_evasion", "source_ability": "Слава солнцу"})
	# Урон Пустыни по врагам удваивается, пока благословение активно
	_ra_sun_glory_active = true
	_log_combat("☀️ [Жрец Ра] %s: Слава солнцу! Союзники +10 уклонения, урон Пустыни по врагам удвоен." % unit.unit_name)
	_update_all_visuals()

## Сфинкс: «Облик статуи» — +30 брони и восстановление 20% HP.
func _trigger_sphinx_statue_form(unit: Combatant):
	unit.apply_stat_change("armor", 30)
	unit.active_effects.append({"stat": "armor", "value": 30, "duration": 1, "effect_id": "sphinx_statue_armor", "source_ability": "Облик статуи"})
	var heal = int(unit.max_hp * 0.20)
	if heal > 0:
		var hp_before = unit.current_hp
		unit.apply_stat_change("hp", heal)
		_log_combat("🗿 [Сфинкс] %s: Облик статуи! +30 брони, восстановление %d HP (%d → %d)." % [unit.unit_name, heal, hp_before, unit.current_hp])
	else:
		_log_combat("🗿 [Сфинкс] %s: Облик статуи! +30 брони." % unit.unit_name)
	_update_all_visuals()

## Золотой скоробей: «Зарыться в песок» — +40% уклонения, случайный враг получает 0.4 урона и -15 точности на 1 ход.
func _trigger_scarab_bury_in_sand(unit: Combatant):
	unit.apply_stat_change("evasion", 40)
	unit.active_effects.append({"stat": "evasion", "value": 40, "duration": 1, "effect_id": "scarab_bury_evasion", "source_ability": "Зарыться в песок"})
	var enemy_side = enemies_team if _is_player_hero(unit) else heroes_team
	var live = _get_living_team_members(enemy_side)
	if not live.is_empty():
		var target = live[randi() % live.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(unit, target, 0.4)
		if dmg_result.is_hit:
			target.take_damage(dmg_result.final_damage)
			_log_combat("🪲 [Скоробей] %s: +40%% уклонения. %s получает %d урона из песка. HP: %d → %d" % [
				unit.unit_name, target.unit_name, dmg_result.final_damage, dmg_result.hp_before, target.current_hp])
			if target.current_hp <= 0:
				_log_combat("  → %s повержен!" % target.unit_name)
				_on_unit_killed(target)
				_compact_team(enemy_side)
		else:
			_log_combat("🪲 [Скоробей] %s зарывается: +40%% уклонения. Песок промахнулся по %s." % [unit.unit_name, target.unit_name])
		if target.current_hp > 0:
			target.apply_stat_change("accuracy", -15)
			target.active_effects.append({"stat": "accuracy", "value": -15, "duration": 1, "effect_id": "scarab_sand_blind", "source_ability": "Зарыться в песок"})
			_log_combat("  → %s: -15 точности на 1 ход." % target.unit_name)
	else:
		_log_combat("🪲 [Скоробей] %s зарывается в песок: +40%% уклонения." % unit.unit_name)
	_update_all_visuals()

## Сфинкс: разрешение «Загадки». Меченый (тот, кто ранил/сдвинул сфинкса) получает
## 90% своего макс. HP как чистый урон, а сфинкс исцеляется на 10% своего макс. HP. Метка снимается.
func _resolve_sphinx_riddle(marked: Combatant, sphinx: Combatant, log_lines: Array = []):
	# Снимаем метку «Загадки» с меченого
	var i = 0
	while i < marked.active_effects.size():
		if Combatant._effect_get(marked.active_effects[i], "effect_id", "") == "sphinx_riddle":
			marked.active_effects.remove_at(i)
		else:
			i += 1
	# 90% от макс. HP меченого как чистый урон
	var riddle_dmg = int(marked.max_hp * 0.9)
	var hp_before = marked.current_hp
	marked.take_damage(riddle_dmg)
	var _msg = "  → [Сфинкс] Загадка не разгадана! %s получает %d урона (90%% макс. HP). HP: %d → %d" % [
		marked.unit_name, riddle_dmg, hp_before, marked.current_hp]
	if log_lines.size() > 0:
		log_lines.append(_msg)
	else:
		_log_combat(_msg)
	# Сфинкс исцеляется на 10% своего макс. HP
	if sphinx != null and sphinx.current_hp > 0:
		var heal = int(sphinx.max_hp * 0.10)
		if heal > 0:
			var s_hp_before = sphinx.current_hp
			sphinx.apply_stat_change("hp", heal)
			var _msg2 = "  → [Сфинкс] %s питается разгадкой: +%d HP (%d → %d)." % [sphinx.unit_name, heal, s_hp_before, sphinx.current_hp]
			if log_lines.size() > 0:
				log_lines.append(_msg2)
			else:
				_log_combat(_msg2)
	# Если меченый погиб — корректно обрабатываем смерть
	if marked.current_hp <= 0:
		var _msg3 = "  → %s повержен Загадкой Сфинкса!" % marked.unit_name
		if log_lines.size() > 0:
			log_lines.append(_msg3)
		else:
			_log_combat(_msg3)
		_on_unit_killed(marked, log_lines)
	_update_all_visuals()

## Красный Они: «Пламенный дождь» — 5 огненных ударов по случайным врагам (0.3x урон каждый).
func _trigger_oni_flaming_rain(unit: Combatant):
	var enemy_side = enemies_team if _is_player_hero(unit) else heroes_team
	var mult = unit.active_stance.damage_modifier if unit.active_stance != null else 0.3
	_log_combat("🌧️ [Они] Пламенный дождь! 5 огненных ударов по случайным врагам.")
	for i in range(5):
		if _check_battle_end():
			break
		var live = _get_living_team_members(enemy_side)
		if live.is_empty():
			break
		var target = live[randi() % live.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(unit, target, mult)
		if not dmg_result.is_hit:
			_log_combat("  → Удар #%d: промах по %s." % [i + 1, target.unit_name])
			continue
		target.take_damage(dmg_result.final_damage)
		_log_combat("  → Удар #%d: %s получает %d урона. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, dmg_result.hp_before, target.current_hp])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			_compact_team(enemy_side)
	_update_all_visuals()

## Атакующий титан: «Рождённый для битвы» — следующим ходом 80% урона по позициям 1-2 врагов.
func _trigger_titan_born_to_battle(unit: Combatant):
	var enemy_team = enemies_team if _is_player_hero(unit) else heroes_team
	var targets = []
	for t in enemy_team:
		if t and t.current_hp > 0 and (t.position_index == 0 or t.position_index == 1):
			targets.append(t)
	if targets.is_empty():
		_log_combat("⚔️ [Титан] Рождённый для битвы! Но целей на позициях 1-2 нет.")
		_update_all_visuals()
		return
	_log_combat("⚔️ [Титан] Рождённый для битвы! 80% урона по позициям 1-2.")
	for target in targets:
		if _check_battle_end():
			break
		var dmg_result = CombatCalculator.calculate_fixed_damage(unit, target, 0.8)
		if not dmg_result.is_hit:
			_log_combat("  → Промах по %s." % target.unit_name)
			continue
		target.take_damage(dmg_result.final_damage)
		_log_combat("  → %s получает %d урона. HP: %d → %d" % [
			target.unit_name, dmg_result.final_damage, dmg_result.hp_before, target.current_hp])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			_compact_team(enemy_team)
	_update_all_visuals()

## _has_provocation/_has_innocence/_remove_effect_id перенесены в battle_effects.gd
## (BattleEffects) — см. effects._has_provocation() и т.п.
func _has_effect_id(unit: Combatant, effect_id: String) -> bool:
	if unit == null:
		return false
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == effect_id:
			return true
	return false

func _trigger_thor_fight_me_heal(unit: Combatant) -> String:
	if unit == null or unit.current_hp <= 0:
		return ""
	if not _has_effect_id(unit, "thor_fight_me_heal"):
		return ""
	var heal_amount: int = maxi(1, int(unit.max_hp * 0.07))
	var hp_before: int = unit.current_hp
	unit.apply_stat_change("hp", heal_amount)
	return "[fight_me] %s восстанавливает %d HP при атаке (%d → %d)." % [unit.unit_name, unit.current_hp - hp_before, hp_before, unit.current_hp]

func _should_trigger_thor_hammer_of_lightning(attacker: Combatant, ability: AbilityResource) -> bool:
	if attacker == null or ability == null:
		return false
	if not _has_effect_id(attacker, "thor_hammer_of_lightning"):
		return false
	if ability.ability_marker == "thor_hammer_of_lightning":
		return false
	return ability.target_type == "Enemy" or ability.target_type == "All_Enemies"

func _trigger_thor_hammer_of_lightning(attacker: Combatant, log_lines: Array[String]) -> void:
	var enemy_team: Array = enemies_team if not attacker.is_enemy else heroes_team
	var pure_damage: int = maxi(1, int(attacker.damage * 0.05))
	for enemy in enemy_team.duplicate():
		if enemy == null or enemy.current_hp <= 0:
			continue
		var hp_before: int = enemy.current_hp
		enemy.take_damage(pure_damage)
		log_lines.append("  → [Hammer_of_lightning] %s получает %d чистого урона (%d → %d)." % [enemy.unit_name, pure_damage, hp_before, enemy.current_hp])
		if enemy.current_hp <= 0:
			enemy.killed_by = attacker
			log_lines.append("  → %s повержен!" % enemy.unit_name)
			_on_unit_killed(enemy, log_lines)
			_compact_team(enemy_team)
			continue
		if randf() < 0.10 and not enemy.is_stunned:
			enemy.is_stunned = true
			var _hol_duration = _compute_effect_duration(attacker, enemy, 1, true)
			enemy.active_effects.append({"stat": "stun", "value": 1, "duration": _hol_duration, "source_ability": "Hammer_of_lightning"})
			enemy.check_stance_interruption("stun")
			_notify_stun_applied(enemy)
			log_lines.append("  → [Hammer_of_lightning] %s оглушён." % enemy.unit_name)

func _trigger_storm_marks(attacker: Combatant):
	var mark_count = 0
	for eff in attacker.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "neverending_storm_mark":
			mark_count += 1
	if mark_count == 0:
		return
	var enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
	if enemies.is_empty():
		return
	_log_combat("⛈ Вечная буря Зевса — %d удар(ов) молнией!" % mark_count)
	for i in range(mark_count):
		if _check_battle_end():
			return
		enemies = _get_living_team_members(enemies_team if _is_player_hero(attacker) else heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.6)
		if not dmg_result.is_hit:
			_log_combat("  [Молния %d] → Промах по %s." % [i + 1, target.unit_name])
			continue
		_deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_log_combat("  [Молния %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text, dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_log_combat("  → %s повержен!" % target.unit_name)
			_on_unit_killed(target)
			var team = heroes_team if target.is_enemy == false else enemies_team
			_compact_team(team)
	_update_all_visuals()

# ═══ Система позиционных марок перенесена в battle_marks.gd (класс BattleMarks) ═══
# Логика и состояние марок инкапсулированы в объекте `marks` (см. _ready() и battle_marks.gd).
# Поведение боя не изменено — перенесено 1:1.

func _apply_shift_effect(target: Combatant, distance: int, is_hero: bool):
	var team = heroes_team if is_hero else enemies_team
	var members = _get_living_team_members(team)
	var idx = members.find(target)
	if idx < 0:
		return
	# Леший «Ни шагу» / иммобилизация: цель с эффектом «rooted» не может двигаться
	for _rs_eff in target.active_effects:
		if Combatant._effect_get(_rs_eff, "stat", "") == "rooted":
			_log_combat("🌿 %s опутан корнями и не может двигаться." % target.unit_name)
			return
	
	var new_idx = clampi(idx + distance, 0, members.size() - 1)
	if new_idx == idx:
		return
	
	var unit = members[idx]
	members.remove_at(idx)
	members.insert(new_idx, unit)
	_apply_member_order_to_team(team, members)
	target.check_stance_interruption("move", target.position_index)
	# Посейдон: «Штиль» — при движении противника 70% урона
	for enemy in heroes_team + enemies_team:
		if enemy != null and enemy.current_hp > 0 and enemy != target:
			if enemy.active_stance != null and enemy.active_stance.stance_effect_type == "poseidon_calm":
				var _is_enemy_of_mover = (enemy.is_enemy != target.is_enemy)
				if _is_enemy_of_mover:
					var calm_dmg = CombatCalculator.calculate_fixed_damage(enemy, target, 0.7)
					if calm_dmg.is_hit and calm_dmg.final_damage > 0:
						_deal_damage(target, calm_dmg.final_damage, calm_dmg.is_crit)
						_log_combat("  → [Штиль] %s наносит %d урона за движение %s." % [enemy.unit_name, calm_dmg.final_damage, target.unit_name])
						if target.current_hp <= 0:
							_log_combat("  → %s повержен Штилем!" % target.unit_name)
							_on_unit_killed(target)
							_compact_team(heroes_team if not target.is_enemy else enemies_team)
							_check_battle_end()
						break
	marks.check_on_move(target)
	# Нага воин: пассивка — при перемещении +7 удачи на 2 хода
	if target.special_effect_type == "naga_move_luck":
		target.apply_stat_change("crit", 7)
		target.active_effects.append({"stat": "crit", "value": 7, "duration": 2, "effect_id": "naga_move_luck", "source_ability": "Пассивка Нага"})
		_log_combat("🐍 [Нага] %s получает +7 удачи за перемещение (2 хода)." % target.unit_name)
	# Асура: сброс «Чёрной полосы» meta, если марка истекла (проверка активных марок streak)
	var _asura_has_streak = false
	for _as_m in marks.position_marks:
		if _as_m.get("effect_type", "") == "asura_streak_debuff":
			_asura_has_streak = true
			break
	if not _asura_has_streak and target.has_meta("asura_streak_active"):
		target.remove_meta("asura_streak_active")
	_apply_kappa_auras()
	_sync_visual_positions()
	
	# ═══ Хуки перемещения для юнитов Глубины ═══
	_on_unit_moved(target)
	
	# ═══ Звёзды — Овен: при перемещении получает бафф каждой пройденной клетки (1 ход) ═══
	if target.special_effect_type == "aries_path_buffs" and CombatManager.selected_location_id == "stars":
		for _ar_pos in range(mini(idx, new_idx), maxi(idx, new_idx) + 1):
			locations._apply_star_cell_buff(target, _ar_pos, 1)
		_log_combat("🐏 [Овен] %s получает звёздные баффы пройденных клеток." % target.unit_name)

	# ═══ Локация: Глубина — урон/лечение при смене позиции ═══
	locations._location_depths_on_move(target)

func _get_living_team_members(team: Array) -> Array:
	var members: Array = []
	for u in team:
		if u and u.current_hp > 0 and not members.has(u):
			members.append(u)
	members.sort_custom(func(a, b): return a.position_index < b.position_index)
	return members

func _apply_member_order_to_team(team: Array, members: Array) -> void:
	for i in range(4):
		team[i] = null
	var pos = 0
	for i in range(members.size()):
		if pos >= 4:
			push_warning("_apply_member_order_to_team: некорректное построение — не помещается в 4 позиции, юнит отброшен.")
			break
		var m = members[i]
		m.position_index = pos
		team[pos] = m
		pos += 1
		if m.is_large and pos < 4:
			team[pos] = m  # Большой юнит занимает соседнюю позицию
			pos += 1
	
func _compact_team(team: Array):
	_apply_member_order_to_team(team, _get_living_team_members(team))

## Хуки перемещения для юнитов Глубины (вызывается при любом перемещении юнита).
func _on_unit_moved(target: Combatant):
	if target == null or target.current_hp <= 0:
		return
	target.moved_this_round = true
	# Русал воин: +10 удачи (крит) на 1 ход при собственном перемещении
	if target.special_effect_type == "merwarrior_move_luck":
		target.apply_stat_change("crit", 10)
		target.active_effects.append({"stat": "crit", "value": 10, "duration": 1, "effect_id": "merwarrior_move_luck", "source_ability": "Пассивка Русала"})
	# Тритон: когда враг двигается — -10 брони на 1 ход
	var _tr_team = enemies_team if not target.is_enemy else heroes_team
	for _triton in _tr_team:
		if _triton and _triton.current_hp > 0 and _triton.special_effect_type == "triton_enemy_move_armor":
			target.apply_stat_change("armor", -10)
			target.active_effects.append({"stat": "armor", "value": -10, "duration": 1, "effect_id": "triton_enemy_move_armor", "source_ability": "Пассивка Тритона"})
			break
	# Рассекающий волны: когда враг двигается — наносит ему 15% урона носителя
	for _wc_u in _tr_team:
		if _wc_u and _wc_u.current_hp > 0 and _wc_u.has_item_effect("wave_cleaver_move_punish"):
			var _wc_dmg = int(_wc_u.damage * 0.15)
			if _wc_dmg > 0 and target.current_hp > 0:
				var _wc_hp_before = target.current_hp
				target.take_damage(_wc_dmg)
				_log_combat("🌊 [Рассекающий волны] %s получает %d урона за перемещение. HP: %d → %d" % [target.unit_name, _wc_dmg, _wc_hp_before, target.current_hp])
				if target.current_hp <= 0:
					_log_combat("  → %s повержен!" % target.unit_name)
					target.killed_by = _wc_u
					_on_unit_killed(target)
					var _wc_team = heroes_team if target.is_enemy == false else enemies_team
					_compact_team(_wc_team)
					_apply_kappa_auras()
			break

## Валькирии: распространение баффа на противоположный тип валькирий.
func _propagate_valkyrie_buff(source: Combatant, source_type: String, target_type: String, stat: String, value: int, duration: int, log_lines: Array):
	var team = enemies_team if source.is_enemy else heroes_team
	for v in team:
		if v and v.current_hp > 0 and v != source and v.special_effect_type == target_type:
			v.apply_stat_change(stat, value)
			v.active_effects.append({"stat": stat, "value": value, "duration": duration, "effect_id": "valkyrie_shared_buff", "source_ability": "Пассивка Валькирии"})
			log_lines.append("  → [Пассивка Валькирии] %s получает +%d %s на %d ход." % [v.unit_name, value, stat, duration])

## Пегас: когда союзник получает бафф — +5 атаки навсегда.
## log_lines необязателен — если не передан (или вызов идёт из места без пакетного лога),
## строка сразу уходит в _log_combat.
## _check_pegasus_ally_buff перенесена в battle_effects.gd (см. effects._check_pegasus_ally_buff()).

## Морская ведьма: «Водоворот» — разворот позиций противников (1↔4, 2↔3), считается 4 перемещениями для локации.
func _swap_enemy_positions(caster: Combatant) -> Array[String]:
	var lines: Array[String] = []
	var team = heroes_team if caster.is_enemy else enemies_team
	var members = _get_living_team_members(team)
	if members.size() < 2:
		return lines
	var reversed_members: Array = []
	for i in range(members.size() - 1, -1, -1):
		reversed_members.append(members[i])
	_apply_member_order_to_team(team, reversed_members)
	lines.append("  → [Водоворот] Позиции противников перевёрнуты!")
	for u in reversed_members:
		if u and u.current_hp > 0:
			u.check_stance_interruption("move", u.position_index)
			marks.check_on_move(u)
	_apply_kappa_auras()
	_sync_visual_positions()
	for u in reversed_members:
		if u and u.current_hp > 0:
			_on_unit_moved(u)
			locations._location_depths_on_move(u)
	_update_all_visuals()
	return lines
	_sync_visual_positions()
	
func _refresh_passive_auras_for_all_units() -> void:
	for unit in heroes_team + enemies_team:
		if unit != null:
			unit.refresh_passive_auras()

func _update_all_visuals():
	_refresh_passive_auras_for_all_units()
	# Синхронизируем позиции визуалов с актуальным состоянием команд,
	# чтобы после компоновки (смерть/перемещение) визуалы перемещались вместе с логикой.
	_sync_visual_positions()
	for v in hero_visuals + enemy_visuals:
		if v:
			v.update_visuals()
	_sync_status_bar_positions()
	_update_marks_display()
	# Доступность способностей зависит от текущей позиции/величия — обновляем
	# кнопки активного бога при любом изменении (движение заклинанием и т.п.).
	if waiting_for_player and active_unit != null:
		_refresh_ability_buttons_availability(active_unit)

## Подсветка HP-бара юнита, чей сейчас ход (снимает подсветку с остальных).
func _sync_status_bar_positions() -> void:
	var bar_top: float = _get_bottom_status_top()
	for v in hero_visuals + enemy_visuals:
		if v and v.has_method("set_status_bars_global_top"):
			v.set_status_bars_global_top(bar_top)

func _update_active_highlight():
	for v in hero_visuals + enemy_visuals:
		if v:
			v.set_active(v.data != null and v.data == active_unit)
	# Обновляем полосу очереди ходов (текущий ходящий подсвечивается).
	_update_turn_order_display()

func _sync_visual_positions():
	# Крупный юнит (is_large) присутствует и в team[i], и в team[i+1].
	# Чтобы не сдвигать его визуал дважды (он бы уехал на соседний слот),
	# каждый юнит помещаем один раз — на свой первичный слот.
	var placed_heroes: Dictionary = {}
	var placed_enemies: Dictionary = {}
	for i in range(4):
		if heroes_team[i]:
			var u = heroes_team[i]
			if not placed_heroes.has(u):
				placed_heroes[u] = true
				var vis = _find_visual_for_unit(u, hero_visuals)
				_move_visual_to_slot(vis, "HeroPositions/Pos" + str(i + 1))
				# Герои идут справа налево: центр между этим и следующим слотом = -70px.
				if u.is_large:
					vis.position = Vector2(-70, 0)
		if enemies_team[i]:
			var u = enemies_team[i]
			if not placed_enemies.has(u):
				placed_enemies[u] = true
				var vis = _find_visual_for_unit(u, enemy_visuals)
				_move_visual_to_slot(vis, "EnemyPositions/Pos" + str(i + 1))
				# Враги идут слева направо: центр между этим и следующим слотом = +70px.
				if u.is_large:
					vis.position = Vector2(70, 0)

func _find_visual_for_unit(unit: Combatant, visuals: Array) -> Node2D:
	for v in visuals:
		if v and v.data == unit:
			return v
	return null

## Удаляет визуал (спрайт, полоски) мёртвого юнита со сцены,
## чтобы его арт не оставался на поле и не перекрывал живых юнитов.
func _remove_visual_for_unit(unit: Combatant):
	if unit == null:
		return
	var visuals = enemy_visuals if unit.is_enemy else hero_visuals
	for i in range(visuals.size()):
		var v = visuals[i]
		if v and v.data == unit:
			# Слот освобождаем сразу (игровая логика видит место свободным немедленно),
			# а сам узел лишь плавно растворяется и убирается из сцены чуть позже —
			# чисто визуальный эффект, ни на что механическое не влияет.
			visuals[i] = null
			_fade_out_and_free_visual(v)
			return

## Растворяет спрайт погибшего юнита до полной прозрачности за 1 секунду, затем
## удаляет узел. Вызывается вместо мгновенного queue_free() в _remove_visual_for_unit.
func _fade_out_and_free_visual(visual: Node2D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 1.0)
	tween.tween_callback(visual.queue_free)

## Создаёт визуал юниту, если у него его нет (нужно при воскрешении Жрецом Анубиса).
func _ensure_visual_for_unit(unit: Combatant):
	if unit == null:
		return
	if _find_visual_for_unit(unit, hero_visuals) != null or _find_visual_for_unit(unit, enemy_visuals) != null:
		return
	var visuals = enemy_visuals if unit.is_enemy else hero_visuals
	var prefix = "EnemyPositions/Pos" if unit.is_enemy else "HeroPositions/Pos"
	for i in range(visuals.size()):
		if visuals[i] == null:
			var path = prefix + str(i + 1)
			if has_node(path):
				_create_visual(unit, path, visuals, i)
			return

func _move_visual_to_slot(visual: Node2D, path: String):
	if visual == null or not has_node(path):
		return
	var slot = get_node(path)
	if visual.get_parent() != slot:
		if visual.get_parent():
			visual.get_parent().remove_child(visual)
		slot.add_child(visual)
	visual.position = Vector2.ZERO

## Наносит урон цели и помечает его критическим (для всплывающих чисел), если is_crit.
func _deal_damage(target: Combatant, amount: int, is_crit: bool = false) -> void:
	if is_crit:
		target.pending_crit = true
	target.take_damage(amount)
	# Шива «Карма»: отражение и копирование дебаффов обрабатываются в блоке реакций _use_ability

## Красная вспышка на спрайте юнита, получившего урон.
func _on_unit_damaged(_amount: int, unit: Combatant):
	if unit == null:
		return
	var vis = _find_visual_for_unit(unit, hero_visuals)
	if vis == null:
		vis = _find_visual_for_unit(unit, enemy_visuals)
	if vis != null:
		vis.flash_damage()
	_track_mission_damage_stats(unit, _amount)

## Статистика урона за миссию (см. MissionState.hero_battle_stats), для итогового
## экрана после её завершения. «Получено» — считаем прямо на пострадавшем боге.
## «Нанесено» — приписываем текущему активному юниту хода, если это бог, а урон
## получил враг (эвристика: не проходит per-source атрибуцию через все точки
## take_damage(), но верно покрывает подавляющее большинство реального урона —
## прямые попадания способностей/ульт/заклинаний — и не путает урон себе/от эффектов).
func _track_mission_damage_stats(unit: Combatant, amount: int) -> void:
	if not CombatManager.is_mission_battle or unit == null or amount <= 0:
		return
	if not unit.is_enemy and unit.source_resource_path != "":
		MissionState.add_hero_damage_taken(unit.source_resource_path, amount)
	elif unit.is_enemy and active_unit != null and not active_unit.is_enemy and active_unit.source_resource_path != "":
		MissionState.add_hero_damage_dealt(active_unit.source_resource_path, amount)

## Учёт исцеления за миссию (см. MissionState.hero_battle_stats) — только для героев,
## считаем прямо на исцелённом боге (кто вылечил — не различаем, как и с уроном выше).
func _on_unit_healed(amount: int, unit: Combatant) -> void:
	if not CombatManager.is_mission_battle or unit == null or amount <= 0:
		return
	if not unit.is_enemy and unit.source_resource_path != "":
		MissionState.add_hero_damage_healed(unit.source_resource_path, amount)

## Подстраховка на случай, если какой-то конкретный источник урона забудет вручную
## вызвать _on_unit_killed()/_compact_team()/_check_battle_end() (см. Combatant.died,
## эмитится один раз при первом падении HP до 0). Намеренно НЕ вызывает
## _compact_team()/_check_battle_end() отсюда — died эмитится синхронно изнутри
## take_damage(), а вызывающий код по всему файлу часто ещё держит в работе
## индексы/итераторы по heroes_team/enemies_team, которые компоновка команды
## могла бы сломать. _on_unit_killed() же безопасен: он не меняет сами массивы
## команд, только очередь ходов, визуал и «кладбище» — и теперь идемпотентен.
func _on_unit_died(unit: Combatant) -> void:
	_on_unit_killed(unit)

func _on_phoenix_shield_triggered(unit: Combatant) -> void:
	_log_combat("🔥 [Перо феникса] %s: гибель предотвращена, здоровье полностью восстановлено!" % unit.unit_name)
	_update_all_visuals()

func _show_miss_popup(unit: Combatant) -> void:
	if unit == null:
		return
	var vis = _find_visual_for_unit(unit, hero_visuals)
	if vis == null:
		vis = _find_visual_for_unit(unit, enemy_visuals)
	if vis != null and vis.has_method("show_floating_number"):
		vis.show_floating_number(0, "miss")


func show_unit_stats(unit: Combatant):
	_log_combat("─── %s ───" % unit.unit_name)
	_log_combat(unit.get_status_report())
	
func spawn_unit(unit: Combatant, sprite_path: String, spawn_pos: Vector2, _is_hero: bool, _index: int):
	var display = UNIT_DISPLAY.instantiate()
	add_child(display)
	display.position = spawn_pos
	display.setup(unit, sprite_path)
	display.unit_clicked.connect(show_unit_stats)

# ══════════════════════════════════════════════
#  ЭФФЕКТЫ СПОСОБНОСТЕЙ НА ЦЕЛЯХ
# ══════════════════════════════════════════════


## Централизованный расчёт итоговой длительности НОВОГО баффа/дебаффа с учётом пассивок,
## которые её продлевают. Единственная точка входа для этой логики — использовать её
## везде, где создаётся эффект с ограниченной длительностью, вместо копирования проверок
## по месту в каждой способности.
## base_duration <= 0 (например -1 = навсегда/до конца боя) возвращается как есть —
## такие эффекты пассивками продления не трогаются.
## is_debuff: true — «Кикимора»/«Самди» (дебаффы), false — «Один»/«Нага монах» (баффы).
func _compute_effect_duration(attacker: Combatant, target: Combatant, base_duration: int, is_debuff: bool) -> int:
	if attacker == null or target == null or base_duration <= 0:
		return base_duration
	var duration := base_duration
	if not is_debuff:
		# Один + Нага монах: неуникальные баффы союзников (по стороне ЦЕЛИ) длятся на 1 ход дольше.
		var target_team = heroes_team if not target.is_enemy else enemies_team
		if effects._has_special_on_team(target_team, "odin_buff_duration"):
			duration += 1
		if effects._has_special_on_team(target_team, "naga_monk_buff_duration"):
			duration += 1
		# Мысль и память: баффы на самого Одина длятся ещё на 1 ход дольше (сверх общей пассивки).
		if attacker == target and target.has_item_effect("odin_self_buff_extend"):
			duration += 1
	else:
		var caster_team = enemies_team if attacker.is_enemy else heroes_team
		# Кикимора: дебафф её команды НА БОГА (не на своих союзников) — +1 ход.
		if not target.is_enemy and effects._has_special_on_team(caster_team, "kikimora_extended_debuffs"):
			duration += 1
		# Самди: дебафф его команды НА ВРАГА (не на своих союзников) — 50% шанс +1 ход.
		if target.is_enemy != attacker.is_enemy and effects._has_special_on_team(caster_team, "samdi_extend_debuffs") and randf() < 0.5:
			duration += 1
		# ═══ Шляпа Самди: когда противник Самди получает дебафф, наносит ему 15% урона Самди ═══
		if target.current_hp > 0:
			var _samdi_hat_team = enemies_team if target.is_enemy else heroes_team
			for _samdi_u in _samdi_hat_team:
				if _samdi_u and _samdi_u.current_hp > 0 and _samdi_u.is_enemy != target.is_enemy and _samdi_u.has_item_effect("samdi_hat_debuff_punish"):
					var _sh_dmg = int(_samdi_u.damage * 0.15)
					if _sh_dmg > 0:
						var _sh_hp_before = target.current_hp
						target.take_damage(_sh_dmg)
						_log_combat("🎩 [Шляпа Самди] %s получает %d урона за дебафф. HP: %d → %d" % [target.unit_name, _sh_dmg, _sh_hp_before, target.current_hp])
					break
			# ═══ Цветок кикиморы: владелец восстанавливает 3% HP каждый раз, получая дебафф ═══
			if target.current_hp > 0 and target.has_item_effect("kikimora_flower_heal_on_debuff"):
				var _kf_heal = int(target.max_hp * 0.03)
				if _kf_heal > 0:
					var _kf_hp_before = target.current_hp
					target.apply_stat_change("hp", _kf_heal)
					_log_combat("🌸 [Цветок кикиморы] %s восстанавливает %d HP от дебаффа. HP: %d → %d" % [target.unit_name, _kf_heal, _kf_hp_before, target.current_hp])
	return duration

## _apply_effect_to_target() и _extract_stat_name() перенесены в battle_effects.gd
## (см. effects._apply_effect_to_target()).

# ══════════════════════════════════════════════
#  ПАССИВНЫЕ СПОСОБНОСТИ ПЕРСОНАЖЕЙ
# ══════════════════════════════════════════════

## Посейдон: лечение 5% HP за каждый уникальный положительный бафф в начале хода
func _trigger_poseidon_heal(unit: Combatant):
	var unique_buffs = {}
	for effect in unit.active_effects:
		var val = Combatant._effect_get(effect, "value", 0)
		if val <= 0:
			continue
		var key = Combatant._effect_get(effect, "source_ability", "")
		if key == "":
			key = Combatant._effect_get(effect, "effect_id", "")
		if key != "":
			unique_buffs[key] = true
	var buff_count = unique_buffs.size()
	if buff_count == 0:
		return
	var heal_amount = int(unit.max_hp * 0.05 * buff_count)
	var hp_before = unit.current_hp
	unit.apply_stat_change("hp", heal_amount)
	_log_combat("🔱 [Посейдон] %s лечится за %d уникальных баффов: +%d HP (%d → %d)" % [
		unit.unit_name, buff_count, heal_amount, hp_before, unit.current_hp
	])

## Вызывается при смерти юнита. Обрабатывает пассивки, зависящие от убийства.
func _on_unit_killed(victim: Combatant, log_lines: Array = []):
	# Идемпотентность: обычный код и подстраховка через сигнал died могут оба
	# попытаться обработать одну и ту же смерть — разово-смертные пассивки
	# (Банши, проклятие Принцессы и т.п.) не должны сработать дважды.
	if victim.death_processed:
		return
	victim.death_processed = true
	# Замок: трекинг смертей в этом раунде (Рыцарь «Отважный удар»)
	if victim.is_enemy:
		_enemies_died_this_round = true
	else:
		_heroes_died_this_round = true

	# Замок: отметить убийцу (Стражник, Принцесса)
	if victim.killed_by != null and victim.killed_by.current_hp > 0:
		if victim.is_enemy:
			victim.killed_by.has_killed_hero = true
		else:
			victim.killed_by.has_killed_enemy = true

	# ═══ Замок — Принцесса: предсмертное проклятие убийцы ═══
	if victim.special_effect_type == "princess_death_curse" and victim.killed_by != null and victim.killed_by.current_hp > 0:
		var _killer = victim.killed_by
		var _armor_loss = maxi(1, int(_killer.armor * 0.15))
		_killer.apply_stat_change("armor", -_armor_loss)
		_killer.active_effects.append({"stat": "armor", "value": -_armor_loss, "duration": -1, "effect_id": "princess_death_curse", "source_ability": "Предсмертное проклятие"})
		# Метка провокации до конца боя
		var _has_mark = false
		for _pe in _killer.active_effects:
			if Combatant._effect_get(_pe, "effect_id", "") == "princess_provocation":
				_has_mark = true
				break
		if not _has_mark:
			_killer.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": -1, "effect_id": "princess_provocation", "source_ability": "Предсмертное проклятие", "dispellable": false})
		var _pmsg = "  → [Принцесса] Предсмертное проклятие! %s теряет %d брони навсегда и получает метку провокации." % [_killer.unit_name, _armor_loss]
		if log_lines.size() > 0:
			log_lines.append(_pmsg)
		else:
			_log_combat(_pmsg)

	# Очистка локации Топь
	if victim == _swamp_tracked_unit:
		_swamp_tracked_unit = null
	if victim == _swamp_grace_unit:
		_swamp_grace_unit = null
		_swamp_grace_turns_left = 0
	
	# Записываем погибшего в «кладбище» его команды (для воскрешения Жрецом Анубиса)
	if victim.is_enemy:
		if not _enemy_graveyard.has(victim):
			_enemy_graveyard.append(victim)
	else:
		if not _hero_graveyard.has(victim):
			_hero_graveyard.append(victim)

	# Банши: при смерти все герои получают +20 к урону на 1 ход
	if victim.is_enemy and victim.special_effect_type == "banshee_death_debuff":
		for hero in heroes_team:
			if hero and hero.current_hp > 0:
				hero.apply_stat_change("damage", 20)
				hero.active_effects.append({
					"stat": "damage", "value": 20, "duration": 1,
					"effect_id": "banshee_death", "source_ability": "Банши"
				})
		var banshee_msg = "  → [Банши] Предсмертный визг! Все герои получают +20 к урону на 1 ход."
		if log_lines.size() > 0:
			log_lines.append(banshee_msg)
		else:
			_log_combat(banshee_msg)
	
	var opposing_team = heroes_team if victim.is_enemy else enemies_team
	for ally in opposing_team:
		if ally and ally.current_hp > 0 and ally.special_effect_type == "set_kill_majesty":
			ally.modify_majesty(20)
			var msg = "  → [Сет] %s получает 20 величия за убийство противника." % ally.unit_name
			if log_lines.size() > 0:
				log_lines.append(msg)
			else:
				_log_combat(msg)
		# Аид: +6 очков фантазии за смерть противника
		if ally and ally.current_hp > 0 and ally.special_effect_type == "hades_kill_fantasy":
			# Шлем Аида: удваивает эффект пассивки, если противника убил сам Аид.
			var _hades_gain = 6
			if victim.killed_by == ally and ally.has_item_effect("hades_helm_self_kill_double"):
				_hades_gain = 12
			current_fantasy = mini(max_fantasy, current_fantasy + _hades_gain)
			var msg2 = "  → [Аид] %s восстанавливает %d фантазии за смерть врага (итого: %d)." % [ally.unit_name, _hades_gain, current_fantasy]
			if log_lines.size() > 0:
				log_lines.append(msg2)
			else:
				_log_combat(msg2)
			_update_spell_ui()
	
	# ═══ Лернейский лев: при смерти союзника — полностью восстановить HP ═══
	var victim_team = enemies_team if victim.is_enemy else heroes_team
	for ally in victim_team:
		if ally and ally.current_hp > 0 and ally != victim and ally.special_effect_type == "lion_ally_death_heal":
			var _hp_before_lion = ally.current_hp
			ally.apply_stat_change("hp", ally.max_hp)
			var _msg_lion = "  → [Лев] Союзник пал! %s полностью восстанавливает HP (%d → %d)." % [ally.unit_name, _hp_before_lion, ally.current_hp]
			if log_lines.size() > 0:
				log_lines.append(_msg_lion)
			else:
				_log_combat(_msg_lion)

	# ═══ Золотой скоробей: при смерти исцелить остальных союзников на 15% HP ═══
	if victim.special_effect_type == "scarab_death_heal_allies":
		for ally in victim_team:
			if ally and ally.current_hp > 0 and ally != victim:
				var _heal = int(ally.max_hp * 0.15)
				if _heal > 0:
					var _hp_b = ally.current_hp
					ally.apply_stat_change("hp", _heal)
					var _msg = "  → [Скоробей] %s: последняя удача! %s исцеляется на %d HP (%d → %d)." % [victim.unit_name, ally.unit_name, _heal, _hp_b, ally.current_hp]
					if log_lines.size() > 0:
						log_lines.append(_msg)
					else:
						_log_combat(_msg)

	# ═══ Краб-коллектор: при смерти копирует свои баффы всем союзникам ═══
	if victim.special_effect_type == "crab_collector_death_copy":
		var _victim_buffs: Array = []
		for e in victim.active_effects:
			var _bstat = Combatant._effect_get(e, "stat", "")
			var _bval = Combatant._effect_get(e, "value", 0)
			if _bval > 0 and _bstat != "stun" and _bstat != "periodic_damage":
				_victim_buffs.append(e.duplicate())
		for ally in victim_team:
			if ally and ally.current_hp > 0 and ally != victim:
				for be in _victim_buffs:
					var _bstat2 = Combatant._effect_get(be, "stat", "")
					var _bval2 = Combatant._effect_get(be, "value", 0)
					ally.apply_stat_change(_bstat2, _bval2)
					var _copy = be.duplicate()
					_copy["source_ability"] = "crab_collector_death_copy"
					ally.active_effects.append(_copy)
				var _cmsg = "  → [Краб коллектор] %s передаёт свои баффы %s (%d эффект(ов))." % [victim.unit_name, ally.unit_name, _victim_buffs.size()]
				if log_lines.size() > 0:
					log_lines.append(_cmsg)
				else:
					_log_combat(_cmsg)
		_update_all_visuals()

	# ═══ Жрец Анубиса: при смерти воскрешает мёртвого союзника с полным HP ═══
	if victim.special_effect_type == "anubis_resurrect":
		var graveyard = _enemy_graveyard if victim.is_enemy else _hero_graveyard
		var revived: Combatant = null
		for dead_ally in graveyard:
			if dead_ally != victim:
				revived = dead_ally
				break
		if revived != null:
			revived.current_hp = revived.max_hp
			revived.active_effects.clear()
			revived.is_stunned = false
			revived.death_processed = false
			graveyard.erase(revived)
			# Сначала компактируем команду: мёртвая жертва покинет свой слот,
			# освободив место для воскрешённого (исключает коллизию позиций).
			_compact_team(victim_team)
			# Помещаем воскрешённого в первый свободный слот
			if not victim_team.has(revived):
				for slot in range(victim_team.size()):
					if victim_team[slot] == null:
						revived.position_index = slot
						victim_team[slot] = revived
						break
			var _msg = "  → [Жрец Анубиса] %s приносит себя в жертву: %s воскрешён с полным HP (%d)!" % [victim.unit_name, revived.unit_name, revived.current_hp]
			if log_lines.size() > 0:
				log_lines.append(_msg)
			else:
				_log_combat(_msg)
			_ensure_visual_for_unit(revived)
			_update_all_visuals()
	# Арт погибшего убирается со сцены, чтобы он не перекрывал живых юнитов.
	_remove_visual_for_unit(victim)
	# Убираем погибшего из очереди ходов и обновляем полосу.
	turn_order.erase(victim)
	_update_turn_order_display()

## Проверяет, есть ли живой юнит с указанной пассивкой в команде
## _has_special_on_team перенесена в battle_effects.gd (см. effects._has_special_on_team()).

func _check_battle_end() -> bool:
	var heroes_alive = false
	var enemies_alive = false
	
	for h in heroes_team:
		if h and h.current_hp > 0:
			heroes_alive = true
			break
			
	for e in enemies_team:
		if e and e.current_hp > 0:
			enemies_alive = true
			break
			
	if not heroes_alive:
		battle_running = false
		waiting_for_player = false
		active_unit = null
		_update_active_highlight()
		if CombatManager.is_mission_battle:
			_set_status("Поражение! Миссия провалена. Возврат в главное меню...")
		else:
			_set_status("Поражение! Все герои мертвы. Возврат в главное меню...")
		_log_combat("Поражение: все герои мертвы.")
		_end_battle(false)
		return true

	if not enemies_alive:
		battle_running = false
		waiting_for_player = false
		active_unit = null
		_update_active_highlight()
		if CombatManager.is_mission_battle:
			_set_status("Победа! Все враги повержены. Переход к следующей сцене миссии...")
		else:
			_set_status("Победа! Все враги повержены. Возврат в главное меню...")
		_log_combat("Победа: все враги повержены.")
		_end_battle(true)
		return true
		
	return false

## Завершает бой: короткая пауза (чтобы игрок увидел результат) и возврат в главное меню.
## Предохранитель _battle_ending гарантирует, что переход запланирован ровно один раз.
func _end_battle(victory: bool = false) -> void:
	if _battle_ending:
		return
	_battle_ending = true
	_sync_campaign_hero_health()
	_sync_mission_hero_majesty()
	if victory:
		_mark_defeated_nemeses()
	# Забвение: боги, погибшие в бою миссии, получают +2.5 усталости.
	if CombatManager.is_mission_battle:
		_apply_death_fading()
	var t = create_tween()
	t.tween_interval(2.5)
	if CombatManager.is_mission_battle:
		if victory:
			t.tween_callback(_return_to_mission_after_battle)
		else:
			t.tween_callback(_return_to_mission_after_defeat)
	else:
		t.tween_callback(func():
			CombatManager.is_mission_battle = false
			get_tree().change_scene_to_file("res://main_menu.tscn")
		)

func _sync_campaign_hero_health() -> void:
	for i in range(heroes_team.size()):
		if i >= CombatManager.selected_heroes.size():
			continue
		var hero_path: String = str(CombatManager.selected_heroes[i])
		if hero_path.strip_edges() == "":
			continue
		var hero: Combatant = heroes_team[i] as Combatant
		if hero == null:
			continue
		CampaignState.set_god_current_hp(hero_path, hero.current_hp, hero.max_hp)

func _sync_mission_hero_majesty() -> void:
	if not CombatManager.is_mission_battle:
		return
	for i in range(heroes_team.size()):
		if i >= CombatManager.selected_heroes.size():
			continue
		var hero_path: String = str(CombatManager.selected_heroes[i]).strip_edges()
		if hero_path == "":
			continue
		var hero: Combatant = heroes_team[i] as Combatant
		if hero == null:
			continue
		MissionState.set_hero_majesty(hero_path, hero.current_majesty)

## Отмечает побеждённым любого немезида (CharacterResource.is_nemesis), который был
## в команде врагов этого выигранного боя.
func _mark_defeated_nemeses() -> void:
	for enemy_value in enemies_team:
		var enemy: Combatant = enemy_value as Combatant
		if enemy != null and enemy.is_nemesis and enemy.source_resource_path != "":
			CampaignState.mark_nemesis_defeated(enemy.source_resource_path)

func _return_to_mission_after_battle() -> void:
	CombatManager.is_mission_battle = false
	if MissionState.advance_after_battle():
		SceneTransition.change_scene_with_fade("res://Missions/mission_scene.tscn")
		return
	# Бой был последним действием миссии — экран победы/наград/статистики покажет
	# сама mission_scene.gd (см. MissionState.pending_mission_end_kind), она же и
	# завершит миссию (CampaignState.complete_mission и т.д.) в _finish_mission().
	MissionState.pending_mission_end_kind = MissionState.MissionEndKind.VICTORY
	SceneTransition.change_scene_with_fade("res://Missions/mission_scene.tscn")

## Поражение в бою миссии: дальше сцены миссии не идут, независимо от того, был ли
## у боя next_scene_after_battle — экран поражения/наград/статистики покажет
## mission_scene.gd (см. MissionState.pending_mission_end_kind).
func _return_to_mission_after_defeat() -> void:
	CombatManager.is_mission_battle = false
	MissionState.next_scene_after_battle = null
	MissionState.pending_mission_end_kind = MissionState.MissionEndKind.DEFEAT
	SceneTransition.change_scene_with_fade("res://Missions/mission_scene.tscn")

## Начисляет ровно 2 полных уровня забвения каждому богу, погибшему в текущем
## бою миссии. Если это не привело к окончательной смерти (5.0 забвения) —
## бог полностью восстанавливает здоровье и остаётся доступен для следующих
## боёв этой же миссии. Если добил до предела — окончательно погиб, недоступен
## до конца миссии (как и раньше).
func _apply_death_fading() -> void:
	for i in range(heroes_team.size()):
		var hero = heroes_team[i]
		if hero == null or hero.current_hp > 0:
			continue
		if i >= CombatManager.selected_heroes.size():
			continue
		var hero_path = CombatManager.selected_heroes[i]
		if hero_path.strip_edges() == "":
			continue
		var res = load(hero_path) as CharacterResource
		if res == null or res.is_dead:
			continue
		res.add_forgetting(2.0)
		if res.is_dead:
			if not CombatManager.mission_dead_heroes.has(hero_path):
				CombatManager.mission_dead_heroes.append(hero_path)
		else:
			CampaignState.set_god_current_hp(hero_path, CampaignState.get_god_max_hp(hero_path))
		var err = ResourceSaver.save(res, hero_path)
		if err != OK:
			print("[Смерть] Ошибка сохранения %s: %s" % [hero_path, err])
		else:
			print("[Смерть] %s → забвение %.1f%s" % [
				res.unit_name, res.forgetting_level,
				" (МЁРТВ)" if res.is_dead else ""
			])

## _dispel_effects/_dispel_stat_debuffs перенесены в battle_effects.gd
## (см. effects._dispel_effects()/effects._dispel_stat_debuffs()).

## Считает количество уникальных дебаффов на юните (для «На дно» Сирены).
func _count_debuffs_on_unit(unit: Combatant) -> int:
	var debuff_sources = {}
	for eff in unit.active_effects:
		var val = Combatant._effect_get(eff, "value", 0)
		if val < 0:
			var src = Combatant._effect_get(eff, "source_ability", "")
			var eid = Combatant._effect_get(eff, "effect_id", "")
			var key = src if src != "" else eid
			if key != "":
				debuff_sources[key] = true
			else:
				debuff_sources[Combatant._effect_get(eff, "stat", "")] = true
	return debuff_sources.size()

## Считает количество уникальных баффов на юните.
func _count_buffs_on_unit(unit: Combatant) -> int:
	var buff_sources = {}
	for eff in unit.active_effects:
		var val = Combatant._effect_get(eff, "value", 0)
		if val > 0:
			var src = Combatant._effect_get(eff, "source_ability", "")
			var eid = Combatant._effect_get(eff, "effect_id", "")
			var key = src if src != "" else eid
			if key != "":
				buff_sources[key] = true
			else:
				buff_sources[Combatant._effect_get(eff, "stat", "")] = true
	return buff_sources.size()

## Проверяет, есть ли на юните эффект неуязвимости.
func _is_unit_invulnerable(unit: Combatant) -> bool:
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "stat", "") == "invulnerable":
			return true
	return false

## _steal_buffs_from_to перенесена в battle_effects.gd (см. effects._steal_buffs_from_to()).

## Медуза: при оглушении любого юнита — лечится на 15% HP.
func _notify_stun_applied(stunned_unit: Combatant):
	for team in [heroes_team, enemies_team]:
		for unit in team:
			if unit and unit.current_hp > 0 and unit.special_effect_type == "medusa_stun_heal":
				var heal_amount = int(unit.max_hp * 0.15)
				if heal_amount > 0:
					var hp_before = unit.current_hp
					unit.apply_stat_change("hp", heal_amount)
					_log_combat("🐍 [Медуза] %s поглощает чьё-то оцепенение: +%d HP (%d → %d)." % [
						unit.unit_name, heal_amount, hp_before, unit.current_hp])

## Лавовый кабан: текущий процент отскока урона (10% база + 5% за каждый стак горячего сердца).
func _lava_boar_thorns_percent(unit: Combatant) -> int:
	var stacks = 0
	for e in unit.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "lava_boar_warm_heart_stack":
			stacks += 1
	return 10 + stacks * 5

# ══════════════════════════════════════════════
#  UI: НАВЕДЕНИЕ НА ЮНИТОВ И ТУЛТИПЫ СПОСОБНОСТЕЙ
# ══════════════════════════════════════════════

## Иконка открытой двери локации для верхнего правого угла экрана боя.
const LOCATION_DOOR_ICON_OPEN := {
	"helheim": "res://Doors/Helheim_door_open.png",
	"hell": "res://Doors/Hell_door_Open (1).png",
	"tunnels": "res://Doors/tunnels_door_open.png",
	"clouds": "res://Doors/Clouds_door_open.png",
	"stars": "res://Doors/Starts_door_open.png",
	"mountains": "res://Doors/Peaks_door_open.png",
	"arena": "res://Doors/Arena_door_open.png",
	"castle": "res://Doors/Castle_door_open.png",
	"desert": "res://Doors/Desert_door_open.png",
	"depths": "res://Doors/Depth_door_open.png",
	"island": "res://Doors/Islands_door_open.png",
	"ships": "res://Doors/Ships_door_open.png",
	"jungle": "res://Doors/Jungle_door_open.png",
	"garden": "res://Doors/Garden_door_open.png",
	"swamp": "res://Doors/Marsh_door_open.png",
}

## Текст уникальных правил локации — показывается во всплывающей подсказке
## над иконкой двери (верхний правый угол).
const LOCATION_RULE_TEXT := {
	"helheim": "30% шанс туманного раунда (60%, пока жив Йотун): у всех героев -20 к урону (атаке) на 1 ход.",
	"hell": "Каждый раунд все боги теряют 5 величия, игрок теряет 5 фантазии.",
	"tunnels": "Юнит с бронёй выше 50 получает регенерацию 7% HP на 1 ход.",
	"clouds": "Враг (не бог), получивший урон и оставшийся в живых, получает +10 уклонения на 1 ход (стакается; у Купидона — +20).",
	"stars": "Враги на позициях 1-4 получают фиксированные бонусы клетки: +10 брони / регенерация 10% / +10% удачи / +10 урона.",
	"mountains": "Уникальных боевых правил нет — только флейвор-текст в начале боя.",
	"arena": "Урон от способностей увеличен на 20% (не действует на периодический урон).",
	"castle": "Заклинания стоят x1.5 фантазии; всего до 2 заклинаний за раунд на всю команду.",
	"desert": "В начале раунда все юниты получают 5 чистого урона, но не ниже 1 HP (герои — до 10 при «Славе солнцу»). Жрец Ра защищает своих союзников от этого урона.",
	"depths": "Смена позиции наносит 20 чистого урона в нечётные раунды («Бурные потоки») или лечит на 10% HP в чётные («Спокойные воды»).",
	"island": "Каждый раунд инициатива героев снижается на 1 (до 0).",
	"ships": "Героям доступно уникальное заклинание «Ром».",
	"jungle": "Критический удар наносит x3 урона вместо обычного x2.",
	"garden": "Если бог (герой) получает дебафф — он получает ещё 15 чистого урона.",
	"swamp": "Бог на первой позиции копит дебафф (-1 инициатива, -5 брони и -5 уклонения за ход, суммируется, пока стоит). Утопленница «Вниз» может продлить дебафф на 1 ход после ухода с позиции — стек сохранится, если бог вернётся.",
}

## Создаёт иконку двери текущей локации (верхний правый угол) с подсказкой её правил при наведении.
func _setup_location_door_icon():
	var loc_id: String = CombatManager.selected_location_id
	var icon_path: String = str(LOCATION_DOOR_ICON_OPEN.get(loc_id, ""))
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return
	var rule_text: String = str(LOCATION_RULE_TEXT.get(loc_id, ""))
	var btn := Button.new()
	btn.name = "LocationDoorIcon"
	btn.set_script(load("res://location_rule_tooltip_button.gd"))
	btn.flat = true
	btn.icon = load(icon_path) as Texture2D
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var icon_size := Vector2(76, 76)
	btn.custom_minimum_size = icon_size
	btn.size = icon_size
	btn.position = Vector2(1280 - icon_size.x - 8, 4)
	btn.z_index = 200
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_HELP
	$BattleUI.add_child(btn)
	if rule_text != "":
		btn.set("rule_text", rule_text)

## Создаёт панель информации о юните (показывается при наведении)
func _setup_hover_info_panel():
	# Статус-строка — чисто показательный элемент: не должна перехватывать клики
	# по юнитам (иначе её полоса 16..700 x 268..300 перекрывает Area2D передних врагов).
	if status_label:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# === Панель наведения на юнитов ===
	_hover_info_panel = PanelContainer.new()
	_position_hover_info_panel()
	_hover_info_panel.z_index = 100
	# Панель и текст НЕ перехватывают клики (mouse_filter IGNORE).
	# Иначе панель 440..1200 x 16..320 перекрывает передний ряд врагов (Йотун в Pos1
	# стоит в ~640,300) и блокирует Area2D — клик «то проходит, то нет».
	_hover_info_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_hover_content = HBoxContainer.new()
	_hover_content.add_theme_constant_override("separation", 10)
	_hover_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_hover_info_panel.add_child(_hover_content)
	_hover_label = RichTextLabel.new()
	_hover_label.bbcode_enabled = true
	_hover_label.hint_underlined = false
	_hover_label.scroll_following = false
	_hover_label.fit_content = true
	_hover_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_hover_content.add_child(_hover_label)
	_hover_ability_grid = GridContainer.new()
	_hover_ability_grid.columns = 3
	_hover_ability_grid.add_theme_constant_override("h_separation", int(ABILITY_BUTTON_GAP))
	_hover_ability_grid.add_theme_constant_override("v_separation", int(ABILITY_BUTTON_GAP))
	_hover_ability_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_hover_content.add_child(_hover_ability_grid)
	$BattleUI.add_child(_hover_info_panel)
	_hover_info_panel.hide()

## Обработчик наведения на юнита
func _position_hover_info_panel() -> void:
	if _hover_info_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var left_block_width := ABILITY_ICON_BUTTON_SIZE.x * 5.0 + ABILITY_BUTTON_GAP * 4.0
	if _ability_actions_row != null:
		left_block_width = maxf(left_block_width, _ability_actions_row.size.x)
	var panel_left := 16.0 + left_block_width + 16.0
	var panel_top := _get_bottom_controls_top()
	var panel_right := viewport_size.x - 16.0
	if _spell_panel != null:
		panel_right = minf(panel_right, _spell_panel.offset_left - 16.0)
	if panel_right - panel_left < 360.0:
		panel_right = minf(viewport_size.x - 16.0, panel_left + 560.0)
	var panel_bottom := viewport_size.y - 16.0
	_hover_info_panel.offset_left = panel_left
	_hover_info_panel.offset_top = panel_top
	_hover_info_panel.offset_right = panel_right
	_hover_info_panel.offset_bottom = panel_bottom
	_hover_info_panel.custom_minimum_size = Vector2(panel_right - panel_left, panel_bottom - panel_top)
	_hover_info_panel.size = _hover_info_panel.custom_minimum_size
	var content_width := panel_right - panel_left - 16.0
	var content_height := panel_bottom - panel_top - 12.0
	var ability_grid_width := HOVER_ABILITY_BUTTON_SIZE.x * 3.0 + ABILITY_BUTTON_GAP * 2.0
	if _hover_content != null:
		_hover_content.custom_minimum_size = Vector2(content_width, content_height)
		_hover_content.size = _hover_content.custom_minimum_size
	if _hover_label != null:
		_hover_label.custom_minimum_size = Vector2(maxf(260.0, content_width - ability_grid_width - 10.0), content_height)
		_hover_label.size = _hover_label.custom_minimum_size
	if _hover_ability_grid != null:
		_hover_ability_grid.custom_minimum_size = Vector2(ability_grid_width, content_height)
		_hover_ability_grid.size = _hover_ability_grid.custom_minimum_size

func _show_unit_info_panel(unit: Combatant) -> void:
	if _hover_info_panel == null or _hover_label == null or unit == null:
		return
	_position_hover_info_panel()
	_hover_label.text = _get_unit_hover_text(unit)
	_rebuild_hover_ability_buttons(unit)
	_hover_info_panel.show()

func _apply_hover_ability_button_style(button: Button) -> void:
	button.custom_minimum_size = HOVER_ABILITY_BUTTON_SIZE
	button.size = HOVER_ABILITY_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true

func _rebuild_hover_ability_buttons(unit: Combatant) -> void:
	if _hover_ability_grid == null:
		return
	for child in _hover_ability_grid.get_children():
		child.queue_free()
	var abilities: Array[AbilityResource] = []
	for ability in unit.active_abilities:
		if ability != null:
			abilities.append(ability)
	if unit.ultimate_ability != null and not abilities.has(unit.ultimate_ability):
		abilities.append(unit.ultimate_ability)
	_hover_ability_grid.visible = not abilities.is_empty()
	for i in range(abilities.size()):
		var ability := abilities[i]
		var btn: Button = STAT_ICON_TOOLTIP_BUTTON_SCRIPT.new()
		_apply_hover_ability_button_style(btn)
		_set_ability_button_content(btn, ability)
		if unit.is_enemy and i < ENEMY_ABILITY_ICON_PATHS.size():
			var enemy_icon_path := str(ENEMY_ABILITY_ICON_PATHS[i])
			if ResourceLoader.exists(enemy_icon_path):
				btn.icon = load(enemy_icon_path) as Texture2D
				btn.text = ""
		btn.tooltip_text = _get_ability_tooltip(ability, unit)
		btn.rich_tooltip_text = btn.tooltip_text
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_hover_ability_grid.add_child(btn)

func _clear_pinned_unit_info() -> void:
	_pinned_hover_unit = null
	if _hover_info_panel != null:
		_hover_info_panel.hide()

## Обработчик наведения на юнит
func _on_unit_hovered(unit: Combatant):
	if _pinned_hover_unit != null:
		return
	_show_unit_info_panel(unit)

## Обработчик ухода курсора с юнита
func _on_unit_unhovered():
	if _hover_info_panel and _pinned_hover_unit == null:
		_hover_info_panel.hide()

## Формирует BBCode-текст с полной информацией о юните
func _get_unit_hover_text(unit: Combatant) -> String:
	var lines = []
	lines.append("[b]%s[/b] (линия %d)" % [unit.unit_name, unit.position_index + 1])
	lines.append("%s %d / %d" % [_stat_icon_or_text("health", "HP"), unit.current_hp, unit.max_hp])
	var dmg_diff = unit.damage - unit.base_damage
	var arm_diff = unit.armor - unit.base_armor
	var acc_diff = unit.accuracy - unit.base_accuracy
	var eva_diff = unit.evasion - unit.base_evasion
	var crit_diff = unit.crit_chance - unit.base_crit_chance
	var dmg_suffix = " [color=lime](+%d)[/color]" % dmg_diff if dmg_diff > 0 else (" [color=red](%d)[/color]" % dmg_diff if dmg_diff < 0 else "")
	var arm_suffix = " [color=lime](+%d)[/color]" % arm_diff if arm_diff > 0 else (" [color=red](%d)[/color]" % arm_diff if arm_diff < 0 else "")
	var acc_suffix = " [color=lime](+%d)[/color]" % acc_diff if acc_diff > 0 else (" [color=red](%d)[/color]" % acc_diff if acc_diff < 0 else "")
	var eva_suffix = " [color=lime](+%d)[/color]" % eva_diff if eva_diff > 0 else (" [color=red](%d)[/color]" % eva_diff if eva_diff < 0 else "")
	var crit_suffix = " [color=lime](+%d%%)[/color]" % int(crit_diff * 100) if crit_diff > 0 else (" [color=red](%d%%)[/color]" % int(crit_diff * 100) if crit_diff < 0 else "")
	lines.append("%s %d%s | %s %d%s" % [_stat_icon_or_text("attack", "Урон"), unit.damage, dmg_suffix, _stat_icon_or_text("armor", "Броня"), unit.armor, arm_suffix])
	lines.append("%s %d%%%s | %s %d%%%s" % [_stat_icon_or_text("accuracy", "Точность"), unit.accuracy, acc_suffix, _stat_icon_or_text("evasion", "Уклонение"), unit.evasion, eva_suffix])
	lines.append("%s %d%%%s | %s %d" % [_stat_icon_or_text("luck", "Удача"), int(unit.crit_chance * 100), crit_suffix, _stat_icon_or_text("initiative", "Инициатива"), unit.initiative])
	if not unit.is_enemy:
		lines.append("%s %d / 100" % [_stat_icon_or_text("glory", "Величие"), unit.current_majesty])
	var passive = DataTables.get_passive_description(unit.special_effect_type)
	if passive != "":
		lines.append("[color=cyan]%s[/color]" % passive)
	if unit.is_stunned:
		lines.append("[color=red]⚡ Оглушён[/color]")
	if unit.active_stance:
		lines.append("★ Стойка: %s" % unit.active_stance.name)
	return "\n".join(lines)

## Формирует текст тултипа для способности (обычный текст, без BBCode)
func _get_ability_tooltip(ability: AbilityResource, user: Combatant) -> String:
	var lines: Array[String] = []
	lines.append("=== %s ===" % ability.get_display_name())
	var ability_description: String = ability.get_display_description().strip_edges()
	if not DataTables.is_placeholder_description(ability_description):
		lines.append(ability_description)
		lines.append("")

	if ability.damage_modifier > 0:
		if user != null:
			var dmg: int = int(user.damage * ability.damage_modifier)
			lines.append("Урон: %d (%d%% от текущей атаки %d)" % [dmg, int(ability.damage_modifier * 100), user.damage])
		else:
			lines.append("Урон: %d%% от атаки" % int(ability.damage_modifier * 100))
		if ability.damage_type != "" and ability.damage_type != "Physical":
			lines.append("Тип урона: %s" % ability.damage_type)
	if ability.majesty_cost > 0:
		lines.append("Стоимость: %d величия" % ability.majesty_cost)
	if ability.majesty_gain > 0:
		lines.append("Величие: +%d" % ability.majesty_gain)
	if ability.target_type != "":
		lines.append("Цель: %s" % DataTables.get_target_type_name(ability.target_type))
	if ability.extra_targets_count > 0:
		lines.append("Доп. цели: +%d цель" % ability.extra_targets_count)

	if ability.effect_types.size() > 0:
		lines.append("")
		lines.append("Эффекты:")
		for effect in ability.effect_types:
			var val: int = int(ability.effect_values.get(effect, 0))
			var dur: int = int(ability.effect_durations.get(effect, 1))
			var dur_text: String = "навсегда" if dur == -1 else "%d ход." % dur
			lines.append("  • %s [%s]" % [DataTables.describe_effect(effect, val), dur_text])

	var extra_lines: Array[String] = []
	var extra_description: String = ability.get_display_extra_effect_description().strip_edges()
	if not DataTables.is_placeholder_description(extra_description):
		extra_lines.append(extra_description)
	if ability.never_miss:
		extra_lines.append("Не может промахнуться.")
	if ability.breaks_enemy_stances:
		extra_lines.append("Сбивает стойку цели.")
	if ability.is_stance:
		var stance_line: String = "Стойка"
		if ability.stance_duration_type != "":
			stance_line += " (%s)" % ability.stance_duration_type
		extra_lines.append(stance_line + ".")
		var stance_description: String = DataTables.get_stance_effect_description(ability.stance_effect_type)
		var current_text_for_stance: String = "\n".join(lines)
		if extra_lines.size() > 0:
			current_text_for_stance += "\n" + "\n".join(extra_lines)
		if DataTables.should_append_detail(current_text_for_stance, stance_description):
			extra_lines.append(stance_description)
	if ability.condition != "":
		var condition_line: String = "Срабатывает %s" % DataTables.get_condition_name(ability.condition)
		if ability.condition_effect != "":
			var cond_val: int = ability.condition_effect_value
			var cond_dur: int = ability.condition_effect_duration
			var cond_dur_text: String = "навсегда" if cond_dur == -1 else "%d ход." % cond_dur
			condition_line += ": %s [%s]" % [DataTables.describe_effect(ability.condition_effect, cond_val), cond_dur_text]
		condition_line += "."
		extra_lines.append(condition_line)
	if ability.mark_type != "":
		var mark_line: String = "Отложенная метка: %s, позиция %d, сторона: %s" % [DataTables.get_mark_type_name(ability.mark_type), ability.mark_position + 1, ability.mark_target_team]
		if ability.mark_duration > 0:
			mark_line += ", %d ход." % ability.mark_duration
		else:
			mark_line += "."
		extra_lines.append(mark_line)
		if ability.mark_damage_percent > 0:
			extra_lines.append("После метки наносит %d%% от текущей атаки." % ability.mark_damage_percent)
		if ability.mark_effect_type != "":
			var mark_dur_text: String = "навсегда" if ability.mark_effect_duration == -1 else "%d ход." % ability.mark_effect_duration
			extra_lines.append("Эффект метки: %s [%s]" % [DataTables.describe_effect(ability.mark_effect_type, ability.mark_effect_value), mark_dur_text])
	var marker_description: String = DataTables.get_ability_marker_description(ability.ability_marker)
	var current_text_for_marker: String = "\n".join(lines)
	if extra_lines.size() > 0:
		current_text_for_marker += "\n" + "\n".join(extra_lines)
	if DataTables.should_append_detail(current_text_for_marker, marker_description):
		extra_lines.append(marker_description)
	if extra_lines.size() > 0:
		lines.append("")
		lines.append("Дополнительно:")
		for extra_line in extra_lines:
			lines.append("  • %s" % extra_line)

	var pos_from: Array[String] = []
	for i in range(ability.usable_from_positions.size()):
		if ability.usable_from_positions[i]:
			pos_from.append(str(i + 1))
	if pos_from.size() > 0 and pos_from.size() < 4:
		lines.append("Доступно с линий: %s" % " / ".join(pos_from))
	var target_pos: Array[String] = []
	for i in range(ability.targetable_positions.size()):
		if ability.targetable_positions[i]:
			target_pos.append(str(i + 1))
	if target_pos.size() > 0:
		lines.append("Цель на линиях: %s" % " / ".join(target_pos))
	return "\n".join(lines)
func _sort_spells_for_battle_ui() -> void:
	available_spells.sort_custom(func(a: SpellResource, b: SpellResource) -> bool:
		if a.spell_name == "Ром" and b.spell_name != "Ром":
			return true
		if b.spell_name == "Ром" and a.spell_name != "Ром":
			return false
		return a.resource_path < b.resource_path
	)

func _load_spells() -> void:
	available_spells.clear()
	_collect_spells_from_dir("res://Spells")
	_sort_spells_for_battle_ui()
	_setup_spell_panel()
	_update_spell_ui()

func _collect_spells_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_spells_from_dir(path)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var spell := load(path) as SpellResource
			if spell != null and _is_spell_available_for_location(spell):
				available_spells.append(_apply_spell_upgrade_discount(spell))
		file_name = dir.get_next()
	dir.list_dir_end()
func _is_spell_available_for_location(spell: SpellResource) -> bool:
	var required_location := spell.required_location_id.strip_edges()
	if required_location == "" or required_location == CombatManager.selected_location_id:
		return true
	# Чарка вечного рома: позволяет использовать заклинание «Ром» в любой локации.
	for _rum_hero in heroes_team:
		if _rum_hero and _rum_hero.current_hp > 0 and _rum_hero.has_item_effect("eternal_rum_cup_anywhere"):
			return true
	return false

## Бесконечная библиотека — "Осмыслять сюжет": применяет уровень улучшения заклинания
## (стоимость + эффект целиком заменяются по SpellUpgradeData, см. Spells/spell_upgrade_data.gd).
## Дублирует ресурс перед изменением — load() возвращает общий закэшированный
## инстанс, менять его напрямую было бы накопительным багом между боями.
func _apply_spell_upgrade_discount(spell: SpellResource) -> SpellResource:
	var level := CampaignState.get_spell_upgrade_level(spell.resource_path)
	if level <= 0:
		return spell
	var data := SpellUpgradeData.get_level_data(spell.resource_path, level)
	if data.is_empty():
		return spell
	var upgraded := spell.duplicate() as SpellResource
	upgraded.fantasy_cost = int(data.get("fantasy_cost", upgraded.fantasy_cost))
	upgraded.description = str(data.get("description", upgraded.description))
	if data.has("effect_types"):
		var new_effect_types: Array[String] = []
		for e in data["effect_types"]:
			new_effect_types.append(str(e))
		upgraded.effect_types = new_effect_types
		upgraded.effect_values = (data.get("effect_values", {}) as Dictionary).duplicate()
		upgraded.effect_durations = (data.get("effect_durations", {}) as Dictionary).duplicate()
	if data.has("flat_damage"):
		upgraded.flat_damage = int(data["flat_damage"])
	upgraded.set_meta("upgrade_level", level)
	upgraded.set_meta("refund_on_kill", bool(data.get("refund_on_kill", false)))
	return upgraded

## Создание панели заклинаний в правом нижнем углу
func _setup_spell_panel():
	var ui_layer = $BattleUI
	if not ui_layer:
		return

	var spell_content := VBoxContainer.new()
	spell_content.name = "SpellPanel"
	spell_content.add_theme_constant_override("separation", int(ABILITY_BUTTON_GAP))

	# Заголовок: очки фантазии (иконка + значение), по аналогии со строками характеристик.
	var fantasy_row := HBoxContainer.new()
	fantasy_row.name = "FantasyRow"
	fantasy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fantasy_row.add_theme_constant_override("separation", 6)
	var fantasy_icon := TextureRect.new()
	fantasy_icon.name = "FantasyIcon"
	fantasy_icon.custom_minimum_size = Vector2(STAT_ICON_BBCODE_SIZE, STAT_ICON_BBCODE_SIZE)
	fantasy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fantasy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fantasy_icon.texture = load("res://Icons/fantasy_icon.png") as Texture2D
	fantasy_icon.tooltip_text = "Фантазия"
	fantasy_row.add_child(fantasy_icon)
	_fantasy_label = Label.new()
	_fantasy_label.name = "FantasyLabel"
	_fantasy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fantasy_row.add_child(_fantasy_label)
	spell_content.add_child(fantasy_row)

	var spell_buttons_area := HBoxContainer.new()
	spell_buttons_area.name = "SpellButtonsArea"
	spell_buttons_area.add_theme_constant_override("separation", int(ABILITY_BUTTON_GAP))
	spell_content.add_child(spell_buttons_area)

	var rum_column := VBoxContainer.new()
	rum_column.name = "RumColumn"
	spell_buttons_area.add_child(rum_column)

	var spell_grid := GridContainer.new()
	spell_grid.name = "SpellButtonsGrid"
	spell_grid.columns = 4
	spell_grid.add_theme_constant_override("h_separation", int(ABILITY_BUTTON_GAP))
	spell_grid.add_theme_constant_override("v_separation", int(ABILITY_BUTTON_GAP))
	spell_buttons_area.add_child(spell_grid)

	# Кнопки заклинаний: Ром отдельно слева, остальные справа в сетке 4 колонки.
	_spell_buttons.clear()
	for i in range(available_spells.size()):
		var btn = Button.new()
		var spell: SpellResource = available_spells[i]
		var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
		_apply_spell_button_base_style(btn)
		_set_spell_button_content(btn, spell, cost, false)
		btn.tooltip_text = "%s\nСтоимость: %d фантазии\nТип цели: %s" % [spell.get_display_description(), cost, DataTables.get_target_type_name(spell.target_type)]
		btn.pressed.connect(_on_spell_clicked.bind(i))
		if spell.spell_name == "Ром":
			rum_column.add_child(btn)
		else:
			spell_grid.add_child(btn)
		_spell_buttons.append(btn)
	if rum_column.get_child_count() == 0:
		rum_column.queue_free()

	# Обёртка-панель с фоном
	var panel_bg = PanelContainer.new()
	panel_bg.name = "SpellPanelBG"
	panel_bg.add_child(spell_content)
	ui_layer.add_child(panel_bg)

	# Позиционирование: Ром отдельной кнопкой слева, остальные заклинания в 2 ряда по 4.
	var spell_top := _get_bottom_controls_top()
	var columns := 4
	var has_rum := false
	for spell in available_spells:
		if spell.spell_name == "Ром":
			has_rum = true
			break
	var grid_count := available_spells.size() - (1 if has_rum else 0)
	var rows := int(ceil(float(maxi(grid_count, 1)) / float(columns)))
	var grid_width := ABILITY_ICON_BUTTON_SIZE.x * float(columns) + ABILITY_BUTTON_GAP * float(columns - 1)
	var rum_width := ABILITY_ICON_BUTTON_SIZE.x + ABILITY_BUTTON_GAP if has_rum else 0.0
	var panel_width := grid_width + rum_width
	var grid_height := ABILITY_ICON_BUTTON_SIZE.y * float(rows) + ABILITY_BUTTON_GAP * float(maxi(rows - 1, 0))
	var panel_height := 34.0 + ABILITY_BUTTON_GAP + maxf(ABILITY_ICON_BUTTON_SIZE.y, grid_height)
	var viewport_width := get_viewport_rect().size.x
	var panel_left := maxf(16.0, viewport_width - panel_width - 16.0)
	panel_bg.offset_left = panel_left
	panel_bg.offset_top = spell_top
	panel_bg.offset_right = panel_left + panel_width
	panel_bg.offset_bottom = spell_top + panel_height
	panel_bg.hide()

	# Привязываем _spell_panel к bg-контейнеру.
	_spell_panel = panel_bg

func _apply_spell_button_base_style(button: Button) -> void:
	button.custom_minimum_size = ABILITY_ICON_BUTTON_SIZE
	button.size = ABILITY_ICON_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true

func _set_spell_button_content(button: Button, spell: SpellResource, cost: int, used: bool) -> void:
	var icon := spell.get_icon_texture()
	button.icon = icon
	if icon != null:
		button.text = ""
	elif used:
		button.text = "%s (исп.)" % spell.get_display_name()
	else:
		button.text = "%s (%d)" % [spell.get_display_name(), cost]

## Обновление состояния UI заклинаний
func _update_spell_ui():
	if not _fantasy_label:
		return
	_fantasy_label.text = "%d / %d" % [current_fantasy, max_fantasy]
	for i in range(_spell_buttons.size()):
		if i >= available_spells.size():
			break
		var spell: SpellResource = available_spells[i]
		var btn: Button = _spell_buttons[i]
		var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
		var not_enough: bool = current_fantasy < cost
		btn.disabled = spells_used_this_round >= max_spells_per_round or not_enough
		_set_spell_button_content(btn, spell, cost, spells_used_this_round >= max_spells_per_round)
		btn.tooltip_text = "%s\nСтоимость: %d фантазии\nТип цели: %s" % [spell.get_display_description(), cost, DataTables.get_target_type_name(spell.target_type)]

## Обработка клика по кнопке заклинания
func _on_spell_clicked(spell_index: int):
	if spell_index < 0 or spell_index >= available_spells.size():
		return
	var spell: SpellResource = available_spells[spell_index]

	# Сброс режима выбора цели для способности (игрок переключился на заклинание)
	waiting_for_target = false
	selected_ability = null

	if spells_used_this_round >= max_spells_per_round:
		_set_status("Заклинание уже использовано максимальное число раз в этом раунде.")
		return
	var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
	# ═══ Замок — Рыцарь: все заклинания стоят +2 за каждого живого Рыцаря ═══
	var _knight_extra = 0
	for _ke in enemies_team:
		if _ke and _ke.current_hp > 0 and _ke.special_effect_type == "knight_spell_cost_increase":
			_knight_extra += 2
			# Стойка «Сила превыше магии»: ещё +2 дополнительно
			for _keff in _ke.active_effects:
				if Combatant._effect_get(_keff, "effect_id", "") == "knight_magic_supremacy_cost":
					_knight_extra += 2
					break
	if _knight_extra > 0:
		cost += _knight_extra
	if current_fantasy < cost:
		_set_status("Недостаточно очков фантазии для %s (нужно: %d⚛)." % [spell.get_display_name(), cost])
		return

	# Self-заклинание применяется мгновенно
	if spell.target_type == "Self":
		_apply_spell_to_target(active_unit, spell)
		_deduct_spell(spell)
		_update_spell_ui()
		return

	# All_Enemies / All_Allies — применяем ко всем
	if spell.target_type == "All_Enemies" or spell.target_type == "All_Allies":
		var team = enemies_team if spell.target_type == "All_Enemies" else heroes_team
		for unit in team:
			if unit and unit.current_hp > 0:
				_apply_spell_to_target(unit, spell)
		_deduct_spell(spell)
		_update_spell_ui()
		_update_all_visuals()
		return

	# Для одиночных целей (включая "Any") — ожидаем выбора
	_waiting_for_spell_target = true
	_selected_spell = spell
	_set_status("Выберите цель для заклинания: %s" % spell.get_display_name())
	_update_target_highlights()

## Применение эффектов заклинания к одной цели
func _apply_spell_to_target(target: Combatant, spell: SpellResource):
	# ═══ Замок — Инквизитор: иммунитет к заклинаниям ═══
	if target.special_effect_type == "inquisitor_spell_immune":
		_log_combat("🛡️ %s: иммунитет к заклинаниям — «%s» рассеян!" % [target.unit_name, spell.spell_name])
		return
	var voodoo_effect_snapshot: Array = _snapshot_active_effects()
	# Обработка эффектов заклинания
	for effect in spell.effect_types:
		var val: int = spell.effect_values.get(effect, 0)
		var duration: int = spell.effect_durations.get(effect, 1)
		
		if effect == "restart_battle":
			_log_combat("⚡ Перечитать: битва начнётся заново в тех же условиях.")
			call_deferred("_restart_battle_from_spell")
		elif effect == "periodic_damage":
			var _spell_dot_duration = _compute_effect_duration(active_unit, target, duration, true)
			target.active_effects.append({"stat": "periodic_damage", "value": val, "duration": _spell_dot_duration, "source_ability": spell.spell_name})
			_log_combat("⚡ %s: %s получает %d периодического урона на %d ход(ов)." % [spell.spell_name, target.unit_name, val, _spell_dot_duration])
		elif effect == "periodic_damage_percent":
			var _pct_dot_val = int(target.max_hp * val / 100.0)
			var _pct_dot_duration = _compute_effect_duration(active_unit, target, duration, true)
			if _pct_dot_val > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _pct_dot_val, "duration": _pct_dot_duration, "source_ability": spell.spell_name})
				_log_combat("⚡ %s: %s получает %d периодического урона (%d%% от макс. HP) на %d ход(ов)." % [spell.spell_name, target.unit_name, _pct_dot_val, val, _pct_dot_duration])
		elif effect == "target_heal_percent":
			var _heal_amount = int(target.max_hp * val / 100.0)
			if _heal_amount > 0:
				var _heal_hp_before = target.current_hp
				target.apply_stat_change("hp", _heal_amount)
				_log_combat("⚡ %s: %s восстанавливает %d HP (%d%% от макс). HP: %d → %d" % [spell.spell_name, target.unit_name, _heal_amount, val, _heal_hp_before, target.current_hp])
		elif effect == "pull_forward":
			var old_pos = target.position_index
			_apply_shift_effect(target, -val, _is_player_hero(target))
			_log_combat("⚡ %s: %s притягивается вперёд (линия %d → %d)." % [spell.spell_name, target.unit_name, old_pos + 1, target.position_index + 1])
		elif effect == "push_back":
			var old_pos = target.position_index
			_apply_shift_effect(target, val, _is_player_hero(target))
			_log_combat("⚡ %s: %s отталкивается назад (линия %d → %d)." % [spell.spell_name, target.unit_name, old_pos + 1, target.position_index + 1])
		elif effect.contains("buff") or effect.contains("debuff"):
			# Общий обработчик баффов/дебаффов для заклинаний
			var stat = effects._extract_stat_name(effect)
			if effect.contains("debuff"):
				var spell_debuff_duration = _compute_effect_duration(active_unit, target, duration, true)
				target.apply_stat_change(stat, -val)
				target.active_effects.append({"stat": stat, "value": -val, "duration": spell_debuff_duration, "source_ability": spell.spell_name})
				# Локация: Сад — при дебаффе на союзника
				if CombatManager.selected_location_id == "garden" and not target.is_enemy and target.current_hp > 0:
					var hp_before_g = target.current_hp
					target.take_damage(15)
					_log_combat("  → [Сад] +15 чистого урона при дебаффе. HP: %d → %d" % [hp_before_g, target.current_hp])
				_log_combat("⚡ %s: %s: -%d к %s на %d ход(ов)." % [spell.spell_name, target.unit_name, val, stat, spell_debuff_duration])
			elif effect.contains("buff"):
				if effects._block_buff_for_hopeless_stance(target):
					return
				var spell_buff_duration = _compute_effect_duration(active_unit, target, duration, false)
				target.apply_stat_change(stat, val)
				target.active_effects.append({"stat": stat, "value": val, "duration": spell_buff_duration, "source_ability": spell.spell_name})
				_log_combat("⚡ %s: %s: +%d к %s на %d ход(ов)." % [spell.spell_name, target.unit_name, val, stat, spell_buff_duration])
				effects._check_pegasus_ally_buff(target)
	
	# Матрос: пассивка sailor_rum_heal — восстанавливает 10% HP при получении заклинания «Ром»
	if spell.spell_name == "Ром" and target.special_effect_type == "sailor_rum_heal":
		var heal_amount = int(target.max_hp * 0.10)
		if heal_amount > 0:
			var hp_before = target.current_hp
			target.apply_stat_change("hp", heal_amount)
			_log_combat("🍺 [Матрос] %s восстанавливает %d HP от Рома! HP: %d → %d" % [
				target.unit_name, heal_amount, hp_before, target.current_hp])

	# Моргана: пассивка — при использовании заклинания на врага, наложить 10% периодического урона на 2 хода
	if target.is_enemy:
		for hero in heroes_team:
			if hero and hero.current_hp > 0 and hero.special_effect_type == "morgan_spell_periodic":
				# Жезл тьмы: удваивает урон от пассивки Морганы.
				var _mp_pct = 0.20 if hero.has_item_effect("morgan_double_passive_dot") else 0.10
				var mp_dmg = int(target.max_hp * _mp_pct)
				if mp_dmg > 0:
					var _mp_duration = _compute_effect_duration(hero, target, 2, true)
					target.active_effects.append({"stat": "periodic_damage", "value": mp_dmg, "duration": _mp_duration, "source_ability": "Пассивка Морганы"})
					_log_combat("🌙 [Моргана] %s получает %d периодического урона на %d хода от пассивки." % [target.unit_name, mp_dmg, _mp_duration])
				break
	
	# Прямой урон
	if spell.flat_damage > 0:
		if not _is_unit_invulnerable(target):
			target.take_damage(spell.flat_damage)
			_log_combat("⚡ %s: %s получает %d урона (%s)." % [spell.spell_name, target.unit_name, spell.flat_damage, spell.damage_type])
			if target.current_hp <= 0:
				_log_combat("☠ %s погибает от заклинания %s!" % [target.unit_name, spell.spell_name])
				_on_unit_killed(target)
				_compact_team(heroes_team if not target.is_enemy else enemies_team)
				if bool(spell.get_meta("refund_on_kill", false)):
					_pending_spell_refund = true
					_log_combat("⚡ %s: враг повержен — можно применить ещё одно заклинание в этот ход!" % spell.spell_name)
				_check_battle_end()
		else:
			_log_combat("⚡ %s: %s неуязвим — урон поглощён." % [spell.spell_name, target.unit_name])

	var voodoo_log: Array = []
	_propagate_new_voodoo_debuffs(voodoo_effect_snapshot, voodoo_log)
	for line in voodoo_log:
		_log_combat(line)
	_update_all_visuals()

## Списание очков фантазии и отметка использования
func _restart_battle_from_spell() -> void:
	get_tree().reload_current_scene()

func _deduct_spell(spell: SpellResource):
	_clear_pinned_unit_info()
	_show_ability_banner(spell.get_display_name())
	var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
	current_fantasy = maxi(current_fantasy - cost, 0)
	spells_used_this_round += 1
	if _pending_spell_refund:
		_pending_spell_refund = false
		spells_used_this_round = maxi(0, spells_used_this_round - 1)
	_log_combat("⚡ Заклинание «%s» использовано (стоимость: %d⚛). Фантазия: %d/%d." % [spell.spell_name, cost, current_fantasy, max_fantasy])
	# ═══ Экскалибур: +1 к атаке до конца боя за каждую единицу потраченной фантазии ═══
	if cost > 0:
		for _exc_hero in heroes_team:
			if _exc_hero and _exc_hero.current_hp > 0 and _exc_hero.has_item_effect("excalibur_fantasy_spent_damage"):
				_exc_hero.apply_stat_change("damage", cost)
				_log_combat("⚔ [Экскалибур] %s: +%d урона (потрачена фантазия)." % [_exc_hero.unit_name, cost])
	# ═══ Маска шута: +1% удачи до конца боя за каждую единицу потраченной фантазии ═══
	if cost > 0:
		for _jm_hero in heroes_team:
			if _jm_hero and _jm_hero.current_hp > 0 and _jm_hero.has_item_effect("jesters_mask_fantasy_spent_luck"):
				_jm_hero.apply_stat_change("crit", cost)
				_log_combat("🎭 [Маска шута] %s: +%d%% удачи (потрачена фантазия)." % [_jm_hero.unit_name, cost])
	# ═══ Замок — Волшебник: восстановление HP = потраченной фантазии ═══
	if active_unit and active_unit.current_hp > 0 and active_unit.special_effect_type == "wizard_fantasy_heal":
		var _wh_hp_b = active_unit.current_hp
		active_unit.apply_stat_change("hp", cost)
		_log_combat("  → [Волшебник] %s восстанавливает %d HP за потраченную фантазию (%d → %d)." % [active_unit.unit_name, cost, _wh_hp_b, active_unit.current_hp])
		_update_all_visuals()

# ══════════════════════════════════════════════════════════════
#  ЭФФЕКТЫ ЛОКАЦИЙ — вынесены в battle_locations.gd (класс BattleLocations,
#  объект `locations`, инициализируется в _ready()). Хельхейм/Ад/Тоннели/Звёзды/
#  Горы/Пустыня/Глубина/Остров/Топь — там; Облака/Арена/Замок/Корабли/Джунгли/Сад
#  без выделенной функции (комментарии-указатели остались в battle_locations.gd).
# ══════════════════════════════════════════════════════════════

## Снимок ссылок на эффекты нужен, чтобы после действия отличить новые эффекты
## от уже находившихся на юните до применения способности или заклинания.
func _snapshot_active_effects() -> Array:
	var snapshot: Array = []
	var seen_units: Dictionary = {}
	for unit in heroes_team + enemies_team:
		if unit != null and not seen_units.has(unit):
			seen_units[unit] = true
			snapshot.append({"unit": unit, "effects": unit.active_effects.duplicate(false)})
	return snapshot

func _is_voodoo_debuff(effect_data: Dictionary) -> bool:
	if bool(effect_data.get("voodoo_copy", false)):
		return false
	var stat: String = str(Combatant._effect_get(effect_data, "stat", ""))
	var value: float = float(Combatant._effect_get(effect_data, "value", 0))
	if value < 0.0:
		return true
	return stat in [
		"periodic_damage",
		"stun",
		"rooted",
		"riddle_mark",
		"provocation_mark",
		"thorn_bush_mark",
	]

func _effect_existed_before(effect_data: Dictionary, previous_effects: Array) -> bool:
	for previous_effect in previous_effects:
		if is_same(previous_effect, effect_data):
			return true
	return false

## Кукла вуду копирует полный словарь каждого нового боевого дебаффа:
## длительность, стаки и специальные параметры сохраняются.
func _propagate_new_voodoo_debuffs(snapshot: Array, log_arr: Array) -> void:
	for entry in snapshot:
		var target: Combatant = entry.get("unit", null)
		if target == null:
			continue
		var linked: Combatant = null
		for mark_effect in target.active_effects:
			if Combatant._effect_get(mark_effect, "effect_id", "") == "voodoo_marked":
				linked = mark_effect.get("linked", null)
				break
		if linked == null or linked == target or linked.current_hp <= 0:
			continue

		var previous_effects: Array = entry.get("effects", [])
		var copied_count: int = 0
		for effect in target.active_effects:
			if not (effect is Dictionary):
				continue
			var effect_data: Dictionary = effect
			if _effect_existed_before(effect_data, previous_effects) or not _is_voodoo_debuff(effect_data):
				continue

			var copied_effect: Dictionary = effect_data.duplicate(true)
			copied_effect.erase("linked")
			copied_effect["voodoo_copy"] = true
			var source: String = str(copied_effect.get("source_ability", "Дебафф"))
			copied_effect["source_ability"] = source + " (кукла вуду)"
			linked.active_effects.append(copied_effect)

			var stat: String = str(Combatant._effect_get(copied_effect, "stat", ""))
			var value: int = int(Combatant._effect_get(copied_effect, "value", 0))
			if value < 0 and stat in ["damage", "damage_percent", "armor", "accuracy", "evasion", "initiative", "crit", "max_hp"]:
				linked.apply_stat_change(stat, value)
			elif stat == "stun":
				linked.is_stunned = true
				linked.check_stance_interruption("stun")
				_notify_stun_applied(linked)
			copied_count += 1

		if copied_count > 0:
			log_arr.append("  → [Кукла вуду] %s копирует %d дебафф(ов) с %s." % [linked.unit_name, copied_count, target.unit_name])
## _apply_tormentor_regen / _block_buff_for_hopeless_stance / _apply_buff_to_unit
## перенесены в battle_effects.gd (см. effects._apply_buff_to_unit() и т.п.).

# (Звёзды-Горы-Пустыня-Глубина-Остров-Топь — см. battle_locations.gd, BattleLocations.)
