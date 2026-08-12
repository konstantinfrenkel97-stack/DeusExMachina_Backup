extends RefCounted
class_name DruidLogic

## Друид:
## — если не наложено «Стимулировать рост» — 70% применяет на случайную ally-позицию (кроме своей);
## — иначе если нет союзников с «Укрыть среди трав» — 70% применяет его;
## — иначе «Гнев природы».

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var usable: Array = []
	var growth: AbilityResource = null
	var hide: AbilityResource = null
	var wrath: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			match ab.name:
				"Стимулировать рост": growth = ab
				"Укрыть среди трав": hide = ab
				"Гнев природы": wrath = ab
	if usable.is_empty():
		return {}

	# Проверяем, есть ли уже +урон от Стимулировать рост на союзниках
	var growth_active = false
	for ally in allies:
		if ally and ally.current_hp > 0:
			for e in ally.active_effects:
				if Combatant._effect_get(e, "effect_id", "") == "druid_stimulate_growth":
					growth_active = true
					break
		if growth_active:
			break

	# 1) Стимулировать рост на случайного союзника (кроме себя), если ещё не наложено
	if growth and not growth_active and randf() < 0.7:
		var candidates: Array = []
		for ally in allies:
			if ally and ally.current_hp > 0 and ally != monster:
				candidates.append(ally)
		if not candidates.is_empty():
			return {"ability": growth, "target": candidates.pick_random()}

	# 2) Укрыть среди трав, если никто под ним
	if hide:
		var hide_active = false
		for ally in allies:
			if ally and ally.current_hp > 0:
				for e in ally.active_effects:
					if Combatant._effect_get(e, "source_ability", "") == "Укрыть среди трав":
						hide_active = true
						break
			if hide_active:
				break
		if not hide_active and randf() < 0.7:
			return {"ability": hide, "target": monster}

	# 3) Гнев природы (или любой доступный)
	var ability: AbilityResource = wrath if wrath else usable.pick_random()
	if ability.target_type == "Self" or ability.target_type == "All_Allies":
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
