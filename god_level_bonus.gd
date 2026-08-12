extends Resource
class_name GodLevelBonus

@export_range(1, 6, 1) var level: int = 1
@export var max_hp: int = 0
@export var damage: int = 0
@export var armor: int = 0
@export var initiative: int = 0
@export var accuracy: int = 0
@export var evasion: int = 0
@export var crit_chance_percent: float = 0.0

func to_stat_dictionary() -> Dictionary:
	return {
		"max_hp": max_hp,
		"damage": damage,
		"armor": armor,
		"initiative": initiative,
		"accuracy": accuracy,
		"evasion": evasion,
		"crit_chance": crit_chance_percent / 100.0,
	}