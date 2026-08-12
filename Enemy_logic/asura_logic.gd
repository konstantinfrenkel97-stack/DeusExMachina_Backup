extends RefCounted
class_name AsuraLogic

## ИИ Асура: если не активна «Чёрная полоса» (марка) — применяет её. Иначе другой навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var streak_ab = null
	var chaos_ab = null
	var curse_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		match ab.ability_marker:
			"asura_streak": streak_ab = ab
			"asura_chaos_strike": chaos_ab = ab
			"asura_curse": curse_ab = ab
	# Активна ли Чёрная полоса? (meta флаг ставится в battle_scene при размещении марки)
	var streak_active = monster.has_meta("asura_streak_active")
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
	if usable.is_empty():
		return {}
	if not streak_active and streak_ab != null:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, streak_ab):
				return {"ability": streak_ab, "target": h}
	# Иначе другой навык (предпочтение curse → chaos)
	if curse_ab != null and usable.has(curse_ab):
		return {"ability": curse_ab, "target": monster}
	if chaos_ab != null:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, chaos_ab):
				return {"ability": chaos_ab, "target": h}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
