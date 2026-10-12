extends "res://tests/case_base.gd"

const GameConfig := preload("res://scripts/core/game_config.gd")
const TMP_PATH := "user://test_game_config.json"


func _write_tmp(text: String) -> void:
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_shipped_config_uses_test_app_id() -> void:
	assert_eq(GameConfig.get_steam_app_id(), 480, "shipped App ID")


func test_steam_appid_txt_matches_config() -> void:
	var from_file := FileAccess.get_file_as_string("res://steam_appid.txt").strip_edges()
	assert_eq(from_file, str(GameConfig.get_steam_app_id()), "steam_appid.txt")


func test_missing_file_falls_back() -> void:
	assert_eq(GameConfig.get_steam_app_id("user://does_not_exist.json"), 480, "missing file")


func test_malformed_json_falls_back() -> void:
	_write_tmp("{ not json")
	assert_eq(GameConfig.get_steam_app_id(TMP_PATH), 480, "malformed json")


func test_invalid_app_id_values_fall_back() -> void:
	for bad in ["-5", "0", "1.5", "\"abc\"", "null"]:
		_write_tmp("{\"steam_app_id\": %s}" % bad)
		assert_eq(GameConfig.get_steam_app_id(TMP_PATH), 480, "bad value %s" % bad)


func test_valid_custom_app_id_is_used() -> void:
	_write_tmp("{\"steam_app_id\": 123456}")
	assert_eq(GameConfig.get_steam_app_id(TMP_PATH), 123456, "custom App ID")
