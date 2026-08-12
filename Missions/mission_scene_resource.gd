extends Resource
class_name MissionSceneResource

## Сцена миссии: текст-описание + варианты ответа.
## Каждая сцена отображается как ОДНА кнопка в файле-миссии.

# Подпись кнопки в списке миссии (короткое название сцены).
@export var scene_title: String = "Сцена"
# Картинка сцены (показывается над текстом). Можно оставить пустым.
@export var image: Texture2D = null
# Основной текст сцены (описание ситуации, реплика и т.п.).
@export_multiline var body_text: String = ""
@export_group("Localization")
@export var scene_title_key: String = ""
@export var body_text_key: String = ""
@export_group("")
# Варианты ответа. Каждый — отдельная кнопка под текстом.
# Нетипизированный массив: позволяет создавать ответы ПРЯМО ВНУТРИ этого файла
# (встроенные под-ресурсы MissionChoice), без отдельных файлов.
@export var choices: Array = []
