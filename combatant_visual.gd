extends Area2D

signal unit_clicked(unit)
signal unit_hovered(unit)
signal unit_unhovered

@onready var hp_bar = $HPBar
@onready var hp_label = $HPLabel
@onready var name_label = $NameLabel
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

const BASE_BATTLE_SPRITE_SCALE_MULTIPLIER := 2.0
const SPRITE_FEET_Y := 140.0
const EFFECT_ICON_HEIGHT := 22.0
const HP_BAR_Y := SPRITE_FEET_Y + EFFECT_ICON_HEIGHT + 4.0
const HP_BAR_HEIGHT := 14.0
const MAJESTY_BAR_HEIGHT := 6.0
const EFFECT_ICON_GAP := 4
const EFFECT_ICON_BAR_GAP := 4.0
# Подсветка допустимой цели при выборе способности: чуть шире HP-бара, лежит
# прямо над ним и своей верхней частью перекрывает низ спрайта (ноги персонажа).
const TARGET_HIGHLIGHT_HEIGHT := 28.0
const TARGET_HIGHLIGHT_GAP_ABOVE_HP := 6.0
const TARGET_HIGHLIGHT_WIDTH_MULT := 1.3
const TARGET_HIGHLIGHT_ENEMY_TEX := "res://UI/Red_highlight.png"
# Крупные юниты вдвое шире (bar_width=260 против 130) — при таком растяжении
# обычная картинка выглядит слишком растянутой, поэтому у неё есть отдельная
# широкая версия с иначе расставленными "зубцами" под этот масштаб.
const TARGET_HIGHLIGHT_ENEMY_TEX_WIDE := "res://UI/Red_highlight_wide.png"
const TARGET_HIGHLIGHT_ALLY_TEX := "res://UI/Blue_highlight.png"
# Предпросмотр цели способности при наведении (шанс попадания + мигание HP).
const PREVIEW_LABEL_HEIGHT := 16.0
const PREVIEW_LABEL_GAP := 2.0
# Облачко диалога с озвученной фразой (см. show_voice_line) — над головой спрайта,
# фиксированная ширина (как PREVIEW_LABEL выше — не подгоняется под длину текста).
const VOICE_BUBBLE_WIDTH := 220.0
const VOICE_BUBBLE_GAP_ABOVE_HEAD := 12.0
const VOICE_BUBBLE_MIN_DURATION := 2.0
const VOICE_BUBBLE_FADE_DURATION := 0.4
## Хвостик — ближе к левому краю облака (не по центру), само облако из-за этого
## смещено вправо относительно головы юнита. См. show_voice_line()/_ensure_voice_bubble().
const VOICE_BUBBLE_TAIL_X_RATIO := 0.18
## Минимальный отступ от края экрана при выравнивании облака внутрь видимой области.
const VOICE_BUBBLE_SCREEN_MARGIN := 6.0
## Текст и рамка облачка реплики — свои у каждого бога (фон при этом всегда чёрный).
## Ключ — папка бога (Gods/<Folder>/...), как в CampaignState.GOD_FOLDER_TO_LOCATION.
const VOICE_BUBBLE_GOD_COLORS := {
	"Osiris": Color(1.0, 0.82, 0.0),      # Золотой
	"Susanoo": Color(1.0, 0.15, 0.1),     # Ярко красный
	"Odin": Color(0.75, 0.05, 0.2),       # Багряный
	"Poseidon": Color(0.0, 0.65, 0.65),   # Цвет морской волны
	"Zeus": Color(0.65, 0.82, 1.0),       # Бледно голубой
	"Hades": Color(0.78, 0.78, 0.8),      # Бледно серый
	"Chernobog": Color(1.0, 1.0, 1.0),    # Белый
	"Koschei": Color(0.1, 0.75, 0.45),    # Изумрудный
	"Danu": Color(0.6, 0.9, 0.25),        # Салатовый
	"Samdi": Color(0.85, 0.1, 0.6),       # Ярко пурпурный
	"Morgan": Color(0.75, 0.55, 0.9),     # Сиреневый
	"Set": Color(0.55, 0.2, 0.9),         # Фиолетовый
	"Shiva": Color(0.15, 0.45, 1.0),      # Ярко синий
	"Loki": Color(0.58, 0.62, 0.95),       # Бледно синий (отличается от Зевса и Шивы)
}
# Вспышка эффекта способности (напр. молния Зевса, AbilityResource.attack_effect_texture)
# поверх спрайта юнита, которого бьют — см. show_attack_effect_flash().
const ATTACK_FLASH_FADE_DURATION := 0.25
const EFFECT_ICON_PATHS := {
	"buff": "res://icons/Buff_icon.png",
	"debuff": "res://icons/debuff_icon.png",
	"regeneration": "res://icons/Regeneration_icon.png",
	"periodic_damage": "res://icons/Periodic_damage_icon.png",
	"stance": "res://icons/Stance_Icon.png",
	"hammer_of_lightning": "res://icons/Hammer_of_lightning_icon.png",
	"neverending_storm": "res://icons/Neverneding_storm_icon.png",
	"provocation_mark": "res://icons/Taunt_mark_icon.png",
	"innocence_mark": "res://icons/Innocense_mark_icon.png",
	"voodoo_curse": "res://icons/Vodoo_curse_icon.png",
	"plant_poison": "res://icons/Plant_poison_icon.png",
}
const EFFECT_ICON_ORDER := [
	"hammer_of_lightning",
	"neverending_storm",
	"provocation_mark",
	"innocence_mark",
	"stance",
	"regeneration",
	"periodic_damage",
	"plant_poison",
	"voodoo_curse",
	"buff",
	"debuff",
]

var data: Combatant
var _base_sprite_scale := Vector2.ONE
var _applied_sprite_scale_percent: float = -1.0
var _applied_sprite_y_offset_percent: float = 0.0
var majesty_bar: ProgressBar = null
var flash_sprite: Sprite2D = null
var flash_tween: Tween = null
var _target_highlight: TextureRect = null
var _preview_label: Label = null
var _preview_overlay: ColorRect = null
var _preview_tween: Tween = null
var _voice_bubble: SpeechBubbleShape = null
var _voice_bubble_margin: MarginContainer = null
var _voice_bubble_label: RichTextLabel = null
var _voice_audio_player: AudioStreamPlayer = null
var _voice_hide_tween: Tween = null
var _effect_icon_row: HBoxContainer = null
var _sprite_opaque_bounds := Rect2()
var _status_bar_width := 130.0
var _status_hp_height := HP_BAR_HEIGHT
var _status_majesty_height := MAJESTY_BAR_HEIGHT

func _ready():
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# RectangleShape2D_click в combatant_visual.tscn не помечен "Local to Scene" —
	# Godot кэширует под-ресурсы .tscn и РАЗДЕЛЯЕТ их между ВСЕМИ инстансами сцены,
	# если явно не задублировать. Из-за этого все юниты в бою (герои и враги) делили
	# один и тот же RectangleShape2D: чей _apply_sprite_scale_keep_feet() отработал
	# последним, тот и задавал .size хитбокса — сразу для ВСЕХ юнитов одновременно
	# (позиция CollisionShape2D — своя у каждого узла, а вот размер самой Shape-фигуры
	# был общим). Дублируем здесь, чтобы у каждого юнита была своя независимая форма.
	if collision_shape != null and collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()

func _on_mouse_entered():
	if data:
		unit_hovered.emit(data)

func _on_mouse_exited():
	unit_unhovered.emit()

