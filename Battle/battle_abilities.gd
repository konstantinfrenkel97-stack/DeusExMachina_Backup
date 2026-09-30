extends RefCounted
class_name BattleAbilities

## Применение способностей (_use_ability) и его звук/вспышки/реплики, длительность эффектов.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Проигрывает одну из ability.voice_lines для бога-игрока (не для врагов). Правила:
## - ПЕРВОЕ применение конкретной способности этим богом в этом бою — всегда (100%),
##   игрок должен хотя бы раз услышать реплику новой способности;
## - ультимативная способность — всегда (100%);
## - иначе — базовый шанс из настроек (GameSettings.voice_line_base_chance(): редко 15%,
##   обычно 30%, часто 50%);
## - одна и та же фраза не повторяется чаще, чем раз в VOICE_LINE_REPEAT_COOLDOWN_ROUNDS
##   раундов — если в пуле способности есть другие варианты, выбирается один из них;
## - НИКОГДА две реплики не звучат одновременно по всей команде богов: пока предыдущая
##   ещё не доиграла (оценка по реальной длительности трека, _voice_line_busy_until_msec),
##   новая не запускается вовсе (не встаёт в очередь — просто эта конкретная попытка молчит).
## Само облачко/звук рисует CombatantVisual, подписанный на Combatant.voice_line_used.
func _maybe_play_ability_voice_line(attacker: Combatant, ability: AbilityResource) -> void:
	if attacker.is_enemy or ability.voice_lines.is_empty():
		return
	# Локи «Рагнарек»: реплика должна звучать в момент удара (_trigger_loki_ragnarok),
	# а не при входе в стойку — иначе она проигрывалась бы за ход до самой атаки.
	if ability.stance_effect_type == "loki_ragnarok":
		return
	if Time.get_ticks_msec() < _scene._voice_line_busy_until_msec:
		return

	var cast_key: String = "%d|%d" % [attacker.get_instance_id(), ability.get_instance_id()]
	var is_first_cast: bool = not _scene._voice_line_first_cast_seen.has(cast_key)
	var is_ultimate: bool = ability == attacker.ultimate_ability
	if not (is_first_cast or is_ultimate) and randf() >= GameSettings.voice_line_base_chance():
		return

	# Избегаем фразы, звучавшей от этого бога совсем недавно, если в пуле есть другая.
	var candidates: Array[VoiceLineResource] = ability.voice_lines.duplicate()
	if candidates.size() > 1:
		var fresh: Array[VoiceLineResource] = []
		for vl in candidates:
			var line_key: String = "%d|%s" % [attacker.get_instance_id(), vl.text]
			var last_round: int = int(_scene._voice_line_last_round.get(line_key, -BattleScene.VOICE_LINE_REPEAT_COOLDOWN_ROUNDS))
			if _scene.current_round - last_round >= BattleScene.VOICE_LINE_REPEAT_COOLDOWN_ROUNDS:
				fresh.append(vl)
		if not fresh.is_empty():
			candidates = fresh
	var voice_line: VoiceLineResource = candidates[randi() % candidates.size()]
	if voice_line == null or voice_line.audio == null:
		return

	_scene._voice_line_first_cast_seen[cast_key] = true
	_scene._voice_line_last_round["%d|%s" % [attacker.get_instance_id(), voice_line.text]] = _scene.current_round
	var length_sec: float = voice_line.audio.get_length()
	_scene._voice_line_busy_until_msec = Time.get_ticks_msec() + int(maxf(length_sec, 0.6) * 1000.0)
	attacker.voice_line_used.emit(voice_line.text, voice_line.audio)

