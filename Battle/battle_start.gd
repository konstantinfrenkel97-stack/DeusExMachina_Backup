extends RefCounted
class_name BattleStart

## Начало боя: расстановка команд, эффекты миссии/немезиса, стартовые пассивки и эффекты предметов.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Применяет модификаторы боя миссии (HP%, заряды пассивки, баффы) к врагам и героям.
func _apply_pending_mission_modifiers() -> void:
	_apply_modifier_list(CombatManager.pending_enemy_modifiers, _scene.enemies_team)
	_apply_modifier_list(CombatManager.pending_hero_modifiers, _scene.heroes_team)
	_apply_pending_mission_party_effects()
	_apply_pending_nemesis_buffs()
	_apply_pending_nemesis_enemy_effects()
	_apply_battle_start_item_effects()
	_scene._rum_spell_whole_team_active = CombatManager.pending_rum_spell_whole_team
	CombatManager.pending_rum_spell_whole_team = false
	_scene.desert_immune_this_battle = CombatManager.pending_desert_immunity
	CombatManager.pending_desert_immunity = false
	_scene.hell_immune_this_battle = CombatManager.pending_hell_immunity
	CombatManager.pending_hell_immunity = false
	CombatManager.pending_enemy_modifiers = []
	CombatManager.pending_hero_modifiers = []

## Немезис: если этот бой — против ближайшего непобеждённого немезида выбранной
## локации, применяет все отложенные баффы (CampaignState.pending_nemesis_buffs),
## зарегистрированные для этой пары (локация, бог), и снимает их из очереди —
## это одноразовые сюжетные бонусы, не повторяющиеся на будущих боях.
func _apply_pending_nemesis_buffs() -> void:
	if CampaignState.pending_nemesis_buffs.is_empty():
		return
	var location_id: String = CombatManager.selected_location_id
	if location_id == "":
		return
	var next_nemesis_path := CampaignState.get_next_nemesis_path(location_id)
	if next_nemesis_path == "":
		return
	var fighting_nemesis := false
	for enemy_value in _scene.enemies_team:
		var enemy: Combatant = enemy_value as Combatant
		if enemy != null and enemy.source_resource_path == next_nemesis_path:
			fighting_nemesis = true
			break
	if not fighting_nemesis:
		return
	var consumed: Array = []
	for entry_value in CampaignState.pending_nemesis_buffs:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("location_id", "")) != location_id:
			continue
		var god_path: String = str(entry.get("god_path", ""))
		var hero: Combatant = _find_hero_by_resource_path(god_path) if god_path != "" else null
		if hero == null or hero.current_hp <= 0:
			continue
		var majesty_delta: int = int(entry.get("majesty_delta", 0))
		if majesty_delta != 0:
			hero.modify_majesty(majesty_delta)
			_scene._log_combat("✨ [Немезис] %s: %+d величия за грядущую встречу с немезидом." % [hero.unit_name, majesty_delta])
		var buff_stat: int = int(entry.get("buff_stat", -1))
		if buff_stat >= 0:
			var buff_duration: int = int(entry.get("buff_duration", -1))
			_apply_mission_buff({"stat": buff_stat, "value": int(entry.get("buff_value", 0)), "duration": buff_duration}, hero)
			_scene._log_combat("✨ [Немезис] %s получает бафф перед встречей с немезидом." % hero.unit_name)
		consumed.append(entry)
	for entry in consumed:
		CampaignState.pending_nemesis_buffs.erase(entry)