func setup(combatant_data: Combatant):
	data = combatant_data
	# ÃÅ¸ÃÂ¾ÃÂ´ÃÂºÃÂ»Ã‘Å½Ã‘â€¡ÃÂ°ÃÂµÃÂ¼ Ã‘ÂÃÂ¸ÃÂ³ÃÂ½ÃÂ°ÃÂ»Ã‘â€¹ Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ½ÃÂ°/ÃÂ»ÃÂµÃ‘â€¡ÃÂµÃÂ½ÃÂ¸Ã‘Â ÃÂ´ÃÂ»Ã‘Â ÃÂ²Ã‘ÂÃÂ¿ÃÂ»Ã‘â€¹ÃÂ²ÃÂ°Ã‘Å½Ã‘â€°ÃÂ¸Ã‘â€¦ Ã‘â€¡ÃÂ¸Ã‘ÂÃÂµÃÂ» ÃÂ½ÃÂ°ÃÂ´ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ¾ÃÂ¼.
	if not data.damage_taken.is_connected(_on_damage_taken):
		data.damage_taken.connect(_on_damage_taken)
	if not data.healed.is_connected(_on_healed):
		data.healed.connect(_on_healed)
	if not data.voice_line_used.is_connected(_on_voice_line_used):
		data.voice_line_used.connect(_on_voice_line_used)
	name_label.text = data.unit_name
	name_label.visible = false
	name_label.z_index = 10
	hp_bar.z_index = 10
	hp_label.z_index = 10
	sprite.z_index = 0
	sprite.centered = true
	if data.sprite_path != null and data.sprite_path != "":
		sprite.texture = load(data.sprite_path)
		
		# Ãâ€˜ÃÂ°ÃÂ·ÃÂ¾ÃÂ²Ã‘â€¹ÃÂ¹ ÃÂ±ÃÂ¾ÃÂµÃÂ²ÃÂ¾ÃÂ¹ Ã‘ÂÃ‘â€šÃÂ°ÃÂ½ÃÂ´ÃÂ°Ã‘â‚¬Ã‘â€š: ÃÂ²Ã‘ÂÃÂµ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃ‘â€¹ ÃÂ²ÃÂ¸ÃÂ·Ã‘Æ’ÃÂ°ÃÂ»Ã‘Å’ÃÂ½ÃÂ¾ ÃÂ² 2 Ã‘â‚¬ÃÂ°ÃÂ·ÃÂ° ÃÂºÃ‘â‚¬Ã‘Æ’ÃÂ¿ÃÂ½ÃÂµÃÂµ ÃÂ¿Ã‘â‚¬ÃÂµÃÂ¶ÃÂ½ÃÂµÃÂ³ÃÂ¾ Ã‘â‚¬ÃÂ°ÃÂ·ÃÂ¼ÃÂµÃ‘â‚¬ÃÂ°.
		var target_size := Vector2(120, 180)
		if data.is_large:
			target_size = Vector2(240, 360)
		_rebuild_base_sprite_scale()
		
		var sprite_height: float = _get_scaled_opaque_height()
		# ÃÂ¨ÃÂ¸Ã‘â‚¬ÃÂ¸ÃÂ½ÃÂ° ÃÂ¿ÃÂ¾ÃÂ»ÃÂ¾Ã‘ÂÃÂ¾ÃÂº/ÃÂ½ÃÂ°ÃÂ´ÃÂ¿ÃÂ¸Ã‘ÂÃÂµÃÂ¹: ÃÂ¾ÃÂ±Ã‘â€¹Ã‘â€¡ÃÂ½Ã‘â€¹ÃÂ¹ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€š Ã¢â‚¬â€ 1 ÃÂºÃÂ»ÃÂµÃ‘â€šÃÂºÃÂ° (130), ÃÂºÃ‘â‚¬Ã‘Æ’ÃÂ¿ÃÂ½Ã‘â€¹ÃÂ¹ Ã¢â‚¬â€ 2 ÃÂºÃÂ»ÃÂµÃ‘â€šÃÂºÃÂ¸ (260).
		var bar_width = 130.0
		if data.is_large:
			bar_width = 260.0
		var bar_h = HP_BAR_HEIGHT
		var label_h = 18.0
		_status_bar_width = bar_width
		_status_hp_height = bar_h
		_status_majesty_height = MAJESTY_BAR_HEIGHT

		# Ãâ€˜ÃÂ°ÃÂ·ÃÂ¾ÃÂ²ÃÂ°Ã‘Â ÃÂ»ÃÂ¸ÃÂ½ÃÂ¸Ã‘Â Ã‚Â«ÃÂ½ÃÂ¾ÃÂ³Ã‚Â»: ÃÂ½ÃÂ¸ÃÂ· ÃÂ¾ÃÂ±Ã‘â€¹Ã‘â€¡ÃÂ½ÃÂ¾ÃÂ³ÃÂ¾ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° (180px) ÃÂ¿Ã‘â‚¬ÃÂ¸ Ã‘â€ ÃÂµÃÂ½Ã‘â€šÃ‘â‚¬ÃÂ¸Ã‘â‚¬ÃÂ¾ÃÂ²ÃÂ°ÃÂ½ÃÂ¸ÃÂ¸ ÃÂ² 0 = +90.
		# Ãâ€™Ã‘ÂÃÂµ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃ‘â€¹ (ÃÂ²ÃÂºÃÂ». ÃÂºÃ‘â‚¬Ã‘Æ’ÃÂ¿ÃÂ½Ã‘â€¹Ã‘â€¦) ÃÂ²Ã‘â€¹Ã‘â‚¬ÃÂ°ÃÂ²ÃÂ½ÃÂ¸ÃÂ²ÃÂ°Ã‘Å½Ã‘â€šÃ‘ÂÃ‘Â ÃÂ¿ÃÂ¾ ÃÂ½ÃÂµÃÂ¹ Ã¢â‚¬â€ Ã‘ÂÃ‘â€šÃÂ¾Ã‘ÂÃ‘â€š ÃÂ½ÃÂ° ÃÂ¾ÃÂ´ÃÂ½ÃÂ¾ÃÂ¼ Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ²ÃÂ½ÃÂµ,
		# ÃÂ° HP-ÃÂ±ÃÂ°Ã‘â‚¬/ÃÂ¸ÃÂ¼Ã‘Â ÃÂºÃ‘â‚¬Ã‘Æ’ÃÂ¿ÃÂ½Ã‘â€¹Ã‘â€¦ ÃÂ½ÃÂµ Ã‘Æ’ÃÂµÃÂ·ÃÂ¶ÃÂ°Ã‘Å½Ã‘â€š ÃÂ²ÃÂ½ÃÂ¸ÃÂ· ÃÂ¾Ã‘â€šÃÂ½ÃÂ¾Ã‘ÂÃÂ¸Ã‘â€šÃÂµÃÂ»Ã‘Å’ÃÂ½ÃÂ¾ ÃÂ¼ÃÂ°ÃÂ»ÃÂµÃÂ½Ã‘Å’ÃÂºÃÂ¸Ã‘â€¦.
		var feet_y := SPRITE_FEET_Y
		var top_y: float = feet_y - sprite_height
		var hp_y := HP_BAR_Y

		# ÃÅ¡Ã‘â‚¬ÃÂ°Ã‘ÂÃÂ½Ã‘â€¹ÃÂ¹ ÃÂ¾ÃÂ²ÃÂµÃ‘â‚¬ÃÂ»ÃÂµÃÂ¹ ÃÂ¿ÃÂ¾ÃÂ²ÃÂµÃ‘â‚¬Ã‘â€¦ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° ÃÂ´ÃÂ»Ã‘Â ÃÂ²Ã‘ÂÃÂ¿Ã‘â€¹Ã‘Ë†ÃÂºÃÂ¸ ÃÂ¿Ã‘â‚¬ÃÂ¸ ÃÂ¿ÃÂ¾ÃÂ»Ã‘Æ’Ã‘â€¡ÃÂµÃÂ½ÃÂ¸ÃÂ¸ Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ½ÃÂ°.
		flash_sprite = Sprite2D.new()
		flash_sprite.texture = sprite.texture
		flash_sprite.centered = sprite.centered
		flash_sprite.scale = sprite.scale
		flash_sprite.position = sprite.position
		flash_sprite.modulate = Color(1, 0, 0, 0)
		flash_sprite.z_index = sprite.z_index + 1
		add_child(flash_sprite)

		# ÃËœÃÂ¼Ã‘Â Ã¢â‚¬â€ ÃÂ½ÃÂ°ÃÂ´ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ¾ÃÂ¼, ÃÂ¿ÃÂ¾ Ã‘Ë†ÃÂ¸Ã‘â‚¬ÃÂ¸ÃÂ½ÃÂµ bar_width (Ã‘â€šÃÂµÃÂºÃ‘ÂÃ‘â€š Ã‘â€ ÃÂµÃÂ½Ã‘â€šÃ‘â‚¬ÃÂ¸Ã‘â‚¬ÃÂ¾ÃÂ²ÃÂ°ÃÂ½)
		name_label.position = Vector2(-bar_width * 0.5, top_y - 22)
		name_label.size = Vector2(bar_width, label_h)

		# HP ÃÂ±ÃÂ°Ã‘â‚¬ Ã¢â‚¬â€ ÃÂ½ÃÂ° Ã‘â€žÃÂ¸ÃÂºÃ‘ÂÃÂ¸Ã‘â‚¬ÃÂ¾ÃÂ²ÃÂ°ÃÂ½ÃÂ½ÃÂ¾ÃÂ¹ ÃÂ²Ã‘â€¹Ã‘ÂÃÂ¾Ã‘â€šÃÂµ ÃÂ¿ÃÂ¾ÃÂ´ ÃÂ½ÃÂ¾ÃÂ³ÃÂ°ÃÂ¼ÃÂ¸ (ÃÂ¾ÃÂ´ÃÂ¸ÃÂ½ÃÂ°ÃÂºÃÂ¾ÃÂ²ÃÂ¾ÃÂ¹ ÃÂ´ÃÂ»Ã‘Â ÃÂ²Ã‘ÂÃÂµÃ‘â€¦ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃÂ¾ÃÂ²)
		hp_bar.custom_minimum_size = Vector2(bar_width, bar_h)
		hp_bar.size = Vector2(bar_width, bar_h)
		hp_bar.position = Vector2(-bar_width * 0.5, hp_y)
		_ensure_effect_icon_row(bar_width, hp_y)
		_ensure_target_highlight(bar_width * TARGET_HIGHLIGHT_WIDTH_MULT, hp_y)

		# HP text inside the health bar.
		hp_label.position = Vector2(-bar_width * 0.5, hp_y)
		hp_label.size = Vector2(bar_width, bar_h)
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.clip_text = true
		hp_label.add_theme_font_size_override("font_size", 8)
		hp_label.add_theme_color_override("font_color", Color.WHITE)
		hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
		hp_label.add_theme_constant_override("outline_size", 1)

		# Ãâ€™ÃÂµÃÂ»ÃÂ¸Ã‘â€¡ÃÂ¸ÃÂµ Ã¢â‚¬â€ ÃÂ¿ÃÂ¾ÃÂ´ HP Ã‘â€šÃÂµÃÂºÃ‘ÂÃ‘â€šÃÂ¾ÃÂ¼ (Ã‘â€šÃÂ¾ÃÂ»Ã‘Å’ÃÂºÃÂ¾ ÃÂ´ÃÂ»Ã‘Â ÃÂ³ÃÂµÃ‘â‚¬ÃÂ¾ÃÂµÃÂ²)
		if not data.is_enemy:
			majesty_bar = ProgressBar.new()
			majesty_bar.max_value = 100
			majesty_bar.custom_minimum_size = Vector2(bar_width, _status_majesty_height)
			majesty_bar.size = Vector2(bar_width, _status_majesty_height)
			majesty_bar.position = Vector2(-bar_width * 0.5, hp_y + bar_h)
			majesty_bar.z_index = 10
			majesty_bar.show_percentage = false
			# Ãâ€˜ÃÂ»ÃÂµÃÂ´ÃÂ½ÃÂ¾-ÃÂ¶Ã‘â€˜ÃÂ»Ã‘â€šÃ‘â€¹ÃÂ¹ Ã‘â€ ÃÂ²ÃÂµÃ‘â€š ÃÂ·ÃÂ°ÃÂ»ÃÂ¸ÃÂ²ÃÂºÃÂ¸
			var majesty_fill = StyleBoxFlat.new()
			majesty_fill.bg_color = Color(1.0, 1.0, 0.6, 1.0)
			majesty_fill.corner_radius_top_left = 2
			majesty_fill.corner_radius_top_right = 2
			majesty_fill.corner_radius_bottom_left = 2
			majesty_fill.corner_radius_bottom_right = 2
			majesty_bar.add_theme_stylebox_override("fill", majesty_fill)
			# ÃÂ¤ÃÂ¾ÃÂ½ ÃÂ¿ÃÂ¾ÃÂ»ÃÂ¾Ã‘ÂÃÂºÃÂ¸ ÃÂ²ÃÂµÃÂ»ÃÂ¸Ã‘â€¡ÃÂ¸Ã‘Â
			var majesty_bg = StyleBoxFlat.new()
			majesty_bg.bg_color = Color(0.2, 0.2, 0.15, 0.6)
			majesty_bg.corner_radius_top_left = 2
			majesty_bg.corner_radius_top_right = 2
			majesty_bg.corner_radius_bottom_left = 2
			majesty_bg.corner_radius_bottom_right = 2
			majesty_bar.add_theme_stylebox_override("background", majesty_bg)
			majesty_bar.value = data.current_majesty
			add_child(majesty_bar)

	hp_bar.max_value = data.max_hp
	hp_bar.value = data.current_hp
	_update_hp_text()
	_refresh_effect_icons()

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unit_clicked.emit(data)

