extends RefCounted
class_name BattleTargeting

## Ввод игрока: выбор способности/ульты/цели, проверки доступности способностей и целей, подсветка целей.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Отмена любого текущего выбора и возврат к панели действий игрока.
func _cancel_selection() -> void:
	var had_selection = _scene.waiting_for_target or _scene._waiting_for_spell_target or _scene._waiting_for_ultimate_target or _scene.selected_mark_position >= 0
	_scene.waiting_for_target = false
	_scene._waiting_for_ultimate_target = false
	_scene.selected_ability = null
	_scene._waiting_for_spell_target = false
	_scene._selected_spell = null
	_scene.selected_mark_position = -1
	if had_selection:
		_update_target_highlights()
		_scene._info._clear_ability_target_preview()
	if _scene.active_unit and _scene.waiting_for_player:
		_scene._hud._show_player_interface(_scene.active_unit)
	elif had_selection:
		_scene._set_status("")

## Золотой трон: снижает стоимость «Узурпировать» на 20 величия.
func _effective_majesty_cost(user: Combatant, ability: AbilityResource) -> int:
	var cost = ability.majesty_cost
	if ability.ability_marker == "set_usurp" and user.has_item_effect("set_throne_usurp_discount"):
		cost = maxi(0, cost - 20)
	return cost

func _is_ability_usable(user: Combatant, ability: AbilityResource) -> bool:
	if ability == null:
		return false
	if not user.can_use_ability_from_position(ability):
		return false
	if ability.majesty_cost > 0 and user.current_majesty < _effective_majesty_cost(user, ability):
		return false
	if ability.ability_marker == "set_usurp":
		return _has_set_usurp_target(user, ability)
	if ability.target_type == "Self" or ability.target_type == "Position":
		return true
	return _find_valid_target(ability) != null

func _on_ability_clicked(ability_index: int):
	if _scene._is_battle_paused():
		return
	if _scene.active_unit == null:
		return
	if not _scene.waiting_for_player or not _scene._is_player_hero(_scene.active_unit):
		return
	_scene._waiting_for_ultimate_target = false
	_scene.selected_ability = _scene.active_unit.active_abilities[ability_index]
	if _scene.selected_ability == null:
		return
	if not _is_ability_usable(_scene.active_unit, _scene.selected_ability):
		return
	
	if _scene.selected_ability.target_type == "Self":
		_scene._abilities._use_ability(_scene.active_unit, _scene.active_unit, _scene.selected_ability)
		_scene._hud._hide_ability_controls()
		_scene._set_status("")
		_scene._turns._finish_unit_turn(_scene.active_unit)
		return
	
	if _scene.selected_ability.target_type == "Position":
		# Марка ставится на позицию, которую выберет игрок.
		_scene.waiting_for_target = true
		_scene._hud._hide_ability_controls()
		_scene._set_status("Выберите позицию для марки: " + _scene.selected_ability.get_display_name())
		_update_target_highlights()
		_scene._menus._show_battle_targeting_tutorial_if_needed()
		return
	
	if _scene.selected_ability.target_type == "All_Enemies" or _scene.selected_ability.target_type == "All_Allies":
		var target = _find_valid_target(_scene.selected_ability)
		if target:
			_scene._abilities._use_ability(_scene.active_unit, target, _scene.selected_ability)
			_scene._hud._hide_ability_controls()
			_scene._set_status("")
			_scene._turns._finish_unit_turn(_scene.active_unit)
		return
	
	_scene.waiting_for_target = true
	_scene._hud._hide_ability_controls()
	_scene._set_status("Выберите цель для: " + _scene.selected_ability.get_display_name())
	_update_target_highlights()
	_scene._menus._show_battle_targeting_tutorial_if_needed()

