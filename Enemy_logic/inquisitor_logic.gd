extends RefCounted
class_name InquisitorLogic

## Инквизитор:
## • если ни на ком нет эффекта «Аутодафе» — применить его;
## • иначе случайный навык; если случайно выпала «Исповедь» — выбрать союзника
##   с наибольшим числом дебаффов (если такого нет, «Исповедь» пропускается).

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var auto_ab := _find_by_marker(monster, "inquisitor_auto_da_fe")
	var confession_ab := _find_by_marker(monster, "inquisitor_confession")

	# Проверить, нет ли уже эффекта Аутодафе на врагах
	if auto_ab != null and _is_usable_from_position(auto_ab, monster.position_index):
		var has_auto = false
		for h in heroes:
			if h and h.current_hp > 0 and _has_effect_source(h, "Аутодафе"):
				has_auto = true
				break
		if not has_auto:
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, auto_ab):
					return {"ability": auto_ab, "target": h}

	return _random_decision(monster, heroes, allies, confession_ab)


static func _find_best_debuffed_ally(monster: Combatant, allies: Array, confession_ab: AbilityResource) -> Combatant:
	var best_ally: Combatant = null
	var best_debuffs = 0
	for a in allies:
		if a and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, confession_ab):
			var dc = _count_debuffs(a)
			if dc > best_debuffs:
				best_debuffs = dc
				best_ally = a
	return best_ally


static func _has_effect_source(unit: Combatant, source: String) -> bool:
	for e in unit.active_effects:
		if Combatant._effect_get(e, "source_ability", "") == source:
			return true
	return false


static func _count_debuffs(unit: Combatant) -> int:
	var cnt = 0
	for e in unit.active_effects:
		var v = Combatant._effect_get(e, "value", 0)
		var s = Combatant._effect_get(e, "stat", "")
		if v < 0 or s == "stun" or s == "periodic_damage":
			cnt += 1
	return cnt


static func _random_decision(monster: Combatant, heroes: Array, allies: Array, confession_ab: AbilityResource) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab == confession_ab:
			# «Исповедь»: цель — союзник с наибольшим числом дебаффов.
			# Нет подходящей цели — пропускаем и пробуем следующий навык.
			var best_ally := _find_best_debuffed_ally(monster, allies, confession_ab)
			if best_ally != null:
				return {"ability": confession_ab, "target": best_ally}
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		if ab.target_type == "Ally":
			for a in allies:
				if a and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, ab):
					return {"ability": ab, "target": a}
			continue
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
