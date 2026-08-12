extends RefCounted
class_name NagaMonkLogic

## ИИ Нага монах: 2+ союзника → «Часть вселенной» 70%; иначе «Наставление» на другого союзника.
## Если союзников < 2 → «Кармическое наказание», иначе «Наставление».

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var universe_ab = null
	var guidance_ab = null
	var karma_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.is_stance and ab.stance_effect_type == "naga_universe":
			universe_ab = ab
		elif ab.ability_marker == "naga_karma_punish":
			karma_ab = ab
		elif ab.target_type == "Ally":
			guidance_ab = ab
	var ally_count = 0
	for a in allies:
		if a != null and a.current_hp > 0 and a != monster:
			ally_count += 1
	# 2+ союзника → Часть вселенной 70%
	if ally_count >= 2 and universe_ab != null and randf() < 0.70:
		if universe_ab.usable_from_positions.size() > monster.position_index and universe_ab.usable_from_positions[monster.position_index]:
			return {"ability": universe_ab, "target": monster}
	# Иначе Наставление на другого союзника
	if ally_count >= 2 and guidance_ab != null:
		for a in allies:
			if a != null and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, guidance_ab):
				return {"ability": guidance_ab, "target": a}
	# < 2 союзников → Кармическое наказание, иначе Наставление
	if karma_ab != null and (karma_ab.usable_from_positions.size() > monster.position_index and karma_ab.usable_from_positions[monster.position_index]):
		return {"ability": karma_ab, "target": monster}
	if guidance_ab != null:
		for a in allies:
			if a != null and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, guidance_ab):
				return {"ability": guidance_ab, "target": a}
	return {}
