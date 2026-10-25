extends Node3D
## Swept ray movement keeps arrows from passing through small animals at high speed.

const HuntFX := preload("res://scripts/hunting/hunt_fx.gd")

var direction := Vector3.FORWARD
var speed: float = 35.0
var damage: float = 24.0
var gravity: float = 2.4
var shooter: CollisionObject3D
var shot_origin := Vector3.ZERO
var collision_mask: int = 1

var _velocity := Vector3.ZERO
var _age: float = 0.0
var _spent: bool = false


func _ready() -> void:
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	_velocity = direction.normalized() * speed
	if shot_origin == Vector3.ZERO:
		shot_origin = global_position
	_build_arrow()
	look_at(global_position + _velocity, _safe_up(_velocity))


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= 5.0:
		queue_free()
		return
	var next := global_position + _velocity * delta + Vector3.DOWN * gravity * delta * delta * 0.5
	var ray := PhysicsRayQueryParameters3D.create(global_position, next, collision_mask)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.hit_from_inside = true
	if is_instance_valid(shooter):
		ray.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		_spent = true
		global_position = hit["position"]
		var collider: Object = hit["collider"]
		if is_instance_valid(collider) and collider.has_method("take_hit"):
			collider.call("take_hit", damage, hit["position"], shot_origin)
		else:
			HuntFX.burst(get_parent(), global_position, Color(0.88, 0.87, 0.72))
		queue_free()
		return
	global_position = next
	_velocity += Vector3.DOWN * gravity * delta
	if not _velocity.is_zero_approx():
		look_at(global_position + _velocity, _safe_up(_velocity))


func _build_arrow() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.018
	shaft.bottom_radius = 0.018
	shaft.height = 0.58
	shaft.radial_segments = 5
	_add_mesh(shaft, Vector3.ZERO, Color(0.61, 0.35, 0.15), Vector3(PI / 2.0, 0.0, 0.0))
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.065
	tip.height = 0.18
	tip.radial_segments = 4
	_add_mesh(tip, Vector3(0.0, 0.0, -0.34), Color(0.79, 0.92, 0.95), Vector3(-PI / 2.0, 0.0, 0.0))
	for index in 2:
		var fin := BoxMesh.new()
		fin.size = Vector3(0.15, 0.014, 0.14)
		_add_mesh(fin, Vector3(0.0, 0.0, 0.22), Color(0.98, 0.60, 0.25), Vector3(0.0, 0.0, float(index) * PI / 2.0))


func _add_mesh(mesh: PrimitiveMesh, at: Vector3, color: Color, angles: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	visual.rotation = angles
	add_child(visual)


static func _safe_up(travel: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(travel.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
