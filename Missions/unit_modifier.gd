extends Resource
class_name UnitModifier

## Модификатор юнита в предстоящем бою миссии.
## Применяется к конкретной позиции построения (или ко всем) до начала боя.

# 0 = все юниты на стороне; 1..4 = конкретная позиция построения.
@export var target_position: int = 0
# 0 = не менять; 80 = установить текущее HP в 80% от максимума.
@export_range(0, 100) var hp_percent: int = 0
# -1 = не менять; 7 = установить 7 «зарядов пассивки».
@export var passive_charges: int = -1
# Array[BuffEntry] — баффы/дебаффы.
@export var buffs: Array[BuffEntry] = []
