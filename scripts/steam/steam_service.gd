extends Node
## The only entry point to Steam. Game logic and UI call this service, never Steam directly.
##
## GodotSteam registers an engine singleton named "Steam". It is looked up at runtime, so the
## project runs and tests pass even when GodotSteam is not installed or Steam is not running.
## When Steam is unavailable every method here returns a safe fallback.

signal initialized(available: bool)
signal lobby_changed(lobby_id: int)
signal lobby_failed(reason: String)
signal invite_received(lobby_id: int)

const GameConfig := preload("res://scripts/core/game_config.gd")
const STEAM_SINGLETON := "Steam"
const FALLBACK_PERSONA_NAME := "Player"
const LOBBY_PROTOCOL := preload("res://scripts/core/snapshot_wire.gd").PROTOCOL
const MAX_HUNTERS := 4
const LOBBY_TIMEOUT := 20.0

var lobby_id: int = 0
var lobby_owner: int = 0
var _lobby_request := ""
var _joining_id: int = 0
var _lobby_elapsed := 0.0

## Tests set this to false to avoid picking up a real GodotSteam install.
var allow_singleton: bool = true

var _steam: Object = null
var _available: bool = false
var _app_id: int = 0
var _status_message: String = "Steam not initialized."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--offline-tests" in OS.get_cmdline_user_args():
		allow_singleton = false
	initialize()


func _process(delta: float) -> void:
	if _available and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")
	if not _lobby_request.is_empty():
		_lobby_elapsed += delta
		if _lobby_elapsed >= LOBBY_TIMEOUT:
			_lobby_error("coop.lobby_timeout")


## Tries to start Steam. Returns true if Steam is available afterwards.
## `steam_override` lets tests inject a fake backend. `app_id` <= 0 means "read from config".
func initialize(steam_override: Object = null, app_id: int = -1) -> bool:
	leave_lobby()
	_disconnect_lobby_signals()
	_app_id = app_id if app_id > 0 else GameConfig.get_steam_app_id()
	_steam = steam_override
	if _steam == null and allow_singleton and Engine.has_singleton(STEAM_SINGLETON):
		_steam = Engine.get_singleton(STEAM_SINGLETON)

	if _steam == null:
		return _finish(false, "GodotSteam not found. Running without Steam.")

	# Steam reads the App ID from these variables on every GodotSteam version, so set them first.
	# This keeps the ID we report in get_app_id() identical to the one Steam initializes with.
	OS.set_environment("SteamAppId", str(_app_id))
	OS.set_environment("SteamGameId", str(_app_id))

	var result: Variant = null
	if _steam.has_method("steamInitEx"):
		# GodotSteam: steamInitEx(app_id, embed_callbacks) -> {status, verbal}, status 0 = OK.
		result = _steam.call("steamInitEx", _app_id)
	elif _steam.has_method("steamInit"):
		# Older builds. No argument here: their first parameter is not the App ID, so the
		# environment variables above carry it. Returns a bool, or {status, verbal} (status 1 = OK).
		result = _steam.call("steamInit")
	else:
		return _finish(false, "Steam singleton has no init method. Running without Steam.")

	return _interpret_init_result(result, _steam.has_method("steamInitEx"))


func _interpret_init_result(result: Variant, is_init_ex: bool) -> bool:
	if typeof(result) == TYPE_BOOL:
		if result:
			return _finish(true, "Steam initialized.")
		return _finish(false, "Steam init failed. Running without Steam.")
	if typeof(result) == TYPE_DICTIONARY and result.has("status"):
		var ok_status := 0 if is_init_ex else 1
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
		_connect_lobby_signals()
		print("SteamService: %s (App ID %d)" % [message, _app_id])
	else:
		push_warning("SteamService: %s" % message)
	initialized.emit(available)
	return available


## Lobby preparation only. Entering a lobby does not synchronize gameplay.
func supports_lobbies() -> bool:
	if not _available or not is_instance_valid(_steam):
		return false
	for method in ["createLobby", "joinLobby", "leaveLobby", "setLobbyData", "getLobbyData", "getLobbyOwner", "getSteamID"]:
		if not _steam.has_method(method):
			return false
	return _steam.has_signal("lobby_created") and _steam.has_signal("lobby_joined")


func host_lobby() -> bool:
	if not supports_lobbies() or lobby_id != 0 or not _lobby_request.is_empty():
		return false
	_lobby_request = "host"
	_lobby_elapsed = 0.0
	_steam.call("createLobby", 1, MAX_HUNTERS) # Friends-only, never public under test App ID.
	return true


