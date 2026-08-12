extends RefCounted
class_name MermaidSorceressLogic

## Русалка волшебница: если живых союзников ≤ 1 — всегда «Гнев океана».
## Иначе — случайный доступный навык.

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var living_allies := 0
	for a in allies:
		if a and a.current_hp > 0:
			living_allies += 1
	var wrath_ab := _find_by_name(monster, "Гнев океана")
	if living_allies <= 1 and wrath_ab != null and _is_usable_from_position(wrath_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, wrath_ab):
				return {"ability": wrath_ab, "target": h}
	# Иначе — случайная доступная способность (включая баффы/стойку на союзников).
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
		if ab.target_type == "Ally" or ab.target_type == "All_Allies":
			for a in allies:
				if a and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, ab):
					return {"ability": ab, "target": a}
		else:
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
					return {"ability": ab, "target": h}
	return {}


static func _find_by_name(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
