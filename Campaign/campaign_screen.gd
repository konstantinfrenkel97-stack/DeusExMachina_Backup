extends Control
class_name CampaignScreen
## Экран кампании.
## Содержит три вкладки, переключаемые кнопками вверху:
##   • Боги         — ростер доступных богов (CharacterResource)
##   • Сокровищница — собранные артефакты (ItemResource)
##   • Миссии       — доступные миссии (MissionResource)
##
## Содержимое каждой вкладки заполняется динамически из CampaignState.
## Пока массивы пусты — показывается текст-заглушка.
## Никакого хардкода: стоит только добавить элементы в CampaignState,
## и они автоматически появятся на экране.

const TAB_GODS := 0
const TAB_TREASURY := 1
const TAB_MISSIONS := 2
# Подключаем слот ростера по пути (preload), чтобы не зависеть от
# регистрации class_name в глобальном кэше классов.
const _RosterSlot := preload("res://Campaign/god_roster_slot.gd")
const SettingsPanel := preload("res://Settings/settings_panel.gd")
const STAT_ICON_TOOLTIP_BUTTON_SCRIPT := preload("res://stat_icon_tooltip_button.gd")
const StatIconFormatter := preload("res://Scripts/stat_icon_formatter.gd")
const CAMPAIGN_BACKGROUND_PATH := "res://Background/Campaign_Background.png"
const REQUIRED_GODS_FOR_FIRST_BATTLE := 4
const FIRST_BATTLE_MISSION_PATH := "res://Missions/First_battle.tres"
const DOORS_SCENE_PATH := "res://Doors/doors.tscn"
const BEFORE_FIRST_BATTLE_DIALOGUE_PATH := "res://Dialogues/Instructions/Before_first_battle.tres"
const AFTER_FIRST_BATTLE_DIALOGUE_PATH := "res://Dialogues/Introduction/After_first_battle.tres"
const BEFORE_DOORS_DIALOGUE_PATH := "res://Dialogues/Introduction/Before_doors.tres"
const GATES_WRONG_DIALOGUE_PATH := "res://Dialogues/Instructions/Gates_wrong.tres"
const WRONG_LOCATION_DIALOGUE_PATH := "res://Dialogues/Instructions/Wrong_location.tres"
const OPEN_DOOR_CHOICE_ID := "open_door"
const _ABILITY_ICON_BUTTON_SIZE := Vector2(58.0, 58.0)
## Общая палитра — см. Scripts/campaign_theme.gd (единый источник для этого экрана,
## battle_setup.gd и mission_select.gd).
const GOD_DETAIL_BG_COLOR := CampaignTheme.PANEL_BG
const GOD_DETAIL_ACCENT_COLOR := CampaignTheme.ACCENT
const GOD_DETAIL_ACCENT_DIM_COLOR := CampaignTheme.ACCENT_DIM
# Кнопки внутри полупрозрачных окон — непрозрачные и чуть темнее панели, чтобы не сливаться с фоном.
const BUTTON_OPAQUE_BG_COLOR := CampaignTheme.BUTTON_BG
const BUTTON_OPAQUE_BG_HOVER_COLOR := CampaignTheme.BUTTON_BG_HOVER
const BUTTON_OPAQUE_BG_PRESSED_COLOR := CampaignTheme.BUTTON_BG_PRESSED
const BUTTON_OPAQUE_BG_DISABLED_COLOR := CampaignTheme.BUTTON_BG_DISABLED

## ПРАВИЛО: картинка на кнопке-иконке НИКОГДА не должна вылезать за её границы.
## Используем только нативный Button.icon/expand_icon (не самодельный дочерний
## TextureRect с ручным .size/.position — на практике он либо не рисуется вовсе,
## либо разрастается на всё окно, в зависимости от контекста-контейнера).
## clip_contents — обязательная страховка на случай любых будущих сбоев масштабирования.
func _apply_tight_icon_button_style(btn: Button) -> void:
	btn.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_OPAQUE_BG_COLOR
	style.border_color = GOD_DETAIL_ACCENT_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

