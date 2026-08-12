extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry: DialogueSpeakerRegistry = load("res://Dialogues/speaker_profiles.tres") as DialogueSpeakerRegistry
	if registry == null:
		print("registry=null")
		quit(1)
		return
	var thor: DialogueSpeakerProfile = registry.find_profile("Тор")
	print("thor_profile=", thor != null)
	if thor != null:
		print("thor_sprite_path=", thor.default_sprite_path)
		print("thor_auto_sprite=", thor.auto_fill_sprite)
		print("thor_auto_layout=", thor.auto_fill_layout)
		print("thor_mirror=", thor.default_mirror_layout)
		print("thor_sprite_loaded=", thor.load_default_sprite() != null)
	var lena: DialogueSpeakerProfile = registry.find_profile("Лена")
	print("lena_profile=", lena != null)
	if lena != null:
		print("lena_auto_sprite=", lena.auto_fill_sprite)
		print("lena_auto_layout=", lena.auto_fill_layout)
	var player_scene: PackedScene = load("res://Dialogues/dialogue_player.tscn")
	var player: DialoguePlayer = player_scene.instantiate() as DialoguePlayer
	root.add_child(player)
	await process_frame
	var line := DialogueLine.new()
	line.speaker_name = "Тор"
	line.text = "Проверка"
	var profile: DialogueSpeakerProfile = player.call("_get_speaker_profile", line)
	var sprite: Texture2D = player.call("_get_effective_sprite", line, profile)
	var mirror: bool = player.call("_get_effective_mirror_layout", line, profile)
	print("player_profile=", profile != null)
	print("player_sprite=", sprite != null)
	print("player_mirror=", mirror)
	quit(0)