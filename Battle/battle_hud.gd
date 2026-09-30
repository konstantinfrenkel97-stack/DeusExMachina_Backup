extends RefCounted
class_name BattleHud

## Интерфейс боя: фон, нижняя панель, кнопки способностей, баннер, очередь ходов, иконки марок.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

func _create_background_node():
	if _scene.has_node("Background"):
		var existing: Node = _scene.get_node("Background")
		if existing is Sprite2D:
			_scene._bg_sprite = existing
			_scene._bg_sprite.z_index = -100
			_scene._bg_sprite.centered = false
			_create_bottom_backdrop()
			return
	_scene._bg_sprite = Sprite2D.new()
	_scene._bg_sprite.name = "Background"
	_scene._bg_sprite.z_index = -100
	_scene._bg_sprite.centered = false
	_scene._bg_sprite.position = Vector2.ZERO
	_scene.add_child(_scene._bg_sprite)
	_scene.move_child(_scene._bg_sprite, 0)
	_create_bottom_backdrop()

func _create_bottom_backdrop() -> void:
	if _scene._bottom_backdrop != null:
		_position_bottom_backdrop()
		return
	if _scene.has_node("BottomBlackBackdrop"):
		var root_existing: Node = _scene.get_node("BottomBlackBackdrop")
		if root_existing is ColorRect:
			_scene._bottom_backdrop = root_existing
	elif _scene.has_node("BattleUI/BottomBlackBackdrop"):
		var ui_existing: Node = _scene.get_node("BattleUI/BottomBlackBackdrop")
		if ui_existing is ColorRect:
			_scene._bottom_backdrop = ui_existing
	else:
		_scene._bottom_backdrop = ColorRect.new()
		_scene._bottom_backdrop.name = "BottomBlackBackdrop"
	if _scene._bottom_backdrop.get_parent() != _scene:
		if _scene._bottom_backdrop.get_parent():
			_scene._bottom_backdrop.get_parent().remove_child(_scene._bottom_backdrop)
		_scene.add_child(_scene._bottom_backdrop)
	# Навy — тот же цвет, что и панели остального интерфейса (кампания, Библиотека, Сад, Весы).
	_scene._bottom_backdrop.color = Color(0.09, 0.11, 0.20, 1.0)
	_scene._bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene._bottom_backdrop.z_index = -90
	_position_bottom_backdrop()

func _position_bottom_backdrop() -> void:
	if _scene._bottom_backdrop == null:
		return
	var vp_size: Vector2 = _scene.get_viewport_rect().size
	var frame_h: float = floor(vp_size.x * BattleScene.BACKGROUND_FRAME_RATIO)
	_scene._bottom_backdrop.position = Vector2(0.0, frame_h)
	_scene._bottom_backdrop.size = Vector2(vp_size.x, maxf(0.0, vp_size.y - frame_h))

func _apply_background():
	if _scene._bg_sprite == null:
		return
	var bg_path: String = _resolve_location_background_path(CombatManager.selected_background)
	if bg_path == "":
		return
	var tex = load(bg_path)
	if tex:
		_scene._bg_sprite.texture = tex
		_fit_background()

func _resolve_location_background_path(path: String) -> String:
	var cleaned := path.strip_edges()
	if cleaned != "" and ResourceLoader.exists(cleaned):
		return cleaned
	match CombatManager.selected_location_id:
		"helheim": return "res://Background/Helheim.png"
		"hell": return "res://Background/Hell.png"
		"tunnels": return "res://Background/Tunnels.png"
		"clouds": return "res://Background/Clouds.png"
		"stars": return "res://Background/Stars.png"
		"mountains": return "res://Background/Peaks.png"
		"arena": return "res://Background/Arena.png"
		"castle": return "res://Background/Castle.png"
		"desert": return "res://Background/Desert.png"
		"depths": return "res://Background/Deep.png"
		"island": return "res://Background/Islands.png"
		"ships": return "res://Background/Ships.png"
		"jungle": return "res://Background/Jungle.png"
		"garden": return "res://Background/Garden.png"
		"swamp": return "res://Background/Marsh.png"
		"book": return "res://Background/Book_background.png"
		_: return ""

