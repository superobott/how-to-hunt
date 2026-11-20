extends Area3D
## Collectable presentation only. The world owns inventory, rewards and removal.

const MeshBatch := preload("res://scripts/world/mesh_batch.gd")

var animal_id: String = "rabbit"
var rare: bool = false
var trick_shot: bool = false

var _display: Node3D
var _stars: Array[Node3D] = []
var _age: float = 0.0
var _materials: Dictionary = {}


func _ready() -> void:
	add_to_group("hunt_loot")
	monitoring = false
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.5
	add_child(collider)
	_display = Node3D.new()
	_display.position.y = 0.48
	add_child(_display)
	var gold := Color("f2ce70")
	var disk := CylinderMesh.new()
	disk.top_radius = 0.32
	disk.bottom_radius = 0.32
	disk.height = 0.075
	disk.radial_segments = 16
	var coin := _mesh(_display, disk, Vector3.ZERO, gold, true)
	coin.rotation.x = PI / 2.0
	for side in [-1.0, 1.0]:
		_box(_display, Vector3(0, 0, side * 0.045), Vector3(0.045, 0.35, 0.015), Color("fff2b5"))
		_box(_display, Vector3(0, 0.10, side * 0.045), Vector3(0.16, 0.045, 0.015), Color("fff2b5"))
	MeshBatch.combine(_display)
	for index in 3:
		var star := _gem(self, Vector3.ZERO, Vector3(0.055, 0.15 if rare else 0.11, 0.055), gold)
		_stars.append(star)



func _process(delta: float) -> void:
	_age += delta
	_display.position.y = 0.48 + sin(_age * 2.7) * 0.07
	_display.rotation.y += delta * 0.65
	for index in _stars.size():
		var angle := _age * 1.8 + float(index) * TAU / 3.0
		_stars[index].position = Vector3(cos(angle) * 0.45, 0.66 + sin(angle * 1.7) * 0.17, sin(angle) * 0.45)
		_stars[index].rotation.y += delta * 1.9


func _sphere(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var visual := _mesh(parent, mesh, at, color)
	visual.scale = size
	return visual


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, color)


func _segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 5
	var visual := _mesh(parent, mesh, (start + end) * 0.5, color)
	visual.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))


func _gem(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> Node3D:
	var gem := Node3D.new()
	gem.position = at
	parent.add_child(gem)
	for half in [-1.0, 1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.0
		cone.height = 1.0
		cone.radial_segments = 4
		var visual := _mesh(gem, cone, Vector3(0, half * size.y * 0.25, 0), color, true)
		visual.scale = Vector3(size.x, size.y * 0.5, size.z)
		visual.rotation.x = PI if half < 0.0 else 0.0
		visual.rotation.y = PI / 4.0
	MeshBatch.combine(gem)
	return gem


func _mesh(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, color: Color, sparkle: bool = false) -> MeshInstance3D:
	var key := "%s:%s" % [color.to_html(), sparkle]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.48 if sparkle else 0.92
		material.emission_enabled = sparkle
		material.emission = color * 0.12
		_materials[key] = material
	mesh.material = _materials[key]
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)
	return visual
