extends RefCounted
class_name CyclopsLogic

const GAZE_ABILITY_NAME = "взгляд циклопа"
const GAZE_SELF_EFFECT = "self_buff_accuracy"
const GAZE_TARGET_EFFECT = "target_debuff_accuracy"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var has_gaze_buff = _has_gaze_self_buff(monster)
	var gaze_ability = _find_gaze_ability(monster)
	var other_abilities = _get_other_usable_abilities(monster)

	# Бафф точности активен — не используем взгляд, атакуем
	if has_gaze_buff:
		var attack = _pick_attack_ability(monster, heroes, other_abilities)
		if attack.has("ability"):
			return attack
		return {}

	# Нет баффа — 70% взгляд, 30% атака
	if randf() < 0.70 and gaze_ability != null:
		var gaze_target = _get_gaze_target(monster, heroes)
		if gaze_target:
			return {"ability": gaze_ability, "target": gaze_target}

	# 30% атака (или взгляд недоступен — тоже атакуем)
	if not other_abilities.is_empty():
		var attack = _pick_attack_ability(monster, heroes, other_abilities)
		if attack.has("ability"):
			return attack

	# Совсем ничего не нашли — всё равно попробуем взгляд как последний вариант
	if gaze_ability != null:
		var gaze_target = _get_gaze_target(monster, heroes)
		if gaze_target:
			return {"ability": gaze_ability, "target": gaze_target}

	return {}

static func _pick_attack_ability(monster: Combatant, heroes: Array, abilities: Array) -> Dictionary:
	if abilities.is_empty():
		return {}
	var shuffled = abilities.duplicate()
	shuffled.shuffle()
	for ability in shuffled:
		var target = _find_gaze_debuffed_target(heroes, ability)
		if target == null:
			target = _get_random_target(heroes, ability)
		if target:
			return {"ability": ability, "target": target}
	return {}

static func _find_gaze_ability(monster: Combatant) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == GAZE_ABILITY_NAME:
			return ab
	return null

static func _get_other_usable_abilities(monster: Combatant) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab == null or ab.name.to_lower() == GAZE_ABILITY_NAME:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				abilities.append(ab)
	return abilities

static func _get_gaze_target(monster: Combatant, heroes: Array) -> Combatant:
	var potential: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and _hero_in_gaze_range(monster.position_index, h.position_index):
			potential.append(h)
	return potential.pick_random() if not potential.is_empty() else null

static func _hero_in_gaze_range(cyclops_pos: int, hero_pos: int) -> bool:
	if cyclops_pos <= 1:
		return hero_pos <= 1
	return hero_pos >= 1 and hero_pos <= 2

static func _find_gaze_debuffed_target(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and _has_gaze_debuff(h):
			if _can_target_with_ability(ability, h):
				return h
	return null

static func _get_random_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid = _get_valid_targets(heroes, ability)
	return valid.pick_random() if not valid.is_empty() else null

static func _get_valid_targets(heroes: Array, ability: AbilityResource) -> Array:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and _can_target_with_ability(ability, h):
			valid.append(h)
	return valid

static func _can_target_with_ability(ability: AbilityResource, hero: Combatant) -> bool:
	return Combatant.can_be_targeted_at(hero, ability)

static func _has_gaze_self_buff(unit: Combatant) -> bool:
	for effect in unit.active_effects:
		# Проверяем строго по effect_id — любой бафф точности не считается
		if _effect_key(effect, "effect_id") == GAZE_SELF_EFFECT:
			return true
	return false

static func _has_gaze_debuff(unit: Combatant) -> bool:
	for effect in unit.active_effects:
		if _effect_key(effect, "effect_id") == GAZE_TARGET_EFFECT:
			return true
		if _effect_key(effect, "stat") == "accuracy" and _effect_int(effect, "value") < 0:
			return true
	return false

static func _effect_key(effect, key: String):
	if effect is Dictionary:
		return effect.get(key)
	return effect.get(key) if effect.has_method("get") else null

static func _effect_int(effect, key: String) -> int:
	return int(_effect_key(effect, key))
