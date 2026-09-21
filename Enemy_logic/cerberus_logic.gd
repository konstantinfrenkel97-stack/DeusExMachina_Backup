extends RefCounted
class_name CerberusLogic

## Цербер (немезис Ада).
## Пока активен эффект «Трехголовый» (в этот ход он совершает три действия), действия идут
## строго по порядку: «Укус стража» → «Трое на одного» → «Сторожевой пес» (по номеру действия
## в раунде). Если очередного шага нельзя сделать (позиция не позволяет / нет цели), берётся
## случайная доступная способность. Без эффекта — всегда случайная доступная способность
## (ульта «Трехголовый» входит в выбор, когда хватает величия и она ещё не активирована).

const THREE_HEADED_ACTIVE_META := "cerberus_three_active"
const THREE_HEADED_PENDING_META := "cerberus_three_pending"
const SEQUENCE_MARKERS: Array[String] = ["cerberus_bite_of_guard", "cerberus_three_on_one", "cerberus_watchdog"]


static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	if monster.has_meta(THREE_HEADED_ACTIVE_META):
		var step: int = clampi(monster.actions_taken_this_round, 0, SEQUENCE_MARKERS.size() - 1)
		var planned: AbilityResource = _find_by_marker(monster, SEQUENCE_MARKERS[step])
		var planned_decision: Dictionary = _decision_for(monster, heroes, planned)
		if not planned_decision.is_empty():
			return planned_decision

	var pool: Array = []
	for ab in monster.active_abilities:
		if ab != null:
			pool.append(ab)
	var ultimate: AbilityResource = monster.ultimate_ability
	if ultimate != null and monster.current_majesty >= ultimate.majesty_cost \
			and not monster.has_meta(THREE_HEADED_ACTIVE_META) and not monster.has_meta(THREE_HEADED_PENDING_META):
		pool.append(ultimate)
	pool.shuffle()
	for ab in pool:
		var decision: Dictionary = _decision_for(monster, heroes, ab)
		if not decision.is_empty():
			return decision
	return {}


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


## {"ability", "target"} для способности, если её можно применить с текущей позиции и есть цель.
static func _decision_for(monster: Combatant, heroes: Array, ability: AbilityResource) -> Dictionary:
	if ability == null:
		return {}
	if not monster.can_use_ability_from_position(ability):
		return {}
	if ability.target_type == "Self" or ability.target_type == "All_Enemies":
		return {"ability": ability, "target": monster}
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return {"ability": ability, "target": h}
	return {}
