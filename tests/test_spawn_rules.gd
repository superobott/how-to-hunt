extends "res://tests/case_base.gd"

const SpawnRules := preload("res://scripts/core/spawn_rules.gd")


func test_same_seed_repeats_positions_animals_and_rarity() -> void:
	var first := SpawnRules.new(283)
	var second := SpawnRules.new(283)
	for index in range(80):
		assert_eq(first.next_spawn(), second.next_spawn(), "same seed repeats full spawn sequence")
	var different := SpawnRules.new(284)
	assert_false(first.next_position().is_equal_approx(different.next_position()), "different seeds diverge")


func test_spawn_positions_stay_on_outer_plateau_and_use_height() -> void:
	var rules := SpawnRules.new(191)
	var average_squared_radius := 0.0
	for index in range(1000):
		var position := rules.next_position(2.5)
		var radius := Vector2(position.x, position.z).length()
		assert_true(position.is_finite())
		assert_true(radius >= 44.0 - 0.0001 and radius <= 56.0 + 0.0001, "annulus radius")
		assert_near(position.y, 2.5)
		average_squared_radius += radius * radius
	average_squared_radius /= 1000.0
	assert_near(average_squared_radius, (44.0 * 44.0 + 56.0 * 56.0) / 2.0,
		"annulus is distributed by area", 45.0)


func test_configured_annulus_and_eligible_animals() -> void:
	var rules := SpawnRules.new(441, {"inner_radius": 8.0, "outer_radius": 9.0})
	var only_boar: Array[String] = ["boar"]
	var unknown: Array[String] = ["unknown"]
	for index in range(40):
		var spawn := rules.next_spawn(only_boar)
		assert_eq(spawn["animal_id"], "boar")
		var position: Vector3 = spawn["position"]
		var radius := Vector2(position.x, position.z).length()
		assert_true(radius >= 8.0 - 0.0001 and radius <= 9.0 + 0.0001)
	assert_eq(rules.choose_animal(unknown), "")
	assert_true(rules.next_spawn(unknown).is_empty())


func test_rarity_boundaries_and_seeded_rate() -> void:
	var rules := SpawnRules.new(914)
	for index in range(40):
		assert_false(rules.roll_rare(0.0))
		assert_false(rules.roll_rare(-1.0))
		assert_true(rules.roll_rare(1.0))
		assert_true(rules.roll_rare(2.0))
	var rare_count := 0
	for index in range(2000):
		if rules.roll_rare(0.12):
			rare_count += 1
	assert_true(rare_count >= 175 and rare_count <= 305, "seeded 12% rate within broad deterministic bound")
