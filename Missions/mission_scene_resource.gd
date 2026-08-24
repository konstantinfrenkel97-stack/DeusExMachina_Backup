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
# Типизированный массив MissionChoice: при "Add Element" в инспекторе Godot
# сразу предлагает создать MissionChoice, не нужно искать тип вручную.
# Ответы всё так же можно встраивать ПРЯМО ВНУТРИ этого файла (как под-ресурсы),
# отдельные файлы не обязательны — типизация массива этому не мешает.
@export var choices: Array[MissionChoice] = []
