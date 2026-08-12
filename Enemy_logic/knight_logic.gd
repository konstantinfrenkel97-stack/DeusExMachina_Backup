extends RefCounted
class_name KnightLogic

## Рыцарь: если у цели есть бафф — 50% «Изгнать зло», иначе случайный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var banish := _find_by_marker(monster, "knight_banish_evil")
	if banish != null and _is_usable_from_position(banish, monster.position_index):
		# Найти героя с баффами
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, banish) and _has_buffs(h):
				if randf() < 0.50:
					return {"ability": banish, "target": h}
	return _random_decision(monster, heroes)


static func _has_buffs(unit: Combatant) -> bool:
	for e in unit.active_effects:
		var v = Combatant._effect_get(e, "value", 0)
		var s = Combatant._effect_get(e, "stat", "")
		if v > 0 and s != "stun" and s != "periodic_damage":
			return true
	return false


static func _random_decision(monster: Combatant, heroes: Array) -> Dictionary:
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
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
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
