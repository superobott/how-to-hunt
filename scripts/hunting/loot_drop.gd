extends Area3D
## Collectable presentation only. The world owns inventory, rewards and removal.

const Text := preload("res://scripts/core/game_text.gd")

var animal_id: String = "rabbit"
var rare: bool = false
var trick_shot: bool = false

var _display: Node3D
var _stars: Array[Node3D] = []
var _age: float = 0.0


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
	var leather := Color(0.99, 0.72, 0.18) if rare else Color(0.20, 0.71, 0.66)
	_sphere(_display, Vector3.ZERO, Vector3(0.29, 0.27, 0.22), leather)
	_box(_display, Vector3(0.0, 0.13, -0.12), Vector3(0.44, 0.17, 0.14), leather.lightened(0.18))
	_box(_display, Vector3(0.0, 0.0, -0.23), Vector3(0.11, 0.15, 0.045), Color(1.0, 0.90, 0.58))
	_box(_display, Vector3(-0.12, 0.30, 0.0), Vector3(0.045, 0.19, 0.055), leather.darkened(0.25))
	_box(_display, Vector3(0.12, 0.30, 0.0), Vector3(0.045, 0.19, 0.055), leather.darkened(0.25))
	_box(_display, Vector3(0.0, 0.38, 0.0), Vector3(0.26, 0.045, 0.055), leather.darkened(0.25))
	for index in 3:
		var star := _sphere(self, Vector3.ZERO, Vector3(0.085, 0.14, 0.085), Color(1.0, 0.88, 0.36))
		_stars.append(star)
	var label := Label3D.new()
	label.text = Text.get_text("world.rare_loot" if rare else "world.loot")
	label.font_size = 30
	label.pixel_size = 0.008
	label.position.y = 1.23
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.86, 0.37) if rare else Color(0.81, 1.0, 0.92)
	label.outline_size = 6
	add_child(label)


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


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(parent, mesh, at, color)


func _mesh(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.emission_enabled = true
	material.emission = color * 0.16
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)
	return visual