func _update_hp_text():
	hp_label.text = str(data.current_hp) + " / " + str(data.max_hp)
	hp_label.size = Vector2(_status_bar_width, _status_hp_height)

func set_status_bars_global_top(global_top_y: float) -> void:
	if not is_inside_tree():
		return
	var local_y: float = to_local(Vector2(global_position.x, global_top_y)).y
	_position_status_bars(local_y)

func _position_status_bars(hp_y: float) -> void:
	var bar_width: float = _status_bar_width
	var bar_h: float = _status_hp_height
	hp_bar.custom_minimum_size = Vector2(bar_width, bar_h)
	hp_bar.size = Vector2(bar_width, bar_h)
	hp_bar.position = Vector2(-bar_width * 0.5, hp_y)
	hp_label.position = hp_bar.position
	hp_label.size = Vector2(bar_width, bar_h)
	if majesty_bar:
		majesty_bar.custom_minimum_size = Vector2(bar_width, _status_majesty_height)
		majesty_bar.size = Vector2(bar_width, _status_majesty_height)
		majesty_bar.position = Vector2(-bar_width * 0.5, hp_y + bar_h)
	_ensure_effect_icon_row(bar_width, hp_y)
	_ensure_target_highlight(bar_width * TARGET_HIGHLIGHT_WIDTH_MULT, hp_y)

func update_visuals():
	if data == null:
		return
	_refresh_runtime_sprite_scale_percent()
		
	# ÃÅ¾ÃÂ³ÃÂ»Ã‘Æ’Ã‘Ë†Ã‘â€˜ÃÂ½ÃÂ½Ã‘â€¹ÃÂ¹ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€š ÃÂ²ÃÂ¸ÃÂ·Ã‘Æ’ÃÂ°ÃÂ»Ã‘Å’ÃÂ½ÃÂ¾ Ã‘ÂÃÂµÃ‘â‚¬ÃÂµÃÂµÃ‘â€š ÃÂ¸ Ã‘ÂÃ‘â€šÃÂ°ÃÂ½ÃÂ¾ÃÂ²ÃÂ¸Ã‘â€šÃ‘ÂÃ‘Â ÃÂ¿ÃÂ¾ÃÂ»Ã‘Æ’ÃÂ¿Ã‘â‚¬ÃÂ¾ÃÂ·Ã‘â‚¬ÃÂ°Ã‘â€¡ÃÂ½Ã‘â€¹ÃÂ¼ (50%).
	if data.is_stunned:
		sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		sprite.modulate = Color(1, 1, 1, 1)

	hp_bar.value = data.current_hp
	if majesty_bar:
		majesty_bar.value = data.current_majesty
	_update_hp_text()
	_refresh_effect_icons()


