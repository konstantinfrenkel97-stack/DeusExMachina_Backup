extends RefCounted
class_name RakshasaLogic

## ИИ Ракшас: на позициях 1-2 (index 0-1) — 70% «Злобный удар» / 30% «Подсечка». Иначе «Дисгармония».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var vicious_ab = null
	var sweep_ab = null
	var dish_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		match ab.ability_marker:
			"rakshasa_vicious_strike": vicious_ab = ab
		if ab.name == "Подсечка":
			sweep_ab = ab
		elif ab.is_stance and ab.stance_effect_type == "rakshasa_disharmony":
			dish_ab = ab
	var usable_from = func(ab) -> bool:
		return ab != null and ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]
	if monster.position_index <= 1:
		var roll = randf()
		if roll < 0.70 and usable_from.call(vicious_ab):
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, vicious_ab):
					return {"ability": vicious_ab, "target": h}
		if usable_from.call(sweep_ab):
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, sweep_ab):
					return {"ability": sweep_ab, "target": h}
	if dish_ab != null and usable_from.call(dish_ab):
		return {"ability": dish_ab, "target": monster}
	# Fallback
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
