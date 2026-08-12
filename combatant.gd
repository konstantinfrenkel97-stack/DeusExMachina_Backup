extends RefCounted
class_name Combatant

signal damage_taken(amount: int)
signal healed(amount: int)


var unit_name: String
var source_resource_path: String = ""
var sprite_path: String # <--- Ð­Ð¢Ð Ð¡Ð¢Ð ÐžÐšÐ ÐÐ£Ð–ÐÐ
var face_sprite: String # ÐŸÑƒÑ‚ÑŒ Ðº ÑÐ¿Ñ€Ð°Ð¹Ñ‚Ñƒ Ð»Ð¸Ñ†Ð° (Ð´Ð»Ñ Ð¿Ð¾Ñ€Ñ‚Ñ€ÐµÑ‚Ð¾Ð² Ð² Ð¿Ð¾Ð»Ð¾ÑÐµ Ð¾Ñ‡ÐµÑ€ÐµÐ´Ð¸ Ñ…Ð¾Ð´Ð¾Ð²)
var battle_sprite_scale_percent: float = 100.0 # Ð˜Ð½Ð´Ð¸Ð²Ð¸Ð´ÑƒÐ°Ð»ÑŒÐ½Ñ‹Ð¹ Ð¼Ð°ÑÑˆÑ‚Ð°Ð± ÑÐ¿Ñ€Ð°Ð¹Ñ‚Ð° Ð½Ð° Ð¿Ð¾Ð»Ðµ Ð±Ð¾Ñ.
var max_hp: int
var current_hp: int
var base_damage: int
var base_armor: int
var base_accuracy: int
var base_evasion: int
var base_crit_chance: float
var initiative: int
var is_enemy: bool
var active_abilities: Array[AbilityResource] = []
var ultimate_ability: AbilityResource
var original_ultimate_ability: AbilityResource
var has_usurped_ultimate: bool = false
var position_index: int = 0
var current_majesty: int = 0
var has_waited_this_round: bool = false
var has_acted_this_round: bool = false
var round_wait_stamp: int = -1
var special_effect_type: String = ""
var god_level: int = 1
var is_large: bool = false
var is_stunned: bool = false
var pending_crit: bool = false  # Ð¤Ð»Ð°Ð³: ÑÐ»ÐµÐ´ÑƒÑŽÑ‰Ð¸Ð¹ Ð¿Ð¾Ð»ÑƒÑ‡ÐµÐ½Ð½Ñ‹Ð¹ ÑƒÑ€Ð¾Ð½ â€” ÐºÑ€Ð¸Ñ‚Ð¸Ñ‡ÐµÑÐºÐ¸Ð¹ (Ð´Ð»Ñ Ð²ÑÐ¿Ð»Ñ‹Ð²Ð°ÑŽÑ‰Ð¸Ñ… Ñ‡Ð¸ÑÐµÐ»)
var active_stance: AbilityResource = null # Ð¡ÑÑ‹Ð»ÐºÐ° Ð½Ð° Ñ‚ÐµÐºÑƒÑ‰ÑƒÑŽ ÑÑ‚Ð¾Ð¹ÐºÑƒ
var ai_script: GDScript
var life_charges: int = 0  # ÐšÐ¾Ñ‰ÐµÐ¹: Ð·Ð°Ñ€ÑÐ´Ñ‹ Ð¶Ð¸Ð·Ð½Ð¸ (5 Ð¿Ð¾ ÑƒÐ¼Ð¾Ð»Ñ‡Ð°Ð½Ð¸ÑŽ)
var mission_charges: int = -1  # Â«Ð—Ð°Ñ€ÑÐ´Ñ‹ Ð¿Ð°ÑÑÐ¸Ð²ÐºÐ¸Â» Ð¸Ð· Ð¼Ð¸ÑÑÐ¸Ð¸ (-1 = Ð½Ðµ Ð·Ð°Ð´Ð°Ð½Ð¾)
var ultimate_blocked: bool = false  # Ð‘Ð»Ð¾ÐºÐ¸Ñ€Ð¾Ð²ÐºÐ° ÑƒÐ»ÑŒÑ‚Ð¸Ð¼Ð°Ñ‚Ð¸Ð²Ð½Ð¾Ð¹ ÑÐ¿Ð¾ÑÐ¾Ð±Ð½Ð¾ÑÑ‚Ð¸ (ÐœÑ€Ð°Ñ‡Ð½Ð°Ñ ÑÐ´ÐµÐ»ÐºÐ°)
var jaw_mark_target: Combatant = null  # Ð£Ð³Ð¾Ñ€ÑŒ: Ñ†ÐµÐ»ÑŒ Ð¾Ñ‚Ð»Ð¾Ð¶ÐµÐ½Ð½Ð¾Ð¹ Ð°Ñ‚Ð°ÐºÐ¸ Â«ÐœÐµÑ‚ÐºÐ° Ñ‡ÐµÐ»ÑŽÑÑ‚Ð¸Â»
var moved_this_round: bool = false  # Ð¤Ð»Ð°Ð³: ÑŽÐ½Ð¸Ñ‚ Ð¿ÐµÑ€ÐµÐ¼ÐµÑ‰Ð°Ð»ÑÑ Ð² ÑÑ‚Ð¾Ð¼ Ñ€Ð°ÑƒÐ½Ð´Ðµ (Ð£Ð³Ð¾Ñ€ÑŒ Ð¸ Ð´Ñ€.)
var griffin_first_strike_used: bool = false  # Ð“Ñ€Ð¸Ñ„Ð¾Ð½: Ð¿ÐµÑ€Ð²Ñ‹Ð¹ ÑƒÐ´Ð°Ñ€ Ð² Ñ€Ð°ÑƒÐ½Ð´Ðµ ÑƒÐ¶Ðµ ÑÑ€Ð°Ð±Ð¾Ñ‚Ð°Ð»
var killed_by: Combatant = null  # Ð—Ð°Ð¼Ð¾Ðº: ÐºÑ‚Ð¾ ÑƒÐ±Ð¸Ð» ÑÑ‚Ð¾Ð³Ð¾ ÑŽÐ½Ð¸Ñ‚Ð° (ÐŸÑ€Ð¸Ð½Ñ†ÐµÑÑÐ°, Ð¡Ñ‚Ñ€Ð°Ð¶Ð½Ð¸Ðº)
var has_killed_enemy: bool = false  # Ð—Ð°Ð¼Ð¾Ðº: ÑƒÐ±Ð¸Ð» Ð»Ð¸ Ð²Ñ€Ð°Ð³Ð° (ÑÐ¾ÑŽÐ·Ð½Ð¸ÐºÐ° Ð¡Ñ‚Ñ€Ð°Ð¶Ð½Ð¸ÐºÐ°)
var has_killed_hero: bool = false  # Ð—Ð°Ð¼Ð¾Ðº: ÑƒÐ±Ð¸Ð» Ð»Ð¸ Ð³ÐµÑ€Ð¾Ñ (ÑÐ¾ÑŽÐ·Ð½Ð¸ÐºÐ° ÐŸÑ€Ð¸Ð½Ñ†ÐµÑÑÑ‹)