func _on_unit_selected(target: Combatant):
	if _scene._is_battle_paused():
		return
	if target != null:
		_scene._pinned_hover_unit = target
		_scene._info._show_unit_info_panel(target)
	if _scene.active_unit == null or not _scene.waiting_for_player or not _scene._is_player_hero(_scene.active_unit):
		return
	# === Выбор цели для заклинания ===
	if _scene._waiting_for_spell_target and _scene._selected_spell != null:
		var can_target = _can_target_unit_for_spell(_scene._selected_spell, target)
		if can_target:
			if _scene._rum_spell_whole_team_active and _scene._selected_spell.spell_name == "Ром":
				# Чарка рома взята с собой: заклинание бьёт не только цель, но и всю её команду.
				var rum_team: Array = _scene.enemies_team if target.is_enemy else _scene.heroes_team
				for rum_unit_value in rum_team:
					var rum_unit: Combatant = rum_unit_value as Combatant
					if rum_unit != null and rum_unit.current_hp > 0:
						_scene._spells._apply_spell_to_target(rum_unit, _scene._selected_spell)
			else:
				_scene._spells._apply_spell_to_target(target, _scene._selected_spell)
			_scene._spells._deduct_spell(_scene._selected_spell)
			_scene._spells._update_spell_ui()
			_scene._waiting_for_spell_target = false
			_scene._selected_spell = null
			_scene._set_status("")
			_update_target_highlights()
		else:
			_scene._set_status("Нельзя выбрать эту цель для заклинания: %s" % _scene._selected_spell.get_display_name())
		return
	
	if not _scene.waiting_for_target or _scene.selected_ability == null:
		return
	
	# === Марка на выбранную позицию (target_type = "Position") ===
	if _scene.selected_ability.target_type == "Position":
		var side_ok := false
		if _scene.selected_ability.mark_target_team == "ally":
			side_ok = _scene._is_player_hero(target)
		else:
			side_ok = _scene._is_on_enemies_team(target)
		if not side_ok or target.current_hp <= 0:
			_scene._set_status("Марку можно поставить только на живого юнита нужной команды.")
			return
		_scene.waiting_for_target = false
		_scene._info._clear_ability_target_preview()
		var mark_ab := _scene.selected_ability
		_scene.selected_ability = null
		_scene._hud._hide_ability_controls()
		_scene._set_status("")
		_scene.marks.place_mark(_scene.active_unit, mark_ab, target.position_index)
		_scene._hud._update_marks_display()
		_scene._turns._finish_unit_turn(_scene.active_unit)
		return
	
	if not _can_user_target_unit(_scene.active_unit, target, _scene.selected_ability):
		_scene._set_status("Эту цель нельзя выбрать для " + _scene.selected_ability.get_display_name())
		return
	
	_scene.waiting_for_target = false
	_scene._info._clear_ability_target_preview()
	var used_ability := _scene.selected_ability
	_scene.selected_ability = null
	_scene._hud._hide_ability_controls()
	_scene._set_status("")
	if _scene._waiting_for_ultimate_target:
		_scene._waiting_for_ultimate_target = false
		_scene.active_unit.modify_majesty(-_effective_majesty_cost(_scene.active_unit, used_ability))
		_scene._abilities._use_ability(_scene.active_unit, target, used_ability)
		_restore_usurped_ultimate_after_use(_scene.active_unit, used_ability)
	else:
		_scene._abilities._use_ability(_scene.active_unit, target, used_ability)
	_scene._turns._finish_unit_turn(_scene.active_unit)

func _on_ultimate_clicked():
	if _scene._is_battle_paused():
		return
	if _scene.active_unit == null or _scene.active_unit.ultimate_ability == null:
		return
	if not _scene.waiting_for_player or not _scene._is_player_hero(_scene.active_unit):
		return
	# ═══ Мрачная сделка: блокировка ультимативной способности ═══
	var _ub_blocked = false
	for _ub_e in _scene.active_unit.active_effects:
		if Combatant._effect_get(_ub_e, "effect_id", "") == "ultimate_blocked":
			_ub_blocked = true
			break
	if _ub_blocked:
		_scene._log_combat("⛔ [Мрачная сделка] %s: ультимативная способность заблокирована!" % _scene.active_unit.unit_name)
		return
	var ultimate := _scene.active_unit.ultimate_ability
	if not _is_ability_usable(_scene.active_unit, ultimate):
		return
	if _ultimate_requires_manual_target(ultimate):
		_scene.selected_ability = ultimate
		_scene.waiting_for_target = true
		_scene._waiting_for_ultimate_target = true
		_scene._hud._hide_ability_controls()
		_scene._set_status("Выберите цель для ульты: " + ultimate.name)
		_update_target_highlights()
		return
	var target = _find_valid_target(ultimate)
	if target:
		_scene._hud._hide_ability_controls()
		_scene.active_unit.modify_majesty(-_effective_majesty_cost(_scene.active_unit, ultimate))
		_scene._abilities._use_ability(_scene.active_unit, target, ultimate)
		_restore_usurped_ultimate_after_use(_scene.active_unit, ultimate)
		_scene._turns._finish_unit_turn(_scene.active_unit)

func _ultimate_requires_manual_target(ability: AbilityResource) -> bool:
	return ability.target_type == "Enemy" or ability.target_type == "Ally"

## Проверка допустимости цели для заклинания (вынесена из _on_unit_selected,
## чтобы одной и той же логикой пользовались и разрешение выбора, и подсветка целей).
func _can_target_unit_for_spell(spell: SpellResource, target: Combatant) -> bool:
	if target == null or target.current_hp <= 0:
		return false
	var can_target = false
	if spell.target_type == "Any":
		# «Ром» и аналогичные — можно на любого живого юнита
		can_target = true
	else:
		if spell.target_type == "Enemy" and _scene._is_on_enemies_team(target):
			can_target = true
		if spell.target_type == "Ally" and _scene._is_player_hero(target):
			can_target = true
	if can_target:
		var tp = spell.targetable_positions
		# Крупный юнит занимает 2 клетки — достаточно совпадения по любой из них
		# (аналогично Combatant.can_be_targeted_at для способностей).
		var pos_ok = tp.size() > target.position_index and tp[target.position_index]
		if target.is_large and target.position_index + 1 < tp.size() and tp[target.position_index + 1]:
			pos_ok = true
		if not pos_ok:
			can_target = false
	return can_target

