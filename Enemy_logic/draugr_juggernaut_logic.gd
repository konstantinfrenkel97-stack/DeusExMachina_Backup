extends RefCounted
class_name DraugrJuggernautLogic

const UNSTOPPABLE_ADVANCE = "неостановимое наступление"
const SHREDDING_CUT = "рассекающий удар"
const FINAL_BLOW = "добивающий удар"
const ARMOR_DEBUFF_THRESHOLD = -30

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var pos = monster.position_index

	# На задних позициях (2-3): выдвигаемся вперёд
	if pos >= 2:
		var advance = _find_ability(monster, UNSTOPPABLE_ADVANCE)
		if advance:
			return {"ability": advance, "target": monster}

	# На передних позициях (0-1): атакуем
	# Приоритет: если у бога дебафф брони >= 30 — добивающий удар
	var debuffed_target = _find_high_armor_debuff_target(heroes)
	if debuffed_target:
		var final_blow = _find_ability(monster, FINAL_BLOW)
		if final_blow and _can_target_with_ability(final_blow, debuffed_target):
			return {"ability": final_blow, "target": debuffed_target}

	# По умолчанию: рассекающий удар
	var cut = _find_ability(monster, SHREDDING_CUT)
	if cut:
		var cut_target = _get_random_valid_target(heroes, cut)
		if cut_target:
			return {"ability": cut, "target": cut_target}

	# Запасной вариант: любая доступная способность
	return _fallback_ability(monster, heroes)

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == ability_name:
			return ab
	return null

static func _find_high_armor_debuff_target(heroes: Array) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0:
			for effect in h.active_effects:
				var stat = _effect_key(effect, "stat")
				var value = _effect_key(effect, "value")
				if stat == "armor" and value is int and value <= ARMOR_DEBUFF_THRESHOLD:
					return h
	return null

static func _can_target_with_ability(ability: AbilityResource, hero: Combatant) -> bool:
	return Combatant.can_be_targeted_at(hero, ability)

static func _get_random_valid_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and _can_target_with_ability(ability, h):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null

static func _fallback_ability(monster: Combatant, heroes: Array) -> Dictionary:
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		var target = _get_random_valid_target(heroes, ab)
		if target:
			return {"ability": ab, "target": target}
	return {}

static func _effect_key(effect, key: String):
	if effect is Dictionary:
		return effect.get(key)
	return effect.get(key) if effect.has_method("get") else null
