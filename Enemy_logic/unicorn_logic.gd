extends RefCounted
class_name UnicornLogic

## Единорог:
## — если есть союзник < 40%% HP — «Кровь единорога»;
## — иначе 70%% «Очищающий рог», 30%% «Грациозная осанка».

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var usable: Array = []
	var horn: AbilityResource = null
	var blood: AbilityResource = null
	var grace: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			match ab.name:
				"Очищающий рог": horn = ab
				"Кровь единорога": blood = ab
				"Грациозная осанка": grace = ab
	if usable.is_empty():
		return {}

	# Союзник < 40%% HP → Кровь единорога
	if blood:
		for ally in allies:
			if ally and ally.current_hp > 0 and float(ally.current_hp) / float(maxi(1, ally.max_hp)) < 0.4:
				return {"ability": blood, "target": ally}

	# 70%% Очищающий рог, 30%% Грациозная осанка
	var ability: AbilityResource
	if randf() < 0.7:
		ability = horn if horn else usable.pick_random()
	else:
		ability = grace if grace else usable.pick_random()
	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}
	var target = _first_valid_hero(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
	# fallback
	var fb = usable.pick_random()
	if fb.target_type == "Self":
		return {"ability": fb, "target": monster}
	return {}


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
