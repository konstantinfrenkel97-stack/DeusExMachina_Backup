extends RefCounted
class_name BattleOutcome

## Конец боя: проверка победы/поражения, синхронизация HP/величия с кампанией, забвение, возврат в миссию.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

func _check_battle_end() -> bool:
	var heroes_alive = false
	var enemies_alive = false
	
	for h in _scene.heroes_team:
		if h and h.current_hp > 0:
			heroes_alive = true
			break
			
	for e in _scene.enemies_team:
		if e and e.current_hp > 0:
			enemies_alive = true
			break
			
	if not heroes_alive:
		_scene.battle_running = false
		_scene.waiting_for_player = false
		_scene.active_unit = null
		_scene._field._update_active_highlight()
		if CombatManager.is_mission_battle:
			_scene._set_status("Поражение! Миссия провалена. Возврат в главное меню...")
		else:
			_scene._set_status("Поражение! Все герои мертвы. Возврат в главное меню...")
		_scene._log_combat("Поражение: все герои мертвы.")
		_end_battle(false)
		return true

	if not enemies_alive:
		_scene.battle_running = false
		_scene.waiting_for_player = false
		_scene.active_unit = null
		_scene._field._update_active_highlight()
		if CombatManager.is_mission_battle:
			_scene._set_status("Победа! Все враги повержены. Переход к следующей сцене миссии...")
		else:
			_scene._set_status("Победа! Все враги повержены. Возврат в главное меню...")
		_scene._log_combat("Победа: все враги повержены.")
		_end_battle(true)
		return true
		
	return false

## Завершает бой: короткая пауза (чтобы игрок увидел результат) и возврат в главное меню.
## Предохранитель _battle_ending гарантирует, что переход запланирован ровно один раз.
func _end_battle(victory: bool = false) -> void:
	if _scene._battle_ending:
		return
	_scene._battle_ending = true
	_sync_campaign_hero_health()
	_sync_mission_hero_majesty()
	if victory:
		_mark_defeated_nemeses()
	# Забвение: боги, погибшие в бою миссии, получают +2.5 усталости.
	if CombatManager.is_mission_battle:
		_apply_death_fading()
	var t = _scene.create_tween()
	t.tween_interval(2.5)
	if CombatManager.is_mission_battle:
		if victory:
			t.tween_callback(_return_to_mission_after_battle)
		else:
			t.tween_callback(_return_to_mission_after_defeat)
	else:
		t.tween_callback(func():
			CombatManager.is_mission_battle = false
			_scene.get_tree().change_scene_to_file("res://main_menu.tscn")
		)

func _sync_campaign_hero_health() -> void:
	for i in range(_scene.heroes_team.size()):
		if i >= CombatManager.selected_heroes.size():
			continue
		var hero_path: String = str(CombatManager.selected_heroes[i])
		if hero_path.strip_edges() == "":
			continue
		var hero: Combatant = _scene.heroes_team[i] as Combatant
		if hero == null:
			continue
		CampaignState.set_god_current_hp(hero_path, hero.current_hp, hero.max_hp)

func _sync_mission_hero_majesty() -> void:
	if not CombatManager.is_mission_battle:
		return
	for i in range(_scene.heroes_team.size()):
		if i >= CombatManager.selected_heroes.size():
			continue
		var hero_path: String = str(CombatManager.selected_heroes[i]).strip_edges()
		if hero_path == "":
			continue
		var hero: Combatant = _scene.heroes_team[i] as Combatant
		if hero == null:
			continue
		MissionState.set_hero_majesty(hero_path, hero.current_majesty)

## Отмечает побеждённым любого немезида (CharacterResource.is_nemesis), который был
## в команде врагов этого выигранного боя.
func _mark_defeated_nemeses() -> void:
	for enemy_value in _scene.enemies_team:
		var enemy: Combatant = enemy_value as Combatant
		if enemy != null and enemy.is_nemesis and enemy.source_resource_path != "":
			CampaignState.mark_nemesis_defeated(enemy.source_resource_path)

func _return_to_mission_after_battle() -> void:
	CombatManager.is_mission_battle = false
	_apply_post_battle_outcome_effects()
	if MissionState.advance_after_battle():
		SceneTransition.change_scene_with_fade("res://Missions/mission_scene.tscn")
		return
	# Бой был последним действием миссии — экран победы/наград/статистики покажет
	# сама mission_scene.gd (см. MissionState.pending_mission_end_kind), она же и
	# завершит миссию (CampaignState.complete_mission и т.д.) в _finish_mission().
	MissionState.pending_mission_end_kind = MissionState.MissionEndKind.VICTORY
	SceneTransition.change_scene_with_fade("res://Missions/mission_scene.tscn")