func _swap_background(tex_path: String):
	if _scene._bg_sprite == null:
		return
	if tex_path == "":
		_apply_background()
		return
	var tex = load(tex_path)
	if tex:
		_scene._bg_sprite.texture = tex
		_fit_background()

func _fit_background():
	if _scene._bg_sprite == null or _scene._bg_sprite.texture == null:
		return
	var vp_size: Vector2 = _scene.get_viewport_rect().size
	var tex_w: int = _scene._bg_sprite.texture.get_width()
	var tex_h: int = _scene._bg_sprite.texture.get_height()
	if tex_h <= 0 or tex_w <= 0 or vp_size.x <= 0:
		return
	var frame_w: float = vp_size.x
	var frame_h: float = frame_w * BattleScene.BACKGROUND_FRAME_RATIO
	_scene._bg_sprite.centered = false
	_scene._bg_sprite.position = Vector2.ZERO
	_scene._bg_sprite.scale = Vector2(frame_w / float(tex_w), frame_h / float(tex_h))
	_position_bottom_backdrop()

# ══════════════════════════════════════════════
#  UI: КНОПКИ И СОЕДИНЕНИЯ
# ══════════════════════════════════════════════

func _connect_ui_buttons():
	_setup_ability_slot_buttons()
	for i in range(_scene.slots.size()):
		_scene.slots[i].pressed.connect(_scene._targeting._on_ability_clicked.bind(i))
	_scene.slot_ult.pressed.connect(_scene._targeting._on_ultimate_clicked)
	_scene.tactical_button.pressed.connect(_scene._turns._on_wait_button_pressed)
	_scene.skip_turn_button.pressed.connect(_scene._turns._on_skip_turn_pressed)

func _setup_ability_slot_buttons() -> void:
	_scene.ability_panel.columns = 5
	_scene.ability_panel.add_theme_constant_override("h_separation", int(BattleScene.ABILITY_BUTTON_GAP))
	_scene.ability_panel.add_theme_constant_override("v_separation", int(BattleScene.ABILITY_BUTTON_GAP))
	_scene.ability_panel.position = Vector2(16.0, _get_bottom_controls_top())
	_scene.ability_panel.size = Vector2(BattleScene.ABILITY_ICON_BUTTON_SIZE.x * 5.0 + BattleScene.ABILITY_BUTTON_GAP * 4.0, BattleScene.ABILITY_ICON_BUTTON_SIZE.y)
	for button in _scene.slots:
		_apply_ability_button_base_style(button)
	_apply_ability_button_base_style(_scene.slot_ult)
	_setup_ability_actions_row()

func _setup_ability_actions_row() -> void:
	if _scene._ability_actions_row == null:
		_scene._ability_actions_row = HBoxContainer.new()
		_scene._ability_actions_row.name = "AbilityActionsRow"
		_scene._ability_actions_row.add_theme_constant_override("separation", int(BattleScene.ABILITY_BUTTON_GAP))
		_scene.get_node("BattleUI").add_child(_scene._ability_actions_row)
	_move_button_to_actions_row(_scene.tactical_button)
	_move_button_to_actions_row(_scene.skip_turn_button)
	_scene._ability_actions_row.position = Vector2(16.0, _get_bottom_controls_top() + BattleScene.ABILITY_ICON_BUTTON_SIZE.y + BattleScene.ABILITY_BUTTON_GAP)
	_scene._ability_actions_row.size = Vector2(BattleScene.ACTION_BUTTON_SIZE.x * 2.0 + BattleScene.ABILITY_BUTTON_GAP, BattleScene.ACTION_BUTTON_SIZE.y)

func _move_button_to_actions_row(button: Button) -> void:
	if button.get_parent() != _scene._ability_actions_row:
		if button.get_parent():
			button.get_parent().remove_child(button)
		_scene._ability_actions_row.add_child(button)
	button.custom_minimum_size = BattleScene.ACTION_BUTTON_SIZE
	button.size = BattleScene.ACTION_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true

