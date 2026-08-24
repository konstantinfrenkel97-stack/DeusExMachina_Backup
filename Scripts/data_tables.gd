## Централизованные таблицы текстовых данных.
## Извлечено из battle_scene.gd для повторного использования и упрощения кода.
## Все методы статические — не нужно инстанцировать класс.
class_name DataTables


## Человекочитаемое описание эффекта способности.
static func describe_effect(effect: String, val: int) -> String:
	match effect:
		"target_root": return "Обездвиживает цель"
		"target_push_forward": return "Толкает цель вперёд на %d" % val
		"target_pull_forward": return "Притягивает цель вперёд на %d" % val
		"target_heal_percent": return "Лечит цель на %d%% HP" % val
		"target_extend_location_effect": return "Продлевает на цели текущий штраф или бонус от выбранной локации на %d ход." % val
		"self_thor_hammer_of_lightning": return "Метка Громового молота: после атак по врагу задевает всех противников"
		"self_thor_fight_me_heal": return "Лечится на %d%% максимального здоровья при попадании по себе" % val
		"self_push_forward": return "Продвигается вперёд на %d" % val
		"self_push_back": return "Отходит назад на %d" % val
		"self_provocation_mark": return "Получает метку провокации"
		"self_fog_accuracy": return "+%d к точности в тумане" % val
		"self_damage_hp_percent": return "Наносит себе %d%% от максимального здоровья" % val
		"self_damage_dealt_percent": return "Наносит себе %d%% от нанесённого урона" % val
		"push_forward": return "Продвигает вперёд на %d" % val
		"medusa_curse_initiative": return "-%d к инициативе цели" % val
		"enemy_push_back": return "Отталкивает врага назад на %d" % val
		"enemy_periodic_damage": return "Периодический урон врагу: %d/ход" % val
		"crit_stun": return "При критическом ударе оглушает цель"
		"ally_pull_porward": return "Притягивает союзника вперёд на %d" % val
		"target_periodic_damage": return "Периодический урон цели: %d/ход" % val
		"ally_buff_evasion": return "+%d к уклонению союзнику" % val
		"asura_streak_debuff": return "-%d к удаче цели" % val
		"raven_mark_accuracy": return "После атаки отмеченной цели атакующий получает +%d к точности" % val
		"voodoo_mark": return "50% полученного урона переносится на юнита позади"
		"chernobog_endless_horror": return "Ужас не заканчивается после срабатывания"
		"copy_location_effect": return "Копирует эффект текущей локации"
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
		"restart_battle": return "Начинает бой заново в тех же условиях"
		_:
			if effect.begins_with("dispel_") or effect.contains("_dispel_"):
				return _describe_dispel_effect(effect)
			if effect.contains("debuff"):
				var stat := _clean_effect_stat(effect, "debuff")
				return "-%d к %s%s" % [absi(val), _effect_stat_name(stat), _effect_scope_text(effect)]
			if effect.contains("buff"):
				var stat := _clean_effect_stat(effect, "buff")
				return "+%d к %s%s" % [absi(val), _effect_stat_name(stat), _effect_scope_text(effect)]
			return "Особый эффект: " + effect


static func _describe_dispel_effect(effect: String) -> String:
	if effect == "dispel_accuracy_debuffs" or effect == "dispel_accuracys":
		return "Снимает штрафы точности"
	if effect.contains("debuff"):
		return "Снимает дебаффы"
	if effect.contains("buff"):
		return "Снимает баффы"
	return "Снимает эффекты"


static func _effect_scope_text(effect: String) -> String:
	if effect.begins_with("All_Allies_") or effect.begins_with("all_allies_"):
		return " всем союзникам"
	if effect.begins_with("All_Enemies_") or effect.begins_with("all_enemies_"):
		return " всем врагам"
	if effect.begins_with("target_") or effect.begins_with("enemy_"):
		return " цели"
	if effect.begins_with("ally_"):
		return " союзнику"
	if effect.begins_with("self_"):
		return " себе"
	return ""


