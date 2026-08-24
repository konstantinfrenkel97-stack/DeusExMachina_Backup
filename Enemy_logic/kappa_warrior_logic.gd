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

	# Отравить случайного врага «Ядом древнего народа» — но только один раз за бой,
	# в первый подходящий ход (спека: «...и больше не применяет»).
	if poison_ab != null and not monster.get_meta("kappa_poison_used", false) \
			and _is_usable_from_position(poison_ab, monster.position_index):
		var targets: Array = []
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, poison_ab) \
					and not _has_effect_from(h, "periodic_damage", "kappa_ancient_poison"):
				targets.append(h)
		if targets.size() > 0:
			monster.set_meta("kappa_poison_used", true)
			return {"ability": poison_ab, "target": targets.pick_random()}

	# Иначе — случайный доступный навык (яд сюда уже не попадёт после первого применения).
	return _random_usable(monster, heroes, poison_ab if monster.get_meta("kappa_poison_used", false) else null)


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


static func _random_usable(monster: Combatant, heroes: Array, exclude_ab: AbilityResource = null) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null or ab == exclude_ab:
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
