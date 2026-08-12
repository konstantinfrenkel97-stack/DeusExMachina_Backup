## Централизованные таблицы текстовых данных.
## Извлечено из battle_scene.gd для повторного использования и упрощения кода.
## Все методы статические — не нужно инстанцировать класс.
class_name DataTables


## Человекочитаемое описание эффекта способности.
static func describe_effect(effect: String, val: int) -> String:
	match effect:
		"self_buff_damage": return "+%d к атаке" % val
		"self_buff_armor": return "+%d к броне" % val
		"self_buff_accuracy": return "+%d к точности" % val
		"self_buff_evasion": return "+%d к уклонению" % val
		"self_buff_crit": return "+%d%% к удаче" % val
		"target_debuff_accuracy": return "-%d к точности цели" % val
		"target_debuff_damage": return "-%d к атаке цели" % val
		"target_debuff_armor": return "-%d к броне цели" % val
		"target_debuff_evasion": return "-%d к уклонению цели" % val
		"self_heal_percent": return "Лечение %d%% HP" % val
		"heal_flat": return "Лечение %d HP" % val
		"dispel_buffs": return "Снятие баффов"
		"dispel_debuffs": return "Снятие дебаффов"
		"self_dispel_debuffs": return "Снятие дебаффов с себя"
		"cleanse_all": return "Очистка всех эффектов"
		"all_allies_dispel_debuffs": return "Снятие дебаффов со всех союзников"
		"self_pull_forward": return "Притягивание вперёд на %d" % val
		"push_back": return "Отталкивание назад на %d" % val
		"pull_forward": return "Притягивание вперёд на %d" % val
		"stun": return "Оглушение"
		"periodic_damage": return "Периодический урон: %d/ход" % val
		"regeneration": return "Регенерация: %d%% HP/ход" % val
		"neverending_storm_mark": return "Метка Вечной Бури"
		"innocence_mark": return "Метка невинности"
		"dispel_accuracy_debuffs": return "Снятие штрафов точности"
		"All_Allies_buff_accuracy": return "+%d к точности всем союзникам" % val
		"random_stat_buff": return "+%d к случайной характеристике" % val
		"steal_buffs": return "Кража баффов"
		_:
			if effect.contains("debuff"):
				var stat := _clean_effect_stat(effect, "debuff")
				return "-%d к %s" % [val, _effect_stat_name(stat)]
			if effect.contains("buff"):
				var stat := _clean_effect_stat(effect, "buff")
				return "+%d к %s" % [val, _effect_stat_name(stat)]
			return effect


static func _clean_effect_stat(effect: String, kind: String) -> String:
	var stat := effect
	var prefixes := ["All_Enemies_", "All_Allies_", "all_enemies_", "all_allies_", "target_", "self_", "enemy_", "ally_"]
	for prefix in prefixes:
		stat = stat.replace(prefix, "")
	stat = stat.replace("_" + kind, "")
	stat = stat.replace(kind + "_", "")
	return stat


static func _effect_stat_name(stat: String) -> String:
	match stat:
		"damage", "attack": return "атаке"
		"armor": return "броне"
		"accuracy": return "точности"
		"evasion": return "уклонению"
		"initiative": return "инициативе"
		"crit", "crit_chance", "luck": return "удаче"
		"health", "hp", "max_hp": return "здоровью"
		"glory": return "величию"
		_: return stat


