extends RefCounted
class_name KoboldLogic

## ИИ Кобольда: случайный выбор способности (включая «Прокопать тоннель» на союзников).

static func get_decision(monster: Combatant, heroes: Array, allies: Array = []) -> Dictionary:
	return ArenaRandomLogic.get_decision(monster, heroes, allies)
