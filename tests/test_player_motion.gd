extends "res://tests/case_base.gd"

const Motion := preload("res://scripts/core/player_motion.gd")

const DT := 1.0 / 60.0


func test_forward_input_faces_negative_z_at_zero_yaw() -> void:
	assert_vec3_near(Motion.wish_direction(Vector2(0, 1), 0.0), Vector3(0, 0, -1), "forward")


func test_strafe_right_is_positive_x_at_zero_yaw() -> void:
	assert_vec3_near(Motion.wish_direction(Vector2(1, 0), 0.0), Vector3(1, 0, 0), "right")


func test_yaw_rotates_the_wish_direction() -> void:
	# Turning left by 90 degrees makes "forward" point along negative X.
	assert_vec3_near(Motion.wish_direction(Vector2(0, 1), PI / 2.0), Vector3(-1, 0, 0), "yaw 90")


func test_diagonal_input_is_not_faster() -> void:
	var wish := Motion.wish_direction(Vector2(1, 1), 0.0)
	assert_near(wish.length(), 1.0, "diagonal length")


func test_no_input_gives_zero_direction() -> void:
	assert_eq(Motion.wish_direction(Vector2.ZERO, 1.2), Vector3.ZERO, "zero input")


func test_partial_stick_gives_partial_speed() -> void:
	assert_near(Motion.wish_direction(Vector2(0, 0.5), 0.0).length(), 0.5, "half stick")


func test_sprint_is_faster_than_walk() -> void:
	assert_true(Motion.target_speed(true) > Motion.target_speed(false), "sprint > walk")


func test_ground_acceleration_reaches_walk_speed() -> void:
	var velocity := Vector3.ZERO
	var wish := Vector3(0, 0, -1)
	for i in 60:
		velocity = Motion.step_horizontal(velocity, wish, Motion.WALK_SPEED, true, DT)
	assert_near(velocity.length(), Motion.WALK_SPEED, "reached walk speed")


func test_horizontal_step_never_overshoots_target() -> void:
	var velocity := Motion.step_horizontal(Vector3(0, 0, -4.9), Vector3(0, 0, -1), 5.0, true, 1.0)
	assert_near(velocity.z, -5.0, "clamped to target")


func test_air_control_is_weaker_than_ground_control() -> void:
	var wish := Vector3(1, 0, 0)
	var ground := Motion.step_horizontal(Vector3.ZERO, wish, 5.0, true, DT)
	var air := Motion.step_horizontal(Vector3.ZERO, wish, 5.0, false, DT)
	assert_true(air.length() < ground.length(), "air < ground")


func test_horizontal_step_keeps_vertical_velocity() -> void:
	var velocity := Motion.step_horizontal(Vector3(0, 3.5, 0), Vector3(1, 0, 0), 5.0, false, DT)
	assert_near(velocity.y, 3.5, "vertical untouched")


func test_stops_when_there_is_no_input() -> void:
	var velocity := Vector3(0, 0, -5)
	for i in 60:
		velocity = Motion.step_horizontal(velocity, Vector3.ZERO, 5.0, true, DT)
	assert_near(velocity.length(), 0.0, "came to rest")


func test_jump_only_works_on_the_floor() -> void:
	assert_near(Motion.step_vertical(0.0, true, true, DT), Motion.JUMP_VELOCITY, "jump on floor")
	var in_air := Motion.step_vertical(2.0, false, true, DT)
	assert_true(in_air < 2.0, "no double jump, gravity applies")


func test_standing_on_floor_has_no_vertical_velocity() -> void:
	assert_near(Motion.step_vertical(-5.0, true, false, DT), 0.0, "standing")


func test_gravity_pulls_down_in_the_air() -> void:
	assert_near(Motion.step_vertical(0.0, false, false, 0.5), -Motion.GRAVITY * 0.5, "fall")


func test_simulated_jump_peaks_at_the_computed_height() -> void:
	var vy := Motion.step_vertical(0.0, true, true, DT)
	var height := 0.0
	var peak := 0.0
	for i in 600:
		height += vy * DT
		vy = Motion.step_vertical(vy, false, false, DT)
		peak = maxf(peak, height)
	# Euler integration overshoots slightly, so allow a small tolerance.
	assert_near(peak, Motion.jump_height(), "jump peak", 0.15)
	assert_true(Motion.jump_height() > 1.0, "can clear a knee-high rock")


func test_climb_starts_only_on_a_climbable_wall_with_forward_input() -> void:
	assert_true(Motion.can_start_climb(true, true, 1.0), "grab")
	assert_false(Motion.can_start_climb(false, true, 1.0), "no wall")
	assert_false(Motion.can_start_climb(true, false, 1.0), "not climbable")
	assert_false(Motion.can_start_climb(true, true, 0.0), "no input")
	assert_false(Motion.can_start_climb(true, true, -1.0), "walking away")


func test_climb_stops_when_wall_ends_or_player_jumps() -> void:
	assert_true(Motion.should_stop_climb(false, false, false, 1.0), "wall ended")
	assert_true(Motion.should_stop_climb(true, true, false, 1.0), "jumped off")
	assert_false(Motion.should_stop_climb(true, false, false, 1.0), "keep climbing")


func test_climbing_down_to_the_floor_lets_go() -> void:
	assert_true(Motion.should_stop_climb(true, false, true, -1.0), "back on floor")
	assert_false(Motion.should_stop_climb(true, false, true, 1.0), "still pushing up")


func test_climb_velocity_is_vertical_only() -> void:
	assert_vec3_near(Motion.climb_velocity(1.0), Vector3(0, Motion.CLIMB_SPEED, 0), "up")
	assert_vec3_near(Motion.climb_velocity(-1.0), Vector3(0, -Motion.CLIMB_SPEED, 0), "down")
	assert_vec3_near(Motion.climb_velocity(5.0), Vector3(0, Motion.CLIMB_SPEED, 0), "clamped")


func test_pitch_is_clamped_short_of_straight_up_and_down() -> void:
	assert_near(Motion.clamp_pitch(10.0), Motion.MAX_PITCH, "up clamp")
	assert_near(Motion.clamp_pitch(-10.0), -Motion.MAX_PITCH, "down clamp")
	assert_true(Motion.MAX_PITCH < PI / 2.0, "never fully vertical")


func test_look_moves_yaw_and_pitch_in_the_expected_direction() -> void:
	# Mouse right (positive x) turns right, which is a negative rotation around up.
	var look := Motion.apply_look(0.0, 0.0, Vector2(0.1, 0.0))
	assert_near(look.x, -0.1, "turn right")
	# Mouse up (negative y) looks up, which is a positive pitch.
	look = Motion.apply_look(0.0, 0.0, Vector2(0.0, -0.1))
	assert_near(look.y, 0.1, "look up")


func test_look_wraps_yaw_and_clamps_pitch() -> void:
	var look := Motion.apply_look(PI - 0.05, 0.0, Vector2(-0.1, 0.0))
	assert_true(absf(look.x) <= PI, "yaw stays in range")
	assert_true(look.x < 0.0, "yaw wrapped past PI")
	look = Motion.apply_look(0.0, Motion.MAX_PITCH, Vector2(0.0, -5.0))
	assert_near(look.y, Motion.MAX_PITCH, "pitch clamped")
