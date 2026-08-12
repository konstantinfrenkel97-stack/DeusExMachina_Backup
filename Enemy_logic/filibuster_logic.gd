extends RefCounted
class_name FilibusterLogic

## Флибустьер: если нет баффа на удачу → «Морской кураж».
## Если есть бафф на удачу → «Я знаю что делаю».
## Иначе → другой доступный навык.

const SEA_FERVOR_NAME = "Морской кураж"
const I_KNOW_NAME = "Я знаю что делаю"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var has_luck_buff = _has_crit_buff(monster)
	
	# 1. Нет баффа на удачу → Морской кураж
	if not has_luck_buff:
		var fervor = _find_ability(monster, SEA_FERVOR_NAME)
		if fervor and _is_usable(monster, fervor):
			var target = _get_random_target(heroes, fervor)
			if target:
				return {"ability": fervor, "target": target}
	
	# 2. Есть бафф на удачу → Я знаю что делаю
	if has_luck_buff:
		var iknow = _find_ability(monster, I_KNOW_NAME)
		if iknow and _is_usable(monster, iknow):
			# Стойка — цель на себя (не используется для атаки)
			return {"ability": iknow, "target": monster}
	
	# 3. Другой доступный навык
	var usable = _get_usable_except(monster, [SEA_FERVOR_NAME, I_KNOW_NAME])
	if not usable.is_empty():
		for ab in usable:
			var t = _get_random_target(heroes, ab)
			if t:
				return {"ability": ab, "target": t}
	
	# 4. Резерв — любой доступный
	var all_usable = _get_usable_abilities(monster)
	for ab in all_usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		var t = _get_random_target(heroes, ab)
		if t:
			return {"ability": ab, "target": t}
	
	return {}

static func _has_crit_buff(unit: Combatant) -> bool:
	for eff in unit.active_effects:
		var stat = Combatant._effect_get(eff, "stat", "")
		var val = Combatant._effect_get(eff, "value", 0)
		if stat == "crit" and val > 0:
			return true
	return false

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name == ability_name:
			return ab
	return null

static func _is_usable(monster: Combatant, ability: AbilityResource) -> bool:
	if ability.usable_from_positions.size() > monster.position_index:
		return ability.usable_from_positions[monster.position_index]
	return false

static func _get_usable_abilities(monster: Combatant) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab and _is_usable(monster, ab):
			abilities.append(ab)
	return abilities

static func _get_usable_except(monster: Combatant, excluded_names: Array) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab and _is_usable(monster, ab) and not ab.name in excluded_names:
			abilities.append(ab)
	return abilities

static func _get_random_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
