extends "res://tests/case_base.gd"

const IslandBounds := preload("res://scripts/core/island_bounds.gd")


func _bounds() -> RefCounted:
	return IslandBounds.new(60.0, 90.0, -40.0, Vector3(0, 1.5, 0))


func test_centre_is_on_the_plateau() -> void:
	assert_false(_bounds().is_past_edge(Vector3(0, 0, 0)), "centre")


func test_edge_is_inclusive() -> void:
	assert_false(_bounds().is_past_edge(Vector3(60, 0, 0)), "exactly on the edge")
	assert_true(_bounds().is_past_edge(Vector3(60.1, 0, 0)), "just past the edge")


func test_edge_uses_horizontal_distance_only() -> void:
	assert_false(_bounds().is_past_edge(Vector3(0, 500, 0)), "high above centre")
	assert_true(_bounds().is_past_edge(Vector3(45, 0, 45)), "diagonal past the edge")


func test_respawn_triggers_only_below_kill_height() -> void:
	var bounds := _bounds()
	assert_false(bounds.should_respawn(Vector3(0, -39.9, 0)), "just above")
	assert_true(bounds.should_respawn(Vector3(0, -40.1, 0)), "just below")


func test_respawn_goes_to_the_spawn_point() -> void:
	assert_eq(_bounds().respawn_position(), Vector3(0, 1.5, 0), "spawn point")


func test_clamp_leaves_inside_positions_alone() -> void:
	var position := Vector3(30, 5, -20)
	assert_eq(_bounds().clamp_to_outer(position), position, "inside")


func test_clamp_pulls_far_positions_back_to_outer_radius() -> void:
	var clamped: Vector3 = _bounds().clamp_to_outer(Vector3(300, -7, 400))
	assert_near(Vector2(clamped.x, clamped.z).length(), 90.0, "on the outer ring")
	assert_near(clamped.y, -7.0, "height unchanged")
	# Direction is preserved (3:4 ratio).
	assert_near(clamped.x / clamped.z, 0.75, "direction preserved")


func test_horizontal_distance_ignores_height() -> void:
	assert_near(IslandBounds.horizontal_distance(Vector3(3, 100, 4)), 5.0, "3-4-5 triangle")
