extends Resource
class_name ThoughtsResource

## Мысли — игровой ресурс/валюта.
## Поля: название, иконка (ссылка на Texture2D), текущее количество.

@export var name: String = ""       # Название
@export var icon: Texture2D         # Ссылка на иконку
@export var amount: int = 0         # Текущее количество
