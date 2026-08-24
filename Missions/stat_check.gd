extends Resource
class_name StatCheck

## Проверка характеристики миссии.
## Бросок = случайное 0..100 + (средний стат команды × коэффициент).
## УСПЕХ, если результат ≥ difficulty.

enum Stat { ATTACK, INITIATIVE, ARMOR, EVASION, ACCURACY, CRIT, MAX_HP }

# Какая характеристика усредняется по команде.
@export var stat: Stat = Stat.ATTACK
# Подпись для игрока («Атака», «Инициатива»). Пусто — берётся из stat.
@export var stat_label: String = ""
# Множитель вклада среднего стата команды (потом вы решаете значение).
@export var coefficient: float = 1.0
# Порог сложности. Чем выше — тем труднее пройти проверку.
@export var difficulty: int = 50


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


## Собственно бросок: успех если rand(0..100) + средний_стат×коэфф ≥ difficulty − difficulty_delta.
## difficulty_delta — одноразовая скидка сложности от эффектов миссии (не меняет сам ресурс).
func is_success(avg_team_stat: float, difficulty_delta: int = 0) -> bool:
	var roll := randi_range(0, 100) + int(avg_team_stat * coefficient)
	return roll >= (difficulty - difficulty_delta)


## Среднее значение характеристики по команде (массив путей .tres богов).
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
