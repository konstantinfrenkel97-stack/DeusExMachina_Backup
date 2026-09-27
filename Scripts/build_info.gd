extends RefCounted
class_name BuildInfo

## Версия сборки, показывается мелким текстом в углу главного меню (см. main_menu.gd)
## и печатается в лог при старте — чтобы можно было по .exe узнать, из какого коммита
## он собран (см. пункт про "раздаваемая сборка не совпадает с веткой" в дневнике
## разработки). Обновляется вручную перед каждым релизным экспортом: скопировать
## актуальный `git rev-parse --short HEAD` и сегодняшнюю дату сюда, затем собрать .exe.
const COMMIT_HASH := "b8c7b31"
const BUILT_AT := "2026-09-27"

static func label_text() -> String:
	return "Godmaker · %s · %s" % [COMMIT_HASH, BUILT_AT]
