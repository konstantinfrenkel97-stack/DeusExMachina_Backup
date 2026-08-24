extends RefCounted
class_name OniSorcererLogic

const BEADS_NAME = "пылающие бусы"

## Красный Они: если ни на ком нет дебаффа пылающих бусин — 70% использовать их.
## Иначе применяет другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var beads_ability = _find_beads_ability(monster)
	var has_beads_debuff = _any_hero_has_beads_debuff(heroes)

	# Нет дебаффа на врагах и бусины доступны — 70% шанс
	if not has_beads_debuff and beads_ability != null:
		if randf() < 0.70:
			var target = _get_random_target(heroes, beads_ability)
			if target:
				return {"ability": beads_ability, "target": target}

	# Иначе случайная доступная способность — не бусины, если дебафф уже есть
	# (если условие для бусин выше просто не выпало на броске, они остаются в пуле)
	var usable = _get_usable_abilities(monster)
	if has_beads_debuff and beads_ability != null:
		usable.erase(beads_ability)
	usable.shuffle()
	for ability in usable:
		var target = _get_random_target(heroes, ability)
		if target:
			return {"ability": ability, "target": target}

	# Фолбэк — бусины как последний вариант, только если дебаффа ещё ни на ком нет
	if not has_beads_debuff and beads_ability != null:
		var target = _get_random_target(heroes, beads_ability)
		if target:
			return {"ability": beads_ability, "target": target}

	return {}

static func _find_beads_ability(monster: Combatant) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == BEADS_NAME:
			return ab
	return null

static func _any_hero_has_beads_debuff(heroes: Array) -> bool:
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		for eff in h.active_effects:
			var src = Combatant._effect_get(eff, "source_ability", "")
			if src != "" and src.to_lower() == BEADS_NAME:
				return true
			var eid = Combatant._effect_get(eff, "effect_id", "")
			if eid != "" and eid == "oni_flaming_beads":
				return true
	return false

static func _get_usable_abilities(monster: Combatant) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				abilities.append(ab)
	return abilities

static func _get_random_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
