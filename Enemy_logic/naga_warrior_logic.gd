extends RefCounted
class_name NagaWarriorLogic

## ИИ Нага воин: если есть бафф точности — не применяет «Танец джунглей». Иначе случайный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var has_acc_buff = false
	for eff in monster.active_effects:
		if Combatant._effect_get(eff, "stat", "") == "accuracy" and Combatant._effect_get(eff, "value", 0) > 0:
			has_acc_buff = true
			break
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if has_acc_buff and ab.name == "Танец джунглей":
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	# Fallback (даже танец)
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