static func _clean_effect_stat(effect: String, kind: String) -> String:
	var stat := effect
	var prefixes := ["All_Enemies_", "All_Allies_", "all_enemies_", "all_allies_", "target_", "self_", "enemy_", "ally_"]
	for prefix in prefixes:
		stat = stat.replace(prefix, "")
	stat = stat.replace("_" + kind, "")
	stat = stat.replace(kind + "_", "")
	stat = stat.replace("accuracys", "accuracy")
	stat = stat.replace("crit_chance", "crit")
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


static func normalize_description_text(text: String) -> String:
	return text.strip_edges().to_lower().replace("?", "?").replace("\r", "\n")


static func is_placeholder_description(text: String) -> bool:
	var normalized := normalize_description_text(text)
	return normalized == "" or normalized == "описание" or normalized == "название"


static func should_append_detail(existing_text: String, detail: String) -> bool:
	var normalized_detail := normalize_description_text(detail)
	if normalized_detail == "":
		return false
	var normalized_existing := normalize_description_text(existing_text)
	if normalized_existing.contains(normalized_detail):
		return false
	if normalized_existing.length() > 0 and normalized_detail.length() >= 24 and normalized_detail.contains(normalized_existing):
		return false
	return true


static func get_condition_name(condition: String) -> String:
	match condition:
		"OnCrit": return "при критическом ударе"
		"OnMiss": return "при промахе"
		"OnKill": return "при убийстве"
		_: return condition


static func get_mark_type_name(mark_type: String) -> String:
	match mark_type:
		"once": return "одноразовая"
		"persistent": return "многоходовая"
		_: return mark_type


