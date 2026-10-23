extends RefCounted
## English is the fallback catalog; optional language files override individual keys.

const ENGLISH_PATH := "res://data/localization/en.json"
static var _catalog: Dictionary = {}
static var _loaded := false


static func get_text(key: String, args: Array = []) -> String:
	if not _loaded:
		_load_catalog()
	var result: String = str(_catalog.get(key, key))
	for index in args.size():
		result = result.replace("{%d}" % index, str(args[index]))
	return result


static func _load_catalog() -> void:
	_loaded = true
	_catalog = _read_dictionary(ENGLISH_PATH)
	var language := OS.get_locale_language()
	if language != "en" and not language.is_empty():
		var locale_path := "res://data/localization/%s.json" % language
		if FileAccess.file_exists(locale_path):
			_catalog.merge(_read_dictionary(locale_path), true)


static func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("GameText: missing catalog %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameText: invalid catalog %s" % path)
		return {}
	return parsed
