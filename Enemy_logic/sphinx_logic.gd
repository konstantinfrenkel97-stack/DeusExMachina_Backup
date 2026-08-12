extends RefCounted
class_name SphinxLogic

## Сфинкс: при HP <50% — 50% шанс «Облик статуи».
## Иначе — случайная доступная способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	if float(monster.current_hp) / float(monster.max_hp) < 0.50:
		if randf() < 0.50:
			var statue = _find_ability(monster, "sphinx_statue_form")
			if statue and _is_usable(monster, statue):
				return {"ability": statue, "target": monster}
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
