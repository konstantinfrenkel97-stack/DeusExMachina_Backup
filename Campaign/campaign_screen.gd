extends Control
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
const STAT_ICON_TOOLTIP_BUTTON_SCRIPT := preload("res://stat_icon_tooltip_button.gd")
const CAMPAIGN_BACKGROUND_PATH := "res://Background/Campaign_Background.png"
const _ABILITY_ICON_BUTTON_SIZE := Vector2(58.0, 58.0)
const CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT := 96.0
const ROSTER_BOTTOM_GAP := 10.0
const ROSTER_Z_INDEX := 80
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
var _campaign_bottom_bar: ColorRect
var _campaign_pages_label: Label
var _campaign_hover_section: String = ""
var _campaign_room_mask_images: Dictionary = {}
var _campaign_room_mask_bounds_cache: Dictionary = {}

# Кнопка вызова меню (верхний левый угол).
var _menu_button: Button
# Всплывающее меню.
var _menu_popup: PopupPanel
# Диалог сохранения/загрузки (оверлей).
var _dialog_overlay: Control

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
	"Природа|Природа": "res://Gods/Duna/Duna.tres",
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
const SUMMON_DIALOGUE_DIR := "res://Dialogues/Gods_dialogue"
var _current_god_path: String = ""
var _current_god_res: CharacterResource
# Панель инвентаря справа (показывается при клике на слот).
var _inventory_side: VBoxContainer
# Текущий тип слота экипировки (0=оружие, 1=броня, 2=безделушка).
var _current_slot_type: int = -1

# ── Ростер богов внизу (1 ряд из 16 квадратов) ──
const ROSTER_COLUMNS := 16
const ROSTER_ROWS := 1
var _roster_grid: GridContainer
var _roster_slots: Array = []           # Array[GodRosterSlot] — 16 квадратов
var _roster_order: Array[String] = []   # Расположение: путь бога или "" (16 элементов)

# Сигнал, который экран может发射ать при изменении (на будущее).


func _ready() -> void:
	_build_ui()
	_build_menu()
	# По умолчанию ни одна кнопка-раздел не активна (содержимое пустое).
	# Ростер богов обновляется автоматически при изменении CampaignState.
	if not CampaignState.roster_changed.is_connected(_refresh_roster):
		CampaignState.roster_changed.connect(_refresh_roster)
	_refresh_roster()


# ════════════════════════════════════════════════════════════
#  Построение интерфейса
# ════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_build_campaign_background()
	_build_campaign_room_hit_layer()
	_build_campaign_bottom_bar()

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

	_build_god_roster(root_vb)



func _build_campaign_background() -> void:
	_campaign_background_rect = TextureRect.new()
	_campaign_background_rect.texture = load(CAMPAIGN_BACKGROUND_PATH) as Texture2D
	_campaign_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_campaign_background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_campaign_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_background_rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_campaign_background_rect)
	call_deferred("_layout_campaign_map")


func _build_campaign_room_hit_layer() -> void:
	_campaign_room_hit_layer = Control.new()
	_campaign_room_hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_room_hit_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_campaign_room_hit_layer.z_index = 20
	add_child(_campaign_room_hit_layer)

	_campaign_hover_fill = TextureRect.new()
	_campaign_hover_fill.visible = false
	_campaign_hover_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_campaign_hover_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_campaign_hover_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_room_hit_layer.add_child(_campaign_hover_fill)

	_campaign_hover_label = Label.new()
	_campaign_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_hover_label.visible = false
	_campaign_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_hover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_campaign_hover_label.add_theme_font_size_override("font_size", 26)
	_campaign_hover_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_campaign_hover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_campaign_hover_label.add_theme_constant_override("shadow_offset_x", 2)
	_campaign_hover_label.add_theme_constant_override("shadow_offset_y", 2)
	_campaign_room_hit_layer.add_child(_campaign_hover_label)
	call_deferred("_layout_campaign_map")

func _build_campaign_bottom_bar() -> void:
	_campaign_bottom_bar = ColorRect.new()
	_campaign_bottom_bar.color = Color.BLACK
	_campaign_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_bottom_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_campaign_bottom_bar.z_index = 30
	add_child(_campaign_bottom_bar)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 10)
	_campaign_bottom_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	_build_currency_bar(row)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var pages_box := HBoxContainer.new()
	pages_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pages_box.add_theme_constant_override("separation", 8)
	row.add_child(pages_box)

	var pages_title := Label.new()
	pages_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages_title.text = "Страницы"
	pages_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pages_title.add_theme_font_size_override("font_size", 22)
	pages_box.add_child(pages_title)

	_campaign_pages_label = Label.new()
	_campaign_pages_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_campaign_pages_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_campaign_pages_label.add_theme_font_size_override("font_size", 22)
	pages_box.add_child(_campaign_pages_label)
	_refresh_pages()


func _campaign_map_point(x: float, y: float) -> Vector2:
	return Vector2(x / 1681.0, y / 936.0)


func _campaign_room_defs() -> Array[Dictionary]:
	return [
		{"section": "Бесконечная библиотека", "mask": "res://Background/Campaign_Hover_library.png", "points": [
			_campaign_map_point(119, 74), _campaign_map_point(118, 75), _campaign_map_point(116, 76), 
			_campaign_map_point(115, 77), _campaign_map_point(113, 78), _campaign_map_point(112, 79), 
			_campaign_map_point(110, 80), _campaign_map_point(109, 81), _campaign_map_point(107, 82), 
			_campaign_map_point(106, 83), _campaign_map_point(105, 84), _campaign_map_point(103, 85), 
			_campaign_map_point(102, 86), _campaign_map_point(100, 87), _campaign_map_point(99, 88), 
			_campaign_map_point(98, 89), _campaign_map_point(96, 90), _campaign_map_point(95, 91), 
			_campaign_map_point(94, 92), _campaign_map_point(92, 93), _campaign_map_point(91, 94), 
			_campaign_map_point(90, 95), _campaign_map_point(88, 96), _campaign_map_point(87, 97), 
			_campaign_map_point(86, 98), _campaign_map_point(85, 99), _campaign_map_point(84, 100), 
			_campaign_map_point(83, 101), _campaign_map_point(82, 102), _campaign_map_point(81, 103), 
			_campaign_map_point(79, 104), _campaign_map_point(78, 105), _campaign_map_point(77, 106), 
			_campaign_map_point(76, 107), _campaign_map_point(75, 108), _campaign_map_point(74, 109), 
			_campaign_map_point(73, 110), _campaign_map_point(72, 111), _campaign_map_point(71, 112), 
			_campaign_map_point(70, 113), _campaign_map_point(69, 114), _campaign_map_point(68, 115), 
			_campaign_map_point(67, 116), _campaign_map_point(66, 117), _campaign_map_point(66, 118), 
			_campaign_map_point(65, 119), _campaign_map_point(64, 120), _campaign_map_point(63, 121), 
			_campaign_map_point(62, 122), _campaign_map_point(61, 123), _campaign_map_point(60, 124), 
			_campaign_map_point(59, 125), _campaign_map_point(58, 126), _campaign_map_point(58, 127), 
			_campaign_map_point(57, 128), _campaign_map_point(56, 129), _campaign_map_point(56, 130), 
			_campaign_map_point(55, 131), _campaign_map_point(54, 132), _campaign_map_point(53, 133), 
			_campaign_map_point(52, 134), _campaign_map_point(51, 135), _campaign_map_point(50, 136), 
			_campaign_map_point(50, 137), _campaign_map_point(49, 138), _campaign_map_point(49, 139), 
			_campaign_map_point(48, 140), _campaign_map_point(48, 141), _campaign_map_point(47, 142), 
			_campaign_map_point(46, 143), _campaign_map_point(46, 144), _campaign_map_point(45, 145), 
			_campaign_map_point(44, 146), _campaign_map_point(44, 147), _campaign_map_point(42, 148), 
			_campaign_map_point(42, 149), _campaign_map_point(41, 150), _campaign_map_point(40, 151), 
			_campaign_map_point(40, 152), _campaign_map_point(39, 153), _campaign_map_point(39, 154), 
			_campaign_map_point(38, 155), _campaign_map_point(38, 156), _campaign_map_point(37, 157), 
			_campaign_map_point(36, 158), _campaign_map_point(36, 159), _campaign_map_point(35, 160), 
			_campaign_map_point(35, 161), _campaign_map_point(34, 162), _campaign_map_point(34, 163), 
			_campaign_map_point(33, 164), _campaign_map_point(32, 165), _campaign_map_point(32, 166), 
			_campaign_map_point(31, 167), _campaign_map_point(31, 168), _campaign_map_point(30, 169), 
			_campaign_map_point(30, 170), _campaign_map_point(29, 171), _campaign_map_point(29, 172), 
			_campaign_map_point(29, 173), _campaign_map_point(28, 174), _campaign_map_point(28, 175), 
			_campaign_map_point(27, 176), _campaign_map_point(27, 177), _campaign_map_point(26, 178), 
			_campaign_map_point(26, 179), _campaign_map_point(26, 180), _campaign_map_point(25, 181), 
			_campaign_map_point(25, 182), _campaign_map_point(24, 183), _campaign_map_point(24, 184), 
			_campaign_map_point(24, 185), _campaign_map_point(23, 186), _campaign_map_point(23, 187), 
			_campaign_map_point(23, 188), _campaign_map_point(22, 189), _campaign_map_point(22, 190), 
			_campaign_map_point(22, 191), _campaign_map_point(21, 192), _campaign_map_point(21, 193), 
			_campaign_map_point(21, 194), _campaign_map_point(20, 195), _campaign_map_point(20, 196), 
			_campaign_map_point(20, 197), _campaign_map_point(20, 198), _campaign_map_point(19, 199), 
			_campaign_map_point(19, 200), _campaign_map_point(19, 201), _campaign_map_point(19, 202), 
			_campaign_map_point(18, 203), _campaign_map_point(18, 204), _campaign_map_point(18, 205), 
			_campaign_map_point(19, 206), _campaign_map_point(19, 207), _campaign_map_point(19, 208), 
			_campaign_map_point(19, 209), _campaign_map_point(19, 210), _campaign_map_point(19, 211), 
			_campaign_map_point(19, 212), _campaign_map_point(19, 213), _campaign_map_point(19, 214), 
			_campaign_map_point(19, 215), _campaign_map_point(19, 216), _campaign_map_point(17, 217), 
			_campaign_map_point(15, 218), _campaign_map_point(14, 219), _campaign_map_point(14, 220), 
			_campaign_map_point(14, 221), _campaign_map_point(14, 222), _campaign_map_point(14, 223), 
			_campaign_map_point(14, 224), _campaign_map_point(14, 225), _campaign_map_point(14, 226), 
			_campaign_map_point(14, 227), _campaign_map_point(14, 228), _campaign_map_point(14, 229), 
			_campaign_map_point(14, 230), _campaign_map_point(14, 231), _campaign_map_point(14, 232), 
			_campaign_map_point(14, 233), _campaign_map_point(14, 234), _campaign_map_point(14, 235), 
			_campaign_map_point(14, 236), _campaign_map_point(14, 237), _campaign_map_point(14, 238), 
			_campaign_map_point(14, 239), _campaign_map_point(14, 240), _campaign_map_point(14, 241), 
			_campaign_map_point(14, 242), _campaign_map_point(14, 243), _campaign_map_point(14, 244), 
			_campaign_map_point(14, 245), _campaign_map_point(14, 246), _campaign_map_point(14, 247), 
			_campaign_map_point(14, 248), _campaign_map_point(14, 249), _campaign_map_point(14, 250), 
			_campaign_map_point(14, 251), _campaign_map_point(14, 252), _campaign_map_point(14, 253), 
			_campaign_map_point(14, 254), _campaign_map_point(14, 255), _campaign_map_point(14, 256), 
			_campaign_map_point(14, 257), _campaign_map_point(14, 258), _campaign_map_point(14, 259), 
			_campaign_map_point(14, 260), _campaign_map_point(14, 261), _campaign_map_point(14, 262), 
			_campaign_map_point(14, 263), _campaign_map_point(14, 264), _campaign_map_point(14, 265), 
			_campaign_map_point(14, 266), _campaign_map_point(14, 267), _campaign_map_point(14, 268), 
			_campaign_map_point(14, 269), _campaign_map_point(14, 270), _campaign_map_point(14, 271), 
			_campaign_map_point(14, 272), _campaign_map_point(14, 273), _campaign_map_point(14, 274), 
			_campaign_map_point(14, 275), _campaign_map_point(14, 276), _campaign_map_point(14, 277), 
			_campaign_map_point(14, 278), _campaign_map_point(14, 279), _campaign_map_point(14, 280), 
			_campaign_map_point(14, 281), _campaign_map_point(14, 282), _campaign_map_point(14, 283), 
			_campaign_map_point(14, 284), _campaign_map_point(14, 285), _campaign_map_point(14, 286), 
			_campaign_map_point(14, 287), _campaign_map_point(14, 288), _campaign_map_point(14, 289), 
			_campaign_map_point(14, 290), _campaign_map_point(14, 291), _campaign_map_point(14, 292), 
			_campaign_map_point(14, 293), _campaign_map_point(14, 294), _campaign_map_point(14, 295), 
			_campaign_map_point(14, 296), _campaign_map_point(14, 297), _campaign_map_point(14, 298), 
			_campaign_map_point(14, 299), _campaign_map_point(14, 300), _campaign_map_point(14, 301), 
			_campaign_map_point(14, 302), _campaign_map_point(14, 303), _campaign_map_point(14, 304), 
			_campaign_map_point(14, 305), _campaign_map_point(14, 306), _campaign_map_point(14, 307), 
			_campaign_map_point(14, 308), _campaign_map_point(14, 309), _campaign_map_point(14, 310), 
			_campaign_map_point(14, 311), _campaign_map_point(14, 312), _campaign_map_point(14, 313), 
			_campaign_map_point(14, 314), _campaign_map_point(14, 315), _campaign_map_point(14, 316), 
			_campaign_map_point(14, 317), _campaign_map_point(14, 318), _campaign_map_point(14, 319), 
			_campaign_map_point(14, 320), _campaign_map_point(14, 321), _campaign_map_point(14, 322), 
			_campaign_map_point(14, 323), _campaign_map_point(14, 324), _campaign_map_point(14, 325), 
			_campaign_map_point(14, 326), _campaign_map_point(14, 327), _campaign_map_point(14, 328), 
			_campaign_map_point(15, 329), _campaign_map_point(15, 330), _campaign_map_point(15, 331), 
			_campaign_map_point(15, 332), _campaign_map_point(15, 333), _campaign_map_point(15, 334), 
			_campaign_map_point(15, 335), _campaign_map_point(15, 336), _campaign_map_point(15, 337), 
			_campaign_map_point(15, 338), _campaign_map_point(15, 339), _campaign_map_point(14, 340), 
			_campaign_map_point(15, 341), _campaign_map_point(15, 342), _campaign_map_point(15, 343), 
			_campaign_map_point(15, 344), _campaign_map_point(15, 345), _campaign_map_point(15, 346), 
			_campaign_map_point(15, 347), _campaign_map_point(15, 348), _campaign_map_point(15, 349), 
			_campaign_map_point(15, 350), _campaign_map_point(15, 351), _campaign_map_point(15, 352), 
			_campaign_map_point(15, 353), _campaign_map_point(15, 354), _campaign_map_point(15, 355), 
			_campaign_map_point(15, 356), _campaign_map_point(15, 357), _campaign_map_point(15, 358), 
			_campaign_map_point(15, 359), _campaign_map_point(15, 360), _campaign_map_point(15, 361), 
			_campaign_map_point(15, 362), _campaign_map_point(15, 363), _campaign_map_point(15, 364), 
			_campaign_map_point(15, 365), _campaign_map_point(14, 366), _campaign_map_point(14, 367), 
			_campaign_map_point(14, 368), _campaign_map_point(14, 369), _campaign_map_point(14, 370), 
			_campaign_map_point(14, 371), _campaign_map_point(14, 372), _campaign_map_point(14, 373), 
			_campaign_map_point(14, 374), _campaign_map_point(14, 375), _campaign_map_point(14, 376), 
			_campaign_map_point(14, 377), _campaign_map_point(14, 378), _campaign_map_point(14, 379), 
			_campaign_map_point(14, 380), _campaign_map_point(15, 381), _campaign_map_point(15, 382), 
			_campaign_map_point(15, 383), _campaign_map_point(15, 384), _campaign_map_point(15, 385), 
			_campaign_map_point(15, 386), _campaign_map_point(15, 387), _campaign_map_point(15, 388), 
			_campaign_map_point(15, 389), _campaign_map_point(15, 390), _campaign_map_point(15, 391), 
			_campaign_map_point(15, 392), _campaign_map_point(15, 393), _campaign_map_point(15, 394), 
			_campaign_map_point(14, 395), _campaign_map_point(14, 396), _campaign_map_point(14, 397), 
			_campaign_map_point(14, 398), _campaign_map_point(14, 399), _campaign_map_point(14, 400), 
			_campaign_map_point(14, 401), _campaign_map_point(14, 402), _campaign_map_point(14, 403), 
			_campaign_map_point(14, 404), _campaign_map_point(14, 405), _campaign_map_point(14, 406), 
			_campaign_map_point(14, 407), _campaign_map_point(14, 408), _campaign_map_point(14, 409), 
			_campaign_map_point(14, 410), _campaign_map_point(14, 411), _campaign_map_point(14, 412), 
			_campaign_map_point(14, 413), _campaign_map_point(14, 414), _campaign_map_point(14, 415), 
			_campaign_map_point(14, 416), _campaign_map_point(14, 417), _campaign_map_point(14, 418), 
			_campaign_map_point(14, 419), _campaign_map_point(14, 420), _campaign_map_point(14, 421), 
			_campaign_map_point(14, 422), _campaign_map_point(14, 423), _campaign_map_point(14, 424), 
			_campaign_map_point(14, 425), _campaign_map_point(14, 426), _campaign_map_point(14, 427), 
			_campaign_map_point(14, 428), _campaign_map_point(14, 429), _campaign_map_point(15, 430), 
			_campaign_map_point(15, 431), _campaign_map_point(15, 432), _campaign_map_point(15, 433), 
			_campaign_map_point(15, 434), _campaign_map_point(15, 435), _campaign_map_point(15, 436), 
			_campaign_map_point(15, 437), _campaign_map_point(15, 438), _campaign_map_point(15, 439), 
			_campaign_map_point(15, 440), _campaign_map_point(15, 441), _campaign_map_point(15, 442), 
			_campaign_map_point(15, 443), _campaign_map_point(15, 444), _campaign_map_point(15, 445), 
			_campaign_map_point(15, 446), _campaign_map_point(15, 447), _campaign_map_point(15, 448), 
			_campaign_map_point(15, 449), _campaign_map_point(15, 450), _campaign_map_point(15, 451), 
			_campaign_map_point(15, 452), _campaign_map_point(15, 453), _campaign_map_point(15, 454), 
			_campaign_map_point(15, 455), _campaign_map_point(15, 456), _campaign_map_point(15, 457), 
			_campaign_map_point(15, 458), _campaign_map_point(15, 459), _campaign_map_point(15, 460), 
			_campaign_map_point(15, 461), _campaign_map_point(15, 462), _campaign_map_point(15, 463), 
			_campaign_map_point(15, 464), _campaign_map_point(15, 465), _campaign_map_point(15, 466), 
			_campaign_map_point(15, 467), _campaign_map_point(15, 468), _campaign_map_point(15, 469), 
			_campaign_map_point(15, 470), _campaign_map_point(15, 471), _campaign_map_point(15, 472), 
			_campaign_map_point(15, 473), _campaign_map_point(15, 474), _campaign_map_point(15, 475), 
			_campaign_map_point(15, 476), _campaign_map_point(15, 477), _campaign_map_point(15, 478), 
			_campaign_map_point(15, 479), _campaign_map_point(15, 480), _campaign_map_point(15, 481), 
			_campaign_map_point(15, 482), _campaign_map_point(15, 483), _campaign_map_point(15, 484), 
			_campaign_map_point(15, 485), _campaign_map_point(14, 486), _campaign_map_point(14, 487), 
			_campaign_map_point(14, 488), _campaign_map_point(14, 489), _campaign_map_point(14, 490), 
			_campaign_map_point(14, 491), _campaign_map_point(14, 492), _campaign_map_point(14, 493), 
			_campaign_map_point(14, 494), _campaign_map_point(15, 495), _campaign_map_point(15, 496), 
			_campaign_map_point(15, 497), _campaign_map_point(15, 498), _campaign_map_point(15, 499), 
			_campaign_map_point(15, 500), _campaign_map_point(15, 501), _campaign_map_point(15, 502), 
			_campaign_map_point(15, 503), _campaign_map_point(15, 504), _campaign_map_point(15, 505), 
			_campaign_map_point(15, 506), _campaign_map_point(15, 507), _campaign_map_point(15, 508), 
			_campaign_map_point(15, 509), _campaign_map_point(15, 510), _campaign_map_point(15, 511), 
			_campaign_map_point(15, 512), _campaign_map_point(15, 513), _campaign_map_point(15, 514), 
			_campaign_map_point(15, 515), _campaign_map_point(15, 516), _campaign_map_point(14, 517), 
			_campaign_map_point(14, 518), _campaign_map_point(14, 519), _campaign_map_point(14, 520), 
			_campaign_map_point(14, 521), _campaign_map_point(14, 522), _campaign_map_point(14, 523), 
			_campaign_map_point(14, 524), _campaign_map_point(14, 525), _campaign_map_point(14, 526), 
			_campaign_map_point(14, 527), _campaign_map_point(14, 528), _campaign_map_point(14, 529), 
			_campaign_map_point(14, 530), _campaign_map_point(15, 531), _campaign_map_point(15, 532), 
			_campaign_map_point(15, 533), _campaign_map_point(15, 534), _campaign_map_point(15, 535), 
			_campaign_map_point(15, 536), _campaign_map_point(15, 537), _campaign_map_point(15, 538), 
			_campaign_map_point(15, 539), _campaign_map_point(15, 540), _campaign_map_point(15, 541), 
			_campaign_map_point(15, 542), _campaign_map_point(15, 543), _campaign_map_point(15, 544), 
			_campaign_map_point(15, 545), _campaign_map_point(15, 546), _campaign_map_point(15, 547), 
			_campaign_map_point(15, 548), _campaign_map_point(15, 549), _campaign_map_point(15, 550), 
			_campaign_map_point(15, 551), _campaign_map_point(15, 552), _campaign_map_point(15, 553), 
			_campaign_map_point(15, 554), _campaign_map_point(15, 555), _campaign_map_point(15, 556), 
			_campaign_map_point(15, 557), _campaign_map_point(15, 558), _campaign_map_point(15, 559), 
			_campaign_map_point(15, 560), _campaign_map_point(15, 561), _campaign_map_point(15, 562), 
			_campaign_map_point(15, 563), _campaign_map_point(15, 564), _campaign_map_point(15, 565), 
			_campaign_map_point(15, 566), _campaign_map_point(15, 567), _campaign_map_point(15, 568), 
			_campaign_map_point(15, 569), _campaign_map_point(15, 570), _campaign_map_point(15, 571), 
			_campaign_map_point(15, 572), _campaign_map_point(15, 573), _campaign_map_point(15, 574), 
			_campaign_map_point(15, 575), _campaign_map_point(15, 576), _campaign_map_point(15, 577), 
			_campaign_map_point(15, 578), _campaign_map_point(15, 579), _campaign_map_point(15, 580), 
			_campaign_map_point(15, 581), _campaign_map_point(15, 582), _campaign_map_point(15, 583), 
			_campaign_map_point(15, 584), _campaign_map_point(15, 585), _campaign_map_point(15, 586), 
			_campaign_map_point(15, 587), _campaign_map_point(15, 588), _campaign_map_point(15, 589), 
			_campaign_map_point(15, 590), _campaign_map_point(15, 591), _campaign_map_point(15, 592), 
			_campaign_map_point(15, 593), _campaign_map_point(15, 594), _campaign_map_point(15, 595), 
			_campaign_map_point(15, 596), _campaign_map_point(15, 597), _campaign_map_point(15, 598), 
			_campaign_map_point(15, 599), _campaign_map_point(15, 600), _campaign_map_point(15, 601), 
			_campaign_map_point(15, 602), _campaign_map_point(15, 603), _campaign_map_point(15, 604), 
			_campaign_map_point(15, 605), _campaign_map_point(15, 606), _campaign_map_point(15, 607), 
			_campaign_map_point(15, 608), _campaign_map_point(15, 609), _campaign_map_point(15, 610), 
			_campaign_map_point(15, 611), _campaign_map_point(15, 612), _campaign_map_point(15, 613), 
			_campaign_map_point(15, 614), _campaign_map_point(15, 615), _campaign_map_point(15, 616), 
			_campaign_map_point(15, 617), _campaign_map_point(15, 618), _campaign_map_point(15, 619), 
			_campaign_map_point(15, 620), _campaign_map_point(15, 621), _campaign_map_point(15, 622), 
			_campaign_map_point(15, 623), _campaign_map_point(15, 624), _campaign_map_point(15, 625), 
			_campaign_map_point(15, 626), _campaign_map_point(15, 627), _campaign_map_point(15, 628), 
			_campaign_map_point(15, 629), _campaign_map_point(15, 630), _campaign_map_point(15, 631), 
			_campaign_map_point(15, 632), _campaign_map_point(15, 633), _campaign_map_point(15, 634), 
			_campaign_map_point(15, 635), _campaign_map_point(15, 636), _campaign_map_point(15, 637), 
			_campaign_map_point(15, 638), _campaign_map_point(15, 639), _campaign_map_point(15, 640), 
			_campaign_map_point(15, 641), _campaign_map_point(15, 642), _campaign_map_point(15, 643), 
			_campaign_map_point(15, 644), _campaign_map_point(15, 645), _campaign_map_point(15, 646), 
			_campaign_map_point(15, 647), _campaign_map_point(15, 648), _campaign_map_point(15, 649), 
			_campaign_map_point(15, 650), _campaign_map_point(15, 651), _campaign_map_point(15, 652), 
			_campaign_map_point(15, 653), _campaign_map_point(15, 654), _campaign_map_point(15, 655), 
			_campaign_map_point(15, 656), _campaign_map_point(15, 657), _campaign_map_point(15, 658), 
			_campaign_map_point(15, 659), _campaign_map_point(15, 660), _campaign_map_point(15, 661), 
			_campaign_map_point(15, 662), _campaign_map_point(15, 663), _campaign_map_point(15, 664), 
			_campaign_map_point(15, 665), _campaign_map_point(15, 666), _campaign_map_point(15, 667), 
			_campaign_map_point(15, 668), _campaign_map_point(15, 669), _campaign_map_point(15, 670), 
			_campaign_map_point(15, 671), _campaign_map_point(15, 672), _campaign_map_point(15, 673), 
			_campaign_map_point(15, 674), _campaign_map_point(15, 675), _campaign_map_point(15, 676), 
			_campaign_map_point(15, 677), _campaign_map_point(15, 678), _campaign_map_point(15, 679), 
			_campaign_map_point(15, 680), _campaign_map_point(15, 681), _campaign_map_point(15, 682), 
			_campaign_map_point(15, 683), _campaign_map_point(15, 684), _campaign_map_point(15, 685), 
			_campaign_map_point(15, 686), _campaign_map_point(15, 687), _campaign_map_point(15, 688), 
			_campaign_map_point(15, 689), _campaign_map_point(15, 690), _campaign_map_point(15, 691), 
			_campaign_map_point(15, 692), _campaign_map_point(15, 693), _campaign_map_point(15, 694), 
			_campaign_map_point(15, 695), _campaign_map_point(15, 696), _campaign_map_point(15, 697), 
			_campaign_map_point(15, 698), _campaign_map_point(15, 699), _campaign_map_point(15, 700), 
			_campaign_map_point(15, 701), _campaign_map_point(15, 702), _campaign_map_point(15, 703), 
			_campaign_map_point(15, 704), _campaign_map_point(15, 705), _campaign_map_point(15, 706), 
			_campaign_map_point(15, 707), _campaign_map_point(15, 708), _campaign_map_point(15, 709), 
			_campaign_map_point(15, 710), _campaign_map_point(15, 711), _campaign_map_point(15, 712), 
			_campaign_map_point(15, 713), _campaign_map_point(15, 714), _campaign_map_point(15, 715), 
			_campaign_map_point(15, 716), _campaign_map_point(15, 717), _campaign_map_point(15, 718), 
			_campaign_map_point(15, 719), _campaign_map_point(15, 720), _campaign_map_point(15, 721), 
			_campaign_map_point(15, 722), _campaign_map_point(15, 723), _campaign_map_point(15, 724), 
			_campaign_map_point(15, 725), _campaign_map_point(15, 726), _campaign_map_point(15, 727), 
			_campaign_map_point(15, 728), _campaign_map_point(15, 729), _campaign_map_point(15, 730), 
			_campaign_map_point(15, 731), _campaign_map_point(15, 732), _campaign_map_point(15, 733), 
			_campaign_map_point(15, 734), _campaign_map_point(15, 735), _campaign_map_point(15, 736), 
			_campaign_map_point(15, 737), _campaign_map_point(15, 738), _campaign_map_point(15, 739), 
			_campaign_map_point(15, 740), _campaign_map_point(15, 741), _campaign_map_point(15, 742), 
			_campaign_map_point(15, 743), _campaign_map_point(15, 744), _campaign_map_point(15, 745), 
			_campaign_map_point(15, 746), _campaign_map_point(15, 747), _campaign_map_point(15, 748), 
			_campaign_map_point(15, 749), _campaign_map_point(15, 750), _campaign_map_point(15, 751), 
			_campaign_map_point(17, 752), _campaign_map_point(17, 753), _campaign_map_point(17, 754), 
			_campaign_map_point(17, 755), _campaign_map_point(17, 756), _campaign_map_point(17, 757), 
			_campaign_map_point(17, 758), _campaign_map_point(17, 759), _campaign_map_point(17, 760), 
			_campaign_map_point(17, 761), _campaign_map_point(17, 762), _campaign_map_point(16, 763), 
			_campaign_map_point(16, 764), _campaign_map_point(16, 765), _campaign_map_point(16, 766), 
			_campaign_map_point(16, 767), _campaign_map_point(16, 768), _campaign_map_point(16, 769), 
			_campaign_map_point(16, 770), _campaign_map_point(16, 771), _campaign_map_point(16, 772), 
			_campaign_map_point(16, 773), _campaign_map_point(16, 774), _campaign_map_point(16, 775), 
			_campaign_map_point(16, 776), _campaign_map_point(16, 777), _campaign_map_point(16, 778), 
			_campaign_map_point(16, 779), _campaign_map_point(16, 780), _campaign_map_point(16, 781), 
			_campaign_map_point(16, 782), _campaign_map_point(16, 783), _campaign_map_point(16, 784), 
			_campaign_map_point(28, 784), _campaign_map_point(38, 783), _campaign_map_point(57, 782), 
			_campaign_map_point(66, 781), _campaign_map_point(75, 780), _campaign_map_point(89, 779), 
			_campaign_map_point(99, 778), _campaign_map_point(108, 777), _campaign_map_point(115, 776), 
			_campaign_map_point(124, 775), _campaign_map_point(135, 774), _campaign_map_point(151, 773), 
			_campaign_map_point(154, 772), _campaign_map_point(165, 771), _campaign_map_point(180, 770), 
			_campaign_map_point(191, 769), _campaign_map_point(201, 768), _campaign_map_point(213, 767), 
			_campaign_map_point(220, 766), _campaign_map_point(226, 765), _campaign_map_point(234, 764), 
			_campaign_map_point(238, 763), _campaign_map_point(239, 762), _campaign_map_point(240, 761), 
			_campaign_map_point(240, 760), _campaign_map_point(241, 759), _campaign_map_point(241, 758), 
			_campaign_map_point(242, 757), _campaign_map_point(242, 756), _campaign_map_point(242, 755), 
			_campaign_map_point(242, 754), _campaign_map_point(242, 753), _campaign_map_point(242, 752), 
			_campaign_map_point(242, 751), _campaign_map_point(242, 750), _campaign_map_point(242, 749), 
			_campaign_map_point(242, 748), _campaign_map_point(242, 747), _campaign_map_point(242, 746), 
			_campaign_map_point(242, 745), _campaign_map_point(242, 744), _campaign_map_point(242, 743), 
			_campaign_map_point(242, 742), _campaign_map_point(242, 741), _campaign_map_point(242, 740), 
			_campaign_map_point(242, 739), _campaign_map_point(242, 738), _campaign_map_point(242, 737), 
			_campaign_map_point(242, 736), _campaign_map_point(242, 735), _campaign_map_point(242, 734), 
			_campaign_map_point(242, 733), _campaign_map_point(242, 732), _campaign_map_point(242, 731), 
			_campaign_map_point(242, 730), _campaign_map_point(242, 729), _campaign_map_point(242, 728), 
			_campaign_map_point(242, 727), _campaign_map_point(242, 726), _campaign_map_point(243, 725), 
			_campaign_map_point(243, 724), _campaign_map_point(243, 723), _campaign_map_point(244, 722), 
			_campaign_map_point(244, 721), _campaign_map_point(244, 720), _campaign_map_point(244, 719), 
			_campaign_map_point(244, 718), _campaign_map_point(244, 717), _campaign_map_point(244, 716), 
			_campaign_map_point(244, 715), _campaign_map_point(244, 714), _campaign_map_point(244, 713), 
			_campaign_map_point(244, 712), _campaign_map_point(244, 711), _campaign_map_point(244, 710), 
			_campaign_map_point(244, 709), _campaign_map_point(243, 708), _campaign_map_point(243, 707), 
			_campaign_map_point(243, 706), _campaign_map_point(243, 705), _campaign_map_point(243, 704), 
			_campaign_map_point(243, 703), _campaign_map_point(243, 702), _campaign_map_point(243, 701), 
			_campaign_map_point(243, 700), _campaign_map_point(243, 699), _campaign_map_point(243, 698), 
			_campaign_map_point(243, 697), _campaign_map_point(243, 696), _campaign_map_point(243, 695), 
			_campaign_map_point(243, 694), _campaign_map_point(243, 693), _campaign_map_point(243, 692), 
			_campaign_map_point(243, 691), _campaign_map_point(243, 690), _campaign_map_point(243, 689), 
			_campaign_map_point(243, 688), _campaign_map_point(243, 687), _campaign_map_point(243, 686), 
			_campaign_map_point(243, 685), _campaign_map_point(243, 684), _campaign_map_point(243, 683), 
			_campaign_map_point(243, 682), _campaign_map_point(243, 681), _campaign_map_point(243, 680), 
			_campaign_map_point(243, 679), _campaign_map_point(243, 678), _campaign_map_point(243, 677), 
			_campaign_map_point(243, 676), _campaign_map_point(243, 675), _campaign_map_point(243, 674), 
			_campaign_map_point(243, 673), _campaign_map_point(243, 672), _campaign_map_point(243, 671), 
			_campaign_map_point(243, 670), _campaign_map_point(243, 669), _campaign_map_point(243, 668), 
			_campaign_map_point(243, 667), _campaign_map_point(243, 666), _campaign_map_point(243, 665), 
			_campaign_map_point(243, 664), _campaign_map_point(243, 663), _campaign_map_point(243, 662), 
			_campaign_map_point(243, 661), _campaign_map_point(243, 660), _campaign_map_point(243, 659), 
			_campaign_map_point(243, 658), _campaign_map_point(243, 657), _campaign_map_point(244, 656), 
			_campaign_map_point(244, 655), _campaign_map_point(244, 654), _campaign_map_point(244, 653), 
			_campaign_map_point(244, 652), _campaign_map_point(244, 651), _campaign_map_point(244, 650), 
			_campaign_map_point(244, 649), _campaign_map_point(244, 648), _campaign_map_point(244, 647), 
			_campaign_map_point(244, 646), _campaign_map_point(244, 645), _campaign_map_point(244, 644), 
			_campaign_map_point(244, 643), _campaign_map_point(244, 642), _campaign_map_point(244, 641), 
			_campaign_map_point(244, 640), _campaign_map_point(244, 639), _campaign_map_point(244, 638), 
			_campaign_map_point(244, 637), _campaign_map_point(244, 636), _campaign_map_point(244, 635), 
			_campaign_map_point(244, 634), _campaign_map_point(244, 633), _campaign_map_point(244, 632), 
			_campaign_map_point(244, 631), _campaign_map_point(244, 630), _campaign_map_point(244, 629), 
			_campaign_map_point(244, 628), _campaign_map_point(244, 627), _campaign_map_point(244, 626), 
			_campaign_map_point(244, 625), _campaign_map_point(244, 624), _campaign_map_point(244, 623), 
			_campaign_map_point(244, 622), _campaign_map_point(244, 621), _campaign_map_point(244, 620), 
			_campaign_map_point(244, 619), _campaign_map_point(244, 618), _campaign_map_point(244, 617), 
			_campaign_map_point(244, 616), _campaign_map_point(244, 615), _campaign_map_point(244, 614), 
			_campaign_map_point(244, 613), _campaign_map_point(244, 612), _campaign_map_point(244, 611), 
			_campaign_map_point(244, 610), _campaign_map_point(244, 609), _campaign_map_point(244, 608), 
			_campaign_map_point(244, 607), _campaign_map_point(244, 606), _campaign_map_point(244, 605), 
			_campaign_map_point(244, 604), _campaign_map_point(243, 603), _campaign_map_point(243, 602), 
			_campaign_map_point(243, 601), _campaign_map_point(243, 600), _campaign_map_point(243, 599), 
			_campaign_map_point(243, 598), _campaign_map_point(243, 597), _campaign_map_point(243, 596), 
			_campaign_map_point(243, 595), _campaign_map_point(243, 594), _campaign_map_point(243, 593), 
			_campaign_map_point(243, 592), _campaign_map_point(243, 591), _campaign_map_point(243, 590), 
			_campaign_map_point(243, 589), _campaign_map_point(243, 588), _campaign_map_point(243, 587), 
			_campaign_map_point(243, 586), _campaign_map_point(243, 585), _campaign_map_point(243, 584), 
			_campaign_map_point(243, 583), _campaign_map_point(243, 582), _campaign_map_point(243, 581), 
			_campaign_map_point(243, 580), _campaign_map_point(243, 579), _campaign_map_point(243, 578), 
			_campaign_map_point(243, 577), _campaign_map_point(243, 576), _campaign_map_point(243, 575), 
			_campaign_map_point(243, 574), _campaign_map_point(243, 573), _campaign_map_point(243, 572), 
			_campaign_map_point(243, 571), _campaign_map_point(243, 570), _campaign_map_point(243, 569), 
			_campaign_map_point(243, 568), _campaign_map_point(243, 567), _campaign_map_point(243, 566), 
			_campaign_map_point(243, 565), _campaign_map_point(243, 564), _campaign_map_point(243, 563), 
			_campaign_map_point(243, 562), _campaign_map_point(243, 561), _campaign_map_point(243, 560), 
			_campaign_map_point(243, 559), _campaign_map_point(243, 558), _campaign_map_point(243, 557), 
			_campaign_map_point(243, 556), _campaign_map_point(243, 555), _campaign_map_point(243, 554), 
			_campaign_map_point(243, 553), _campaign_map_point(243, 552), _campaign_map_point(243, 551), 
			_campaign_map_point(243, 550), _campaign_map_point(243, 549), _campaign_map_point(243, 548), 
			_campaign_map_point(243, 547), _campaign_map_point(243, 546), _campaign_map_point(243, 545), 
			_campaign_map_point(243, 544), _campaign_map_point(243, 543), _campaign_map_point(243, 542), 
			_campaign_map_point(243, 541), _campaign_map_point(243, 540), _campaign_map_point(243, 539), 
			_campaign_map_point(243, 538), _campaign_map_point(243, 537), _campaign_map_point(243, 536), 
			_campaign_map_point(243, 535), _campaign_map_point(243, 534), _campaign_map_point(243, 533), 
			_campaign_map_point(243, 532), _campaign_map_point(243, 531), _campaign_map_point(243, 530), 
			_campaign_map_point(243, 529), _campaign_map_point(243, 528), _campaign_map_point(243, 527), 
			_campaign_map_point(243, 526), _campaign_map_point(243, 525), _campaign_map_point(243, 524), 
			_campaign_map_point(243, 523), _campaign_map_point(243, 522), _campaign_map_point(243, 521), 
			_campaign_map_point(243, 520), _campaign_map_point(243, 519), _campaign_map_point(243, 518), 
			_campaign_map_point(243, 517), _campaign_map_point(243, 516), _campaign_map_point(243, 515), 
			_campaign_map_point(243, 514), _campaign_map_point(243, 513), _campaign_map_point(243, 512), 
			_campaign_map_point(243, 511), _campaign_map_point(243, 510), _campaign_map_point(243, 509), 
			_campaign_map_point(243, 508), _campaign_map_point(243, 507), _campaign_map_point(243, 506), 
			_campaign_map_point(243, 505), _campaign_map_point(243, 504), _campaign_map_point(243, 503), 
			_campaign_map_point(243, 502), _campaign_map_point(243, 501), _campaign_map_point(243, 500), 
			_campaign_map_point(243, 499), _campaign_map_point(243, 498), _campaign_map_point(243, 497), 
			_campaign_map_point(243, 496), _campaign_map_point(243, 495), _campaign_map_point(243, 494), 
			_campaign_map_point(243, 493), _campaign_map_point(243, 492), _campaign_map_point(243, 491), 
			_campaign_map_point(243, 490), _campaign_map_point(243, 489), _campaign_map_point(243, 488), 
			_campaign_map_point(243, 487), _campaign_map_point(243, 486), _campaign_map_point(243, 485), 
			_campaign_map_point(243, 484), _campaign_map_point(243, 483), _campaign_map_point(243, 482), 
			_campaign_map_point(243, 481), _campaign_map_point(243, 480), _campaign_map_point(244, 479), 
			_campaign_map_point(244, 478), _campaign_map_point(244, 477), _campaign_map_point(244, 476), 
			_campaign_map_point(244, 475), _campaign_map_point(244, 474), _campaign_map_point(244, 473), 
			_campaign_map_point(244, 472), _campaign_map_point(244, 471), _campaign_map_point(244, 470), 
			_campaign_map_point(244, 469), _campaign_map_point(244, 468), _campaign_map_point(244, 467), 
			_campaign_map_point(244, 466), _campaign_map_point(244, 465), _campaign_map_point(244, 464), 
			_campaign_map_point(244, 463), _campaign_map_point(244, 462), _campaign_map_point(244, 461), 
			_campaign_map_point(244, 460), _campaign_map_point(244, 459), _campaign_map_point(244, 458), 
			_campaign_map_point(244, 457), _campaign_map_point(244, 456), _campaign_map_point(244, 455), 
			_campaign_map_point(244, 454), _campaign_map_point(244, 453), _campaign_map_point(244, 452), 
			_campaign_map_point(244, 451), _campaign_map_point(244, 450), _campaign_map_point(244, 449), 
			_campaign_map_point(244, 448), _campaign_map_point(244, 447), _campaign_map_point(244, 446), 
			_campaign_map_point(244, 445), _campaign_map_point(244, 444), _campaign_map_point(244, 443), 
			_campaign_map_point(244, 442), _campaign_map_point(244, 441), _campaign_map_point(244, 440), 
			_campaign_map_point(244, 439), _campaign_map_point(244, 438), _campaign_map_point(244, 437), 
			_campaign_map_point(244, 436), _campaign_map_point(244, 435), _campaign_map_point(244, 434), 
			_campaign_map_point(244, 433), _campaign_map_point(244, 432), _campaign_map_point(244, 431), 
			_campaign_map_point(244, 430), _campaign_map_point(244, 429), _campaign_map_point(244, 428), 
			_campaign_map_point(244, 427), _campaign_map_point(244, 426), _campaign_map_point(244, 425), 
			_campaign_map_point(244, 424), _campaign_map_point(244, 423), _campaign_map_point(244, 422), 
			_campaign_map_point(244, 421), _campaign_map_point(244, 420), _campaign_map_point(244, 419), 
			_campaign_map_point(244, 418), _campaign_map_point(244, 417), _campaign_map_point(244, 416), 
			_campaign_map_point(244, 415), _campaign_map_point(244, 414), _campaign_map_point(244, 413), 
			_campaign_map_point(244, 412), _campaign_map_point(244, 411), _campaign_map_point(244, 410), 
			_campaign_map_point(244, 409), _campaign_map_point(244, 408), _campaign_map_point(244, 407), 
			_campaign_map_point(244, 406), _campaign_map_point(244, 405), _campaign_map_point(244, 404), 
			_campaign_map_point(244, 403), _campaign_map_point(244, 402), _campaign_map_point(244, 401), 
			_campaign_map_point(244, 400), _campaign_map_point(244, 399), _campaign_map_point(244, 398), 
			_campaign_map_point(244, 397), _campaign_map_point(244, 396), _campaign_map_point(244, 395), 
			_campaign_map_point(244, 394), _campaign_map_point(244, 393), _campaign_map_point(244, 392), 
			_campaign_map_point(244, 391), _campaign_map_point(244, 390), _campaign_map_point(244, 389), 
			_campaign_map_point(244, 388), _campaign_map_point(244, 387), _campaign_map_point(244, 386), 
			_campaign_map_point(244, 385), _campaign_map_point(244, 384), _campaign_map_point(244, 383), 
			_campaign_map_point(244, 382), _campaign_map_point(245, 381), _campaign_map_point(245, 380), 
			_campaign_map_point(245, 379), _campaign_map_point(245, 378), _campaign_map_point(245, 377), 
			_campaign_map_point(245, 376), _campaign_map_point(245, 375), _campaign_map_point(245, 374), 
			_campaign_map_point(245, 373), _campaign_map_point(245, 372), _campaign_map_point(245, 371), 
			_campaign_map_point(245, 370), _campaign_map_point(245, 369), _campaign_map_point(245, 368), 
			_campaign_map_point(245, 367), _campaign_map_point(245, 366), _campaign_map_point(245, 365), 
			_campaign_map_point(245, 364), _campaign_map_point(245, 363), _campaign_map_point(245, 362), 
			_campaign_map_point(245, 361), _campaign_map_point(245, 360), _campaign_map_point(245, 359), 
			_campaign_map_point(245, 358), _campaign_map_point(245, 357), _campaign_map_point(245, 356), 
			_campaign_map_point(244, 355), _campaign_map_point(244, 354), _campaign_map_point(244, 353), 
			_campaign_map_point(244, 352), _campaign_map_point(244, 351), _campaign_map_point(244, 350), 
			_campaign_map_point(244, 349), _campaign_map_point(244, 348), _campaign_map_point(244, 347), 
			_campaign_map_point(244, 346), _campaign_map_point(244, 345), _campaign_map_point(244, 344), 
			_campaign_map_point(244, 343), _campaign_map_point(244, 342), _campaign_map_point(244, 341), 
			_campaign_map_point(244, 340), _campaign_map_point(244, 339), _campaign_map_point(244, 338), 
			_campaign_map_point(244, 337), _campaign_map_point(244, 336), _campaign_map_point(244, 335), 
			_campaign_map_point(244, 334), _campaign_map_point(244, 333), _campaign_map_point(244, 332), 
			_campaign_map_point(244, 331), _campaign_map_point(244, 330), _campaign_map_point(244, 329), 
			_campaign_map_point(244, 328), _campaign_map_point(244, 327), _campaign_map_point(244, 326), 
			_campaign_map_point(244, 325), _campaign_map_point(244, 324), _campaign_map_point(244, 323), 
			_campaign_map_point(244, 322), _campaign_map_point(244, 321), _campaign_map_point(244, 320), 
			_campaign_map_point(244, 319), _campaign_map_point(244, 318), _campaign_map_point(244, 317), 
			_campaign_map_point(244, 316), _campaign_map_point(244, 315), _campaign_map_point(244, 314), 
			_campaign_map_point(244, 313), _campaign_map_point(244, 312), _campaign_map_point(244, 311), 
			_campaign_map_point(244, 310), _campaign_map_point(244, 309), _campaign_map_point(244, 308), 
			_campaign_map_point(244, 307), _campaign_map_point(244, 306), _campaign_map_point(244, 305), 
			_campaign_map_point(244, 304), _campaign_map_point(244, 303), _campaign_map_point(244, 302), 
			_campaign_map_point(244, 301), _campaign_map_point(244, 300), _campaign_map_point(244, 299), 
			_campaign_map_point(244, 298), _campaign_map_point(244, 297), _campaign_map_point(244, 296), 
			_campaign_map_point(244, 295), _campaign_map_point(244, 294), _campaign_map_point(244, 293), 
			_campaign_map_point(244, 292), _campaign_map_point(244, 291), _campaign_map_point(244, 290), 
			_campaign_map_point(244, 289), _campaign_map_point(244, 288), _campaign_map_point(244, 287), 
			_campaign_map_point(244, 286), _campaign_map_point(244, 285), _campaign_map_point(244, 284), 
			_campaign_map_point(244, 283), _campaign_map_point(244, 282), _campaign_map_point(244, 281), 
			_campaign_map_point(244, 280), _campaign_map_point(244, 279), _campaign_map_point(244, 278), 
			_campaign_map_point(244, 277), _campaign_map_point(244, 276), _campaign_map_point(244, 275), 
			_campaign_map_point(244, 274), _campaign_map_point(244, 273), _campaign_map_point(244, 272), 
			_campaign_map_point(244, 271), _campaign_map_point(244, 270), _campaign_map_point(244, 269), 
			_campaign_map_point(244, 268), _campaign_map_point(244, 267), _campaign_map_point(244, 266), 
			_campaign_map_point(244, 265), _campaign_map_point(244, 264), _campaign_map_point(244, 263), 
			_campaign_map_point(244, 262), _campaign_map_point(244, 261), _campaign_map_point(244, 260), 
			_campaign_map_point(245, 259), _campaign_map_point(245, 258), _campaign_map_point(245, 257), 
			_campaign_map_point(245, 256), _campaign_map_point(245, 255), _campaign_map_point(245, 254), 
			_campaign_map_point(245, 253), _campaign_map_point(245, 252), _campaign_map_point(245, 251), 
			_campaign_map_point(245, 250), _campaign_map_point(245, 249), _campaign_map_point(245, 248), 
			_campaign_map_point(245, 247), _campaign_map_point(245, 246), _campaign_map_point(244, 245), 
			_campaign_map_point(244, 244), _campaign_map_point(244, 243), _campaign_map_point(244, 242), 
			_campaign_map_point(244, 241), _campaign_map_point(239, 240), _campaign_map_point(238, 239), 
			_campaign_map_point(238, 238), _campaign_map_point(238, 237), _campaign_map_point(238, 236), 
			_campaign_map_point(238, 235), _campaign_map_point(238, 234), _campaign_map_point(238, 233), 
			_campaign_map_point(238, 232), _campaign_map_point(238, 231), _campaign_map_point(238, 230), 
			_campaign_map_point(238, 229), _campaign_map_point(238, 228), _campaign_map_point(240, 227), 
			_campaign_map_point(240, 226), _campaign_map_point(239, 225), _campaign_map_point(239, 224), 
			_campaign_map_point(239, 223), _campaign_map_point(239, 222), _campaign_map_point(239, 221), 
			_campaign_map_point(238, 220), _campaign_map_point(238, 219), _campaign_map_point(238, 218), 
			_campaign_map_point(238, 217), _campaign_map_point(237, 216), _campaign_map_point(237, 215), 
			_campaign_map_point(236, 214), _campaign_map_point(236, 213), _campaign_map_point(236, 212), 
			_campaign_map_point(235, 211), _campaign_map_point(235, 210), _campaign_map_point(235, 209), 
			_campaign_map_point(234, 208), _campaign_map_point(234, 207), _campaign_map_point(234, 206), 
			_campaign_map_point(233, 205), _campaign_map_point(233, 204), _campaign_map_point(232, 203), 
			_campaign_map_point(232, 202), _campaign_map_point(231, 201), _campaign_map_point(231, 200), 
			_campaign_map_point(230, 199), _campaign_map_point(230, 198), _campaign_map_point(230, 197), 
			_campaign_map_point(229, 196), _campaign_map_point(229, 195), _campaign_map_point(228, 194), 
			_campaign_map_point(228, 193), _campaign_map_point(227, 192), _campaign_map_point(227, 191), 
			_campaign_map_point(226, 190), _campaign_map_point(226, 189), _campaign_map_point(226, 188), 
			_campaign_map_point(225, 187), _campaign_map_point(224, 186), _campaign_map_point(224, 185), 
			_campaign_map_point(224, 184), _campaign_map_point(223, 183), _campaign_map_point(223, 182), 
			_campaign_map_point(222, 181), _campaign_map_point(222, 180), _campaign_map_point(221, 179), 
			_campaign_map_point(221, 178), _campaign_map_point(220, 177), _campaign_map_point(219, 176), 
			_campaign_map_point(218, 175), _campaign_map_point(218, 174), _campaign_map_point(217, 173), 
			_campaign_map_point(217, 172), _campaign_map_point(216, 171), _campaign_map_point(216, 170), 
			_campaign_map_point(215, 169), _campaign_map_point(214, 168), _campaign_map_point(214, 167), 
			_campaign_map_point(213, 166), _campaign_map_point(212, 165), _campaign_map_point(212, 164), 
			_campaign_map_point(211, 163), _campaign_map_point(210, 162), _campaign_map_point(210, 161), 
			_campaign_map_point(209, 160), _campaign_map_point(208, 159), _campaign_map_point(208, 158), 
			_campaign_map_point(207, 157), _campaign_map_point(206, 156), _campaign_map_point(205, 155), 
			_campaign_map_point(205, 154), _campaign_map_point(204, 153), _campaign_map_point(203, 152), 
			_campaign_map_point(202, 151), _campaign_map_point(202, 150), _campaign_map_point(201, 149), 
			_campaign_map_point(200, 148), _campaign_map_point(200, 147), _campaign_map_point(199, 146), 
			_campaign_map_point(198, 145), _campaign_map_point(197, 144), _campaign_map_point(196, 143), 
			_campaign_map_point(196, 142), _campaign_map_point(195, 141), _campaign_map_point(194, 140), 
			_campaign_map_point(194, 139), _campaign_map_point(193, 138), _campaign_map_point(192, 137), 
			_campaign_map_point(191, 136), _campaign_map_point(190, 135), _campaign_map_point(190, 134), 
			_campaign_map_point(189, 133), _campaign_map_point(188, 132), _campaign_map_point(187, 131), 
			_campaign_map_point(186, 130), _campaign_map_point(185, 129), _campaign_map_point(184, 128), 
			_campaign_map_point(184, 127), _campaign_map_point(183, 126), _campaign_map_point(182, 125), 
			_campaign_map_point(181, 124), _campaign_map_point(180, 123), _campaign_map_point(180, 122), 
			_campaign_map_point(178, 121), _campaign_map_point(177, 120), _campaign_map_point(176, 119), 
			_campaign_map_point(176, 118), _campaign_map_point(175, 117), _campaign_map_point(174, 116), 
			_campaign_map_point(173, 115), _campaign_map_point(172, 114), _campaign_map_point(170, 113), 
			_campaign_map_point(169, 112), _campaign_map_point(168, 111), _campaign_map_point(167, 110), 
			_campaign_map_point(166, 109), _campaign_map_point(165, 108), _campaign_map_point(164, 107), 
			_campaign_map_point(163, 106), _campaign_map_point(162, 105), _campaign_map_point(161, 104), 
			_campaign_map_point(160, 103), _campaign_map_point(159, 102), _campaign_map_point(158, 101), 
			_campaign_map_point(157, 100), _campaign_map_point(156, 99), _campaign_map_point(154, 98), 
			_campaign_map_point(153, 97), _campaign_map_point(152, 96), _campaign_map_point(142, 95), 
			_campaign_map_point(142, 94), _campaign_map_point(140, 93), _campaign_map_point(139, 92), 
			_campaign_map_point(137, 91), _campaign_map_point(136, 90), _campaign_map_point(136, 89), 
			_campaign_map_point(136, 88), _campaign_map_point(136, 87), _campaign_map_point(136, 86), 
			_campaign_map_point(136, 85), _campaign_map_point(136, 84), _campaign_map_point(136, 83), 
			_campaign_map_point(136, 82), _campaign_map_point(134, 81), _campaign_map_point(133, 80), 
			_campaign_map_point(132, 79), _campaign_map_point(131, 78), _campaign_map_point(129, 77), 
			_campaign_map_point(128, 76), _campaign_map_point(127, 75), _campaign_map_point(125, 74)
		]},
		{"section": "Колодец памяти", "mask": "res://Background/Campaign_Hover_memory_well.png", "points": [
			_campaign_map_point(373, 108), _campaign_map_point(372, 109), _campaign_map_point(370, 110), 
			_campaign_map_point(369, 111), _campaign_map_point(367, 112), _campaign_map_point(366, 113), 
			_campaign_map_point(364, 114), _campaign_map_point(363, 115), _campaign_map_point(361, 116), 
			_campaign_map_point(360, 117), _campaign_map_point(358, 118), _campaign_map_point(357, 119), 
			_campaign_map_point(355, 120), _campaign_map_point(354, 121), _campaign_map_point(353, 122), 
			_campaign_map_point(351, 123), _campaign_map_point(350, 124), _campaign_map_point(348, 125), 
			_campaign_map_point(347, 126), _campaign_map_point(346, 127), _campaign_map_point(344, 128), 
			_campaign_map_point(343, 129), _campaign_map_point(342, 130), _campaign_map_point(341, 131), 
			_campaign_map_point(340, 132), _campaign_map_point(339, 133), _campaign_map_point(338, 134), 
			_campaign_map_point(337, 135), _campaign_map_point(335, 136), _campaign_map_point(334, 137), 
			_campaign_map_point(333, 138), _campaign_map_point(332, 139), _campaign_map_point(331, 140), 
			_campaign_map_point(330, 141), _campaign_map_point(329, 142), _campaign_map_point(328, 143), 
			_campaign_map_point(327, 144), _campaign_map_point(326, 145), _campaign_map_point(325, 146), 
			_campaign_map_point(324, 147), _campaign_map_point(323, 148), _campaign_map_point(322, 149), 
			_campaign_map_point(321, 150), _campaign_map_point(320, 151), _campaign_map_point(319, 152), 
			_campaign_map_point(318, 153), _campaign_map_point(317, 154), _campaign_map_point(316, 155), 
			_campaign_map_point(315, 156), _campaign_map_point(315, 157), _campaign_map_point(314, 158), 
			_campaign_map_point(313, 159), _campaign_map_point(312, 160), _campaign_map_point(311, 161), 
			_campaign_map_point(310, 162), _campaign_map_point(310, 163), _campaign_map_point(309, 164), 
			_campaign_map_point(308, 165), _campaign_map_point(307, 166), _campaign_map_point(307, 167), 
			_campaign_map_point(306, 168), _campaign_map_point(305, 169), _campaign_map_point(305, 170), 
			_campaign_map_point(304, 171), _campaign_map_point(303, 172), _campaign_map_point(303, 173), 
			_campaign_map_point(302, 174), _campaign_map_point(301, 175), _campaign_map_point(301, 176), 
			_campaign_map_point(300, 177), _campaign_map_point(299, 178), _campaign_map_point(299, 179), 
			_campaign_map_point(298, 180), _campaign_map_point(298, 181), _campaign_map_point(297, 182), 
			_campaign_map_point(296, 183), _campaign_map_point(296, 184), _campaign_map_point(295, 185), 
			_campaign_map_point(295, 186), _campaign_map_point(294, 187), _campaign_map_point(294, 188), 
			_campaign_map_point(293, 189), _campaign_map_point(293, 190), _campaign_map_point(292, 191), 
			_campaign_map_point(292, 192), _campaign_map_point(291, 193), _campaign_map_point(291, 194), 
			_campaign_map_point(290, 195), _campaign_map_point(290, 196), _campaign_map_point(289, 197), 
			_campaign_map_point(289, 198), _campaign_map_point(288, 199), _campaign_map_point(288, 200), 
			_campaign_map_point(288, 201), _campaign_map_point(287, 202), _campaign_map_point(287, 203), 
			_campaign_map_point(287, 204), _campaign_map_point(286, 205), _campaign_map_point(286, 206), 
			_campaign_map_point(286, 207), _campaign_map_point(285, 208), _campaign_map_point(285, 209), 
			_campaign_map_point(284, 210), _campaign_map_point(284, 211), _campaign_map_point(284, 212), 
			_campaign_map_point(283, 213), _campaign_map_point(283, 214), _campaign_map_point(283, 215), 
			_campaign_map_point(282, 216), _campaign_map_point(282, 217), _campaign_map_point(282, 218), 
			_campaign_map_point(282, 219), _campaign_map_point(281, 220), _campaign_map_point(281, 221), 
			_campaign_map_point(281, 222), _campaign_map_point(281, 223), _campaign_map_point(281, 224), 
			_campaign_map_point(280, 225), _campaign_map_point(280, 226), _campaign_map_point(280, 227), 
			_campaign_map_point(280, 228), _campaign_map_point(280, 229), _campaign_map_point(280, 230), 
			_campaign_map_point(280, 231), _campaign_map_point(280, 232), _campaign_map_point(280, 233), 
			_campaign_map_point(280, 234), _campaign_map_point(280, 235), _campaign_map_point(280, 236), 
			_campaign_map_point(280, 237), _campaign_map_point(280, 238), _campaign_map_point(280, 239), 
			_campaign_map_point(280, 240), _campaign_map_point(275, 241), _campaign_map_point(274, 242), 
			_campaign_map_point(274, 243), _campaign_map_point(274, 244), _campaign_map_point(274, 245), 
			_campaign_map_point(274, 246), _campaign_map_point(274, 247), _campaign_map_point(274, 248), 
			_campaign_map_point(275, 249), _campaign_map_point(275, 250), _campaign_map_point(275, 251), 
			_campaign_map_point(275, 252), _campaign_map_point(275, 253), _campaign_map_point(275, 254), 
			_campaign_map_point(275, 255), _campaign_map_point(275, 256), _campaign_map_point(275, 257), 
			_campaign_map_point(275, 258), _campaign_map_point(275, 259), _campaign_map_point(275, 260), 
			_campaign_map_point(275, 261), _campaign_map_point(275, 262), _campaign_map_point(275, 263), 
			_campaign_map_point(275, 264), _campaign_map_point(275, 265), _campaign_map_point(274, 266), 
			_campaign_map_point(274, 267), _campaign_map_point(274, 268), _campaign_map_point(274, 269), 
			_campaign_map_point(274, 270), _campaign_map_point(274, 271), _campaign_map_point(274, 272), 
			_campaign_map_point(274, 273), _campaign_map_point(274, 274), _campaign_map_point(274, 275), 
			_campaign_map_point(274, 276), _campaign_map_point(274, 277), _campaign_map_point(274, 278), 
			_campaign_map_point(274, 279), _campaign_map_point(274, 280), _campaign_map_point(274, 281), 
			_campaign_map_point(274, 282), _campaign_map_point(274, 283), _campaign_map_point(274, 284), 
			_campaign_map_point(274, 285), _campaign_map_point(274, 286), _campaign_map_point(274, 287), 
			_campaign_map_point(274, 288), _campaign_map_point(274, 289), _campaign_map_point(274, 290), 
			_campaign_map_point(274, 291), _campaign_map_point(274, 292), _campaign_map_point(274, 293), 
			_campaign_map_point(274, 294), _campaign_map_point(274, 295), _campaign_map_point(274, 296), 
			_campaign_map_point(274, 297), _campaign_map_point(274, 298), _campaign_map_point(274, 299), 
			_campaign_map_point(274, 300), _campaign_map_point(274, 301), _campaign_map_point(274, 302), 
			_campaign_map_point(274, 303), _campaign_map_point(274, 304), _campaign_map_point(274, 305), 
			_campaign_map_point(274, 306), _campaign_map_point(274, 307), _campaign_map_point(274, 308), 
			_campaign_map_point(274, 309), _campaign_map_point(274, 310), _campaign_map_point(274, 311), 
			_campaign_map_point(274, 312), _campaign_map_point(274, 313), _campaign_map_point(274, 314), 
			_campaign_map_point(274, 315), _campaign_map_point(274, 316), _campaign_map_point(274, 317), 
			_campaign_map_point(274, 318), _campaign_map_point(274, 319), _campaign_map_point(274, 320), 
			_campaign_map_point(274, 321), _campaign_map_point(274, 322), _campaign_map_point(274, 323), 
			_campaign_map_point(274, 324), _campaign_map_point(274, 325), _campaign_map_point(274, 326), 
			_campaign_map_point(274, 327), _campaign_map_point(274, 328), _campaign_map_point(274, 329), 
			_campaign_map_point(274, 330), _campaign_map_point(274, 331), _campaign_map_point(274, 332), 
			_campaign_map_point(274, 333), _campaign_map_point(274, 334), _campaign_map_point(274, 335), 
			_campaign_map_point(274, 336), _campaign_map_point(274, 337), _campaign_map_point(274, 338), 
			_campaign_map_point(274, 339), _campaign_map_point(274, 340), _campaign_map_point(274, 341), 
			_campaign_map_point(274, 342), _campaign_map_point(274, 343), _campaign_map_point(274, 344), 
			_campaign_map_point(274, 345), _campaign_map_point(274, 346), _campaign_map_point(274, 347), 
			_campaign_map_point(274, 348), _campaign_map_point(274, 349), _campaign_map_point(274, 350), 
			_campaign_map_point(274, 351), _campaign_map_point(274, 352), _campaign_map_point(274, 353), 
			_campaign_map_point(274, 354), _campaign_map_point(273, 355), _campaign_map_point(273, 356), 
			_campaign_map_point(273, 357), _campaign_map_point(273, 358), _campaign_map_point(273, 359), 
			_campaign_map_point(274, 360), _campaign_map_point(274, 361), _campaign_map_point(274, 362), 
			_campaign_map_point(274, 363), _campaign_map_point(274, 364), _campaign_map_point(274, 365), 
			_campaign_map_point(274, 366), _campaign_map_point(274, 367), _campaign_map_point(274, 368), 
			_campaign_map_point(274, 369), _campaign_map_point(274, 370), _campaign_map_point(274, 371), 
			_campaign_map_point(274, 372), _campaign_map_point(273, 373), _campaign_map_point(273, 374), 
			_campaign_map_point(273, 375), _campaign_map_point(273, 376), _campaign_map_point(273, 377), 
			_campaign_map_point(273, 378), _campaign_map_point(273, 379), _campaign_map_point(273, 380), 
			_campaign_map_point(273, 381), _campaign_map_point(273, 382), _campaign_map_point(273, 383), 
			_campaign_map_point(273, 384), _campaign_map_point(273, 385), _campaign_map_point(273, 386), 
			_campaign_map_point(273, 387), _campaign_map_point(273, 388), _campaign_map_point(273, 389), 
			_campaign_map_point(273, 390), _campaign_map_point(273, 391), _campaign_map_point(273, 392), 
			_campaign_map_point(273, 393), _campaign_map_point(273, 394), _campaign_map_point(274, 395), 
			_campaign_map_point(274, 396), _campaign_map_point(274, 397), _campaign_map_point(274, 398), 
			_campaign_map_point(274, 399), _campaign_map_point(274, 400), _campaign_map_point(274, 401), 
			_campaign_map_point(274, 402), _campaign_map_point(274, 403), _campaign_map_point(274, 404), 
			_campaign_map_point(274, 405), _campaign_map_point(274, 406), _campaign_map_point(274, 407), 
			_campaign_map_point(274, 408), _campaign_map_point(274, 409), _campaign_map_point(274, 410), 
			_campaign_map_point(274, 411), _campaign_map_point(274, 412), _campaign_map_point(274, 413), 
			_campaign_map_point(274, 414), _campaign_map_point(274, 415), _campaign_map_point(274, 416), 
			_campaign_map_point(274, 417), _campaign_map_point(274, 418), _campaign_map_point(274, 419), 
			_campaign_map_point(274, 420), _campaign_map_point(274, 421), _campaign_map_point(274, 422), 
			_campaign_map_point(274, 423), _campaign_map_point(274, 424), _campaign_map_point(274, 425), 
			_campaign_map_point(274, 426), _campaign_map_point(274, 427), _campaign_map_point(274, 428), 
			_campaign_map_point(274, 429), _campaign_map_point(274, 430), _campaign_map_point(273, 431), 
			_campaign_map_point(273, 432), _campaign_map_point(273, 433), _campaign_map_point(273, 434), 
			_campaign_map_point(273, 435), _campaign_map_point(274, 436), _campaign_map_point(274, 437), 
			_campaign_map_point(274, 438), _campaign_map_point(274, 439), _campaign_map_point(274, 440), 
			_campaign_map_point(274, 441), _campaign_map_point(274, 442), _campaign_map_point(274, 443), 
			_campaign_map_point(274, 444), _campaign_map_point(274, 445), _campaign_map_point(274, 446), 
			_campaign_map_point(274, 447), _campaign_map_point(274, 448), _campaign_map_point(273, 449), 
			_campaign_map_point(273, 450), _campaign_map_point(273, 451), _campaign_map_point(273, 452), 
			_campaign_map_point(273, 453), _campaign_map_point(273, 454), _campaign_map_point(273, 455), 
			_campaign_map_point(273, 456), _campaign_map_point(273, 457), _campaign_map_point(273, 458), 
			_campaign_map_point(273, 459), _campaign_map_point(273, 460), _campaign_map_point(273, 461), 
			_campaign_map_point(273, 462), _campaign_map_point(273, 463), _campaign_map_point(273, 464), 
			_campaign_map_point(273, 465), _campaign_map_point(273, 466), _campaign_map_point(273, 467), 
			_campaign_map_point(273, 468), _campaign_map_point(273, 469), _campaign_map_point(273, 470), 
			_campaign_map_point(273, 471), _campaign_map_point(273, 472), _campaign_map_point(273, 473), 
			_campaign_map_point(273, 474), _campaign_map_point(273, 475), _campaign_map_point(273, 476), 
			_campaign_map_point(273, 477), _campaign_map_point(273, 478), _campaign_map_point(273, 479), 
			_campaign_map_point(274, 480), _campaign_map_point(274, 481), _campaign_map_point(274, 482), 
			_campaign_map_point(274, 483), _campaign_map_point(274, 484), _campaign_map_point(274, 485), 
			_campaign_map_point(274, 486), _campaign_map_point(274, 487), _campaign_map_point(274, 488), 
			_campaign_map_point(274, 489), _campaign_map_point(274, 490), _campaign_map_point(274, 491), 
			_campaign_map_point(274, 492), _campaign_map_point(274, 493), _campaign_map_point(274, 494), 
			_campaign_map_point(274, 495), _campaign_map_point(274, 496), _campaign_map_point(274, 497), 
			_campaign_map_point(274, 498), _campaign_map_point(274, 499), _campaign_map_point(274, 500), 
			_campaign_map_point(274, 501), _campaign_map_point(274, 502), _campaign_map_point(274, 503), 
			_campaign_map_point(274, 504), _campaign_map_point(274, 505), _campaign_map_point(274, 506), 
			_campaign_map_point(274, 507), _campaign_map_point(274, 508), _campaign_map_point(274, 509), 
			_campaign_map_point(274, 510), _campaign_map_point(274, 511), _campaign_map_point(274, 512), 
			_campaign_map_point(274, 513), _campaign_map_point(274, 514), _campaign_map_point(274, 515), 
			_campaign_map_point(274, 516), _campaign_map_point(274, 517), _campaign_map_point(274, 518), 
			_campaign_map_point(274, 519), _campaign_map_point(274, 520), _campaign_map_point(274, 521), 
			_campaign_map_point(274, 522), _campaign_map_point(274, 523), _campaign_map_point(274, 524), 
			_campaign_map_point(274, 525), _campaign_map_point(274, 526), _campaign_map_point(274, 527), 
			_campaign_map_point(274, 528), _campaign_map_point(274, 529), _campaign_map_point(274, 530), 
			_campaign_map_point(274, 531), _campaign_map_point(274, 532), _campaign_map_point(274, 533), 
			_campaign_map_point(274, 534), _campaign_map_point(274, 535), _campaign_map_point(274, 536), 
			_campaign_map_point(274, 537), _campaign_map_point(274, 538), _campaign_map_point(274, 539), 
			_campaign_map_point(274, 540), _campaign_map_point(274, 541), _campaign_map_point(274, 542), 
			_campaign_map_point(274, 543), _campaign_map_point(274, 544), _campaign_map_point(274, 545), 
			_campaign_map_point(274, 546), _campaign_map_point(274, 547), _campaign_map_point(274, 548), 
			_campaign_map_point(274, 549), _campaign_map_point(273, 550), _campaign_map_point(273, 551), 
			_campaign_map_point(273, 552), _campaign_map_point(273, 553), _campaign_map_point(273, 554), 
			_campaign_map_point(273, 555), _campaign_map_point(273, 556), _campaign_map_point(273, 557), 
			_campaign_map_point(273, 558), _campaign_map_point(273, 559), _campaign_map_point(273, 560), 
			_campaign_map_point(273, 561), _campaign_map_point(273, 562), _campaign_map_point(273, 563), 
			_campaign_map_point(273, 564), _campaign_map_point(273, 565), _campaign_map_point(273, 566), 
			_campaign_map_point(273, 567), _campaign_map_point(273, 568), _campaign_map_point(273, 569), 
			_campaign_map_point(273, 570), _campaign_map_point(273, 571), _campaign_map_point(273, 572), 
			_campaign_map_point(273, 573), _campaign_map_point(273, 574), _campaign_map_point(273, 575), 
			_campaign_map_point(273, 576), _campaign_map_point(274, 577), _campaign_map_point(274, 578), 
			_campaign_map_point(274, 579), _campaign_map_point(274, 580), _campaign_map_point(274, 581), 
			_campaign_map_point(274, 582), _campaign_map_point(274, 583), _campaign_map_point(274, 584), 
			_campaign_map_point(274, 585), _campaign_map_point(274, 586), _campaign_map_point(274, 587), 
			_campaign_map_point(274, 588), _campaign_map_point(274, 589), _campaign_map_point(274, 590), 
			_campaign_map_point(274, 591), _campaign_map_point(274, 592), _campaign_map_point(274, 593), 
			_campaign_map_point(274, 594), _campaign_map_point(274, 595), _campaign_map_point(274, 596), 
			_campaign_map_point(274, 597), _campaign_map_point(274, 598), _campaign_map_point(274, 599), 
			_campaign_map_point(274, 600), _campaign_map_point(274, 601), _campaign_map_point(274, 602), 
			_campaign_map_point(274, 603), _campaign_map_point(273, 604), _campaign_map_point(273, 605), 
			_campaign_map_point(273, 606), _campaign_map_point(273, 607), _campaign_map_point(273, 608), 
			_campaign_map_point(273, 609), _campaign_map_point(273, 610), _campaign_map_point(273, 611), 
			_campaign_map_point(273, 612), _campaign_map_point(273, 613), _campaign_map_point(274, 614), 
			_campaign_map_point(274, 615), _campaign_map_point(274, 616), _campaign_map_point(274, 617), 
			_campaign_map_point(274, 618), _campaign_map_point(274, 619), _campaign_map_point(274, 620), 
			_campaign_map_point(274, 621), _campaign_map_point(274, 622), _campaign_map_point(274, 623), 
			_campaign_map_point(274, 624), _campaign_map_point(274, 625), _campaign_map_point(274, 626), 
			_campaign_map_point(273, 627), _campaign_map_point(273, 628), _campaign_map_point(273, 629), 
			_campaign_map_point(273, 630), _campaign_map_point(273, 631), _campaign_map_point(273, 632), 
			_campaign_map_point(273, 633), _campaign_map_point(273, 634), _campaign_map_point(273, 635), 
			_campaign_map_point(273, 636), _campaign_map_point(273, 637), _campaign_map_point(273, 638), 
			_campaign_map_point(273, 639), _campaign_map_point(273, 640), _campaign_map_point(273, 641), 
			_campaign_map_point(273, 642), _campaign_map_point(273, 643), _campaign_map_point(273, 644), 
			_campaign_map_point(273, 645), _campaign_map_point(273, 646), _campaign_map_point(273, 647), 
			_campaign_map_point(273, 648), _campaign_map_point(273, 649), _campaign_map_point(273, 650), 
			_campaign_map_point(273, 651), _campaign_map_point(273, 652), _campaign_map_point(273, 653), 
			_campaign_map_point(273, 654), _campaign_map_point(273, 655), _campaign_map_point(273, 656), 
			_campaign_map_point(273, 657), _campaign_map_point(273, 658), _campaign_map_point(273, 659), 
			_campaign_map_point(273, 660), _campaign_map_point(273, 661), _campaign_map_point(273, 662), 
			_campaign_map_point(273, 663), _campaign_map_point(273, 664), _campaign_map_point(274, 665), 
			_campaign_map_point(274, 666), _campaign_map_point(274, 667), _campaign_map_point(274, 668), 
			_campaign_map_point(274, 669), _campaign_map_point(274, 670), _campaign_map_point(274, 671), 
			_campaign_map_point(274, 672), _campaign_map_point(274, 673), _campaign_map_point(274, 674), 
			_campaign_map_point(274, 675), _campaign_map_point(274, 676), _campaign_map_point(274, 677), 
			_campaign_map_point(274, 678), _campaign_map_point(274, 679), _campaign_map_point(274, 680), 
			_campaign_map_point(274, 681), _campaign_map_point(274, 682), _campaign_map_point(274, 683), 
			_campaign_map_point(274, 684), _campaign_map_point(274, 685), _campaign_map_point(274, 686), 
			_campaign_map_point(274, 687), _campaign_map_point(274, 688), _campaign_map_point(274, 689), 
			_campaign_map_point(274, 690), _campaign_map_point(274, 691), _campaign_map_point(274, 692), 
			_campaign_map_point(274, 693), _campaign_map_point(274, 694), _campaign_map_point(274, 695), 
			_campaign_map_point(274, 696), _campaign_map_point(274, 697), _campaign_map_point(274, 698), 
			_campaign_map_point(274, 699), _campaign_map_point(274, 700), _campaign_map_point(274, 701), 
			_campaign_map_point(274, 702), _campaign_map_point(274, 703), _campaign_map_point(275, 704), 
			_campaign_map_point(275, 705), _campaign_map_point(275, 706), _campaign_map_point(275, 707), 
			_campaign_map_point(275, 708), _campaign_map_point(275, 709), _campaign_map_point(275, 710), 
			_campaign_map_point(275, 711), _campaign_map_point(275, 712), _campaign_map_point(275, 713), 
			_campaign_map_point(275, 714), _campaign_map_point(274, 715), _campaign_map_point(274, 716), 
			_campaign_map_point(274, 717), _campaign_map_point(274, 718), _campaign_map_point(274, 719), 
			_campaign_map_point(274, 720), _campaign_map_point(274, 721), _campaign_map_point(274, 722), 
			_campaign_map_point(274, 723), _campaign_map_point(274, 724), _campaign_map_point(275, 725), 
			_campaign_map_point(275, 726), _campaign_map_point(275, 727), _campaign_map_point(276, 728), 
			_campaign_map_point(276, 729), _campaign_map_point(276, 730), _campaign_map_point(276, 731), 
			_campaign_map_point(276, 732), _campaign_map_point(276, 733), _campaign_map_point(276, 734), 
			_campaign_map_point(276, 735), _campaign_map_point(276, 736), _campaign_map_point(276, 737), 
			_campaign_map_point(276, 738), _campaign_map_point(276, 739), _campaign_map_point(276, 740), 
			_campaign_map_point(275, 741), _campaign_map_point(275, 742), _campaign_map_point(275, 743), 
			_campaign_map_point(275, 744), _campaign_map_point(275, 745), _campaign_map_point(275, 746), 
			_campaign_map_point(275, 747), _campaign_map_point(275, 748), _campaign_map_point(275, 749), 
			_campaign_map_point(275, 750), _campaign_map_point(275, 751), _campaign_map_point(275, 752), 
			_campaign_map_point(275, 753), _campaign_map_point(275, 754), _campaign_map_point(275, 755), 
			_campaign_map_point(276, 756), _campaign_map_point(277, 757), _campaign_map_point(277, 758), 
			_campaign_map_point(278, 759), _campaign_map_point(279, 760), _campaign_map_point(285, 760), 
			_campaign_map_point(293, 759), _campaign_map_point(300, 758), _campaign_map_point(307, 757), 
			_campaign_map_point(314, 756), _campaign_map_point(321, 755), _campaign_map_point(327, 754), 
			_campaign_map_point(335, 753), _campaign_map_point(345, 752), _campaign_map_point(352, 751), 
			_campaign_map_point(361, 750), _campaign_map_point(367, 749), _campaign_map_point(374, 748), 
			_campaign_map_point(383, 747), _campaign_map_point(389, 746), _campaign_map_point(399, 745), 
			_campaign_map_point(404, 744), _campaign_map_point(415, 743), _campaign_map_point(423, 742), 
			_campaign_map_point(430, 741), _campaign_map_point(439, 740), _campaign_map_point(446, 739), 
			_campaign_map_point(453, 738), _campaign_map_point(461, 737), _campaign_map_point(469, 736), 
			_campaign_map_point(474, 735), _campaign_map_point(476, 734), _campaign_map_point(477, 733), 
			_campaign_map_point(477, 732), _campaign_map_point(478, 731), _campaign_map_point(479, 730), 
			_campaign_map_point(479, 729), _campaign_map_point(480, 728), _campaign_map_point(480, 727), 
			_campaign_map_point(480, 726), _campaign_map_point(480, 725), _campaign_map_point(481, 724), 
			_campaign_map_point(481, 723), _campaign_map_point(481, 722), _campaign_map_point(481, 721), 
			_campaign_map_point(481, 720), _campaign_map_point(481, 719), _campaign_map_point(481, 718), 
			_campaign_map_point(481, 717), _campaign_map_point(481, 716), _campaign_map_point(481, 715), 
			_campaign_map_point(481, 714), _campaign_map_point(481, 713), _campaign_map_point(481, 712), 
			_campaign_map_point(481, 711), _campaign_map_point(481, 710), _campaign_map_point(481, 709), 
			_campaign_map_point(481, 708), _campaign_map_point(481, 707), _campaign_map_point(481, 706), 
			_campaign_map_point(481, 705), _campaign_map_point(481, 704), _campaign_map_point(481, 703), 
			_campaign_map_point(481, 702), _campaign_map_point(481, 701), _campaign_map_point(481, 700), 
			_campaign_map_point(481, 699), _campaign_map_point(481, 698), _campaign_map_point(481, 697), 
			_campaign_map_point(481, 696), _campaign_map_point(481, 695), _campaign_map_point(481, 694), 
			_campaign_map_point(481, 693), _campaign_map_point(481, 692), _campaign_map_point(481, 691), 
			_campaign_map_point(481, 690), _campaign_map_point(482, 689), _campaign_map_point(482, 688), 
			_campaign_map_point(482, 687), _campaign_map_point(482, 686), _campaign_map_point(482, 685), 
			_campaign_map_point(482, 684), _campaign_map_point(482, 683), _campaign_map_point(482, 682), 
			_campaign_map_point(482, 681), _campaign_map_point(482, 680), _campaign_map_point(482, 679), 
			_campaign_map_point(482, 678), _campaign_map_point(482, 677), _campaign_map_point(482, 676), 
			_campaign_map_point(482, 675), _campaign_map_point(482, 674), _campaign_map_point(482, 673), 
			_campaign_map_point(482, 672), _campaign_map_point(482, 671), _campaign_map_point(482, 670), 
			_campaign_map_point(482, 669), _campaign_map_point(482, 668), _campaign_map_point(482, 667), 
			_campaign_map_point(482, 666), _campaign_map_point(482, 665), _campaign_map_point(482, 664), 
			_campaign_map_point(482, 663), _campaign_map_point(482, 662), _campaign_map_point(482, 661), 
			_campaign_map_point(482, 660), _campaign_map_point(482, 659), _campaign_map_point(482, 658), 
			_campaign_map_point(482, 657), _campaign_map_point(482, 656), _campaign_map_point(482, 655), 
			_campaign_map_point(482, 654), _campaign_map_point(482, 653), _campaign_map_point(482, 652), 
			_campaign_map_point(482, 651), _campaign_map_point(482, 650), _campaign_map_point(482, 649), 
			_campaign_map_point(482, 648), _campaign_map_point(482, 647), _campaign_map_point(482, 646), 
			_campaign_map_point(482, 645), _campaign_map_point(482, 644), _campaign_map_point(482, 643), 
			_campaign_map_point(482, 642), _campaign_map_point(482, 641), _campaign_map_point(482, 640), 
			_campaign_map_point(482, 639), _campaign_map_point(482, 638), _campaign_map_point(482, 637), 
			_campaign_map_point(482, 636), _campaign_map_point(482, 635), _campaign_map_point(482, 634), 
			_campaign_map_point(482, 633), _campaign_map_point(482, 632), _campaign_map_point(482, 631), 
			_campaign_map_point(482, 630), _campaign_map_point(482, 629), _campaign_map_point(482, 628), 
			_campaign_map_point(482, 627), _campaign_map_point(482, 626), _campaign_map_point(482, 625), 
			_campaign_map_point(482, 624), _campaign_map_point(482, 623), _campaign_map_point(482, 622), 
			_campaign_map_point(482, 621), _campaign_map_point(482, 620), _campaign_map_point(482, 619), 
			_campaign_map_point(482, 618), _campaign_map_point(482, 617), _campaign_map_point(482, 616), 
			_campaign_map_point(482, 615), _campaign_map_point(482, 614), _campaign_map_point(482, 613), 
			_campaign_map_point(482, 612), _campaign_map_point(482, 611), _campaign_map_point(482, 610), 
			_campaign_map_point(482, 609), _campaign_map_point(482, 608), _campaign_map_point(482, 607), 
			_campaign_map_point(482, 606), _campaign_map_point(482, 605), _campaign_map_point(482, 604), 
			_campaign_map_point(482, 603), _campaign_map_point(482, 602), _campaign_map_point(482, 601), 
			_campaign_map_point(482, 600), _campaign_map_point(482, 599), _campaign_map_point(482, 598), 
			_campaign_map_point(482, 597), _campaign_map_point(482, 596), _campaign_map_point(482, 595), 
			_campaign_map_point(482, 594), _campaign_map_point(482, 593), _campaign_map_point(482, 592), 
			_campaign_map_point(482, 591), _campaign_map_point(482, 590), _campaign_map_point(482, 589), 
			_campaign_map_point(482, 588), _campaign_map_point(482, 587), _campaign_map_point(482, 586), 
			_campaign_map_point(482, 585), _campaign_map_point(482, 584), _campaign_map_point(482, 583), 
			_campaign_map_point(482, 582), _campaign_map_point(482, 581), _campaign_map_point(482, 580), 
			_campaign_map_point(482, 579), _campaign_map_point(482, 578), _campaign_map_point(482, 577), 
			_campaign_map_point(482, 576), _campaign_map_point(482, 575), _campaign_map_point(482, 574), 
			_campaign_map_point(482, 573), _campaign_map_point(482, 572), _campaign_map_point(482, 571), 
			_campaign_map_point(482, 570), _campaign_map_point(482, 569), _campaign_map_point(482, 568), 
			_campaign_map_point(482, 567), _campaign_map_point(482, 566), _campaign_map_point(482, 565), 
			_campaign_map_point(482, 564), _campaign_map_point(482, 563), _campaign_map_point(482, 562), 
			_campaign_map_point(482, 561), _campaign_map_point(482, 560), _campaign_map_point(482, 559), 
			_campaign_map_point(482, 558), _campaign_map_point(482, 557), _campaign_map_point(482, 556), 
			_campaign_map_point(482, 555), _campaign_map_point(482, 554), _campaign_map_point(482, 553), 
			_campaign_map_point(482, 552), _campaign_map_point(482, 551), _campaign_map_point(482, 550), 
			_campaign_map_point(482, 549), _campaign_map_point(482, 548), _campaign_map_point(482, 547), 
			_campaign_map_point(482, 546), _campaign_map_point(482, 545), _campaign_map_point(482, 544), 
			_campaign_map_point(482, 543), _campaign_map_point(482, 542), _campaign_map_point(482, 541), 
			_campaign_map_point(482, 540), _campaign_map_point(482, 539), _campaign_map_point(482, 538), 
			_campaign_map_point(482, 537), _campaign_map_point(482, 536), _campaign_map_point(482, 535), 
			_campaign_map_point(482, 534), _campaign_map_point(482, 533), _campaign_map_point(482, 532), 
			_campaign_map_point(482, 531), _campaign_map_point(482, 530), _campaign_map_point(482, 529), 
			_campaign_map_point(482, 528), _campaign_map_point(482, 527), _campaign_map_point(482, 526), 
			_campaign_map_point(482, 525), _campaign_map_point(482, 524), _campaign_map_point(482, 523), 
			_campaign_map_point(482, 522), _campaign_map_point(482, 521), _campaign_map_point(482, 520), 
			_campaign_map_point(482, 519), _campaign_map_point(482, 518), _campaign_map_point(482, 517), 
			_campaign_map_point(482, 516), _campaign_map_point(482, 515), _campaign_map_point(482, 514), 
			_campaign_map_point(482, 513), _campaign_map_point(482, 512), _campaign_map_point(482, 511), 
			_campaign_map_point(482, 510), _campaign_map_point(482, 509), _campaign_map_point(482, 508), 
			_campaign_map_point(482, 507), _campaign_map_point(482, 506), _campaign_map_point(482, 505), 
			_campaign_map_point(482, 504), _campaign_map_point(482, 503), _campaign_map_point(482, 502), 
			_campaign_map_point(482, 501), _campaign_map_point(482, 500), _campaign_map_point(482, 499), 
			_campaign_map_point(482, 498), _campaign_map_point(482, 497), _campaign_map_point(482, 496), 
			_campaign_map_point(482, 495), _campaign_map_point(482, 494), _campaign_map_point(482, 493), 
			_campaign_map_point(482, 492), _campaign_map_point(482, 491), _campaign_map_point(482, 490), 
			_campaign_map_point(482, 489), _campaign_map_point(482, 488), _campaign_map_point(482, 487), 
			_campaign_map_point(482, 486), _campaign_map_point(482, 485), _campaign_map_point(482, 484), 
			_campaign_map_point(482, 483), _campaign_map_point(482, 482), _campaign_map_point(482, 481), 
			_campaign_map_point(482, 480), _campaign_map_point(482, 479), _campaign_map_point(482, 478), 
			_campaign_map_point(482, 477), _campaign_map_point(482, 476), _campaign_map_point(482, 475), 
			_campaign_map_point(482, 474), _campaign_map_point(482, 473), _campaign_map_point(482, 472), 
			_campaign_map_point(482, 471), _campaign_map_point(482, 470), _campaign_map_point(482, 469), 
			_campaign_map_point(482, 468), _campaign_map_point(482, 467), _campaign_map_point(482, 466), 
			_campaign_map_point(482, 465), _campaign_map_point(482, 464), _campaign_map_point(482, 463), 
			_campaign_map_point(482, 462), _campaign_map_point(482, 461), _campaign_map_point(482, 460), 
			_campaign_map_point(482, 459), _campaign_map_point(482, 458), _campaign_map_point(482, 457), 
			_campaign_map_point(482, 456), _campaign_map_point(482, 455), _campaign_map_point(482, 454), 
			_campaign_map_point(482, 453), _campaign_map_point(482, 452), _campaign_map_point(482, 451), 
			_campaign_map_point(482, 450), _campaign_map_point(482, 449), _campaign_map_point(482, 448), 
			_campaign_map_point(482, 447), _campaign_map_point(482, 446), _campaign_map_point(482, 445), 
			_campaign_map_point(482, 444), _campaign_map_point(482, 443), _campaign_map_point(482, 442), 
			_campaign_map_point(482, 441), _campaign_map_point(482, 440), _campaign_map_point(482, 439), 
			_campaign_map_point(482, 438), _campaign_map_point(482, 437), _campaign_map_point(482, 436), 
			_campaign_map_point(482, 435), _campaign_map_point(482, 434), _campaign_map_point(482, 433), 
			_campaign_map_point(482, 432), _campaign_map_point(482, 431), _campaign_map_point(482, 430), 
			_campaign_map_point(482, 429), _campaign_map_point(482, 428), _campaign_map_point(482, 427), 
			_campaign_map_point(482, 426), _campaign_map_point(482, 425), _campaign_map_point(482, 424), 
			_campaign_map_point(482, 423), _campaign_map_point(482, 422), _campaign_map_point(482, 421), 
			_campaign_map_point(482, 420), _campaign_map_point(482, 419), _campaign_map_point(482, 418), 
			_campaign_map_point(482, 417), _campaign_map_point(482, 416), _campaign_map_point(482, 415), 
			_campaign_map_point(482, 414), _campaign_map_point(482, 413), _campaign_map_point(482, 412), 
			_campaign_map_point(482, 411), _campaign_map_point(482, 410), _campaign_map_point(482, 409), 
			_campaign_map_point(482, 408), _campaign_map_point(482, 407), _campaign_map_point(482, 406), 
			_campaign_map_point(482, 405), _campaign_map_point(482, 404), _campaign_map_point(482, 403), 
			_campaign_map_point(482, 402), _campaign_map_point(482, 401), _campaign_map_point(482, 400), 
			_campaign_map_point(482, 399), _campaign_map_point(482, 398), _campaign_map_point(482, 397), 
			_campaign_map_point(482, 396), _campaign_map_point(482, 395), _campaign_map_point(482, 394), 
			_campaign_map_point(482, 393), _campaign_map_point(482, 392), _campaign_map_point(482, 391), 
			_campaign_map_point(482, 390), _campaign_map_point(482, 389), _campaign_map_point(482, 388), 
			_campaign_map_point(482, 387), _campaign_map_point(482, 386), _campaign_map_point(482, 385), 
			_campaign_map_point(482, 384), _campaign_map_point(482, 383), _campaign_map_point(482, 382), 
			_campaign_map_point(482, 381), _campaign_map_point(482, 380), _campaign_map_point(482, 379), 
			_campaign_map_point(482, 378), _campaign_map_point(482, 377), _campaign_map_point(482, 376), 
			_campaign_map_point(482, 375), _campaign_map_point(482, 374), _campaign_map_point(482, 373), 
			_campaign_map_point(482, 372), _campaign_map_point(482, 371), _campaign_map_point(482, 370), 
			_campaign_map_point(482, 369), _campaign_map_point(482, 368), _campaign_map_point(482, 367), 
			_campaign_map_point(482, 366), _campaign_map_point(482, 365), _campaign_map_point(482, 364), 
			_campaign_map_point(482, 363), _campaign_map_point(482, 362), _campaign_map_point(482, 361), 
			_campaign_map_point(482, 360), _campaign_map_point(482, 359), _campaign_map_point(482, 358), 
			_campaign_map_point(482, 357), _campaign_map_point(482, 356), _campaign_map_point(482, 355), 
			_campaign_map_point(482, 354), _campaign_map_point(482, 353), _campaign_map_point(482, 352), 
			_campaign_map_point(482, 351), _campaign_map_point(482, 350), _campaign_map_point(482, 349), 
			_campaign_map_point(482, 348), _campaign_map_point(482, 347), _campaign_map_point(482, 346), 
			_campaign_map_point(482, 345), _campaign_map_point(482, 344), _campaign_map_point(482, 343), 
			_campaign_map_point(482, 342), _campaign_map_point(482, 341), _campaign_map_point(482, 340), 
			_campaign_map_point(482, 339), _campaign_map_point(482, 338), _campaign_map_point(482, 337), 
			_campaign_map_point(482, 336), _campaign_map_point(482, 335), _campaign_map_point(482, 334), 
			_campaign_map_point(482, 333), _campaign_map_point(482, 332), _campaign_map_point(482, 331), 
			_campaign_map_point(482, 330), _campaign_map_point(482, 329), _campaign_map_point(482, 328), 
			_campaign_map_point(482, 327), _campaign_map_point(482, 326), _campaign_map_point(482, 325), 
			_campaign_map_point(482, 324), _campaign_map_point(482, 323), _campaign_map_point(482, 322), 
			_campaign_map_point(482, 321), _campaign_map_point(482, 320), _campaign_map_point(482, 319), 
			_campaign_map_point(482, 318), _campaign_map_point(482, 317), _campaign_map_point(482, 316), 
			_campaign_map_point(482, 315), _campaign_map_point(482, 314), _campaign_map_point(482, 313), 
			_campaign_map_point(482, 312), _campaign_map_point(482, 311), _campaign_map_point(482, 310), 
			_campaign_map_point(482, 309), _campaign_map_point(482, 308), _campaign_map_point(482, 307), 
			_campaign_map_point(482, 306), _campaign_map_point(482, 305), _campaign_map_point(482, 304), 
			_campaign_map_point(482, 303), _campaign_map_point(482, 302), _campaign_map_point(482, 301), 
			_campaign_map_point(482, 300), _campaign_map_point(482, 299), _campaign_map_point(482, 298), 
			_campaign_map_point(482, 297), _campaign_map_point(482, 296), _campaign_map_point(482, 295), 
			_campaign_map_point(482, 294), _campaign_map_point(482, 293), _campaign_map_point(482, 292), 
			_campaign_map_point(482, 291), _campaign_map_point(482, 290), _campaign_map_point(482, 289), 
			_campaign_map_point(482, 288), _campaign_map_point(482, 287), _campaign_map_point(482, 286), 
			_campaign_map_point(482, 285), _campaign_map_point(482, 284), _campaign_map_point(482, 283), 
			_campaign_map_point(482, 282), _campaign_map_point(482, 281), _campaign_map_point(482, 280), 
			_campaign_map_point(482, 279), _campaign_map_point(482, 278), _campaign_map_point(482, 277), 
			_campaign_map_point(482, 276), _campaign_map_point(482, 275), _campaign_map_point(482, 274), 
			_campaign_map_point(482, 273), _campaign_map_point(482, 272), _campaign_map_point(482, 271), 
			_campaign_map_point(482, 270), _campaign_map_point(482, 269), _campaign_map_point(482, 268), 
			_campaign_map_point(482, 267), _campaign_map_point(482, 266), _campaign_map_point(482, 265), 
			_campaign_map_point(482, 264), _campaign_map_point(481, 263), _campaign_map_point(481, 262), 
			_campaign_map_point(481, 261), _campaign_map_point(481, 260), _campaign_map_point(481, 259), 
			_campaign_map_point(481, 258), _campaign_map_point(481, 257), _campaign_map_point(481, 256), 
			_campaign_map_point(481, 255), _campaign_map_point(481, 254), _campaign_map_point(478, 253), 
			_campaign_map_point(477, 252), _campaign_map_point(477, 251), _campaign_map_point(477, 250), 
			_campaign_map_point(477, 249), _campaign_map_point(477, 248), _campaign_map_point(477, 247), 
			_campaign_map_point(477, 246), _campaign_map_point(476, 245), _campaign_map_point(476, 244), 
			_campaign_map_point(476, 243), _campaign_map_point(476, 242), _campaign_map_point(475, 241), 
			_campaign_map_point(475, 240), _campaign_map_point(475, 239), _campaign_map_point(474, 238), 
			_campaign_map_point(474, 237), _campaign_map_point(474, 236), _campaign_map_point(474, 235), 
			_campaign_map_point(473, 234), _campaign_map_point(473, 233), _campaign_map_point(473, 232), 
			_campaign_map_point(472, 231), _campaign_map_point(472, 230), _campaign_map_point(472, 229), 
			_campaign_map_point(471, 228), _campaign_map_point(471, 227), _campaign_map_point(470, 226), 
			_campaign_map_point(470, 225), _campaign_map_point(470, 224), _campaign_map_point(470, 223), 
			_campaign_map_point(469, 222), _campaign_map_point(469, 221), _campaign_map_point(468, 220), 
			_campaign_map_point(468, 219), _campaign_map_point(467, 218), _campaign_map_point(467, 217), 
			_campaign_map_point(466, 216), _campaign_map_point(466, 215), _campaign_map_point(465, 214), 
			_campaign_map_point(465, 213), _campaign_map_point(464, 212), _campaign_map_point(464, 211), 
			_campaign_map_point(464, 210), _campaign_map_point(463, 209), _campaign_map_point(463, 208), 
			_campaign_map_point(462, 207), _campaign_map_point(462, 206), _campaign_map_point(461, 205), 
			_campaign_map_point(461, 204), _campaign_map_point(460, 203), _campaign_map_point(460, 202), 
			_campaign_map_point(459, 201), _campaign_map_point(459, 200), _campaign_map_point(458, 199), 
			_campaign_map_point(458, 198), _campaign_map_point(457, 197), _campaign_map_point(456, 196), 
			_campaign_map_point(456, 195), _campaign_map_point(455, 194), _campaign_map_point(454, 193), 
			_campaign_map_point(454, 192), _campaign_map_point(453, 191), _campaign_map_point(453, 190), 
			_campaign_map_point(452, 189), _campaign_map_point(451, 188), _campaign_map_point(451, 187), 
			_campaign_map_point(450, 186), _campaign_map_point(450, 185), _campaign_map_point(449, 184), 
			_campaign_map_point(448, 183), _campaign_map_point(448, 182), _campaign_map_point(447, 181), 
			_campaign_map_point(446, 180), _campaign_map_point(446, 179), _campaign_map_point(445, 178), 
			_campaign_map_point(445, 177), _campaign_map_point(444, 176), _campaign_map_point(443, 175), 
			_campaign_map_point(443, 174), _campaign_map_point(442, 173), _campaign_map_point(441, 172), 
			_campaign_map_point(440, 171), _campaign_map_point(440, 170), _campaign_map_point(439, 169), 
			_campaign_map_point(438, 168), _campaign_map_point(438, 167), _campaign_map_point(437, 166), 
			_campaign_map_point(436, 165), _campaign_map_point(435, 164), _campaign_map_point(434, 163), 
			_campaign_map_point(434, 162), _campaign_map_point(433, 161), _campaign_map_point(432, 160), 
			_campaign_map_point(431, 159), _campaign_map_point(430, 158), _campaign_map_point(429, 157), 
			_campaign_map_point(429, 156), _campaign_map_point(428, 155), _campaign_map_point(427, 154), 
			_campaign_map_point(426, 153), _campaign_map_point(425, 152), _campaign_map_point(425, 151), 
			_campaign_map_point(424, 150), _campaign_map_point(423, 149), _campaign_map_point(422, 148), 
			_campaign_map_point(422, 147), _campaign_map_point(421, 146), _campaign_map_point(420, 145), 
			_campaign_map_point(419, 144), _campaign_map_point(418, 143), _campaign_map_point(417, 142), 
			_campaign_map_point(416, 141), _campaign_map_point(415, 140), _campaign_map_point(415, 139), 
			_campaign_map_point(414, 138), _campaign_map_point(413, 137), _campaign_map_point(412, 136), 
			_campaign_map_point(410, 135), _campaign_map_point(409, 134), _campaign_map_point(408, 133), 
			_campaign_map_point(407, 132), _campaign_map_point(406, 131), _campaign_map_point(406, 130), 
			_campaign_map_point(405, 129), _campaign_map_point(404, 128), _campaign_map_point(403, 127), 
			_campaign_map_point(402, 126), _campaign_map_point(400, 125), _campaign_map_point(399, 124), 
			_campaign_map_point(398, 123), _campaign_map_point(397, 122), _campaign_map_point(396, 121), 
			_campaign_map_point(395, 120), _campaign_map_point(394, 119), _campaign_map_point(393, 118), 
			_campaign_map_point(392, 117), _campaign_map_point(390, 116), _campaign_map_point(389, 115), 
			_campaign_map_point(388, 114), _campaign_map_point(387, 113), _campaign_map_point(385, 112), 
			_campaign_map_point(384, 111), _campaign_map_point(383, 110), _campaign_map_point(382, 109), 
			_campaign_map_point(381, 108)
		]},
		{"section": "Алтарь восхваления", "mask": "res://Background/Campaign_Hover_altar.png", "points": [
			_campaign_map_point(594, 121), _campaign_map_point(592, 122), _campaign_map_point(590, 123), 
			_campaign_map_point(588, 124), _campaign_map_point(587, 125), _campaign_map_point(585, 126), 
			_campaign_map_point(584, 127), _campaign_map_point(582, 128), _campaign_map_point(581, 129), 
			_campaign_map_point(579, 130), _campaign_map_point(578, 131), _campaign_map_point(577, 132), 
			_campaign_map_point(575, 133), _campaign_map_point(574, 134), _campaign_map_point(573, 135), 
			_campaign_map_point(572, 136), _campaign_map_point(570, 137), _campaign_map_point(569, 138), 
			_campaign_map_point(568, 139), _campaign_map_point(567, 140), _campaign_map_point(566, 141), 
			_campaign_map_point(565, 142), _campaign_map_point(564, 143), _campaign_map_point(563, 144), 
			_campaign_map_point(562, 145), _campaign_map_point(562, 146), _campaign_map_point(561, 147), 
			_campaign_map_point(560, 148), _campaign_map_point(559, 149), _campaign_map_point(558, 150), 
			_campaign_map_point(557, 151), _campaign_map_point(556, 152), _campaign_map_point(555, 153), 
			_campaign_map_point(554, 154), _campaign_map_point(553, 155), _campaign_map_point(552, 156), 
			_campaign_map_point(551, 157), _campaign_map_point(550, 158), _campaign_map_point(549, 159), 
			_campaign_map_point(549, 160), _campaign_map_point(548, 161), _campaign_map_point(547, 162), 
			_campaign_map_point(546, 163), _campaign_map_point(546, 164), _campaign_map_point(545, 165), 
			_campaign_map_point(544, 166), _campaign_map_point(544, 167), _campaign_map_point(543, 168), 
			_campaign_map_point(542, 169), _campaign_map_point(541, 170), _campaign_map_point(541, 171), 
			_campaign_map_point(540, 172), _campaign_map_point(539, 173), _campaign_map_point(539, 174), 
			_campaign_map_point(538, 175), _campaign_map_point(537, 176), _campaign_map_point(537, 177), 
			_campaign_map_point(536, 178), _campaign_map_point(535, 179), _campaign_map_point(535, 180), 
			_campaign_map_point(534, 181), _campaign_map_point(534, 182), _campaign_map_point(533, 183), 
			_campaign_map_point(533, 184), _campaign_map_point(532, 185), _campaign_map_point(531, 186), 
			_campaign_map_point(531, 187), _campaign_map_point(530, 188), _campaign_map_point(530, 189), 
			_campaign_map_point(529, 190), _campaign_map_point(529, 191), _campaign_map_point(528, 192), 
			_campaign_map_point(527, 193), _campaign_map_point(527, 194), _campaign_map_point(527, 195), 
			_campaign_map_point(526, 196), _campaign_map_point(525, 197), _campaign_map_point(525, 198), 
			_campaign_map_point(525, 199), _campaign_map_point(524, 200), _campaign_map_point(524, 201), 
			_campaign_map_point(523, 202), _campaign_map_point(523, 203), _campaign_map_point(523, 204), 
			_campaign_map_point(522, 205), _campaign_map_point(522, 206), _campaign_map_point(521, 207), 
			_campaign_map_point(521, 208), _campaign_map_point(521, 209), _campaign_map_point(520, 210), 
			_campaign_map_point(520, 211), _campaign_map_point(519, 212), _campaign_map_point(519, 213), 
			_campaign_map_point(519, 214), _campaign_map_point(518, 215), _campaign_map_point(518, 216), 
			_campaign_map_point(518, 217), _campaign_map_point(517, 218), _campaign_map_point(517, 219), 
			_campaign_map_point(517, 220), _campaign_map_point(517, 221), _campaign_map_point(517, 222), 
			_campaign_map_point(516, 223), _campaign_map_point(516, 224), _campaign_map_point(516, 225), 
			_campaign_map_point(515, 226), _campaign_map_point(515, 227), _campaign_map_point(515, 228), 
			_campaign_map_point(514, 229), _campaign_map_point(514, 230), _campaign_map_point(514, 231), 
			_campaign_map_point(514, 232), _campaign_map_point(513, 233), _campaign_map_point(513, 234), 
			_campaign_map_point(513, 235), _campaign_map_point(513, 236), _campaign_map_point(513, 237), 
			_campaign_map_point(513, 238), _campaign_map_point(512, 239), _campaign_map_point(512, 240), 
			_campaign_map_point(512, 241), _campaign_map_point(512, 242), _campaign_map_point(512, 243), 
			_campaign_map_point(512, 244), _campaign_map_point(512, 245), _campaign_map_point(512, 246), 
			_campaign_map_point(512, 247), _campaign_map_point(512, 248), _campaign_map_point(512, 249), 
			_campaign_map_point(512, 250), _campaign_map_point(511, 251), _campaign_map_point(511, 252), 
			_campaign_map_point(510, 253), _campaign_map_point(508, 254), _campaign_map_point(507, 255), 
			_campaign_map_point(507, 256), _campaign_map_point(507, 257), _campaign_map_point(506, 258), 
			_campaign_map_point(506, 259), _campaign_map_point(506, 260), _campaign_map_point(506, 261), 
			_campaign_map_point(506, 262), _campaign_map_point(506, 263), _campaign_map_point(506, 264), 
			_campaign_map_point(506, 265), _campaign_map_point(507, 266), _campaign_map_point(507, 267), 
			_campaign_map_point(507, 268), _campaign_map_point(507, 269), _campaign_map_point(507, 270), 
			_campaign_map_point(507, 271), _campaign_map_point(507, 272), _campaign_map_point(507, 273), 
			_campaign_map_point(507, 274), _campaign_map_point(507, 275), _campaign_map_point(507, 276), 
			_campaign_map_point(507, 277), _campaign_map_point(507, 278), _campaign_map_point(507, 279), 
			_campaign_map_point(507, 280), _campaign_map_point(507, 281), _campaign_map_point(507, 282), 
			_campaign_map_point(507, 283), _campaign_map_point(507, 284), _campaign_map_point(507, 285), 
			_campaign_map_point(507, 286), _campaign_map_point(507, 287), _campaign_map_point(507, 288), 
			_campaign_map_point(506, 289), _campaign_map_point(506, 290), _campaign_map_point(506, 291), 
			_campaign_map_point(506, 292), _campaign_map_point(506, 293), _campaign_map_point(506, 294), 
			_campaign_map_point(506, 295), _campaign_map_point(506, 296), _campaign_map_point(506, 297), 
			_campaign_map_point(506, 298), _campaign_map_point(506, 299), _campaign_map_point(506, 300), 
			_campaign_map_point(506, 301), _campaign_map_point(506, 302), _campaign_map_point(506, 303), 
			_campaign_map_point(506, 304), _campaign_map_point(506, 305), _campaign_map_point(506, 306), 
			_campaign_map_point(506, 307), _campaign_map_point(506, 308), _campaign_map_point(506, 309), 
			_campaign_map_point(506, 310), _campaign_map_point(506, 311), _campaign_map_point(506, 312), 
			_campaign_map_point(506, 313), _campaign_map_point(506, 314), _campaign_map_point(506, 315), 
			_campaign_map_point(506, 316), _campaign_map_point(506, 317), _campaign_map_point(506, 318), 
			_campaign_map_point(506, 319), _campaign_map_point(506, 320), _campaign_map_point(506, 321), 
			_campaign_map_point(506, 322), _campaign_map_point(506, 323), _campaign_map_point(506, 324), 
			_campaign_map_point(506, 325), _campaign_map_point(506, 326), _campaign_map_point(506, 327), 
			_campaign_map_point(506, 328), _campaign_map_point(506, 329), _campaign_map_point(506, 330), 
			_campaign_map_point(506, 331), _campaign_map_point(506, 332), _campaign_map_point(506, 333), 
			_campaign_map_point(506, 334), _campaign_map_point(506, 335), _campaign_map_point(506, 336), 
			_campaign_map_point(506, 337), _campaign_map_point(506, 338), _campaign_map_point(506, 339), 
			_campaign_map_point(506, 340), _campaign_map_point(506, 341), _campaign_map_point(506, 342), 
			_campaign_map_point(506, 343), _campaign_map_point(506, 344), _campaign_map_point(506, 345), 
			_campaign_map_point(506, 346), _campaign_map_point(506, 347), _campaign_map_point(506, 348), 
			_campaign_map_point(506, 349), _campaign_map_point(506, 350), _campaign_map_point(506, 351), 
			_campaign_map_point(506, 352), _campaign_map_point(506, 353), _campaign_map_point(506, 354), 
			_campaign_map_point(506, 355), _campaign_map_point(506, 356), _campaign_map_point(506, 357), 
			_campaign_map_point(506, 358), _campaign_map_point(506, 359), _campaign_map_point(506, 360), 
			_campaign_map_point(506, 361), _campaign_map_point(506, 362), _campaign_map_point(506, 363), 
			_campaign_map_point(506, 364), _campaign_map_point(506, 365), _campaign_map_point(506, 366), 
			_campaign_map_point(506, 367), _campaign_map_point(506, 368), _campaign_map_point(506, 369), 
			_campaign_map_point(506, 370), _campaign_map_point(506, 371), _campaign_map_point(506, 372), 
			_campaign_map_point(506, 373), _campaign_map_point(506, 374), _campaign_map_point(506, 375), 
			_campaign_map_point(506, 376), _campaign_map_point(506, 377), _campaign_map_point(500, 378), 
			_campaign_map_point(500, 379), _campaign_map_point(500, 380), _campaign_map_point(500, 381), 
			_campaign_map_point(500, 382), _campaign_map_point(500, 383), _campaign_map_point(500, 384), 
			_campaign_map_point(506, 385), _campaign_map_point(506, 386), _campaign_map_point(506, 387), 
			_campaign_map_point(506, 388), _campaign_map_point(506, 389), _campaign_map_point(506, 390), 
			_campaign_map_point(506, 391), _campaign_map_point(506, 392), _campaign_map_point(506, 393), 
			_campaign_map_point(506, 394), _campaign_map_point(506, 395), _campaign_map_point(506, 396), 
			_campaign_map_point(506, 397), _campaign_map_point(506, 398), _campaign_map_point(506, 399), 
			_campaign_map_point(506, 400), _campaign_map_point(506, 401), _campaign_map_point(506, 402), 
			_campaign_map_point(506, 403), _campaign_map_point(506, 404), _campaign_map_point(506, 405), 
			_campaign_map_point(506, 406), _campaign_map_point(506, 407), _campaign_map_point(506, 408), 
			_campaign_map_point(506, 409), _campaign_map_point(506, 410), _campaign_map_point(506, 411), 
			_campaign_map_point(506, 412), _campaign_map_point(506, 413), _campaign_map_point(506, 414), 
			_campaign_map_point(506, 415), _campaign_map_point(506, 416), _campaign_map_point(506, 417), 
			_campaign_map_point(506, 418), _campaign_map_point(506, 419), _campaign_map_point(506, 420), 
			_campaign_map_point(506, 421), _campaign_map_point(506, 422), _campaign_map_point(506, 423), 
			_campaign_map_point(506, 424), _campaign_map_point(506, 425), _campaign_map_point(506, 426), 
			_campaign_map_point(506, 427), _campaign_map_point(506, 428), _campaign_map_point(506, 429), 
			_campaign_map_point(506, 430), _campaign_map_point(506, 431), _campaign_map_point(506, 432), 
			_campaign_map_point(506, 433), _campaign_map_point(506, 434), _campaign_map_point(506, 435), 
			_campaign_map_point(506, 436), _campaign_map_point(506, 437), _campaign_map_point(506, 438), 
			_campaign_map_point(506, 439), _campaign_map_point(506, 440), _campaign_map_point(506, 441), 
			_campaign_map_point(506, 442), _campaign_map_point(506, 443), _campaign_map_point(506, 444), 
			_campaign_map_point(506, 445), _campaign_map_point(506, 446), _campaign_map_point(506, 447), 
			_campaign_map_point(506, 448), _campaign_map_point(506, 449), _campaign_map_point(506, 450), 
			_campaign_map_point(506, 451), _campaign_map_point(506, 452), _campaign_map_point(506, 453), 
			_campaign_map_point(506, 454), _campaign_map_point(506, 455), _campaign_map_point(506, 456), 
			_campaign_map_point(506, 457), _campaign_map_point(506, 458), _campaign_map_point(506, 459), 
			_campaign_map_point(506, 460), _campaign_map_point(506, 461), _campaign_map_point(506, 462), 
			_campaign_map_point(506, 463), _campaign_map_point(506, 464), _campaign_map_point(506, 465), 
			_campaign_map_point(506, 466), _campaign_map_point(506, 467), _campaign_map_point(506, 468), 
			_campaign_map_point(506, 469), _campaign_map_point(506, 470), _campaign_map_point(506, 471), 
			_campaign_map_point(506, 472), _campaign_map_point(506, 473), _campaign_map_point(506, 474), 
			_campaign_map_point(506, 475), _campaign_map_point(506, 476), _campaign_map_point(506, 477), 
			_campaign_map_point(506, 478), _campaign_map_point(506, 479), _campaign_map_point(506, 480), 
			_campaign_map_point(506, 481), _campaign_map_point(506, 482), _campaign_map_point(506, 483), 
			_campaign_map_point(506, 484), _campaign_map_point(506, 485), _campaign_map_point(506, 486), 
			_campaign_map_point(506, 487), _campaign_map_point(506, 488), _campaign_map_point(506, 489), 
			_campaign_map_point(506, 490), _campaign_map_point(506, 491), _campaign_map_point(506, 492), 
			_campaign_map_point(506, 493), _campaign_map_point(506, 494), _campaign_map_point(506, 495), 
			_campaign_map_point(506, 496), _campaign_map_point(506, 497), _campaign_map_point(506, 498), 
			_campaign_map_point(506, 499), _campaign_map_point(506, 500), _campaign_map_point(506, 501), 
			_campaign_map_point(506, 502), _campaign_map_point(506, 503), _campaign_map_point(506, 504), 
			_campaign_map_point(506, 505), _campaign_map_point(506, 506), _campaign_map_point(506, 507), 
			_campaign_map_point(506, 508), _campaign_map_point(506, 509), _campaign_map_point(506, 510), 
			_campaign_map_point(506, 511), _campaign_map_point(506, 512), _campaign_map_point(506, 513), 
			_campaign_map_point(506, 514), _campaign_map_point(506, 515), _campaign_map_point(506, 516), 
			_campaign_map_point(506, 517), _campaign_map_point(506, 518), _campaign_map_point(506, 519), 
			_campaign_map_point(506, 520), _campaign_map_point(506, 521), _campaign_map_point(506, 522), 
			_campaign_map_point(506, 523), _campaign_map_point(506, 524), _campaign_map_point(506, 525), 
			_campaign_map_point(506, 526), _campaign_map_point(506, 527), _campaign_map_point(506, 528), 
			_campaign_map_point(506, 529), _campaign_map_point(506, 530), _campaign_map_point(506, 531), 
			_campaign_map_point(506, 532), _campaign_map_point(506, 533), _campaign_map_point(506, 534), 
			_campaign_map_point(506, 535), _campaign_map_point(506, 536), _campaign_map_point(506, 537), 
			_campaign_map_point(506, 538), _campaign_map_point(506, 539), _campaign_map_point(506, 540), 
			_campaign_map_point(506, 541), _campaign_map_point(506, 542), _campaign_map_point(506, 543), 
			_campaign_map_point(506, 544), _campaign_map_point(506, 545), _campaign_map_point(506, 546), 
			_campaign_map_point(506, 547), _campaign_map_point(506, 548), _campaign_map_point(506, 549), 
			_campaign_map_point(506, 550), _campaign_map_point(506, 551), _campaign_map_point(506, 552), 
			_campaign_map_point(506, 553), _campaign_map_point(506, 554), _campaign_map_point(506, 555), 
			_campaign_map_point(506, 556), _campaign_map_point(506, 557), _campaign_map_point(506, 558), 
			_campaign_map_point(506, 559), _campaign_map_point(506, 560), _campaign_map_point(506, 561), 
			_campaign_map_point(506, 562), _campaign_map_point(506, 563), _campaign_map_point(506, 564), 
			_campaign_map_point(506, 565), _campaign_map_point(506, 566), _campaign_map_point(506, 567), 
			_campaign_map_point(506, 568), _campaign_map_point(506, 569), _campaign_map_point(506, 570), 
			_campaign_map_point(506, 571), _campaign_map_point(506, 572), _campaign_map_point(506, 573), 
			_campaign_map_point(506, 574), _campaign_map_point(506, 575), _campaign_map_point(506, 576), 
			_campaign_map_point(506, 577), _campaign_map_point(506, 578), _campaign_map_point(506, 579), 
			_campaign_map_point(506, 580), _campaign_map_point(506, 581), _campaign_map_point(506, 582), 
			_campaign_map_point(506, 583), _campaign_map_point(506, 584), _campaign_map_point(506, 585), 
			_campaign_map_point(506, 586), _campaign_map_point(506, 587), _campaign_map_point(506, 588), 
			_campaign_map_point(506, 589), _campaign_map_point(506, 590), _campaign_map_point(506, 591), 
			_campaign_map_point(506, 592), _campaign_map_point(506, 593), _campaign_map_point(506, 594), 
			_campaign_map_point(506, 595), _campaign_map_point(506, 596), _campaign_map_point(506, 597), 
			_campaign_map_point(506, 598), _campaign_map_point(506, 599), _campaign_map_point(506, 600), 
			_campaign_map_point(506, 601), _campaign_map_point(506, 602), _campaign_map_point(506, 603), 
			_campaign_map_point(506, 604), _campaign_map_point(506, 605), _campaign_map_point(506, 606), 
			_campaign_map_point(506, 607), _campaign_map_point(506, 608), _campaign_map_point(506, 609), 
			_campaign_map_point(506, 610), _campaign_map_point(506, 611), _campaign_map_point(506, 612), 
			_campaign_map_point(506, 613), _campaign_map_point(506, 614), _campaign_map_point(506, 615), 
			_campaign_map_point(506, 616), _campaign_map_point(506, 617), _campaign_map_point(506, 618), 
			_campaign_map_point(506, 619), _campaign_map_point(506, 620), _campaign_map_point(506, 621), 
			_campaign_map_point(506, 622), _campaign_map_point(506, 623), _campaign_map_point(506, 624), 
			_campaign_map_point(506, 625), _campaign_map_point(506, 626), _campaign_map_point(506, 627), 
			_campaign_map_point(506, 628), _campaign_map_point(506, 629), _campaign_map_point(506, 630), 
			_campaign_map_point(506, 631), _campaign_map_point(506, 632), _campaign_map_point(506, 633), 
			_campaign_map_point(506, 634), _campaign_map_point(506, 635), _campaign_map_point(506, 636), 
			_campaign_map_point(506, 637), _campaign_map_point(506, 638), _campaign_map_point(506, 639), 
			_campaign_map_point(506, 640), _campaign_map_point(506, 641), _campaign_map_point(506, 642), 
			_campaign_map_point(506, 643), _campaign_map_point(506, 644), _campaign_map_point(506, 645), 
			_campaign_map_point(506, 646), _campaign_map_point(506, 647), _campaign_map_point(506, 648), 
			_campaign_map_point(506, 649), _campaign_map_point(506, 650), _campaign_map_point(506, 651), 
			_campaign_map_point(506, 652), _campaign_map_point(506, 653), _campaign_map_point(506, 654), 
			_campaign_map_point(506, 655), _campaign_map_point(506, 656), _campaign_map_point(506, 657), 
			_campaign_map_point(506, 658), _campaign_map_point(506, 659), _campaign_map_point(506, 660), 
			_campaign_map_point(506, 661), _campaign_map_point(506, 662), _campaign_map_point(506, 663), 
			_campaign_map_point(506, 664), _campaign_map_point(506, 665), _campaign_map_point(506, 666), 
			_campaign_map_point(506, 667), _campaign_map_point(506, 668), _campaign_map_point(506, 669), 
			_campaign_map_point(506, 670), _campaign_map_point(506, 671), _campaign_map_point(506, 672), 
			_campaign_map_point(506, 673), _campaign_map_point(506, 674), _campaign_map_point(506, 675), 
			_campaign_map_point(506, 676), _campaign_map_point(506, 677), _campaign_map_point(506, 678), 
			_campaign_map_point(506, 679), _campaign_map_point(506, 680), _campaign_map_point(506, 681), 
			_campaign_map_point(506, 682), _campaign_map_point(506, 683), _campaign_map_point(507, 684), 
			_campaign_map_point(507, 685), _campaign_map_point(507, 686), _campaign_map_point(507, 687), 
			_campaign_map_point(507, 688), _campaign_map_point(507, 689), _campaign_map_point(507, 690), 
			_campaign_map_point(507, 691), _campaign_map_point(507, 692), _campaign_map_point(507, 693), 
			_campaign_map_point(507, 694), _campaign_map_point(508, 695), _campaign_map_point(508, 696), 
			_campaign_map_point(508, 697), _campaign_map_point(508, 698), _campaign_map_point(508, 699), 
			_campaign_map_point(508, 700), _campaign_map_point(508, 701), _campaign_map_point(508, 702), 
			_campaign_map_point(508, 703), _campaign_map_point(508, 704), _campaign_map_point(508, 705), 
			_campaign_map_point(508, 706), _campaign_map_point(508, 707), _campaign_map_point(508, 708), 
			_campaign_map_point(508, 709), _campaign_map_point(508, 710), _campaign_map_point(508, 711), 
			_campaign_map_point(508, 712), _campaign_map_point(508, 713), _campaign_map_point(508, 714), 
			_campaign_map_point(508, 715), _campaign_map_point(508, 716), _campaign_map_point(508, 717), 
			_campaign_map_point(508, 718), _campaign_map_point(508, 719), _campaign_map_point(508, 720), 
			_campaign_map_point(508, 721), _campaign_map_point(509, 722), _campaign_map_point(510, 723), 
			_campaign_map_point(511, 724), _campaign_map_point(512, 725), _campaign_map_point(512, 726), 
			_campaign_map_point(660, 735), _campaign_map_point(642, 736), _campaign_map_point(624, 737), 
			_campaign_map_point(611, 738), _campaign_map_point(593, 739), _campaign_map_point(571, 740), 
			_campaign_map_point(548, 741), _campaign_map_point(524, 742), _campaign_map_point(500, 743), 
			_campaign_map_point(500, 744), _campaign_map_point(500, 745), _campaign_map_point(500, 746), 
			_campaign_map_point(500, 747), _campaign_map_point(500, 748), _campaign_map_point(500, 749), 
			_campaign_map_point(500, 750), _campaign_map_point(500, 751), _campaign_map_point(500, 752), 
			_campaign_map_point(500, 753), _campaign_map_point(500, 754), _campaign_map_point(500, 755), 
			_campaign_map_point(500, 756), _campaign_map_point(500, 757), _campaign_map_point(500, 758), 
			_campaign_map_point(500, 759), _campaign_map_point(500, 760), _campaign_map_point(500, 761), 
			_campaign_map_point(500, 762), _campaign_map_point(500, 763), _campaign_map_point(500, 764), 
			_campaign_map_point(500, 765), _campaign_map_point(500, 766), _campaign_map_point(500, 767), 
			_campaign_map_point(500, 768), _campaign_map_point(500, 769), _campaign_map_point(500, 770), 
			_campaign_map_point(500, 771), _campaign_map_point(500, 772), _campaign_map_point(500, 773), 
			_campaign_map_point(500, 774), _campaign_map_point(500, 775), _campaign_map_point(500, 776), 
			_campaign_map_point(500, 777), _campaign_map_point(500, 778), _campaign_map_point(500, 779), 
			_campaign_map_point(500, 780), _campaign_map_point(500, 781), _campaign_map_point(500, 782), 
			_campaign_map_point(500, 783), _campaign_map_point(500, 784), _campaign_map_point(500, 785), 
			_campaign_map_point(500, 786), _campaign_map_point(500, 787), _campaign_map_point(500, 788), 
			_campaign_map_point(500, 789), _campaign_map_point(500, 790), _campaign_map_point(500, 791), 
			_campaign_map_point(500, 792), _campaign_map_point(500, 793), _campaign_map_point(500, 794), 
			_campaign_map_point(500, 795), _campaign_map_point(500, 796), _campaign_map_point(500, 797), 
			_campaign_map_point(500, 798), _campaign_map_point(500, 799), _campaign_map_point(500, 800), 
			_campaign_map_point(500, 801), _campaign_map_point(500, 802), _campaign_map_point(500, 803), 
			_campaign_map_point(500, 804), _campaign_map_point(500, 805), _campaign_map_point(500, 806), 
			_campaign_map_point(500, 807), _campaign_map_point(500, 808), _campaign_map_point(500, 809), 
			_campaign_map_point(500, 810), _campaign_map_point(640, 810), _campaign_map_point(640, 809), 
			_campaign_map_point(640, 808), _campaign_map_point(640, 807), _campaign_map_point(640, 806), 
			_campaign_map_point(640, 805), _campaign_map_point(641, 804), _campaign_map_point(641, 803), 
			_campaign_map_point(642, 802), _campaign_map_point(642, 801), _campaign_map_point(643, 800), 
			_campaign_map_point(644, 799), _campaign_map_point(644, 798), _campaign_map_point(645, 797), 
			_campaign_map_point(645, 796), _campaign_map_point(646, 795), _campaign_map_point(646, 794), 
			_campaign_map_point(647, 793), _campaign_map_point(647, 792), _campaign_map_point(648, 791), 
			_campaign_map_point(649, 790), _campaign_map_point(649, 789), _campaign_map_point(650, 788), 
			_campaign_map_point(650, 787), _campaign_map_point(651, 786), _campaign_map_point(651, 785), 
			_campaign_map_point(652, 784), _campaign_map_point(652, 783), _campaign_map_point(653, 782), 
			_campaign_map_point(653, 781), _campaign_map_point(654, 780), _campaign_map_point(654, 779), 
			_campaign_map_point(655, 778), _campaign_map_point(655, 777), _campaign_map_point(656, 776), 
			_campaign_map_point(656, 775), _campaign_map_point(657, 774), _campaign_map_point(657, 773), 
			_campaign_map_point(658, 772), _campaign_map_point(659, 771), _campaign_map_point(659, 770), 
			_campaign_map_point(660, 769), _campaign_map_point(660, 768), _campaign_map_point(661, 767), 
			_campaign_map_point(661, 766), _campaign_map_point(662, 765), _campaign_map_point(662, 764), 
			_campaign_map_point(663, 763), _campaign_map_point(663, 762), _campaign_map_point(664, 761), 
			_campaign_map_point(664, 760), _campaign_map_point(665, 759), _campaign_map_point(666, 758), 
			_campaign_map_point(666, 757), _campaign_map_point(667, 756), _campaign_map_point(667, 755), 
			_campaign_map_point(668, 754), _campaign_map_point(668, 753), _campaign_map_point(669, 752), 
			_campaign_map_point(669, 751), _campaign_map_point(670, 750), _campaign_map_point(670, 749), 
			_campaign_map_point(671, 748), _campaign_map_point(671, 747), _campaign_map_point(672, 746), 
			_campaign_map_point(672, 745), _campaign_map_point(673, 744), _campaign_map_point(673, 743), 
			_campaign_map_point(674, 742), _campaign_map_point(674, 741), _campaign_map_point(675, 740), 
			_campaign_map_point(675, 739), _campaign_map_point(676, 738), _campaign_map_point(677, 737), 
			_campaign_map_point(677, 736), _campaign_map_point(678, 735), _campaign_map_point(682, 726), 
			_campaign_map_point(683, 725), _campaign_map_point(683, 724), _campaign_map_point(684, 723), 
			_campaign_map_point(684, 722), _campaign_map_point(685, 721), _campaign_map_point(685, 720), 
			_campaign_map_point(686, 719), _campaign_map_point(686, 718), _campaign_map_point(687, 717), 
			_campaign_map_point(687, 716), _campaign_map_point(687, 715), _campaign_map_point(687, 714), 
			_campaign_map_point(687, 713), _campaign_map_point(687, 712), _campaign_map_point(687, 711), 
			_campaign_map_point(687, 710), _campaign_map_point(687, 709), _campaign_map_point(687, 708), 
			_campaign_map_point(688, 707), _campaign_map_point(688, 706), _campaign_map_point(688, 705), 
			_campaign_map_point(688, 704), _campaign_map_point(688, 703), _campaign_map_point(688, 702), 
			_campaign_map_point(689, 701), _campaign_map_point(689, 700), _campaign_map_point(689, 699), 
			_campaign_map_point(690, 698), _campaign_map_point(690, 697), _campaign_map_point(690, 696), 
			_campaign_map_point(690, 695), _campaign_map_point(690, 694), _campaign_map_point(690, 693), 
			_campaign_map_point(690, 692), _campaign_map_point(690, 691), _campaign_map_point(690, 690), 
			_campaign_map_point(690, 689), _campaign_map_point(692, 688), _campaign_map_point(692, 687), 
			_campaign_map_point(692, 686), _campaign_map_point(692, 685), _campaign_map_point(692, 684), 
			_campaign_map_point(692, 683), _campaign_map_point(692, 682), _campaign_map_point(692, 681), 
			_campaign_map_point(692, 680), _campaign_map_point(692, 679), _campaign_map_point(692, 678), 
			_campaign_map_point(692, 677), _campaign_map_point(692, 676), _campaign_map_point(692, 675), 
			_campaign_map_point(692, 674), _campaign_map_point(691, 673), _campaign_map_point(691, 672), 
			_campaign_map_point(691, 671), _campaign_map_point(691, 670), _campaign_map_point(691, 669), 
			_campaign_map_point(691, 668), _campaign_map_point(691, 667), _campaign_map_point(691, 666), 
			_campaign_map_point(691, 665), _campaign_map_point(691, 664), _campaign_map_point(691, 663), 
			_campaign_map_point(691, 662), _campaign_map_point(692, 661), _campaign_map_point(692, 660), 
			_campaign_map_point(692, 659), _campaign_map_point(692, 658), _campaign_map_point(692, 657), 
			_campaign_map_point(692, 656), _campaign_map_point(692, 655), _campaign_map_point(692, 654), 
			_campaign_map_point(692, 653), _campaign_map_point(692, 652), _campaign_map_point(692, 651), 
			_campaign_map_point(692, 650), _campaign_map_point(692, 649), _campaign_map_point(692, 648), 
			_campaign_map_point(692, 647), _campaign_map_point(692, 646), _campaign_map_point(692, 645), 
			_campaign_map_point(692, 644), _campaign_map_point(692, 643), _campaign_map_point(692, 642), 
			_campaign_map_point(692, 641), _campaign_map_point(692, 640), _campaign_map_point(692, 639), 
			_campaign_map_point(692, 638), _campaign_map_point(692, 637), _campaign_map_point(692, 636), 
			_campaign_map_point(692, 635), _campaign_map_point(692, 634), _campaign_map_point(692, 633), 
			_campaign_map_point(692, 632), _campaign_map_point(692, 631), _campaign_map_point(692, 630), 
			_campaign_map_point(692, 629), _campaign_map_point(692, 628), _campaign_map_point(692, 627), 
			_campaign_map_point(692, 626), _campaign_map_point(692, 625), _campaign_map_point(692, 624), 
			_campaign_map_point(692, 623), _campaign_map_point(692, 622), _campaign_map_point(692, 621), 
			_campaign_map_point(692, 620), _campaign_map_point(692, 619), _campaign_map_point(692, 618), 
			_campaign_map_point(692, 617), _campaign_map_point(692, 616), _campaign_map_point(692, 615), 
			_campaign_map_point(692, 614), _campaign_map_point(692, 613), _campaign_map_point(692, 612), 
			_campaign_map_point(692, 611), _campaign_map_point(692, 610), _campaign_map_point(692, 609), 
			_campaign_map_point(692, 608), _campaign_map_point(692, 607), _campaign_map_point(692, 606), 
			_campaign_map_point(692, 605), _campaign_map_point(692, 604), _campaign_map_point(692, 603), 
			_campaign_map_point(692, 602), _campaign_map_point(692, 601), _campaign_map_point(692, 600), 
			_campaign_map_point(692, 599), _campaign_map_point(692, 598), _campaign_map_point(692, 597), 
			_campaign_map_point(692, 596), _campaign_map_point(692, 595), _campaign_map_point(692, 594), 
			_campaign_map_point(692, 593), _campaign_map_point(693, 592), _campaign_map_point(693, 591), 
			_campaign_map_point(693, 590), _campaign_map_point(693, 589), _campaign_map_point(693, 588), 
			_campaign_map_point(693, 587), _campaign_map_point(692, 586), _campaign_map_point(692, 585), 
			_campaign_map_point(692, 584), _campaign_map_point(692, 583), _campaign_map_point(692, 582), 
			_campaign_map_point(692, 581), _campaign_map_point(692, 580), _campaign_map_point(692, 579), 
			_campaign_map_point(692, 578), _campaign_map_point(692, 577), _campaign_map_point(692, 576), 
			_campaign_map_point(692, 575), _campaign_map_point(692, 574), _campaign_map_point(692, 573), 
			_campaign_map_point(692, 572), _campaign_map_point(692, 571), _campaign_map_point(692, 570), 
			_campaign_map_point(692, 569), _campaign_map_point(692, 568), _campaign_map_point(692, 567), 
			_campaign_map_point(692, 566), _campaign_map_point(692, 565), _campaign_map_point(692, 564), 
			_campaign_map_point(692, 563), _campaign_map_point(692, 562), _campaign_map_point(692, 561), 
			_campaign_map_point(692, 560), _campaign_map_point(692, 559), _campaign_map_point(692, 558), 
			_campaign_map_point(692, 557), _campaign_map_point(692, 556), _campaign_map_point(692, 555), 
			_campaign_map_point(692, 554), _campaign_map_point(692, 553), _campaign_map_point(692, 552), 
			_campaign_map_point(692, 551), _campaign_map_point(692, 550), _campaign_map_point(692, 549), 
			_campaign_map_point(692, 548), _campaign_map_point(692, 547), _campaign_map_point(692, 546), 
			_campaign_map_point(692, 545), _campaign_map_point(692, 544), _campaign_map_point(692, 543), 
			_campaign_map_point(692, 542), _campaign_map_point(692, 541), _campaign_map_point(692, 540), 
			_campaign_map_point(692, 539), _campaign_map_point(692, 538), _campaign_map_point(692, 537), 
			_campaign_map_point(692, 536), _campaign_map_point(692, 535), _campaign_map_point(692, 534), 
			_campaign_map_point(692, 533), _campaign_map_point(692, 532), _campaign_map_point(692, 531), 
			_campaign_map_point(692, 530), _campaign_map_point(692, 529), _campaign_map_point(692, 528), 
			_campaign_map_point(692, 527), _campaign_map_point(692, 526), _campaign_map_point(692, 525), 
			_campaign_map_point(692, 524), _campaign_map_point(692, 523), _campaign_map_point(692, 522), 
			_campaign_map_point(692, 521), _campaign_map_point(692, 520), _campaign_map_point(692, 519), 
			_campaign_map_point(692, 518), _campaign_map_point(692, 517), _campaign_map_point(692, 516), 
			_campaign_map_point(692, 515), _campaign_map_point(692, 514), _campaign_map_point(692, 513), 
			_campaign_map_point(692, 512), _campaign_map_point(692, 511), _campaign_map_point(692, 510), 
			_campaign_map_point(692, 509), _campaign_map_point(692, 508), _campaign_map_point(692, 507), 
			_campaign_map_point(692, 506), _campaign_map_point(692, 505), _campaign_map_point(692, 504), 
			_campaign_map_point(692, 503), _campaign_map_point(692, 502), _campaign_map_point(692, 501), 
			_campaign_map_point(692, 500), _campaign_map_point(692, 499), _campaign_map_point(692, 498), 
			_campaign_map_point(692, 497), _campaign_map_point(692, 496), _campaign_map_point(692, 495), 
			_campaign_map_point(692, 494), _campaign_map_point(692, 493), _campaign_map_point(692, 492), 
			_campaign_map_point(692, 491), _campaign_map_point(692, 490), _campaign_map_point(692, 489), 
			_campaign_map_point(692, 488), _campaign_map_point(692, 487), _campaign_map_point(692, 486), 
			_campaign_map_point(692, 485), _campaign_map_point(692, 484), _campaign_map_point(692, 483), 
			_campaign_map_point(692, 482), _campaign_map_point(692, 481), _campaign_map_point(692, 480), 
			_campaign_map_point(692, 479), _campaign_map_point(692, 478), _campaign_map_point(692, 477), 
			_campaign_map_point(692, 476), _campaign_map_point(692, 475), _campaign_map_point(692, 474), 
			_campaign_map_point(692, 473), _campaign_map_point(692, 472), _campaign_map_point(692, 471), 
			_campaign_map_point(692, 470), _campaign_map_point(692, 469), _campaign_map_point(692, 468), 
			_campaign_map_point(692, 467), _campaign_map_point(692, 466), _campaign_map_point(692, 465), 
			_campaign_map_point(692, 464), _campaign_map_point(692, 463), _campaign_map_point(692, 462), 
			_campaign_map_point(692, 461), _campaign_map_point(692, 460), _campaign_map_point(692, 459), 
			_campaign_map_point(692, 458), _campaign_map_point(692, 457), _campaign_map_point(692, 456), 
			_campaign_map_point(692, 455), _campaign_map_point(692, 454), _campaign_map_point(692, 453), 
			_campaign_map_point(692, 452), _campaign_map_point(692, 451), _campaign_map_point(692, 450), 
			_campaign_map_point(692, 449), _campaign_map_point(692, 448), _campaign_map_point(692, 447), 
			_campaign_map_point(692, 446), _campaign_map_point(692, 445), _campaign_map_point(692, 444), 
			_campaign_map_point(692, 443), _campaign_map_point(692, 442), _campaign_map_point(692, 441), 
			_campaign_map_point(692, 440), _campaign_map_point(692, 439), _campaign_map_point(692, 438), 
			_campaign_map_point(692, 437), _campaign_map_point(692, 436), _campaign_map_point(692, 435), 
			_campaign_map_point(692, 434), _campaign_map_point(692, 433), _campaign_map_point(692, 432), 
			_campaign_map_point(692, 431), _campaign_map_point(692, 430), _campaign_map_point(692, 429), 
			_campaign_map_point(692, 428), _campaign_map_point(692, 427), _campaign_map_point(692, 426), 
			_campaign_map_point(692, 425), _campaign_map_point(692, 424), _campaign_map_point(692, 423), 
			_campaign_map_point(692, 422), _campaign_map_point(692, 421), _campaign_map_point(692, 420), 
			_campaign_map_point(692, 419), _campaign_map_point(692, 418), _campaign_map_point(692, 417), 
			_campaign_map_point(692, 416), _campaign_map_point(692, 415), _campaign_map_point(692, 414), 
			_campaign_map_point(692, 413), _campaign_map_point(692, 412), _campaign_map_point(692, 411), 
			_campaign_map_point(692, 410), _campaign_map_point(692, 409), _campaign_map_point(692, 408), 
			_campaign_map_point(692, 407), _campaign_map_point(692, 406), _campaign_map_point(692, 405), 
			_campaign_map_point(692, 404), _campaign_map_point(692, 403), _campaign_map_point(692, 402), 
			_campaign_map_point(692, 401), _campaign_map_point(692, 400), _campaign_map_point(692, 399), 
			_campaign_map_point(692, 398), _campaign_map_point(692, 397), _campaign_map_point(692, 396), 
			_campaign_map_point(692, 395), _campaign_map_point(692, 394), _campaign_map_point(692, 393), 
			_campaign_map_point(692, 392), _campaign_map_point(692, 391), _campaign_map_point(692, 390), 
			_campaign_map_point(692, 389), _campaign_map_point(692, 388), _campaign_map_point(692, 387), 
			_campaign_map_point(692, 386), _campaign_map_point(692, 385), _campaign_map_point(692, 384), 
			_campaign_map_point(692, 383), _campaign_map_point(692, 382), _campaign_map_point(692, 381), 
			_campaign_map_point(692, 380), _campaign_map_point(692, 379), _campaign_map_point(692, 378), 
			_campaign_map_point(692, 377), _campaign_map_point(692, 376), _campaign_map_point(692, 375), 
			_campaign_map_point(692, 374), _campaign_map_point(692, 373), _campaign_map_point(692, 372), 
			_campaign_map_point(692, 371), _campaign_map_point(692, 370), _campaign_map_point(692, 369), 
			_campaign_map_point(692, 368), _campaign_map_point(692, 367), _campaign_map_point(692, 366), 
			_campaign_map_point(692, 365), _campaign_map_point(692, 364), _campaign_map_point(692, 363), 
			_campaign_map_point(692, 362), _campaign_map_point(692, 361), _campaign_map_point(692, 360), 
			_campaign_map_point(692, 359), _campaign_map_point(692, 358), _campaign_map_point(692, 357), 
			_campaign_map_point(692, 356), _campaign_map_point(692, 355), _campaign_map_point(691, 354), 
			_campaign_map_point(691, 353), _campaign_map_point(691, 352), _campaign_map_point(691, 351), 
			_campaign_map_point(691, 350), _campaign_map_point(691, 349), _campaign_map_point(691, 348), 
			_campaign_map_point(691, 347), _campaign_map_point(691, 346), _campaign_map_point(691, 345), 
			_campaign_map_point(691, 344), _campaign_map_point(691, 343), _campaign_map_point(691, 342), 
			_campaign_map_point(691, 341), _campaign_map_point(691, 340), _campaign_map_point(691, 339), 
			_campaign_map_point(691, 338), _campaign_map_point(691, 337), _campaign_map_point(691, 336), 
			_campaign_map_point(692, 335), _campaign_map_point(692, 334), _campaign_map_point(692, 333), 
			_campaign_map_point(692, 332), _campaign_map_point(692, 331), _campaign_map_point(692, 330), 
			_campaign_map_point(692, 329), _campaign_map_point(692, 328), _campaign_map_point(692, 327), 
			_campaign_map_point(692, 326), _campaign_map_point(692, 325), _campaign_map_point(692, 324), 
			_campaign_map_point(692, 323), _campaign_map_point(692, 322), _campaign_map_point(692, 321), 
			_campaign_map_point(692, 320), _campaign_map_point(692, 319), _campaign_map_point(692, 318), 
			_campaign_map_point(692, 317), _campaign_map_point(692, 316), _campaign_map_point(692, 315), 
			_campaign_map_point(692, 314), _campaign_map_point(692, 313), _campaign_map_point(692, 312), 
			_campaign_map_point(692, 311), _campaign_map_point(692, 310), _campaign_map_point(692, 309), 
			_campaign_map_point(692, 308), _campaign_map_point(692, 307), _campaign_map_point(692, 306), 
			_campaign_map_point(692, 305), _campaign_map_point(692, 304), _campaign_map_point(692, 303), 
			_campaign_map_point(692, 302), _campaign_map_point(692, 301), _campaign_map_point(692, 300), 
			_campaign_map_point(692, 299), _campaign_map_point(692, 298), _campaign_map_point(692, 297), 
			_campaign_map_point(692, 296), _campaign_map_point(692, 295), _campaign_map_point(692, 294), 
			_campaign_map_point(692, 293), _campaign_map_point(692, 292), _campaign_map_point(692, 291), 
			_campaign_map_point(692, 290), _campaign_map_point(692, 289), _campaign_map_point(692, 288), 
			_campaign_map_point(692, 287), _campaign_map_point(692, 286), _campaign_map_point(692, 285), 
			_campaign_map_point(692, 284), _campaign_map_point(692, 283), _campaign_map_point(692, 282), 
			_campaign_map_point(692, 281), _campaign_map_point(692, 280), _campaign_map_point(692, 279), 
			_campaign_map_point(691, 278), _campaign_map_point(691, 277), _campaign_map_point(691, 276), 
			_campaign_map_point(691, 275), _campaign_map_point(691, 274), _campaign_map_point(691, 273), 
			_campaign_map_point(691, 272), _campaign_map_point(691, 271), _campaign_map_point(691, 270), 
			_campaign_map_point(691, 269), _campaign_map_point(691, 268), _campaign_map_point(691, 267), 
			_campaign_map_point(692, 266), _campaign_map_point(692, 265), _campaign_map_point(692, 264), 
			_campaign_map_point(692, 263), _campaign_map_point(692, 262), _campaign_map_point(692, 261), 
			_campaign_map_point(692, 260), _campaign_map_point(692, 259), _campaign_map_point(691, 258), 
			_campaign_map_point(691, 257), _campaign_map_point(691, 256), _campaign_map_point(691, 255), 
			_campaign_map_point(691, 254), _campaign_map_point(691, 253), _campaign_map_point(691, 252), 
			_campaign_map_point(690, 251), _campaign_map_point(689, 250), _campaign_map_point(685, 249), 
			_campaign_map_point(685, 248), _campaign_map_point(685, 247), _campaign_map_point(685, 246), 
			_campaign_map_point(685, 245), _campaign_map_point(685, 244), _campaign_map_point(685, 243), 
			_campaign_map_point(685, 242), _campaign_map_point(685, 241), _campaign_map_point(685, 240), 
			_campaign_map_point(685, 239), _campaign_map_point(685, 238), _campaign_map_point(684, 237), 
			_campaign_map_point(684, 236), _campaign_map_point(684, 235), _campaign_map_point(684, 234), 
			_campaign_map_point(684, 233), _campaign_map_point(684, 232), _campaign_map_point(684, 231), 
			_campaign_map_point(683, 230), _campaign_map_point(683, 229), _campaign_map_point(683, 228), 
			_campaign_map_point(682, 227), _campaign_map_point(682, 226), _campaign_map_point(681, 225), 
			_campaign_map_point(681, 224), _campaign_map_point(680, 223), _campaign_map_point(680, 222), 
			_campaign_map_point(680, 221), _campaign_map_point(679, 220), _campaign_map_point(679, 219), 
			_campaign_map_point(679, 218), _campaign_map_point(678, 217), _campaign_map_point(678, 216), 
			_campaign_map_point(677, 215), _campaign_map_point(677, 214), _campaign_map_point(676, 213), 
			_campaign_map_point(676, 212), _campaign_map_point(675, 211), _campaign_map_point(675, 210), 
			_campaign_map_point(674, 209), _campaign_map_point(674, 208), _campaign_map_point(673, 207), 
			_campaign_map_point(673, 206), _campaign_map_point(672, 205), _campaign_map_point(672, 204), 
			_campaign_map_point(671, 203), _campaign_map_point(671, 202), _campaign_map_point(670, 201), 
			_campaign_map_point(670, 200), _campaign_map_point(669, 199), _campaign_map_point(669, 198), 
			_campaign_map_point(668, 197), _campaign_map_point(668, 196), _campaign_map_point(667, 195), 
			_campaign_map_point(666, 194), _campaign_map_point(666, 193), _campaign_map_point(665, 192), 
			_campaign_map_point(665, 191), _campaign_map_point(664, 190), _campaign_map_point(663, 189), 
			_campaign_map_point(663, 188), _campaign_map_point(662, 187), _campaign_map_point(661, 186), 
			_campaign_map_point(661, 185), _campaign_map_point(661, 184), _campaign_map_point(660, 183), 
			_campaign_map_point(659, 182), _campaign_map_point(659, 181), _campaign_map_point(658, 180), 
			_campaign_map_point(657, 179), _campaign_map_point(657, 178), _campaign_map_point(656, 177), 
			_campaign_map_point(656, 176), _campaign_map_point(655, 175), _campaign_map_point(654, 174), 
			_campaign_map_point(653, 173), _campaign_map_point(653, 172), _campaign_map_point(652, 171), 
			_campaign_map_point(651, 170), _campaign_map_point(650, 169), _campaign_map_point(649, 168), 
			_campaign_map_point(649, 167), _campaign_map_point(648, 166), _campaign_map_point(647, 165), 
			_campaign_map_point(647, 164), _campaign_map_point(646, 163), _campaign_map_point(645, 162), 
			_campaign_map_point(644, 161), _campaign_map_point(643, 160), _campaign_map_point(642, 159), 
			_campaign_map_point(642, 158), _campaign_map_point(641, 157), _campaign_map_point(640, 156), 
			_campaign_map_point(639, 155), _campaign_map_point(638, 154), _campaign_map_point(637, 153), 
			_campaign_map_point(636, 152), _campaign_map_point(635, 151), _campaign_map_point(634, 150), 
			_campaign_map_point(633, 149), _campaign_map_point(632, 148), _campaign_map_point(631, 147), 
			_campaign_map_point(630, 146), _campaign_map_point(630, 145), _campaign_map_point(629, 144), 
			_campaign_map_point(628, 143), _campaign_map_point(627, 142), _campaign_map_point(626, 141), 
			_campaign_map_point(625, 140), _campaign_map_point(624, 139), _campaign_map_point(622, 138), 
			_campaign_map_point(621, 137), _campaign_map_point(620, 136), _campaign_map_point(618, 135), 
			_campaign_map_point(617, 134), _campaign_map_point(616, 133), _campaign_map_point(614, 132), 
			_campaign_map_point(613, 131), _campaign_map_point(612, 130), _campaign_map_point(610, 129), 
			_campaign_map_point(609, 128), _campaign_map_point(608, 127), _campaign_map_point(606, 126), 
			_campaign_map_point(605, 125), _campaign_map_point(604, 124), _campaign_map_point(602, 123), 
			_campaign_map_point(601, 122), _campaign_map_point(599, 121)
		]},
		{"section": "Ворота", "mask": "res://Background/Campaign_Hover_gates.png", "points": [
			_campaign_map_point(837, 46), _campaign_map_point(836, 47), _campaign_map_point(834, 48), 
			_campaign_map_point(832, 49), _campaign_map_point(831, 50), _campaign_map_point(829, 51), 
			_campaign_map_point(827, 52), _campaign_map_point(826, 53), _campaign_map_point(824, 54), 
			_campaign_map_point(822, 55), _campaign_map_point(821, 56), _campaign_map_point(819, 57), 
			_campaign_map_point(818, 58), _campaign_map_point(816, 59), _campaign_map_point(815, 60), 
			_campaign_map_point(813, 61), _campaign_map_point(812, 62), _campaign_map_point(810, 63), 
			_campaign_map_point(809, 64), _campaign_map_point(807, 65), _campaign_map_point(806, 66), 
			_campaign_map_point(805, 67), _campaign_map_point(804, 68), _campaign_map_point(802, 69), 
			_campaign_map_point(801, 70), _campaign_map_point(800, 71), _campaign_map_point(799, 72), 
			_campaign_map_point(798, 73), _campaign_map_point(796, 74), _campaign_map_point(795, 75), 
			_campaign_map_point(794, 76), _campaign_map_point(793, 77), _campaign_map_point(792, 78), 
			_campaign_map_point(791, 79), _campaign_map_point(790, 80), _campaign_map_point(789, 81), 
			_campaign_map_point(788, 82), _campaign_map_point(787, 83), _campaign_map_point(786, 84), 
			_campaign_map_point(785, 85), _campaign_map_point(785, 86), _campaign_map_point(784, 87), 
			_campaign_map_point(783, 88), _campaign_map_point(782, 89), _campaign_map_point(781, 90), 
			_campaign_map_point(780, 91), _campaign_map_point(779, 92), _campaign_map_point(778, 93), 
			_campaign_map_point(777, 94), _campaign_map_point(776, 95), _campaign_map_point(775, 96), 
			_campaign_map_point(774, 97), _campaign_map_point(774, 98), _campaign_map_point(773, 99), 
			_campaign_map_point(772, 100), _campaign_map_point(771, 101), _campaign_map_point(770, 102), 
			_campaign_map_point(769, 103), _campaign_map_point(769, 104), _campaign_map_point(768, 105), 
			_campaign_map_point(767, 106), _campaign_map_point(767, 107), _campaign_map_point(766, 108), 
			_campaign_map_point(765, 109), _campaign_map_point(764, 110), _campaign_map_point(764, 111), 
			_campaign_map_point(763, 112), _campaign_map_point(762, 113), _campaign_map_point(761, 114), 
			_campaign_map_point(761, 115), _campaign_map_point(760, 116), _campaign_map_point(759, 117), 
			_campaign_map_point(758, 118), _campaign_map_point(758, 119), _campaign_map_point(757, 120), 
			_campaign_map_point(756, 121), _campaign_map_point(756, 122), _campaign_map_point(755, 123), 
			_campaign_map_point(755, 124), _campaign_map_point(754, 125), _campaign_map_point(753, 126), 
			_campaign_map_point(753, 127), _campaign_map_point(752, 128), _campaign_map_point(752, 129), 
			_campaign_map_point(751, 130), _campaign_map_point(750, 131), _campaign_map_point(750, 132), 
			_campaign_map_point(749, 133), _campaign_map_point(749, 134), _campaign_map_point(748, 135), 
			_campaign_map_point(748, 136), _campaign_map_point(747, 137), _campaign_map_point(747, 138), 
			_campaign_map_point(746, 139), _campaign_map_point(746, 140), _campaign_map_point(745, 141), 
			_campaign_map_point(745, 142), _campaign_map_point(744, 143), _campaign_map_point(744, 144), 
			_campaign_map_point(744, 145), _campaign_map_point(743, 146), _campaign_map_point(743, 147), 
			_campaign_map_point(742, 148), _campaign_map_point(742, 149), _campaign_map_point(742, 150), 
			_campaign_map_point(741, 151), _campaign_map_point(741, 152), _campaign_map_point(740, 153), 
			_campaign_map_point(740, 154), _campaign_map_point(739, 155), _campaign_map_point(739, 156), 
			_campaign_map_point(739, 157), _campaign_map_point(738, 158), _campaign_map_point(738, 159), 
			_campaign_map_point(737, 160), _campaign_map_point(737, 161), _campaign_map_point(737, 162), 
			_campaign_map_point(736, 163), _campaign_map_point(736, 164), _campaign_map_point(736, 165), 
			_campaign_map_point(736, 166), _campaign_map_point(735, 167), _campaign_map_point(735, 168), 
			_campaign_map_point(735, 169), _campaign_map_point(734, 170), _campaign_map_point(734, 171), 
			_campaign_map_point(734, 172), _campaign_map_point(733, 173), _campaign_map_point(733, 174), 
			_campaign_map_point(733, 175), _campaign_map_point(732, 176), _campaign_map_point(731, 177), 
			_campaign_map_point(731, 178), _campaign_map_point(731, 179), _campaign_map_point(730, 180), 
			_campaign_map_point(730, 181), _campaign_map_point(730, 182), _campaign_map_point(730, 183), 
			_campaign_map_point(730, 184), _campaign_map_point(729, 185), _campaign_map_point(729, 186), 
			_campaign_map_point(729, 187), _campaign_map_point(729, 188), _campaign_map_point(728, 189), 
			_campaign_map_point(728, 190), _campaign_map_point(728, 191), _campaign_map_point(727, 192), 
			_campaign_map_point(727, 193), _campaign_map_point(727, 194), _campaign_map_point(727, 195), 
			_campaign_map_point(726, 196), _campaign_map_point(726, 197), _campaign_map_point(726, 198), 
			_campaign_map_point(726, 199), _campaign_map_point(726, 200), _campaign_map_point(726, 201), 
			_campaign_map_point(725, 202), _campaign_map_point(725, 203), _campaign_map_point(725, 204), 
			_campaign_map_point(725, 205), _campaign_map_point(725, 206), _campaign_map_point(725, 207), 
			_campaign_map_point(724, 208), _campaign_map_point(724, 209), _campaign_map_point(724, 210), 
			_campaign_map_point(724, 211), _campaign_map_point(724, 212), _campaign_map_point(724, 213), 
			_campaign_map_point(723, 214), _campaign_map_point(723, 215), _campaign_map_point(723, 216), 
			_campaign_map_point(723, 217), _campaign_map_point(723, 218), _campaign_map_point(723, 219), 
			_campaign_map_point(723, 220), _campaign_map_point(723, 221), _campaign_map_point(723, 222), 
			_campaign_map_point(723, 223), _campaign_map_point(723, 224), _campaign_map_point(723, 225), 
			_campaign_map_point(723, 226), _campaign_map_point(723, 227), _campaign_map_point(723, 228), 
			_campaign_map_point(723, 229), _campaign_map_point(723, 230), _campaign_map_point(722, 231), 
			_campaign_map_point(722, 232), _campaign_map_point(722, 233), _campaign_map_point(722, 234), 
			_campaign_map_point(722, 235), _campaign_map_point(722, 236), _campaign_map_point(722, 237), 
			_campaign_map_point(722, 238), _campaign_map_point(722, 239), _campaign_map_point(722, 240), 
			_campaign_map_point(722, 241), _campaign_map_point(722, 242), _campaign_map_point(722, 243), 
			_campaign_map_point(721, 244), _campaign_map_point(721, 245), _campaign_map_point(721, 246), 
			_campaign_map_point(720, 247), _campaign_map_point(719, 248), _campaign_map_point(718, 249), 
			_campaign_map_point(717, 250), _campaign_map_point(717, 251), _campaign_map_point(717, 252), 
			_campaign_map_point(717, 253), _campaign_map_point(717, 254), _campaign_map_point(717, 255), 
			_campaign_map_point(717, 256), _campaign_map_point(717, 257), _campaign_map_point(717, 258), 
			_campaign_map_point(717, 259), _campaign_map_point(717, 260), _campaign_map_point(717, 261), 
			_campaign_map_point(716, 262), _campaign_map_point(716, 263), _campaign_map_point(717, 264), 
			_campaign_map_point(717, 265), _campaign_map_point(717, 266), _campaign_map_point(717, 267), 
			_campaign_map_point(717, 268), _campaign_map_point(717, 269), _campaign_map_point(717, 270), 
			_campaign_map_point(717, 271), _campaign_map_point(717, 272), _campaign_map_point(717, 273), 
			_campaign_map_point(717, 274), _campaign_map_point(717, 275), _campaign_map_point(717, 276), 
			_campaign_map_point(717, 277), _campaign_map_point(717, 278), _campaign_map_point(717, 279), 
			_campaign_map_point(717, 280), _campaign_map_point(716, 281), _campaign_map_point(716, 282), 
			_campaign_map_point(716, 283), _campaign_map_point(716, 284), _campaign_map_point(716, 285), 
			_campaign_map_point(716, 286), _campaign_map_point(717, 287), _campaign_map_point(717, 288), 
			_campaign_map_point(717, 289), _campaign_map_point(717, 290), _campaign_map_point(717, 291), 
			_campaign_map_point(717, 292), _campaign_map_point(717, 293), _campaign_map_point(717, 294), 
			_campaign_map_point(717, 295), _campaign_map_point(717, 296), _campaign_map_point(717, 297), 
			_campaign_map_point(717, 298), _campaign_map_point(717, 299), _campaign_map_point(717, 300), 
			_campaign_map_point(717, 301), _campaign_map_point(717, 302), _campaign_map_point(717, 303), 
			_campaign_map_point(717, 304), _campaign_map_point(717, 305), _campaign_map_point(717, 306), 
			_campaign_map_point(717, 307), _campaign_map_point(717, 308), _campaign_map_point(717, 309), 
			_campaign_map_point(717, 310), _campaign_map_point(717, 311), _campaign_map_point(717, 312), 
			_campaign_map_point(717, 313), _campaign_map_point(716, 314), _campaign_map_point(716, 315), 
			_campaign_map_point(716, 316), _campaign_map_point(717, 317), _campaign_map_point(717, 318), 
			_campaign_map_point(717, 319), _campaign_map_point(717, 320), _campaign_map_point(717, 321), 
			_campaign_map_point(717, 322), _campaign_map_point(717, 323), _campaign_map_point(717, 324), 
			_campaign_map_point(717, 325), _campaign_map_point(717, 326), _campaign_map_point(717, 327), 
			_campaign_map_point(717, 328), _campaign_map_point(717, 329), _campaign_map_point(717, 330), 
			_campaign_map_point(717, 331), _campaign_map_point(717, 332), _campaign_map_point(717, 333), 
			_campaign_map_point(717, 334), _campaign_map_point(717, 335), _campaign_map_point(717, 336), 
			_campaign_map_point(717, 337), _campaign_map_point(717, 338), _campaign_map_point(717, 339), 
			_campaign_map_point(717, 340), _campaign_map_point(717, 341), _campaign_map_point(717, 342), 
			_campaign_map_point(717, 343), _campaign_map_point(717, 344), _campaign_map_point(717, 345), 
			_campaign_map_point(717, 346), _campaign_map_point(717, 347), _campaign_map_point(717, 348), 
			_campaign_map_point(717, 349), _campaign_map_point(717, 350), _campaign_map_point(717, 351), 
			_campaign_map_point(717, 352), _campaign_map_point(717, 353), _campaign_map_point(717, 354), 
			_campaign_map_point(717, 355), _campaign_map_point(717, 356), _campaign_map_point(717, 357), 
			_campaign_map_point(717, 358), _campaign_map_point(717, 359), _campaign_map_point(717, 360), 
			_campaign_map_point(717, 361), _campaign_map_point(717, 362), _campaign_map_point(717, 363), 
			_campaign_map_point(717, 364), _campaign_map_point(717, 365), _campaign_map_point(717, 366), 
			_campaign_map_point(717, 367), _campaign_map_point(717, 368), _campaign_map_point(717, 369), 
			_campaign_map_point(717, 370), _campaign_map_point(717, 371), _campaign_map_point(717, 372), 
			_campaign_map_point(717, 373), _campaign_map_point(717, 374), _campaign_map_point(717, 375), 
			_campaign_map_point(717, 376), _campaign_map_point(717, 377), _campaign_map_point(717, 378), 
			_campaign_map_point(717, 379), _campaign_map_point(717, 380), _campaign_map_point(717, 381), 
			_campaign_map_point(717, 382), _campaign_map_point(717, 383), _campaign_map_point(717, 384), 
			_campaign_map_point(717, 385), _campaign_map_point(717, 386), _campaign_map_point(717, 387), 
			_campaign_map_point(717, 388), _campaign_map_point(717, 389), _campaign_map_point(717, 390), 
			_campaign_map_point(717, 391), _campaign_map_point(717, 392), _campaign_map_point(717, 393), 
			_campaign_map_point(717, 394), _campaign_map_point(717, 395), _campaign_map_point(717, 396), 
			_campaign_map_point(716, 397), _campaign_map_point(716, 398), _campaign_map_point(716, 399), 
			_campaign_map_point(716, 400), _campaign_map_point(716, 401), _campaign_map_point(717, 402), 
			_campaign_map_point(717, 403), _campaign_map_point(717, 404), _campaign_map_point(717, 405), 
			_campaign_map_point(717, 406), _campaign_map_point(717, 407), _campaign_map_point(717, 408), 
			_campaign_map_point(717, 409), _campaign_map_point(717, 410), _campaign_map_point(717, 411), 
			_campaign_map_point(717, 412), _campaign_map_point(716, 413), _campaign_map_point(716, 414), 
			_campaign_map_point(716, 415), _campaign_map_point(716, 416), _campaign_map_point(716, 417), 
			_campaign_map_point(716, 418), _campaign_map_point(716, 419), _campaign_map_point(716, 420), 
			_campaign_map_point(716, 421), _campaign_map_point(716, 422), _campaign_map_point(716, 423), 
			_campaign_map_point(716, 424), _campaign_map_point(716, 425), _campaign_map_point(716, 426), 
			_campaign_map_point(716, 427), _campaign_map_point(716, 428), _campaign_map_point(716, 429), 
			_campaign_map_point(716, 430), _campaign_map_point(716, 431), _campaign_map_point(716, 432), 
			_campaign_map_point(716, 433), _campaign_map_point(716, 434), _campaign_map_point(716, 435), 
			_campaign_map_point(716, 436), _campaign_map_point(716, 437), _campaign_map_point(716, 438), 
			_campaign_map_point(716, 439), _campaign_map_point(716, 440), _campaign_map_point(716, 441), 
			_campaign_map_point(716, 442), _campaign_map_point(716, 443), _campaign_map_point(716, 444), 
			_campaign_map_point(716, 445), _campaign_map_point(716, 446), _campaign_map_point(716, 447), 
			_campaign_map_point(716, 448), _campaign_map_point(716, 449), _campaign_map_point(716, 450), 
			_campaign_map_point(716, 451), _campaign_map_point(716, 452), _campaign_map_point(716, 453), 
			_campaign_map_point(716, 454), _campaign_map_point(716, 455), _campaign_map_point(716, 456), 
			_campaign_map_point(716, 457), _campaign_map_point(716, 458), _campaign_map_point(716, 459), 
			_campaign_map_point(716, 460), _campaign_map_point(716, 461), _campaign_map_point(716, 462), 
			_campaign_map_point(716, 463), _campaign_map_point(716, 464), _campaign_map_point(716, 465), 
			_campaign_map_point(716, 466), _campaign_map_point(716, 467), _campaign_map_point(716, 468), 
			_campaign_map_point(716, 469), _campaign_map_point(716, 470), _campaign_map_point(716, 471), 
			_campaign_map_point(716, 472), _campaign_map_point(716, 473), _campaign_map_point(716, 474), 
			_campaign_map_point(716, 475), _campaign_map_point(716, 476), _campaign_map_point(716, 477), 
			_campaign_map_point(716, 478), _campaign_map_point(716, 479), _campaign_map_point(716, 480), 
			_campaign_map_point(716, 481), _campaign_map_point(716, 482), _campaign_map_point(716, 483), 
			_campaign_map_point(716, 484), _campaign_map_point(716, 485), _campaign_map_point(716, 486), 
			_campaign_map_point(716, 487), _campaign_map_point(716, 488), _campaign_map_point(716, 489), 
			_campaign_map_point(716, 490), _campaign_map_point(716, 491), _campaign_map_point(716, 492), 
			_campaign_map_point(716, 493), _campaign_map_point(716, 494), _campaign_map_point(716, 495), 
			_campaign_map_point(716, 496), _campaign_map_point(716, 497), _campaign_map_point(716, 498), 
			_campaign_map_point(716, 499), _campaign_map_point(716, 500), _campaign_map_point(716, 501), 
			_campaign_map_point(716, 502), _campaign_map_point(716, 503), _campaign_map_point(716, 504), 
			_campaign_map_point(716, 505), _campaign_map_point(716, 506), _campaign_map_point(716, 507), 
			_campaign_map_point(716, 508), _campaign_map_point(716, 509), _campaign_map_point(716, 510), 
			_campaign_map_point(716, 511), _campaign_map_point(716, 512), _campaign_map_point(716, 513), 
			_campaign_map_point(716, 514), _campaign_map_point(716, 515), _campaign_map_point(716, 516), 
			_campaign_map_point(716, 517), _campaign_map_point(716, 518), _campaign_map_point(716, 519), 
			_campaign_map_point(716, 520), _campaign_map_point(716, 521), _campaign_map_point(716, 522), 
			_campaign_map_point(716, 523), _campaign_map_point(716, 524), _campaign_map_point(716, 525), 
			_campaign_map_point(716, 526), _campaign_map_point(716, 527), _campaign_map_point(716, 528), 
			_campaign_map_point(716, 529), _campaign_map_point(716, 530), _campaign_map_point(716, 531), 
			_campaign_map_point(716, 532), _campaign_map_point(716, 533), _campaign_map_point(716, 534), 
			_campaign_map_point(716, 535), _campaign_map_point(716, 536), _campaign_map_point(716, 537), 
			_campaign_map_point(716, 538), _campaign_map_point(716, 539), _campaign_map_point(716, 540), 
			_campaign_map_point(716, 541), _campaign_map_point(716, 542), _campaign_map_point(716, 543), 
			_campaign_map_point(716, 544), _campaign_map_point(716, 545), _campaign_map_point(716, 546), 
			_campaign_map_point(716, 547), _campaign_map_point(716, 548), _campaign_map_point(716, 549), 
			_campaign_map_point(716, 550), _campaign_map_point(716, 551), _campaign_map_point(716, 552), 
			_campaign_map_point(716, 553), _campaign_map_point(716, 554), _campaign_map_point(716, 555), 
			_campaign_map_point(716, 556), _campaign_map_point(716, 557), _campaign_map_point(716, 558), 
			_campaign_map_point(716, 559), _campaign_map_point(716, 560), _campaign_map_point(716, 561), 
			_campaign_map_point(716, 562), _campaign_map_point(716, 563), _campaign_map_point(716, 564), 
			_campaign_map_point(716, 565), _campaign_map_point(716, 566), _campaign_map_point(716, 567), 
			_campaign_map_point(716, 568), _campaign_map_point(716, 569), _campaign_map_point(716, 570), 
			_campaign_map_point(716, 571), _campaign_map_point(716, 572), _campaign_map_point(716, 573), 
			_campaign_map_point(716, 574), _campaign_map_point(716, 575), _campaign_map_point(716, 576), 
			_campaign_map_point(716, 577), _campaign_map_point(716, 578), _campaign_map_point(716, 579), 
			_campaign_map_point(716, 580), _campaign_map_point(716, 581), _campaign_map_point(716, 582), 
			_campaign_map_point(716, 583), _campaign_map_point(716, 584), _campaign_map_point(716, 585), 
			_campaign_map_point(716, 586), _campaign_map_point(716, 587), _campaign_map_point(716, 588), 
			_campaign_map_point(716, 589), _campaign_map_point(716, 590), _campaign_map_point(716, 591), 
			_campaign_map_point(716, 592), _campaign_map_point(716, 593), _campaign_map_point(716, 594), 
			_campaign_map_point(716, 595), _campaign_map_point(716, 596), _campaign_map_point(716, 597), 
			_campaign_map_point(716, 598), _campaign_map_point(716, 599), _campaign_map_point(716, 600), 
			_campaign_map_point(716, 601), _campaign_map_point(716, 602), _campaign_map_point(716, 603), 
			_campaign_map_point(716, 604), _campaign_map_point(716, 605), _campaign_map_point(716, 606), 
			_campaign_map_point(716, 607), _campaign_map_point(716, 608), _campaign_map_point(716, 609), 
			_campaign_map_point(716, 610), _campaign_map_point(716, 611), _campaign_map_point(716, 612), 
			_campaign_map_point(716, 613), _campaign_map_point(716, 614), _campaign_map_point(716, 615), 
			_campaign_map_point(716, 616), _campaign_map_point(716, 617), _campaign_map_point(716, 618), 
			_campaign_map_point(716, 619), _campaign_map_point(716, 620), _campaign_map_point(716, 621), 
			_campaign_map_point(716, 622), _campaign_map_point(716, 623), _campaign_map_point(716, 624), 
			_campaign_map_point(716, 625), _campaign_map_point(716, 626), _campaign_map_point(716, 627), 
			_campaign_map_point(716, 628), _campaign_map_point(716, 629), _campaign_map_point(716, 630), 
			_campaign_map_point(716, 631), _campaign_map_point(716, 632), _campaign_map_point(716, 633), 
			_campaign_map_point(716, 634), _campaign_map_point(716, 635), _campaign_map_point(716, 636), 
			_campaign_map_point(716, 637), _campaign_map_point(716, 638), _campaign_map_point(716, 639), 
			_campaign_map_point(716, 640), _campaign_map_point(716, 641), _campaign_map_point(716, 642), 
			_campaign_map_point(716, 643), _campaign_map_point(716, 644), _campaign_map_point(716, 645), 
			_campaign_map_point(716, 646), _campaign_map_point(716, 647), _campaign_map_point(716, 648), 
			_campaign_map_point(716, 649), _campaign_map_point(716, 650), _campaign_map_point(716, 651), 
			_campaign_map_point(716, 652), _campaign_map_point(716, 653), _campaign_map_point(716, 654), 
			_campaign_map_point(716, 655), _campaign_map_point(716, 656), _campaign_map_point(716, 657), 
			_campaign_map_point(716, 658), _campaign_map_point(716, 659), _campaign_map_point(716, 660), 
			_campaign_map_point(716, 661), _campaign_map_point(716, 662), _campaign_map_point(716, 663), 
			_campaign_map_point(716, 664), _campaign_map_point(716, 665), _campaign_map_point(716, 666), 
			_campaign_map_point(716, 667), _campaign_map_point(716, 668), _campaign_map_point(716, 669), 
			_campaign_map_point(716, 670), _campaign_map_point(716, 671), _campaign_map_point(716, 672), 
			_campaign_map_point(716, 673), _campaign_map_point(716, 674), _campaign_map_point(716, 675), 
			_campaign_map_point(716, 676), _campaign_map_point(716, 677), _campaign_map_point(716, 678), 
			_campaign_map_point(716, 679), _campaign_map_point(716, 680), _campaign_map_point(716, 681), 
			_campaign_map_point(716, 682), _campaign_map_point(716, 683), _campaign_map_point(716, 684), 
			_campaign_map_point(716, 685), _campaign_map_point(717, 686), _campaign_map_point(717, 687), 
			_campaign_map_point(717, 688), _campaign_map_point(717, 689), _campaign_map_point(717, 690), 
			_campaign_map_point(717, 691), _campaign_map_point(717, 692), _campaign_map_point(717, 693), 
			_campaign_map_point(717, 694), _campaign_map_point(717, 695), _campaign_map_point(717, 696), 
			_campaign_map_point(717, 697), _campaign_map_point(717, 698), _campaign_map_point(717, 699), 
			_campaign_map_point(717, 700), _campaign_map_point(717, 701), _campaign_map_point(717, 702), 
			_campaign_map_point(716, 703), _campaign_map_point(716, 704), _campaign_map_point(716, 705), 
			_campaign_map_point(715, 706), _campaign_map_point(714, 707), _campaign_map_point(714, 708), 
			_campaign_map_point(714, 709), _campaign_map_point(713, 710), _campaign_map_point(713, 711), 
			_campaign_map_point(712, 712), _campaign_map_point(712, 713), _campaign_map_point(711, 714), 
			_campaign_map_point(711, 715), _campaign_map_point(710, 716), _campaign_map_point(710, 717), 
			_campaign_map_point(709, 718), _campaign_map_point(709, 719), _campaign_map_point(708, 720), 
			_campaign_map_point(708, 721), _campaign_map_point(707, 722), _campaign_map_point(707, 723), 
			_campaign_map_point(706, 724), _campaign_map_point(706, 725), _campaign_map_point(705, 726), 
			_campaign_map_point(705, 727), _campaign_map_point(704, 728), _campaign_map_point(704, 729), 
			_campaign_map_point(703, 730), _campaign_map_point(703, 731), _campaign_map_point(702, 732), 
			_campaign_map_point(702, 733), _campaign_map_point(701, 734), _campaign_map_point(700, 735), 
			_campaign_map_point(700, 736), _campaign_map_point(699, 737), _campaign_map_point(699, 738), 
			_campaign_map_point(698, 739), _campaign_map_point(698, 740), _campaign_map_point(697, 741), 
			_campaign_map_point(697, 742), _campaign_map_point(696, 743), _campaign_map_point(696, 744), 
			_campaign_map_point(695, 745), _campaign_map_point(695, 746), _campaign_map_point(694, 747), 
			_campaign_map_point(694, 748), _campaign_map_point(693, 749), _campaign_map_point(693, 750), 
			_campaign_map_point(692, 751), _campaign_map_point(692, 752), _campaign_map_point(691, 753), 
			_campaign_map_point(691, 754), _campaign_map_point(690, 755), _campaign_map_point(690, 756), 
			_campaign_map_point(689, 757), _campaign_map_point(689, 758), _campaign_map_point(688, 759), 
			_campaign_map_point(688, 760), _campaign_map_point(687, 761), _campaign_map_point(687, 762), 
			_campaign_map_point(686, 763), _campaign_map_point(686, 764), _campaign_map_point(686, 765), 
			_campaign_map_point(685, 766), _campaign_map_point(684, 767), _campaign_map_point(684, 768), 
			_campaign_map_point(683, 769), _campaign_map_point(683, 770), _campaign_map_point(682, 771), 
			_campaign_map_point(682, 772), _campaign_map_point(681, 773), _campaign_map_point(681, 774), 
			_campaign_map_point(680, 775), _campaign_map_point(680, 776), _campaign_map_point(679, 777), 
			_campaign_map_point(679, 778), _campaign_map_point(678, 779), _campaign_map_point(678, 780), 
			_campaign_map_point(677, 781), _campaign_map_point(676, 782), _campaign_map_point(676, 783), 
			_campaign_map_point(675, 784), _campaign_map_point(675, 785), _campaign_map_point(674, 786), 
			_campaign_map_point(674, 787), _campaign_map_point(674, 788), _campaign_map_point(673, 789), 
			_campaign_map_point(672, 790), _campaign_map_point(672, 791), _campaign_map_point(671, 792), 
			_campaign_map_point(671, 793), _campaign_map_point(671, 794), _campaign_map_point(670, 795), 
			_campaign_map_point(670, 796), _campaign_map_point(669, 797), _campaign_map_point(668, 798), 
			_campaign_map_point(668, 799), _campaign_map_point(667, 800), _campaign_map_point(667, 801), 
			_campaign_map_point(666, 802), _campaign_map_point(666, 803), _campaign_map_point(665, 804), 
			_campaign_map_point(665, 805), _campaign_map_point(664, 806), _campaign_map_point(663, 807), 
			_campaign_map_point(663, 808), _campaign_map_point(662, 809), _campaign_map_point(662, 810), 
			_campaign_map_point(661, 811), _campaign_map_point(660, 812), _campaign_map_point(660, 813), 
			_campaign_map_point(659, 814), _campaign_map_point(659, 815), _campaign_map_point(658, 816), 
			_campaign_map_point(658, 817), _campaign_map_point(657, 818), _campaign_map_point(657, 819), 
			_campaign_map_point(656, 820), _campaign_map_point(656, 821), _campaign_map_point(655, 822), 
			_campaign_map_point(655, 823), _campaign_map_point(654, 824), _campaign_map_point(654, 825), 
			_campaign_map_point(653, 826), _campaign_map_point(653, 827), _campaign_map_point(652, 828), 
			_campaign_map_point(652, 829), _campaign_map_point(651, 830), _campaign_map_point(650, 831), 
			_campaign_map_point(650, 832), _campaign_map_point(649, 833), _campaign_map_point(648, 834), 
			_campaign_map_point(648, 835), _campaign_map_point(647, 836), _campaign_map_point(647, 837), 
			_campaign_map_point(647, 838), _campaign_map_point(647, 839), _campaign_map_point(635, 840), 
			_campaign_map_point(635, 841), _campaign_map_point(635, 842), _campaign_map_point(635, 843), 
			_campaign_map_point(635, 844), _campaign_map_point(635, 845), _campaign_map_point(635, 846), 
			_campaign_map_point(635, 847), _campaign_map_point(635, 848), _campaign_map_point(635, 849), 
			_campaign_map_point(635, 850), _campaign_map_point(635, 851), _campaign_map_point(635, 852), 
			_campaign_map_point(635, 853), _campaign_map_point(635, 854), _campaign_map_point(635, 855), 
			_campaign_map_point(635, 856), _campaign_map_point(635, 857), _campaign_map_point(635, 858), 
			_campaign_map_point(635, 859), _campaign_map_point(635, 860), _campaign_map_point(635, 861), 
			_campaign_map_point(635, 862), _campaign_map_point(635, 863), _campaign_map_point(635, 864), 
			_campaign_map_point(635, 865), _campaign_map_point(635, 866), _campaign_map_point(635, 867), 
			_campaign_map_point(635, 868), _campaign_map_point(635, 869), _campaign_map_point(635, 870), 
			_campaign_map_point(635, 871), _campaign_map_point(635, 872), _campaign_map_point(635, 873), 
			_campaign_map_point(635, 874), _campaign_map_point(635, 875), _campaign_map_point(635, 876), 
			_campaign_map_point(635, 877), _campaign_map_point(635, 878), _campaign_map_point(635, 879), 
			_campaign_map_point(635, 880), _campaign_map_point(635, 881), _campaign_map_point(635, 882), 
			_campaign_map_point(635, 883), _campaign_map_point(635, 884), _campaign_map_point(635, 885), 
			_campaign_map_point(635, 886), _campaign_map_point(635, 887), _campaign_map_point(635, 888), 
			_campaign_map_point(635, 889), _campaign_map_point(635, 890), _campaign_map_point(635, 891), 
			_campaign_map_point(635, 892), _campaign_map_point(635, 893), _campaign_map_point(635, 894), 
			_campaign_map_point(635, 895), _campaign_map_point(635, 896), _campaign_map_point(635, 897), 
			_campaign_map_point(635, 898), _campaign_map_point(635, 899), _campaign_map_point(635, 900), 
			_campaign_map_point(635, 901), _campaign_map_point(635, 902), _campaign_map_point(635, 903), 
			_campaign_map_point(635, 904), _campaign_map_point(635, 905), _campaign_map_point(635, 906), 
			_campaign_map_point(635, 907), _campaign_map_point(635, 908), _campaign_map_point(635, 909), 
			_campaign_map_point(635, 910), _campaign_map_point(635, 911), _campaign_map_point(635, 912), 
			_campaign_map_point(635, 913), _campaign_map_point(635, 914), _campaign_map_point(635, 915), 
			_campaign_map_point(635, 916), _campaign_map_point(635, 917), _campaign_map_point(635, 918), 
			_campaign_map_point(635, 919), _campaign_map_point(635, 920), _campaign_map_point(635, 921), 
			_campaign_map_point(635, 922), _campaign_map_point(635, 923), _campaign_map_point(635, 924), 
			_campaign_map_point(635, 925), _campaign_map_point(635, 926), _campaign_map_point(635, 927), 
			_campaign_map_point(635, 928), _campaign_map_point(635, 929), _campaign_map_point(635, 930), 
			_campaign_map_point(635, 931), _campaign_map_point(635, 932), _campaign_map_point(635, 933), 
			_campaign_map_point(635, 934), _campaign_map_point(635, 935), _campaign_map_point(1055, 935), 
			_campaign_map_point(1055, 934), _campaign_map_point(1055, 933), _campaign_map_point(1055, 932), 
			_campaign_map_point(1055, 931), _campaign_map_point(1055, 930), _campaign_map_point(1055, 929), 
			_campaign_map_point(1055, 928), _campaign_map_point(1055, 927), _campaign_map_point(1055, 926), 
			_campaign_map_point(1055, 925), _campaign_map_point(1055, 924), _campaign_map_point(1055, 923), 
			_campaign_map_point(1055, 922), _campaign_map_point(1055, 921), _campaign_map_point(1055, 920), 
			_campaign_map_point(1055, 919), _campaign_map_point(1055, 918), _campaign_map_point(1055, 917), 
			_campaign_map_point(1055, 916), _campaign_map_point(1055, 915), _campaign_map_point(1055, 914), 
			_campaign_map_point(1055, 913), _campaign_map_point(1055, 912), _campaign_map_point(1055, 911), 
			_campaign_map_point(1055, 910), _campaign_map_point(1055, 909), _campaign_map_point(1055, 908), 
			_campaign_map_point(1055, 907), _campaign_map_point(1055, 906), _campaign_map_point(1055, 905), 
			_campaign_map_point(1055, 904), _campaign_map_point(1055, 903), _campaign_map_point(1055, 902), 
			_campaign_map_point(1055, 901), _campaign_map_point(1055, 900), _campaign_map_point(1055, 899), 
			_campaign_map_point(1055, 898), _campaign_map_point(1055, 897), _campaign_map_point(1055, 896), 
			_campaign_map_point(1055, 895), _campaign_map_point(1055, 894), _campaign_map_point(1055, 893), 
			_campaign_map_point(1055, 892), _campaign_map_point(1055, 891), _campaign_map_point(1055, 890), 
			_campaign_map_point(1055, 889), _campaign_map_point(1055, 888), _campaign_map_point(1055, 887), 
			_campaign_map_point(1055, 886), _campaign_map_point(1055, 885), _campaign_map_point(1055, 884), 
			_campaign_map_point(1055, 883), _campaign_map_point(1055, 882), _campaign_map_point(1055, 881), 
			_campaign_map_point(1055, 880), _campaign_map_point(1055, 879), _campaign_map_point(1055, 878), 
			_campaign_map_point(1055, 877), _campaign_map_point(1055, 876), _campaign_map_point(1055, 875), 
			_campaign_map_point(1055, 874), _campaign_map_point(1055, 873), _campaign_map_point(1055, 872), 
			_campaign_map_point(1055, 871), _campaign_map_point(1055, 870), _campaign_map_point(1055, 869), 
			_campaign_map_point(1055, 868), _campaign_map_point(1055, 867), _campaign_map_point(1055, 866), 
			_campaign_map_point(1055, 865), _campaign_map_point(1055, 864), _campaign_map_point(1055, 863), 
			_campaign_map_point(1055, 862), _campaign_map_point(1055, 861), _campaign_map_point(1055, 860), 
			_campaign_map_point(1055, 859), _campaign_map_point(1055, 858), _campaign_map_point(1055, 857), 
			_campaign_map_point(1055, 856), _campaign_map_point(1055, 855), _campaign_map_point(1055, 854), 
			_campaign_map_point(1055, 853), _campaign_map_point(1055, 852), _campaign_map_point(1055, 851), 
			_campaign_map_point(1055, 850), _campaign_map_point(1055, 849), _campaign_map_point(1055, 848), 
			_campaign_map_point(1055, 847), _campaign_map_point(1055, 846), _campaign_map_point(1055, 845), 
			_campaign_map_point(1055, 844), _campaign_map_point(1055, 843), _campaign_map_point(1055, 842), 
			_campaign_map_point(1055, 841), _campaign_map_point(1055, 840), _campaign_map_point(1055, 839), 
			_campaign_map_point(1055, 838), _campaign_map_point(1055, 837), _campaign_map_point(1055, 836), 
			_campaign_map_point(1055, 835), _campaign_map_point(1055, 834), _campaign_map_point(1055, 833), 
			_campaign_map_point(1055, 832), _campaign_map_point(1055, 831), _campaign_map_point(1055, 830), 
			_campaign_map_point(1055, 829), _campaign_map_point(1055, 828), _campaign_map_point(1055, 827), 
			_campaign_map_point(1055, 826), _campaign_map_point(1055, 825), _campaign_map_point(1055, 824), 
			_campaign_map_point(1055, 823), _campaign_map_point(1055, 822), _campaign_map_point(1055, 821), 
			_campaign_map_point(1055, 820), _campaign_map_point(1055, 819), _campaign_map_point(1055, 818), 
			_campaign_map_point(1055, 817), _campaign_map_point(1055, 816), _campaign_map_point(1055, 815), 
			_campaign_map_point(1055, 814), _campaign_map_point(1055, 813), _campaign_map_point(1055, 812), 
			_campaign_map_point(1055, 811), _campaign_map_point(1055, 810), _campaign_map_point(1055, 809), 
			_campaign_map_point(1055, 808), _campaign_map_point(1055, 807), _campaign_map_point(1055, 806), 
			_campaign_map_point(1055, 805), _campaign_map_point(1055, 804), _campaign_map_point(1055, 803), 
			_campaign_map_point(1055, 802), _campaign_map_point(1055, 801), _campaign_map_point(1055, 800), 
			_campaign_map_point(1055, 799), _campaign_map_point(1055, 798), _campaign_map_point(1055, 797), 
			_campaign_map_point(1055, 796), _campaign_map_point(1055, 795), _campaign_map_point(1055, 794), 
			_campaign_map_point(1055, 793), _campaign_map_point(1055, 792), _campaign_map_point(1055, 791), 
			_campaign_map_point(1055, 790), _campaign_map_point(1055, 789), _campaign_map_point(1055, 788), 
			_campaign_map_point(1055, 787), _campaign_map_point(1055, 786), _campaign_map_point(1055, 785), 
			_campaign_map_point(1055, 784), _campaign_map_point(1055, 783), _campaign_map_point(1055, 782), 
			_campaign_map_point(1055, 781), _campaign_map_point(1055, 780), _campaign_map_point(1055, 779), 
			_campaign_map_point(1055, 778), _campaign_map_point(1055, 777), _campaign_map_point(1055, 776), 
			_campaign_map_point(1055, 775), _campaign_map_point(1055, 774), _campaign_map_point(1055, 773), 
			_campaign_map_point(1055, 772), _campaign_map_point(1055, 771), _campaign_map_point(1055, 770), 
			_campaign_map_point(1055, 769), _campaign_map_point(1055, 768), _campaign_map_point(1055, 767), 
			_campaign_map_point(1055, 766), _campaign_map_point(1055, 765), _campaign_map_point(1055, 764), 
			_campaign_map_point(1055, 763), _campaign_map_point(1055, 762), _campaign_map_point(1055, 761), 
			_campaign_map_point(1055, 760), _campaign_map_point(1055, 759), _campaign_map_point(1055, 758), 
			_campaign_map_point(1055, 757), _campaign_map_point(1055, 756), _campaign_map_point(1055, 755), 
			_campaign_map_point(1055, 754), _campaign_map_point(1055, 753), _campaign_map_point(1055, 752), 
			_campaign_map_point(1055, 751), _campaign_map_point(1055, 750), _campaign_map_point(1055, 749), 
			_campaign_map_point(1055, 748), _campaign_map_point(1055, 747), _campaign_map_point(1055, 746), 
			_campaign_map_point(1055, 745), _campaign_map_point(1055, 744), _campaign_map_point(1055, 743), 
			_campaign_map_point(1055, 742), _campaign_map_point(1055, 741), _campaign_map_point(1055, 740), 
			_campaign_map_point(1055, 739), _campaign_map_point(1055, 738), _campaign_map_point(1055, 737), 
			_campaign_map_point(1055, 736), _campaign_map_point(1055, 735), _campaign_map_point(1055, 734), 
			_campaign_map_point(1055, 733), _campaign_map_point(1055, 732), _campaign_map_point(1055, 731), 
			_campaign_map_point(1055, 730), _campaign_map_point(1045, 729), _campaign_map_point(1028, 728), 
			_campaign_map_point(1013, 727), _campaign_map_point(1004, 726), _campaign_map_point(1001, 725), 
			_campaign_map_point(1000, 724), _campaign_map_point(1000, 723), _campaign_map_point(1000, 722), 
			_campaign_map_point(1000, 721), _campaign_map_point(1000, 720), _campaign_map_point(1000, 719), 
			_campaign_map_point(1000, 718), _campaign_map_point(1000, 717), _campaign_map_point(1000, 716), 
			_campaign_map_point(1000, 715), _campaign_map_point(1000, 714), _campaign_map_point(1055, 713), 
			_campaign_map_point(1055, 712), _campaign_map_point(1055, 711), _campaign_map_point(1055, 710), 
			_campaign_map_point(1055, 709), _campaign_map_point(1055, 708), _campaign_map_point(1055, 707), 
			_campaign_map_point(1055, 706), _campaign_map_point(1055, 705), _campaign_map_point(1055, 704), 
			_campaign_map_point(1055, 703), _campaign_map_point(1055, 702), _campaign_map_point(1055, 701), 
			_campaign_map_point(1055, 700), _campaign_map_point(1055, 699), _campaign_map_point(1055, 698), 
			_campaign_map_point(1055, 697), _campaign_map_point(1055, 696), _campaign_map_point(1055, 695), 
			_campaign_map_point(1055, 694), _campaign_map_point(1055, 693), _campaign_map_point(1055, 692), 
			_campaign_map_point(1055, 691), _campaign_map_point(1055, 690), _campaign_map_point(1055, 689), 
			_campaign_map_point(1055, 688), _campaign_map_point(1055, 687), _campaign_map_point(1055, 686), 
			_campaign_map_point(1055, 685), _campaign_map_point(1055, 684), _campaign_map_point(1055, 683), 
			_campaign_map_point(1055, 682), _campaign_map_point(1055, 681), _campaign_map_point(1055, 680), 
			_campaign_map_point(1055, 679), _campaign_map_point(1055, 678), _campaign_map_point(1055, 677), 
			_campaign_map_point(1055, 676), _campaign_map_point(1055, 675), _campaign_map_point(1055, 674), 
			_campaign_map_point(1055, 673), _campaign_map_point(1055, 672), _campaign_map_point(1055, 671), 
			_campaign_map_point(1055, 670), _campaign_map_point(1055, 669), _campaign_map_point(1055, 668), 
			_campaign_map_point(1055, 667), _campaign_map_point(1055, 666), _campaign_map_point(1055, 665), 
			_campaign_map_point(1055, 664), _campaign_map_point(1055, 663), _campaign_map_point(1055, 662), 
			_campaign_map_point(1055, 661), _campaign_map_point(1055, 660), _campaign_map_point(1055, 659), 
			_campaign_map_point(1055, 658), _campaign_map_point(1055, 657), _campaign_map_point(1055, 656), 
			_campaign_map_point(1055, 655), _campaign_map_point(1055, 654), _campaign_map_point(1055, 653), 
			_campaign_map_point(1055, 652), _campaign_map_point(1055, 651), _campaign_map_point(1055, 650), 
			_campaign_map_point(1055, 649), _campaign_map_point(1055, 648), _campaign_map_point(1055, 647), 
			_campaign_map_point(1055, 646), _campaign_map_point(1055, 645), _campaign_map_point(1055, 644), 
			_campaign_map_point(1055, 643), _campaign_map_point(1055, 642), _campaign_map_point(1055, 641), 
			_campaign_map_point(1055, 640), _campaign_map_point(1055, 639), _campaign_map_point(1055, 638), 
			_campaign_map_point(1055, 637), _campaign_map_point(1055, 636), _campaign_map_point(1055, 635), 
			_campaign_map_point(1055, 634), _campaign_map_point(1055, 633), _campaign_map_point(1055, 632), 
			_campaign_map_point(1055, 631), _campaign_map_point(1055, 630), _campaign_map_point(1055, 629), 
			_campaign_map_point(1055, 628), _campaign_map_point(1055, 627), _campaign_map_point(1055, 626), 
			_campaign_map_point(1055, 625), _campaign_map_point(1055, 624), _campaign_map_point(1055, 623), 
			_campaign_map_point(1055, 622), _campaign_map_point(1055, 621), _campaign_map_point(1055, 620), 
			_campaign_map_point(1055, 619), _campaign_map_point(1055, 618), _campaign_map_point(1055, 617), 
			_campaign_map_point(1055, 616), _campaign_map_point(1055, 615), _campaign_map_point(1055, 614), 
			_campaign_map_point(1055, 613), _campaign_map_point(1055, 612), _campaign_map_point(1055, 611), 
			_campaign_map_point(1055, 610), _campaign_map_point(1055, 609), _campaign_map_point(1055, 608), 
			_campaign_map_point(1055, 607), _campaign_map_point(1055, 606), _campaign_map_point(1055, 605), 
			_campaign_map_point(1055, 604), _campaign_map_point(1055, 603), _campaign_map_point(1055, 602), 
			_campaign_map_point(1055, 601), _campaign_map_point(1055, 600), _campaign_map_point(1055, 599), 
			_campaign_map_point(1055, 598), _campaign_map_point(1055, 597), _campaign_map_point(1055, 596), 
			_campaign_map_point(1055, 595), _campaign_map_point(1055, 594), _campaign_map_point(1055, 593), 
			_campaign_map_point(1055, 592), _campaign_map_point(1055, 591), _campaign_map_point(1055, 590), 
			_campaign_map_point(1055, 589), _campaign_map_point(1055, 588), _campaign_map_point(1055, 587), 
			_campaign_map_point(1055, 586), _campaign_map_point(1055, 585), _campaign_map_point(1055, 584), 
			_campaign_map_point(1055, 583), _campaign_map_point(1055, 582), _campaign_map_point(1055, 581), 
			_campaign_map_point(1055, 580), _campaign_map_point(1055, 579), _campaign_map_point(1055, 578), 
			_campaign_map_point(1055, 577), _campaign_map_point(1055, 576), _campaign_map_point(1055, 575), 
			_campaign_map_point(1055, 574), _campaign_map_point(1055, 573), _campaign_map_point(1055, 572), 
			_campaign_map_point(1055, 571), _campaign_map_point(1055, 570), _campaign_map_point(1055, 569), 
			_campaign_map_point(1055, 568), _campaign_map_point(1055, 567), _campaign_map_point(1055, 566), 
			_campaign_map_point(1055, 565), _campaign_map_point(1055, 564), _campaign_map_point(1055, 563), 
			_campaign_map_point(1055, 562), _campaign_map_point(1055, 561), _campaign_map_point(1055, 560), 
			_campaign_map_point(1055, 559), _campaign_map_point(1055, 558), _campaign_map_point(1055, 557), 
			_campaign_map_point(1055, 556), _campaign_map_point(1055, 555), _campaign_map_point(1055, 554), 
			_campaign_map_point(1055, 553), _campaign_map_point(1055, 552), _campaign_map_point(1055, 551), 
			_campaign_map_point(1055, 550), _campaign_map_point(1055, 549), _campaign_map_point(1055, 548), 
			_campaign_map_point(1055, 547), _campaign_map_point(1055, 546), _campaign_map_point(1055, 545), 
			_campaign_map_point(1055, 544), _campaign_map_point(1055, 543), _campaign_map_point(1055, 542), 
			_campaign_map_point(1055, 541), _campaign_map_point(1055, 540), _campaign_map_point(1055, 539), 
			_campaign_map_point(1055, 538), _campaign_map_point(1055, 537), _campaign_map_point(1055, 536), 
			_campaign_map_point(1055, 535), _campaign_map_point(1055, 534), _campaign_map_point(1055, 533), 
			_campaign_map_point(1055, 532), _campaign_map_point(1055, 531), _campaign_map_point(1055, 530), 
			_campaign_map_point(1055, 529), _campaign_map_point(1055, 528), _campaign_map_point(1055, 527), 
			_campaign_map_point(1055, 526), _campaign_map_point(1055, 525), _campaign_map_point(1055, 524), 
			_campaign_map_point(1055, 523), _campaign_map_point(1055, 522), _campaign_map_point(1055, 521), 
			_campaign_map_point(1055, 520), _campaign_map_point(1055, 519), _campaign_map_point(1055, 518), 
			_campaign_map_point(1055, 517), _campaign_map_point(1055, 516), _campaign_map_point(1055, 515), 
			_campaign_map_point(1055, 514), _campaign_map_point(1055, 513), _campaign_map_point(1055, 512), 
			_campaign_map_point(1055, 511), _campaign_map_point(1055, 510), _campaign_map_point(1055, 509), 
			_campaign_map_point(1055, 508), _campaign_map_point(1055, 507), _campaign_map_point(1055, 506), 
			_campaign_map_point(1055, 505), _campaign_map_point(1055, 504), _campaign_map_point(1055, 503), 
			_campaign_map_point(1055, 502), _campaign_map_point(1055, 501), _campaign_map_point(1055, 500), 
			_campaign_map_point(1055, 499), _campaign_map_point(1055, 498), _campaign_map_point(1055, 497), 
			_campaign_map_point(1055, 496), _campaign_map_point(1055, 495), _campaign_map_point(1055, 494), 
			_campaign_map_point(1055, 493), _campaign_map_point(1055, 492), _campaign_map_point(1055, 491), 
			_campaign_map_point(1055, 490), _campaign_map_point(1055, 489), _campaign_map_point(1055, 488), 
			_campaign_map_point(1055, 487), _campaign_map_point(1055, 486), _campaign_map_point(1055, 485), 
			_campaign_map_point(1055, 484), _campaign_map_point(1055, 483), _campaign_map_point(1055, 482), 
			_campaign_map_point(1055, 481), _campaign_map_point(1055, 480), _campaign_map_point(1055, 479), 
			_campaign_map_point(1055, 478), _campaign_map_point(1055, 477), _campaign_map_point(1055, 476), 
			_campaign_map_point(1055, 475), _campaign_map_point(1055, 474), _campaign_map_point(1055, 473), 
			_campaign_map_point(1055, 472), _campaign_map_point(1055, 471), _campaign_map_point(1055, 470), 
			_campaign_map_point(1055, 469), _campaign_map_point(1055, 468), _campaign_map_point(1055, 467), 
			_campaign_map_point(1055, 466), _campaign_map_point(1055, 465), _campaign_map_point(1055, 464), 
			_campaign_map_point(1055, 463), _campaign_map_point(1055, 462), _campaign_map_point(1055, 461), 
			_campaign_map_point(1055, 460), _campaign_map_point(1055, 459), _campaign_map_point(1055, 458), 
			_campaign_map_point(1055, 457), _campaign_map_point(1055, 456), _campaign_map_point(1055, 455), 
			_campaign_map_point(1055, 454), _campaign_map_point(1055, 453), _campaign_map_point(1055, 452), 
			_campaign_map_point(1055, 451), _campaign_map_point(1055, 450), _campaign_map_point(1055, 449), 
			_campaign_map_point(1055, 448), _campaign_map_point(1055, 447), _campaign_map_point(1055, 446), 
			_campaign_map_point(1055, 445), _campaign_map_point(1055, 444), _campaign_map_point(1055, 443), 
			_campaign_map_point(1055, 442), _campaign_map_point(1055, 441), _campaign_map_point(1055, 440), 
			_campaign_map_point(1055, 439), _campaign_map_point(1055, 438), _campaign_map_point(1055, 437), 
			_campaign_map_point(1055, 436), _campaign_map_point(1055, 435), _campaign_map_point(1055, 434), 
			_campaign_map_point(1055, 433), _campaign_map_point(1055, 432), _campaign_map_point(1055, 431), 
			_campaign_map_point(1055, 430), _campaign_map_point(1055, 429), _campaign_map_point(1055, 428), 
			_campaign_map_point(1055, 427), _campaign_map_point(1055, 426), _campaign_map_point(1055, 425), 
			_campaign_map_point(1055, 424), _campaign_map_point(1055, 423), _campaign_map_point(1055, 422), 
			_campaign_map_point(1055, 421), _campaign_map_point(1055, 420), _campaign_map_point(1055, 419), 
			_campaign_map_point(1055, 418), _campaign_map_point(1055, 417), _campaign_map_point(1055, 416), 
			_campaign_map_point(1055, 415), _campaign_map_point(1055, 414), _campaign_map_point(1055, 413), 
			_campaign_map_point(1055, 412), _campaign_map_point(1055, 411), _campaign_map_point(1055, 410), 
			_campaign_map_point(1055, 409), _campaign_map_point(1055, 408), _campaign_map_point(1055, 407), 
			_campaign_map_point(1055, 406), _campaign_map_point(1055, 405), _campaign_map_point(1055, 404), 
			_campaign_map_point(1055, 403), _campaign_map_point(1055, 402), _campaign_map_point(1055, 401), 
			_campaign_map_point(1055, 400), _campaign_map_point(1055, 399), _campaign_map_point(1055, 398), 
			_campaign_map_point(1055, 397), _campaign_map_point(1055, 396), _campaign_map_point(1055, 395), 
			_campaign_map_point(1055, 394), _campaign_map_point(1055, 393), _campaign_map_point(1055, 392), 
			_campaign_map_point(1055, 391), _campaign_map_point(1055, 390), _campaign_map_point(1055, 389), 
			_campaign_map_point(1055, 388), _campaign_map_point(1055, 387), _campaign_map_point(1055, 386), 
			_campaign_map_point(1055, 385), _campaign_map_point(1055, 384), _campaign_map_point(1055, 383), 
			_campaign_map_point(1055, 382), _campaign_map_point(1055, 381), _campaign_map_point(1055, 380), 
			_campaign_map_point(1055, 379), _campaign_map_point(1055, 378), _campaign_map_point(1055, 377), 
			_campaign_map_point(1055, 376), _campaign_map_point(1055, 375), _campaign_map_point(1055, 374), 
			_campaign_map_point(1055, 373), _campaign_map_point(1055, 372), _campaign_map_point(1055, 371), 
			_campaign_map_point(1055, 370), _campaign_map_point(1055, 369), _campaign_map_point(1055, 368), 
			_campaign_map_point(1055, 367), _campaign_map_point(1055, 366), _campaign_map_point(1055, 365), 
			_campaign_map_point(1055, 364), _campaign_map_point(1055, 363), _campaign_map_point(1055, 362), 
			_campaign_map_point(1055, 361), _campaign_map_point(1055, 360), _campaign_map_point(1055, 359), 
			_campaign_map_point(1055, 358), _campaign_map_point(1055, 357), _campaign_map_point(1055, 356), 
			_campaign_map_point(1055, 355), _campaign_map_point(1055, 354), _campaign_map_point(1055, 353), 
			_campaign_map_point(1055, 352), _campaign_map_point(1055, 351), _campaign_map_point(1055, 350), 
			_campaign_map_point(1055, 349), _campaign_map_point(1055, 348), _campaign_map_point(1055, 347), 
			_campaign_map_point(1055, 346), _campaign_map_point(1055, 345), _campaign_map_point(1055, 344), 
			_campaign_map_point(1055, 343), _campaign_map_point(1055, 342), _campaign_map_point(1055, 341), 
			_campaign_map_point(1055, 340), _campaign_map_point(1055, 339), _campaign_map_point(1055, 338), 
			_campaign_map_point(1055, 337), _campaign_map_point(1055, 336), _campaign_map_point(1055, 335), 
			_campaign_map_point(1055, 334), _campaign_map_point(1055, 333), _campaign_map_point(1055, 332), 
			_campaign_map_point(1055, 331), _campaign_map_point(1055, 330), _campaign_map_point(1055, 329), 
			_campaign_map_point(1055, 328), _campaign_map_point(1055, 327), _campaign_map_point(1055, 326), 
			_campaign_map_point(1055, 325), _campaign_map_point(1055, 324), _campaign_map_point(1055, 323), 
			_campaign_map_point(1055, 322), _campaign_map_point(1055, 321), _campaign_map_point(1055, 320), 
			_campaign_map_point(1055, 319), _campaign_map_point(1055, 318), _campaign_map_point(1055, 317), 
			_campaign_map_point(1055, 316), _campaign_map_point(1055, 315), _campaign_map_point(1055, 314), 
			_campaign_map_point(1055, 313), _campaign_map_point(1055, 312), _campaign_map_point(1055, 311), 
			_campaign_map_point(1055, 310), _campaign_map_point(1055, 309), _campaign_map_point(1055, 308), 
			_campaign_map_point(1055, 307), _campaign_map_point(1055, 306), _campaign_map_point(1055, 305), 
			_campaign_map_point(1055, 304), _campaign_map_point(1055, 303), _campaign_map_point(1055, 302), 
			_campaign_map_point(1055, 301), _campaign_map_point(1055, 300), _campaign_map_point(1055, 299), 
			_campaign_map_point(1055, 298), _campaign_map_point(1055, 297), _campaign_map_point(1055, 296), 
			_campaign_map_point(1055, 295), _campaign_map_point(1055, 294), _campaign_map_point(1055, 293), 
			_campaign_map_point(1055, 292), _campaign_map_point(1055, 291), _campaign_map_point(1055, 290), 
			_campaign_map_point(1055, 289), _campaign_map_point(1055, 288), _campaign_map_point(1055, 287), 
			_campaign_map_point(1055, 286), _campaign_map_point(1055, 285), _campaign_map_point(1055, 284), 
			_campaign_map_point(1055, 283), _campaign_map_point(1055, 282), _campaign_map_point(1055, 281), 
			_campaign_map_point(1055, 280), _campaign_map_point(1055, 279), _campaign_map_point(1055, 278), 
			_campaign_map_point(1055, 277), _campaign_map_point(1055, 276), _campaign_map_point(1055, 275), 
			_campaign_map_point(1055, 274), _campaign_map_point(1055, 273), _campaign_map_point(1055, 272), 
			_campaign_map_point(1055, 271), _campaign_map_point(1055, 270), _campaign_map_point(1055, 269), 
			_campaign_map_point(1055, 268), _campaign_map_point(1055, 267), _campaign_map_point(1055, 266), 
			_campaign_map_point(1055, 265), _campaign_map_point(1055, 264), _campaign_map_point(1055, 263), 
			_campaign_map_point(1055, 262), _campaign_map_point(1055, 261), _campaign_map_point(1055, 260), 
			_campaign_map_point(1055, 259), _campaign_map_point(1055, 258), _campaign_map_point(1055, 257), 
			_campaign_map_point(1055, 256), _campaign_map_point(1055, 255), _campaign_map_point(1055, 254), 
			_campaign_map_point(1055, 253), _campaign_map_point(1055, 252), _campaign_map_point(1055, 251), 
			_campaign_map_point(1055, 250), _campaign_map_point(1055, 249), _campaign_map_point(1055, 248), 
			_campaign_map_point(1055, 247), _campaign_map_point(1055, 246), _campaign_map_point(1055, 245), 
			_campaign_map_point(1055, 244), _campaign_map_point(1055, 243), _campaign_map_point(1055, 242), 
			_campaign_map_point(1055, 241), _campaign_map_point(1055, 240), _campaign_map_point(1055, 239), 
			_campaign_map_point(1055, 238), _campaign_map_point(1055, 237), _campaign_map_point(1055, 236), 
			_campaign_map_point(1055, 235), _campaign_map_point(1055, 234), _campaign_map_point(1055, 233), 
			_campaign_map_point(1055, 232), _campaign_map_point(1055, 231), _campaign_map_point(1055, 230), 
			_campaign_map_point(1055, 229), _campaign_map_point(1055, 228), _campaign_map_point(1055, 227), 
			_campaign_map_point(1055, 226), _campaign_map_point(1055, 225), _campaign_map_point(1055, 224), 
			_campaign_map_point(1055, 223), _campaign_map_point(1055, 222), _campaign_map_point(1055, 221), 
			_campaign_map_point(1055, 220), _campaign_map_point(1055, 219), _campaign_map_point(1055, 218), 
			_campaign_map_point(1055, 217), _campaign_map_point(1055, 216), _campaign_map_point(1055, 215), 
			_campaign_map_point(1055, 214), _campaign_map_point(1055, 213), _campaign_map_point(1055, 212), 
			_campaign_map_point(1055, 211), _campaign_map_point(1055, 210), _campaign_map_point(1055, 209), 
			_campaign_map_point(1055, 208), _campaign_map_point(1055, 207), _campaign_map_point(1055, 206), 
			_campaign_map_point(1055, 205), _campaign_map_point(1055, 204), _campaign_map_point(1055, 203), 
			_campaign_map_point(1055, 202), _campaign_map_point(1055, 201), _campaign_map_point(1055, 200), 
			_campaign_map_point(1055, 199), _campaign_map_point(1055, 198), _campaign_map_point(1055, 197), 
			_campaign_map_point(1055, 196), _campaign_map_point(1055, 195), _campaign_map_point(1055, 194), 
			_campaign_map_point(1055, 193), _campaign_map_point(1055, 192), _campaign_map_point(1055, 191), 
			_campaign_map_point(1055, 190), _campaign_map_point(1055, 189), _campaign_map_point(1055, 188), 
			_campaign_map_point(1055, 187), _campaign_map_point(1055, 186), _campaign_map_point(1055, 185), 
			_campaign_map_point(1055, 184), _campaign_map_point(1055, 183), _campaign_map_point(1055, 182), 
			_campaign_map_point(1055, 181), _campaign_map_point(1055, 180), _campaign_map_point(1055, 179), 
			_campaign_map_point(1055, 178), _campaign_map_point(1055, 177), _campaign_map_point(1055, 176), 
			_campaign_map_point(1055, 175), _campaign_map_point(1055, 174), _campaign_map_point(1055, 173), 
			_campaign_map_point(1055, 172), _campaign_map_point(1055, 171), _campaign_map_point(1055, 170), 
			_campaign_map_point(1055, 169), _campaign_map_point(1055, 168), _campaign_map_point(1055, 167), 
			_campaign_map_point(1055, 166), _campaign_map_point(1055, 165), _campaign_map_point(1055, 164), 
			_campaign_map_point(1055, 163), _campaign_map_point(1055, 162), _campaign_map_point(1055, 161), 
			_campaign_map_point(1055, 160), _campaign_map_point(1055, 159), _campaign_map_point(1055, 158), 
			_campaign_map_point(1055, 157), _campaign_map_point(1055, 156), _campaign_map_point(1055, 155), 
			_campaign_map_point(1055, 154), _campaign_map_point(1055, 153), _campaign_map_point(1055, 152), 
			_campaign_map_point(1055, 151), _campaign_map_point(1055, 150), _campaign_map_point(1055, 149), 
			_campaign_map_point(934, 148), _campaign_map_point(934, 147), _campaign_map_point(933, 146), 
			_campaign_map_point(933, 145), _campaign_map_point(932, 144), _campaign_map_point(931, 143), 
			_campaign_map_point(931, 142), _campaign_map_point(930, 141), _campaign_map_point(930, 140), 
			_campaign_map_point(929, 139), _campaign_map_point(928, 138), _campaign_map_point(928, 137), 
			_campaign_map_point(927, 136), _campaign_map_point(927, 135), _campaign_map_point(926, 134), 
			_campaign_map_point(926, 133), _campaign_map_point(925, 132), _campaign_map_point(924, 131), 
			_campaign_map_point(924, 130), _campaign_map_point(923, 129), _campaign_map_point(922, 128), 
			_campaign_map_point(921, 127), _campaign_map_point(921, 126), _campaign_map_point(920, 125), 
			_campaign_map_point(919, 124), _campaign_map_point(919, 123), _campaign_map_point(918, 122), 
			_campaign_map_point(917, 121), _campaign_map_point(917, 120), _campaign_map_point(916, 119), 
			_campaign_map_point(916, 118), _campaign_map_point(915, 117), _campaign_map_point(915, 116), 
			_campaign_map_point(913, 115), _campaign_map_point(913, 114), _campaign_map_point(912, 113), 
			_campaign_map_point(912, 112), _campaign_map_point(911, 111), _campaign_map_point(911, 110), 
			_campaign_map_point(910, 109), _campaign_map_point(909, 108), _campaign_map_point(907, 107), 
			_campaign_map_point(906, 106), _campaign_map_point(906, 105), _campaign_map_point(905, 104), 
			_campaign_map_point(904, 103), _campaign_map_point(904, 102), _campaign_map_point(903, 101), 
			_campaign_map_point(902, 100), _campaign_map_point(901, 99), _campaign_map_point(900, 98), 
			_campaign_map_point(900, 97), _campaign_map_point(899, 96), _campaign_map_point(898, 95), 
			_campaign_map_point(897, 94), _campaign_map_point(896, 93), _campaign_map_point(896, 92), 
			_campaign_map_point(895, 91), _campaign_map_point(894, 90), _campaign_map_point(893, 89), 
			_campaign_map_point(892, 88), _campaign_map_point(891, 87), _campaign_map_point(890, 86), 
			_campaign_map_point(889, 85), _campaign_map_point(888, 84), _campaign_map_point(887, 83), 
			_campaign_map_point(886, 82), _campaign_map_point(885, 81), _campaign_map_point(884, 80), 
			_campaign_map_point(883, 79), _campaign_map_point(882, 78), _campaign_map_point(880, 77), 
			_campaign_map_point(879, 76), _campaign_map_point(878, 75), _campaign_map_point(877, 74), 
			_campaign_map_point(876, 73), _campaign_map_point(875, 72), _campaign_map_point(874, 71), 
			_campaign_map_point(873, 70), _campaign_map_point(868, 69), _campaign_map_point(868, 68), 
			_campaign_map_point(868, 67), _campaign_map_point(868, 66), _campaign_map_point(867, 65), 
			_campaign_map_point(866, 64), _campaign_map_point(865, 63), _campaign_map_point(864, 62), 
			_campaign_map_point(863, 61), _campaign_map_point(861, 60), _campaign_map_point(859, 59), 
			_campaign_map_point(858, 58), _campaign_map_point(857, 57), _campaign_map_point(856, 56), 
			_campaign_map_point(855, 55), _campaign_map_point(854, 54), _campaign_map_point(853, 53), 
			_campaign_map_point(851, 52), _campaign_map_point(850, 51), _campaign_map_point(848, 50), 
			_campaign_map_point(847, 49), _campaign_map_point(845, 48), _campaign_map_point(844, 47), 
			_campaign_map_point(843, 46)
		]},
		{"section": "Сад творения", "mask": "res://Background/Campaign_Hover_creation_garden.png", "points": [
			_campaign_map_point(1084, 129), _campaign_map_point(1082, 130), _campaign_map_point(1080, 131), 
			_campaign_map_point(1078, 132), _campaign_map_point(1077, 133), _campaign_map_point(1075, 134), 
			_campaign_map_point(1073, 135), _campaign_map_point(1072, 136), _campaign_map_point(1070, 137), 
			_campaign_map_point(1069, 138), _campaign_map_point(1067, 139), _campaign_map_point(1066, 140), 
			_campaign_map_point(1064, 141), _campaign_map_point(1063, 142), _campaign_map_point(1062, 143), 
			_campaign_map_point(1060, 144), _campaign_map_point(1059, 145), _campaign_map_point(1058, 146), 
			_campaign_map_point(1057, 147), _campaign_map_point(1056, 148), _campaign_map_point(1055, 149), 
			_campaign_map_point(1053, 150), _campaign_map_point(1052, 151), _campaign_map_point(1051, 152), 
			_campaign_map_point(1050, 153), _campaign_map_point(1048, 154), _campaign_map_point(1047, 155), 
			_campaign_map_point(1046, 156), _campaign_map_point(1045, 157), _campaign_map_point(1044, 158), 
			_campaign_map_point(1043, 159), _campaign_map_point(1042, 160), _campaign_map_point(1041, 161), 
			_campaign_map_point(1041, 162), _campaign_map_point(1040, 163), _campaign_map_point(1039, 164), 
			_campaign_map_point(1038, 165), _campaign_map_point(1037, 166), _campaign_map_point(1036, 167), 
			_campaign_map_point(1035, 168), _campaign_map_point(1034, 169), _campaign_map_point(1033, 170), 
			_campaign_map_point(1032, 171), _campaign_map_point(1031, 172), _campaign_map_point(1031, 173), 
			_campaign_map_point(1030, 174), _campaign_map_point(1029, 175), _campaign_map_point(1024, 176), 
			_campaign_map_point(1023, 177), _campaign_map_point(1022, 178), _campaign_map_point(1022, 179), 
			_campaign_map_point(1021, 180), _campaign_map_point(1020, 181), _campaign_map_point(1020, 182), 
			_campaign_map_point(1020, 183), _campaign_map_point(1020, 184), _campaign_map_point(1020, 185), 
			_campaign_map_point(1020, 186), _campaign_map_point(1020, 187), _campaign_map_point(1019, 188), 
			_campaign_map_point(1019, 189), _campaign_map_point(1018, 190), _campaign_map_point(1018, 191), 
			_campaign_map_point(1017, 192), _campaign_map_point(1016, 193), _campaign_map_point(1016, 194), 
			_campaign_map_point(1015, 195), _campaign_map_point(1015, 196), _campaign_map_point(1014, 197), 
			_campaign_map_point(1014, 198), _campaign_map_point(1010, 199), _campaign_map_point(1009, 200), 
			_campaign_map_point(1009, 201), _campaign_map_point(1008, 202), _campaign_map_point(1008, 203), 
			_campaign_map_point(1007, 204), _campaign_map_point(1007, 205), _campaign_map_point(1007, 206), 
			_campaign_map_point(1006, 207), _campaign_map_point(1006, 208), _campaign_map_point(1005, 209), 
			_campaign_map_point(1004, 210), _campaign_map_point(1004, 211), _campaign_map_point(1004, 212), 
			_campaign_map_point(1003, 213), _campaign_map_point(1003, 214), _campaign_map_point(1003, 215), 
			_campaign_map_point(1002, 216), _campaign_map_point(1002, 217), _campaign_map_point(1002, 218), 
			_campaign_map_point(1002, 219), _campaign_map_point(1001, 220), _campaign_map_point(1001, 221), 
			_campaign_map_point(1000, 222), _campaign_map_point(1000, 223), _campaign_map_point(1000, 224), 
			_campaign_map_point(999, 225), _campaign_map_point(999, 226), _campaign_map_point(999, 227), 
			_campaign_map_point(998, 228), _campaign_map_point(998, 229), _campaign_map_point(998, 230), 
			_campaign_map_point(998, 231), _campaign_map_point(998, 232), _campaign_map_point(999, 233), 
			_campaign_map_point(999, 234), _campaign_map_point(999, 235), _campaign_map_point(999, 236), 
			_campaign_map_point(999, 237), _campaign_map_point(999, 238), _campaign_map_point(999, 239), 
			_campaign_map_point(999, 240), _campaign_map_point(999, 241), _campaign_map_point(999, 242), 
			_campaign_map_point(999, 243), _campaign_map_point(999, 244), _campaign_map_point(999, 245), 
			_campaign_map_point(999, 246), _campaign_map_point(999, 247), _campaign_map_point(999, 248), 
			_campaign_map_point(998, 249), _campaign_map_point(998, 250), _campaign_map_point(993, 251), 
			_campaign_map_point(993, 252), _campaign_map_point(991, 253), _campaign_map_point(991, 254), 
			_campaign_map_point(991, 255), _campaign_map_point(991, 256), _campaign_map_point(991, 257), 
			_campaign_map_point(991, 258), _campaign_map_point(991, 259), _campaign_map_point(991, 260), 
			_campaign_map_point(991, 261), _campaign_map_point(991, 262), _campaign_map_point(991, 263), 
			_campaign_map_point(991, 264), _campaign_map_point(991, 265), _campaign_map_point(991, 266), 
			_campaign_map_point(991, 267), _campaign_map_point(991, 268), _campaign_map_point(991, 269), 
			_campaign_map_point(991, 270), _campaign_map_point(991, 271), _campaign_map_point(991, 272), 
			_campaign_map_point(991, 273), _campaign_map_point(991, 274), _campaign_map_point(991, 275), 
			_campaign_map_point(991, 276), _campaign_map_point(991, 277), _campaign_map_point(991, 278), 
			_campaign_map_point(991, 279), _campaign_map_point(991, 280), _campaign_map_point(991, 281), 
			_campaign_map_point(991, 282), _campaign_map_point(991, 283), _campaign_map_point(991, 284), 
			_campaign_map_point(991, 285), _campaign_map_point(991, 286), _campaign_map_point(991, 287), 
			_campaign_map_point(991, 288), _campaign_map_point(991, 289), _campaign_map_point(991, 290), 
			_campaign_map_point(991, 291), _campaign_map_point(991, 292), _campaign_map_point(991, 293), 
			_campaign_map_point(991, 294), _campaign_map_point(991, 295), _campaign_map_point(991, 296), 
			_campaign_map_point(991, 297), _campaign_map_point(991, 298), _campaign_map_point(991, 299), 
			_campaign_map_point(991, 300), _campaign_map_point(991, 301), _campaign_map_point(991, 302), 
			_campaign_map_point(991, 303), _campaign_map_point(991, 304), _campaign_map_point(991, 305), 
			_campaign_map_point(991, 306), _campaign_map_point(991, 307), _campaign_map_point(991, 308), 
			_campaign_map_point(991, 309), _campaign_map_point(991, 310), _campaign_map_point(991, 311), 
			_campaign_map_point(991, 312), _campaign_map_point(991, 313), _campaign_map_point(991, 314), 
			_campaign_map_point(991, 315), _campaign_map_point(991, 316), _campaign_map_point(991, 317), 
			_campaign_map_point(991, 318), _campaign_map_point(991, 319), _campaign_map_point(991, 320), 
			_campaign_map_point(991, 321), _campaign_map_point(991, 322), _campaign_map_point(991, 323), 
			_campaign_map_point(991, 324), _campaign_map_point(991, 325), _campaign_map_point(991, 326), 
			_campaign_map_point(991, 327), _campaign_map_point(991, 328), _campaign_map_point(991, 329), 
			_campaign_map_point(991, 330), _campaign_map_point(991, 331), _campaign_map_point(991, 332), 
			_campaign_map_point(991, 333), _campaign_map_point(991, 334), _campaign_map_point(991, 335), 
			_campaign_map_point(991, 336), _campaign_map_point(991, 337), _campaign_map_point(991, 338), 
			_campaign_map_point(991, 339), _campaign_map_point(991, 340), _campaign_map_point(991, 341), 
			_campaign_map_point(991, 342), _campaign_map_point(991, 343), _campaign_map_point(991, 344), 
			_campaign_map_point(991, 345), _campaign_map_point(991, 346), _campaign_map_point(991, 347), 
			_campaign_map_point(991, 348), _campaign_map_point(991, 349), _campaign_map_point(991, 350), 
			_campaign_map_point(991, 351), _campaign_map_point(991, 352), _campaign_map_point(991, 353), 
			_campaign_map_point(991, 354), _campaign_map_point(991, 355), _campaign_map_point(991, 356), 
			_campaign_map_point(991, 357), _campaign_map_point(991, 358), _campaign_map_point(991, 359), 
			_campaign_map_point(991, 360), _campaign_map_point(991, 361), _campaign_map_point(991, 362), 
			_campaign_map_point(991, 363), _campaign_map_point(991, 364), _campaign_map_point(991, 365), 
			_campaign_map_point(991, 366), _campaign_map_point(991, 367), _campaign_map_point(991, 368), 
			_campaign_map_point(991, 369), _campaign_map_point(991, 370), _campaign_map_point(991, 371), 
			_campaign_map_point(991, 372), _campaign_map_point(991, 373), _campaign_map_point(991, 374), 
			_campaign_map_point(991, 375), _campaign_map_point(991, 376), _campaign_map_point(991, 377), 
			_campaign_map_point(991, 378), _campaign_map_point(991, 379), _campaign_map_point(991, 380), 
			_campaign_map_point(991, 381), _campaign_map_point(991, 382), _campaign_map_point(991, 383), 
			_campaign_map_point(991, 384), _campaign_map_point(991, 385), _campaign_map_point(991, 386), 
			_campaign_map_point(991, 387), _campaign_map_point(991, 388), _campaign_map_point(991, 389), 
			_campaign_map_point(991, 390), _campaign_map_point(991, 391), _campaign_map_point(991, 392), 
			_campaign_map_point(991, 393), _campaign_map_point(991, 394), _campaign_map_point(991, 395), 
			_campaign_map_point(991, 396), _campaign_map_point(991, 397), _campaign_map_point(991, 398), 
			_campaign_map_point(991, 399), _campaign_map_point(991, 400), _campaign_map_point(991, 401), 
			_campaign_map_point(991, 402), _campaign_map_point(991, 403), _campaign_map_point(991, 404), 
			_campaign_map_point(991, 405), _campaign_map_point(991, 406), _campaign_map_point(991, 407), 
			_campaign_map_point(991, 408), _campaign_map_point(991, 409), _campaign_map_point(991, 410), 
			_campaign_map_point(991, 411), _campaign_map_point(991, 412), _campaign_map_point(991, 413), 
			_campaign_map_point(991, 414), _campaign_map_point(991, 415), _campaign_map_point(991, 416), 
			_campaign_map_point(991, 417), _campaign_map_point(991, 418), _campaign_map_point(991, 419), 
			_campaign_map_point(991, 420), _campaign_map_point(991, 421), _campaign_map_point(991, 422), 
			_campaign_map_point(991, 423), _campaign_map_point(991, 424), _campaign_map_point(991, 425), 
			_campaign_map_point(991, 426), _campaign_map_point(991, 427), _campaign_map_point(991, 428), 
			_campaign_map_point(991, 429), _campaign_map_point(991, 430), _campaign_map_point(991, 431), 
			_campaign_map_point(991, 432), _campaign_map_point(991, 433), _campaign_map_point(991, 434), 
			_campaign_map_point(991, 435), _campaign_map_point(991, 436), _campaign_map_point(991, 437), 
			_campaign_map_point(991, 438), _campaign_map_point(991, 439), _campaign_map_point(991, 440), 
			_campaign_map_point(991, 441), _campaign_map_point(991, 442), _campaign_map_point(991, 443), 
			_campaign_map_point(991, 444), _campaign_map_point(991, 445), _campaign_map_point(991, 446), 
			_campaign_map_point(991, 447), _campaign_map_point(991, 448), _campaign_map_point(991, 449), 
			_campaign_map_point(991, 450), _campaign_map_point(991, 451), _campaign_map_point(991, 452), 
			_campaign_map_point(991, 453), _campaign_map_point(991, 454), _campaign_map_point(991, 455), 
			_campaign_map_point(991, 456), _campaign_map_point(991, 457), _campaign_map_point(991, 458), 
			_campaign_map_point(991, 459), _campaign_map_point(991, 460), _campaign_map_point(991, 461), 
			_campaign_map_point(991, 462), _campaign_map_point(991, 463), _campaign_map_point(991, 464), 
			_campaign_map_point(991, 465), _campaign_map_point(991, 466), _campaign_map_point(991, 467), 
			_campaign_map_point(991, 468), _campaign_map_point(991, 469), _campaign_map_point(991, 470), 
			_campaign_map_point(991, 471), _campaign_map_point(991, 472), _campaign_map_point(991, 473), 
			_campaign_map_point(991, 474), _campaign_map_point(991, 475), _campaign_map_point(991, 476), 
			_campaign_map_point(991, 477), _campaign_map_point(991, 478), _campaign_map_point(991, 479), 
			_campaign_map_point(991, 480), _campaign_map_point(991, 481), _campaign_map_point(991, 482), 
			_campaign_map_point(991, 483), _campaign_map_point(991, 484), _campaign_map_point(991, 485), 
			_campaign_map_point(991, 486), _campaign_map_point(991, 487), _campaign_map_point(991, 488), 
			_campaign_map_point(995, 489), _campaign_map_point(995, 490), _campaign_map_point(995, 491), 
			_campaign_map_point(995, 492), _campaign_map_point(995, 493), _campaign_map_point(995, 494), 
			_campaign_map_point(995, 495), _campaign_map_point(995, 496), _campaign_map_point(995, 497), 
			_campaign_map_point(995, 498), _campaign_map_point(995, 499), _campaign_map_point(995, 500), 
			_campaign_map_point(995, 501), _campaign_map_point(991, 502), _campaign_map_point(991, 503), 
			_campaign_map_point(991, 504), _campaign_map_point(991, 505), _campaign_map_point(991, 506), 
			_campaign_map_point(991, 507), _campaign_map_point(991, 508), _campaign_map_point(991, 509), 
			_campaign_map_point(991, 510), _campaign_map_point(991, 511), _campaign_map_point(991, 512), 
			_campaign_map_point(991, 513), _campaign_map_point(991, 514), _campaign_map_point(991, 515), 
			_campaign_map_point(991, 516), _campaign_map_point(991, 517), _campaign_map_point(991, 518), 
			_campaign_map_point(991, 519), _campaign_map_point(991, 520), _campaign_map_point(991, 521), 
			_campaign_map_point(991, 522), _campaign_map_point(991, 523), _campaign_map_point(991, 524), 
			_campaign_map_point(991, 525), _campaign_map_point(991, 526), _campaign_map_point(991, 527), 
			_campaign_map_point(991, 528), _campaign_map_point(991, 529), _campaign_map_point(991, 530), 
			_campaign_map_point(991, 531), _campaign_map_point(991, 532), _campaign_map_point(991, 533), 
			_campaign_map_point(991, 534), _campaign_map_point(991, 535), _campaign_map_point(991, 536), 
			_campaign_map_point(991, 537), _campaign_map_point(991, 538), _campaign_map_point(991, 539), 
			_campaign_map_point(991, 540), _campaign_map_point(991, 541), _campaign_map_point(991, 542), 
			_campaign_map_point(991, 543), _campaign_map_point(991, 544), _campaign_map_point(991, 545), 
			_campaign_map_point(991, 546), _campaign_map_point(991, 547), _campaign_map_point(991, 548), 
			_campaign_map_point(991, 549), _campaign_map_point(991, 550), _campaign_map_point(991, 551), 
			_campaign_map_point(991, 552), _campaign_map_point(991, 553), _campaign_map_point(991, 554), 
			_campaign_map_point(991, 555), _campaign_map_point(991, 556), _campaign_map_point(991, 557), 
			_campaign_map_point(991, 558), _campaign_map_point(991, 559), _campaign_map_point(991, 560), 
			_campaign_map_point(991, 561), _campaign_map_point(991, 562), _campaign_map_point(991, 563), 
			_campaign_map_point(991, 564), _campaign_map_point(995, 565), _campaign_map_point(995, 566), 
			_campaign_map_point(995, 567), _campaign_map_point(995, 568), _campaign_map_point(995, 569), 
			_campaign_map_point(995, 570), _campaign_map_point(995, 571), _campaign_map_point(995, 572), 
			_campaign_map_point(995, 573), _campaign_map_point(995, 574), _campaign_map_point(995, 575), 
			_campaign_map_point(995, 576), _campaign_map_point(995, 577), _campaign_map_point(996, 578), 
			_campaign_map_point(996, 579), _campaign_map_point(996, 580), _campaign_map_point(996, 581), 
			_campaign_map_point(996, 582), _campaign_map_point(996, 583), _campaign_map_point(996, 584), 
			_campaign_map_point(996, 585), _campaign_map_point(996, 586), _campaign_map_point(996, 587), 
			_campaign_map_point(996, 588), _campaign_map_point(991, 589), _campaign_map_point(991, 590), 
			_campaign_map_point(991, 591), _campaign_map_point(991, 592), _campaign_map_point(991, 593), 
			_campaign_map_point(991, 594), _campaign_map_point(991, 595), _campaign_map_point(991, 596), 
			_campaign_map_point(991, 597), _campaign_map_point(991, 598), _campaign_map_point(991, 599), 
			_campaign_map_point(995, 600), _campaign_map_point(995, 601), _campaign_map_point(995, 602), 
			_campaign_map_point(995, 603), _campaign_map_point(995, 604), _campaign_map_point(995, 605), 
			_campaign_map_point(995, 606), _campaign_map_point(995, 607), _campaign_map_point(995, 608), 
			_campaign_map_point(995, 609), _campaign_map_point(995, 610), _campaign_map_point(995, 611), 
			_campaign_map_point(995, 612), _campaign_map_point(995, 613), _campaign_map_point(995, 614), 
			_campaign_map_point(995, 615), _campaign_map_point(992, 616), _campaign_map_point(992, 617), 
			_campaign_map_point(992, 618), _campaign_map_point(992, 619), _campaign_map_point(992, 620), 
			_campaign_map_point(992, 621), _campaign_map_point(992, 622), _campaign_map_point(992, 623), 
			_campaign_map_point(992, 624), _campaign_map_point(992, 625), _campaign_map_point(991, 626), 
			_campaign_map_point(991, 627), _campaign_map_point(991, 628), _campaign_map_point(991, 629), 
			_campaign_map_point(991, 630), _campaign_map_point(991, 631), _campaign_map_point(991, 632), 
			_campaign_map_point(991, 633), _campaign_map_point(991, 634), _campaign_map_point(991, 635), 
			_campaign_map_point(991, 636), _campaign_map_point(991, 637), _campaign_map_point(991, 638), 
			_campaign_map_point(991, 639), _campaign_map_point(983, 640), _campaign_map_point(983, 641), 
			_campaign_map_point(983, 642), _campaign_map_point(991, 643), _campaign_map_point(991, 644), 
			_campaign_map_point(992, 645), _campaign_map_point(992, 646), _campaign_map_point(992, 647), 
			_campaign_map_point(992, 648), _campaign_map_point(992, 649), _campaign_map_point(992, 650), 
			_campaign_map_point(992, 651), _campaign_map_point(992, 652), _campaign_map_point(992, 653), 
			_campaign_map_point(992, 654), _campaign_map_point(992, 655), _campaign_map_point(991, 656), 
			_campaign_map_point(991, 657), _campaign_map_point(991, 658), _campaign_map_point(991, 659), 
			_campaign_map_point(991, 660), _campaign_map_point(991, 661), _campaign_map_point(991, 662), 
			_campaign_map_point(991, 663), _campaign_map_point(991, 664), _campaign_map_point(991, 665), 
			_campaign_map_point(991, 666), _campaign_map_point(992, 667), _campaign_map_point(992, 668), 
			_campaign_map_point(992, 669), _campaign_map_point(992, 670), _campaign_map_point(992, 671), 
			_campaign_map_point(992, 672), _campaign_map_point(992, 673), _campaign_map_point(992, 674), 
			_campaign_map_point(992, 675), _campaign_map_point(992, 676), _campaign_map_point(992, 677), 
			_campaign_map_point(992, 678), _campaign_map_point(992, 679), _campaign_map_point(992, 680), 
			_campaign_map_point(992, 681), _campaign_map_point(992, 682), _campaign_map_point(992, 683), 
			_campaign_map_point(992, 684), _campaign_map_point(992, 685), _campaign_map_point(992, 686), 
			_campaign_map_point(992, 687), _campaign_map_point(992, 688), _campaign_map_point(992, 689), 
			_campaign_map_point(992, 690), _campaign_map_point(992, 691), _campaign_map_point(993, 692), 
			_campaign_map_point(993, 693), _campaign_map_point(993, 694), _campaign_map_point(994, 695), 
			_campaign_map_point(994, 696), _campaign_map_point(995, 697), _campaign_map_point(995, 698), 
			_campaign_map_point(995, 699), _campaign_map_point(996, 700), _campaign_map_point(996, 701), 
			_campaign_map_point(996, 702), _campaign_map_point(997, 703), _campaign_map_point(997, 704), 
			_campaign_map_point(997, 705), _campaign_map_point(997, 706), _campaign_map_point(997, 707), 
			_campaign_map_point(997, 708), _campaign_map_point(997, 709), _campaign_map_point(997, 710), 
			_campaign_map_point(997, 711), _campaign_map_point(997, 712), _campaign_map_point(997, 713), 
			_campaign_map_point(997, 714), _campaign_map_point(997, 715), _campaign_map_point(997, 716), 
			_campaign_map_point(997, 717), _campaign_map_point(996, 718), _campaign_map_point(997, 719), 
			_campaign_map_point(997, 720), _campaign_map_point(1001, 727), _campaign_map_point(1001, 728), 
			_campaign_map_point(1002, 729), _campaign_map_point(1002, 730), _campaign_map_point(1003, 731), 
			_campaign_map_point(1003, 732), _campaign_map_point(1004, 733), _campaign_map_point(1005, 734), 
			_campaign_map_point(1005, 735), _campaign_map_point(1005, 736), _campaign_map_point(1006, 737), 
			_campaign_map_point(1007, 738), _campaign_map_point(1007, 739), _campaign_map_point(1008, 740), 
			_campaign_map_point(1008, 741), _campaign_map_point(1009, 742), _campaign_map_point(1009, 743), 
			_campaign_map_point(1010, 744), _campaign_map_point(1010, 745), _campaign_map_point(1011, 746), 
			_campaign_map_point(1011, 747), _campaign_map_point(1012, 748), _campaign_map_point(1012, 749), 
			_campaign_map_point(1013, 750), _campaign_map_point(1013, 751), _campaign_map_point(1014, 752), 
			_campaign_map_point(1015, 753), _campaign_map_point(1015, 754), _campaign_map_point(1016, 755), 
			_campaign_map_point(1016, 756), _campaign_map_point(1017, 757), _campaign_map_point(1017, 758), 
			_campaign_map_point(1018, 759), _campaign_map_point(1018, 760), _campaign_map_point(1019, 761), 
			_campaign_map_point(1019, 762), _campaign_map_point(1020, 763), _campaign_map_point(1021, 764), 
			_campaign_map_point(1021, 765), _campaign_map_point(1021, 766), _campaign_map_point(1022, 767), 
			_campaign_map_point(1022, 768), _campaign_map_point(1023, 769), _campaign_map_point(1023, 770), 
			_campaign_map_point(1024, 771), _campaign_map_point(1024, 772), _campaign_map_point(1025, 773), 
			_campaign_map_point(1025, 774), _campaign_map_point(1026, 775), _campaign_map_point(1026, 776), 
			_campaign_map_point(1027, 777), _campaign_map_point(1027, 778), _campaign_map_point(1028, 779), 
			_campaign_map_point(1029, 780), _campaign_map_point(1029, 781), _campaign_map_point(1030, 782), 
			_campaign_map_point(1030, 783), _campaign_map_point(1031, 784), _campaign_map_point(1031, 785), 
			_campaign_map_point(1032, 786), _campaign_map_point(1032, 787), _campaign_map_point(1033, 788), 
			_campaign_map_point(1033, 789), _campaign_map_point(1034, 790), _campaign_map_point(1034, 791), 
			_campaign_map_point(1035, 792), _campaign_map_point(1035, 793), _campaign_map_point(1036, 794), 
			_campaign_map_point(1036, 795), _campaign_map_point(1037, 796), _campaign_map_point(1037, 797), 
			_campaign_map_point(1038, 798), _campaign_map_point(1038, 799), _campaign_map_point(1039, 800), 
			_campaign_map_point(1039, 801), _campaign_map_point(1040, 802), _campaign_map_point(1040, 803), 
			_campaign_map_point(1041, 804), _campaign_map_point(1041, 805), _campaign_map_point(1041, 806), 
			_campaign_map_point(1041, 807), _campaign_map_point(1041, 808), _campaign_map_point(1041, 809), 
			_campaign_map_point(1041, 810), _campaign_map_point(1205, 810), _campaign_map_point(1205, 809), 
			_campaign_map_point(1205, 808), _campaign_map_point(1205, 807), _campaign_map_point(1205, 806), 
			_campaign_map_point(1205, 805), _campaign_map_point(1205, 804), _campaign_map_point(1205, 803), 
			_campaign_map_point(1205, 802), _campaign_map_point(1205, 801), _campaign_map_point(1205, 800), 
			_campaign_map_point(1205, 799), _campaign_map_point(1205, 798), _campaign_map_point(1205, 797), 
			_campaign_map_point(1205, 796), _campaign_map_point(1205, 795), _campaign_map_point(1205, 794), 
			_campaign_map_point(1205, 793), _campaign_map_point(1205, 792), _campaign_map_point(1205, 791), 
			_campaign_map_point(1205, 790), _campaign_map_point(1205, 789), _campaign_map_point(1205, 788), 
			_campaign_map_point(1205, 787), _campaign_map_point(1205, 786), _campaign_map_point(1205, 785), 
			_campaign_map_point(1205, 784), _campaign_map_point(1205, 783), _campaign_map_point(1205, 782), 
			_campaign_map_point(1205, 781), _campaign_map_point(1205, 780), _campaign_map_point(1205, 779), 
			_campaign_map_point(1205, 778), _campaign_map_point(1205, 777), _campaign_map_point(1205, 776), 
			_campaign_map_point(1205, 775), _campaign_map_point(1205, 774), _campaign_map_point(1205, 773), 
			_campaign_map_point(1205, 772), _campaign_map_point(1205, 771), _campaign_map_point(1205, 770), 
			_campaign_map_point(1205, 769), _campaign_map_point(1205, 768), _campaign_map_point(1205, 767), 
			_campaign_map_point(1205, 766), _campaign_map_point(1205, 765), _campaign_map_point(1205, 764), 
			_campaign_map_point(1205, 763), _campaign_map_point(1205, 762), _campaign_map_point(1205, 761), 
			_campaign_map_point(1205, 760), _campaign_map_point(1205, 759), _campaign_map_point(1205, 758), 
			_campaign_map_point(1205, 757), _campaign_map_point(1205, 756), _campaign_map_point(1205, 755), 
			_campaign_map_point(1205, 754), _campaign_map_point(1205, 753), _campaign_map_point(1205, 752), 
			_campaign_map_point(1205, 751), _campaign_map_point(1205, 750), _campaign_map_point(1205, 749), 
			_campaign_map_point(1205, 748), _campaign_map_point(1205, 747), _campaign_map_point(1205, 746), 
			_campaign_map_point(1205, 745), _campaign_map_point(1205, 744), _campaign_map_point(1196, 743), 
			_campaign_map_point(1192, 742), _campaign_map_point(1191, 741), _campaign_map_point(1191, 740), 
			_campaign_map_point(1190, 739), _campaign_map_point(1190, 738), _campaign_map_point(1190, 737), 
			_campaign_map_point(1189, 736), _campaign_map_point(1188, 735), _campaign_map_point(1186, 734), 
			_campaign_map_point(1184, 733), _campaign_map_point(1184, 732), _campaign_map_point(1086, 731), 
			_campaign_map_point(1065, 730), _campaign_map_point(1045, 729), _campaign_map_point(1028, 728), 
			_campaign_map_point(1013, 727), _campaign_map_point(1168, 720), _campaign_map_point(1168, 719), 
			_campaign_map_point(1168, 718), _campaign_map_point(1169, 717), _campaign_map_point(1170, 716), 
			_campaign_map_point(1171, 715), _campaign_map_point(1171, 714), _campaign_map_point(1171, 713), 
			_campaign_map_point(1171, 712), _campaign_map_point(1171, 711), _campaign_map_point(1171, 710), 
			_campaign_map_point(1171, 709), _campaign_map_point(1171, 708), _campaign_map_point(1171, 707), 
			_campaign_map_point(1171, 706), _campaign_map_point(1171, 705), _campaign_map_point(1171, 704), 
			_campaign_map_point(1170, 703), _campaign_map_point(1170, 702), _campaign_map_point(1170, 701), 
			_campaign_map_point(1170, 700), _campaign_map_point(1170, 699), _campaign_map_point(1170, 698), 
			_campaign_map_point(1170, 697), _campaign_map_point(1170, 696), _campaign_map_point(1170, 695), 
			_campaign_map_point(1170, 694), _campaign_map_point(1170, 693), _campaign_map_point(1170, 692), 
			_campaign_map_point(1171, 691), _campaign_map_point(1171, 690), _campaign_map_point(1171, 689), 
			_campaign_map_point(1171, 688), _campaign_map_point(1171, 687), _campaign_map_point(1171, 686), 
			_campaign_map_point(1171, 685), _campaign_map_point(1171, 684), _campaign_map_point(1171, 683), 
			_campaign_map_point(1171, 682), _campaign_map_point(1171, 681), _campaign_map_point(1172, 680), 
			_campaign_map_point(1172, 679), _campaign_map_point(1172, 678), _campaign_map_point(1172, 677), 
			_campaign_map_point(1172, 676), _campaign_map_point(1172, 675), _campaign_map_point(1172, 674), 
			_campaign_map_point(1172, 673), _campaign_map_point(1172, 672), _campaign_map_point(1173, 671), 
			_campaign_map_point(1173, 670), _campaign_map_point(1173, 669), _campaign_map_point(1173, 668), 
			_campaign_map_point(1173, 667), _campaign_map_point(1173, 666), _campaign_map_point(1173, 665), 
			_campaign_map_point(1173, 664), _campaign_map_point(1173, 663), _campaign_map_point(1172, 662), 
			_campaign_map_point(1172, 661), _campaign_map_point(1172, 660), _campaign_map_point(1172, 659), 
			_campaign_map_point(1172, 658), _campaign_map_point(1172, 657), _campaign_map_point(1172, 656), 
			_campaign_map_point(1172, 655), _campaign_map_point(1172, 654), _campaign_map_point(1172, 653), 
			_campaign_map_point(1172, 652), _campaign_map_point(1172, 651), _campaign_map_point(1172, 650), 
			_campaign_map_point(1172, 649), _campaign_map_point(1172, 648), _campaign_map_point(1172, 647), 
			_campaign_map_point(1172, 646), _campaign_map_point(1172, 645), _campaign_map_point(1172, 644), 
			_campaign_map_point(1172, 643), _campaign_map_point(1172, 642), _campaign_map_point(1172, 641), 
			_campaign_map_point(1172, 640), _campaign_map_point(1172, 639), _campaign_map_point(1172, 638), 
			_campaign_map_point(1172, 637), _campaign_map_point(1172, 636), _campaign_map_point(1172, 635), 
			_campaign_map_point(1172, 634), _campaign_map_point(1172, 633), _campaign_map_point(1172, 632), 
			_campaign_map_point(1172, 631), _campaign_map_point(1172, 630), _campaign_map_point(1172, 629), 
			_campaign_map_point(1172, 628), _campaign_map_point(1172, 627), _campaign_map_point(1172, 626), 
			_campaign_map_point(1172, 625), _campaign_map_point(1172, 624), _campaign_map_point(1172, 623), 
			_campaign_map_point(1172, 622), _campaign_map_point(1172, 621), _campaign_map_point(1172, 620), 
			_campaign_map_point(1172, 619), _campaign_map_point(1172, 618), _campaign_map_point(1172, 617), 
			_campaign_map_point(1172, 616), _campaign_map_point(1172, 615), _campaign_map_point(1172, 614), 
			_campaign_map_point(1172, 613), _campaign_map_point(1172, 612), _campaign_map_point(1172, 611), 
			_campaign_map_point(1172, 610), _campaign_map_point(1172, 609), _campaign_map_point(1172, 608), 
			_campaign_map_point(1172, 607), _campaign_map_point(1172, 606), _campaign_map_point(1172, 605), 
			_campaign_map_point(1172, 604), _campaign_map_point(1172, 603), _campaign_map_point(1172, 602), 
			_campaign_map_point(1172, 601), _campaign_map_point(1172, 600), _campaign_map_point(1172, 599), 
			_campaign_map_point(1172, 598), _campaign_map_point(1172, 597), _campaign_map_point(1172, 596), 
			_campaign_map_point(1172, 595), _campaign_map_point(1172, 594), _campaign_map_point(1172, 593), 
			_campaign_map_point(1172, 592), _campaign_map_point(1172, 591), _campaign_map_point(1172, 590), 
			_campaign_map_point(1172, 589), _campaign_map_point(1172, 588), _campaign_map_point(1172, 587), 
			_campaign_map_point(1172, 586), _campaign_map_point(1172, 585), _campaign_map_point(1172, 584), 
			_campaign_map_point(1172, 583), _campaign_map_point(1172, 582), _campaign_map_point(1172, 581), 
			_campaign_map_point(1172, 580), _campaign_map_point(1172, 579), _campaign_map_point(1172, 578), 
			_campaign_map_point(1172, 577), _campaign_map_point(1172, 576), _campaign_map_point(1172, 575), 
			_campaign_map_point(1172, 574), _campaign_map_point(1172, 573), _campaign_map_point(1172, 572), 
			_campaign_map_point(1172, 571), _campaign_map_point(1172, 570), _campaign_map_point(1172, 569), 
			_campaign_map_point(1172, 568), _campaign_map_point(1172, 567), _campaign_map_point(1172, 566), 
			_campaign_map_point(1172, 565), _campaign_map_point(1172, 564), _campaign_map_point(1172, 563), 
			_campaign_map_point(1172, 562), _campaign_map_point(1172, 561), _campaign_map_point(1172, 560), 
			_campaign_map_point(1172, 559), _campaign_map_point(1172, 558), _campaign_map_point(1172, 557), 
			_campaign_map_point(1172, 556), _campaign_map_point(1172, 555), _campaign_map_point(1172, 554), 
			_campaign_map_point(1172, 553), _campaign_map_point(1172, 552), _campaign_map_point(1172, 551), 
			_campaign_map_point(1172, 550), _campaign_map_point(1172, 549), _campaign_map_point(1172, 548), 
			_campaign_map_point(1172, 547), _campaign_map_point(1172, 546), _campaign_map_point(1172, 545), 
			_campaign_map_point(1172, 544), _campaign_map_point(1172, 543), _campaign_map_point(1172, 542), 
			_campaign_map_point(1172, 541), _campaign_map_point(1172, 540), _campaign_map_point(1172, 539), 
			_campaign_map_point(1172, 538), _campaign_map_point(1172, 537), _campaign_map_point(1172, 536), 
			_campaign_map_point(1172, 535), _campaign_map_point(1172, 534), _campaign_map_point(1172, 533), 
			_campaign_map_point(1172, 532), _campaign_map_point(1172, 531), _campaign_map_point(1172, 530), 
			_campaign_map_point(1172, 529), _campaign_map_point(1172, 528), _campaign_map_point(1172, 527), 
			_campaign_map_point(1172, 526), _campaign_map_point(1172, 525), _campaign_map_point(1172, 524), 
			_campaign_map_point(1172, 523), _campaign_map_point(1172, 522), _campaign_map_point(1172, 521), 
			_campaign_map_point(1172, 520), _campaign_map_point(1172, 519), _campaign_map_point(1172, 518), 
			_campaign_map_point(1172, 517), _campaign_map_point(1172, 516), _campaign_map_point(1172, 515), 
			_campaign_map_point(1172, 514), _campaign_map_point(1172, 513), _campaign_map_point(1172, 512), 
			_campaign_map_point(1172, 511), _campaign_map_point(1172, 510), _campaign_map_point(1172, 509), 
			_campaign_map_point(1172, 508), _campaign_map_point(1172, 507), _campaign_map_point(1172, 506), 
			_campaign_map_point(1172, 505), _campaign_map_point(1172, 504), _campaign_map_point(1172, 503), 
			_campaign_map_point(1172, 502), _campaign_map_point(1172, 501), _campaign_map_point(1172, 500), 
			_campaign_map_point(1172, 499), _campaign_map_point(1172, 498), _campaign_map_point(1172, 497), 
			_campaign_map_point(1172, 496), _campaign_map_point(1172, 495), _campaign_map_point(1172, 494), 
			_campaign_map_point(1172, 493), _campaign_map_point(1172, 492), _campaign_map_point(1172, 491), 
			_campaign_map_point(1172, 490), _campaign_map_point(1172, 489), _campaign_map_point(1172, 488), 
			_campaign_map_point(1172, 487), _campaign_map_point(1172, 486), _campaign_map_point(1172, 485), 
			_campaign_map_point(1172, 484), _campaign_map_point(1172, 483), _campaign_map_point(1172, 482), 
			_campaign_map_point(1172, 481), _campaign_map_point(1172, 480), _campaign_map_point(1172, 479), 
			_campaign_map_point(1172, 478), _campaign_map_point(1172, 477), _campaign_map_point(1172, 476), 
			_campaign_map_point(1172, 475), _campaign_map_point(1172, 474), _campaign_map_point(1172, 473), 
			_campaign_map_point(1172, 472), _campaign_map_point(1172, 471), _campaign_map_point(1172, 470), 
			_campaign_map_point(1172, 469), _campaign_map_point(1172, 468), _campaign_map_point(1172, 467), 
			_campaign_map_point(1172, 466), _campaign_map_point(1172, 465), _campaign_map_point(1172, 464), 
			_campaign_map_point(1172, 463), _campaign_map_point(1172, 462), _campaign_map_point(1172, 461), 
			_campaign_map_point(1172, 460), _campaign_map_point(1172, 459), _campaign_map_point(1172, 458), 
			_campaign_map_point(1172, 457), _campaign_map_point(1172, 456), _campaign_map_point(1172, 455), 
			_campaign_map_point(1172, 454), _campaign_map_point(1172, 453), _campaign_map_point(1172, 452), 
			_campaign_map_point(1172, 451), _campaign_map_point(1172, 450), _campaign_map_point(1172, 449), 
			_campaign_map_point(1172, 448), _campaign_map_point(1172, 447), _campaign_map_point(1172, 446), 
			_campaign_map_point(1172, 445), _campaign_map_point(1172, 444), _campaign_map_point(1172, 443), 
			_campaign_map_point(1172, 442), _campaign_map_point(1172, 441), _campaign_map_point(1172, 440), 
			_campaign_map_point(1172, 439), _campaign_map_point(1172, 438), _campaign_map_point(1172, 437), 
			_campaign_map_point(1172, 436), _campaign_map_point(1172, 435), _campaign_map_point(1172, 434), 
			_campaign_map_point(1172, 433), _campaign_map_point(1172, 432), _campaign_map_point(1172, 431), 
			_campaign_map_point(1172, 430), _campaign_map_point(1172, 429), _campaign_map_point(1172, 428), 
			_campaign_map_point(1172, 427), _campaign_map_point(1172, 426), _campaign_map_point(1172, 425), 
			_campaign_map_point(1172, 424), _campaign_map_point(1172, 423), _campaign_map_point(1172, 422), 
			_campaign_map_point(1172, 421), _campaign_map_point(1172, 420), _campaign_map_point(1172, 419), 
			_campaign_map_point(1172, 418), _campaign_map_point(1172, 417), _campaign_map_point(1172, 416), 
			_campaign_map_point(1172, 415), _campaign_map_point(1172, 414), _campaign_map_point(1172, 413), 
			_campaign_map_point(1172, 412), _campaign_map_point(1172, 411), _campaign_map_point(1172, 410), 
			_campaign_map_point(1172, 409), _campaign_map_point(1172, 408), _campaign_map_point(1172, 407), 
			_campaign_map_point(1172, 406), _campaign_map_point(1172, 405), _campaign_map_point(1172, 404), 
			_campaign_map_point(1172, 403), _campaign_map_point(1172, 402), _campaign_map_point(1172, 401), 
			_campaign_map_point(1172, 400), _campaign_map_point(1172, 399), _campaign_map_point(1172, 398), 
			_campaign_map_point(1172, 397), _campaign_map_point(1172, 396), _campaign_map_point(1172, 395), 
			_campaign_map_point(1172, 394), _campaign_map_point(1172, 393), _campaign_map_point(1172, 392), 
			_campaign_map_point(1172, 391), _campaign_map_point(1172, 390), _campaign_map_point(1172, 389), 
			_campaign_map_point(1172, 388), _campaign_map_point(1172, 387), _campaign_map_point(1172, 386), 
			_campaign_map_point(1172, 385), _campaign_map_point(1172, 384), _campaign_map_point(1172, 383), 
			_campaign_map_point(1172, 382), _campaign_map_point(1172, 381), _campaign_map_point(1172, 380), 
			_campaign_map_point(1172, 379), _campaign_map_point(1172, 378), _campaign_map_point(1172, 377), 
			_campaign_map_point(1172, 376), _campaign_map_point(1172, 375), _campaign_map_point(1172, 374), 
			_campaign_map_point(1172, 373), _campaign_map_point(1172, 372), _campaign_map_point(1172, 371), 
			_campaign_map_point(1172, 370), _campaign_map_point(1172, 369), _campaign_map_point(1172, 368), 
			_campaign_map_point(1172, 367), _campaign_map_point(1172, 366), _campaign_map_point(1172, 365), 
			_campaign_map_point(1172, 364), _campaign_map_point(1172, 363), _campaign_map_point(1172, 362), 
			_campaign_map_point(1172, 361), _campaign_map_point(1172, 360), _campaign_map_point(1172, 359), 
			_campaign_map_point(1172, 358), _campaign_map_point(1172, 357), _campaign_map_point(1172, 356), 
			_campaign_map_point(1172, 355), _campaign_map_point(1172, 354), _campaign_map_point(1172, 353), 
			_campaign_map_point(1172, 352), _campaign_map_point(1172, 351), _campaign_map_point(1172, 350), 
			_campaign_map_point(1172, 349), _campaign_map_point(1172, 348), _campaign_map_point(1172, 347), 
			_campaign_map_point(1172, 346), _campaign_map_point(1172, 345), _campaign_map_point(1172, 344), 
			_campaign_map_point(1172, 343), _campaign_map_point(1172, 342), _campaign_map_point(1172, 341), 
			_campaign_map_point(1172, 340), _campaign_map_point(1172, 339), _campaign_map_point(1172, 338), 
			_campaign_map_point(1172, 337), _campaign_map_point(1172, 336), _campaign_map_point(1172, 335), 
			_campaign_map_point(1172, 334), _campaign_map_point(1172, 333), _campaign_map_point(1172, 332), 
			_campaign_map_point(1172, 331), _campaign_map_point(1172, 330), _campaign_map_point(1172, 329), 
			_campaign_map_point(1172, 328), _campaign_map_point(1172, 327), _campaign_map_point(1172, 326), 
			_campaign_map_point(1172, 325), _campaign_map_point(1172, 324), _campaign_map_point(1172, 323), 
			_campaign_map_point(1172, 322), _campaign_map_point(1172, 321), _campaign_map_point(1172, 320), 
			_campaign_map_point(1172, 319), _campaign_map_point(1172, 318), _campaign_map_point(1172, 317), 
			_campaign_map_point(1172, 316), _campaign_map_point(1172, 315), _campaign_map_point(1172, 314), 
			_campaign_map_point(1172, 313), _campaign_map_point(1172, 312), _campaign_map_point(1172, 311), 
			_campaign_map_point(1172, 310), _campaign_map_point(1172, 309), _campaign_map_point(1172, 308), 
			_campaign_map_point(1172, 307), _campaign_map_point(1172, 306), _campaign_map_point(1172, 305), 
			_campaign_map_point(1172, 304), _campaign_map_point(1172, 303), _campaign_map_point(1172, 302), 
			_campaign_map_point(1172, 301), _campaign_map_point(1172, 300), _campaign_map_point(1172, 299), 
			_campaign_map_point(1172, 298), _campaign_map_point(1172, 297), _campaign_map_point(1172, 296), 
			_campaign_map_point(1172, 295), _campaign_map_point(1172, 294), _campaign_map_point(1172, 293), 
			_campaign_map_point(1172, 292), _campaign_map_point(1172, 291), _campaign_map_point(1172, 290), 
			_campaign_map_point(1172, 289), _campaign_map_point(1172, 288), _campaign_map_point(1172, 287), 
			_campaign_map_point(1172, 286), _campaign_map_point(1172, 285), _campaign_map_point(1172, 284), 
			_campaign_map_point(1172, 283), _campaign_map_point(1172, 282), _campaign_map_point(1172, 281), 
			_campaign_map_point(1172, 280), _campaign_map_point(1172, 279), _campaign_map_point(1172, 278), 
			_campaign_map_point(1172, 277), _campaign_map_point(1172, 276), _campaign_map_point(1172, 275), 
			_campaign_map_point(1172, 274), _campaign_map_point(1172, 273), _campaign_map_point(1172, 272), 
			_campaign_map_point(1172, 271), _campaign_map_point(1172, 270), _campaign_map_point(1172, 269), 
			_campaign_map_point(1172, 268), _campaign_map_point(1172, 267), _campaign_map_point(1172, 266), 
			_campaign_map_point(1172, 265), _campaign_map_point(1172, 264), _campaign_map_point(1172, 263), 
			_campaign_map_point(1172, 262), _campaign_map_point(1172, 261), _campaign_map_point(1172, 260), 
			_campaign_map_point(1172, 259), _campaign_map_point(1172, 258), _campaign_map_point(1172, 257), 
			_campaign_map_point(1172, 256), _campaign_map_point(1171, 255), _campaign_map_point(1170, 254), 
			_campaign_map_point(1167, 253), _campaign_map_point(1167, 252), _campaign_map_point(1167, 251), 
			_campaign_map_point(1167, 250), _campaign_map_point(1167, 249), _campaign_map_point(1167, 248), 
			_campaign_map_point(1167, 247), _campaign_map_point(1167, 246), _campaign_map_point(1167, 245), 
			_campaign_map_point(1167, 244), _campaign_map_point(1167, 243), _campaign_map_point(1168, 242), 
			_campaign_map_point(1168, 241), _campaign_map_point(1168, 240), _campaign_map_point(1168, 239), 
			_campaign_map_point(1168, 238), _campaign_map_point(1167, 237), _campaign_map_point(1167, 236), 
			_campaign_map_point(1167, 235), _campaign_map_point(1167, 234), _campaign_map_point(1167, 233), 
			_campaign_map_point(1167, 232), _campaign_map_point(1167, 231), _campaign_map_point(1166, 230), 
			_campaign_map_point(1166, 229), _campaign_map_point(1166, 228), _campaign_map_point(1166, 227), 
			_campaign_map_point(1166, 226), _campaign_map_point(1165, 225), _campaign_map_point(1165, 224), 
			_campaign_map_point(1165, 223), _campaign_map_point(1164, 222), _campaign_map_point(1164, 221), 
			_campaign_map_point(1164, 220), _campaign_map_point(1164, 219), _campaign_map_point(1163, 218), 
			_campaign_map_point(1163, 217), _campaign_map_point(1162, 216), _campaign_map_point(1162, 215), 
			_campaign_map_point(1161, 214), _campaign_map_point(1161, 213), _campaign_map_point(1161, 212), 
			_campaign_map_point(1160, 211), _campaign_map_point(1160, 210), _campaign_map_point(1160, 209), 
			_campaign_map_point(1159, 208), _campaign_map_point(1159, 207), _campaign_map_point(1158, 206), 
			_campaign_map_point(1158, 205), _campaign_map_point(1157, 204), _campaign_map_point(1157, 203), 
			_campaign_map_point(1156, 202), _campaign_map_point(1156, 201), _campaign_map_point(1156, 200), 
			_campaign_map_point(1155, 199), _campaign_map_point(1155, 198), _campaign_map_point(1154, 197), 
			_campaign_map_point(1154, 196), _campaign_map_point(1154, 195), _campaign_map_point(1153, 194), 
			_campaign_map_point(1153, 193), _campaign_map_point(1152, 192), _campaign_map_point(1152, 191), 
			_campaign_map_point(1151, 190), _campaign_map_point(1151, 189), _campaign_map_point(1150, 188), 
			_campaign_map_point(1149, 187), _campaign_map_point(1149, 186), _campaign_map_point(1148, 185), 
			_campaign_map_point(1147, 184), _campaign_map_point(1147, 183), _campaign_map_point(1146, 182), 
			_campaign_map_point(1146, 181), _campaign_map_point(1145, 180), _campaign_map_point(1141, 179), 
			_campaign_map_point(1141, 178), _campaign_map_point(1140, 177), _campaign_map_point(1139, 176), 
			_campaign_map_point(1138, 175), _campaign_map_point(1138, 174), _campaign_map_point(1137, 173), 
			_campaign_map_point(1136, 172), _campaign_map_point(1136, 171), _campaign_map_point(1136, 170), 
			_campaign_map_point(1136, 169), _campaign_map_point(1133, 168), _campaign_map_point(1132, 167), 
			_campaign_map_point(1132, 166), _campaign_map_point(1131, 165), _campaign_map_point(1130, 164), 
			_campaign_map_point(1130, 163), _campaign_map_point(1130, 162), _campaign_map_point(1127, 161), 
			_campaign_map_point(1126, 160), _campaign_map_point(1126, 159), _campaign_map_point(1126, 158), 
			_campaign_map_point(1126, 157), _campaign_map_point(1126, 156), _campaign_map_point(1125, 155), 
			_campaign_map_point(1125, 154), _campaign_map_point(1124, 153), _campaign_map_point(1123, 152), 
			_campaign_map_point(1122, 151), _campaign_map_point(1121, 150), _campaign_map_point(1120, 149), 
			_campaign_map_point(1119, 148), _campaign_map_point(1118, 147), _campaign_map_point(1117, 146), 
			_campaign_map_point(1116, 145), _campaign_map_point(1114, 144), _campaign_map_point(1113, 143), 
			_campaign_map_point(1112, 142), _campaign_map_point(1111, 141), _campaign_map_point(1103, 140), 
			_campaign_map_point(1102, 139), _campaign_map_point(1100, 138), _campaign_map_point(1099, 137), 
			_campaign_map_point(1099, 136), _campaign_map_point(1099, 135), _campaign_map_point(1099, 134), 
			_campaign_map_point(1092, 133), _campaign_map_point(1090, 132), _campaign_map_point(1089, 131), 
			_campaign_map_point(1089, 130), _campaign_map_point(1089, 129)
		]},
		{"section": "Залы декораций", "mask": "res://Background/Campaign_Hover_decoration_halls.png", "points": [
			_campaign_map_point(1309, 112), _campaign_map_point(1307, 113), _campaign_map_point(1306, 114), 
			_campaign_map_point(1305, 115), _campaign_map_point(1303, 116), _campaign_map_point(1302, 117), 
			_campaign_map_point(1300, 118), _campaign_map_point(1299, 119), _campaign_map_point(1298, 120), 
			_campaign_map_point(1297, 121), _campaign_map_point(1295, 122), _campaign_map_point(1294, 123), 
			_campaign_map_point(1293, 124), _campaign_map_point(1291, 125), _campaign_map_point(1290, 126), 
			_campaign_map_point(1289, 127), _campaign_map_point(1288, 128), _campaign_map_point(1287, 129), 
			_campaign_map_point(1286, 130), _campaign_map_point(1285, 131), _campaign_map_point(1284, 132), 
			_campaign_map_point(1282, 133), _campaign_map_point(1281, 134), _campaign_map_point(1280, 135), 
			_campaign_map_point(1279, 136), _campaign_map_point(1278, 137), _campaign_map_point(1277, 138), 
			_campaign_map_point(1276, 139), _campaign_map_point(1275, 140), _campaign_map_point(1274, 141), 
			_campaign_map_point(1272, 142), _campaign_map_point(1272, 143), _campaign_map_point(1271, 144), 
			_campaign_map_point(1270, 145), _campaign_map_point(1268, 146), _campaign_map_point(1268, 147), 
			_campaign_map_point(1267, 148), _campaign_map_point(1266, 149), _campaign_map_point(1265, 150), 
			_campaign_map_point(1264, 151), _campaign_map_point(1263, 152), _campaign_map_point(1261, 153), 
			_campaign_map_point(1260, 154), _campaign_map_point(1260, 155), _campaign_map_point(1259, 156), 
			_campaign_map_point(1258, 157), _campaign_map_point(1257, 158), _campaign_map_point(1256, 159), 
			_campaign_map_point(1255, 160), _campaign_map_point(1254, 161), _campaign_map_point(1253, 162), 
			_campaign_map_point(1253, 163), _campaign_map_point(1252, 164), _campaign_map_point(1251, 165), 
			_campaign_map_point(1250, 166), _campaign_map_point(1250, 167), _campaign_map_point(1249, 168), 
			_campaign_map_point(1248, 169), _campaign_map_point(1247, 170), _campaign_map_point(1247, 171), 
			_campaign_map_point(1246, 172), _campaign_map_point(1245, 173), _campaign_map_point(1244, 174), 
			_campaign_map_point(1243, 175), _campaign_map_point(1243, 176), _campaign_map_point(1242, 177), 
			_campaign_map_point(1241, 178), _campaign_map_point(1240, 179), _campaign_map_point(1239, 180), 
			_campaign_map_point(1239, 181), _campaign_map_point(1238, 182), _campaign_map_point(1237, 183), 
			_campaign_map_point(1236, 184), _campaign_map_point(1236, 185), _campaign_map_point(1235, 186), 
			_campaign_map_point(1234, 187), _campaign_map_point(1233, 188), _campaign_map_point(1233, 189), 
			_campaign_map_point(1232, 190), _campaign_map_point(1232, 191), _campaign_map_point(1231, 192), 
			_campaign_map_point(1230, 193), _campaign_map_point(1230, 194), _campaign_map_point(1229, 195), 
			_campaign_map_point(1228, 196), _campaign_map_point(1228, 197), _campaign_map_point(1227, 198), 
			_campaign_map_point(1227, 199), _campaign_map_point(1226, 200), _campaign_map_point(1225, 201), 
			_campaign_map_point(1225, 202), _campaign_map_point(1224, 203), _campaign_map_point(1224, 204), 
			_campaign_map_point(1223, 205), _campaign_map_point(1223, 206), _campaign_map_point(1222, 207), 
			_campaign_map_point(1222, 208), _campaign_map_point(1221, 209), _campaign_map_point(1221, 210), 
			_campaign_map_point(1220, 211), _campaign_map_point(1219, 212), _campaign_map_point(1219, 213), 
			_campaign_map_point(1218, 214), _campaign_map_point(1218, 215), _campaign_map_point(1217, 216), 
			_campaign_map_point(1217, 217), _campaign_map_point(1216, 218), _campaign_map_point(1216, 219), 
			_campaign_map_point(1215, 220), _campaign_map_point(1215, 221), _campaign_map_point(1215, 222), 
			_campaign_map_point(1214, 223), _campaign_map_point(1214, 224), _campaign_map_point(1213, 225), 
			_campaign_map_point(1213, 226), _campaign_map_point(1212, 227), _campaign_map_point(1212, 228), 
			_campaign_map_point(1212, 229), _campaign_map_point(1211, 230), _campaign_map_point(1211, 231), 
			_campaign_map_point(1210, 232), _campaign_map_point(1210, 233), _campaign_map_point(1210, 234), 
			_campaign_map_point(1209, 235), _campaign_map_point(1209, 236), _campaign_map_point(1209, 237), 
			_campaign_map_point(1209, 238), _campaign_map_point(1209, 239), _campaign_map_point(1209, 240), 
			_campaign_map_point(1208, 241), _campaign_map_point(1208, 242), _campaign_map_point(1208, 243), 
			_campaign_map_point(1208, 244), _campaign_map_point(1208, 245), _campaign_map_point(1208, 246), 
			_campaign_map_point(1208, 247), _campaign_map_point(1208, 248), _campaign_map_point(1208, 249), 
			_campaign_map_point(1208, 250), _campaign_map_point(1208, 251), _campaign_map_point(1208, 252), 
			_campaign_map_point(1208, 253), _campaign_map_point(1208, 254), _campaign_map_point(1207, 255), 
			_campaign_map_point(1200, 256), _campaign_map_point(1200, 257), _campaign_map_point(1200, 258), 
			_campaign_map_point(1200, 259), _campaign_map_point(1200, 260), _campaign_map_point(1200, 261), 
			_campaign_map_point(1200, 262), _campaign_map_point(1200, 263), _campaign_map_point(1200, 264), 
			_campaign_map_point(1200, 265), _campaign_map_point(1200, 266), _campaign_map_point(1200, 267), 
			_campaign_map_point(1200, 268), _campaign_map_point(1200, 269), _campaign_map_point(1200, 270), 
			_campaign_map_point(1200, 271), _campaign_map_point(1200, 272), _campaign_map_point(1200, 273), 
			_campaign_map_point(1201, 274), _campaign_map_point(1201, 275), _campaign_map_point(1201, 276), 
			_campaign_map_point(1201, 277), _campaign_map_point(1201, 278), _campaign_map_point(1201, 279), 
			_campaign_map_point(1201, 280), _campaign_map_point(1201, 281), _campaign_map_point(1201, 282), 
			_campaign_map_point(1201, 283), _campaign_map_point(1201, 284), _campaign_map_point(1201, 285), 
			_campaign_map_point(1201, 286), _campaign_map_point(1201, 287), _campaign_map_point(1201, 288), 
			_campaign_map_point(1200, 289), _campaign_map_point(1200, 290), _campaign_map_point(1200, 291), 
			_campaign_map_point(1200, 292), _campaign_map_point(1200, 293), _campaign_map_point(1200, 294), 
			_campaign_map_point(1200, 295), _campaign_map_point(1200, 296), _campaign_map_point(1200, 297), 
			_campaign_map_point(1200, 298), _campaign_map_point(1200, 299), _campaign_map_point(1200, 300), 
			_campaign_map_point(1200, 301), _campaign_map_point(1200, 302), _campaign_map_point(1200, 303), 
			_campaign_map_point(1200, 304), _campaign_map_point(1200, 305), _campaign_map_point(1200, 306), 
			_campaign_map_point(1200, 307), _campaign_map_point(1200, 308), _campaign_map_point(1200, 309), 
			_campaign_map_point(1200, 310), _campaign_map_point(1200, 311), _campaign_map_point(1200, 312), 
			_campaign_map_point(1200, 313), _campaign_map_point(1200, 314), _campaign_map_point(1200, 315), 
			_campaign_map_point(1200, 316), _campaign_map_point(1200, 317), _campaign_map_point(1200, 318), 
			_campaign_map_point(1200, 319), _campaign_map_point(1200, 320), _campaign_map_point(1200, 321), 
			_campaign_map_point(1200, 322), _campaign_map_point(1200, 323), _campaign_map_point(1200, 324), 
			_campaign_map_point(1200, 325), _campaign_map_point(1200, 326), _campaign_map_point(1200, 327), 
			_campaign_map_point(1200, 328), _campaign_map_point(1200, 329), _campaign_map_point(1200, 330), 
			_campaign_map_point(1200, 331), _campaign_map_point(1201, 332), _campaign_map_point(1201, 333), 
			_campaign_map_point(1201, 334), _campaign_map_point(1201, 335), _campaign_map_point(1201, 336), 
			_campaign_map_point(1201, 337), _campaign_map_point(1201, 338), _campaign_map_point(1201, 339), 
			_campaign_map_point(1201, 340), _campaign_map_point(1201, 341), _campaign_map_point(1201, 342), 
			_campaign_map_point(1201, 343), _campaign_map_point(1201, 344), _campaign_map_point(1201, 345), 
			_campaign_map_point(1201, 346), _campaign_map_point(1201, 347), _campaign_map_point(1201, 348), 
			_campaign_map_point(1201, 349), _campaign_map_point(1201, 350), _campaign_map_point(1201, 351), 
			_campaign_map_point(1201, 352), _campaign_map_point(1201, 353), _campaign_map_point(1201, 354), 
			_campaign_map_point(1201, 355), _campaign_map_point(1201, 356), _campaign_map_point(1201, 357), 
			_campaign_map_point(1201, 358), _campaign_map_point(1201, 359), _campaign_map_point(1201, 360), 
			_campaign_map_point(1201, 361), _campaign_map_point(1201, 362), _campaign_map_point(1200, 363), 
			_campaign_map_point(1200, 364), _campaign_map_point(1200, 365), _campaign_map_point(1200, 366), 
			_campaign_map_point(1200, 367), _campaign_map_point(1200, 368), _campaign_map_point(1200, 369), 
			_campaign_map_point(1200, 370), _campaign_map_point(1200, 371), _campaign_map_point(1200, 372), 
			_campaign_map_point(1200, 373), _campaign_map_point(1200, 374), _campaign_map_point(1200, 375), 
			_campaign_map_point(1200, 376), _campaign_map_point(1200, 377), _campaign_map_point(1200, 378), 
			_campaign_map_point(1200, 379), _campaign_map_point(1200, 380), _campaign_map_point(1200, 381), 
			_campaign_map_point(1200, 382), _campaign_map_point(1200, 383), _campaign_map_point(1200, 384), 
			_campaign_map_point(1200, 385), _campaign_map_point(1200, 386), _campaign_map_point(1200, 387), 
			_campaign_map_point(1200, 388), _campaign_map_point(1200, 389), _campaign_map_point(1200, 390), 
			_campaign_map_point(1200, 391), _campaign_map_point(1200, 392), _campaign_map_point(1200, 393), 
			_campaign_map_point(1200, 394), _campaign_map_point(1200, 395), _campaign_map_point(1200, 396), 
			_campaign_map_point(1200, 397), _campaign_map_point(1200, 398), _campaign_map_point(1200, 399), 
			_campaign_map_point(1200, 400), _campaign_map_point(1200, 401), _campaign_map_point(1200, 402), 
			_campaign_map_point(1200, 403), _campaign_map_point(1200, 404), _campaign_map_point(1200, 405), 
			_campaign_map_point(1200, 406), _campaign_map_point(1200, 407), _campaign_map_point(1200, 408), 
			_campaign_map_point(1200, 409), _campaign_map_point(1200, 410), _campaign_map_point(1200, 411), 
			_campaign_map_point(1200, 412), _campaign_map_point(1200, 413), _campaign_map_point(1200, 414), 
			_campaign_map_point(1200, 415), _campaign_map_point(1200, 416), _campaign_map_point(1200, 417), 
			_campaign_map_point(1200, 418), _campaign_map_point(1200, 419), _campaign_map_point(1200, 420), 
			_campaign_map_point(1200, 421), _campaign_map_point(1200, 422), _campaign_map_point(1200, 423), 
			_campaign_map_point(1200, 424), _campaign_map_point(1200, 425), _campaign_map_point(1200, 426), 
			_campaign_map_point(1200, 427), _campaign_map_point(1200, 428), _campaign_map_point(1200, 429), 
			_campaign_map_point(1200, 430), _campaign_map_point(1200, 431), _campaign_map_point(1200, 432), 
			_campaign_map_point(1200, 433), _campaign_map_point(1200, 434), _campaign_map_point(1200, 435), 
			_campaign_map_point(1200, 436), _campaign_map_point(1200, 437), _campaign_map_point(1200, 438), 
			_campaign_map_point(1200, 439), _campaign_map_point(1200, 440), _campaign_map_point(1200, 441), 
			_campaign_map_point(1200, 442), _campaign_map_point(1200, 443), _campaign_map_point(1200, 444), 
			_campaign_map_point(1200, 445), _campaign_map_point(1200, 446), _campaign_map_point(1200, 447), 
			_campaign_map_point(1200, 448), _campaign_map_point(1200, 449), _campaign_map_point(1200, 450), 
			_campaign_map_point(1200, 451), _campaign_map_point(1200, 452), _campaign_map_point(1200, 453), 
			_campaign_map_point(1200, 454), _campaign_map_point(1200, 455), _campaign_map_point(1200, 456), 
			_campaign_map_point(1200, 457), _campaign_map_point(1200, 458), _campaign_map_point(1200, 459), 
			_campaign_map_point(1200, 460), _campaign_map_point(1200, 461), _campaign_map_point(1200, 462), 
			_campaign_map_point(1200, 463), _campaign_map_point(1200, 464), _campaign_map_point(1200, 465), 
			_campaign_map_point(1200, 466), _campaign_map_point(1200, 467), _campaign_map_point(1200, 468), 
			_campaign_map_point(1200, 469), _campaign_map_point(1200, 470), _campaign_map_point(1200, 471), 
			_campaign_map_point(1200, 472), _campaign_map_point(1200, 473), _campaign_map_point(1200, 474), 
			_campaign_map_point(1200, 475), _campaign_map_point(1200, 476), _campaign_map_point(1200, 477), 
			_campaign_map_point(1200, 478), _campaign_map_point(1200, 479), _campaign_map_point(1200, 480), 
			_campaign_map_point(1200, 481), _campaign_map_point(1200, 482), _campaign_map_point(1200, 483), 
			_campaign_map_point(1200, 484), _campaign_map_point(1200, 485), _campaign_map_point(1200, 486), 
			_campaign_map_point(1200, 487), _campaign_map_point(1200, 488), _campaign_map_point(1200, 489), 
			_campaign_map_point(1200, 490), _campaign_map_point(1200, 491), _campaign_map_point(1200, 492), 
			_campaign_map_point(1200, 493), _campaign_map_point(1200, 494), _campaign_map_point(1200, 495), 
			_campaign_map_point(1200, 496), _campaign_map_point(1200, 497), _campaign_map_point(1200, 498), 
			_campaign_map_point(1200, 499), _campaign_map_point(1200, 500), _campaign_map_point(1200, 501), 
			_campaign_map_point(1200, 502), _campaign_map_point(1200, 503), _campaign_map_point(1200, 504), 
			_campaign_map_point(1200, 505), _campaign_map_point(1200, 506), _campaign_map_point(1200, 507), 
			_campaign_map_point(1200, 508), _campaign_map_point(1200, 509), _campaign_map_point(1200, 510), 
			_campaign_map_point(1200, 511), _campaign_map_point(1200, 512), _campaign_map_point(1200, 513), 
			_campaign_map_point(1200, 514), _campaign_map_point(1200, 515), _campaign_map_point(1200, 516), 
			_campaign_map_point(1200, 517), _campaign_map_point(1200, 518), _campaign_map_point(1200, 519), 
			_campaign_map_point(1200, 520), _campaign_map_point(1200, 521), _campaign_map_point(1200, 522), 
			_campaign_map_point(1200, 523), _campaign_map_point(1200, 524), _campaign_map_point(1200, 525), 
			_campaign_map_point(1200, 526), _campaign_map_point(1200, 527), _campaign_map_point(1200, 528), 
			_campaign_map_point(1200, 529), _campaign_map_point(1200, 530), _campaign_map_point(1200, 531), 
			_campaign_map_point(1200, 532), _campaign_map_point(1200, 533), _campaign_map_point(1200, 534), 
			_campaign_map_point(1200, 535), _campaign_map_point(1200, 536), _campaign_map_point(1200, 537), 
			_campaign_map_point(1200, 538), _campaign_map_point(1200, 539), _campaign_map_point(1200, 540), 
			_campaign_map_point(1200, 541), _campaign_map_point(1200, 542), _campaign_map_point(1200, 543), 
			_campaign_map_point(1200, 544), _campaign_map_point(1200, 545), _campaign_map_point(1200, 546), 
			_campaign_map_point(1200, 547), _campaign_map_point(1200, 548), _campaign_map_point(1200, 549), 
			_campaign_map_point(1200, 550), _campaign_map_point(1200, 551), _campaign_map_point(1200, 552), 
			_campaign_map_point(1200, 553), _campaign_map_point(1200, 554), _campaign_map_point(1200, 555), 
			_campaign_map_point(1200, 556), _campaign_map_point(1200, 557), _campaign_map_point(1200, 558), 
			_campaign_map_point(1200, 559), _campaign_map_point(1200, 560), _campaign_map_point(1200, 561), 
			_campaign_map_point(1200, 562), _campaign_map_point(1200, 563), _campaign_map_point(1200, 564), 
			_campaign_map_point(1200, 565), _campaign_map_point(1200, 566), _campaign_map_point(1200, 567), 
			_campaign_map_point(1200, 568), _campaign_map_point(1200, 569), _campaign_map_point(1200, 570), 
			_campaign_map_point(1200, 571), _campaign_map_point(1200, 572), _campaign_map_point(1200, 573), 
			_campaign_map_point(1200, 574), _campaign_map_point(1200, 575), _campaign_map_point(1200, 576), 
			_campaign_map_point(1200, 577), _campaign_map_point(1200, 578), _campaign_map_point(1200, 579), 
			_campaign_map_point(1200, 580), _campaign_map_point(1200, 581), _campaign_map_point(1200, 582), 
			_campaign_map_point(1200, 583), _campaign_map_point(1200, 584), _campaign_map_point(1200, 585), 
			_campaign_map_point(1200, 586), _campaign_map_point(1200, 587), _campaign_map_point(1200, 588), 
			_campaign_map_point(1200, 589), _campaign_map_point(1200, 590), _campaign_map_point(1200, 591), 
			_campaign_map_point(1200, 592), _campaign_map_point(1200, 593), _campaign_map_point(1200, 594), 
			_campaign_map_point(1200, 595), _campaign_map_point(1200, 596), _campaign_map_point(1200, 597), 
			_campaign_map_point(1200, 598), _campaign_map_point(1200, 599), _campaign_map_point(1200, 600), 
			_campaign_map_point(1200, 601), _campaign_map_point(1200, 602), _campaign_map_point(1200, 603), 
			_campaign_map_point(1200, 604), _campaign_map_point(1200, 605), _campaign_map_point(1200, 606), 
			_campaign_map_point(1200, 607), _campaign_map_point(1200, 608), _campaign_map_point(1200, 609), 
			_campaign_map_point(1200, 610), _campaign_map_point(1200, 611), _campaign_map_point(1200, 612), 
			_campaign_map_point(1200, 613), _campaign_map_point(1200, 614), _campaign_map_point(1200, 615), 
			_campaign_map_point(1200, 616), _campaign_map_point(1200, 617), _campaign_map_point(1200, 618), 
			_campaign_map_point(1200, 619), _campaign_map_point(1200, 620), _campaign_map_point(1200, 621), 
			_campaign_map_point(1200, 622), _campaign_map_point(1200, 623), _campaign_map_point(1200, 624), 
			_campaign_map_point(1200, 625), _campaign_map_point(1200, 626), _campaign_map_point(1200, 627), 
			_campaign_map_point(1200, 628), _campaign_map_point(1200, 629), _campaign_map_point(1200, 630), 
			_campaign_map_point(1200, 631), _campaign_map_point(1200, 632), _campaign_map_point(1200, 633), 
			_campaign_map_point(1200, 634), _campaign_map_point(1200, 635), _campaign_map_point(1200, 636), 
			_campaign_map_point(1200, 637), _campaign_map_point(1200, 638), _campaign_map_point(1200, 639), 
			_campaign_map_point(1200, 640), _campaign_map_point(1200, 641), _campaign_map_point(1200, 642), 
			_campaign_map_point(1200, 643), _campaign_map_point(1200, 644), _campaign_map_point(1200, 645), 
			_campaign_map_point(1200, 646), _campaign_map_point(1200, 647), _campaign_map_point(1200, 648), 
			_campaign_map_point(1200, 649), _campaign_map_point(1200, 650), _campaign_map_point(1200, 651), 
			_campaign_map_point(1200, 652), _campaign_map_point(1200, 653), _campaign_map_point(1200, 654), 
			_campaign_map_point(1200, 655), _campaign_map_point(1200, 656), _campaign_map_point(1200, 657), 
			_campaign_map_point(1200, 658), _campaign_map_point(1200, 659), _campaign_map_point(1200, 660), 
			_campaign_map_point(1200, 661), _campaign_map_point(1200, 662), _campaign_map_point(1200, 663), 
			_campaign_map_point(1200, 664), _campaign_map_point(1200, 665), _campaign_map_point(1200, 666), 
			_campaign_map_point(1200, 667), _campaign_map_point(1200, 668), _campaign_map_point(1200, 669), 
			_campaign_map_point(1200, 670), _campaign_map_point(1200, 671), _campaign_map_point(1200, 672), 
			_campaign_map_point(1200, 673), _campaign_map_point(1200, 674), _campaign_map_point(1200, 675), 
			_campaign_map_point(1200, 676), _campaign_map_point(1200, 677), _campaign_map_point(1200, 678), 
			_campaign_map_point(1200, 679), _campaign_map_point(1200, 680), _campaign_map_point(1200, 681), 
			_campaign_map_point(1200, 682), _campaign_map_point(1200, 683), _campaign_map_point(1200, 684), 
			_campaign_map_point(1200, 685), _campaign_map_point(1200, 686), _campaign_map_point(1200, 687), 
			_campaign_map_point(1200, 688), _campaign_map_point(1200, 689), _campaign_map_point(1200, 690), 
			_campaign_map_point(1200, 691), _campaign_map_point(1200, 692), _campaign_map_point(1200, 693), 
			_campaign_map_point(1200, 694), _campaign_map_point(1200, 695), _campaign_map_point(1200, 696), 
			_campaign_map_point(1200, 697), _campaign_map_point(1200, 698), _campaign_map_point(1200, 699), 
			_campaign_map_point(1200, 700), _campaign_map_point(1200, 701), _campaign_map_point(1200, 702), 
			_campaign_map_point(1200, 703), _campaign_map_point(1200, 704), _campaign_map_point(1200, 705), 
			_campaign_map_point(1200, 706), _campaign_map_point(1200, 707), _campaign_map_point(1200, 708), 
			_campaign_map_point(1200, 709), _campaign_map_point(1200, 710), _campaign_map_point(1200, 711), 
			_campaign_map_point(1200, 712), _campaign_map_point(1200, 713), _campaign_map_point(1200, 714), 
			_campaign_map_point(1200, 715), _campaign_map_point(1200, 716), _campaign_map_point(1200, 717), 
			_campaign_map_point(1200, 718), _campaign_map_point(1200, 719), _campaign_map_point(1201, 720), 
			_campaign_map_point(1202, 721), _campaign_map_point(1203, 722), _campaign_map_point(1204, 723), 
			_campaign_map_point(1204, 724), _campaign_map_point(1205, 725), _campaign_map_point(1206, 726), 
			_campaign_map_point(1209, 727), _campaign_map_point(1218, 728), _campaign_map_point(1226, 729), 
			_campaign_map_point(1232, 730), _campaign_map_point(1240, 731), _campaign_map_point(1247, 732), 
			_campaign_map_point(1254, 733), _campaign_map_point(1261, 734), _campaign_map_point(1268, 735), 
			_campaign_map_point(1275, 736), _campaign_map_point(1284, 737), _campaign_map_point(1292, 738), 
			_campaign_map_point(1299, 739), _campaign_map_point(1308, 740), _campaign_map_point(1317, 741), 
			_campaign_map_point(1326, 742), _campaign_map_point(1334, 743), _campaign_map_point(1346, 744), 
			_campaign_map_point(1350, 745), _campaign_map_point(1356, 746), _campaign_map_point(1363, 747), 
			_campaign_map_point(1368, 748), _campaign_map_point(1379, 749), _campaign_map_point(1385, 750), 
			_campaign_map_point(1393, 751), _campaign_map_point(1403, 751), _campaign_map_point(1404, 750), 
			_campaign_map_point(1405, 749), _campaign_map_point(1406, 748), _campaign_map_point(1406, 747), 
			_campaign_map_point(1406, 746), _campaign_map_point(1406, 745), _campaign_map_point(1406, 744), 
			_campaign_map_point(1406, 743), _campaign_map_point(1406, 742), _campaign_map_point(1406, 741), 
			_campaign_map_point(1406, 740), _campaign_map_point(1406, 739), _campaign_map_point(1406, 738), 
			_campaign_map_point(1406, 737), _campaign_map_point(1406, 736), _campaign_map_point(1406, 735), 
			_campaign_map_point(1406, 734), _campaign_map_point(1406, 733), _campaign_map_point(1406, 732), 
			_campaign_map_point(1406, 731), _campaign_map_point(1406, 730), _campaign_map_point(1406, 729), 
			_campaign_map_point(1406, 728), _campaign_map_point(1406, 727), _campaign_map_point(1406, 726), 
			_campaign_map_point(1406, 725), _campaign_map_point(1406, 724), _campaign_map_point(1407, 723), 
			_campaign_map_point(1407, 722), _campaign_map_point(1407, 721), _campaign_map_point(1407, 720), 
			_campaign_map_point(1407, 719), _campaign_map_point(1407, 718), _campaign_map_point(1407, 717), 
			_campaign_map_point(1407, 716), _campaign_map_point(1407, 715), _campaign_map_point(1407, 714), 
			_campaign_map_point(1407, 713), _campaign_map_point(1408, 712), _campaign_map_point(1408, 711), 
			_campaign_map_point(1408, 710), _campaign_map_point(1408, 709), _campaign_map_point(1408, 708), 
			_campaign_map_point(1408, 707), _campaign_map_point(1408, 706), _campaign_map_point(1408, 705), 
			_campaign_map_point(1408, 704), _campaign_map_point(1408, 703), _campaign_map_point(1408, 702), 
			_campaign_map_point(1408, 701), _campaign_map_point(1408, 700), _campaign_map_point(1408, 699), 
			_campaign_map_point(1408, 698), _campaign_map_point(1408, 697), _campaign_map_point(1408, 696), 
			_campaign_map_point(1408, 695), _campaign_map_point(1408, 694), _campaign_map_point(1408, 693), 
			_campaign_map_point(1408, 692), _campaign_map_point(1408, 691), _campaign_map_point(1408, 690), 
			_campaign_map_point(1409, 689), _campaign_map_point(1409, 688), _campaign_map_point(1409, 687), 
			_campaign_map_point(1409, 686), _campaign_map_point(1409, 685), _campaign_map_point(1409, 684), 
			_campaign_map_point(1409, 683), _campaign_map_point(1409, 682), _campaign_map_point(1409, 681), 
			_campaign_map_point(1409, 680), _campaign_map_point(1409, 679), _campaign_map_point(1409, 678), 
			_campaign_map_point(1409, 677), _campaign_map_point(1409, 676), _campaign_map_point(1409, 675), 
			_campaign_map_point(1409, 674), _campaign_map_point(1409, 673), _campaign_map_point(1409, 672), 
			_campaign_map_point(1409, 671), _campaign_map_point(1409, 670), _campaign_map_point(1409, 669), 
			_campaign_map_point(1409, 668), _campaign_map_point(1409, 667), _campaign_map_point(1409, 666), 
			_campaign_map_point(1409, 665), _campaign_map_point(1409, 664), _campaign_map_point(1409, 663), 
			_campaign_map_point(1409, 662), _campaign_map_point(1409, 661), _campaign_map_point(1409, 660), 
			_campaign_map_point(1409, 659), _campaign_map_point(1409, 658), _campaign_map_point(1409, 657), 
			_campaign_map_point(1409, 656), _campaign_map_point(1409, 655), _campaign_map_point(1409, 654), 
			_campaign_map_point(1409, 653), _campaign_map_point(1408, 652), _campaign_map_point(1408, 651), 
			_campaign_map_point(1408, 650), _campaign_map_point(1408, 649), _campaign_map_point(1408, 648), 
			_campaign_map_point(1408, 647), _campaign_map_point(1408, 646), _campaign_map_point(1408, 645), 
			_campaign_map_point(1408, 644), _campaign_map_point(1408, 643), _campaign_map_point(1408, 642), 
			_campaign_map_point(1409, 641), _campaign_map_point(1409, 640), _campaign_map_point(1409, 639), 
			_campaign_map_point(1409, 638), _campaign_map_point(1409, 637), _campaign_map_point(1409, 636), 
			_campaign_map_point(1409, 635), _campaign_map_point(1409, 634), _campaign_map_point(1409, 633), 
			_campaign_map_point(1409, 632), _campaign_map_point(1409, 631), _campaign_map_point(1409, 630), 
			_campaign_map_point(1409, 629), _campaign_map_point(1409, 628), _campaign_map_point(1409, 627), 
			_campaign_map_point(1409, 626), _campaign_map_point(1409, 625), _campaign_map_point(1409, 624), 
			_campaign_map_point(1409, 623), _campaign_map_point(1409, 622), _campaign_map_point(1409, 621), 
			_campaign_map_point(1409, 620), _campaign_map_point(1409, 619), _campaign_map_point(1409, 618), 
			_campaign_map_point(1409, 617), _campaign_map_point(1409, 616), _campaign_map_point(1409, 615), 
			_campaign_map_point(1409, 614), _campaign_map_point(1409, 613), _campaign_map_point(1409, 612), 
			_campaign_map_point(1409, 611), _campaign_map_point(1409, 610), _campaign_map_point(1409, 609), 
			_campaign_map_point(1409, 608), _campaign_map_point(1409, 607), _campaign_map_point(1409, 606), 
			_campaign_map_point(1409, 605), _campaign_map_point(1409, 604), _campaign_map_point(1409, 603), 
			_campaign_map_point(1409, 602), _campaign_map_point(1409, 601), _campaign_map_point(1409, 600), 
			_campaign_map_point(1409, 599), _campaign_map_point(1409, 598), _campaign_map_point(1409, 597), 
			_campaign_map_point(1409, 596), _campaign_map_point(1408, 595), _campaign_map_point(1408, 594), 
			_campaign_map_point(1408, 593), _campaign_map_point(1408, 592), _campaign_map_point(1408, 591), 
			_campaign_map_point(1408, 590), _campaign_map_point(1408, 589), _campaign_map_point(1408, 588), 
			_campaign_map_point(1408, 587), _campaign_map_point(1408, 586), _campaign_map_point(1408, 585), 
			_campaign_map_point(1408, 584), _campaign_map_point(1408, 583), _campaign_map_point(1408, 582), 
			_campaign_map_point(1408, 581), _campaign_map_point(1408, 580), _campaign_map_point(1408, 579), 
			_campaign_map_point(1408, 578), _campaign_map_point(1408, 577), _campaign_map_point(1408, 576), 
			_campaign_map_point(1408, 575), _campaign_map_point(1408, 574), _campaign_map_point(1408, 573), 
			_campaign_map_point(1408, 572), _campaign_map_point(1409, 571), _campaign_map_point(1409, 570), 
			_campaign_map_point(1409, 569), _campaign_map_point(1409, 568), _campaign_map_point(1409, 567), 
			_campaign_map_point(1409, 566), _campaign_map_point(1409, 565), _campaign_map_point(1409, 564), 
			_campaign_map_point(1409, 563), _campaign_map_point(1409, 562), _campaign_map_point(1409, 561), 
			_campaign_map_point(1409, 560), _campaign_map_point(1409, 559), _campaign_map_point(1409, 558), 
			_campaign_map_point(1409, 557), _campaign_map_point(1409, 556), _campaign_map_point(1409, 555), 
			_campaign_map_point(1409, 554), _campaign_map_point(1409, 553), _campaign_map_point(1409, 552), 
			_campaign_map_point(1409, 551), _campaign_map_point(1409, 550), _campaign_map_point(1409, 549), 
			_campaign_map_point(1409, 548), _campaign_map_point(1409, 547), _campaign_map_point(1409, 546), 
			_campaign_map_point(1409, 545), _campaign_map_point(1409, 544), _campaign_map_point(1409, 543), 
			_campaign_map_point(1409, 542), _campaign_map_point(1409, 541), _campaign_map_point(1409, 540), 
			_campaign_map_point(1409, 539), _campaign_map_point(1409, 538), _campaign_map_point(1409, 537), 
			_campaign_map_point(1409, 536), _campaign_map_point(1409, 535), _campaign_map_point(1409, 534), 
			_campaign_map_point(1409, 533), _campaign_map_point(1409, 532), _campaign_map_point(1409, 531), 
			_campaign_map_point(1409, 530), _campaign_map_point(1409, 529), _campaign_map_point(1409, 528), 
			_campaign_map_point(1409, 527), _campaign_map_point(1409, 526), _campaign_map_point(1409, 525), 
			_campaign_map_point(1409, 524), _campaign_map_point(1409, 523), _campaign_map_point(1409, 522), 
			_campaign_map_point(1409, 521), _campaign_map_point(1409, 520), _campaign_map_point(1409, 519), 
			_campaign_map_point(1409, 518), _campaign_map_point(1409, 517), _campaign_map_point(1409, 516), 
			_campaign_map_point(1409, 515), _campaign_map_point(1409, 514), _campaign_map_point(1409, 513), 
			_campaign_map_point(1409, 512), _campaign_map_point(1409, 511), _campaign_map_point(1409, 510), 
			_campaign_map_point(1409, 509), _campaign_map_point(1409, 508), _campaign_map_point(1409, 507), 
			_campaign_map_point(1409, 506), _campaign_map_point(1409, 505), _campaign_map_point(1409, 504), 
			_campaign_map_point(1409, 503), _campaign_map_point(1409, 502), _campaign_map_point(1409, 501), 
			_campaign_map_point(1409, 500), _campaign_map_point(1409, 499), _campaign_map_point(1409, 498), 
			_campaign_map_point(1409, 497), _campaign_map_point(1409, 496), _campaign_map_point(1409, 495), 
			_campaign_map_point(1409, 494), _campaign_map_point(1409, 493), _campaign_map_point(1409, 492), 
			_campaign_map_point(1409, 491), _campaign_map_point(1409, 490), _campaign_map_point(1409, 489), 
			_campaign_map_point(1409, 488), _campaign_map_point(1409, 487), _campaign_map_point(1409, 486), 
			_campaign_map_point(1409, 485), _campaign_map_point(1409, 484), _campaign_map_point(1409, 483), 
			_campaign_map_point(1409, 482), _campaign_map_point(1409, 481), _campaign_map_point(1409, 480), 
			_campaign_map_point(1409, 479), _campaign_map_point(1409, 478), _campaign_map_point(1409, 477), 
			_campaign_map_point(1409, 476), _campaign_map_point(1409, 475), _campaign_map_point(1409, 474), 
			_campaign_map_point(1409, 473), _campaign_map_point(1409, 472), _campaign_map_point(1409, 471), 
			_campaign_map_point(1409, 470), _campaign_map_point(1409, 469), _campaign_map_point(1409, 468), 
			_campaign_map_point(1409, 467), _campaign_map_point(1409, 466), _campaign_map_point(1409, 465), 
			_campaign_map_point(1409, 464), _campaign_map_point(1409, 463), _campaign_map_point(1409, 462), 
			_campaign_map_point(1409, 461), _campaign_map_point(1409, 460), _campaign_map_point(1409, 459), 
			_campaign_map_point(1409, 458), _campaign_map_point(1409, 457), _campaign_map_point(1409, 456), 
			_campaign_map_point(1409, 455), _campaign_map_point(1409, 454), _campaign_map_point(1409, 453), 
			_campaign_map_point(1409, 452), _campaign_map_point(1409, 451), _campaign_map_point(1409, 450), 
			_campaign_map_point(1409, 449), _campaign_map_point(1409, 448), _campaign_map_point(1409, 447), 
			_campaign_map_point(1409, 446), _campaign_map_point(1409, 445), _campaign_map_point(1409, 444), 
			_campaign_map_point(1409, 443), _campaign_map_point(1409, 442), _campaign_map_point(1409, 441), 
			_campaign_map_point(1409, 440), _campaign_map_point(1409, 439), _campaign_map_point(1409, 438), 
			_campaign_map_point(1409, 437), _campaign_map_point(1409, 436), _campaign_map_point(1409, 435), 
			_campaign_map_point(1409, 434), _campaign_map_point(1409, 433), _campaign_map_point(1409, 432), 
			_campaign_map_point(1409, 431), _campaign_map_point(1409, 430), _campaign_map_point(1409, 429), 
			_campaign_map_point(1409, 428), _campaign_map_point(1409, 427), _campaign_map_point(1409, 426), 
			_campaign_map_point(1409, 425), _campaign_map_point(1409, 424), _campaign_map_point(1409, 423), 
			_campaign_map_point(1409, 422), _campaign_map_point(1409, 421), _campaign_map_point(1409, 420), 
			_campaign_map_point(1409, 419), _campaign_map_point(1409, 418), _campaign_map_point(1409, 417), 
			_campaign_map_point(1409, 416), _campaign_map_point(1409, 415), _campaign_map_point(1409, 414), 
			_campaign_map_point(1409, 413), _campaign_map_point(1409, 412), _campaign_map_point(1409, 411), 
			_campaign_map_point(1409, 410), _campaign_map_point(1409, 409), _campaign_map_point(1409, 408), 
			_campaign_map_point(1409, 407), _campaign_map_point(1409, 406), _campaign_map_point(1409, 405), 
			_campaign_map_point(1409, 404), _campaign_map_point(1409, 403), _campaign_map_point(1409, 402), 
			_campaign_map_point(1409, 401), _campaign_map_point(1409, 400), _campaign_map_point(1409, 399), 
			_campaign_map_point(1409, 398), _campaign_map_point(1409, 397), _campaign_map_point(1409, 396), 
			_campaign_map_point(1409, 395), _campaign_map_point(1409, 394), _campaign_map_point(1409, 393), 
			_campaign_map_point(1409, 392), _campaign_map_point(1409, 391), _campaign_map_point(1409, 390), 
			_campaign_map_point(1409, 389), _campaign_map_point(1409, 388), _campaign_map_point(1409, 387), 
			_campaign_map_point(1409, 386), _campaign_map_point(1409, 385), _campaign_map_point(1409, 384), 
			_campaign_map_point(1409, 383), _campaign_map_point(1409, 382), _campaign_map_point(1409, 381), 
			_campaign_map_point(1409, 380), _campaign_map_point(1409, 379), _campaign_map_point(1409, 378), 
			_campaign_map_point(1409, 377), _campaign_map_point(1409, 376), _campaign_map_point(1409, 375), 
			_campaign_map_point(1409, 374), _campaign_map_point(1409, 373), _campaign_map_point(1409, 372), 
			_campaign_map_point(1409, 371), _campaign_map_point(1409, 370), _campaign_map_point(1409, 369), 
			_campaign_map_point(1409, 368), _campaign_map_point(1409, 367), _campaign_map_point(1409, 366), 
			_campaign_map_point(1409, 365), _campaign_map_point(1409, 364), _campaign_map_point(1409, 363), 
			_campaign_map_point(1409, 362), _campaign_map_point(1409, 361), _campaign_map_point(1409, 360), 
			_campaign_map_point(1409, 359), _campaign_map_point(1409, 358), _campaign_map_point(1409, 357), 
			_campaign_map_point(1409, 356), _campaign_map_point(1409, 355), _campaign_map_point(1409, 354), 
			_campaign_map_point(1409, 353), _campaign_map_point(1409, 352), _campaign_map_point(1409, 351), 
			_campaign_map_point(1409, 350), _campaign_map_point(1409, 349), _campaign_map_point(1409, 348), 
			_campaign_map_point(1409, 347), _campaign_map_point(1409, 346), _campaign_map_point(1409, 345), 
			_campaign_map_point(1409, 344), _campaign_map_point(1409, 343), _campaign_map_point(1409, 342), 
			_campaign_map_point(1409, 341), _campaign_map_point(1409, 340), _campaign_map_point(1409, 339), 
			_campaign_map_point(1409, 338), _campaign_map_point(1409, 337), _campaign_map_point(1409, 336), 
			_campaign_map_point(1409, 335), _campaign_map_point(1409, 334), _campaign_map_point(1409, 333), 
			_campaign_map_point(1409, 332), _campaign_map_point(1409, 331), _campaign_map_point(1409, 330), 
			_campaign_map_point(1409, 329), _campaign_map_point(1409, 328), _campaign_map_point(1409, 327), 
			_campaign_map_point(1409, 326), _campaign_map_point(1409, 325), _campaign_map_point(1409, 324), 
			_campaign_map_point(1409, 323), _campaign_map_point(1409, 322), _campaign_map_point(1409, 321), 
			_campaign_map_point(1409, 320), _campaign_map_point(1409, 319), _campaign_map_point(1409, 318), 
			_campaign_map_point(1409, 317), _campaign_map_point(1409, 316), _campaign_map_point(1409, 315), 
			_campaign_map_point(1409, 314), _campaign_map_point(1409, 313), _campaign_map_point(1409, 312), 
			_campaign_map_point(1409, 311), _campaign_map_point(1409, 310), _campaign_map_point(1409, 309), 
			_campaign_map_point(1409, 308), _campaign_map_point(1409, 307), _campaign_map_point(1409, 306), 
			_campaign_map_point(1409, 305), _campaign_map_point(1409, 304), _campaign_map_point(1409, 303), 
			_campaign_map_point(1409, 302), _campaign_map_point(1409, 301), _campaign_map_point(1409, 300), 
			_campaign_map_point(1409, 299), _campaign_map_point(1409, 298), _campaign_map_point(1409, 297), 
			_campaign_map_point(1409, 296), _campaign_map_point(1409, 295), _campaign_map_point(1409, 294), 
			_campaign_map_point(1409, 293), _campaign_map_point(1409, 292), _campaign_map_point(1409, 291), 
			_campaign_map_point(1409, 290), _campaign_map_point(1409, 289), _campaign_map_point(1409, 288), 
			_campaign_map_point(1409, 287), _campaign_map_point(1409, 286), _campaign_map_point(1409, 285), 
			_campaign_map_point(1409, 284), _campaign_map_point(1409, 283), _campaign_map_point(1409, 282), 
			_campaign_map_point(1409, 281), _campaign_map_point(1409, 280), _campaign_map_point(1409, 279), 
			_campaign_map_point(1409, 278), _campaign_map_point(1409, 277), _campaign_map_point(1409, 276), 
			_campaign_map_point(1409, 275), _campaign_map_point(1409, 274), _campaign_map_point(1409, 273), 
			_campaign_map_point(1409, 272), _campaign_map_point(1409, 271), _campaign_map_point(1409, 270), 
			_campaign_map_point(1409, 269), _campaign_map_point(1408, 268), _campaign_map_point(1408, 267), 
			_campaign_map_point(1408, 266), _campaign_map_point(1408, 265), _campaign_map_point(1408, 264), 
			_campaign_map_point(1408, 263), _campaign_map_point(1408, 262), _campaign_map_point(1408, 261), 
			_campaign_map_point(1408, 260), _campaign_map_point(1408, 259), _campaign_map_point(1408, 258), 
			_campaign_map_point(1409, 257), _campaign_map_point(1409, 256), _campaign_map_point(1409, 255), 
			_campaign_map_point(1409, 254), _campaign_map_point(1409, 253), _campaign_map_point(1409, 252), 
			_campaign_map_point(1409, 251), _campaign_map_point(1409, 250), _campaign_map_point(1409, 249), 
			_campaign_map_point(1409, 248), _campaign_map_point(1409, 247), _campaign_map_point(1409, 246), 
			_campaign_map_point(1409, 245), _campaign_map_point(1409, 244), _campaign_map_point(1409, 243), 
			_campaign_map_point(1409, 242), _campaign_map_point(1409, 241), _campaign_map_point(1409, 240), 
			_campaign_map_point(1409, 239), _campaign_map_point(1409, 238), _campaign_map_point(1408, 237), 
			_campaign_map_point(1405, 236), _campaign_map_point(1404, 235), _campaign_map_point(1404, 234), 
			_campaign_map_point(1404, 233), _campaign_map_point(1404, 232), _campaign_map_point(1404, 231), 
			_campaign_map_point(1404, 230), _campaign_map_point(1404, 229), _campaign_map_point(1404, 228), 
			_campaign_map_point(1404, 227), _campaign_map_point(1404, 226), _campaign_map_point(1403, 225), 
			_campaign_map_point(1403, 224), _campaign_map_point(1403, 223), _campaign_map_point(1403, 222), 
			_campaign_map_point(1403, 221), _campaign_map_point(1402, 220), _campaign_map_point(1402, 219), 
			_campaign_map_point(1402, 218), _campaign_map_point(1402, 217), _campaign_map_point(1402, 216), 
			_campaign_map_point(1402, 215), _campaign_map_point(1401, 214), _campaign_map_point(1401, 213), 
			_campaign_map_point(1401, 212), _campaign_map_point(1400, 211), _campaign_map_point(1400, 210), 
			_campaign_map_point(1400, 209), _campaign_map_point(1400, 208), _campaign_map_point(1399, 207), 
			_campaign_map_point(1399, 206), _campaign_map_point(1399, 205), _campaign_map_point(1398, 204), 
			_campaign_map_point(1398, 203), _campaign_map_point(1398, 202), _campaign_map_point(1397, 201), 
			_campaign_map_point(1396, 200), _campaign_map_point(1396, 199), _campaign_map_point(1396, 198), 
			_campaign_map_point(1395, 197), _campaign_map_point(1395, 196), _campaign_map_point(1395, 195), 
			_campaign_map_point(1394, 194), _campaign_map_point(1393, 193), _campaign_map_point(1393, 192), 
			_campaign_map_point(1393, 191), _campaign_map_point(1392, 190), _campaign_map_point(1392, 189), 
			_campaign_map_point(1391, 188), _campaign_map_point(1391, 187), _campaign_map_point(1391, 186), 
			_campaign_map_point(1390, 185), _campaign_map_point(1390, 184), _campaign_map_point(1389, 183), 
			_campaign_map_point(1389, 182), _campaign_map_point(1388, 181), _campaign_map_point(1387, 180), 
			_campaign_map_point(1386, 179), _campaign_map_point(1386, 178), _campaign_map_point(1385, 177), 
			_campaign_map_point(1384, 176), _campaign_map_point(1384, 175), _campaign_map_point(1384, 174), 
			_campaign_map_point(1383, 173), _campaign_map_point(1382, 172), _campaign_map_point(1382, 171), 
			_campaign_map_point(1381, 170), _campaign_map_point(1381, 169), _campaign_map_point(1380, 168), 
			_campaign_map_point(1379, 167), _campaign_map_point(1378, 166), _campaign_map_point(1377, 165), 
			_campaign_map_point(1376, 164), _campaign_map_point(1375, 163), _campaign_map_point(1375, 162), 
			_campaign_map_point(1374, 161), _campaign_map_point(1373, 160), _campaign_map_point(1372, 159), 
			_campaign_map_point(1371, 158), _campaign_map_point(1370, 157), _campaign_map_point(1369, 156), 
			_campaign_map_point(1369, 155), _campaign_map_point(1368, 154), _campaign_map_point(1367, 153), 
			_campaign_map_point(1366, 152), _campaign_map_point(1366, 151), _campaign_map_point(1365, 150), 
			_campaign_map_point(1364, 149), _campaign_map_point(1363, 148), _campaign_map_point(1362, 147), 
			_campaign_map_point(1361, 146), _campaign_map_point(1360, 145), _campaign_map_point(1359, 144), 
			_campaign_map_point(1358, 143), _campaign_map_point(1357, 142), _campaign_map_point(1356, 141), 
			_campaign_map_point(1355, 140), _campaign_map_point(1353, 139), _campaign_map_point(1353, 138), 
			_campaign_map_point(1352, 137), _campaign_map_point(1351, 136), _campaign_map_point(1349, 135), 
			_campaign_map_point(1348, 134), _campaign_map_point(1347, 133), _campaign_map_point(1346, 132), 
			_campaign_map_point(1336, 131), _campaign_map_point(1335, 130), _campaign_map_point(1335, 129), 
			_campaign_map_point(1332, 128), _campaign_map_point(1332, 127), _campaign_map_point(1332, 126), 
			_campaign_map_point(1332, 125), _campaign_map_point(1326, 124), _campaign_map_point(1325, 123), 
			_campaign_map_point(1323, 122), _campaign_map_point(1323, 121), _campaign_map_point(1320, 120), 
			_campaign_map_point(1318, 119), _campaign_map_point(1315, 118), _campaign_map_point(1315, 117), 
			_campaign_map_point(1315, 116), _campaign_map_point(1315, 115), _campaign_map_point(1315, 114), 
			_campaign_map_point(1315, 113), _campaign_map_point(1315, 112)
		]},
		{"section": "Весы переосмысления", "mask": "res://Background/Campaign_Hover_scales.png", "points": [
			_campaign_map_point(1554, 79), _campaign_map_point(1553, 80), _campaign_map_point(1552, 81), 
			_campaign_map_point(1550, 82), _campaign_map_point(1549, 83), _campaign_map_point(1547, 84), 
			_campaign_map_point(1546, 85), _campaign_map_point(1544, 86), _campaign_map_point(1543, 87), 
			_campaign_map_point(1541, 88), _campaign_map_point(1540, 89), _campaign_map_point(1539, 90), 
			_campaign_map_point(1537, 91), _campaign_map_point(1536, 92), _campaign_map_point(1534, 93), 
			_campaign_map_point(1533, 94), _campaign_map_point(1532, 95), _campaign_map_point(1530, 96), 
			_campaign_map_point(1529, 97), _campaign_map_point(1528, 98), _campaign_map_point(1527, 99), 
			_campaign_map_point(1525, 100), _campaign_map_point(1524, 101), _campaign_map_point(1523, 102), 
			_campaign_map_point(1522, 103), _campaign_map_point(1520, 104), _campaign_map_point(1519, 105), 
			_campaign_map_point(1518, 106), _campaign_map_point(1517, 107), _campaign_map_point(1516, 108), 
			_campaign_map_point(1514, 109), _campaign_map_point(1513, 110), _campaign_map_point(1512, 111), 
			_campaign_map_point(1511, 112), _campaign_map_point(1510, 113), _campaign_map_point(1510, 114), 
			_campaign_map_point(1508, 115), _campaign_map_point(1507, 116), _campaign_map_point(1506, 117), 
			_campaign_map_point(1506, 118), _campaign_map_point(1504, 119), _campaign_map_point(1503, 120), 
			_campaign_map_point(1502, 121), _campaign_map_point(1501, 122), _campaign_map_point(1500, 123), 
			_campaign_map_point(1499, 124), _campaign_map_point(1498, 125), _campaign_map_point(1497, 126), 
			_campaign_map_point(1496, 127), _campaign_map_point(1495, 128), _campaign_map_point(1494, 129), 
			_campaign_map_point(1493, 130), _campaign_map_point(1492, 131), _campaign_map_point(1491, 132), 
			_campaign_map_point(1490, 133), _campaign_map_point(1490, 134), _campaign_map_point(1489, 135), 
			_campaign_map_point(1488, 136), _campaign_map_point(1487, 137), _campaign_map_point(1486, 138), 
			_campaign_map_point(1485, 139), _campaign_map_point(1484, 140), _campaign_map_point(1483, 141), 
			_campaign_map_point(1482, 142), _campaign_map_point(1482, 143), _campaign_map_point(1481, 144), 
			_campaign_map_point(1480, 145), _campaign_map_point(1479, 146), _campaign_map_point(1479, 147), 
			_campaign_map_point(1478, 148), _campaign_map_point(1477, 149), _campaign_map_point(1476, 150), 
			_campaign_map_point(1476, 151), _campaign_map_point(1475, 152), _campaign_map_point(1474, 153), 
			_campaign_map_point(1473, 154), _campaign_map_point(1473, 155), _campaign_map_point(1472, 156), 
			_campaign_map_point(1471, 157), _campaign_map_point(1471, 158), _campaign_map_point(1470, 159), 
			_campaign_map_point(1469, 160), _campaign_map_point(1468, 161), _campaign_map_point(1468, 162), 
			_campaign_map_point(1467, 163), _campaign_map_point(1466, 164), _campaign_map_point(1466, 165), 
			_campaign_map_point(1465, 166), _campaign_map_point(1464, 167), _campaign_map_point(1464, 168), 
			_campaign_map_point(1463, 169), _campaign_map_point(1463, 170), _campaign_map_point(1462, 171), 
			_campaign_map_point(1461, 172), _campaign_map_point(1461, 173), _campaign_map_point(1460, 174), 
			_campaign_map_point(1460, 175), _campaign_map_point(1460, 176), _campaign_map_point(1459, 177), 
			_campaign_map_point(1458, 178), _campaign_map_point(1458, 179), _campaign_map_point(1458, 180), 
			_campaign_map_point(1457, 181), _campaign_map_point(1457, 182), _campaign_map_point(1456, 183), 
			_campaign_map_point(1456, 184), _campaign_map_point(1455, 185), _campaign_map_point(1455, 186), 
			_campaign_map_point(1454, 187), _campaign_map_point(1454, 188), _campaign_map_point(1454, 189), 
			_campaign_map_point(1453, 190), _campaign_map_point(1453, 191), _campaign_map_point(1452, 192), 
			_campaign_map_point(1452, 193), _campaign_map_point(1451, 194), _campaign_map_point(1451, 195), 
			_campaign_map_point(1450, 196), _campaign_map_point(1450, 197), _campaign_map_point(1450, 198), 
			_campaign_map_point(1449, 199), _campaign_map_point(1449, 200), _campaign_map_point(1449, 201), 
			_campaign_map_point(1449, 202), _campaign_map_point(1448, 203), _campaign_map_point(1448, 204), 
			_campaign_map_point(1448, 205), _campaign_map_point(1447, 206), _campaign_map_point(1447, 207), 
			_campaign_map_point(1447, 208), _campaign_map_point(1446, 209), _campaign_map_point(1446, 210), 
			_campaign_map_point(1446, 211), _campaign_map_point(1445, 212), _campaign_map_point(1445, 213), 
			_campaign_map_point(1445, 214), _campaign_map_point(1444, 215), _campaign_map_point(1444, 216), 
			_campaign_map_point(1444, 217), _campaign_map_point(1444, 218), _campaign_map_point(1443, 219), 
			_campaign_map_point(1443, 220), _campaign_map_point(1443, 221), _campaign_map_point(1443, 222), 
			_campaign_map_point(1443, 223), _campaign_map_point(1443, 224), _campaign_map_point(1443, 225), 
			_campaign_map_point(1443, 226), _campaign_map_point(1443, 227), _campaign_map_point(1443, 228), 
			_campaign_map_point(1443, 229), _campaign_map_point(1443, 230), _campaign_map_point(1443, 231), 
			_campaign_map_point(1443, 232), _campaign_map_point(1443, 233), _campaign_map_point(1440, 234), 
			_campaign_map_point(1439, 235), _campaign_map_point(1439, 236), _campaign_map_point(1438, 237), 
			_campaign_map_point(1438, 238), _campaign_map_point(1438, 239), _campaign_map_point(1438, 240), 
			_campaign_map_point(1438, 241), _campaign_map_point(1438, 242), _campaign_map_point(1438, 243), 
			_campaign_map_point(1438, 244), _campaign_map_point(1438, 245), _campaign_map_point(1438, 246), 
			_campaign_map_point(1438, 247), _campaign_map_point(1438, 248), _campaign_map_point(1438, 249), 
			_campaign_map_point(1438, 250), _campaign_map_point(1438, 251), _campaign_map_point(1438, 252), 
			_campaign_map_point(1438, 253), _campaign_map_point(1438, 254), _campaign_map_point(1438, 255), 
			_campaign_map_point(1438, 256), _campaign_map_point(1438, 257), _campaign_map_point(1438, 258), 
			_campaign_map_point(1438, 259), _campaign_map_point(1438, 260), _campaign_map_point(1438, 261), 
			_campaign_map_point(1438, 262), _campaign_map_point(1439, 263), _campaign_map_point(1439, 264), 
			_campaign_map_point(1439, 265), _campaign_map_point(1439, 266), _campaign_map_point(1439, 267), 
			_campaign_map_point(1439, 268), _campaign_map_point(1439, 269), _campaign_map_point(1439, 270), 
			_campaign_map_point(1439, 271), _campaign_map_point(1439, 272), _campaign_map_point(1439, 273), 
			_campaign_map_point(1439, 274), _campaign_map_point(1439, 275), _campaign_map_point(1439, 276), 
			_campaign_map_point(1439, 277), _campaign_map_point(1439, 278), _campaign_map_point(1439, 279), 
			_campaign_map_point(1439, 280), _campaign_map_point(1439, 281), _campaign_map_point(1439, 282), 
			_campaign_map_point(1439, 283), _campaign_map_point(1439, 284), _campaign_map_point(1439, 285), 
			_campaign_map_point(1439, 286), _campaign_map_point(1439, 287), _campaign_map_point(1439, 288), 
			_campaign_map_point(1439, 289), _campaign_map_point(1439, 290), _campaign_map_point(1439, 291), 
			_campaign_map_point(1439, 292), _campaign_map_point(1439, 293), _campaign_map_point(1439, 294), 
			_campaign_map_point(1439, 295), _campaign_map_point(1439, 296), _campaign_map_point(1439, 297), 
			_campaign_map_point(1439, 298), _campaign_map_point(1439, 299), _campaign_map_point(1439, 300), 
			_campaign_map_point(1439, 301), _campaign_map_point(1439, 302), _campaign_map_point(1439, 303), 
			_campaign_map_point(1439, 304), _campaign_map_point(1439, 305), _campaign_map_point(1439, 306), 
			_campaign_map_point(1439, 307), _campaign_map_point(1439, 308), _campaign_map_point(1439, 309), 
			_campaign_map_point(1439, 310), _campaign_map_point(1439, 311), _campaign_map_point(1439, 312), 
			_campaign_map_point(1439, 313), _campaign_map_point(1439, 314), _campaign_map_point(1439, 315), 
			_campaign_map_point(1439, 316), _campaign_map_point(1439, 317), _campaign_map_point(1439, 318), 
			_campaign_map_point(1439, 319), _campaign_map_point(1439, 320), _campaign_map_point(1439, 321), 
			_campaign_map_point(1439, 322), _campaign_map_point(1439, 323), _campaign_map_point(1439, 324), 
			_campaign_map_point(1439, 325), _campaign_map_point(1439, 326), _campaign_map_point(1439, 327), 
			_campaign_map_point(1439, 328), _campaign_map_point(1439, 329), _campaign_map_point(1439, 330), 
			_campaign_map_point(1439, 331), _campaign_map_point(1439, 332), _campaign_map_point(1439, 333), 
			_campaign_map_point(1439, 334), _campaign_map_point(1439, 335), _campaign_map_point(1439, 336), 
			_campaign_map_point(1439, 337), _campaign_map_point(1439, 338), _campaign_map_point(1439, 339), 
			_campaign_map_point(1439, 340), _campaign_map_point(1439, 341), _campaign_map_point(1439, 342), 
			_campaign_map_point(1439, 343), _campaign_map_point(1439, 344), _campaign_map_point(1439, 345), 
			_campaign_map_point(1439, 346), _campaign_map_point(1439, 347), _campaign_map_point(1439, 348), 
			_campaign_map_point(1439, 349), _campaign_map_point(1439, 350), _campaign_map_point(1439, 351), 
			_campaign_map_point(1439, 352), _campaign_map_point(1439, 353), _campaign_map_point(1439, 354), 
			_campaign_map_point(1439, 355), _campaign_map_point(1439, 356), _campaign_map_point(1439, 357), 
			_campaign_map_point(1439, 358), _campaign_map_point(1439, 359), _campaign_map_point(1439, 360), 
			_campaign_map_point(1439, 361), _campaign_map_point(1439, 362), _campaign_map_point(1439, 363), 
			_campaign_map_point(1439, 364), _campaign_map_point(1439, 365), _campaign_map_point(1439, 366), 
			_campaign_map_point(1439, 367), _campaign_map_point(1439, 368), _campaign_map_point(1439, 369), 
			_campaign_map_point(1439, 370), _campaign_map_point(1439, 371), _campaign_map_point(1439, 372), 
			_campaign_map_point(1439, 373), _campaign_map_point(1439, 374), _campaign_map_point(1439, 375), 
			_campaign_map_point(1439, 376), _campaign_map_point(1439, 377), _campaign_map_point(1439, 378), 
			_campaign_map_point(1439, 379), _campaign_map_point(1439, 380), _campaign_map_point(1439, 381), 
			_campaign_map_point(1439, 382), _campaign_map_point(1439, 383), _campaign_map_point(1439, 384), 
			_campaign_map_point(1439, 385), _campaign_map_point(1439, 386), _campaign_map_point(1439, 387), 
			_campaign_map_point(1439, 388), _campaign_map_point(1439, 389), _campaign_map_point(1439, 390), 
			_campaign_map_point(1439, 391), _campaign_map_point(1439, 392), _campaign_map_point(1439, 393), 
			_campaign_map_point(1439, 394), _campaign_map_point(1439, 395), _campaign_map_point(1439, 396), 
			_campaign_map_point(1439, 397), _campaign_map_point(1439, 398), _campaign_map_point(1439, 399), 
			_campaign_map_point(1439, 400), _campaign_map_point(1439, 401), _campaign_map_point(1439, 402), 
			_campaign_map_point(1439, 403), _campaign_map_point(1439, 404), _campaign_map_point(1439, 405), 
			_campaign_map_point(1439, 406), _campaign_map_point(1439, 407), _campaign_map_point(1439, 408), 
			_campaign_map_point(1439, 409), _campaign_map_point(1439, 410), _campaign_map_point(1439, 411), 
			_campaign_map_point(1439, 412), _campaign_map_point(1439, 413), _campaign_map_point(1439, 414), 
			_campaign_map_point(1439, 415), _campaign_map_point(1439, 416), _campaign_map_point(1439, 417), 
			_campaign_map_point(1439, 418), _campaign_map_point(1439, 419), _campaign_map_point(1439, 420), 
			_campaign_map_point(1439, 421), _campaign_map_point(1439, 422), _campaign_map_point(1439, 423), 
			_campaign_map_point(1439, 424), _campaign_map_point(1439, 425), _campaign_map_point(1439, 426), 
			_campaign_map_point(1439, 427), _campaign_map_point(1439, 428), _campaign_map_point(1439, 429), 
			_campaign_map_point(1439, 430), _campaign_map_point(1439, 431), _campaign_map_point(1439, 432), 
			_campaign_map_point(1439, 433), _campaign_map_point(1439, 434), _campaign_map_point(1439, 435), 
			_campaign_map_point(1439, 436), _campaign_map_point(1439, 437), _campaign_map_point(1439, 438), 
			_campaign_map_point(1439, 439), _campaign_map_point(1439, 440), _campaign_map_point(1439, 441), 
			_campaign_map_point(1439, 442), _campaign_map_point(1439, 443), _campaign_map_point(1439, 444), 
			_campaign_map_point(1439, 445), _campaign_map_point(1439, 446), _campaign_map_point(1439, 447), 
			_campaign_map_point(1439, 448), _campaign_map_point(1439, 449), _campaign_map_point(1439, 450), 
			_campaign_map_point(1439, 451), _campaign_map_point(1439, 452), _campaign_map_point(1439, 453), 
			_campaign_map_point(1439, 454), _campaign_map_point(1439, 455), _campaign_map_point(1439, 456), 
			_campaign_map_point(1439, 457), _campaign_map_point(1439, 458), _campaign_map_point(1439, 459), 
			_campaign_map_point(1439, 460), _campaign_map_point(1439, 461), _campaign_map_point(1439, 462), 
			_campaign_map_point(1439, 463), _campaign_map_point(1439, 464), _campaign_map_point(1439, 465), 
			_campaign_map_point(1439, 466), _campaign_map_point(1439, 467), _campaign_map_point(1439, 468), 
			_campaign_map_point(1439, 469), _campaign_map_point(1439, 470), _campaign_map_point(1439, 471), 
			_campaign_map_point(1439, 472), _campaign_map_point(1439, 473), _campaign_map_point(1439, 474), 
			_campaign_map_point(1439, 475), _campaign_map_point(1439, 476), _campaign_map_point(1439, 477), 
			_campaign_map_point(1439, 478), _campaign_map_point(1439, 479), _campaign_map_point(1439, 480), 
			_campaign_map_point(1439, 481), _campaign_map_point(1439, 482), _campaign_map_point(1439, 483), 
			_campaign_map_point(1439, 484), _campaign_map_point(1439, 485), _campaign_map_point(1439, 486), 
			_campaign_map_point(1439, 487), _campaign_map_point(1439, 488), _campaign_map_point(1439, 489), 
			_campaign_map_point(1439, 490), _campaign_map_point(1439, 491), _campaign_map_point(1439, 492), 
			_campaign_map_point(1439, 493), _campaign_map_point(1439, 494), _campaign_map_point(1439, 495), 
			_campaign_map_point(1439, 496), _campaign_map_point(1439, 497), _campaign_map_point(1439, 498), 
			_campaign_map_point(1439, 499), _campaign_map_point(1439, 500), _campaign_map_point(1439, 501), 
			_campaign_map_point(1439, 502), _campaign_map_point(1439, 503), _campaign_map_point(1439, 504), 
			_campaign_map_point(1439, 505), _campaign_map_point(1439, 506), _campaign_map_point(1439, 507), 
			_campaign_map_point(1439, 508), _campaign_map_point(1439, 509), _campaign_map_point(1439, 510), 
			_campaign_map_point(1439, 511), _campaign_map_point(1439, 512), _campaign_map_point(1439, 513), 
			_campaign_map_point(1439, 514), _campaign_map_point(1439, 515), _campaign_map_point(1439, 516), 
			_campaign_map_point(1439, 517), _campaign_map_point(1439, 518), _campaign_map_point(1439, 519), 
			_campaign_map_point(1439, 520), _campaign_map_point(1439, 521), _campaign_map_point(1439, 522), 
			_campaign_map_point(1439, 523), _campaign_map_point(1439, 524), _campaign_map_point(1439, 525), 
			_campaign_map_point(1439, 526), _campaign_map_point(1439, 527), _campaign_map_point(1439, 528), 
			_campaign_map_point(1439, 529), _campaign_map_point(1439, 530), _campaign_map_point(1439, 531), 
			_campaign_map_point(1439, 532), _campaign_map_point(1439, 533), _campaign_map_point(1439, 534), 
			_campaign_map_point(1439, 535), _campaign_map_point(1439, 536), _campaign_map_point(1439, 537), 
			_campaign_map_point(1439, 538), _campaign_map_point(1439, 539), _campaign_map_point(1439, 540), 
			_campaign_map_point(1439, 541), _campaign_map_point(1439, 542), _campaign_map_point(1439, 543), 
			_campaign_map_point(1439, 544), _campaign_map_point(1439, 545), _campaign_map_point(1439, 546), 
			_campaign_map_point(1439, 547), _campaign_map_point(1439, 548), _campaign_map_point(1439, 549), 
			_campaign_map_point(1439, 550), _campaign_map_point(1439, 551), _campaign_map_point(1439, 552), 
			_campaign_map_point(1439, 553), _campaign_map_point(1439, 554), _campaign_map_point(1439, 555), 
			_campaign_map_point(1439, 556), _campaign_map_point(1439, 557), _campaign_map_point(1439, 558), 
			_campaign_map_point(1439, 559), _campaign_map_point(1439, 560), _campaign_map_point(1439, 561), 
			_campaign_map_point(1439, 562), _campaign_map_point(1439, 563), _campaign_map_point(1439, 564), 
			_campaign_map_point(1439, 565), _campaign_map_point(1439, 566), _campaign_map_point(1439, 567), 
			_campaign_map_point(1439, 568), _campaign_map_point(1439, 569), _campaign_map_point(1439, 570), 
			_campaign_map_point(1439, 571), _campaign_map_point(1439, 572), _campaign_map_point(1439, 573), 
			_campaign_map_point(1439, 574), _campaign_map_point(1439, 575), _campaign_map_point(1439, 576), 
			_campaign_map_point(1439, 577), _campaign_map_point(1439, 578), _campaign_map_point(1439, 579), 
			_campaign_map_point(1439, 580), _campaign_map_point(1439, 581), _campaign_map_point(1439, 582), 
			_campaign_map_point(1439, 583), _campaign_map_point(1439, 584), _campaign_map_point(1439, 585), 
			_campaign_map_point(1439, 586), _campaign_map_point(1439, 587), _campaign_map_point(1439, 588), 
			_campaign_map_point(1439, 589), _campaign_map_point(1439, 590), _campaign_map_point(1439, 591), 
			_campaign_map_point(1439, 592), _campaign_map_point(1439, 593), _campaign_map_point(1439, 594), 
			_campaign_map_point(1439, 595), _campaign_map_point(1439, 596), _campaign_map_point(1439, 597), 
			_campaign_map_point(1439, 598), _campaign_map_point(1439, 599), _campaign_map_point(1439, 600), 
			_campaign_map_point(1439, 601), _campaign_map_point(1439, 602), _campaign_map_point(1439, 603), 
			_campaign_map_point(1439, 604), _campaign_map_point(1439, 605), _campaign_map_point(1439, 606), 
			_campaign_map_point(1439, 607), _campaign_map_point(1439, 608), _campaign_map_point(1439, 609), 
			_campaign_map_point(1439, 610), _campaign_map_point(1439, 611), _campaign_map_point(1439, 612), 
			_campaign_map_point(1439, 613), _campaign_map_point(1439, 614), _campaign_map_point(1439, 615), 
			_campaign_map_point(1439, 616), _campaign_map_point(1439, 617), _campaign_map_point(1439, 618), 
			_campaign_map_point(1439, 619), _campaign_map_point(1439, 620), _campaign_map_point(1439, 621), 
			_campaign_map_point(1439, 622), _campaign_map_point(1439, 623), _campaign_map_point(1439, 624), 
			_campaign_map_point(1439, 625), _campaign_map_point(1439, 626), _campaign_map_point(1439, 627), 
			_campaign_map_point(1439, 628), _campaign_map_point(1439, 629), _campaign_map_point(1439, 630), 
			_campaign_map_point(1439, 631), _campaign_map_point(1439, 632), _campaign_map_point(1439, 633), 
			_campaign_map_point(1439, 634), _campaign_map_point(1439, 635), _campaign_map_point(1439, 636), 
			_campaign_map_point(1439, 637), _campaign_map_point(1439, 638), _campaign_map_point(1439, 639), 
			_campaign_map_point(1439, 640), _campaign_map_point(1439, 641), _campaign_map_point(1439, 642), 
			_campaign_map_point(1439, 643), _campaign_map_point(1439, 644), _campaign_map_point(1439, 645), 
			_campaign_map_point(1439, 646), _campaign_map_point(1439, 647), _campaign_map_point(1439, 648), 
			_campaign_map_point(1439, 649), _campaign_map_point(1439, 650), _campaign_map_point(1439, 651), 
			_campaign_map_point(1439, 652), _campaign_map_point(1439, 653), _campaign_map_point(1439, 654), 
			_campaign_map_point(1439, 655), _campaign_map_point(1439, 656), _campaign_map_point(1439, 657), 
			_campaign_map_point(1439, 658), _campaign_map_point(1439, 659), _campaign_map_point(1439, 660), 
			_campaign_map_point(1439, 661), _campaign_map_point(1439, 662), _campaign_map_point(1439, 663), 
			_campaign_map_point(1439, 664), _campaign_map_point(1439, 665), _campaign_map_point(1439, 666), 
			_campaign_map_point(1439, 667), _campaign_map_point(1439, 668), _campaign_map_point(1439, 669), 
			_campaign_map_point(1439, 670), _campaign_map_point(1439, 671), _campaign_map_point(1439, 672), 
			_campaign_map_point(1439, 673), _campaign_map_point(1439, 674), _campaign_map_point(1439, 675), 
			_campaign_map_point(1439, 676), _campaign_map_point(1439, 677), _campaign_map_point(1439, 678), 
			_campaign_map_point(1439, 679), _campaign_map_point(1439, 680), _campaign_map_point(1439, 681), 
			_campaign_map_point(1439, 682), _campaign_map_point(1439, 683), _campaign_map_point(1439, 684), 
			_campaign_map_point(1439, 685), _campaign_map_point(1439, 686), _campaign_map_point(1439, 687), 
			_campaign_map_point(1439, 688), _campaign_map_point(1439, 689), _campaign_map_point(1439, 690), 
			_campaign_map_point(1439, 691), _campaign_map_point(1439, 692), _campaign_map_point(1439, 693), 
			_campaign_map_point(1439, 694), _campaign_map_point(1439, 695), _campaign_map_point(1439, 696), 
			_campaign_map_point(1439, 697), _campaign_map_point(1439, 698), _campaign_map_point(1439, 699), 
			_campaign_map_point(1439, 700), _campaign_map_point(1439, 701), _campaign_map_point(1439, 702), 
			_campaign_map_point(1439, 703), _campaign_map_point(1439, 704), _campaign_map_point(1439, 705), 
			_campaign_map_point(1439, 706), _campaign_map_point(1439, 707), _campaign_map_point(1439, 708), 
			_campaign_map_point(1439, 709), _campaign_map_point(1439, 710), _campaign_map_point(1439, 711), 
			_campaign_map_point(1439, 712), _campaign_map_point(1439, 713), _campaign_map_point(1439, 714), 
			_campaign_map_point(1439, 715), _campaign_map_point(1439, 716), _campaign_map_point(1439, 717), 
			_campaign_map_point(1439, 718), _campaign_map_point(1439, 719), _campaign_map_point(1439, 720), 
			_campaign_map_point(1439, 721), _campaign_map_point(1439, 722), _campaign_map_point(1439, 723), 
			_campaign_map_point(1439, 724), _campaign_map_point(1439, 725), _campaign_map_point(1440, 726), 
			_campaign_map_point(1440, 727), _campaign_map_point(1440, 728), _campaign_map_point(1440, 729), 
			_campaign_map_point(1440, 730), _campaign_map_point(1440, 731), _campaign_map_point(1440, 732), 
			_campaign_map_point(1440, 733), _campaign_map_point(1440, 734), _campaign_map_point(1440, 735), 
			_campaign_map_point(1440, 736), _campaign_map_point(1440, 737), _campaign_map_point(1440, 738), 
			_campaign_map_point(1440, 739), _campaign_map_point(1440, 740), _campaign_map_point(1440, 741), 
			_campaign_map_point(1440, 742), _campaign_map_point(1440, 743), _campaign_map_point(1440, 744), 
			_campaign_map_point(1440, 745), _campaign_map_point(1440, 746), _campaign_map_point(1440, 747), 
			_campaign_map_point(1440, 748), _campaign_map_point(1440, 749), _campaign_map_point(1440, 750), 
			_campaign_map_point(1440, 751), _campaign_map_point(1440, 752), _campaign_map_point(1440, 753), 
			_campaign_map_point(1441, 754), _campaign_map_point(1442, 755), _campaign_map_point(1443, 756), 
			_campaign_map_point(1444, 757), _campaign_map_point(1445, 758), _campaign_map_point(1446, 759), 
			_campaign_map_point(1448, 760), _campaign_map_point(1458, 761), _campaign_map_point(1466, 762), 
			_campaign_map_point(1474, 763), _campaign_map_point(1481, 764), _campaign_map_point(1488, 765), 
			_campaign_map_point(1496, 766), _campaign_map_point(1506, 767), _campaign_map_point(1518, 768), 
			_campaign_map_point(1522, 769), _campaign_map_point(1531, 770), _campaign_map_point(1539, 771), 
			_campaign_map_point(1552, 772), _campaign_map_point(1555, 773), _campaign_map_point(1564, 774), 
			_campaign_map_point(1567, 775), _campaign_map_point(1576, 776), _campaign_map_point(1584, 777), 
			_campaign_map_point(1588, 778), _campaign_map_point(1595, 779), _campaign_map_point(1604, 780), 
			_campaign_map_point(1612, 781), _campaign_map_point(1620, 782), _campaign_map_point(1628, 783), 
			_campaign_map_point(1639, 784), _campaign_map_point(1649, 785), _campaign_map_point(1663, 785), 
			_campaign_map_point(1663, 784), _campaign_map_point(1663, 783), _campaign_map_point(1663, 782), 
			_campaign_map_point(1663, 781), _campaign_map_point(1663, 780), _campaign_map_point(1663, 779), 
			_campaign_map_point(1663, 778), _campaign_map_point(1663, 777), _campaign_map_point(1663, 776), 
			_campaign_map_point(1663, 775), _campaign_map_point(1663, 774), _campaign_map_point(1663, 773), 
			_campaign_map_point(1663, 772), _campaign_map_point(1663, 771), _campaign_map_point(1663, 770), 
			_campaign_map_point(1663, 769), _campaign_map_point(1663, 768), _campaign_map_point(1663, 767), 
			_campaign_map_point(1663, 766), _campaign_map_point(1663, 765), _campaign_map_point(1663, 764), 
			_campaign_map_point(1663, 763), _campaign_map_point(1663, 762), _campaign_map_point(1664, 761), 
			_campaign_map_point(1664, 760), _campaign_map_point(1664, 759), _campaign_map_point(1664, 758), 
			_campaign_map_point(1664, 757), _campaign_map_point(1664, 756), _campaign_map_point(1664, 755), 
			_campaign_map_point(1664, 754), _campaign_map_point(1664, 753), _campaign_map_point(1664, 752), 
			_campaign_map_point(1664, 751), _campaign_map_point(1663, 750), _campaign_map_point(1662, 749), 
			_campaign_map_point(1662, 748), _campaign_map_point(1662, 747), _campaign_map_point(1662, 746), 
			_campaign_map_point(1662, 745), _campaign_map_point(1662, 744), _campaign_map_point(1662, 743), 
			_campaign_map_point(1662, 742), _campaign_map_point(1662, 741), _campaign_map_point(1662, 740), 
			_campaign_map_point(1662, 739), _campaign_map_point(1665, 738), _campaign_map_point(1665, 737), 
			_campaign_map_point(1665, 736), _campaign_map_point(1665, 735), _campaign_map_point(1665, 734), 
			_campaign_map_point(1665, 733), _campaign_map_point(1665, 732), _campaign_map_point(1665, 731), 
			_campaign_map_point(1665, 730), _campaign_map_point(1665, 729), _campaign_map_point(1665, 728), 
			_campaign_map_point(1665, 727), _campaign_map_point(1665, 726), _campaign_map_point(1665, 725), 
			_campaign_map_point(1665, 724), _campaign_map_point(1665, 723), _campaign_map_point(1665, 722), 
			_campaign_map_point(1665, 721), _campaign_map_point(1665, 720), _campaign_map_point(1665, 719), 
			_campaign_map_point(1665, 718), _campaign_map_point(1665, 717), _campaign_map_point(1665, 716), 
			_campaign_map_point(1665, 715), _campaign_map_point(1665, 714), _campaign_map_point(1665, 713), 
			_campaign_map_point(1665, 712), _campaign_map_point(1665, 711), _campaign_map_point(1665, 710), 
			_campaign_map_point(1665, 709), _campaign_map_point(1665, 708), _campaign_map_point(1665, 707), 
			_campaign_map_point(1665, 706), _campaign_map_point(1665, 705), _campaign_map_point(1665, 704), 
			_campaign_map_point(1665, 703), _campaign_map_point(1665, 702), _campaign_map_point(1665, 701), 
			_campaign_map_point(1665, 700), _campaign_map_point(1665, 699), _campaign_map_point(1665, 698), 
			_campaign_map_point(1665, 697), _campaign_map_point(1665, 696), _campaign_map_point(1665, 695), 
			_campaign_map_point(1665, 694), _campaign_map_point(1665, 693), _campaign_map_point(1665, 692), 
			_campaign_map_point(1665, 691), _campaign_map_point(1665, 690), _campaign_map_point(1665, 689), 
			_campaign_map_point(1665, 688), _campaign_map_point(1665, 687), _campaign_map_point(1665, 686), 
			_campaign_map_point(1665, 685), _campaign_map_point(1665, 684), _campaign_map_point(1665, 683), 
			_campaign_map_point(1665, 682), _campaign_map_point(1665, 681), _campaign_map_point(1665, 680), 
			_campaign_map_point(1665, 679), _campaign_map_point(1665, 678), _campaign_map_point(1665, 677), 
			_campaign_map_point(1665, 676), _campaign_map_point(1665, 675), _campaign_map_point(1665, 674), 
			_campaign_map_point(1665, 673), _campaign_map_point(1665, 672), _campaign_map_point(1665, 671), 
			_campaign_map_point(1665, 670), _campaign_map_point(1665, 669), _campaign_map_point(1665, 668), 
			_campaign_map_point(1665, 667), _campaign_map_point(1665, 666), _campaign_map_point(1665, 665), 
			_campaign_map_point(1665, 664), _campaign_map_point(1665, 663), _campaign_map_point(1665, 662), 
			_campaign_map_point(1665, 661), _campaign_map_point(1665, 660), _campaign_map_point(1665, 659), 
			_campaign_map_point(1665, 658), _campaign_map_point(1665, 657), _campaign_map_point(1665, 656), 
			_campaign_map_point(1665, 655), _campaign_map_point(1665, 654), _campaign_map_point(1665, 653), 
			_campaign_map_point(1665, 652), _campaign_map_point(1665, 651), _campaign_map_point(1665, 650), 
			_campaign_map_point(1665, 649), _campaign_map_point(1665, 648), _campaign_map_point(1665, 647), 
			_campaign_map_point(1665, 646), _campaign_map_point(1665, 645), _campaign_map_point(1665, 644), 
			_campaign_map_point(1665, 643), _campaign_map_point(1665, 642), _campaign_map_point(1665, 641), 
			_campaign_map_point(1665, 640), _campaign_map_point(1665, 639), _campaign_map_point(1665, 638), 
			_campaign_map_point(1665, 637), _campaign_map_point(1665, 636), _campaign_map_point(1665, 635), 
			_campaign_map_point(1665, 634), _campaign_map_point(1665, 633), _campaign_map_point(1665, 632), 
			_campaign_map_point(1665, 631), _campaign_map_point(1665, 630), _campaign_map_point(1665, 629), 
			_campaign_map_point(1665, 628), _campaign_map_point(1665, 627), _campaign_map_point(1665, 626), 
			_campaign_map_point(1665, 625), _campaign_map_point(1665, 624), _campaign_map_point(1665, 623), 
			_campaign_map_point(1665, 622), _campaign_map_point(1665, 621), _campaign_map_point(1665, 620), 
			_campaign_map_point(1665, 619), _campaign_map_point(1665, 618), _campaign_map_point(1665, 617), 
			_campaign_map_point(1665, 616), _campaign_map_point(1665, 615), _campaign_map_point(1665, 614), 
			_campaign_map_point(1665, 613), _campaign_map_point(1665, 612), _campaign_map_point(1665, 611), 
			_campaign_map_point(1665, 610), _campaign_map_point(1665, 609), _campaign_map_point(1665, 608), 
			_campaign_map_point(1665, 607), _campaign_map_point(1665, 606), _campaign_map_point(1665, 605), 
			_campaign_map_point(1665, 604), _campaign_map_point(1665, 603), _campaign_map_point(1665, 602), 
			_campaign_map_point(1665, 601), _campaign_map_point(1665, 600), _campaign_map_point(1665, 599), 
			_campaign_map_point(1665, 598), _campaign_map_point(1665, 597), _campaign_map_point(1665, 596), 
			_campaign_map_point(1665, 595), _campaign_map_point(1665, 594), _campaign_map_point(1665, 593), 
			_campaign_map_point(1665, 592), _campaign_map_point(1665, 591), _campaign_map_point(1665, 590), 
			_campaign_map_point(1665, 589), _campaign_map_point(1665, 588), _campaign_map_point(1665, 587), 
			_campaign_map_point(1665, 586), _campaign_map_point(1665, 585), _campaign_map_point(1665, 584), 
			_campaign_map_point(1665, 583), _campaign_map_point(1665, 582), _campaign_map_point(1665, 581), 
			_campaign_map_point(1665, 580), _campaign_map_point(1665, 579), _campaign_map_point(1665, 578), 
			_campaign_map_point(1665, 577), _campaign_map_point(1665, 576), _campaign_map_point(1665, 575), 
			_campaign_map_point(1665, 574), _campaign_map_point(1665, 573), _campaign_map_point(1665, 572), 
			_campaign_map_point(1665, 571), _campaign_map_point(1665, 570), _campaign_map_point(1665, 569), 
			_campaign_map_point(1665, 568), _campaign_map_point(1665, 567), _campaign_map_point(1665, 566), 
			_campaign_map_point(1665, 565), _campaign_map_point(1665, 564), _campaign_map_point(1665, 563), 
			_campaign_map_point(1665, 562), _campaign_map_point(1665, 561), _campaign_map_point(1665, 560), 
			_campaign_map_point(1665, 559), _campaign_map_point(1665, 558), _campaign_map_point(1665, 557), 
			_campaign_map_point(1665, 556), _campaign_map_point(1665, 555), _campaign_map_point(1665, 554), 
			_campaign_map_point(1665, 553), _campaign_map_point(1665, 552), _campaign_map_point(1665, 551), 
			_campaign_map_point(1665, 550), _campaign_map_point(1665, 549), _campaign_map_point(1665, 548), 
			_campaign_map_point(1665, 547), _campaign_map_point(1665, 546), _campaign_map_point(1665, 545), 
			_campaign_map_point(1665, 544), _campaign_map_point(1665, 543), _campaign_map_point(1665, 542), 
			_campaign_map_point(1665, 541), _campaign_map_point(1665, 540), _campaign_map_point(1665, 539), 
			_campaign_map_point(1665, 538), _campaign_map_point(1665, 537), _campaign_map_point(1665, 536), 
			_campaign_map_point(1665, 535), _campaign_map_point(1665, 534), _campaign_map_point(1665, 533), 
			_campaign_map_point(1665, 532), _campaign_map_point(1665, 531), _campaign_map_point(1665, 530), 
			_campaign_map_point(1665, 529), _campaign_map_point(1665, 528), _campaign_map_point(1665, 527), 
			_campaign_map_point(1665, 526), _campaign_map_point(1665, 525), _campaign_map_point(1665, 524), 
			_campaign_map_point(1665, 523), _campaign_map_point(1665, 522), _campaign_map_point(1665, 521), 
			_campaign_map_point(1665, 520), _campaign_map_point(1665, 519), _campaign_map_point(1665, 518), 
			_campaign_map_point(1665, 517), _campaign_map_point(1665, 516), _campaign_map_point(1665, 515), 
			_campaign_map_point(1665, 514), _campaign_map_point(1665, 513), _campaign_map_point(1665, 512), 
			_campaign_map_point(1665, 511), _campaign_map_point(1665, 510), _campaign_map_point(1665, 509), 
			_campaign_map_point(1665, 508), _campaign_map_point(1665, 507), _campaign_map_point(1665, 506), 
			_campaign_map_point(1665, 505), _campaign_map_point(1665, 504), _campaign_map_point(1665, 503), 
			_campaign_map_point(1665, 502), _campaign_map_point(1665, 501), _campaign_map_point(1665, 500), 
			_campaign_map_point(1665, 499), _campaign_map_point(1665, 498), _campaign_map_point(1665, 497), 
			_campaign_map_point(1665, 496), _campaign_map_point(1665, 495), _campaign_map_point(1665, 494), 
			_campaign_map_point(1665, 493), _campaign_map_point(1665, 492), _campaign_map_point(1665, 491), 
			_campaign_map_point(1665, 490), _campaign_map_point(1665, 489), _campaign_map_point(1665, 488), 
			_campaign_map_point(1665, 487), _campaign_map_point(1665, 486), _campaign_map_point(1665, 485), 
			_campaign_map_point(1665, 484), _campaign_map_point(1665, 483), _campaign_map_point(1665, 482), 
			_campaign_map_point(1665, 481), _campaign_map_point(1665, 480), _campaign_map_point(1665, 479), 
			_campaign_map_point(1665, 478), _campaign_map_point(1665, 477), _campaign_map_point(1665, 476), 
			_campaign_map_point(1665, 475), _campaign_map_point(1665, 474), _campaign_map_point(1665, 473), 
			_campaign_map_point(1665, 472), _campaign_map_point(1665, 471), _campaign_map_point(1665, 470), 
			_campaign_map_point(1665, 469), _campaign_map_point(1665, 468), _campaign_map_point(1665, 467), 
			_campaign_map_point(1665, 466), _campaign_map_point(1665, 465), _campaign_map_point(1665, 464), 
			_campaign_map_point(1665, 463), _campaign_map_point(1665, 462), _campaign_map_point(1665, 461), 
			_campaign_map_point(1665, 460), _campaign_map_point(1665, 459), _campaign_map_point(1665, 458), 
			_campaign_map_point(1665, 457), _campaign_map_point(1665, 456), _campaign_map_point(1665, 455), 
			_campaign_map_point(1665, 454), _campaign_map_point(1665, 453), _campaign_map_point(1665, 452), 
			_campaign_map_point(1665, 451), _campaign_map_point(1665, 450), _campaign_map_point(1665, 449), 
			_campaign_map_point(1665, 448), _campaign_map_point(1665, 447), _campaign_map_point(1665, 446), 
			_campaign_map_point(1665, 445), _campaign_map_point(1665, 444), _campaign_map_point(1665, 443), 
			_campaign_map_point(1665, 442), _campaign_map_point(1665, 441), _campaign_map_point(1665, 440), 
			_campaign_map_point(1666, 439), _campaign_map_point(1666, 438), _campaign_map_point(1666, 437), 
			_campaign_map_point(1666, 436), _campaign_map_point(1666, 435), _campaign_map_point(1666, 434), 
			_campaign_map_point(1666, 433), _campaign_map_point(1666, 432), _campaign_map_point(1666, 431), 
			_campaign_map_point(1666, 430), _campaign_map_point(1666, 429), _campaign_map_point(1666, 428), 
			_campaign_map_point(1666, 427), _campaign_map_point(1666, 426), _campaign_map_point(1666, 425), 
			_campaign_map_point(1666, 424), _campaign_map_point(1666, 423), _campaign_map_point(1666, 422), 
			_campaign_map_point(1666, 421), _campaign_map_point(1666, 420), _campaign_map_point(1666, 419), 
			_campaign_map_point(1666, 418), _campaign_map_point(1666, 417), _campaign_map_point(1666, 416), 
			_campaign_map_point(1666, 415), _campaign_map_point(1665, 414), _campaign_map_point(1665, 413), 
			_campaign_map_point(1665, 412), _campaign_map_point(1665, 411), _campaign_map_point(1665, 410), 
			_campaign_map_point(1665, 409), _campaign_map_point(1665, 408), _campaign_map_point(1665, 407), 
			_campaign_map_point(1665, 406), _campaign_map_point(1665, 405), _campaign_map_point(1665, 404), 
			_campaign_map_point(1665, 403), _campaign_map_point(1666, 402), _campaign_map_point(1666, 401), 
			_campaign_map_point(1666, 400), _campaign_map_point(1666, 399), _campaign_map_point(1666, 398), 
			_campaign_map_point(1666, 397), _campaign_map_point(1666, 396), _campaign_map_point(1666, 395), 
			_campaign_map_point(1666, 394), _campaign_map_point(1666, 393), _campaign_map_point(1666, 392), 
			_campaign_map_point(1666, 391), _campaign_map_point(1666, 390), _campaign_map_point(1666, 389), 
			_campaign_map_point(1666, 388), _campaign_map_point(1666, 387), _campaign_map_point(1666, 386), 
			_campaign_map_point(1666, 385), _campaign_map_point(1666, 384), _campaign_map_point(1666, 383), 
			_campaign_map_point(1666, 382), _campaign_map_point(1666, 381), _campaign_map_point(1666, 380), 
			_campaign_map_point(1666, 379), _campaign_map_point(1666, 378), _campaign_map_point(1666, 377), 
			_campaign_map_point(1666, 376), _campaign_map_point(1666, 375), _campaign_map_point(1666, 374), 
			_campaign_map_point(1666, 373), _campaign_map_point(1666, 372), _campaign_map_point(1666, 371), 
			_campaign_map_point(1666, 370), _campaign_map_point(1666, 369), _campaign_map_point(1666, 368), 
			_campaign_map_point(1666, 367), _campaign_map_point(1666, 366), _campaign_map_point(1666, 365), 
			_campaign_map_point(1666, 364), _campaign_map_point(1666, 363), _campaign_map_point(1666, 362), 
			_campaign_map_point(1666, 361), _campaign_map_point(1666, 360), _campaign_map_point(1666, 359), 
			_campaign_map_point(1666, 358), _campaign_map_point(1666, 357), _campaign_map_point(1666, 356), 
			_campaign_map_point(1666, 355), _campaign_map_point(1666, 354), _campaign_map_point(1666, 353), 
			_campaign_map_point(1666, 352), _campaign_map_point(1666, 351), _campaign_map_point(1666, 350), 
			_campaign_map_point(1666, 349), _campaign_map_point(1666, 348), _campaign_map_point(1666, 347), 
			_campaign_map_point(1666, 346), _campaign_map_point(1666, 345), _campaign_map_point(1666, 344), 
			_campaign_map_point(1666, 343), _campaign_map_point(1666, 342), _campaign_map_point(1666, 341), 
			_campaign_map_point(1666, 340), _campaign_map_point(1666, 339), _campaign_map_point(1666, 338), 
			_campaign_map_point(1666, 337), _campaign_map_point(1666, 336), _campaign_map_point(1666, 335), 
			_campaign_map_point(1666, 334), _campaign_map_point(1666, 333), _campaign_map_point(1666, 332), 
			_campaign_map_point(1666, 331), _campaign_map_point(1666, 330), _campaign_map_point(1666, 329), 
			_campaign_map_point(1666, 328), _campaign_map_point(1666, 327), _campaign_map_point(1666, 326), 
			_campaign_map_point(1666, 325), _campaign_map_point(1666, 324), _campaign_map_point(1666, 323), 
			_campaign_map_point(1666, 322), _campaign_map_point(1666, 321), _campaign_map_point(1666, 320), 
			_campaign_map_point(1666, 319), _campaign_map_point(1666, 318), _campaign_map_point(1666, 317), 
			_campaign_map_point(1666, 316), _campaign_map_point(1666, 315), _campaign_map_point(1666, 314), 
			_campaign_map_point(1666, 313), _campaign_map_point(1666, 312), _campaign_map_point(1666, 311), 
			_campaign_map_point(1666, 310), _campaign_map_point(1666, 309), _campaign_map_point(1666, 308), 
			_campaign_map_point(1666, 307), _campaign_map_point(1666, 306), _campaign_map_point(1666, 305), 
			_campaign_map_point(1666, 304), _campaign_map_point(1666, 303), _campaign_map_point(1666, 302), 
			_campaign_map_point(1666, 301), _campaign_map_point(1666, 300), _campaign_map_point(1666, 299), 
			_campaign_map_point(1666, 298), _campaign_map_point(1666, 297), _campaign_map_point(1666, 296), 
			_campaign_map_point(1666, 295), _campaign_map_point(1666, 294), _campaign_map_point(1666, 293), 
			_campaign_map_point(1666, 292), _campaign_map_point(1666, 291), _campaign_map_point(1666, 290), 
			_campaign_map_point(1666, 289), _campaign_map_point(1666, 288), _campaign_map_point(1666, 287), 
			_campaign_map_point(1666, 286), _campaign_map_point(1666, 285), _campaign_map_point(1666, 284), 
			_campaign_map_point(1666, 283), _campaign_map_point(1666, 282), _campaign_map_point(1666, 281), 
			_campaign_map_point(1666, 280), _campaign_map_point(1666, 279), _campaign_map_point(1666, 278), 
			_campaign_map_point(1666, 277), _campaign_map_point(1666, 276), _campaign_map_point(1666, 275), 
			_campaign_map_point(1666, 274), _campaign_map_point(1666, 273), _campaign_map_point(1666, 272), 
			_campaign_map_point(1666, 271), _campaign_map_point(1666, 270), _campaign_map_point(1666, 269), 
			_campaign_map_point(1666, 268), _campaign_map_point(1666, 267), _campaign_map_point(1666, 266), 
			_campaign_map_point(1666, 265), _campaign_map_point(1666, 264), _campaign_map_point(1666, 263), 
			_campaign_map_point(1666, 262), _campaign_map_point(1666, 261), _campaign_map_point(1666, 260), 
			_campaign_map_point(1666, 259), _campaign_map_point(1666, 258), _campaign_map_point(1666, 257), 
			_campaign_map_point(1666, 256), _campaign_map_point(1666, 255), _campaign_map_point(1666, 254), 
			_campaign_map_point(1666, 253), _campaign_map_point(1666, 252), _campaign_map_point(1666, 251), 
			_campaign_map_point(1666, 250), _campaign_map_point(1666, 249), _campaign_map_point(1666, 248), 
			_campaign_map_point(1666, 247), _campaign_map_point(1666, 246), _campaign_map_point(1666, 245), 
			_campaign_map_point(1666, 244), _campaign_map_point(1666, 243), _campaign_map_point(1666, 242), 
			_campaign_map_point(1666, 241), _campaign_map_point(1666, 240), _campaign_map_point(1666, 239), 
			_campaign_map_point(1666, 238), _campaign_map_point(1666, 237), _campaign_map_point(1666, 236), 
			_campaign_map_point(1666, 235), _campaign_map_point(1666, 234), _campaign_map_point(1660, 233), 
			_campaign_map_point(1660, 232), _campaign_map_point(1660, 231), _campaign_map_point(1660, 230), 
			_campaign_map_point(1660, 229), _campaign_map_point(1660, 228), _campaign_map_point(1660, 227), 
			_campaign_map_point(1660, 226), _campaign_map_point(1660, 225), _campaign_map_point(1660, 224), 
			_campaign_map_point(1660, 223), _campaign_map_point(1666, 222), _campaign_map_point(1666, 221), 
			_campaign_map_point(1666, 220), _campaign_map_point(1666, 219), _campaign_map_point(1663, 218), 
			_campaign_map_point(1663, 217), _campaign_map_point(1663, 216), _campaign_map_point(1663, 215), 
			_campaign_map_point(1663, 214), _campaign_map_point(1663, 213), _campaign_map_point(1663, 212), 
			_campaign_map_point(1663, 211), _campaign_map_point(1663, 210), _campaign_map_point(1662, 209), 
			_campaign_map_point(1662, 208), _campaign_map_point(1662, 207), _campaign_map_point(1662, 206), 
			_campaign_map_point(1662, 205), _campaign_map_point(1662, 204), _campaign_map_point(1662, 203), 
			_campaign_map_point(1661, 202), _campaign_map_point(1661, 201), _campaign_map_point(1661, 200), 
			_campaign_map_point(1661, 199), _campaign_map_point(1660, 198), _campaign_map_point(1660, 197), 
			_campaign_map_point(1660, 196), _campaign_map_point(1659, 195), _campaign_map_point(1659, 194), 
			_campaign_map_point(1659, 193), _campaign_map_point(1659, 192), _campaign_map_point(1658, 191), 
			_campaign_map_point(1658, 190), _campaign_map_point(1658, 189), _campaign_map_point(1657, 188), 
			_campaign_map_point(1657, 187), _campaign_map_point(1657, 186), _campaign_map_point(1656, 185), 
			_campaign_map_point(1656, 184), _campaign_map_point(1655, 183), _campaign_map_point(1655, 182), 
			_campaign_map_point(1655, 181), _campaign_map_point(1654, 180), _campaign_map_point(1654, 179), 
			_campaign_map_point(1654, 178), _campaign_map_point(1653, 177), _campaign_map_point(1653, 176), 
			_campaign_map_point(1652, 175), _campaign_map_point(1652, 174), _campaign_map_point(1651, 173), 
			_campaign_map_point(1651, 172), _campaign_map_point(1650, 171), _campaign_map_point(1650, 170), 
			_campaign_map_point(1649, 169), _campaign_map_point(1649, 168), _campaign_map_point(1648, 167), 
			_campaign_map_point(1648, 166), _campaign_map_point(1647, 165), _campaign_map_point(1647, 164), 
			_campaign_map_point(1646, 163), _campaign_map_point(1645, 162), _campaign_map_point(1645, 161), 
			_campaign_map_point(1644, 160), _campaign_map_point(1644, 159), _campaign_map_point(1643, 158), 
			_campaign_map_point(1642, 157), _campaign_map_point(1642, 156), _campaign_map_point(1641, 155), 
			_campaign_map_point(1640, 154), _campaign_map_point(1640, 153), _campaign_map_point(1639, 152), 
			_campaign_map_point(1638, 151), _campaign_map_point(1638, 150), _campaign_map_point(1637, 149), 
			_campaign_map_point(1636, 148), _campaign_map_point(1635, 147), _campaign_map_point(1634, 146), 
			_campaign_map_point(1633, 145), _campaign_map_point(1633, 144), _campaign_map_point(1632, 143), 
			_campaign_map_point(1631, 142), _campaign_map_point(1630, 141), _campaign_map_point(1630, 140), 
			_campaign_map_point(1629, 139), _campaign_map_point(1628, 138), _campaign_map_point(1627, 137), 
			_campaign_map_point(1627, 136), _campaign_map_point(1626, 135), _campaign_map_point(1625, 134), 
			_campaign_map_point(1624, 133), _campaign_map_point(1623, 132), _campaign_map_point(1622, 131), 
			_campaign_map_point(1621, 130), _campaign_map_point(1620, 129), _campaign_map_point(1619, 128), 
			_campaign_map_point(1619, 127), _campaign_map_point(1618, 126), _campaign_map_point(1617, 125), 
			_campaign_map_point(1616, 124), _campaign_map_point(1615, 123), _campaign_map_point(1614, 122), 
			_campaign_map_point(1613, 121), _campaign_map_point(1611, 120), _campaign_map_point(1610, 119), 
			_campaign_map_point(1609, 118), _campaign_map_point(1608, 117), _campaign_map_point(1607, 116), 
			_campaign_map_point(1606, 115), _campaign_map_point(1605, 114), _campaign_map_point(1604, 113), 
			_campaign_map_point(1603, 112), _campaign_map_point(1602, 111), _campaign_map_point(1601, 110), 
			_campaign_map_point(1600, 109), _campaign_map_point(1599, 108), _campaign_map_point(1598, 107), 
			_campaign_map_point(1597, 106), _campaign_map_point(1596, 105), _campaign_map_point(1595, 104), 
			_campaign_map_point(1593, 103), _campaign_map_point(1592, 102), _campaign_map_point(1591, 101), 
			_campaign_map_point(1589, 100), _campaign_map_point(1588, 99), _campaign_map_point(1587, 98), 
			_campaign_map_point(1585, 97), _campaign_map_point(1584, 96), _campaign_map_point(1583, 95), 
			_campaign_map_point(1581, 94), _campaign_map_point(1580, 93), _campaign_map_point(1579, 92), 
			_campaign_map_point(1577, 91), _campaign_map_point(1576, 90), _campaign_map_point(1574, 89), 
			_campaign_map_point(1573, 88), _campaign_map_point(1572, 87), _campaign_map_point(1570, 86), 
			_campaign_map_point(1569, 85), _campaign_map_point(1567, 84), _campaign_map_point(1566, 83), 
			_campaign_map_point(1564, 82), _campaign_map_point(1562, 81), _campaign_map_point(1561, 80), 
			_campaign_map_point(1559, 79)
		]},
	]


func _layout_campaign_map() -> void:
	if _campaign_background_rect == null or not is_instance_valid(_campaign_background_rect):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var background_size: Vector2 = _get_campaign_background_display_size()
	var background_height: float = background_size.y
	var bottom_bar_top: float = _get_campaign_bottom_bar_top(viewport_size, background_height)
	_campaign_background_rect.offset_left = 0.0
	_campaign_background_rect.offset_top = 0.0
	_campaign_background_rect.offset_right = 0.0
	_campaign_background_rect.offset_bottom = background_height
	_layout_campaign_bottom_bar(viewport_size, bottom_bar_top)
	if _campaign_room_hit_layer == null or not is_instance_valid(_campaign_room_hit_layer):
		return
	_campaign_room_hit_layer.offset_left = 0.0
	_campaign_room_hit_layer.offset_top = 0.0
	_campaign_room_hit_layer.offset_right = viewport_size.x
	_campaign_room_hit_layer.offset_bottom = background_height
	if _campaign_hover_fill != null and is_instance_valid(_campaign_hover_fill):
		_campaign_hover_fill.position = Vector2.ZERO
		_campaign_hover_fill.size = Vector2(viewport_size.x, background_height)
	_update_campaign_hover(get_viewport().get_mouse_position())


func _get_campaign_bottom_bar_top(viewport_size: Vector2, background_height: float) -> float:
	var natural_top: float = clampf(background_height, 0.0, viewport_size.y)
	if viewport_size.y - natural_top >= CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT:
		return natural_top
	return maxf(0.0, viewport_size.y - CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT)


func _layout_campaign_bottom_bar(viewport_size: Vector2, top: float) -> void:
	if _campaign_bottom_bar == null or not is_instance_valid(_campaign_bottom_bar):
		return
	_campaign_bottom_bar.offset_left = 0.0
	_campaign_bottom_bar.offset_top = top
	_campaign_bottom_bar.offset_right = viewport_size.x
	_campaign_bottom_bar.offset_bottom = viewport_size.y


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_campaign_map")


func _process(_delta: float) -> void:
	_update_campaign_hover(get_viewport().get_mouse_position())


func _campaign_room_input_is_blocked() -> bool:
	if _creation_overlay != null and is_instance_valid(_creation_overlay):
		return true
	if _god_overlay != null and is_instance_valid(_god_overlay):
		return true
	if _dialog_overlay != null and is_instance_valid(_dialog_overlay):
		return true
	if _menu_popup != null and is_instance_valid(_menu_popup) and _menu_popup.visible:
		return true
	return false


func _campaign_click_hits_real_button() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		if _roster_grid != null and is_instance_valid(_roster_grid) and (_roster_grid == hovered or _roster_grid.is_ancestor_of(hovered)):
			return true
		if hovered is Button:
			if _campaign_room_hit_layer != null and is_instance_valid(_campaign_room_hit_layer) and _campaign_room_hit_layer.is_ancestor_of(hovered):
				return false
			return true
		hovered = hovered.get_parent() as Control
	return false

func _campaign_section_at_position(position: Vector2) -> String:
	var room: Dictionary = _campaign_room_at_position(position)
	if room.is_empty():
		return ""
	return str(room["section"])


func _campaign_room_at_position(position: Vector2) -> Dictionary:
	var bg_size: Vector2 = _get_campaign_background_display_size()
	if position.x < 0.0 or position.y < 0.0 or position.x > bg_size.x or position.y > bg_size.y:
		return {}
	for room in _campaign_room_defs():
		var polygon: PackedVector2Array = _campaign_room_polygon(room, bg_size)
		if _campaign_point_in_polygon(position, polygon):
			return {"section": str(room["section"]), "rect": _campaign_polygon_bounds(polygon), "polygon": polygon, "mask": str(room.get("mask", ""))}
	return {}


func _campaign_room_polygon(room: Dictionary, bg_size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var source_points: Array = room["points"]
	for source_point in source_points:
		var normalized_point: Vector2 = source_point
		points.append(Vector2(normalized_point.x * bg_size.x, normalized_point.y * bg_size.y))
	return points


func _campaign_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_pos: Vector2 = polygon[0]
	var max_pos: Vector2 = polygon[0]
	for point in polygon:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	return Rect2(min_pos, max_pos - min_pos)


func _campaign_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j: int = polygon.size() - 1
	for i in range(polygon.size()):
		var current: Vector2 = polygon[i]
		var previous: Vector2 = polygon[j]
		var crosses_y: bool = (current.y > point.y) != (previous.y > point.y)
		if crosses_y:
			var edge_x: float = (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
			if point.x < edge_x:
				inside = not inside
		j = i
	return inside


func _update_campaign_hover(position: Vector2) -> void:
	if _campaign_room_hit_layer == null or not is_instance_valid(_campaign_room_hit_layer):
		return
	if _campaign_hover_fill == null or not is_instance_valid(_campaign_hover_fill):
		return
	if _campaign_hover_label == null or not is_instance_valid(_campaign_hover_label):
		return
	if _campaign_room_input_is_blocked() or _campaign_click_hits_real_button():
		_clear_campaign_hover()
		return
	var room: Dictionary = _campaign_room_at_position(position)
	if room.is_empty():
		_clear_campaign_hover()
		return
	var section: String = str(room["section"])
	var pixel_rect: Rect2 = room["rect"]
	_campaign_hover_section = section
	_campaign_hover_fill.visible = true
	_campaign_hover_fill.texture = load(str(room.get("mask", ""))) as Texture2D
	_campaign_hover_label.visible = true
	_campaign_hover_label.text = section
	var label_width: float = clamp(pixel_rect.size.x, 180.0, 420.0)
	var label_size := Vector2(label_width, 44.0)
	_campaign_hover_label.size = label_size
	_campaign_hover_label.position = Vector2(
		pixel_rect.position.x + (pixel_rect.size.x - label_size.x) * 0.5,
		max(8.0, pixel_rect.position.y + 18.0)
	)


func _clear_campaign_hover() -> void:
	_campaign_hover_section = ""
	if _campaign_hover_fill != null and is_instance_valid(_campaign_hover_fill):
		_campaign_hover_fill.visible = false
	if _campaign_hover_label != null and is_instance_valid(_campaign_hover_label):
		_campaign_hover_label.visible = false


func _get_campaign_background_display_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if _campaign_background_rect == null or not is_instance_valid(_campaign_background_rect):
		return viewport_size
	var texture := _campaign_background_rect.texture
	if texture == null or texture.get_size().x <= 0.0:
		return viewport_size
	var tex_size := texture.get_size()
	return Vector2(viewport_size.x, viewport_size.x * tex_size.y / tex_size.x)

## Полоса ресурсов в нижней панели: 5 эссенций + мысли.
## Каждая пара — иконка слева, количество справа.
func _build_currency_bar(parent: Node) -> void:
	_currency_amount_labels.clear()
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 22)
	parent.add_child(bar)
	for path in _CURRENCY_PATHS:
		var res = load(path)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if res and res.icon:
			icon.texture = res.icon
		pair.add_child(icon)
		var amt := Label.new()
		amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amt.add_theme_font_size_override("font_size", 20)
		if res:
			amt.text = str(CampaignState.get_currency_amount(path))
			amt.tooltip_text = res.name
		else:
			amt.text = "0"
		pair.add_child(amt)
		_currency_amount_labels.append(amt)
		bar.add_child(pair)

## Обновить отображаемые количества (вызвать после изменения amount ресурса).
func _refresh_currencies() -> void:
	for i in range(_CURRENCY_PATHS.size()):
		if i >= _currency_amount_labels.size():
			break
		var res = load(_CURRENCY_PATHS[i])
		if res:
			_currency_amount_labels[i].text = str(CampaignState.get_currency_amount(_CURRENCY_PATHS[i]))
	_refresh_pages()


func _refresh_pages() -> void:
	if _campaign_pages_label == null or not is_instance_valid(_campaign_pages_label):
		return
	_campaign_pages_label.text = str(CampaignState.get_pages())


# ════════════════════════════════════════════════════════════
#  Ростер богов (2 ряда по 8 квадратов)
# ════════════════════════════════════════════════════════════

## Создаёт сетку 1×16 квадратов и подключает слоты.
func _build_god_roster(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", 6)
	box.z_index = ROSTER_Z_INDEX
	parent.add_child(box)


	_roster_grid = GridContainer.new()
	_roster_grid.z_index = ROSTER_Z_INDEX
	_roster_grid.columns = ROSTER_COLUMNS
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)

	# Ряд: портреты богов + кнопка «Артефакты» справа от них.
	var roster_row := HBoxContainer.new()
	roster_row.z_index = ROSTER_Z_INDEX
	roster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	roster_row.add_theme_constant_override("separation", 16)
	roster_row.add_child(_roster_grid)
	var artifacts_btn := Button.new()
	artifacts_btn.text = "Артефакты"
	artifacts_btn.custom_minimum_size = Vector2(160, 64)
	artifacts_btn.add_theme_font_size_override("font_size", 18)
	artifacts_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	artifacts_btn.pressed.connect(_select_tab.bind(TAB_TREASURY))
	roster_row.add_child(artifacts_btn)
	box.add_child(roster_row)

	var total := ROSTER_COLUMNS * ROSTER_ROWS
	_roster_order.resize(total)
	for i in range(total):
		_roster_order[i] = ""
		var slot := _RosterSlot.new()
		slot.slot_index = i
		slot.god_double_clicked.connect(_show_god_detail)
		slot.god_dialogue_requested.connect(_on_god_dialogue_requested)
		slot.swap_requested.connect(_on_roster_swap)
		_roster_slots.append(slot)
		_roster_grid.add_child(slot)

## Синхронизирует расположение с CampaignState.available_gods:
## убирает пропавших богов, добавляет новых в первые свободные квадраты.
func _refresh_roster() -> void:
	if _roster_slots.is_empty():
		return
	var avail: Array = CampaignState.available_gods
	# Убираем богов, которых больше нет в доступных.
	for i in range(_roster_order.size()):
		if _roster_order[i] != "" and not avail.has(_roster_order[i]):
			_roster_order[i] = ""
	# Добавляем новых доступных богов в первые свободные квадраты.
	for god_path in avail:
		if god_path == "" or _roster_order.has(god_path):
			continue
		var free_idx := _roster_order.find("")
		if free_idx < 0:
			break
		_roster_order[free_idx] = god_path
	# Перерисовываем слоты.
	for i in range(_roster_slots.size()):
		if _roster_slots[i]:
			_roster_slots[i].set_god(_roster_order[i])

## Перетаскивание портрета из одного квадрата в другой — меняем их местами.
func _on_roster_swap(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= _roster_order.size():
		return
	if to_index < 0 or to_index >= _roster_order.size():
		return
	var tmp: String = _roster_order[from_index]
	_roster_order[from_index] = _roster_order[to_index]
	_roster_order[to_index] = tmp
	_refresh_roster()

func _on_god_dialogue_requested(god_path: String) -> void:
	if god_path.strip_edges() == "":
		return
	var god_res := CampaignState.load_character_resource(god_path)
	if god_res == null:
		return
	var dialogue_path := _campaign_dialogue_path_for_god(god_path, god_res)
	if dialogue_path == "":
		push_warning("Диалог бога не найден: " + god_res.unit_name)
		return
	DialogueManager.show_dialogue_path(dialogue_path)


func _campaign_dialogue_path_for_god(god_path: String, god_res: CharacterResource) -> String:
	if god_res != null:
		var explicit_path := god_res.campaign_dialogue_path.strip_edges()
		if explicit_path != "" and ResourceLoader.exists(explicit_path):
			return explicit_path
	var folder_name := god_path.get_base_dir().get_file().strip_edges()
	if folder_name == "":
		return ""
	var dialogue_candidates: Array[String] = [
		"%s/%s_dialogue_1.tres" % [SUMMON_DIALOGUE_DIR, folder_name],
		"%s/%s_dialogue_1.tres" % [SUMMON_DIALOGUE_DIR, folder_name.to_lower()],
	]
	for dialogue_path in dialogue_candidates:
		if ResourceLoader.exists(dialogue_path):
			return dialogue_path
	return ""
# ════════════════════════════════════════════════════════════
#  Переключение вкладок
# ════════════════════════════════════════════════════════════

## Кнопка-раздел кампании (Ворота, Колодец памяти, и т.д.).
## Пока показывает заглушку; механики разделов добавляются позже.
func _on_section_button(section: String) -> void:
	if section == "Ворота":
		get_tree().change_scene_to_file("res://Doors/doors.tscn")
		return
	if section == "Сад творения":
		_show_creation_window()
		return
	for child in _content_grid.get_children():
		child.queue_free()
	var hint := Label.new()
	hint.text = "«%s» — раздел в разработке." % section
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	_content_grid.add_child(hint)


func _select_tab(tab: int) -> void:
	# Подсветка активной вкладки (disabled = нажата).
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].disabled = (i == tab)

	# Очистка содержимого.
	for child in _content_grid.get_children():
		child.queue_free()

	# Заполнение в зависимости от вкладки.
	match tab:
		TAB_GODS:
			_populate_gods()
		TAB_TREASURY:
			_populate_treasury()
		TAB_MISSIONS:
			_populate_missions()


# ════════════════════════════════════════════════════════════
#  Заполнение вкладок из CampaignState
# ════════════════════════════════════════════════════════════

func _populate_gods() -> void:
	var paths := CampaignState.available_gods
	if paths.is_empty():
		_content_grid.add_child(_make_placeholder("Боги ещё не открыты"))
		return
	for path in paths:
		_content_grid.add_child(_make_god_card(path))


func _populate_treasury() -> void:
	var paths := CampaignState.treasury
	if paths.is_empty():
		_content_grid.add_child(_make_placeholder("Сокровищница пуста"))
		return
	for path in paths:
		_content_grid.add_child(_make_item_card(path))


func _populate_missions() -> void:
	var paths := CampaignState.available_missions
	if paths.is_empty():
		_content_grid.add_child(_make_placeholder("Нет доступных миссий"))
		return
	for path in paths:
		_content_grid.add_child(_make_mission_card(path))


# ════════════════════════════════════════════════════════════
#  Фабрики карточек
# ════════════════════════════════════════════════════════════

func _make_placeholder(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	# Растягиваем на всю ширину грида.
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_god_card(path: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var res := CampaignState.load_character_resource(path)
	var display_name := "Без имени"
	if res != null and res.unit_name != "":
		display_name = res.unit_name
	if res != null and res.is_dead:
		display_name += "\n☠ Мёртв"

	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	# Уровень забвения (если есть).
	if res != null and res.forgetting_level > 0.0:
		var fade_lbl := Label.new()
		fade_lbl.text = "Забвение: %.1f / 5.0" % res.forgetting_level
		fade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fade_lbl.add_theme_font_size_override("font_size", 14)
		fade_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		vb.add_child(fade_lbl)

	# Двойной клик открывает страницу бога.
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_show_god_detail(path)
	)

	return panel


func _make_item_card(path: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 140)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var res := load(path) as ItemResource
	var display_name := "Предмет"
	if res != null and res.item_name != "":
		display_name = res.item_name

	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	return panel


func _make_mission_card(path: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var res := load(path) as MissionResource
	var display_name := path
	if res != null and res.mission_name != "":
		display_name = res.mission_name

	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_launch_mission_from_path(path)
	)

	return panel

func _launch_mission_from_path(path: String) -> void:
	if path.strip_edges() == "" or not ResourceLoader.exists(path):
		push_warning("Не найдена миссия: " + path)
		return
	MissionState.requested_mission_path = path
	MissionState.return_scene_path = "res://Campaign/campaign_screen.tscn"
	get_tree().change_scene_to_file("res://Missions/mission_select.tscn")

#  Навигация
# ════════════════════════════════════════════════════════════

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")


# ════════════════════════════════════════════════════════════
#  Меню (верхний левый угол)
# ════════════════════════════════════════════════════════════

func _build_menu() -> void:
	_menu_button = Button.new()
	_menu_button.text = "☰ Меню"
	_menu_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_menu_button.offset_left = 10
	_menu_button.offset_top = 10
	_menu_button.custom_minimum_size = Vector2(120, 44)
	_menu_button.add_theme_font_size_override("font_size", 18)
	_menu_button.pressed.connect(_show_menu_popup)
	add_child(_menu_button)


func _show_menu_popup() -> void:
	if _menu_popup != null and is_instance_valid(_menu_popup):
		_menu_popup.queue_free()
	_menu_popup = PopupPanel.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	for entry in [
		{"text": "Продолжить", "action": _menu_continue},
		{"text": "Сохранить", "action": _menu_save},
		{"text": "Загрузить", "action": _menu_load},
		{"text": "Настройки", "action": _menu_settings},
		{"text": "Выход", "action": _menu_exit},
	]:
		var btn := Button.new()
		btn.text = entry["text"]
		btn.custom_minimum_size = Vector2(200, 44)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(entry["action"])
		vb.add_child(btn)

	_menu_popup.add_child(vb)
	add_child(_menu_popup)
	var btn_rect := _menu_button.get_global_rect()
	_menu_popup.position = Vector2(btn_rect.position.x, btn_rect.position.y + btn_rect.size.y + 4)
	_menu_popup.popup()


## Правый щелчок мыши закрывает всплывающее меню и страницу бога.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _campaign_room_input_is_blocked():
			var section := _campaign_section_at_position(event.position)
			if section != "":
				var viewport := get_viewport()
				_on_section_button(section)
				if viewport != null:
					viewport.set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _menu_popup != null and is_instance_valid(_menu_popup) and _menu_popup.visible:
			_menu_popup.hide()
		if _dialog_overlay != null and is_instance_valid(_dialog_overlay):
			_close_dialog()
		# Страница бога закрывается правым кликом в любом месте — см. _input() ниже.


## Правый щелчок закрывает страницу бога ВЕЗДЕ (в т.ч. по контенту панели):
## дочерние элементы поглощают событие, поэтому gui_input панели его не получает.
## _input срабатывает до обработки GUI и ловит клик над любым элементом оверлея.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _campaign_room_input_is_blocked() and not _campaign_click_hits_real_button():
			var section := _campaign_section_at_position(event.position)
			if section != "":
				var viewport := get_viewport()
				_on_section_button(section)
				if viewport != null:
					viewport.set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _creation_overlay != null and is_instance_valid(_creation_overlay):
			_close_creation_window()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		elif _god_overlay != null and is_instance_valid(_god_overlay):
			_close_god_detail()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()


# === Сад творения (создание богов из двух эссенций) ===

## Открывает окно Сада творения: 2 слота эссенций, место спрайта бога, кнопка «Создать».
func _show_creation_window() -> void:
	_close_creation_window()
	_creation_slots = ["", ""]
	_creation_overlay = Control.new()
	_creation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_creation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_creation_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_creation_bg_input)
	_creation_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_creation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 12)
	margin.add_child(main_vb)

	var title := Label.new()
	title.text = "Сад творения"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	main_vb.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vb.add_child(row)

	var hint := Label.new()
	hint.text = "Нажмите на квадрат, чтобы выбрать эссенцию"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	main_vb.add_child(hint)

	# Слева: два слота эссенций.
	var slots_col := VBoxContainer.new()
	slots_col.add_theme_constant_override("separation", 16)
	slots_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_creation_slot_icons.clear()
	_creation_slot_hints.clear()
	for i in range(2):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(100, 100)
		slot.gui_input.connect(_on_creation_slot_input.bind(i))
		# Видимая рамка-квадрат.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.2, 0.8)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.7, 0.7, 0.7, 1.0)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		slot.add_theme_stylebox_override("panel", sb)
		var tex := TextureRect.new()
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)
		# Знак «?» — виден, пока эссенция не выбрана.
		var qmark := Label.new()
		qmark.set_anchors_preset(Control.PRESET_FULL_RECT)
		qmark.text = "?"
		qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		qmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qmark.add_theme_font_size_override("font_size", 36)
		slot.add_child(qmark)
		_creation_slot_icons.append(tex)
		_creation_slot_hints.append(qmark)
		slots_col.add_child(slot)
	row.add_child(slots_col)

	# Справа: место спрайта бога + имя + кнопка «Создать».
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creation_sprite = TextureRect.new()
	_creation_sprite.custom_minimum_size = Vector2(180, 240)
	_creation_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_creation_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_col.add_child(_creation_sprite)
	_creation_name_label = Label.new()
	_creation_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_creation_name_label.add_theme_font_size_override("font_size", 22)
	right_col.add_child(_creation_name_label)
	_creation_create_btn = Button.new()
	_creation_create_btn.text = "Создать"
	_creation_create_btn.custom_minimum_size = Vector2(200, 50)
	_creation_create_btn.add_theme_font_size_override("font_size", 20)
	_creation_create_btn.disabled = true
	_creation_create_btn.pressed.connect(_on_create_pressed)
	right_col.add_child(_creation_create_btn)
	row.add_child(right_col)

	_build_creation_popup()
	_update_creation_view()


## Клик по тёмному фону — закрыть окно.
func _on_creation_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_creation_window()


## Закрывает окно Сада творения.
func _close_creation_window() -> void:
	if _creation_popup != null and is_instance_valid(_creation_popup):
		_creation_popup.queue_free()
		_creation_popup = null
	if _creation_overlay != null and is_instance_valid(_creation_overlay):
		_creation_overlay.queue_free()
		_creation_overlay = null


## Строит попап выбора эссенции (5 кнопок с текущим количеством).
func _build_creation_popup() -> void:
	if _creation_popup != null and is_instance_valid(_creation_popup):
		_creation_popup.queue_free()
	_creation_popup = PopupPanel.new()
	add_child(_creation_popup)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_creation_popup.add_child(hbox)
	for ename in CREATION_ESSENCES.keys():
		var res = load(CREATION_ESSENCES[ename])
		var btn := Button.new()
		btn.text = ename
		btn.tooltip_text = "Количество: %d" % [CampaignState.get_currency_amount(str(CREATION_ESSENCES[ename])) if res != null else 0]
		btn.custom_minimum_size = Vector2(96, 64)
		btn.pressed.connect(_on_essence_chosen.bind(ename))
		hbox.add_child(btn)


## Клик по слоту эссенции — открыть попап выбора для этого слота.
func _on_creation_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_creation_active_slot = slot_index
		if _creation_popup != null and is_instance_valid(_creation_popup):
			var slot_node = _creation_slot_icons[slot_index].get_parent()
			_creation_popup.position = slot_node.global_position + Vector2(slot_node.size.x + 8, 0)
			_creation_popup.popup()


## Выбор эссенции в попапе.
func _on_essence_chosen(essence_name: String) -> void:
	if _creation_active_slot < _creation_slots.size():
		_creation_slots[_creation_active_slot] = essence_name
	if _creation_popup != null and is_instance_valid(_creation_popup):
		_creation_popup.hide()
	_update_creation_view()


## Ключ рецепта: две эссенции по алфавиту через «|».
func _creation_key(a: String, b: String) -> String:
	var arr := [a, b]
	arr.sort()
	return "%s|%s" % [arr[0], arr[1]]


## Путь к богу по текущей паре эссенций (или "").
func _creation_result_god() -> String:
	if _creation_slots.size() < 2 or _creation_slots[0] == "" or _creation_slots[1] == "":
		return ""
	return CREATION_RECIPES.get(_creation_key(_creation_slots[0], _creation_slots[1]), "")


## Достаточно ли эссенций для создания?
func _has_enough_essences() -> bool:
	if _creation_slots.size() < 2:
		return false
	var a: String = _creation_slots[0]
	var b: String = _creation_slots[1]
	if not CREATION_ESSENCES.has(a) or not CREATION_ESSENCES.has(b):
		return false
	var pa := str(CREATION_ESSENCES[a])
	var pb := str(CREATION_ESSENCES[b])
	if a == b:
		return CampaignState.get_currency_amount(pa) >= 2
	return CampaignState.get_currency_amount(pa) >= 1 and CampaignState.get_currency_amount(pb) >= 1


## Обновить иконки слотов, превью бога и состояние кнопки «Создать».
func _update_creation_view() -> void:
	for i in range(_creation_slot_icons.size()):
		var ename: String = _creation_slots[i] if i < _creation_slots.size() else ""
		var tex: Texture2D = null
		if ename != "":
			var res = load(CREATION_ESSENCES[ename])
			if res != null and res.icon != null:
				tex = res.icon
		_creation_slot_icons[i].texture = tex
		if i < _creation_slot_hints.size():
			_creation_slot_hints[i].visible = (tex == null)
	var god_path := _creation_result_god()
	if god_path == "":
		_creation_sprite.texture = null
		_creation_name_label.text = ""
	else:
		var gres := CampaignState.load_character_resource(god_path)
		if gres != null:
			var t: Texture2D = null
			if gres.face_sprite != "":
				t = load(gres.face_sprite) as Texture2D
			if t == null and gres.sprite_path != "":
				t = load(gres.sprite_path) as Texture2D
			_creation_sprite.texture = t
			_creation_name_label.text = gres.unit_name
	_apply_create_button_state(god_path)


## Включает/выключает «Создать» и задаёт всплывающую подсказку.
func _apply_create_button_state(god_path: String) -> void:
	if god_path == "":
		_creation_create_btn.disabled = true
		_creation_create_btn.tooltip_text = "Выберите две эссенции"
		return
	if CampaignState.available_gods.has(god_path):
		_creation_create_btn.disabled = true
		_creation_create_btn.tooltip_text = "Вы уже сотворили этого бога"
		return
	if not _has_enough_essences():
		_creation_create_btn.disabled = true
		_creation_create_btn.tooltip_text = "Недостаточно эссенций"
		return
	_creation_create_btn.disabled = false
	_creation_create_btn.tooltip_text = ""


## Создать бога: вычесть по 1 эссенции каждого выбранного типа, добавить бога, обновить UI.
func _on_create_pressed() -> void:
	var god_path := _creation_result_god()
	if god_path == "" or CampaignState.available_gods.has(god_path):
		return
	if not _has_enough_essences():
		return
	var costs: Dictionary = {}
	var first_path := str(CREATION_ESSENCES[_creation_slots[0]])
	var second_path := str(CREATION_ESSENCES[_creation_slots[1]])
	costs[first_path] = int(costs.get(first_path, 0)) + 1
	costs[second_path] = int(costs.get(second_path, 0)) + 1
	if not CampaignState.spend_currency_amounts(costs):
		return
	CampaignState.add_god(god_path)
	CampaignState.set_god_creation_essences(god_path, [first_path, second_path])
	_build_creation_popup()
	_update_creation_view()
	_refresh_currencies()
	_play_summon_dialogue_for_god(god_path)


func _play_summon_dialogue_for_god(god_path: String) -> void:
	var dialogue_path := _summon_dialogue_path_for_god(god_path)
	if dialogue_path == "" or not ResourceLoader.exists(dialogue_path):
		return
	DialogueManager.show_dialogue_path(dialogue_path)


func _summon_dialogue_path_for_god(god_path: String) -> String:
	var folder_name := god_path.get_base_dir().get_file()
	if folder_name.strip_edges() == "":
		return ""
	return "%s/%s_summon.tres" % [SUMMON_DIALOGUE_DIR, folder_name]

# ════════════════════════════════════════════════════════════
#  Действия меню
# ════════════════════════════════════════════════════════════

func _menu_continue() -> void:
	_hide_menu_popup()


func _menu_save() -> void:
	_hide_menu_popup()
	_show_save_dialog()


func _menu_load() -> void:
	_hide_menu_popup()
	_show_load_dialog()


func _menu_settings() -> void:
	_hide_menu_popup()
	# Пока пусто — заглушка для будущих настроек.


func _menu_exit() -> void:
	_hide_menu_popup()
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _hide_menu_popup() -> void:
	if _menu_popup != null and is_instance_valid(_menu_popup):
		_menu_popup.hide()


# ════════════════════════════════════════════════════════════
#  Диалог сохранения
# ════════════════════════════════════════════════════════════

func _show_save_dialog() -> void:
	_close_dialog()
	_dialog_overlay = _make_overlay()

	var panel := _make_centered_panel("Сохранить кампанию", Vector2(400, 200))

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Введите название сохранения"
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.custom_minimum_size = Vector2(360, 44)
	panel.add_child(name_edit)

	var status_label := Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(status_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)

	var save_btn := Button.new()
	save_btn.text = "Сохранить"
	save_btn.custom_minimum_size = Vector2(140, 44)
	save_btn.add_theme_font_size_override("font_size", 18)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)

	btn_row.add_child(save_btn)
	btn_row.add_child(cancel_btn)
	panel.add_child(btn_row)

	save_btn.pressed.connect(func():
		var slot := name_edit.text.strip_edges()
		if slot == "":
			status_label.text = "Введите название!"
			status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
			return
		var ok := SaveSystem.save_game(slot)
		if ok:
			_close_dialog()
			_show_notification("Игра сохранена")
		else:
			status_label.text = "Ошибка сохранения!"
			status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	)
	cancel_btn.pressed.connect(_close_dialog)

	add_child(_dialog_overlay)
	name_edit.grab_focus()


# ════════════════════════════════════════════════════════════
#  Диалог загрузки
# ════════════════════════════════════════════════════════════

func _show_load_dialog() -> void:
	_close_dialog()
	_dialog_overlay = _make_overlay()

	var panel := _make_centered_panel("Загрузить кампанию", Vector2(500, 400))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(460, 280)
	panel.add_child(scroll)

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

			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.custom_minimum_size = Vector2(40, 50)

			row.add_child(info_btn)
			row.add_child(load_btn)
			row.add_child(del_btn)
			list.add_child(row)

			var slot_name: String = slot_info["slot"]
			load_btn.pressed.connect(func():
				var ok := SaveSystem.load_game(slot_name)
				if ok:
					_close_dialog()
					# Обновляем текущую вкладку.
					_select_tab(_current_tab_index())
				else:
					push_warning("Не удалось загрузить: " + slot_name)
			)
			info_btn.pressed.connect(load_btn.pressed.emit)
			del_btn.pressed.connect(func():
				SaveSystem.delete_save(slot_name)
				_close_dialog()
				_show_load_dialog()
			)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(_close_dialog)
	panel.add_child(cancel_btn)

	add_child(_dialog_overlay)


# ════════════════════════════════════════════════════════════
#  Вспомогательные методы для диалогов
# ════════════════════════════════════════════════════════════

## Определяет индекс текущей активной вкладки.
func _current_tab_index() -> int:
	for i in range(_tab_buttons.size()):
		if _tab_buttons[i].disabled:
			return i
	return TAB_GODS


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

func _show_god_detail(god_path: String) -> void:
	_close_god_detail()
	_current_god_path = god_path
	_current_god_res = CampaignState.load_character_resource(god_path)
	if _current_god_res == null:
		return

	var vp_size := get_viewport().get_visible_rect().size

	_god_overlay = Control.new()
	_god_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_god_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dark_bg := ColorRect.new()
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0, 0, 0, 0.75)
	# Любой клик по тёмному фону (вне панели) закрывает страницу.
	dark_bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_god_detail()
	)
	_god_overlay.add_child(dark_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE — клики мимо панели проходят сквозь к dark_bg и закрывают страницу.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_god_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(vp_size.x * 0.8, vp_size.y * 0.8)
	# Правый клик по панели тоже закрывает страницу.
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_close_god_detail()
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var main_hb := HBoxContainer.new()
	main_hb.add_theme_constant_override("separation", 16)
	margin.add_child(main_hb)

	# Левая колонка: статы + умения.
	main_hb.add_child(_build_god_left_column())

	# Центральная колонка: спрайт + полоски + экипировка.
	var center_col := _build_god_center_column()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hb.add_child(center_col)

	# Правая колонка: инвентарь (скрыт по умолчанию).
	_inventory_side = VBoxContainer.new()
	_inventory_side.custom_minimum_size = Vector2(220, 0)
	_inventory_side.visible = false
	main_hb.add_child(_inventory_side)

	add_child(_god_overlay)


# ── Левая колонка ──

func _build_god_left_column() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	var res := _current_god_res

	var title := Label.new()
	title.text = res.unit_name
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	if res.is_dead:
		var dead_lbl := Label.new()
		dead_lbl.text = "☠ Мёртв"
		dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		dead_lbl.add_theme_font_size_override("font_size", 18)
		vb.add_child(dead_lbl)

	vb.add_child(HSeparator.new())

	var stats_title := Label.new()
	stats_title.text = "Характеристики"
	stats_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(stats_title)

	vb.add_child(_make_stat_icon_row("health", "%d" % res.max_hp))
	vb.add_child(_make_stat_icon_row("attack", "%d" % res.damage))
	vb.add_child(_make_stat_icon_row("armor", "%d" % res.armor))
	vb.add_child(_make_stat_icon_row("initiative", "%d" % res.initiative))
	vb.add_child(_make_stat_icon_row("accuracy", "%d" % res.accuracy))
	vb.add_child(_make_stat_icon_row("evasion", "%d" % res.evasion))
	vb.add_child(_make_stat_icon_row("luck", "%d%%" % int(res.crit_chance * 100)))

	var fade_mult := res.get_forgetting_multiplier()
	if fade_mult < 1.0:
		var penalty := Label.new()
		penalty.text = "Штраф забвения: −%d%%" % int((1.0 - fade_mult) * 100)
		penalty.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		penalty.add_theme_font_size_override("font_size", 14)
		vb.add_child(penalty)

	vb.add_child(HSeparator.new())

	var abilities_title := Label.new()
	abilities_title.text = "Умения"
	abilities_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(abilities_title)

	for ability in res.active_abilities:
		vb.add_child(_make_ability_button(ability))

	if res.ultimate_ability != null:
		var ult_lbl := Label.new()
		ult_lbl.text = "Ультимативное:"
		ult_lbl.add_theme_font_size_override("font_size", 14)
		ult_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
		vb.add_child(ult_lbl)
		vb.add_child(_make_ability_button(res.ultimate_ability))

	return scroll


func _make_ability_button(ability: AbilityResource) -> Button:
	var btn: Button = STAT_ICON_TOOLTIP_BUTTON_SCRIPT.new()
	var icon := ability.get_icon_texture()
	btn.icon = icon
	btn.text = "" if icon != null else ability.name
	btn.add_theme_font_size_override("font_size", 15)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER if icon != null else HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = _ABILITY_ICON_BUTTON_SIZE if icon != null else Vector2(0, 36)
	btn.size = _ABILITY_ICON_BUTTON_SIZE if icon != null else btn.size
	btn.expand_icon = icon != null
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.clip_text = true
	# Тултип всплывает при наведении — так же, как в бою.
	btn.tooltip_text = _format_ability_tooltip(ability)
	btn.rich_tooltip_text = btn.tooltip_text
	return btn


## Формирует подробный текст тултипа умения (аналогично боевому _get_ability_tooltip).
func _format_ability_tooltip(ability: AbilityResource) -> String:
	var lines: Array[String] = []
	lines.append("=== %s ===" % ability.name)
	if ability.description != "":
		lines.append(ability.description)
		lines.append("")
	if ability.damage_modifier > 0:
		lines.append("Урон: %d%% от базового" % int(ability.damage_modifier * 100))
		if ability.damage_type != "" and ability.damage_type != "Physical":
			lines.append("Тип урона: %s" % ability.damage_type)
	if ability.majesty_cost > 0:
		lines.append("Стоимость: %d величия" % ability.majesty_cost)
	if ability.majesty_gain > 0:
		lines.append("Величие: +%d" % ability.majesty_gain)
	var _target_ru := {
		"Enemy": "Враг", "Ally": "Союзник", "Self": "Себя",
		"All_Enemies": "Все враги", "All_Allies": "Все союзники",
		"Position": "Позиция"
	}
	if ability.target_type != "":
		lines.append("Цель: %s" % _target_ru.get(ability.target_type, ability.target_type))
	if ability.extra_targets_count > 0:
		lines.append("Доп. цели: +%d позади" % ability.extra_targets_count)
	if ability.effect_types.size() > 0:
		lines.append("")
		lines.append("Эффекты:")
		for effect in ability.effect_types:
			var dur: int = ability.effect_durations.get(effect, 1)
			var dur_text := "бесконечно" if dur == -1 else "%d ход." % dur
			lines.append("  • %s [%s]" % [effect, dur_text])
	if ability.is_stance:
		lines.append("")
		lines.append("★ Стойка (%s)" % ability.stance_duration_type)
	if ability.condition != "":
		lines.append("")
		lines.append("Условие: %s" % ability.condition)
	var pos_from: Array[String] = []
	for i in range(ability.usable_from_positions.size()):
		if ability.usable_from_positions[i]:
			pos_from.append(str(i + 1))
	if pos_from.size() > 0 and pos_from.size() < 4:
		lines.append("Доступно с линий: %s" % " / ".join(pos_from))
	return "\n".join(lines)


# ── Центральная колонка ──

func _build_god_center_column() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER

	var res := _current_god_res

	# Спрайт.
	if res.sprite_path != "":
		var tex := load(res.sprite_path) as Texture2D
		if tex != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(300, 300)
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vb.add_child(tex_rect)

	# Полоска здоровья.
	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = res.max_hp
	hp_bar.value = res.max_hp
	hp_bar.custom_minimum_size = Vector2(300, 26)
	hp_bar.show_percentage = false
	vb.add_child(_make_bar_with_label("HP", hp_bar, "%d / %d" % [res.max_hp, res.max_hp], Color(0.3, 0.8, 0.3)))

	# Полоска забвения.
	var fade_bar := ProgressBar.new()
	fade_bar.min_value = 0
	fade_bar.max_value = 5.0
	fade_bar.value = res.forgetting_level
	fade_bar.custom_minimum_size = Vector2(300, 26)
	fade_bar.show_percentage = false
	vb.add_child(_make_bar_with_label("Забвение", fade_bar, "%.1f / 5.0" % res.forgetting_level, Color(0.9, 0.5, 0.3)))

	vb.add_child(HSeparator.new())

	# Слоты экипировки.
	var equip_title := Label.new()
	equip_title.text = "Экипировка"
	equip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(equip_title)

	var equip_row := HBoxContainer.new()
	equip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_row.add_theme_constant_override("separation", 12)
	vb.add_child(equip_row)

	for slot_info in [
		{"type": 0, "label": "Оружие", "item": res.equipped_weapon},
		{"type": 1, "label": "Броня", "item": res.equipped_armor},
		{"type": 2, "label": "Безделушка", "item": res.equipped_trinket},
	]:
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(120, 60)
		slot_btn.add_theme_font_size_override("font_size", 14)
		var item: ItemResource = slot_info["item"]
		if item != null:
			slot_btn.text = "%s\n%s" % [slot_info["label"], item.item_name]
		else:
			slot_btn.text = "%s\n— пусто —" % slot_info["label"]
		slot_btn.pressed.connect(_on_equipment_slot_pressed.bind(slot_info["type"]))
		equip_row.add_child(slot_btn)

	return vb


func _make_bar_with_label(label_text: String, bar: ProgressBar, value_text: String, color: Color) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)

	var hb := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", 14)
	hb.add_child(val_lbl)
	wrapper.add_child(hb)

	bar.modulate = color
	wrapper.add_child(bar)

	return wrapper


# ── Инвентарь и экипировка ──

func _on_equipment_slot_pressed(slot_type: int) -> void:
	_current_slot_type = slot_type
	_populate_inventory_panel()


func _populate_inventory_panel() -> void:
	if _inventory_side == null or not is_instance_valid(_inventory_side):
		return

	for child in _inventory_side.get_children():
		child.queue_free()

	_inventory_side.visible = true

	var title := Label.new()
	title.text = "Инвентарь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	_inventory_side.add_child(title)

	var unequip_btn := Button.new()
	unequip_btn.text = "Снять экипировку"
	unequip_btn.custom_minimum_size = Vector2(0, 36)
	unequip_btn.add_theme_font_size_override("font_size", 14)
	unequip_btn.pressed.connect(_unequip_current_slot)
	_inventory_side.add_child(unequip_btn)

	_inventory_side.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(200, 300)
	_inventory_side.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var needed_type: int = _current_slot_type
	var found_any := false

	for item_path in CampaignState.treasury:
		var item := load(item_path) as ItemResource
		if item == null:
			continue
		if item.item_type != needed_type:
			continue
		found_any = true

		var summary := _item_bonus_summary(item)
		var item_btn := Button.new()
		item_btn.text = "%s\n%s" % [item.item_name, summary]
		item_btn.add_theme_font_size_override("font_size", 13)
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.custom_minimum_size = Vector2(0, 50)
		item_btn.pressed.connect(_equip_item.bind(item_path))
		list.add_child(item_btn)

	if not found_any:
		var empty := Label.new()
		empty.text = "Нет подходящих предметов"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		list.add_child(empty)


func _item_bonus_summary(item: ItemResource) -> String:
	var parts: Array[String] = []
	if item.bonus_max_hp != 0:
		parts.append("HP %+d" % item.bonus_max_hp)
	if item.bonus_damage != 0:
		parts.append("Урон %+d" % item.bonus_damage)
	if item.bonus_armor != 0:
		parts.append("Броня %+d" % item.bonus_armor)
	if item.bonus_initiative != 0:
		parts.append("Иниц %+d" % item.bonus_initiative)
	if item.bonus_accuracy != 0:
		parts.append("Точ %+d" % item.bonus_accuracy)
	if item.bonus_evasion != 0:
		parts.append("Укл %+d" % item.bonus_evasion)
	if item.bonus_crit_chance != 0.0:
		parts.append("Крит %+d%%" % int(item.bonus_crit_chance * 100))
	if parts.is_empty():
		return ""
	return " | ".join(parts)


func _equip_item(item_path: String) -> void:
	var item := load(item_path) as ItemResource
	if item == null:
		return
	match _current_slot_type:
		0: _current_god_res.equipped_weapon = item
		1: _current_god_res.equipped_armor = item
		2: _current_god_res.equipped_trinket = item
	CampaignState.set_god_equipment_path(_current_god_path, _current_slot_type, item_path)
	_refresh_god_detail()


func _unequip_current_slot() -> void:
	match _current_slot_type:
		0: _current_god_res.equipped_weapon = null
		1: _current_god_res.equipped_armor = null
		2: _current_god_res.equipped_trinket = null
	CampaignState.set_god_equipment_path(_current_god_path, _current_slot_type, "")
	_refresh_god_detail()


func _refresh_god_detail() -> void:
	if _current_god_path == "":
		return
	var path := _current_god_path
	_close_god_detail()
	_show_god_detail(path)


func _close_god_detail() -> void:
	if _god_overlay != null and is_instance_valid(_god_overlay):
		_god_overlay.queue_free()
		_god_overlay = null
	_current_god_path = ""
	_current_god_res = null
	_current_slot_type = -1
	_inventory_side = null
