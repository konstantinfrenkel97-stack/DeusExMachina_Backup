extends Control
class_name DialoguePlayer

signal dialogue_closed(dialogue_id: String)
signal choice_selected(dialogue_id: String, choice_id: String)

const SPEAKER_REGISTRY_PATH := "res://Dialogues/speaker_profiles.tres"
const SPEAKER_LINE_HEIGHT := 40.0
const SPEAKER_PLACEHOLDER := " "
const PORTRAIT_BOTTOM_EDGE_RATIO := 4.0 / 3.0
const PORTRAIT_SIDE_OVERHANG := 20.0
const PORTRAIT_TOP_GAP_RATIO := 1.0 / 4.0
const MIRRORED_EDGE_HIDE := 24.0
const CHOICES_PANEL_WIDTH := 680.0
const CHOICE_BUTTON_HEIGHT := 54.0
const CHOICE_BUTTON_FONT_SIZE := 22

@onready var close_button: Button = $CloseButton
@onready var portrait_anchor: Control = $PortraitAnchor
@onready var portrait_rect: TextureRect = $PortraitAnchor/Portrait
@onready var speaker_label: Label = $Panel/Margin/VBox/SpeakerName
@onready var body_label: RichTextLabel = $Panel/Margin/VBox/BodyText
@onready var choices_container: VBoxContainer = $Panel/Margin/VBox/Choices

var _dialogue = null
var _current_index: int = -1
var _speaker_registry: DialogueSpeakerRegistry = null
var _choices_center: Control = null

func _ready() -> void:
	_load_speaker_registry()
	close_button.pressed.connect(_finish_dialogue)
	speaker_label.custom_minimum_size = Vector2(0, SPEAKER_LINE_HEIGHT)
	speaker_label.gui_input.connect(_on_text_gui_input)
	body_label.gui_input.connect(_on_text_gui_input)
	body_label.bbcode_enabled = true
	body_label.scroll_active = false
	portrait_anchor.clip_contents = true
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_setup_choices_overlay()

func _setup_choices_overlay() -> void:
	var old_parent: Node = choices_container.get_parent()
	if old_parent != null:
		old_parent.remove_child(choices_container)
	_choices_center = Control.new()
	_choices_center.name = "ChoicesCenter"
	_choices_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices_center.z_index = 30
	add_child(_choices_center)
	_choices_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choices_center.offset_left = 0.0
	_choices_center.offset_top = 0.0
	_choices_center.offset_right = 0.0
	_choices_center.offset_bottom = 0.0
	choices_container.custom_minimum_size = Vector2(CHOICES_PANEL_WIDTH, 0)
	choices_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_choices_center.add_child(choices_container)
	_choices_center.visible = false
	_layout_choices_overlay()

func _load_speaker_registry() -> void:
	if not ResourceLoader.exists(SPEAKER_REGISTRY_PATH):
		return
	var loaded: Resource = load(SPEAKER_REGISTRY_PATH)
	_speaker_registry = loaded as DialogueSpeakerRegistry

func start_dialogue(dialogue) -> void:
	_dialogue = dialogue
	_current_index = dialogue.get_start_index() if dialogue != null else -1
	_show_current_line()

func _input(event: InputEvent) -> void:
	if not visible or _dialogue == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if close_button.get_global_rect().has_point(event.position):
			return
		if _can_advance_current_line():
			_advance()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _dialogue == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_finish_dialogue()
			get_viewport().set_input_as_handled()
			return
		if _can_advance_current_line() and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_advance()
			get_viewport().set_input_as_handled()

