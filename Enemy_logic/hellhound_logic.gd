extends RefCounted
class_name HellhoundLogic

## ИИ Адской гончей: с шансом 70% применяет «Не бояться смерти», если эффект ещё не наложен.
## Иначе — другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var has_no_fear = false
	for eff in monster.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "hellhound_no_fear":
			has_no_fear = true
			break
	var no_fear_ab = null
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			if ab.ability_marker == "hellhound_no_fear":
				no_fear_ab = ab
	if usable.is_empty():
		return {}
	if no_fear_ab != null and not has_no_fear and randf() < 0.70:
		return {"ability": no_fear_ab, "target": monster}
	# Иначе — любой другой навык
	var others = usable.duplicate()
	if no_fear_ab != null:
		others.erase(no_fear_ab)
	if not others.is_empty():
		others.shuffle()
		for ab in others:
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
					return {"ability": ab, "target": h}
	# Fallback на любой
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