static func get_stance_effect_description(stance_effect_type: String) -> String:
	match stance_effect_type:
		"warrior_of_night_stance": return "При входе в стойку получает +10 уклонения на 1 ход и даёт +10 уклонения золотым валькириям на 1 ход. В начале следующего хода получает +10 атаки, +10 точности и +10 удачи на 3 хода."
		"warrior_of_day_stance": return "При входе в стойку получает +10 уклонения на 1 ход и даёт +10 уклонения серебряным валькириям на 1 ход. В начале следующего хода получает +10 максимального HP навсегда, +10 брони и +10 уклонения на 3 хода."
		"unicorn_grace": return "Пока стойка активна, единорог получает +20 брони и +20 уклонения."
		"titan_indestructible": return "При входе в стойку получает метку провокации на 1 ход. Каждый раз, когда по титану атакуют, он получает +5 брони на 3 хода."
		"titan_born_to_battle": return "Каждый раз, когда по титану атакуют, он получает +10 атаки на 2 хода. В начале следующего хода наносит 80% урона целям на 1-2 позициях."
		"sphinx_statue_form": return "При активации получает +30 брони на 1 ход и лечится на 20% максимального HP."
		"smith_forge": return "Ковать железо: получает жетон ковки; следующее улучшение снаряжения дополнительно даёт +5 атаки и +5 брони за каждое удвоение жетона."
		"sea_power_stance": return "В начале следующего хода все союзники получают +20 атаки на 1 ход."
		"scarab_bury_in_sand": return "В начале следующего хода получает +40% уклонения на 1 ход; случайный враг получает 40% урона скоробея и -15 точности на 1 ход."
		"rakshasa_disharmony": return "Враги теряют удачу и точность."
		"princess_in_trouble": return "Накладывает провокацию и даёт уклонение, пока стойка активна."
		"pegasus_arrow_rain": return "В начале следующего хода выпускает дождь стрел по противникам."
		"oni_flaming_rain": return "В начале следующего хода наносит огненный удар по противникам."
		"oboroten_ambush": return "Следующий враг, совершивший действие, получает 150% урона оборотня."
		"novice_training": return "Даёт уклонение, пока стойка активна."
		"nightmare_unforgettable": return "В начале следующего хода получает щит от смерти на 1 ход."
		"naga_universe": return "Пока стойка активна, союзник при получении баффа получает +7 удачи на 1 ход и лечение на 7% HP."
		"libra_balance": return "Пока стойка активна, когда союзник получает урон, враги получают 25% этого урона чистым уроном."
		"lava_boar_heart": return "В начале следующего хода восстанавливает 10% HP и добавляет +5% к урону от пассивного отражения до конца боя."
		"knight_magic_supremacy": return "На время стойки получает +15 брони, а стоимость заклинаний противника увеличивается на 2."
		"kirin_lightning_dodge": return "Быстрый как молния: после атаки по нему получает +3 уклонения на 1 ход за каждую единицу разницы инициативы с атакующим."
		"kikimora_beauty": return "Атаки по цели могут обернуться против атакующего."
		"jester_deadly_strike": return "В начале следующего хода атакует случайного врага на часть его текущего здоровья."
		"indigo_hunt_stance": return "В начале следующего хода атакует доступную цель на 2-3 позиции с 150% урона и отступает на 1 позицию."
		"immortal_my_battle_not_over": return "В начале следующего хода, если щит смерти был потрачен, восстанавливает его; иначе получает 20 периодического урона на 2 хода."
		"guardsman_halt": return "При активации все враги получают -20 уклонения."
		"giant_ceiling": return "Обрушивает потолок в начале следующего хода."
		"devil_abandon_hope": return "Пока стойка активна, противники не получают баффы: вместо баффа получают 15% урона и теряют 10 величия."
		"chernobog_no_hope": return "Пока стойка активна, противники не получают баффы: вместо баффа получают 80% урона."
		"bombardment_stance": return "В начале следующего хода наносит 4 удара по случайным врагам, каждый удар наносит 50% урона."
		"thunder_wrath": return "В начале следующего хода наносит 5 ударов по случайным врагам, каждый удар наносит 30% урона Зевса."
		"filibuster_double_hit": return "Следующая атака повторяется."
		"centaur_suppressive_fire": return "Пока стойка активна, каждый действующий противник получает 60% урона кентавра."
		"duna_harmony": return "Назад на 1. Пока стойка активна, союзники не получают дебаффы; отменённый дебафф лечит цель."
		"hoplite_shield_wall": return "При входе в стойку получает +20 брони. Когда по гоплиту атакуют, он наносит атакующему 60% ответного урона."
		"koschei_immortal": return "При активации получает +30 брони и метку провокации на 1 ход."
		"loki_ragnarok": return "В начале следующего хода все враги получают 50% урона; текущая удача Локи удваивается на 1 ход."
		"odin_foresight": return "Пока стойка активна, все союзники получают +20 уклонения и +15 удачи."
		"poseidon_calm": return "Пока стойка активна, каждый противник при перемещении получает 70% урона Посейдона."
		"ra_sun_glory": return "Отступает на 2 линии; все союзники получают +10 уклонения на 2 хода; урон Пустыни по врагам удваивается."
		"satyr_charm": return "Пока стойка активна, в начале каждого раунда все враги теряют ещё 5 атаки. Эффект накапливается."
		"set_true_king": return "Пока стойка активна, величие союзников перехватывается Сетом; союзник вместо этого лечится на 10% HP и получает +10 брони на 2 хода."
		"shiva_karma": return "Пока стойка активна, атакующий получает 50% нанесённого урона обратно и копирует дебаффы Шивы."
		"shiva_destruction_cycle": return "Вперёд на 2. Пока стойка активна, при действии противника Шива наносит ему 70% урона; крит повторяет удар."
		"susanoo_reflection": return "Позволяет ответить отражением."
		"wizard_armageddon": return "В начале следующего хода наносит 80% урона всем остальным юнитам: союзникам и врагам."
		_: return ""


