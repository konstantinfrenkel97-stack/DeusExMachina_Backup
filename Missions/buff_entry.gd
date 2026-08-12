extends Resource
class_name BuffEntry

## Бафф/дебафф юнита в бою миссии (напр. −20 урона до конца боя, +20 удачи на 1 ход).

enum Stat { DAMAGE, LUCK, ACCURACY, EVASION, ARMOR, CRIT, INITIATIVE, STUN, REGENERATION }

@export var stat: Stat = Stat.DAMAGE
@export var value: int = 0            # напр. -20 урон, +20 удача
@export var duration: int = -1        # -1 = до конца боя, 1 = 1 ход
