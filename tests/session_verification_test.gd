extends SceneTree

## ════════════════════════════════════════════════════════════════
##  Автотест правок из сессии (Мумия, Водяной, Леший, Пушка,
##  Кикимора, Пегас, Оборотень, Топь, CombatCalculator, Флибустьер).
##
##  Запуск (из корня проекта, в PowerShell/cmd):
##    Godot_v4.6.3-stable_win64_console.exe --headless --script res://tests/session_verification_test.gd
##
##  Результат печатается построчно PASS/FAIL и в самом конце — итог.
##  Скрипт не требует GUT — использует тот же приём, что и уже
##  существующие в проекте _test_marks.gd / _verify_mechs.gd
##  (extends SceneTree, headless --script).
## ════════════════════════════════════════════════════════════════

var _pass := 0
var _fail := 0
var scene  # реальная инстанцированная battle_scene.tscn


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	print("\n════════ 0. Компиляция изменённых скриптов ════════")
	_check_compiles([
		"res://battle_scene.gd",
		"res://battle_marks.gd",
		"res://combatant.gd",
		"res://character_resource.gd",
		"res://ability_resource.gd",
		"res://combat_manager.gd",
		"res://Scripts/combat_calculator.gd",
		"res://Enemy_logic/mummy_logic.gd",
		"res://Enemy_logic/vodyanoy_logic.gd",
		"res://Enemy_logic/leshy_logic.gd",
	])

	print("\n════════ 1. CombatCalculator (чистая логика) ════════")
	_test_combat_calculator()

	print("\n════════ 2. Combatant.apply_stat_change / tick_effects ════════")
	_test_combatant_core()

	print("\n════════ 3. Инстанцирование battle_scene.tscn ════════")
	scene = load("res://battle_scene.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	_check("battle_scene.tscn инстанцирован", scene != null and scene.marks != null)

	print("\n════════ 4. BattleMarks: Мумия «Древнее проклятие» / Водяной «Болотное царство» ════════")
	_test_battle_marks()

	print("\n════════ 5. ИИ: Мумия / Водяной / Леший ════════")
	_test_ai_logic()

	print("\n════════ 6. Пушка: урон по позиции цели ════════")
	_test_cannon_position_damage()

	print("\n════════ 7. Кикимора: +1 к длительности дебаффов союзной команды ════════")
	_test_kikimora_debuff_duration()

	print("\n════════ 8. Пегас: бонус при БЮБОМ баффе союзника ════════")
	_test_pegasus_ally_buff()

	print("\n════════ 9. Оборотень: бонус с 3-го раунда (идемпотентно) ════════")
	_test_oboroten_round3()

	print("\n════════ 10. Топь: стаки, уклонение, Русалка-утопленница, Водяной-стан ════════")
	_test_swamp_location()

	print("\n════════════════════════════════════")
	print("ИТОГО: PASS=%d  FAIL=%d" % [_pass, _fail])
	print("РЕЗУЛЬТАТ: %s" % ("ALL_TESTS_PASSED" if _fail == 0 else "HAS_FAILURES"))
	print("════════════════════════════════════\n")
	quit(0 if _fail == 0 else 1)


# ────────────────────────────────────────────────────────────────
#  Утилиты
# ────────────────────────────────────────────────────────────────

func _check(label: String, condition: bool, extra: String = "") -> void:
	if condition:
		_pass += 1
		print("  PASS: %s" % label)
	else:
		_fail += 1
		print("  FAIL: %s%s" % [label, ("  (" + extra + ")") if extra != "" else ""])


func _check_compiles(files: Array) -> void:
	for f in files:
		var s = load(f)
		_check("компилируется: %s" % f, s != null)


func _new_char_resource(unit_name: String, hp: int, dmg: int, armor: int, acc: int, eva: int, crit: float, special: String = "", is_enemy: bool = true) -> CharacterResource:
	var r := CharacterResource.new()
	r.unit_name = unit_name
	r.max_hp = hp
	r.damage = dmg
	r.armor = armor
	r.accuracy = acc
	r.evasion = eva
	r.crit_chance = crit
	r.initiative = 5
	r.is_enemy = is_enemy
	r.special_effect_type = special
	return r


func _new_combatant(unit_name: String, hp: int, dmg: int, armor: int, acc: int, eva: int, crit: float, special: String = "", is_enemy: bool = true, position_index: int = 0) -> Combatant:
	var c := Combatant.new(_new_char_resource(unit_name, hp, dmg, armor, acc, eva, crit, special, is_enemy))
	c.position_index = position_index
	return c


func _new_ability(damage_modifier: float = 1.0, never_miss: bool = true, damage_type: String = "Physical") -> AbilityResource:
	var a := AbilityResource.new()
	a.damage_modifier = damage_modifier
	a.never_miss = never_miss
	a.damage_type = damage_type
	a.target_type = "Enemy"
	a.targetable_positions = [true, true, true, true]
	a.usable_from_positions = [true, true, true, true]
	return a


# ────────────────────────────────────────────────────────────────
#  1. CombatCalculator
# ────────────────────────────────────────────────────────────────

func _test_combat_calculator() -> void:
	# giant_armor_pierce: должен вдвое срезать броню и в calculate_ability_damage (не только в forced_hit)
	var attacker := _new_combatant("Каменный страж", 999, 100, 0, 999, 0, 0.0, "giant_armor_pierce")
	var target_normal := _new_combatant("Цель", 999, 0, 50, 0, 0, 0.0)
	var ability := _new_ability(1.0, false, "Physical")  # never_miss=false -> идёт через calculate_ability_damage
	var r1 := CombatCalculator.calculate_ability_damage(attacker, target_normal, ability)
	_check("calculate_ability_damage: попадание гарантировано (accuracy 999 vs evasion 0)", r1.is_hit)
	# apply_armor(100, 50) = 100 * (1 - 0.5) = 50 (обычный урон, без пробития)
	var attacker_normal := _new_combatant("Обычный атакующий", 999, 100, 0, 999, 0, 0.0, "")
	var r2 := CombatCalculator.calculate_ability_damage(attacker_normal, target_normal, ability)
	_check("giant_armor_pierce уменьшает урон от брони вдвое по сравнению с обычным атакующим", r1.final_damage > r2.final_damage,
		"giant=%d normal=%d (ожидалось giant > normal, т.к. пробитая броня режет меньше урона)" % [r1.final_damage, r2.final_damage])
	_check("giant_armor_pierce: точное значение урона = %d (броня 50%% -> эффективная 25%%)" % int(100 * 0.75), r1.final_damage == int(100 * 0.75),
		"получено %d" % r1.final_damage)
	_check("обычный атакующий: точное значение урона = 50 (полная броня 50%%)", r2.final_damage == 50, "получено %d" % r2.final_damage)

	# nanau_bloodlust: +50% урона по целям с periodic_damage
	var nanau := _new_combatant("Нанауэ", 999, 100, 0, 999, 0, 0.0, "nanau_bloodlust")
	var dot_target := _new_combatant("Цель с DoT", 999, 0, 0, 0, 0, 0.0)
	dot_target.active_effects.append({"stat": "periodic_damage", "value": 5, "duration": 2})
	var r3 := CombatCalculator.calculate_ability_damage(nanau, dot_target, ability)
	_check("nanau_bloodlust: +50%% урона по цели с periodic_damage (100 -> 150)", r3.final_damage == 150, "получено %d" % r3.final_damage)

	# calculate_forced_hit_damage: никогда не промахивается, тоже учитывает giant_armor_pierce
	var r4 := CombatCalculator.calculate_forced_hit_damage(attacker, target_normal, ability)
	_check("calculate_forced_hit_damage: всегда попадание", r4.is_hit)
	_check("calculate_forced_hit_damage: giant_armor_pierce тоже работает (урон 75)", r4.final_damage == 75, "получено %d" % r4.final_damage)


# ────────────────────────────────────────────────────────────────
#  2. Combatant
# ────────────────────────────────────────────────────────────────

func _test_combatant_core() -> void:
	var c := _new_combatant("Тест-юнит", 100, 20, 10, 90, 10, 0.05)
	c.apply_stat_change("armor", 15)
	_check("apply_stat_change('armor', 15): armor 10 -> 25", c.armor == 25, "получено %d" % c.armor)
	c.apply_stat_change("damage", -5)
	_check("apply_stat_change('damage', -5): damage 20 -> 15", c.damage == 15, "получено %d" % c.damage)
	c.apply_stat_change("crit", 20)
	_check("apply_stat_change('crit', 20): 0.05 -> ~0.25", absf(c.crit_chance - 0.25) < 0.001, "получено %f" % c.crit_chance)

	# tick_effects: временный эффект должен реверснуться при duration==0
	var c2 := _new_combatant("Тест-юнит-2", 100, 20, 10, 90, 10, 0.05)
	c2.apply_stat_change("armor", -8)
	c2.active_effects.append({"stat": "armor", "value": -8, "duration": 1})
	c2.snapshot_turn_start_effects()
	c2.tick_effects()
	_check("tick_effects: временный дебафф брони (-8, duration 1) реверсируется и снимается", c2.armor == 10 and c2.active_effects.is_empty(),
		"armor=%d effects_left=%d" % [c2.armor, c2.active_effects.size()])

	# duration == -1 (перманентный) не должен реверсироваться tick_effects'ом
	var c3 := _new_combatant("Тест-юнит-3", 100, 20, 10, 90, 10, 0.05)
	c3.apply_stat_change("armor", -8)
	c3.active_effects.append({"stat": "armor", "value": -8, "duration": -1, "effect_id": "mummy_ancient_curse_mark"})
	c3.snapshot_turn_start_effects()
	c3.tick_effects()
	_check("tick_effects: перманентный эффект (duration -1, напр. проклятие Мумии) НЕ снимается", c3.armor == 2 and c3.active_effects.size() == 1,
		"armor=%d effects_left=%d" % [c3.armor, c3.active_effects.size()])


# ────────────────────────────────────────────────────────────────
#  3-4. BattleMarks: Мумия / Водяной
# ────────────────────────────────────────────────────────────────

func _test_battle_marks() -> void:
	var caster := _new_combatant("Мумия", 100, 30, 5, 80, 5, 0.05, "", true)

	# --- Мумия: «Древнее проклятие» ---
	var target := _new_combatant("Герой (проклят)", 100, 20, 20, 80, 10, 0.05, "", false)
	var mark := {
		"caster": caster, "team": "ally", "position": 0,
		"type": "persistent", "rounds_left": 999,
		"damage_percent": 0.0, "damage_type": "Pure",
		"effect_type": "mummy_ancient_curse_mark", "effect_value": 2, "effect_duration": -1,
		"icon": null, "triggered_units_this_round": []
	}
	scene.marks.apply_mark_to_unit(mark, target, true)
	_check("Мумия: проклятие даёт -2 урона (20 -> 18)", target.damage == 18, "получено %d" % target.damage)
	_check("Мумия: проклятие даёт -2 брони (20 -> 18)", target.armor == 18, "получено %d" % target.armor)
	# Повторное применение НЕ должно складываться (идемпотентность)
	scene.marks.apply_mark_to_unit(mark, target, true)
	_check("Мумия: повторное применение проклятия не стакается (урон остаётся 18, не 16)", target.damage == 18, "получено %d" % target.damage)

	# --- Водяной: «Болотное царство» — копирует эффект Топи, только если локация "swamp" ---
	CombatManager.selected_location_id = ""
	var hero_no_swamp := _new_combatant("Герой (без Топи)", 100, 20, 20, 80, 10, 0.05, "", false)
	var vod_mark := {
		"caster": caster, "team": "ally", "position": 0,
		"type": "persistent", "rounds_left": 5,
		"damage_percent": 0.0, "damage_type": "Physical",
		"effect_type": "copy_location_effect", "effect_value": 0, "effect_duration": 1,
		"icon": null, "triggered_units_this_round": []
	}
	scene.marks.apply_mark_to_unit(vod_mark, hero_no_swamp, true)
	_check("Водяной: марка не действует ВНЕ локации Топь (броня/уклонение не тронуты)",
		hero_no_swamp.armor == 20 and hero_no_swamp.evasion == 10,
		"armor=%d evasion=%d" % [hero_no_swamp.armor, hero_no_swamp.evasion])

	CombatManager.selected_location_id = "swamp"
	var hero_swamp := _new_combatant("Герой (в Топи)", 100, 20, 20, 80, 10, 0.05, "", false)
	scene.enemies_team = [caster, null, null, null]
	scene.marks.apply_mark_to_unit(vod_mark, hero_swamp, true)
	_check("Водяной: в Топи марка снимает -5 брони и -5 уклонения (без Утопленниц)",
		hero_swamp.armor == 15 and hero_swamp.evasion == 5,
		"armor=%d evasion=%d" % [hero_swamp.armor, hero_swamp.evasion])

	# Утопленница усиливает эффект на 5% за штуку
	var utop1 := _new_combatant("Утопленница 1", 50, 10, 5, 70, 5, 0.05, "utoplennitsa_location_amplify", true)
	var utop2 := _new_combatant("Утопленница 2", 50, 10, 5, 70, 5, 0.05, "utoplennitsa_location_amplify", true)
	scene.enemies_team = [caster, utop1, utop2, null]
	var hero_swamp2 := _new_combatant("Герой (в Топи, 2 Утопленницы)", 100, 20, 20, 80, 10, 0.05, "", false)
	scene.marks.apply_mark_to_unit(vod_mark, hero_swamp2, true)
	# 5 * (1 + 0.05*2) = 5.5 -> round -> 6
	_check("Водяной: 2 Утопленницы усиливают эффект марки (5 -> 6 брони/уклонения)",
		hero_swamp2.armor == 14 and hero_swamp2.evasion == 4,
		"armor=%d evasion=%d (ожидалось armor=14 evasion=4)" % [hero_swamp2.armor, hero_swamp2.evasion])


# ────────────────────────────────────────────────────────────────
#  5. ИИ: Мумия / Водяной / Леший
# ────────────────────────────────────────────────────────────────

func _test_ai_logic() -> void:
	# Мумия: не должна перекастовывать проклятие, если герой уже помечен
	var mummy := _new_combatant("Мумия-ИИ", 100, 30, 5, 80, 5, 0.05, "", true)
	var curse_ab := _new_ability(1.0, false)
	curse_ab.ability_marker = "mummy_ancient_curse"
	curse_ab.name = "Древнее проклятие"
	curse_ab.usable_from_positions = [true, true, true, true]
	curse_ab.mark_type_int = 2
	mummy.active_abilities = [curse_ab]
	var hero_cursed := _new_combatant("Герой (уже проклят)", 100, 20, 10, 80, 10, 0.05, "", false)
	hero_cursed.active_effects.append({"stat": "damage", "value": -2, "duration": -1, "effect_id": "mummy_ancient_curse_mark"})
	var decision := MummyLogic.get_decision(mummy, [hero_cursed])
	_check("MummyLogic: не перекастовывает проклятие на уже проклятого героя (падает в random_usable)",
		decision.is_empty() or decision.get("ability") != curse_ab)

	# Водяной: mark_active проверяется по effect_id "bolotnoe_tsarstvo_mark" на герое
	var vod := _new_combatant("Водяной-ИИ", 100, 25, 5, 80, 5, 0.05, "", true)
	var mark_ab := _new_ability(1.0, false)
	mark_ab.ability_marker = "bolotnoe_tsarstvo"
	mark_ab.usable_from_positions = [true, true, true, true]
	vod.active_abilities = [mark_ab]
	var hero_marked := _new_combatant("Герой (помечен Водяным)", 100, 20, 10, 80, 10, 0.05, "", false)
	hero_marked.active_effects.append({"stat": "armor", "value": -5, "duration": 1, "effect_id": "bolotnoe_tsarstvo_mark"})
	var mark_still_seen := false
	for e in hero_marked.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "bolotnoe_tsarstvo_mark":
			mark_still_seen = true
	_check("VodyanoyLogic: effect_id 'bolotnoe_tsarstvo_mark' корректно виден на герое (сам механизм проверки)", mark_still_seen)

	# Леший: подсчёт стаков дебаффа локации читает "swamp_debuff"/"stacks"
	var hero_stacked := _new_combatant("Герой (3 стака Топи)", 100, 20, 10, 80, 10, 0.05, "", false)
	hero_stacked.active_effects.append({"stat": "location_debuff", "value": 0, "duration": -1, "effect_id": "swamp_debuff", "stacks": 3})
	var stacks := LeshyLogic._count_location_debuffs(hero_stacked)
	_check("LeshyLogic._count_location_debuffs: читает 3 стака из swamp_debuff/stacks", stacks == 3, "получено %d" % stacks)


# ────────────────────────────────────────────────────────────────
#  6. Пушка
# ────────────────────────────────────────────────────────────────

func _test_cannon_position_damage() -> void:
	var cannon := _new_combatant("Пушка", 100, 100, 0, 999, 0, 0.0, "cannon_position_damage", true)
	cannon.position_index = 0
	var ability := _new_ability(1.0, true, "Physical")  # never_miss -> детерминированный урон
	scene.enemies_team = [cannon, null, null, null]

	var expected := {0: 80, 1: 100, 2: 120, 3: 150}
	for pos in expected.keys():
		var target := _new_combatant("Цель на позиции %d" % (pos + 1), 999, 0, 0, 0, 0, 0.0, "", false)
		target.position_index = pos
		scene.heroes_team = [target, null, null, null]
		var hp_before := target.current_hp
		scene._use_ability(cannon, target, ability)
		var dealt := hp_before - target.current_hp
		_check("Пушка: позиция %d -> урон %d" % [pos + 1, expected[pos]], dealt == expected[pos],
			"ожидалось %d, получено %d" % [expected[pos], dealt])


# ────────────────────────────────────────────────────────────────
#  7. Кикимора
# ────────────────────────────────────────────────────────────────

func _test_kikimora_debuff_duration() -> void:
	var ability := _new_ability(1.0, true)
	ability.effect_types = ["target_debuff_armor"]
	var _vals: Dictionary[String, int] = {"target_debuff_armor": 10}
	ability.effect_values = _vals
	var _durs: Dictionary[String, int] = {"target_debuff_armor": 2}
	ability.effect_durations = _durs

	# Без Кикиморы в команде — duration остаётся 2
	var attacker_plain := _new_combatant("Атакующий (без Кикиморы)", 100, 20, 5, 80, 10, 0.05, "", true)
	scene.enemies_team = [attacker_plain, null, null, null]
	scene.heroes_team = [null, null, null, null]
	var target1 := _new_combatant("Цель 1", 100, 20, 10, 80, 10, 0.05, "", false)
	scene._apply_effect_to_target(attacker_plain, target1, "target_debuff_armor", ability)
	var dur1 = target1.active_effects.back().get("duration", -99) if not target1.active_effects.is_empty() else -99
	_check("Кикимора: без неё в команде длительность дебаффа = 2", dur1 == 2, "получено %s" % str(dur1))

	# С Кикиморой в той же команде, что и атакующий — duration должна стать 3
	var kikimora := _new_combatant("Кикимора", 80, 15, 5, 80, 10, 0.05, "kikimora_extended_debuffs", true)
	var attacker2 := _new_combatant("Атакующий (с Кикиморой)", 100, 20, 5, 80, 10, 0.05, "", true)
	scene.enemies_team = [attacker2, kikimora, null, null]
	var target2 := _new_combatant("Цель 2", 100, 20, 10, 80, 10, 0.05, "", false)
	scene._apply_effect_to_target(attacker2, target2, "target_debuff_armor", ability)
	var dur2 = target2.active_effects.back().get("duration", -99) if not target2.active_effects.is_empty() else -99
	_check("Кикимора: с ней в команде атакующего длительность дебаффа = 3 (на 1 больше)", dur2 == 3, "получено %s" % str(dur2))


# ────────────────────────────────────────────────────────────────
#  8. Пегас
# ────────────────────────────────────────────────────────────────

func _test_pegasus_ally_buff() -> void:
	var pegasus := _new_combatant("Пегас", 100, 20, 10, 80, 10, 0.05, "pegasus_ally_buff", false)
	var ally := _new_combatant("Союзник Пегаса", 100, 15, 10, 80, 10, 0.05, "", false)
	scene.heroes_team = [pegasus, ally, null, null]
	var dmg_before := pegasus.damage
	scene._check_pegasus_ally_buff(ally)
	_check("Пегас: получает +5 атаки при ЛЮБОМ баффе союзника", pegasus.damage == dmg_before + 5,
		"было %d, стало %d" % [dmg_before, pegasus.damage])


# ────────────────────────────────────────────────────────────────
#  9. Оборотень
# ────────────────────────────────────────────────────────────────

func _test_oboroten_round3() -> void:
	var oboroten := _new_combatant("Оборотень", 100, 20, 10, 80, 10, 0.05, "oboroten_round3_power", true)
	scene.enemies_team = [oboroten, null, null, null]
	scene.heroes_team = [null, null, null, null]
	var dmg_before := oboroten.damage
	var eva_before := oboroten.evasion
	var crit_before := oboroten.crit_chance
	scene._apply_oboroten_round3_power()
	_check("Оборотень: +30 урона/уклонения/удачи применяется",
		oboroten.damage == dmg_before + 30 and oboroten.evasion == eva_before + 30 and absf(oboroten.crit_chance - (crit_before + 0.30)) < 0.001,
		"damage=%d evasion=%d crit=%f" % [oboroten.damage, oboroten.evasion, oboroten.crit_chance])
	# Повторный вызов не должен повторно применять бонус
	scene._apply_oboroten_round3_power()
	_check("Оборотень: повторный вызов НЕ дублирует бонус (идемпотентность)", oboroten.damage == dmg_before + 30,
		"получено %d (ожидалось %d)" % [oboroten.damage, dmg_before + 30])


# ────────────────────────────────────────────────────────────────
#  10. Топь
# ────────────────────────────────────────────────────────────────

func _test_swamp_location() -> void:
	CombatManager.selected_location_id = "swamp"
	var hero := _new_combatant("Герой в Топи", 200, 20, 30, 80, 30, 0.05, "", false)
	scene.heroes_team = [hero, null, null, null]
	scene.enemies_team = [null, null, null, null]
	scene._swamp_tracked_unit = null
	scene._swamp_init_loss = 0
	scene._swamp_armor_loss = 0
	scene._swamp_evasion_loss = 0
	scene._swamp_consecutive_rounds = 0

	scene._location_swamp()
	scene._location_swamp()
	scene._location_swamp()

	var stack_entry = null
	for e in hero.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "swamp_debuff":
			stack_entry = e
	_check("Топь: после 3 раундов на герое висит swamp_debuff со стеком 3", stack_entry != null and int(stack_entry.get("stacks", 0)) == 3,
		"stack_entry=%s" % str(stack_entry))
	_check("Топь: броня и уклонение снижены на 15 (5 x 3 раунда)", hero.armor == 15 and hero.evasion == 15,
		"armor=%d evasion=%d" % [hero.armor, hero.evasion])
	_check("Топь: герой ещё не оглушён (Водяного в команде нет)", not hero.is_stunned)

	# Теперь с Водяным в команде — на 3-й раунд подряд должен оглушить
	var hero2 := _new_combatant("Герой в Топи (с Водяным)", 200, 20, 30, 80, 30, 0.05, "", false)
	var vodyanoy := _new_combatant("Водяной", 100, 25, 5, 80, 5, 0.05, "vodyanoy_location_stun", true)
	scene.heroes_team = [hero2, null, null, null]
	scene.enemies_team = [vodyanoy, null, null, null]
	scene._swamp_tracked_unit = null
	scene._swamp_init_loss = 0
	scene._swamp_armor_loss = 0
	scene._swamp_evasion_loss = 0
	scene._swamp_consecutive_rounds = 0
	scene._location_swamp()
	scene._location_swamp()
	scene._location_swamp()
	_check("Топь + Водяной: после 3 раундов подряд герой оглушён", hero2.is_stunned)