static func describe_active_effect(effect_id: String, stat: String, value: int, source: String) -> String:
	var key := effect_id
	if key == "":
		key = stat
	match key:
		"thor_hammer_of_lightning": return "Громовой молот: после способности по противнику все враги получают чистый урон от атаки Тора и могут быть оглушены."
		"thor_fight_me_heal": return "Тор лечится на 7% максимального здоровья каждый раз, когда по нему попадают атакой."
		"neverending_storm_mark": return "Нескончаемый шторм: эффект активен до конца боя. В начале раунда молния бьёт самого дальнего противника."
		"provocation_mark", "princess_provocation": return "Метка провокации: враги должны атаковать эту цель, если могут."
		"cupid_innocence": return "Метка невинности: атака может быть перенаправлена на случайного союзника цели."
		"plant_poison_buff": return "Растительный яд: 3 хода при попадании союзника по врагу накладывает периодический урон 20% от атаки Дуны на 4 хода."
		"voodoo_marked": return "Кукла вуду: часть урона и наложенные дебаффы передаются связанному юниту."
		"raven_marked": return "Стая воронов: атака по отмеченной цели даёт атакующему точность."
		"root_thorns": return "Шипы корней: атакующий получает ответный урон при попадании по цели."
		"duna_harmony_immune": return "Гармония с природой: дебафф отменяется, а цель лечится."
		"ultimate_blocked": return "Ульта заблокирована."
		"sphinx_riddle": return "Загадка Сфинкса: цель отмечена загадкой."
		"rooted": return "Корни: цель не может передвигаться."
		"sarcophagus_stun": return "Саркофаг: цель оглушена."
		"sarcophagus_invul": return "Саркофаг: цель неуязвима до следующего хода Сета."
		"immortal_shield_used": return "Щит смерти уже сработал: при следующей смерти полного восстановления не будет."
		"oni_rage_active": return "Ярость Они: +5 инициативы и +15 атаки до конца боя."
		"sailor_bomber_low_hp_triggered": return "Матрос с бомбой уже активировал рывок при низком здоровье."
		"lava_boar_warm_heart_stack": return "Горячее сердце: базовый ответный урон 10%; каждый стак добавляет ещё +5%."
		"forget": return "Забытьё: снижает уровни способностей."
		"stars_bonus": return "Звёзды: позиция 1 даёт +10 брони, позиция 2 регенерацию 10%, позиция 3 +10 удачи, позиция 4 +10 атаки."
		"helheim_fog": return "Туман Хельхейма: -20 атаки на 1 ход."
		"indigo_fog": return "Туман Хельхейма: +25 уклонения на 1 ход."
		"swamp_debuff": return "Топь: штраф локации."
		"kappa_warrior_aura": return "Аура каппы-воина: юнит позади получает броню."
		"kappa_shaman_aura": return "Аура каппы-шамана: юнит впереди получает броню."
		"thor_berserk_aura_damage": return "Пассивка Тора: +5 атаки за каждые полные 10% недостающего HP; пересчитывается при изменении здоровья."
		"thor_berserk_aura_armor": return "Пассивка Тора: +5 брони за каждые полные 10% недостающего HP; пересчитывается при изменении здоровья."
		"draugr_raider_luck": return "Драугр-налётчик: при попадании по нему получает +5% удачи до конца боя."
		"draugr_juggernaut_armor": return "Драугр-джаггернаут: при попадании по нему получает +5 брони до конца боя."
		"draugr_berserker_damage": return "Драугр-берсерк: при попадании по нему получает +5 атаки до конца боя."
		"nightmare_death_shield": return "Щит смерти: цель не погибнет от следующего смертельного урона."
		"soul_position": return "Страдающая душа: на первой позиции получает +4 инициативы и +20 уклонения на 1 ход."
		"rakshasa_aura": return "Аура ракшаса: снижает удачу противников."
		"rakshasa_disharmony": return "Дисгармония: противники теряют удачу и точность."
		"jester_fantasy_luck": return "Получает +1% удачи за каждую недостающую единицу фантазии."
		"sea_power_buff": return "Сила моря: союзники получают атаку."
		"warrior_of_day_armor", "warrior_of_day_evasion": return "Воин дня: +10 максимального HP, +10 брони и +10 уклонения на 3 хода."
		"warrior_of_night_damage", "warrior_of_night_accuracy", "warrior_of_night_crit": return "Воин ночи: +10 атаки, +10 точности и +10 удачи на 3 хода."
		"giant_ceiling_armor": return "Обрушить потолок: цель теряет 10 брони."
		"duna_heal_damage": return "Дуна: в конце хода получает атаку за часть здоровья, восстановленного в этот ход."
		"titan_indestructible_armor": return "Несокрушимый: после атаки по нему получает +5 брони на 3 хода."
		"titan_born_to_battle_damage": return "Рождённый для битвы: после атаки по нему получает +10 атаки на 2 хода."
		"kirin_lightning_dodge": return "Быстрый как молния: после атаки по нему получает +3 уклонения на 1 ход за каждую единицу разницы инициативы с атакующим."
		"unicorn_counter_accuracy": return "Единорог: атакующий теряет точность за атаку по цели."
		"raven_accuracy": return "Стая воронов: атакующий получил точность за удар по отмеченной цели."
		"mummy_curse_max_hp": return "Аура мумии: максимальное здоровье снижено до конца боя."
		"clouds_evasion": return "Облака: уклонение после попадания."
		"set_tear_apart_armor": return "Разорвать: цель теряет 5 брони на 3 хода за каждый бафф на ней."
		"loki_trickster_debuff": return "Танец бога обмана: каждый враг получает -10 удачи на 2 хода."
		"loki_trickster_buff": return "Танец бога обмана: Локи получает +10 удачи на 2 хода за каждого врага."
		"koschei_go_back_armor": return "Назад!: Кощей восстанавливает 1 заряд жизни и получает +20 брони."
		"immortal_sand_step": return "Двигаться вместе с песком: продвигается вперёд на 1 и получает +20 уклонения на 2 хода."
		"anubis_death_delay_dmg", "anubis_death_delay_acc": return "Отсрочка от смерти: если у цели меньше 40% HP, лечит 40% максимального HP и даёт +15 атаки и +15 точности на 3 хода."
		"mummy_curse": return "Древнее проклятие: атака и броня снижены до конца боя."
		"mummy_death_aura": return "Аура смерти: все враги получают -10 удачи, пока мумия жива."
		"set_true_king_armor": return "Настоящий король: броня после перехвата величия."
		"loki_ragnarok_crit": return "Рагнарек: шанс крита Локи удваивается на этот удар."
		"koschei_immortal_armor": return "Неубиваемый: при срабатывании щита смерти получает +30 брони и метку провокации на 1 ход."
		"ra_sun_glory_evasion": return "Слава солнцу: все союзники получают +10 уклонения на 2 хода; урон Пустыни по врагам удваивается."
		"sphinx_statue_armor": return "Облик статуи: +30 брони на 1 ход и лечение 20% максимального HP."
		"scarab_bury_evasion": return "Зарыться в песок: +40 уклонения на 1 ход, затем случайный враг получает удар 40% атаки."
		"scarab_sand_blind": return "Песчаная слепота: цель получает -15 точности на 1 ход."
		"naga_move_luck": return "После перемещения получает +7 удачи на 2 хода."
		"merwarrior_move_luck": return "При перемещении получает +10 удачи на 1 ход."
		"triton_enemy_move_armor": return "Пассивка Тритона: когда враг перемещается, этот враг получает -10 брони на 1 ход."
		"valkyrie_shared_buff": return "Пассивка Валькирии: когда парная валькирия получает +10 уклонения от стойки, эта валькирия тоже получает +10 уклонения на 1 ход."
		"pegasus_ally_buff_stack": return "Пассивка Пегаса: атака выросла после баффа союзника."
		"self_fog_accuracy": return "Туманный раунд: точность повышена."
		"tormentor_regen": return "Пассивка Мучителя: регенерация за периодический урон союзника."
		"naga_universe": return "Часть вселенной: удача и лечение при баффе союзника."
		"banshee_death": return "Банши: при смерти все герои получают -20 атаки на 1 ход."
		_:
			if key.ends_with("_gemini_copy"):
				return "Копия Близнецов: копирует полученный союзником бафф на себя."
			if key.begins_with("crab_search_treasure_"):
				return "Найденное сокровище: постоянный случайный бонус."
			if key.contains("voodoo") or key.contains("curse"):
				return "Проклятие: накладывает отрицательный эффект, заданный этой способностью."
			if stat == "trigger_marker":
				return "Уникальная метка способности."
			return ""
