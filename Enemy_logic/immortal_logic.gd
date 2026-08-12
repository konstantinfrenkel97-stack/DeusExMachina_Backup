extends RefCounted
class_name ImmortalLogic

## Бессмертный: если щит смерти уже использован — 70% восстановить его («Мой бой не окончен»).
## Иначе — случайная доступная способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var shield_used = false
	for eff in monster.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "immortal_shield_used":
			shield_used = true
			break
	if shield_used and randf() < 0.70:
		var stance = _find_ability(monster, "immortal_my_battle_not_over")
		if stance and _is_usable(monster, stance):
			return {"ability": stance, "target": monster}
	return _random_usable(monster, heroes)


static func _find_ability(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable(monster: Combatant, ab: AbilityResource) -> bool:
	if ab.usable_from_positions.size() > monster.position_index:
		return ab.usable_from_positions[monster.position_index]
	return false


static func _random_usable(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable(monster, ab):
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