## Создаёт (при первом вызове) и позиционирует полоску подсветки допустимой цели.
## Лежит чуть выше HP-бара и заходит вверх на низ спрайта, чтобы его перекрывать.
func _ensure_target_highlight(highlight_width: float, hp_y: float) -> void:
	if _target_highlight == null:
		_target_highlight = TextureRect.new()
		_target_highlight.stretch_mode = TextureRect.STRETCH_SCALE
		# EXPAND_IGNORE_SIZE — иначе присвоение texture сбрасывает size обратно
		# к исходному размеру картинки (2161x728), затирая наш ручной размер полоски.
		_target_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_target_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_target_highlight.z_index = 13
		_target_highlight.visible = false
		add_child(_target_highlight)
	var bottom_y: float = hp_y - TARGET_HIGHLIGHT_GAP_ABOVE_HP
	var top_y: float = bottom_y - TARGET_HIGHLIGHT_HEIGHT
	_target_highlight.position = Vector2(-highlight_width * 0.5, top_y)
	_target_highlight.size = Vector2(highlight_width, TARGET_HIGHLIGHT_HEIGHT)

## kind: "" — скрыть, "enemy" — красная подсветка, "ally" — синяя.
## Вызывается извне (battle_scene.gd) во время выбора цели способности/заклинания.
func set_target_highlight(kind: String) -> void:
	if _target_highlight == null:
		return
	if kind == "":
		_target_highlight.visible = false
		return
	var path := TARGET_HIGHLIGHT_ALLY_TEX
	if kind == "enemy":
		var is_large: bool = data != null and data.is_large
		path = TARGET_HIGHLIGHT_ENEMY_TEX_WIDE if is_large else TARGET_HIGHLIGHT_ENEMY_TEX
	if _target_highlight.texture == null or _target_highlight.texture.resource_path != path:
		_target_highlight.texture = load(path)
	_target_highlight.visible = true

## Предпросмотр цели способности при наведении (см. battle_scene.gd::
## _update_ability_target_preview) — вызывается для КАЖДОГО юнита, который
## реально получит эффект выбранной способности, не только для того, на кого
## наведён курсор (AoE-способности задевают сразу нескольких).
## hit_chance — доля 0..1, всегда показывается текстом над юнитом.
## predicted_damage > 0 — дополнительно запускает медленное белое мигание той
## части HP-полоски, которая пропадёт при попадании (само число уже посчитано
## БЕЗ крита, если он не гарантирован, и без периодического урона — см.
## CombatCalculator.preview_ability_damage()).
func show_target_preview(hit_chance: float, predicted_damage: int) -> void:
	_ensure_preview_label()
	_preview_label.text = "Шанс попадания: %d%%" % int(round(hit_chance * 100.0))
	_preview_label.visible = true
	var bar_width: float = hp_bar.size.x
	# Текст с подписью шире, чем сам HP-бар (особенно у обычных юнитов, bar_width=130) —
	# берём более широкую фиксированную ширину, но центрируем её на середине бара.
	var label_width: float = maxf(bar_width, 190.0)
	var bar_center_x: float = hp_bar.position.x + bar_width * 0.5
	_preview_label.position = Vector2(bar_center_x - label_width * 0.5, hp_bar.position.y - EFFECT_ICON_HEIGHT - EFFECT_ICON_BAR_GAP - PREVIEW_LABEL_HEIGHT - PREVIEW_LABEL_GAP)
	_preview_label.size = Vector2(label_width, PREVIEW_LABEL_HEIGHT)

	if predicted_damage > 0 and data != null and data.max_hp > 0:
		_ensure_preview_overlay()
		var bar_height: float = hp_bar.size.y
		var fraction_end: float = clampf(float(data.current_hp) / float(data.max_hp), 0.0, 1.0)
		var fraction_start: float = clampf(float(data.current_hp - predicted_damage) / float(data.max_hp), 0.0, 1.0)
		var seg_left: float = bar_width * fraction_start
		var seg_right: float = bar_width * fraction_end
		_preview_overlay.position = Vector2(hp_bar.position.x + seg_left, hp_bar.position.y)
		_preview_overlay.size = Vector2(maxf(0.0, seg_right - seg_left), bar_height)
		_preview_overlay.visible = seg_right > seg_left
		if _preview_overlay.visible:
			_start_preview_blink()
		else:
			_stop_preview_blink()
	elif _preview_overlay != null:
		_preview_overlay.visible = false
		_stop_preview_blink()

## Скрывает предпросмотр (наведение ушло с цели / выбор цели завершён/отменён).
func clear_target_preview() -> void:
	if _preview_label != null:
		_preview_label.visible = false
	if _preview_overlay != null:
		_preview_overlay.visible = false
	_stop_preview_blink()

func _ensure_preview_label() -> void:
	if _preview_label != null:
		return
	_preview_label = Label.new()
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_label.add_theme_font_size_override("font_size", 13)
	_preview_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_preview_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_preview_label.add_theme_constant_override("outline_size", 3)
	_preview_label.z_index = 14
	_preview_label.visible = false
	add_child(_preview_label)

func _ensure_preview_overlay() -> void:
	if _preview_overlay != null:
		return
	_preview_overlay = ColorRect.new()
	_preview_overlay.color = Color(1, 1, 1, 1)
	_preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_overlay.z_index = 11
	_preview_overlay.visible = false
	add_child(_preview_overlay)