static func get_ability_marker_description(marker: String) -> String:
	match marker:
		"virgo_stars_decree": return "Все союзники получают бафф своей клетки звёзд на 2 хода."
		"virgo_starfall": return "Атакует цель и следующую позицию на 70% урона; все живые юниты получают +10 удачи на 2 хода."
		"virgo_innocent_touch": return "Атакует цель на 100% урона. Заклинатель теряет все свои баффы и получает +10 атаки на 2 хода за каждый снятый бафф."
		"titan_mighty_hit": return "Добавляет к урону часть атаки, зависящую от брони титана."
		"susanoo_sword_dance": return "Если цель погибает, Сусаноо повторяет атаку по следующей доступной цели."
		"set_usurp": return "Копирует ультимативную способность выбранного союзника до применения: иконка и эффект становятся как у скопированной ульты, после применения возвращается Узурпировать."
		"set_desert_power": return "Сила пустыни: следующий пустынный приём Сета срабатывает повторно."
		"scorpio_cruelty": return "Все живые юниты получают +10 атаки и -10 брони на 1 ход."
		"morgan_dark_dominion": return "За каждый дебафф на цели накладывает периодический урон 3% от максимального HP цели на 5 ходов."
		"loki_trickster_dance": return "+30 уклонения Локи на 2 хода, вперёд на 1; каждый враг получает -10 удачи на 2 хода; Локи получает +10 удачи за каждого врага на 2 хода."
		"koschei_hoard_gold": return "Снимает с себя дебаффы и получает защитный эффект через накопленное золото."
		"hades_soul_catcher": return "Если есть 15 фантазии, тратит 15 фантазии и лечит выбранного союзника на 15% его максимального HP."
		"dwarf_smith_upgrade": return "Расходует жетоны кузнеца: цель получает дополнительную броню и атаку на 2 хода за каждый жетон."
		"chernobog_terrifying_end": return "Если у Чернобога меньше 50% HP, удар не может промахнуться и наносит чистый урон."
		"chernobog_endless_horror": return "После срабатывания ужас не исчезает."
		"chernobog_whisper": return "Шёпот Чернобога: накладывает уникальный негативный эффект Чернобога на цель."
		"siren_to_the_bottom": return "Урон увеличивается на 50% за каждый дебафф на цели."
		"succubus_whip": return "Урон увеличивается на 10% за каждый дебафф на цели."
		"devil_punishment": return "Если у цели 0 величия, урон увеличивается на 80%."
		"rakshasa_vicious_strike": return "Если удача цели ниже 10%, урон становится чистым."
		"kirin_heaven_descent": return "Урон увеличивается на 10% за каждый бафф на цели."
		"koschei_disobedience": return "Урон увеличивается на процент брони Кощея."
		"koschei_needle_tip": return "Урон увеличивается на 60% за каждый потерянный заряд жизни Кощея."
		"hades_ash_to_ash": return "Урон увеличивается на 10% за каждый дебафф на цели."
		"hades_to_tartarus": return "Наносит урон от недостающего здоровья цели."
		"oni_crush_bones": return "Если ярость Они активна, получает +20% к удаче для этого удара."
		"immortal_eastern_blade": return "Пока щит смерти не израсходован, урон увеличен на 20%."
		"mummy_corrupting_touch": return "Урон увеличивается на 20% за каждый дебафф на цели."
		"morgan_black_lightning": return "Если в этом раунде было использовано заклинание, урон становится чистым."
		"shiva_trust_fate": return "Урон случайно уменьшается на 0-30%."
		"kappa_spear_strike": return "После попадания сразу срабатывает периодический урон цели."
		"naga_tail_strike": return "При критическом ударе оглушает цель."
		_: return ""


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
		"alraune_regen": return "Большой. Каждый ход восстанавливает 30% здоровья. Периодический урон отключает регенерацию."
		"flower_fairy_debuff_evasion": return "Когда противник получает дебафф — все союзники получают +3 уклонения на 1 ход"
		"thorn_fairy_debuff_damage": return "Когда противник получает дебафф — он получает 5 чистого урона"
		"druid_regen_aura": return "В начале раунда все союзники восстанавливают 5% здоровья"
		"unicorn_counter_accuracy": return "При атаке по нему атаковавший теряет 15 точности на 2 хода (даже при промахе)"
		"asura_noncrit_reduce": return "Получает на 50% меньше урона от некритических атак"
		"banshee_death_debuff": return "При смерти накладывает на всех героев -20 к атаке на 1 ход"
		"bird_death_damage": return "При смерти наносит урон всем противникам"
		"chernobog_uncurseable": return "Союзники не могут выбрать его целью способностей и марок"
		"coatl_crit_heal": return "При критическом ударе восстанавливает здоровье союзникам"
		"cupid_double_location": return "Купидон получает второй раз тот же штраф или бонус, который выбранная локация применяет к нему."
		"devil_forget_crit": return "Критические атаки усиливают забывание цели"
		"duna_heal_damage": return "Дуна: в конце хода получает атаку за часть здоровья, восстановленного в этот ход."
		"eel_counter_stun": return "При атаке по нему может оглушить атакующего"
		"golden_valkyrie": return "Когда золотая валькирия получает +10 уклонения от стойки, серебряная валькирия тоже получает +10 уклонения на 1 ход"
		"griffin_first_strike": return "Первая атака по Грифону в раунде вызывает ответный урон, равный атаке Грифона."
		"guardsman_killer_bonus": return "Если цель убивала союзника Стражника, Стражник получает +30 точности и +15% удачи для атаки по ней."
		"hellhound_missing_hp_damage": return "Адская гончая: +1% урона за каждый 1% недостающего HP цели."
		"indigo_fog_evasion": return "В туманный раунд получает +25 уклонения"
		"inquisitor_spell_immune": return "Иммунен к заклинаниям"
		"jester_fantasy_luck": return "Получает +1% удачи за каждую недостающую единицу фантазии."
		"jotun_fog": return "Пока жив, шанс туманного раунда увеличен"
		"kikimora_extended_debuffs": return "Кикимора: наложенные ею дебаффы длятся на 1 ход дольше."
		"knight_spell_cost_increase": return "Рыцарь: пока жив, все заклинания стоят на 2 фантазии дороже; со стойкой ещё на 2 дороже."
		"leshy_damage_per_debuff": return "Леший: наносит дополнительный урон за каждый дебафф на цели."
		"mentor_accuracy_aura": return "Все союзники получают +15 точности"
		"mermaid_depth_heal": return "В яростной глубине союзники лечатся вместо получения урона"
		"merwarrior_move_luck": return "При перемещении получает +10 удачи на 1 ход."
		"naga_monk_buff_duration": return "Нага-монах: баффы на союзниках длятся на 1 ход дольше."
		"naga_move_luck": return "После перемещения получает +7 удачи на 2 хода."
		"nanau_bloodlust": return "Наносит на 50% больше урона целям с периодическим уроном"
		"nightmare_majesty_damage": return "Кошмар: +1% урона за каждую единицу величия, которой цели не хватает до 100."
		"novice_transformation": return "Меняет форму в зависимости от позиции"
		"oboroten_round3_power": return "С третьего раунда оборотень получает боевую форму до конца боя; форма даёт регенерацию 10% HP и +15 точности на 3 хода при активации."
		"pegasus_ally_buff": return "Когда союзник получает бафф, Пегас получает +5 атаки навсегда"
		"princess_death_curse": return "Принцесса: при смерти убийца навсегда теряет 15% текущей брони и получает метку провокации до конца боя."
		"rakshasa_crit_aura": return "Пока жив, противники теряют 10 удачи"
		"samdi_extend_debuffs": return "Продлевает дебаффы на противниках"
		"saru_crit_evasion": return "Сару: при критическом ударе все союзные Сару получают +7% уклонения на 1 ход."
		"seawitch_double_depth": return "Морская ведьма: эффект Глубины для неё применяется в двойном размере."
		"silver_valkyrie": return "Когда серебряная валькирия получает +10 уклонения от стойки, золотая валькирия тоже получает +10 уклонения на 1 ход"
		"soul_position_buff": return "На первой позиции получает +4 инициативы и +20 уклонения"
		"succubus_god_resist": return "Получает меньше урона от богов"
		"tormentor_dot_regen": return "Когда союзник накладывает периодический урон, получает регенерацию"
		"triton_enemy_move_armor": return "Пассивка Тритона: когда враг перемещается, этот враг получает -10 брони на 1 ход."
		"troll_self_stun_on_no_damage": return "Если не получает урон, может оглушить себя"
		"utoplennitsa_location_amplify": return "В Топи штраф первой позиции дополнительно увеличивает накопленную потерю инициативы и брони."
		"vodyanoy_location_stun": return "В Топи при срабатывании болотного штрафа может наложить оглушение на цель."
		"wizard_fantasy_heal": return "Восстанавливает здоровье за потраченную фантазию"
		"satyr_redirect": return "Метка невинности: 50% шанс, что атака по нему перенесётся на случайного союзника"
		"": return ""
		_: return ""


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
