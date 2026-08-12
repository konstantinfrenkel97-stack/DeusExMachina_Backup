extends RefCounted
class_name TrollLogic

## Тролль: если HP < 50% и нет активной регенерации — применяет "Тролли не умирают".
## Иначе применяет другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var heal_ability: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
				if ab.ability_marker == "trolli_ne_umirayut":
					heal_ability = ab

	if usable.is_empty():
		return {}

	# Проверяем активна ли регенерация от "Тролли не умирают"
	var regen_active = false
	for e in monster.active_effects:
		if Combatant._effect_get(e, "source_ability", "") == "trolli_ne_umirayut":
			regen_active = true
			break

	# Если HP < 50% и нет регенерации — лечимся
	var hp_pct = float(monster.current_hp) / float(monster.max_hp) if monster.max_hp > 0 else 1.0
	if hp_pct < 0.5 and not regen_active and heal_ability:
		return {"ability": heal_ability, "target": monster}

	# Иначе — случайный другой навык
	var other: Array = []
	for ab in usable:
		if ab != heal_ability:
			other.append(ab)
	if other.is_empty() and heal_ability:
		other = [heal_ability]
	if other.is_empty():
		return {}

	var ability: AbilityResource = other[randi() % other.size()]
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
