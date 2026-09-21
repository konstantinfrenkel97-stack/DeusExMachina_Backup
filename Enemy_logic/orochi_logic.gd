extends RefCounted
class_name OrochiLogic

## Яматано Орочи (немезис Островов). ИИ в описании не задан, поэтому — случайная доступная
## способность (как у Кракена), но ульта «Нескончаемый рост» берётся в выбор только когда
## общий пул щитов смерти неполный: иначе она ничего бы не дала.

const MAX_SHIELDS_META := "orochi_shields"
const MAX_SHIELDS := 8


static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var pool: Array = []
	for ab in monster.active_abilities:
		if ab != null:
			pool.append(ab)
	var ultimate: AbilityResource = monster.ultimate_ability
	var shields: int = int(monster.get_meta(MAX_SHIELDS_META, MAX_SHIELDS))
	if ultimate != null and monster.current_majesty >= ultimate.majesty_cost and shields < MAX_SHIELDS:
		pool.append(ultimate)
	pool.shuffle()
	for ab in pool:
		var decision: Dictionary = NemesisRandomLogic.decision_for(monster, heroes, ab)
		if not decision.is_empty():
			return decision
	return {}
