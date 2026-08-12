extends SceneTree

## Проверка компиляции изменённых скриптов в контексте проекта (с глобалами/автозагрузками).
func _init():
	var files = [
		"res://battle_scene.gd",
		"res://battle_marks.gd",
		"res://combatant.gd",
		"res://Missions/mission_scene.gd",
		"res://combat_manager.gd",
	]
	var ok = true
	for f in files:
		var s = load(f)
		if s == null:
			ok = false
			print("FAIL load: ", f)
		else:
			print("OK: ", f)
	print("RESULT: ", "ALL_SCRIPTS_OK" if ok else "HAS_FAILURES")
	quit(0 if ok else 1)
