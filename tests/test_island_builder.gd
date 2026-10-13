extends "res://tests/case_base.gd"

const IslandBuilder := preload("res://scripts/world/island_builder.gd")


func test_tiers_shrink_and_rise() -> void:
	for i in range(1, IslandBuilder.TIERS.size()):
		var lower: Dictionary = IslandBuilder.TIERS[i - 1]
		var upper: Dictionary = IslandBuilder.TIERS[i]
		assert_true(upper["radius"] < lower["radius"], "tier %d is narrower" % i)
		assert_true(upper["top"] > lower["top"], "tier %d is higher" % i)


func test_each_cliff_is_a_climbable_height() -> void:
	# A step much taller than ~30 m would take too long to climb at CLIMB_SPEED.
	for i in range(1, IslandBuilder.TIERS.size()):
		var step: float = IslandBuilder.TIERS[i]["top"] - IslandBuilder.TIERS[i - 1]["top"]
		assert_true(step > 1.5, "tier %d step is more than a jump" % i)
		assert_true(step < 30.0, "tier %d step is not absurdly tall" % i)


func test_ground_height_follows_the_tiers() -> void:
	assert_near(IslandBuilder.ground_height_at(0.0), 24.0, "summit")
	assert_near(IslandBuilder.ground_height_at(20.0), 15.0, "second tier")
	assert_near(IslandBuilder.ground_height_at(40.0), 7.0, "first tier")
	assert_near(IslandBuilder.ground_height_at(55.0), 0.0, "plateau")
	assert_true(is_nan(IslandBuilder.ground_height_at(61.0)), "beyond the cliff edge")


func test_build_creates_one_climbable_body_per_tier_and_a_sea() -> void:
	var island := IslandBuilder.build()
	var bodies := 0
	for child in island.get_children():
		if child is StaticBody3D:
			bodies += 1
			assert_true(child.is_in_group(IslandBuilder.CLIMBABLE_GROUP), "%s climbable" % child.name)
	assert_eq(bodies, IslandBuilder.TIERS.size(), "tier bodies")
	assert_true(island.get_node_or_null("Sea") != null, "sea exists")
	island.free()
