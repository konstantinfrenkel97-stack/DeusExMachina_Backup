extends Control
class_name GodRosterSlot

signal god_double_clicked(god_path: String)
signal god_dialogue_requested(god_path: String)
signal swap_requested(from_index: int, to_index: int)

const SLOT_SIZE := Vector2(72, 82)
const PORTRAIT_MARGIN := 4.0
const PORTRAIT_BOTTOM_GAP := 14.0
const DIALOGUE_BUTTON_SIZE := 20.0
const HP_BAR_HEIGHT := 5.0

var slot_index: int = -1
var god_path: String = ""

var _bg: ColorRect
var _portrait: TextureRect
var _dialogue_button: Button
var _hp_bar: ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SLOT_SIZE

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.12, 0.12, 0.16, 0.9)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_portrait = TextureRect.new()
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = PORTRAIT_MARGIN
	_portrait.offset_top = PORTRAIT_MARGIN
	_portrait.offset_right = -PORTRAIT_MARGIN
	_portrait.offset_bottom = -PORTRAIT_BOTTOM_GAP
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	_hp_bar = _make_hp_bar()
	_hp_bar.anchor_left = 0.0
	_hp_bar.anchor_top = 1.0
	_hp_bar.anchor_right = 1.0
	_hp_bar.anchor_bottom = 1.0
	_hp_bar.offset_left = PORTRAIT_MARGIN
	_hp_bar.offset_top = -HP_BAR_HEIGHT - PORTRAIT_MARGIN
	_hp_bar.offset_right = -PORTRAIT_MARGIN
	_hp_bar.offset_bottom = -PORTRAIT_MARGIN
	_hp_bar.visible = false
	add_child(_hp_bar)

	_dialogue_button = Button.new()
	_dialogue_button.anchor_left = 1.0
	_dialogue_button.anchor_top = 0.0
	_dialogue_button.anchor_right = 1.0
	_dialogue_button.anchor_bottom = 0.0
	_dialogue_button.offset_left = -DIALOGUE_BUTTON_SIZE - 4.0
	_dialogue_button.offset_top = 4.0
	_dialogue_button.offset_right = -4.0
	_dialogue_button.offset_bottom = DIALOGUE_BUTTON_SIZE + 4.0
	_dialogue_button.custom_minimum_size = Vector2(DIALOGUE_BUTTON_SIZE, DIALOGUE_BUTTON_SIZE)
	_dialogue_button.text = "💬"
	_dialogue_button.tooltip_text = "Диалог"
	_dialogue_button.focus_mode = Control.FOCUS_NONE
	_dialogue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dialogue_button.visible = false
	_dialogue_button.pressed.connect(_on_dialogue_button_pressed)
	add_child(_dialogue_button)

func set_god(path: String) -> void:
	god_path = path
	if path == "":
		_portrait.texture = null
		_portrait.tooltip_text = ""
		_dialogue_button.visible = false
		_hp_bar.visible = false
		return
	var res := CampaignState.load_character_resource(path)
	if res == null:
		_portrait.texture = null
		_dialogue_button.visible = false
		_hp_bar.visible = false
		return
	var tex: Texture2D = null
	if res.face_sprite != "":
		tex = load(res.face_sprite) as Texture2D
	if tex == null and res.sprite_path != "":
		tex = load(res.sprite_path) as Texture2D
	_portrait.texture = tex
	_portrait.tooltip_text = res.unit_name
	_dialogue_button.visible = true
	_refresh_hp_bar()

func _process(_delta: float) -> void:
	if god_path != "":
		_refresh_hp_bar()

func _make_hp_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.02, 0.02, 1.0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _refresh_hp_bar() -> void:
	if _hp_bar == null or god_path == "":
		return
	var max_hp := CampaignState.get_god_max_hp(god_path)
	_hp_bar.max_value = maxi(1, max_hp)
	_hp_bar.value = CampaignState.get_god_current_hp(god_path)
	_hp_bar.visible = _portrait.texture != null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if god_path != "":
			god_double_clicked.emit(god_path)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if god_path == "":
		return null
	var data := {"index": slot_index, "path": god_path}
	var preview := TextureRect.new()
	preview.texture = _portrait.texture
	preview.custom_minimum_size = SLOT_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return data

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("index"):
		var from_idx: int = int(data["index"])
		if from_idx != slot_index:
			swap_requested.emit(from_idx, slot_index)

func _on_dialogue_button_pressed() -> void:
	if god_path != "":
		god_dialogue_requested.emit(god_path)