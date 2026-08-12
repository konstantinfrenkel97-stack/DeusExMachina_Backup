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
var majesty_bar: ProgressBar = null
var flash_sprite: Sprite2D = null
var flash_tween: Tween = null
var _outline: Line2D = null
var _effect_icon_row: HBoxContainer = null
var _sprite_opaque_bounds := Rect2()
var _status_bar_width := 130.0
var _status_hp_height := HP_BAR_HEIGHT
var _status_majesty_height := MAJESTY_BAR_HEIGHT

func _ready():
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

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

		# ÃÅ¾ÃÂ±ÃÂ²ÃÂ¾ÃÂ´ÃÂºÃÂ° ÃÂ°ÃÂºÃ‘â€šÃÂ¸ÃÂ²ÃÂ½ÃÂ¾ÃÂ³ÃÂ¾ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃÂ° (Ã‘â€¡ÃÂµÃÂ¹ Ã‘â€¦ÃÂ¾ÃÂ´): ÃÂ·ÃÂ¾ÃÂ»ÃÂ¾Ã‘â€šÃÂ°Ã‘Â Ã‘â‚¬ÃÂ°ÃÂ¼ÃÂºÃÂ° ÃÂ²ÃÂ¾ÃÂºÃ‘â‚¬Ã‘Æ’ÃÂ³ HP-ÃÂ±ÃÂ°Ã‘â‚¬ÃÂ°.
		# ÃÂ¦ÃÂ²ÃÂµÃ‘â€š ÃÂ·ÃÂ°ÃÂ»ÃÂ¸ÃÂ²ÃÂºÃÂ¸ HP-ÃÂ±ÃÂ°Ã‘â‚¬ÃÂ° ÃÂÃâ€¢ ÃÂ¼ÃÂµÃÂ½Ã‘ÂÃÂµÃ‘â€šÃ‘ÂÃ‘Â. Ãâ€™ÃÂ¸ÃÂ´ÃÂ½ÃÂ° Ã‘â€šÃÂ¾ÃÂ»Ã‘Å’ÃÂºÃÂ¾ ÃÂ´ÃÂ»Ã‘Â Ã‘â€¦ÃÂ¾ÃÂ´Ã‘ÂÃ‘â€°ÃÂµÃÂ³ÃÂ¾ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃÂ° (Ã‘ÂÃÂ¼. set_active).
		var _ol_width = 4.0
		var _ol_half_width = _ol_width * 0.5
		var _ol_left = -bar_width * 0.5 - _ol_half_width
		var _ol_right = bar_width * 0.5 + _ol_half_width
		var _ol_top = hp_y - _ol_half_width
		var _ol_bottom = hp_y + bar_h - _ol_half_width
		_outline = Line2D.new()
		_outline.width = _ol_width
		_outline.default_color = Color(1.0, 0.85, 0.2, 1.0)
		_outline.joint_mode = Line2D.LINE_JOINT_ROUND
		_outline.z_index = 11
		_outline.points = PackedVector2Array([
			Vector2(_ol_left, _ol_top),
			Vector2(_ol_right, _ol_top),
			Vector2(_ol_right, _ol_bottom),
			Vector2(_ol_left, _ol_bottom),
			Vector2(_ol_left, _ol_top),
		])
		_outline.visible = false
		add_child(_outline)

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
	if _outline:
		var line_width: float = _outline.width
		var half_width: float = line_width * 0.5
		var left: float = -bar_width * 0.5 - half_width
		var right: float = bar_width * 0.5 + half_width
		var top: float = hp_y - half_width
		var bottom: float = hp_y + bar_h - half_width
		_outline.points = PackedVector2Array([
			Vector2(left, top),
			Vector2(right, top),
			Vector2(right, bottom),
			Vector2(left, bottom),
			Vector2(left, top),
		])
		
