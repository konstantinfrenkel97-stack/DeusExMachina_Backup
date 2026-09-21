extends RefCounted
class_name HelpButtonFactory

## Круглая золотая кнопка "?" — единый вид для всех мест, где игрок может открыть
## список подсказок: бой, кампания (над чёрной областью снизу), выбор отряда и сцены
## миссии (слева от портретов богов). Рисуется заранее как PNG (Icons/Help/) —
## глянцевый золотой значок с объёмной фаской и тенью, а не плоский StyleBoxFlat,
## поэтому смена состояния (наведение/нажатие) — это подмена текстуры, а не цвета.

const DIAMETER := 40.0

const ICON_NORMAL := preload("res://Icons/Help/help_button_normal.png")
const ICON_HOVER := preload("res://Icons/Help/help_button_hover.png")
const ICON_PRESSED := preload("res://Icons/Help/help_button_pressed.png")

## diameter — размер кнопки в тех же единицах, что и остальной UI экрана (если
## экран масштабирует через _canvas_value/_canvas_size, передайте уже отмасштабированное
## значение).
static func create(diameter: float = DIAMETER) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.size = Vector2(diameter, diameter)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "Подсказки"
	btn.clip_contents = true
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.icon = ICON_NORMAL
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, empty_style)
	btn.mouse_entered.connect(func(): btn.icon = ICON_PRESSED if btn.button_pressed else ICON_HOVER)
	btn.mouse_exited.connect(func(): btn.icon = ICON_NORMAL)
	btn.button_down.connect(func(): btn.icon = ICON_PRESSED)
	btn.button_up.connect(func(): btn.icon = ICON_HOVER if btn.is_hovered() else ICON_NORMAL)
	return btn