## Медленное мигание (0.6с туда, 0.6с обратно, по кругу) — пока предпросмотр активен.
func _start_preview_blink() -> void:
	if _preview_overlay == null:
		return
	if _preview_tween != null and _preview_tween.is_valid():
		return
	_preview_overlay.modulate.a = 0.15
	_preview_tween = create_tween()
	_preview_tween.set_loops()
	_preview_tween.tween_property(_preview_overlay, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
	_preview_tween.tween_property(_preview_overlay, "modulate:a", 0.15, 0.6).set_trans(Tween.TRANS_SINE)

func _stop_preview_blink() -> void:
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_tween = null

func _ensure_effect_icon_row(bar_width: float, hp_y: float) -> void:
	if _effect_icon_row == null:
		_effect_icon_row = HBoxContainer.new()
		_effect_icon_row.z_index = 12
		_effect_icon_row.mouse_filter = Control.MOUSE_FILTER_PASS
		_effect_icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_effect_icon_row.add_theme_constant_override("separation", EFFECT_ICON_GAP)
		add_child(_effect_icon_row)
	_effect_icon_row.position = Vector2(-bar_width * 0.5, hp_y - EFFECT_ICON_HEIGHT - EFFECT_ICON_BAR_GAP)
	_effect_icon_row.custom_minimum_size = Vector2(bar_width, EFFECT_ICON_HEIGHT)
	_effect_icon_row.size = Vector2(bar_width, EFFECT_ICON_HEIGHT)

func _refresh_effect_icons() -> void:
	if _effect_icon_row == null or data == null:
		return
	for child in _effect_icon_row.get_children():
		_effect_icon_row.remove_child(child)
		child.queue_free()
	var entries := _build_effect_icon_entries()
	_effect_icon_row.visible = not entries.is_empty()
	for entry in entries:
		var icon_path := str(entry.get("path", ""))
		if icon_path == "" or not ResourceLoader.exists(icon_path):
			continue
		var texture := load(icon_path) as Texture2D
		if texture == null:
			continue
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(EFFECT_ICON_HEIGHT, EFFECT_ICON_HEIGHT)
		icon.size = Vector2(EFFECT_ICON_HEIGHT, EFFECT_ICON_HEIGHT)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = str(entry.get("tooltip", ""))
		_effect_icon_row.add_child(icon)

func _build_effect_icon_entries() -> Array[Dictionary]:
	var grouped := {}
	for effect in data.active_effects:
		var category := _get_effect_icon_category(effect)
		if category == "":
			continue
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(_format_effect_tooltip_line(effect))
	if data.active_stance != null:
		grouped["stance"] = [_format_stance_tooltip_line(data.active_stance)]
	if data.special_effect_type == "satyr_redirect":
		if not grouped.has("innocence_mark"):
			grouped["innocence_mark"] = []
		grouped["innocence_mark"].append("Метка невинности: 50% шанс перенаправить атаку на случайного союзника.")
	var entries: Array[Dictionary] = []
	for category in EFFECT_ICON_ORDER:
		if not grouped.has(category):
			continue
		var icon_path := str(EFFECT_ICON_PATHS.get(category, ""))
		if icon_path == "":
			continue
		entries.append({"path": icon_path, "tooltip": "\n".join(grouped[category])})
	return entries

func _get_effect_icon_category(effect) -> String:
	var stat := str(Combatant._effect_get(effect, "stat", ""))
	var effect_id := str(Combatant._effect_get(effect, "effect_id", ""))
	var source := str(Combatant._effect_get(effect, "source_ability", ""))
	var key := (stat + " " + effect_id + " " + source).to_lower()
	if effect_id == "thor_hammer_of_lightning" or stat == "thor_hammer_of_lightning":
		return "hammer_of_lightning"
	if effect_id == "neverending_storm_mark" or stat == "neverending_storm_mark":
		return "neverending_storm"
	if stat == "provocation_mark" or effect_id == "provocation_mark" or effect_id == "princess_provocation":
		return "provocation_mark"
	if effect_id == "cupid_innocence":
		return "innocence_mark"
	if effect_id == "plant_poison_buff":
		return "plant_poison"
	if stat == "regeneration":
		return "regeneration"
	if stat == "periodic_damage":
		return "periodic_damage"
	if key.contains("voodoo") or key.contains("vodoo") or key.contains("curse") or key.contains("прокля"):
		return "voodoo_curse"
	if stat == "trigger_marker":
		return "buff"
	var value := int(Combatant._effect_get(effect, "value", 0))
	if stat == "stun" or stat == "rooted" or value < 0:
		return "debuff"
	if value > 0:
		return "buff"
	return ""

func _format_effect_tooltip_line(effect) -> String:
	var stat := str(Combatant._effect_get(effect, "stat", "effect"))
	var effect_id := str(Combatant._effect_get(effect, "effect_id", ""))
	var source := str(Combatant._effect_get(effect, "source_ability", ""))
	var value := int(Combatant._effect_get(effect, "value", 0))
	var duration := int(Combatant._effect_get(effect, "duration", 0))
	var title := source
	if title == "":
		title = _effect_title(effect_id, stat)
	var description := DataTables.describe_active_effect(effect_id, stat, value, source)
	if description == "":
		description = _effect_value_text(stat, value)
	var duration_text := _effect_duration_text(effect_id, duration)
	if duration_text == "":
		return "%s: %s" % [title, description]
	return "%s: %s, %s" % [title, description, duration_text]

func _format_stance_tooltip_line(stance: AbilityResource) -> String:
	var details := "Стойка: %s" % stance.name
	if stance.stance_effect_type != "":
		var description := DataTables.get_stance_effect_description(stance.stance_effect_type)
		# Пусто в общей таблице — не редкость (часть способностей полностью описывает
		# себя в собственном description, без дублирующего автотекста). Тогда просто
		# показываем этот собственный текст способности вместо служебного stance_effect_type.
		if description == "":
			description = stance.get_display_description().strip_edges()
		if description != "":
			details += "\n%s" % description
	if stance.stance_duration_type != "":
		details += "\nДлительность: %s" % _stance_duration_text(stance.stance_duration_type)
	return details

func _effect_value_text(stat: String, value: int) -> String:
	if stat == "periodic_damage":
		return "периодический урон %d" % value
	if stat == "regeneration":
		return "регенерация %d%%" % value
	if stat == "stun":
		return "оглушение"
	if stat == "rooted":
		return "обездвиживание"
	if stat == "trigger_marker":
		return "уникальная метка"
	if value > 0:
		return "+%d к %s" % [value, _effect_stat_title(stat)]
	if value < 0:
		return "%d к %s" % [value, _effect_stat_title(stat)]
	return _effect_stat_title(stat)

func _effect_duration_text(effect_id: String, duration: int) -> String:
	var shown_duration := duration
	if effect_id == "thor_hammer_of_lightning" and duration > 0:
		shown_duration = maxi(1, duration - 1)
	if shown_duration < 0:
		return "до конца боя"
	if shown_duration == 0:
		return "заканчивается"
	return "%d ход(ов)" % shown_duration

func _effect_title(effect_id: String, stat: String) -> String:
	match effect_id:
		"thor_hammer_of_lightning": return "Громовой молот"
		"neverending_storm_mark": return "Нескончаемый шторм"
		"thor_fight_me_heal": return "Провокация Тора"
		"plant_poison_buff": return "Растительный яд"
		"cupid_innocence": return "Метка невинности"
		"provocation_mark", "princess_provocation": return "Метка провокации"
		"voodoo_marked": return "Кукла вуду"
		"raven_marked": return "Стая воронов"
		"root_thorns": return "Шипы корней"
		"duna_harmony_immune": return "Гармония с природой"
		"ultimate_blocked": return "Блокировка ульты"
		"sphinx_riddle": return "Загадка Сфинкса"
		_:
			if effect_id != "":
				return effect_id.capitalize().replace("_", " ")
			return _effect_stat_title(stat)

func _stance_duration_text(duration_type: String) -> String:
	match duration_type:
		"UntilNextTurn": return "до следующего хода"
		"UntilBattleEnd": return "до конца боя"
		"UntilStanceBroken": return "пока стойка не сбита"
		_: return duration_type

func _effect_stat_title(stat: String) -> String:
	match stat:
		"hp": return "здоровье"
		"max_hp": return "максимальное здоровье"
		"damage", "attack": return "атаку"
		"armor": return "броню"
		"accuracy": return "точность"
		"evasion": return "уклонение"
		"crit", "crit_chance", "luck": return "удачу"
		"initiative": return "инициативу"
		"provocation_mark": return "метку провокации"
		"invulnerable": return "неуязвимость"
		"crit_modifier": return "шанс крита"
		_: return stat
func flash_damage():
	if flash_sprite == null:
		return
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_sprite.modulate = Color(1, 0, 0, 0)
	flash_tween = create_tween()
	flash_tween.tween_property(flash_sprite, "modulate:a", 0.75, 0.05)
	flash_tween.tween_interval(0.3)
	flash_tween.tween_property(flash_sprite, "modulate:a", 0.0, 0.05)

func _rebuild_base_sprite_scale() -> void:
	if sprite == null or sprite.texture == null or data == null:
		return
	var target_size := Vector2(120.0, 180.0)
	if data.is_large:
		target_size = Vector2(240.0, 360.0)
	var resource_scale: float = maxf(0.01, data.battle_sprite_scale_percent / 100.0)
	target_size *= BASE_BATTLE_SPRITE_SCALE_MULTIPLIER * resource_scale
	var texture_size: Vector2 = sprite.texture.get_size()
	_sprite_opaque_bounds = _get_texture_opaque_bounds(sprite.texture)
	var scale_basis: Vector2 = _sprite_opaque_bounds.size
	if scale_basis.x <= 0.0 or scale_basis.y <= 0.0:
		scale_basis = texture_size
	var scale_factor: float = minf(target_size.x / scale_basis.x, target_size.y / scale_basis.y)
	_base_sprite_scale = Vector2(scale_factor, scale_factor)
	_applied_sprite_scale_percent = data.battle_sprite_scale_percent
	_applied_sprite_y_offset_percent = data.battle_sprite_y_offset_percent
	_apply_sprite_scale_keep_feet(_base_sprite_scale)

func _refresh_runtime_sprite_scale_percent() -> void:
	if data == null:
		return
	if data.source_resource_path != "" and ResourceLoader.exists(data.source_resource_path):
		var live_resource := ResourceLoader.load(data.source_resource_path, "", ResourceLoader.CACHE_MODE_REPLACE) as CharacterResource
		if live_resource != null:
			data.battle_sprite_scale_percent = live_resource.battle_sprite_scale_percent
			data.battle_sprite_y_offset_percent = live_resource.battle_sprite_y_offset_percent
	if absf(data.battle_sprite_scale_percent - _applied_sprite_scale_percent) > 0.001 or absf(data.battle_sprite_y_offset_percent - _applied_sprite_y_offset_percent) > 0.001:
		_rebuild_base_sprite_scale()

func _get_scaled_opaque_height() -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	var bounds := _sprite_opaque_bounds
	if bounds.size.y <= 0.0:
		return sprite.texture.get_size().y * absf(sprite.scale.y)
	return bounds.size.y * absf(sprite.scale.y)

func _get_texture_opaque_bounds(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null:
		return Rect2(Vector2.ZERO, texture.get_size())
	if image.is_compressed():
		var err := image.decompress()
		if err != OK:
			return Rect2(Vector2.ZERO, texture.get_size())
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))
## update_collision=false — двигает/масштабирует только спрайт (визуальный эффект,
## например рост при наведении), не трогая Area2D-хитбокс. Так хитбокс при наведении
## не "разрастается" на соседнюю позицию и не перехватывает её клики/наведение
## (см. правило "наводка выбирает по юниту на позиции, а не по перекрывающему спрайту").
func _apply_sprite_scale_keep_feet(new_scale: Vector2, update_collision: bool = true) -> void:
	if sprite == null or sprite.texture == null:
		return
	sprite.scale = new_scale
	var texture_size: Vector2 = sprite.texture.get_size()
	var bounds := _sprite_opaque_bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = Rect2(Vector2.ZERO, texture_size)
	var opaque_bottom_from_center := bounds.position.y + bounds.size.y - texture_size.y * 0.5
	var osiris_set_vertical_offset := 0.0
	if data != null and (data.unit_name == "Сет" or data.sprite_path.ends_with("/Set.png")):
		osiris_set_vertical_offset = -bounds.size.y * absf(sprite.scale.y) * 0.10
	var resource_vertical_offset := 0.0
	if data != null:
		resource_vertical_offset = -bounds.size.y * absf(sprite.scale.y) * (data.battle_sprite_y_offset_percent / 100.0)
	sprite.position = Vector2(0, SPRITE_FEET_Y - opaque_bottom_from_center * absf(sprite.scale.y) + osiris_set_vertical_offset + resource_vertical_offset)
	# Хитбокс — не по непрозрачным пикселям спрайта (тонкие силуэты/просветы давали
	# мёртвые зоны, курсор часто "не ловил" юнита), а сплошной прямоугольник во всю
	# зону НАД HP-баром: от верха спрайта (полный габарит текстуры, БЕЗ обрезки по
	# прозрачности) до HP_BAR_Y, шириной с сам HP-бар. Раньше здесь по ошибке было
	# [0, HP_BAR_Y] — это кусок НИЖЕ середины спрайта (почти под ногами), а не вся
	# его высота.
	if update_collision and collision_shape != null:
		var bar_width: float = 260.0 if (data != null and data.is_large) else 130.0
		var sprite_top_y: float = sprite.position.y - texture_size.y * absf(sprite.scale.y) * 0.5
		var height: float = maxf(1.0, HP_BAR_Y - sprite_top_y)
		var shape := collision_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(bar_width, height)
		collision_shape.position = Vector2(0, (sprite_top_y + HP_BAR_Y) * 0.5)
	if flash_sprite != null:
		flash_sprite.scale = sprite.scale
		flash_sprite.position = sprite.position

