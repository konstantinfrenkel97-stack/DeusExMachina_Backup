extends RefCounted
class_name SirenLogic

## Сирена: если на враге 3+ разных дебаффа → «На дно».
## Иначе 70% «Ласковый зов», 30% «Нежная песня».

const GENTLE_CALL_NAME = "Ласковый зов"
const TENDER_SONG_NAME = "Нежная песня"
const TO_THE_BOTTOM_NAME = "На дно"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	# 1. Проверяем, есть ли враг с 3+ дебаффами → «На дно»
	var bottom = _find_ability(monster, TO_THE_BOTTOM_NAME)
	if bottom and _is_usable(monster, bottom):
		var best_target = _get_target_with_most_debuffs(heroes, bottom)
		if best_target and _count_debuffs(best_target) >= 3:
			return {"ability": bottom, "target": best_target}
	
	# 2. 70% «Ласковый зов», 30% «Нежная песня»
	if randf() < 0.70:
		var call = _find_ability(monster, GENTLE_CALL_NAME)
		if call and _is_usable(monster, call):
			var target = _get_random_target(heroes, call)
			if target:
				return {"ability": call, "target": target}
	
	var song = _find_ability(monster, TENDER_SONG_NAME)
	if song and _is_usable(monster, song):
		# All_Enemies — цель не важна, берём первого живого
		var any_alive = _get_any_alive(heroes)
		if any_alive:
			return {"ability": song, "target": any_alive}
	
	# Резерв — любая доступная
	var call = _find_ability(monster, GENTLE_CALL_NAME)
	if call and _is_usable(monster, call):
		var target = _get_random_target(heroes, call)
		if target:
			return {"ability": call, "target": target}
	
	return {}

static func _count_debuffs(unit: Combatant) -> int:
	var debuff_sources = {}
	for eff in unit.active_effects:
		var val = Combatant._effect_get(eff, "value", 0)
		if val < 0:
			var src = Combatant._effect_get(eff, "source_ability", "")
			var eid = Combatant._effect_get(eff, "effect_id", "")
			var key = src if src != "" else eid
			if key != "":
				debuff_sources[key] = true
			else:
				debuff_sources[Combatant._effect_get(eff, "stat", "")] = true
	return debuff_sources.size()

static func _get_target_with_most_debuffs(heroes: Array, ability: AbilityResource) -> Combatant:
	var best: Combatant = null
	var best_count: int = 0
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			var count = _count_debuffs(h)
			if count > best_count:
				best_count = count
				best = h
	return best

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name == ability_name:
			return ab
	return null

static func _is_usable(monster: Combatant, ability: AbilityResource) -> bool:
	if ability.usable_from_positions.size() > monster.position_index:
		return ability.usable_from_positions[monster.position_index]
	return false

static func _get_random_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null

static func _get_any_alive(heroes: Array) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0:
			return h
	return null
