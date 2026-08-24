extends RefCounted
class_name ScarabLogic

## Золотой скоробей:
## • нет союзников кроме других Золотых скоробеев — всегда «Царапать»;
## • иначе, если союзников (любых) 2+ — 70% «На удачу», иначе «Зарыться в песок».

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var living_allies = 0
	var non_scarab_allies = 0
	for a in allies:
		if a and a.current_hp > 0 and a != monster:
			living_allies += 1
			if a.ai_script != monster.ai_script:
				non_scarab_allies += 1
	var scratch = _find_ability(monster, "scarab_scratch")
	var luck = _find_ability(monster, "scarab_good_luck")
	var bury = _find_ability(monster, "scarab_bury_in_sand")
	if non_scarab_allies == 0:
		if scratch and _is_usable(monster, scratch):
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, scratch):
					return {"ability": scratch, "target": h}
	if living_allies >= 2 and luck and _is_usable(monster, luck) and randf() < 0.70:
		return {"ability": luck, "target": monster}
	if bury and _is_usable(monster, bury):
		return {"ability": bury, "target": monster}
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
