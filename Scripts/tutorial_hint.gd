extends CanvasLayer
class_name TutorialHint

## Небольшая переиспользуемая всплывающая подсказка обучения: затемнение +
## центрированная панель с текстом (BBCode — используется для иконок
## характеристик) и кнопкой подтверждения. Та же навy/золотая палитра, что и
## остальные оверлеи кампании/боя (см. CampaignTheme).
##
## CanvasLayer (а не обычный Control) — принципиально: и campaign_screen.gd, и
## battle_scene.gd используют собственные CanvasLayer для части интерфейса
## (например, $BattleUI), и обычный Control-оверлей, добавленный простым
## add_child(), рисовался бы и ловил клики НИЖЕ них независимо от z_index —
## z_index сравнивается только между узлами внутри одного canvas layer. Здесь —
## заведомо самый верхний слой (layer = TOP_LAYER), поверх вообще всего.
##
## Тексты подсказок живут в Scripts/tutorial_texts.gd — правь их там.

signal dismissed

const PANEL_MIN_WIDTH := 620.0
const TOP_LAYER := 100

## Ничего не показывает и возвращает null, если обучение отключено игроком
## (см. кнопку "Отключить обучение" ниже) — вызывающему коду не нужно самому
## помнить об этой проверке.
static func present(parent: Node, text: String, button_text: String = "Понятно") -> TutorialHint:
	if CampaignState.tutorial_disabled:
		return null
	var hint := TutorialHint.new()
	parent.add_child(hint)
	hint._build(text, button_text)
	return hint

## steps: Array[String] или Array[Dictionary] ({"text":..., "button_text":...}).
## Показывает по одному, следующий — сразу после закрытия предыдущего.
## on_all_dismissed вызывается один раз, когда закрыт последний шаг (или сразу,
## если обучение отключено — см. present()).
static func show_sequence(parent: Node, steps: Array, final_button_text: String = "Понятно", on_all_dismissed: Callable = Callable()) -> void:
	_show_step(parent, steps, 0, final_button_text, on_all_dismissed)

static func _show_step(parent: Node, steps: Array, index: int, final_button_text: String, on_all_dismissed: Callable) -> void:
	if index >= steps.size():
		if on_all_dismissed.is_valid():
			on_all_dismissed.call()
		return
	var step = steps[index]
	var text: String = step if step is String else str(step.get("text", ""))
	var is_last: bool = index == steps.size() - 1
	var button_text: String = final_button_text if is_last else "Далее"
	if step is Dictionary and step.has("button_text"):
		button_text = str(step["button_text"])
	var hint := present(parent, text, button_text)
	if hint == null:
		if on_all_dismissed.is_valid():
			on_all_dismissed.call()
		return
	hint.dismissed.connect(func(): _show_step(parent, steps, index + 1, final_button_text, on_all_dismissed))

var _root: Control

func _build(text: String, button_text: String) -> void:
	layer = TOP_LAYER

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(PANEL_MIN_WIDTH - 56.0, 0)
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", CampaignTheme.ACCENT)
	label.text = text
	vb.add_child(label)

	var btn := Button.new()
	btn.text = button_text
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_confirm_pressed)
	vb.add_child(btn)

	var disable_btn := Button.new()
	disable_btn.text = "Отключить обучение"
	disable_btn.flat = true
	disable_btn.focus_mode = Control.FOCUS_NONE
	disable_btn.add_theme_font_size_override("font_size", 13)
	disable_btn.add_theme_color_override("font_color", CampaignTheme.ACCENT_DIM)
	disable_btn.add_theme_color_override("font_hover_color", CampaignTheme.ACCENT)
	disable_btn.pressed.connect(_on_disable_pressed)
	vb.add_child(disable_btn)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CampaignTheme.PANEL_BG
	style.border_color = CampaignTheme.ACCENT
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style

func _on_confirm_pressed() -> void:
	dismissed.emit()
	queue_free()

## "Отключить обучение" — на случай случайного клика подтверждение обязательно
## (см. запрос пользователя): маленький доп.-оверлей поверх этой же подсказки,
## в том же CanvasLayer (рисуется поверх неё, т.к. добавлен позже).
func _on_disable_pressed() -> void:
	var confirm_root := Control.new()
	confirm_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var msg := Label.new()
	msg.text = "Точно отключить обучение? Больше подсказки показываться не будут."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 17)
	msg.add_theme_color_override("font_color", CampaignTheme.ACCENT)
	vb.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(160, 46)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(func(): confirm_root.queue_free())
	row.add_child(cancel_btn)

	var yes_btn := Button.new()
	yes_btn.text = "Да, отключить"
	yes_btn.custom_minimum_size = Vector2(160, 46)
	yes_btn.add_theme_font_size_override("font_size", 16)
	yes_btn.pressed.connect(_on_disable_confirmed)
	row.add_child(yes_btn)

func _on_disable_confirmed() -> void:
	CampaignState.tutorial_disabled = true
	dismissed.emit()
	queue_free()
