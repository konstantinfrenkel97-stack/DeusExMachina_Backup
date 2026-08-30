extends RefCounted
class_name SpellUpgradeData

## Данные по уровням улучшения заклинаний ("Осмыслять сюжет", 2 уровня).
## Уровень 0 — базовое заклинание (значения берутся прямо из SpellResource).
## Уровни 1/2 — полная замена стоимости/эффекта (не просто скидка).
## Стоимость улучшения в мыслях/эссенции — общая для всех, см. CampaignState
## (SPELL_UPGRADE_LEVEL_1_COST / SPELL_UPGRADE_LEVEL_2_COST).

const LEVELS := {
	"res://Spells/accelerate.tres": {
		1: {"fantasy_cost": 3, "effect_types": ["pull_forward"], "effect_values": {"pull_forward": 1}, "effect_durations": {}, "description": "Передвинуть союзника на 1 позицию вперёд"},
		2: {"fantasy_cost": 0, "effect_types": ["pull_forward", "target_buff_accuracy"], "effect_values": {"pull_forward": 1, "target_buff_accuracy": 10}, "effect_durations": {"target_buff_accuracy": 1}, "description": "Передвинуть союзника на 1 позицию вперёд, дать +10 точности на 1 ход"},
	},
	"res://Spells/decelerate.tres": {
		1: {"fantasy_cost": 3, "effect_types": ["push_back"], "effect_values": {"push_back": 1}, "effect_durations": {}, "description": "Передвинуть союзника на 1 позицию назад"},
		2: {"fantasy_cost": 0, "effect_types": ["push_back", "target_buff_evasion"], "effect_values": {"push_back": 1, "target_buff_evasion": 10}, "effect_durations": {"target_buff_evasion": 1}, "description": "Передвинуть союзника на 1 позицию назад, дать +10 уклонения на 1 ход"},
	},
	"res://Spells/lucky.tres": {
		1: {"fantasy_cost": 12, "effect_types": ["target_buff_crit", "target_buff_accuracy"], "effect_values": {"target_buff_crit": 12, "target_buff_accuracy": 12}, "effect_durations": {"target_buff_crit": 1, "target_buff_accuracy": 1}, "description": "Даёт +12 удачи и +12 точности на 1 ход"},
		2: {"fantasy_cost": 10, "effect_types": ["target_buff_crit", "target_buff_accuracy"], "effect_values": {"target_buff_crit": 15, "target_buff_accuracy": 15}, "effect_durations": {"target_buff_crit": 2, "target_buff_accuracy": 2}, "description": "Даёт +15 удачи и +15 точности на 2 хода"},
	},
	"res://Spells/tear_page.tres": {
		1: {"fantasy_cost": 8, "flat_damage": 20, "refund_on_kill": false, "description": "Наносит 20 чистого урона"},
		2: {"fantasy_cost": 7, "flat_damage": 25, "refund_on_kill": true, "description": "Наносит 25 чистого урона. Если враг погибает — можно применить ещё одно заклинание в этот ход"},
	},
	"res://Spells/hate_the_character.tres": {
		1: {"fantasy_cost": 18, "effect_types": ["target_debuff_armor", "target_debuff_evasion"], "effect_values": {"target_debuff_armor": 17, "target_debuff_evasion": 17}, "effect_durations": {"target_debuff_armor": 1, "target_debuff_evasion": 1}, "description": "Выбранный противник теряет 17 брони и 17 уклонения на 1 ход"},
		2: {"fantasy_cost": 15, "effect_types": ["target_debuff_armor", "target_debuff_evasion"], "effect_values": {"target_debuff_armor": 20, "target_debuff_evasion": 20}, "effect_durations": {"target_debuff_armor": 2, "target_debuff_evasion": 2}, "description": "Выбранный противник теряет 20 брони и 20 уклонения на 2 хода"},
	},
	"res://Spells/criticize.tres": {
		1: {"fantasy_cost": 27, "effect_types": ["periodic_damage_percent"], "effect_values": {"periodic_damage_percent": 7}, "effect_durations": {"periodic_damage_percent": 2}, "description": "Все враги получают периодический урон 7% от макс. здоровья на 2 хода"},
		2: {"fantasy_cost": 27, "effect_types": ["periodic_damage_percent"], "effect_values": {"periodic_damage_percent": 8}, "effect_durations": {"periodic_damage_percent": 3}, "description": "Все враги получают периодический урон 8% от макс. здоровья на 3 хода"},
	},
	"res://Spells/plot_armor.tres": {
		1: {"fantasy_cost": 18, "effect_types": ["target_buff_armor", "target_heal_percent"], "effect_values": {"target_buff_armor": 17, "target_heal_percent": 17}, "effect_durations": {"target_buff_armor": 1}, "description": "Выбранный союзник получает 17 брони на 1 ход и восстанавливает 17% здоровья"},
		2: {"fantasy_cost": 15, "effect_types": ["target_buff_armor", "target_heal_percent"], "effect_values": {"target_buff_armor": 20, "target_heal_percent": 25}, "effect_durations": {"target_buff_armor": 1}, "description": "Выбранный союзник получает 20 брони на 1 ход и восстанавливает 25% здоровья"},
	},
	"res://Spells/reread.tres": {
		1: {"fantasy_cost": 45, "effect_types": ["restart_battle"], "effect_values": {"restart_battle": 1}, "effect_durations": {"restart_battle": 1}, "description": "Начинает битву заново в тех же условиях, в которых она начиналась"},
		2: {"fantasy_cost": 40, "effect_types": ["restart_battle"], "effect_values": {"restart_battle": 1}, "effect_durations": {"restart_battle": 1}, "description": "Начинает битву заново в тех же условиях, в которых она начиналась"},
	},
}


## Полные данные для применения эффекта заклинания на уровне level (1 или 2). {} если нет данных.
static func get_level_data(spell_path: String, level: int) -> Dictionary:
	var by_level: Dictionary = LEVELS.get(spell_path, {})
	return by_level.get(level, {})


## {"cost": int, "description": String} для отображения в UI (уровень 0 — базовое заклинание).
static func get_display(spell: SpellResource, level: int) -> Dictionary:
	if level <= 0:
		return {"cost": spell.fantasy_cost, "description": spell.description}
	var data := get_level_data(spell.resource_path, level)
	if data.is_empty():
		return {"cost": spell.fantasy_cost, "description": spell.description}
	return {"cost": int(data.get("fantasy_cost", spell.fantasy_cost)), "description": str(data.get("description", spell.description))}


## Есть ли для этого заклинания данные апгрейда вообще (не все заклинания улучшаемы, напр. «Ром»).
static func has_upgrades(spell_path: String) -> bool:
	return LEVELS.has(spell_path)
