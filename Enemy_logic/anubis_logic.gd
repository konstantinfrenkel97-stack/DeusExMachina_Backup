extends RefCounted
class_name AnubisLogic

## Жрец Анубиса: если есть союзник <40% HP — 70% «Отсрочка от смерти».
## Иначе — случайная доступная способность.

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var heal_ab = _find_ability(monster, "anubis_death_delay")
	if heal_ab and _is_usable(monster, heal_ab):
		var low_ally: Combatant = null
		for a in allies:
			if a and a.current_hp > 0 and a != monster:
				if float(a.current_hp) / float(a.max_hp) < 0.40:
					if Combatant.can_be_targeted_at(a, heal_ab):
						low_ally = a
						break
		if low_ally and randf() < 0.70:
			return {"ability": heal_ab, "target": low_ally}
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
		# Поддерживающие способности (Ally/All_Allies) не наводятся на врагов
		if ab.target_type == "Ally" or ab.target_type == "All_Allies":
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
