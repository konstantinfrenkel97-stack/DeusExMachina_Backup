extends Node
## Автозагружаемый синглтон (GameSettings). Хранит пользовательские настройки
## (звук, экран, язык, геймплей), применяет их сразу и сохраняет в user://settings.cfg.
## Настройки — это НЕ прогресс игрока (для этого есть SaveSystem): один файл на
## компьютер, переживает любые сохранения/загрузки партии.

const SETTINGS_PATH := "user://settings.cfg"

# ── Звук (0.0..1.0, применяется на шины AudioServer) ──
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var master_muted: bool = false

# ── Экран ──
var fullscreen: bool = true

# ── Геймплей ──
var confirm_before_surrender: bool = true
# По умолчанию боевой лог свёрнут (текущее поведение battle_scene.gd) — здесь
# хранится обратное, "развёрнут ли лог по умолчанию", чтобы имя поля читалось понятно.
var combat_log_expanded_default: bool = false
# Множитель скорости боя (Engine.time_scale, включается только в battle_scene.gd).
var battle_speed: float = 1.0
const BATTLE_SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]

# ── Язык (см. Localization autoload — реально переключает TranslationServer) ──
var language: String = "ru"

signal settings_changed


func _ready() -> void:
	_ensure_audio_buses()
	_load()
	_apply_audio()
	_apply_fullscreen()
	_apply_language()


## Создаёт шины "Music" и "SFX" при первом запуске (в проекте нет заранее
## сохранённого bus layout — шины существуют только в рантайме AudioServer).
func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	master_muted = bool(cfg.get_value("audio", "master_muted", master_muted))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	confirm_before_surrender = bool(cfg.get_value("gameplay", "confirm_before_surrender", confirm_before_surrender))
	combat_log_expanded_default = bool(cfg.get_value("gameplay", "combat_log_expanded_default", combat_log_expanded_default))
	battle_speed = float(cfg.get_value("gameplay", "battle_speed", battle_speed))
	language = str(cfg.get_value("language", "value", language))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "master_muted", master_muted)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "confirm_before_surrender", confirm_before_surrender)
	cfg.set_value("gameplay", "combat_log_expanded_default", combat_log_expanded_default)
	cfg.set_value("gameplay", "battle_speed", battle_speed)
	cfg.set_value("language", "value", language)
	cfg.save(SETTINGS_PATH)


func _apply_audio() -> void:
	_apply_bus_volume("Master", master_volume, master_muted)
	_apply_bus_volume("Music", music_volume, false)
	_apply_bus_volume("SFX", sfx_volume, false)


func _apply_bus_volume(bus_name: String, linear: float, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, muted or linear <= 0.001)
	if linear > 0.001:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_language() -> void:
	Localization.set_language(language)


func _changed() -> void:
	_save()
	settings_changed.emit()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume, master_muted)
	_changed()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume, false)
	_changed()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume, false)
	_changed()


func set_master_muted(muted: bool) -> void:
	master_muted = muted
	_apply_bus_volume("Master", master_volume, master_muted)
	_changed()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	_changed()


func set_confirm_before_surrender(value: bool) -> void:
	confirm_before_surrender = value
	_changed()


func set_combat_log_expanded_default(value: bool) -> void:
	combat_log_expanded_default = value
	_changed()


func set_battle_speed(value: float) -> void:
	battle_speed = value
	_changed()


func set_language(locale: String) -> void:
	language = locale
	_apply_language()
	_changed()
