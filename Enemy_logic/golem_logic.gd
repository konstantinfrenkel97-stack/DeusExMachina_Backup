extends RefCounted
class_name GolemLogic

## ИИ Голема: случайный выбор способности.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	return ArenaRandomLogic.get_decision(monster, heroes)