var accuracy_modifier: int = 0
var damage_modifier_flat: int = 0
var damage_modifier_percent: float = 0.0
var armor_modifier: int = 0
var evasion_modifier: int = 0
var crit_modifier: float = 0.0

var accuracy: int: get = get_accuracy
var damage: int: get = get_damage
var armor: int: get = get_armor
var evasion: int: get = get_evasion
var crit_chance: float: get = get_crit
# ÐœÐ°ÑÑÐ¸Ð² ÑÐ»Ð¾Ð²Ð°Ñ€ÐµÐ¹: [{"effect": "str", "value": int, "duration": int}]
# Ð•ÑÐ»Ð¸ duration == -1, ÑÑ„Ñ„ÐµÐºÑ‚ Ð´ÐµÐ¹ÑÑ‚Ð²ÑƒÐµÑ‚ Ð´Ð¾ ÐºÐ¾Ð½Ñ†Ð° Ð±Ð¾Ñ.
var active_effects = []
var _thor_berserk_aura_bonus: int = 0

func _init(resource: CharacterResource):
	source_resource_path = resource.resource_path
	unit_name = resource.unit_name
	sprite_path = resource.sprite_path # <--- ÐŸÐ Ð˜Ð¡Ð’ÐžÐ•ÐÐ˜Ð• Ð˜Ð— Ð Ð•Ð¡Ð£Ð Ð¡Ð
	face_sprite = resource.face_sprite
	battle_sprite_scale_percent = resource.battle_sprite_scale_percent
	max_hp = resource.max_hp
	current_hp = resource.max_hp
	base_damage = resource.damage
	base_armor = resource.armor
	base_accuracy = resource.accuracy
	base_evasion = resource.evasion
	base_crit_chance = resource.crit_chance
	initiative = resource.initiative
	is_enemy = resource.is_enemy
	active_abilities = resource.active_abilities
	ultimate_ability = resource.ultimate_ability
	original_ultimate_ability = resource.ultimate_ability
	special_effect_type = resource.special_effect_type
	is_large = resource.is_large
	god_level = resource.get_clamped_level()
	_apply_level_bonuses(resource.get_total_level_bonus())
	ai_script = resource.ai_script
	if special_effect_type == "koschei_life_charges":
		life_charges = 5
	# Ð—Ð°Ð±Ð²ÐµÐ½Ð¸Ðµ: ÐºÐ°Ð¶Ð´Ñ‹Ð¹ Ñ†ÐµÐ»Ñ‹Ð¹ ÑƒÑ€Ð¾Ð²ÐµÐ½ÑŒ ÑÐ½Ð¸Ð¶Ð°ÐµÑ‚ Ð²ÑÐµ ÑÑ‚Ð°Ñ‚Ñ‹ Ð±Ð¾Ð³Ð° Ð½Ð° 10%
	if not is_enemy and resource.forgetting_level > 0.0:
		var fm: float = resource.get_forgetting_multiplier()
		max_hp = maxi(1, int(max_hp * fm))
		current_hp = max_hp
		base_damage = maxi(1, int(base_damage * fm))
		base_armor = int(base_armor * fm)
		base_accuracy = int(base_accuracy * fm)
		base_evasion = int(base_evasion * fm)
		base_crit_chance = base_crit_chance * fm
		initiative = maxi(1, int(initiative * fm))

