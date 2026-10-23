extends CharacterBody3D
## Procedural wildlife. A small state machine roams the first terrace and flees hits.

signal defeated(animal_id: String, rare: bool, trick_shot: bool, at: Vector3)

const HuntFX := preload("res://scripts/hunting/hunt_fx.gd")
const MeshBatch := preload("res://scripts/world/mesh_batch.gd")
const LONG_SHOT_DISTANCE := 18.0

var definition: Dictionary = {}
var animal_id: String = "rabbit"
var rare: bool = false
var player: Node3D
var home := Vector3.ZERO
var rng_seed: int = 0
var inner_radius: float = 44.0
var outer_radius: float = 56.0

var health: float = 24.0
var _rng := RandomNumberGenerator.new()
var _target := Vector3.ZERO
var _decision_time: float = 0.0
var _flee_time: float = 0.0
var _age: float = 0.0
var _dead: bool = false
var _trick_shot: bool = false
var _visual: Node3D
var _head_center := Vector3.ZERO
var _head_radius: float = 0.28
var _body_radius: float = 0.45
var _body_color := Color(0.86, 0.80, 0.69)
var _materials: Dictionary = {}


func _ready() -> void:
	add_to_group("hunt_animals")
	_rng.seed = rng_seed if rng_seed != 0 else hash("%s:%s:%s" % [animal_id, name, position])
	health = maxf(1.0, float(definition.get("hp", 24.0)))
	_body_radius = maxf(0.25, float(definition.get("radius", 0.46 if animal_id == "rabbit" else 0.72)))
	var color_data: Array = definition.get("body_color", [0.86, 0.80, 0.69])
	if color_data.size() >= 3:
		_body_color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]))
	if rare:
		_body_color = Color(1.0, 0.75, 0.25)
	if home == Vector3.ZERO:
		home = global_position
	home = _safe_point(home)
	global_position = _safe_point(global_position)
	_visual = Node3D.new()
	_visual.name = "Model"
	add_child(_visual)
	if animal_id == "boar":
		_build_boar()
	else:
		_build_rabbit()
	MeshBatch.combine(_visual)
	_build_collider()
	floor_snap_length = 0.5
	_decide_target()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	_decision_time -= delta
	_flee_time = maxf(0.0, _flee_time - delta)
	var timid: bool = str(definition.get("behavior", "flee")) in ["flee", "skittish"]
	if timid and is_instance_valid(player):
		var flat_distance := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length()
		if flat_distance < 7.0:
			_flee_time = 1.8
	if _flee_time > 0.0 and is_instance_valid(player):
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3.RIGHT
		_target = _safe_point(global_position + away.normalized() * 7.0)
		# Near either rim, the tangential component keeps prey running around the terrace.
		if global_position.distance_to(_target) < 1.0:
			var tangent := Vector3(-global_position.z, 0.0, global_position.x).normalized()
			_target = _safe_point(global_position + tangent * 6.0)
	elif _decision_time <= 0.0:
		_decide_target()
	var wish := _target - global_position
	wish.y = 0.0
	var moving := wish.length() > 0.5
	var move_speed := float(definition.get("speed", 3.4))
	if _flee_time > 0.0:
		move_speed *= 1.55
	elif _decision_time < 0.7:
		move_speed = 0.0
	var desired := wish.normalized() * move_speed if moving else Vector3.ZERO
	velocity.x = move_toward(velocity.x, desired.x, delta * 12.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 12.0)
	velocity.y = -1.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	var safe := _safe_point(global_position)
	global_position.x = safe.x
	global_position.z = safe.z
	if global_position.y < -1.0:
		global_position.y = 0.1
		velocity.y = 0.0
	if desired.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, delta * 9.0))
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	_visual.position.y = absf(sin(_age * (12.0 if animal_id == "rabbit" else 8.0))) * minf(flat_speed, 4.0) * 0.035
	_visual.rotation.z = sin(_age * 8.0) * minf(flat_speed, 4.0) * 0.012


func take_hit(damage: float, hit_position: Vector3, shot_origin: Vector3) -> void:
	if _dead or damage <= 0.0:
		return
	# Head colliders belong to this body too. Classify the actual contact in local space.
	var local_hit := to_local(hit_position)
	var headshot := local_hit.distance_to(_head_center) <= _head_radius * 1.25
	var longshot := shot_origin.distance_to(hit_position) >= LONG_SHOT_DISTANCE
	_trick_shot = _trick_shot or headshot or longshot
	health -= damage * (1.5 if headshot else 1.0)
	_flee_time = 4.0
	_decision_time = 0.0
	HuntFX.burst(get_parent(), hit_position, Color(1.0, 0.87, 0.39) if headshot else Color(0.80, 0.94, 1.0))
	if health <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		HuntFX.burst(get_parent(), global_position + Vector3.UP * 0.6, _body_color.lightened(0.25))
		defeated.emit(animal_id, rare, _trick_shot, global_position)
		queue_free()


func _decide_target() -> void:
	var home_angle := atan2(home.z, home.x)
	var angle := home_angle + _rng.randf_range(-0.28, 0.28)
	var margin := minf(0.8, maxf(0.0, outer_radius - inner_radius) * 0.25)
	var radius := _rng.randf_range(inner_radius + margin, outer_radius - margin)
	_target = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_decision_time = _rng.randf_range(2.0, 4.5)


