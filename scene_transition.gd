extends CanvasLayer
## Затемнение/высветление экрана при переходах между сценой миссии и боем (и обратно).
## Автозагрузчик — переживает change_scene_to_file, поэтому и оверлей, и сам переход
## (корутина ниже) не прерываются сменой сцены.

const FADE_DURATION := 0.75

var _fade_rect: ColorRect = null
var _fade_id: int = 0

func _ready() -> void:
	layer = 4096
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

## Затемняет экран за duration сек, меняет сцену на scene_path, затем высветляет
## обратно за duration сек. Не блокирует вызывающий код (fire-and-forget).
func change_scene_with_fade(scene_path: String, duration: float = FADE_DURATION) -> void:
	_fade_id += 1
	var my_id := _fade_id
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, duration)
	await fade_out.finished
	if my_id != _fade_id:
		return
	get_tree().change_scene_to_file(scene_path)
	# Даём новой сцене хотя бы пару кадров на инициализацию (_ready и т.п.),
	# прежде чем начинать высветление.
	await get_tree().process_frame
	await get_tree().process_frame
	if my_id != _fade_id:
		return
	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, duration)
	await fade_in.finished
	if my_id != _fade_id:
		return
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
