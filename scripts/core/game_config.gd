extends RefCounted
## Loads game-wide configuration from data/config/game_config.json.
## The Steam App ID lives here as the single source of truth.

const CONFIG_PATH := "res://data/config/game_config.json"
const DEFAULT_STEAM_APP_ID := 480 # Valve's public test App ID.


## Returns the parsed config, or an empty Dictionary if the file is missing or invalid.
static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("GameConfig: %s not found, using defaults." % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameConfig: %s is not a valid JSON object, using defaults." % path)
		return {}
	return parsed


## Returns the configured Steam App ID, or the test App ID if the value is missing or invalid.
static func get_steam_app_id(path: String = CONFIG_PATH) -> int:
	var config := load_config(path)
	var value: Variant = config.get("steam_app_id", DEFAULT_STEAM_APP_ID)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return DEFAULT_STEAM_APP_ID
	var app_id := int(value)
	if app_id <= 0 or float(app_id) != float(value):
		return DEFAULT_STEAM_APP_ID
	return app_id
