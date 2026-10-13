extends RefCounted
## Pure movement rules for the first-person player. No nodes, no input, no physics engine,
## so every rule here is deterministic and unit-testable. The Player node feeds it state.

const WALK_SPEED := 5.0 ## metres per second
const SPRINT_SPEED := 8.0
const GROUND_ACCEL := 40.0 ## metres per second squared
const AIR_ACCEL := 8.0
const GRAVITY := 24.0
const JUMP_VELOCITY := 8.0
const CLIMB_SPEED := 3.0
const MAX_PITCH := deg_to_rad(89.0)
const CLIMB_START_INPUT := 0.1 ## minimum forward input to grab a wall


## World-space horizontal direction the player wants to move in.
## `input.x` is strafe (right positive), `input.y` is forward (forward positive).
## `yaw` is the camera's rotation around the up axis in radians. The result has length 0 to 1.
static func wish_direction(input: Vector2, yaw: float) -> Vector3:
	var clamped := input.limit_length(1.0)
	var local := Vector3(clamped.x, 0.0, -clamped.y)
	return local.rotated(Vector3.UP, yaw)


static func target_speed(sprinting: bool) -> float:
	return SPRINT_SPEED if sprinting else WALK_SPEED


## Moves the horizontal part of `velocity` toward `wish * speed`. Vertical part is untouched.
## The player has less control in the air.
static func step_horizontal(
	velocity: Vector3, wish: Vector3, speed: float, on_floor: bool, delta: float
) -> Vector3:
	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(wish * speed, accel * delta)
	return Vector3(horizontal.x, velocity.y, horizontal.z)


## New vertical velocity. Jumping is only possible on the floor.
static func step_vertical(vy: float, on_floor: bool, jump_pressed: bool, delta: float) -> float:
	if on_floor:
		return JUMP_VELOCITY if jump_pressed else 0.0
	return vy - GRAVITY * delta


## Peak height of a jump from standing, in metres.
static func jump_height() -> float:
	return JUMP_VELOCITY * JUMP_VELOCITY / (2.0 * GRAVITY)


## True when the player should grab the wall in front of them.
static func can_start_climb(wall_ahead: bool, wall_climbable: bool, forward_input: float) -> bool:
	return wall_ahead and wall_climbable and forward_input > CLIMB_START_INPUT


## True when the player should let go: wall gone, jumped off, or walking back down onto the floor.
static func should_stop_climb(
	wall_ahead: bool, jump_pressed: bool, on_floor: bool, forward_input: float
) -> bool:
	if not wall_ahead or jump_pressed:
		return true
	return on_floor and forward_input <= 0.0


## Velocity while hanging on a wall: up or down with forward/back input, no sideways drift.
static func climb_velocity(forward_input: float) -> Vector3:
	return Vector3(0.0, clampf(forward_input, -1.0, 1.0) * CLIMB_SPEED, 0.0)


static func clamp_pitch(pitch: float) -> float:
	return clampf(pitch, -MAX_PITCH, MAX_PITCH)


## Applies a look delta (radians, already scaled by sensitivity) to the camera angles.
## Returns Vector2(yaw, pitch). Yaw wraps to stay in -PI..PI, pitch is clamped.
static func apply_look(yaw: float, pitch: float, look_delta: Vector2) -> Vector2:
	return Vector2(wrapf(yaw - look_delta.x, -PI, PI), clamp_pitch(pitch - look_delta.y))
