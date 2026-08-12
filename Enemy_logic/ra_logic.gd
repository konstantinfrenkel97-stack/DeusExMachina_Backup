extends RefCounted
class_name RaLogic

## Жрец Ра: если «Испепеление» может опустить цель ниже 50% HP — бить её.
## Иначе — «Слава солнцу».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var incin = _find_ability(monster, "ra_incineration")
	var sun = _find_ability(monster, "ra_sun_glory")
	if incin and _is_usable(monster, incin):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, incin):
				var threshold = float(h.max_hp) * 0.5
				if float(h.current_hp) > threshold:
					var est = int(monster.damage * 1.4)
					if float(h.current_hp - est) <= threshold:
						return {"ability": incin, "target": h}
	if sun and _is_usable(monster, sun):
		return {"ability": sun, "target": monster}
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