## Раньше подсвечивало активного юнита жёлтой рамкой вокруг HP-бара — убрано, мешало визуально (жёлтая линия между фоном и полосой величия).
func set_active(active: bool) -> void:
	pass

## ÃÅ¸ÃÂ¾ÃÂ´Ã‘ÂÃÂ²ÃÂµÃ‘â€šÃÂºÃÂ° ÃÂ¿Ã‘â‚¬ÃÂ¸ ÃÂ½ÃÂ°ÃÂ²ÃÂµÃÂ´ÃÂµÃÂ½ÃÂ¸ÃÂ¸ ÃÂ½ÃÂ° ÃÂ¿ÃÂ¾Ã‘â‚¬Ã‘â€šÃ‘â‚¬ÃÂµÃ‘â€š Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃÂ° (ÃÂ½ÃÂ°ÃÂ¿Ã‘â‚¬ÃÂ¸ÃÂ¼ÃÂµÃ‘â‚¬, ÃÂ¸ÃÂ· ÃÂ¿ÃÂ¾ÃÂ»ÃÂ¾Ã‘ÂÃ‘â€¹ ÃÂ¾Ã‘â€¡ÃÂµÃ‘â‚¬ÃÂµÃÂ´ÃÂ¸ Ã‘â€¦ÃÂ¾ÃÂ´ÃÂ¾ÃÂ²):
## Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€š Ã‘ÂÃÂ»ÃÂµÃÂ³ÃÂºÃÂ° Ã‘Æ’ÃÂ²ÃÂµÃÂ»ÃÂ¸Ã‘â€¡ÃÂ¸ÃÂ²ÃÂ°ÃÂµÃ‘â€šÃ‘ÂÃ‘Â ÃÂ¸ ÃÂ¿ÃÂ¾Ã‘ÂÃÂ²ÃÂ»Ã‘ÂÃÂµÃ‘â€šÃ‘ÂÃ‘Â ÃÂ¸ÃÂ¼Ã‘Â Ã¢â‚¬â€ Ã‘â€¡Ã‘â€šÃÂ¾ÃÂ±Ã‘â€¹ ÃÂ±Ã‘â€¹ÃÂ»ÃÂ¾ ÃÂ²ÃÂ¸ÃÂ´ÃÂ½ÃÂ¾, ÃÂºÃÂ¾ÃÂ³ÃÂ¾ ÃÂ²Ã‘â€¹ÃÂ±Ã‘â‚¬ÃÂ°ÃÂ»ÃÂ¸.
func set_hover(hovered: bool) -> void:
	if sprite == null or sprite.texture == null:
		return
	_apply_sprite_scale_keep_feet(_base_sprite_scale * (1.15 if hovered else 1.0), false)
	if name_label:
		name_label.visible = hovered

## ÃÅ¾ÃÂ±Ã‘â‚¬ÃÂ°ÃÂ±ÃÂ¾Ã‘â€šÃ‘â€¡ÃÂ¸ÃÂº ÃÂ¿ÃÂ¾ÃÂ»Ã‘Æ’Ã‘â€¡ÃÂµÃÂ½ÃÂ¸Ã‘Â Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ½ÃÂ°: ÃÂ¿ÃÂ¾ÃÂºÃÂ°ÃÂ·Ã‘â€¹ÃÂ²ÃÂ°ÃÂµÃ‘â€š ÃÂ²Ã‘ÂÃÂ¿ÃÂ»Ã‘â€¹ÃÂ²ÃÂ°Ã‘Å½Ã‘â€°ÃÂµÃÂµ Ã‘â€¡ÃÂ¸Ã‘ÂÃÂ»ÃÂ¾ ÃÂ½ÃÂ°ÃÂ´ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ¾ÃÂ¼.
## Ãâ€¢Ã‘ÂÃÂ»ÃÂ¸ Ã‘Æ’Ã‘ÂÃ‘â€šÃÂ°ÃÂ½ÃÂ¾ÃÂ²ÃÂ»ÃÂµÃÂ½ Ã‘â€žÃÂ»ÃÂ°ÃÂ³ pending_crit Ã¢â‚¬â€ Ã‘â€¡ÃÂ¸Ã‘ÂÃÂ»ÃÂ¾ ÃÂ¾Ã‘â€šÃÂ¾ÃÂ±Ã‘â‚¬ÃÂ°ÃÂ¶ÃÂ°ÃÂµÃ‘â€šÃ‘ÂÃ‘Â ÃÂºÃÂ°ÃÂº ÃÂºÃ‘â‚¬ÃÂ¸Ã‘â€šÃÂ¸Ã‘â€¡ÃÂµÃ‘ÂÃÂºÃÂ¾ÃÂµ.
func _on_damage_taken(amount: int) -> void:
	if data and data.pending_crit:
		data.pending_crit = false
		show_floating_number(amount, "crit")
	else:
		show_floating_number(amount, "damage")

## ÃÅ¾ÃÂ±Ã‘â‚¬ÃÂ°ÃÂ±ÃÂ¾Ã‘â€šÃ‘â€¡ÃÂ¸ÃÂº ÃÂ»ÃÂµÃ‘â€¡ÃÂµÃÂ½ÃÂ¸Ã‘Â: ÃÂ·ÃÂµÃÂ»Ã‘â€˜ÃÂ½ÃÂ¾ÃÂµ ÃÂ²Ã‘ÂÃÂ¿ÃÂ»Ã‘â€¹ÃÂ²ÃÂ°Ã‘Å½Ã‘â€°ÃÂµÃÂµ Ã‘â€¡ÃÂ¸Ã‘ÂÃÂ»ÃÂ¾.
func _on_healed(amount: int) -> void:
	show_floating_number(amount, "heal")

