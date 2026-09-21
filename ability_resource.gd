extends Resource
class_name AbilityResource
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.res", "*.tres") var icon_path: String = ""

@export var name: String = "Название"
@export_multiline var description: String = "Описание"
@export_multiline var extra_effect_description: String = ""
@export_group("Localization")
@export var name_key: String = ""
@export var description_key: String = ""
@export var extra_effect_description_key: String = ""
@export_group("")
@export_group("Upgrade")
@export var upgraded_ability: AbilityResource
@export_group("")
@export var damage_modifier: float = 1.0
@export var majesty_gain: int = 20
@export var majesty_cost: int = 0
@export_enum("Enemy", "Ally", "Self", "All_Enemies", "All_Allies", "Position") var target_type: String = "Enemy"
@export var extra_targets_count: int = 0 # Количество дополнительных целей позади основной

@export var effect_types: Array[String] = []
@export var effect_values: Dictionary[String, int] = {}
# В файле ability_resource.gd
@export var effect_durations: Dictionary[String, int] = {}
@export_enum("Physical", "Pure") var damage_type: String = "Physical"

@export_group("Valid Positions")
@export var usable_from_positions: Array[bool] = [true, true, true, true]
@export var targetable_positions: Array[bool] = [true, true, true, true]
@export_enum("UntilNextTurn", "UntilBroken") var stance_duration_type: String
@export var breaks_enemy_stances: bool = false
@export var never_miss: bool = false
# В файле ability_resource.gd
@export var is_stance: bool = false
# Уникальный тип стойки — по этому полю код определяет поведение (не по имени!)
# Примеры: "thunder_wrath", "" (пусто = обычная стойка)
@export var stance_effect_type: String = ""

@export var condition: String = ""        # Пример: "OnKill"
@export var condition_effect: String = "" # Пример: "self_heal_percent"
@export var condition_effect_value: int = 0
@export var condition_effect_duration: int = 1

@export_group("Attack Sound")
## Звук, проигрываемый в момент, когда эта способность реально бьёт по цели —
## не в момент нажатия кнопки способности. Для отложенных атак (стойки вроде
## "Гнев Бога Грома", марки вроде "Нескончаемый шторм", контратаки "Отражения")
## звук звучит при каждом фактическом ударе, а не при наложении/активации.
## Пусто = у способности нет отдельного звука атаки.
@export var attack_sfx: AudioStream = null
## Если > 0 — звук обрезается по времени (доигрывается не дольше стольких секунд),
## не трогая сам файл. 0 = играть целиком.
@export var attack_sfx_max_length: float = 0.0
## Громкость звука атаки в дБ относительно исходного файла (0 = без изменений,
## отрицательное — тише). Напр. -1.94 ≈ на 20% тише по громкости (не по дБ).
@export var attack_sfx_volume_db: float = 0.0
## Картинка вспышки способности (напр. молния Зевса), которая появляется поверх
## спрайта ЦЕЛИ в момент удара — плавно проявляется, потом плавно исчезает (см.
## CombatantVisual.show_attack_effect_flash). Пусто = нет визуальной вспышки. Каждый
## удар — даже несколько подряд по одной и той же цели — получает свою отдельную,
## независимую анимацию (не делят один узел/таймер).
@export var attack_effect_texture: Texture2D = null
## Множитель размера вспышки относительно роста цели (1.0 = высота непрозрачной
## части спрайта цели, 2.0 = вдвое крупнее).
@export var attack_effect_scale: float = 1.0
@export_group("")

@export_group("Voice Lines")
## Возможные озвученные фразы при применении этой способности (см. VoiceLineResource).
## Пусто = способность немая. Если не пусто — при каждом применении 30% шанс, что
## случайная фраза из списка прозвучит и покажется в облачке у головы бога
## (см. battle_scene.gd::_use_ability, VOICE_LINE_CHANCE).
@export var voice_lines: Array[VoiceLineResource] = []
@export_group("")

@export_group("Effect Tracking")
# Уникальный маркер способности для отслеживания источников эффектов.
# Используется пассивками (например, Посейдон) для подсчёта уникальных баффов.
# Если пусто — используется name способности.
@export var ability_marker: String = ""

@export_group("Mark (позиционная марка)")
# 0 = нет марки, 1 = одноразовая (once), 2 = многоходовая (persistent)
@export_enum("None", "Once", "Persistent") var mark_type_int: int = 0
# Удобный геттер — код в battle_scene использует этот
var mark_type: String:
	get:
		match mark_type_int:
			1: return "once"
			2: return "persistent"
			_: return ""
# Сторона команды на которую накладывается марка: "enemy" или "ally"
@export_enum("enemy", "ally") var mark_target_team: String = "enemy"
# Позиция (0-3) на которую накладывается марка
@export var mark_position: int = 0
# Длительность марки в раундах (только для "persistent")
@export var mark_duration: int = 2
# Эффект который применяется маркой (например "target_debuff_accuracy", или "" для чистого урона)
@export var mark_effect_type: String = ""
# Значение эффекта марки
@export var mark_effect_value: int = 0
# Длительность эффекта марки (если это бафф/дебафф)
@export var mark_effect_duration: int = 1
# Урон марки как процент от урона владельца (0 = нет урона)
@export var mark_damage_percent: float = 0.0
# Тип урона марки
@export_enum("Physical", "Pure") var mark_damage_type: String = "Physical"
# Иконка, отображаемая над меченой позицией (своя для каждой способности-марки).
# Пусто → используется глобальная иконка mark_icon_texture со сцены боя.
@export var mark_icon: Texture2D = null
func get_icon_texture() -> Texture2D:
	if icon_path == "":
		return null
	return load(icon_path) as Texture2D

func get_display_name() -> String:
	return Localization.t(name_key, name)

func get_display_description() -> String:
	return Localization.t(description_key, description)

func get_display_extra_effect_description() -> String:
	return Localization.t(extra_effect_description_key, extra_effect_description)
