extends RefCounted
class_name BattleAI

## ИИ врагов: выбор способности и цели (скриптовые логики боссов и случайный выбор).
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

func _enemy_ai_turn(monster: Combatant):
	var decision = _get_ai_decision(monster)
	if decision.has("ability") and decision.ability and decision.has("target") and decision.target:
		var _used_ability: AbilityResource = decision.ability
		if _used_ability.majesty_cost > 0:
			monster.modify_majesty(-_scene._targeting._effective_majesty_cost(monster, _used_ability))
		_scene._abilities._use_ability(monster, decision.target, _used_ability)
	else:
		_scene._log_combat("%s не нашёл подходящего действия и пропускает ход." % monster.unit_name)
	_scene._turns._finish_unit_turn(monster)

## Fallback ИИ: выбирает случайную доступную способность и валидную цель.
## Используется когда у юнита нет ai_script или скрипт не зарегистрирован.
func _get_random_ai_decision(monster: Combatant) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		var valid: Array = []
		# Цели-враги (герои)
		for h in _scene.heroes_team:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				valid.append(h)
		# Цели-союзники (для Ally/All_Allies)
		if ab.target_type == "Ally" or ab.target_type == "All_Allies":
			valid.clear()
			for a in _scene.enemies_team:
				if a and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, ab):
					valid.append(a)
		if valid.size() > 0:
			return {"ability": ab, "target": valid.pick_random()}
	return {}

