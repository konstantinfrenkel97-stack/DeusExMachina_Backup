extends HeroTargetEffect
class_name HeroMajestyDeltaEffect

## Изменение величия одного/нескольких/всех богов отряда — WHO выбирается полем target
## (см. HeroTargetEffect), WHEN полем immediate здесь.
##
## Заменяет:
##   hero_majesty_delta (весь отряд)      → target=TEAM, immediate=true
##       (legacy применял величие НЕМЕДЛЕННО через MissionState.add_majesty_to_selected_heroes
##        ко ВСЕМ selected_heroes, без учёта живых/мёртвых — поэтому для TEAM+immediate
##        эффект делает ровно тот же вызов, а не идёт через resolve по живым)
##   target_majesty_delta (+ target_god)  → target=SPECIFIC, immediate=false
##   target_god_immediate_majesty_delta   → target=SPECIFIC, immediate=true

@export var delta: int = 0
## true — применяется НЕМЕДЛЕННО (сразу в MissionState).
## false (по умолчанию) — одноразово, в ближайшем следующем бою.
@export var immediate: bool = false


func apply() -> void:
	if delta == 0:
		return
	if immediate:
		if target == Target.TEAM:
			MissionState.add_majesty_to_selected_heroes(delta)
			return
		for path in _resolve_target_paths():
			MissionState.add_hero_majesty(path, delta)
		return
	for path in _resolve_target_paths():
		CombatManager.pending_mission_target_effects.append({
			"resource_path": path,
			"current_hp_percent_delta": 0,
			"majesty_delta": delta,
			"buffs": [],
		})