func _show_current_line() -> void:
	_clear_choices()
	var line = _get_current_line()
	if line == null:
		_finish_dialogue()
		return
	var profile: DialogueSpeakerProfile = _get_speaker_profile(line)
	var is_mirrored: bool = _get_effective_mirror_layout(line, profile)
	var line_sprite: Texture2D = _get_effective_sprite(line, profile)
	var portrait_scale_percent := _get_effective_portrait_scale_percent(line, profile)
	var portrait_y_offset_percent := _get_effective_portrait_y_offset_percent(profile)
	_apply_line_layout(is_mirrored)
	var raw_speaker_name: String = line.speaker_name.strip_edges()
	var speaker_name: String = Localization.t(str(line.get("speaker_name_key")), raw_speaker_name)
	speaker_label.text = speaker_name if speaker_name != "" else SPEAKER_PLACEHOLDER
	speaker_label.visible = true
	body_label.text = Localization.t(str(line.get("text_key")), line.text)
	if line_sprite != null:
		portrait_rect.texture = line_sprite
		portrait_rect.flip_h = is_mirrored
		_apply_mirrored_edge_hide(is_mirrored)
		_update_portrait_geometry(line_sprite, is_mirrored, portrait_scale_percent, portrait_y_offset_percent)
		portrait_anchor.visible = true
	else:
		portrait_rect.texture = null
		portrait_rect.flip_h = false
		_apply_mirrored_edge_hide(false)
		portrait_anchor.visible = false
	for choice in line.choices:
		if choice == null:
			continue
		var button := Button.new()
		button.text = Localization.t(str(choice.get("choice_text_key")), choice.choice_text)
		button.custom_minimum_size = Vector2(CHOICES_PANEL_WIDTH, CHOICE_BUTTON_HEIGHT)
		button.add_theme_font_size_override("font_size", CHOICE_BUTTON_FONT_SIZE)
		button.pressed.connect(_on_choice_pressed.bind(choice))
		choices_container.add_child(button)
	if _choices_center != null:
		_layout_choices_overlay()
		_choices_center.visible = choices_container.get_child_count() > 0

