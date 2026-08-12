# Переработка формата миссий (архитектура)

Цель — дать автору (вам) простой, инспектор-ориентированный способ собирать
ветвящиеся миссии со всеми механиками из примера «Бесконечная ярость».

## Что должно поддерживаться
1. Ветвление диалогов: выбор → другая сцена с выборами.
2. Бой против построения с модификаторами юнитов (HP%, «заряды пассивки», баффы).
3. Награды: артефакт / эссенция / предмет / бог.
4. Условные выборы: доступно только при наличии конкретного бога.
5. Проверка характеристики с броском (рандом vs сложность → успех/провал → разные итоги).

## Ресурсы (новые/изменённые) — всё типизированное, видно в инспекторе

### MissionChoice (расширяется)
- `choice_text: String` — текст кнопки.
- `required_god: CharacterResource` — если задан, выбор активен только когда этот бог в отряде. (`null` = всегда.) → «Нужен Локи».
- `stat_check: StatCheck` (`null` = без проверки).
- `outcome: MissionOutcome` — что происходит (если проверки НЕТ).
- `success_outcome: MissionOutcome` — при успехе проверки.
- `failure_outcome: MissionOutcome` — при провале проверки.

### StatCheck (новый)
- `stat: enum {Attack, Initiative, Armor, Evasion, Accuracy, Crit, MaxHP}` — какая характеристика усредняется по команде.
- `stat_label: String` — подпись для игрока («Атака», «Инициатива»); можно автозаполнить из stat.
- `coefficient: float = 1.0` — множитель вклада среднего стата (потом вы решаете значение).
- `difficulty: int` — порог.
- **Правило**: `результат = randi_range(0,100) + floor(средний_стат_команды × коэффициент)`; **УСПЕХ если результат ≥ difficulty**.

### MissionOutcome (новый) — что происходит при разрешении выбора
- `result_text: String` — текст итога (показывается игроку).
- `next_scene: MissionSceneResource` — перейти к другому диалогу (`null` = завершить).
- `battle: BattleConfig` (`null` = без боя).
- `rewards: Array[Reward]` — выдать награды.

### BattleConfig (новый)
- `formation: FormationResource` — построение врагов (4 позиции).
- `location_override: MissionResource.Location` — локация боя (опц.).
- `enemy_modifiers: Array[UnitModifier]` — модификаторы на врагов.
- `hero_modifiers: Array[UnitModifier]` — модификаторы на героев.

### UnitModifier (новый) — модификатор юнита в предстоящем бою
- `target_position: int (0=все, 1..4)` — кого модифицировать.
- `hp_percent: int (0=не менять; 80=80% HP)`.
- `passive_charges: int (-1=не менять; 7=7 зарядов пассивки)`.
- `buffs: Array[Buff]`.

### Buff (новый)
- `stat: {Damage, Luck, Accuracy, Evasion, Armor, Crit, Initiative}`.
- `value: int` (−20 урон, +20 удача).
- `duration: int (-1=до конца боя, 1=1 ход)`.

### Reward (новый)
- `kind: {Item, Essence, God}`.
- `resource: Resource` (ItemResource / EssenceResource / CharacterResource).
- `amount: int` (для эссенций).

## Как авторится пример «Бесконечная ярость» (один MissionSceneResource)
- body_text = «Пробираясь через туман вы слышите скрежет…»
- choices:
  - **В1 «Быстро убить берсерка»** — stat_check(Атака, difficulty=D).
    - success_outcome: battle(formation=[Берсерк], enemy_mods=[pos1 hp10%, charges7]); result_text=«…превращается в едва живой останок».
    - failure_outcome: battle(formation=[Берсерк], enemy_mods=[pos1 hp80%, charges7]).
  - **В2 «Уходить»** — stat_check(Инициатива, E).
    - success_outcome: battle(formation=[Джаггернаут,Банши,Рейдер]); result_text=«…безумный берсерк остается позади».
    - failure_outcome: battle(formation=[Берсерк,Берсерк,Банши,Рейдер], enemy_mods=[pos1 hp80%, charges7, buff Luck+20 dur1]).
  - **В3 «Устроить дуэль»** — required_god=Локи; outcome: rewards=[Item «когти берсерка»], battle(formation=[Берсерк], enemy_mods=[pos1 hp80%, charges8, buff Damage−20 dur-1]); result_text=«…бросая оппоненту оружие».

## Runner (mission_scene.gd)
1. Рисует выборы; если `required_god` задан и его нет в отряде — кнопка выключена, подпись «(нужен Локи)».
2. По клику: если `stat_check` — бросок, выбираем success/failure_outcome; иначе `outcome`.
3. Применяет итог: показывает `result_text`, выдаёт `rewards`, настраивает бой (`formation`+моды+локация) или переходит к `next_scene`.
4. Моды боя применяются до старта через CombatManager (HP%, заряды, баффы на combatant).

## Решения, которые надо подтвердить
1. **Правило броска**: успех если `randi()%100+1 ≥ difficulty`. (Альтернатива: difficulty = шанс успеха %, успех если бросок ≤ difficulty.)
2. **«Заряды пассивки»**: общее поле `passive_charges`, которое ставится на combatant; логика берсерка должна его учитывать (нужен хук в Combatant/battle_scene). Подтвердить, что у берсерка есть/должен быть счётчик зарядов.
3. **Обратная совместимость**: старые поля MissionChoice (formation/launch_battle/next_scene) — мигрировать в outcome (чисто) или оставить как fallback. Предлагаю мигрировать.
4. **Расположение автора**: всё вкладывается в инспектор (choice → stat_check + 1..3 outcome → battle/rewards/next_scene). Подходит ли такая вложенность, или нужно ещё проще (напр. плоский список эффектов)?