func _apply_level_bonuses(bonuses: Dictionary) -> void:
	if bonuses.is_empty():
		return
	var hp_bonus := int(bonuses.get("max_hp", 0))
	var was_full_hp := current_hp >= max_hp
	max_hp = maxi(1, max_hp + hp_bonus)
	if was_full_hp:
		current_hp = max_hp
	else:
		current_hp = clampi(current_hp, 0, max_hp)
	base_damage += int(bonuses.get("damage", 0))
	base_armor += int(bonuses.get("armor", 0))
	initiative += int(bonuses.get("initiative", 0))
	base_accuracy += int(bonuses.get("accuracy", 0))
	base_evasion += int(bonuses.get("evasion", 0))
	base_crit_chance += float(bonuses.get("crit_chance", 0.0))
func get_accuracy() -> int: return max(0, base_accuracy + accuracy_modifier)
func get_damage() -> int:
	var bonus = 0
	# Ð—Ð²Ñ‘Ð·Ð´Ñ‹ â€” Ð¡ÐºÐ¾Ñ€Ð¿Ð¸Ð¾Ð½: +5% ÑƒÑ€Ð¾Ð½Ð° Ð·Ð° ÐºÐ°Ð¶Ð´Ñ‹Ð¹ Ð´ÐµÐ±Ð°Ñ„Ñ„ Ð½Ð° ÑÐµÐ±Ðµ
	if special_effect_type == "scorpio_debuff_damage":
		bonus += int((base_damage + damage_modifier_flat) * 0.05 * _count_active_debuffs())
	var flat_damage: int = int(base_damage) + damage_modifier_flat + bonus
	return maxi(0, int(round(float(flat_damage) * (1.0 + damage_modifier_percent / 100.0))))

