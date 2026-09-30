extends Node2D
class_name BattleScene

const COMBATANT_VISUAL = preload("res://combatant_visual.tscn")
const STAT_ICON_TOOLTIP_BUTTON_SCRIPT := preload("res://stat_icon_tooltip_button.gd")
const UNIT_DISPLAY = preload("res://unit_display.tscn")
const ENEMY_TURN_DELAY_SEC = 1.2
const HERO_TO_ENEMY_TURN_DELAY_SEC = 0.5
## Базовый шанс, что при ОБЫЧНОМ (не первом, не ультимативном) применении способности
## прозвучит одна из AbilityResource.voice_lines — настраивается игроком, см.
## GameSettings.voice_line_base_chance()/voice_line_frequency и _maybe_play_ability_voice_line().
const VOICE_LINE_REPEAT_COOLDOWN_ROUNDS := 2
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
# Визуалы, на которых сейчас показан предпросмотр цели способности (шанс
# попадания + мигание HP) — см. _update_ability_target_preview().
var _preview_active_visuals: Array = []
# Подсказки обучения показываются только в кампании (Campaign/campaign_screen.gd),
# не в бою — см. _show_blocking_tutorial_hint()/_show_blocking_tutorial_sequence()
# ниже, единственные две точки входа в TutorialHint из этого файла.
const BATTLE_TUTORIALS_ENABLED := false
# Обучающая система: пока > 0, любое игровое действие (выбор способности/цели,
# ждать/пропустить ход, заклинания, отмена ПКМ) блокируется — см. TutorialHint
# (сам оверлей уже блокирует клики визуально, это — защита от _input()/правого
# клика, который идёт мимо обычной GUI-системы кликов Control).
var _active_tutorial_hints: int = 0
# Для паузы HERO_TO_ENEMY_TURN_DELAY_SEC — true, если последний закончивший ход
# юнит был героем (см. _next_turn()); сбрасывается в false, как только пауза
# перед следующим враждебным ходом использована.
var _last_turn_was_hero: bool = false

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
var _hover_label_scroll: ScrollContainer
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
## Если true (см. CombatManager.pending_desert_immunity) — отряд героев не получает
## урон локации "Пустыня" в этом бою целиком (см. battle_locations.gd::_location_desert()).
var desert_immune_this_battle: bool = false
## Если true (см. CombatManager.pending_hell_immunity) — отряд героев не получает
## эффект локации "Ад" в этом бою целиком (см. battle_locations.gd::_location_hell()).
var hell_immune_this_battle: bool = false

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

# ═══ Модули боя (Battle/*.gd) ═══
# Логика разнесена по делегатам с типизированной обратной ссылкой на сцену: сцена хранит
# состояние боя и общие хелперы, модули — поведение. Создаются в _init(), до _ready().
var _menus: BattleMenus
var _start: BattleStart
var _hud: BattleHud
var _info: BattleUnitInfo
var _turns: BattleTurns
var _targeting: BattleTargeting
var _ai: BattleAI
var _abilities: BattleAbilities
var _passives: BattlePassives
var _field: BattleField
var _unit_events: BattleUnitEvents
var _outcome: BattleOutcome
var _spells: BattleSpells

# ═══ Состояние локационных эффектов ═══
var _is_fog_round: bool = false                  # Хельхейм: текущий раунд туманный
var _bg_sprite: Sprite2D = null                  # Узел бэкграунда (самый нижний слой)
var _bottom_backdrop: ColorRect = null              # Область под полем боя (в цвет интерфейса)
var _swamp_tracked_unit: Combatant = null        # Топь: юнит на первой позиции
var _swamp_consecutive_rounds: int = 0           # Топь: сколько ходов подряд юнит под эффектом локации (для пассивки Водяного)
var _swamp_grace_unit: Combatant = null          # Топь/Утопленница: юнит покинул позицию 1, но дебафф ещё держится
var _swamp_grace_turns_left: int = 0             # Топь/Утопленница: сколько ходов осталось до полного снятия

var _ra_sun_glory_active: bool = false           # Жрец Ра: «Слава солнцу» — урон Пустыни по врагам x2
var _enemy_graveyard: Array = []                 # Погибшие враги (для воскрешения Жрецом Анубиса)
var _hero_graveyard: Array = []                  # Погибшие герои (для воскрешения)
var _heroes_died_this_round: bool = false        # Замок: Рыцарь «Отважный удар»
var _enemies_died_this_round: bool = false       # Замок: Рыцарь «Отважный удар»