func _set_action_button_icon(button: Button, icon_path: String, fallback_text: String) -> void:
	button.tooltip_text = fallback_text
	if ResourceLoader.exists(icon_path):
		button.icon = load(icon_path) as Texture2D
		button.text = ""
	else:
		button.icon = null
		button.text = fallback_text

func _apply_ability_button_base_style(button: Button) -> void:
	button.custom_minimum_size = BattleScene.ABILITY_ICON_BUTTON_SIZE
	button.size = BattleScene.ABILITY_ICON_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true

func _get_bottom_status_top() -> float:
	return floor(_scene.get_viewport_rect().size.x * BattleScene.BACKGROUND_FRAME_RATIO)

func _get_bottom_ui_top() -> float:
	return _get_bottom_status_top() + BattleScene.BOTTOM_UI_MARGIN

func _get_bottom_controls_top() -> float:
	return _get_bottom_status_top() + BattleScene.BOTTOM_STATUS_STRIP_HEIGHT

func _show_ability_controls() -> void:
	_scene.ability_panel.show()
	if _scene._ability_actions_row:
		_scene._ability_actions_row.show()

func _hide_ability_controls() -> void:
	_scene.ability_panel.hide()
	if _scene._ability_actions_row:
		_scene._ability_actions_row.hide()

func _position_bottom_ui_controls() -> void:
	var controls_top: float = _get_bottom_controls_top()
	if _scene.ability_panel:
		_scene.ability_panel.position = Vector2(16.0, controls_top)
		_scene.ability_panel.size = Vector2(BattleScene.ABILITY_ICON_BUTTON_SIZE.x * 5.0 + BattleScene.ABILITY_BUTTON_GAP * 4.0, BattleScene.ABILITY_ICON_BUTTON_SIZE.y)
	if _scene._ability_actions_row:
		_scene._ability_actions_row.position = Vector2(16.0, controls_top + BattleScene.ABILITY_ICON_BUTTON_SIZE.y + BattleScene.ABILITY_BUTTON_GAP)
		_scene._ability_actions_row.size = Vector2(BattleScene.ACTION_BUTTON_SIZE.x * 2.0 + BattleScene.ABILITY_BUTTON_GAP, BattleScene.ACTION_BUTTON_SIZE.y)

func _show_player_interface(god: Combatant):
	_scene.waiting_for_target = false
	_scene.selected_ability = null
	var pos_label = " (линия %d)" % (god.position_index + 1)
	_scene._log_combat("Ваш ход: %s%s" % [god.unit_name, pos_label])
	_show_ability_controls()
	
	var has_usable_ability = false
	for i in range(4):
		if i < god.active_abilities.size() and god.active_abilities[i] != null:
			var ability = god.active_abilities[i]
			_set_ability_button_content(_scene.slots[i], ability)
			_scene.slots[i].tooltip_text = _scene._info._get_ability_tooltip(ability, god)
			_scene.slots[i].rich_tooltip_text = _scene.slots[i].tooltip_text
			_scene.slots[i].show()
			_scene.slots[i].disabled = not _scene._targeting._is_ability_usable(god, ability)
			if not _scene.slots[i].disabled:
				has_usable_ability = true
		else:
			_scene.slots[i].text = "---"
			_scene.slots[i].icon = null
			_scene.slots[i].tooltip_text = ""
			_scene.slots[i].hide()
	if god.ultimate_ability and (god.active_abilities.is_empty() or god.ultimate_ability != god.active_abilities[0]):
		_set_ability_button_content(_scene.slot_ult, god.ultimate_ability)
		_scene.slot_ult.tooltip_text = _scene._info._get_ability_tooltip(god.ultimate_ability, god)
		_scene.slot_ult.rich_tooltip_text = _scene.slot_ult.tooltip_text
		_scene.slot_ult.show()
		_scene.slot_ult.disabled = not _scene._targeting._is_ability_usable(god, god.ultimate_ability)
		if not _scene.slot_ult.disabled:
			has_usable_ability = true
	else:
		_scene.slot_ult.icon = null
		_scene.slot_ult.hide()
		_scene.slot_ult.tooltip_text = ""
	
	_scene.tactical_button.show()
	_set_action_button_icon(_scene.tactical_button, BattleScene.WAIT_ICON_PATH, "Ждать")
	_scene.tactical_button.disabled = false
	_scene.skip_turn_button.show()
	_set_action_button_icon(_scene.skip_turn_button, BattleScene.END_TURN_ICON_PATH, "Пропустить ход")
	_scene.skip_turn_button.disabled = false

	# Панель заклинаний
	if _scene._spell_panel:
		_scene._spell_panel.show()
		_scene._spells._update_spell_ui()
	
	_scene._set_status("")

