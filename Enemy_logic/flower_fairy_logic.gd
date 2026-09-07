extends RefCounted
class_name FlowerFairyLogic

## Фея лепестков: 30% шанс применить «Неудержимое цветение», если доступно. Иначе другой навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var bloom: AbilityResource = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			if ab.name == "Неудержимое цветение":
				bloom = ab
	if usable.is_empty():
		return {}
	# 30% — Неудержимое цветение (если доступно с текущей позиции)
	if bloom and randf() < 0.3:
		return {"ability": bloom, "target": monster}
	# Иначе случайный доступный навык, кроме цветения
	var others = usable.duplicate()
	others.erase(bloom)
	if others.is_empty():
		var picked = usable.pick_random()
		if picked.target_type == "Self" or picked.target_type == "All_Enemies":
			return {"ability": picked, "target": monster}
		return {"ability": picked, "target": _first_valid_hero(heroes, picked)}
	var ability: AbilityResource = others.pick_random()
	if ability.target_type == "Self" or ability.target_type == "All_Enemies":
		return {"ability": ability, "target": monster}
	var target = _first_valid_hero(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
	return {}


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
