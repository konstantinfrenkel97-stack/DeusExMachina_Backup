extends RefCounted
class_name SeaWitchLogic

## Морская ведьма:
## - Бурные потоки (is_raging=true) → «Водоворот».
## - Иначе если ни на ком из врагов не висит «Глубоководное проклятие» → применить его.
## - Иначе «Мрачная сделка» по врагу с макс. Величием.

static func get_decision_depths(monster: Combatant, heroes: Array, is_raging: bool) -> Dictionary:
	var whirlpool_ab := _find_by_name(monster, "Водоворот")
	var curse_ab := _find_by_name(monster, "Глубоководное проклятие")
	var deal_ab := _find_by_name(monster, "Мрачная сделка")

	# 1. Бурные потоки → Водоворот (All_Enemies; цель-маркер — первый враг).
	if is_raging and whirlpool_ab != null and _is_usable_from_position(whirlpool_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0:
				return {"ability": whirlpool_ab, "target": h}

	# 2. Если ни у кого из врагов нет проклятия → Глубоководное проклятие.
	if curse_ab != null and _is_usable_from_position(curse_ab, monster.position_index):
		if not _any_hero_has_curse(heroes):
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, curse_ab):
					return {"ability": curse_ab, "target": h}

	# 3. Мрачная сделка по врагу с макс. Величием.
	if deal_ab != null and _is_usable_from_position(deal_ab, monster.position_index):
		var best: Combatant = null
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, deal_ab):
				if best == null or h.current_majesty > best.current_majesty:
					best = h
		if best != null:
			return {"ability": deal_ab, "target": best}

	# Fallback: любая доступная способность.
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}


static func _any_hero_has_curse(heroes: Array) -> bool:
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		for e in h.active_effects:
			if Combatant._effect_get(e, "stat", "") == "periodic_damage" \
					and Combatant._effect_get(e, "source_ability", "") == "Глубоководное проклятие":
				return true
	return false


static func _find_by_name(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
