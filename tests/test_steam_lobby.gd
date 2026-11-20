extends "res://tests/case_base.gd"

const Service := preload("res://scripts/steam/steam_service.gd")

class Backend:
	extends RefCounted
	signal lobby_created(result: int, id: int)
	signal lobby_joined(id: int, permissions: int, locked: bool, response: int)
	var created: Array = []
	var joined: Array = []
	var left: Array = []
	var protocol := Service.LOBBY_PROTOCOL
	func steamInitEx(_id: int) -> Dictionary:
		return {"status": 0}
	func createLobby(kind: int, count: int) -> void:
		created.append([kind, count])
	func joinLobby(id: int) -> void:
		joined.append(id)
	func leaveLobby(id: int) -> void:
		left.append(id)
	func setLobbyData(_id: int, _key: String, value: String) -> bool:
		protocol = value
		return true
	func getLobbyData(_id: int, _key: String) -> String:
		return protocol
	func getLobbyOwner(_id: int) -> int:
		return 42
	func getSteamID() -> int:
		return 42

func test_offline_lobby_operations_are_safe() -> void:
	var service := Service.new()
	service.allow_singleton = false
	assert_false(service.host_lobby())
	assert_false(service.join_lobby(123))
	service.leave_lobby()
	service.free()

func test_host_is_friends_only_and_limited_to_four() -> void:
	var fake := Backend.new()
	var service := Service.new()
	service.initialize(fake)
	assert_true(service.host_lobby())
	assert_false(service.host_lobby(), "reject overlapping requests")
	assert_eq(fake.created, [[1, 4]])
	fake.lobby_created.emit(1, 123)
	fake.lobby_joined.emit(123, 0, false, 1)
	assert_eq(service.lobby_id, 123)
	assert_eq(service.lobby_owner, 42)
	service.leave_lobby()
	assert_eq(fake.left, [123])
	assert_eq(service.lobby_id, 0)
	service.free()

func test_join_checks_protocol_and_accepts_matching_lobby() -> void:
	var fake := Backend.new()
	var service := Service.new()
	service.initialize(fake)
	assert_false(service.join_lobby(-1))
	assert_true(service.join_lobby(123))
	fake.protocol = "another-game"
	fake.lobby_joined.emit(123, 0, false, 1)
	assert_eq(service.lobby_id, 0)
	assert_eq(fake.left, [123])
	fake.protocol = Service.LOBBY_PROTOCOL
	assert_true(service.join_lobby(456))
	fake.lobby_joined.emit(456, 0, false, 1)
	assert_eq(service.lobby_id, 456)
	service.leave_lobby()
	service.free()

func test_timeout_and_cancelled_join_cleanup() -> void:
	var fake := Backend.new()
	var service := Service.new()
	service.initialize(fake)
	var failures: Array = []
	service.lobby_failed.connect(func(reason: String) -> void: failures.append(reason))
	service.join_lobby(123)
	service._process(21.0)
	assert_eq(failures.size(), 1)
	fake.lobby_joined.emit(123, 0, false, 1)
	assert_eq(service.lobby_id, 0)
	assert_eq(fake.left, [123])
	service.free()

func test_reinitialize_disconnects_old_callbacks() -> void:
	var old_backend := Backend.new()
	var service := Service.new()
	service.initialize(old_backend)
	service.initialize(Backend.new())
	service.host_lobby()
	old_backend.lobby_created.emit(1, 123)
	assert_eq(service.lobby_id, 0)
	service.free()