## Кнопка выбора эссенции (Сад творения, Весы) — иконка занимает практически всю
## кнопку (минимальный фиксированный отступ, как у _apply_tight_icon_button_style).
## Размер кнопки жёстко фиксируется на custom_minimum_size (= видимая рамка), чтобы
## контейнер-родитель не мог растянуть кнопку больше рамки — тогда отступ до иконки
## всегда пропорционален тому, что реально видно на экране.
func _apply_essence_button_style(btn: Button, highlighted: bool = false) -> void:
	btn.clip_contents = true
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if btn.custom_minimum_size != Vector2.ZERO:
		btn.size = btn.custom_minimum_size
	var margin := 4.0
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_OPAQUE_BG_HOVER_COLOR if highlighted else BUTTON_OPAQUE_BG_COLOR
	style.border_color = GOD_DETAIL_ACCENT_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

## Стиль для всплывающих информационных панелей (наведение на предмет/юнита) — тоньше
## рамка и заметно больше отступ, чем у обычных панелей, чтобы текст не упирался в рамку.
func _make_info_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GOD_DETAIL_BG_COLOR
	style.border_color = GOD_DETAIL_ACCENT_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

const GOD_DETAIL_TOP_MARGIN := 92.0
const GOD_DETAIL_ROSTER_GAP := 14.0
const CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT := 96.0
const ROSTER_BOTTOM_GAP := 10.0
const ROSTER_Z_INDEX := 80
# Единый фиксированный размер окна для всех комнат кампании (Сад творения,
# Библиотека, Весы) — не меняется от вкладки к вкладке и от шага к шагу.
const ROOM_PANEL_SIZE := Vector2(980, 640)
const SCALES_COMMON_TO_RARE_COST := 800
const SCALES_RARE_TO_EPIC_THOUGHTS_COST := 1200
const SCALES_BUY_ESSENCE_COST := 600
const SCALES_SELL_ESSENCE_GAIN := 400
const SCALES_ITEM_SLOT_SIZE := Vector2(164.0, 164.0)
const SCALES_ARTIFACT_CARD_SIZE := Vector2(128.0, 144.0)
const _STAT_ICON_SIZE := Vector2(24.0, 24.0)
const _STAT_ICON_PATHS := {
	"health": "res://Icons/Stats/Health.png",
	"attack": "res://Icons/Stats/Attack.png",
	"armor": "res://Icons/Stats/Armor.png",
	"initiative": "res://Icons/Stats/Initiative.png",
	"accuracy": "res://Icons/Stats/Accuracy.png",
	"evasion": "res://Icons/Stats/Evasion.png",
	"luck": "res://Icons/Stats/Luck.png",
	"glory": "res://Icons/Stats/Glory.png",
}
const _STAT_ICON_TOOLTIPS := {
	"health": "Здоровье",
	"attack": "Урон",
	"armor": "Броня",
	"initiative": "Инициатива",
	"accuracy": "Точность",
	"evasion": "Уклонение",
	"luck": "Удача",
	"glory": "Величие",
}

# Ресурсы-валюты в самом верху: 5 эссенций, затем мысли (последние справа).
const _CURRENCY_PATHS: Array[String] = [
	"res://Essence/essence_power.tres",
	"res://Essence/essence_death.tres",
	"res://Essence/essence_nature.tres",
	"res://Essence/essence_chaos.tres",
	"res://Essence/essence_strength.tres",
	"res://Essence/thoughts.tres",
]
var _currency_amount_labels: Array[Label] = []

var _tab_buttons: Array[Button] = []


var _content_scroll: ScrollContainer
var _content_grid: GridContainer
var _campaign_background_rect: TextureRect
var _campaign_room_hit_layer: Control
var _campaign_hover_fill: TextureRect
var _campaign_hover_label: Label
var _campaign_hover_label_panel: PanelContainer
var _campaign_bottom_bar: ColorRect
var _help_button: Button
var _campaign_pages_label: Label
var _campaign_hover_section: String = ""
var _campaign_room_mask_images: Dictionary = {}
## Обучающая система: постоянно мигающий силуэт единственно доступной сейчас
## комнаты (см. _tutorial_locked_room_section()/_update_tutorial_room_highlight()),
## и счётчик открытых сейчас TutorialHint-подсказок (блокирует клики по комнатам,
## как остальные полноэкранные оверлеи — см. _campaign_room_input_is_blocked()).
var _tutorial_room_highlight: TextureRect
var _tutorial_room_highlight_tween: Tween
var _active_tutorial_hints: int = 0
var _campaign_room_mask_bounds_cache: Dictionary = {}

