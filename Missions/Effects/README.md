# Effects — структурированные эффекты исходов

`MissionOutcome.effects: Array[MissionEffect]` — новый способ описывать побочные эффекты
исхода выбора (баффы, изменение HP/величия и т.п.), взамен добавления очередного плоского
поля в `MissionOutcome` на каждую комбинацию "кому / насколько долго".

Применяются в `mission_scene.gd::_apply_effects()`, **после** всех старых (legacy) полей
того же `MissionOutcome`. Диспетчер ничего не знает о конкретных видах эффектов — каждый сам
реализует `apply()`. Добавление нового вида эффекта = новый файл-наследник `MissionEffect`,
без правок диспетчера.

## Что уже перенесено сюда

| Эффект | Поле `target` | Заменяет старые поля MissionOutcome |
|---|---|---|
| `HeroBuffEffect` | TEAM / SPECIFIC / RANDOM / STRONGEST_ATTACK / STRONGEST_ARMOR | `hero_buffs(+until_mission_end)`, `target_god+target_buffs(+until_mission_end)`, `target_random_hero_buffs(+preferred_god, +until_mission_end)`, `strongest_hero_buffs` |
| `HeroHpDeltaEffect` | TEAM / SPECIFIC / RANDOM | `hero_heal_percent` (immediate=true + heal_item_bonus=true), `hero_hp_percent_delta`, `hero_hp_flat_delta`(только с `immediate=true`), `random_hero_hp_percent_delta`, `target_god+target_current_hp_percent_delta`, `target_god_immediate+target_god_immediate_hp_percent_delta` |
| `HeroMajestyDeltaEffect` | TEAM / SPECIFIC / RANDOM | `hero_majesty_delta`, `target_god+target_majesty_delta` |

"Кому" (`target`) и "насколько долго" (`duration` на `HeroBuffEffect` / `immediate` на
`HeroHpDeltaEffect`) — независимые настройки ОДНОГО эффекта, а не разные поля под каждую
комбинацию.

### WHO: `target` (на `HeroTargetEffect`, общий для всех трёх классов выше)

- `TEAM` — все живые боги отряда миссии.
- `SPECIFIC` — заранее выбранный бог (`specific_god`).
- `RANDOM` — случайный живой бог отряда; если задан `preferred_god` и он жив в отряде —
  приоритет ему.
- `STRONGEST_ATTACK` / `STRONGEST_ARMOR` — живой бог отряда с наибольшим БАЗОВЫМ
  `damage`/`armor` на `CharacterResource` (без учёта временных баффов боя — они ещё не
  наложены). При равенстве — первый по порядку в отряде.

**Важно про тайминг** (дизайнерское решение): все варианты `target`, включая
`STRONGEST_ATTACK`/`STRONGEST_ARMOR`, вычисляются В МОМЕНТ РАЗРЕШЕНИЯ ИСХОДА СЦЕНЫ (вызова
`apply()`), а не в момент старта следующего боя. Старое поле `strongest_hero_buffs`
вычисляло цель иначе — по живому `Combatant` в момент старта боя (с учётом уже применённых
модификаторов) — это поведение сохранено как есть для старых сцен (не трогали), но новый
`effects`-путь ему не обязан соответствовать по таймингу: это осознанное изменение, а не
несогласованность.

### HOW LONG: `duration` на `HeroBuffEffect`

- `ONE_BATTLE` (по умолчанию) — одноразово, в ближайшем следующем бою.
- `UNTIL_MISSION_END` — держится до конца миссии, применяется в каждом бою, пока цель жива;
  снимается, когда миссия заканчивается (как и раньше с `mission_team_buffs`/`mission_target_buffs`).
- `PERMANENT` — навсегда. Сохраняется в `CampaignState.permanent_god_buffs` (переживает
  сохранение/загрузку игры, см. `save_system.gd`), применяется в КАЖДОМ бою этого бога до
  конца игры (`Battle/battle_start.gd::_apply_pending_mission_party_effects()`), не снимается
  по завершении миссии. В отличие от `permanent_god_crit_bonus`/`permanent_god_max_hp_bonus`
  (узкие, встроенные прямо в `combatant.gd::_init()`, умеют только крит и макс. HP) — это
  общий канал для ЛЮБОГО `BuffEntry.Stat`, через тот же механизм применения баффов миссии,
  что и `mission_target_buffs`.

## Иммунитет локации — вариант стандартной награды, а не эффект сцены

Иммунитет к эффекту локации (Пустыня/Ад/Остров/туман Хельхейма) — не `MissionEffect`, а
**вид `Reward`** (`Reward.Kind.LOCATION_IMMUNITY` + `location_immunity_tags: Array[String]`,
теги `"desert"`/`"hell"`/`"island"`/`"helheim_fog"`), см. `Missions/reward.gd`. Добавляется в
`MissionOutcome.rewards`, как обычная награда — уже применяется существующим пайплайном
наград (`mission_scene.gd::_grant_and_record_reward`), без правок диспетчера.

Под капотом все 4 иммунитета — теперь ОДНА очередь, `CombatManager.pending_location_immunities:
Array[String]`, а не 4 разных булевых/целочисленных поля, как было раньше. Старые 4 поля
`MissionOutcome` (`grant_desert_immunity_next_battle`, `grant_hell_immunity_next_battle`,
`grant_island_immunity_next_battle`, `skip_helheim_fog_first_round`) сохранены для старых
сцен — работают как раньше, просто внутри тоже пишут в этот же единый массив
(`mission_scene.gd`, конец `_apply_outcome_mission_effects`).

