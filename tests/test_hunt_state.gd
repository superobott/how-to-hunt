extends "res://tests/case_base.gd"

const HuntState := preload("res://scripts/core/hunt_state.gd")


func test_hunting_collecting_selling_and_upgrade_loop() -> void:
	var state := HuntState.new()
	state.tool_id = "starter_bow"
	assert_false(state.buy_upgrade(), "fresh player cannot afford an upgrade")
	for index in range(4):
		state.record_hunt("rabbit")
		assert_true(state.collect_loot("rabbit"), "loot fits in the bag")
	assert_eq(state.hunts, 4)
	assert_eq(state.xp, 80, "collection does not award duplicate XP")
	assert_eq(state.coins, 0, "loot must be sold before it funds purchases")
	assert_eq(state.sell_all(), 48)
	assert_eq(state.sell_all(), 0, "selling an empty bag cannot duplicate coins")
	assert_eq(state.coins, 48)
	state.coins = int(state.next_tool()["price"])
	assert_true(state.buy_upgrade())
	assert_eq(state.tool_id, "hunters_bow")
	assert_eq(state.coins, 0)
	assert_false(state.buy_upgrade(), "second upgrade needs more coins")
	assert_eq(state.tool_id, "hunters_bow")


func test_capacity_and_unknown_animals_do_not_change_progress() -> void:
	var state := HuntState.new()
	state.record_hunt("missing")
	assert_false(state.collect_loot("missing"))
	for index in range(state.capacity()):
		assert_true(state.collect_loot("rabbit"))
	var before := state.snapshot()
	assert_false(state.collect_loot("boar", true, true))
	assert_eq(state.snapshot(), before, "a full bag must not mutate inventory or XP")
	assert_eq(state.hunts, 0, "collection does not create hunts")
	assert_eq(state.xp, 0)


func test_rare_trick_rewards_and_level_threshold() -> void:
	var state := HuntState.new()
	state.record_hunt("rabbit", true, true)
	assert_eq(state.xp, 90)
	assert_eq(state.level(), 1)
	state.record_hunt("rabbit")
	assert_eq(state.level(), 2)
	assert_true(state.collect_loot("rabbit", true, true))
	assert_eq(state.bag_value(), 54, "rare and trick multipliers combine once")
	assert_eq(state.sell_all(), 54)
	assert_eq(state.coins, 54)


func test_final_upgrade_stops_and_snapshot_is_independent() -> void:
	var state := HuntState.new()
	state.coins = 100000
	for index in state.catalog["tools"].size() - 1:
		assert_true(state.buy_upgrade())
	var before := state.coins
	assert_true(state.next_tool().is_empty())
	assert_false(state.buy_upgrade())
	assert_eq(state.coins, before)
	state.collect_loot("rabbit")
	var saved := state.snapshot()
	saved["inventory"][0]["animal_id"] = "boar"
	assert_eq(state.inventory[0]["animal_id"], "rabbit", "snapshot must not alias live bag items")


func test_restore_roundtrip_copies_inventory() -> void:
	var source := HuntState.new()
	source.coins = 74
	source.record_hunt("boar", true)
	source.collect_loot("boar", true)
	var saved := source.snapshot()
	var restored := HuntState.new()
	assert_true(restored.restore(saved))
	assert_eq(restored.snapshot(), saved)
	saved["inventory"].clear()
	assert_eq(restored.inventory.size(), 1, "caller mutations cannot change restored state")


func test_restore_rejects_invalid_numbers_without_partial_changes() -> void:
	var state := HuntState.new()
	state.coins = 7
	state.collect_loot("rabbit")
	var before := state.snapshot()
	for field in ["coins", "xp", "hunts", "version"]:
		for invalid: Variant in [-1, 1.5, INF, NAN, 1e100, "7", true, null]:
			var malformed := before.duplicate(true)
			malformed[field] = invalid
			assert_false(state.restore(malformed), "reject %s=%s" % [field, str(invalid)])
			assert_eq(state.snapshot(), before, "invalid save must be atomic")