## ÃÅ¸ÃÂ¾ÃÂºÃÂ°ÃÂ·Ã‘â€¹ÃÂ²ÃÂ°ÃÂµÃ‘â€š ÃÂ²Ã‘ÂÃÂ¿ÃÂ»Ã‘â€¹ÃÂ²ÃÂ°Ã‘Å½Ã‘â€°ÃÂµÃÂµ Ã‘â€¡ÃÂ¸Ã‘ÂÃÂ»ÃÂ¾ ÃÂ½ÃÂ°ÃÂ´ ÃÂ³ÃÂ¾ÃÂ»ÃÂ¾ÃÂ²ÃÂ¾ÃÂ¹ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° ÃÂ¸ ÃÂ¿ÃÂ»ÃÂ°ÃÂ²ÃÂ½ÃÂ¾ Ã‘Æ’ÃÂ±ÃÂ¸Ã‘â‚¬ÃÂ°ÃÂµÃ‘â€š ÃÂµÃÂ³ÃÂ¾.
## kind: "damage" (ÃÂ±ÃÂµÃÂ»ÃÂ¾ÃÂµ Ã‘Â ÃÂºÃ‘â‚¬ÃÂ°Ã‘ÂÃÂ½Ã‘â€¹ÃÂ¼ ÃÂºÃÂ¾ÃÂ½Ã‘â€šÃ‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ¼), "crit" (ÃÂºÃ‘â‚¬Ã‘Æ’ÃÂ¿ÃÂ½ÃÂµÃÂµ, ÃÂ¿ÃÂ¾ÃÂ»ÃÂ½ÃÂ¾Ã‘ÂÃ‘â€šÃ‘Å’Ã‘Å½ ÃÂºÃ‘â‚¬ÃÂ°Ã‘ÂÃÂ½ÃÂ¾ÃÂµ),
## "heal" (ÃÂ·ÃÂµÃÂ»Ã‘â€˜ÃÂ½ÃÂ¾ÃÂµ, Ã‘Â ÃÂ¿ÃÂ»Ã‘Å½Ã‘ÂÃÂ¾ÃÂ¼).
func show_floating_number(amount: int, kind: String) -> void:
	if amount == 0 and kind != "miss":
		return
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# z_as_relative = false + ÃÂ²Ã‘â€¹Ã‘ÂÃÂ¾ÃÂºÃÂ¸ÃÂ¹ z_index ÃÂ³ÃÂ°Ã‘â‚¬ÃÂ°ÃÂ½Ã‘â€šÃÂ¸Ã‘â‚¬Ã‘Æ’ÃÂµÃ‘â€š ÃÂ¾Ã‘â€šÃ‘â‚¬ÃÂ¸Ã‘ÂÃÂ¾ÃÂ²ÃÂºÃ‘Æ’ ÃÂ¿ÃÂ¾ÃÂ²ÃÂµÃ‘â‚¬Ã‘â€¦ ÃÂ²Ã‘ÂÃÂµÃ‘â€¦ Ã‘ÂÃÂ»ÃÂ¾Ã‘â€˜ÃÂ² Ã‘ÂÃ‘â€ ÃÂµÃÂ½Ã‘â€¹.
	lbl.z_as_relative = false
	lbl.z_index = 1000
	var font_size := 42
	var col := Color(1, 1, 1, 1)
	var outline := Color(0.8, 0.0, 0.0, 1.0)
	var prefix := ""
	match kind:
		"miss":
			font_size = 44
			col = Color(1, 1, 1, 1)
			outline = Color(0, 0, 0, 1)
		"crit":
			font_size = 52  # ÃÂ½ÃÂ° ~20% ÃÂ±ÃÂ¾ÃÂ»Ã‘Å’Ã‘Ë†ÃÂµ ÃÂ±ÃÂ°ÃÂ·ÃÂ¾ÃÂ²ÃÂ¾ÃÂ³ÃÂ¾
			col = Color(1.0, 0.12, 0.12, 1.0)
			outline = Color(0.35, 0.0, 0.0, 1.0)
		"heal":
			col = Color(0.25, 1.0, 0.35, 1.0)
			outline = Color(0.0, 0.3, 0.0, 1.0)
			prefix = "+"
	lbl.text = "Промах" if kind == "miss" else prefix + str(amount)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", outline)
	lbl.add_theme_constant_override("outline_size", 8)
	add_child(lbl)
	# ÃÅ¸ÃÂ¾ÃÂ·ÃÂ¸Ã‘â€ ÃÂ¸Ã‘Â: ÃÂ½ÃÂ°ÃÂ´ ÃÂ³ÃÂ¾ÃÂ»ÃÂ¾ÃÂ²ÃÂ¾ÃÂ¹ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° (ÃÂ½ÃÂ¸ÃÂ· Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° ÃÂ½ÃÂ° feet_y=90, ÃÂ²ÃÂ²ÃÂµÃ‘â‚¬Ã‘â€¦ ÃÂ½ÃÂ° ÃÂ²Ã‘â€¹Ã‘ÂÃÂ¾Ã‘â€šÃ‘Æ’ Ã‘â€šÃÂµÃÂºÃ‘ÂÃ‘â€šÃ‘Æ’Ã‘â‚¬Ã‘â€¹).
	var tex_h := 180.0
	if sprite.texture:
		tex_h = sprite.texture.get_size().y * sprite.scale.y
	var start_y := SPRITE_FEET_Y - tex_h - 30.0
	lbl.position = Vector2(-70, start_y)
	lbl.size = Vector2(140, 56)
	# ÃÂÃÂ½ÃÂ¸ÃÂ¼ÃÂ°Ã‘â€ ÃÂ¸Ã‘Â: Ã‘â€¡ÃÂ¸Ã‘ÂÃÂ»ÃÂ¾ ÃÂ¿ÃÂ¾ÃÂ´ÃÂ½ÃÂ¸ÃÂ¼ÃÂ°ÃÂµÃ‘â€šÃ‘ÂÃ‘Â ÃÂ²ÃÂ²ÃÂµÃ‘â‚¬Ã‘â€¦ ÃÂ¸ ÃÂ¿ÃÂ»ÃÂ°ÃÂ²ÃÂ½ÃÂ¾ ÃÂ¸Ã‘ÂÃ‘â€¡ÃÂµÃÂ·ÃÂ°ÃÂµÃ‘â€š, ÃÂ·ÃÂ°Ã‘â€šÃÂµÃÂ¼ Ã‘Æ’ÃÂ´ÃÂ°ÃÂ»Ã‘ÂÃÂµÃ‘â€šÃ‘ÂÃ‘Â.
	# Ãâ€ÃÂ»ÃÂ¸Ã‘â€šÃÂµÃÂ»Ã‘Å’ÃÂ½ÃÂ¾Ã‘ÂÃ‘â€šÃÂ¸ Ã‘Æ’ÃÂ²ÃÂµÃÂ»ÃÂ¸Ã‘â€¡ÃÂµÃÂ½Ã‘â€¹, Ã‘â€¡Ã‘â€šÃÂ¾ÃÂ±Ã‘â€¹ Ã‘â€¡ÃÂ¸Ã‘ÂÃÂ»ÃÂ¾ ÃÂ±Ã‘â€¹ÃÂ»ÃÂ¾ Ã‘â€¦ÃÂ¾Ã‘â‚¬ÃÂ¾Ã‘Ë†ÃÂ¾ ÃÂ·ÃÂ°ÃÂ¼ÃÂµÃ‘â€šÃÂ½ÃÂ¾.
	var t := create_tween()
	t.tween_property(lbl, "position:y", start_y - 60.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.8)
	t.tween_callback(lbl.queue_free)

func _on_voice_line_used(text: String, audio: AudioStream) -> void:
	show_voice_line(text, audio)