func _get_ai_decision(monster: Combatant) -> Dictionary:
	if monster.ai_script == null:
		return _get_random_ai_decision(monster)
	# Состояние локации Глубина: Бурные потоки = нечётный раунд (урон при перемещении)
	var is_raging: bool = (_scene.current_round % 2 == 1) and CombatManager.selected_location_id == "depths"
	match monster.ai_script.resource_path.get_file():
		"orochi_logic.gd":
			return OrochiLogic.get_decision(monster, _scene.heroes_team)
		"nemesis_random_logic.gd":
			return NemesisRandomLogic.get_decision(monster, _scene.heroes_team)
		"cerberus_logic.gd":
			return CerberusLogic.get_decision(monster, _scene.heroes_team)
		"baldr_logic.gd":
			return BaldrLogic.get_decision(monster, _scene.heroes_team)
		"cyclops_logic.gd":
			return CyclopsLogic.get_decision(monster, _scene.heroes_team)
		"draugr_juggernaut_logic.gd":
			return DraugrJuggernautLogic.get_decision(monster, _scene.heroes_team)
		"draugr_raider_logic.gd":
			return DraugrRaiderLogic.get_decision(monster, _scene.heroes_team)
		"draugr_berserk_logic.gd":
			return DraugrBerserkLogic.get_decision(monster, _scene.heroes_team)
		"banshee_logic.gd":
			return BansheeLogic.get_decision(monster, _scene.heroes_team)
		"indigo_logic.gd":
			return IndigoLogic.get_decision(monster, _scene.heroes_team, _scene._is_fog_round)
		"jotun_logic.gd":
			return JotunLogic.get_decision(monster, _scene.heroes_team)
		"cannon_logic.gd":
			return CannonLogic.get_decision(monster, _scene.heroes_team)
		"captain_logic.gd":
			return CaptainLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"siren_logic.gd":
			return SirenLogic.get_decision(monster, _scene.heroes_team)
		"filibuster_logic.gd":
			return FilibusterLogic.get_decision(monster, _scene.heroes_team)
		"sailor_logic.gd":
			return SailorLogic.get_decision(monster, _scene.heroes_team)
		"sailor_bomber_logic.gd":
			return SailorBomberLogic.get_decision(monster, _scene.heroes_team)
		"oni_warrior_logic.gd":
			return OniWarriorLogic.get_decision(monster, _scene.heroes_team)
		"oni_sorcerer_logic.gd":
			return OniSorcererLogic.get_decision(monster, _scene.heroes_team)
		"lernaean_lion_logic.gd":
			return LernaeanLionLogic.get_decision(monster, _scene.heroes_team)
		"armored_titan_logic.gd":
			return ArmoredTitanLogic.get_decision(monster, _scene.heroes_team)
		"attacking_titan_logic.gd":
			return AttackingTitanLogic.get_decision(monster, _scene.heroes_team)
		"immortal_logic.gd":
			return ImmortalLogic.get_decision(monster, _scene.heroes_team)
		"anubis_logic.gd":
			return AnubisLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"ra_logic.gd":
			return RaLogic.get_decision(monster, _scene.heroes_team)
		"mummy_logic.gd":
			return MummyLogic.get_decision(monster, _scene.heroes_team)
		"sphinx_logic.gd":
			return SphinxLogic.get_decision(monster, _scene.heroes_team)
		"scarab_logic.gd":
			return ScarabLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"kappa_warrior_logic.gd":
			return KappaWarriorLogic.get_decision(monster, _scene.heroes_team)
		"kappa_shaman_logic.gd":
			return KappaShamanLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"crab_collector_logic.gd":
			return CrabCollectorLogic.get_decision(monster, _scene.heroes_team)
		"saru_logic.gd":
			return SaruLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"naga_warrior_logic.gd":
			return NagaWarriorLogic.get_decision(monster, _scene.heroes_team)
		"naga_monk_logic.gd":
			return NagaMonkLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"rakshasa_logic.gd":
			return RakshasaLogic.get_decision(monster, _scene.heroes_team)
		"coatl_logic.gd":
			return CoatlLogic.get_decision(monster, _scene.heroes_team)
		"asura_logic.gd":
			return AsuraLogic.get_decision(monster, _scene.heroes_team)
		"medusa_logic.gd":
			return MedusaLogic.get_decision(monster, _scene.heroes_team)
		"lava_boar_logic.gd":
			return LavaBoarLogic.get_decision(monster, _scene.heroes_team)
		"kirin_logic.gd":
			return KirinLogic.get_decision(monster, _scene.heroes_team)
		"kikimora_logic.gd":
			return KikimoraLogic.get_decision(monster, _scene.heroes_team)
		"leshy_logic.gd":
			return LeshyLogic.get_decision(monster, _scene.heroes_team)
		"oboroten_logic.gd":
			return OborotenLogic.get_decision(monster, _scene.heroes_team)
		"troll_logic.gd":
			return TrollLogic.get_decision(monster, _scene.heroes_team)
		"utoplennitsa_logic.gd":
			return UtoplennitsaLogic.get_decision(monster, _scene.heroes_team)
		"vodyanoy_logic.gd":
			return VodyanoyLogic.get_decision(monster, _scene.heroes_team)
		"arena_random_logic.gd":
			return ArenaRandomLogic.get_decision(monster, _scene.heroes_team)
		"hell_random_logic.gd":
			return HellRandomLogic.get_decision(monster, _scene.heroes_team)
		"hellhound_logic.gd":
			return HellhoundLogic.get_decision(monster, _scene.heroes_team)
		"tormentor_logic.gd":
			return TormentorLogic.get_decision(monster, _scene.heroes_team)
		"succubus_logic.gd":
			return SuccubusLogic.get_decision(monster, _scene.heroes_team)
		"nightmare_logic.gd":
			return NightmareLogic.get_decision(monster, _scene.heroes_team)
		"devil_logic.gd":
			return DevilLogic.get_decision(monster, _scene.heroes_team)
		"mentor_logic.gd":
			return MentorLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"minotaur_logic.gd":
			return MinotaurLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"nanahue_logic.gd":
			return NanahueLogic.get_decision(monster, _scene.heroes_team)
		"merwarrior_logic.gd":
			return MerwarriorLogic.get_decision_depths(monster, _scene.heroes_team, is_raging)
		"mermaid_sorceress_logic.gd":
			return MermaidSorceressLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"seawitch_logic.gd":
			return SeaWitchLogic.get_decision_depths(monster, _scene.heroes_team, is_raging)
		"eel_logic.gd":
			return EelLogic.get_decision_depths(monster, _scene.heroes_team, is_raging)
		"triton_logic.gd":
			return TritonLogic.get_decision(monster, _scene.heroes_team)
		"golden_valkyrie_logic.gd":
			return GoldenValkyrieLogic.get_decision(monster, _scene.heroes_team)
		"silver_valkyrie_logic.gd":
			return SilverValkyrieLogic.get_decision(monster, _scene.heroes_team)
		"bird_knife_wings_logic.gd":
			return BirdKnifeWingsLogic.get_decision(monster, _scene.heroes_team)
		"cupid_logic.gd":
			return CupidLogic.get_decision(monster, _scene.heroes_team)
		"pegasus_logic.gd":
			return PegasusLogic.get_decision(monster, _scene.heroes_team)
		"griffin_logic.gd":
			return GriffinLogic.get_decision(monster, _scene.heroes_team)
		"princess_logic.gd":
			return PrincessLogic.get_decision(monster, _scene.heroes_team)
		"jester_logic.gd":
			return JesterLogic.get_decision(monster, _scene.heroes_team)
		"knight_logic.gd":
			return KnightLogic.get_decision(monster, _scene.heroes_team)
		"wizard_logic.gd":
			return WizardLogic.get_decision(monster, _scene.heroes_team)
		"guardsman_logic.gd":
			return GuardsmanLogic.get_decision_castle(monster, _scene.heroes_team, _scene.enemies_team, _scene.current_round)
		"inquisitor_logic.gd":
			return InquisitorLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"kobold_logic.gd":
			return KoboldLogic.get_decision(monster, _scene.heroes_team, _scene.enemies_team)
		"dwarf_shield_logic.gd":
			return DwarfShieldLogic.get_decision(monster, _scene.heroes_team)
		"dwarf_smith_logic.gd":
			return DwarfSmithLogic.get_decision(monster, _scene.heroes_team, _scene.enemies_team)
		"golem_logic.gd":
			return GolemLogic.get_decision(monster, _scene.heroes_team)
		"stone_giant_warrior_logic.gd":
			return StoneGiantWarriorLogic.get_decision(monster, _scene.heroes_team)
		"stone_giant_shaman_logic.gd":
			return StoneGiantShamanLogic.get_decision(monster, _scene.heroes_team)
		"boulder_logic.gd":
			return BoulderLogic.get_decision(monster, _scene.heroes_team)
		"libra_logic.gd":
			return LibraLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"virgo_logic.gd":
			return VirgoLogic.get_decision(monster, _scene.heroes_team)
		"aquarius_logic.gd":
			return AquariusLogic.get_decision(monster, _scene.heroes_team)
		"aries_logic.gd":
			return AriesLogic.get_decision(monster, _scene.heroes_team)
		"scorpio_logic.gd":
			return ScorpioLogic.get_decision(monster, _scene.heroes_team)
		"gemini_logic.gd":
			return GeminiLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"flower_fairy_logic.gd":
			return FlowerFairyLogic.get_decision(monster, _scene.heroes_team)
		"thorn_fairy_logic.gd":
			return ThornFairyLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"alraune_logic.gd":
			return AlrauneLogic.get_decision(monster, _scene.heroes_team)
		"druid_logic.gd":
			return DruidLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"unicorn_logic.gd":
			return UnicornLogic.get_decision_with_allies(monster, _scene.heroes_team, _scene.enemies_team)
		"satyr_logic.gd":
			return SatyrLogic.get_decision(monster, _scene.heroes_team)
		_:
			# Незарегистрированный ИИ — fallback на случайную доступную способность
			return _get_random_ai_decision(monster)


# ══════════════════════════════════════════════
#  ИСПОЛЬЗОВАНИЕ СПОСОБНОСТЕЙ
# ══════════════════════════════════════════════