## Немезис: отложенные эффекты на ВРАЖЕСКУЮ сторону боя (CampaignState.pending_nemesis_enemy_effects)
## — в отличие от _apply_pending_nemesis_buffs() выше (баффует своего бога), эти трогают самого
## немезида и его свиту. Срабатывает один раз, сразу после спавна врагов, до первого раунда.
func _apply_pending_nemesis_enemy_effects() -> void:
	if CampaignState.pending_nemesis_enemy_effects.is_empty():
		return
	var location_id: String = CombatManager.selected_location_id
	if location_id == "":
		return
	var next_nemesis_path := CampaignState.get_next_nemesis_path(location_id)
	if next_nemesis_path == "":
		return
	var nemesis_unit: Combatant = null
	for enemy in _scene.enemies_team:
		if enemy != null and enemy.source_resource_path == next_nemesis_path:
			nemesis_unit = enemy
			break
	if nemesis_unit == null:
		return
	var consumed: Array = []
	var cursed_targets: Array = []  # чтобы несколько «вуду»-исходов не выбрали одну и ту же цель
	for entry_value in CampaignState.pending_nemesis_enemy_effects:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("location_id", "")) != location_id:
			continue
		var kind: String = str(entry.get("kind", ""))
		var value: float = float(entry.get("value", 0.0))
		match kind:
			"nemesis_hp_percent":
				if nemesis_unit.current_hp > 0:
					var _nhp_dmg: int = int(nemesis_unit.max_hp * value / 100.0)
					if _nhp_dmg > 0:
						var _nhp_before: int = nemesis_unit.current_hp
						nemesis_unit.take_damage(_nhp_dmg)
						_scene._log_combat("⚡ [Немезис] %s теряет %d HP (%d%%) ещё до начала боя. HP: %d → %d" % [nemesis_unit.unit_name, _nhp_dmg, int(value), _nhp_before, nemesis_unit.current_hp])
			"others_hp_percent":
				for other in _scene.enemies_team:
					if other != null and other != nemesis_unit and other.current_hp > 0:
						var _ohp_dmg: int = int(other.max_hp * value / 100.0)
						if _ohp_dmg > 0:
							var _ohp_before: int = other.current_hp
							other.take_damage(_ohp_dmg)
							_scene._log_combat("⚡ [Немезис] %s теряет %d HP (%d%%) ещё до начала боя. HP: %d → %d" % [other.unit_name, _ohp_dmg, int(value), _ohp_before, other.current_hp])
			"voodoo_curse_random_except_nemesis":
				var candidates: Array = []
				for other in _scene.enemies_team:
					if other != null and other != nemesis_unit and other.current_hp > 0 and not cursed_targets.has(other):
						candidates.append(other)
				if not candidates.is_empty() and nemesis_unit.current_hp > 0:
					var chosen: Combatant = candidates.pick_random()
					cursed_targets.append(chosen)
					_scene.marks.apply_voodoo_mark(nemesis_unit, chosen, 1)
		consumed.append(entry)
	for entry in consumed:
		CampaignState.pending_nemesis_enemy_effects.erase(entry)
	if not consumed.is_empty():
		_scene._field._update_all_visuals()

## Друидическое зелье силы (Items/Trinkets/Rare/druidic_potion_of_strength.tres):
## носитель получает +20 атаки на первый раунд боя. У предметов в этом проекте нет
## общего движка эффектов — каждый обрабатывается отдельной проверкой has_item_effect(),
## как и все остальные (см. соседние вызовы по всему файлу).
func _apply_battle_start_item_effects() -> void:
	for unit_value in _scene.heroes_team:
		var hero: Combatant = unit_value as Combatant
		if hero == null or hero.current_hp <= 0:
			continue
		if hero.has_item_effect("druidic_potion_of_strength"):
			hero.apply_stat_change("damage", 20)
			hero.active_effects.append({"stat": "damage", "value": 20, "duration": 1, "effect_id": "druidic_potion_of_strength", "source_ability": "Друидическое зелье силы"})

