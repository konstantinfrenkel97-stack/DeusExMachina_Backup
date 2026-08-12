extends RefCounted
class_name KappaWarriorLogic

## Каппа воин: в первый ход применяет «Яд древнего народа» на случайного врага без этого эффекта,
## затем — случайный доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var poison_ab: AbilityResource = null
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == "kappa_ancient_poison":
			poison_ab = ab
			break

	# Если есть способность яда и доступна — проверить, нужно ли применить (есть ли враг без яда).
	if poison_ab != null and _is_usable_from_position(poison_ab, monster.position_index):
		var has_enemy_without_poison = false
		for h in heroes:
			if h == null or h.current_hp <= 0:
				continue
			if Combatant.can_be_targeted_at(h, poison_ab):
				if not _has_effect_from(h, "periodic_damage", "kappa_ancient_poison"):
					has_enemy_without_poison = true
					break
		# Применяем яд, только если НИКТО из врагов ещё не отравлен.
		if has_enemy_without_poison and not _any_hero_poisoned(heroes, poison_ab):
			var targets: Array = []
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, poison_ab) \
						and not _has_effect_from(h, "periodic_damage", "kappa_ancient_poison"):
					targets.append(h)
			if targets.size() > 0:
				return {"ability": poison_ab, "target": targets.pick_random()}

	# Иначе — случайный доступный навык (включая яд при необходимости).
	return _random_usable(monster, heroes)


static func _any_hero_poisoned(heroes: Array, poison_ab: AbilityResource) -> bool:
	for h in heroes:
		if h and h.current_hp > 0 and _has_effect_from(h, "periodic_damage", "kappa_ancient_poison"):
			return true
	return false


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true


static func _has_effect_from(unit: Combatant, stat: String, source_marker: String) -> bool:
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "stat", "") == stat:
			var sa = Combatant._effect_get(eff, "source_ability", "")
			if sa == source_marker:
				return true
	return false


static func _random_usable(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
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
