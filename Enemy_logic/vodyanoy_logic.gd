extends RefCounted
class_name VodyanoyLogic

## Водяной: если не активна марка "Болотное царство" — применяет её (70%).
## Иначе применяет другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var mark_ability: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
				if ab.ability_marker == "bolotnoe_tsarstvo":
					mark_ability = ab

	if usable.is_empty():
		return {}

	# Проверяем, активна ли уже марка «Болотное царство» на ком-то из героев
	# (сама марка хранится в BattleMarks и недоступна отсюда напрямую, поэтому
	# используем тот же приём, что и у Феи шипов: метка узнаётся по effect_id
	# на цели, на которую был применён эффект марки).
	var mark_active = false
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		for e in h.active_effects:
			if Combatant._effect_get(e, "effect_id", "") == "bolotnoe_tsarstvo_mark":
				mark_active = true
				break
		if mark_active:
			break

	# Если марка не активна — 70% шанс применить её
	if not mark_active and mark_ability and randi() % 100 < 70:
		var target = _get_random_valid_target(heroes, mark_ability)
		if target:
			return {"ability": mark_ability, "target": target}

	# Иначе — случайный другой навык
	var other: Array = []
	for ab in usable:
		if ab != mark_ability:
			other.append(ab)
	if other.is_empty() and mark_ability:
		other = [mark_ability]
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