func _can_user_target_unit(user: Combatant, target: Combatant, ability: AbilityResource) -> bool:
	if user == null or target == null or ability == null or target.current_hp <= 0:
		return false
	if ability.target_type == "Enemy" and target.is_enemy == user.is_enemy:
		return false
	if ability.target_type == "Ally" and target.is_enemy != user.is_enemy:
		return false
	if ability.ability_marker == "set_usurp":
		if target == user or target.ultimate_ability == null:
			return false
	return _can_target_unit(target, ability)

func _has_set_usurp_target(user: Combatant, ability: AbilityResource) -> bool:
	if user == null:
		return false
	var team: Array = _scene.enemies_team if user.is_enemy else _scene.heroes_team
	for unit in team:
		if unit and unit != user and unit.current_hp > 0 and unit.ultimate_ability != null and _can_target_unit(unit, ability):
			return true
	return false

## Подсвечивает допустимые цели (красным — врагов, синим — союзников) во время выбора
## цели способности/ульты/заклинания, до того как игрок применит выбор. Снимает
## подсветку со всех, если сейчас цель не выбирается.
func _update_target_highlights() -> void:
	var mode := ""
	if _scene.waiting_for_target and _scene.selected_ability != null and _scene.active_unit != null:
		mode = "ability"
	elif _scene._waiting_for_spell_target and _scene._selected_spell != null:
		mode = "spell"
	for v in _scene.hero_visuals + _scene.enemy_visuals:
		if v == null or v.data == null:
			continue
		var unit: Combatant = v.data
		var highlight := ""
		if mode != "" and unit.current_hp > 0:
			var is_valid := false
			if mode == "ability":
				if _scene.selected_ability.target_type == "Position":
					if _scene.selected_ability.mark_target_team == "ally":
						is_valid = _scene._is_player_hero(unit)
					else:
						is_valid = _scene._is_on_enemies_team(unit)
				else:
					is_valid = _can_user_target_unit(_scene.active_unit, unit, _scene.selected_ability)
			else:
				is_valid = _can_target_unit_for_spell(_scene._selected_spell, unit)
			if is_valid:
				highlight = "enemy" if unit.is_enemy else "ally"
		if v.has_method("set_target_highlight"):
			v.set_target_highlight(highlight)

func _restore_usurped_ultimate_after_use(unit: Combatant, used_ultimate: AbilityResource) -> void:
	if unit == null or not unit.has_usurped_ultimate:
		return
	if used_ultimate == unit.original_ultimate_ability:
		return
	unit.ultimate_ability = unit.original_ultimate_ability
	unit.has_usurped_ultimate = false
	_scene._log_combat("%s возвращает ульту «%s»." % [unit.unit_name, unit.ultimate_ability.name])

func _find_valid_target(ability: AbilityResource) -> Combatant:
	if ability.target_type == "All_Enemies" or ability.target_type == "All_Allies":
		var all_targets = _get_all_targets(ability)
		return all_targets[0] if all_targets.size() > 0 else null
	
	if ability.target_type == "Self":
		return _scene.active_unit
	
	var team = _scene.enemies_team if (ability.target_type == "Enemy" or ability.target_type == "All_Enemies") else _scene.heroes_team
	for unit in team:
		if unit and unit.current_hp > 0 and _can_target_unit(unit, ability):
			return unit
	return null

func _can_target_unit(target: Combatant, ability: AbilityResource) -> bool:
	# Чернобог: союзники не могут выбрать его целью (пассивка «uncurseable»).
	# Белая маска снимает это ограничение.
	if target.special_effect_type == "chernobog_uncurseable" and not target.is_enemy \
			and not target.has_item_effect("chernobog_white_mask_allow_target"):
		if ability.target_type == "Ally" or ability.target_type == "All_Allies" or ability.mark_target_team == "ally":
			return false
	return Combatant.can_be_targeted_at(target, ability)

func _get_all_targets(ability: AbilityResource, attacker: Combatant = null) -> Array:
	var targets = []
	var is_enemy_target = (ability.target_type == "Enemy" or ability.target_type == "All_Enemies")
	var team: Array
	if attacker != null:
		# Команда определяется относительно атакующего
		if is_enemy_target:
			team = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
		else:
			team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
	else:
		# Перспектива игрока (героя)
		team = _scene.enemies_team if is_enemy_target else _scene.heroes_team
	for u in team:
		if u and u.current_hp > 0 and _can_target_unit(u, ability):
			targets.append(u)
	return targets