func _apply_pending_mission_party_effects() -> void:
	var majesty_delta: int = int(CombatManager.pending_mission_hero_majesty_delta)
	if majesty_delta != 0:
		for unit_value in _scene.heroes_team:
			var hero: Combatant = unit_value as Combatant
			if hero != null and hero.current_hp > 0:
				hero.modify_majesty(majesty_delta)
	var fantasy_delta: int = int(CombatManager.pending_mission_fantasy_delta)
	if fantasy_delta != 0:
		_scene.current_fantasy = clampi(_scene.current_fantasy + fantasy_delta, 0, _scene.max_fantasy)
	for buff in CombatManager.pending_mission_hero_buffs:
		if buff == null:
			continue
		for unit_value in _scene.heroes_team:
			var hero: Combatant = unit_value as Combatant
			if hero != null and hero.current_hp > 0:
				_apply_mission_buff(buff, hero)
	for buff in CombatManager.pending_mission_enemy_buffs:
		if buff == null:
			continue
		for unit_value in _scene.enemies_team:
			var enemy: Combatant = unit_value as Combatant
			if enemy != null and enemy.current_hp > 0:
				_apply_mission_buff(buff, enemy)
	_apply_pending_mission_target_effects()
	var strongest: Combatant = _get_strongest_attack_hero()
	if strongest != null:
		for buff in CombatManager.mission_strongest_hero_buffs:
			if buff != null:
				_apply_mission_buff(buff, strongest)
	# Баффы на весь отряд, действующие до конца миссии (не очищаются здесь — применяются в каждом бою).
	for buff in CombatManager.mission_team_buffs:
		if buff == null:
			continue
		for unit_value in _scene.heroes_team:
			var team_buff_hero: Combatant = unit_value as Combatant
			if team_buff_hero != null and team_buff_hero.current_hp > 0:
				_apply_mission_buff(buff, team_buff_hero)
	# Баффы на конкретных богов, действующие до конца миссии (не очищаются здесь — применяются в каждом бою).
	for entry_value in CombatManager.mission_target_buffs:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var entry_path: String = str(entry.get("resource_path", ""))
		if entry_path == "":
			continue
		var entry_hero: Combatant = _find_hero_by_resource_path(entry_path)
		if entry_hero == null or entry_hero.current_hp <= 0:
			continue
		var entry_raw_buffs = entry.get("buffs", [])
		for buff in (entry_raw_buffs if entry_raw_buffs is Array else []):
			if buff != null:
				_apply_mission_buff(buff, entry_hero)
	CombatManager.pending_mission_fantasy_delta = 0
	CombatManager.pending_mission_hero_majesty_delta = 0
	CombatManager.pending_mission_hero_buffs = []
	CombatManager.pending_mission_enemy_buffs = []
	CombatManager.pending_mission_target_effects = []

func _apply_pending_mission_target_effects() -> void:
	for effect_value in CombatManager.pending_mission_target_effects:
		if not (effect_value is Dictionary):
			continue
		var effect: Dictionary = effect_value
		var target_path: String = str(effect.get("resource_path", ""))
		if target_path == "":
			continue
		var target: Combatant = _find_hero_by_resource_path(target_path)
		if target == null or target.current_hp <= 0:
			continue
		var hp_delta: int = int(effect.get("current_hp_percent_delta", 0))
		if hp_delta < 0:
			var damage_amount: int = int(float(target.current_hp) * float(abs(hp_delta)) / 100.0)
			if damage_amount > 0:
				target.apply_stat_change("hp", -damage_amount)
		elif hp_delta > 0:
			var heal_amount: int = int(float(target.max_hp) * float(hp_delta) / 100.0)
			if heal_amount > 0:
				target.apply_stat_change("hp", heal_amount)
		var target_majesty_delta: int = int(effect.get("majesty_delta", 0))
		if target_majesty_delta != 0:
			target.modify_majesty(target_majesty_delta)
		var raw_buffs = effect.get("buffs", [])
		var buffs: Array = raw_buffs if raw_buffs is Array else []
		for buff in buffs:
			if buff != null:
				_apply_mission_buff(buff, target)

func _find_hero_by_resource_path(path: String) -> Combatant:
	for unit_value in _scene.heroes_team:
		var hero: Combatant = unit_value as Combatant
		if hero != null and hero.source_resource_path == path:
			return hero
	return null

func _get_strongest_attack_hero() -> Combatant:
	var best: Combatant = null
	var best_damage: int = -999999
	for unit_value in _scene.heroes_team:
		var hero: Combatant = unit_value as Combatant
		if hero == null or hero.current_hp <= 0:
			continue
		if hero.damage > best_damage:
			best = hero
			best_damage = hero.damage
	return best

