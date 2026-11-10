extends Node
var fails := 0
func _ready() -> void:
	var ms = load("res://Missions/mission_scene.gd")
	if ms == null or not ms.can_instantiate():
		fails += 1; printerr("mission_scene.gd compile FAIL")
	var n := 0; var fx := 0
	for rel in _list("res://Scenes"):
		print("LOADING ", rel)
		var r = load(rel)
		if r == null:
			fails += 1; printerr("LOAD FAIL ", rel); continue
		if not (r is MissionSceneResource): continue
		n += 1
		for c in r.choices:
			if c == null: continue
			for pr in ["outcome", "success_outcome", "failure_outcome"]:
				var o = c.get(pr)
				if o == null: continue
				CombatManager.mission_heroes = ["res://Gods/Zeus/zeus.tres", "res://Gods/Thor/thor.tres"]
				for e in o.effects:
					if e == null:
						fails += 1; printerr("NULL effect ", rel); continue
					e.apply(); fx += 1
	# unit: STRONGEST_ATTACK/ARMOR
	CombatManager.mission_heroes = ["res://Gods/Zeus/zeus.tres", "res://Gods/Thor/thor.tres", "res://Gods/Odin/Odin.tres", "res://Gods/Loki/Loki.tres"]
	CombatManager.mission_dead_heroes = []
	for p in CombatManager.mission_heroes:
		CampaignState.set_god_current_hp(p, 10, 100)
	var e := HeroBuffEffect.new()
	for t in [HeroTargetEffect.Target.STRONGEST_ATTACK, HeroTargetEffect.Target.STRONGEST_ARMOR, HeroTargetEffect.Target.RANDOM, HeroTargetEffect.Target.TEAM]:
		e.target = t
		print("target ", t, " -> ", e._resolve_target_paths())
	var best := ""; var bv := -1
	for p in CombatManager.mission_heroes:
		var rr = CampaignState.load_character_resource(p)
		if rr.damage > bv: bv = rr.damage; best = p
	e.target = HeroTargetEffect.Target.STRONGEST_ATTACK
	if e._resolve_target_paths() != [best]: fails += 1; printerr("STRONGEST_ATTACK wrong")
	print("scenes=", n, " effects_applied=", fx, " fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
func _list(root: String) -> Array:
	var out := []
	var d := DirAccess.open(root)
	for s in d.get_directories(): out.append_array(_list(root + "/" + s))
	for f in d.get_files():
		if f.ends_with(".tres"): out.append(root + "/" + f)
	return out
