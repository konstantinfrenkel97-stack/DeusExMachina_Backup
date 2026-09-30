extends RefCounted
class_name BattleTurns

## Порядок ходов: новый раунд, очередь инициативы, передача хода, завершение хода, ход врага.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

func _start_new_round():
	if _scene._outcome._check_battle_end():
		return


	# ═══ Туннели — Шаман: +20 брони, если не перемещался в прошлом раунде ═══
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "shaman_no_move_armor":
			if _scene.current_round > 0 and not unit.moved_this_round:
				unit.apply_stat_change("armor", 20)
				unit.active_effects.append({"stat": "armor", "value": 20, "duration": 1, "effect_id": "shaman_no_move_armor", "source_ability": "Пассивка"})
				_scene._log_combat("🛡️ [Каменная кожа] %s: +20 брони за отсутствие перемещений." % unit.unit_name)
	
	# ═══ Звёзды — Водолей: если не перемещался в прошлом раунде — +15 урона (навсегда) ═══
	for unit_aq in _scene.heroes_team + _scene.enemies_team:
		if unit_aq and unit_aq.current_hp > 0 and unit_aq.special_effect_type == "aquarius_no_move_attack":
			if _scene.current_round > 0 and not unit_aq.moved_this_round:
				_scene.effects._apply_buff_to_unit(unit_aq, "damage", 15, -1, "aquarius_no_move_attack", "Пассивка")
				_scene._log_combat("💧 [Водолей] %s: +15 урона за отсутствие перемещений (навсегда)." % unit_aq.unit_name)

	# ═══ Сад — Альрауне: каждый ход восстанавливает 30% здоровья; периодический урон отключает пассивку ═══
	for unit_ar in _scene.heroes_team + _scene.enemies_team:
		if unit_ar and unit_ar.current_hp > 0 and unit_ar.special_effect_type == "alraune_regen":
			var _ar_poisoned = false
			for _ar_e in unit_ar.active_effects:
				if Combatant._effect_get(_ar_e, "stat", "") == "periodic_damage":
					_ar_poisoned = true
					break
			if _ar_poisoned:
				continue
			var _ar_heal = int(unit_ar.max_hp * 0.30)
			if _ar_heal > 0:
				var _ar_hp_b = unit_ar.current_hp
				unit_ar.apply_stat_change("hp", _ar_heal)
				_scene._log_combat("🌿 [Альрауне] %s восстанавливает %d HP (%d → %d)." % [unit_ar.unit_name, _ar_heal, _ar_hp_b, unit_ar.current_hp])

	# ═══ Сад — Друид: в начале раунда все союзники восстанавливают 5% здоровья ═══
	for unit_dr in _scene.heroes_team + _scene.enemies_team:
		if unit_dr and unit_dr.current_hp > 0 and unit_dr.special_effect_type == "druid_regen_aura":
			var _dr_team = _scene.enemies_team if unit_dr.is_enemy else _scene.heroes_team
			for _dr_ally in _dr_team:
				if _dr_ally and _dr_ally.current_hp > 0:
					var _dr_heal = int(_dr_ally.max_hp * 0.05)
					if _dr_heal > 0:
						_dr_ally.apply_stat_change("hp", _dr_heal)
			_scene._log_combat("🌻 [Друид] %s: все союзники восстанавливают 5%% HP." % unit_dr.unit_name)

	# ═══ Сад — Сатир: «Чарующая песня» — в начале раунда эффект дебаффа растёт на 5 ═══
	for unit_st in _scene.heroes_team + _scene.enemies_team:
		if unit_st and unit_st.current_hp > 0 and unit_st.active_stance and unit_st.active_stance.stance_effect_type == "satyr_charm":
			var _st_stacks = unit_st.get_meta("satyr_charm_stacks", 0) + 5
			unit_st.set_meta("satyr_charm_stacks", _st_stacks)
			var _st_foe_team = _scene.heroes_team if unit_st.is_enemy else _scene.enemies_team
			for _st_foe in _st_foe_team:
				if _st_foe and _st_foe.current_hp > 0:
					_st_foe.apply_stat_change("damage", -5)
					_st_foe.active_effects.append({"stat": "damage", "value": -5, "duration": -1, "effect_id": "satyr_charm", "source_ability": "Чарующая песня"})
					# Локация «Сад»: при дебаффе на героя — +15 чистого урона (как у обычных дебаффов).
					if CombatManager.selected_location_id == "garden" and not _st_foe.is_enemy:
						var _st_g_hp = _st_foe.current_hp
						_st_foe.take_damage(15)
						_scene._log_combat("  → [Сад] %s получает 15 чистого урона за дебафф песни. HP: %d → %d" % [_st_foe.unit_name, _st_g_hp, _st_foe.current_hp])
				_scene._log_combat("🎵 [Чарующая песня] %s: враги теряют ещё 5 атаки (всего -%d)." % [unit_st.unit_name, _st_stacks])

	# ═══ Предметы: пассивная регенерация фантазии в начале раунда ═══
	var _item_fantasy_regen: int = 0
	for hero_it in _scene.heroes_team:
		if hero_it and hero_it.current_hp > 0:
			for item_it in hero_it.get_equipped_items():
				_item_fantasy_regen += item_it.fantasy_regen_per_turn
	# Сюжетный бонус до конца миссии (см. MissionOutcome.mission_fantasy_regen_per_turn_bonus).
	_item_fantasy_regen += CombatManager.mission_fantasy_regen_per_turn
	if _item_fantasy_regen != 0:
		var _fantasy_before: int = _scene.current_fantasy
		_scene.current_fantasy = clampi(_scene.current_fantasy + _item_fantasy_regen, 0, _scene.max_fantasy)
		if _scene.current_fantasy != _fantasy_before:
			_scene._log_combat("✨ [Артефакты] Восстановление фантазии: %+d (%d → %d)." % [_item_fantasy_regen, _fantasy_before, _scene.current_fantasy])

	# ═══ Предметы: пассивная регенерация величия и HP в начале раунда ═══
	for hero_reg in _scene.heroes_team:
		if hero_reg == null or hero_reg.current_hp <= 0:
			continue
		var _item_majesty_regen: int = 0
		var _item_hp_regen_pct: float = 0.0
		for item_reg in hero_reg.get_equipped_items():
			_item_majesty_regen += item_reg.majesty_regen_per_turn
			_item_hp_regen_pct += item_reg.hp_regen_percent
		# Баффы миссии «величие за ход» (BuffEntry.Stat.MAJESTY_PER_TURN, напр. бонус Осириса против немезиса).
		for _mr_eff in hero_reg.active_effects:
			if str(Combatant._effect_get(_mr_eff, "stat", "")) == "majesty_regen":
				_item_majesty_regen += int(Combatant._effect_get(_mr_eff, "value", 0))
		if _item_majesty_regen != 0:
			var _majesty_before: int = hero_reg.current_majesty
			hero_reg.modify_majesty(_item_majesty_regen)
			if hero_reg.current_majesty != _majesty_before:
				_scene._log_combat("✨ [Артефакт] %s: величие %+d (%d → %d)." % [hero_reg.unit_name, _item_majesty_regen, _majesty_before, hero_reg.current_majesty])
		if _item_hp_regen_pct != 0.0:
			var _hp_regen_amount = int(hero_reg.max_hp * _item_hp_regen_pct / 100.0)
			if _hp_regen_amount > 0:
				var _hp_before_reg = hero_reg.current_hp
				hero_reg.apply_stat_change("hp", _hp_regen_amount)
				if hero_reg.current_hp != _hp_before_reg:
					_scene._log_combat("✨ [Артефакт] %s восстанавливает %d HP (%d → %d)." % [hero_reg.unit_name, _hp_regen_amount, _hp_before_reg, hero_reg.current_hp])

	# ═══ Артефакт «Красивый камень»: свободное место в отряде героев — призыв Булыжника ═══
	for hero_bs in _scene.heroes_team:
		if hero_bs and hero_bs.current_hp > 0 and hero_bs.has_item_effect("beautiful_stone_summon_boulder"):
			_scene._passives._summon_beautiful_stone_boulder()
			break

	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0:
			unit.start_new_round()

	# ═══ Цербер: «Трехголовый» — переключение числа ходов между раундами ═══
	# Ульта, применённая в прошлом раунде, даёт ТРИ хода в этом; после него число ходов возвращается.
	var _cb_seen: Dictionary = {}
	for unit_cb in _scene.heroes_team + _scene.enemies_team:
		# Большой юнит (Цербер) стоит в команде в двух клетках — обрабатываем один раз.
		if unit_cb == null or unit_cb.current_hp <= 0 or _cb_seen.has(unit_cb):
			continue
		_cb_seen[unit_cb] = true
		if unit_cb.has_meta("cerberus_three_active"):
			unit_cb.actions_per_round = int(unit_cb.get_meta("cerberus_base_actions", 1))
			unit_cb.remove_meta("cerberus_three_active")
			_scene.effects._remove_effect_id(unit_cb, "cerberus_three_headed")
		if unit_cb.has_meta("cerberus_three_pending"):
			unit_cb.remove_meta("cerberus_three_pending")
			unit_cb.set_meta("cerberus_base_actions", unit_cb.actions_per_round)
			unit_cb.actions_per_round = 3
			unit_cb.set_meta("cerberus_three_active", true)
			_scene._log_combat("🐕 [Трехголовый] %s совершает три действия в этом раунде (величия за них не получает)." % unit_cb.unit_name)

	# Тик марок: сбрасываем triggered_units, уменьшаем rounds_left
	_scene.marks.tick()
	_scene._passives._apply_kappa_auras()
	_scene._passives._apply_siren_evasion_auras()
	_scene._passives._apply_mentor_accuracy_auras()
	
	# Шива: в начале раунда базовая удача принимает случайное значение от 0 до 30%
	# (Дамару поднимает верхнюю границу до 50%)
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "shiva_random_luck":
			var _shiva_cap = 0.50 if unit.has_item_effect("shiva_damaru_luck_cap_50") else 0.30
			unit.base_crit_chance = randf() * _shiva_cap
			_scene._log_combat("🎲 [Шива] %s: удача установлена на %d%%" % [unit.unit_name, int(unit.base_crit_chance * 100)])
	
	# ═══ АД — Страдающая душа: на позиции 1 получает +4 инициативы и +20 уклонения ═══
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "soul_position_buff":
			if unit.position_index == 0:
				unit.apply_stat_change("initiative", 4)
				unit.apply_stat_change("evasion", 20)
				unit.active_effects.append({"stat": "initiative", "value": 4, "duration": 1, "effect_id": "soul_position", "source_ability": "Пассивка"})
				unit.active_effects.append({"stat": "evasion", "value": 20, "duration": 1, "effect_id": "soul_position", "source_ability": "Пассивка"})
				_scene._log_combat("👻 [Страдающая душа] %s на позиции 1: +4 инициативы, +20 уклонения." % unit.unit_name)
	
	# ═══ ДЖУНГЛИ — Ракшас: пока жив, все противники теряют 10 удачи (aura) ═══
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "rakshasa_crit_aura":
			var _ra_foes = _scene.heroes_team if unit.is_enemy else _scene.enemies_team
			for _ra_f in _ra_foes:
				if _ra_f != null and _ra_f.current_hp > 0:
					_ra_f.apply_stat_change("crit", -10)
					_ra_f.active_effects.append({"stat": "crit", "value": -10, "duration": 1, "effect_id": "rakshasa_aura", "source_ability": "Пассивка Ракшас"})
	# ═══ ДЖУНГЛИ — Ракшас: «Дисгармония» стойка — противники -10 удачи -10 точности пока активна ═══
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.active_stance != null and unit.active_stance.stance_effect_type == "rakshasa_disharmony":
			var _dh_foes = _scene.heroes_team if unit.is_enemy else _scene.enemies_team
			for _dh_f in _dh_foes:
				if _dh_f != null and _dh_f.current_hp > 0:
					_dh_f.apply_stat_change("crit", -10)
					_dh_f.apply_stat_change("accuracy", -10)
					_dh_f.active_effects.append({"stat": "crit", "value": -10, "duration": 1, "effect_id": "rakshasa_disharmony", "source_ability": "Дисгармония"})
					_dh_f.active_effects.append({"stat": "accuracy", "value": -10, "duration": 1, "effect_id": "rakshasa_disharmony", "source_ability": "Дисгармония"})
	# ═══ Асура: сброс временного переопределения удачи (asura_chaos) по истечении ═══
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit != null and unit.has_meta("asura_chaos_crit_turns"):
			var _ac_t = int(unit.get_meta("asura_chaos_crit_turns", 0)) - 1
			if _ac_t <= 0:
				unit.remove_meta("asura_chaos_crit_override")
				unit.remove_meta("asura_chaos_crit_turns")
			else:
				unit.set_meta("asura_chaos_crit_turns", _ac_t)

	# ═══ Замок — Мистический шут: +1% удачи за каждую недостающую единицу фантазии ═══
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "jester_fantasy_luck":
			# Удалить старый бонус удачи
			for _ji in range(unit.active_effects.size() - 1, -1, -1):
				if Combatant._effect_get(unit.active_effects[_ji], "effect_id", "") == "jester_fantasy_luck":
					var _old_val = Combatant._effect_get(unit.active_effects[_ji], "value", 0)
					unit.crit_modifier -= float(_old_val) / 100.0
					unit.active_effects.remove_at(_ji)
			var _missing_fantasy = maxi(0, _scene.max_fantasy - _scene.current_fantasy)
			if _missing_fantasy > 0:
				unit.apply_stat_change("crit", _missing_fantasy)
				unit.active_effects.append({"stat": "crit", "value": _missing_fantasy, "duration": -1, "effect_id": "jester_fantasy_luck", "source_ability": "jester_fantasy_luck"})
				_scene._log_combat("🃏 [Шут] %s: +%d%% удачи за %d недостающей фантазии." % [unit.unit_name, _missing_fantasy, _missing_fantasy])
	
	# Сброс отслеживания смертей (Замок: Рыцарь «Отважный удар»)
	_scene._heroes_died_this_round = false
	_scene._enemies_died_this_round = false
	# Сброс заклинаний
	_scene.spells_used_this_round = 0
	_scene.max_spells_per_round = 2 if CombatManager.can_cast_two_spells() else 1
	
	_scene.wait_counter = 0
	_scene.current_round += 1
	# Новичок: благословлённый (метка Арены) превращается на 1 ход раньше обычного.
	if _scene.current_round == 2:
		_scene._passives._apply_novice_transformation("novice_transformation_blessed")
	# Новичок: на 3-м раунде превращается в Гладиатора/Гоплита
	if _scene.current_round == 3:
		_scene._passives._apply_novice_transformation()
		_scene._passives._apply_oboroten_round3_power()
	_build_turn_order()
	
	if _scene.turn_order.is_empty():
		return
	
	_scene._log_combat("--- Раунд %d ---" % _scene.current_round)
	
	# ═══ ЭФФЕКТЫ ЛОКАЦИЙ (начало раунда) ═══
	_scene.locations._location_helheim()
	_scene.locations._location_hell()
	_scene.locations._location_tunnels()
	_scene.locations._location_desert()
	_scene.locations._location_stars()
	_scene.locations._location_depths_label()
	_scene.locations._location_island()
	_scene.locations._location_swamp()
	_scene._field._update_all_visuals()
	
	if _scene._outcome._check_battle_end():
		return
	
	_next_turn.call_deferred()

