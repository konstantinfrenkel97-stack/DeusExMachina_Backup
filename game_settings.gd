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
var voice_volume: float = 1.0
var master_muted: bool = false

# ── Экран ──
var fullscreen: bool = true
# Размер окна в оконном режиме (индекс в WINDOW_SIZES; в полноэкранном не используется).
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var window_size_index: int = 0
var vsync: bool = true
# Ограничение FPS (0 = без ограничения).
const MAX_FPS_OPTIONS: Array[int] = [0, 30, 60, 120, 144]
var max_fps: int = 0

# ── Геймплей ──
var confirm_before_surrender: bool = true
# По умолчанию боевой лог свёрнут (текущее поведение battle_scene.gd) — здесь
# хранится обратное, "развёрнут ли лог по умолчанию", чтобы имя поля читалось понятно.
var combat_log_expanded_default: bool = false
# Множитель скорости боя (Engine.time_scale, включается только в battle_scene.gd).
var battle_speed: float = 1.0
const BATTLE_SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]
# Обучающие подсказки — глобальная настройка игрока, а не часть сохранения: переживает
# «Новую игру» и загрузку (см. CampaignState.tutorial_disabled — это её инвертированный вид).
var tutorial_hints_enabled: bool = true

# ── Реплики богов в бою (см. battle_scene.gd::_maybe_play_ability_voice_line) ──
# Базовый шанс, что при обычном (не первом, не ультимативном) применении способности
# прозвучит одна из её озвученных фраз. Первое применение способности богом за бой и
# сама ультимативная способность всегда озвучены (100%), независимо от этой настройки.
enum VoiceLineFrequency { RARE, NORMAL, OFTEN }
const VOICE_LINE_FREQUENCY_CHANCE := {
	VoiceLineFrequency.RARE: 0.15,
	VoiceLineFrequency.NORMAL: 0.3,
	VoiceLineFrequency.OFTEN: 0.5,
}
var voice_line_frequency: int = VoiceLineFrequency.NORMAL

func voice_line_base_chance() -> float:
	return float(VOICE_LINE_FREQUENCY_CHANCE.get(voice_line_frequency, 0.3))

# ── Язык (см. Localization autoload — реально переключает TranslationServer) ──
var language: String = "ru"

signal settings_changed


func _ready() -> void:
	_ensure_audio_buses()
	_load()
	_apply_audio()
	_apply_fullscreen()
	_apply_vsync()
	_apply_max_fps()
	_apply_language()


## Создаёт шины "Music", "SFX" и "Voice" при первом запуске (в проекте нет заранее
## сохранённого bus layout — шины существуют только в рантайме AudioServer).
## Плееры музыки/эффектов/голосов привязываются к ним в music_manager.gd,
## battle_scene.gd и combatant_visual.gd — без этого ползунки ничего бы не меняли.
func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX", "Voice"]:
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
	voice_volume = clampf(float(cfg.get_value("audio", "voice_volume", voice_volume)), 0.0, 1.0)
	master_muted = bool(cfg.get_value("audio", "master_muted", master_muted))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	window_size_index = clampi(int(cfg.get_value("video", "window_size_index", window_size_index)), 0, WINDOW_SIZES.size() - 1)
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	max_fps = int(cfg.get_value("video", "max_fps", max_fps))
	if not MAX_FPS_OPTIONS.has(max_fps):
		max_fps = 0
	confirm_before_surrender = bool(cfg.get_value("gameplay", "confirm_before_surrender", confirm_before_surrender))
	combat_log_expanded_default = bool(cfg.get_value("gameplay", "combat_log_expanded_default", combat_log_expanded_default))
	battle_speed = float(cfg.get_value("gameplay", "battle_speed", battle_speed))
	tutorial_hints_enabled = bool(cfg.get_value("gameplay", "tutorial_hints_enabled", tutorial_hints_enabled))
	voice_line_frequency = clampi(int(cfg.get_value("gameplay", "voice_line_frequency", voice_line_frequency)), 0, VoiceLineFrequency.OFTEN)
	language = str(cfg.get_value("language", "value", language))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "voice_volume", voice_volume)
	cfg.set_value("audio", "master_muted", master_muted)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "window_size_index", window_size_index)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("gameplay", "confirm_before_surrender", confirm_before_surrender)
	cfg.set_value("gameplay", "combat_log_expanded_default", combat_log_expanded_default)
	cfg.set_value("gameplay", "battle_speed", battle_speed)
	cfg.set_value("gameplay", "tutorial_hints_enabled", tutorial_hints_enabled)
	cfg.set_value("gameplay", "voice_line_frequency", voice_line_frequency)
	cfg.set_value("language", "value", language)
	cfg.save(SETTINGS_PATH)


func _apply_audio() -> void:
	_apply_bus_volume("Master", master_volume, master_muted)
	_apply_bus_volume("Music", music_volume, false)
	_apply_bus_volume("SFX", sfx_volume, false)
	_apply_bus_volume("Voice", voice_volume, false)


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
	if not fullscreen:
		var size: Vector2i = WINDOW_SIZES[window_size_index]
		DisplayServer.window_set_size(size)
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen_size - size) / 2)


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


func _apply_max_fps() -> void:
	Engine.max_fps = max_fps


## Размеры окна, которые помещаются на текущий экран (для списка в настройках).
func get_available_window_sizes() -> Array[Vector2i]:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var out: Array[Vector2i] = []
	for size in WINDOW_SIZES:
		if size.x <= screen_size.x and size.y <= screen_size.y:
			out.append(size)
	if out.is_empty():
		out.append(WINDOW_SIZES[0])
	return out


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


func set_voice_volume(v: float) -> void:
	voice_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Voice", voice_volume, false)
	_changed()


func set_master_muted(muted: bool) -> void:
	master_muted = muted
	_apply_bus_volume("Master", master_volume, master_muted)
	_changed()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	_changed()


func set_window_size_index(index: int) -> void:
	window_size_index = clampi(index, 0, WINDOW_SIZES.size() - 1)
	_apply_fullscreen()
	_changed()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_vsync()
	_changed()


func set_max_fps(value: int) -> void:
	max_fps = value if MAX_FPS_OPTIONS.has(value) else 0
	_apply_max_fps()
	_changed()


## Возвращает звук/экран/геймплей к значениям по умолчанию (язык и обучающие подсказки
## не трогает — это не «настройки производительности», а выбор игрока).
func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	voice_volume = 1.0
	master_muted = false
	fullscreen = true
	window_size_index = 0
	vsync = true
	max_fps = 0
	confirm_before_surrender = true
	combat_log_expanded_default = false
	battle_speed = 1.0
	voice_line_frequency = VoiceLineFrequency.NORMAL
	_apply_audio()
	_apply_fullscreen()
	_apply_vsync()
	_apply_max_fps()
	_changed()


func set_confirm_before_surrender(value: bool) -> void:
	confirm_before_surrender = value
	_changed()


func set_combat_log_expanded_default(value: bool) -> void:
	combat_log_expanded_default = value
	_changed()


func set_tutorial_hints_enabled(value: bool) -> void:
	tutorial_hints_enabled = value
	_changed()


func set_voice_line_frequency(value: int) -> void:
	voice_line_frequency = clampi(value, 0, VoiceLineFrequency.OFTEN)
	_changed()


func set_battle_speed(value: float) -> void:
	battle_speed = value
	_changed()


func set_language(locale: String) -> void:
	language = locale
	_apply_language()
	_changed()