## Ð¡Ñ‡Ð¸Ñ‚Ð°ÐµÑ‚ ÐºÐ¾Ð»Ð¸Ñ‡ÐµÑÑ‚Ð²Ð¾ Ð°ÐºÑ‚Ð¸Ð²Ð½Ñ‹Ñ… Ð´ÐµÐ±Ð°Ñ„Ñ„Ð¾Ð² (Ð¾Ñ‚Ñ€Ð¸Ñ†Ð°Ñ‚ÐµÐ»ÑŒÐ½Ñ‹Ðµ ÑÑ„Ñ„ÐµÐºÑ‚Ñ‹ Ð¸ Ð¿ÐµÑ€Ð¸Ð¾Ð´Ð¸Ñ‡ÐµÑÐºÐ¸Ð¹ ÑƒÑ€Ð¾Ð½).
func _count_active_debuffs() -> int:
	var n = 0
	for e in active_effects:
		var st = _effect_get(e, "stat", "")
		var v = _effect_get(e, "value", 0)
		if st == "periodic_damage":
			n += 1
		elif v < 0 and st != "stun":
			n += 1
	return n
func get_armor() -> int: 
	return base_armor + armor_modifier
func get_evasion() -> int: return max(0, base_evasion + evasion_modifier)
func get_forget_levels() -> float:
	var total: float = 0.0
	for e in active_effects:
		if _effect_get(e, "stat", "") == "forget":
			total += float(_effect_get(e, "value", 0))
	return total

func add_forget(levels: float, source: String) -> void:
	active_effects.append({"stat": "forget", "value": levels, "duration": -1, "effect_id": "forget", "source_ability": source})

func get_crit() -> float:
	# Ð—Ð°Ð±Ñ‹Ñ‚ÑŒÑ‘: -10% ÐºÑ€Ð¸Ñ‚Ð° Ð·Ð° ÐºÐ°Ð¶Ð´Ñ‹Ð¹ ÑƒÑ€Ð¾Ð²ÐµÐ½ÑŒ
	var base_val = maxf(0.0, base_crit_chance + crit_modifier - get_forget_levels() * 0.10)
	# ÐÑÑƒÑ€Ð° Â«Ð£Ð´Ð°Ñ€ Ñ…Ð°Ð¾ÑÐ°Â»: Ð²Ñ€ÐµÐ¼ÐµÐ½Ð½Ð¾Ðµ Ð¿ÐµÑ€ÐµÐ¾Ð¿Ñ€ÐµÐ´ÐµÐ»ÐµÐ½Ð¸Ðµ Ð±Ð°Ð·Ð¾Ð²Ð¾Ð¹ ÑƒÐ´Ð°Ñ‡Ð¸
	if has_meta("asura_chaos_crit_override"):
		var _ov_turns = int(get_meta("asura_chaos_crit_turns", 0))
		if _ov_turns > 0:
			return float(get_meta("asura_chaos_crit_override"))
	return base_val

func apply_stat_change(stat: String, amount: int):
	var value = amount
	if special_effect_type == "cyclops_sensitive_accuracy" and stat == "accuracy":
		value *= 2
	# Ð‘Ñ€Ð¾Ð½Ð¸Ñ€Ð¾Ð²Ð°Ð½Ð½Ñ‹Ð¹ Ñ‚Ð¸Ñ‚Ð°Ð½: Ð²ÑÐµ ÑÑ„Ñ„ÐµÐºÑ‚Ñ‹ Ð±Ñ€Ð¾Ð½Ð¸ ÑƒÐ´Ð²Ð°Ð¸Ð²Ð°ÑŽÑ‚ÑÑ
	if special_effect_type == "titan_armor_double" and stat == "armor":
		value *= 2
	# ÐÑ‚Ð°ÐºÑƒÑŽÑ‰Ð¸Ð¹ Ñ‚Ð¸Ñ‚Ð°Ð½: Ð²ÑÐµ ÑÑ„Ñ„ÐµÐºÑ‚Ñ‹ ÑƒÑ€Ð¾Ð½Ð° ÑƒÐ´Ð²Ð°Ð¸Ð²Ð°ÑŽÑ‚ÑÑ
	if special_effect_type == "titan_damage_double" and stat == "damage":
		value *= 2
	match stat:
		"hp":
			current_hp = clampi(current_hp + value, 0, max_hp)
			refresh_passive_auras()
			if value < 0:
				damage_taken.emit(-value)
			elif value > 0:
				healed.emit(value)
		"max_hp":
			max_hp = maxi(1, max_hp + value)
			if current_hp > max_hp:
				current_hp = max_hp
			refresh_passive_auras()
		"accuracy": accuracy_modifier += value
		"damage": damage_modifier_flat += value
		"damage_percent": damage_modifier_percent += value
		"armor": armor_modifier += value
		"evasion": evasion_modifier += value
		"crit": crit_modifier += (float(value) / 100.0)
		"initiative": initiative += value