func _apply_modifier_list(mods: Array, team: Array) -> void:
	for m in mods:
		if m == null:
			continue
		var targets: Array = []
		if int(m.target_position) <= 0:
			targets = _scene._field._get_living_team_members(team)
		else:
			var idx := int(m.target_position) - 1
			if idx >= 0 and idx < team.size() and team[idx] != null and team[idx].current_hp > 0:
				targets = [team[idx]]
		for unit in targets:
			if int(m.max_hp_delta) != 0:
				unit.max_hp = maxi(1, unit.max_hp + int(m.max_hp_delta))
				unit.current_hp = maxi(1, unit.current_hp + int(m.max_hp_delta))
			if int(m.hp_percent) > 0:
				unit.current_hp = maxi(1, int(unit.max_hp * int(m.hp_percent) / 100.0))
			if int(m.passive_charges) >= 0:
				unit.mission_charges = int(m.passive_charges)
			for b in m.buffs:
				if b != null:
					_apply_mission_buff(b, unit)
			if bool(m.disable_passive):
				unit.special_effect_type = ""
			if bool(m.bless_early_transform) and unit.special_effect_type == "novice_transformation":
				unit.special_effect_type = "novice_transformation_blessed"
				_scene._log_combat("✨ [Благословение] %s получает благословение от своего кумира." % unit.unit_name)

## Бафф миссии на юнита (по enum BuffEntry.Stat: 0=урон,1=удача,2=точность,3=уклонение,4=броня,5=крит,6=инициатива,7=стан,8=регенерация,9=периодический урон,10=величие за ход).
## b — либо ресурс BuffEntry, либо словарь {"stat","value","duration"} (напр. из pending_nemesis_buffs).
func _apply_mission_buff(b, unit: Combatant) -> void:
	var stat: int = int(b.stat) if b is Resource else int(b.get("stat", 0))
	var val: int = int(b.value) if b is Resource else int(b.get("value", 0))
	var dur: int = int(b.duration) if b is Resource else int(b.get("duration", -1))
	var effect_stat: String = "mission_buff"
	match stat:
		0:
			unit.damage_modifier_flat += val
			effect_stat = "damage"
		1:
			unit.crit_modifier += val / 100.0
			effect_stat = "luck"
		2:
			unit.accuracy_modifier += val
			effect_stat = "accuracy"
		3:
			unit.evasion_modifier += val
			effect_stat = "evasion"
		4:
			unit.armor_modifier += val
			effect_stat = "armor"
		5:
			unit.crit_modifier += val / 100.0
			effect_stat = "crit"
		6:
			unit.initiative = maxi(0, unit.initiative + val)
			effect_stat = "initiative"
		7:
			unit.is_stunned = true
			effect_stat = "stun"
		8:
			effect_stat = "regeneration"
		9:
			effect_stat = "periodic_damage"
			var percent_flag: bool = bool(b.percent_of_max_hp) if b is Resource else bool(b.get("percent_of_max_hp", false))
			if percent_flag:
				val = int(unit.max_hp * val / 100.0)
		10:
			effect_stat = "majesty_regen"
	unit.active_effects.append({"stat": effect_stat, "value": val, "duration": dur, "source_ability": "Заклинание"})

