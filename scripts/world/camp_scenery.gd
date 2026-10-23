extends RefCounted
## Original, collision-free camp props and deterministic terrace dressing.

const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const GameText := preload("res://scripts/core/game_text.gd")
const MeshBatch := preload("res://scripts/world/mesh_batch.gd")


static func build() -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "CampScenery"
	var materials := _palette()
	_trader(scenery, materials)
	_campfire(scenery, materials)
	_tent(scenery, materials)
	for at in [Vector3(10.6, 0.0, 49.2), Vector3(11.1, 0.0, 50.6), Vector3(6.3, 0.0, 48.8)]:
		_crate(scenery, at, materials)
	_label(scenery, GameText.get_text("world.camp"), Vector3(-3.0, 1.6, 55.3), 0.012)
	_box(scenery, Vector3(-3.0, 1.6, 55.3), Vector3(2.4, 0.65, 0.12), materials["wood"])
	_box(scenery, Vector3(-3.0, 0.75, 55.35), Vector3(0.14, 1.5, 0.14), materials["wood"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 729401
	var bands := [[45.5, 56.0, 9], [29.0, 39.0, 8], [15.5, 23.0, 6], [4.0, 10.0, 3]]
	for band in bands:
		for index in int(band[2]):
			var at := _position(rng, float(band[0]), float(band[1]))
			_pine(scenery, at, rng.randf_range(0.8, 1.45), materials, index % 2 == 0)
	for index in 18:
		var at := _position(rng, 44.5, 57.5)
		var rock := _sphere(scenery, at + Vector3.UP * 0.21, Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.2, 0.45), 0.4), materials["rock"])
		rock.rotation.y = rng.randf_range(0.0, TAU)
	for index in 18:
		var at := _position(rng, 44.5, 57.0)
		for petal in 3:
			var offset := Vector3(float(petal - 1) * 0.15, 0.14 + float(petal % 2) * 0.08, 0.0)
			_sphere(scenery, at + offset, Vector3(0.12, 0.11, 0.12), materials["flower" if index % 2 == 0 else "amber"])
	MeshBatch.combine(scenery)
	return scenery


static func _palette() -> Dictionary:
	var colors := {
		"wood": Color(0.25, 0.13, 0.09), "plank": Color(0.56, 0.31, 0.15),
		"pine": Color(0.08, 0.29, 0.23), "leaf": Color(0.16, 0.43, 0.28),
		"amber": Color(1.0, 0.66, 0.18), "cream": Color(0.98, 0.87, 0.62),
		"clay": Color(0.73, 0.32, 0.22), "skin": Color(0.93, 0.66, 0.44),
		"dark": Color(0.10, 0.14, 0.15), "rock": Color(0.44, 0.48, 0.46),
		"flower": Color(0.85, 0.41, 0.60), "flame": Color(1.0, 0.36, 0.08)
	}
	var materials := {}
	for key in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[key]
		material.roughness = 1.0
		if key == "flame" or key == "amber":
			material.emission_enabled = true
			material.emission = colors[key] * (0.7 if key == "flame" else 0.10)
		materials[key] = material
	return materials


static func _trader(parent: Node3D, mat: Dictionary) -> void:
	var stall := Node3D.new()
	stall.name = "TraderCamp"
	stall.position = Vector3(8.0, 0.0, 50.0)
	stall.rotation.y = atan2(8.0, -2.0)
	parent.add_child(stall)
	_cylinder(stall, Vector3(0.0, 0.025, -0.2), 2.25, 2.25, 0.05, mat["clay"], 12)
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			_box(stall, Vector3(side * 1.35, 1.25, depth * 0.70), Vector3(0.13, 2.5, 0.13), mat["wood"])
	_box(stall, Vector3(0.0, 1.12, -0.75), Vector3(3.0, 0.18, 0.78), mat["plank"])
	_box(stall, Vector3(0.0, 0.60, -0.97), Vector3(2.9, 0.96, 0.10), mat["wood"])
	for index in 6:
		_box(stall, Vector3(-1.25 + float(index) * 0.5, 0.61, -1.03), Vector3(0.40, 0.85, 0.09), mat["plank"])
		var stripe := _box(stall, Vector3(-1.25 + float(index) * 0.5, 2.60, -0.12), Vector3(0.50, 0.12, 2.25), mat["amber" if index % 2 == 0 else "cream"])
		stripe.rotation.x = -0.12
		_box(stall, Vector3(-1.25 + float(index) * 0.5, 2.34, -1.22), Vector3(0.50, 0.30, 0.10), mat["amber" if index % 2 == 0 else "cream"])
	_label(stall, GameText.get_text("world.trader"), Vector3(0.0, 3.13, -0.20), 0.014)
	_sphere(stall, Vector3(0.0, 1.14, 0.25), Vector3(0.39, 0.51, 0.26), mat["pine"])
	_box(stall, Vector3(0.0, 1.10, -0.01), Vector3(0.43, 0.60, 0.06), mat["clay"])
	_sphere(stall, Vector3(0.0, 1.80, 0.18), Vector3(0.29, 0.32, 0.28), mat["skin"])
	_sphere(stall, Vector3(0.0, 1.63, -0.025), Vector3(0.25, 0.23, 0.12), mat["cream"])
	for side in [-1.0, 1.0]:
		_sphere(stall, Vector3(side * 0.105, 1.86, -0.078), Vector3(0.035, 0.045, 0.025), mat["dark"])
		var arm := _sphere(stall, Vector3(side * 0.42, 1.32, 0.18), Vector3(0.13, 0.36, 0.13), mat["pine"])
		arm.rotation.z = side * -0.30
		_sphere(stall, Vector3(side * 0.49, 1.05, 0.10), Vector3(0.13, 0.13, 0.13), mat["skin"])
	_sphere(stall, Vector3(0.0, 1.75, -0.13), Vector3(0.065, 0.075, 0.075), mat["skin"])
	_cylinder(stall, Vector3(0.0, 2.05, 0.18), 0.42, 0.42, 0.08, mat["amber"], 8)
	_cylinder(stall, Vector3(0.0, 2.20, 0.18), 0.20, 0.28, 0.26, mat["pine"], 8)
	for index in 3:
		_sphere(stall, Vector3(-0.85 + float(index) * 0.85, 1.38, -0.76), Vector3(0.20, 0.19, 0.18), mat["clay" if index % 2 == 0 else "cream"])


