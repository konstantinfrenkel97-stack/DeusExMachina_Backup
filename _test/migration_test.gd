extends Node

## Сверка миграции legacy-полей группы A -> MissionOutcome.effects.
## Для каждого исхода из ИСХОДНЫХ сцен (res://_orig/Scenes) эмулируется старая логика
## mission_scene.gd, для МИГРИРОВАННЫХ (res://Scenes) вызывается настоящий effect.apply().
## Снимки состояния должны совпасть. Запуск:
##   godot --headless --path . -s res://_test/migration_test.gd

const ROSTER := [
	"res://Gods/Zeus/zeus.tres", "res://Gods/Thor/thor.tres",
	"res://Gods/Odin/Odin.tres", "res://Gods/Loki/Loki.tres",
]
const LEGACY_FIELDS := [
	"hero_heal_percent", "hero_hp_percent_delta", "hero_hp_flat_delta", "random_hero_hp_percent_delta",
	"hero_majesty_delta", "target_current_hp_percent_delta", "target_majesty_delta",
	"target_god_immediate_hp_percent_delta", "target_god_immediate_majesty_delta",
]
const LEGACY_ARRAYS := ["hero_buffs", "enemy_buffs", "strongest_hero_buffs", "target_buffs", "target_random_hero_buffs"]
const LEGACY_REFS := ["target_god", "target_god_immediate", "target_random_hero_preferred_god"]

var extra_paths: Dictionary = {}
var checked := 0
var mismatches := 0
var legacy_left := 0
var nontrivial := 0
var baseline: String = ""
var scenes_with_outcomes := 0


func _ready() -> void:
	var orig_root := "res://_orig/Scenes"
	var new_root := "res://Scenes"
	var rels := _list_tres(orig_root, "")
	rels.sort()
	for rel in rels:
		var a: Resource = load(orig_root + "/" + rel)
		var b: Resource = load(new_root + "/" + rel)
		if a == null or b == null:
			printerr("LOAD FAIL: ", rel, " orig=", a != null, " new=", b != null)
			mismatches += 1
			continue
		if not (a is MissionSceneResource):
			continue
		var oa: Array = []
		var ob: Array = []
		_collect_outcomes(a, oa)
		_collect_outcomes(b, ob)
		if oa.size() != ob.size():
			printerr("OUTCOME COUNT DIFF: ", rel, " ", oa.size(), " vs ", ob.size())
			mismatches += 1
			continue
		scenes_with_outcomes += 1
		for i in oa.size():
			_compare(rel, i, oa[i], ob[i])
	print("scenes=", scenes_with_outcomes, " outcomes_checked=", checked, " mismatches=", mismatches, " nontrivial=", nontrivial, " legacy_props_left_in_migrated=", legacy_left)
	get_tree().quit(1 if (mismatches > 0 or legacy_left > 0) else 0)