func _init() -> void:
	_menus = BattleMenus.new(self)
	_start = BattleStart.new(self)
	_hud = BattleHud.new(self)
	_info = BattleUnitInfo.new(self)
	_turns = BattleTurns.new(self)
	_targeting = BattleTargeting.new(self)
	_ai = BattleAI.new(self)
	_abilities = BattleAbilities.new(self)
	_passives = BattlePassives.new(self)
	_field = BattleField.new(self)
	_unit_events = BattleUnitEvents.new(self)
	_outcome = BattleOutcome.new(self)
	_spells = BattleSpells.new(self)

func _ready():
	randomize()
	Engine.time_scale = GameSettings.battle_speed
	# Смена скорости боя через «Настройки» прямо во время боя применяется сразу
	# (с учётом паузы: во время вспышки/звука удара time_scale остаётся 0).
	GameSettings.settings_changed.connect(_refresh_battle_pause_time_scale)
	_combat_log_collapsed = not GameSettings.combat_log_expanded_default
	# Бесконечная библиотека — "Читать книги" даёт постоянный бонус к максимальной фантазии.
	max_fantasy += CampaignState.library_max_fantasy_bonus
	current_fantasy = max_fantasy
	marks = BattleMarks.new(self)
	locations = BattleLocations.new(self)
	effects = BattleEffects.new(self)
	_hud._create_background_node()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_hud._apply_background()
	_start._spawn_teams_from_resources()
	_hud._connect_ui_buttons()
	_spells._load_spells()
	_info._setup_hover_info_panel()
	_hud._setup_ability_banner()
	_hud._setup_turn_order_display()
	_menus._setup_settings_button()
	_menus._setup_combat_log_toggle_button()
	_menus._setup_help_button()
	# Добавляется последней, чтобы гарантированно оказаться выше полосы очереди ходов
	# и прочих элементов верхней панели при наведении мыши (порядок узлов = порядок хит-теста).
	_hud._setup_location_door_icon()
	if ability_panel:
		_hud._hide_ability_controls()
	current_round = 0
	# Инициализация лимита заклинаний для локации
	max_spells_per_round = 2 if CombatManager.can_cast_two_spells() else 1
	_log_combat("Бой начался!")
	if CombatManager.selected_location_id != "":
		var effect_name = DataTables.get_battle_effect_name(CombatManager.selected_location_id)
		_log_combat("⚔ Локация: %s" % effect_name)
		_menus._show_location_visited_hint_if_needed(CombatManager.selected_location_id)
		# Боевая музыка локации — только для боёв внутри миссии (см. MusicManager);
		# возврат к non_battle треку миссии — в _exit_tree() ниже.
		if CombatManager.is_mission_battle:
			MusicManager.play_battle(CombatManager.selected_location_id)
	locations._location_mountains_label()
	_start._apply_pending_mission_modifiers()
	_passives._init_orochi_pool()
	Combatant.shared_death_shield_provider = _passives._try_shared_death_shield
	_turns._start_new_round()
	_menus._show_battle_intro_tutorial_if_needed()

## Пока хотя бы одна подсказка на экране ИЛИ доигрывает звук/вспышка способности —
## игра буквально на паузе (иначе враги продолжали ходить/анимации крутились под
## затемнённым экраном, пока игрок не может ничего сделать, или следующий удар
## перекрывал ещё не доигравший предыдущий). Engine.time_scale=0 замораживает все
## Tween/create_timer в проекте (в т.ч. паузу перед ходом врага — см.
## ENEMY_TURN_DELAY_SEC — и саму AI-логику хода); кнопки подсказки не завязаны на
## time_scale и продолжают работать, а сам твин вспышки способности явно помечен
## set_ignore_time_scale(true) (см. CombatantVisual.show_attack_effect_flash),
## иначе он тоже застрял бы на паузе, которую сам же и держит. Восстанавливаем не
## 1.0, а GameSettings.battle_speed — то же значение, что стоит вне пауз (см.
## _ready()/_exit_tree()).
var _active_attack_effects: int = 0

func _is_battle_paused() -> bool:
	return _active_tutorial_hints > 0 or _active_attack_effects > 0

func _refresh_battle_pause_time_scale() -> void:
	Engine.time_scale = 0.0 if _is_battle_paused() else GameSettings.battle_speed

func _adjust_tutorial_hint_count(delta: int) -> void:
	_active_tutorial_hints = maxi(0, _active_tutorial_hints + delta)
	_refresh_battle_pause_time_scale()

func _adjust_attack_effect_count(delta: int) -> void:
	_active_attack_effects = maxi(0, _active_attack_effects + delta)
	_refresh_battle_pause_time_scale()