# Кнопка вызова меню (верхний левый угол).
var _menu_button: Button
# Всплывающее меню.
var _menu_popup: PopupPanel
# Диалог сохранения/загрузки (оверлей).
var _dialog_overlay: Control
# Справка вынесена в campaign_help.gd (класс CampaignHelp). Инициализируется в _ready().
var help: CampaignHelp

# ── Страница бога ──
var _god_overlay: Control

# ── Сад творения (создание богов из двух эссенций) ──
const CREATION_ESSENCES := {
	"Сила": "res://Essence/essence_strength.tres",
	"Природа": "res://Essence/essence_nature.tres",
	"Власть": "res://Essence/essence_power.tres",
	"Хаос": "res://Essence/essence_chaos.tres",
	"Смерть": "res://Essence/essence_death.tres",
}
# Рецепты: ключ — две эссенции по алфавиту через «|» → путь к богу.
const CREATION_RECIPES := {
	"Природа|Смерть": "res://Gods/Koschei/Koschei.tres",
	"Сила|Сила": "res://Gods/Susanoo/Susanoo.tres",
	"Природа|Сила": "res://Gods/Thor/thor.tres",
	"Власть|Сила": "res://Gods/Odin/Odin.tres",
	"Сила|Смерть": "res://Gods/Chernobog/Chernobog.tres",
	"Сила|Хаос": "res://Gods/Shiva/Shiva.tres",
	"Природа|Природа": "res://Gods/Danu/Danu.tres",
	"Власть|Природа": "res://Gods/Zeus/zeus.tres",
	"Природа|Хаос": "res://Gods/Poseidon/Poseidon.tres",
	"Власть|Власть": "res://Gods/Osiris/Osiris.tres",
	"Власть|Хаос": "res://Gods/Set/Set.tres",
	"Власть|Смерть": "res://Gods/Hades/Hades.tres",
	"Хаос|Хаос": "res://Gods/Loki/Loki.tres",
	"Смерть|Хаос": "res://Gods/Morgan/Morgan.tres",
	"Смерть|Смерть": "res://Gods/Samdi/Samdi.tres",
}
var _creation_overlay: Control
var _creation_slots: Array[String] = ["", ""]
var _creation_slot_icons: Array[TextureRect] = []
var _creation_slot_hints: Array[Label] = []
var _creation_sprite: TextureRect
var _creation_name_label: Label
var _creation_create_btn: Button
var _creation_popup: PopupPanel
var _creation_active_slot: int = 0
var _creation_essence_count_labels: Array[Label] = []
var _creation_essence_count_paths: Array[String] = []
const SUMMON_DIALOGUE_DIR := "res://Dialogues/Gods_dialogue"

# ── Весы переосмысления ──
var _scales_overlay: Control
var _scales_body: VBoxContainer
var _scales_tab_row: HBoxContainer
var _scales_mode: String = "improve"
var _scales_selected_item_path: String = ""
var _scales_selected_essence_path: String = ""
var _scales_picker_visible: bool = false

# ── Бесконечная библиотека ──
var _library_overlay: Control

# ── Колодец памяти ──
const MEMORY_WELL_COST := 500
var _memory_well_overlay: Control
var _memory_well_body: VBoxContainer
var _memory_well_selected_god_path: String = ""

