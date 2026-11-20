extends CharacterBody3D
## Procedural wildlife. A small state machine roams the first terrace and flees hits.

signal attacked(damage: float, from: Vector3)

signal defeated(animal_id: String, rare: bool, trick_shot: bool, at: Vector3)

const HuntFX := preload("res://scripts/hunting/hunt_fx.gd")
const MeshBatch := preload("res://scripts/world/mesh_batch.gd")
const LONG_SHOT_DISTANCE := 18.0
const Terrain := preload("res://scripts/world/island_builder.gd")

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
var attack_windup := -1.0
var _attack_cooldown := 0.0
var _flight_time := 0.0
var _flight_rest := 0.0
var _wings: Array[Node3D] = []


func _ready() -> void:
	add_to_group("hunt_animals")
	_rng.seed = rng_seed if rng_seed != 0 else hash("%s:%s:%s" % [animal_id, name, position])
	health = maxf(1.0, float(definition.get("hp", 24.0)))
	_body_radius = maxf(0.12, float(definition.get("radius", 0.46 if animal_id == "rabbit" else 0.72)))
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
	match animal_id:
		"boar": _build_boar()
		"rabbit": _build_rabbit()
		"deer", "goat": _build_hoofed()
		"fox", "wolf": _build_canine()
		"bear": _build_bear()
		"ant": _build_ant()
		"bird": _build_bird()
	MeshBatch.combine(_visual)
	_build_collider()
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(46.0)
	_decide_target()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	if animal_id == "bird":
		_tick_bird(delta)
		return
	var hunting := _tick_predator(delta)
	_decision_time -= delta
	_flee_time = maxf(0.0, _flee_time - delta)
	var timid: bool = str(definition.get("behavior", "flee")) in ["flee", "skittish"]
	if not hunting and timid and is_instance_valid(player):
		var flat_distance := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length()
		if flat_distance < 7.0:
			_flee_time = 1.8
	if hunting:
		pass
	elif _flee_time > 0.0 and is_instance_valid(player):
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
	if attack_windup > 0:
		move_speed = 0
	elif hunting:
		move_speed *= 1.1
	elif _flee_time > 0.0:
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
	if global_position.y < Terrain.ground_height_at(Vector2(global_position.x, global_position.z).length()) - 0.5:
		global_position.y = safe.y
		velocity.y = 0.0
	if desired.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, delta * 9.0))
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	_visual.position.y = absf(sin(_age * (12.0 if animal_id == "rabbit" else 8.0))) * minf(flat_speed, 4.0) * 0.035
	_visual.rotation.z = sin(_age * 8.0) * minf(flat_speed, 4.0) * 0.012


func _tick_predator(delta: float) -> bool:
	_attack_cooldown = maxf(0, _attack_cooldown - delta)
	if str(definition.get("behavior", "")) != "hostile" or not is_instance_valid(player):
		return false
	var distance := global_position.distance_to(player.global_position)
	var safe := Vector2(player.position.x, player.position.z).length() < 14
	if safe or distance > float(definition.get("aggro_range", 8)) + (5 if _flee_time > 0 else 0):
		attack_windup = -1
		return false
	_target = _safe_point(player.global_position)
	if attack_windup > 0:
		attack_windup -= delta
		_visual.rotation.x = -0.12
		if attack_windup <= 0:
			_visual.rotation.x = 0
			_attack_cooldown = 1.8
			attack_windup = -1
			if distance < 2.6:
				var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, player.global_position + Vector3.UP)
				ray.exclude = [get_rid()]
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit["collider"] == player:
					attacked.emit(float(definition["attack_damage"]), global_position)
	elif _attack_cooldown <= 0 and distance < 2.4:
		attack_windup = float(definition.get("attack_windup", 0.7))
	return true


