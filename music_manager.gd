extends Node
## Автозагрузчик — фоновая музыка кампании и миссий. Переживает смену сцен
## (get_tree().change_scene_to_file), поэтому логика "продолжать/прервать между
## экранами" живёт здесь, а не в конкретных screen-скриптах, которые сами
## пересоздаются при каждом переходе.
##
## Правила (по просьбе):
## - Кампания (Campaign_background.mp3): играет на экране кампании, СНАЧАЛА при
##   каждом входе (не бесшовно) — см. play_campaign(). Останавливается ровно в
##   момент выбора локации за дверью — см. stop_campaign() (Doors/doors.gd).
## - "non_battle" трек локации: играет с момента входа в меню выбора миссии
##   (Missions/mission_select.gd) — see play_mission_non_battle() — и не
##   прерывается на всём протяжении сцен/выборов миссии, пока не начнётся бой.
## - "battle" трек локации: только на время самого боя в этой локации — см.
##   play_battle() (battle_scene.gd::_ready()). После боя non_battle трек
##   возобновляется с той же позиции, где был прерван — см.
##   resume_mission_non_battle() (battle_scene.gd::_exit_tree()).
## - stop_mission() — полная остановка при завершении миссии/возврате в кампанию
##   (Missions/mission_scene.gd::_complete_mission_return()).

const CAMPAIGN_MUSIC := "res://Sounds/Music/Campaign_background.mp3"

## location_id (MissionResource.LOCATION_IDS) → {"battle": путь, "non_battle": путь}.
## Пустая строка/отсутствующий ключ = трека для этой роли в этой локации ещё нет —
## соответствующий play_*()/переключение тогда просто не проигрывает ничего.
const LOCATION_MUSIC := {
	"castle": {
		"battle": "res://Sounds/Location_Backgrounds/Castle_battle_music.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Castle_non_battle.mp3",
	},
	"desert": {
		"battle": "res://Sounds/Location_Backgrounds/Desert_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Desert_non_battle.mp3",
	},
	"jungle": {
		"battle": "res://Sounds/Location_Backgrounds/Jungle_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Jungle_non_battle.mp3",
	},
	"stars": {
		"battle": "res://Sounds/Location_Backgrounds/Stars.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/stars_non_battle.mp3",
	},
	"mountains": {
		"battle": "res://Sounds/Location_Backgrounds/Mountain_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Mountain_non_battle.mp3",
	},
	"ships": {
		"battle": "res://Sounds/Location_Backgrounds/Ships_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Ships_non_battle.mp3",
	},
	"helheim": {
		"battle": "res://Sounds/Location_Backgrounds/Helheim_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Helheim_non_battle.mp3",
	},
	"hell": {
		"battle": "res://Sounds/Location_Backgrounds/hell_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Hell_non_battle.mp3",
	},
	"tunnels": {
		"battle": "res://Sounds/Location_Backgrounds/tunnels_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/tunnels_non_battle.mp3",
	},
	"clouds": {
		"battle": "res://Sounds/Location_Backgrounds/Clouds_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Clouds_non_battle.mp3",
	},
	"arena": {
		"battle": "res://Sounds/Location_Backgrounds/Arena_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Arena_non_battle.mp3",
	},
	"depths": {
		"battle": "res://Sounds/Location_Backgrounds/Depth_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Depth_non_battle.mp3",
	},
	"garden": {
		"battle": "res://Sounds/Location_Backgrounds/Garden_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/garden_non_battle.mp3",
	},
	"island": {
		"battle": "res://Sounds/Location_Backgrounds/Islands_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Islands_non_battle.mp3",
	},
	"swamp": {
		"battle": "res://Sounds/Location_Backgrounds/Marsh_battle.mp3",
		"non_battle": "res://Sounds/Location_Backgrounds/Marsh_non_battle.mp3",
	},
}

var _player: AudioStreamPlayer = null
## Путь non_battle-трека, логически активного для текущей миссии — используется,
## чтобы после боя возобновить именно его (resume_mission_non_battle()).
var _mission_non_battle_path: String = ""
## Позиция non_battle-трека на момент, когда его прервали ради боевой музыки.
var _mission_non_battle_position: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	add_child(_player)

func play_campaign() -> void:
	_mission_non_battle_path = ""
	_mission_non_battle_position = 0.0
	_set_stream(CAMPAIGN_MUSIC, 0.0)

func stop_campaign() -> void:
	if _player.stream != null and _player.stream.resource_path == CAMPAIGN_MUSIC:
		_stop()

func play_mission_non_battle(location_id: String) -> void:
	var path: String = str((LOCATION_MUSIC.get(location_id, {}) as Dictionary).get("non_battle", ""))
	# Идемпотентно: экран выбора миссии локации (Doors/mission_choice_screen.gd) и экран
	# подготовки отряда (Missions/mission_select.gd) оба вызывают это при входе — если
	# трек этой же локации уже играет без перерыва, повторный вызов не должен рвать и
	# перезапускать его с нуля (это нарушило бы "не прекращается, пока не начнётся бой").
	if path != "" and _mission_non_battle_path == path and _player.playing and _player.stream != null and _player.stream.resource_path == path:
		return
	_mission_non_battle_path = path
	_mission_non_battle_position = 0.0
	if path == "":
		_stop()
		return
	_set_stream(path, 0.0)

func play_battle(location_id: String) -> void:
	if _player.playing:
		_mission_non_battle_position = _player.get_playback_position()
	var path: String = str((LOCATION_MUSIC.get(location_id, {}) as Dictionary).get("battle", ""))
	if path == "":
		_stop()
		return
	_set_stream(path, 0.0)

func resume_mission_non_battle() -> void:
	if _mission_non_battle_path == "":
		_stop()
		return
	_set_stream(_mission_non_battle_path, _mission_non_battle_position)

func stop_mission() -> void:
	_mission_non_battle_path = ""
	_mission_non_battle_position = 0.0
	_stop()

func _set_stream(path: String, position: float) -> void:
	if not ResourceLoader.exists(path):
		_stop()
		return
	var stream := load(path) as AudioStream
	if stream == null:
		_stop()
		return
	# Зацикливаем сам поток — не полагаемся на сигнал finished/ручной replay, так
	# нет крошечного разрыва звука между повторами.
	if "loop" in stream:
		stream.loop = true
	_player.stream = stream
	_player.play(position)

func _stop() -> void:
	_player.stop()
	_player.stream = null
