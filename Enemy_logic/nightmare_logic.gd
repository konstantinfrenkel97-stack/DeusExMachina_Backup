extends RefCounted
class_name NightmareLogic

## ИИ Кошмара: если нет щита от смерти, с шансом 70% — «Незабываемый».
## Иначе случайный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var unforg_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			if ab.ability_marker == "nightmare_unforgettable" or ab.stance_effect_type == "nightmare_unforgettable":
				unforg_ab = ab
	if usable.is_empty():
		return {}
	# Есть ли уже активный щит от смерти?
	var has_shield = (monster.special_effect_type == "immortal_death_shield")
	for eff in monster.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "nightmare_death_shield":
			has_shield = true
			break
	if unforg_ab != null and not has_shield and randf() < 0.70:
		return {"ability": unforg_ab, "target": monster}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		if ab.target_type == "All_Enemies":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
