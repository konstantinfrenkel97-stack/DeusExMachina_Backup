extends Button
## Кнопка-иконка с мгновенной текстовой подсказкой (без стандартной задержки Godot
## и без bbcode/картинок) — используется иконкой двери локации в бою.

var rule_text: String = ""
var _tooltip_panel: PanelContainer = null

func _ready() -> void:
	mouse_entered.connect(_show_instant_tooltip)
	mouse_exited.connect(_hide_instant_tooltip)

func _show_instant_tooltip() -> void:
	if rule_text == "" or _tooltip_panel != null:
		return
	var parent := get_parent()
	if parent == null:
		return
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.z_index = 500
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = rule_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(360, 0)
	margin.add_child(label)
	parent.add_child(_tooltip_panel)
	# Слева-снизу от иконки, чтобы подсказка не уходила за правый край экрана.
	_tooltip_panel.position = Vector2(position.x + size.x - 360 - 10, position.y + size.y + 6)

func _hide_instant_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.queue_free()
		_tooltip_panel = null

func _exit_tree() -> void:
	_hide_instant_tooltip()