func _tick_bird(delta: float) -> void:
	_decision_time -= delta
	_flight_rest = maxf(0, _flight_rest - delta)
	var near := is_instance_valid(player) and global_position.distance_to(player.global_position) < 6.5
	if _flight_time <= 0 and _flight_rest <= 0 and near:
		_flight_time = 5.0
		_flight_rest = 8.0
		var away := global_position - player.global_position
		away.y = 0
		_target = _safe_point(global_position + away.normalized() * 14)
	elif _decision_time <= 0 and _flight_time <= 0:
		_decide_target()
	_flight_time = maxf(0, _flight_time - delta)
	var flying := _flight_time > 0
	var toward := _target - global_position
	toward.y = 0
	var desired := toward.normalized() * (6.0 if flying else 1.5) if toward.length() > 0.7 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, desired.x, delta * 8)
	velocity.z = move_toward(velocity.z, desired.z, delta * 8)
	var ground := Terrain.ground_height_at(Vector2(position.x, position.z).length())
	velocity.y = clampf((ground + 3.5 - position.y) * 3, -4, 5) if flying else (-1.0 if is_on_floor() else velocity.y - delta * 12)
	move_and_slide()
	var safe := _safe_point(position)
	position.x = safe.x
	position.z = safe.z
	if position.y < ground - 0.3:
		position.y = ground + 0.1
	if desired.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1, delta * 6))
	for index in _wings.size():
		_wings[index].rotation.z = (1 if index == 0 else -1) * (sin(_age * 18) * 0.7 if flying else 0.9)
	_visual.position.y = absf(sin(_age * 9)) * 0.06 if not flying else 0.0


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
	return Vector3(flat.x, maxf(Terrain.ground_height_at(flat.length()) + 0.05, point.y), flat.y)


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
	var cream := _body_color.lerp(Color("fff5df"), 0.64)
	var shade := _body_color.darkened(0.16)
	var pink := Color("dca1a0") if not rare else Color("c98c3d")
	var ink := Color("24333b")
	_sphere(Vector3(0.0, 0.45, 0.08) * size, Vector3(0.40, 0.43, 0.49) * size, _body_color)
	_sphere(Vector3(0.0, 0.37, -0.20) * size, Vector3(0.29, 0.32, 0.28) * size, cream)
	_sphere(Vector3(0.0, 0.68, -0.33) * size, Vector3(0.30, 0.29, 0.31) * size, _body_color.lightened(0.10))
	_head_center = Vector3(0.0, 0.68, -0.33) * size
	_head_radius = 0.29 * size
	for side in [-1.0, 1.0]:
		# Overlapping haunch, long rear foot and little front paw give a crouched silhouette.
		_sphere(Vector3(side * 0.29, 0.32, 0.22) * size, Vector3(0.22, 0.28, 0.29) * size, _body_color)
		_sphere(Vector3(side * 0.28, 0.12, 0.17) * size, Vector3(0.18, 0.11, 0.32) * size, shade)
		_sphere(Vector3(side * 0.19, 0.13, -0.30) * size, Vector3(0.10, 0.13, 0.18) * size, cream)
		for toe in [-1.0, 1.0]:
			_segment(Vector3(side * 0.19 + toe * 0.025, 0.11, -0.459) * size,
				Vector3(side * 0.19 + toe * 0.025, 0.15, -0.463) * size, 0.006 * size, shade)
		var ear := _sphere(Vector3(side * 0.13, 1.04, -0.29) * size, Vector3(0.09, 0.36, 0.105) * size, _body_color)
		ear.rotation.z = side * -0.14
		var inner_ear := _sphere(Vector3(side * 0.13, 1.05, -0.37) * size, Vector3(0.045, 0.25, 0.032) * size, pink)
		inner_ear.rotation.z = side * -0.14
		# Eyes wrap around the cheek so they remain readable from a hunting angle.
		_sphere(Vector3(side * 0.247, 0.748, -0.493) * size, Vector3(0.064, 0.079, 0.045) * size, cream)
		_sphere(Vector3(side * 0.262, 0.758, -0.519) * size, Vector3(0.045, 0.060, 0.035) * size, ink)
		_sphere(Vector3(side * 0.272, 0.780, -0.541) * size, Vector3(0.013, 0.018, 0.009) * size, Color("fff9ec"))
		_sphere(Vector3(side * 0.13, 0.625, -0.565) * size, Vector3(0.14, 0.10, 0.10) * size, cream)
		for whisker in 2:
			var height := 0.616 + float(whisker) * 0.025
			_segment(Vector3(side * 0.135, height, -0.640) * size,
				Vector3(side * 0.34, height + float(whisker * 2 - 1) * 0.026, -0.61) * size,
				0.004 * size, shade)
	_sphere(Vector3(0.0, 0.65, -0.658) * size, Vector3(0.048, 0.035, 0.026) * size, pink)
	_segment(Vector3(0.0, 0.622, -0.649) * size, Vector3(0.0, 0.599, -0.641) * size, 0.005 * size, ink)
	_sphere(Vector3(0.0, 0.48, 0.51) * size, Vector3(0.17, 0.17, 0.17) * size, cream)
	if rare:
		_sphere(Vector3(0.0, 0.84, -0.51) * size, Vector3(0.055, 0.07, 0.027) * size, Color("fff9cc"))
		_add_rare_mark(Vector3(0.0, 1.58, -0.1) * size)