# ── Сад творения (создание артефактов) ──
const THOUGHTS_PATH := "res://Essence/thoughts.tres"
# Индексы соответствуют ItemResource.ItemType (WEAPON=0, ARMOR=1, TRINKET=2).
const ARTIFACT_TYPE_NAMES: Array[String] = ["Оружие", "Доспехи", "Безделушка"]
const ARTIFACT_TYPE_COST: Array[int] = [500, 500, 300]
const ARTIFACT_COMMON_ITEMS: Array = [
	[
		"res://Items/Weapons/Common/Attack_item1.tres",
		"res://Items/Weapons/Common/Attack_item2.tres",
		"res://Items/Weapons/Common/Attack_item3.tres",
		"res://Items/Weapons/Common/Luck_item1.tres",
		"res://Items/Weapons/Common/luck_item2.tres",
		"res://Items/Weapons/Common/luck_item3.tres",
		"res://Items/Weapons/Common/accuracy_item1.tres",
		"res://Items/Weapons/Common/accuracy_item2.tres",
		"res://Items/Weapons/Common/accuracy_item3.tres",
	],
	[
		"res://Items/Armor/Common/Armor_item1.tres",
		"res://Items/Armor/Common/Armor_item2.tres",
		"res://Items/Armor/Common/Armor_item3.tres",
		"res://Items/Armor/Common/Health_item1.tres",
		"res://Items/Armor/Common/Health_item2.tres",
		"res://Items/Armor/Common/Health_item3.tres",
		"res://Items/Armor/Common/Dodge_item1.tres",
		"res://Items/Armor/Common/Dodge_Item2.tres",
		"res://Items/Armor/Common/Dodge_item3.tres",
	],
	[
		"res://Items/Trinkets/Common/Common_ring.tres",
		"res://Items/Trinkets/Common/common_Amulet.tres",
		"res://Items/Trinkets/Common/common_Potion.tres",
	],
]
var _artifact_selected_type: int = -1
## Сообщение об ошибке для показа на экране выбора предмета (например, нехватка
## мыслей при попытке создать) — выставляется перед пересборкой окна и потребляется
## один раз при следующем показе _show_artifact_item_window.
var _artifact_create_error: String = ""
var _current_god_path: String = ""
var _current_god_res: CharacterResource
# Текущий тип слота экипировки (0=оружие, 1=броня, 2=безделушка).
var _current_slot_type: int = -1
# Окно выбора артефакта (открывается поверх страницы персонажа по клику на ячейку).
var _equip_picker_overlay: Control
var _equip_picker_info_panel: PanelContainer
var _equip_picker_info_label: RichTextLabel

# ── Ростер богов внизу (1 ряд из 16 квадратов) ──
const ROSTER_COLUMNS := 16
const ROSTER_ROWS := 1
const MYTH_FACE_PATH := "res://Main_characters/Myth/Myth_Ironic_face.png"
const MYTH_BEFORE_MISSION_DIALOGUE_PATH := "res://Dialogues/Instructions/Myth_before_mission.tres"
const MYTH_DIALOGUE_CANDIDATES: Array[String] = [
	"res://Dialogues/Myth/Myth_Dialogue_1.tres",
]
var _roster_grid: GridContainer
var _roster_slots: Array = []           # Array[GodRosterSlot] — 16 квадратов
var _before_first_battle_dialogue_pending: bool = false
var _myth_face_slot: Control = null
var _myth_skip_button: Button = null
var _active_god_dialogue_path: String = ""
var _roster_order: Array[String] = []   # Расположение: путь бога или "" (16 элементов)

# ═══ Модули экрана кампании (Campaign/campaign_*.gd) ═══
# Экран хранит состояние и общие хелперы, окна/разделы — в делегатах с типизированной
# обратной ссылкой (_screen: CampaignScreen). Создаются в _init(), до _ready().
var _map: CampaignMap
var _roster: CampaignRoster
var _story: CampaignStory
var _scales: CampaignScales
var _memory_well: CampaignMemoryWell
var _tabs: CampaignTabs
var _artifacts: CampaignArtifacts
var _library: CampaignLibrary
var _creation: CampaignCreation
var _menu: CampaignMenu
var _god_detail: CampaignGodDetail

# Сигнал, который экран может испускать при изменении (на будущее).


func _init() -> void:
	_map = CampaignMap.new(self)
	_roster = CampaignRoster.new(self)
	_story = CampaignStory.new(self)
	_scales = CampaignScales.new(self)
	_memory_well = CampaignMemoryWell.new(self)
	_tabs = CampaignTabs.new(self)
	_artifacts = CampaignArtifacts.new(self)
	_library = CampaignLibrary.new(self)
	_creation = CampaignCreation.new(self)
	_menu = CampaignMenu.new(self)
	_god_detail = CampaignGodDetail.new(self)


## Сигналы автолоадов подключены к модулям (RefCounted), а не к самому экрану, поэтому
## при его удалении Godot их сам не отключит — отключаем явно (иначе модуль, переживший
## экран в ожидании корутины, получил бы сигнал уже без экрана).
func _exit_tree() -> void:
	for connection in [
		[CampaignState.roster_changed, _roster._refresh_roster],
		[CampaignState.currency_changed, _roster._refresh_currencies],
		[CampaignState.currency_changed, _creation._refresh_creation_essence_counts],
		[DialogueManager.dialogue_choice_selected, _story._on_dialogue_choice_selected],
	]:
		var sig: Signal = connection[0]
		if sig.is_connected(connection[1]):
			sig.disconnect(connection[1])