## Постбоевые эффекты ИМЕННО этого боя (см. MissionOutcome.zero_hero_majesty_after_battle /
## restore_hero_hp_to_pre_battle_after_battle, mission_scene.gd::_arm_post_battle_effects) —
## только при победе (вызывается из _return_to_mission_after_battle), до перехода на next_scene.
## Отдельная функция — чтобы её можно было проверить без реального перехода на сцену миссии.
func _apply_post_battle_outcome_effects() -> void:
	if CombatManager.pending_zero_hero_majesty_after_battle:
		for hero_path_value in CombatManager.selected_heroes:
			var hero_path: String = str(hero_path_value).strip_edges()
			if hero_path != "":
				MissionState.set_hero_majesty(hero_path, 0)
		CombatManager.pending_zero_hero_majesty_after_battle = false
	if CombatManager.pending_restore_hero_hp_after_battle:
		for hero_path_value in CombatManager.selected_heroes:
			var hero_path: String = str(hero_path_value).strip_edges()
			if hero_path == "" or CampaignState.is_god_dead(hero_path):
				continue
			if CombatManager.hero_hp_snapshot_before_battle.has(hero_path):
				CampaignState.set_god_current_hp(hero_path, int(CombatManager.hero_hp_snapshot_before_battle[hero_path]))
		CombatManager.pending_restore_hero_hp_after_battle = false
		CombatManager.hero_hp_snapshot_before_battle = {}

## Поражение в бою миссии: дальше сцены миссии не идут, независимо от того, был ли
## у боя next_scene_after_battle — экран поражения/наград/статистики покажет
## mission_scene.gd (см. MissionState.pending_mission_end_kind).
func _return_to_mission_after_defeat() -> void:
	CombatManager.is_mission_battle = false
	_clear_post_battle_outcome_effects()
	MissionState.pending_mission_end_kind = MissionState.MissionEndKind.DEFEAT
	SceneTransition.change_scene_with_fade("res://Missions/mission_scene.tscn")

## Поражение не должно оставлять постбоевые эффекты ИМЕННО ЭТОГО боя (см.
## _apply_post_battle_outcome_effects()) взведёнными — они относились к бою, который
## теперь уже никогда не "выиграется". Отдельная функция — чтобы её можно было
## проверить без реального перехода на сцену миссии.
func _clear_post_battle_outcome_effects() -> void:
	MissionState.next_scene_after_battle = null
	CombatManager.pending_zero_hero_majesty_after_battle = false
	CombatManager.pending_restore_hero_hp_after_battle = false
	CombatManager.hero_hp_snapshot_before_battle = {}

## Начисляет ровно 2 полных уровня забвения каждому богу, погибшему в текущем
## бою миссии, и в ЛЮБОМ случае делает его недоступным до конца этой миссии
## (CombatManager.mission_dead_heroes — несмотря на название, функционально это
## список "не участвует в ОСТАВШИХСЯ боях текущей миссии", читается везде, где
## собирается отряд на следующий бой — mission_scene.gd/battle_setup.gd).
## Если добавленное забвение НЕ привело к окончательной смерти (5.0 — is_dead),
## бог всё равно восстанавливает здоровье (чтобы не висеть "недобитым" до конца
## кампании) — но в следующих боях ЭТОЙ миссии участвовать уже не будет, только
## со следующей миссии. Если же добило до 5.0 — окончательно погиб, недоступен
## и в будущих миссиях тоже (CampaignState.is_god_dead()), пока не воскрешён
## отдельной механикой.
## Хранится ИСКЛЮЧИТЕЛЬНО через CampaignState._god_state_overrides (см.
## CampaignState.add_god_forgetting) — то же хранилище, что и SaveSystem, а не запись
## поверх исходного .tres бога: тот файл — общий шаблон для ВСЕХ партий этого бога
## в игре, и `ResourceSaver.save()` в экспортированной сборке по res:// либо не
## сработает (packed pck на большинстве платформ доступен только на чтение), либо в
## редакторе необратимо испортит сам ассет забвением одной случайной партии.
func _apply_death_fading() -> void:
	for i in range(_scene.heroes_team.size()):
		var hero = _scene.heroes_team[i]
		if hero == null or hero.current_hp > 0:
			continue
		if i >= CombatManager.selected_heroes.size():
			continue
		var hero_path: String = str(CombatManager.selected_heroes[i]).strip_edges()
		if hero_path == "" or CampaignState.is_god_dead(hero_path):
			continue
		var state: Dictionary = CampaignState.add_god_forgetting(hero_path, 2.0)
		MissionState.add_hero_forgetting_gained(hero_path, 2.0)
		var is_dead: bool = bool(state.get("is_dead", false))
		if not CombatManager.mission_dead_heroes.has(hero_path):
			CombatManager.mission_dead_heroes.append(hero_path)
		# Расходуемые артефакты сгорают сразу при смерти владельца в миссии.
		for item_name in CampaignState.consume_single_mission_items(hero_path):
			_scene._log_combat("%s: «%s» сгорает вместе с гибелью владельца." % [hero.unit_name, item_name])
		if not is_dead:
			CampaignState.set_god_current_hp(hero_path, CampaignState.get_god_max_hp(hero_path))
		print("[Смерть] %s → забвение %.1f%s" % [
			hero.unit_name, float(state.get("forgetting_level", 0.0)),
			" (МЁРТВ)" if is_dead else ""
		])

## _dispel_effects/_dispel_stat_debuffs перенесены в battle_effects.gd
## (см. effects._dispel_effects()/effects._dispel_stat_debuffs()).
