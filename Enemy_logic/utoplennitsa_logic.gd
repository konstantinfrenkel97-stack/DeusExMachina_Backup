extends RefCounted
class_name UtoplennitsaLogic

## Утопленница: выбирает случайную доступную способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)

	if usable.is_empty():
		return {}

	var ability: AbilityResource = usable[randi() % usable.size()]

	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}

	var target = _get_random_valid_target(heroes, ability)
	if target:
		return {"ability": ability, "target": target}

	return {}

static func _get_random_valid_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
