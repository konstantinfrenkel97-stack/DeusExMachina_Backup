extends Resource
class_name MissionOutcome

## Итог выбора в миссии — что происходит при разрешении варианта.
## Может: показать текст, перейти к другой сцене, запустить бой, выдать награды.

# Текст-итог (показывается игроку после разрешения выбора).
@export_multiline var result_text: String = ""
@export_group("Localization")
@export var result_text_key: String = ""
@export_group("")
# Перейти к другому диалогу (null = завершить сцену/вернуться к списку миссии).
@export var next_scene: MissionSceneResource
# Запустить бой (null = без боя).
@export var battle: BattleConfig
# Награды: Array[Reward].
@export var rewards: Array[Reward] = []

@export_group("Mission Effects")
# Одноразовое лечение всего отряда в следующем бою, в процентах от максимального HP.
@export var hero_heal_percent: int = 0
# Одноразовое изменение фантазии игрока в следующем бою.
@export var fantasy_delta: int = 0
# Одноразовое изменение величия всех живых богов в следующем бою.
@export var hero_majesty_delta: int = 0
# Постоянные до конца миссии баффы на героя с наибольшей атакой.
@export var strongest_hero_buffs: Array[BuffEntry] = []
# Баффы на весь отряд героев. По умолчанию — одноразово, в следующем бою.
# Если hero_buffs_until_mission_end = true — держатся до конца миссии и применяются в каждом бою.
@export var hero_buffs: Array[BuffEntry] = []
@export var hero_buffs_until_mission_end: bool = false
# Одноразовые эффекты на конкретного бога в следующем бою.
@export var target_god: CharacterResource
@export var target_current_hp_percent_delta: int = 0
@export var target_majesty_delta: int = 0
# Баффы на target_god. По умолчанию — одноразово, в следующем бою.
# Если target_buffs_until_mission_end = true — держатся до конца миссии и применяются в каждом бою,
# пока target_god жив (hp/majesty delta выше всегда применяются один раз, в следующем бою).
@export var target_buffs: Array[BuffEntry] = []
@export var target_buffs_until_mission_end: bool = false
# Если true, следующий первый ход Хельхейма пройдет без тумана.
@export var skip_helheim_fog_first_round: bool = false
# Одноразовая скидка сложности для СЛЕДУЮЩЕЙ проверки характеристики в миссии (напр. "жульничество").
@export var next_check_difficulty_delta: int = 0
# Если true — миссия немедленно считается проваленной (без боя и наград), игрок
# возвращается на экран кампании. Для сценариев мгновенного поражения ("вас удалили с арены").
@export var end_mission_as_failure: bool = false
@export_group("")
