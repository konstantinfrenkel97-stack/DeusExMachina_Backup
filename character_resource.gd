extends Resource
class_name CharacterResource

@export var unit_name: String
@export_group("Localization")
@export var unit_name_key: String = ""
@export_group("")
@export var sprite_path: String # Сюда будем вписывать путь к файлу картинки, например "res://assets/cyclops.png"
@export var face_sprite: String # Путь к спрайту лица персонажа, например "res://Gods/Thor/Thor_Face.png"
@export_range(10.0, 400.0, 1.0, "or_greater") var battle_sprite_scale_percent: float = 100.0 # Индивидуальный масштаб спрайта на поле боя: 100 = стандартный размер.
@export_range(-100.0, 100.0, 1.0) var battle_sprite_y_offset_percent: float = 0.0 # Positive values move the battle sprite upward.
@export var campaign_dialogue_path: String = "" # Путь к диалогу бога в кампании.

@export_group("Levels")
@export_range(1, 6, 1) var god_level: int = 1
@export var level_bonuses: Array[Resource] = []
@export var upgrade_essence_paths: Array[String] = []
@export_group("")
@export var max_hp: int = 100
# ... остальные поля (damage, armor, и т.д.)

@export var damage: int = 20
@export var armor: int = 5
@export var initiative: int = 3
@export var accuracy: int = 90
@export var evasion: int = 10
@export var crit_chance: float = 0.05
@export var is_enemy: bool = true

@export_group("Забвение (усталость)")
## Текущий уровень забвения (0.0 – 5.0).
## Растёт на 0.5 за каждую миссию в кампании.
## Каждый целый уровень снижает все статы на 10%.
## При достижении 5.0 бог умирает (is_dead = true).
@export var forgetting_level: float = 0.0
## True — бог погиб от забвения. Данные сохранены, требует воскрешения.
@export var is_dead: bool = false

# Код особого эффекта юнита. Доступные значения:
# "thor_berserk"               — урон и броня растут при потере HP
# "zeus_position_bonus"        — множитель урона зависит от позиции цели
# "cyclops_sensitive_accuracy" — вдвойне чувствителен к изменениям точности
# "osiris_majesty_aura"        — в начале боя все союзники получают +15 величия
# "susanoo_hit_crit"           — каждое попадание даёт +5% к удаче навсегда
# "loki_crit_stun"             — каждый крит накладывает стан на цель (1 ход)
# "draugr_raider"              — при получении удара +5% к удаче
# "draugr_juggernaut"          — при получении удара +5 брони
# "draugr_berserker"           — при получении удара +5 атаки
# "kappa_warrior"              — юнит позади получает +10 брони (пересчитывается при движении)
# "kappa_shaman"               — юнит впереди получает +10 брони (пересчитывается при движении)
# "odin_buff_duration"         — все баффы на союзниках длятся на 1 раунд дольше
# "poseidon_buff_heal"         — в начале хода восстанавливает 5% HP за каждый уникальный бафф
# "shiva_random_luck"          — в начале раунда удача принимает случайное значение 0–30%
# "set_kill_majesty"           — получает 15 величия за каждое убийство противника
# "banshee_death_debuff"       — при смерти все герои получают -20 к урону на 1 ход
# "jotun_fog"                  — пока жив, шанс туманного раунда удваивается (30%→60%)
# "indigo_fog_evasion"         — в туманный раунд получает +25 уклонения
@export var special_effect_type: String = ""

# Если true — юнит занимает 2 позиции. Ограничивает макс. число юнитов в команде.
# Иммунен к отталкиванию/притягиванию. Марки на обеих позициях действуют одновременно.
@export var is_large: bool = false

@export_group("Equipment")
# Снаряжение бога: 3 слота — по одному на каждый тип предмета.
@export var equipped_weapon: ItemResource
@export var equipped_armor: ItemResource
@export var equipped_trinket: ItemResource

@export_group("Abilities")
@export var active_abilities: Array[AbilityResource] = []
@export var ultimate_ability: AbilityResource
	
@export var ai_script: GDScript # Сюда ты перетащишь файл с логикой в инспекторе


func get_display_name() -> String:
	return Localization.t(unit_name_key, unit_name)

func get_clamped_level() -> int:
	return clampi(god_level, 1, 6)

func get_total_level_bonus() -> Dictionary:
	var total := {
		"max_hp": 0,
		"damage": 0,
		"armor": 0,
		"initiative": 0,
		"accuracy": 0,
		"evasion": 0,
		"crit_chance": 0.0,
	}
	var current_level := get_clamped_level()
	for bonus in level_bonuses:
		if bonus == null or bonus.level > current_level:
			continue
		var stats: Dictionary = bonus.to_stat_dictionary()
		for stat_name in total.keys():
			total[stat_name] += stats.get(stat_name, 0)
	return total
# ============================================================
#  Забвение (усталость)
# ============================================================

## Возвращает множитель статов от забвения.
## 1.0 = без штрафа, 0.9 = −10%, 0.8 = −20% и т.д.
## Штраф считается по целым уровням: 1.5 забвения → 1 уровень → −10%.
func get_forgetting_multiplier() -> float:
	return 1.0 - floori(forgetting_level) * 0.1

## Возвращает количество целых уровней забвения (0–5).
func get_forgetting_levels() -> int:
	return floori(forgetting_level)

## Добавляет усталость. При достижении 5 уровней бог умирает.
func add_forgetting(amount: float) -> void:
	forgetting_level = clampf(forgetting_level + amount, 0.0, 5.0)
	if forgetting_level >= 5.0:
		is_dead = true
