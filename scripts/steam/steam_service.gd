extends Node
## The only entry point to Steam. Game logic and UI call this service, never Steam directly.
##
## GodotSteam registers an engine singleton named "Steam". It is looked up at runtime, so the
## project runs and tests pass even when GodotSteam is not installed or Steam is not running.
## When Steam is unavailable every method here returns a safe fallback.

signal initialized(available: bool)

const GameConfig := preload("res://scripts/core/game_config.gd")
const STEAM_SINGLETON := "Steam"
const FALLBACK_PERSONA_NAME := "Player"

## Tests set this to false to avoid picking up a real GodotSteam install.
var allow_singleton: bool = true

var _steam: Object = null
var _available: bool = false
var _app_id: int = 0
var _status_message: String = "Steam not initialized."


func _ready() -> void:
	initialize()


func _process(_delta: float) -> void:
	if _available and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


## Tries to start Steam. Returns true if Steam is available afterwards.
## `steam_override` lets tests inject a fake backend. `app_id` <= 0 means "read from config".
func initialize(steam_override: Object = null, app_id: int = -1) -> bool:
	_app_id = app_id if app_id > 0 else GameConfig.get_steam_app_id()
	_steam = steam_override
	if _steam == null and allow_singleton and Engine.has_singleton(STEAM_SINGLETON):
		_steam = Engine.get_singleton(STEAM_SINGLETON)

	if _steam == null:
		return _finish(false, "GodotSteam not found. Running without Steam.")

	# GodotSteam 4.x exposes steamInitEx (status 0 = OK); older builds expose steamInit (status 1 = OK).
	var ok_status := 0
	var result: Variant = null
	if _steam.has_method("steamInitEx"):
		result = _steam.call("steamInitEx")
	elif _steam.has_method("steamInit"):
		ok_status = 1
		result = _steam.call("steamInit")
	else:
		return _finish(false, "Steam singleton has no init method. Running without Steam.")

	if typeof(result) == TYPE_DICTIONARY and result.has("status"):
		if int(result["status"]) == ok_status:
			return _finish(true, "Steam initialized.")
		var verbal: String = str(result.get("verbal", "unknown error"))
		return _finish(false, "Steam init failed (%s). Running without Steam." % verbal)
	return _finish(false, "Steam init returned an unexpected result. Running without Steam.")


func is_available() -> bool:
	return _available


func get_app_id() -> int:
	return _app_id


func get_status_message() -> String:
	return _status_message


## The Steam display name, or a fallback when Steam is unavailable.
func get_persona_name() -> String:
	if _available and _steam.has_method("getPersonaName"):
		var name: Variant = _steam.call("getPersonaName")
		if typeof(name) == TYPE_STRING and not (name as String).is_empty():
			return name
	return FALLBACK_PERSONA_NAME


func _finish(available: bool, message: String) -> bool:
	_available = available
	_status_message = message
	if not available:
		_steam = null
	# Only poll Steam callbacks while Steam is running.
	set_process(available)
	if available:
		print("SteamService: %s (App ID %d)" % [message, _app_id])
	else:
		push_warning("SteamService: %s" % message)
	initialized.emit(available)
	return available
