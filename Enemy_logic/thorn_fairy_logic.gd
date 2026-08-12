extends RefCounted
class_name ThornFairyLogic

## Фея шипов: если «Колючий куст» ещё не наложен — 70% применяет его на случайную ally-позицию.
## Иначе применяет другой доступный навык.

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var usable: Array = []
	var bush: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			if ab.name == "Колючий куст":
				bush = ab
	if usable.is_empty():
		return {}
	# Проверяем, есть ли уже активная марка «Колючий куст» на союзниках
	var bush_active = false
	for ally in allies:
		if ally and ally.current_hp > 0:
			for e in ally.active_effects:
				if Combatant._effect_get(e, "source_ability", "") == "Колючий куст":
					bush_active = true
					break
		if bush_active:
			break
	if bush and not bush_active and randf() < 0.7:
		# Выбираем случайного живого союзника как цель-позицию
		var ally_targets: Array = []
		for ally in allies:
			if ally and ally.current_hp > 0:
				ally_targets.append(ally)
		if not ally_targets.is_empty():
			return {"ability": bush, "target": ally_targets.pick_random()}
	# Иначе другой навык
	var others = usable.duplicate()
	others.erase(bush)
	var ability: AbilityResource = (others.pick_random() if not others.is_empty() else usable.pick_random())
	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}
	var target = _first_valid_hero(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
	return {}


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
