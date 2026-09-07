extends Resource
class_name BuffEntry

## Бафф/дебафф юнита в бою миссии (напр. −20 урона до конца боя, +20 удачи на 1 ход).

enum Stat { DAMAGE, LUCK, ACCURACY, EVASION, ARMOR, CRIT, INITIATIVE, STUN, REGENERATION, PERIODIC_DAMAGE }

@export var stat: Stat = Stat.DAMAGE
@export var value: int = 0            # напр. -20 урон, +20 удача
@export var duration: int = -1        # -1 = до конца боя, 1 = 1 ход
# Только для PERIODIC_DAMAGE: если true, value трактуется как % от максимального
# HP юнита (пересчитывается индивидуально для каждого юнита при старте боя),
# а не как фиксированное число урона за ход.
@export var percent_of_max_hp: bool = false
