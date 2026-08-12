extends RefCounted
class_name ScorpioLogic

## Скорпион: с шансом 30% использует Жестокость (бафф/дебафф на всех),
## иначе — случайную другую доступную способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var cruelty_ab := _find_by_marker(monster, "scorpio_cruelty")

	if cruelty_ab != null and _is_usable_from_position(cruelty_ab, monster.position_index):
		if randf() < 0.30:
			return {"ability": cruelty_ab, "target": monster}

	# Иначе — любая другая доступная способность.
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab == cruelty_ab:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)

	if usable.is_empty():
		# Если ничего не осталось — используем Жестокость, если доступна.
		if cruelty_ab != null and _is_usable_from_position(cruelty_ab, monster.position_index):
			return {"ability": cruelty_ab, "target": monster}
		return {}

	var ability: AbilityResource = usable.pick_random()

	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}

	var target = _first_valid_hero(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
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


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
