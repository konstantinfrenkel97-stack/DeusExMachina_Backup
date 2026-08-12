extends RefCounted
class_name DevilLogic

## ИИ Дьявола: если есть противник с 0 величия — «Наказание для недостойных».
## Иначе 70% — «Адская гильотина», 30% — «Оставь надежду».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var pun_ab = null
	var guil_ab = null
	var hope_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			match ab.ability_marker:
				"devil_punishment": pun_ab = ab
				"devil_guillotine": guil_ab = ab
				"": if ab.is_stance: hope_ab = ab
	if usable.is_empty():
		return {}
	# Есть ли противник с 0 величия?
	var zero_target = null
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		if h.current_majesty <= 0 and pun_ab != null and Combatant.can_be_targeted_at(h, pun_ab):
			zero_target = h
			break
	if pun_ab != null and zero_target != null:
		return {"ability": pun_ab, "target": zero_target}
	# Иначе 70% гильотина / 30% «Оставь надежду»
	var roll = randf()
	if roll < 0.70 and guil_ab != null:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, guil_ab):
				return {"ability": guil_ab, "target": h}
	if hope_ab != null:
		return {"ability": hope_ab, "target": monster}
	# Fallback
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