func join_lobby(id: int) -> bool:
	if id <= 0 or not supports_lobbies() or lobby_id != 0 or not _lobby_request.is_empty():
		return false
	_lobby_request = "join"
	_joining_id = id
	_lobby_elapsed = 0.0
	_steam.call("joinLobby", id)
	return true


func leave_lobby() -> void:
	if lobby_id != 0 and is_instance_valid(_steam) and _steam.has_method("leaveLobby"):
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	lobby_owner = 0
	_lobby_request = ""
	_joining_id = 0
	lobby_changed.emit(0)


func _connect_lobby_signals() -> void:
	for pair in [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["join_requested", _on_join_requested]]:
		if _steam.has_signal(pair[0]) and not _steam.is_connected(pair[0], pair[1]):
			_steam.connect(pair[0], pair[1])


func _disconnect_lobby_signals() -> void:
	if not is_instance_valid(_steam):
		return
	for pair in [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["join_requested", _on_join_requested]]:
		if _steam.has_signal(pair[0]) and _steam.is_connected(pair[0], pair[1]):
			_steam.disconnect(pair[0], pair[1])


func _on_lobby_created(result: int, id: int) -> void:
	if _lobby_request != "host":
		if result == 1 and id > 0 and id != lobby_id:
			_steam.call("leaveLobby", id)
		return
	if result != 1 or id <= 0:
		_lobby_error("coop.create_failed")
		return
	if not bool(_steam.call("setLobbyData", id, "protocol", LOBBY_PROTOCOL)):
		_steam.call("leaveLobby", id)
		_lobby_error("coop.metadata_failed")
		return
	lobby_id = id
	lobby_owner = int(_steam.call("getSteamID"))
	_lobby_request = ""
	lobby_changed.emit(lobby_id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	# Steam also emits this callback for a newly created host lobby.
	if _lobby_request == "host" or id == lobby_id:
		return
	if _lobby_request != "join" or id != _joining_id:
		if response == 1 and id > 0:
			_steam.call("leaveLobby", id)
		return
	if response != 1:
		_lobby_error("coop.join_failed")
		return
	if str(_steam.call("getLobbyData", id, "protocol")) != LOBBY_PROTOCOL:
		_steam.call("leaveLobby", id)
		_lobby_error("coop.incompatible")
		return
	var owner := int(_steam.call("getLobbyOwner", id))
	if owner <= 0:
		_steam.call("leaveLobby", id)
		_lobby_error("coop.invalid_host")
		return
	lobby_id = id
	lobby_owner = owner
	_lobby_request = ""
	_joining_id = 0
	lobby_changed.emit(lobby_id)


func _lobby_error(reason: String) -> void:
	_lobby_request = ""
	_joining_id = 0
	lobby_failed.emit(reason)


func _exit_tree() -> void:
	leave_lobby()
	_disconnect_lobby_signals()


func _on_join_requested(id: int, _friend: int) -> void:
	# UI offers acceptance; an overlay invite never discards an active expedition.
	invite_received.emit(id)


func is_lobby_host() -> bool:
	return lobby_id > 0 and _available and lobby_owner == int(_steam.call("getSteamID"))


func create_transport() -> MultiplayerPeer:
	if not supports_lobbies() or lobby_id == 0 or not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var result: int = peer.call("create_host", 0) if is_lobby_host() else peer.call("create_client", lobby_owner, 0)
	if result != OK:
		peer.close()
		return null
	return peer


func peer_identity(peer: MultiplayerPeer, id: int) -> String:
	if not supports_lobbies() or lobby_id == 0 or not peer.has_method("get_steam_id_for_peer_id"):
		return ""
	var steam_id := int(peer.call("get_steam_id_for_peer_id", id))
	if steam_id <= 0 or not _steam.has_method("getNumLobbyMembers") or not _steam.has_method("getLobbyMemberByIndex"):
		return ""
	for index in mini(MAX_HUNTERS, int(_steam.call("getNumLobbyMembers", lobby_id))):
		if int(_steam.call("getLobbyMemberByIndex", lobby_id, index)) == steam_id:
			return str(steam_id)
	return ""


func invite_friends() -> void:
	if lobby_id > 0 and _available and _steam.has_method("activateGameOverlayInviteDialog"):
		_steam.call("activateGameOverlayInviteDialog", lobby_id)