## Строит очередь ходов раунда. Юнит с несколькими ходами (actions_per_round > 1) стоит в
## очереди столько раз, сколько ходов ему осталось, — все копии подряд по одной инициативе.
## Юнит, чей ход идёт прямо сейчас (turn_open), уже вынут из очереди — его текущий ход
## не считается, чтобы пересборка очереди посреди хода (призыв и т.п.) не добавила лишний.
func _build_turn_order():
	_scene.turn_order.clear()
	var _queue_units: Array = []
	var _queue_index: Dictionary = {}
	for u in _scene.heroes_team + _scene.enemies_team:
		# Большой юнит (is_large) стоит в команде сразу в двух клетках — в очередь он попадает один раз.
		if u and u.current_hp > 0 and not _queue_index.has(u):
			_queue_index[u] = _queue_units.size()
			_queue_units.append(u)
	# При равной инициативе — порядок команд; заодно копии одного юнита всегда идут подряд.
	_queue_units.sort_custom(func(a, b):
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		return _queue_index[a] < _queue_index[b]
	)
	for u in _queue_units:
		var copies: int = u.remaining_actions() - (1 if (u.turn_open and u == _scene.active_unit) else 0)
		for _i in range(maxi(copies, 0)):
			_scene.turn_order.append(u)

func _recalculate_turn_order():
	_build_turn_order()
	_scene.turn_order = _scene.turn_order.filter(func(u): return not u.has_acted_this_round)

