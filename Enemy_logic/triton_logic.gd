extends RefCounted
class_name TritonLogic

## Тритон: если на нём не активен бафф «Морская кавалерия» —
## с шансом 70% применяет его. Иначе — другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var cavalry_ab := _find_by_name(monster, "Морская кавалерия")
	if cavalry_ab != null and _is_usable_from_position(cavalry_ab, monster.position_index):
		if not _has_cavalry_buff(monster):
			if randf() < 0.70:
				return {"ability": cavalry_ab, "target": monster}

	# Иначе — случайная доступная способность.
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


static func _has_cavalry_buff(unit: Combatant) -> bool:
	for e in unit.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "triton_cavalry":
			return true
	return false


static func _find_by_name(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
