extends CharacterBody3D
## First-person player. Reads input, asks PlayerMotion what to do, and moves the body.
## All movement rules live in PlayerMotion; this node only gathers input and applies results.

signal respawned

const Motion := preload("res://scripts/core/player_motion.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const IslandBuilder := preload("res://scripts/world/island_builder.gd")

const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.8
const EYE_HEIGHT := 1.6
const WALL_RAY_HEIGHT := 0.5
const WALL_RAY_LENGTH := 0.9
## Ledge check used before a hop over the top: a ray dropped from just past the wall, above
## the point where the wall ray lost contact. It only hits if there is ground to land on.
const LEDGE_REACH := 0.6
const LEDGE_RAY_HEIGHT := 1.4
const LEDGE_RAY_DROP := 1.6

@export var mouse_sensitivity: float = 0.0025 ## radians per pixel
@export var stick_look_speed: float = 2.5 ## radians per second at full stick

## Set by the world. Decides where the cliff is and where to respawn.
var bounds: RefCounted = null

## Camera angles in radians. Set `yaw` to turn the player from code.
var yaw: float = 0.0
var pitch: float = 0.0
var climbing: bool = false

var _camera: Camera3D
var _head: Node3D
var _wall_ray: RayCast3D
var _ledge_ray: RayCast3D
## Horizontal direction into the wall being climbed. Fixed at grab time so turning the camera
## mid-climb neither loses the wall nor changes where a ledge hop or wall jump sends the player.
var _climb_dir: Vector3 = Vector3.FORWARD


func _ready() -> void:
	InputSetup.ensure_actions()
	_build_nodes()
	floor_snap_length = 0.4
	floor_stop_on_slope = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_apply_look(motion.relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	var stick_look := Vector2(
		Input.get_axis(InputSetup.LOOK_LEFT, InputSetup.LOOK_RIGHT),
		Input.get_axis(InputSetup.LOOK_UP, InputSetup.LOOK_DOWN)
	)
	if stick_look != Vector2.ZERO:
		_apply_look(stick_look * stick_look_speed * delta)
	rotation.y = yaw

	var move_input := Input.get_vector(
		InputSetup.MOVE_LEFT, InputSetup.MOVE_RIGHT, InputSetup.MOVE_BACK, InputSetup.MOVE_FORWARD
	)
	var jump_pressed := Input.is_action_just_pressed(InputSetup.JUMP)
	var sprinting := Input.is_action_pressed(InputSetup.SPRINT)

	_update_climb_state(move_input, jump_pressed)
	if climbing:
		velocity = Motion.climb_velocity(move_input.y)
	else:
		_step_walking(move_input, jump_pressed, sprinting, delta)
	move_and_slide()
	_enforce_bounds()


func respawn() -> void:
	if bounds != null:
		global_position = bounds.respawn_position()
	velocity = Vector3.ZERO
	climbing = false
	respawned.emit()


func _step_walking(move_input: Vector2, jump_pressed: bool, sprinting: bool, delta: float) -> void:
	var wish := Motion.wish_direction(move_input, yaw)
	var on_floor := is_on_floor()
	velocity = Motion.step_horizontal(velocity, wish, Motion.target_speed(sprinting), on_floor, delta)
	velocity.y = Motion.step_vertical(velocity.y, on_floor, jump_pressed, delta)


## Decides whether to grab, keep or let go of a climbable wall. Letting go can launch the player:
## a hop over the ledge at the top, or a push away from the wall when jumping off.
func _update_climb_state(move_input: Vector2, jump_pressed: bool) -> void:
	if not climbing:
		var wall_ahead := _wall_ray.is_colliding()
		var climbable := wall_ahead and _is_climbable(_wall_ray.get_collider())
		if Motion.can_start_climb(wall_ahead, climbable, move_input.y):
			climbing = true
			_climb_dir = Motion.climb_direction(
				_wall_ray.get_collision_normal(), -global_transform.basis.z
			)
		return

	# While climbing, keep the wall ray on the wall that was grabbed, not on where the camera points.
	_wall_ray.global_basis = Basis.looking_at(_climb_dir, Vector3.UP)
	_wall_ray.force_raycast_update()
	var wall_ahead := _wall_ray.is_colliding()
	if not wall_ahead and move_input.y > 0.0 and _ledge_ahead():
		_end_climb()
		velocity = Motion.mantle_velocity(_climb_dir)
	elif Motion.should_stop_climb(wall_ahead, jump_pressed, is_on_floor(), move_input.y):
		_end_climb()
		if jump_pressed:
			velocity = Motion.wall_jump_velocity(-_climb_dir)


func _end_climb() -> void:
	climbing = false
	_wall_ray.rotation = Vector3.ZERO # follow the camera direction again


## True when there is ground just past the wall to hop onto. Without it, losing the wall means
## the wall ended some other way (a gap, an overhang), and the player lets go instead of launching.
func _ledge_ahead() -> bool:
	_ledge_ray.global_position = (
		global_position + _climb_dir * LEDGE_REACH + Vector3.UP * LEDGE_RAY_HEIGHT
	)
	_ledge_ray.force_raycast_update()
	return _ledge_ray.is_colliding()


func _enforce_bounds() -> void:
	if bounds == null:
		return
	global_position = bounds.clamp_to_outer(global_position)
	if bounds.should_respawn(global_position):
		respawn()


func _apply_look(look_delta: Vector2) -> void:
	var angles := Motion.apply_look(yaw, pitch, look_delta)
	yaw = angles.x
	pitch = angles.y
	if _head != null:
		_head.rotation.x = pitch


static func _is_climbable(collider: Object) -> bool:
	return collider is Node and (collider as Node).is_in_group(IslandBuilder.CLIMBABLE_GROUP)


func _build_nodes() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position = Vector3(0.0, CAPSULE_HEIGHT / 2.0, 0.0)
	add_child(collider)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	add_child(_head)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = true
	_camera.fov = 75.0
	_head.add_child(_camera)

	_wall_ray = RayCast3D.new()
	_wall_ray.name = "WallRay"
	_wall_ray.position = Vector3(0.0, WALL_RAY_HEIGHT, 0.0)
	_wall_ray.target_position = Vector3(0.0, 0.0, -WALL_RAY_LENGTH)
	_wall_ray.collide_with_areas = false
	add_child(_wall_ray)

	_ledge_ray = RayCast3D.new()
	_ledge_ray.name = "LedgeRay"
	_ledge_ray.target_position = Vector3(0.0, -LEDGE_RAY_DROP, 0.0)
	_ledge_ray.collide_with_areas = false
	add_child(_ledge_ray)