## Пересчёт доступности кнопок способностей по текущей позиции/величию бога.
## Вызывается при любом изменении состояния боя (движение, заклинания, величие).
func _refresh_ability_buttons_availability(god: Combatant) -> void:
	if god == null or _scene.ability_panel == null:
		return
	for i in range(4):
		if i < god.active_abilities.size() and god.active_abilities[i] != null:
			var ability: AbilityResource = god.active_abilities[i]
			if _scene.slots[i].is_visible_in_tree():
				_scene.slots[i].disabled = not _scene._targeting._is_ability_usable(god, ability)
	if god.ultimate_ability and (god.active_abilities.is_empty() or god.ultimate_ability != god.active_abilities[0]):
		if _scene.slot_ult.is_visible_in_tree():
			_scene.slot_ult.disabled = not _scene._targeting._is_ability_usable(god, god.ultimate_ability)

func _set_ability_button_content(button: Button, ability: AbilityResource) -> void:
	if button.get_script() == null:
		button.set_script(BattleScene.STAT_ICON_TOOLTIP_BUTTON_SCRIPT)
	var icon := ability.get_icon_texture()
	button.icon = icon
	button.text = "" if icon != null else ability.get_display_name()

## Создаёт крупный баннер названия способности вверху по центру экрана.
## Текст не перехватывает клики (mouse_filter = IGNORE), поверх него
## рисуется чёрная обводка для читаемости на любом фоне.
func _setup_ability_banner():
	_scene._ability_banner = Label.new()
	_scene._ability_banner.name = "AbilityBanner"
	# Растягиваем на весь экран, текст центрируем по горизонтали и прижимаем к верху.
	_scene._ability_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Сдвинуто вниз, чтобы не перекрывать полосу очереди ходов в самом верху.
	_scene._ability_banner.offset_top = 38.0
	_scene._ability_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene._ability_banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Не блокируем клики по юнитам/кнопкам под баннером.
	_scene._ability_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene._ability_banner.z_index = 50
	_scene._ability_banner.add_theme_font_size_override("font_size", 46)
	_scene._ability_banner.add_theme_color_override("font_color", Color(1.0, 0.96, 0.55))
	_scene._ability_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_scene._ability_banner.add_theme_constant_override("outline_size", 10)
	_scene.get_node("BattleUI").add_child(_scene._ability_banner)
	_scene._ability_banner.hide()

## Показывает название способности крупным текстом вверху экрана.
## Текст держится дольше, затем плавно исчезает.
func _show_ability_banner(ability_name: String) -> void:
	if _scene._ability_banner == null or ability_name == "":
		return
	_scene._ability_banner.text = ability_name
	_scene._ability_banner.modulate.a = 1.0
	_scene._ability_banner.show()
	if _scene._ability_banner_tween and _scene._ability_banner_tween.is_valid():
		_scene._ability_banner_tween.kill()
	_scene._ability_banner_tween = _scene.create_tween()
	_scene._ability_banner_tween.tween_interval(2.5)
	_scene._ability_banner_tween.tween_property(_scene._ability_banner, "modulate:a", 0.0, 0.5)
	_scene._ability_banner_tween.tween_callback(_scene._ability_banner.hide)

