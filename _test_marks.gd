extends SceneTree

func _initialize() -> void:
	_run_tests()

func _run_tests() -> void:
	await create_timer(1.0).timeout
	var scene = load("res://battle_scene.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout
	print("TEST: scene found, marks=", scene.marks != null)
	print("TEST: marks before=", scene.marks.position_marks.size())
	# 1) Марка как от rays_of_glory: place_mark по способности
	var rays = load("res://Gods/Osiris/Rays_of_glory.tres")
	if rays:
		scene.marks.place_mark(scene.heroes_team[0] if scene.heroes_team.size() > 0 else null, rays)
	# 2) Марка как от precise_slash: ИИ-блок структура (once, enemy)
	scene.marks.add_position_mark({
		"caster": null, "team": "enemy", "position": 2,
		"type": "once", "rounds_left": 1,
		"damage_percent": 140.0, "damage_type": "Physical",
		"effect_type": "", "effect_value": 0, "effect_duration": 0,
		"icon": load("res://Gods/Susanoo/precise_slash_icon.png"),
		"triggered_units_this_round": []
	})
	print("TEST: marks after=", scene.marks.position_marks.size())
	scene._update_marks_display()
	print("TEST: mark_nodes=", scene._mark_nodes.size())
	for m in scene.marks.position_marks:
		var anchor = scene.get_node_or_null(("HeroPositions/Pos%d" if str(m.get("team","")) == "ally" else "EnemyPositions/Pos%d") % (int(m.get("position",-1)) + 1))
		print("TEST: mark team=", m.get("team"), " pos=", m.get("position"), " icon=", m.get("icon") != null, " anchor=", anchor)
	quit()
