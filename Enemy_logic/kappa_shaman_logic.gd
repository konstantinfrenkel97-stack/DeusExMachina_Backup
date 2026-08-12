extends RefCounted
class_name KappaShamanLogic

## Каппа шаман: поддерживает хотя бы один эффект — Прилив (бафф союзников) или Отлив (дебафф врагов).
## Если оба отсутствуют — случайный из них. Иначе — Злые волны (приоритет на врага в стойке).

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var flow_ab := _find_by_marker(monster, "kappa_flow")
	var ebb_ab := _find_by_marker(monster, "kappa_ebb")
	var waves_ab := _find_by_marker(monster, "kappa_angry_waves")

	var has_flow = _team_has_buff_effect(allies, monster, "target_buff_damage") or _team_has_buff_effect(allies, monster, "target_buff_initiative")
	var has_ebb = _team_has_debuff_effect(heroes, "target_debuff_damage") or _team_has_debuff_effect(heroes, "target_debuff_evasion")

	# Если нет эффекта ни Прилива, ни Отлива — случайный из доступных.
	if not has_flow and not has_ebb:
		var choices: Array = []
		if flow_ab != null and _is_usable_from_position(flow_ab, monster.position_index):
			choices.append(flow_ab)
		if ebb_ab != null and _is_usable_from_position(ebb_ab, monster.position_index):
			choices.append(ebb_ab)
		if choices.size() > 0:
			var chosen = choices.pick_random()
			if chosen == flow_ab:
				return {"ability": flow_ab, "target": monster}
			else:
				return {"ability": ebb_ab, "target": _first_valid_hero(heroes, ebb_ab)}

	# Если нет Прилива — применить Прилив.
	if not has_flow and flow_ab != null and _is_usable_from_position(flow_ab, monster.position_index):
		return {"ability": flow_ab, "target": monster}

	# Если нет Отлива — применить Отлив.
	if not has_ebb and ebb_ab != null and _is_usable_from_position(ebb_ab, monster.position_index):
		var t = _first_valid_hero(heroes, ebb_ab)
		if t:
			return {"ability": ebb_ab, "target": t}

	# Иначе — Злые волны (приоритет: враг в стойке).
	if waves_ab != null and _is_usable_from_position(waves_ab, monster.position_index):
		var stance_target = _first_stanced_hero(heroes, waves_ab)
		if stance_target:
			return {"ability": waves_ab, "target": stance_target}
		var any_target = _first_valid_hero(heroes, waves_ab)
		if any_target:
			return {"ability": waves_ab, "target": any_target}

	# Fallback: любой доступный навык.
	return _random_usable(monster, heroes)


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true


static func _team_has_buff_effect(team: Array, monster: Combatant, effect_id: String) -> bool:
	for u in team:
		if u == null or u.current_hp <= 0:
			continue
		for eff in u.active_effects:
			if Combatant._effect_get(eff, "effect_id", "") == effect_id:
				return true
	return false


static func _team_has_debuff_effect(team: Array, effect_id: String) -> bool:
	for u in team:
		if u == null or u.current_hp <= 0:
			continue
		for eff in u.active_effects:
			if Combatant._effect_get(eff, "effect_id", "") == effect_id:
				return true
	return false


static func _first_valid_hero(heroes: Array, ab: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
			return h
	return null


static func _first_stanced_hero(heroes: Array, ab: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and h.active_stance != null and Combatant.can_be_targeted_at(h, ab):
			return h
	return null


static func _random_usable(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
