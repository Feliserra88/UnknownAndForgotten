@tool
extends RefCounted
## CSV-backed translations for the item editor (@tool plugins must not touch TranslationServer.set_locale).

const _CSV_PATH := "res://locale/translations.csv"

static var _ready: bool = false
static var _csv_by_locale: Dictionary = {}

static func ensure_loaded() -> void:
	if _ready:
		return
	_load_csv()
	_ready = true

static func translate_key(key: String) -> String:
	if key.is_empty():
		return ""
	ensure_loaded()
	var locale := _detect_locale()
	var table: Dictionary = _csv_by_locale.get(locale, {})
	if table.has(key):
		return String(table[key])
	if locale != "en" and _csv_by_locale.has("en") and _csv_by_locale["en"].has(key):
		return String(_csv_by_locale["en"][key])
	return key

static func _detect_locale() -> String:
	var os_lang := OS.get_locale_language()
	if os_lang == "es":
		return "es"
	var fallback: String = ProjectSettings.get_setting("internationalization/locale/fallback", "en")
	return fallback if not fallback.is_empty() else "en"

static func _load_csv() -> void:
	_csv_by_locale.clear()
	var file := FileAccess.open(_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("Item editor i18n: cannot read %s" % _CSV_PATH)
		return
	var header := file.get_csv_line()
	if header.is_empty() or header.size() < 2:
		return
	for col in range(1, header.size()):
		var locale_id := header[col].strip_edges().to_lower()
		if locale_id.is_empty():
			continue
		_csv_by_locale[locale_id] = {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or row[0].is_empty():
			continue
		var msg_key := row[0]
		for col in range(1, mini(row.size(), header.size())):
			var locale_id := header[col].strip_edges().to_lower()
			if locale_id.is_empty():
				continue
			if not _csv_by_locale.has(locale_id):
				_csv_by_locale[locale_id] = {}
			_csv_by_locale[locale_id][msg_key] = row[col]
