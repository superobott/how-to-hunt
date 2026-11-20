extends "res://tests/case_base.gd"
const Terrain := preload("res://scripts/world/island_builder.gd")


func test_continuous_walkable_mountain() -> void:
	assert_near(Terrain.ground_height_at(0), 24.0, "summit")
	assert_near(Terrain.ground_height_at(12), 24.0, "flat store summit")
	assert_near(Terrain.ground_height_at(44), 0.0, "foot")
	assert_near(Terrain.ground_height_at(90), 0.0, "walkable surrounding land")
	for radius in range(1, 110):
		var rise := Terrain.ground_height_at(radius - 1) - Terrain.ground_height_at(radius)
		assert_true(rise >= 0 and rise <= 0.76, "every metre has a walkable slope")


func test_rendered_surface_supplies_collision() -> void:
	var terrain := Terrain.build()
	var body := terrain.get_node("WalkableMountain")
	assert_true(body is StaticBody3D)
	assert_true(body.get_child(1).shape is ConcavePolygonShape3D)
	assert_true(terrain.get_node_or_null("Sea") == null)
	assert_true(terrain.get_node_or_null("DryValley") != null)
	terrain.free()
