extends Node

# Массивы путей к файлам .tres, которые выбрал игрок
var selected_heroes: Array[String] = ["", "", "", ""]
var selected_enemies: Array[String] = ["", "", "", ""]
# Враги, заданные файлом Построения из миссии.
# battle_setup._ready() подставит их в selected_enemies и заблокирует редактирование.
var pending_formation_enemies: Array[String] = ["", "", "", ""]
# Локация, заданная в Миссии. Если не пусто — battle_setup применит её и заблокирует кнопку.
var pending_location_id: String = ""
# Модификаторы юнитов боя миссии (Array[UnitModifier]). Применяются battle_scene после спавна.
var pending_enemy_modifiers: Array = []
var pending_hero_modifiers: Array = []
# Одноразовые эффекты сцен миссии, применяются в следующем бою после спавна отряда.
var pending_mission_hero_heal_percent: int = 0
var pending_mission_fantasy_delta: int = 0
var pending_mission_hero_majesty_delta: int = 0
var pending_mission_hero_buffs: Array = []
var pending_mission_target_effects: Array = []
var pending_helheim_skip_fog_rounds: int = 0
# Эффекты, которые держатся до конца миссии и применяются в каждом бою.
var mission_strongest_hero_buffs: Array = []

# ════════════════════════════════════════════════════════════
#  СОСТОЯНИЕ МИССИИ (внутри компании)
#  Компания = глобальный ростер богов + fading на .tres.
#  Миссия = конкретное задание: отряд, смертность, позиции.
# ════════════════════════════════════════════════════════════

## True — текущий бой запущен из миссии.
var is_mission_battle: bool = false

## Пути (.tres) богов, погибших в ТЕКУЩЕЙ МИССИИ.
## Недоступны до конца миссии, но остаются в компании (fading в .tres).
var mission_dead_heroes: Array[String] = []

## Отряд миссии (4 бога). Выбирается ОДИН раз перед первым боем.
## В последующих боях можно менять только позиции, но не состав.
var mission_heroes: Array[String] = ["", "", "", ""]
var mission_heroes_set: bool = false

## Сброс состояния миссии (вызывается при старте новой миссии).
func reset_mission():
	mission_heroes = ["", "", "", ""]
	mission_heroes_set = false
	mission_dead_heroes = []
	pending_enemy_modifiers = []
	pending_hero_modifiers = []
	pending_mission_hero_heal_percent = 0
	pending_mission_fantasy_delta = 0
	pending_mission_hero_majesty_delta = 0
	pending_mission_hero_buffs = []
	pending_mission_target_effects = []
	pending_helheim_skip_fog_rounds = 0
	mission_strongest_hero_buffs = []
	is_mission_battle = false

# Выбранный бэкграунд (путь к текстуре, "" = нет)
var selected_background: String = ""

# Информация о локации для отображения в бою
var selected_location_name: String = ""
var selected_location_description: String = ""
var selected_location_id: String = ""
var selected_location_category: String = ""

# Хельхейм: путь к туманному фоновому изображению (сменяется на 1 раунд)
var selected_fog_background: String = ""

func clear_selection():
	selected_heroes = ["", "", "", ""]
	selected_enemies = ["", "", "", ""]
	pending_formation_enemies = ["", "", "", ""]
	pending_location_id = ""
	pending_enemy_modifiers = []
	pending_hero_modifiers = []
	pending_mission_hero_heal_percent = 0
	pending_mission_fantasy_delta = 0
	pending_mission_hero_majesty_delta = 0
	pending_mission_hero_buffs = []
	pending_mission_target_effects = []
	pending_helheim_skip_fog_rounds = 0
	mission_strongest_hero_buffs = []
	selected_background = ""
	selected_location_name = ""
	selected_location_description = ""
	selected_location_id = ""
	selected_location_category = ""
	selected_fog_background = ""
	is_mission_battle = false
	
## Возвращает глобальный множитель урона от способностей (не периодического).
func get_damage_multiplier() -> float:
	if selected_location_id == "arena":
		return 1.2
	return 1.0

## Возвращает true если броня должна игнорироваться.
func is_armor_ignored() -> bool:
	return false

## Возвращает множитель критического урона (по умолчанию x2).
func get_crit_multiplier() -> float:
	if selected_location_id == "jungle":
		return 3.0
	return 2.0

## Возвращает множитель стоимости заклинаний по очкам фантазии.
func get_spell_cost_multiplier() -> float:
	if selected_location_id == "castle":
		return 1.5
	return 1.0

## Возвращает true если можно применить 2 заклинания за раунд (Замок).
func can_cast_two_spells() -> bool:
	return selected_location_id == "castle"

## Возвращает true если данная локация — Корабли (уникальное заклинание «Ром»).
func is_ships_location() -> bool:
	return selected_location_id == "ships"

## Переключение полноэкранного режима: F11 или Alt+Enter.
## Работает во всех сценах, так как CombatManager — автозагрузчик.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var toggle: bool = (event.keycode == KEY_F11) or (event.keycode == KEY_ENTER and event.alt_pressed)
		if toggle:
			var w: Window = get_window()
			if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
				w.mode = Window.MODE_WINDOWED
			else:
				w.mode = Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
