extends Resource
class_name StatCheck

## Проверка характеристики миссии.
##
## Формула (см. success_chance_percent):
##   team_score = normalized_average(отряд, stat)                 -- 0..1, средний стат
##                                                                    команды к "практическому
##                                                                    максимуму" этого стата
##   team_score_bonus = team_score × coefficient × 100             -- в процентных пунктах
##   difficulty_penalty = difficulty − difficulty_delta − 50       -- 50 = "стандартная"
##                                                                    сложность, без штрафа/бонуса
##   chance = clamp(50 + team_score_bonus − difficulty_penalty, 5%, 95%)
## УСПЕХ, если случайное 0..100% < chance. Шанс никогда не бывает гарантированным (100%) или
## невозможным (0%) — даже максимально прокачанный отряд может провалить проверку раз в 20, и
## даже самый слабый отряд имеет шанс раз в 20 пройти сложнейшую.

enum Stat { ATTACK, INITIATIVE, ARMOR, EVASION, ACCURACY, CRIT, MAX_HP }

# Какая характеристика усредняется по команде.
@export var stat: Stat = Stat.ATTACK
# Подпись для игрока («Атака», «Инициатива»). Пусто — берётся из stat.
@export var stat_label: String = ""
# Вес вклада нормализованного стата команды в шанс (в долях от 100 процентных пунктов).
# При 1.0 полностью "прокачанный" по этому стату отряд (normalized_average = 1.0) добавляет
# +100 п.п. (шанс тут же упрётся в потолок 95%). 0.3 — типичное значение: команда со
# средним статом ~70% от потолка получает примерно +21 п.п.
@export var coefficient: float = 0.3
# Порог сложности. Чем выше — тем труднее пройти проверку. 50 — стандартная сложность
# (не меняет базовый шанс 50%); значения выше 50 — специально усложнённые проверки
# ("высокая сложность", напр. 70 = -20 п.п. к шансу).
@export var difficulty: int = 50

# "Практический максимум" для каждого стата — к нему приводится сырой team_average() перед
# использованием в формуле (см. normalized_average). Не жёсткий потолок для самой
# характеристики (юнит может быть и сильнее) — только точка отсчёта "сильная команда" для
# ЭТОЙ проверки. Подобраны по типичному разбросу статов богов/врагов в игре.
const STAT_NORMALIZATION_MAX := {
	Stat.ATTACK: 100.0,
	Stat.INITIATIVE: 15.0,
	Stat.ARMOR: 100.0,
	Stat.EVASION: 50.0,
	Stat.ACCURACY: 100.0,
	Stat.CRIT: 40.0,   # _stat_of() уже переводит crit_chance (0.05-0.3) в проценты (5-30)
	Stat.MAX_HP: 200.0,
}

const BASE_CHANCE_PERCENT := 50.0
const MIN_CHANCE_PERCENT := 5.0
const MAX_CHANCE_PERCENT := 95.0
const STANDARD_DIFFICULTY := 50


## Человекочитаемое название характеристики.
func display_stat() -> String:
	if stat_label != "":
		return stat_label
	match stat:
		Stat.ATTACK: return "Атака"
		Stat.INITIATIVE: return "Инициатива"
		Stat.ARMOR: return "Броня"
		Stat.EVASION: return "Уклонение"
		Stat.ACCURACY: return "Точность"
		Stat.CRIT: return "Удача"
		Stat.MAX_HP: return "Макс. HP"
	return "?"


## Итоговый шанс успеха в процентах (0..100), уже с учётом одноразовой скидки сложности
## эффектов миссии (difficulty_delta, см. MissionState.pending_check_difficulty_delta).
## god_paths — пути (.tres) ИМЕННО отряда, участвующего в проверке (обычно
## MissionState.selected_heroes) — НЕ весь открытый ростер игрока.
func success_chance_percent(god_paths: Array, difficulty_delta: int = 0) -> float:
	var team_score: float = normalized_average(god_paths)
	var team_score_bonus: float = team_score * coefficient * 100.0
	var difficulty_penalty: float = float(difficulty - difficulty_delta - STANDARD_DIFFICULTY)
	return clampf(BASE_CHANCE_PERCENT + team_score_bonus - difficulty_penalty, MIN_CHANCE_PERCENT, MAX_CHANCE_PERCENT)


## Собственно бросок: успех с вероятностью success_chance_percent(god_paths, difficulty_delta).
func is_success(god_paths: Array, difficulty_delta: int = 0) -> bool:
	return randf() * 100.0 < success_chance_percent(god_paths, difficulty_delta)


## Средний СЫРОЙ стат команды (массив путей .tres богов), без нормализации — см. normalized_average.
func team_average(god_paths: Array) -> float:
	var sum := 0.0
	var n := 0
	for p in god_paths:
		if p == "":
			continue
		var g = load(p)
		if g == null:
			continue
		sum += _stat_of(g)
		n += 1
	return sum / float(n) if n > 0 else 0.0


## team_average(), приведённый к 0..1 через STAT_NORMALIZATION_MAX (см. заголовок файла).
func normalized_average(god_paths: Array) -> float:
	var cap: float = float(STAT_NORMALIZATION_MAX.get(stat, 100.0))
	if cap <= 0.0:
		return 0.0
	return clampf(team_average(god_paths) / cap, 0.0, 1.0)


func _stat_of(g) -> float:
	match stat:
		Stat.ATTACK: return g.damage
		Stat.INITIATIVE: return g.initiative
		Stat.ARMOR: return g.armor
		Stat.EVASION: return g.evasion
		Stat.ACCURACY: return g.accuracy
		Stat.CRIT: return g.crit_chance * 100.0
		Stat.MAX_HP: return g.max_hp
	return 0.0
