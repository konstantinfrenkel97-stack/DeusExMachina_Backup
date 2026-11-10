extends MissionEffect
class_name HeroTargetEffect

## Общий способ выбрать, КОГО из богов текущего отряда миссии затрагивает эффект.
## Наследуют HeroBuffEffect, HeroHpDeltaEffect, HeroMajestyDeltaEffect — вместо того, чтобы
## городить в MissionOutcome отдельные team_*/target_*/random_hero_* поля под один и тот же
## эффект на разные цели (как было раньше).
##
## ВСЕ варианты target, включая STRONGEST_ATTACK/STRONGEST_ARMOR, вычисляются В МОМЕНТ
## РАЗРЕШЕНИЯ ИСХОДА СЦЕНЫ (вызова apply()), а не в момент старта боя — так решил
## дизайнер: "сильнейший бог" выбирается сразу, как и любой другой target, по базовым
## статам CharacterResource (без учёта временных баффов, которые ещё не наложены).
## Раньше (strongest_hero_buffs) это выбиралось в начале боя по живому Combatant —
## то поведение сохранено как legacy-путь (см. Effects/README.md), этот effects-путь
## его не использует и не обязан совпадать с ним по таймингу.

enum Target {
	TEAM,             ## все живые боги отряда миссии
	SPECIFIC,         ## заранее выбранный бог (specific_god)
	RANDOM,           ## случайный живой бог отряда; если preferred_god задан и жив в отряде — приоритет ему
	STRONGEST_ATTACK, ## живой бог отряда с наибольшим базовым damage (при равенстве — первый по порядку)
	STRONGEST_ARMOR,  ## живой бог отряда с наибольшим базовым armor (при равенстве — первый по порядку)
}

@export var target: Target = Target.TEAM
@export var specific_god: CharacterResource  ## для Target.SPECIFIC
@export var preferred_god: CharacterResource ## для Target.RANDOM — предпочитаемый бог, если есть в отряде


## Пути (.tres) живых богов отряда миссии, которых затрагивает эффект — по правилу target.
func _resolve_target_paths() -> Array[String]:
	var alive: Array[String] = []
	for hero_path in CombatManager.mission_heroes:
		var path: String = str(hero_path).strip_edges()
		if path == "" or CombatManager.mission_dead_heroes.has(path):
			continue
		if CampaignState.get_god_current_hp(path) <= 0:
			continue
		alive.append(path)
	var result: Array[String] = []
	match target:
		Target.TEAM:
			return alive
		Target.SPECIFIC:
			# Как и legacy target_god/target_god_immediate: достаточно, чтобы бог не был мёртв —
			# НЕ обязательно быть в mission_heroes (сюжетный бог может получить эффект и вне отряда).
			var specific_path: String = specific_god.resource_path if specific_god != null else ""
			if specific_path != "" and not CampaignState.is_god_dead(specific_path):
				result.append(specific_path)
			return result
		Target.RANDOM:
			if alive.is_empty():
				return result
			var preferred_path: String = preferred_god.resource_path if preferred_god != null else ""
			if preferred_path != "" and alive.has(preferred_path):
				result.append(preferred_path)
			else:
				result.append(alive[randi_range(0, alive.size() - 1)])
			return result
		Target.STRONGEST_ATTACK:
			var best_attack_path: String = _pick_best_by_stat(alive, "damage")
			if best_attack_path != "":
				result.append(best_attack_path)
			return result
		Target.STRONGEST_ARMOR:
			var best_armor_path: String = _pick_best_by_stat(alive, "armor")
			if best_armor_path != "":
				result.append(best_armor_path)
			return result
	return result


## Возвращает путь живого бога из candidate_paths с наибольшим базовым значением
## stat_name ("damage"/"armor") на его CharacterResource. При равенстве — первый по
## порядку. "" если candidate_paths пуст. То же самое правило, что и в
## MissionScene._hero_with_highest_armor() (выбор по базовому стату ресурса, без
## учёта временных баффов боя — на момент выбора боя ещё нет).
func _pick_best_by_stat(candidate_paths: Array[String], stat_name: String) -> String:
	var best_path: String = ""
	var best_value: int = -1
	for path in candidate_paths:
		var res: CharacterResource = CampaignState.load_character_resource(path)
		if res == null:
			continue
		var value: int = int(res.get(stat_name))
		if value > best_value:
			best_value = value
			best_path = path
	return best_path
