extends RefCounted
class_name CampaignStory

## Сюжетные диалоги и обучение на экране кампании: Миф, диалоги богов, первый бой, врата/двери, призыв.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

## Кнопка рядом с портретом Мифа: сразу отмечает стартовую миссию (First_battle)
## пройденной и проигрывает After_first_battle — тот же итог, что и после реального
## прохождения миссии (см. _check_first_battle_mission_return), без самого боя.
func _on_skip_first_mission_button_pressed() -> void:
	CampaignState.before_first_battle_played = true
	CampaignState.first_battle_completed = true
	if _screen._myth_skip_button != null and is_instance_valid(_screen._myth_skip_button):
		_screen._myth_skip_button.queue_free()
		_screen._myth_skip_button = null
	DialogueManager.show_dialogue_path(CampaignScreen.AFTER_FIRST_BATTLE_DIALOGUE_PATH)

## До прохождения First_battle — Myth_before_mission. После — обычный Myth_dialogue_1.
func _on_myth_dialogue_button_pressed() -> void:
	if not CampaignState.first_battle_completed and ResourceLoader.exists(CampaignScreen.MYTH_BEFORE_MISSION_DIALOGUE_PATH):
		DialogueManager.show_dialogue_path(CampaignScreen.MYTH_BEFORE_MISSION_DIALOGUE_PATH)
		return
	for dialogue_path in CampaignScreen.MYTH_DIALOGUE_CANDIDATES:
		if ResourceLoader.exists(dialogue_path):
			DialogueManager.show_dialogue_path(dialogue_path)
			return
	push_warning("Диалог Мифа не найден")

## Первый раз, когда в ростере оказалось REQUIRED_GODS_FOR_FIRST_BATTLE богов —
## помечает Before_first_battle как "ожидает показа". Флаг одноразовый, обратного
## пути нет. Сам диалог показывается через _flush_pending_before_first_battle_dialogue(),
## а не отсюда напрямую: если 5-й бог только что создан в Саду творения, следом
## сразу показывается его диалог призыва, а DialogueManager.show_dialogue_path()
## закрывает текущий проигрываемый диалог при показе нового — так что Before_first_battle,
## показанный прямо здесь, тут же обрывался бы диалогом призыва бога.
func _check_first_battle_intro_dialogue() -> void:
	if CampaignState.before_first_battle_played:
		return
	if CampaignState.available_gods.size() < CampaignScreen.REQUIRED_GODS_FOR_FIRST_BATTLE:
		return
	CampaignState.before_first_battle_played = true
	_screen._before_first_battle_dialogue_pending = true

## Показывает Before_first_battle, если он ждал своей очереди (см. комментарий выше).
func _flush_pending_before_first_battle_dialogue() -> void:
	if not _screen._before_first_battle_dialogue_pending:
		return
	_screen._before_first_battle_dialogue_pending = false
	DialogueManager.show_dialogue_path(CampaignScreen.BEFORE_FIRST_BATTLE_DIALOGUE_PATH)

## Показывает одноразовую реплику, поставленную в очередь сценой миссии перед
## возвратом на экран кампании (см. MissionState.pending_campaign_dialogue_path).
func _flush_pending_campaign_dialogue() -> void:
	var path := MissionState.pending_campaign_dialogue_path.strip_edges()
	if path == "":
		return
	MissionState.pending_campaign_dialogue_path = ""
	if ResourceLoader.exists(path):
		DialogueManager.show_dialogue_path(path)

## DEBUG-хоткей (Ctrl+Shift+F9, только в debug-сборке): отмечает First_battle
## пройденной, чтобы проверять диалоги/двери ПОСЛЕ неё, не переигрывая бой
## каждый раз. before_doors_played сбрасывается в false, чтобы Before_doors
## можно было увидеть повторно при следующем клике на ворота.
## Не заменяет призыв REQUIRED_GODS_FOR_FIRST_BATTLE богов — он всё ещё нужен, чтобы клик по воротам вообще
## дошёл до проверки first_battle_completed (см. _on_gates_clicked).
func _debug_skip_first_battle() -> void:
	CampaignState.before_first_battle_played = true
	CampaignState.first_battle_completed = true
	CampaignState.before_doors_played = false
	print("[DEBUG] First_battle пропущена: before_first_battle_played=true, first_battle_completed=true, before_doors_played=false")

