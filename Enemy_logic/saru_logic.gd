extends RefCounted
class_name SaruLogic

## ИИ Сару: 2+ союзника и можно «Играться» → она; нет 2 союзников и можно «Обезьяньи трюки» → они; иначе «Напрыгнуть».

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var play_ab = null
	var tricks_ab = null
	var leap_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if not (ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]):
			continue
		match ab.ability_marker:
			"saru_tricks": tricks_ab = ab
			_: 
				if ab.name == "Играться": play_ab = ab
				elif ab.name == "Напрыгнуть": leap_ab = ab
	# Живые союзники кроме себя
	var ally_count = 0
	for a in allies:
		if a != null and a.current_hp > 0 and a != monster:
			ally_count += 1
	if ally_count >= 2 and play_ab != null:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, play_ab):
				return {"ability": play_ab, "target": h}
	if ally_count < 2 and tricks_ab != null:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, tricks_ab):
				return {"ability": tricks_ab, "target": h}
	if leap_ab != null:
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, leap_ab):
				return {"ability": leap_ab, "target": h}
	# Fallback на любой
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
