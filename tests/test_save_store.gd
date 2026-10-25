extends "res://tests/case_base.gd"

const HuntState := preload("res://scripts/core/hunt_state.gd")
const SaveStore := preload("res://scripts/core/save_store.gd")
const SAVE_PATH := "user://test_hunt_save.json"


func _clear() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func test_save_roundtrip_preserves_progress_and_inventory() -> void:
	_clear()
	var state := HuntState.new()
	state.coins = 80
	state.buy_upgrade()
	state.record_hunt("boar", true, true)
	state.collect_loot("boar", true, true)
	assert_true(SaveStore.save_state(state, SAVE_PATH))
	assert_false(FileAccess.file_exists(SAVE_PATH + ".tmp"), "committed temp is renamed")
	var restored := HuntState.new()
	assert_true(SaveStore.load_state(restored, SAVE_PATH))
	assert_eq(restored.snapshot(), state.snapshot())
	_clear()


func test_truncated_main_save_recovers_previous_valid_backup() -> void:
	_clear()
	var state := HuntState.new()
	state.coins = 15
	assert_true(SaveStore.save_state(state, SAVE_PATH))
	state.coins = 30
	assert_true(SaveStore.save_state(state, SAVE_PATH))
	_write(SAVE_PATH, "{\"version\":1,\"coins\":")
	var restored := HuntState.new()
	assert_true(SaveStore.load_state(restored, SAVE_PATH))
	assert_eq(restored.coins, 15, "last complete backup survives truncation")
	# Saving after recovery must retain the valid backup despite the corrupt main.
	assert_true(SaveStore.save_state(restored, SAVE_PATH))
	_write(SAVE_PATH, "corrupt again")
	assert_true(SaveStore.load_state(HuntState.new(), SAVE_PATH))
	_clear()


func test_malformed_main_falls_back_and_all_corrupt_keeps_live_state() -> void:
	_clear()
	var state := HuntState.new()
	state.coins = 9
	assert_true(SaveStore.save_state(state, SAVE_PATH))
	state.coins = 18
	assert_true(SaveStore.save_state(state, SAVE_PATH))
	var invalid := state.snapshot()
	invalid["inventory"] = [{"animal_id": "missing", "rare": false, "trick_shot": false}]
	_write(SAVE_PATH, JSON.stringify(invalid))
	var live := HuntState.new()
	assert_true(SaveStore.load_state(live, SAVE_PATH))
	assert_eq(live.coins, 9)
	_write(SAVE_PATH + ".bak", "[]")
	var before := live.snapshot()
	assert_false(SaveStore.load_state(live, SAVE_PATH))
	assert_eq(live.snapshot(), before, "failed load cannot change live state")
	_clear()


func test_leftover_temp_recovers_only_when_committed_files_unavailable() -> void:
	_clear()
	var pending := HuntState.new()
	pending.coins = 99
	_write(SAVE_PATH + ".tmp", JSON.stringify(pending.snapshot()))
	var restored := HuntState.new()
	assert_true(SaveStore.load_state(restored, SAVE_PATH))
	assert_eq(restored.coins, 99)
	var committed := HuntState.new()
	committed.coins = 23
	_write(SAVE_PATH, JSON.stringify(committed.snapshot()))
	assert_true(SaveStore.load_state(restored, SAVE_PATH))
	assert_eq(restored.coins, 23, "committed save takes priority over leftover temp")
	_clear()


func test_missing_save_and_invalid_state_fail_cleanly() -> void:
	_clear()
	var state := HuntState.new()
	assert_false(SaveStore.load_state(state, SAVE_PATH))
	state.coins = -3
	assert_false(SaveStore.save_state(state, SAVE_PATH))
	assert_false(FileAccess.file_exists(SAVE_PATH))
	_clear()
