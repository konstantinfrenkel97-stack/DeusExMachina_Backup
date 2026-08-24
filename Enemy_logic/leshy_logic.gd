extends RefCounted
class_name LeshyLogic

## Леший: всегда атакует противников с максимумом дебаффов.
## 30% шанс применить "Ужас".
## Если нет цели с 2 стаками дебаффа локации — 70% "Ты принадлежишь лесу".
## Иначе — 70% "Ни шагу".
## Иначе атакует цель с максимумом дебаффов.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var ni_shagu: AbilityResource = null
	var ty_lesu: AbilityResource = null
	var uzhas: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
				match ab.ability_marker:
					"ty_prinadlezhish_lesu": ty_lesu = ab
					"uzhas": uzhas = ab
					_: pass
				if ab.name == "Ни шагу":
					ni_shagu = ab

	if usable.is_empty():
		return {}

	# 30% шанс применить "Ужас"
	if uzhas and randi() % 100 < 30:
		return {"ability": uzhas, "target": monster}

	# Подсчитываем дебаффы на каждом живом герое
	var best_target: Combatant = null
	var best_debuff_count: int = -1
	var has_2stack_location: bool = false
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		var debuff_count = _count_debuffs(h)
		var loc_stacks = _count_location_debuffs(h)
		if loc_stacks >= 2:
			has_2stack_location = true
		if debuff_count > best_debuff_count:
			best_debuff_count = debuff_count
			best_target = h

	# Если нет цели с 2 стаками дебаффа локации — 70% "Ты принадлежишь лесу"
	if not has_2stack_location and ty_lesu and randi() % 100 < 70:
		var target = best_target if best_target and Combatant.can_be_targeted_at(best_target, ty_lesu) else _get_random_valid_target(heroes, ty_lesu)
		if target:
			return {"ability": ty_lesu, "target": target}

	# Иначе — 70% "Ни шагу"
	if has_2stack_location and ni_shagu and randi() % 100 < 70:
		var target = best_target if best_target and Combatant.can_be_targeted_at(best_target, ni_shagu) else _get_random_valid_target(heroes, ni_shagu)
		if target:
			return {"ability": ni_shagu, "target": target}

	# По умолчанию — атака по цели с максимумом дебаффов
	# Выбираем атакующий навык (Ни шагу есть_DAMAGE, либо другой не-self)
	var attack_abilities: Array = []
	for ab in usable:
		if ab.target_type == "Enemy":
			attack_abilities.append(ab)
	if attack_abilities.is_empty():
		attack_abilities = usable.duplicate()

	var ability: AbilityResource = attack_abilities[randi() % attack_abilities.size()]
	var target = best_target if best_target and Combatant.can_be_targeted_at(best_target, ability) else _get_random_valid_target(heroes, ability)
	if target:
		return {"ability": ability, "target": target}

	return {}

## Подсчёт количества дебаффов на combatant (по active_effects)
static func _count_debuffs(c: Combatant) -> int:
	var count: int = 0
	for e in c.active_effects:
		var eid = Combatant._effect_get(e, "effect_id", "")
		if eid.begins_with("target_debuff") or eid.begins_with("all_enemies_debuff"):
			count += 1
	return count

## Подсчёт стаков дебаффа локации (Топь: "swamp_debuff") на combatant
static func _count_location_debuffs(c: Combatant) -> int:
	for e in c.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "swamp_debuff":
			return int(Combatant._effect_get(e, "stacks", 0))
	return 0

static func _get_random_valid_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