func _build_boar() -> void:
	var size := _body_radius / 0.72
	var mane := _body_color.darkened(0.28)
	var cream := Color("f9e7bc")
	var snout := Color("c99380") if not rare else Color("e3aa54")
	var ink := Color("26313a")
	_sphere(Vector3(0.0, 0.68, 0.10) * size, Vector3(0.63, 0.62, 0.85) * size, _body_color)
	_sphere(Vector3(0.0, 0.98, 0.02) * size, Vector3(0.48, 0.33, 0.69) * size, _body_color.darkened(0.12))
	_sphere(Vector3(0.0, 0.64, -0.60) * size, Vector3(0.48, 0.44, 0.49) * size, _body_color.lightened(0.12))
	_head_center = Vector3(0.0, 0.64, -0.62) * size
	_head_radius = 0.44 * size
	_sphere(Vector3(0.0, 0.53, -1.02) * size, Vector3(0.28, 0.22, 0.16) * size, snout)
	_sphere(Vector3(0.0, 0.51, -1.145) * size, Vector3(0.23, 0.145, 0.035) * size, snout.lightened(0.12))
	_segment(Vector3(-0.13, 0.383, -1.04) * size, Vector3(0.13, 0.383, -1.04) * size, 0.012 * size, mane)
	for side in [-1.0, 1.0]:
		_sphere(Vector3(side * 0.10, 0.54, -1.179) * size, Vector3(0.034, 0.046, 0.012) * size, ink)
		_sphere(Vector3(side * 0.345, 0.83, -0.865) * size, Vector3(0.095, 0.095, 0.052) * size, _body_color.darkened(0.12))
		_sphere(Vector3(side * 0.365, 0.83, -0.895) * size, Vector3(0.050, 0.060, 0.035) * size, ink)
		_sphere(Vector3(side * 0.377, 0.851, -0.919) * size, Vector3(0.014, 0.018, 0.009) * size, Color("fff9ec"))
		_segment(Vector3(side * 0.28, 0.925, -0.884) * size,
			Vector3(side * 0.42, 0.914, -0.79) * size, 0.034 * size, mane)
		var ear := _sphere(Vector3(side * 0.38, 1.10, -0.55) * size, Vector3(0.19, 0.24, 0.10) * size, mane)
		ear.rotation.z = side * -0.55
		var inner_ear := _sphere(Vector3(side * 0.39, 1.105, -0.624) * size, Vector3(0.115, 0.155, 0.025) * size, snout)
		inner_ear.rotation.z = side * -0.55
		_sphere(Vector3(side * 0.275, 0.475, -0.96) * size, Vector3(0.09, 0.10, 0.08) * size, mane)
		var tusk := CylinderMesh.new()
		tusk.top_radius = 0.0
		tusk.bottom_radius = 0.075 * size
		tusk.height = 0.27 * size
		tusk.radial_segments = 5
		var tusk_visual := _mesh(tusk, Vector3(side * 0.28, 0.51, -0.95) * size, cream)
		tusk_visual.rotation.z = side * -0.35
		for front in [-1.0, 1.0]:
			_sphere(Vector3(side * 0.40, 0.25, front * 0.46) * size, Vector3(0.18, 0.29, 0.20) * size, mane)
			_sphere(Vector3(side * 0.40, 0.08, front * 0.46 - 0.03) * size, Vector3(0.19, 0.09, 0.23) * size, ink)
			_segment(Vector3(side * 0.40, 0.06, front * 0.46 - 0.244) * size,
				Vector3(side * 0.40, 0.12, front * 0.46 - 0.22) * size, 0.009 * size, mane)
		_sphere(Vector3(side * 0.575, 0.69, 0.20) * size, Vector3(0.065, 0.29, 0.50) * size, _body_color.lightened(0.12))
	for index in 5:
		var bristle := CylinderMesh.new()
		bristle.top_radius = 0.0
		bristle.bottom_radius = 0.105 * size
		bristle.height = 0.29 * size
		bristle.radial_segments = 4
		var tuft := _mesh(bristle, Vector3(0.0, 1.24, -0.43 + float(index) * 0.24) * size, mane)
		tuft.rotation.x = -0.23
	_segment(Vector3(0.0, 0.85, 0.87) * size, Vector3(0.10, 0.92, 1.03) * size, 0.027 * size, mane)
	_sphere(Vector3(0.10, 0.92, 1.03) * size, Vector3(0.06, 0.065, 0.07) * size, mane)
	if rare:
		_sphere(Vector3(0.0, 0.87, -0.965) * size, Vector3(0.07, 0.13, 0.028) * size, cream)
		_add_rare_mark(Vector3(0.0, 1.65, 0.0) * size)


