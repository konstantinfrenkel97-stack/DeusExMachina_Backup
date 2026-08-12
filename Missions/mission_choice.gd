extends Resource
class_name MissionChoice

## Вариант ответа в сцене миссии (расширенный формат).
##
## Может быть доступен только при наличии конкретного бога (required_god),
## содержать проверку характеристики (stat_check) с разными итогами
## для успеха/провала, либо сразу вести к одному итогу (outcome).
##
## Итог (MissionOutcome) может: показать текст, перейти к другой сцене,
## запустить бой (с построением и модификаторами), выдать награды.
##
## Старые поля (formation/launch_battle/battle_setup_path/next_scene/effects)
## сохранены для обратной совместимости со старыми миссиями.

# Текст кнопки варианта ответа.
@export var choice_text: String = "Вариант"
@export_group("Localization")
@export var choice_text_key: String = ""
@export_group("")

# ── Условие доступности ──
# Если задан — выбор активен только когда этот бог есть в отряде игрока.
@export var required_god: CharacterResource

# ── Проверка характеристики (опционально) ──
# null = без проверки; тогда используется outcome.
@export var stat_check: StatCheck

# ── Итоги ──
# Применяется, если проверки НЕТ (или как итог по умолчанию).
@export var outcome: MissionOutcome
# При успехе проверки.
@export var success_outcome: MissionOutcome
# При провале проверки.
@export var failure_outcome: MissionOutcome

# ── Legacy (старые миссии) ──
@export_multiline var effects: String = ""
@export var formation: FormationResource
@export var launch_battle: bool = false
@export var battle_setup_path: String = ""
@export var next_scene: MissionSceneResource
