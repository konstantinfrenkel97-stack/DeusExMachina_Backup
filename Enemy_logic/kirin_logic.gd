extends RefCounted
class_name KirinLogic

## Кирин: если у цели есть 2+ баффов и доступно «Нисхождение с небес» — применяет его.
## Иначе — «Укус кирина». С вероятностью 30% — стойка «Быстрый как молния».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var lightning_ab := _find_by_marker(monster, "kirin_lightning_fast")
	var bite_ab := _find_by_marker(monster, "kirin_bite")
	var heaven_ab := _find_by_marker(monster, "kirin_heaven_descent")

	# 30% — стойка «Быстрый как молния» (если доступна).
	if lightning_ab != null and _is_usable_from_position(lightning_ab, monster.position_index):
		if randf() < 0.30:
			return {"ability": lightning_ab, "target": monster}

	# «Нисхождение с небес», если у какой-то цели 2+ баффов.
	if heaven_ab != null and _is_usable_from_position(heaven_ab, monster.position_index):
		for h in heroes:
			if h == null or h.current_hp <= 0:
				continue
			if not Combatant.can_be_targeted_at(h, heaven_ab):
				continue
			if _count_buffs_on_unit(h) >= 2:
				return {"ability": heaven_ab, "target": h}

	# Иначе — «Укус кирина».
	if bite_ab != null and _is_usable_from_position(bite_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, bite_ab):
				return {"ability": bite_ab, "target": h}

	# Fallback: любой доступный навык.
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


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true


static func _count_buffs_on_unit(unit: Combatant) -> int:
	var cnt = 0
	for eff in unit.active_effects:
		var stat_name = Combatant._effect_get(eff, "stat", "")
		var effect_value = Combatant._effect_get(eff, "value", 0)
		var is_buff = effect_value > 0 and stat_name != "stun" and stat_name != "periodic_damage" \
				and stat_name != "regeneration"
		if is_buff:
			cnt += 1
	return cnt
