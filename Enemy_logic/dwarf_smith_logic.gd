extends RefCounted
class_name DwarfSmithLogic

## ИИ Гнома-кузнеца: случайный выбор способности.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	return ArenaRandomLogic.get_decision(monster, heroes)