func _build_ant() -> void:
	var dark := _body_color.darkened(0.2)
	_sphere(Vector3(0, 0.19, 0.20), Vector3(0.19, 0.16, 0.25), _body_color)
	_sphere(Vector3(0, 0.19, -0.08), Vector3(0.10, 0.10, 0.12), dark)
	_head_center = Vector3(0, 0.21, -0.28)
	_head_radius = 0.13
	_sphere(_head_center, Vector3(0.14, 0.13, 0.14), _body_color)
	for side in [-1.0, 1.0]:
		for leg in 3:
			var root := Vector3(side * 0.06, 0.18, -0.13 + leg * 0.12)
			var knee := root + Vector3(side * 0.20, 0.02, (leg - 1) * 0.09)
			_segment(root, knee, 0.018, dark)
			_segment(knee, knee + Vector3(side * 0.08, -0.18, 0.02), 0.012, dark)
		_segment(Vector3(side * 0.07, 0.29, -0.35), Vector3(side * 0.14, 0.40, -0.47), 0.012, dark)
		_segment(Vector3(side * 0.14, 0.40, -0.47), Vector3(side * 0.20, 0.39, -0.54), 0.009, dark)
		_sphere(Vector3(side * 0.10, 0.25, -0.37), Vector3.ONE * 0.025, Color("141c20"))
	if rare:
		_add_rare_mark(Vector3(0, 0.7, 0))