func _layout_choices_overlay() -> void:
	if _choices_center == null or choices_container == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_choices_center.position = Vector2.ZERO
	var count: int = choices_container.get_child_count()
	var separation: int = choices_container.get_theme_constant("separation")
	var height: float = float(count) * CHOICE_BUTTON_HEIGHT + float(maxi(0, count - 1) * separation)
	var panel_size := Vector2(CHOICES_PANEL_WIDTH, height)
	choices_container.custom_minimum_size = panel_size
	choices_container.size = panel_size
	choices_container.position = Vector2(
		floor((viewport_size.x - panel_size.x) * 0.5),
		floor((viewport_size.y - panel_size.y) * 0.5)
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_choices_overlay()

func _get_speaker_profile(line) -> DialogueSpeakerProfile:
	if line == null or _speaker_registry == null:
		return null
	return _speaker_registry.find_profile(line.speaker_name)

func _get_effective_mirror_layout(line, profile: DialogueSpeakerProfile) -> bool:
	if line == null:
		return false
	if line.layout_mode == DialogueLine.LAYOUT_LEFT:
		return false
	if line.layout_mode == DialogueLine.LAYOUT_RIGHT:
		return true
	if profile != null and profile.auto_fill_layout:
		return profile.default_mirror_layout
	return line.mirror_layout

func _get_effective_sprite(line, profile: DialogueSpeakerProfile) -> Texture2D:
	if line == null:
		return null
	if line.sprite != null:
		return line.sprite
	if profile != null and profile.auto_fill_sprite:
		return profile.load_default_sprite()
	return null

func _get_effective_portrait_scale_percent(line, profile: DialogueSpeakerProfile) -> float:
	if line != null and line.portrait_scale_percent > 0.0:
		return line.portrait_scale_percent
	if profile != null:
		return profile.get_portrait_scale_percent()
	return 100.0

func _get_effective_portrait_y_offset_percent(profile: DialogueSpeakerProfile) -> float:
	if profile != null:
		return profile.get_portrait_y_offset_percent()
	return 0.0

func _apply_line_layout(is_mirrored: bool) -> void:
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_mirrored else HORIZONTAL_ALIGNMENT_LEFT

func _apply_mirrored_edge_hide(is_mirrored: bool) -> void:
	portrait_rect.offset_top = 0.0
	portrait_rect.offset_right = 0.0
	portrait_rect.offset_bottom = 0.0
	portrait_rect.offset_left = -MIRRORED_EDGE_HIDE if is_mirrored else 0.0

func _update_portrait_geometry(texture: Texture2D, is_mirrored: bool, scale_percent: float, y_offset_percent: float = 0.0) -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.y <= 0.0:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var top_gap: float = viewport_size.y * PORTRAIT_TOP_GAP_RATIO
	var bottom_edge: float = viewport_size.y * PORTRAIT_BOTTOM_EDGE_RATIO
	var scale_factor := maxf(0.01, scale_percent / 100.0)
	var target_height: float = (bottom_edge - top_gap) * scale_factor
	var target_width: float = float(tex_size.x) * target_height / tex_size.y
	# Положительный % поднимает портрет вверх — как и battle_sprite_y_offset_percent в бою.
	bottom_edge -= target_height * (y_offset_percent / 100.0)
	var top_edge: float = bottom_edge - target_height
	portrait_anchor.anchor_left = 0.0
	portrait_anchor.anchor_top = 0.0
	portrait_anchor.anchor_right = 0.0
	portrait_anchor.anchor_bottom = 0.0
	var left := -PORTRAIT_SIDE_OVERHANG
	if is_mirrored:
		left = viewport_size.x - target_width + PORTRAIT_SIDE_OVERHANG
	portrait_anchor.offset_left = left
	portrait_anchor.offset_top = top_edge
	portrait_anchor.offset_right = left + target_width
	portrait_anchor.offset_bottom = bottom_edge

func _on_text_gui_input(event: InputEvent) -> void:
	if not _can_advance_current_line():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()

func _on_choice_pressed(choice) -> void:
	emit_signal("choice_selected", _get_dialogue_id(), choice.choice_id)
	if choice.end_dialogue:
		_finish_dialogue()
		return
	if choice.next_dialogue != null:
		start_dialogue(choice.next_dialogue)
		return
	if _jump_to_line(choice.next_line_id):
		return
	_advance_default()

func _advance() -> void:
	var line = _get_current_line()
	if line == null:
		_finish_dialogue()
		return
	if line.next_dialogue != null:
		start_dialogue(line.next_dialogue)
		return
	if _jump_to_line(line.next_line_id):
		return
	_advance_default()

func _advance_default() -> void:
	if _dialogue == null:
		_finish_dialogue()
		return
	var next_index: int = _current_index + 1
	if next_index >= _dialogue.lines.size():
		_finish_dialogue()
		return
	_current_index = next_index
	_show_current_line()

func _jump_to_line(line_id: String) -> bool:
	if _dialogue == null or line_id.strip_edges() == "":
		return false
	var index: int = _dialogue.find_line_index(line_id)
	if index == -1:
		return false
	_current_index = index
	_show_current_line()
	return true

func _can_advance_current_line() -> bool:
	var line = _get_current_line()
	return line != null and line.choices.is_empty()

func _get_current_line():
	if _dialogue == null or _current_index < 0 or _current_index >= _dialogue.lines.size():
		return null
	return _dialogue.lines[_current_index]

func _clear_choices() -> void:
	if _choices_center != null:
		_choices_center.visible = false
	for child in choices_container.get_children():
		child.queue_free()

func _finish_dialogue() -> void:
	var dialogue_id := _get_dialogue_id()
	emit_signal("dialogue_closed", dialogue_id)
	queue_free()

func _get_dialogue_id() -> String:
	if _dialogue == null:
		return ""
	if _dialogue.dialogue_id.strip_edges() != "":
		return _dialogue.dialogue_id
	if _dialogue.resource_path != "":
		return _dialogue.resource_path
	return _dialogue.dialogue_name
