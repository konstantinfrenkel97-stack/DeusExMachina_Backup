extends RefCounted
class_name CoatlLogic

## ИИ Коатль: если может «Кислотное дыхание» — оно. Иначе 70% «Ветра судьбы» / 30% «Крылья урагана».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var acid_ab = null
	var wings_ab = null
	var winds_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		match ab.ability_marker:
			"coatl_acid_breath": acid_ab = ab
			"coatl_winds": winds_ab = ab
		if ab.name == "Крылья урагана":
			wings_ab = ab
	var usable_from = func(ab) -> bool:
		return ab != null and ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]
	if usable_from.call(acid_ab):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, acid_ab):
				return {"ability": acid_ab, "target": h}
	var roll = randf()
	if roll < 0.70 and usable_from.call(winds_ab):
		return {"ability": winds_ab, "target": monster}
	if usable_from.call(wings_ab):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, wings_ab):
				return {"ability": wings_ab, "target": h}
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
