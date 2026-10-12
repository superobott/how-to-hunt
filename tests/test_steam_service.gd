extends "res://tests/case_base.gd"

const SteamServiceScript := preload("res://scripts/steam/steam_service.gd")


class FakeSteamEx:
	extends RefCounted
	var status: int = 0
	var callbacks_run: int = 0

	func steamInitEx() -> Dictionary:
		return {"status": status, "verbal": "fake status %d" % status}

	func getPersonaName() -> String:
		return "Trapper"

	func run_callbacks() -> void:
		callbacks_run += 1


class FakeSteamLegacy:
	extends RefCounted
	var status: int = 1

	func steamInit() -> Dictionary:
		return {"status": status, "verbal": "legacy"}


class FakeSteamNoInit:
	extends RefCounted


func _make_service() -> Node:
	var service: Node = SteamServiceScript.new()
	service.allow_singleton = false
	return service


func test_no_backend_is_unavailable_with_fallbacks() -> void:
	var service := _make_service()
	assert_false(service.initialize(), "initialize without backend")
	assert_false(service.is_available(), "is_available")
	assert_eq(service.get_persona_name(), "Player", "fallback persona name")
	assert_eq(service.get_app_id(), 480, "App ID from config")
	service.free()


func test_init_ex_success() -> void:
	var service := _make_service()
	var fake := FakeSteamEx.new()
	assert_true(service.initialize(fake), "initialize with ok status")
	assert_true(service.is_available(), "is_available")
	assert_eq(service.get_persona_name(), "Trapper", "persona name from Steam")
	service.free()


func test_init_ex_failure_falls_back() -> void:
	var service := _make_service()
	var fake := FakeSteamEx.new()
	fake.status = 2
	assert_false(service.initialize(fake), "initialize with failing status")
	assert_false(service.is_available(), "is_available")
	assert_eq(service.get_persona_name(), "Player", "fallback persona name")
	service.free()


func test_legacy_init_success() -> void:
	var service := _make_service()
	assert_true(service.initialize(FakeSteamLegacy.new()), "legacy init ok")
	service.free()


func test_legacy_init_failure() -> void:
	var service := _make_service()
	var fake := FakeSteamLegacy.new()
	fake.status = 0
	assert_false(service.initialize(fake), "legacy init failure")
	service.free()


func test_backend_without_init_method_is_unavailable() -> void:
	var service := _make_service()
	assert_false(service.initialize(FakeSteamNoInit.new()), "no init method")
	service.free()


func test_explicit_app_id_overrides_config() -> void:
	var service := _make_service()
	service.initialize(null, 999)
	assert_eq(service.get_app_id(), 999, "explicit App ID")
	service.free()


func test_initialized_signal_reports_availability() -> void:
	var service := _make_service()
	var seen: Array = []
	service.initialized.connect(func(available: bool) -> void: seen.append(available))
	service.initialize()
	service.initialize(FakeSteamEx.new())
	assert_eq(seen, [false, true], "signal values")
	service.free()
