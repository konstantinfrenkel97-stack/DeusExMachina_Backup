extends RefCounted
class_name CannonLogic

## Пушка: всегда стреляет в строгом порядке — Заряжай → Цельсь → Пли → повтор.
## Использует meta-счётчик (надёжнее, чем active_effects, которые истекают).

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var step = int(monster.get_meta("cannon_step", 0))
	
	var charge = _find_ability(monster, "Заряжай")
	var aim = _find_ability(monster, "Цельсь")
	var fire = _find_ability(monster, "Пли")
	
	match step:
		0:
			# Заряжай
			if charge:
				monster.set_meta("cannon_step", 1)
				return {"ability": charge, "target": monster}
		1:
			# Цельсь
			if aim:
				monster.set_meta("cannon_step", 2)
				return {"ability": aim, "target": monster}
		2:
			# Пли
			if fire:
				monster.set_meta("cannon_step", 0)
				var target = _get_target_for_ability(monster, heroes, fire)
				if target:
					return {"ability": fire, "target": target}
				# Нет цели — всё равно сбрасываем цикл
				monster.set_meta("cannon_step", 0)
	
	# Fallback: если способность не найдена, пробуем любую доступную
	var usable = _get_usable_abilities(monster)
	if not usable.is_empty():
		var ab = usable[0]
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		var t = _get_target_for_ability(monster, heroes, ab)
		if t:
			return {"ability": ab, "target": t}
	
	return {}

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name == ability_name:
			return ab
	return null

static func _get_usable_abilities(monster: Combatant) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			abilities.append(ab)
	return abilities

static func _get_target_for_ability(monster: Combatant, heroes: Array, ab: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
			return h
	return null
