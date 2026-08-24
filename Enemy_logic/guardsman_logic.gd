extends RefCounted
class_name GuardsmanLogic

## Стражник:
## • чётный раунд — «Стой кто идёт!», если ни у одного Стражника нет активной стойки;
## • иначе случайный навык (без «Стой кто идёт!», чтобы не обойти условия выше);
## • предпочитает атаковать убийц союзников.

static func get_decision_castle(monster: Combatant, heroes: Array, allies: Array, current_round: int) -> Dictionary:
	var halt_ab := _find_by_marker(monster, "guardsman_halt")

	# Чётный раунд: попытаться использовать «Стой кто идёт!»
	if halt_ab != null and current_round % 2 == 0 and _is_usable_from_position(halt_ab, monster.position_index):
		# Проверить, нет ли уже активной стойки у другого Стражника
		var someone_has_halt = false
		for a in allies:
			if a and a.current_hp > 0 and a.active_stance != null:
				if a.active_stance.stance_effect_type == "guardsman_halt":
					someone_has_halt = true
					break
		if not someone_has_halt:
			return {"ability": halt_ab, "target": monster}

	# Случайный навык с приоритетом на убийц; «Стой кто идёт!» сюда не попадает,
	# иначе случайный выбор мог бы применить его в нечётный раунд или поверх чужой стойки.
	return _random_decision_prefer_killers(monster, heroes, halt_ab)


static func _random_decision_prefer_killers(monster: Combatant, heroes: Array, exclude_ab: AbilityResource) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null or ab == exclude_ab:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		# Сначала пытаемся атаковать убийцу союзников
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab) and h.has_killed_enemy:
				return {"ability": ab, "target": h}
		# Иначе любой враг
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