## ÐŸÑ€Ð¾Ð²ÐµÑ€ÑÐµÑ‚, Ð·Ð°Ð½Ð¸Ð¼Ð°ÐµÑ‚ Ð»Ð¸ ÑŽÐ½Ð¸Ñ‚ ÑƒÐºÐ°Ð·Ð°Ð½Ð½ÑƒÑŽ Ð¿Ð¾Ð·Ð¸Ñ†Ð¸ÑŽ.
## Ð”Ð»Ñ Ð¾Ð±Ñ‹Ñ‡Ð½Ñ‹Ñ… â€” Ñ‚Ð¾Ð»ÑŒÐºÐ¾ position_index. Ð”Ð»Ñ Ð±Ð¾Ð»ÑŒÑˆÐ¸Ñ… â€” Ñ‚Ð°ÐºÐ¶Ðµ position_index + 1.
func occupies_position(pos: int) -> bool:
	if pos == position_index:
		return true
	if is_large and pos == position_index + 1:
		return true
	return false

## ÐŸÑ€Ð¾Ð²ÐµÑ€ÑÐµÑ‚, Ð¼Ð¾Ð¶ÐµÑ‚ Ð»Ð¸ ability Ð²Ñ‹Ð±Ñ€Ð°Ñ‚ÑŒ Ð´Ð°Ð½Ð½Ð¾Ð³Ð¾ ÑŽÐ½Ð¸Ñ‚Ð° ÐºÐ°Ðº Ñ†ÐµÐ»ÑŒ (ÑƒÑ‡Ð¸Ñ‚Ñ‹Ð²Ð°ÐµÑ‚ targetable_positions).
## Ð”Ð»Ñ Ð±Ð¾Ð»ÑŒÑˆÐ¸Ñ… ÑŽÐ½Ð¸Ñ‚Ð¾Ð² â€” Ð´Ð¾ÑÑ‚Ð°Ñ‚Ð¾Ñ‡Ð½Ð¾ ÑÐ¾Ð²Ð¿Ð°Ð´ÐµÐ½Ð¸Ñ Ð¿Ð¾ Ð»ÑŽÐ±Ð¾Ð¹ Ð¸Ð· Ð·Ð°Ð½Ð¸Ð¼Ð°ÐµÐ¼Ñ‹Ñ… Ð¿Ð¾Ð·Ð¸Ñ†Ð¸Ð¹.
static func can_be_targeted_at(unit: Combatant, ability: AbilityResource) -> bool:
	if ability.targetable_positions.size() > unit.position_index:
		if ability.targetable_positions[unit.position_index]:
			return true
	if unit.is_large and unit.position_index + 1 < ability.targetable_positions.size():
		if ability.targetable_positions[unit.position_index + 1]:
			return true
	return false

func get_damage_modifier(target_pos: int) -> float:
	if special_effect_type == "zeus_position_bonus":
		if target_pos == 0: return 0.8
		if target_pos == 2: return 1.2
		if target_pos == 3: return 1.5
	return 1.0