func update_visuals():
	if data == null:
		return
	_refresh_runtime_sprite_scale_percent()
		
	# ÃÅ¾ÃÂ³ÃÂ»Ã‘Æ’Ã‘Ë†Ã‘â€˜ÃÂ½ÃÂ½Ã‘â€¹ÃÂ¹ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€š ÃÂ²ÃÂ¸ÃÂ·Ã‘Æ’ÃÂ°ÃÂ»Ã‘Å’ÃÂ½ÃÂ¾ Ã‘ÂÃÂµÃ‘â‚¬ÃÂµÃÂµÃ‘â€š ÃÂ¸ Ã‘ÂÃ‘â€šÃÂ°ÃÂ½ÃÂ¾ÃÂ²ÃÂ¸Ã‘â€šÃ‘ÂÃ‘Â ÃÂ¿ÃÂ¾ÃÂ»Ã‘Æ’ÃÂ¿Ã‘â‚¬ÃÂ¾ÃÂ·Ã‘â‚¬ÃÂ°Ã‘â€¡ÃÂ½Ã‘â€¹ÃÂ¼ (50%).
	if data.is_stunned:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		sprite.modulate = Color(1, 1, 1, 1)

	hp_bar.value = data.current_hp
	if majesty_bar:
		majesty_bar.value = data.current_majesty
	_update_hp_text()
	_refresh_effect_icons()


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
		var icon_width := EFFECT_ICON_HEIGHT
		if texture.get_height() > 0:
			icon_width = maxf(EFFECT_ICON_HEIGHT, texture.get_width() * EFFECT_ICON_HEIGHT / texture.get_height())
		icon.custom_minimum_size = Vector2(icon_width, EFFECT_ICON_HEIGHT)
		icon.size = Vector2(icon_width, EFFECT_ICON_HEIGHT)
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
		grouped["innocence_mark"].append("ÃÅ“ÃÂµÃ‘â€šÃÂºÃÂ° ÃÂ½ÃÂµÃÂ²ÃÂ¸ÃÂ½ÃÂ½ÃÂ¾Ã‘ÂÃ‘â€šÃÂ¸: 50% Ã‘Ë†ÃÂ°ÃÂ½Ã‘Â ÃÂ¿ÃÂµÃ‘â‚¬ÃÂµÃÂ½ÃÂ°ÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ²ÃÂ¸Ã‘â€šÃ‘Å’ ÃÂ°Ã‘â€šÃÂ°ÃÂºÃ‘Æ’ ÃÂ½ÃÂ° Ã‘ÂÃÂ»Ã‘Æ’Ã‘â€¡ÃÂ°ÃÂ¹ÃÂ½ÃÂ¾ÃÂ³ÃÂ¾ Ã‘ÂÃÂ¾Ã‘Å½ÃÂ·ÃÂ½ÃÂ¸ÃÂºÃÂ°")
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
	if key.contains("voodoo") or key.contains("vodoo") or key.contains("curse") or key.contains("ÃÂ¿Ã‘â‚¬ÃÂ¾ÃÂºÃÂ»Ã‘Â"):
		return "voodoo_curse"
	if stat == "trigger_marker":
		return ""
	var value := int(Combatant._effect_get(effect, "value", 0))
	if stat == "stun" or value < 0:
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
		title = effect_id
	if title == "":
		title = _effect_stat_title(stat)
	var value_text := _effect_value_text(stat, value)
	var duration_text := _effect_duration_text(effect_id, duration)
	return "%s: %s, %s" % [title, value_text, duration_text]

func _format_stance_tooltip_line(stance: AbilityResource) -> String:
	var details := "ÃÂ¡Ã‘â€šÃÂ¾ÃÂ¹ÃÂºÃÂ°: %s" % stance.name
	if stance.stance_effect_type != "":
		details += "\nÃÂ­Ã‘â€žÃ‘â€žÃÂµÃÂºÃ‘â€š: %s" % stance.stance_effect_type
	if stance.stance_duration_type != "":
		details += "\nÃâ€ÃÂ»ÃÂ¸Ã‘â€šÃÂµÃÂ»Ã‘Å’ÃÂ½ÃÂ¾Ã‘ÂÃ‘â€šÃ‘Å’: %s" % stance.stance_duration_type
	return details

