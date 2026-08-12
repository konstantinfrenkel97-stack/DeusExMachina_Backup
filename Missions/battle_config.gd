extends Resource
class_name BattleConfig

## Настройка боя, запускаемого из миссии: построение + модификаторы + локация.

# Построение врагов (4 позиции).
@export var formation: FormationResource
# Модификаторы на врагов (по позициям).
@export var enemy_modifiers: Array[UnitModifier] = []   # Array[UnitModifier]
# Модификаторы на героев.
@export var hero_modifiers: Array[UnitModifier] = []    # Array[UnitModifier]
# Локация боя (id из battle_setup: "helheim", "hell", ...). Пусто = локация миссии.
@export var location_id: String = ""