## Ð’Ñ‹Ð·Ñ‹Ð²Ð°ÐµÑ‚ÑÑ ÐºÐ¾Ð³Ð´Ð° Ð¿Ð¾ ÑÑ‚Ð¾Ð¼Ñƒ ÑŽÐ½Ð¸Ñ‚Ñƒ ÐÐÐŸÐ ÐÐ’Ð›Ð•ÐÐ Ð°Ñ‚Ð°ÐºÐ° (Ð´Ð°Ð¶Ðµ ÐµÑÐ»Ð¸ Ð¿Ñ€Ð¾Ð¼Ð°Ñ…). Ð’Ð¾Ð·Ð²Ñ€Ð°Ñ‰Ð°ÐµÑ‚ ÑÑ‚Ñ€Ð¾ÐºÑƒ Ð»Ð¾Ð³Ð° Ð¸Ð»Ð¸ "".
func on_targeted_by_attack() -> String:
	return ""

## Ð’Ñ‹Ð·Ñ‹Ð²Ð°ÐµÑ‚ÑÑ ÐºÐ¾Ð³Ð´Ð° Ð¿Ð¾ ÑÑ‚Ð¾Ð¼Ñƒ ÑŽÐ½Ð¸Ñ‚Ñƒ ÐŸÐžÐŸÐÐ›Ð˜ (ÑƒÑ€Ð¾Ð½ > 0). Ð’Ð¾Ð·Ð²Ñ€Ð°Ñ‰Ð°ÐµÑ‚ ÑÑ‚Ñ€Ð¾ÐºÑƒ Ð»Ð¾Ð³Ð° Ð¸Ð»Ð¸ "".
func on_hit_by_attack() -> String:
	match special_effect_type:
		"draugr_raider":
			crit_modifier += 0.05
			active_effects.append({"stat": "crit", "value": 5, "duration": -1, "effect_id": "draugr_raider_luck", "source_ability": "Пассивка драугра"})
			return "[Ð”Ñ€Ð°ÑƒÐ³Ñ€-Ð½Ð°Ð»Ñ‘Ñ‚Ñ‡Ð¸Ðº] %s: +5%% Ðº ÑƒÐ´Ð°Ñ‡Ðµ (Ð¸Ñ‚Ð¾Ð³Ð¾ %d%%)" % [unit_name, int(crit_chance * 100)]
		"draugr_juggernaut":
			armor_modifier += 5
			active_effects.append({"stat": "armor", "value": 5, "duration": -1, "effect_id": "draugr_juggernaut_armor", "source_ability": "Пассивка драугра"})
			return "[Ð”Ñ€Ð°ÑƒÐ³Ñ€-Ð´Ð¶Ð°Ð³Ð³ÐµÑ€Ð½Ð°ÑƒÑ‚] %s: +5 Ð±Ñ€Ð¾Ð½Ð¸ (Ð¸Ñ‚Ð¾Ð³Ð¾ %d%%)" % [unit_name, armor]
		"draugr_berserker":
			damage_modifier_flat += 5
			active_effects.append({"stat": "damage", "value": 5, "duration": -1, "effect_id": "draugr_berserker_damage", "source_ability": "Пассивка драугра"})
			return "[Ð”Ñ€Ð°ÑƒÐ³Ñ€-Ð±ÐµÑ€ÑÐµÑ€Ðº] %s: +5 Ð°Ñ‚Ð°ÐºÐ¸ (Ð¸Ñ‚Ð¾Ð³Ð¾ %d)" % [unit_name, damage]
	return ""

## Ð’Ð¾Ð·Ð²Ñ€Ð°Ñ‰Ð°ÐµÑ‚ Ð¿Ð¾Ð·Ð¸Ñ†Ð¸Ð¾Ð½Ð½Ñ‹Ð¹ Ð¸Ð½Ð´ÐµÐºÑ ÑŽÐ½Ð¸Ñ‚Ð° Ð¿Ð¾Ð·Ð°Ð´Ð¸ (position_index + 1), Ð¸Ð»Ð¸ -1 ÐµÑÐ»Ð¸ Ð½Ðµ Ð¿Ñ€Ð¸Ð¼ÐµÐ½Ð¸Ð¼Ð¾.
func get_behind_position() -> int:
	return position_index + 1