func _list_tres(root: String, sub: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(root + ("/" + sub if sub != "" else ""))
	if dir == null:
		return out
	for d in dir.get_directories():
		out.append_array(_list_tres(root, (sub + "/" + d) if sub != "" else d))
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append((sub + "/" + f) if sub != "" else f)
	return out


func _collect_outcomes(scene: Resource, out: Array) -> void:
	for choice in scene.get("choices"):
		if choice == null:
			continue
		for prop in ["outcome", "success_outcome", "failure_outcome"]:
			var o = choice.get(prop)
			if o != null:
				out.append(o)


# ---------------------------------------------------------------- state

func _reset_state() -> void:
	CombatManager.mission_heroes = []
	for p in ROSTER:
		CombatManager.mission_heroes.append(p)
	CombatManager.mission_dead_heroes = []
	CombatManager.pending_mission_hero_buffs = []
	CombatManager.pending_mission_enemy_buffs = []
	CombatManager.pending_mission_target_effects = []
	CombatManager.mission_team_buffs = []
	CombatManager.mission_target_buffs = []
	CombatManager.mission_strongest_hero_buffs = []
	MissionState.hero_majesty = {}
	MissionState.selected_heroes = []
	for p in ROSTER:
		MissionState.selected_heroes.append(p)
	for p in ROSTER + extra_paths.keys():
		CampaignState.set_god_current_hp(p, int(CampaignState.get_god_max_hp(p) / 2.0), CampaignState.get_god_max_hp(p))
	seed(1234)


func _bk(b) -> String:
	if b == null:
		return "null"
	return "%d:%d:%d:%s" % [int(b.stat), int(b.value), int(b.duration), str(b.percent_of_max_hp)]


func _bks(arr: Array) -> Array:
	var r: Array = []
	for b in arr:
		r.append(_bk(b))
	r.sort()
	return r


func _strongest_path() -> String:
	var best := ""
	var best_v := -1
	for p in ROSTER:
		var res: CharacterResource = CampaignState.load_character_resource(p)
		if res != null and int(res.damage) > best_v:
			best_v = int(res.damage)
			best = p
	return best


func _snapshot(strongest_legacy: Array = []) -> Dictionary:
	var snap := {}
	snap["hero_buffs"] = _bks(CombatManager.pending_mission_hero_buffs)
	snap["enemy_buffs"] = _bks(CombatManager.pending_mission_enemy_buffs)
	snap["team_buffs_until_end"] = _bks(CombatManager.mission_team_buffs)
	# per-path агрегаты "следующего боя"
	var hp := {}
	var maj := {}
	var nb := {}
	for e in CombatManager.pending_mission_target_effects:
		var p: String = e["resource_path"]
		hp[p] = int(hp.get(p, 0)) + int(e.get("current_hp_percent_delta", 0))
		maj[p] = int(maj.get(p, 0)) + int(e.get("majesty_delta", 0))
		if not nb.has(p):
			nb[p] = []
		nb[p].append_array(_bks(e.get("buffs", [])))
	var until := {}
	for e in CombatManager.mission_target_buffs:
		var p: String = e["resource_path"]
		if not until.has(p):
			until[p] = []
		until[p].append_array(_bks(e["buffs"]))
	# legacy "strongest" -> эквивалент "mission_target_buffs у сильнейшего" (тайминг меняется осознанно)
	if not strongest_legacy.is_empty():
		var sp := _strongest_path()
		if not until.has(sp):
			until[sp] = []
		until[sp].append_array(_bks(strongest_legacy))
	for k in nb.keys():
		nb[k].sort()
	for k in until.keys():
		until[k].sort()
	var hp_clean := {}
	for k in hp.keys():
		if hp[k] != 0 or maj[k] != 0 or not nb[k].is_empty():
			hp_clean[k] = [hp[k], maj[k], nb[k]]
	snap["next_battle_target"] = hp_clean
	snap["until_end_target"] = until
	var gods := {}
	for p in ROSTER + extra_paths.keys():
		gods[p] = [CampaignState.get_god_current_hp(p), MissionState.get_hero_majesty(p)]
	snap["gods"] = gods
	return snap


# --------------------------------------------------------------- legacy

func _g(o, name: String, d = 0):
	var v = o.get(name)
	return d if v == null else v


func _alive_roster() -> Array:
	var c: Array = []
	for hp in CombatManager.mission_heroes:
		var p := str(hp).strip_edges()
		if p == "" or CombatManager.mission_dead_heroes.has(p) or CampaignState.get_god_current_hp(p) <= 0:
			continue
		c.append(p)
	return c


func _legacy_apply(o) -> void:
	var heal: int = int(_g(o, "hero_heal_percent"))
	if heal != 0:
		for p in _alive_roster():
			var eff := heal
			if CampaignState.god_has_item_effect(p, "stone_face_bonus_heal"):
				eff += 2
			var mx := CampaignState.get_god_max_hp(p)
			var d := int(round(float(mx) * float(eff) / 100.0))
			if d == 0:
				d = 1 if eff > 0 else -1
			CampaignState.set_god_current_hp(p, CampaignState.get_god_current_hp(p) + d, mx)
	var rb: Array = _g(o, "target_random_hero_buffs", [])
	if not rb.is_empty():
		var cand := _alive_roster()
		if not cand.is_empty():
			var pref = _g(o, "target_random_hero_preferred_god", null)
			var tp := ""
			if pref != null:
				var pp := str(pref.resource_path)
				if cand.has(pp):
					tp = pp
			if tp == "":
				tp = cand[randi_range(0, cand.size() - 1)]
			if bool(_g(o, "target_random_hero_buffs_until_mission_end", false)):
				CombatManager.mission_target_buffs.append({"resource_path": tp, "buffs": rb})
			else:
				CombatManager.pending_mission_target_effects.append({"resource_path": tp, "current_hp_percent_delta": 0, "majesty_delta": 0, "buffs": rb})
	var rhp: int = int(_g(o, "random_hero_hp_percent_delta"))
	if rhp != 0:
		var cand2 := _alive_roster()
		if not cand2.is_empty():
			var tp2: String = cand2[randi_range(0, cand2.size() - 1)]
			var mx2 := CampaignState.get_god_max_hp(tp2)
			var d2 := int(round(float(mx2) * float(rhp) / 100.0))
			if d2 == 0:
				d2 = 1 if rhp > 0 else -1
			CampaignState.set_god_current_hp(tp2, CampaignState.get_god_current_hp(tp2) + d2, mx2)
	var thp: int = int(_g(o, "hero_hp_percent_delta"))
	if thp != 0:
		for p in _alive_roster():
			var mx3 := CampaignState.get_god_max_hp(p)
			var d3 := int(round(float(mx3) * float(thp) / 100.0))
			if d3 == 0:
				d3 = 1 if thp > 0 else -1
			CampaignState.set_god_current_hp(p, CampaignState.get_god_current_hp(p) + d3, mx3)
	var flat: int = int(_g(o, "hero_hp_flat_delta"))
	if flat != 0:
		for p in _alive_roster():
			CampaignState.set_god_current_hp(p, CampaignState.get_god_current_hp(p) + flat, CampaignState.get_god_max_hp(p))
	var maj: int = int(_g(o, "hero_majesty_delta"))
	if maj != 0:
		MissionState.add_majesty_to_selected_heroes(maj)
	var ig = _g(o, "target_god_immediate", null)
	if ig != null:
		var ip: String = str(ig.resource_path)
		extra_paths[ip] = true
		if ip != "" and not CampaignState.is_god_dead(ip):
			var ih: int = int(_g(o, "target_god_immediate_hp_percent_delta"))
			var im: int = int(_g(o, "target_god_immediate_majesty_delta"))
			if ih != 0:
				var imx := CampaignState.get_god_max_hp(ip)
				var ia := int(round(float(imx) * float(ih) / 100.0))
				if ia == 0:
					ia = 1 if ih > 0 else -1
				CampaignState.set_god_current_hp(ip, CampaignState.get_god_current_hp(ip) + ia, imx)
			if im != 0:
				MissionState.add_hero_majesty(ip, im)
	var until_team: bool = bool(_g(o, "hero_buffs_until_mission_end", false))
	for b in _g(o, "hero_buffs", []):
		if b != null:
			if until_team:
				CombatManager.mission_team_buffs.append(b)
			else:
				CombatManager.pending_mission_hero_buffs.append(b)
	for b in _g(o, "enemy_buffs", []):
		if b != null:
			CombatManager.pending_mission_enemy_buffs.append(b)
	for b in _g(o, "strongest_hero_buffs", []):
		if b != null:
			CombatManager.mission_strongest_hero_buffs.append(b)
	var tg = _g(o, "target_god", null)
	if tg != null:
		var tpath: String = str(tg.resource_path)
		extra_paths[tpath] = true
		if tpath != "":
			var tbuffs: Array = _g(o, "target_buffs", [])
			var t_until: bool = bool(_g(o, "target_buffs_until_mission_end", false))
			var thp2: int = int(_g(o, "target_current_hp_percent_delta"))
			var tmj: int = int(_g(o, "target_majesty_delta"))
			if thp2 != 0 or tmj != 0 or (not t_until and tbuffs.size() > 0):
				CombatManager.pending_mission_target_effects.append({
					"resource_path": tpath, "current_hp_percent_delta": thp2, "majesty_delta": tmj,
					"buffs": ([] if t_until else tbuffs)})
			if t_until and tbuffs.size() > 0:
				CombatManager.mission_target_buffs.append({"resource_path": tpath, "buffs": tbuffs})


func _compare(rel: String, idx: int, orig, migrated) -> void:
	checked += 1
	# учесть сюжетных богов (вне ростера) заранее, чтобы снимки сравнивали одинаковый набор
	for ref in ["target_god", "target_god_immediate"]:
		var g = orig.get(ref)
		if g != null:
			extra_paths[str(g.resource_path)] = true
	# 1) в мигрированном не осталось legacy-значений
	for f in LEGACY_FIELDS:
		var v = migrated.get(f)
		if v != null and int(v) != 0:
			legacy_left += 1
			printerr("LEGACY LEFT: ", rel, "#", idx, " ", f, "=", v)
	for f in LEGACY_ARRAYS:
		var v2 = migrated.get(f)
		if v2 != null and not (v2 as Array).is_empty():
			legacy_left += 1
			printerr("LEGACY LEFT: ", rel, "#", idx, " ", f)
	for f in LEGACY_REFS:
		if migrated.get(f) != null:
			legacy_left += 1
			printerr("LEGACY LEFT: ", rel, "#", idx, " ", f)
	# 2) снимки
	_reset_state()
	_legacy_apply(orig)
	for e0 in _g(orig, "effects", []):
		if e0 != null:
			e0.apply()
	var s_legacy := _snapshot(_g(orig, "strongest_hero_buffs", []))
	_reset_state()
	for e in _g(migrated, "effects", []):
		if e != null:
			e.apply()
	var s_new := _snapshot()
	_reset_state()
	var s_empty := JSON.stringify(_snapshot(), "", true)
	if JSON.stringify(s_legacy, "", true) != s_empty:
		nontrivial += 1
	if JSON.stringify(s_legacy, "", true) != JSON.stringify(s_new, "", true):
		mismatches += 1
		printerr("MISMATCH: ", rel, "#", idx)
		printerr("  legacy: ", JSON.stringify(s_legacy, "", true))
		printerr("  new:    ", JSON.stringify(s_new, "", true))