func _next_turn():
	if _scene.waiting_for_player or not _scene.battle_running:
		return
	
	while _scene.turn_order.size() > 0:
		var next_unit = _scene.turn_order[0]
		if next_unit == null or next_unit.current_hp <= 0 or next_unit.has_acted_this_round:
			_scene.turn_order.pop_front()
		else:
			break
	
	if _scene.turn_order.is_empty():
		if _scene._outcome._check_battle_end():
			return
		_start_new_round()
		return
	
	_scene.active_unit = _scene.turn_order.pop_front()
	_scene.active_unit.turn_open = true
	_scene._turn_serial += 1
	_scene._duna_turn_heal = 0
	
	if _scene.active_unit.current_hp <= 0:
		_next_turn.call_deferred()
		return
	
	# ═══ Угорь: метка челюсти — отложенная атака 100% в начале след. хода ═══
	if _scene.active_unit.jaw_mark_target != null:
		var _jm_target = _scene.active_unit.jaw_mark_target
		_scene.active_unit.jaw_mark_target = null
		if _jm_target and _jm_target.current_hp > 0 and _scene.active_unit.current_hp > 0:
			var _jm_dmg = _scene.active_unit.damage
			var _jm_hp_b = _jm_target.current_hp
			_jm_target.take_damage(_jm_dmg)
			_scene._log_combat("🦈 [Метка челюсти] %s наносит %d урона %s. HP: %d → %d" % [_scene.active_unit.unit_name, _jm_dmg, _jm_target.unit_name, _jm_hp_b, _jm_target.current_hp])
			if _jm_target.current_hp <= 0:
				_scene._log_combat("  → %s повержен меткой челюсти!" % _jm_target.unit_name)
				_scene._unit_events._on_unit_killed(_jm_target)
				var _jm_team = _scene.heroes_team if not _jm_target.is_enemy else _scene.enemies_team
				_scene._field._compact_team(_jm_team)
	
	# === Стойка с эффектом: проверяем stance_effect_type ===
	if _scene.active_unit.active_stance != null:
		var set = _scene.active_unit.active_stance.stance_effect_type
		if set == "thunder_wrath":
			_scene._passives._trigger_thunder_wrath(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "indigo_hunt_stance":
			_scene._passives._trigger_indigo_hunt_stance(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "filibuster_double_hit":
			_scene._passives._trigger_filibuster_double_hit(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "bombardment_stance":
			_scene._passives._trigger_bombardment_stance(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "set_true_king":
			_scene._passives._trigger_set_true_king(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "loki_ragnarok":
			_scene._passives._trigger_loki_ragnarok(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "koschei_immortal":
			# Бафф (броня + провокация) ставится при касте и держится, пока активна стойка;
			# снимается в combatant.break_stance().
			_scene.active_unit.break_stance()
		elif set == "odin_foresight":
			# Не прерываем стойку — баффы обновляются каждый ход, пока её не собьют движением/станом.
			_scene._passives._refresh_odin_foresight_aura(_scene.active_unit)
		elif set == "oni_flaming_rain":
			_scene._passives._trigger_oni_flaming_rain(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "titan_indestructible":
			_scene.active_unit.break_stance()
		elif set == "titan_born_to_battle":
			_scene._passives._trigger_titan_born_to_battle(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "immortal_my_battle_not_over":
			_scene._passives._trigger_immortal_my_battle_not_over(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "sphinx_statue_form":
			_scene._passives._trigger_sphinx_statue_form(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "scarab_bury_in_sand":
			_scene._passives._trigger_scarab_bury_in_sand(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "ra_sun_glory":
			_scene._passives._trigger_ra_sun_glory(_scene.active_unit)
			_scene.active_unit.break_stance()
		elif set == "nightmare_unforgettable":
			# Кошмар: в начале след хода получает щит от смерти (эффект на 1 ход)
			_scene.active_unit.active_effects.append({"stat": "invulnerable", "value": 0, "duration": 1, "effect_id": "nightmare_death_shield", "source_ability": "Незабываемый"})
			_scene._log_combat("😈 [Кошмар] %s: щит от смерти активирован на 1 ход." % _scene.active_unit.unit_name)
			_scene.active_unit.break_stance()
		elif set == "lava_boar_heart":
			# Восстановление 10% HP + увеличение отскока пассивки на 5%
			var _lb_heal = int(_scene.active_unit.max_hp * 0.10)
			if _lb_heal > 0:
				var _lb_hp_before = _scene.active_unit.current_hp
				_scene.active_unit.apply_stat_change("hp", _lb_heal)
				_scene._log_combat("🔥 [Горячее сердце] %s восстанавливает %d HP (%d → %d)." % [_scene.active_unit.unit_name, _lb_heal, _lb_hp_before, _scene.active_unit.current_hp])
			var _warm_stacks = 0
			for e in _scene.active_unit.active_effects:
				if Combatant._effect_get(e, "effect_id", "") == "lava_boar_warm_heart_stack":
					_warm_stacks += 1
			_scene.active_unit.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "lava_boar_warm_heart_stack"})
			_scene._log_combat("🔥 [Горячее сердце] %s: отражение урона усилено (%d%%)." % [_scene.active_unit.unit_name, 10 + _warm_stacks * 5 + 5])
			_scene.active_unit.break_stance()
		elif set == "kirin_lightning_dodge":
			# +1 инициатива навсегда
			_scene.active_unit.apply_stat_change("initiative", 1)
			_scene.active_unit.active_effects.append({"stat": "initiative", "value": 1, "duration": -1, "effect_id": "kirin_lightning_init", "source_ability": "kirin_lightning_fast"})
			_scene._log_combat("⚡ [Быстрый как молния] %s: +1 инициативы (итого %d)." % [_scene.active_unit.unit_name, _scene.active_unit.initiative])
			_scene.active_unit.break_stance()
		elif set == "novice_training":
			_scene.active_unit.break_stance()
		elif set == "hoplite_shield_wall":
			_scene.active_unit.break_stance()
		elif set == "centaur_suppressive_fire":
			_scene.active_unit.break_stance()
		elif set == "sea_power_stance":
			var _sp_team = _scene.enemies_team if _scene.active_unit.is_enemy else _scene.heroes_team
			for _sp_ally in _sp_team:
				if _sp_ally and _sp_ally.current_hp > 0:
					_sp_ally.apply_stat_change("damage", 20)
					_sp_ally.active_effects.append({"stat": "damage", "value": 20, "duration": 1, "effect_id": "sea_power_buff", "source_ability": "Сила моря"})
			_scene._log_combat("🌊 [Сила моря] Все союзники %s: +20 урона на 1 ход." % _scene.active_unit.unit_name)
			_scene.active_unit.break_stance()
		elif set == "warrior_of_day_stance":
			_scene.active_unit.apply_stat_change("max_hp", 10)
			_scene.active_unit.current_hp += 10
			_scene.active_unit.apply_stat_change("armor", 10)
			_scene.active_unit.active_effects.append({"stat": "armor", "value": 10, "duration": 3, "effect_id": "warrior_of_day_armor", "source_ability": "Воин дня"})
			_scene.active_unit.apply_stat_change("evasion", 10)
			_scene.active_unit.active_effects.append({"stat": "evasion", "value": 10, "duration": 3, "effect_id": "warrior_of_day_evasion", "source_ability": "Воин дня"})
			_scene._log_combat("☀ [Воин дня] %s: +10 макс. HP, +10 брони и +10 уклонения на 3 хода." % _scene.active_unit.unit_name)
			_scene.active_unit.break_stance()
		elif set == "warrior_of_night_stance":
			_scene.active_unit.apply_stat_change("damage", 10)
			_scene.active_unit.active_effects.append({"stat": "damage", "value": 10, "duration": 3, "effect_id": "warrior_of_night_damage", "source_ability": "Воин ночи"})
			_scene.active_unit.apply_stat_change("accuracy", 10)
			_scene.active_unit.active_effects.append({"stat": "accuracy", "value": 10, "duration": 3, "effect_id": "warrior_of_night_accuracy", "source_ability": "Воин ночи"})
			_scene.active_unit.apply_stat_change("crit", 10)
			_scene.active_unit.active_effects.append({"stat": "crit", "value": 10, "duration": 3, "effect_id": "warrior_of_night_crit", "source_ability": "Воин ночи"})
			_scene._log_combat("🌙 [Воин ночи] %s: +10 урона, +10 точности и +10 удачи на 3 хода." % _scene.active_unit.unit_name)
			_scene.active_unit.break_stance()
		elif set == "pegasus_arrow_rain":
			var _ar_foe_team = _scene.heroes_team if _scene.active_unit.is_enemy else _scene.enemies_team
			for _ar_foe in _ar_foe_team:
				if _ar_foe and _ar_foe.current_hp > 0:
					var _ar_dmg = int(_scene.active_unit.damage * 0.8)
					var _ar_hp_b = _ar_foe.current_hp
					_ar_foe.take_damage(_ar_dmg)
					_scene._log_combat("🏹 [Дождь стрел] %s наносит %d урона %s. HP: %d → %d" % [_scene.active_unit.unit_name, _ar_dmg, _ar_foe.unit_name, _ar_hp_b, _ar_foe.current_hp])
			_scene.active_unit.break_stance()
		# ═══ Замок — Шут: «Смертельный удар» — атака случайного врага на 60% HP ═══
		elif set == "jester_deadly_strike":
			var _ds_foe_team = _scene.heroes_team if _scene.active_unit.is_enemy else _scene.enemies_team
			var _ds_targets: Array = []
			for _ds_foe in _ds_foe_team:
				if _ds_foe and _ds_foe.current_hp > 0:
					_ds_targets.append(_ds_foe)
			if not _ds_targets.is_empty():
				var _ds_target = _ds_targets.pick_random()
				var _ds_dmg = int(_ds_target.current_hp * 0.6)
				var _ds_hp_b = _ds_target.current_hp
				_ds_target.take_damage(_ds_dmg)
				_scene._log_combat("🃏 [Смертельный удар] %s наносит %d урона %s (60%% текущего HP). HP: %d → %d" % [_scene.active_unit.unit_name, _ds_dmg, _ds_target.unit_name, _ds_hp_b, _ds_target.current_hp])
				if _ds_target.current_hp <= 0:
					_scene._log_combat("  → %s повержен смертельным ударом!" % _ds_target.unit_name)
					_ds_target.killed_by = _scene.active_unit
					_scene._unit_events._on_unit_killed(_ds_target)
					var _ds_team = _scene.heroes_team if not _ds_target.is_enemy else _scene.enemies_team
					_scene._field._compact_team(_ds_team)
			_scene.active_unit.break_stance()
		# ═══ Замок — Волшебник: «Армагеддон» — 0.8 урона всем остальным юнитам ═══
		elif set == "wizard_armageddon":
			for _ag_unit in _scene.heroes_team + _scene.enemies_team:
				if _ag_unit and _ag_unit.current_hp > 0 and _ag_unit != _scene.active_unit:
					var _ag_dmg = int(_scene.active_unit.damage * 0.8)
					var _ag_hp_b = _ag_unit.current_hp
					_ag_unit.take_damage(_ag_dmg)
					_scene._log_combat("☄️ [Армагеддон] %s наносит %d урона %s. HP: %d → %d" % [_scene.active_unit.unit_name, _ag_dmg, _ag_unit.unit_name, _ag_hp_b, _ag_unit.current_hp])
					if _ag_unit.current_hp <= 0:
						_scene._log_combat("  → %s повержён Армагеддоном!" % _ag_unit.unit_name)
						_ag_unit.killed_by = _scene.active_unit
						_scene._unit_events._on_unit_killed(_ag_unit)
						var _ag_team = _scene.heroes_team if not _ag_unit.is_enemy else _scene.enemies_team
						_scene._field._compact_team(_ag_team)
			_scene.active_unit.break_stance()
		# ═══ Замок — простые UntilNextTurn стойки: просто сброс ═══
		elif set == "princess_in_trouble":
			_scene.active_unit.break_stance()
		elif set == "knight_magic_supremacy":
			_scene.active_unit.break_stance()
		elif set == "guardsman_halt":
			_scene.active_unit.break_stance()
		# ═══ Туннели — Дварф-кузнец: «Ковать железо» — жетон ковки ═══
		elif set == "smith_forge":
			var _forge_tokens = _scene.active_unit.get_meta("smith_forge_tokens", 0) + 1
			_scene.active_unit.set_meta("smith_forge_tokens", _forge_tokens)
			_scene._log_combat("🔨 [Ковать железо] %s: получен жетон ковки (всего: %d)." % [_scene.active_unit.unit_name, _forge_tokens])
			_scene.active_unit.break_stance()
		# ═══ Туннели — Великан воин: «Обрушить потолок» — 0.7 урона всем врагам + -10 брони ═══
		elif set == "giant_ceiling":
			var _gc_foe_team = _scene.heroes_team if _scene.active_unit.is_enemy else _scene.enemies_team
			for _gc_foe in _gc_foe_team:
				if _gc_foe and _gc_foe.current_hp > 0:
					var _gc_dmg = int(_scene.active_unit.damage * 0.7)
					var _gc_hp_b = _gc_foe.current_hp
					_gc_foe.take_damage(_gc_dmg)
					_scene._log_combat("⛰️ [Обрушить потолок] %s наносит %d урона %s. HP: %d → %d" % [_scene.active_unit.unit_name, _gc_dmg, _gc_foe.unit_name, _gc_hp_b, _gc_foe.current_hp])
					_gc_foe.apply_stat_change("armor", -10)
					_gc_foe.active_effects.append({"stat": "armor", "value": -10, "duration": -1, "effect_id": "giant_ceiling_armor", "source_ability": "Обрушить потолок"})
					if _gc_foe.current_hp <= 0:
						_scene._log_combat("  → %s повержен обрушенным потолком!" % _gc_foe.unit_name)
						_gc_foe.killed_by = _scene.active_unit
						_scene._unit_events._on_unit_killed(_gc_foe)
						var _gc_team = _scene.heroes_team if not _gc_foe.is_enemy else _scene.enemies_team
						_scene._field._compact_team(_gc_team)
			_scene.active_unit.break_stance()
		
		# === Кентавр: «Подавляющий обстрел» — враг получивший ход, получает урон ===
	_scene._passives._trigger_centaur_suppressive_fire(_scene.active_unit)
	if _scene.active_unit.current_hp <= 0:
		_next_turn.call_deferred()
		return

	# === Оборотень: «Засада» — следующий враг, совершивший действие, получает урон ===
	_scene._passives._trigger_oboroten_ambush(_scene.active_unit)
	if _scene.active_unit.current_hp <= 0:
		_next_turn.call_deferred()
		return
	
	# === Марки: срабатывание "once" в начале хода владельца ===
	_scene.marks.trigger_once_for_caster(_scene.active_unit)
	
	# === Марки: срабатывание "persistent" в начале хода юнита стоящего на марке ===
	_scene.marks.trigger_persistent_for_unit(_scene.active_unit)
	
	# === Neverending Storm: удар 60% за каждую метку в начале хода ===
	_scene._passives._trigger_storm_marks(_scene.active_unit)
	
	# === Посейдон: лечение за каждый уникальный бафф в начале хода ===
	if _scene.active_unit.special_effect_type == "poseidon_buff_heal":
		_scene._passives._trigger_poseidon_heal(_scene.active_unit)

	# ═══ Перо феникса: -5% максимального здоровья в начале хода носителя ═══
	if _scene.active_unit.has_item_effect("phoenix_feather") and _scene.active_unit.current_hp > 0:
		var _pf_dmg = int(_scene.active_unit.max_hp * 0.05)
		if _pf_dmg > 0:
			var _pf_hp_b = _scene.active_unit.current_hp
			_scene.active_unit.take_damage(_pf_dmg)
			_scene._log_combat("🔥 [Перо феникса] %s теряет %d HP в начале хода (%d → %d)." % [_scene.active_unit.unit_name, _pf_dmg, _pf_hp_b, _scene.active_unit.current_hp])

	# Марки могли убить владельца хода (например, персистентная марка на его позиции)
	# ещё до того, как ему дали действовать — без этой проверки waiting_for_player
	# взводился бы для уже мёртвого юнита, и все следующие ходы молча блокировались бы.
	if _scene.active_unit.current_hp <= 0:
		_next_turn.call_deferred()
		return

	# Подсветка HP-бара юнита, чей сейчас ход.
	_scene._field._update_active_highlight()

	if _scene.active_unit.is_stunned:
		_scene._log_combat("%s оглушён и пропускает ход." % _scene.active_unit.unit_name)
		_finish_unit_turn.call_deferred(_scene.active_unit)
		return

	# Снимок эффектов на начало хода: эффекты, наложенные на себя в этом ходе,
	# не должны терять длительность за ход наложения (правило «ход наложения не считается»).
	_scene.active_unit.snapshot_turn_start_effects()

	if _scene._is_player_hero(_scene.active_unit):
		_scene._last_turn_was_hero = true
		_scene.waiting_for_player = true
		_scene._hud._show_player_interface(_scene.active_unit)
	else:
		# Небольшая пауза именно на переходе "бог → враг" (не враг → враг), чтобы
		# действие противника не читалось как мгновенное продолжение хода бога.
		if _scene._last_turn_was_hero:
			_scene._last_turn_was_hero = false
			await _scene.get_tree().create_timer(BattleScene.HERO_TO_ENEMY_TURN_DELAY_SEC).timeout
			if not _scene.battle_running:
				return
		_scene._log_combat("Ход врага: %s" % _scene.active_unit.unit_name)
		_run_enemy_turn(_scene.active_unit)

func _run_enemy_turn(monster: Combatant) -> void:
	if not _scene.battle_running or monster == null:
		return
	if monster.current_hp <= 0:
		_next_turn.call_deferred()
		return
	var decision = _scene._ai._get_ai_decision(monster)
	if decision.has("ability") and decision.ability and decision.has("target") and decision.target:
		var _used_ability: AbilityResource = decision.ability
		if _used_ability.majesty_cost > 0:
			monster.modify_majesty(-_scene._targeting._effective_majesty_cost(monster, _used_ability))
		_scene._abilities._use_ability(monster, decision.target, _used_ability)
	else:
		_scene._log_combat("%s не нашёл подходящего действия и пропускает ход." % monster.unit_name)
	var _serial_at_start: int = _scene._turn_serial
	await _scene.get_tree().create_timer(BattleScene.ENEMY_TURN_DELAY_SEC).timeout
	if not _scene.battle_running or _serial_at_start != _scene._turn_serial:
		return
	_finish_unit_turn(monster)

func _on_wait_button_pressed():
	if _scene._is_battle_paused():
		return
	if _scene.active_unit == null or _scene.active_unit.has_acted_this_round:
		return
	if not _scene.waiting_for_player or not _scene._is_player_hero(_scene.active_unit):
		return
	_scene._info._clear_pinned_unit_info()
	_scene._hud._hide_ability_controls()
	_defer_active_unit_turn()
	_scene.waiting_for_player = false
	_scene.waiting_for_target = false
	_scene.selected_ability = null
	_next_turn.call_deferred()

func _on_skip_turn_pressed():
	if _scene._is_battle_paused():
		return
	if _scene.active_unit == null:
		return
	if not _scene.waiting_for_player or not _scene._is_player_hero(_scene.active_unit):
		return
	_scene._hud._hide_ability_controls()
	_scene._log_combat("%s пропускает ход." % _scene.active_unit.unit_name)
	_finish_unit_turn(_scene.active_unit)

func _defer_active_unit_turn():
	var unit = _scene.active_unit
	# Ход отложен, а не завершён: его место занимает копия в очереди ниже, поэтому turn_open
	# снимаем (иначе пересборка очереди «съела» бы один ход). Из очереди самого юнита здесь
	# ничего не удаляем: у юнита с несколькими ходами там лежат его СЛЕДУЮЩИЕ ходы.
	unit.turn_open = false
	unit.wait_action()
	unit.round_wait_stamp = _scene.wait_counter
	_scene.wait_counter += 1
	
	# Кто ждал позже (больший номер) — ходит раньше среди «ждущих»
	var insert_at = _scene.turn_order.size()
	for i in range(_scene.turn_order.size()):
		var queued = _scene.turn_order[i]
		if queued.round_wait_stamp >= 0 and queued.round_wait_stamp < unit.round_wait_stamp:
			insert_at = i
			break
	_scene.turn_order.insert(insert_at, unit)
	
	_scene._log_combat("%s ждёт — ход перенесён в конец очереди (позиция %d из %d)." % [
		unit.unit_name, insert_at + 1, _scene.turn_order.size()
	])

func _finish_unit_turn(unit: Combatant):
	_scene._info._clear_pinned_unit_info()
	if unit == null:
		_scene.waiting_for_player = false
		_next_turn.call_deferred()
		return
	# Идемпотентность: если для этого юнита ход уже завершался в этом раунде (гонка
	# между ожидающей AI-корутиной и случайным повторным кликом — см. баг-репорт про
	# "боги ходят сами"), повторный вызов не должен снова тикать эффекты/двигать очередь.
	if unit.has_acted_this_round or not unit.turn_open:
		return
	unit.tick_effects()
	if unit.current_hp <= 0:
		_scene._log_combat("☠ %s погибает от периодического урона в конце хода." % unit.unit_name)
		_scene._unit_events._on_unit_killed(unit)
		_scene._field._compact_team(_scene.heroes_team if not unit.is_enemy else _scene.enemies_team)
	# ═══ Трезубец Посейдона: в конце хода +7 к случайной характеристике на 1 ход ═══
	if unit.current_hp > 0 and unit.has_item_effect("poseidon_trident_end_turn_buff"):
		var _pt_stats = ["damage", "armor", "accuracy", "evasion", "initiative"]
		var _pt_stat = _pt_stats.pick_random()
		unit.apply_stat_change(_pt_stat, 7)
		unit.active_effects.append({"stat": _pt_stat, "value": 7, "duration": 1, "effect_id": "poseidon_trident_buff", "source_ability": "Трезубец Посейдона"})
		_scene._log_combat("🔱 [Трезубец Посейдона] %s получает +7 к «%s» на 1 ход." % [unit.unit_name, _pt_stat])
	# ═══ Туннели — Голем: в конце хода +5 урона, +3 брони (навсегда) ═══
	if unit.current_hp > 0 and unit.special_effect_type == "golem_end_turn_growth":
		var _g_mult = 2 if unit.has_meta("golem_double_passive") else 1
		unit.apply_stat_change("damage", 5 * _g_mult)
		unit.apply_stat_change("armor", 3 * _g_mult)
		if unit.has_meta("golem_double_passive"):
			unit.remove_meta("golem_double_passive")
			_scene._log_combat("🪨 [Рост x2] %s: +%d урона, +%d брони («Вперёд» удвоил пассивку)." % [unit.unit_name, 5 * _g_mult, 3 * _g_mult])
		else:
			_scene._log_combat("🪨 [Рост] %s: +5 урона, +3 брони (навсегда)." % unit.unit_name)
	# Дану: в конце своего хода получает +урон на 1 ход = половина всего HP, восстановленного кому-либо за её ход
	if unit.current_hp > 0 and unit.special_effect_type == "duna_heal_damage" and _scene._duna_turn_heal > 0:
		var _dh_buff = int(_scene._duna_turn_heal / 2)
		if _dh_buff > 0:
			var _dh_duration = _scene._abilities._compute_effect_duration(unit, unit, 3, false)
			unit.apply_stat_change("damage", _dh_buff)
			unit.active_effects.append({"stat": "damage", "value": _dh_buff, "duration": _dh_duration, "effect_id": "duna_heal_damage", "source_ability": "Пассивка Дану"})
			_scene._log_combat("🌿 [Дану] %s восстановила %d HP за ход → +%d урона на %d хода." % [unit.unit_name, _scene._duna_turn_heal, _dh_buff, _dh_duration])
		_scene._duna_turn_heal = 0
	_scene._field._update_all_visuals()
	# Ход завершён; has_acted_this_round ставится только после последнего хода раунда
	# (у обычного юнита с одним ходом — сразу, как и раньше).
	unit.actions_taken_this_round += 1
	unit.turn_open = false
	if unit.actions_taken_this_round >= unit.actions_per_round:
		unit.has_acted_this_round = true
	_scene.waiting_for_player = false
	_scene.waiting_for_target = false
	_scene._waiting_for_spell_target = false
	_scene._selected_spell = null
	_scene._targeting._update_target_highlights()
	_scene._info._clear_ability_target_preview()
	if _scene._spell_panel:
		_scene._spell_panel.hide()
	if _scene._outcome._check_battle_end():
		return
	_next_turn.call_deferred()