## Проигрывает озвученную фразу (AbilityResource.voice_lines) и показывает облачко
## диалога с её текстом над головой спрайта (та же позиция "над головой", что и
## у show_floating_number: низ спрайта на SPRITE_FEET_Y, вверх на высоту текстуры).
func show_voice_line(text: String, audio: AudioStream) -> void:
	_ensure_voice_bubble()
	_ensure_voice_audio_player()
	if _voice_hide_tween != null and _voice_hide_tween.is_valid():
		_voice_hide_tween.kill()
	_voice_bubble_label.text = text
	_voice_bubble.modulate.a = 1.0
	_voice_bubble.visible = true
	# Ждём кадр разметки: MarginContainer/RichTextLabel с fit_content пересчитывают
	# размер только на следующем кадре — без этого позиция ниже использует старую
	# (или нулевую) высоту и облачко на миг залезает на спрайт/съезжает вниз.
	await get_tree().process_frame
	_voice_bubble.size = _voice_bubble_margin.size
	var tex_h := 180.0
	if sprite.texture:
		tex_h = sprite.texture.get_size().y * sprite.scale.y
	var head_y := SPRITE_FEET_Y - tex_h
	# Хвостик стоит у левого края облака (VOICE_BUBBLE_TAIL_X_RATIO), поэтому облако
	# сдвинуто вправо относительно головы ровно настолько, чтобы хвостик остался над
	# головой юнита (там же, где раньше был центр облака).
	_voice_bubble.position = Vector2(-_voice_bubble.size.x * VOICE_BUBBLE_TAIL_X_RATIO, head_y - VOICE_BUBBLE_GAP_ABOVE_HEAD - _voice_bubble.size.y)
	_clamp_voice_bubble_to_screen()
	if audio != null:
		_voice_audio_player.stream = audio
		_voice_audio_player.play()
	var duration := VOICE_BUBBLE_MIN_DURATION
	if audio != null:
		duration = maxf(VOICE_BUBBLE_MIN_DURATION, audio.get_length())
	_voice_hide_tween = create_tween()
	_voice_hide_tween.tween_interval(duration)
	_voice_hide_tween.tween_property(_voice_bubble, "modulate:a", 0.0, VOICE_BUBBLE_FADE_DURATION)
	_voice_hide_tween.tween_callback(func(): _voice_bubble.visible = false)

## Сдвигает облако по горизонтали так, чтобы оно целиком помещалось в видимую
## область экрана — иначе у юнитов на крайних позициях (особенно позиция 4,
## ближе всего к правому краю) облако с текстом могло вылезти за экран.
func _clamp_voice_bubble_to_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var global_left: float = _voice_bubble.global_position.x
	var global_right: float = global_left + _voice_bubble.size.x
	var overflow_right: float = global_right - (viewport_size.x - VOICE_BUBBLE_SCREEN_MARGIN)
	if overflow_right > 0.0:
		_voice_bubble.position.x -= overflow_right
		global_left = _voice_bubble.global_position.x
	if global_left < VOICE_BUBBLE_SCREEN_MARGIN:
		_voice_bubble.position.x += VOICE_BUBBLE_SCREEN_MARGIN - global_left

func _ensure_voice_bubble() -> void:
	if _voice_bubble != null:
		return
	var bubble_color := _get_voice_bubble_color()
	# Настоящее облачко диалога (скруглённый прямоугольник + хвостик), а не просто
	# прямоугольник — см. Scripts/speech_bubble_shape.gd. Само рисование фона/рамки
	# вынесено в SpeechBubbleShape; текст внутри раскладывает обычный MarginContainer.
	_voice_bubble = SpeechBubbleShape.new()
	_voice_bubble.z_as_relative = false
	_voice_bubble.z_index = 1000
	_voice_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_bubble.fill_color = Color(0.0, 0.0, 0.0, 0.9)
	_voice_bubble.border_color = bubble_color
	_voice_bubble.border_width = 2.0
	_voice_bubble.corner_radius = 10.0
	_voice_bubble.tail_width = 18.0
	_voice_bubble.tail_height = 12.0
	_voice_bubble.tail_x_ratio = VOICE_BUBBLE_TAIL_X_RATIO
	_voice_bubble_margin = MarginContainer.new()
	_voice_bubble_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_bubble_margin.add_theme_constant_override("margin_left", 10)
	_voice_bubble_margin.add_theme_constant_override("margin_right", 10)
	_voice_bubble_margin.add_theme_constant_override("margin_top", 6)
	_voice_bubble_margin.add_theme_constant_override("margin_bottom", 6)
	_voice_bubble.add_child(_voice_bubble_margin)
	_voice_bubble_label = RichTextLabel.new()
	_voice_bubble_label.bbcode_enabled = false
	_voice_bubble_label.fit_content = true
	_voice_bubble_label.scroll_active = false
	_voice_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_bubble_label.custom_minimum_size = Vector2(VOICE_BUBBLE_WIDTH - 20.0, 0)
	_voice_bubble_label.add_theme_font_size_override("normal_font_size", 15)
	_voice_bubble_label.add_theme_color_override("default_color", bubble_color)
	_voice_bubble_margin.add_child(_voice_bubble_label)
	_voice_bubble.visible = false
	add_child(_voice_bubble)

## Цвет текста/рамки облачка реплики для текущего юнита (см. VOICE_BUBBLE_GOD_COLORS).
## Белый — по умолчанию, для врагов и богов без своего цвета в списке.
func _get_voice_bubble_color() -> Color:
	if data == null or data.source_resource_path == "":
		return Color(1, 1, 1, 1)
	var folder := data.source_resource_path.get_base_dir().get_file()
	return VOICE_BUBBLE_GOD_COLORS.get(folder, Color(1, 1, 1, 1))

func _ensure_voice_audio_player() -> void:
	if _voice_audio_player != null:
		return
	_voice_audio_player = AudioStreamPlayer.new()
	_voice_audio_player.bus = "Voice"
	add_child(_voice_audio_player)

## Вспышка эффекта способности (напр. молния Зевса) поверх спрайта ЭТОГО юнита —
## плавно проявляется за ATTACK_FLASH_FADE_DURATION, потом так же плавно исчезает.
## Вызывается battle_scene.gd на визуале ЦЕЛИ удара, а не атакующего. Каждый вызов
## создаёт СВОЙ независимый узел и сам его удаляет по завершении — так несколько
## ударов подряд по одной и той же цели (Гнев Бога Грома, Нескончаемый шторм) каждый
## получает отдельную, самостоятельную анимацию, а не делят один и тот же узел/твин
## (что обрывало бы предыдущую вспышку при следующем ударе). Размер — по реальной
## (непрозрачной) высоте спрайта цели, как у обычных вражеских спрайтов, умноженной
## на scale_mult (AbilityResource.attack_effect_scale — по умолчанию 1.0, у молнии
## Зевса 2.0, крупнее для лучшей читаемости). Высокий z_index (как у
## show_floating_number) — рисуется поверх любых спрайтов на поле.
func show_attack_effect_flash(texture: Texture2D, scale_mult: float = 1.0) -> void:
	if texture == null:
		return
	var flash := TextureRect.new()
	flash.z_as_relative = false
	flash.z_index = 1001
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EXPAND_IGNORE_SIZE — иначе TextureRect игнорирует .size и всегда рисует
	# картинку в её родном (огромном, до масштабирования) размере текстуры.
	flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flash.texture = texture
	add_child(flash)
	var tex_h: float = _get_scaled_opaque_height()
	if tex_h <= 0.0:
		tex_h = 180.0
	tex_h *= maxf(0.01, scale_mult)
	var tex_w: float = tex_h * (float(texture.get_width()) / float(maxi(1, texture.get_height())))
	flash.size = Vector2(tex_w, tex_h)
	flash.position = Vector2(-tex_w * 0.5, SPRITE_FEET_Y - tex_h)
	flash.modulate.a = 0.0
	var tween := create_tween()
	# Бой стоит на паузе (Engine.time_scale=0), пока эта же вспышка не доиграет —
	# см. battle_scene.gd::_adjust_attack_effect_count(). Без ignore_time_scale твин
	# застрял бы на середине своей же собственной паузы и никогда бы не закончился.
	tween.set_ignore_time_scale(true)
	tween.tween_property(flash, "modulate:a", 1.0, ATTACK_FLASH_FADE_DURATION)
	tween.tween_property(flash, "modulate:a", 0.0, ATTACK_FLASH_FADE_DURATION)
	tween.tween_callback(flash.queue_free)