## Если мы только что вернулись с миссии First_battle — отмечаем её пройденной
## и один раз проигрываем After_first_battle.
func _check_first_battle_mission_return() -> void:
	if MissionState.last_completed_mission_path != CampaignScreen.FIRST_BATTLE_MISSION_PATH:
		return
	MissionState.last_completed_mission_path = ""
	CampaignState.first_battle_completed = true
	DialogueManager.show_dialogue_path(CampaignScreen.AFTER_FIRST_BATTLE_DIALOGUE_PATH)

func _on_god_dialogue_requested(god_path: String) -> void:
	if god_path.strip_edges() == "":
		return
	var god_res := CampaignState.load_character_resource(god_path)
	if god_res == null:
		return
	var dialogue_path := CampaignState.dialogue_path_for_god(god_path)
	if dialogue_path == "":
		push_warning("Диалог бога не найден: " + god_res.unit_name)
		return
	_screen._active_god_dialogue_path = god_path
	DialogueManager.show_dialogue_path(dialogue_path)

## Реплика "Открыть дверь" есть в диалоге каждого бога (choice_id = "open_door").
## Как только игрок её выбирает — соответствующая богу локация (см.
## CampaignState.GOD_FOLDER_TO_LOCATION) считается открытой: на экране Ворот её
## дверь сменит спрайт на открытый, а если для неё уже есть миссия
## "Welcome_to_<локация>" — она станет доступна для входа через эту дверь.
func _on_dialogue_choice_selected(_dialogue_id: String, choice_id: String) -> void:
	if choice_id != CampaignScreen.OPEN_DOOR_CHOICE_ID or _screen._active_god_dialogue_path == "":
		return
	var folder_name := _screen._active_god_dialogue_path.get_base_dir().get_file()
	var location: String = str(CampaignState.GOD_FOLDER_TO_LOCATION.get(folder_name, ""))
	if location == "":
		return
	var was_first_location_opened := CampaignState.opened_locations.is_empty()
	CampaignState.open_location(location)
	_screen._map._update_tutorial_room_highlight()
	if was_first_location_opened and not CampaignState.room_hints_shown:
		CampaignState.room_hints_shown = true
		# Не сразу — диалог с богом обычно продолжается после самого выбора "Открыть
		# дверь" (реплики благодарности и т.п.). Показываем подсказки только когда
		# ТЕКУЩИЙ диалог реально закроется, иначе они виснут под ним.
		if DialogueManager.dialogue_finished.is_connected(_on_open_door_dialogue_finished):
			DialogueManager.dialogue_finished.disconnect(_on_open_door_dialogue_finished)
		DialogueManager.dialogue_finished.connect(_on_open_door_dialogue_finished, Object.CONNECT_ONE_SHOT)

func _on_open_door_dialogue_finished(_dialogue_id: String) -> void:
	_screen._active_tutorial_hints += 1
	TutorialHint.show_sequence(_screen, TutorialTexts.room_hints(), "Понятно", func(): _screen._active_tutorial_hints -= 1)


# ════════════════════════════════════════════════════════════
#  Переключение вкладок
# ════════════════════════════════════════════════════════════