func _effect_value_text(stat: String, value: int) -> String:
	if stat == "periodic_damage":
		return "ÃÂ¿ÃÂµÃ‘â‚¬ÃÂ¸ÃÂ¾ÃÂ´ÃÂ¸Ã‘â€¡ÃÂµÃ‘ÂÃÂºÃÂ¸ÃÂ¹ Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ½ %d" % value
	if stat == "regeneration":
		return "Ã‘â‚¬ÃÂµÃÂ³ÃÂµÃÂ½ÃÂµÃ‘â‚¬ÃÂ°Ã‘â€ ÃÂ¸Ã‘Â %d%%" % value
	if stat == "stun":
		return "ÃÂ¾ÃÂ³ÃÂ»Ã‘Æ’Ã‘Ë†ÃÂµÃÂ½ÃÂ¸ÃÂµ"
	if stat == "trigger_marker":
		return "Ã‘Æ’ÃÂ½ÃÂ¸ÃÂºÃÂ°ÃÂ»Ã‘Å’ÃÂ½ÃÂ°Ã‘Â ÃÂ¼ÃÂµÃ‘â€šÃÂºÃÂ°"
	if value > 0:
		return "+%d ÃÂº %s" % [value, _effect_stat_title(stat)]
	if value < 0:
		return "%d ÃÂº %s" % [value, _effect_stat_title(stat)]
	return _effect_stat_title(stat)

func _effect_duration_text(effect_id: String, duration: int) -> String:
	var shown_duration := duration
	if effect_id == "thor_hammer_of_lightning" and duration > 0:
		shown_duration = maxi(1, duration - 1)
	if shown_duration < 0:
		return "ÃÂ´ÃÂ¾ ÃÂºÃÂ¾ÃÂ½Ã‘â€ ÃÂ° ÃÂ±ÃÂ¾Ã‘Â"
	if shown_duration == 0:
		return "ÃÂ·ÃÂ°ÃÂºÃÂ°ÃÂ½Ã‘â€¡ÃÂ¸ÃÂ²ÃÂ°ÃÂµÃ‘â€šÃ‘ÂÃ‘Â"
	return "%d Ã‘â€¦ÃÂ¾ÃÂ´(ÃÂ¾ÃÂ²)" % shown_duration

func _effect_stat_title(stat: String) -> String:
	match stat:
		"hp": return "ÃÂ·ÃÂ´ÃÂ¾Ã‘â‚¬ÃÂ¾ÃÂ²Ã‘Å’ÃÂµ"
		"max_hp": return "ÃÂ¼ÃÂ°ÃÂºÃ‘Â. ÃÂ·ÃÂ´ÃÂ¾Ã‘â‚¬ÃÂ¾ÃÂ²Ã‘Å’ÃÂµ"
		"damage": return "Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ½"
		"armor": return "ÃÂ±Ã‘â‚¬ÃÂ¾ÃÂ½Ã‘Â"
		"accuracy": return "Ã‘â€šÃÂ¾Ã‘â€¡ÃÂ½ÃÂ¾Ã‘ÂÃ‘â€šÃ‘Å’"
		"evasion": return "Ã‘Æ’ÃÂºÃÂ»ÃÂ¾ÃÂ½ÃÂµÃÂ½ÃÂ¸ÃÂµ"
		"crit": return "ÃÂºÃ‘â‚¬ÃÂ¸Ã‘â€š"
		"initiative": return "ÃÂ¸ÃÂ½ÃÂ¸Ã‘â€ ÃÂ¸ÃÂ°Ã‘â€šÃÂ¸ÃÂ²ÃÂ°"
		"provocation_mark": return "ÃÂ¼ÃÂµÃ‘â€šÃÂºÃÂ° ÃÂ¿Ã‘â‚¬ÃÂ¾ÃÂ²ÃÂ¾ÃÂºÃÂ°Ã‘â€ ÃÂ¸ÃÂ¸"
		"invulnerable": return "ÃÂ½ÃÂµÃ‘Æ’Ã‘ÂÃÂ·ÃÂ²ÃÂ¸ÃÂ¼ÃÂ¾Ã‘ÂÃ‘â€šÃ‘Å’"
		_: return stat