func _ensure_attack_sfx_players() -> void:
	if not _scene._attack_sfx_players.is_empty():
		return
	for i in range(BattleScene.ATTACK_SFX_PLAYER_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		_scene.add_child(p)
		_scene._attack_sfx_players.append(p)

func _get_attack_sfx_volume_db(ability: AbilityResource) -> float:
	var scale: float = BattleScene.ATTACK_SFX_VOLUME_SCALE
	if not ability.voice_lines.is_empty():
		scale *= BattleScene.ATTACK_SFX_VOLUME_SCALE_WITH_VOICE
	return ability.attack_sfx_volume_db + linear_to_db(scale)

## Проигрывает ability.attack_sfx (звук удара) — вызывается ровно в момент, когда
## способность реально бьёт по цели, а не когда игрок нажал на неё. Небольшой пул
## AudioStreamPlayer (не один on) — чтобы быстрые серии ударов (Гнев Бога Грома,
## Нескончаемый шторм) не обрывали звук друг друга, доигрывая только последний.
## Пока звук не доиграет (с учётом attack_sfx_max_length) — бой на паузе, см.
## _adjust_attack_effect_count()/_is_battle_paused().
func _play_ability_attack_sfx(ability: AbilityResource) -> void:
	if ability == null or ability.attack_sfx == null:
		return
	_ensure_attack_sfx_players()
	var player: AudioStreamPlayer = _scene._attack_sfx_players[_scene._next_attack_sfx_player_idx]
	_scene._next_attack_sfx_player_idx = (_scene._next_attack_sfx_player_idx + 1) % _scene._attack_sfx_players.size()
	player.stream = ability.attack_sfx
	player.volume_db = _get_attack_sfx_volume_db(ability)
	player.play()
	var sound_length: float = ability.attack_sfx.get_length()
	var truncated: bool = ability.attack_sfx_max_length > 0.0
	if truncated:
		sound_length = minf(sound_length, ability.attack_sfx_max_length)
	_scene._adjust_attack_effect_count(1)
	# RealTimeWait, не create_timer(ignore_time_scale=true) — этот параметр движка
	# ломается ровно при time_scale=0.0 (проверено: запрошенные 300ms срабатывали
	# за ~8ms), а именно это значение держит пауза, которую сам же этот таймер и
	# обслуживает. См. Scripts/real_time_wait.gd.
	await RealTimeWait.wait(_scene, sound_length)
	if truncated and is_instance_valid(player) and player.stream == ability.attack_sfx:
		player.stop()
	_scene._adjust_attack_effect_count(-1)

## Показывает только вспышку (без звука) на визуале target — см.
## CombatantVisual.show_attack_effect_flash: каждый вызов создаёт СВОЮ независимую
## вспышку (не делят один узел), поэтому и повторные удары по одной и той же цели
## (Гнев Бога Грома, Нескончаемый шторм), и удары по разным целям одновременно
## (Молот молнии Тора по всем врагам) — у каждого своя отдельная анимация. Пока
## вспышка не доиграет — бой на паузе (см. _adjust_attack_effect_count() выше).
func _show_ability_attack_flash(ability: AbilityResource, target: Combatant) -> void:
	if ability == null or ability.attack_effect_texture == null or target == null:
		return
	var visual = _scene._field._find_visual_for_unit(target, _scene.hero_visuals)
	if visual == null:
		visual = _scene._field._find_visual_for_unit(target, _scene.enemy_visuals)
	if visual == null or not visual.has_method("show_attack_effect_flash"):
		return
	visual.show_attack_effect_flash(ability.attack_effect_texture, ability.attack_effect_scale)
	_scene._adjust_attack_effect_count(1)
	await RealTimeWait.wait(_scene, BattleScene.ATTACK_FLASH_TOTAL_DURATION)
	_scene._adjust_attack_effect_count(-1)

## Проигрывает звук И вспышку способности в момент, когда она реально бьёт по
## target — удобный вызов для обычного одиночного удара. Для случаев вроде Молота
## молнии Тора (один звук на всю серию, но вспышка на каждом враге) звук и вспышки
## запускаются отдельно через _play_ability_attack_sfx()/_show_ability_attack_flash().
func _play_ability_attack_effects(ability: AbilityResource, target: Combatant) -> void:
	if ability == null:
		return
	_play_ability_attack_sfx(ability)
	_show_ability_attack_flash(ability, target)

func _use_ability(attacker: Combatant, defender: Combatant, ability: AbilityResource):
	attacker.refresh_passive_auras()
	if defender != null:
		defender.refresh_passive_auras()
	_scene._hud._show_ability_banner(ability.get_display_name())
	_maybe_play_ability_voice_line(attacker, ability)
	var log_lines: Array[String] = []
	log_lines.append("%s использует «%s»." % [attacker.unit_name, ability.name])
	var total_damage_dealt: int = 0
	var _kraken_ink_bonus_given: bool = false  # «Облако чернил»: +30 величия один раз за применение, не за каждую цель
	var voodoo_effect_snapshot: Array = _scene._passives._snapshot_active_effects()

	# ═══ Сердце природы: каждый раз, когда Дану применяет способность, бог с наименьшим
	# HP в её команде восстанавливает 10% от макс. здоровья ═══
	if attacker.has_item_effect("duna_heart_heal_lowest"):
		var _dh_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
		var _dh_lowest: Combatant = null
		for _dh_u in _dh_team:
			if _dh_u and _dh_u.current_hp > 0:
				if _dh_lowest == null or _dh_u.current_hp < _dh_lowest.current_hp:
					_dh_lowest = _dh_u
		if _dh_lowest != null:
			var _dh_heal = int(_dh_lowest.max_hp * 0.10)
			if _dh_heal > 0:
				var _dh_hp_before = _dh_lowest.current_hp
				_dh_lowest.apply_stat_change("hp", _dh_heal)
				log_lines.append("  → [Сердце природы] %s восстанавливает %d HP (%d → %d)." % [_dh_lowest.unit_name, _dh_heal, _dh_hp_before, _dh_lowest.current_hp])

	# ═══ Метка невинности: 50% перенаправление одиночной атаки на случайного союзника цели ═══
	if ability.target_type != "Self" and ability.target_type != "All_Enemies" and ability.target_type != "All_Allies":
		if attacker.is_enemy != defender.is_enemy and _scene.effects._has_innocence(defender):
			var innocence_team: Array = _scene.heroes_team if not defender.is_enemy else _scene.enemies_team
			var innocence_allies: Array = _scene._field._get_living_team_members(innocence_team).filter(func(unit): return unit != defender)
			if not innocence_allies.is_empty() and randf() < 0.5:
				var redirected_target: Combatant = innocence_allies.pick_random()
				log_lines.append("  → [Метка невинности] %s перенаправляет атаку на %s!" % [defender.unit_name, redirected_target.unit_name])
				defender = redirected_target

	# ═══ Сатир: 50% шанс перенаправить атаку против него на другого союзника ═══
	if ability.target_type != "Self" and ability.target_type != "All_Enemies" and ability.target_type != "All_Allies":
		if attacker.is_enemy != defender.is_enemy and defender.special_effect_type == "satyr_redirect":
			var satyr_team: Array = _scene.heroes_team if not defender.is_enemy else _scene.enemies_team
			var satyr_allies: Array = _scene._field._get_living_team_members(satyr_team).filter(func(unit): return unit != defender)
			if not satyr_allies.is_empty() and randf() < 0.5:
				var satyr_redirected: Combatant = satyr_allies.pick_random()
				log_lines.append("  → [Сатир] Атака перенаправлена с %s на %s!" % [defender.unit_name, satyr_redirected.unit_name])
				defender = satyr_redirected

	# ═══ Провокация: перенаправление одиночной атаки (только при атаке ВРАГА) ═══
	if ability.target_type != "Self" and ability.target_type != "All_Enemies" and ability.target_type != "All_Allies":
		if attacker.is_enemy != defender.is_enemy:
			var target_team = _scene.enemies_team if defender.is_enemy else _scene.heroes_team
			for ally in target_team:
				if ally and ally.current_hp > 0 and ally != defender and _scene.effects._has_provocation(ally):
					if randf() < 0.5:
						log_lines.append("  → [Провокация] %s перенаправляет атаку на себя!" % ally.unit_name)
						defender = ally
					break
	
	# 1. Self-эффекты (бафф на атакующего и т.п.)
	for effect in ability.effect_types:
		if effect == "neverending_storm_mark":
			attacker.active_effects.append({
				"stat": "neverending_storm_mark",
				"value": 1,
				"duration": -1,
				"effect_id": "neverending_storm_mark",
				"dispellable": false
			})
			log_lines.append("  → %s получает Метку Вечной Бури (стаки: %d)." % [
				attacker.unit_name,
				attacker.active_effects.filter(func(e): return Combatant._effect_get(e, "effect_id", "") == "neverending_storm_mark").size()
			])
		elif effect.begins_with("self_"):
			var note = _scene.effects._apply_effect_to_target(attacker, attacker, effect, ability)
			if note != "":
				log_lines.append("  → " + note)
			
	# 2. Определение списка целей
	var targets = []
	if ability.target_type == "Self":
		targets = [attacker]
	elif ability.target_type == "All_Enemies" or ability.target_type == "All_Allies":
		targets = _scene._targeting._get_all_targets(ability, attacker)
	else:
		targets.append(defender)
		if ability.extra_targets_count > 0:
			var team = _scene.enemies_team if defender.is_enemy else _scene.heroes_team
			for i in range(ability.extra_targets_count):
				var next_pos = defender.position_index + i + 1
				for unit in team:
					if unit and unit.position_index == next_pos and unit.current_hp > 0:
						targets.append(unit)
						break

	# ═══ Посейдон: «ШТОРМ» — реверс позиций противников, независимо от попадания/промаха ═══
	if ability.ability_marker == "poseidon_storm":
		var storm_lines = _scene._field._swap_enemy_positions(attacker)
		for sl in storm_lines:
			log_lines.append(sl)

	for target_idx in range(targets.size()):
		var target = targets[target_idx]
		if target == null or target.current_hp <= 0:
			continue

		var deals_damage = ability.damage_modifier > 0
		# Флибустьер «Я знаю что делаю» / Матрос с бомбой «Бомбардировка»: damage_modifier
		# здесь используется только отложенным триггером стойки (2/4 удара в начале след. хода) —
		# сам момент входа в стойку не должен наносить немедленный удар по цели.
		if ability.stance_effect_type == "filibuster_double_hit" or ability.stance_effect_type == "bombardment_stance":
			deals_damage = false
		# Применять ли эффекты/дебаффы по цели: на союзника (или себя) — всегда;
		# на врага — по проверке точности vs уклонения, даже если способность не наносит
		# урон напрямую (иначе дебафф накладывался бы гарантированно, минуя промах).
		# Наносящие урон способности сами проверяют попадание чуть ниже.
		var attack_landed: bool = not deals_damage
		if not deals_damage and target.is_enemy != attacker.is_enemy:
			attack_landed = CombatCalculator.check_hit(attacker.accuracy, target.evasion)
			if not attack_landed:
				log_lines.append("  → %s промахивается мимо %s." % [attacker.unit_name, target.unit_name])
		var is_crit_landed: bool = false

		if deals_damage:
			# Налётчик реагирует на саму попытку атаки, даже на промах
			var targeted_note = target.on_targeted_by_attack()
			if targeted_note != "":
				log_lines.append("  → " + targeted_note)

			
			# ═══ Реакция стоек титанов на направленную по ним атаку ═══
			if target.active_stance != null:
				var _tstance = target.active_stance.stance_effect_type
				if _tstance == "titan_indestructible":
					target.apply_stat_change("armor", 5)
					target.active_effects.append({"stat": "armor", "value": 5, "duration": 3, "effect_id": "titan_indestructible_armor", "source_ability": "Несокрушимый"})
					log_lines.append("  → [Несокрушимый] %s: +5 брони за атаку по нему (3 хода)." % target.unit_name)
				elif _tstance == "titan_born_to_battle":
					target.apply_stat_change("damage", 10)
					target.active_effects.append({"stat": "damage", "value": 10, "duration": 2, "effect_id": "titan_born_to_battle_damage", "source_ability": "Рождённый для битвы"})
					log_lines.append("  → [Рождённый для битвы] %s: +10 урона за атаку по нему (2 хода)." % target.unit_name)
				elif _tstance == "kirin_lightning_dodge":
					# +3 уклонения за каждую единицу разницы в инициативе с атакующим
					var _kdiff = absi(target.initiative - attacker.initiative)
					var _kev = 3 * _kdiff
					if _kev > 0:
						target.apply_stat_change("evasion", _kev)
						target.active_effects.append({"stat": "evasion", "value": _kev, "duration": 1, "effect_id": "kirin_lightning_dodge", "source_ability": "kirin_lightning_fast"})
						log_lines.append("  → [Быстрый как молния] %s: +%d уклонения за разницу инициатив (%d)." % [target.unit_name, _kev, _kdiff])
				elif _tstance == "hoplite_shield_wall":
					# Поднять щиты: 0.6 ответного урона атакующему
					var _hs_dmg = int(target.damage * 0.6)
					if _hs_dmg > 0 and attacker.current_hp > 0:
						var _hs_hp_before = attacker.current_hp
						attacker.take_damage(_hs_dmg)
						log_lines.append("  → [Поднять щиты] %s наносит %d ответного урона %s. HP: %d → %d" % [target.unit_name, _hs_dmg, attacker.unit_name, _hs_hp_before, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен ответным уроном!" % attacker.unit_name)
							_scene._unit_events._on_unit_killed(attacker, log_lines)
							var _hs_team = _scene.heroes_team if attacker.is_enemy == false else _scene.enemies_team
							_scene._field._compact_team(_hs_team)
							_scene._passives._apply_kappa_auras()
	
				# ═══ Сад — Единорог: пассивка — атаковавший получает -15 точности на 2 хода (даже при промахе) ═══
				if target.special_effect_type == "unicorn_counter_accuracy" and attacker.current_hp > 0:
					attacker.apply_stat_change("accuracy", -15)
					attacker.active_effects.append({"stat": "accuracy", "value": -15, "duration": 2, "effect_id": "unicorn_counter_accuracy", "source_ability": "Пассивка Единорога"})
					log_lines.append("  → [Единорог] %s теряет 15 точности за атаку по %s (2 хода)." % [attacker.unit_name, target.unit_name])
	
				# ═══ Сад — Фея шипов: «Колючий куст» — атаковавший получает 30% урона владельца марки ═══
				for _tb_e in target.active_effects:
					if Combatant._effect_get(_tb_e, "stat", "") == "thorn_bush_mark":
						var _tb_owner = _tb_e.get("owner", null)
						if _tb_owner and _tb_owner.current_hp > 0 and attacker.current_hp > 0:
							var _tb_dmg = int(_tb_owner.damage * 0.3)
							if _tb_dmg > 0:
								var _tb_hp_b = attacker.current_hp
								attacker.take_damage(_tb_dmg)
								log_lines.append("  → [Колючий куст] %s получает %d ответного урона. HP: %d → %d" % [attacker.unit_name, _tb_dmg, _tb_hp_b, attacker.current_hp])
						break
	
				# Рассчитываем урон через централизованный калькулятор
			var dmg_result: Dictionary
			# ═══ Замок — Стражник: бонус против убийц союзников ═══
			var _gkb_applied = false
			if attacker.special_effect_type == "guardsman_killer_bonus" and target.has_killed_enemy:
				attacker.accuracy_modifier += 30
				attacker.crit_modifier += 0.15
				_gkb_applied = true
			if ability.never_miss or ability.ability_marker == "centaur_precise_shot" or ability.ability_marker == "wizard_magic_arrow":
				# Точный выстрел / Волшебная стрела — никогда не промахивается
				dmg_result = CombatCalculator.calculate_forced_hit_damage(attacker, target, ability)
			elif ability.ability_marker == "chernobog_terrifying_end" and float(attacker.current_hp) / float(maxi(1, attacker.max_hp)) < 0.50:
				# Чернобог «Ужасный конец»: чистый урон (damage_type Pure) + не промахивается при HP < 50%.
				# damage_type временно переключается на Pure только для этого расчёта — при HP >= 50%
				# способность обычная физическая (см. .tres, где damage_type больше не задан статически).
				var _prev_damage_type := ability.damage_type
				ability.damage_type = "Pure"
				dmg_result = CombatCalculator.calculate_forced_hit_damage(attacker, target, ability)
				ability.damage_type = _prev_damage_type
				log_lines.append("  → [Ужасный конец] %s в отчаянии (HP<50%%) — атака не промахнётся и наносит чистый урон!" % attacker.unit_name)
			else:
				dmg_result = CombatCalculator.calculate_ability_damage(attacker, target, ability)
			if _gkb_applied:
				attacker.accuracy_modifier -= 30
				attacker.crit_modifier -= 0.15
				log_lines.append("  → [Стражник] +30 точности и +15%% удачи против убийцы союзников." % [])
			
			if not dmg_result.is_hit:
				attack_landed = false
				_scene._field._show_miss_popup(target)
				log_lines.append("  → %s промахивается по %s." % [attacker.unit_name, target.unit_name])
				# ═══ Цербер (пассивка «Большой»): промах атакой — 15 чистого урона себе ═══
				if attacker.special_effect_type == "cerberus_miss_self_damage" and attacker.current_hp > 0:
					var _cb_hp_b = attacker.current_hp
					attacker.take_damage(15)
					log_lines.append("  → [Большой] %s промахнулся и получает 15 чистого урона. HP: %d → %d" % [attacker.unit_name, _cb_hp_b, attacker.current_hp])
				# ═══ OnMiss: способность «Подлая заточка» и аналогичные ═══
				if "condition" in ability and ability.condition == "OnMiss":
					_scene.effects._apply_effect_to_target(attacker, attacker, ability.condition_effect, ability)
					log_lines.append("  → [Промах] %s: срабатывает эффект %s." % [attacker.unit_name, ability.condition_effect])
				# Сусаноо «Отражение»: контратакует и промахнувшихся по нему
				if target.active_stance != null and target.active_stance.stance_effect_type == "susanoo_reflection" and target.current_hp > 0 and attacker.current_hp > 0:
					var _refl_miss_result = CombatCalculator.calculate_fixed_damage(target, attacker, 0.4)
					if _refl_miss_result.is_hit:
						var _refl_miss_hp_b = attacker.current_hp
						_play_ability_attack_effects(target.active_stance, attacker)
						attacker.take_damage(_refl_miss_result.final_damage)
						log_lines.append("  → [Отражение] %s контратакует %s на %d урона. HP: %d → %d" % [target.unit_name, attacker.unit_name, _refl_miss_result.final_damage, _refl_miss_hp_b, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен Отражением!" % attacker.unit_name)
							_scene._unit_events._on_unit_killed(attacker, log_lines)
							_scene._field._compact_team(_scene.heroes_team if not attacker.is_enemy else _scene.enemies_team)
			else:
				attack_landed = true
				var is_crit: bool = dmg_result.is_crit
				is_crit_landed = is_crit
				var raw_damage: int = dmg_result.raw_damage
				var final_damage: int = dmg_result.final_damage
				
				# ═══ Туннели — Кобольд: +30% урона, если у цели больше HP чем у атакующего ═══
				if attacker.special_effect_type == "kobold_hp_advantage" and target.current_hp > attacker.current_hp:
					final_damage = int(final_damage * 1.3)
					log_lines.append("  → [Преимущество HP] +30%% урона (цель здоровее).")

				# ═══ Топь — Леший: наносит дополнительный урон за каждый дебафф на цели ═══
				if attacker.special_effect_type == "leshy_damage_per_debuff":
					var _lsh_debuffs = _scene._count_debuffs_on_unit(target)
					if _lsh_debuffs > 0:
						var _lsh_bonus = int(raw_damage * 0.1 * _lsh_debuffs)
						if _lsh_bonus > 0:
							final_damage += _lsh_bonus
							log_lines.append("  → [Леший] +%d урона за %d дебафф(ов) на цели." % [_lsh_bonus, _lsh_debuffs])
				
				# ═══ Туннели — Дварф-щитовик: -50% урона от атакующих на позициях 3-4 ═══
				if target.special_effect_type == "dwarf_shield_back_protect" and attacker.position_index >= 2:
					final_damage = int(final_damage * 0.5)
					log_lines.append("  → [Защитник тыла] %s получает на 50%% меньше урона с задних позиций." % target.unit_name)
				
				# Сирена: «На дно» — +0.5 множитель урона за каждый дебафф на цели
				if ability.ability_marker == "siren_to_the_bottom":
					var debuff_count = _scene._count_debuffs_on_unit(target)
					if debuff_count > 0:
						var bonus = int(attacker.damage * 0.5 * debuff_count)
						final_damage += bonus
						log_lines.append("  → [На дно] +%d бонусного урона за %d дебафф(ов)." % [bonus, debuff_count])
				
				# ════ АД: модификаторы урона пассивок Hell ════
				# Суккуб: «Ласка кнута» — +0.1 урона за каждый дебафф на цели
				if ability.ability_marker == "succubus_whip":
					var _sw_debuffs = _scene._count_debuffs_on_unit(target)
					if _sw_debuffs > 0:
						var _sw_bonus = int(raw_damage * 0.1 * _sw_debuffs)
						final_damage += _sw_bonus
						log_lines.append("  → [Ласка кнута] +%d урона за %d дебафф(ов)." % [_sw_bonus, _sw_debuffs])
				# Дьявол: «Наказание для недостойных» — +0.8 урона если у цели 0 величия
				if ability.ability_marker == "devil_punishment" and target.current_majesty <= 0:
					var _dp_bonus = int(raw_damage * 0.8)
					final_damage += _dp_bonus
					log_lines.append("  → [Наказание для недостойных] +%d урона (0 величия)." % _dp_bonus)
				# Адская гончая: пассивка — +1% урона за каждый 1% недостающего HP цели
				if attacker.special_effect_type == "hellhound_missing_hp_damage":
					var _hh_missing_pct = float(target.max_hp - target.current_hp) / float(maxi(1, target.max_hp)) * 100.0
					if _hh_missing_pct > 0:
						var _hh_bonus = int(final_damage * _hh_missing_pct / 100.0)
						if _hh_bonus > 0:
							final_damage += _hh_bonus
							log_lines.append("  → [Гончая] +%d урона за %d%% недостающего HP цели." % [_hh_bonus, int(_hh_missing_pct)])
				# Кошмар: пассивка — +1% урона за каждое величие, которого не хватает противнику до 100
				if attacker.special_effect_type == "nightmare_majesty_damage":
					var _nm_missing = maxi(0, 100 - target.current_majesty)
					if _nm_missing > 0:
						var _nm_bonus = int(final_damage * _nm_missing / 100.0)
						if _nm_bonus > 0:
							final_damage += _nm_bonus
							log_lines.append("  → [Кошмар] +%d урона за %d недостающего величия." % [_nm_bonus, _nm_missing])
				# Суккуб: пассивка — -30% урона от богов (кроме Дану/Моргана/Чернобог) к Суккубу
				if target.special_effect_type == "succubus_god_resist" and not attacker.is_enemy:
					# attacker — бог (герой). Список иммунных: Дану, Моргана, Чернобог
					var _sr_name = attacker.unit_name
					if _sr_name != "Дану" and _sr_name != "Моргана Лефей" and _sr_name != "Моргана" and _sr_name != "Чернобог":
						final_damage = int(final_damage * 0.7)
						log_lines.append("  → [Суккуб] -30%% урона от бога %s." % _sr_name)
				# Асура: пассивка — если атака не критическая, урон по Асуре -50%
				if target.special_effect_type == "asura_noncrit_reduce" and not is_crit:
					final_damage = int(final_damage * 0.5)
					log_lines.append("  → [Асура] -50%% урона (не крит).")
				# Ракшас: «Злобный удар» — если у цели <10% удачи, урон становится чистым
				if ability.ability_marker == "rakshasa_vicious_strike" and target.crit_chance < 0.10:
					final_damage = raw_damage
					log_lines.append("  → [Злобный удар] Урон чистый (удача цели %d%% < 10%%)." % int(target.crit_chance * 100))
			
			# ═══ Кирин: «Нисхождение с небес» — +10% урона за каждый бафф на цели (до развеяния) ═══
				if ability.ability_marker == "kirin_heaven_descent":
					var _hd_buffs = _scene._count_buffs_on_unit(target)
					if _hd_buffs > 0:
						var _hd_bonus = int(raw_damage * 0.10 * _hd_buffs)
						final_damage += _hd_bonus
						log_lines.append("  → [Нисхождение с небес] +%d урона за %d бафф(ов) цели." % [_hd_bonus, _hd_buffs])
				
				# ═══ Кирин: пассивка — +5% урона за каждую единицу разницы инициатив с целью ═══
				if attacker.special_effect_type == "kirin_initiative_damage":
					var _kidiff = absi(attacker.initiative - target.initiative)
					if _kidiff > 0:
						var _kibonus = int(raw_damage * 0.05 * _kidiff)
						final_damage += _kibonus
						log_lines.append("  → [Кирин] +%d урона за разницу инициатив (%d)." % [_kibonus, _kidiff])
				
				# ═══ Кощей: «Непослушание» — урон = base * (1 + своя броня%) ═══
				if ability.ability_marker == "koschei_disobedience":
					var armor_bonus = int(attacker.damage * float(attacker.armor) / 100.0)
					if armor_bonus > 0:
						final_damage += armor_bonus
						log_lines.append("  → [Непослушание] +%d урона за %d%% собственной брони Кощея." % [armor_bonus, attacker.armor])
				
				# ═══ Кощей: «Кончик иглы» — +0.6 множитель за каждый потерянный заряд жизни ═══
				if ability.ability_marker == "koschei_needle_tip":
					var missing_charges = attacker.get_max_life_charges() - attacker.life_charges
					if missing_charges > 0:
						var needle_bonus = int(attacker.damage * 0.6 * missing_charges)
						final_damage += needle_bonus
						log_lines.append("  → [Кончик иглы] +%d урона за %d потерянных зарядов." % [needle_bonus, missing_charges])
				
				# ═══ Аид: «Прах к праху» — +10% урона за каждый дебафф на цели ═══
				if ability.ability_marker == "hades_ash_to_ash":
					var debuff_cnt = _scene._count_debuffs_on_unit(target)
					if debuff_cnt > 0:
						var ash_bonus = int(raw_damage * 0.10 * debuff_cnt)
						final_damage += ash_bonus
						log_lines.append("  → [Прах к праху] +%d бонусного урона за %d дебафф(ов)." % [ash_bonus, debuff_cnt])
				
				# ═══ Аид: «В Тартар» — урон = недостающее_HP * 0.8 (заменяет обычный урон) ═══
				if ability.ability_marker == "hades_to_tartarus":
					var missing_hp = target.max_hp - target.current_hp
					final_damage = int(missing_hp * 0.8)
					log_lines.append("  → [В Тартар] Урон = %d (80%% от недостающего HP %d/%d)." % [final_damage, missing_hp, target.max_hp])
				
				# ═══ Они: «Крошить кости» — +20% крита, если активна ярость Они ═══
				if ability.ability_marker == "oni_crush_bones" and not is_crit:
					var _oni_rage_on = false
					for _eff in attacker.active_effects:
						if Combatant._effect_get(_eff, "effect_id", "") == "oni_rage_active":
							_oni_rage_on = true
							break
					if _oni_rage_on and randf() < 0.20:
						is_crit = true
						final_damage = int(final_damage * CombatManager.get_crit_multiplier())
						log_lines.append("  → [Крошить кости] Ярость Они! Критический удар (+20% шанс).")
					
				# ═══ Замок — Рыцарь: «Отважный удар» — крит, если союзник погиб в этом раунде ═══
				if ability.ability_marker == "knight_brave_strike" and not is_crit:
					var _bs_ally_died = _scene._enemies_died_this_round if attacker.is_enemy else _scene._heroes_died_this_round
					if _bs_ally_died:
						is_crit = true
						final_damage = int(final_damage * CombatManager.get_crit_multiplier())
						log_lines.append("  → [Отважный удар] Союзник пал в этом раунде — критический удар!")
				
				# ═══ Титан: «Тяжёлый удар» — +урон равен текущему проценту брони атакующего ═══
				if ability.ability_marker == "titan_heavy_hit":
					var _th_bonus = int(attacker.damage * float(attacker.armor) / 100.0)
					if _th_bonus > 0:
						final_damage += _th_bonus
						log_lines.append("  → [Тяжёлый удар] +%d урона за %d%% брони." % [_th_bonus, attacker.armor])
				
				# ═══ Бессмертный: «Клинок востока» — +20% урона, если щит смерти ещё не использован ═══
				if ability.ability_marker == "immortal_eastern_blade":
					var _imm_shield_used = false
					for _eff in attacker.active_effects:
						if Combatant._effect_get(_eff, "effect_id", "") == "immortal_shield_used":
							_imm_shield_used = true
							break
					if not _imm_shield_used:
						var _eb_bonus = int(final_damage * 0.20)
						final_damage += _eb_bonus
						log_lines.append("  → [Клинок востока] +20%% урона (щит активен): +%d." % _eb_bonus)
				
				# ═══ Мумия: «Пагубное касание» — +0.2 за каждый дебафф на цели ═══
				if ability.ability_marker == "mummy_corrupting_touch":
					var _ct_debuffs = _scene._count_debuffs_on_unit(target)
					if _ct_debuffs > 0:
						var _ct_bonus = int(attacker.damage * 0.2 * _ct_debuffs)
						final_damage += _ct_bonus
						log_lines.append("  → [Пагубное касание] +%d урона за %d дебафф(ов)." % [_ct_bonus, _ct_debuffs])
				
				# ═══ Моргана: «Чёрная молния» — чистый урон, если заклинание использовано в этом ходе ═══
				if ability.ability_marker == "morgan_black_lightning" and _scene.spells_used_this_round > 0:
					final_damage = raw_damage
					log_lines.append("  → [Чёрная молния] Заклинание использовано — чистый урон!")
				
				# ═══ Пушка: урон по цепочке целей — 150% первой цели, 120% второй, 90% третьей и далее ═══
				if attacker.special_effect_type == "cannon_position_damage":
					var _cannon_mult = maxf(0.3, 1.5 - 0.3 * target_idx)
					final_damage = int(final_damage * _cannon_mult)
					log_lines.append("  → [Пушка] Цель %d по цепочке: урон %d%% (%d)." % [target_idx + 1, int(_cannon_mult * 100), final_damage])
				
				# ═══ Шива: «Доверься судьбе» — урон режется на случайный 0-30% ═══
				if ability.ability_marker == "shiva_trust_fate":
					var _sf_fate = randi_range(0, 30)
					final_damage = int(final_damage * (1.0 - _sf_fate / 100.0))
					attacker.set_meta("shiva_trust_fate_pct", _sf_fate)
					log_lines.append("  → [Доверься судьбе] Урон уменьшен на %d%%." % _sf_fate)
			
			# ═══ Неуязвимость: если на цели эффект invulnerable, урон = 0 ═══
				var _is_invuln = false
				for _inv in target.active_effects:
					if Combatant._effect_get(_inv, "stat", "") == "invulnerable":
						_is_invuln = true
						break
				if _is_invuln:
					final_damage = 0
					log_lines.append("  → %s неуязвим! Урон поглощён." % target.unit_name)
				
				# Флаг крита для всплывающего числа (крупнее и полностью красное).
				if is_crit:
					target.pending_crit = true
				_play_ability_attack_effects(ability, target)
				target.take_damage(final_damage)
				total_damage_dealt += final_damage
				if final_damage > 0:
					var thor_heal_note = _scene._passives._trigger_thor_fight_me_heal(target)
					if thor_heal_note != "":
						log_lines.append("  → " + thor_heal_note)
				if ability.ability_marker == "kappa_spear_strike" and final_damage > 0 and target.current_hp > 0:
					var triggered_dot: int = 0
					for kappa_eff in target.active_effects:
						if Combatant._effect_get(kappa_eff, "stat", "") == "periodic_damage":
							triggered_dot += int(Combatant._effect_get(kappa_eff, "value", 0))
					if triggered_dot > 0:
						var kappa_hp_before: int = target.current_hp
						target.take_damage(triggered_dot)
						log_lines.append("  → [Удар копья] %s получает %d уже висящего периодического урона. HP: %d → %d" % [target.unit_name, triggered_dot, kappa_hp_before, target.current_hp])
						if target.current_hp <= 0:
							_scene._unit_events._on_unit_killed(target, log_lines)

				# ════ Реакции новых механик на полученный целью урон ════
				# Шива «Карма»: 50% урона обратно атакующему + копирование своих дебаффов на него
				if final_damage > 0 and target.active_stance != null and target.active_stance.stance_effect_type == "shiva_karma" and target.current_hp > 0:
					var _km_amt = int(final_damage * 0.5)
					if _km_amt > 0 and attacker.current_hp > 0:
						var _km_hp_b = attacker.current_hp
						attacker.take_damage(_km_amt)
						log_lines.append("  → [Карма] %s отражает %d урона в %s. HP: %d → %d" % [target.unit_name, _km_amt, attacker.unit_name, _km_hp_b, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен Кармой!" % attacker.unit_name)
							_scene._unit_events._on_unit_killed(attacker, log_lines)
							_scene._field._compact_team(_scene.heroes_team if not attacker.is_enemy else _scene.enemies_team)
							if _scene._outcome._check_battle_end():
								for line in log_lines:
									_scene._log_combat(line)
								return
					if attacker.current_hp > 0:
						for _km_eff in target.active_effects:
							var _km_st = Combatant._effect_get(_km_eff, "stat", "")
							var _km_vl = Combatant._effect_get(_km_eff, "value", 0)
							if _km_vl < 0 or _km_st == "periodic_damage" or _km_st == "stun":
								attacker.active_effects.append(_km_eff.duplicate())
								if _km_st == "stun":
									attacker.is_stunned = true
									attacker.check_stance_interruption("stun")
						log_lines.append("  → [Карма] %s копирует свои дебаффы на %s." % [target.unit_name, attacker.unit_name])
				# Сусаноо «Отражение»: пока стойка активна, каждый атаковавший его получает 40% урона в ответ
				if final_damage > 0 and target.active_stance != null and target.active_stance.stance_effect_type == "susanoo_reflection" and target.current_hp > 0 and attacker.current_hp > 0:
					var _refl_result = CombatCalculator.calculate_fixed_damage(target, attacker, 0.4)
					if _refl_result.is_hit:
						var _refl_hp_b = attacker.current_hp
						_play_ability_attack_effects(target.active_stance, attacker)
						attacker.take_damage(_refl_result.final_damage)
						log_lines.append("  → [Отражение] %s контратакует %s на %d урона. HP: %d → %d" % [target.unit_name, attacker.unit_name, _refl_result.final_damage, _refl_hp_b, attacker.current_hp])
						if attacker.current_hp <= 0:
							log_lines.append("  → %s повержен Отражением!" % attacker.unit_name)
							_scene._unit_events._on_unit_killed(attacker, log_lines)
							_scene._field._compact_team(_scene.heroes_team if not attacker.is_enemy else _scene.enemies_team)
							if _scene._outcome._check_battle_end():
								for line in log_lines:
									_scene._log_combat(line)
								return
				# Самди «Кукла вуду»: связанный (позади) юнит получает 50% урона и копии дебаффов меченой цели
				if final_damage > 0:
					for _vd_e in target.active_effects:
						if Combatant._effect_get(_vd_e, "effect_id", "") == "voodoo_marked":
							var _vlink = _vd_e.get("linked", null)
							if _vlink != null and _vlink.current_hp > 0 and _vlink != attacker:
								var _vd_dmg = int(final_damage * 0.5)
								if _vd_dmg > 0:
									var _vd_hp_b = _vlink.current_hp
									_vlink.take_damage(_vd_dmg)
									log_lines.append("  → [Кукла вуду] %s получает %d урона (50%% от %s). HP: %d → %d" % [_vlink.unit_name, _vd_dmg, target.unit_name, _vd_hp_b, _vlink.current_hp])
							break
				# Дану «Защита из корней»: атакующий получает % урона шипами (пока активен эффект root_thorns)
				if final_damage > 0 and attacker.current_hp > 0:
					for _rt_e in target.active_effects:
						if Combatant._effect_get(_rt_e, "effect_id", "") == "root_thorns":
							var _rt_pct = int(Combatant._effect_get(_rt_e, "value", 40))
							var _rt_dmg = int(final_damage * _rt_pct / 100.0)
							if _rt_dmg > 0:
								var _rt_hp_b = attacker.current_hp
								attacker.take_damage(_rt_dmg)
								log_lines.append("  → [Защита из корней] %s получает %d ответного урона (%d%%). HP: %d → %d" % [attacker.unit_name, _rt_dmg, _rt_pct, _rt_hp_b, attacker.current_hp])
								if attacker.current_hp <= 0:
									log_lines.append("  → %s повержен шипами корней!" % attacker.unit_name)
									_scene._unit_events._on_unit_killed(attacker, log_lines)
									_scene._field._compact_team(_scene.heroes_team if not attacker.is_enemy else _scene.enemies_team)
									if _scene._outcome._check_battle_end():
										for line in log_lines:
											_scene._log_combat(line)
										return
							break
				# Один «Стая воронов»: атаковавший меченую позицию получает +15 точности (1 ход)
				if final_damage > 0 and attacker.current_hp > 0:
					var _rv_marked = false
					for _rv_e in target.active_effects:
						if Combatant._effect_get(_rv_e, "effect_id", "") == "raven_marked":
							_rv_marked = true
							break
					if not _rv_marked and _scene.marks != null:
						# Эффекта нет (юнит сменился/истёк) — проверяем позиционную марку.
						for _rv_m in _scene.marks.position_marks:
							if str(_rv_m.get("team", "")) == "enemy" \
									and int(_rv_m.get("position", -1)) == target.position_index \
									and str(_rv_m.get("effect_type", "")) == "raven_mark_accuracy":
								_rv_marked = true
								break
					if _rv_marked:
						var _rva_duration = _compute_effect_duration(attacker, attacker, 1, false)
						attacker.apply_stat_change("accuracy", 15)
						attacker.active_effects.append({"stat": "accuracy", "value": 15, "duration": _rva_duration, "effect_id": "raven_accuracy", "source_ability": "Стая воронов"})
						log_lines.append("  → [Стая воронов] %s получает +15 точности за атаку меченой позиции (%d ход(ов))." % [attacker.unit_name, _rva_duration])
					# Тролль: применил атаку, но не нанёс урона (промах/неуязвимость) — самооглушение на 1 ход
					if final_damage <= 0 and attacker.current_hp > 0 \
							and attacker.special_effect_type == "troll_self_stun_on_no_damage" and not attacker.is_stunned:
						attacker.is_stunned = true
						var _tss_duration = _compute_effect_duration(attacker, attacker, 1, true)
						attacker.active_effects.append({"stat": "stun", "value": 1, "duration": _tss_duration, "effect_id": "troll_self_stun", "source_ability": "Пассивка тролля"})
						attacker.check_stance_interruption("stun")
						_scene._passives._notify_stun_applied(attacker)
						log_lines.append("  → [Тролль] %s не нанёс урона и оглушает себя (1 ход)." % attacker.unit_name)
					# Дану «Растительный яд»: союзник с баффом яда накладывает DoT 20% от урона ДАНУ на 4 хода при атаке
				if final_damage > 0 and target.current_hp > 0 and attacker.has_meta("plant_poison_attacker_dmg"):
					var _pp_has = false
					for _pp_e in attacker.active_effects:
						if Combatant._effect_get(_pp_e, "effect_id", "") == "plant_poison_buff":
							_pp_has = true
							break
					if _pp_has:
						var _pp_dot = int(attacker.get_meta("plant_poison_attacker_dmg") * 0.2)
						if _pp_dot > 0:
							target.active_effects.append({"stat": "periodic_damage", "value": _pp_dot, "duration": 4, "source_ability": "Растительный яд"})
							log_lines.append("  → [Растительный яд] %s получает периодический урон (%d) на 4 хода." % [target.unit_name, _pp_dot])
				# Шива «Цикл разрушения»: при действии противника — 0.7 урона, при крите — повтор удара
				if final_damage > 0 and not attacker.has_meta("_dc_guard"):
					var _dc_shiva = null
					var _dc_opp = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
					for _dc_u in _dc_opp:
						if _dc_u != null and _dc_u.current_hp > 0 and _dc_u.active_stance != null and _dc_u.active_stance.stance_effect_type == "shiva_destruction_cycle":
							_dc_shiva = _dc_u
							break
					if _dc_shiva != null:
						attacker.set_meta("_dc_guard", true)
						for _dc_n in range(2):
							if attacker.current_hp <= 0 or _scene._outcome._check_battle_end():
								break
							var _dc_r = CombatCalculator.calculate_fixed_damage(_dc_shiva, attacker, 0.7)
							if not _dc_r.is_hit:
								log_lines.append("  → [Цикл разрушения] %s промахивается по %s." % [_dc_shiva.unit_name, attacker.unit_name])
								break
							var _dc_hp_b = attacker.current_hp
							attacker.take_damage(_dc_r.final_damage)
							log_lines.append("  → [Цикл разрушения] %s наносит %d урона %s%s." % [_dc_shiva.unit_name, _dc_r.final_damage, attacker.unit_name, " (крит!)" if _dc_r.is_crit else ""])
							if attacker.current_hp <= 0:
								log_lines.append("  → %s повержен Циклом разрушения!" % attacker.unit_name)
								_scene._unit_events._on_unit_killed(attacker, log_lines)
								_scene._field._compact_team(_scene.heroes_team if not attacker.is_enemy else _scene.enemies_team)
								break
							if not _dc_r.is_crit:
								break
						attacker.remove_meta("_dc_guard")
	
				# ═══ Грифон: первый атакующий в раунде получает 100% урона (если удар не смертельный) ═══
				if final_damage > 0 and target.special_effect_type == "griffin_first_strike" and not target.griffin_first_strike_used and target.current_hp > 0 and attacker.current_hp > 0:
					target.griffin_first_strike_used = true
					var _gs_dmg = target.damage
					var _gs_hp_b = attacker.current_hp
					attacker.take_damage(_gs_dmg)
					log_lines.append("  → [Грифон] %s наносит %d ответного урона %s (первая атака). HP: %d → %d" % [target.unit_name, _gs_dmg, attacker.unit_name, _gs_hp_b, attacker.current_hp])
					if attacker.current_hp <= 0:
						log_lines.append("  → %s повержен ответным уроном Грифона!" % attacker.unit_name)
						_scene._unit_events._on_unit_killed(attacker, log_lines)
						var _gs_team = _scene.heroes_team if not attacker.is_enemy else _scene.enemies_team
						_scene._field._compact_team(_gs_team)
						if _scene._outcome._check_battle_end():
							for line in log_lines:
								_scene._log_combat(line)
							return
				# ═══ Птица: при смерти от атаки наносит 0,8 урона убийце ═══
				if final_damage > 0 and target.current_hp <= 0 and target.special_effect_type == "bird_death_damage" and attacker.current_hp > 0:
					var _bd_dmg = int(target.damage * 0.8)
					var _bd_hp_b = attacker.current_hp
					attacker.take_damage(_bd_dmg)
					log_lines.append("  → [Птица] %s наносит %d урона %s перед смертью. HP: %d → %d" % [target.unit_name, _bd_dmg, attacker.unit_name, _bd_hp_b, attacker.current_hp])
					if attacker.current_hp <= 0:
						log_lines.append("  → %s повержен ответным уроном Птицы!" % attacker.unit_name)
						_scene._unit_events._on_unit_killed(attacker, log_lines)
						var _bd_team = _scene.heroes_team if not attacker.is_enemy else _scene.enemies_team
						_scene._field._compact_team(_bd_team)
						if _scene._outcome._check_battle_end():
							for line in log_lines:
								_scene._log_combat(line)
							return
				
				# Джаггернаут и берсерк — только при реальном уроне
				if final_damage > 0:
					var hit_note = target.on_hit_by_attack()
					if hit_note != "":
						log_lines.append("  → " + hit_note)
					# ═══ Кикимора: «Неоценённая красота» — при получении урона всем противникам 0.2 урона ═══
					if target.active_stance != null and target.active_stance.stance_effect_type == "kikimora_beauty" and target.current_hp > 0:
						var _kk_dmg = int(target.damage * 0.2)
						if _kk_dmg > 0:
							var _kk_foes = _scene.heroes_team if target.is_enemy else _scene.enemies_team
							for _kk_foe in _kk_foes:
								if _kk_foe != null and _kk_foe.current_hp > 0:
									var _kk_hp_b = _kk_foe.current_hp
									_kk_foe.take_damage(_kk_dmg)
									log_lines.append("  → [Неоценённая красота] %s наносит %d урона %s. HP: %d → %d" % [target.unit_name, _kk_dmg, _kk_foe.unit_name, _kk_hp_b, _kk_foe.current_hp])
				# ═══ Звёзды — Весы: «Равновесие» — союзник получил урон → все враги получают 1/4 чистым ═══
					var _lb_team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
					for _lb_ally in _lb_team:
						if _lb_ally == null or _lb_ally.current_hp <= 0 or _lb_ally == target:
							continue
						if _lb_ally.active_stance != null and _lb_ally.active_stance.stance_effect_type == "libra_balance":
							var _lb_reflect = int(final_damage / 4.0)
							if _lb_reflect > 0:
								var _lb_foe_team = _scene.heroes_team if _lb_ally.is_enemy else _scene.enemies_team
								for _lb_foe in _lb_foe_team:
									if _lb_foe != null and _lb_foe.current_hp > 0:
										var _lfb = _lb_foe.current_hp
										_lb_foe.take_damage(_lb_reflect)
										log_lines.append("  → [Равновесие] %s отражает %d чистого урона на %s. HP: %d → %d" % [_lb_ally.unit_name, _lb_reflect, _lb_foe.unit_name, _lfb, _lb_foe.current_hp])
								break
					# ═══ Угорь: 5% шанс контр-оглушения при получении урона (x2 если двигался) ═══
					if target.special_effect_type == "eel_counter_stun" and attacker.current_hp > 0:
						var _cs_chance = 0.05 * (2.0 if target.moved_this_round else 1.0)
						if randf() < _cs_chance:
							attacker.is_stunned = true
							attacker.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Пассивка Угря"})
							attacker.check_stance_interruption("stun")
							log_lines.append("  → [Угорь] %s: %s оглушён контратакой!" % [target.unit_name, attacker.unit_name])
					# ═══ Мумия: при попадании по ней атакующий теряет -5 макс. HP до конца боя (рассеиваемо) ═══
					if target.special_effect_type == "mummy_hit_max_hp_reduce" and attacker.current_hp > 0:
						attacker.max_hp = maxi(1, attacker.max_hp - 5)
						attacker.active_effects.append({"stat": "max_hp", "value": -5, "duration": -1, "effect_id": "mummy_curse_max_hp", "source_ability": "Аура мумии"})
						if attacker.current_hp > attacker.max_hp:
							attacker.current_hp = attacker.max_hp
						log_lines.append("  → [Мумия] %s: -5 макс. HP (итого %d) до конца боя." % [attacker.unit_name, attacker.max_hp])
					# ═══ Лавовый кабан: пассивка — при попадании атакующий получает урон (% от урона кабана) ═══
					if target.special_effect_type == "lava_boar_thorns" and attacker.current_hp > 0:
						var _th_pct = _scene._passives._lava_boar_thorns_percent(target)
						var _th_dmg = int(target.damage * _th_pct / 100.0)
						if _th_dmg > 0:
							var _th_hp_before = attacker.current_hp
							attacker.take_damage(_th_dmg)
							log_lines.append("  → [Горячее сердце] %s отражает %d урона (%d%%) на %s. HP: %d → %d" % [
								target.unit_name, _th_dmg, _th_pct, attacker.unit_name, _th_hp_before, attacker.current_hp])
							if attacker.current_hp <= 0:
								log_lines.append("  → %s повержен отражённым уроном!" % attacker.unit_name)
								_scene._unit_events._on_unit_killed(attacker, log_lines)
								var _th_team = _scene.heroes_team if attacker.is_enemy == false else _scene.enemies_team
								_scene._field._compact_team(_th_team)
								_scene._passives._apply_kappa_auras()
				
				# Матрос с бомбой: при HP <20% — толкает вперёд на 2 (однократно)
				if target.special_effect_type == "sailor_bomber_low_hp" and target.current_hp > 0:
					if float(target.current_hp) / float(target.max_hp) < 0.20:
						var already_triggered = false
						for eff in target.active_effects:
							if Combatant._effect_get(eff, "effect_id", "") == "sailor_bomber_low_hp_triggered":
								already_triggered = true
								break
						if not already_triggered:
							var old_pos_bomber = target.position_index
							_scene._field._apply_shift_effect(target, -2, false)
							target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "sailor_bomber_low_hp_triggered"})
							log_lines.append("  → [Матрос с бомбой] %s: HP <20%%, толкается вперёд (линия %d → %d)!" % [target.unit_name, old_pos_bomber + 1, target.position_index + 1])
				
				# ═══ Они: «Ярость Они» — при HP <50% активируется ярость (+5 инициативы, +15 урона) ═══
				if target.special_effect_type == "oni_rage" and target.current_hp > 0:
					if float(target.current_hp) / float(target.max_hp) < 0.50:
						var _oni_rage_on = false
						for _eff in target.active_effects:
							if Combatant._effect_get(_eff, "effect_id", "") == "oni_rage_active":
								_oni_rage_on = true
								break
						if not _oni_rage_on:
							target.apply_stat_change("initiative", 5)
							target.apply_stat_change("damage", 15)
							target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "oni_rage_active"})
							log_lines.append("  → [Ярость Они] %s: HP <50%%, ярость! +5 инициативы, +15 урона до конца боя." % target.unit_name)
				
				# Пассивка атакующего — Флибустьер: +10% удачи при крите
				if is_crit and attacker.special_effect_type == "filibuster_crit_luck" and final_damage > 0:
					attacker.crit_modifier += 0.10
					log_lines.append("  → [Флибустьер] %s: +10%% к удаче за крит (итого %d%%)" % [attacker.unit_name, int(attacker.crit_chance * 100)])
				
				# Пассивка атакующего — Сусаноо: +5% удачи за каждое попадание
				if attacker.special_effect_type == "susanoo_hit_crit" and final_damage > 0:
					attacker.crit_modifier += 0.05
					log_lines.append("  → [Сусаноо] +5%% к удаче (итого: %d%%)" % int(attacker.crit_chance * 100))
					# Тоцука-но цуруги: пассивка Сусаноо даёт ещё +2% удачи за стак
					if attacker.has_item_effect("susanoo_extra_luck_stack"):
						attacker.crit_modifier += 0.02
						log_lines.append("  → [Тоцука-но цуруги] +2%% к удаче (итого: %d%%)" % int(attacker.crit_chance * 100))

				# Копьё Гора: каждое попадание по противнику даёт +5 величия
				if final_damage > 0 and attacker.has_item_effect("horus_spear_majesty_on_hit"):
					var _hs_majesty_before = attacker.current_majesty
					attacker.modify_majesty(5)
					if attacker.current_majesty != _hs_majesty_before:
						log_lines.append("  → [Копьё Гора] %s получает 5 величия (итого: %d)." % [attacker.unit_name, attacker.current_majesty])

				# Молния Зевса: критические атаки наносят периодический урон (30% урона, 3 хода)
				if is_crit and final_damage > 0 and attacker.has_item_effect("zeus_lightning_crit_dot") and target.current_hp > 0:
					var _zl_dot = int(attacker.damage * 0.3)
					if _zl_dot > 0:
						var _zl_duration = _compute_effect_duration(attacker, target, 3, true)
						target.active_effects.append({"stat": "periodic_damage", "value": _zl_dot, "duration": _zl_duration, "source_ability": "Молния Зевса"})
						log_lines.append("  → [Молния Зевса] %s получает %d периодического урона на %d хода." % [target.unit_name, _zl_dot, _zl_duration])

				# Сокрушающий землю: критические удары наносят 50% урона соседним целям
				if is_crit and final_damage > 0 and attacker.has_item_effect("earth_crusher_crit_splash") and target.current_hp > 0:
					var _ec_team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
					var _ec_splash = int(final_damage * 0.5)
					if _ec_splash > 0:
						for _ec_pos in [target.position_index - 1, target.position_index + 1]:
							for _ec_u in _ec_team:
								if _ec_u and _ec_u.current_hp > 0 and _ec_u.position_index == _ec_pos:
									var _ec_hp_before = _ec_u.current_hp
									_ec_u.take_damage(_ec_splash)
									log_lines.append("  → [Сокрушающий землю] %s получает %d урона (сплэш). HP: %d → %d" % [_ec_u.unit_name, _ec_splash, _ec_hp_before, _ec_u.current_hp])
									if _ec_u.current_hp <= 0:
										log_lines.append("  → %s повержен!" % _ec_u.unit_name)
										_ec_u.killed_by = attacker
										_scene._unit_events._on_unit_killed(_ec_u, log_lines)
										_scene._field._compact_team(_ec_team)
										_scene._passives._apply_kappa_auras()
									break

				# Колесо сансары: у кого-то из команды атакующего есть артефакт — кто кританул, лечится
				# на 5% от нанесённого критического урона.
				if is_crit and final_damage > 0:
					var _sw_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
					for _sw_u in _sw_team:
						if _sw_u and _sw_u.current_hp > 0 and _sw_u.has_item_effect("samsara_wheel_crit_heal"):
							var _sw_heal = int(final_damage * 0.05)
							if _sw_heal > 0:
								attacker.apply_stat_change("hp", _sw_heal)
								log_lines.append("  → [Колесо сансары] %s восстанавливает %d HP от критического урона." % [attacker.unit_name, _sw_heal])
							break
				
				# Пассивка атакующего — Локи: крит = стан на цели (1 ход)
				if is_crit and attacker.special_effect_type == "loki_crit_stun" and target.current_hp > 0:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1})
					target.check_stance_interruption("stun")
					_scene._passives._notify_stun_applied(target)
					log_lines.append("  → [Локи] %s оглушён критическим ударом!" % target.unit_name)
				# ════ ДЖУНГЛИ: on_crit пассивки ════
				# Нага воин: «Удар хвостом» — при крите стан
				if is_crit and ability.ability_marker == "naga_tail_strike" and target.current_hp > 0 and not target.is_stunned:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Удар хвостом"})
					target.check_stance_interruption("stun")
					_scene._passives._notify_stun_applied(target)
					log_lines.append("  → [Удар хвостом] %s оглушён критом!" % target.unit_name)
				# Сару: пассивка — при любом крите все Сару получают +7% уклонения на 1 ход
				if is_crit:
					var _sr_team = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
					for _sr_u in _sr_team:
						if _sr_u != null and _sr_u.current_hp > 0 and _sr_u.special_effect_type == "saru_crit_evasion":
							_sr_u.apply_stat_change("evasion", 7)
							_sr_u.active_effects.append({"stat": "evasion", "value": 7, "duration": 1, "effect_id": "saru_crit_ev", "source_ability": "Пассивка Сару"})
							log_lines.append("  → [Сару] %s получает +7%% уклонения за крит (1 ход)." % _sr_u.unit_name)
				# Коатль: пассивка — при крите восстанавливает 5% HP
				if is_crit and attacker.special_effect_type == "coatl_crit_heal":
					var _ct_heal = int(attacker.max_hp * 0.05)
					if _ct_heal > 0:
						attacker.apply_stat_change("hp", _ct_heal)
						log_lines.append("  → [Коатль] %s восстанавливает %d HP за крит." % [attacker.unit_name, _ct_heal])
				# Асура: пассивка — если атака НЕ крит, урон по Асуре -50% (ниже в блоке урона)

				# ═══ Лавовый кабан: «Поднять на бивни» — при крите цель оглушается ═══
				if is_crit and ability.ability_marker == "lava_boar_tusk_lift" and target.current_hp > 0 and not target.is_stunned:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "lava_boar_tusk_lift"})
					target.check_stance_interruption("stun")
					_scene._passives._notify_stun_applied(target)
					log_lines.append("  → [Поднять на бивни] %s оглушён критическим ударом!" % target.unit_name)
				
				# ═══ Замок — Принцесса: «Истерика» — при крите цель оглушается ═══
				if is_crit and ability.ability_marker == "princess_hysteria" and target.current_hp > 0 and not target.is_stunned:
					target.is_stunned = true
					target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Истерика"})
					target.check_stance_interruption("stun")
					_scene._passives._notify_stun_applied(target)
					log_lines.append("  → [Истерика] %s оглушён критическим ударом!" % target.unit_name)
				
				# ═══ Гладиатор: «Танец клинков» — при крите 20% периодического урона на 2 хода ═══
				if is_crit and ability.ability_marker == "gladiator_blade_dance" and target.current_hp > 0:
					var _bd_dmg = int(target.max_hp * 0.20)
					if _bd_dmg > 0:
						target.active_effects.append({"stat": "periodic_damage", "value": _bd_dmg, "duration": 2, "source_ability": "Танец клинков"})
						log_lines.append("  → [Танец клинков] %s получает %d периодического урона на 2 хода (крит)." % [target.unit_name, _bd_dmg])
				
				# ═══ OnCrit: условие способности — срабатывает при критическом ударе ═══
				if is_crit and "condition" in ability and ability.condition == "OnCrit":
					if ability.ability_marker == "loki_replay":
						var behind_pos = target.position_index + 1
						var replay_team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
						for behind_unit in replay_team:
							if behind_unit and behind_unit.current_hp > 0 and behind_unit.position_index == behind_pos:
								# 15% от урона Локи — периодический урон на юнит позади жертвы крита
								var pdmg = int(attacker.damage * 0.15)
								if pdmg > 0:
									behind_unit.active_effects.append({"stat": "periodic_damage", "value": pdmg, "duration": 2, "source_ability": "Переиграть"})
									log_lines.append("  → [Переиграть/Крит] %s (за %s) получает периодический урон (%d) на 2 хода." % [behind_unit.unit_name, target.unit_name, pdmg])
								break
					else:
						_scene.effects._apply_effect_to_target(attacker, attacker, ability.condition_effect, ability)
						log_lines.append("  → [Крит] %s: срабатывает условие %s." % [attacker.unit_name, ability.condition_effect])
				
				# ═══ Локация: Облака — после попадания по врагу (не богу) ═══
				if CombatManager.selected_location_id == "clouds" and target.is_enemy and final_damage > 0 and target.current_hp > 0:
					var _clouds_val = 20 if target.special_effect_type == "cupid_double_location" else 10
					target.apply_stat_change("evasion", _clouds_val)
					target.active_effects.append({
						"stat": "evasion", "value": _clouds_val, "duration": 1,
						"effect_id": "clouds_evasion", "source_ability": "Облака"
					})
					log_lines.append("  → [Облака] %s получает +%d уклонения на 1 ход (складывается)." % [target.unit_name, _clouds_val])
					_scene.effects._check_pegasus_ally_buff(target, log_lines)
				
				if final_damage > 0:
					var crit_text = " (крит!)" if is_crit else ""
					var armor_note = ""
					if ability.damage_type == "Physical" and final_damage < raw_damage:
						armor_note = " (броня %d%%)" % target.armor
					log_lines.append("  → %s получает %d урона%s%s. HP: %d → %d" % [
						target.unit_name, final_damage, crit_text, armor_note, dmg_result.hp_before, target.current_hp
					])
					# ═══ Сфинкс: «Загадка» — меченый атакующий, ранивший сфинкса ═══
					if target.special_effect_type == "sphinx_debuff_immune":
						var _riddle_on_attacker = false
						for _eff in attacker.active_effects:
							if Combatant._effect_get(_eff, "effect_id", "") == "sphinx_riddle":
								_riddle_on_attacker = true
								break
						if _riddle_on_attacker:
							_scene._passives._resolve_sphinx_riddle(attacker, target, log_lines)
				else:
					log_lines.append("  → %s: урон %d полностью поглощён броней (%d%%)." % [
						target.unit_name, raw_damage, target.armor
					])
		
		if "condition" in ability and ability.condition == "OnKill" and target.current_hp <= 0:
			_scene.effects._apply_effect_to_target(attacker, attacker, ability.condition_effect, ability)
		
		# Примечание: щиты "Кощей: заряды жизни" и "Бессмертный: щит смерти" теперь
		# проверяются прямо в Combatant.take_damage(), ДО died.emit() — см. звук/лог
		# по сигналам koschei_life_shield_triggered/immortal_death_shield_triggered.
		if target.current_hp <= 0:
			log_lines.append("  → %s повержен!" % target.unit_name)
			target.killed_by = attacker
			_scene._unit_events._on_unit_killed(target, log_lines)
			var team = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
			_scene._field._compact_team(team)
			_scene._passives._apply_kappa_auras()
			
			if _scene._outcome._check_battle_end():
				for line in log_lines:
					_scene._log_combat(line)
				return
			
		# Эффекты/дебаффы и снос стоек применяются только при попадании
		# (для способностей без урона attack_landed всегда true).
		if attack_landed:
			if ability.breaks_enemy_stances:
				target.break_stance()
				
			for effect in ability.effect_types:
				if not effect.begins_with("self_"):
					var effect_note = _scene.effects._apply_effect_to_target(attacker, target, effect, ability, is_crit_landed)
					if effect_note != "":
						log_lines.append("  → " + effect_note)
		
		# ═══ Специфичные обработчики маркеров способностей богов ═══
		
		# Яматано Орочи: «Укус змеи» — цель получает периодический урон 25% атаки на 3 хода
		if ability.ability_marker == "orochi_snake_bite" and attack_landed and target.current_hp > 0:
			var _sb_dot: int = int(round(attacker.damage * 0.25 * (1.0 + attacker.get_periodic_damage_bonus_percent() / 100.0)))
			if _sb_dot > 0:
				var _sb_duration: int = _compute_effect_duration(attacker, target, 3, true)
				target.active_effects.append({"stat": "periodic_damage", "value": _sb_dot, "duration": _sb_duration, "source_ability": "Укус змеи"})
				log_lines.append("  → [Укус змеи] %s получает %d периодического урона на %d хода." % [target.unit_name, _sb_dot, _sb_duration])

		# Яматано Орочи: «Змеиный король» — у каждой цели немедленно срабатывает тик периодического урона
		# (длительность при этом уменьшается)
		if ability.ability_marker == "orochi_snake_king" and attack_landed and target.current_hp > 0:
			var _sk_hp_b: int = target.current_hp
			var _sk_total: int = target.trigger_periodic_damage_now()
			if _sk_total > 0:
				log_lines.append("  → [Змеиный король] У %s немедленно срабатывает периодический урон: %d. HP: %d → %d" % [target.unit_name, _sk_total, _sk_hp_b, target.current_hp])
				if target.current_hp <= 0:
					_scene._unit_events._on_unit_killed(target, log_lines)
					_scene._field._compact_team(_scene.heroes_team if not target.is_enemy else _scene.enemies_team)

		# Осирис: «Опаляющий свет» — 0.3 от урона Осириса периодического урона на 3 хода
		if ability.ability_marker == "osiris_scorching_light" and target.current_hp > 0:
			var _sl_dot = int(attacker.damage * 0.3)
			if _sl_dot > 0:
				var _sl_duration = _compute_effect_duration(attacker, target, 3, true)
				target.active_effects.append({"stat": "periodic_damage", "value": _sl_dot, "duration": _sl_duration, "source_ability": "Опаляющий свет"})
				log_lines.append("  → [Опаляющий свет] %s получает %d периодического урона на %d хода." % [target.unit_name, _sl_dot, _sl_duration])

		# Тор: «Удар молота» — если у цели больше 50 брони, ударить ещё раз
		if ability.ability_marker == "thor_hammer_strike" and target.current_hp > 0 and target.armor > 50:
			var hammer_repeat = CombatCalculator.calculate_ability_damage(attacker, target, ability)
			if hammer_repeat.is_hit:
				target.take_damage(hammer_repeat.final_damage)
				total_damage_dealt += hammer_repeat.final_damage
				log_lines.append("  → [Удар молота] Броня цели выше 50 — повторный удар: %d урона. HP: %d → %d" % [
					hammer_repeat.final_damage, hammer_repeat.hp_before, target.current_hp])
				if target.current_hp <= 0:
					log_lines.append("  → %s повержен!" % target.unit_name)
					_scene._unit_events._on_unit_killed(target, log_lines)
					var team_hammer = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
					_scene._field._compact_team(team_hammer)
					_scene._passives._apply_kappa_auras()
					if _scene._outcome._check_battle_end():
						for line in log_lines:
							_scene._log_combat(line)
						return
			else:
				log_lines.append("  → [Удар молота] Броня цели выше 50 — повторный удар промахнулся.")

		# Сусаноо: «Танец меча» — исцеление 12% HP за каждое убийство этой способностью
		if ability.ability_marker == "susanoo_sword_dance" and target.current_hp <= 0:
			var sd_heal = int(attacker.max_hp * 0.12)
			if sd_heal > 0:
				var hp_before_sd = attacker.current_hp
				attacker.apply_stat_change("hp", sd_heal)
				log_lines.append("  → [Танец меча] %s исцеляется на %d HP за убийство. HP: %d → %d" % [
					attacker.unit_name, sd_heal, hp_before_sd, attacker.current_hp])
		
		# Сет: «Разорвать» — повторить удар за каждый бафф на цели.
		# Повторы идут за каждый бафф (и при промахах), но дебафф брони —
		# только за ПОПАВШИЕ повторные удары (-5 брони на 3 хода за попадание).
		if ability.ability_marker == "set_tear_apart" and target.current_hp > 0:
			var buff_count = _scene._count_buffs_on_unit(target)
			var tear_hits := 0
			for repeat_i in range(buff_count):
				if target.current_hp <= 0:
					break
				var rep_result = CombatCalculator.calculate_fixed_damage(attacker, target, 0.3)
				if rep_result.is_hit:
					tear_hits += 1
					target.take_damage(rep_result.final_damage)
					log_lines.append("  → [Разорвать] Повтор #%d: %s получает %d урона. HP: %d → %d" % [
						repeat_i + 1, target.unit_name, rep_result.final_damage, rep_result.hp_before, target.current_hp])
					if target.current_hp <= 0:
						log_lines.append("  → %s повержен!" % target.unit_name)
						_scene._unit_events._on_unit_killed(target, log_lines)
						var team_t = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
						_scene._field._compact_team(team_t)
						_scene._passives._apply_kappa_auras()
						if _scene._outcome._check_battle_end():
							for line in log_lines:
								_scene._log_combat(line)
							return
				else:
					log_lines.append("  → [Разорвать] Повтор #%d: промах по %s." % [repeat_i + 1, target.unit_name])
			if tear_hits > 0:
				var _ta_duration = _compute_effect_duration(attacker, target, 3, true)
				target.apply_stat_change("armor", -5 * tear_hits)
				target.active_effects.append({"stat": "armor", "value": -5 * tear_hits, "duration": _ta_duration, "effect_id": "set_tear_apart_armor", "source_ability": "Разорвать"})
				log_lines.append("  → [Разорвать] %s теряет %d брони на %d хода (%d попаданий из %d)." % [target.unit_name, 5 * tear_hits, _ta_duration, tear_hits, buff_count])

		# Сет: «В саркофаг» — оглушить союзника + неуязвимость до следующего хода Сета
		if ability.ability_marker == "set_sarcophagus":
			target.is_stunned = true
			var _sc_stun_duration = _compute_effect_duration(attacker, target, 1, true)
			var _sc_invul_duration = _compute_effect_duration(attacker, target, 1, false)
			target.active_effects.append({"stat": "stun", "value": 1, "duration": _sc_stun_duration, "effect_id": "sarcophagus_stun", "source_ability": "В саркофаг"})
			target.active_effects.append({"stat": "invulnerable", "value": 1, "duration": _sc_invul_duration, "effect_id": "sarcophagus_invul", "source_ability": "В саркофаг"})
			target.check_stance_interruption("stun")
			log_lines.append("  → [В саркофаг] %s оглушён и неуязвим до следующего хода Сета." % target.unit_name)
		
		# Сет: «Узурпировать» — заменить свою ульту на ульту выбранного союзника.
		if ability.ability_marker == "set_usurp":
			if target.ultimate_ability and target != attacker:
				var copied_ult: AbilityResource = target.ultimate_ability
				attacker.ultimate_ability = copied_ult
				attacker.has_usurped_ultimate = true
				log_lines.append("  → [Узурпировать] %s забирает ульту «%s» у %s." % [
					attacker.unit_name, copied_ult.name, target.unit_name])
			elif target == attacker:
				log_lines.append("  → [Узурпировать] Нельзя узурпировать собственную ульту.")
			else:
				log_lines.append("  → [Узурпировать] У %s нет ульты." % target.unit_name)
		
		# Локи: «Танец бога обмана» — +30 уклонения (2 хода), вперёд 1,
		# каждый враг -10 удачи (2 хода), за каждого врага +10 удачи (2 хода).
		if ability.ability_marker == "loki_trickster_dance":
			# +30 уклонения на 1 ход (+1, если у команды есть пассивка Одина)
			var _ltd_duration = _compute_effect_duration(attacker, attacker, 1, false)
			attacker.apply_stat_change("evasion", 30)
			attacker.active_effects.append({"stat": "evasion", "value": 30, "duration": _ltd_duration, "effect_id": "loki_trickster_evasion", "source_ability": "Танец бога обмана"})
			# Двинуть себя вперёд на 1
			if not attacker.is_large:
				var _td_old = attacker.position_index
				_scene._field._apply_shift_effect(attacker, -1, _scene._is_player_hero(attacker))
				log_lines.append("  → [Танец бога обмана] %s: вперёд 1 (линия %d → %d)." % [attacker.unit_name, _td_old + 1, attacker.position_index + 1])
			# Каждый враг -10 удачи; за каждого врага +10 удачи на 2 хода
			var trick_enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
			var trick_count = 0
			var _ltd_debuff_duration = 2
			for trick_target in trick_enemies:
				_ltd_debuff_duration = _compute_effect_duration(attacker, trick_target, 2, true)
				trick_target.apply_stat_change("crit", -10)
				trick_target.active_effects.append({"stat": "crit", "value": -10, "duration": _ltd_debuff_duration, "effect_id": "loki_trickster_debuff", "source_ability": "Танец бога обмана"})
				trick_count += 1
			if trick_count > 0:
				var _ltd_buff_duration = _compute_effect_duration(attacker, attacker, 2, false)
				attacker.apply_stat_change("crit", 10 * trick_count)
				attacker.active_effects.append({"stat": "crit", "value": 10 * trick_count, "duration": _ltd_buff_duration, "effect_id": "loki_trickster_buff", "source_ability": "Танец бога обмана"})
			log_lines.append("  → [Танец бога обмана] %s: +30 уклонения (2 хода), %d враг(ов) теряют по 10 удачи, +%d удачи (2 хода)." % [attacker.unit_name, trick_count, 10 * trick_count])
		
		# Кощей: «Чахнуть над златом» — восстановить 15 фантазии, снять дебаффы
		if ability.ability_marker == "koschei_hoard_gold":
			_scene.current_fantasy = mini(_scene.max_fantasy, _scene.current_fantasy + 15)
			_scene.effects._dispel_effects(attacker, "debuff")
			_scene._spells._update_spell_ui()
			log_lines.append("  → [Чахнуть над златом] %s восстанавливает 15 фантазии (итого: %d) и снимает дебаффы." % [
				attacker.unit_name, _scene.current_fantasy])
		
		# Кощей: «Назад!» — восстановить 1 заряд жизни + 20 брони
		if ability.ability_marker == "koschei_go_back":
			if attacker.life_charges < attacker.get_max_life_charges():
				attacker.life_charges += 1
				log_lines.append("  → [Назад!] %s восстанавливает 1 заряд жизни (осталось: %d)." % [
					attacker.unit_name, attacker.life_charges])
			else:
				log_lines.append("  → [Назад!] %s уже имеет максимум зарядов жизни." % attacker.unit_name)
			var _gb_duration = _compute_effect_duration(attacker, attacker, 1, false)
			attacker.apply_stat_change("armor", 20)
			attacker.active_effects.append({"stat": "armor", "value": 20, "duration": _gb_duration, "effect_id": "koschei_go_back_armor", "source_ability": "Назад!"})
			log_lines.append("  → [Назад!] %s получает +20 брони на %d ход(ов)." % [attacker.unit_name, _gb_duration])
		
		# Аид: «Касание смерти» — продлить все дебаффы на цели на 1 ход
		if ability.ability_marker == "hades_death_touch":
			for eff in target.active_effects:
				if Combatant._effect_get(eff, "duration", 0) > 0:
					var eff_stat = Combatant._effect_get(eff, "stat", "")
					if eff_stat != "stun" and eff_stat != "invulnerable" and eff_stat != "regeneration":
						if Combatant._effect_get(eff, "value", 0) < 0:
							eff["duration"] = eff.get("duration", 1) + 1
			log_lines.append("  → [Касание смерти] Дебаффы на %s продлены на 1 ход." % target.unit_name)
		
		# Аид: «Ловец душ» — потратить 15 фантазии, исцелить союзника на 15% HP
		if ability.ability_marker == "hades_soul_catcher":
			if _scene.current_fantasy >= 15:
				_scene.current_fantasy -= 15
				var sc_heal = int(target.max_hp * 0.15)
				if sc_heal > 0:
					var hp_before_sc = target.current_hp
					target.apply_stat_change("hp", sc_heal)
					log_lines.append("  → [Ловец душ] %s исцеляет %s на %d HP (%d → %d). Потрачено 15 фантазии." % [
						attacker.unit_name, target.unit_name, sc_heal, hp_before_sc, target.current_hp])
				_scene._spells._update_spell_ui()
			else:
				log_lines.append("  → [Ловец душ] Недостаточно фантазии (%d/15)." % _scene.current_fantasy)
		
		# Моргана: «Усыпление» — если 3+ дебаффа на цели, оглушить
		if ability.ability_marker == "morgan_sleep":
			var sleep_debuffs = _scene._count_debuffs_on_unit(target)
			if sleep_debuffs >= 3 and target.current_hp > 0:
				target.is_stunned = true
				var _sl_stun_duration = _compute_effect_duration(attacker, target, 1, true)
				target.active_effects.append({"stat": "stun", "value": 1, "duration": _sl_stun_duration, "source_ability": "Усыпление"})
				target.check_stance_interruption("stun")
				log_lines.append("  → [Усыпление] %s: %d дебаффов → оглушение на %d ход(ов)!" % [target.unit_name, sleep_debuffs, _sl_stun_duration])
			else:
				log_lines.append("  → [Усыпление] %s: %d дебаффов (нужно 3 для оглушения)." % [target.unit_name, sleep_debuffs])
		
		# Моргана: «Тайная магия» — разрешить дополнительное заклинание в этом раунде
		if ability.ability_marker == "morgan_secret_magic":
			_scene.max_spells_per_round += 1
			log_lines.append("  → [Тайная магия] %s может использовать ещё одно заклинание в этом раунде." % attacker.unit_name)
		
		# Моргана: «Власть тьмы» — за каждый дебафф на цели: 3% периодического урона на 5 ходов
		if ability.ability_marker == "morgan_dark_dominion":
			var dd_debuffs = _scene._count_debuffs_on_unit(target)
			if dd_debuffs > 0:
				var dd_dmg = int(target.max_hp * 0.03 * dd_debuffs)
				var dd_duration = _compute_effect_duration(attacker, target, 5, true)
				target.active_effects.append({"stat": "periodic_damage", "value": dd_dmg, "duration": dd_duration, "source_ability": "Власть тьмы"})
				log_lines.append("  → [Власть тьмы] %s получает %d периодического урона на %d ходов (%d дебаффов)." % [
					target.unit_name, dd_dmg, dd_duration, dd_debuffs])
		
		# ═══ Они: «По голове» — 15% шанс оглушить цель на 1 ход ═══
		if ability.ability_marker == "oni_head_blow" and target.current_hp > 0:
			if randf() < 0.15:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "По голове"})
				target.check_stance_interruption("stun")
				log_lines.append("  → [По голове] %s оглушён! (15%% шанс)." % target.unit_name)
		
		# ═══ Они: «Огненные ладони» — 0.4x периодический урон на 2 хода ═══
		if ability.ability_marker == "oni_fiery_palms" and target.current_hp > 0:
			var _fp_dmg = int(attacker.damage * 0.4)
			if _fp_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _fp_dmg, "duration": 2, "source_ability": "Огненные ладони"})
				log_lines.append("  → [Огненные ладони] %s получает %d периодического урона на 2 хода." % [target.unit_name, _fp_dmg])
		
		# ═══ Лев: «Львиный укус» — исцелить атакующего на половину нанесённого урона ═══
		if ability.ability_marker == "lion_bite" and total_damage_dealt > 0:
			var _lb_heal = int(total_damage_dealt / 2)
			if _lb_heal > 0:
				var _hp_before_lb = attacker.current_hp
				attacker.apply_stat_change("hp", _lb_heal)
				log_lines.append("  → [Львиный укус] %s исцеляется на %d HP (половина урона). HP: %d → %d" % [
					attacker.unit_name, _lb_heal, _hp_before_lb, attacker.current_hp])
		
		# ═══ Титан: «Могучий удар» — +5 урона до конца боя ═══
		if ability.ability_marker == "titan_mighty_hit":
			attacker.apply_stat_change("damage", 5)
			log_lines.append("  → [Могучий удар] %s: +5 урона до конца боя (итого: %d)." % [attacker.unit_name, attacker.damage])
		
		# ═══ Бессмертный: «Двигаться вместе с песком» — вперёд на 1 + уклонение ═══
		if ability.ability_marker == "immortal_sand_step":
			if not attacker.is_large:
				var _ss_old = attacker.position_index
				_scene._field._apply_shift_effect(attacker, -1, _scene._is_player_hero(attacker))
				log_lines.append("  → [Двигаться с песком] %s продвигается вперёд: линия %d → %d." % [attacker.unit_name, _ss_old + 1, attacker.position_index + 1])
			attacker.apply_stat_change("evasion", 20)
			attacker.active_effects.append({"stat": "evasion", "value": 20, "duration": 2, "effect_id": "immortal_sand_step", "source_ability": "Двигаться вместе с песком"})
			log_lines.append("  → [Двигаться с песком] %s: +20 уклонения на 2 хода." % attacker.unit_name)
		
		# ═══ Жрец Анубиса: «Волна скоробеев» — оттолкнуть на 2 + 10% периодического урона ═══
		if ability.ability_marker == "anubis_scarab_wave" and target.current_hp > 0:
			if not target.is_large:
				var _sw_old = target.position_index
				_scene._field._apply_shift_effect(target, 2, _scene._is_player_hero(target))
				log_lines.append("  → [Волна скоробеев] %s отталкивается назад: линия %d → %d." % [target.unit_name, _sw_old + 1, target.position_index + 1])
			var _sw_pdmg = int(target.max_hp * 0.10)
			if _sw_pdmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _sw_pdmg, "duration": 2, "source_ability": "Волна скоробеев"})
				log_lines.append("  → [Волна скоробеев] %s получает %d периодического урона на 2 хода." % [target.unit_name, _sw_pdmg])
		
		# ═══ Жрец Анубиса: «Отсрочка от смерти» — если у цели <40% HP: +40% HP и +15 урон/точность на 3 хода ═══
		if ability.ability_marker == "anubis_death_delay" and target.current_hp > 0:
			if float(target.current_hp) / float(target.max_hp) < 0.40:
				var _dd_heal = int(target.max_hp * 0.40)
				var _dd_hp_before = target.current_hp
				target.apply_stat_change("hp", _dd_heal)
				target.apply_stat_change("damage", 15)
				target.active_effects.append({"stat": "damage", "value": 15, "duration": 3, "effect_id": "anubis_death_delay_dmg", "source_ability": "Отсрочка от смерти"})
				target.apply_stat_change("accuracy", 15)
				target.active_effects.append({"stat": "accuracy", "value": 15, "duration": 3, "effect_id": "anubis_death_delay_acc", "source_ability": "Отсрочка от смерти"})
				log_lines.append("  → [Отсрочка от смерти] %s: восстановление %d HP (%d → %d), +15 урона и точности на 3 хода." % [target.unit_name, _dd_heal, _dd_hp_before, target.current_hp])
			else:
				log_lines.append("  → [Отсрочка от смерти] %s: HP выше 40%% — отсрочка не требуется." % target.unit_name)
		
		# ═══ Мумия: «Древнее проклятие» — метка на позиции: -2 урон и -2 броня до конца боя ═══
		if ability.ability_marker == "mummy_ancient_curse" and target.current_hp > 0:
			target.apply_stat_change("damage", -2)
			target.apply_stat_change("armor", -2)
			target.active_effects.append({"stat": "damage", "value": -2, "duration": -1, "effect_id": "mummy_ancient_curse_mark", "source_ability": "Древнее проклятие"})
			target.active_effects.append({"stat": "armor", "value": -2, "duration": -1, "effect_id": "mummy_ancient_curse_mark", "source_ability": "Древнее проклятие"})
			_scene.marks.add_position_mark({
				"caster": attacker, "team": "ally", "position": target.position_index,
				"type": "persistent", "rounds_left": 999,
				"damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "mummy_ancient_curse_mark", "effect_value": 2, "effect_duration": -1,
				"icon": ability.mark_icon,
				"triggered_units_this_round": [target]
			})
			log_lines.append("  → [Древнее проклятие] Метка на позиции %d: -2 урона и -2 брони до конца боя." % (target.position_index + 1))
		
		# ═══ Мумия: «Аура смерти» — -15% удачи цели на 2 хода ═══
		if ability.ability_marker == "mummy_death_aura" and target.current_hp > 0:
			target.apply_stat_change("crit", -15)
			target.active_effects.append({"stat": "crit", "value": -15, "duration": 2, "effect_id": "mummy_death_aura", "source_ability": "Аура смерти"})
			log_lines.append("  → [Аура смерти] %s: -15%% удачи на 2 хода." % target.unit_name)
		
		# ═══ Сфинкс: «Загадка» — марка загадки на цели ═══
		if ability.ability_marker == "sphinx_riddle" and target.current_hp > 0:
			target.active_effects.append({"stat": "riddle_mark", "value": 1, "duration": 2, "effect_id": "sphinx_riddle", "source_ability": "Загадка"})
			log_lines.append("  → [Загадка] %s под загадкой: ранит сфинкса или сдвинется — получит 90%% урона." % target.unit_name)

		# ════ АД: ability_marker обработчики юнитов локации Hell ════
		# Адская гончая: «Пылающие зубы» — периодический урон 0.3 на 3 хода
		if ability.ability_marker == "hellhound_teeth" and target.current_hp > 0:
			var _ht_dot = int(attacker.damage * 0.3)
			if _ht_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _ht_dot, "duration": 3, "source_ability": "Пылающие зубы"})
				_scene.effects._apply_tormentor_regen(attacker, _ht_dot, 3)
				log_lines.append("  → [Пылающие зубы] %s получает периодический урон (%d) на 3 хода." % [target.unit_name, _ht_dot])

		# Дварф кузнец: «Пламя горнила» — периодический урон 0.15 от урона на 2 хода
		if ability.ability_marker == "dwarf_smith_forge_flame" and target.current_hp > 0:
			var _df_dot = int(attacker.damage * 0.15)
			if _df_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _df_dot, "duration": 2, "source_ability": "Пламя горнила"})
				_scene.effects._apply_tormentor_regen(attacker, _df_dot, 2)
				log_lines.append("  → [Пламя горнила] %s получает периодический урон (%d) на 2 хода." % [target.unit_name, _df_dot])
		# Адская гончая: «Не бояться смерти» — -20 броня +20 урон на 3 хода
		if ability.ability_marker == "hellhound_no_fear":
			attacker.apply_stat_change("armor", -20)
			attacker.apply_stat_change("damage", 20)
			attacker.active_effects.append({"stat": "damage", "value": 20, "duration": 3, "effect_id": "hellhound_no_fear", "source_ability": "Не бояться смерти"})
			attacker.active_effects.append({"stat": "armor", "value": -20, "duration": 3, "effect_id": "hellhound_no_fear", "source_ability": "Не бояться смерти"})
			log_lines.append("  → [Не бояться смерти] %s: -20 брони, +20 урона на 3 хода." % attacker.unit_name)
		# Страдающая душа: «Лишь один путь» — вперёд 1 + лечение 15%
		if ability.ability_marker == "soul_one_path":
			var _sop_heal = int(attacker.max_hp * 0.15)
			if _sop_heal > 0:
				attacker.apply_stat_change("hp", _sop_heal)
				log_lines.append("  → [Лишь один путь] %s восстанавливает %d HP (15%%)." % [attacker.unit_name, _sop_heal])
		# Страдающая душа: «Услышь мой крик» — все враги +1 уровень забыванья
		if ability.ability_marker == "soul_hear_cry" and target == targets[0]:
			var _shc_foes = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			for _shc_f in _shc_foes:
				if _shc_f != null and _shc_f.current_hp > 0:
					_shc_f.add_forget(1.0, "Услышь мой крик")
			log_lines.append("  → [Услышь мой крик] Все враги получают 1 уровень забыванья.")
		# Мучитель: «Зазубренный трезубец» — -10 броня 2 хода, DoT 0.3 2 хода, цель вперёд 1
		if ability.ability_marker == "tormentor_trident" and target.current_hp > 0:
			target.apply_stat_change("armor", -10)
			target.active_effects.append({"stat": "armor", "value": -10, "duration": 2, "effect_id": "tormentor_trident", "source_ability": "Зазубренный трезубец"})
			var _trt_dot = int(attacker.damage * 0.3)
			if _trt_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _trt_dot, "duration": 2, "source_ability": "Зазубренный трезубец"})
				_scene.effects._apply_tormentor_regen(attacker, _trt_dot, 2)
			if not target.is_large:
				_scene._field._apply_shift_effect(target, -1, not target.is_enemy)
			log_lines.append("  → [Зазубренный трезубец] %s: -10 брони (2), DoT (%d) (2), вперёд 1." % [target.unit_name, _trt_dot])
		# Мучитель: «Лязг цепей» — DoT 0.1 4 хода, обе цели вперёд 1
		if ability.ability_marker == "tormentor_chains":
			var _ch_dot = int(attacker.damage * 0.1)
			if _ch_dot > 0:
				if target.current_hp > 0:
					target.active_effects.append({"stat": "periodic_damage", "value": _ch_dot, "duration": 4, "source_ability": "Лязг цепей"})
					_scene.effects._apply_tormentor_regen(attacker, _ch_dot, 4)
				for _ch_t in targets:
					if _ch_t != null and _ch_t.current_hp > 0 and not _ch_t.is_large:
						_scene._field._apply_shift_effect(_ch_t, -1, not _ch_t.is_enemy)
			log_lines.append("  → [Лязг цепей] DoT (%d) на 4 хода, цели вперёд 1." % _ch_dot)
		# Мучитель: «Симфония боли» — союзники +3 атаки и +3 удачи за каждый дебафф на врагах
		if ability.ability_marker == "tormentor_symphony" and target == targets[0]:
			var _sym_foes = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			var _sym_debuffs = 0
			for _sym_f in _sym_foes:
				if _sym_f == null or _sym_f.current_hp <= 0:
					continue
				for _sym_e in _sym_f.active_effects:
					if Combatant._effect_get(_sym_e, "stat", "") == "periodic_damage" or Combatant._effect_get(_sym_e, "value", 0) < 0:
						_sym_debuffs += 1
			var _sym_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			for _sym_ally in _sym_team:
				if _sym_ally and _sym_ally.current_hp > 0:
					var _sym_dmg = 3 * _sym_debuffs
					var _sym_crt = 3 * _sym_debuffs
					if _sym_dmg > 0:
						_sym_ally.apply_stat_change("damage", _sym_dmg)
						_sym_ally.active_effects.append({"stat": "damage", "value": _sym_dmg, "duration": 1, "effect_id": "tormentor_symphony", "source_ability": "Симфония боли"})
					if _sym_crt > 0:
						_sym_ally.apply_stat_change("crit", _sym_crt)
						_sym_ally.active_effects.append({"stat": "crit", "value": _sym_crt, "duration": 1, "effect_id": "tormentor_symphony", "source_ability": "Симфония боли"})
			log_lines.append("  → [Симфония боли] %d дебаффов → союзники +%d урона, +%d удачи (1 ход)." % [_sym_debuffs, 3*_sym_debuffs, 3*_sym_debuffs])
		# Суккуб: «Пылающий поцелуй» — -15 уклонения и -15 атаки на 4 хода
		if ability.ability_marker == "succubus_kiss" and target.current_hp > 0:
			target.apply_stat_change("evasion", -15)
			target.apply_stat_change("damage", -15)
			target.active_effects.append({"stat": "evasion", "value": -15, "duration": 4, "effect_id": "succubus_kiss", "source_ability": "Пылающий поцелуй"})
			target.active_effects.append({"stat": "damage", "value": -15, "duration": 4, "effect_id": "succubus_kiss", "source_ability": "Пылающий поцелуй"})
			log_lines.append("  → [Пылающий поцелуй] %s: -15 уклонения, -15 атаки на 4 хода." % target.unit_name)
		# Суккуб: «Я выбираю тебя» — метка провокации на 3 хода
		if ability.ability_marker == "succubus_choose_you" and target.current_hp > 0:
			target.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": 3, "effect_id": "provocation_mark", "source_ability": "Я выбираю тебя"})
			log_lines.append("  → [Я выбираю тебя] %s получает метку провокации на 3 хода." % target.unit_name)
		# Кошмар: «Наступление ада» — вперёд 1 атакующего (доп. цель позади уже через extra_targets)
		if ability.ability_marker == "nightmare_hell_assault" and target == targets[0]:
			if not attacker.is_large:
				_scene._field._apply_shift_effect(attacker, -1, not attacker.is_enemy)
			log_lines.append("  → [Наступление ада] %s: вперёд 1." % attacker.unit_name)
		# Кошмар: «Проникнуть в сны» — все враги теряют 10 величия
		if ability.ability_marker == "nightmare_dreams" and target == targets[0]:
			var _nd_foes = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			for _nd_f in _nd_foes:
				if _nd_f != null and _nd_f.current_hp > 0:
					_nd_f.modify_majesty(-10)
			log_lines.append("  → [Проникнуть в сны] Все враги теряют 10 величия.")
		# Дьявол: «Адская гильотина» — марка once: в начале след хода дьявола сработает
		if ability.ability_marker == "devil_guillotine" and target.current_hp > 0:
			_scene.marks.add_position_mark({
				"caster": attacker, "team": "enemy", "position": target.position_index,
				"type": "once", "rounds_left": 1, "damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "devil_guillotine", "effect_value": 0, "effect_duration": 0,
				"icon": ability.mark_icon,
				"triggered_units_this_round": [], "_forget": 0.5
			})
			log_lines.append("  → [Адская гильотина] Марка на %s — сработает в начале след. хода дьявола." % target.unit_name)

		# ════ ДЖУНГЛИ: ability_marker обработчики ════
		# Сару: «Обезьяньи трюки» — снять баффы + сбить стойку
		if ability.ability_marker == "saru_tricks" and target.current_hp > 0:
			_scene.effects._dispel_effects(target, "buff")
			if target.active_stance != null:
				target.break_stance()
				log_lines.append("  → [Обезьяньи трюки] Стойка %s сбита." % target.unit_name)
			log_lines.append("  → [Обезьяньи трюки] С %s сняты все баффы." % target.unit_name)
		# Нага воин: «Бросок кобры» — вперёд 1 + DoT 0.3 на 2 хода
		if ability.ability_marker == "naga_cobra_throw" and target.current_hp > 0:
			if not attacker.is_large:
				_scene._field._apply_shift_effect(attacker, -1, not attacker.is_enemy)
			var _nc_dot = int(attacker.damage * 0.3)
			if _nc_dot > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _nc_dot, "duration": 2, "source_ability": "Бросок кобры"})
				log_lines.append("  → [Бросок кобры] %s получает периодический урон (%d) на 2 хода." % [target.unit_name, _nc_dot])
		# Нага монах: «Кармическое наказание» — все противники -12 точности -5 уклонения
		if ability.ability_marker == "naga_karma_punish" and target == targets[0]:
			var _kp_foes = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			for _kp_f in _kp_foes:
				if _kp_f != null and _kp_f.current_hp > 0:
					_kp_f.apply_stat_change("accuracy", -12)
					_kp_f.apply_stat_change("evasion", -5)
					_kp_f.active_effects.append({"stat": "accuracy", "value": -12, "duration": 1, "effect_id": "naga_karma", "source_ability": "Кармическое наказание"})
					_kp_f.active_effects.append({"stat": "evasion", "value": -5, "duration": 1, "effect_id": "naga_karma", "source_ability": "Кармическое наказание"})
			log_lines.append("  → [Кармическое наказание] Все враги: -12 точности, -5 уклонения.")
		# Коатль: «Кислотное дыхание» — DoT 0.2 -10 броня на 2 хода (все цели)
		if ability.ability_marker == "coatl_acid_breath":
			var _ab_dot = int(attacker.damage * 0.2)
			for _ab_t in targets:
				if _ab_t != null and _ab_t.current_hp > 0:
					if _ab_dot > 0:
						_ab_t.active_effects.append({"stat": "periodic_damage", "value": _ab_dot, "duration": 2, "source_ability": "Кислотное дыхание"})
					_ab_t.apply_stat_change("armor", -10)
					_ab_t.active_effects.append({"stat": "armor", "value": -10, "duration": 2, "effect_id": "coatl_acid", "source_ability": "Кислотное дыхание"})
			if _ab_dot > 0:
				log_lines.append("  → [Кислотное дыхание] Цели получают периодический урон (%d) и -10 брони на 2 хода." % _ab_dot)
		# Коатль: «Ветра судьбы» — вперёд 1 + метка невинности 3 хода
		if ability.ability_marker == "coatl_winds":
			if not attacker.is_large:
				_scene._field._apply_shift_effect(attacker, -1, not attacker.is_enemy)
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 3, "effect_id": "cupid_innocence", "source_ability": "Ветра судьбы"})
			log_lines.append("  → [Ветра судьбы] %s: вперёд 1, метка невинности на 3 хода." % attacker.unit_name)
		# Асура: «Проклятие отчаяния» — +1 к числу зарядов curse_pending
		if ability.ability_marker == "asura_curse":
			var _ac_cur = int(attacker.get_meta("asura_curse_pending", 0)) + 1
			attacker.set_meta("asura_curse_pending", _ac_cur)
			log_lines.append("  → [Проклятие отчаяния] %s: следующий «Удар хаоса» наложит DoT 0.4 на 5 ходов (зарядов: %d)." % [attacker.unit_name, _ac_cur])
		# Асура: «Удар хаоса» — меняет базовую удачу цели на 0-10 на 1 ход; если есть curse → DoT 0.4 на 5 ходов
		if ability.ability_marker == "asura_chaos_strike" and target.current_hp > 0:
			var _acs_new_crit = randf() * 0.10
			target.set_meta("asura_chaos_crit_override", _acs_new_crit)
			target.set_meta("asura_chaos_crit_turns", 1)
			var _ac_cur = int(attacker.get_meta("asura_curse_pending", 0))
			if _ac_cur > 0:
				var _ac_dot = int(attacker.damage * 0.4)
				if _ac_dot > 0:
					target.active_effects.append({"stat": "periodic_damage", "value": _ac_dot, "duration": 5, "source_ability": "Проклятие отчаяния"})
					log_lines.append("  → [Удар хаоса/Проклятие] %s получает периодический урон (%d) на 5 ходов." % [target.unit_name, _ac_dot])
				attacker.set_meta("asura_curse_pending", _ac_cur - 1)
			log_lines.append("  → [Удар хаоса] Удача %s установлена на %d%% на 1 ход." % [target.unit_name, int(_acs_new_crit * 100)])
		# Асура: «Чёрная полоса» — ставит meta для ИИ
		if ability.ability_marker == "asura_streak" and target.current_hp > 0:
			attacker.set_meta("asura_streak_active", true)
			log_lines.append("  → [Чёрная полоса] Марка на %s." % target.unit_name)

		# ═══ Золотой скоробей: «На удачу» — все союзники +30% удачи на 1 ход ═══
		if ability.ability_marker == "scarab_good_luck":
			var _gl_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			for _gl_ally in _gl_team:
				if _gl_ally and _gl_ally.current_hp > 0:
					_gl_ally.apply_stat_change("crit", 30)
					_gl_ally.active_effects.append({"stat": "crit", "value": 30, "duration": 1, "effect_id": "scarab_good_luck", "source_ability": "На удачу"})
			log_lines.append("  → [На удачу] Все союзники: +30% удачи на 1 ход.")
		
		# ═══ Минотавр: «Устрашающий рёв» — союзники +10 урона / враги -10 урона на 3 хода ═══
		if ability.ability_marker == "minotaur_intimidating_roar":
			var _mr_ally_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			var _mr_foe_team = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			for _mr_ally in _mr_ally_team:
				if _mr_ally and _mr_ally.current_hp > 0:
					_mr_ally.apply_stat_change("damage", 10)
					_mr_ally.active_effects.append({"stat": "damage", "value": 10, "duration": 3, "effect_id": "minotaur_roar_buff", "source_ability": "Устрашающий рёв"})
			for _mr_foe in _mr_foe_team:
				if _mr_foe and _mr_foe.current_hp > 0:
					_mr_foe.apply_stat_change("damage", -10)
					_mr_foe.active_effects.append({"stat": "damage", "value": -10, "duration": 3, "effect_id": "minotaur_roar_debuff", "source_ability": "Устрашающий рёв"})
			log_lines.append("  → [Устрашающий рёв] Союзники +10 урона, враги -10 урона на 3 хода.")
		
		# ═══ Наставник: «Наказание» — все союзники +15 точности на 1 ход ═══
		if ability.ability_marker == "mentor_punishment":
			var _mp_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			for _mp_ally in _mp_team:
				if _mp_ally and _mp_ally.current_hp > 0:
					_mp_ally.apply_stat_change("accuracy", 15)
					_mp_ally.active_effects.append({"stat": "accuracy", "value": 15, "duration": 1, "effect_id": "mentor_punishment", "source_ability": "Наказание"})
			log_lines.append("  → [Наказание] Все союзники: +15 точности на 1 ход.")
		
		# ═══ Нанауэ: «Драть плоть» — 0.5 периодического урона на 2 хода ═══
		if ability.ability_marker == "nanau_flesh_tear" and target.current_hp > 0:
			var _ft_dmg = int(attacker.damage * 0.5)
			if _ft_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _ft_dmg, "duration": 2, "source_ability": "Драть плоть"})
				log_lines.append("  → [Драть плоть] %s получает периодический урон (%d) на 2 хода." % [target.unit_name, _ft_dmg])
		
		# ═══ Нанауэ: «Поглотить» — отменяет периодический урон цели и лечит Нанауэ на 30% ═══
		if ability.ability_marker == "nanau_consume" and target.current_hp > 0:
			var _had_dot = false
			var _ci = 0
			while _ci < target.active_effects.size():
				if Combatant._effect_get(target.active_effects[_ci], "stat", "") == "periodic_damage":
					target.active_effects.remove_at(_ci)
					_had_dot = true
				else:
					_ci += 1
			if _had_dot:
				var _dev_heal = int(attacker.max_hp * 0.30)
				var _dev_hp_b = attacker.current_hp
				attacker.apply_stat_change("hp", _dev_heal)
				log_lines.append("  → [Поглотить] Периодический урон с %s снят. %s восстанавливает %d HP (%d → %d)." % [target.unit_name, attacker.unit_name, _dev_heal, _dev_hp_b, attacker.current_hp])
		
		# ═══ Морская ведьма: «Водоворот» — обмен позиций врагов 1↔4, 2↔3 (один раз за применение) ═══
		if ability.ability_marker == "seawitch_whirlpool" and (targets.is_empty() or target == targets[0]):
			var _wp_log = _scene._field._swap_enemy_positions(attacker)
			for _wl in _wp_log:
				log_lines.append(_wl)
		
		# ═══ Морская ведьма: «Глубоководное проклятие» — DoT 0.3 на 5 ходов + позиционная марка на 2 хода ═══
		if ability.ability_marker == "seawitch_curse" and target.current_hp > 0:
			var _curs_dmg = int(attacker.damage * 0.3)
			if _curs_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _curs_dmg, "duration": 5, "source_ability": "Глубоководное проклятие"})
				log_lines.append("  → [Глубоководное проклятие] %s получает периодический урон (%d) на 5 ходов." % [target.unit_name, _curs_dmg])
			# Позиционная марка (persistent, 2 хода): повторно накладывает DoT на входящего.
			var _curse_mark = {
				"caster": attacker, "team": "ally", "position": target.position_index,
				"type": "persistent", "rounds_left": 2,
				"damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "seawitch_curse_dot", "effect_value": _curs_dmg, "effect_duration": 5,
				"icon": ability.mark_icon,
				"triggered_units_this_round": []
			}
			_scene.marks.add_position_mark(_curse_mark)
			log_lines.append("  → [Глубоководное проклятие] Марка на позиции %d на 2 хода." % (target.position_index + 1))
		
		# ═══ Морская ведьма: «Мрачная сделка» — +3 инициативы 2 хода + блок ульты 1 ход ═══
		if ability.ability_marker == "seawitch_dark_deal" and target.current_hp > 0:
			target.apply_stat_change("initiative", 3)
			target.active_effects.append({"stat": "initiative", "value": 3, "duration": 2, "effect_id": "seawitch_dark_deal_init", "source_ability": "Мрачная сделка"})
			target.ultimate_blocked = true
			target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 1, "effect_id": "ultimate_blocked", "source_ability": "Мрачная сделка"})
			log_lines.append("  → [Мрачная сделка] %s: +3 инициативы 2 хода, ультимативная способность заблокирована на 1 ход." % target.unit_name)
		
		# ═══ Угорь: «Двойной укус» — метка челюсти (отложенная атака в начале след. хода) ═══
		if ability.ability_marker == "eel_double_bite" and target.current_hp > 0:
			attacker.jaw_mark_target = target
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 1, "effect_id": "eel_jaw_mark", "source_ability": "Двойной укус"})
			log_lines.append("  → [Двойной укус] %s ставит метку челюсти на %s." % [attacker.unit_name, target.unit_name])

		# ═══ Посейдон: «Удар трезубцем» — +5% урона за каждый бафф на себе ═══
		if ability.ability_marker == "poseidon_trident_strike":
			var buff_count = _scene._count_buffs_on_unit(attacker)
			var bonus_dmg = int(attacker.damage * 0.05 * buff_count)
			if bonus_dmg > 0 and target.current_hp > 0:
				target.take_damage(bonus_dmg)
				log_lines.append("  → [Удар трезубцем] +%d доп. урона за %d баффов. HP %s: %d." % [bonus_dmg, buff_count, target.unit_name, target.current_hp])

		# ═══ Самди: «Выпей со смертью» — периодический урон себе и цели ═══
		if ability.ability_marker == "samdi_drink_with_death":
			var dot_self = int(attacker.damage * 0.5)
			var dot_tgt = int(attacker.damage * 0.5)
			if dot_self > 0:
				var _dwd_self_duration = _compute_effect_duration(attacker, attacker, 2, true)
				attacker.active_effects.append({"stat": "periodic_damage", "value": dot_self, "duration": _dwd_self_duration, "source_ability": "Выпей со смертью"})
			if dot_tgt > 0 and target.current_hp > 0:
				var _dwd_tgt_duration = _compute_effect_duration(attacker, target, 2, true)
				target.active_effects.append({"stat": "periodic_damage", "value": dot_tgt, "duration": _dwd_tgt_duration, "source_ability": "Выпей со смертью"})
			log_lines.append("  → [Выпей со смертью] %s и %s получают периодический урон (%d) на 2 хода." % [attacker.unit_name, target.unit_name, dot_self])

		# ═══ Самди: «Веселье никогда не заканчивается» — все юниты +20 удачи +20 уклонения -30 точности -15 брони ═══
		if ability.ability_marker == "samdi_party" and target == targets[0]:
			for u in _scene.heroes_team + _scene.enemies_team:
				if u != null and u.current_hp > 0:
					var _sp_buff_duration = _compute_effect_duration(attacker, u, 2, false)
					var _sp_debuff_duration = _compute_effect_duration(attacker, u, 2, true)
					u.apply_stat_change("crit", 20); u.active_effects.append({"stat":"crit","value":20,"duration":_sp_buff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
					u.apply_stat_change("evasion", 20); u.active_effects.append({"stat":"evasion","value":20,"duration":_sp_buff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
					u.apply_stat_change("accuracy", -30); u.active_effects.append({"stat":"accuracy","value":-30,"duration":_sp_debuff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
					u.apply_stat_change("armor", -15); u.active_effects.append({"stat":"armor","value":-15,"duration":_sp_debuff_duration,"effect_id":"samdi_party","source_ability":"Веселье"})
			log_lines.append("  → [Веселье] Все юниты: +20 удачи, +20 уклонения, -30 точности, -15 брони на 2 хода.")
		
		# ═══ Самди: «Кукла вуду» — метка НА ЮНИТЕ (не позиционная марка): связывает цель с юнитом позади ═══
		if ability.ability_marker == "samdi_voodoo" and target.current_hp > 0:
			_scene.marks.apply_voodoo_mark(attacker, target, 2)
			log_lines.append("  → [Кукла вуду] Метка на %s: 50%% урона и дебаффы уходят юниту позади (2 хода)." % target.unit_name)

		# ═══ Шива: «Шквал кулаков» — 3 случайным противникам ═══
		if ability.ability_marker == "shiva_fist_flurry":
			var enemies = _scene._field._get_living_team_members(_scene.enemies_team if _scene._is_player_hero(attacker) else _scene.heroes_team)
			# 3 РАЗНЫХ случайных противника (если их достаточно) — без повторов, пока пул не исчерпан.
			var _ff_pool = enemies.duplicate()
			_ff_pool.shuffle()
			for _i in range(3):
				if enemies.is_empty() or _scene._outcome._check_battle_end():
					break
				if _ff_pool.is_empty():
					_ff_pool = enemies.duplicate()
					_ff_pool.shuffle()
				var t = _ff_pool.pop_back()
				if t == null or t.current_hp <= 0:
					continue
				var d = CombatCalculator.calculate_fixed_damage(attacker, t, 0.6)
				if d.is_hit:
					_scene._unit_events._deal_damage(t, d.final_damage, d.is_crit)
					log_lines.append("  → [Шквал кулаков] %s получает %d урона%s." % [t.unit_name, d.final_damage, " (крит!)" if d.is_crit else ""])
				if t.current_hp <= 0:
					log_lines.append("  → %s повержен!" % t.unit_name)
					_scene._unit_events._on_unit_killed(t, log_lines)
					var _ff_team = _scene.heroes_team if not t.is_enemy else _scene.enemies_team
					_scene._field._compact_team(_ff_team)
					enemies.erase(t)
			_scene._field._update_all_visuals()

		# ═══ Шива: «Доверься судьбе» — лечение = (30 - fate)% (fate сохранён в meta при резке урона) ═══
		if ability.ability_marker == "shiva_trust_fate":
			var _tf_pct = int(attacker.get_meta("shiva_trust_fate_pct", 0))
			attacker.remove_meta("shiva_trust_fate_pct")
			var heal_amt = int(attacker.max_hp * (30 - _tf_pct) / 100.0)
			if heal_amt > 0:
				attacker.apply_stat_change("hp", heal_amt)
				log_lines.append("  → [Доверься судьбе] %s восстанавливает %d HP (%d%%)." % [attacker.unit_name, heal_amt, 30 - _tf_pct])

		# ═══ Шива: «Аватара» — вперёд 2 + 2 случайных из 6 вариантов на 3 хода ═══
		if ability.ability_marker == "shiva_avatar":
			_scene._field._apply_shift_effect(attacker, -2, _scene._is_player_hero(attacker))
			# 6 вариантов: stat-баффы и «лечение 10% HP» как полноценный вариант
			var _av_choices = [
				{"type": "stat", "stat": "damage", "value": 10},
				{"type": "stat", "stat": "crit", "value": 10},
				{"type": "stat", "stat": "evasion", "value": 10},
				{"type": "stat", "stat": "accuracy", "value": 10},
				{"type": "stat", "stat": "armor", "value": 10},
				{"type": "heal", "value": 10}
			]
			_av_choices.shuffle()
			for j in range(mini(2, _av_choices.size())):
				var c = _av_choices[j]
				if c["type"] == "stat":
					var _av_duration = _compute_effect_duration(attacker, attacker, 3, false)
					attacker.apply_stat_change(c["stat"], c["value"])
					attacker.active_effects.append({"stat": c["stat"], "value": c["value"], "duration": _av_duration, "effect_id": "shiva_avatar", "source_ability": "Аватара"})
				else:
					var _av_heal = int(attacker.max_hp * c["value"] / 100.0)
					if _av_heal > 0:
						attacker.apply_stat_change("hp", _av_heal)
						log_lines.append("  → [Аватара] Восстановление %d%% HP (%d)." % [c["value"], _av_heal])
			log_lines.append("  → [Аватара] %s: вперёд 2, 2 случайных эффекта на 3 хода." % attacker.unit_name)
			_scene.marks.check_on_move(attacker)
			_scene._field._update_all_visuals()

		# ═══ Чернобог: «Я и есть боль» — -7% HP себе, +1 цель, 0.2 DoT 3 хода ═══
		if ability.ability_marker == "chernobog_i_am_pain":
			var self_dmg = int(attacker.max_hp * 0.07)
			attacker.take_damage(self_dmg)
			var dot = int(attacker.damage * 0.2)
			var _iap_duration = _compute_effect_duration(attacker, target, 3, true)
			if dot > 0 and target.current_hp > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": dot, "duration": _iap_duration, "source_ability": "Я и есть боль"})
			# Доп. цель — ровно 1 (не вся команда).
			var extra_candidates = []
			for et_c in _scene._targeting._get_all_targets(ability, attacker):
				if et_c != null and et_c != target and et_c.current_hp > 0:
					extra_candidates.append(et_c)
			if extra_candidates.size() > 0:
				var et = extra_candidates[randi() % extra_candidates.size()]
				et.active_effects.append({"stat": "periodic_damage", "value": dot, "duration": _iap_duration, "source_ability": "Я и есть боль"})
				log_lines.append("  → [Я и есть боль] %s тоже получает периодический урон (%d) на %d хода." % [et.unit_name, dot, _iap_duration])
			log_lines.append("  → [Я и есть боль] %s теряет %d HP (7%%). %s получает DoT (%d) на %d хода." % [attacker.unit_name, self_dmg, target.unit_name, dot, _iap_duration])

		# ═══ Чернобог: «Торжество зла» — стирает величие других богов и бьёт врагов от стёртого величия ═══
		if ability.ability_marker == "chernobog_triumph_evil" and target == targets[0]:
			var total_lost: int = 0
			var allied_team: Array = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			var opposing_team: Array = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			for u in allied_team:
				if u != null and u != attacker and u.current_majesty > 0:
					var lost: int = u.current_majesty
					u.current_majesty = 0
					total_lost += lost
			var triumph_damage: int = int(attacker.damage * float(total_lost) / 100.0)
			log_lines.append("  → [Торжество зла] Другие боги потеряли %d величия. Урон по противникам: %d." % [total_lost, triumph_damage])
			if triumph_damage > 0:
				for enemy in opposing_team:
					if enemy != null and enemy.current_hp > 0:
						var hp_before_triumph: int = enemy.current_hp
						enemy.take_damage(triumph_damage)
						var dealt_triumph: int = maxi(0, hp_before_triumph - enemy.current_hp)
						total_damage_dealt += dealt_triumph
						log_lines.append("  → [Торжество зла] %s получает %d урона. HP: %d → %d" % [enemy.unit_name, dealt_triumph, hp_before_triumph, enemy.current_hp])
						if enemy.current_hp <= 0:
							log_lines.append("  → %s повержен!" % enemy.unit_name)
							enemy.killed_by = attacker
							_scene._unit_events._on_unit_killed(enemy, log_lines)
				var compact_team: Array = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
				_scene._field._compact_team(compact_team)
				_scene._passives._apply_kappa_auras()
				if _scene._outcome._check_battle_end():
					for line in log_lines:
						_scene._log_combat(line)
					return
		# ═══ Дану: «Торжество жизни» — полное лечение цели + баффы ═══
		if ability.ability_marker == "duna_life_celebration" and target.current_hp > 0:
			if attacker.special_effect_type == "duna_heal_damage":
				_scene._duna_turn_heal += maxi(0, target.max_hp - target.current_hp)
			target.current_hp = target.max_hp
			target.apply_stat_change("damage", 10)
			target.active_effects.append({"stat":"damage","value":10,"duration":-1,"effect_id":"duna_life","source_ability":"Торжество жизни"})
			target.apply_stat_change("crit", 10)
			target.active_effects.append({"stat":"crit","value":10,"duration":-1,"effect_id":"duna_life","source_ability":"Торжество жизни"})
			target.apply_stat_change("armor", 10)
			target.active_effects.append({"stat":"armor","value":10,"duration":-1,"effect_id":"duna_life","source_ability":"Торжество жизни"})
			log_lines.append("  → [Торжество жизни] %s: полное HP, +10 урона/удачи/брони навсегда." % target.unit_name)
			_scene._field._update_all_visuals()

		# ═══ Дану: «Поглощение жизни» — лечение 50% от нанесённого урона ═══
		if ability.ability_marker == "duna_life_steal" and target.current_hp > 0:
			var heal = int(total_damage_dealt * 0.5)
			if heal > 0:
				var _ls_before = attacker.current_hp
				attacker.apply_stat_change("hp", heal)
				if attacker.special_effect_type == "duna_heal_damage":
					_scene._duna_turn_heal += maxi(0, attacker.current_hp - _ls_before)
				log_lines.append("  → [Поглощение жизни] %s восстанавливает %d HP (50%% от урона)." % [attacker.unit_name, heal])
				_scene._field._update_all_visuals()

		# ═══ Один: «Последняя битва» — снять все баффы с союзников и противников; за каждый бафф +7 урона до конца боя ═══
		if ability.ability_marker == "odin_last_battle" and target == targets[0]:
			for u in _scene.heroes_team + _scene.enemies_team:
				if u != null and u.current_hp > 0:
					var buff_count = 0
					for eff in u.active_effects:
						var eff_stat = eff.get("stat", "")
						var eff_val = eff.get("value", 0)
						if eff_val > 0 and eff_stat != "stun" and eff_stat != "periodic_damage":
							buff_count += 1
					_scene.effects._dispel_effects(u, "buff")
					if buff_count > 0 and u.is_enemy == false:
						u.damage_modifier_flat += buff_count * 7
						u.active_effects.append({"stat": "damage", "value": buff_count * 7, "duration": -1, "effect_id": "odin_last_battle", "source_ability": "Последняя битва"})
						log_lines.append("  → [Последняя битва] %s: снято %d баффов, +%d урона." % [u.unit_name, buff_count, buff_count * 7])
			log_lines.append("  → [Последняя битва] Все баффы сняты со всех юнитов.")
			_scene._field._update_all_visuals()

		# ═══ Один: «Отец богов» — текущий союзник +1 инициативы и +10 брони на 2 хода (цикл по All_Allies) ═══
		if ability.ability_marker == "odin_father_of_gods" and target.current_hp > 0:
			var _fog_duration = _compute_effect_duration(attacker, target, 2, false)
			_scene.effects._apply_buff_to_unit(target, "initiative", 1, _fog_duration, "odin_father_of_gods", "Отец богов", log_lines)
			_scene.effects._apply_buff_to_unit(target, "armor", 10, _fog_duration, "odin_father_of_gods", "Отец богов", log_lines)
			if target == targets[0]:
				log_lines.append("  → [Отец богов] Все союзники получают +1 инициативы и +10 брони на %d ход(ов)." % _fog_duration)

		# ═══ Один: «Король Асгарда» — продлить свои баффы урона на 1 ход (бонус +5 урона — через self_buff_damage) ═══
		if ability.ability_marker == "odin_king_of_asgard" and target == targets[0]:
			var _koa_ext = 0
			for _koa_e in attacker.active_effects:
				# Исключаем бафф +5 урона, только что наложенный этим же применением способности —
				# иначе он продлевает сам себя (1 ход → 2 хода) вместо продления УЖЕ существовавших баффов.
				if Combatant._effect_get(_koa_e, "effect_id", "") == "self_buff_damage":
					continue
				if Combatant._effect_get(_koa_e, "stat", "") == "damage" and Combatant._effect_get(_koa_e, "value", 0) > 0 and Combatant._effect_get(_koa_e, "duration", 0) > 0:
					_koa_e["duration"] = Combatant._effect_get(_koa_e, "duration", 0) + 1
					_koa_ext += 1
			if _koa_ext > 0:
				log_lines.append("  → [Король Асгарда] %s: продлено %d бафф(ов) урона на 1 ход." % [attacker.unit_name, _koa_ext])

		# ═══ Дану: «Растительный яд» — союзник наносит доп. DoT 20% на 4 хода (3 хода эффект) ═══
		if ability.ability_marker == "duna_plant_poison" and target.current_hp > 0:
			target.set_meta("plant_poison_attacker_dmg", attacker.damage)
			target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 3, "effect_id": "plant_poison_buff", "source_ability": "Растительный яд"})
			log_lines.append("  → [Растительный яд] %s теперь накладывает периодический урон при атаке (3 хода)." % target.unit_name)

		# ═══ Дану: «Защита из корней» — союзник +20% брони, атакующие получают 40% урона (3 хода) ═══
		if ability.ability_marker == "duna_root_protection" and target.current_hp > 0:
			var _rp_bonus = int(target.base_armor * 0.2)
			var _rp_cast_duration = _compute_effect_duration(attacker, target, 3, false)
			target.armor_modifier += _rp_bonus
			target.active_effects.append({"stat": "armor", "value": _rp_bonus, "duration": _rp_cast_duration, "effect_id": "root_protection", "source_ability": "Защита из корней"})
			target.active_effects.append({"stat": "trigger_marker", "value": 40, "duration": _rp_cast_duration, "effect_id": "root_thorns", "source_ability": "Защита из корней"})
			log_lines.append("  → [Защита из корней] %s: +%d брони, шипы 40%% (%d хода)." % [target.unit_name, _rp_bonus, _rp_cast_duration])
			_scene._field._update_all_visuals()
		
		# ═══ Угорь: «Оплетание» — сбивает стойку; если стойки не было — оглушает ═══
		if ability.ability_marker == "eel_entangle" and target.current_hp > 0:
			if target.active_stance != null:
				target.break_stance()
				log_lines.append("  → [Оплетание] Стойка %s сбита." % target.unit_name)
			else:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Оплетание"})
				target.check_stance_interruption("stun")
				log_lines.append("  → [Оплетание] %s оглушён (стойки не было)." % target.unit_name)
		
		# ═══ Замок — Рыцарь: «Изгнать зло» — снять все баффы; если >2 уникальных → стан ═══
		if ability.ability_marker == "knight_banish_evil" and target.current_hp > 0:
			var _be_buffs = _scene._count_buffs_on_unit(target)
			_scene.effects._dispel_effects(target, "buff")
			log_lines.append("  → [Изгнать зло] Снято %d бафф(ов) с %s." % [_be_buffs, target.unit_name])
			if _be_buffs > 2 and not target.is_stunned:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Изгнать зло"})
				target.check_stance_interruption("stun")
				_scene._passives._notify_stun_applied(target)
				log_lines.append("  → [Изгнать зло] Более 2 баффов снято — %s оглушён!" % target.unit_name)

		# ═══ Замок — Шут: «Ядовитый кинжал» — периодический урон 20% на 5 ходов ═══
		if ability.ability_marker == "jester_poison_dagger" and target.current_hp > 0:
			var _pd_dmg = int(attacker.damage * 0.2)
			if _pd_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _pd_dmg, "duration": 5, "source_ability": "Ядовитый кинжал"})
				log_lines.append("  → [Ядовитый кинжал] %s получает периодический урон (%d) на 5 ходов." % [target.unit_name, _pd_dmg])

		# ═══ Замок — Волшебник: «Кольцо холода» — 50% шанс оглушения ═══
		if ability.ability_marker == "wizard_cold_ring" and target.current_hp > 0:
			if randf() < 0.50 and not target.is_stunned:
				target.is_stunned = true
				target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "Кольцо холода"})
				target.check_stance_interruption("stun")
				_scene._passives._notify_stun_applied(target)
				log_lines.append("  → [Кольцо холода] %s оглушён! (50%% шанс)." % target.unit_name)

		# ═══ Замок — Инквизитор: «Аутодафе» — периодический урон + марка на 2 раунда ═══
		if ability.ability_marker == "inquisitor_auto_da_fe" and target.current_hp > 0:
			var _af_dmg = int(attacker.damage * 0.4)
			if _af_dmg > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _af_dmg, "duration": 3, "source_ability": "Аутодафе"})
				log_lines.append("  → [Аутодафе] %s получает периодический урон (%d) на 3 хода." % [target.unit_name, _af_dmg])
			# Позиционная марка (persistent, 2 раунда): повторно накладывает DoT
			_scene.marks.add_position_mark({
				"caster": attacker, "team": "ally", "position": target.position_index,
				"type": "persistent", "rounds_left": 2,
				"damage_percent": 0.0, "damage_type": "Pure",
				"effect_type": "inquisitor_auto_da_fe_dot", "effect_value": _af_dmg, "effect_duration": 3,
				"icon": ability.mark_icon,
				"triggered_units_this_round": []
			})
			log_lines.append("  → [Аутодафе] Марка на позиции %d на 2 раунда." % (target.position_index + 1))

		# ═══ Замок — Инквизитор: «Исповедь» — снять дебаффы, +5% HP за каждый ═══
		if ability.ability_marker == "inquisitor_confession" and target.current_hp > 0:
			var _cf_debuffs = _scene._count_debuffs_on_unit(target)
			_scene.effects._dispel_effects(target, "debuff")
			if _cf_debuffs > 0:
				var _cf_heal = int(target.max_hp * 0.05 * _cf_debuffs)
				var _cf_hp_b = target.current_hp
				target.apply_stat_change("hp", _cf_heal)
				log_lines.append("  → [Исповедь] Снято %d дебафф(ов), восстановлено %d HP (%d → %d)." % [_cf_debuffs, _cf_heal, _cf_hp_b, target.current_hp])
			else:
				log_lines.append("  → [Исповедь] У %s нет дебаффов." % target.unit_name)

		# ═══ Замок — Инквизитор: «Священная кара» — +0.5 урона за погибшего союзника ═══
		if ability.ability_marker == "inquisitor_holy_judgment" and target.current_hp > 0:
			var _dead_allies = 0
			var _hj_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			for _hj_unit in _hj_team:
				if _hj_unit and _hj_unit.current_hp <= 0:
					_dead_allies += 1
			if _dead_allies > 0:
				var _hj_bonus = int(attacker.damage * 0.5 * _dead_allies)
				var _hj_hp_b = target.current_hp
				target.take_damage(_hj_bonus)
				log_lines.append("  → [Священная кара] +%d урона за %d погибших союзников. HP: %d → %d" % [_hj_bonus, _dead_allies, _hj_hp_b, target.current_hp])
				if target.current_hp <= 0:
					log_lines.append("  → %s повержен!" % target.unit_name)
					target.killed_by = attacker
					_scene._unit_events._on_unit_killed(target, log_lines)
					var _hj_team2 = _scene.heroes_team if not target.is_enemy else _scene.enemies_team
					_scene._field._compact_team(_hj_team2)

		# ═══ Тритон: «Морская кавалерия» — маркерный эффект для ИИ (+20 броня/+20 урон уже через effect_types) ═══
		if ability.ability_marker == "triton_cavalry":
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 3, "effect_id": "triton_cavalry", "source_ability": "Морская кавалерия"})
			log_lines.append("  → [Морская кавалерия] %s: +20 брони и +20 атаки на 3 хода." % attacker.unit_name)
			
			# ═══ Птица: «Острые крылья» — -5% брони цели на 4 хода ═══
			if ability.ability_marker == "bird_armor_shred" and target.current_hp > 0:
				var _shred = maxi(1, int(target.armor * 0.05))
				target.apply_stat_change("armor", -_shred)
				target.active_effects.append({"stat": "armor", "value": -_shred, "duration": 4, "effect_id": "bird_armor_shred", "source_ability": "Острые крылья"})
				log_lines.append("  → [Острые крылья] %s: -%d брони (5%%) на 4 хода." % [target.unit_name, _shred])
			
			# ═══ Птица: «Метать перья» — марка на позиции цели (0,7 урона, 2 хода) ═══
			if ability.ability_marker == "bird_feather_mark" and target.current_hp > 0:
				_scene.marks.add_position_mark({
					"caster": attacker, "team": "ally", "position": target.position_index,
					"type": "persistent", "rounds_left": 2,
					"damage_percent": 70.0, "damage_type": "Physical",
					"effect_type": "", "effect_value": 0, "effect_duration": 0,
					"icon": ability.mark_icon,
					"triggered_units_this_round": []
				})
				log_lines.append("  → [Метать перья] Марка на позиции %d (0,7 урона) на 2 хода." % (target.position_index + 1))
			
			# ═══ Купидон: «Я такой милый» — метка невинности (50% перенаправление) ═══
			if ability.ability_marker == "cupid_innocence" and target.current_hp > 0:
				target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": -1, "effect_id": "cupid_innocence", "source_ability": "Я такой милый"})
				log_lines.append("  → [Я такой милый] %s получает метку невинности (50%% перенаправление)." % target.unit_name)
			
			# ═══ Пегас: «Кара с небес» — +10 точности и +10 удачи навсегда ═══
			if ability.ability_marker == "pegasus_judgment":
				attacker.apply_stat_change("accuracy", 10)
				attacker.apply_stat_change("crit", 10)
				attacker.active_effects.append({"stat": "accuracy", "value": 10, "duration": -1, "effect_id": "pegasus_judgment_acc", "source_ability": "Кара с небес"})
				attacker.active_effects.append({"stat": "crit", "value": 10, "duration": -1, "effect_id": "pegasus_judgment_crit", "source_ability": "Кара с небес"})
				log_lines.append("  → [Кара с небес] %s: +10 точности и +10 удачи навсегда." % attacker.unit_name)
			
			# ═══ Грифон: «Пикировать» — марка на позиции цели (200% урона) ═══
			if ability.ability_marker == "griffin_dive" and target.current_hp > 0:
				_scene.marks.add_position_mark({
					"caster": attacker, "team": "ally", "position": target.position_index,
					"type": "once", "rounds_left": 2,
					"damage_percent": 200.0, "damage_type": "Physical",
					"effect_type": "", "effect_value": 0, "effect_duration": 0,
					"icon": ability.mark_icon,
					"triggered_units_this_round": []
				})
				log_lines.append("  → [Пикировать] Марка на позиции %d (200%% урона)." % (target.position_index + 1))
			
			# ═══ Грифон: «Небесное копье» — бонус урон за уклонение ═══
			if ability.ability_marker == "griffin_sky_spear" and target.current_hp > 0:
				var _ss_evasion = attacker.evasion
				var _ss_bonus = int(attacker.damage * _ss_evasion / 100.0)
				if _ss_bonus > 0:
					var _ss_hp_b = target.current_hp
					target.take_damage(_ss_bonus)
					log_lines.append("  → [Небесное копье] +%d урона (%d%% от уклонения). HP: %d → %d" % [_ss_bonus, _ss_evasion, _ss_hp_b, target.current_hp])
			
			# ═══ Пост-уроновые self-эффекты (зависят от нанесённого урона) ═══
		for effect in ability.effect_types:
			if effect == "self_damage_dealt_percent" and total_damage_dealt > 0:
				var pct = ability.effect_values.get("self_damage_dealt_percent", 0)
				var self_dmg = int(total_damage_dealt * pct / 100.0)
				if self_dmg > 0:
					attacker.take_damage(self_dmg)
					log_lines.append("  → %s получает %d ответного урона (%d%% от нанесённого)." % [attacker.unit_name, self_dmg, pct])
		
		if (not attacker.is_enemy or attacker.is_nemesis or attacker.uses_majesty) and ability.majesty_gain > 0 and not attacker.has_meta("cerberus_three_active"):
			if not _scene._passives._redirect_majesty_to_set_true_king(attacker, ability.majesty_gain, log_lines):
				attacker.modify_majesty(ability.majesty_gain)
				log_lines.append("  → %s получает %d величия." % [attacker.unit_name, ability.majesty_gain])
				# Щупальце кракена: всё полученное величие получает и Кракен.
				if attacker.special_effect_type == "kraken_tentacle":
					for _kr in _scene.enemies_team:
						if _kr != null and _kr.current_hp > 0 and _kr.special_effect_type == "kraken_stats_per_ally":
							_kr.modify_majesty(ability.majesty_gain)
							log_lines.append("  → [Щупальце] %s тоже получает %d величия." % [_kr.unit_name, ability.majesty_gain])
							break
		# Кракен: «Облако чернил» — без живых щупалец дополнительно +30 величия.
		if ability.ability_marker == "kraken_ink_cloud" and not _kraken_ink_bonus_given and attacker.special_effect_type == "kraken_stats_per_ally" and attacker.current_hp > 0 and _scene._passives._living_tentacles(attacker).is_empty():
			_kraken_ink_bonus_given = true
			attacker.modify_majesty(30)
			log_lines.append("  → [Облако чернил] Нет живых щупалец: %s получает ещё 30 величия." % attacker.unit_name)
		
		# ═══ Туннели — Дварф-кузнец: «Улучшить снаряжение» — жетоны ковки удваивают эффект ═══
		if ability.ability_marker == "dwarf_smith_upgrade":
			var _ds_tokens = attacker.get_meta("smith_forge_tokens", 0)
			if _ds_tokens > 0:
				var _ds_extra = 5 * (int(pow(2, _ds_tokens)) - 1)
				target.apply_stat_change("armor", _ds_extra)
				target.apply_stat_change("damage", _ds_extra)
				target.active_effects.append({"stat": "armor", "value": _ds_extra, "duration": 2, "effect_id": "dwarf_smith_upgrade", "source_ability": "Улучшить снаряжение"})
				target.active_effects.append({"stat": "damage", "value": _ds_extra, "duration": 2, "effect_id": "dwarf_smith_upgrade", "source_ability": "Улучшить снаряжение"})
				log_lines.append("  → [Улучшить снаряжение] +%d брони, +%d урона (жетоны: %d)." % [_ds_extra, _ds_extra, _ds_tokens])
			# Пассивка кузнеца: +5 брони при баффе союзника
			attacker.apply_stat_change("armor", 5)
			attacker.active_effects.append({"stat": "armor", "value": 5, "duration": 2, "effect_id": "dwarf_smith_passive", "source_ability": "Пассивка"})
			log_lines.append("  → [Кузнец] %s: +5 брони за бафф союзника." % attacker.unit_name)
		
		# ═══ Туннели — Голем: «Вперёд» — пассивка роста сработает дважды ═══
		if ability.ability_marker == "golem_forward":
			attacker.set_meta("golem_double_passive", true)
			log_lines.append("  → [Вперёд] %s: рост пассивки удвоен в этом ходу." % attacker.unit_name)
		
		# ═══ Туннели — Шаман: «Каменная стена» — призыв Валуна ═══
		if ability.ability_marker == "shaman_stone_wall":
			attacker.set_meta("shaman_used_stone_wall", true)
			_scene._passives._summon_boulder(attacker, log_lines)
		
		# ═══════════════════════════════════════════════════════
		# ЗВЁЗДЫ — юниты зодиака (маркеры способностей)
		# ═══════════════════════════════════════════════════════

		# Скорпион: «Ядовитое жало» — периодический урон 0,4 на 3 хода
		if ability.ability_marker == "scorpio_poison_sting" and target.current_hp > 0:
			var _sps_dmg = int(attacker.damage * 0.4)
			if _sps_dmg > 0:
				var _sps_duration = _compute_effect_duration(attacker, target, 3, true)
				target.active_effects.append({"stat": "periodic_damage", "value": _sps_dmg, "duration": _sps_duration, "source_ability": "Ядовитое жало"})
				log_lines.append("  → [Ядовитое жало] %s получает периодический урон (%d) на %d хода." % [target.unit_name, _sps_dmg, _sps_duration])

		# Весы: «Дизбаланс» — доп. чистый урон за каждый 1% недостающего HP Весов
		if ability.ability_marker == "libra_imbalance" and target.current_hp > 0:
			var _lib_miss = float(attacker.max_hp - attacker.current_hp) / float(maxi(1, attacker.max_hp))
			var _lib_bonus = int(attacker.damage * _lib_miss)
			if _lib_bonus > 0:
				var _lib_hp_b = target.current_hp
				target.take_damage(_lib_bonus)
				log_lines.append("  → [Дизбаланс] +%d чистого урона (%d%% недостающего HP). HP: %d → %d" % [_lib_bonus, int(_lib_miss * 100), _lib_hp_b, target.current_hp])

		# ── Запускаемые один раз за применение способности ──
		var _stars_run_once = targets.is_empty() or target == targets[0]

		if _stars_run_once and _scene._passives._should_trigger_thor_hammer_of_lightning(attacker, ability):
			_scene._passives._trigger_thor_hammer_of_lightning(attacker, log_lines)

		# Скорпион: «Жестокость» — ВСЕМ юнитам +10 атаки и -10 брони на 1 ход
		if ability.ability_marker == "scorpio_cruelty" and _stars_run_once:
			for _cr_u in (_scene.enemies_team + _scene.heroes_team):
				if _cr_u == null or _cr_u.current_hp <= 0:
					continue
				var _cr_buff_duration = _compute_effect_duration(attacker, _cr_u, 1, false)
				var _cr_debuff_duration = _compute_effect_duration(attacker, _cr_u, 1, true)
				_scene.effects._apply_buff_to_unit(_cr_u, "damage", 10, _cr_buff_duration, "scorpio_cruelty", "Жестокость")
				_cr_u.apply_stat_change("armor", -10)
				_cr_u.active_effects.append({"stat": "armor", "value": -10, "duration": _cr_debuff_duration, "effect_id": "scorpio_cruelty", "source_ability": "Жестокость"})
			log_lines.append("  → [Жестокость] Все юниты: +10 урона, -10 брони (1 ход).")

		# Дева: «Звездопад» — все юниты +10 крита на 2 хода
		if ability.ability_marker == "virgo_starfall" and _stars_run_once:
			for _sf_u in (_scene.enemies_team + _scene.heroes_team):
				if _sf_u == null or _sf_u.current_hp <= 0:
					continue
				var _sf_duration = _compute_effect_duration(attacker, _sf_u, 2, false)
				_scene.effects._apply_buff_to_unit(_sf_u, "crit", 10, _sf_duration, "virgo_starfall", "Звездопад")
			log_lines.append("  → [Звездопад] Все юниты: +10 крита (2 хода).")

		# Дева: «Невинное касание» — теряет все свои баффы, +10 урона за каждый снятый эффект
		if ability.ability_marker == "virgo_innocent_touch" and _stars_run_once:
			var _it_count = _scene._count_buffs_on_unit(attacker)
			_scene.effects._dispel_effects(attacker, "buff")
			var _it_bonus = _it_count * 10
			if _it_bonus > 0:
				var _it_duration = _compute_effect_duration(attacker, attacker, 1, false)
				_scene.effects._apply_buff_to_unit(attacker, "damage", _it_bonus, _it_duration, "virgo_innocent_touch", "Невинное касание")
			log_lines.append("  → [Невинное касание] %s теряет %d бафф(ов), +%d урона." % [attacker.unit_name, _it_count, _it_bonus])

		# Дева: «Как повелели звёзды» — союзники получают эффект своей клетки как бафф на 2 хода
		if ability.ability_marker == "virgo_stars_decree" and _stars_run_once:
			var _asd_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
			for _asd_i in range(_asd_team.size()):
				var _asd_u = _asd_team[_asd_i]
				if _asd_u == null or _asd_u.current_hp <= 0:
					continue
				_scene.locations._apply_star_cell_buff(_asd_u, _asd_i, 2)
			log_lines.append("  → [Как повелели звёзды] Союзники получают эффект своих клеток (2 хода).")

		# Близнецы: «Разделиться» — лечит 50% макс. HP, -50% урона до конца боя
		if ability.ability_marker == "gemini_split" and _stars_run_once:
			var _sp_heal = int(attacker.max_hp * 0.5)
			var _sp_hp_b = attacker.current_hp
			attacker.apply_stat_change("hp", _sp_heal)
			var _sp_dmg_down = maxi(1, int(attacker.base_damage * 0.5))
			attacker.damage_modifier_flat -= _sp_dmg_down
			attacker.active_effects.append({"stat": "damage", "value": -_sp_dmg_down, "duration": -1, "effect_id": "gemini_split", "source_ability": "Разделиться"})
			log_lines.append("  → [Разделиться] %s восстанавливает %d HP (%d → %d), -%d урона до конца боя." % [attacker.unit_name, _sp_heal, _sp_hp_b, attacker.current_hp, _sp_dmg_down])

		# ═══════════════════════════════════════════════════════
		# САД — маркеры способностей юнитов сада
		# ═══════════════════════════════════════════════════════

		# Цветочная фея: «Неудержимое цветение» — всем врагам регенерация 5% и периодический урон
		if ability.ability_marker == "flower_unstoppable_bloom":
			var _fb_foe_team = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			var _fb_pdmg = int(attacker.damage * 0.15)
			for _fb_f in _fb_foe_team:
				if _fb_f and _fb_f.current_hp > 0:
					_fb_f.active_effects.append({"stat": "regeneration", "value": 5, "duration": 2, "effect_id": "flower_unstoppable_bloom", "source_ability": "Неудержимое цветение"})
					if _fb_pdmg > 0:
						_fb_f.active_effects.append({"stat": "periodic_damage", "value": _fb_pdmg, "duration": 2, "source_ability": "Неудержимое цветение"})
			log_lines.append("  → [Неудержимое цветение] Все противники: регенерация 5%% + периодический урон (%d) на 2 хода." % _fb_pdmg)

		# Фея шипов: «Чесоточный порошок» — периодический урон
		if ability.ability_marker == "thorn_itching_powder" and target and target.current_hp > 0:
			var _ip_pdmg = maxi(1, int(attacker.damage * 0.2))
			target.active_effects.append({"stat": "periodic_damage", "value": _ip_pdmg, "duration": 3, "source_ability": "Чесоточный порошок"})
			log_lines.append("  → [Чесоточный порошок] %s получает периодический урон (%d) на 3 хода." % [target.unit_name, _ip_pdmg])

		# Фея шипов: «Колючий куст» — марка на союзника (отражение 30% урона феи)
		if ability.ability_marker == "thorn_bush" and target and target.current_hp > 0:
			target.active_effects.append({"stat": "thorn_bush_mark", "value": 1, "duration": 3, "effect_id": "thorn_bush_mark", "source_ability": "Колючий куст", "owner": attacker})
			log_lines.append("  → [Колючий куст] %s под защитой: атаковавший получит 30%% урона феи шипов (3 хода)." % target.unit_name)

		# Альрауне: «Высасывание жизни» — лечение 30% от урона
		if ability.ability_marker == "alraune_life_drain" and target and target.current_hp >= 0:
			var _ld_heal = int(attacker.damage * ability.damage_modifier * 0.3)
			if _ld_heal > 0:
				var _ld_hp_b = attacker.current_hp
				attacker.apply_stat_change("hp", _ld_heal)
				log_lines.append("  → [Высасывание жизни] %s восстанавливает %d HP (%d → %d)." % [attacker.unit_name, _ld_heal, _ld_hp_b, attacker.current_hp])

		# Друид: «Стимулировать рост» — союзник +4 урона навсегда
		if ability.ability_marker == "druid_stimulate_growth" and target and target.current_hp > 0:
			_scene.effects._apply_buff_to_unit(target, "damage", 4, -1, "druid_stimulate_growth", "Стимулировать рост")
			log_lines.append("  → [Стимулировать рост] %s: +4 урона до конца боя." % target.unit_name)

		# Друид: «Гнев природы» — +1 к длительности всех дебаффов цели
		if ability.ability_marker == "druid_natures_wrath" and target and target.current_hp > 0:
			var _nw_cnt = 0
			for _nw_e in target.active_effects:
				var _nw_v = Combatant._effect_get(_nw_e, "value", 0)
				var _nw_d = Combatant._effect_get(_nw_e, "duration", -1)
				if _nw_v < 0 and _nw_d > 0 and Combatant._effect_get(_nw_e, "stat", "") != "stun":
					_nw_e["duration"] = _nw_d + 1
					_nw_cnt += 1
			log_lines.append("  → [Гнев природы] %s: длительность %d дебафф(ов) +1." % [target.unit_name, _nw_cnt])

		# Единорог: «Очищающий рог» — +15% урона за каждый дебафф (доп. чистый урон)
		if ability.ability_marker == "unicorn_cleansing_horn" and target and target.current_hp > 0:
			var _ch_debuffs = target._count_active_debuffs()
			if _ch_debuffs > 0:
				var _ch_bonus = int(attacker.damage * 0.15 * _ch_debuffs)
				if _ch_bonus > 0:
					var _ch_hp_b = target.current_hp
					target.take_damage(_ch_bonus)
					log_lines.append("  → [Очищающий рог] +%d чистого урона за %d дебафф(ов). HP: %d → %d" % [_ch_bonus, _ch_debuffs, _ch_hp_b, target.current_hp])
	
		# Единорог: «Кровь единорога» — потерять 10% HP, полностью вылечить союзника
		if ability.ability_marker == "unicorn_blood" and target and target.current_hp > 0:
			var _ub_cost = int(attacker.max_hp * 0.10)
			attacker.take_damage(_ub_cost)
			var _ub_hp_b = target.current_hp
			target.apply_stat_change("hp", target.max_hp)
			log_lines.append("  → [Кровь единорога] %s теряет %d HP, %s восстанавливает полное HP (%d → %d)." % [attacker.unit_name, _ub_cost, target.unit_name, _ub_hp_b, target.current_hp])

		# ═══ Яматано Орочи: «Нескончаемый рост» — общий пул щитов смерти +1 (максимум 8) ═══
		if ability.ability_marker == "orochi_endless_growth" and target == attacker and attacker.current_hp > 0:
			var _eg_before: int = _scene._orochi_death_shields
			_scene._passives._set_orochi_shields(_scene._orochi_death_shields + 1)
			log_lines.append("  → [Нескончаемый рост] Щитов смерти: %d → %d (максимум %d)." % [_eg_before, _scene._orochi_death_shields, BattleScene.OROCHI_MAX_SHIELDS])

		# ═══ Кракен: «Ярость океана» — за каждое живое щупальце случайный противник получает 150% урона;
		# если все щупальца мертвы — 150% урона получает сам Кракен ═══
		if ability.ability_marker == "kraken_ocean_fury" and target == attacker and attacker.current_hp > 0:
			var _of_tentacles: Array = _scene._passives._living_tentacles(attacker)
			var _of_raw: int = int(attacker.damage * 1.5)
			if _of_tentacles.is_empty():
				var _of_self_hp_b: int = attacker.current_hp
				attacker.take_damage(_of_raw)
				log_lines.append("  → [Ярость океана] Щупалец не осталось — %s получает %d урона (150%%). HP: %d → %d" % [attacker.unit_name, _of_raw, _of_self_hp_b, attacker.current_hp])
			else:
				var _of_foes: Array = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
				for _of_t in _of_tentacles:
					var _of_alive: Array = []
					for _of_f in _of_foes:
						if _of_f != null and _of_f.current_hp > 0 and not _of_alive.has(_of_f):
							_of_alive.append(_of_f)
					if _of_alive.is_empty():
						break
					var _of_victim: Combatant = _of_alive.pick_random()
					var _of_dmg: int = CombatCalculator.apply_armor(_of_raw, _of_victim.armor)
					var _of_hp_b: int = _of_victim.current_hp
					_of_victim.take_damage(_of_dmg)
					log_lines.append("  → [Ярость океана] %s бьёт %s на %d урона (150%%). HP: %d → %d" % [_of_t.unit_name, _of_victim.unit_name, _of_dmg, _of_hp_b, _of_victim.current_hp])
					if _of_victim.current_hp <= 0:
						_scene._unit_events._on_unit_killed(_of_victim, log_lines)
				_scene._field._compact_team(_of_foes)

		# ═══ Цербер: «Трехголовый» — в СЛЕДУЮЩИЙ свой раунд совершает действия трижды ═══
		# Число ходов переключается в _start_new_round(); пока активно, величие за способности не начисляется.
		if ability.ability_marker == "cerberus_three_headed" and target == attacker and attacker.current_hp > 0:
			attacker.set_meta("cerberus_three_pending", true)
			_scene.effects._remove_effect_id(attacker, "cerberus_three_headed")
			attacker.active_effects.append({"stat": "trigger_marker", "value": 3, "duration": -1, "effect_id": "cerberus_three_headed", "source_ability": ability.name})
			log_lines.append("  → [Трехголовый] %s в следующем раунде совершит три действия." % attacker.unit_name)

		# ═══ Бальдр: «Стрела в моём теле» — 100% чистого урона себе, снимает свои дебаффы,
		# за каждый снятый противники получают 5 урона ═══
		if ability.ability_marker == "baldr_arrow_in_my_body" and target == attacker and attacker.current_hp > 0:
			var _bal_self_dmg = int(attacker.damage)
			var _bal_hp_before = attacker.current_hp
			attacker.take_damage(_bal_self_dmg)
			log_lines.append("  → [Стрела в моём теле] %s получает %d чистого урона. HP: %d → %d" % [attacker.unit_name, _bal_self_dmg, _bal_hp_before, attacker.current_hp])
			if attacker.current_hp > 0:
				var _bal_debuff_count = _scene._count_debuffs_on_unit(attacker)
				_scene.effects._dispel_effects(attacker, "debuff")
				if _bal_debuff_count > 0:
					var _bal_dmg_each = 5 * _bal_debuff_count
					log_lines.append("  → [Стрела в моём теле] %s снимает с себя %d дебафф(ов) — противники получают по %d урона." % [attacker.unit_name, _bal_debuff_count, _bal_dmg_each])
					for _bal_h in _scene.heroes_team:
						if _bal_h and _bal_h.current_hp > 0:
							var _bal_h_hp_b = _bal_h.current_hp
							_bal_h.take_damage(_bal_dmg_each)
							log_lines.append("    %s получает %d урона. HP: %d → %d" % [_bal_h.unit_name, _bal_dmg_each, _bal_h_hp_b, _bal_h.current_hp])
							if _bal_h.current_hp <= 0:
								_scene._unit_events._on_unit_killed(_bal_h, log_lines)
					_scene._field._compact_team(_scene.heroes_team)
			else:
				_scene._unit_events._on_unit_killed(attacker, log_lines)
				_scene._field._compact_team(_scene.enemies_team)
	
			# ═══ Стойка: войти в стойку после применения способности ═══
	if ability.is_stance:
		attacker.enter_stance(ability)
		log_lines.append("  → %s входит в стойку: %s." % [attacker.unit_name, ability.name])
		# Гном кузнец: «Ковать железо» не наносит урона, поэтому единственный момент
		# для звука/вспышки удара молотом — сам вход в стойку (удар по наковальне).
		if ability.stance_effect_type == "smith_forge":
			_play_ability_attack_effects(ability, attacker)
		# Новичок: «Я только учусь» — +30 уклонения, пока активна стойка
		if ability.stance_effect_type == "novice_training":
			attacker.apply_stat_change("evasion", 30)
			attacker.active_effects.append({"stat": "evasion", "value": 30, "duration": 2, "effect_id": "novice_training", "source_ability": "Я только учусь"})
			log_lines.append("  → [Я только учусь] %s: +30 уклонения." % attacker.unit_name)
		# Гоплит: «Поднять щиты» — +20 брони, пока активна стойка
		elif ability.stance_effect_type == "hoplite_shield_wall":
			attacker.apply_stat_change("armor", 20)
			attacker.active_effects.append({"stat": "armor", "value": 20, "duration": 2, "effect_id": "hoplite_shield_armor", "source_ability": "Поднять щиты"})
			log_lines.append("  → [Поднять щиты] %s: +20 брони." % attacker.unit_name)
		# Золотая валькирия: «Воин дня» — +10 уклонения + распространение на серебряных валькирий
		elif ability.stance_effect_type == "warrior_of_day_stance":
			attacker.apply_stat_change("evasion", 10)
			attacker.active_effects.append({"stat": "evasion", "value": 10, "duration": 1, "effect_id": "warrior_of_day_stance", "source_ability": "Воин дня"})
			log_lines.append("  → [Воин дня] %s: +10 уклонения." % attacker.unit_name)
			_scene._passives._propagate_valkyrie_buff(attacker, "golden_valkyrie", "silver_valkyrie", "evasion", 10, 1, log_lines)
		# Серебрянная валькирия: «Воин ночи» — +10 уклонения + распространение на золотых валькирий
		elif ability.stance_effect_type == "warrior_of_night_stance":
			attacker.apply_stat_change("evasion", 10)
			attacker.active_effects.append({"stat": "evasion", "value": 10, "duration": 1, "effect_id": "warrior_of_night_stance", "source_ability": "Воин ночи"})
			log_lines.append("  → [Воин ночи] %s: +10 уклонения." % attacker.unit_name)
			_scene._passives._propagate_valkyrie_buff(attacker, "silver_valkyrie", "golden_valkyrie", "evasion", 10, 1, log_lines)
		# ═══ Замок — Принцесса: «В беде» — метка провокации + 20 уклонения ═══
		elif ability.stance_effect_type == "princess_in_trouble":
			attacker.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": 1, "effect_id": "provocation_mark", "source_ability": "В беде"})
			attacker.apply_stat_change("evasion", 20)
			attacker.active_effects.append({"stat": "evasion", "value": 20, "duration": 1, "effect_id": "princess_in_trouble", "source_ability": "В беде"})
			log_lines.append("  → [В беде] %s: метка провокации + 20 уклонения." % attacker.unit_name)
		# ═══ Замок — Рыцарь: «Сила превыше магии» — +15 брони + +2 к стоимости заклинаний ═══
		elif ability.stance_effect_type == "knight_magic_supremacy":
			attacker.apply_stat_change("armor", 15)
			attacker.active_effects.append({"stat": "armor", "value": 15, "duration": 1, "effect_id": "knight_magic_supremacy", "source_ability": "Сила превыше магии"})
			attacker.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": 1, "effect_id": "knight_magic_supremacy_cost", "source_ability": "Сила превыше магии"})
			log_lines.append("  → [Сила превыше магии] %s: +15 брони, +2 к стоимости заклинаний." % attacker.unit_name)
		# ═══ Замок — Стражник: «Стой кто идёт!» — все враги -20 уклонения ═══
		elif ability.stance_effect_type == "guardsman_halt":
			var _halt_foe_team = _scene.heroes_team if attacker.is_enemy else _scene.enemies_team
			for _halt_foe in _halt_foe_team:
				if _halt_foe and _halt_foe.current_hp > 0:
					_halt_foe.apply_stat_change("evasion", -20)
					_halt_foe.active_effects.append({"stat": "evasion", "value": -20, "duration": 1, "effect_id": "guardsman_halt", "source_ability": "Стой кто идёт!"})
			log_lines.append("  → [Стой кто идёт!] Все враги: -20 уклонения.")
		
		# Звёзды — Весы: «Равновесие» — стойка (реакция на урон союзника обрабатывается в блоке попадания)
		elif ability.stance_effect_type == "libra_balance":
			log_lines.append("  → [Равновесие] %s: пока союзники получают урон, враги страдают (1/4 чистым)." % attacker.unit_name)
		# Сад — Единорог: «Грациозная осанка» — +20 брони и +20 уклонения
		elif ability.stance_effect_type == "unicorn_grace":
			attacker.apply_stat_change("armor", 20)
			attacker.active_effects.append({"stat": "armor", "value": 20, "duration": -1, "effect_id": "unicorn_grace_armor", "source_ability": "Грациозная осанка"})
			attacker.apply_stat_change("evasion", 20)
			attacker.active_effects.append({"stat": "evasion", "value": 20, "duration": -1, "effect_id": "unicorn_grace_evasion", "source_ability": "Грациозная осанка"})
			log_lines.append("  → [Грациозная осанка] %s: +20 брони, +20 уклонения." % attacker.unit_name)
		# Сад — Сатир: «Чарующая песня» — все враги -5 атаки (эффект растёт в начале следующего раунда)
		elif ability.stance_effect_type == "satyr_charm":
			attacker.set_meta("satyr_charm_stacks", 0)
			log_lines.append("  → [Чарующая песня] %s: враги теряют по 5 атаки каждый раунд стойки." % attacker.unit_name)
		# Один: «Предвидеть» — все союзники +20 уклонения и +15 удачи на 1 ход (стойка, обновляется каждый ход)
		elif ability.stance_effect_type == "odin_foresight":
			_scene._passives._refresh_odin_foresight_aura(attacker)
		# Дану: «В гармонии с природой» — назад 1, союзники иммунны к дебаффам
		elif ability.stance_effect_type == "duna_harmony":
			_scene._field._apply_shift_effect(attacker, 1, _scene._is_player_hero(attacker))
			var _hteam = _scene.heroes_team if not attacker.is_enemy else _scene.enemies_team
			for ally in _hteam:
				if ally and ally.current_hp > 0:
					ally.active_effects.append({"stat":"trigger_marker","value":0,"duration":-1,"effect_id":"duna_harmony_immune","source_ability":"В гармонии с природой"})
			log_lines.append("  → [В гармонии с природой] %s: назад 1. Союзники иммунны к негативным эффектам." % attacker.unit_name)
			_scene.marks.check_on_move(attacker)
			_scene._field._update_all_visuals()
		# Шива: «Карма» — противник получает 50% урона + копирует дебаффы
		elif ability.stance_effect_type == "shiva_karma":
			log_lines.append("  → [Карма] %s: противники получают 50%% урона и копируют дебаффы." % attacker.unit_name)
		# Чернобог: «Надежды нет» — противники не могут получать баффы
		elif ability.stance_effect_type == "chernobog_no_hope":
			log_lines.append("  → [Надежды нет] %s: противники не могут получать баффы; попытка = 80%% урона." % attacker.unit_name)
		# Посейдон: «Штиль» — при движении противника 70% урона
		elif ability.stance_effect_type == "poseidon_calm":
			log_lines.append("  → [Штиль] %s: при движении противника — 70%% урона." % attacker.unit_name)
		# Шива: «Цикл разрушения» — реакция на действие + крит повтор + вперёд 2
		elif ability.stance_effect_type == "shiva_destruction_cycle":
			_scene._field._apply_shift_effect(attacker, -2, _scene._is_player_hero(attacker))
			log_lines.append("  → [Цикл разрушения] %s: вперёд 2. При действии врага — 0.7 урона. Крит — повтор." % attacker.unit_name)
			_scene.marks.check_on_move(attacker)
			_scene._field._update_all_visuals()
		# ═══ Индиго: при использовании Охоты/Разорвать — снять все стаки «Взять след» ═══
	if ability.name == "Охота" or ability.name == "Разорвать":
		_scene._passives._remove_indigo_trail_buffs(attacker, log_lines)
	
	# ═══ Марка от ИИ (Пытка попугаем, Болотное царство и т.п.): разместить марку на позиции цели ═══
	if ability.mark_type_int > 0 and ability.target_type == "Enemy" and defender:
		var mark = {
			"caster": attacker,
			"team": "enemy" if defender.is_enemy else "ally",
			"position": defender.position_index,
			"type": ability.mark_type,
			"rounds_left": ability.mark_duration if ability.mark_type == "persistent" else 1,
			"damage_percent": ability.mark_damage_percent,
			"damage_type": ability.mark_damage_type,
			"effect_type": ability.mark_effect_type,
			"effect_value": ability.mark_effect_value,
			"effect_duration": ability.mark_effect_duration,
			"icon": ability.mark_icon,
			"triggered_units_this_round": []
		}
		_scene.marks.add_position_mark(mark)
		log_lines.append("  → %s накладывает марку «%s» на позицию %d на %d ход(ов)." % [
			attacker.unit_name, ability.name, defender.position_index + 1, ability.mark_duration])
		# Персистентная марка срабатывает сразу при наложении (но не чаще раза за раунд);
		# одноразовая (once) — только в начале следующего хода заклинателя.
		if ability.mark_type == "persistent" and defender.current_hp > 0:
			_scene.marks.apply_mark_to_unit(mark, defender, true)
			mark["triggered_units_this_round"].append(defender)
	# Марки прочих типов цели (Position у ИИ, Ally, Self и др.):
	# ставятся на позицию выбранной цели, на стороне этой цели.
	elif ability.mark_type_int > 0 and ability.target_type != "Enemy" and defender:
		var _pos_mark = {
			"caster": attacker,
			"team": "enemy" if defender.is_enemy else "ally",
			"position": defender.position_index,
			"type": ability.mark_type,
			"rounds_left": ability.mark_duration if ability.mark_type == "persistent" else 1,
			"damage_percent": ability.mark_damage_percent,
			"damage_type": ability.mark_damage_type,
			"effect_type": ability.mark_effect_type,
			"effect_value": ability.mark_effect_value,
			"effect_duration": ability.mark_effect_duration,
			"icon": ability.mark_icon,
			"triggered_units_this_round": []
		}
		_scene.marks.add_position_mark(_pos_mark)
		log_lines.append("  → %s накладывает марку «%s» на позицию %d на %d ход(ов)." % [
			attacker.unit_name, ability.name, defender.position_index + 1, _pos_mark["rounds_left"]])
		if ability.mark_type == "persistent" and defender.current_hp > 0:
			_scene.marks.apply_mark_to_unit(_pos_mark, defender, true)
			_pos_mark["triggered_units_this_round"].append(defender)
				
	_scene._passives._propagate_new_voodoo_debuffs(voodoo_effect_snapshot, log_lines)
	_scene._hud._update_marks_display()
	_scene._field._update_all_visuals()
	for line in log_lines:
		_scene._log_combat(line)