## Ворота проходят несколько состояний по мере продвижения сюжета:
## 1) < REQUIRED_GODS_FOR_FIRST_BATTLE богов → Gates_wrong (каждый раз, это просто предупреждение).
## 2) богов достаточно, но First_battle ещё не пройдена → сразу запускается миссия First_battle.
## 3) First_battle пройдена, ни одна дверь ещё не открыта → Миф объясняет, что не может
##    открыть ворота сам (Before_doors), и игрок остаётся на экране кампании — см.
##    _on_before_doors_finished(). Двери открываются только когда какой-то бог их откроет
##    (CampaignState.open_location(), см. _on_dialogue_choice_selected).
## 4) Хотя бы одна дверь уже открыта → ворота ведут прямо на экран дверей.
func _on_gates_clicked() -> void:
	# Если First_battle уже отмечена пройденной (в т.ч. через кнопку "Пропустить
	# стартовую миссию"), ворота считают, что богов достаточно, и эту проверку не делают.
	if not CampaignState.first_battle_completed and CampaignState.available_gods.size() < CampaignScreen.REQUIRED_GODS_FOR_FIRST_BATTLE:
		DialogueManager.show_dialogue_path(CampaignScreen.GATES_WRONG_DIALOGUE_PATH)
		return
	if not CampaignState.first_battle_completed:
		_launch_first_battle_mission()
		return
	if CampaignState.opened_locations.is_empty():
		if not CampaignState.before_doors_played:
			CampaignState.before_doors_played = true
			if DialogueManager.dialogue_finished.is_connected(_on_before_doors_finished):
				DialogueManager.dialogue_finished.disconnect(_on_before_doors_finished)
			DialogueManager.dialogue_finished.connect(_on_before_doors_finished, Object.CONNECT_ONE_SHOT)
			DialogueManager.show_dialogue_path(CampaignScreen.BEFORE_DOORS_DIALOGUE_PATH)
		else:
			_show_ask_a_god_hint()
		return
	_screen.get_tree().change_scene_to_file(CampaignScreen.DOORS_SCENE_PATH)

func _on_before_doors_finished(_dialogue_id: String) -> void:
	_show_ask_a_god_hint()

## Тот же формат, что и боевые подсказки: блокирует экран, требует "Всё понятно".
## После показа — ворота перестают мигать (см. _tutorial_highlighted_room_section()),
## хотя формально остаются заблокированы для клика, пока дверь не откроет бог.
func _show_ask_a_god_hint() -> void:
	CampaignState.ask_a_god_hint_shown = true
	_screen._map._update_tutorial_room_highlight()
	_show_blocking_tutorial_hint(TutorialTexts.ASK_A_GOD_HINT, "Всё понятно")

## Обёртка над TutorialHint.present() для одиночных (не-последовательных) подсказок
## на экране кампании — держит _active_tutorial_hints синхронизированным, чтобы
## клики по комнатам оставались заблокированы, пока подсказка на экране (см.
## _campaign_room_input_is_blocked()). show_sequence() в _on_dialogue_choice_selected
## делает то же самое сама, отдельным колбэком on_all_dismissed.
func _show_blocking_tutorial_hint(text: String, button_text: String = "Понятно") -> void:
	_screen._active_tutorial_hints += 1
	var hint := TutorialHint.present(_screen, text, button_text)
	if hint == null:
		_screen._active_tutorial_hints -= 1
		return
	hint.dismissed.connect(func(): _screen._active_tutorial_hints -= 1)

func _launch_first_battle_mission() -> void:
	MissionState.requested_mission_path = CampaignScreen.FIRST_BATTLE_MISSION_PATH
	MissionState.return_scene_path = "res://Campaign/campaign_screen.tscn"
	_screen.get_tree().change_scene_to_file("res://Missions/mission_select.tscn")

func _play_summon_dialogue_for_god(god_path: String) -> void:
	var dialogue_path := _summon_dialogue_path_for_god(god_path)
	if dialogue_path == "" or not ResourceLoader.exists(dialogue_path):
		_flush_pending_before_first_battle_dialogue()
		return
	if DialogueManager.dialogue_finished.is_connected(_on_summon_dialogue_finished):
		DialogueManager.dialogue_finished.disconnect(_on_summon_dialogue_finished)
	DialogueManager.dialogue_finished.connect(_on_summon_dialogue_finished, Object.CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_path(dialogue_path)

func _on_summon_dialogue_finished(_dialogue_id: String) -> void:
	_flush_pending_before_first_battle_dialogue()

func _summon_dialogue_path_for_god(god_path: String) -> String:
	var folder_name := god_path.get_base_dir().get_file()
	if folder_name.strip_edges() == "":
		return ""
	return "%s/%s_summon.tres" % [CampaignScreen.SUMMON_DIALOGUE_DIR, folder_name]

# ════════════════════════════════════════════════════════════
#  Действия меню
# ════════════════════════════════════════════════════════════