func _safe_point(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z)
	if flat.is_zero_approx():
		flat = Vector2(0.0, 50.0)
	flat = flat.normalized() * clampf(flat.length(), inner_radius, outer_radius)
	return Vector3(flat.x, maxf(0.05, point.y), flat.y)


func _build_collider() -> void:
	var body_shape := SphereShape3D.new()
	body_shape.radius = _body_radius
	var body_collider := CollisionShape3D.new()
	body_collider.name = "BodyCollider"
	body_collider.shape = body_shape
	body_collider.position.y = _body_radius
	add_child(body_collider)
	var head_shape := SphereShape3D.new()
	head_shape.radius = _head_radius
	var head_collider := CollisionShape3D.new()
	head_collider.name = "HeadCollider"
	head_collider.shape = head_shape
	head_collider.position = _head_center
	add_child(head_collider)


func _build_rabbit() -> void:
	var size := _body_radius / 0.46
	_sphere(Vector3(0.0, 0.45, 0.08) * size, Vector3(0.40, 0.43, 0.49) * size, _body_color)
	_sphere(Vector3(0.0, 0.68, -0.33) * size, Vector3(0.30, 0.29, 0.31) * size, _body_color.lightened(0.10))
	_head_center = Vector3(0.0, 0.68, -0.33) * size
	_head_radius = 0.29 * size
	for side in [-1.0, 1.0]:
		var ear := _sphere(Vector3(side * 0.13, 1.04, -0.29) * size, Vector3(0.09, 0.36, 0.105) * size, _body_color)
		ear.rotation.z = side * -0.14
		var inner_ear := _sphere(Vector3(side * 0.13, 1.05, -0.37) * size, Vector3(0.045, 0.25, 0.032) * size, Color(0.96, 0.55, 0.58))
		inner_ear.rotation.z = side * -0.14
		_sphere(Vector3(side * 0.185, 0.76, -0.555) * size, Vector3(0.054, 0.070, 0.037) * size, Color(0.11, 0.13, 0.18))
		_sphere(Vector3(side * 0.19, 0.785, -0.583) * size, Vector3(0.016, 0.022, 0.011) * size, Color.WHITE)
		_sphere(Vector3(side * 0.27, 0.13, -0.12) * size, Vector3(0.17, 0.12, 0.26) * size, _body_color.darkened(0.06))
	_sphere(Vector3(0.0, 0.62, -0.63) * size, Vector3(0.060, 0.045, 0.035) * size, Color(0.96, 0.55, 0.58))
	_sphere(Vector3(0.0, 0.48, 0.51) * size, Vector3(0.17, 0.17, 0.17) * size, Color(1.0, 0.97, 0.87))
	if rare:
		_add_rare_mark(Vector3(0.0, 1.58, -0.1) * size)


func _build_boar() -> void:
	var size := _body_radius / 0.72
	_sphere(Vector3(0.0, 0.68, 0.10) * size, Vector3(0.63, 0.62, 0.85) * size, _body_color)
	_sphere(Vector3(0.0, 0.64, -0.60) * size, Vector3(0.48, 0.44, 0.49) * size, _body_color.lightened(0.12))
	_head_center = Vector3(0.0, 0.64, -0.62) * size
	_head_radius = 0.44 * size
	_sphere(Vector3(0.0, 0.53, -1.02) * size, Vector3(0.27, 0.22, 0.16) * size, Color(0.88, 0.57, 0.44))
	for side in [-1.0, 1.0]:
		_sphere(Vector3(side * 0.10, 0.55, -1.16) * size, Vector3(0.034, 0.044, 0.020) * size, Color(0.24, 0.18, 0.19))
		_sphere(Vector3(side * 0.34, 0.83, -0.89) * size, Vector3(0.055, 0.067, 0.035) * size, Color(0.11, 0.13, 0.18))
		_sphere(Vector3(side * 0.35, 0.85, -0.915) * size, Vector3(0.016, 0.020, 0.010) * size, Color.WHITE)
		var ear := _sphere(Vector3(side * 0.38, 1.10, -0.55) * size, Vector3(0.19, 0.24, 0.10) * size, _body_color.darkened(0.1))
		ear.rotation.z = side * -0.55
		var tusk := CylinderMesh.new()
		tusk.top_radius = 0.0
		tusk.bottom_radius = 0.075 * size
		tusk.height = 0.27 * size
		tusk.radial_segments = 5
		var tusk_visual := _mesh(tusk, Vector3(side * 0.28, 0.51, -0.95) * size, Color(1.0, 0.93, 0.73))
		tusk_visual.rotation.z = side * -0.35
		for front in [-1.0, 1.0]:
			_sphere(Vector3(side * 0.40, 0.25, front * 0.46) * size, Vector3(0.18, 0.29, 0.20) * size, _body_color.darkened(0.18))
	for index in 5:
		_sphere(Vector3(0.0, 1.18, -0.43 + float(index) * 0.24) * size, Vector3(0.09, 0.19, 0.12) * size, _body_color.darkened(0.23))
	if rare:
		_add_rare_mark(Vector3(0.0, 1.65, 0.0) * size)


func _add_rare_mark(at: Vector3) -> void:
	_sphere(at, Vector3(0.13, 0.23, 0.13), Color(1.0, 0.96, 0.52))


func _sphere(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var visual := _mesh(mesh, at, color)
	visual.scale = size
	return visual


func _mesh(mesh: PrimitiveMesh, at: Vector3, color: Color) -> MeshInstance3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.95
		_materials[color] = material
	mesh.material = _materials[color]
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	_visual.add_child(visual)
	return visual
