extends RefCounted
class_name BattleUnitEvents

## Реакции на события юнитов: урон, лечение, смерть/убийство, щиты воскрешения, сбитая стойка.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Наносит урон цели и помечает его критическим (для всплывающих чисел), если is_crit.
func _deal_damage(target: Combatant, amount: int, is_crit: bool = false) -> void:
	if is_crit:
		target.pending_crit = true
	target.take_damage(amount)
	# Шива «Карма»: отражение и копирование дебаффов обрабатываются в блоке реакций _use_ability

## Красная вспышка на спрайте юнита, получившего урон.
func _on_unit_damaged(_amount: int, unit: Combatant):
	if unit == null:
		return
	var vis = _scene._field._find_visual_for_unit(unit, _scene.hero_visuals)
	if vis == null:
		vis = _scene._field._find_visual_for_unit(unit, _scene.enemy_visuals)
	if vis != null:
		vis.flash_damage()
	_track_mission_damage_stats(unit, _amount)

## Статистика урона за миссию (см. MissionState.hero_battle_stats), для итогового
## экрана после её завершения. «Получено» — считаем прямо на пострадавшем боге.
## «Нанесено» — приписываем текущему активному юниту хода, если это бог, а урон
## получил враг (эвристика: не проходит per-source атрибуцию через все точки
## take_damage(), но верно покрывает подавляющее большинство реального урона —
## прямые попадания способностей/ульт/заклинаний — и не путает урон себе/от эффектов).
func _track_mission_damage_stats(unit: Combatant, amount: int) -> void:
	if not CombatManager.is_mission_battle or unit == null or amount <= 0:
		return
	if not unit.is_enemy and unit.source_resource_path != "":
		MissionState.add_hero_damage_taken(unit.source_resource_path, amount)
	elif unit.is_enemy and _scene.active_unit != null and not _scene.active_unit.is_enemy and _scene.active_unit.source_resource_path != "":
		MissionState.add_hero_damage_dealt(_scene.active_unit.source_resource_path, amount)

## Учёт исцеления за миссию (см. MissionState.hero_battle_stats) — только для героев,
## считаем прямо на исцелённом боге (кто вылечил — не различаем, как и с уроном выше).
func _on_unit_healed(amount: int, unit: Combatant) -> void:
	if not CombatManager.is_mission_battle or unit == null or amount <= 0:
		return
	if not unit.is_enemy and unit.source_resource_path != "":
		MissionState.add_hero_damage_healed(unit.source_resource_path, amount)

## Подстраховка на случай, если какой-то конкретный источник урона забудет вручную
## вызвать _on_unit_killed()/_compact_team()/_check_battle_end() (см. Combatant.died,
## эмитится один раз при первом падении HP до 0). Намеренно НЕ вызывает
## _compact_team()/_check_battle_end() отсюда — died эмитится синхронно изнутри
## take_damage(), а вызывающий код по всему файлу часто ещё держит в работе
## индексы/итераторы по heroes_team/enemies_team, которые компоновка команды
## могла бы сломать. _on_unit_killed() же безопасен: он не меняет сами массивы
## команд, только очередь ходов, визуал и «кладбище» — и теперь идемпотентен.
func _on_unit_died(unit: Combatant) -> void:
	_on_unit_killed(unit)

func _on_phoenix_shield_triggered(unit: Combatant) -> void:
	_scene._log_combat("🔥 [Перо феникса] %s: гибель предотвращена, здоровье полностью восстановлено!" % unit.unit_name)
	_scene._field._update_all_visuals()

func _on_koschei_life_shield_triggered(unit: Combatant) -> void:
	_scene._log_combat("💀 [Кощей] %s теряет 1 заряд жизни (осталось: %d). HP восстановлено до %d." % [unit.unit_name, unit.life_charges, unit.current_hp])
	_scene._field._update_all_visuals()

func _on_immortal_death_shield_triggered(unit: Combatant) -> void:
	_scene._log_combat("🛡 [Щит смерти] %s: восстанавливает полное HP (%d) вместо гибели!" % [unit.unit_name, unit.current_hp])
	_scene._field._update_all_visuals()

## Стойки, чей эффект наложен не только на самого юнита, а на всю его команду —
## при прерывании/окончании стойки эффект нужно снять со всех, не только с юнита,
## у которого была стойка (combatant.gd::break_stance() снимает только свои эффекты).
func _on_unit_stance_broken(stance_effect_type: String, unit: Combatant) -> void:
	if stance_effect_type == "duna_harmony":
		var team: Array = _scene.enemies_team if unit.is_enemy else _scene.heroes_team
		for ally in team:
			if ally:
				ally._strip_effects_by_source("В гармонии с природой")
		_scene._field._update_all_visuals()