`"desert"`/`"hell"`/`"island"` расходуются целиком в начале СЛЕДУЮЩЕГО боя, независимо от его
локации (как и раньше). `"helheim_fog"` — особый случай: не трогается при старте боя, живёт в
массиве, пока его не заберёт `battle_locations.gd::_location_helheim()` в бою, где локация
реально Хельхейм (по одному заряду за туманный раунд — несколько зарядов = несколько записей
тега в массиве, как раньше `pending_helheim_skip_fog_rounds > 0`).

## Что сознательно НЕ перенесено (остаётся как legacy-поле MissionOutcome)

Переносить стоит только то, что реально повторяется в разных сценах с разными целями/сроком —
остальное использовалось точечно 1–2 раза и не выигрывает от обобщения, либо имеет другую
природу (другой момент вычисления, другой канал применения):

- **`target_god_immediate_majesty_delta`** — немедленное величие без боя; для величия такого
  канала в движке никогда не было, расширять `pending_mission_target_effects` под это не стали.
- **Немезис-эффекты** (`nemesis_buff_*`, `nemesis_enemy_*`) — откладываются до боя с конкретным
  немезидом локации, не до "следующего боя"; отдельная, более сложная система ожидания.
- **Счётчик отдыха** (`rest_counter_*`), **узкие постоянные бонусы на всю игру**
  (`permanent_enemy_debuff_*`, `permanent_god_crit_bonus_*`, `permanent_god_max_hp_bonus_*` —
  крит/макс.HP остались отдельными узкими полями `CampaignState`, не через `permanent_god_buffs`,
  т.к. это не `BuffEntry.Stat`, а отдельные механики), **постбоевые эффекты этого конкретного
  боя** (`zero_hero_majesty_after_battle`, `restore_hero_hp_to_pre_battle_after_battle`),
  **реплика "Рома" на всю команду** (`rum_spell_whole_team_next_battle`) — каждое встречается
  точечно, не дублируется под разные цели, переносить в отдельный класс эффекта сейчас не даёт
  выигрыша. Если какой-то из них обрастёт вариациями ("то же самое, но другому богу" / "то же
  самое, но на N боёв") — тогда и стоит выносить в `MissionEffect`.
- **Баффы на врагов** (`enemy_buffs`) и **получение награды** (`rewards`) — пока не обёрнуты в
  отдельные классы эффектов (`EnemyBuffEffect`/`GrantRewardEffect`), хотя это запланировано:
  `enemy_buffs` всегда "все враги, следующий бой" (без вариативности цели — WHO тут не нужен),
  `rewards` уже и так отдельный массив `MissionOutcome.rewards`, применяемый отдельным
  пайплайном (см. выше про иммунитет локации) — обёртка в `MissionEffect` добавила бы
  единообразия, но пока не выбирающая ничего не ломает.

Если нужного эффекта среди классов выше нет — используйте соответствующее поле
`MissionOutcome` напрямую, как раньше. Это не ошибка и не "забыли перенести" — так и задумано.

## Результат аудита сцен (legacy-поля группы A)

Найдено 230 использований в 107 файлах `Scenes/**/*.tres`: `hero_buffs` 58, `hero_heal_percent` 37,
`hero_majesty_delta` 35, `hero_hp_percent_delta` 23, `target_god` 19, `strongest_hero_buffs` 15,
`target_buffs` 11, `target_god_immediate` 7, `target_majesty_delta` 6, `enemy_buffs` 6, остальные <5.
Исправлено: `hero_heal_percent` и `hero_majesty_delta` в legacy применяются НЕМЕДЛЕННО (раньше в этом
README было указано иначе — это была ошибка). Эффекты теперь это учитывают (`immediate`,
`heal_item_bonus`). Ещё НЕ идентичны: `hero_buffs` (legacy бьёт всех `Combatant` команды в бою,
эффект TEAM — только живых из `CombatManager.mission_heroes`).

## Что ЕЩЁ НЕ сделано (миграция существующих сцен)

Группа "безопасно/стандартизировано" (`hero_buffs`, `target_buffs`, `target_random_hero_buffs`,
`strongest_hero_buffs`, `hero_heal_percent`/`hero_hp_percent_delta`/`hero_hp_flat_delta`/
`random_hero_hp_percent_delta`/`target_current_hp_percent_delta`/
`target_god_immediate_hp_percent_delta`, `hero_majesty_delta`/`target_majesty_delta`) уже имеет
эквивалент в `effects`, и правка старого применяющего кода в `mission_scene.gd` для НИХ
разрешена — но сами legacy-поля из `MissionOutcome` и их применение в `mission_scene.gd` ЕЩЁ НЕ
удалены, потому что сначала нужно найти и перенести все существующие использования этих полей
среди ~170 файлов сцен (`Scenes/**/*.tres`) на новый `effects`, иначе удаление полей молча
отключит эффект в этих сценах при загрузке. Это отдельная задача аудита/миграции, не сделанная
в этом проходе.

## Как добавить новый вид эффекта

1. Новый файл в этой папке, `extends MissionEffect` (или `extends HeroTargetEffect`, если
   эффект тоже бьёт по "одному/нескольким/всем богам отряда" — переиспользуйте выбор цели).
2. Переопределить `apply() -> void`.
3. В сцене — `Add Element` в поле **Effects** ресурса `MissionOutcome` → New <ВашКласс>.

Ничего в `mission_scene.gd` менять не нужно.