## Возвращает глобальную скорость движка к норме при выходе из боя (см. GameSettings.battle_speed
## в _ready()) — иначе она "утекала" бы в меню и другие экраны после боя/сдачи.
func _exit_tree() -> void:
	Combatant.shared_death_shield_provider = Callable()
	if GameSettings.settings_changed.is_connected(_refresh_battle_pause_time_scale):
		GameSettings.settings_changed.disconnect(_refresh_battle_pause_time_scale)
	Engine.time_scale = 1.0
	# Безусловно (не только для миссий) — если это был не миссионный бой, у
	# MusicManager просто нечего возобновлять, вызов тогда ничего не делает.
	MusicManager.resume_mission_non_battle()


## Обработка правого клика: ВСЕГДА отменяет текущее выделение (способность / заклинание / марка).
func _input(event: InputEvent):
	if _is_battle_paused():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _menus._handle_help_back():
			get_viewport().set_input_as_handled()
			return
		_targeting._cancel_selection()

func _on_viewport_size_changed() -> void:
	_hud._fit_background()
	_hud._position_bottom_backdrop()
	_hud._position_bottom_ui_controls()
	_field._sync_status_bar_positions()
	_info._position_hover_info_panel()
	_menus._position_combat_log_toggle_button()

const BACKGROUND_FRAME_RATIO := 798.0 / 1972.0

func _get_unit_at_position(team: Array, pos: int) -> Combatant:
	if pos < 0 or pos > 3:
		return null
	if team[pos] and team[pos].current_hp > 0:
		return team[pos]
	return null

var _duna_turn_heal: int = 0
# Номер текущего хода (растёт с каждым ходом любого юнита). Асинхронный ход врага сверяет его
# после паузы: у юнита с несколькими ходами за раунд «устаревший» вызов завершения прошлого
# хода иначе закрыл бы его следующий ход раньше времени.
var _turn_serial: int = 0

func _is_player_hero(unit: Combatant) -> bool:
	return not unit.is_enemy

func _is_on_enemies_team(unit: Combatant) -> bool:
	return unit.is_enemy

func _set_status(text: String):
	if status_label:
		status_label.text = text

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
		_hud._update_marks_display()

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
		["Урон", "attack"], ["урона", "attack"], ["урон", "attack"],
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

# Состояние анти-повтора реплик — живёт только на время этого боя (сцена пересоздаётся
# на каждый бой), см. _maybe_play_ability_voice_line().
var _voice_line_first_cast_seen: Dictionary = {}
var _voice_line_last_round: Dictionary = {}
var _voice_line_busy_until_msec: int = 0

const ATTACK_SFX_PLAYER_POOL_SIZE := 6
var _attack_sfx_players: Array[AudioStreamPlayer] = []
var _next_attack_sfx_player_idx: int = 0

## Длительность вспышки способности (см. CombatantVisual.ATTACK_FLASH_FADE_DURATION:
## 0.25 проявление + 0.25 исчезание) — держим отдельной константой здесь, т.к.
## combatant_visual.gd не объявляет class_name и её нельзя прочитать напрямую.
const ATTACK_FLASH_TOTAL_DURATION := 0.5

## Звук анимации способности (attack_sfx) раньше почти всегда играл на полной
## громкости (0 dB) — заметно перекрывал озвученную реплику. ATTACK_SFX_VOLUME_SCALE
## снижает его примерно до громкости речи (голос играет как есть, без затухания —
## см. CombatantVisual._voice_audio_player). Если у способности есть озвученные
## фразы — звук анимации приглушается ещё на 30% (линейно) сверху, на случай если
## реплика сейчас прозвучит (см. _maybe_play_ability_voice_line; шанс настраивается
## игроком через GameSettings.voice_line_base_chance() — приглушение приблизительное,
## не привязано к результату конкретного броска).
const ATTACK_SFX_VOLUME_SCALE := 0.5
const ATTACK_SFX_VOLUME_SCALE_WITH_VOICE := 0.7

## Async: пауза THUNDER_WRATH_HIT_GAP_SEC между каждым из 5 ударов, чтобы они били
## по очереди, а не все разом одним кадром — каждый удар получает свою собственную
## анимацию (см. CombatantVisual.show_attack_effect_flash), но без паузы все 5
## отрисовывались бы визуально в один и тот же момент времени.
const THUNDER_WRATH_HIT_GAP_SEC := 0.5

## _has_provocation/_has_innocence/_remove_effect_id перенесены в battle_effects.gd
## (BattleEffects) — см. effects._has_provocation() и т.п.
func _has_effect_id(unit: Combatant, effect_id: String) -> bool:
	if unit == null:
		return false
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == effect_id:
			return true
	return false

# ═══ Яматано Орочи: общий пул щитов смерти команды ═══
const OROCHI_MAX_SHIELDS := 8
var _orochi_death_shields: int = 0

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