func _spawn_teams_from_resources():
	# Загружаем героев
	for i in range(4):
		var hero_path = CombatManager.selected_heroes[i]
		if hero_path != "":
			var res = CampaignState.load_character_resource(hero_path)
			var hero = Combatant.new(res)
			# load_character_resource() дублирует ресурс (resource.duplicate()), а у
			# дубликата Godot всегда очищает resource_path — из-за этого source_resource_path
			# (выставляемый в Combatant._init() из resource.resource_path) у героев всегда
			# оказывался пустым, что тихо ломало статистику урона/лечения за миссию и поиск
			# героя по пути для баффов немезидов (_find_hero_by_resource_path). Проставляем
			# явно из исходного пути выбора.
			hero.source_resource_path = hero_path
			hero.current_hp = clampi(CampaignState.get_god_current_hp(hero_path), 0, hero.max_hp)
			if CombatManager.is_mission_battle:
				hero.current_majesty = MissionState.get_hero_majesty(hero_path)
			hero.is_enemy = false
			hero.position_index = i
			_scene.heroes_team[i] = hero
			hero.damage_taken.connect(_scene._unit_events._on_unit_damaged.bind(hero))
			hero.healed.connect(_scene._unit_events._on_unit_healed.bind(hero))
			hero.died.connect(_scene._unit_events._on_unit_died.bind(hero))
			hero.phoenix_feather_shield_triggered.connect(_scene._unit_events._on_phoenix_shield_triggered.bind(hero))
			hero.koschei_life_shield_triggered.connect(_scene._unit_events._on_koschei_life_shield_triggered.bind(hero))
			hero.immortal_death_shield_triggered.connect(_scene._unit_events._on_immortal_death_shield_triggered.bind(hero))
			hero.stance_broken.connect(_scene._unit_events._on_unit_stance_broken.bind(hero))
			
			var pos_node_name = "HeroPositions/Pos" + str(i + 1)
			if _scene.has_node(pos_node_name):
				_scene._field._create_visual(hero, pos_node_name, _scene.hero_visuals, i)
			else:
				push_error("Узел не найден: " + pos_node_name)

	# Загружаем врагов
	for i in range(4):
		var enemy_path = CombatManager.selected_enemies[i]
		if enemy_path != "":
			var res = load(enemy_path) as CharacterResource
			var enemy = Combatant.new(res)
			enemy.is_enemy = true
			enemy.position_index = i
			var _perm_debuff: int = int(CampaignState.permanent_enemy_accuracy_debuffs.get(enemy.unit_name, 0))
			if _perm_debuff != 0:
				enemy.accuracy_modifier += _perm_debuff
			_scene.enemies_team[i] = enemy
			enemy.damage_taken.connect(_scene._unit_events._on_unit_damaged.bind(enemy))
			enemy.died.connect(_scene._unit_events._on_unit_died.bind(enemy))
			enemy.phoenix_feather_shield_triggered.connect(_scene._unit_events._on_phoenix_shield_triggered.bind(enemy))
			enemy.koschei_life_shield_triggered.connect(_scene._unit_events._on_koschei_life_shield_triggered.bind(enemy))
			enemy.immortal_death_shield_triggered.connect(_scene._unit_events._on_immortal_death_shield_triggered.bind(enemy))
			enemy.stance_broken.connect(_scene._unit_events._on_unit_stance_broken.bind(enemy))
			
			var pos_node_name = "EnemyPositions/Pos" + str(i + 1)
			if _scene.has_node(pos_node_name):
				_scene._field._create_visual(enemy, pos_node_name, _scene.enemy_visuals, i)
			else:
				push_error("Узел не найден: " + pos_node_name)
	
	_scene._field._compact_team(_scene.heroes_team)
	_scene._field._compact_team(_scene.enemies_team)
	_trigger_battle_start_passives()
	_scene._passives._apply_kappa_auras()
	_scene._field._update_all_visuals()

func _trigger_battle_start_passives():
	for hero in _scene.heroes_team:
		if hero and hero.special_effect_type == "osiris_majesty_aura":
			# Золотой саркофаг: удваивает величие от пассивки Осириса (15 → 30).
			var _osiris_aura_val = 30 if hero.has_item_effect("osiris_sarcophagus_double_aura") else 15
			_scene._log_combat("✨ [Осирис] Все союзники получают %d величия." % _osiris_aura_val)
			for ally in _scene.heroes_team:
				if ally and ally.current_hp > 0:
					ally.modify_majesty(_osiris_aura_val)
	
	# Капитан: все другие союзники получают +2 инициативы
	for unit in _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "captain_ally_initiative":
			for ally in _scene.enemies_team:
				if ally and ally.current_hp > 0 and ally != unit:
					ally.initiative += 2
			_scene._log_combat("🏴‍☠️ [Капитан] %s: все союзники получают +2 инициативы." % unit.unit_name)
			break
	
	# Сирена: +10 уклонения за каждого живого союзника
	_scene._passives._apply_siren_evasion_auras()