static func get_passive_description(effect_type: String) -> String:
	match effect_type:
		"thor_berserk": return "Урон и броня растут при потере HP"
		"zeus_position_bonus": return "Множитель урона зависит от позиции цели"
		"cyclops_sensitive_accuracy": return "Вдвойне чувствителен к изменениям точности"
		"osiris_majesty_aura": return "В начале боя все союзники получают +15 величия"
		"susanoo_hit_crit": return "Каждое попадание даёт +5% к удаче навсегда"
		"loki_crit_stun": return "Каждый крит накладывает стан на цель (1 ход)"
		"draugr_raider": return "При получении удара +5% к удаче"
		"draugr_juggernaut": return "При получении удара +5 брони"
		"draugr_berserker": return "При получении удара +5 атаки"
		"kappa_warrior": return "Юнит позади получает +10 брони"
		"kappa_shaman": return "Юнит впереди получает +10 брони"
		"odin_buff_duration": return "Все баффы на союзниках длятся на 1 раунд дольше"
		"poseidon_buff_heal": return "В начале хода восстанавливает 5% HP за каждый уникальный бафф"
		"shiva_random_luck": return "В начале раунда удача принимает случайное значение 0–30%"
		"set_kill_majesty": return "Получает 20 величия за каждое убийство противника"
		"cannon_position_damage": return "Урон по цепочке целей: 100% первой, 90% второй, 80% третьей"
		"captain_ally_initiative": return "Все союзники получают +2 инициативы"
		"siren_ally_evasion": return "+10 уклонения за каждого союзника"
		"filibuster_crit_luck": return "При критическом ударе +10% удачи до конца боя"
		"sailor_rum_heal": return "При получении заклинания «Ром» восстанавливает 10% HP"
		"sailor_bomber_low_hp": return "При HP <20% толкает вперёд на 2 и применяет Самоподрыв"
		"koschei_life_charges": return "5 зарядов жизни: при смерти теряет 1 заряд и восстанавливает HP"
		"hades_kill_fantasy": return "При смерти противника восстанавливает 6 очков фантазии"
		"morgan_spell_periodic": return "При применении заклинания на врага: 10% периодического урона на 2 хода"
		"oni_rage": return "При HP <50% активируется Ярость: +5 инициативы и +15 урона до конца боя"
		"lion_ally_death_heal": return "При смерти союзника полностью восстанавливает HP"
		"titan_armor_double": return "Все эффекты брони удваиваются"
		"titan_damage_double": return "Все эффекты урона удваиваются"
		"immortal_death_shield": return "Впервые при HP=0 восстанавливает полное HP вместо гибели"
		"anubis_resurrect": return "При смерти воскрешает другого мёртвого союзника с полным HP"
		"ra_no_location_damage": return "Пока жив, союзники не получают урон от локации"
		"mummy_hit_max_hp_reduce": return "При попадании по ней атакующий теряет 5 макс. HP до конца боя"
		"sphinx_debuff_immune": return "Иммунен ко всем дебаффам"
		"scarab_death_heal_allies": return "При смерти исцеляет остальных союзников на 15% HP"
		"crab_collector_death_copy": return "При смерти копирует свои баффы всем союзникам"
		"medusa_stun_heal": return "Лечится на 15% HP при оглушении любого юнита"
		"lava_boar_thorns": return "При попадании по нему атакующий получает урон (10%+)"
		"kirin_initiative_damage": return "+5% урона за каждую единицу разницы инициатив с целью"
		"kobold_hp_advantage": return "+30% урона по целям с большим HP, чем у себя"
		"dwarf_shield_back_protect": return "-50% урона от атакующих на позициях 3-4"
		"dwarf_smith_ally_buff": return "+5 брони (2 хода) при баффе союзника"
		"golem_end_turn_growth": return "В конце хода +5 атаки и +3 брони навсегда"
		"giant_armor_pierce": return "Игнорирует половину брони цели"
		"shaman_no_move_armor": return "+20 брони, если не перемещался в прошлом раунде"
		"boulder_provocation": return "Постоянная метка провокации"
		"libra_adjacent_buff": return "Союзники на соседних клетках получают звёздный бафф Весов"
		"virgo_buff_amplify": return "Баффы, получаемые союзниками, усилены на 100% за каждую Деву"
		"aquarius_no_move_attack": return "+15 атаки навсегда, если не перемещался в прошлом раунде"
		"aries_path_buffs": return "При перемещении получает бафф каждой пройденной клетки (1 ход)"
		"scorpio_debuff_damage": return "+5% урона за каждый дебафф на себе"
		"gemini_buff_copy": return "При получении баффа союзником — копирует его на себя"
		"alraune_regen": return "Большой. Каждый ход восстанавливает 10% здоровья"
		"druid_regen_aura": return "В начале раунда все союзники восстанавливают 5% здоровья"
		"unicorn_counter_accuracy": return "При атаке по нему атаковавший теряет 15 точности на 2 хода (даже при промахе)"
		"satyr_redirect": return "Метка невинности: 50% шанс, что атака по нему перенесётся на случайного союзника"
		"": return ""
		_: return effect_type


## Название эффекта боя / локации по идентификатору.
static func get_battle_effect_name(location_id: String) -> String:
	match location_id:
		# Подземелье
		"helheim": return "Хельхейм (туман, -20 урона героям)"
		"hell": return "Ад (-5 величия, -5 маны)"
		"tunnels": return "Тоннели (регенерация при броне >50%)"
		# Небо
		"clouds": return "Облака (+10 уклонения после попадания)"
		"stars": return "Звёзды (баффы по позициям врагов)"
		"mountains": return "Горы (Тут не место для малышни)"
		# Цивилизация
		"arena": return "Арена (+20% урона всем)"
		"castle": return "Замок (заклинания x1.5, 2 за ход)"
		"desert": return "Пустыня (10 чистого урона всем)"
		# Море
		"depths": return "Глубина (урон/лечение при смене позиции)"
		"island": return "Остров (-1 инициатива каждый раунд)"
		"ships": return "Корабли (уникальное заклинание «Ром»)"
		# Лес
		"jungle": return "Джунгли (крит x3)"
		"garden": return "Сад (+15 урона при дебаффе на союзника)"
		"swamp": return "Топь (стак дебаффа на первой позиции)"
		"home": return "Дом (без эффектов)"
		"book": return "Книга (без эффектов)"
		# Старые ID (обратная совместимость)
		"all_damage_plus20": return "Арена (+20% урона всем)"
		"all_damage_minus20": return "Туман войны (-20% урона всем)"
		"armor_zero": return "Пробитие (броня игнорируется)"
		"crit_double": return "Джунгли (крит x3)"
		_: return location_id


## Название типа цели (для тултипов).
static func get_target_type_name(target_type: String) -> String:
	var names := {
		"Enemy": "Один противник",
		"Ally": "Союзник",
		"Self": "На себя",
		"All_Enemies": "Все противники",
		"All_Allies": "Все союзники",
		"Any": "Любой юнит (союзник или враг)",
		"Position": "Позиция (марка)",
	}
	return names.get(target_type, target_type)
