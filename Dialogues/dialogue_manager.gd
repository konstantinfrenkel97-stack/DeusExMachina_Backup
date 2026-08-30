extends Node

const DIALOGUE_PLAYER_SCENE := preload("res://Dialogues/dialogue_player.tscn")
const DIALOGUE_CANVAS_LAYER := 1000

signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
signal dialogue_choice_selected(dialogue_id: String, choice_id: String)

var _player = null
var _player_layer: CanvasLayer = null
var _bg_texture: TextureRect = null
var _dim_layer: ColorRect = null
# Небольшое затемнение фона под диалогом (что бы ни было позади — экран кампании,
# бой и т.п.) — как отдельный слой, ниже картинки диалога и самого проигрывателя.
const DIALOGUE_DIM_COLOR := Color(0.0, 0.0, 0.0, 0.35)

func show_dialogue(dialogue, bg_path: String = "") -> void:
	if dialogue == null:
		_clear_background()
		return
	_close_existing_player()
	var scene := get_tree().current_scene
	if scene == null:
		push_warning("DialogueManager: current_scene is null")
		return
	_player_layer = CanvasLayer.new()
	_player_layer.name = "DialogueTopLayer"
	_player_layer.layer = DIALOGUE_CANVAS_LAYER
	get_tree().root.add_child(_player_layer)
	_dim_layer = ColorRect.new()
	_dim_layer.name = "DialogueDim"
	_dim_layer.color = DIALOGUE_DIM_COLOR
	_dim_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_layer.add_child(_dim_layer)
	# Фон устанавливаем ПОСЛЕ создания слоя (раньше это делалось до создания слоя,
	# поэтому фон сразу терялся — для первого диалога слой был null, для следующих
	# фон создавался в старом слое, который затем удалялся).
	if bg_path.strip_edges() != "":
		_set_background(bg_path)
	else:
		_clear_background()
	_player = DIALOGUE_PLAYER_SCENE.instantiate()
	_player_layer.add_child(_player)
	_player.dialogue_closed.connect(_on_dialogue_closed)
	_player.choice_selected.connect(_on_dialogue_choice_selected)
	_player.start_dialogue(dialogue)
	emit_signal("dialogue_started", _dialogue_id(dialogue))

func show_dialogue_path(path: String, bg_path: String = "") -> void:
	if path.strip_edges() == "" or not ResourceLoader.exists(path):
		push_warning("DialogueManager: dialogue path not found: %s" % path)
		return
	var dialogue = load(path)
	if dialogue == null:
		push_warning("DialogueManager: failed to load dialogue: %s" % path)
		return
	show_dialogue(dialogue, bg_path)

func _set_background(bg_path: String) -> void:
	_clear_background()
	if bg_path.strip_edges() == "" or not ResourceLoader.exists(bg_path):
		return
	if _player_layer == null:
		return
	var tex = load(bg_path)
	if tex == null:
		return
	_bg_texture = TextureRect.new()
	_bg_texture.name = "DialogueBackground"
	_bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_texture.texture = tex
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_player_layer.add_child(_bg_texture)
	_player_layer.move_child(_bg_texture, 0)

func _clear_background() -> void:
	if _bg_texture != null and is_instance_valid(_bg_texture):
		_bg_texture.queue_free()
	_bg_texture = null

func is_active() -> bool:
	return _player != null and is_instance_valid(_player)

func close_dialogue() -> void:
	_close_existing_player()

func _close_existing_player() -> void:
	_clear_background()
	if _player_layer != null and is_instance_valid(_player_layer):
		_player_layer.queue_free()
	elif is_active():
		_player.queue_free()
	_player = null
	_player_layer = null
	_dim_layer = null

func _on_dialogue_closed(dialogue_id: String) -> void:
	if _player_layer != null and is_instance_valid(_player_layer):
		_player_layer.queue_free()
	_player = null
	_player_layer = null
	_dim_layer = null
	emit_signal("dialogue_finished", dialogue_id)

func _on_dialogue_choice_selected(dialogue_id: String, choice_id: String) -> void:
	emit_signal("dialogue_choice_selected", dialogue_id, choice_id)

func _dialogue_id(dialogue) -> String:
	if dialogue == null:
		return ""
	if dialogue.dialogue_id.strip_edges() != "":
		return dialogue.dialogue_id
	if dialogue.resource_path != "":
		return dialogue.resource_path
	return dialogue.dialogue_name