## Ãâ€™Ã‘ÂÃÂ¿Ã‘â€¹Ã‘Ë†ÃÂºÃÂ° ÃÂºÃ‘â‚¬ÃÂ°Ã‘ÂÃÂ½Ã‘â€¹ÃÂ¼ ÃÂ¿ÃÂ¾ÃÂ²ÃÂµÃ‘â‚¬Ã‘â€¦ Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° Ã¢â‚¬â€ ÃÂ²ÃÂ¸ÃÂ·Ã‘Æ’ÃÂ°ÃÂ»Ã‘Å’ÃÂ½ÃÂ¾ ÃÂ¿ÃÂµÃ‘â‚¬ÃÂµÃÂ´ÃÂ°Ã‘â€˜Ã‘â€š ÃÂ¿ÃÂ¾ÃÂ»Ã‘Æ’Ã‘â€¡ÃÂµÃÂ½ÃÂ¸ÃÂµ Ã‘Æ’Ã‘â‚¬ÃÂ¾ÃÂ½ÃÂ° (0.75 Ã‘Â, 50%).
func flash_damage():
	if flash_sprite == null:
		return
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_sprite.modulate = Color(1, 0, 0, 0)
	flash_tween = create_tween()
	flash_tween.tween_property(flash_sprite, "modulate:a", 0.5, 0.05)
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
	_apply_sprite_scale_keep_feet(_base_sprite_scale)

func _refresh_runtime_sprite_scale_percent() -> void:
	if data == null:
		return
	if data.source_resource_path != "" and ResourceLoader.exists(data.source_resource_path):
		var live_resource := ResourceLoader.load(data.source_resource_path, "", ResourceLoader.CACHE_MODE_REPLACE) as CharacterResource
		if live_resource != null:
			data.battle_sprite_scale_percent = live_resource.battle_sprite_scale_percent
	if absf(data.battle_sprite_scale_percent - _applied_sprite_scale_percent) > 0.001:
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
func _apply_sprite_scale_keep_feet(new_scale: Vector2) -> void:
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
	sprite.position = Vector2(0, SPRITE_FEET_Y - opaque_bottom_from_center * absf(sprite.scale.y) + osiris_set_vertical_offset)
	if collision_shape != null:
		var opaque_center_from_texture_center := bounds.position + bounds.size * 0.5 - texture_size * 0.5
		collision_shape.position = sprite.position + Vector2(opaque_center_from_texture_center.x * sprite.scale.x, opaque_center_from_texture_center.y * sprite.scale.y)
		var shape := collision_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(bounds.size.x * absf(sprite.scale.x), bounds.size.y * absf(sprite.scale.y))
	if flash_sprite != null:
		flash_sprite.scale = sprite.scale
		flash_sprite.position = sprite.position

## ÃÅ¾ÃÂ±ÃÂ²ÃÂ¾ÃÂ´ÃÂºÃÂ° Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€šÃÂ° ÃÂ°ÃÂºÃ‘â€šÃÂ¸ÃÂ²ÃÂ½ÃÂ¾ÃÂ³ÃÂ¾ Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃÂ° (Ã‘â€¡ÃÂµÃÂ¹ Ã‘ÂÃÂµÃÂ¹Ã‘â€¡ÃÂ°Ã‘Â Ã‘â€¦ÃÂ¾ÃÂ´). ÃÂ¦ÃÂ²ÃÂµÃ‘â€š HP-ÃÂ±ÃÂ°Ã‘â‚¬ÃÂ° ÃÂÃâ€¢ ÃÂ¼ÃÂµÃÂ½Ã‘ÂÃÂµÃ‘â€šÃ‘ÂÃ‘Â.
func set_active(active: bool) -> void:
	if _outline:
		_outline.visible = active

