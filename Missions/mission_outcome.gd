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
# Перезапустить ТЕКУЩУЮ сцену заново (для циклов вроде "отдохнуть ещё немного").
# Godot не поддерживает self-reference .tres через ext_resource, поэтому цикл на ту
# же сцену выражается этим флагом, а не next_scene. Если true — next_scene/battle
# игнорируются.
@export var restart_current_scene: bool = false
# Запустить бой (null = без боя).
@export var battle: BattleConfig
# Награды: Array[Reward].
@export var rewards: Array[Reward] = []

@export_group("Mission Effects")
# Если не пусто — при разрешении этого итога выставляется флаг миссии (см.
# MissionState.mission_flags / MissionChoice.flag_outcomes). Флаги сбрасываются
# при старте и при завершении миссии, другие миссии их не видят.
@export var set_mission_flag: String = ""
# Одноразовое лечение всего отряда в следующем бою, в процентах от максимального HP.
@export var hero_heal_percent: int = 0
# Одноразовое изменение уровня забвения всего отряда миссии (см. CharacterResource.forgetting_level),
# применяется немедленно (не привязано к следующему бою). Положительное значение — усиливает забвение.
@export var hero_forgetting_delta: float = 0.0
# В следующем бою заклинание «Ром» (Spells/rum.tres) бьёт не только выбранную цель,
# но и всю её команду (союзников или врагов — смотря кого выбрал игрок при касте).
@export var rum_spell_whole_team_next_battle: bool = false
# Баффы одному случайному живому богу отряда миссии, до конца миссии (в каждом бою).
# Если target_random_hero_preferred_god задан и он есть в отряде — выбирается именно он
# вместо случайного бога.
@export var target_random_hero_buffs: Array[BuffEntry] = []
@export var target_random_hero_preferred_god: CharacterResource
# Одноразовое изменение HP одного случайного живого бога в миссии, в процентах от max HP.
@export var random_hero_hp_percent_delta: int = 0
# Одноразовое немедленное изменение HP ВСЕХ живых богов миссии, в процентах от max HP
# (не привязано к следующему бою, в отличие от hero_heal_percent). Отрицательное — урон.
@export var hero_hp_percent_delta: int = 0
# Одноразовое изменение фантазии игрока в следующем бою.
@export var fantasy_delta: int = 0
# Немедленное изменение мыслей игрока в кампании. Отрицательное значение = цена выбора.
@export var thoughts_delta: int = 0
# Постоянное изменение максимума фантазии на всю кампанию.
@export var max_fantasy_bonus_delta: int = 0
# Одноразовое изменение величия всех живых богов в следующем бою.
@export var hero_majesty_delta: int = 0
# Постоянные до конца миссии баффы на героя с наибольшей атакой.
@export var strongest_hero_buffs: Array[BuffEntry] = []
# Баффы на весь отряд героев. По умолчанию — одноразово, в следующем бою.
# Если hero_buffs_until_mission_end = true — держатся до конца миссии и применяются в каждом бою.
@export var hero_buffs: Array[BuffEntry] = []
@export var hero_buffs_until_mission_end: bool = false
# Баффы/дебаффы на всех врагов в следующем бою (одноразово).
@export var enemy_buffs: Array[BuffEntry] = []
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
# ─── Счётчик отдыха (для циклов вроде "Отдохнуть ещё немного") ──────────────────
# Прибавляется к MissionState.rest_counter при разрешении этого итога.
@export var rest_counter_delta: int = 0
# Явно обнуляет MissionState.rest_counter (напр. при выборе "Пора двигаться").
@export var rest_counter_reset: bool = false
# Если > 0 и счётчик (после rest_counter_delta) достиг/превысил порог — миссия
# немедленно проваливается вместо обычного result_text/next_scene/restart, и (если
# указан) на экране кампании после возврата один раз проигрывается диалог
# rest_counter_fail_dialogue_path.
@export var rest_counter_fail_threshold: int = 0
@export var rest_counter_fail_dialogue_path: String = ""
# Если true — герои получают в СЛЕДУЮЩЕМ бою дебафф инициативы, равный текущему
# значению счётчика отдыха (на 1 бой), после чего счётчик обнуляется.
@export var apply_rest_counter_initiative_penalty: bool = false

# Постоянный (на весь остаток игры, все локации) дебафф точности всем врагам с этим
# unit_name — напр. "Кобольд" получает -3 точности навсегда после этого исхода.
@export var permanent_enemy_debuff_unit_name: String = ""
@export var permanent_enemy_debuff_accuracy: int = 0

# Немедленные (не ждут следующего боя, в отличие от target_god/target_current_hp_percent_delta
# /target_majesty_delta выше) HP/величие ОДНОМУ конкретному богу — для итогов без боя
# (напр. "Тора придавило камнями, -50% здоровья", без последующей битвы в этой же сцене).
@export var target_god_immediate: CharacterResource
@export var target_god_immediate_hp_percent_delta: int = 0
@export var target_god_immediate_majesty_delta: int = 0

# Немезис: отложенный бафф конкретному богу на бой с ближайшим непобеждённым
# немезидом локации nemesis_buff_location_id (см. CampaignState.pending_nemesis_buffs;
# location_id — как в CombatManager.selected_location_id / battle_setup.gd::LOCATIONS,
# например "clouds"). Ждёт, сколько потребуется — необязательно следующий бой в этой
# же сцене, и переживает сохранение. Можно задать величие (nemesis_buff_majesty) и/или
# произвольный бафф характеристики (nemesis_buff_stat) — независимо друг от друга.
@export var nemesis_buff_god: CharacterResource
@export var nemesis_buff_majesty: int = 0
@export var nemesis_buff_stat: BuffEntry
@export var nemesis_buff_location_id: String = ""
@export_group("")