## Создаёт полосу очереди ходов в самом верху экрана: портреты-лица юнитов.
## Наведение на портрет подсвечивает соответствующего юнита на поле боя.
func _setup_turn_order_display():
	_scene._turn_order_row = HBoxContainer.new()
	_scene._turn_order_row.name = "TurnOrderRow"
	_scene._turn_order_row.position = Vector2(0, 2)
	_scene._turn_order_row.size = Vector2(1280, 64)
	_scene._turn_order_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_scene._turn_order_row.add_theme_constant_override("separation", 8)
	_scene._turn_order_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_scene._turn_order_row.z_index = 60
	_scene.get_node("BattleUI").add_child(_scene._turn_order_row)

## Перерисовывает иконки активных марок — каждая ровно над своей позицией на поле.
func _update_marks_display():
	for n in _scene._mark_nodes:
		if is_instance_valid(n):
			var mark_parent: Node = n.get_parent()
			if mark_parent != null:
				mark_parent.remove_child(n)
			n.queue_free()
	_scene._mark_nodes.clear()
	if _scene.marks == null:
		return
	for m in _scene.marks.position_marks:
		var team := str(m.get("team", ""))
		var pos := int(m.get("position", -1))
		if pos < 0 or pos > 3:
			continue
		var anchor := _scene.get_node_or_null(("HeroPositions/Pos%d" if team == "ally" else "EnemyPositions/Pos%d") % (pos + 1))
		if anchor == null:
			continue
		var icon_tex = m.get("icon", null)
		if icon_tex == null:
			icon_tex = load("res://icons/Buff_icon.png")
		if icon_tex == null:
			continue
		var marked_unit: Combatant = null
		var marked_team: Array = _scene.heroes_team if team == "ally" else _scene.enemies_team
		if pos < marked_team.size():
			marked_unit = marked_team[pos]
		var marked_visual: Node2D = _scene._field._find_visual_for_unit(marked_unit, _scene.hero_visuals if team == "ally" else _scene.enemy_visuals)
		var mark_x: float = marked_visual.global_position.x if marked_visual != null else anchor.global_position.x
		var sprite := Sprite2D.new()
		sprite.texture = icon_tex
		var tex_size: Vector2 = icon_tex.get_size()
		var icon_px := 135.0
		if tex_size.x > 0 and tex_size.y > 0:
			var k := icon_px / maxf(tex_size.x, tex_size.y)
			sprite.scale = Vector2(k, k)
		# Марка рисуется над позицией меченого юнита на поле (не в нижней панели с баффами).
		var mark_y: float = anchor.global_position.y - 260.0
		if marked_visual != null:
			mark_y = marked_visual.global_position.y - 260.0
		sprite.position = Vector2(mark_x, mark_y)
		sprite.z_index = 100
		_scene.add_child(sprite)
		_scene._mark_nodes.append(sprite)
		var rounds := int(m.get("rounds_left", 0))
		if rounds > 0:
			var lbl := Label.new()
			lbl.text = str(rounds)
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.modulate = Color(1, 0.9, 0.5)
			lbl.position = sprite.position + Vector2(8, 5)
			lbl.z_index = 100
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scene.get_node("BattleUI").add_child(lbl)
			_scene._mark_nodes.append(lbl)

## Обновляет полосу очереди: портреты юнитов; текущий ходящий — крупнее с маркером ▶.
func _update_turn_order_display():
	if _scene._turn_order_row == null:
		return
	# Портреты пересоздаются — гасим возможную «залипшую» подсветку наведения на поле.
	for v in _scene.hero_visuals + _scene.enemy_visuals:
		if v:
			v.set_hover(false)
	for child in _scene._turn_order_row.get_children():
		child.queue_free()
	# Порядок: текущий ходящий первым, затем оставшиеся (живые, ещё не ходившие).
	if _scene.active_unit != null and _scene.active_unit.current_hp > 0 and _scene.active_unit.turn_open and not _scene.active_unit.has_acted_this_round:
		_add_turn_portrait(_scene.active_unit, true)
	# Юнит с несколькими ходами повторяется в полосе столько раз, сколько ходов у него осталось
	# (в том числе ближайшие ходы того, кто ходит сейчас).
	for u in _scene.turn_order:
		if u != null and u.current_hp > 0 and not u.has_acted_this_round:
			_add_turn_portrait(u, false)