func _build_bird() -> void:
	var cream := Color("e5d5b2")
	_sphere(Vector3(0, 0.38, 0.05), Vector3(0.25, 0.28, 0.39), _body_color)
	_sphere(Vector3(0, 0.39, -0.15), Vector3(0.19, 0.22, 0.22), cream)
	_head_center = Vector3(0, 0.63, -0.25)
	_head_radius = 0.19
	_sphere(_head_center, Vector3.ONE * 0.20, _body_color)
	_segment(Vector3(0, 0.61, -0.38), Vector3(0, 0.58, -0.58), 0.065, Color("e8b456"))
	for side in [-1.0, 1.0]:
		_sphere(Vector3(side * 0.15, 0.68, -0.35), Vector3.ONE * 0.035, Color("18272b"))
		_segment(Vector3(side * 0.11, 0.22, 0), Vector3(side * 0.11, 0.04, 0), 0.025, Color("c28e4e"))
		_segment(Vector3(side * 0.11, 0.04, 0), Vector3(side * 0.11, 0.04, -0.15), 0.018, Color("c28e4e"))
		var wing := _sphere(Vector3(side * 0.27, 0.43, 0.08), Vector3(0.36, 0.065, 0.31), _body_color.darkened(0.2))
		# Preserve movable wing meshes when static geometry is batched.
		wing.add_child(Node.new())
		_wings.append(wing)
	_sphere(Vector3(0, 0.40, 0.47), Vector3(0.18, 0.08, 0.29), _body_color.darkened(0.25))
	if rare:
		_add_rare_mark(Vector3(0, 1.0, 0))


func _build_hoofed() -> void:
	var deer := animal_id == "deer"
	var height := 1.25 if deer else 0.85
	var length := 0.80 if deer else 0.61
	var cream := _body_color.lightened(0.4)
	var hoof := Color("302b29")
	_sphere(Vector3(0, height, 0.1), Vector3(0.4, 0.45, length), _body_color)
	_segment(Vector3(0, height, -0.45), Vector3(0, height + 0.55, -0.65), 0.24, _body_color)
	_head_center = Vector3(0, height + 0.6, -0.78)
	_head_radius = 0.27
	_sphere(_head_center, Vector3(0.24, 0.28, 0.37), _body_color)
	_sphere(_head_center + Vector3(0, -0.08, -0.28), Vector3(0.17, 0.14, 0.2), cream)
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			var foot := Vector3(side * 0.27, 0.13, front * length * 0.7)
			_segment(foot, Vector3(foot.x, height, foot.z), 0.085, _body_color.darkened(0.15))
			_sphere(foot, Vector3(0.10, 0.13, 0.14), hoof)
		_sphere(_head_center + Vector3(side * 0.31, 0.19, 0), Vector3(0.24, 0.10, 0.12), cream)
		_sphere(_head_center + Vector3(side * 0.21, 0.06, -0.18), Vector3(0.045, 0.05, 0.04), hoof)
		var base := _head_center + Vector3(side * 0.14, 0.23, 0)
		var tip := base + Vector3(side * 0.18, 0.60 if deer else 0.38, 0.18)
		_segment(base, tip, 0.045, cream if deer else hoof)
		if deer:
			for branch in 3:
				var joint := base.lerp(tip, 0.3 + branch * 0.22)
				_segment(joint, joint + Vector3(side * 0.20, 0.22, -0.12), 0.027, cream)
	if not deer:
		_segment(_head_center + Vector3(0, -0.18, -0.17), _head_center + Vector3(0, -0.48, -0.15), 0.10, cream)
	_sphere(Vector3(0, height + 0.12, length + 0.05), Vector3(0.14, 0.18, 0.20), cream)
	if rare:
		_add_rare_mark(_head_center + Vector3.UP * 1.0)


