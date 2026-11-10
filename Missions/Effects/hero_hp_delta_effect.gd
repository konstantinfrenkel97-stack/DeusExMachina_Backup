extends HeroTargetEffect
class_name HeroHpDeltaEffect

## Изменение HP одного/нескольких/всех богов отряда — WHO выбирается полем target
## (см. HeroTargetEffect), WHEN полем immediate здесь.
##
## Заменяет собой старые поля MissionOutcome:
##   hero_heal_percent                              → target=TEAM, immediate=true, percent_delta>0,
##                                                    heal_item_bonus=true (legacy лечил НЕМЕДЛЕННО и
##                                                    добавлял +2% с предметом stone_face_bonus_heal)
##   hero_hp_percent_delta                          → target=TEAM, immediate=true,  percent_delta
##   hero_hp_flat_delta                             → target=TEAM, immediate=true,  flat_delta
##   random_hero_hp_percent_delta                   → target=RANDOM, immediate=true, percent_delta
##   target_current_hp_percent_delta (+ target_god)  → target=SPECIFIC, immediate=false, percent_delta
##   target_god_immediate_hp_percent_delta           → target=SPECIFIC, immediate=true, percent_delta
##
## Ограничение (сознательное, см. Effects/README.md): flat_delta поддержан только при
## immediate=true. "Следующий бой" (immediate=false) идёт через CombatManager.
## pending_mission_target_effects, а этот канал в battle_start.gd умеет только % от HP,
## не фиксированные очки (так было и в legacy hero_hp_flat_delta — это ограничение движка,
## не этого класса).

@export var percent_delta: int = 0 ## % от максимума HP. Отрицательное — урон, положительное — лечение.
@export var flat_delta: int = 0    ## Фиксированные очки HP. Только вместе с immediate = true.
## true — применяется НЕМЕДЛЕННО, без боя (сразу при разрешении исхода).
## false (по умолчанию) — одноразово, в ближайшем следующем бою.
@export var immediate: bool = false
## true — как в legacy hero_heal_percent: богам с предметом-эффектом "stone_face_bonus_heal"
## лечение увеличивается на +2%. Только для immediate=true и percent_delta > 0.
@export var heal_item_bonus: bool = false


func apply() -> void:
	if percent_delta == 0 and flat_delta == 0:
		return
	var paths: Array[String] = _resolve_target_paths()
	if immediate:
		for path in paths:
			_apply_immediate(path)
		return
	if flat_delta != 0:
		push_warning("HeroHpDeltaEffect: flat_delta=%d проигнорирован — fixed-очки HP поддержаны только с immediate=true (ограничение battle_start.gd)." % flat_delta)
	if percent_delta == 0:
		return
	for path in paths:
		CombatManager.pending_mission_target_effects.append({
			"resource_path": path,
			"current_hp_percent_delta": percent_delta,
			"majesty_delta": 0,
			"buffs": [],
		})


func _apply_immediate(path: String) -> void:
	if CampaignState.is_god_dead(path):
		return
	var max_hp: int = CampaignState.get_god_max_hp(path)
	var effective_percent: int = percent_delta
	if heal_item_bonus and CampaignState.god_has_item_effect(path, "stone_face_bonus_heal"):
		effective_percent += 2
	var amount: int = int(round(float(max_hp) * float(effective_percent) / 100.0)) + flat_delta
	if amount == 0 and effective_percent != 0:
		amount = 1 if effective_percent > 0 else -1
	if amount == 0:
		return
	CampaignState.set_god_current_hp(path, CampaignState.get_god_current_hp(path) + amount, max_hp)
