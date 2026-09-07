## ════════════════════════════════════════════════════════════════
##  CampaignHelp — окно справки (кнопка "Помощь" в главном меню кампании).
##  Выделено из campaign_screen.gd (рефакторинг архитектуры, тот же приём,
##  что battle_marks.gd/battle_locations.gd в battle_scene.gd). Вся логика
##  перенесена 1:1; поведение не изменено.
##
##  campaign_screen делегирует показ справки этому объекту (`help`,
##  инициализируется в _ready()) и обращается к нему через `help.show_topics()`
##  и `help.handle_back()` (последний вызывается из _try_close_top_overlay()).
## ════════════════════════════════════════════════════════════════
extends RefCounted
class_name CampaignHelp

# Ссылка на экран кампании — нужна только для add_child() (оверлей вешается на сцену).
var _scene  # намеренно без типа — динамическая диспетчеризация как в battle_marks.gd

var overlay: Control = null
var _showing_topic: bool = false


func _init(scene) -> void:
	_scene = scene


func topics() -> Dictionary:
	return {
		"Кампания": "На экране кампании выбираются разделы замка, создаются и просматриваются боги, открываются миссии и проверяются ресурсы.",
		"Миссии": "В миссиях выбирается отряд богов. Сцены идут по порядку: выбор, результат, возможный бой, затем следующая сцена.",
		"Бой": "Бой идет по очереди хода. Выберите способность или заклинание, затем цель, если она нужна. Правая кнопка мыши отменяет текущий выбор.",
		"Способности": "Способности имеют позиции применения, цели, стоимость величия и эффекты. Наведение показывает подробное описание.",
		"Заклинания": "Заклинания тратят фантазию. Часть заклинаний зависит от выбранной локации.",
		"Эффекты": "Баффы, дебаффы, стойки и уникальные метки отображаются иконками возле персонажа. Наведение на иконку показывает подробности."
	}


func show_topics() -> void:
	clear_overlay()
	_showing_topic = false
	overlay = _make_overlay()
	var panel := _make_panel(overlay)
	var root := _make_root(panel)

	var title := Label.new()
	title.text = "Помощь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	for topic_name in topics().keys():
		var btn := Button.new()
		btn.text = str(topic_name)
		btn.custom_minimum_size = Vector2(640, 58)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(show_topic.bind(str(topic_name), str(topics()[topic_name])))
		root.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(220, 54)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(clear_overlay)
	root.add_child(back_btn)


func show_topic(topic_title: String, topic_text: String) -> void:
	clear_overlay()
	_showing_topic = true
	overlay = _make_overlay()
	var panel := _make_panel(overlay)
	var root := _make_root(panel)

	var title := Label.new()
	title.text = topic_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = true
	body.custom_minimum_size = Vector2(760, 390)
	body.add_theme_font_size_override("normal_font_size", 24)
	body.text = topic_text
	root.add_child(body)

	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(220, 54)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(show_topics)
	root.add_child(back_btn)


func _make_overlay() -> Control:
	var new_overlay := ColorRect.new()
	new_overlay.name = "HelpOverlay"
	new_overlay.color = Color(0, 0, 0, 0.72)
	new_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	new_overlay.z_index = 2000
	_scene.add_child(new_overlay)
	return new_overlay


func _make_panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 620)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-450, -310)
	parent.add_child(panel)
	return panel


func _make_root(panel: PanelContainer) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	root.custom_minimum_size = Vector2(840, 560)
	panel.add_child(root)
	return root


func handle_back() -> bool:
	if overlay == null or not is_instance_valid(overlay):
		return false
	if _showing_topic:
		show_topics()
	else:
		clear_overlay()
	return true


func clear_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	_showing_topic = false
