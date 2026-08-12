extends Resource
class_name FormationResource

## Построение — состав противников на 4 позициях (как ряд врагов в битве).
## Используется в вариантах ответа миссии (MissionChoice): выбор такого варианта
## запускает бой против противников, заданных в этом построении.
##
## Правила больших юнитов (скопированы из battle_setup):
## — обычный юнит занимает 1 позицию;
## — большой юнит (is_large) занимает позицию i И блокирует соседнюю i+1
##   (её нужно оставить пустой).

# Название построения (для удобства в инспекторе).
@export var formation_name: String = "Построение"

# 4 позиции врагов. Перетащи сюда файлы character.tres из папки Enemies/.
# Пустое поле (null) = никто не стоит на этой позиции.
@export_group("Positions")
@export var pos1: CharacterResource
@export var pos2: CharacterResource
@export var pos3: CharacterResource
@export var pos4: CharacterResource


## Возвращает массив из 4 позиций (для внутренней обработки).
func get_enemies() -> Array:
	return [pos1, pos2, pos3, pos4]

## Возвращает массив путей (res://...) к ресурсам врагов по 4 позициям.
## Формат совпадает с CombatManager.selected_enemies (Array[String], "" = пусто).
func get_enemy_paths() -> Array[String]:
	var paths: Array[String] = ["", "", "", ""]
	var slots = [pos1, pos2, pos3, pos4]
	for i in range(4):
		if slots[i] is CharacterResource:
			paths[i] = (slots[i] as CharacterResource).resource_path
	return paths

## Проверяет корректность построения по правилам больших юнитов.
## Возвращает список предупреждений (пусто = всё корректно).
func get_large_unit_warnings() -> Array:
	var warnings: Array = []
	var slots = [pos1, pos2, pos3, pos4]
	for i in range(4):
		if slots[i] is CharacterResource and (slots[i] as CharacterResource).is_large:
			if i + 1 >= 4:
				warnings.append("Большой юнит на позиции %d не помещается (нужна соседняя)." % (i + 1))
			elif slots[i + 1] != null:
				warnings.append("Позиция %d занята большим юнитом — позицию %d оставьте пустой." % [i + 1, i + 2])
	return warnings
