extends RefCounted
class_name DwarfSmithLogic

## ИИ Гнома-кузнеца: случайный выбор способности (включая «Улучшить снаряжение» на союзника).

static func get_decision(monster: Combatant, heroes: Array, allies: Array = []) -> Dictionary:
	return ArenaRandomLogic.get_decision(monster, heroes, allies)
