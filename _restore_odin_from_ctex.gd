extends SceneTree

func _init() -> void:
	var tex := ResourceLoader.load("res://.godot/imported/Odin (1).png-f92db5dd9a8f538076bd97ddda25952b.ctex")
	if tex == null:
		print("RESTORE_FAIL load")
		quit(1)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("RESTORE_FAIL image")
		quit(1)
		return
	var err := img.save_png("D:/dOCS/test/Gods/Odin/Odin_restored_from_ctex.png")
	print("RESTORE_ERR=", err, " SIZE=", img.get_width(), "x", img.get_height())
	quit(0)