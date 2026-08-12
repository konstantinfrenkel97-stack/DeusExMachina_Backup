extends RefCounted
class_name LavaBoarLogic

## Лавовый кабан: с вероятностью 30% и при неполном HP — «Горячее сердце».
## Иначе — любой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var heart_ab := _find_by_marker(monster, "lava_boar_warm_heart")

	# Горячее сердце только при неполном HP и с шансом 30%.
	if heart_ab != null and _is_usable_from_position(heart_ab, monster.position_index):
		if monster.current_hp < monster.max_hp and randf() < 0.30:
			return {"ability": heart_ab, "target": monster}

	# Иначе — любой доступный навык, кроме стойки.
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if not _is_usable_from_position(ab, monster.position_index):
			continue
		if ab.is_stance:
			continue
		usable.append(ab)
	if usable.is_empty():
		# Если не осталось ничего, кроме стойки — применим стойку.
		if heart_ab != null:
			return {"ability": heart_ab, "target": monster}
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
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
