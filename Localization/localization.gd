extends Node

signal language_changed(locale: String)

const DEFAULT_LOCALE: String = "ru"
const SUPPORTED_LOCALES: Array[String] = ["ru", "en", "es"]
const CSV_PATH: String = "res://Localization/game.csv"

var current_locale: String = DEFAULT_LOCALE
var _translations: Dictionary = {}

func _ready() -> void:
	load_translations()
	var engine_locale: String = TranslationServer.get_locale().to_lower()
	if engine_locale.begins_with("en"):
		set_language("en")
	elif engine_locale.begins_with("es"):
		set_language("es")
	else:
		set_language(DEFAULT_LOCALE)

func load_translations(path: String = CSV_PATH) -> void:
	_translations.clear()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	if file.eof_reached():
		return
	var header: PackedStringArray = file.get_csv_line()
	var locale_columns: Dictionary = {}
	for index: int in range(header.size()):
		var column_name: String = header[index].strip_edges().to_lower()
		if SUPPORTED_LOCALES.has(column_name):
			locale_columns[column_name] = index
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() <= 0:
			continue
		var key: String = row[0].strip_edges()
		if key == "" or key.begins_with("#"):
			continue
		var entry: Dictionary = {}
		for locale_value: String in locale_columns.keys():
			var column_index: int = int(locale_columns[locale_value])
			if column_index < row.size():
				entry[locale_value] = row[column_index]
		_translations[key] = entry

func set_language(locale: String) -> void:
	var normalized: String = _normalize_locale(locale)
	if current_locale == normalized:
		return
	current_locale = normalized
	TranslationServer.set_locale(current_locale)
	language_changed.emit(current_locale)

func t(key: String, fallback: String = "") -> String:
	var clean_key: String = key.strip_edges()
	if clean_key == "":
		return fallback
	var entry_value: Variant = _translations.get(clean_key, {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		var localized: String = str(entry.get(current_locale, ""))
		if localized.strip_edges() != "":
			return localized
		var russian: String = str(entry.get(DEFAULT_LOCALE, ""))
		if russian.strip_edges() != "":
			return russian
	if fallback != "":
		return fallback
	return clean_key

func f(key: String, values: Dictionary = {}, fallback: String = "") -> String:
	var text: String = t(key, fallback)
	for placeholder_value: Variant in values.keys():
		var placeholder: String = "{" + str(placeholder_value) + "}"
		text = text.replace(placeholder, str(values[placeholder_value]))
	return text

func text_from(resource: Object, key_property: String, fallback_property: String, default_text: String = "") -> String:
	if resource == null:
		return default_text
	var raw_key: Variant = resource.get(key_property)
	var key: String = ""
	if raw_key != null:
		key = str(raw_key)
	var raw_fallback: Variant = resource.get(fallback_property)
	var fallback: String = default_text
	if raw_fallback != null:
		fallback = str(raw_fallback)
	return t(key, fallback)

func _normalize_locale(locale: String) -> String:
	var normalized: String = locale.strip_edges().to_lower()
	if normalized.begins_with("en"):
		return "en"
	if normalized.begins_with("es"):
		return "es"
	return DEFAULT_LOCALE