func _ready() -> void:
	# Музыка кампании — всегда сначала, даже если это тот же трек, что уже играл
	# (напр. вернулись из дверей, не выбрав локацию): просили именно перезапуск,
	# а не бесшовное продолжение.
	MusicManager.play_campaign()
	help = CampaignHelp.new(self)
	_build_ui()
	_menu._build_menu()
	# По умолчанию ни одна кнопка-раздел не активна (содержимое пустое).
	# Ростер богов обновляется автоматически при изменении CampaignState.
	if not CampaignState.roster_changed.is_connected(_roster._refresh_roster):
		CampaignState.roster_changed.connect(_roster._refresh_roster)
	if not CampaignState.currency_changed.is_connected(_roster._refresh_currencies):
		CampaignState.currency_changed.connect(_roster._refresh_currencies)
	if not CampaignState.currency_changed.is_connected(_creation._refresh_creation_essence_counts):
		CampaignState.currency_changed.connect(_creation._refresh_creation_essence_counts)
	if not DialogueManager.dialogue_choice_selected.is_connected(_story._on_dialogue_choice_selected):
		DialogueManager.dialogue_choice_selected.connect(_story._on_dialogue_choice_selected)
	_roster._refresh_roster()
	_story._check_first_battle_mission_return()
	_story._flush_pending_before_first_battle_dialogue()
	_story._flush_pending_campaign_dialogue()
	_map._update_tutorial_room_highlight()


# ════════════════════════════════════════════════════════════
#  Построение интерфейса
# ════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_map._build_campaign_background()
	_map._build_campaign_room_hit_layer()
	_map._build_campaign_bottom_bar()

	var root_vb := VBoxContainer.new()
	root_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vb.offset_left = 24
	root_vb.offset_top = 20
	root_vb.offset_right = -24
	root_vb.offset_bottom = -CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT - ROSTER_BOTTOM_GAP
	root_vb.mouse_filter = Control.MOUSE_FILTER_PASS
	root_vb.z_index = 40
	root_vb.add_theme_constant_override("separation", 14)
	add_child(root_vb)


	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vb.add_child(_content_scroll)

	_content_grid = GridContainer.new()
	_content_grid.columns = 5
	_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_grid.add_theme_constant_override("h_separation", 14)
	_content_grid.add_theme_constant_override("v_separation", 14)
	_content_scroll.add_child(_content_grid)

	_roster._build_god_roster(root_vb)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_map._layout_campaign_map.call_deferred()


func _process(_delta: float) -> void:
	_map._update_campaign_hover(get_viewport().get_mouse_position())


## Кнопка-раздел кампании (Ворота, Колодец памяти, и т.д.).
## Пока показывает заглушку; механики разделов добавляются позже.
func _on_section_button(section: String) -> void:
	var locked_section := _map._tutorial_locked_room_section()
	if locked_section != "" and section != locked_section:
		_show_notification("Пока недоступно")
		return
	if section == "Ворота":
		_story._on_gates_clicked()
		return
	if section == "Сад творения":
		_creation._show_creation_window()
		return
	if section == "Весы переосмысления":
		_scales._show_scales_window()
		return
	if section == "Бесконечная библиотека":
		_library._show_library_read_window()
		return
	if section == "Колодец памяти":
		_memory_well._show_memory_well_window()
		return
	DialogueManager.show_dialogue_path(WRONG_LOCATION_DIALOGUE_PATH)

## Клик по комнате, не поглощённый ни одним Control — фоллбэк для левой кнопки мыши.
## Правый клик сюда практически никогда не доходит: _input() выполняется раньше и уже
## закрывает любой открытый оверлей через _try_close_top_overlay() (тот же приоритетный
## список, что здесь проверялся раньше отдельной копией).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _map._campaign_room_input_is_blocked():
			var section := _map._campaign_section_at_position(event.position)
			if section != "":
				var viewport := get_viewport()
				_on_section_button(section)
				if viewport != null:
					viewport.set_input_as_handled()
		return


