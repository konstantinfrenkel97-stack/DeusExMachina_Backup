# Effects — структурированные эффекты исходов

`MissionOutcome.effects: Array[MissionEffect]` — новый способ описывать побочные эффекты
исхода выбора (баффы, изменение HP/величия и т.п.), взамен добавления очередного плоского
поля в `MissionOutcome` на каждую комбинацию "кому / насколько долго".

Применяются в `mission_scene.gd::_apply_effects()`, **после** остальных (не перенесённых)
полей того же `MissionOutcome`. Диспетчер ничего не знает о конкретных видах эффектов — каждый сам
реализует `apply()`. Добавление нового вида эффекта = новый файл-наследник `MissionEffect`,
без правок диспетчера.

## Что уже перенесено сюда

| Эффект | Поле `target` | Заменяет старые поля MissionOutcome |
|---|---|---|
| `HeroBuffEffect` | TEAM / SPECIFIC / RANDOM / STRONGEST_ATTACK / STRONGEST_ARMOR | `hero_buffs(+until_mission_end)`, `target_god+target_buffs(+until_mission_end)`, `target_random_hero_buffs(+preferred_god, +until_mission_end)`, `strongest_hero_buffs` |
| `HeroHpDeltaEffect` | TEAM / SPECIFIC / RANDOM | `hero_heal_percent` (immediate=true + heal_item_bonus=true), `hero_hp_percent_delta`, `hero_hp_flat_delta`(только с `immediate=true`), `random_hero_hp_percent_delta`, `target_god+target_current_hp_percent_delta`, `target_god_immediate+target_god_immediate_hp_percent_delta` |
| `HeroMajestyDeltaEffect` | TEAM / SPECIFIC / RANDOM | `hero_majesty_delta` (immediate=true), `target_god+target_majesty_delta`, `target_god_immediate+target_god_immediate_majesty_delta` (immediate=true) |
| `EnemyBuffEffect` | — (всегда все враги, следующий бой) | `enemy_buffs` |

**Все перечисленные в таблице старые поля УДАЛЕНЫ из `MissionOutcome` и из `mission_scene.gd`;
все 107 сцен мигрированы на `effects`** (207 эффектов). Использовать старые имена больше нельзя.

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
`apply()`), а не в момент старта следующего боя. Бывший `strongest_hero_buffs` (выбор по
живому `Combatant` на старте боя) мигрирован в `STRONGEST_ATTACK` + `UNTIL_MISSION_END` — это
осознанное изменение тайминга. `SPECIFIC` (как и legacy `target_god`) требует лишь, чтобы бог
не был мёртв, но НЕ обязательно состоял в отряде миссии.

`TEAM` + `ONE_BATTLE`/`UNTIL_MISSION_END` для `HeroBuffEffect` идёт тем же каналом, что и
legacy `hero_buffs` (`pending_mission_hero_buffs` / `mission_team_buffs` — бьёт всех бойцов
команды в бою), поэтому поведение идентично.

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
- **Получение награды** (`rewards`) — уже отдельный массив `MissionOutcome.rewards` со своим
  пайплайном; обёртка в `MissionEffect` пока не нужна.

Если нужного эффекта среди классов выше нет — используйте соответствующее поле
`MissionOutcome` напрямую, как раньше. Это не ошибка и не "забыли перенести" — так и задумано.

## Миграция сцен (выполнена)

Скрипт переписал 107 файлов `Scenes/**/*.tres` (230 использований legacy-полей → 207 эффектов).
Правила: `hero_heal_percent` → `HeroHpDeltaEffect(immediate, heal_item_bonus)`; `hero_hp_*` →
`HeroHpDeltaEffect(TEAM, immediate)`; `random_hero_hp_percent_delta` → `RANDOM, immediate`;
`hero_majesty_delta` → `HeroMajestyDeltaEffect(TEAM, immediate)`; `target_*` → `SPECIFIC`
(+`UNTIL_MISSION_END` по флагу); `target_god_immediate*` → `SPECIFIC, immediate`;
`hero_buffs` → `HeroBuffEffect(TEAM)`; `enemy_buffs` → `EnemyBuffEffect`;
`strongest_hero_buffs` → `STRONGEST_ATTACK + UNTIL_MISSION_END`.

Проверка до удаления полей: headless-сравнение состояния (HP, величие, очереди баффов) для
694 исходов — эмуляция старой логики на исходных сценах против `effects.apply()` на
мигрированных — 0 расхождений (183 исхода с ненулевым эффектом).

## Как добавить новый вид эффекта

1. Новый файл в этой папке, `extends MissionEffect` (или `extends HeroTargetEffect`, если
   эффект тоже бьёт по "одному/нескольким/всем богам отряда" — переиспользуйте выбор цели).
2. Переопределить `apply() -> void`.
3. В сцене — `Add Element` в поле **Effects** ресурса `MissionOutcome` → New <ВашКласс>.

Ничего в `mission_scene.gd` менять не нужно.
