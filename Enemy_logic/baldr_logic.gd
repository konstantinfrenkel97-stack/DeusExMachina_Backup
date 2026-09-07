extends RefCounted
class_name BaldrLogic

## Бальдр (друг немезида Хельхейма): применяет доступную способность. Если может
## применить ульту (хватает величия и позиция позволяет) — применяет её.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var ultimate: AbilityResource = monster.ultimate_ability
	if ultimate != null and ultimate.majesty_cost > 0 and monster.current_majesty >= ultimate.majesty_cost:
		if ultimate.usable_from_positions.size() > monster.position_index and ultimate.usable_from_positions[monster.position_index]:
			return {"ability": ultimate, "target": monster}

	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self" or ab.target_type == "All_Enemies":
			return {"ability": ab, "target": monster}
		var target = _first_valid_hero(heroes, ab)
		if target:
			return {"ability": ab, "target": target}
	return {}


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
