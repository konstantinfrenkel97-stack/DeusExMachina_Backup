extends RefCounted
class_name SuccubusLogic

## ИИ Суккуба: если нет противника с меткой провокации, с шансом 70% — «Я выбираю тебя».
## Иначе — другой навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var choose_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			if ab.ability_marker == "succubus_choose_you":
				choose_ab = ab
	if usable.is_empty():
		return {}
	# Есть ли уже противник с меткой провокации?
	var has_prov = false
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		for eff in h.active_effects:
			if Combatant._effect_get(eff, "stat", "") == "provocation_mark":
				has_prov = true
				break
		if has_prov:
			break
	if choose_ab != null and not has_prov and randf() < 0.70:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, choose_ab):
				return {"ability": choose_ab, "target": h}
	# Иначе другой навык
	var others = usable.duplicate()
	if choose_ab != null:
		others.erase(choose_ab)
	others.shuffle()
	for ab in others:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
