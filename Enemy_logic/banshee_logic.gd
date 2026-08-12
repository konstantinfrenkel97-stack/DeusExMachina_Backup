extends RefCounted
class_name BansheeLogic

## Банши: на позиции 1 — всегда «Не смотри!», на других — 70% «Крик боли», 30% «Обречённый стон».

const DONT_LOOK = "не смотри!"
const CRY_OF_PAIN = "крик боли"
const DOOMED_GROAN = "обречённый стон"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	# На позиции 0 (передняя): всегда «Не смотри!»
	if monster.position_index == 0:
		var ab = _find_ability(monster, DONT_LOOK)
		if ab:
			var target = _get_random_valid_target(heroes, ab)
			if target:
				return {"ability": ab, "target": target}
	
	# На других позициях: 70% Крик боли, 30% Обречённый стон
	if randf() < 0.70:
		var cry = _find_ability(monster, CRY_OF_PAIN)
		if cry:
			# All_Enemies — цель не важна, но нужен любой живой героль
			return {"ability": cry, "target": _any_alive_hero(heroes)}
	else:
		var groan = _find_ability(monster, DOOMED_GROAN)
		if groan:
			var target = _get_random_valid_target(heroes, groan)
			if target:
				return {"ability": groan, "target": target}
	
	# Запасной вариант: любая доступная способность
	return _fallback(monster, heroes)

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == ability_name:
			return ab
	return null

static func _get_random_valid_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and _can_target(ability, h):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null

static func _any_alive_hero(heroes: Array) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0:
			return h
	return null

static func _can_target(ability: AbilityResource, hero: Combatant) -> bool:
	return Combatant.can_be_targeted_at(hero, ability)

static func _fallback(monster: Combatant, heroes: Array) -> Dictionary:
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		if ab.target_type == "All_Enemies":
			var t = _any_alive_hero(heroes)
			if t:
				return {"ability": ab, "target": t}
		var target = _get_random_valid_target(heroes, ab)
		if target:
			return {"ability": ab, "target": target}
	return {}
