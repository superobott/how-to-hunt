extends "res://tests/case_base.gd"
const HuntState := preload("res://scripts/core/hunt_state.gd")
const Expedition := preload("res://scripts/core/expedition.gd")
const Coop := preload("res://scripts/world/coop_session.gd")

func test_shared_wallet_keeps_equipment_individual() -> void:
	var host := HuntState.new()
	host.coins = 200
	var expedition := Expedition.new(host)
	assert_true(expedition.add_hunter(2, "guest"))
	assert_true(expedition.purchase(2, "starter_bow"))
	assert_eq(host.coins, 80)
	assert_eq(host.tool_id, "knife")
	assert_eq(expedition.hunters[2].tool_id, "starter_bow")
	assert_false(expedition.purchase(2, "starter_bow"), "no duplicate purchase")
	assert_false(expedition.purchase(1, "starter_bow"), "shared wallet cannot overspend")
	assert_eq(host.coins, 80)

func test_rewards_and_rejoin_preserve_session_gear() -> void:
	var host := HuntState.new()
	host.coins = 100
	var expedition := Expedition.new(host)
	expedition.add_hunter(2, "guest")
	assert_false(expedition.add_hunter(3, "guest"), "one connected actor per Steam identity")
	assert_true(expedition.purchase(2, "trail_boots"))
	expedition.record_hunt("rabbit", false, false)
	assert_eq(host.xp, 20)
	assert_eq(expedition.hunters[2].xp, 20)
	assert_eq(expedition.collect(2, "rabbit", false, false), 12)
	assert_eq(host.coins, 22)
	expedition.remove_hunter(2)
	assert_true(expedition.add_hunter(3, "guest"))
	assert_true("trail_boots" in expedition.hunters[3].owned_gear)
	assert_eq(expedition.hunters[3].coins, 22)
	assert_true(host.owned_gear.is_empty())

func test_capacity_and_unknown_peer_do_not_mutate_wallet() -> void:
	var host := HuntState.new()
	host.coins = 1000
	var expedition := Expedition.new(host)
	for peer in [2, 3, 4]:
		assert_true(expedition.add_hunter(peer, str(peer)))
	assert_false(expedition.add_hunter(5, "fifth"))
	assert_false(expedition.purchase(99, "starter_bow"))
	assert_eq(expedition.collect(99, "bear", true, true), 0)
	assert_eq(host.coins, 1000)

func test_network_input_rejects_invalid_values() -> void:
	assert_true(Coop.valid_input(Vector2(0, 1), Vector2.ZERO, 0))
	assert_false(Coop.valid_input(Vector2(NAN, 0), Vector2.ZERO, 0))
	assert_false(Coop.valid_input(Vector2.ZERO, Vector2(INF, 0), 0))
	assert_false(Coop.valid_input(Vector2(5, 0), Vector2.ZERO, 0))
	assert_false(Coop.valid_input(Vector2.ZERO, Vector2.ZERO, 10))
