extends SceneTree

func _initialize() -> void:
	var arr := ["Природа", "Смерть"]
	arr.sort()
	print("nature_death_key=", "%s|%s" % [arr[0], arr[1]])
	var arr2 := ["Власть", "Смерть"]
	arr2.sort()
	print("power_death_key=", "%s|%s" % [arr2[0], arr2[1]])
	quit()