## Централизованный расчёт итоговой длительности НОВОГО баффа/дебаффа с учётом пассивок,
## которые её продлевают. Единственная точка входа для этой логики — использовать её
## везде, где создаётся эффект с ограниченной длительностью, вместо копирования проверок
## по месту в каждой способности.
## base_duration <= 0 (например -1 = навсегда/до конца боя) возвращается как есть —
## такие эффекты пассивками продления не трогаются.
## is_debuff: true — «Кикимора»/«Самди» (дебаффы), false — «Один»/«Нага монах» (баффы).
func _compute_effect_duration(attacker: Combatant, target: Combatant, base_duration: int, is_debuff: bool) -> int:
	if attacker == null or target == null or base_duration <= 0:
		return base_duration
	var duration := base_duration
	if not is_debuff:
		# Один + Нага монах: неуникальные баффы союзников (по стороне ЦЕЛИ) длятся на 1 ход дольше.
		var target_team = _scene.heroes_team if not target.is_enemy else _scene.enemies_team
		if _scene.effects._has_special_on_team(target_team, "odin_buff_duration"):
			duration += 1
		if _scene.effects._has_special_on_team(target_team, "naga_monk_buff_duration"):
			duration += 1
		# Мысль и память: баффы на самого Одина длятся ещё на 1 ход дольше (сверх общей пассивки).
		if attacker == target and target.has_item_effect("odin_self_buff_extend"):
			duration += 1
	else:
		var caster_team = _scene.enemies_team if attacker.is_enemy else _scene.heroes_team
		# Кикимора: дебафф её команды НА БОГА (не на своих союзников) — +1 ход.
		if not target.is_enemy and _scene.effects._has_special_on_team(caster_team, "kikimora_extended_debuffs"):
			duration += 1
		# Самди: дебафф его команды НА ВРАГА (не на своих союзников) — 50% шанс +1 ход.
		if target.is_enemy != attacker.is_enemy and _scene.effects._has_special_on_team(caster_team, "samdi_extend_debuffs") and randf() < 0.5:
			duration += 1
		# ═══ Шляпа Самди: когда противник Самди получает дебафф, наносит ему 15% урона Самди ═══
		if target.current_hp > 0:
			var _samdi_hat_team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
			for _samdi_u in _samdi_hat_team:
				if _samdi_u and _samdi_u.current_hp > 0 and _samdi_u.is_enemy != target.is_enemy and _samdi_u.has_item_effect("samdi_hat_debuff_punish"):
					var _sh_dmg = int(_samdi_u.damage * 0.15)
					if _sh_dmg > 0:
						var _sh_hp_before = target.current_hp
						target.take_damage(_sh_dmg)
						_scene._log_combat("🎩 [Шляпа Самди] %s получает %d урона за дебафф. HP: %d → %d" % [target.unit_name, _sh_dmg, _sh_hp_before, target.current_hp])
					break
			# ═══ Цветок кикиморы: владелец восстанавливает 3% HP каждый раз, получая дебафф ═══
			if target.current_hp > 0 and target.has_item_effect("kikimora_flower_heal_on_debuff"):
				var _kf_heal = int(target.max_hp * 0.03)
				if _kf_heal > 0:
					var _kf_hp_before = target.current_hp
					target.apply_stat_change("hp", _kf_heal)
					_scene._log_combat("🌸 [Цветок кикиморы] %s восстанавливает %d HP от дебаффа. HP: %d → %d" % [target.unit_name, _kf_heal, _kf_hp_before, target.current_hp])
	return duration

## _apply_effect_to_target() и _extract_stat_name() перенесены в battle_effects.gd
## (см. effects._apply_effect_to_target()).

# ══════════════════════════════════════════════
#  ПАССИВНЫЕ СПОСОБНОСТИ ПЕРСОНАЖЕЙ
# ══════════════════════════════════════════════
