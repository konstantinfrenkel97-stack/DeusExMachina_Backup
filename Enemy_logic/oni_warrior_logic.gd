extends RefCounted
class_name OniWarriorLogic

## Синий Они: использует случайную доступную способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable = _get_usable_abilities(monster)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ability in usable:
		var target = _get_random_target(heroes, ability)
		if target:
			return {"ability": ability, "target": target}
	return {}

static func _get_usable_abilities(monster: Combatant) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				abilities.append(ab)
	return abilities

static func _get_random_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