## ÃÅ¸ÃÂ¾ÃÂ´Ã‘ÂÃÂ²ÃÂµÃ‘â€šÃÂºÃÂ° ÃÂ¿Ã‘â‚¬ÃÂ¸ ÃÂ½ÃÂ°ÃÂ²ÃÂµÃÂ´ÃÂµÃÂ½ÃÂ¸ÃÂ¸ ÃÂ½ÃÂ° ÃÂ¿ÃÂ¾Ã‘â‚¬Ã‘â€šÃ‘â‚¬ÃÂµÃ‘â€š Ã‘Å½ÃÂ½ÃÂ¸Ã‘â€šÃÂ° (ÃÂ½ÃÂ°ÃÂ¿Ã‘â‚¬ÃÂ¸ÃÂ¼ÃÂµÃ‘â‚¬, ÃÂ¸ÃÂ· ÃÂ¿ÃÂ¾ÃÂ»ÃÂ¾Ã‘ÂÃ‘â€¹ ÃÂ¾Ã‘â€¡ÃÂµÃ‘â‚¬ÃÂµÃÂ´ÃÂ¸ Ã‘â€¦ÃÂ¾ÃÂ´ÃÂ¾ÃÂ²):
## Ã‘ÂÃÂ¿Ã‘â‚¬ÃÂ°ÃÂ¹Ã‘â€š Ã‘ÂÃÂ»ÃÂµÃÂ³ÃÂºÃÂ° Ã‘Æ’ÃÂ²ÃÂµÃÂ»ÃÂ¸Ã‘â€¡ÃÂ¸ÃÂ²ÃÂ°ÃÂµÃ‘â€šÃ‘ÂÃ‘Â ÃÂ¸ ÃÂ¿ÃÂ¾Ã‘ÂÃÂ²ÃÂ»Ã‘ÂÃÂµÃ‘â€šÃ‘ÂÃ‘Â ÃÂ¸ÃÂ¼Ã‘Â Ã¢â‚¬â€ Ã‘â€¡Ã‘â€šÃÂ¾ÃÂ±Ã‘â€¹ ÃÂ±Ã‘â€¹ÃÂ»ÃÂ¾ ÃÂ²ÃÂ¸ÃÂ´ÃÂ½ÃÂ¾, ÃÂºÃÂ¾ÃÂ³ÃÂ¾ ÃÂ²Ã‘â€¹ÃÂ±Ã‘â‚¬ÃÂ°ÃÂ»ÃÂ¸.
func set_hover(hovered: bool) -> void:
	if sprite == null or sprite.texture == null:
		return
	_apply_sprite_scale_keep_feet(_base_sprite_scale * (1.15 if hovered else 1.0))
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
	if amount == 0:
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
		"crit":
			font_size = 52  # ÃÂ½ÃÂ° ~20% ÃÂ±ÃÂ¾ÃÂ»Ã‘Å’Ã‘Ë†ÃÂµ ÃÂ±ÃÂ°ÃÂ·ÃÂ¾ÃÂ²ÃÂ¾ÃÂ³ÃÂ¾
			col = Color(1.0, 0.12, 0.12, 1.0)
			outline = Color(0.35, 0.0, 0.0, 1.0)
		"heal":
			col = Color(0.25, 1.0, 0.35, 1.0)
			outline = Color(0.0, 0.3, 0.0, 1.0)
			prefix = "+"
	lbl.text = prefix + str(amount)
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