func test_restore_rejects_invalid_schema_and_inventory() -> void:
	var state := HuntState.new()
	state.coins = 19
	state.collect_loot("rabbit")
	var before := state.snapshot()
	var malformed: Array[Dictionary] = []
	var missing := before.duplicate(true)
	missing.erase("xp")
	malformed.append(missing)
	var unknown := before.duplicate(true)
	unknown["tool_id"] = "fake_bow"
	malformed.append(unknown)
	for item: Variant in [null, "rabbit", {}, {"animal_id": "dragon", "rare": false, "trick_shot": false},
		{"animal_id": "rabbit", "rare": 1, "trick_shot": false},
		{"animal_id": "rabbit", "rare": false}]:
		var bad_inventory := before.duplicate(true)
		bad_inventory["inventory"] = [item]
		malformed.append(bad_inventory)
	var oversized := before.duplicate(true)
	for index in range(state.capacity()):
		oversized["inventory"].append({"animal_id": "boar", "rare": false, "trick_shot": false})
	malformed.append(oversized)
	for invalid in malformed:
		assert_false(state.restore(invalid))
		assert_eq(state.snapshot(), before, "malformed schema cannot partially overwrite state")


func test_coins_and_direct_store_selection() -> void:
	var state := HuntState.new()
	assert_eq(state.collect_coins("rabbit"), 12, "ordinary rabbit coin value")
	assert_eq(state.collect_coins("rabbit", true, true), 54, "rare trick reward")
	assert_true(state.inventory.is_empty(), "coins never fill a bag")
	assert_true(not state.buy_tool("mountain_bow"), "unaffordable selection rejected")
	state.coins = int(state.catalog["tools"]["mountain_bow"]["price"]) + 60
	assert_true(state.buy_tool("mountain_bow"), "can choose a later bow directly")
	assert_eq(state.coins, 60, "full selected price deducted")
	assert_true(not state.buy_tool("mountain_bow"), "duplicate purchase rejected")
	assert_true(not state.buy_tool("hunters_bow"), "downgrade rejected")
	assert_true(not state.buy_tool("unknown"), "unknown item rejected")


func test_equipment_and_legacy_save_migration() -> void:
	var state := HuntState.new()
	state.coins = 1000000
	for id in state.catalog["gear"]:
		assert_true(state.buy_gear(id), "equipment can be bought")
		var before := state.coins
		assert_false(state.buy_gear(id), "duplicate equipment rejected")
		assert_eq(state.coins, before)
	assert_near(state.gear_effect("speed", 1.0), 1.2)
	assert_near(state.gear_effect("pickup", 2.2), 4.0)
	assert_near(state.gear_effect("reload", 1.0), 0.8)
	assert_near(state.gear_effect("jump", 1.0), 1.12)
	assert_eq(state.collect_coins("rabbit"), 15, "charm increases coin rewards")
	var restored := HuntState.new()
	assert_true(restored.restore(state.snapshot()))
	assert_eq(restored.owned_gear, state.owned_gear)
	for invalid: Variant in [["unknown"], ["trail_boots", "trail_boots"], [1], null]:
		var bad := state.snapshot()
		bad["owned_gear"] = invalid
		assert_false(restored.restore(bad))
	var old := state.snapshot()
	old.erase("owned_gear")
	old["version"] = 1
	assert_true(restored.restore(old), "old saves migrate")
	assert_true(restored.owned_gear.is_empty())
	assert_eq(restored.coins, state.coins)


func test_knife_start_and_first_bow() -> void:
	var state := HuntState.new()
	assert_eq(state.tool_id, "knife")
	assert_false(state.buy_upgrade())
	for index in 40:
		state.collect_coins("ant")
	assert_eq(state.coins, 120)
	assert_true(state.buy_upgrade())
	assert_eq(state.tool_id, "starter_bow")
	assert_eq(state.coins, 0)
	state.coins = 105
	assert_eq(state.defeat_penalty(), 10)
	assert_eq(state.coins, 95)