static func _tent(parent: Node3D, mat: Dictionary) -> void:
	var tent := Node3D.new()
	tent.name = "HuntersTent"
	tent.position = Vector3(-7.0, 0.0, 51.0)
	tent.rotation.y = -PI / 3.0
	parent.add_child(tent)
	var canvas := PrismMesh.new()
	canvas.size = Vector3(3.0, 2.1, 3.0)
	_mesh(tent, canvas, Vector3(0.0, 1.05, 0.0), mat["clay"])
	var entrance := PrismMesh.new()
	entrance.size = Vector3(1.55, 1.6, 0.05)
	_mesh(tent, entrance, Vector3(0.0, 0.81, -1.53), mat["dark"])
	_box(tent, Vector3(0.0, 1.13, -1.58), Vector3(0.08, 2.26, 0.08), mat["wood"])
	_box(tent, Vector3(0.0, 2.11, 0.0), Vector3(0.10, 0.10, 3.3), mat["wood"])
	_cylinder(tent, Vector3(1.8, 0.22, -0.8), 0.25, 0.25, 0.44, mat["cream"], 8)


static func _campfire(parent: Node3D, mat: Dictionary) -> void:
	var center := Vector3(3.9, 0.0, 54.3)
	for index in 8:
		var angle := float(index) * TAU / 8.0
		_sphere(parent, center + Vector3(cos(angle) * 0.65, 0.12, sin(angle) * 0.65), Vector3(0.22, 0.14, 0.19), mat["rock"])
	for index in 3:
		var log_mesh := _box(parent, center + Vector3(0.0, 0.16, 0.0), Vector3(1.1, 0.17, 0.18), mat["wood"])
		log_mesh.rotation.y = float(index) * PI / 3.0
		_cylinder(parent, center + Vector3(float(index - 1) * 0.14, 0.46, 0.0), 0.0, 0.22, 0.65 - float(index) * 0.1, mat["flame" if index % 2 == 0 else "amber"], 5)
	var glow := OmniLight3D.new()
	glow.position = center + Vector3.UP * 0.8
	glow.light_color = Color(1.0, 0.49, 0.15)
	glow.light_energy = 1.1
	glow.omni_range = 4.0
	parent.add_child(glow)


static func _crate(parent: Node3D, at: Vector3, mat: Dictionary) -> void:
	_box(parent, at + Vector3.UP * 0.4, Vector3(0.8, 0.8, 0.8), mat["plank"])
	for height in [0.17, 0.63]:
		_box(parent, at + Vector3.UP * height, Vector3(0.84, 0.11, 0.84), mat["wood"])


static func _pine(parent: Node3D, at: Vector3, size: float, mat: Dictionary, dark: bool) -> void:
	_cylinder(parent, at + Vector3.UP * 1.1 * size, 0.12 * size, 0.20 * size, 2.2 * size, mat["wood"], 6)
	for index in 3:
		var height := (1.65 + float(index) * 0.85) * size
		_cylinder(parent, at + Vector3.UP * height, 0.0, (1.2 - float(index) * 0.27) * size, 1.9 * size, mat["pine" if dark else "leaf"], 7)


static func _position(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	for attempt in 24:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(inner, outer)
		var at := Vector3(cos(angle) * radius, IslandBuilder.ground_height_at(radius), sin(angle) * radius)
		if absf(at.x) > 5.0 and at.distance_to(Vector3(8.0, 0.0, 50.0)) > 5.0:
			return at
	return Vector3(outer, IslandBuilder.ground_height_at(outer), 0.0)


static func _label(parent: Node3D, text: String, at: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = size
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color(1.0, 0.90, 0.64)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


static func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, material)


static func _sphere(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var visual := _mesh(parent, mesh, at, material)
	visual.scale = size
	return visual


static func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, material: Material, sides: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(parent, mesh, at, material)


static func _mesh(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, material: Material) -> MeshInstance3D:
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)
	return visual
