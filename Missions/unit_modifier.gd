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
# Если true — у юнита отключается пассивка на весь бой (special_effect_type очищается
# при спавне; см. battle_scene.gd::_apply_modifier_list).
@export var disable_passive: bool = false
# Если true — юнит с пассивкой Новичка (превращение в Гладиатора/Гоплита) сработает
# на 1 ход раньше обычного (на 2-м раунде вместо 3-го). В бою это подаётся как
# "получил(а) благословение от своего кумира". Не влияет на юнитов без этой пассивки.
@export var bless_early_transform: bool = false
