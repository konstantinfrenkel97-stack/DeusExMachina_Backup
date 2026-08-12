extends RefCounted
class_name OborotenLogic

## Оборотень: если не активен бафф от "Звериные повадки" — применяет его (70%).
## Иначе применяет другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var buff_ability: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
				if ab.ability_marker == "zverinye_povadki":
					buff_ability = ab

	if usable.is_empty():
		return {}

	# Проверяем, активен ли бафф от "Звериные повадки"
	var buff_active = false
	for e in monster.active_effects:
		var src = Combatant._effect_get(e, "source_ability", "")
		if src == "zverinye_povadki":
			buff_active = true
			break

	# Если бафф не активен — 70% шанс применить его
	if not buff_active and buff_ability and randi() % 100 < 70:
		return {"ability": buff_ability, "target": monster}

	# Иначе — случайный другой навык
	var other: Array = []
	for ab in usable:
		if ab != buff_ability:
			other.append(ab)
	if other.is_empty() and buff_ability:
		other = [buff_ability]
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
