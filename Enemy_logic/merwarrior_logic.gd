extends RefCounted
class_name MerwarriorLogic

## Русал воин: при «Бурных потоках» (is_raging=true) использует «Поймать в сеть»,
## при «Спокойных водах» (is_raging=false) — «Пронзить трезубцем».

static func get_decision_depths(monster: Combatant, heroes: Array, is_raging: bool) -> Dictionary:
	var net_ab := _find_by_name(monster, "Поймать в сеть")
	var trident_ab := _find_by_name(monster, "Пронзить трезубцем")
	var chosen := trident_ab if not is_raging else net_ab
	if chosen != null and _is_usable_from_position(chosen, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, chosen):
				return {"ability": chosen, "target": h}
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


static func _find_by_name(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
