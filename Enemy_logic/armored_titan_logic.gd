extends RefCounted
class_name ArmoredTitanLogic

const INDESTRUCTIBLE_NAME = "несокрушимый"

## Бронированный титан: 70% Несокрушимый если нет баффа на броню.
## Иначе случайная способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var indestructible = _find_indestructible(monster)
	var has_armor_buff = _has_armor_buff(monster)

	# Нет баффа брони и Несокрушимый доступен — 70% шанс
	if not has_armor_buff and indestructible != null:
		if indestructible.usable_from_positions.size() > monster.position_index:
			if indestructible.usable_from_positions[monster.position_index]:
				if randf() < 0.70:
					return {"ability": indestructible, "target": monster}

	# Иначе случайная доступная способность
	var usable = _get_usable_abilities(monster)
	usable.shuffle()
	for ability in usable:
		var target = _get_random_target(heroes, ability)
		if target:
			return {"ability": ability, "target": target}

	return {}

static func _find_indestructible(monster: Combatant) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == INDESTRUCTIBLE_NAME:
			return ab
	return null

static func _has_armor_buff(unit: Combatant) -> bool:
	for eff in unit.active_effects:
		var stat = Combatant._effect_get(eff, "stat", "")
		if stat == "armor" and Combatant._effect_get(eff, "value", 0) > 0:
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
