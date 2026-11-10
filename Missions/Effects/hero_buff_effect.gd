extends HeroTargetEffect
class_name HeroBuffEffect

## Бафф/дебафф одному, нескольким или всем богам отряда миссии — WHO выбирается полем
## target (см. HeroTargetEffect), WHEN/HOW LONG — полем duration здесь. WHO и HOW LONG —
## независимые настройки одного эффекта, а не разные поля под каждую комбинацию.
##
## Заменяет собой старые поля MissionOutcome, которые делали ровно это, но каждое —
## только для одной фиксированной комбинации цели и длительности:
##   hero_buffs (+ hero_buffs_until_mission_end)                  → target=TEAM
##   target_buffs (+ target_god, target_buffs_until_mission_end)  → target=SPECIFIC
##   target_random_hero_buffs (+ preferred_god, until_mission_end) → target=RANDOM
##   strongest_hero_buffs                                          → target=STRONGEST_ATTACK
##   (постоянных бонусов конкретному произвольному статy раньше не было вовсе —
##    permanent_god_crit_bonus/permanent_god_max_hp_bonus умели только крит и макс. HP)

enum Duration {
	ONE_BATTLE,        ## одноразово, в ближайшем следующем бою
	UNTIL_MISSION_END,  ## держится до конца миссии, применяется в каждом бою, пока цель жива;
	                    ## снимается, когда миссия заканчивается (как и раньше)
	PERMANENT,          ## навсегда (сохраняется в CampaignState), применяется в КАЖДОМ бою
	                    ## с этим богом до конца игры, не снимается по завершении миссии
}

@export var buffs: Array[BuffEntry] = []
@export var duration: Duration = Duration.ONE_BATTLE


func apply() -> void:
	if buffs.is_empty():
		return
	for path in _resolve_target_paths():
		match duration:
			Duration.PERMANENT:
				CampaignState.add_permanent_god_buffs(path, buffs)
			Duration.UNTIL_MISSION_END:
				CombatManager.mission_target_buffs.append({
					"resource_path": path,
					"buffs": buffs,
				})
			Duration.ONE_BATTLE:
				CombatManager.pending_mission_target_effects.append({
					"resource_path": path,
					"current_hp_percent_delta": 0,
					"majesty_delta": 0,
					"buffs": buffs,
				})
