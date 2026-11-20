extends RefCounted
## Presentation only: interpolate between host poses; snap spawns/teleports.
const INTERVAL := 0.1
const TELEPORT_DISTANCE := 8.0
var position := Vector3.ZERO
var rotation := Vector3.ZERO
var _start := Vector3.ZERO
var _start_rotation := Vector3.ZERO
var _target := Vector3.ZERO
var _target_rotation := Vector3.ZERO
var _elapsed := INTERVAL
var _initialized := false

func push(next_position: Vector3, next_rotation: Vector3) -> void:
	if not _initialized or position.distance_to(next_position) > TELEPORT_DISTANCE:
		position = next_position
		rotation = next_rotation
		_initialized = true
	_start = position
	_start_rotation = rotation
	_target = next_position
	_target_rotation = next_rotation
	_elapsed = 0.0

func step(delta: float) -> void:
	_elapsed = minf(INTERVAL, _elapsed + maxf(0.0, delta))
	var weight := _elapsed / INTERVAL
	position = _start.lerp(_target, weight)
	rotation = Vector3(lerp_angle(_start_rotation.x, _target_rotation.x, weight),
		lerp_angle(_start_rotation.y, _target_rotation.y, weight), lerp_angle(_start_rotation.z, _target_rotation.z, weight))
