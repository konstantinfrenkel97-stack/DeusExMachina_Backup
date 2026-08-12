extends RefCounted
class_name MummyLogic

## Мумия: если ни на одном враге нет «Древнего проклятия» — наложить его.
## Иначе — случайная доступная способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var curse_ab = _find_ability(monster, "mummy_ancient_curse")
	if curse_ab and _is_usable(monster, curse_ab):
		var any_cursed = false
		for h in heroes:
			if h and h.current_hp > 0:
				for eff in h.active_effects:
					if Combatant._effect_get(eff, "effect_id", "") == "mummy_curse":
						any_cursed = true
						break
				if any_cursed:
					break
		if not any_cursed:
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, curse_ab):
					return {"ability": curse_ab, "target": h}
	return _random_usable(monster, heroes)


static func _find_ability(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable(monster: Combatant, ab: AbilityResource) -> bool:
	if ab.usable_from_positions.size() > monster.position_index:
		return ab.usable_from_positions[monster.position_index]
	return false


static func _random_usable(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable(monster, ab):
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
