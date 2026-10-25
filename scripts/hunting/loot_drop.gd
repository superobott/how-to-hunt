extends Area3D
## Collectable presentation only. The world owns inventory, rewards and removal.

const Text := preload("res://scripts/core/game_text.gd")
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
	var leather := Color("d5a34d") if rare else Color("428e80")
	var trim := Color("76543a")
	var thread := Color("efdfb5")
	var gold := Color("f2ce70")
	_sphere(_display, Vector3.ZERO, Vector3(0.29, 0.27, 0.22), leather)
	_sphere(_display, Vector3(0.0, -0.04, -0.15), Vector3(0.235, 0.19, 0.09), leather.darkened(0.12))
	_sphere(_display, Vector3(0.0, 0.13, -0.12), Vector3(0.26, 0.15, 0.14), leather.lightened(0.14))
	_box(_display, Vector3(0.0, 0.0, -0.236), Vector3(0.065, 0.19, 0.026), trim)
	_box(_display, Vector3(0.0, 0.012, -0.26), Vector3(0.105, 0.09, 0.025), gold)
	_box(_display, Vector3(0.0, 0.014, -0.277), Vector3(0.064, 0.048, 0.009), trim)
	_segment(_display, Vector3(-0.040, 0.015, -0.286), Vector3(0.040, 0.015, -0.286), 0.007, gold)
	for side in [-1.0, 1.0]:
		_segment(_display, Vector3(side * 0.11, 0.18, 0.0), Vector3(side * 0.13, 0.34, 0.0), 0.027, trim)
	_segment(_display, Vector3(-0.13, 0.34, 0.0), Vector3(0.13, 0.34, 0.0), 0.027, trim)
	# Short individual stitches follow the flap seam and keep their shared material.
	for index in 9:
		var horizontal := -0.19 + float(index) * 0.0475
		_segment(_display, Vector3(horizontal, 0.074, -0.243), Vector3(horizontal + 0.014, 0.081, -0.246), 0.004, thread)
	for side in [-1.0, 1.0]:
		for index in 4:
			var height := -0.15 + float(index) * 0.05
			_segment(_display, Vector3(side * 0.212, height, -0.196),
				Vector3(side * 0.216, height + 0.016, -0.196), 0.004, thread)
	# A wooden hunt tag hangs from the flap, with a tiny embossed paw.
	_segment(_display, Vector3(0.17, 0.16, -0.19), Vector3(0.20, -0.015, -0.263), 0.006, trim)
	var tag := _box(_display, Vector3(0.20, -0.035, -0.255), Vector3(0.095, 0.12, 0.022), Color("c99d65"))
	tag.rotation.z = -0.14
	_sphere(_display, Vector3(0.20, -0.046, -0.272), Vector3(0.019, 0.022, 0.006), trim)
	for index in 3:
		_sphere(_display, Vector3(0.178 + float(index) * 0.020, -0.012, -0.274), Vector3(0.008, 0.010, 0.005), trim)
	if rare:
		_gem(_display, Vector3(0.0, 0.015, -0.291), Vector3(0.026, 0.043, 0.022), Color("8dcfbd"))
	MeshBatch.combine(_display)
	for index in 3:
		var star := _gem(self, Vector3.ZERO, Vector3(0.055, 0.15 if rare else 0.11, 0.055), gold)
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
