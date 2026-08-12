extends RefCounted
class_name JotunLogic

## Йотун: приоритетная логика:
## 1) Если может применить «Мощь Йотуна» (позиции 0-1) — 60% шанс → применяет
## 2) Если нет метки провокации → «Недвижим словно айсберг»
## 3) Иначе → «Дыхание Зимы»

const ICEBERG = "недвижим словно айсберг"
const JOTUN_MIGHT = "мощь йотуна"
const WINTER_BREATH = "дыхание зимы"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	# 1) Мощь Йотуна — если стоит на позициях 0-1 и прошёл бросок 60%
	var might = _find_ability(monster, JOTUN_MIGHT)
	if might and _is_ability_usable_from_position(might, monster.position_index):
		if randf() < 0.60:
			var target = _get_random_valid_target(heroes, might)
			if target:
				return {"ability": might, "target": target}
	
	# 2) Нет метки провокации → «Недвижим словно айсберг»
	if not _has_provocation_mark(monster):
		var iceberg = _find_ability(monster, ICEBERG)
		if iceberg and _is_ability_usable_from_position(iceberg, monster.position_index):
			return {"ability": iceberg, "target": monster}
	
	# 3) «Дыхание Зимы»
	var breath = _find_ability(monster, WINTER_BREATH)
	if breath and _is_ability_usable_from_position(breath, monster.position_index):
		var target = _get_random_valid_target(heroes, breath)
		if target:
			return {"ability": breath, "target": target}
	
	# Запасной вариант: любая доступная способность
	return _fallback(monster, heroes)

## Проверяет, есть ли на юните активная метка провокации.
static func _has_provocation_mark(unit: Combatant) -> bool:
	for effect in unit.active_effects:
		if Combatant._effect_get(effect, "stat", "") == "provocation_mark":
			return true
	return false

## Проверяет, можно ли использовать способность с текущей позиции.
static func _is_ability_usable_from_position(ability: AbilityResource, pos: int) -> bool:
	if ability.usable_from_positions.size() > pos:
		return ability.usable_from_positions[pos]
	return false

## Находит способность по имени (без учёта регистра).
static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == ability_name:
			return ab
	return null

## Случайная валидная цель для способности.
static func _get_random_valid_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and _can_target(ability, h):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null

static func _can_target(ability: AbilityResource, hero: Combatant) -> bool:
	return Combatant.can_be_targeted_at(hero, ability)

## Запасной вариант: любая доступная способность.
static func _fallback(monster: Combatant, heroes: Array) -> Dictionary:
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if not _is_ability_usable_from_position(ab, monster.position_index):
			continue
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		var target = _get_random_valid_target(heroes, ab)
		if target:
			return {"ability": ab, "target": target}
	return {}