## Вызывается при смерти юнита. Обрабатывает пассивки, зависящие от убийства.
func _on_unit_killed(victim: Combatant, log_lines: Array = []):
	# Идемпотентность: обычный код и подстраховка через сигнал died могут оба
	# попытаться обработать одну и ту же смерть — разово-смертные пассивки
	# (Банши, проклятие Принцессы и т.п.) не должны сработать дважды.
	if victim.death_processed:
		return
	victim.death_processed = true
	# Замок: трекинг смертей в этом раунде (Рыцарь «Отважный удар»)
	if victim.is_enemy:
		_scene._enemies_died_this_round = true
	else:
		_scene._heroes_died_this_round = true

	# Замок: отметить убийцу (Стражник, Принцесса)
	if victim.killed_by != null and victim.killed_by.current_hp > 0:
		if victim.is_enemy:
			victim.killed_by.has_killed_hero = true
		else:
			victim.killed_by.has_killed_enemy = true

	# ═══ Замок — Принцесса: предсмертное проклятие убийцы ═══
	if victim.special_effect_type == "princess_death_curse" and victim.killed_by != null and victim.killed_by.current_hp > 0:
		var _killer = victim.killed_by
		var _armor_loss = maxi(1, int(_killer.armor * 0.15))
		_killer.apply_stat_change("armor", -_armor_loss)
		_killer.active_effects.append({"stat": "armor", "value": -_armor_loss, "duration": -1, "effect_id": "princess_death_curse", "source_ability": "Предсмертное проклятие"})
		# Метка провокации до конца боя
		var _has_mark = false
		for _pe in _killer.active_effects:
			if Combatant._effect_get(_pe, "effect_id", "") == "princess_provocation":
				_has_mark = true
				break
		if not _has_mark:
			_killer.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": -1, "effect_id": "princess_provocation", "source_ability": "Предсмертное проклятие", "dispellable": false})
		var _pmsg = "  → [Принцесса] Предсмертное проклятие! %s теряет %d брони навсегда и получает метку провокации." % [_killer.unit_name, _armor_loss]
		if log_lines.size() > 0:
			log_lines.append(_pmsg)
		else:
			_scene._log_combat(_pmsg)

	# Очистка локации Топь
	if victim == _scene._swamp_tracked_unit:
		_scene._swamp_tracked_unit = null
	if victim == _scene._swamp_grace_unit:
		_scene._swamp_grace_unit = null
		_scene._swamp_grace_turns_left = 0
	
	# Записываем погибшего в «кладбище» его команды (для воскрешения Жрецом Анубиса)
	if victim.is_enemy:
		if not _scene._enemy_graveyard.has(victim):
			_scene._enemy_graveyard.append(victim)
	else:
		if not _scene._hero_graveyard.has(victim):
			_scene._hero_graveyard.append(victim)

	# Банши: при смерти все герои получают +20 к урону на 1 ход
	if victim.is_enemy and victim.special_effect_type == "banshee_death_debuff":
		for hero in _scene.heroes_team:
			if hero and hero.current_hp > 0:
				hero.apply_stat_change("damage", 20)
				hero.active_effects.append({
					"stat": "damage", "value": 20, "duration": 1,
					"effect_id": "banshee_death", "source_ability": "Банши"
				})
		var banshee_msg = "  → [Банши] Предсмертный визг! Все герои получают +20 к урону на 1 ход."
		if log_lines.size() > 0:
			log_lines.append(banshee_msg)
		else:
			_scene._log_combat(banshee_msg)
	
	var opposing_team = _scene.heroes_team if victim.is_enemy else _scene.enemies_team
	for ally in opposing_team:
		if ally and ally.current_hp > 0 and ally.special_effect_type == "set_kill_majesty":
			ally.modify_majesty(20)
			var msg = "  → [Сет] %s получает 20 величия за убийство противника." % ally.unit_name
			if log_lines.size() > 0:
				log_lines.append(msg)
			else:
				_scene._log_combat(msg)
		# Аид: +6 очков фантазии за смерть противника
		if ally and ally.current_hp > 0 and ally.special_effect_type == "hades_kill_fantasy":
			# Шлем Аида: удваивает эффект пассивки, если противника убил сам Аид.
			var _hades_gain = 6
			if victim.killed_by == ally and ally.has_item_effect("hades_helm_self_kill_double"):
				_hades_gain = 12
			_scene.current_fantasy = mini(_scene.max_fantasy, _scene.current_fantasy + _hades_gain)
			var msg2 = "  → [Аид] %s восстанавливает %d фантазии за смерть врага (итого: %d)." % [ally.unit_name, _hades_gain, _scene.current_fantasy]
			if log_lines.size() > 0:
				log_lines.append(msg2)
			else:
				_scene._log_combat(msg2)
			_scene._spells._update_spell_ui()
	
	# ═══ Лернейский лев: при смерти союзника — полностью восстановить HP ═══
	var victim_team = _scene.enemies_team if victim.is_enemy else _scene.heroes_team
	for ally in victim_team:
		if ally and ally.current_hp > 0 and ally != victim and ally.special_effect_type == "lion_ally_death_heal":
			var _hp_before_lion = ally.current_hp
			ally.apply_stat_change("hp", ally.max_hp)
			var _msg_lion = "  → [Лев] Союзник пал! %s полностью восстанавливает HP (%d → %d)." % [ally.unit_name, _hp_before_lion, ally.current_hp]
			if log_lines.size() > 0:
				log_lines.append(_msg_lion)
			else:
				_scene._log_combat(_msg_lion)

	# ═══ Золотой скоробей: при смерти исцелить остальных союзников на 15% HP ═══
	if victim.special_effect_type == "scarab_death_heal_allies":
		for ally in victim_team:
			if ally and ally.current_hp > 0 and ally != victim:
				var _heal = int(ally.max_hp * 0.15)
				if _heal > 0:
					var _hp_b = ally.current_hp
					ally.apply_stat_change("hp", _heal)
					var _msg = "  → [Скоробей] %s: последняя удача! %s исцеляется на %d HP (%d → %d)." % [victim.unit_name, ally.unit_name, _heal, _hp_b, ally.current_hp]
					if log_lines.size() > 0:
						log_lines.append(_msg)
					else:
						_scene._log_combat(_msg)

	# ═══ Краб-коллектор: при смерти копирует свои баффы всем союзникам ═══
	if victim.special_effect_type == "crab_collector_death_copy":
		var _victim_buffs: Array = []
		for e in victim.active_effects:
			var _bstat = Combatant._effect_get(e, "stat", "")
			var _bval = Combatant._effect_get(e, "value", 0)
			if _bval > 0 and _bstat != "stun" and _bstat != "periodic_damage":
				_victim_buffs.append(e.duplicate())
		for ally in victim_team:
			if ally and ally.current_hp > 0 and ally != victim:
				for be in _victim_buffs:
					var _bstat2 = Combatant._effect_get(be, "stat", "")
					var _bval2 = Combatant._effect_get(be, "value", 0)
					ally.apply_stat_change(_bstat2, _bval2)
					var _copy = be.duplicate()
					_copy["source_ability"] = "crab_collector_death_copy"
					ally.active_effects.append(_copy)
				var _cmsg = "  → [Краб коллектор] %s передаёт свои баффы %s (%d эффект(ов))." % [victim.unit_name, ally.unit_name, _victim_buffs.size()]
				if log_lines.size() > 0:
					log_lines.append(_cmsg)
				else:
					_scene._log_combat(_cmsg)
		_scene._field._update_all_visuals()

	# ═══ Жрец Анубиса: при смерти воскрешает мёртвого союзника с полным HP ═══
	if victim.special_effect_type == "anubis_resurrect":
		var graveyard = _scene._enemy_graveyard if victim.is_enemy else _scene._hero_graveyard
		var revived: Combatant = null
		for dead_ally in graveyard:
			if dead_ally != victim:
				revived = dead_ally
				break
		if revived != null:
			revived.current_hp = revived.max_hp
			revived.active_effects.clear()
			revived.is_stunned = false
			revived.death_processed = false
			graveyard.erase(revived)
			# Сначала компактируем команду: мёртвая жертва покинет свой слот,
			# освободив место для воскрешённого (исключает коллизию позиций).
			_scene._field._compact_team(victim_team)
			# Помещаем воскрешённого в первый свободный слот
			if not victim_team.has(revived):
				for slot in range(victim_team.size()):
					if victim_team[slot] == null:
						revived.position_index = slot
						victim_team[slot] = revived
						break
			var _msg = "  → [Жрец Анубиса] %s приносит себя в жертву: %s воскрешён с полным HP (%d)!" % [victim.unit_name, revived.unit_name, revived.current_hp]
			if log_lines.size() > 0:
				log_lines.append(_msg)
			else:
				_scene._log_combat(_msg)
			_scene._field._ensure_visual_for_unit(revived)
			_scene._field._update_all_visuals()
	# Арт погибшего убирается со сцены, чтобы он не перекрывал живых юнитов.
	_scene._field._remove_visual_for_unit(victim)
	# Убираем погибшего из очереди ходов и обновляем полосу.
	_scene.turn_order = _scene.turn_order.filter(func(u): return u != victim)
	_scene._hud._update_turn_order_display()

## Проверяет, есть ли живой юнит с указанной пассивкой в команде
## _has_special_on_team перенесена в battle_effects.gd (см. effects._has_special_on_team()).
