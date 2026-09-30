extends RefCounted
class_name BattlePassives

## Пассивные способности и ауры юнитов, призывы, вуду, Орочи/Кракен, отражение урона.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Применяет позиционные ауры Каппа к нужному союзнику.
## Вызывается в начале каждого хода и после перемещений.
func _apply_kappa_auras():
	# Сначала сбрасываем все ауры Каппы (они пересчитываются каждый раз)
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "kappa_warrior_aura" or eid == "kappa_shaman_aura":
				var stat = Combatant._effect_get(unit.active_effects[i], "stat", "")
				var val  = Combatant._effect_get(unit.active_effects[i], "value", 0)
				unit.apply_stat_change(stat, -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	
	# Накладываем заново от живых Каппа-юнитов
	for team in [_scene.heroes_team, _scene.enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			match unit.special_effect_type:
				"kappa_warrior":
					var behind = _scene._get_unit_at_position(team, unit.position_index + 1)
					if behind:
						var aura_val = 10
						behind.apply_stat_change("armor", aura_val)
						behind.active_effects.append({
							"stat": "armor", "value": aura_val,
							"duration": -1, "effect_id": "kappa_warrior_aura"
						})
				"kappa_shaman":
					var front = _scene._get_unit_at_position(team, unit.position_index - 1)
					if front:
						front.apply_stat_change("armor", 10)
						front.active_effects.append({
							"stat": "armor", "value": 10,
							"duration": -1, "effect_id": "kappa_shaman_aura"
						})

## Сирена: +10 уклонения за каждого живого союзника (пересчитывается)
func _apply_siren_evasion_auras():
	# Сначала снимаем старые ауры Сирены
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "siren_ally_evasion":
				var val = Combatant._effect_get(unit.active_effects[i], "value", 0)
				unit.apply_stat_change("evasion", -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	
	# Накладываем заново от живых Сирен
	for team in [_scene.heroes_team, _scene.enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type == "siren_ally_evasion":
				# Считаем количество живых союзников (включая саму Сирену)
				var alive_count = 0
				for ally in team:
					if ally and ally.current_hp > 0:
						alive_count += 1
				var aura_val = alive_count * 10
				unit.apply_stat_change("evasion", aura_val)
				unit.active_effects.append({
					"stat": "evasion", "value": aura_val, "duration": -1,
					"effect_id": "siren_ally_evasion", "source_ability": "Сирена"
				})
				_scene._log_combat("🧜‍♀️ [Сирена] %s: +%d уклонения (%d союзников)." % [unit.unit_name, aura_val, alive_count])

## Наставник: все союзники получают +15 точности, пока Наставник жив (пересчитывается)
func _apply_mentor_accuracy_auras():
	# Сначала снимаем старые ауры Наставника
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "mentor_accuracy_aura":
				var val = Combatant._effect_get(unit.active_effects[i], "value", 0)
				unit.apply_stat_change("accuracy", -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	# Накладываем заново от живых Наставников
	for team in [_scene.heroes_team, _scene.enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type == "mentor_accuracy_aura":
				for ally in team:
					if ally and ally.current_hp > 0:
						ally.apply_stat_change("accuracy", 15)
						ally.active_effects.append({"stat": "accuracy", "value": 15, "duration": -1, "effect_id": "mentor_accuracy_aura", "source_ability": "Наставник"})

## Кентавр: «Подавляющий обстрел» — когда враг начинает ход, получает 0.6 урона от Кентавра
func _trigger_centaur_suppressive_fire(active_unit: Combatant):
	if active_unit == null or active_unit.current_hp <= 0:
		return
	var foe_team = _scene.heroes_team if active_unit.is_enemy else _scene.enemies_team
	for foe in foe_team:
		if foe == null or foe.current_hp <= 0 or foe.active_stance == null:
			continue
		# Та же стойка «урон за каждое действие противника» у Кентавра (60%) и Цербера (50%).
		var _sf_type: String = foe.active_stance.stance_effect_type
		if _sf_type == "centaur_suppressive_fire" or _sf_type == "cerberus_watchdog":
			var _sf_is_dog: bool = _sf_type == "cerberus_watchdog"
			var _sf_name: String = "Сторожевой пес" if _sf_is_dog else "Подавляющий обстрел"
			var _sf_dmg = int(foe.damage * (0.5 if _sf_is_dog else 0.6))
			if _sf_dmg > 0:
				var _sf_hp_before = active_unit.current_hp
				active_unit.take_damage(_sf_dmg)
				_scene._log_combat("%s [%s] %s наносит %d урона %s за действие. HP: %d → %d" % ["🐕" if _sf_is_dog else "🏹", _sf_name, foe.unit_name, _sf_dmg, active_unit.unit_name, _sf_hp_before, active_unit.current_hp])
				if active_unit.current_hp <= 0:
					_scene._log_combat("  → %s повержен (%s)!" % [active_unit.unit_name, _sf_name])
					_scene._unit_events._on_unit_killed(active_unit)
					var _sf_team = _scene.heroes_team if active_unit.is_enemy == false else _scene.enemies_team
					_scene._field._compact_team(_sf_team)
					_apply_kappa_auras()
			break  # срабатывает только один Кентавр за ход

## Оборотень: «Засада» — следующий враг (с точки зрения оборотня), совершивший
## действие, получает 150% урона оборотня. В отличие от «Подавляющего обстрела»
## Кентавра — одноразово: после срабатывания стойка снимается.
func _trigger_oboroten_ambush(active_unit: Combatant):
	if active_unit == null or active_unit.current_hp <= 0:
		return
	var foe_team = _scene.heroes_team if active_unit.is_enemy else _scene.enemies_team
	for foe in foe_team:
		if foe == null or foe.current_hp <= 0 or foe.active_stance == null:
			continue
		if foe.active_stance.stance_effect_type == "oboroten_ambush":
			var _oa_dmg = int(foe.damage * 1.5)
			if _oa_dmg > 0:
				var _oa_hp_before = active_unit.current_hp
				active_unit.take_damage(_oa_dmg)
				_scene._log_combat("🐺 [Засада] %s наносит %d урона %s (150%% атаки). HP: %d → %d" % [foe.unit_name, _oa_dmg, active_unit.unit_name, _oa_hp_before, active_unit.current_hp])
				if active_unit.current_hp <= 0:
					_scene._log_combat("  → %s повержен засадой оборотня!" % active_unit.unit_name)
					_scene._unit_events._on_unit_killed(active_unit)
					var _oa_team = _scene.heroes_team if not active_unit.is_enemy else _scene.enemies_team
					_scene._field._compact_team(_oa_team)
					_apply_kappa_auras()
			foe.break_stance()
			break  # срабатывает только один оборотень за ход

## Новичок: на 3-м раунде превращается в Гладиатора (позиции 1-2) или Гоплита (позиции 3-4).
## target_type позволяет отдельно триггерить "благословлённых" (novice_transformation_blessed) —
## они превращаются на 2-м раунде, на 1 ход раньше обычных новичков (см. вызов ниже).
func _apply_novice_transformation(target_type: String = "novice_transformation"):
	var _nt_log: Array[String] = []
	for team in [_scene.heroes_team, _scene.enemies_team]:
		for i in range(team.size()):
			var unit = team[i]
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type != target_type:
				continue
			var pos = unit.position_index
			var form_path: String
			var form_name: String
			if pos <= 1:
				form_path = "res://Enemies/Civilization/Arena/Gladiator/Gladiator.tres"
				form_name = "Гладиатор"
			else:
				form_path = "res://Enemies/Civilization/Arena/Hoplite/Hoplite.tres"
				form_name = "Гоплит"
			var res = load(form_path) as CharacterResource
			if res == null:
				continue
			var new_unit = Combatant.new(res)
			new_unit.is_enemy = unit.is_enemy
			new_unit.position_index = pos
			# +20% HP / урон / точность
			new_unit.max_hp = int(new_unit.max_hp * 1.2)
			new_unit.current_hp = new_unit.max_hp
			new_unit.base_damage = int(new_unit.base_damage * 1.2)
			new_unit.base_accuracy = int(new_unit.base_accuracy * 1.2)
			new_unit.damage_taken.connect(_scene._unit_events._on_unit_damaged.bind(new_unit))
			new_unit.died.connect(_scene._unit_events._on_unit_died.bind(new_unit))
			new_unit.phoenix_feather_shield_triggered.connect(_scene._unit_events._on_phoenix_shield_triggered.bind(new_unit))
			new_unit.koschei_life_shield_triggered.connect(_scene._unit_events._on_koschei_life_shield_triggered.bind(new_unit))
			new_unit.immortal_death_shield_triggered.connect(_scene._unit_events._on_immortal_death_shield_triggered.bind(new_unit))
			new_unit.stance_broken.connect(_scene._unit_events._on_unit_stance_broken.bind(new_unit))
			# Удаляем визуал старого Новичка
			_scene._field._remove_visual_for_unit(unit)
			# Заменяем слот команды
			team[i] = new_unit
			# Создаём визуал новому юниту
			_scene._field._ensure_visual_for_unit(new_unit)
			_nt_log.append("🔄 [Трансформация] %s (линия %d) превращается в %s (+20%% HP/урон/точность)!" % [unit.unit_name, pos + 1, form_name])
	for line in _nt_log:
		_scene._log_combat(line)
	if not _nt_log.is_empty():
		_apply_kappa_auras()
		_apply_mentor_accuracy_auras()

## Оборотень: начиная с 3-го раунда получает +30 уклонения, +30 удачи, +30 урона (единоразово, до конца боя)
func _apply_oboroten_round3_power():
	for team in [_scene.heroes_team, _scene.enemies_team]:
		for unit in team:
			if unit == null or unit.current_hp <= 0:
				continue
			if unit.special_effect_type != "oboroten_round3_power":
				continue
			var _already = false
			for e in unit.active_effects:
				if Combatant._effect_get(e, "effect_id", "") == "oboroten_round3_power":
					_already = true
					break
			if _already:
				continue
			unit.apply_stat_change("evasion", 30)
			unit.apply_stat_change("crit", 30)
			unit.apply_stat_change("damage", 30)
			unit.active_effects.append({"stat": "evasion", "value": 30, "duration": -1, "effect_id": "oboroten_round3_power", "source_ability": "Пассивка Оборотня"})
			unit.active_effects.append({"stat": "crit", "value": 30, "duration": -1, "effect_id": "oboroten_round3_power", "source_ability": "Пассивка Оборотня"})
			unit.active_effects.append({"stat": "damage", "value": 30, "duration": -1, "effect_id": "oboroten_round3_power", "source_ability": "Пассивка Оборотня"})
			_scene._log_combat("🐺 [Оборотень] %s: с 3-го раунда +30 уклонения, +30 удачи, +30 урона." % unit.unit_name)

# ══════════════════════════════════════════════
#  ПРИЗЫВ ВАЛУНА (Туннели — Шаман)
# ══════════════════════════════════════════════
func _summon_boulder(summoner: Combatant, log_lines: Array):
	var team = _scene.enemies_team if summoner.is_enemy else _scene.heroes_team
	var visuals = _scene.enemy_visuals if summoner.is_enemy else _scene.hero_visuals
	var pos_prefix = "EnemyPositions" if summoner.is_enemy else "HeroPositions"
	var empty_pos = -1
	for i in range(4):
		if team[i] == null:
			empty_pos = i
			break
	if empty_pos == -1:
		log_lines.append("  → Нет свободной позиции для призыва Валуна!")
		return
	var res = load("res://Enemies/Dungeon/Tunnels/Bolder/Bolder.tres") as CharacterResource
	if res == null:
		log_lines.append("  → Ошибка загрузки ресурса Валуна!")
		return
	var boulder = Combatant.new(res)
	boulder.is_enemy = summoner.is_enemy
	boulder.position_index = empty_pos
	team[empty_pos] = boulder
	boulder.damage_taken.connect(_scene._unit_events._on_unit_damaged.bind(boulder))
	boulder.died.connect(_scene._unit_events._on_unit_died.bind(boulder))
	boulder.phoenix_feather_shield_triggered.connect(_scene._unit_events._on_phoenix_shield_triggered.bind(boulder))
	boulder.koschei_life_shield_triggered.connect(_scene._unit_events._on_koschei_life_shield_triggered.bind(boulder))
	boulder.immortal_death_shield_triggered.connect(_scene._unit_events._on_immortal_death_shield_triggered.bind(boulder))
	# Постоянная метка провокации
	boulder.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": -1, "effect_id": "provocation_mark", "source_ability": "Валун"})
	# Создать визуал
	var pos_node_name = pos_prefix + "/Pos" + str(empty_pos + 1)
	if _scene.has_node(pos_node_name):
		_scene._field._create_visual(boulder, pos_node_name, visuals, empty_pos)
	_scene._field._update_all_visuals()
	_scene._turns._recalculate_turn_order()
	log_lines.append("  → [Каменная стена] Призван Валун на позицию %d!" % (empty_pos + 1))

## Артефакт «Красивый камень»: пока есть свободное место в отряде героев, призывает союзного Булыжника.
func _summon_beautiful_stone_boulder() -> void:
	var empty_pos = -1
	for i in range(4):
		if _scene.heroes_team[i] == null:
			empty_pos = i
			break
	if empty_pos == -1:
		return
	var res = load("res://Enemies/Dungeon/Tunnels/Bolder/Bolder.tres") as CharacterResource
	if res == null:
		return
	res = res.duplicate()
	res.unit_name = "Булыжник"
	var boulder = Combatant.new(res)
	boulder.is_enemy = false
	boulder.position_index = empty_pos
	_scene.heroes_team[empty_pos] = boulder
	boulder.damage_taken.connect(_scene._unit_events._on_unit_damaged.bind(boulder))
	boulder.died.connect(_scene._unit_events._on_unit_died.bind(boulder))
	boulder.phoenix_feather_shield_triggered.connect(_scene._unit_events._on_phoenix_shield_triggered.bind(boulder))
	boulder.koschei_life_shield_triggered.connect(_scene._unit_events._on_koschei_life_shield_triggered.bind(boulder))
	boulder.immortal_death_shield_triggered.connect(_scene._unit_events._on_immortal_death_shield_triggered.bind(boulder))
	boulder.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": -1, "effect_id": "provocation_mark", "source_ability": "Красивый камень"})
	var pos_node_name = "HeroPositions/Pos" + str(empty_pos + 1)
	if _scene.has_node(pos_node_name):
		_scene._field._create_visual(boulder, pos_node_name, _scene.hero_visuals, empty_pos)
	_scene._field._update_all_visuals()
	_scene._turns._recalculate_turn_order()
	_scene._log_combat("🪨 [Красивый камень] Призван союзный Булыжник на позицию %d!" % (empty_pos + 1))

# ══════════════════════════════════════════════
#  РАУНДЫ И ОЧЕРЕДЬ ХОДОВ
# ══════════════════════════════════════════════

func _trigger_thunder_wrath(attacker: Combatant):
	var enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
	if enemies.is_empty():
		return
	_scene._log_combat("⚡ %s обрушивает Гнев Бога Грома — 5 ударов!" % attacker.unit_name)
	for i in range(5):
		if _scene._outcome._check_battle_end():
			return
		enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.3)
		if not dmg_result.is_hit:
			_scene._log_combat("  [Удар %d] → Промах по %s." % [i + 1, target.unit_name])
			if i < 4:
				# ignore_time_scale=true — иначе этот таймер сам встаёт на паузу,
				# которую держит звук/вспышка предыдущего удара (Engine.time_scale=0
				# пока _active_attack_effects > 0), и следующий удар откладывается
				# на секунды вместо задуманных THUNDER_WRATH_HIT_GAP_SEC.
				await RealTimeWait.wait(_scene, BattleScene.THUNDER_WRATH_HIT_GAP_SEC)
			continue
		_scene._abilities._play_ability_attack_effects(attacker.active_stance, target)
		_scene._unit_events._deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_scene._log_combat("  [Удар %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text, dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			var team = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
			_scene._field._compact_team(team)
		_scene._field._update_all_visuals()
		if i < 4:
			await RealTimeWait.wait(_scene, BattleScene.THUNDER_WRATH_HIT_GAP_SEC)
	_scene._field._update_all_visuals()

func _trigger_indigo_hunt_stance(attacker: Combatant):
	var enemies = _scene._field._get_living_team_members(_scene.heroes_team)  # attacker is enemy
	if enemies.is_empty():
		return
	
	# Фильтруем цели по targetable_positions стойки
	var valid: Array = []
	for e in enemies:
		if Combatant.can_be_targeted_at(e, attacker.active_stance):
			valid.append(e)
	if valid.is_empty():
		valid = enemies
	
	var target: Combatant = valid[randi() % valid.size()]
	var dmg_result = CombatCalculator.calculate_ability_damage(attacker, target, attacker.active_stance)
	
	if not dmg_result.is_hit:
		_scene._log_combat("  → %s (стойка Охота) промахивается по %s." % [attacker.unit_name, target.unit_name])
		return
	
	_scene._unit_events._deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
	var crit_text = " (крит!)" if dmg_result.is_crit else ""
	_scene._log_combat("  → %s (стойка Охота) наносит %d урона%s %s. HP: %d → %d" % [
		attacker.unit_name, dmg_result.final_damage, crit_text, target.unit_name,
		dmg_result.hp_before, target.current_hp
	])
	
	if target.current_hp <= 0:
		_scene._log_combat("  → %s повержен!" % target.unit_name)
		_scene._unit_events._on_unit_killed(target)
		var team = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
		_scene._field._compact_team(team)
	_scene._field._update_all_visuals()

## Индиго: снимает все стаки «Взять след» (эффекты с source_ability == "Взять след"),
## reversing stat changes.
func _remove_indigo_trail_buffs(unit: Combatant, log_lines: Array):
	var removed_count = 0
	var i = 0
	while i < unit.active_effects.size():
		var eff = unit.active_effects[i]
		var src = Combatant._effect_get(eff, "source_ability", "")
		if src == "Взять след":
			var stat = Combatant._effect_get(eff, "stat", "")
			var val = Combatant._effect_get(eff, "value", 0)
			if stat != "" and val != 0:
				unit.apply_stat_change(stat, -val)
			unit.active_effects.remove_at(i)
			removed_count += 1
		else:
			i += 1
	if removed_count > 0:
		log_lines.append("  → %s: снято %d стак(ов) «Взять след»." % [unit.unit_name, removed_count])

## Флибустьер: стойка «Я знаю что делаю» — 2 удара по случайным врагам
## с использованием параметров стойки (damage_modifier). Не промахивается.
func _trigger_filibuster_double_hit(attacker: Combatant):
	var enemies = _scene._field._get_living_team_members(_scene.heroes_team)  # attacker is enemy
	if enemies.is_empty():
		return
	var stance = attacker.active_stance
	_scene._log_combat("🗡️ %s (стойка «Я знаю что делаю») наносит 2 удара!" % attacker.unit_name)
	for i in range(2):
		if _scene._outcome._check_battle_end():
			return
		enemies = _scene._field._get_living_team_members(_scene.heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_forced_hit_damage(attacker, target, stance)
		if not dmg_result.is_hit:
			_scene._log_combat("  [Удар %d] → Промах по %s." % [i + 1, target.unit_name])
			continue
		_scene._unit_events._deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_scene._log_combat("  [Удар %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text,
			dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			var team = _scene.heroes_team
			_scene._field._compact_team(team)
	_scene._field._update_all_visuals()

## Матрос с бомбой: стойка «Бомбардировка» — 4 удара по случайным врагам
## с использованием параметров стойки (damage_modifier = 0.5).
func _trigger_bombardment_stance(attacker: Combatant):
	var enemies = _scene._field._get_living_team_members(_scene.heroes_team)  # attacker is enemy
	if enemies.is_empty():
		return
	var stance = attacker.active_stance
	_scene._log_combat("💥 %s (стойка «Бомбардировка») обрушивает 4 удара!" % attacker.unit_name)
	for i in range(4):
		if _scene._outcome._check_battle_end():
			return
		enemies = _scene._field._get_living_team_members(_scene.heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_ability_damage(attacker, target, stance)
		if not dmg_result.is_hit:
			_scene._log_combat("  [Удар %d] → Промах по %s." % [i + 1, target.unit_name])
			continue
		_scene._unit_events._deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_scene._log_combat("  [Удар %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text,
			dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			var team = _scene.heroes_team
			_scene._field._compact_team(team)
	_scene._field._update_all_visuals()

func _redirect_majesty_to_set_true_king(unit: Combatant, amount: int, log_lines: Array) -> bool:
	if unit == null or amount <= 0 or unit.current_hp <= 0 or unit.is_enemy:
		return false
	var team = _scene.heroes_team if not unit.is_enemy else _scene.enemies_team
	for set_unit in team:
		if set_unit == null or set_unit == unit or set_unit.current_hp <= 0:
			continue
		if set_unit.active_stance != null and set_unit.active_stance.stance_effect_type == "set_true_king":
			set_unit.modify_majesty(amount)
			var heal_amount: int = maxi(1, int(unit.max_hp * 0.10))
			unit.apply_stat_change("hp", heal_amount)
			unit.apply_stat_change("armor", 10)
			var _stk_duration = _scene._abilities._compute_effect_duration(set_unit, unit, 1, false)
			unit.active_effects.append({"stat": "armor", "value": 10, "duration": _stk_duration, "effect_id": "set_true_king_armor", "source_ability": "Настоящий король"})
			log_lines.append("  → [Настоящий король] %s перехватывает %d величия. %s получает +%d HP и +10 брони." % [set_unit.unit_name, amount, unit.unit_name, heal_amount])
			return true
	return false

## Сет: «Настоящий король» — союзники исцеляются на 10% HP, Сет получает 5 величия за каждого союзника.
## Один: «Предвидеть» — обновляет +20 уклонения/+15 удачи на 1 ход всем живым союзникам.
## Вызывается при касте и затем в начале каждого хода Одина, пока стойка не прервана
## (перемещением/станом — см. check_stance_interruption). Раньше баффы ставились с
## duration=-1 (навсегда, без снятия при разрыве стойки) — теперь они честно живут 1 ход
## и обновляются заново, пока стойка держится, а без обновления сами истекают.
func _refresh_odin_foresight_aura(attacker: Combatant) -> void:
	var _team = _scene.heroes_team if not attacker.is_enemy else _scene.enemies_team
	var _fe_duration = _scene._abilities._compute_effect_duration(attacker, attacker, 1, false)
	for ally in _team:
		if ally == null or ally.current_hp <= 0:
			continue
		for _fid in ["odin_foresight_ev", "odin_foresight_cr"]:
			for i in range(ally.active_effects.size() - 1, -1, -1):
				var _fe = ally.active_effects[i]
				if Combatant._effect_get(_fe, "effect_id", "") == _fid:
					var _fst = Combatant._effect_get(_fe, "stat", "")
					var _fvl = Combatant._effect_get(_fe, "value", 0)
					ally.apply_stat_change(_fst, -_fvl)
					ally.active_effects.remove_at(i)
		ally.apply_stat_change("evasion", 20)
		ally.active_effects.append({"stat": "evasion", "value": 20, "duration": _fe_duration, "effect_id": "odin_foresight_ev", "source_ability": "Предвидеть"})
		ally.apply_stat_change("crit", 15)
		ally.active_effects.append({"stat": "crit", "value": 15, "duration": _fe_duration, "effect_id": "odin_foresight_cr", "source_ability": "Предвидеть"})
	_scene._log_combat("  → [Предвидеть] Все союзники: +20 уклонения, +15 удачи на %d ход(ов)." % _fe_duration)

func _trigger_set_true_king(unit: Combatant):
	_scene._log_combat("👑 [Сет] Настоящий король: стойка завершена.")
	_scene._field._update_all_visuals()

## Локи: «Рагнарек» — все враги получают 0.5x урон, текущий шанс крита удваивается на 1 ход.
func _trigger_loki_ragnarok(attacker: Combatant):
	# Удвоить ТЕКУЩИЙ шанс крита: прибавить к modifier текущий crit_chance
	var _rg_cur = attacker.crit_chance
	attacker.crit_modifier += _rg_cur
	var _rg_duration = _scene._abilities._compute_effect_duration(attacker, attacker, 1, false)
	attacker.active_effects.append({"stat": "crit_modifier", "value": _rg_cur, "duration": _rg_duration, "effect_id": "loki_ragnarok_crit", "source_ability": "Рагнарек"})
	_scene._log_combat("🔥 [Локи] Рагнарек! Шанс крита удвоен: %d%% → %d%%." % [int(_rg_cur * 100), int(attacker.crit_chance * 100)])
	var enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
	if enemies.is_empty():
		_scene._log_combat("🔥 [Локи] Рагнарек! Двойной крит, но целей нет.")
		return
	_scene._log_combat("🔥 [Локи] Рагнарек! Все враги получают урон, крит x2!")
	_scene._abilities._maybe_play_ability_voice_line(attacker, attacker.active_stance)
	for target in enemies:
		if _scene._outcome._check_battle_end():
			return
		var dmg_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.5)
		if not dmg_result.is_hit:
			_scene._log_combat("  → Промах по %s." % target.unit_name)
			continue
		_scene._unit_events._deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_scene._log_combat("  → %s получает %d урона%s. HP: %d → %d" % [
			target.unit_name, dmg_result.final_damage, crit_text, dmg_result.hp_before, target.current_hp])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			var team = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
			_scene._field._compact_team(team)
	_scene._field._update_all_visuals()

## Кощей: «Неубиваемый» — +30 брони на 1 ход + метка провокации (весь эффект).
func _trigger_koschei_immortal(unit: Combatant):
	var _ki_duration = _scene._abilities._compute_effect_duration(unit, unit, 1, false)
	unit.apply_stat_change("armor", 30)
	unit.active_effects.append({"stat": "armor", "value": 30, "duration": _ki_duration, "effect_id": "koschei_immortal_armor", "source_ability": "Неубиваемый"})
	unit.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": _ki_duration, "effect_id": "provocation_mark", "source_ability": "Неубиваемый"})
	_scene._log_combat("💀 [Кощей] Неубиваемый! +30 брони и метка провокации на %d ход(ов)." % _ki_duration)
	_scene._field._update_all_visuals()

## Бессмертный: «Мой бой не окончен» — восстановить щит смерти (если утрачен), иначе 20 периодического урона на 2 хода.
func _trigger_immortal_my_battle_not_over(unit: Combatant):
	var shield_used = false
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "immortal_shield_used":
			shield_used = true
			break
	if shield_used:
		var i = 0
		while i < unit.active_effects.size():
			if Combatant._effect_get(unit.active_effects[i], "effect_id", "") == "immortal_shield_used":
				unit.active_effects.remove_at(i)
			else:
				i += 1
		_scene._log_combat("🛡️ [Бессмертный] %s: «Мой бой не окончен» — щит смерти восстановлен!" % unit.unit_name)
	else:
		unit.active_effects.append({"stat": "periodic_damage", "value": 20, "duration": 2, "source_ability": "Мой бой не окончен"})
		_scene._log_combat("🛡️ [Бессмертный] %s: щит ещё цел — получает 20 периодического урона на 2 хода." % unit.unit_name)
	_scene._field._update_all_visuals()

## Жрец Ра: «Слава солнцу» — отступить на 2 линии, союзники +10 уклонения, урон Пустыни по врагам x2.
func _trigger_ra_sun_glory(unit: Combatant):
	# Отступление на 2 линии назад
	if not unit.is_large:
		_scene._field._apply_shift_effect(unit, 2, _scene._is_player_hero(unit))
	# +10 уклонения себе и всем живым союзникам на 2 хода
	var team = _scene.enemies_team if unit.is_enemy else _scene.heroes_team
	for ally in team:
		if ally and ally.current_hp > 0:
			ally.apply_stat_change("evasion", 10)
			ally.active_effects.append({"stat": "evasion", "value": 10, "duration": 2, "effect_id": "ra_sun_glory_evasion", "source_ability": "Слава солнцу"})
	# Урон Пустыни по врагам удваивается, пока благословение активно
	_scene._ra_sun_glory_active = true
	_scene._log_combat("☀️ [Жрец Ра] %s: Слава солнцу! Союзники +10 уклонения, урон Пустыни по врагам удвоен." % unit.unit_name)
	_scene._field._update_all_visuals()

## Сфинкс: «Облик статуи» — +30 брони и восстановление 20% HP.
func _trigger_sphinx_statue_form(unit: Combatant):
	unit.apply_stat_change("armor", 30)
	unit.active_effects.append({"stat": "armor", "value": 30, "duration": 1, "effect_id": "sphinx_statue_armor", "source_ability": "Облик статуи"})
	var heal = int(unit.max_hp * 0.20)
	if heal > 0:
		var hp_before = unit.current_hp
		unit.apply_stat_change("hp", heal)
		_scene._log_combat("🗿 [Сфинкс] %s: Облик статуи! +30 брони, восстановление %d HP (%d → %d)." % [unit.unit_name, heal, hp_before, unit.current_hp])
	else:
		_scene._log_combat("🗿 [Сфинкс] %s: Облик статуи! +30 брони." % unit.unit_name)
	_scene._field._update_all_visuals()

## Золотой скоробей: «Зарыться в песок» — +40% уклонения, случайный враг получает 0.4 урона и -15 точности на 1 ход.
func _trigger_scarab_bury_in_sand(unit: Combatant):
	unit.apply_stat_change("evasion", 40)
	unit.active_effects.append({"stat": "evasion", "value": 40, "duration": 1, "effect_id": "scarab_bury_evasion", "source_ability": "Зарыться в песок"})
	var enemy_side = _scene.enemies_team if _scene._is_player_hero(unit) else _scene.heroes_team
	var live = _scene._field._get_living_team_members(enemy_side)
	if not live.is_empty():
		var target = live[randi() % live.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(unit, target, 0.4)
		if dmg_result.is_hit:
			target.take_damage(dmg_result.final_damage)
			_scene._log_combat("🪲 [Скоробей] %s: +40%% уклонения. %s получает %d урона из песка. HP: %d → %d" % [
				unit.unit_name, target.unit_name, dmg_result.final_damage, dmg_result.hp_before, target.current_hp])
			if target.current_hp <= 0:
				_scene._log_combat("  → %s повержен!" % target.unit_name)
				_scene._unit_events._on_unit_killed(target)
				_scene._field._compact_team(enemy_side)
		else:
			_scene._log_combat("🪲 [Скоробей] %s зарывается: +40%% уклонения. Песок промахнулся по %s." % [unit.unit_name, target.unit_name])
		if target.current_hp > 0:
			target.apply_stat_change("accuracy", -15)
			target.active_effects.append({"stat": "accuracy", "value": -15, "duration": 1, "effect_id": "scarab_sand_blind", "source_ability": "Зарыться в песок"})
			_scene._log_combat("  → %s: -15 точности на 1 ход." % target.unit_name)
	else:
		_scene._log_combat("🪲 [Скоробей] %s зарывается в песок: +40%% уклонения." % unit.unit_name)
	_scene._field._update_all_visuals()

## Сфинкс: разрешение «Загадки». Меченый (тот, кто ранил/сдвинул сфинкса) получает
## 90% своего макс. HP как чистый урон, а сфинкс исцеляется на 10% своего макс. HP. Метка снимается.
func _resolve_sphinx_riddle(marked: Combatant, sphinx: Combatant, log_lines: Array = []):
	# Снимаем метку «Загадки» с меченого
	var i = 0
	while i < marked.active_effects.size():
		if Combatant._effect_get(marked.active_effects[i], "effect_id", "") == "sphinx_riddle":
			marked.active_effects.remove_at(i)
		else:
			i += 1
	# 90% от макс. HP меченого как чистый урон
	var riddle_dmg = int(marked.max_hp * 0.9)
	var hp_before = marked.current_hp
	marked.take_damage(riddle_dmg)
	var _msg = "  → [Сфинкс] Загадка не разгадана! %s получает %d урона (90%% макс. HP). HP: %d → %d" % [
		marked.unit_name, riddle_dmg, hp_before, marked.current_hp]
	if log_lines.size() > 0:
		log_lines.append(_msg)
	else:
		_scene._log_combat(_msg)
	# Сфинкс исцеляется на 10% своего макс. HP
	if sphinx != null and sphinx.current_hp > 0:
		var heal = int(sphinx.max_hp * 0.10)
		if heal > 0:
			var s_hp_before = sphinx.current_hp
			sphinx.apply_stat_change("hp", heal)
			var _msg2 = "  → [Сфинкс] %s питается разгадкой: +%d HP (%d → %d)." % [sphinx.unit_name, heal, s_hp_before, sphinx.current_hp]
			if log_lines.size() > 0:
				log_lines.append(_msg2)
			else:
				_scene._log_combat(_msg2)
	# Если меченый погиб — корректно обрабатываем смерть
	if marked.current_hp <= 0:
		var _msg3 = "  → %s повержен Загадкой Сфинкса!" % marked.unit_name
		if log_lines.size() > 0:
			log_lines.append(_msg3)
		else:
			_scene._log_combat(_msg3)
		_scene._unit_events._on_unit_killed(marked, log_lines)
	_scene._field._update_all_visuals()

## Красный Они: «Пламенный дождь» — 5 огненных ударов по случайным врагам (0.3x урон каждый).
func _trigger_oni_flaming_rain(unit: Combatant):
	var enemy_side = _scene.enemies_team if _scene._is_player_hero(unit) else _scene.heroes_team
	var mult = unit.active_stance.damage_modifier if unit.active_stance != null else 0.3
	_scene._log_combat("🌧️ [Они] Пламенный дождь! 5 огненных ударов по случайным врагам.")
	for i in range(5):
		if _scene._outcome._check_battle_end():
			break
		var live = _scene._field._get_living_team_members(enemy_side)
		if live.is_empty():
			break
		var target = live[randi() % live.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(unit, target, mult)
		if not dmg_result.is_hit:
			_scene._log_combat("  → Удар #%d: промах по %s." % [i + 1, target.unit_name])
			continue
		target.take_damage(dmg_result.final_damage)
		_scene._log_combat("  → Удар #%d: %s получает %d урона. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, dmg_result.hp_before, target.current_hp])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			_scene._field._compact_team(enemy_side)
	_scene._field._update_all_visuals()

## Атакующий титан: «Рождённый для битвы» — следующим ходом 80% урона по позициям 1-2 врагов.
func _trigger_titan_born_to_battle(unit: Combatant):
	var enemy_team = _scene.enemies_team if _scene._is_player_hero(unit) else _scene.heroes_team
	var targets = []
	for t in enemy_team:
		if t and t.current_hp > 0 and (t.position_index == 0 or t.position_index == 1):
			targets.append(t)
	if targets.is_empty():
		_scene._log_combat("⚔️ [Титан] Рождённый для битвы! Но целей на позициях 1-2 нет.")
		_scene._field._update_all_visuals()
		return
	_scene._log_combat("⚔️ [Титан] Рождённый для битвы! 80% урона по позициям 1-2.")
	for target in targets:
		if _scene._outcome._check_battle_end():
			break
		var dmg_result = CombatCalculator.calculate_fixed_damage(unit, target, 0.8)
		if not dmg_result.is_hit:
			_scene._log_combat("  → Промах по %s." % target.unit_name)
			continue
		target.take_damage(dmg_result.final_damage)
		_scene._log_combat("  → %s получает %d урона. HP: %d → %d" % [
			target.unit_name, dmg_result.final_damage, dmg_result.hp_before, target.current_hp])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			_scene._field._compact_team(enemy_team)
	_scene._field._update_all_visuals()

func _trigger_thor_fight_me_heal(unit: Combatant) -> String:
	if unit == null or unit.current_hp <= 0:
		return ""
	if not _scene._has_effect_id(unit, "thor_fight_me_heal"):
		return ""
	var heal_amount: int = maxi(1, int(unit.max_hp * 0.07))
	var hp_before: int = unit.current_hp
	unit.apply_stat_change("hp", heal_amount)
	return "[fight_me] %s восстанавливает %d HP при атаке (%d → %d)." % [unit.unit_name, unit.current_hp - hp_before, hp_before, unit.current_hp]

func _should_trigger_thor_hammer_of_lightning(attacker: Combatant, ability: AbilityResource) -> bool:
	if attacker == null or ability == null:
		return false
	if not _scene._has_effect_id(attacker, "thor_hammer_of_lightning"):
		return false
	if ability.ability_marker == "thor_hammer_of_lightning":
		return false
	return ability.target_type == "Enemy" or ability.target_type == "All_Enemies"

func _trigger_thor_hammer_of_lightning(attacker: Combatant, log_lines: Array[String]) -> void:
	var enemy_team: Array = _scene.enemies_team if not attacker.is_enemy else _scene.heroes_team
	var pure_damage: int = maxi(1, int(attacker.damage * 0.05))
	# Один звук молнии на весь проц (не на каждого врага), но вспышка — на КАЖДОМ
	# враге, все одновременно (без паузы между ними, в отличие от Гнева Бога Грома).
	_scene._abilities._play_ability_attack_sfx(attacker.ultimate_ability)
	for enemy in enemy_team.duplicate():
		if enemy == null or enemy.current_hp <= 0:
			continue
		_scene._abilities._show_ability_attack_flash(attacker.ultimate_ability, enemy)
		var hp_before: int = enemy.current_hp
		enemy.take_damage(pure_damage)
		log_lines.append("  → [Hammer_of_lightning] %s получает %d чистого урона (%d → %d)." % [enemy.unit_name, pure_damage, hp_before, enemy.current_hp])
		if enemy.current_hp <= 0:
			enemy.killed_by = attacker
			log_lines.append("  → %s повержен!" % enemy.unit_name)
			_scene._unit_events._on_unit_killed(enemy, log_lines)
			_scene._field._compact_team(enemy_team)
			continue
		if randf() < 0.10 and not enemy.is_stunned:
			enemy.is_stunned = true
			var _hol_duration = _scene._abilities._compute_effect_duration(attacker, enemy, 1, true)
			enemy.active_effects.append({"stat": "stun", "value": 1, "duration": _hol_duration, "source_ability": "Hammer_of_lightning"})
			enemy.check_stance_interruption("stun")
			_notify_stun_applied(enemy)
			log_lines.append("  → [Hammer_of_lightning] %s оглушён." % enemy.unit_name)

func _trigger_storm_marks(attacker: Combatant):
	var mark_count = 0
	for eff in attacker.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "neverending_storm_mark":
			mark_count += 1
	if mark_count == 0:
		return
	var enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
	if enemies.is_empty():
		return
	_scene._log_combat("⛈ Вечная буря Зевса — %d удар(ов) молнией!" % mark_count)
	for i in range(mark_count):
		if _scene._outcome._check_battle_end():
			return
		enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
		if enemies.is_empty():
			break
		var target: Combatant = enemies[randi() % enemies.size()]
		var dmg_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.6)
		if not dmg_result.is_hit:
			_scene._log_combat("  [Молния %d] → Промах по %s." % [i + 1, target.unit_name])
			if i < mark_count - 1:
				await RealTimeWait.wait(_scene, BattleScene.THUNDER_WRATH_HIT_GAP_SEC)
			continue
		_scene._abilities._play_ability_attack_effects(attacker.ultimate_ability, target)
		_scene._unit_events._deal_damage(target, dmg_result.final_damage, dmg_result.is_crit)
		var crit_text = " (крит!)" if dmg_result.is_crit else ""
		_scene._log_combat("  [Молния %d] → %s получает %d урона%s. HP: %d → %d" % [
			i + 1, target.unit_name, dmg_result.final_damage, crit_text, dmg_result.hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен!" % target.unit_name)
			_scene._unit_events._on_unit_killed(target)
			var team = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
			_scene._field._compact_team(team)
		_scene._field._update_all_visuals()
		# Та же пауза между ударами, что и у Гнева Бога Грома (THUNDER_WRATH_HIT_GAP_SEC) —
		# без неё все удары этой способности тоже били бы визуально одновременно.
		if i < mark_count - 1:
			await RealTimeWait.wait(_scene, BattleScene.THUNDER_WRATH_HIT_GAP_SEC)
	_scene._field._update_all_visuals()

# ═══ Система позиционных марок перенесена в battle_marks.gd (класс BattleMarks) ═══
# Логика и состояние марок инкапсулированы в объекте `marks` (см. _ready() и battle_marks.gd).
# Поведение боя не изменено — перенесено 1:1.

## Валькирии: распространение баффа на противоположный тип валькирий.
func _propagate_valkyrie_buff(source: Combatant, source_type: String, target_type: String, stat: String, value: int, duration: int, log_lines: Array):
	var team = _scene.enemies_team if source.is_enemy else _scene.heroes_team
	for v in team:
		if v and v.current_hp > 0 and v != source and v.special_effect_type == target_type:
			v.apply_stat_change(stat, value)
			v.active_effects.append({"stat": stat, "value": value, "duration": duration, "effect_id": "valkyrie_shared_buff", "source_ability": "Пассивка Валькирии"})
			log_lines.append("  → [Пассивка Валькирии] %s получает +%d %s на %d ход." % [v.unit_name, value, stat, duration])

## Пегас: когда союзник получает бафф — +5 атаки навсегда.
## log_lines необязателен — если не передан (или вызов идёт из места без пакетного лога),
## строка сразу уходит в _log_combat.
## _check_pegasus_ally_buff перенесена в battle_effects.gd (см. effects._check_pegasus_ally_buff()).

func _refresh_passive_auras_for_all_units() -> void:
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit != null:
			unit.refresh_passive_auras()
	_sync_kraken_passive()

func _orochi_alive_on_field() -> bool:
	for e in _scene.enemies_team:
		if e != null and e.current_hp > 0 and e.special_effect_type == "orochi_shared_shields":
			return true
	return false

## В начале боя, если у врагов есть Орочи, пул щитов смерти = 8 (это и максимум).
func _init_orochi_pool() -> void:
	for e in _scene.enemies_team:
		if e != null and e.special_effect_type == "orochi_shared_shields":
			_set_orochi_shields(BattleScene.OROCHI_MAX_SHIELDS)
			return

func _set_orochi_shields(value: int) -> void:
	_scene._orochi_death_shields = clampi(value, 0, BattleScene.OROCHI_MAX_SHIELDS)
	var seen: Dictionary = {}
	for e in _scene.enemies_team:
		if e == null or seen.has(e) or e.special_effect_type != "orochi_shared_shields":
			continue
		seen[e] = true
		e.set_meta("orochi_shields", _scene._orochi_death_shields)
		_scene.effects._remove_effect_id(e, "orochi_death_shields")
		e.active_effects.append({"stat": "trigger_marker", "value": _scene._orochi_death_shields, "duration": -1, "effect_id": "orochi_death_shields", "source_ability": "Щиты смерти", "dispellable": false})

## Обработчик Combatant.shared_death_shield_provider: смертельный урон союзнику Орочи тратит
## один общий щит — юнит восстанавливает полное HP и теряет накопленное величие.
func _try_shared_death_shield(unit: Combatant) -> bool:
	if unit == null or not unit.is_enemy or _scene._orochi_death_shields <= 0:
		return false
	if unit.special_effect_type != "orochi_shared_shields" and not _orochi_alive_on_field():
		return false
	_set_orochi_shields(_scene._orochi_death_shields - 1)
	unit.current_hp = unit.max_hp
	var _lost_majesty: int = unit.current_majesty
	unit.current_majesty = 0
	_scene._log_combat("🐍 [Щит смерти] %s не погибает: полное HP (%d), величие потеряно (%d → 0). Щитов осталось: %d." % [unit.unit_name, unit.current_hp, _lost_majesty, _scene._orochi_death_shields])
	_scene._field._update_all_visuals()
	return true

# ═══ Кракен: +20 брони и уклонения за каждого живого союзника ═══
func _sync_kraken_passive() -> void:
	var seen: Dictionary = {}
	for unit in _scene.enemies_team + _scene.heroes_team:
		if unit == null or seen.has(unit) or unit.special_effect_type != "kraken_stats_per_ally":
			continue
		seen[unit] = true
		var team: Array = _scene.enemies_team if unit.is_enemy else _scene.heroes_team
		var counted: Dictionary = {}
		var allies := 0
		if unit.current_hp > 0:
			for a in team:
				if a != null and a != unit and a.current_hp > 0 and not counted.has(a):
					counted[a] = true
					allies += 1
		var bonus: int = 20 * allies
		var applied: int = int(unit.get_meta("kraken_aura_bonus", 0))
		if bonus == applied:
			continue
		unit.armor_modifier += bonus - applied
		unit.evasion_modifier += bonus - applied
		unit.set_meta("kraken_aura_bonus", bonus)
		_scene.effects._remove_effect_id(unit, "kraken_aura_armor")
		_scene.effects._remove_effect_id(unit, "kraken_aura_evasion")
		if bonus > 0:
			unit.active_effects.append({"stat": "armor", "value": bonus, "duration": -1, "effect_id": "kraken_aura_armor", "source_ability": "Пассивка Кракена", "dispellable": false})
			unit.active_effects.append({"stat": "evasion", "value": bonus, "duration": -1, "effect_id": "kraken_aura_evasion", "source_ability": "Пассивка Кракена", "dispellable": false})

## Живые щупальца кракена в команде этого юнита.
func _living_tentacles(of_unit: Combatant) -> Array:
	var team: Array = _scene.enemies_team if of_unit.is_enemy else _scene.heroes_team
	var out: Array = []
	for u in team:
		if u != null and u.current_hp > 0 and u.special_effect_type == "kraken_tentacle" and not out.has(u):
			out.append(u)
	return out

## Посейдон: лечение 5% HP за каждый уникальный положительный бафф в начале хода
func _trigger_poseidon_heal(unit: Combatant):
	var unique_buffs = {}
	for effect in unit.active_effects:
		var val = Combatant._effect_get(effect, "value", 0)
		if val <= 0:
			continue
		var key = Combatant._effect_get(effect, "source_ability", "")
		if key == "":
			key = Combatant._effect_get(effect, "effect_id", "")
		if key != "":
			unique_buffs[key] = true
	var buff_count = unique_buffs.size()
	if buff_count == 0:
		return
	var heal_amount = int(unit.max_hp * 0.05 * buff_count)
	var hp_before = unit.current_hp
	unit.apply_stat_change("hp", heal_amount)
	_scene._log_combat("🔱 [Посейдон] %s лечится за %d уникальных баффов: +%d HP (%d → %d)" % [
		unit.unit_name, buff_count, heal_amount, hp_before, unit.current_hp
	])

## Медуза: при оглушении любого юнита — лечится на 15% HP.
func _notify_stun_applied(stunned_unit: Combatant):
	for team in [_scene.heroes_team, _scene.enemies_team]:
		for unit in team:
			if unit and unit.current_hp > 0 and unit.special_effect_type == "medusa_stun_heal":
				var heal_amount = int(unit.max_hp * 0.15)
				if heal_amount > 0:
					var hp_before = unit.current_hp
					unit.apply_stat_change("hp", heal_amount)
					_scene._log_combat("🐍 [Медуза] %s поглощает чьё-то оцепенение: +%d HP (%d → %d)." % [
						unit.unit_name, heal_amount, hp_before, unit.current_hp])

## Лавовый кабан: текущий процент отскока урона (10% база + 5% за каждый стак горячего сердца).
func _lava_boar_thorns_percent(unit: Combatant) -> int:
	var stacks = 0
	for e in unit.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "lava_boar_warm_heart_stack":
			stacks += 1
	return 10 + stacks * 5

# ══════════════════════════════════════════════
#  UI: НАВЕДЕНИЕ НА ЮНИТОВ И ТУЛТИПЫ СПОСОБНОСТЕЙ
# ══════════════════════════════════════════════

## Снимок ссылок на эффекты нужен, чтобы после действия отличить новые эффекты
## от уже находившихся на юните до применения способности или заклинания.
func _snapshot_active_effects() -> Array:
	var snapshot: Array = []
	var seen_units: Dictionary = {}
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit != null and not seen_units.has(unit):
			seen_units[unit] = true
			snapshot.append({"unit": unit, "effects": unit.active_effects.duplicate(false)})
	return snapshot

func _is_voodoo_debuff(effect_data: Dictionary) -> bool:
	if bool(effect_data.get("voodoo_copy", false)):
		return false
	var stat: String = str(Combatant._effect_get(effect_data, "stat", ""))
	var value: float = float(Combatant._effect_get(effect_data, "value", 0))
	if value < 0.0:
		return true
	return stat in [
		"periodic_damage",
		"stun",
		"rooted",
		"riddle_mark",
		"provocation_mark",
		"thorn_bush_mark",
	]

func _effect_existed_before(effect_data: Dictionary, previous_effects: Array) -> bool:
	for previous_effect in previous_effects:
		if is_same(previous_effect, effect_data):
			return true
	return false

## Кукла вуду копирует полный словарь каждого нового боевого дебаффа:
## длительность, стаки и специальные параметры сохраняются.
func _propagate_new_voodoo_debuffs(snapshot: Array, log_arr: Array) -> void:
	for entry in snapshot:
		var target: Combatant = entry.get("unit", null)
		if target == null:
			continue
		var linked: Combatant = null
		for mark_effect in target.active_effects:
			if Combatant._effect_get(mark_effect, "effect_id", "") == "voodoo_marked":
				linked = mark_effect.get("linked", null)
				break
		if linked == null or linked == target or linked.current_hp <= 0:
			continue

		var previous_effects: Array = entry.get("effects", [])
		var copied_count: int = 0
		for effect in target.active_effects:
			if not (effect is Dictionary):
				continue
			var effect_data: Dictionary = effect
			if _effect_existed_before(effect_data, previous_effects) or not _is_voodoo_debuff(effect_data):
				continue

			var copied_effect: Dictionary = effect_data.duplicate(true)
			copied_effect.erase("linked")
			copied_effect["voodoo_copy"] = true
			var source: String = str(copied_effect.get("source_ability", "Дебафф"))
			copied_effect["source_ability"] = source + " (кукла вуду)"
			linked.active_effects.append(copied_effect)

			var stat: String = str(Combatant._effect_get(copied_effect, "stat", ""))
			var value: int = int(Combatant._effect_get(copied_effect, "value", 0))
			if value < 0 and stat in ["damage", "damage_percent", "armor", "accuracy", "evasion", "initiative", "crit", "max_hp"]:
				linked.apply_stat_change(stat, value)
			elif stat == "stun":
				linked.is_stunned = true
				linked.check_stance_interruption("stun")
				_notify_stun_applied(linked)
			copied_count += 1

		if copied_count > 0:
			log_arr.append("  → [Кукла вуду] %s копирует %d дебафф(ов) с %s." % [linked.unit_name, copied_count, target.unit_name])
## _apply_tormentor_regen / _block_buff_for_hopeless_stance / _apply_buff_to_unit
## перенесены в battle_effects.gd (см. effects._apply_buff_to_unit() и т.п.).

# (Звёзды-Горы-Пустыня-Глубина-Остров-Топь — см. battle_locations.gd, BattleLocations.)
