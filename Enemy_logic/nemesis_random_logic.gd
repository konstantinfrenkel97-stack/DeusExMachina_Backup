extends RefCounted
class_name NemesisRandomLogic

## «Использует доступную способность» (Кракен и щупальца кракена): случайная из способностей,
## доступных с текущей позиции и имеющих цель; ульта входит в выбор, когда хватает величия.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var pool: Array = []
	for ab in monster.active_abilities:
		if ab != null:
			pool.append(ab)
	var ultimate: AbilityResource = monster.ultimate_ability
	if ultimate != null and monster.current_majesty >= ultimate.majesty_cost:
		pool.append(ultimate)
	pool.shuffle()
	for ab in pool:
		var decision: Dictionary = decision_for(monster, heroes, ab)
		if not decision.is_empty():
			return decision
	return {}


## {"ability", "target"} для способности, если её можно применить с текущей позиции и есть цель.
static func decision_for(monster: Combatant, heroes: Array, ability: AbilityResource) -> Dictionary:
	if ability == null or not monster.can_use_ability_from_position(ability):
		return {}
	if ability.target_type == "Self" or ability.target_type == "All_Enemies":
		return {"ability": ability, "target": monster}
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	if valid.is_empty():
		return {}
	return {"ability": ability, "target": valid.pick_random()}
