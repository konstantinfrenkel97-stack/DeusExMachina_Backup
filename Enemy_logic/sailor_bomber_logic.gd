extends RefCounted
class_name SailorBomberLogic

## Матрос с бомбой: применяет доступный навык.
## Пассивка (sailor_bomber_low_hp) обрабатывается в battle_scene.gd:
## если HP < 20% → толкает вперёд на 2 и заставляет использовать Самоподрыв.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	# Проверяем пассивку: если HP < 20% → обязательно Самоподрыв
	if float(monster.current_hp) / float(monster.max_hp) < 0.2:
		var self_destruct = _find_ability(monster, "Самоподрыв")
		if self_destruct:
			var any_alive = _get_any_alive(heroes)
			if any_alive:
				return {"ability": self_destruct, "target": any_alive}
	
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
	
	if ability.target_type == "All_Enemies":
		var any_alive = _get_any_alive(heroes)
		if any_alive:
			return {"ability": ability, "target": any_alive}
		return {}
	
	var target = _get_random_valid_target(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
	
	return {}

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name == ability_name:
			return ab
	return null

static func _get_any_alive(heroes: Array) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0:
			return h
	return null

static func _get_random_valid_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