## Ð’Ð¾Ð·Ð²Ñ€Ð°Ñ‰Ð°ÐµÑ‚ Ð¿Ð¾Ð·Ð¸Ñ†Ð¸Ð¾Ð½Ð½Ñ‹Ð¹ Ð¸Ð½Ð´ÐµÐºÑ ÑŽÐ½Ð¸Ñ‚Ð° Ð¿ÐµÑ€ÐµÐ´ (position_index - 1), Ð¸Ð»Ð¸ -1 ÐµÑÐ»Ð¸ Ð½Ðµ Ð¿Ñ€Ð¸Ð¼ÐµÐ½Ð¸Ð¼Ð¾.
func get_front_position() -> int:
	return position_index - 1

func take_damage(amount: int):
	current_hp = clampi(current_hp - amount, 0, max_hp)
	refresh_passive_auras()
	if amount > 0:
		damage_taken.emit(amount)
func modify_majesty(amount: int): current_majesty = clampi(current_majesty + amount, 0, 100) if !is_enemy else 0
func start_new_round(): has_waited_this_round = false; has_acted_this_round = false; round_wait_stamp = -1; moved_this_round = false; griffin_first_strike_used = false
func wait_action(): has_waited_this_round = true

func get_status_report() -> String:
	return (
		"ÐŸÐµÑ€ÑÐ¾Ð½Ð°Ð¶: %s\n" % unit_name +
		"Ð—Ð´Ð¾Ñ€Ð¾Ð²ÑŒÐµ: %d/%d\n" % [current_hp, max_hp] +
		"Ð£Ñ€Ð¾Ð½: %d\n" % damage +
		"Ð‘Ñ€Ð¾Ð½Ñ: %d\n" % armor +
		"Ð¢Ð¾Ñ‡Ð½Ð¾ÑÑ‚ÑŒ: %d\n" % accuracy +
		"Ð£ÐºÐ»Ð¾Ð½ÐµÐ½Ð¸Ðµ: %d\n" % evasion +
		"ÐšÑ€Ð¸Ñ‚: %d%%" % [crit_chance * 100]
	)
# Ð’Ð½ÑƒÑ‚Ñ€Ð¸ combatant.gd
func tick_effects():
	var i = 0
	while i < active_effects.size():
		var effect = active_effects[i]
		var stat_name = _effect_get(effect, "stat")
		var effect_value = _effect_get(effect, "value", 0)
		var effect_duration = _effect_get(effect, "duration", 0)
		var effect_id = _effect_get(effect, "effect_id", "")
		if effect_id == "neverending_storm_mark" or stat_name == "neverending_storm_mark":
			effect["duration"] = -1
			i += 1
			continue
		
		if stat_name == "regeneration":
			apply_stat_change("hp", int(max_hp * float(effect_value) / 100.0))
			effect["duration"] = effect_duration - 1
		
		elif stat_name == "periodic_damage":
				var is_invuln = false
				for e in active_effects:
					if _effect_get(e, "stat", "") == "invulnerable":
						is_invuln = true
						break
				if not is_invuln:
					take_damage(effect_value)
				effect["duration"] = effect_duration - 1
		
		elif effect_duration != -1:
			effect["duration"] = effect_duration - 1
			if effect["duration"] == 0:
				if stat_name != "stun":
					apply_stat_change(stat_name, -effect_value)
				if stat_name == "stun":
					is_stunned = false
		
		if _effect_get(effect, "duration", 0) == 0:
			active_effects.remove_at(i)
		else:
			i += 1


func refresh_passive_auras() -> void:
	_refresh_thor_berserk_aura()

func _refresh_thor_berserk_aura() -> void:
	if special_effect_type != "thor_berserk":
		_clear_thor_berserk_aura()
		return
	var missing_hp := maxi(0, max_hp - current_hp)
	var bonus := int(floor((float(missing_hp) / float(maxi(1, max_hp))) * 10.0) * 5.0)
	if bonus == _thor_berserk_aura_bonus:
		return
	_clear_thor_berserk_aura()
	if bonus <= 0:
		return
	damage_modifier_flat += bonus
	armor_modifier += bonus
	_thor_berserk_aura_bonus = bonus
	active_effects.append({"stat": "damage", "value": bonus, "duration": -1, "effect_id": "thor_berserk_aura_damage", "source_ability": "ÐŸÐ°ÑÑÐ¸Ð²ÐºÐ° Ð¢Ð¾Ñ€Ð°", "dispellable": false})
	active_effects.append({"stat": "armor", "value": bonus, "duration": -1, "effect_id": "thor_berserk_aura_armor", "source_ability": "ÐŸÐ°ÑÑÐ¸Ð²ÐºÐ° Ð¢Ð¾Ñ€Ð°", "dispellable": false})