func _build_canine() -> void:
	var fox := animal_id == "fox"
	var size := 0.75 if fox else 1.1
	var cream := Color("e4d9bc") if fox else Color("a6adb1")
	var ink := Color("292c2d")
	_sphere(Vector3(0, 0.63, 0.1) * size, Vector3(0.32, 0.36, 0.70) * size, _body_color)
	_head_center = Vector3(0, 0.92, -0.65) * size
	_head_radius = 0.27 * size
	_sphere(_head_center, Vector3(0.25, 0.28, 0.29) * size, _body_color)
	_sphere(Vector3(0, 0.80, -0.91) * size, Vector3(0.15, 0.13, 0.29) * size, cream)
	_sphere(Vector3(0, 0.83, -1.14) * size, Vector3(0.085, 0.065, 0.065) * size, ink)
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			_segment(Vector3(side * 0.23, 0.62, front * 0.43) * size, Vector3(side * 0.23, 0.1, front * 0.43) * size, 0.075 * size, _body_color)
			_sphere(Vector3(side * 0.23, 0.1, front * 0.43 - 0.06) * size, Vector3(0.10, 0.10, 0.16) * size, ink)
		var ear := CylinderMesh.new()
		ear.top_radius = 0
		ear.bottom_radius = 0.14 * size
		ear.height = 0.35 * size
		ear.radial_segments = 3
		_mesh(ear, Vector3(side * 0.18, 1.24, -0.60) * size, _body_color)
		_sphere(Vector3(side * 0.20, 0.96, -0.83) * size, Vector3(0.04, 0.045, 0.035) * size, ink)
	var tail := _sphere(Vector3(0, 0.52, 0.96) * size, Vector3(0.20, 0.22, 0.50) * size, _body_color)
	tail.rotation.x = 0.35
	_sphere(Vector3(0, 0.36, 1.31) * size, Vector3(0.16, 0.16, 0.23) * size, cream)
	if rare:
		_add_rare_mark(Vector3(0, 1.65, -0.3) * size)


func _build_bear() -> void:
	var dark := _body_color.darkened(0.2)
	_sphere(Vector3(0, 1.0, 0.15), Vector3(0.78, 0.80, 1.10), _body_color)
	_sphere(Vector3(0, 1.4, -0.35), Vector3(0.65, 0.65, 0.7), _body_color)
	_head_center = Vector3(0, 1.25, -1.0)
	_head_radius = 0.46
	_sphere(_head_center, Vector3(0.5, 0.48, 0.5), _body_color)
	_sphere(Vector3(0, 1.12, -1.42), Vector3(0.28, 0.23, 0.25), Color("967254"))
	_sphere(Vector3(0, 1.2, -1.63), Vector3(0.15, 0.11, 0.09), Color("292b2b"))
	for side in [-1.0, 1.0]:
		_sphere(Vector3(side * 0.37, 1.68, -0.92), Vector3(0.18, 0.20, 0.13), dark)
		_sphere(Vector3(side * 0.28, 1.38, -1.38), Vector3(0.05, 0.05, 0.035), Color("161d20"))
		for front in [-1.0, 1.0]:
			_sphere(Vector3(side * 0.51, 0.42, front * 0.65), Vector3(0.29, 0.47, 0.32), dark)
			_sphere(Vector3(side * 0.51, 0.15, front * 0.65 - 0.10), Vector3(0.31, 0.16, 0.39), dark)
	if rare:
		_add_rare_mark(Vector3(0, 2.2, -0.5))


func _add_rare_mark(at: Vector3) -> void:
	# A small faceted jewel reads as special without adding a light to every animal.
	for half in [-1.0, 1.0]:
		var gem := CylinderMesh.new()
		gem.top_radius = 0.0
		gem.bottom_radius = 0.11
		gem.height = 0.14
		gem.radial_segments = 4
		var visual := _mesh(gem, at + Vector3(0.0, half * 0.07, 0.0), Color("fff0a6"))
		visual.rotation.x = PI if half < 0.0 else 0.0
		visual.rotation.y = PI / 4.0


func _segment(start: Vector3, end: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.75
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 5
	var visual := _mesh(mesh, (start + end) * 0.5, color)
	visual.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))
	return visual


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