## Добавляет один портрет юнита в полосу очереди (лицо; запасной — спрайт/имя).
## is_active — True для текущего ходящего (крупнее + маркер ▶).
func _add_turn_portrait(u: Combatant, is_active: bool) -> void:
	if is_active:
		var arrow := Label.new()
		arrow.text = "▶"
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		arrow.add_theme_color_override("font_outline_color", Color.BLACK)
		arrow.add_theme_constant_override("outline_size", 6)
		arrow.add_theme_font_size_override("font_size", 24)
		_scene._turn_order_row.add_child(arrow)
	_scene._turn_order_row.add_child(_make_turn_portrait(u, is_active))

## Создаёт узел-портрет юнита. Наведение курсора подсвечивает юнита на поле боя.
func _make_turn_portrait(u: Combatant, is_active: bool) -> Control:
	var tex: Texture2D = null
	if u.face_sprite != "":
		tex = load(u.face_sprite) as Texture2D
	if tex == null and u.sprite_path != "":
		tex = load(u.sprite_path) as Texture2D
	var psize := 58 if is_active else 46
	if tex == null:
		# Нет ни лица, ни спрайта — запасной вариант: имя.
		var lbl := Label.new()
		lbl.text = _scene._short_unit_name(u.unit_name)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.tooltip_text = u.unit_name
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_active else Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.mouse_entered.connect(_on_turn_portrait_hovered.bind(u))
		lbl.mouse_exited.connect(_on_turn_portrait_unhovered.bind(u))
		return lbl
	var portrait := TextureRect.new()
	portrait.texture = tex
	portrait.custom_minimum_size = Vector2(psize, psize)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.tooltip_text = u.unit_name
	# Активный — в полный цвет; остальные слегка затемнены (чётче видно, чей ход).
	portrait.modulate = Color.WHITE if is_active else Color(0.75, 0.75, 0.75, 1.0)
	portrait.mouse_entered.connect(_on_turn_portrait_hovered.bind(u))
	portrait.mouse_exited.connect(_on_turn_portrait_unhovered.bind(u))
	return portrait

## Наведение на портрет в полосе очереди — подсветить юнита на поле боя.
func _on_turn_portrait_hovered(u: Combatant) -> void:
	var vis = _scene._field._find_visual_for_unit(u, _scene.hero_visuals)
	if vis == null:
		vis = _scene._field._find_visual_for_unit(u, _scene.enemy_visuals)
	if vis:
		vis.set_hover(true)

## Уход курсора с портрета — снять подсветку с юнита на поле боя.
func _on_turn_portrait_unhovered(u: Combatant) -> void:
	var vis = _scene._field._find_visual_for_unit(u, _scene.hero_visuals)
	if vis == null:
		vis = _scene._field._find_visual_for_unit(u, _scene.enemy_visuals)
	if vis:
		vis.set_hover(false)

## Создаёт иконку двери текущей локации (верхний правый угол) с подсказкой её правил при наведении.
func _setup_location_door_icon():
	var loc_id: String = CombatManager.selected_location_id
	var icon_path: String = str(BattleScene.LOCATION_DOOR_ICON_OPEN.get(loc_id, ""))
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return
	var rule_text: String = str(BattleScene.LOCATION_RULE_TEXT.get(loc_id, ""))
	var btn := Button.new()
	btn.name = "LocationDoorIcon"
	btn.set_script(load("res://location_rule_tooltip_button.gd"))
	btn.flat = true
	btn.icon = load(icon_path) as Texture2D
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var icon_size := Vector2(76, 76)
	btn.custom_minimum_size = icon_size
	btn.size = icon_size
	btn.position = Vector2(1280 - icon_size.x - 8, 4)
	btn.z_index = 200
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_HELP
	_scene.get_node("BattleUI").add_child(btn)
	if rule_text != "":
		btn.set("rule_text", rule_text)