func _clear_thor_berserk_aura() -> void:
	if _thor_berserk_aura_bonus != 0:
		damage_modifier_flat -= _thor_berserk_aura_bonus
		armor_modifier -= _thor_berserk_aura_bonus
		_thor_berserk_aura_bonus = 0
	for i in range(active_effects.size() - 1, -1, -1):
		var effect_id = _effect_get(active_effects[i], "effect_id", "")
		if effect_id == "thor_berserk_aura_damage" or effect_id == "thor_berserk_aura_armor":
			active_effects.remove_at(i)
static func _effect_get(effect, key: String, default = null):
	if effect is Dictionary:
		return effect.get(key, default)
	return default
func enter_stance(stance: AbilityResource):
	active_stance = stance
	# Ð—Ð´ÐµÑÑŒ Ð¼Ð¾Ð¶Ð½Ð¾ Ð¸ÑÐ¿ÑƒÑÐºÐ°Ñ‚ÑŒ ÑÐ¸Ð³Ð½Ð°Ð», Ñ‡Ñ‚Ð¾Ð±Ñ‹ UI Ð¾Ð±Ð½Ð¾Ð²Ð¸Ð»ÑÑ (Ð¸ÐºÐ¾Ð½ÐºÐ° ÑÑ‚Ð¾Ð¹ÐºÐ¸)

func break_stance():
	active_stance = null
func check_stance_interruption(reason: String, new_pos: int = -1):
	if active_stance == null: return
	
	# ÐŸÑ€ÐµÑ€Ñ‹Ð²Ð°Ð½Ð¸Ðµ Ð¿Ð¾ ÑÑ‚Ð°Ð½Ñƒ
	if reason == "stun":
		break_stance()
		return
		
	# ÐŸÑ€ÐµÑ€Ñ‹Ð²Ð°Ð½Ð¸Ðµ Ð¿Ð¾ Ð´Ð²Ð¸Ð¶ÐµÐ½Ð¸ÑŽ
	if reason == "move" and new_pos != -1:
		# ÐŸÑ€Ð¾Ð²ÐµÑ€ÑÐµÐ¼, ÐµÑÑ‚ÑŒ Ð»Ð¸ Ð½Ð¾Ð²Ð°Ñ Ð¿Ð¾Ð·Ð¸Ñ†Ð¸Ñ Ð² ÑÐ¿Ð¸ÑÐºÐµ Ñ€Ð°Ð·Ñ€ÐµÑˆÐµÐ½Ð½Ñ‹Ñ… Ð´Ð»Ñ ÑÑ‚Ð¾Ð¹ ÑÑ‚Ð¾Ð¹ÐºÐ¸
		if new_pos < 0 or new_pos > 3 or not active_stance.usable_from_positions[new_pos]:
			break_stance()
			print(unit_name, " ÑÑ‚Ð¾Ð¹ÐºÐ° Ð¿Ñ€ÐµÑ€Ð²Ð°Ð½Ð° Ð¸Ð·-Ð·Ð° Ð¿ÐµÑ€ÐµÐ¼ÐµÑ‰ÐµÐ½Ð¸Ñ Ð² Ð¿Ð¾Ð·Ð¸Ñ†Ð¸ÑŽ ", new_pos)
			
var ai_class = null # Ð¡ÑŽÐ´Ð° Ð±ÑƒÐ´ÐµÑ‚ Ð·Ð°Ð¿Ð¸ÑÑ‹Ð²Ð°Ñ‚ÑŒÑÑ ÐºÐ»Ð°ÑÑ Ð»Ð¾Ð³Ð¸ÐºÐ¸
