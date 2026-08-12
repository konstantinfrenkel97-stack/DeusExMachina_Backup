extends RefCounted
class_name IndigoLogic

## Индиго: в туман всегда Охота, без тумана — любая доступная способность.

const HUNT = "охота"

static func get_decision(monster: Combatant, heroes: Array, is_fog: bool) -> Dictionary:
	# В туманный раунд: всегда Охота
	if is_fog:
		var hunt = _find_ability(monster, HUNT)
		if hunt:
			var target = _get_random_valid_target(heroes, hunt)
			if target:
				return {"ability": hunt, "target": target}
	
	# Без тумана: случайная доступная способность
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
	
	if usable.is_empty():
		return {}
	
	var ability: AbilityResource = usable[randi() % usable.size()]
	
	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}
	
	var target = _get_random_valid_target(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
	
	return {}

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

static func _can_target(ability: AbilityResource, hero: Combatant) -> bool:
	return Combatant.can_be_targeted_at(hero, ability)