## Закрывает самый верхний открытый оверлей/попап кампании (в порядке приоритета) —
## единая точка входа для ПКМ, ESC и трёх точечных background-обработчиков ниже
## (Весы/Колодец памяти/страница бога), вместо пяти отдельных копий одного и того же
## списка "что считается открытым оверлеем".
## Возвращает true, если что-то было закрыто.
func _try_close_top_overlay() -> bool:
	if help.handle_back():
		return true
	elif _dialog_overlay != null and is_instance_valid(_dialog_overlay):
		_close_dialog()
		return true
	elif _menu_popup != null and is_instance_valid(_menu_popup) and _menu_popup.visible:
		_menu_popup.hide()
		return true
	elif _creation_overlay != null and is_instance_valid(_creation_overlay):
		_creation._close_creation_window()
		return true
	elif _scales_overlay != null and is_instance_valid(_scales_overlay):
		_scales._close_scales_window()
		return true
	elif _library_overlay != null and is_instance_valid(_library_overlay):
		_library._close_library_window()
		return true
	elif _memory_well_overlay != null and is_instance_valid(_memory_well_overlay):
		_memory_well._close_memory_well_window()
		return true
	elif _god_overlay != null and is_instance_valid(_god_overlay):
		_god_detail._close_god_detail()
		return true
	return false


## Правый щелчок закрывает страницу бога ВЕЗДЕ (в т.ч. по контенту панели):
## дочерние элементы поглощают событие, поэтому gui_input панели его не получает.
## _input срабатывает до обработки GUI и ловит клик над любым элементом оверлея.
func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9 and event.ctrl_pressed and event.shift_pressed:
			_story._debug_skip_first_battle()
			get_viewport().set_input_as_handled()
			return
	## ESC: закрывает открытый оверлей/попап (тот же приоритет, что и ПКМ ниже),
	## а если ничего не открыто — открывает главное меню (как кнопка "☰ Меню").
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if not _try_close_top_overlay():
			_menu._show_menu_popup()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _map._campaign_room_input_is_blocked() and not _map._campaign_click_hits_real_button():
			var section := _map._campaign_section_at_position(event.position)
			if section != "":
				var viewport := get_viewport()
				_on_section_button(section)
				if viewport != null:
					viewport.set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var cancelled := _try_close_top_overlay()
		if cancelled:
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()

## Создаёт полупрозрачный оверлей на весь экран.
func _make_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	overlay.add_child(bg)
	return overlay


## Создаёт центрированную панель с заголовком.
func _make_centered_panel(title_text: String, panel_size: Vector2) -> VBoxContainer:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_overlay.add_child(wrapper)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	wrapper.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vb)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var sep := HSeparator.new()
	vb.add_child(sep)

	return vb


func _close_dialog() -> void:
	if _dialog_overlay != null and is_instance_valid(_dialog_overlay):
		_dialog_overlay.queue_free()
		_dialog_overlay = null


## Показывает краткое уведомление по центру экрана, исчезает через 1.5 сек.
func _show_notification(text: String) -> void:
	var notif := Label.new()
	notif.text = text
	notif.set_anchors_preset(Control.PRESET_CENTER)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notif.add_theme_font_size_override("font_size", 28)
	notif.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	notif.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	notif.add_theme_constant_override("shadow_offset_x", 2)
	notif.add_theme_constant_override("shadow_offset_y", 2)
	# Подложка.
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.custom_minimum_size = Vector2(360, 70)
	bg.modulate.a = 0.0
	bg.add_child(notif)
	# Растягиваем лейбл внутри подложки.
	notif.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Плавное появление и исчезновение.
	var t := create_tween()
	t.tween_property(bg, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.3)
	t.tween_property(bg, "modulate:a", 0.0, 0.4)
	t.tween_callback(bg.queue_free)


# ════════════════════════════════════════════════════════════
#  Страница бога (двойной клик на карточке)
# ════════════════════════════════════════════════════════════

func _make_stat_icon_row(stat_key: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = _STAT_ICON_SIZE
	icon.size = _STAT_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = str(_STAT_ICON_TOOLTIPS.get(stat_key, ""))
	var path := str(_STAT_ICON_PATHS.get(stat_key, ""))
	if path != "" and ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	row.add_child(icon)
	var lbl := Label.new()
	lbl.text = value_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row

## Иконка мыслей + число — используется вместо текста "N мыслей" в окнах создания
## артефакта, где количество мыслей должно отображаться только иконкой.
func _make_thoughts_icon_row(amount: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var res = load(THOUGHTS_PATH)
	if res != null and res.icon != null:
		icon.texture = res.icon
	row.add_child(icon)
	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)
	return row

const _EQUIP_SLOT_NAMES := ["Оружие", "Броня", "Безделушка"]
