extends MissionEffect
class_name EnemyBuffEffect

## Бафф/дебафф ВСЕМ врагам в ближайшем следующем бою (одноразово).
## Заменяет legacy MissionOutcome.enemy_buffs. Цель не выбирается (всегда "все враги"),
## поэтому наследуется от MissionEffect напрямую, а не от HeroTargetEffect.

@export var buffs: Array[BuffEntry] = []


func apply() -> void:
	for buff in buffs:
		if buff != null:
			CombatManager.pending_mission_enemy_buffs.append(buff)
