extends RefCounted
## Original, collision-free expedition camp and deterministic mountain groves.
## Shared materials bake the static art; grass remains in separate instanced meshes.

const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const GameText := preload("res://scripts/core/game_text.gd")
const MeshBatch := preload("res://scripts/world/mesh_batch.gd")
const MeadowDetails := preload("res://scripts/world/meadow_details.gd")


static func build() -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "CampScenery"
	var materials := _palette()
	_trader(scenery, materials)
	_campfire(scenery, materials)
	_tent(scenery, materials)
	_crate(scenery, Vector3(10.6, 0.0, 49.2), materials)
	_crate(scenery, Vector3(11.1, 0.0, 50.6), materials)
	_crate(scenery, Vector3(10.65, 0.82, 49.2), materials, 0.7)
	_barrel(scenery, Vector3(6.0, 0.0, 48.5), materials)
	_barrel(scenery, Vector3(6.8, 0.0, 48.1), materials, 0.8)
	_sign(scenery, materials)
	var rng := RandomNumberGenerator.new()
	rng.seed = 729401
	var bands := [[45.5, 56.0, 20], [29.5, 38.0, 17], [16.0, 22.5, 11], [5.0, 9.0, 3]]
	for band_index in bands.size():
		var band: Array = bands[band_index]
		for index in int(band[2]):
			var at := _position(rng, float(band[0]), float(band[1]))
			var size := rng.randf_range(0.78, 1.4) * (0.8 if band_index == 3 else 1.0)
			if band_index < 2 and index % 4 == 0:
				_broadleaf(scenery, at, size, rng, materials)
			else:
				_pine(scenery, at, size, rng, materials)
	for index in 32:
		var at := _position(rng, 45.0 if index < 20 else 29.0, 57.0 if index < 20 else 38.0)
		_rock_cluster(scenery, at, rng, materials)
		if index % 2 == 0:
			_bush(scenery, at + Vector3(0.6, 0.0, 0.3), rng, materials)
	# Frame the first-person camp view with a few deliberate foreground silhouettes.
	_pine(scenery, Vector3(3.8, 0.0, 44.7), 1.35, rng, materials)
	_pine(scenery, Vector3(-8.0, 0.0, 48.5), 1.2, rng, materials)
	_broadleaf(scenery, Vector3(12.0, 0.0, 46.5), 1.15, rng, materials)
	MeshBatch.combine(scenery)
	scenery.add_child(MeadowDetails.build())
	return scenery


static func _palette() -> Dictionary:
	var colors := {
		"wood": Color("493a2b"), "wood_end": Color("b58c55"), "plank": Color("a97442"),
		"pine": Color("234e43"), "pine_mid": Color("356851"), "pine_tip": Color("58865c"),
		"leaf": Color("64924d"), "leaf_light": Color("8eac58"), "bush": Color("437551"),
		"amber": Color("e7b55c"), "cream": Color("eee0b5"), "canvas": Color("be7250"),
		"canvas_light": Color("dc9667"), "canvas_dark": Color("98573d"),
		"skin": Color("e6af81"), "dark": Color("27363a"), "iron": Color("4f6061"),
		"rock": Color("737b72"), "rock_light": Color("90958a"), "moss": Color("78875b"),
		"rope": Color("ceb88d"), "berry": Color("bd514e"), "flame": Color("ff983e"),
		"lantern": Color("ffe1a0"), "coal": Color("343737")
	}
	var materials := {}
	for key in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[key]
		material.roughness = 0.9
		if key == "flame" or key == "lantern":
			material.emission_enabled = true
			material.emission = colors[key]
			material.emission_energy_multiplier = 1.3
		if key == "iron":
			material.metallic = 0.45
			material.roughness = 0.58
		materials[key] = material
	return materials


static func _trader(parent: Node3D, mat: Dictionary) -> void:
	var stall := Node3D.new()
	stall.name = "TraderCamp"
	stall.position = Vector3(8.0, 0.0, 50.0)
	stall.rotation.y = atan2(8.0, -2.0)
	parent.add_child(stall)
	# Plank platform, counter and pegged timber frame.
	for index in 9:
		_box(stall, Vector3(-1.4 + index * 0.35, 0.045, 0.0), Vector3(0.33, 0.09, 2.4), mat["plank"])
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			_box(stall, Vector3(side * 1.4, 1.45, depth * 0.85), Vector3(0.13, 2.9, 0.13), mat["wood"])
		_box(stall, Vector3(side * 1.4, 2.82, 0.0), Vector3(0.16, 0.16, 2.9), mat["wood"])
		_beam(stall, Vector3(side * 1.4, 2.1, -0.85), Vector3(side * 0.95, 2.75, -0.85), 0.055, mat["wood"], 5)
		_beam(stall, Vector3(side * 1.4, 2.75, 0.9), Vector3(side * 2.0, 0.12, 1.8), 0.018, mat["rope"], 5)
		_box(stall, Vector3(side * 2.0, 0.11, 1.8), Vector3(0.07, 0.22, 0.07), mat["wood"])
	_box(stall, Vector3(0.0, 1.12, -0.76), Vector3(3.1, 0.16, 0.8), mat["plank"])
	_box(stall, Vector3(0.0, 0.6, -1.1), Vector3(2.9, 0.96, 0.10), mat["wood"])
	for index in 8:
		_box(stall, Vector3(-1.25 + index * 0.36, 0.61, -1.17), Vector3(0.33, 0.85, 0.07), mat["plank"])
	for height in [0.23, 0.98]:
		_box(stall, Vector3(0.0, height, -1.22), Vector3(2.95, 0.09, 0.06), mat["wood_end"])
	# Cloth sags from the ridge; rounded tabs give the valance a scalloped edge.
	var profile := [Vector2(-1.5, 2.62), Vector2(-0.75, 2.90), Vector2(0.10, 3.13), Vector2(0.8, 2.91), Vector2(1.35, 2.78)]
	for stripe in 8:
		var x := -1.4 + stripe * 0.4
		var material: Material = mat["amber" if stripe % 2 == 0 else "cream"]
		for segment in profile.size() - 1:
			var a: Vector2 = profile[segment]
			var b: Vector2 = profile[segment + 1]
			var cloth := _box(stall, Vector3(x, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5), Vector3(0.405, 0.025, a.distance_to(b)), material)
			cloth.rotation.x = -atan2(b.y - a.y, b.x - a.x)
		_box(stall, Vector3(x, 2.52, -1.5), Vector3(0.4, 0.20, 0.035), material)
		_sphere(stall, Vector3(x, 2.43, -1.5), Vector3(0.2, 0.13, 0.022), material)
	_beam(stall, Vector3(-1.6, 3.13, 0.1), Vector3(1.6, 3.13, 0.1), 0.045, mat["wood"], 6)
	for side in [-1.0, 1.0]:
		_beam(stall, Vector3(side * 0.7, 2.65, -1.48), Vector3(side * 0.7, 2.2, -1.48), 0.015, mat["rope"], 5)
	_box(stall, Vector3(0.0, 2.25, -1.5), Vector3(1.8, 0.30, 0.07), mat["wood"])
	_label(stall, GameText.get_text("world.trader"), Vector3(0.0, 3.56, -0.2), 0.012)
	_merchant(stall, mat)
	for index in 3:
		var x := -0.95 + index * 0.83
		_box(stall, Vector3(x, 1.25, -0.78), Vector3(0.62, 0.10, 0.38), mat["wood"])
		for item in 3:
			_sphere(stall, Vector3(x - 0.17 + item * 0.17, 1.37, -0.78), Vector3(0.09, 0.12, 0.10), mat["berry" if index == 0 else "amber"])
	# Rolled maps, a weighing pan and an arrow rack make the wares readable.
	for index in 3:
		var scroll := _cylinder(stall, Vector3(0.9 + index * 0.12, 1.3, -0.4), 0.04, 0.04, 0.4, mat["cream"], 6)
		scroll.rotation.z = PI * 0.5
	_box(stall, Vector3(1.27, 1.26, -0.7), Vector3(0.07, 0.12, 0.06), mat["iron"])
	_cylinder(stall, Vector3(1.27, 1.34, -0.7), 0.16, 0.1, 0.04, mat["iron"], 10)
	_box(stall, Vector3(-1.7, 0.8, 0.3), Vector3(0.13, 1.55, 0.13), mat["wood"])
	_box(stall, Vector3(-1.7, 1.42, 0.3), Vector3(0.65, 0.1, 0.1), mat["wood"])
	for index in 4:
		_beam(stall, Vector3(-1.9 + index * 0.12, 0.2, 0.32), Vector3(-1.8 + index * 0.12, 1.6, 0.32), 0.015, mat["wood_end"], 5)
	_lantern(stall, Vector3(1.43, 2.12, -1.02), mat)
	_crate(stall, Vector3(0.65, 0.1, 0.6), mat, 0.65)


static func _merchant(parent: Node3D, mat: Dictionary) -> void:
	_sphere(parent, Vector3(0.0, 1.14, 0.25), Vector3(0.39, 0.51, 0.26), mat["pine"])
	_box(parent, Vector3(0.0, 1.1, -0.01), Vector3(0.43, 0.60, 0.06), mat["canvas"])
	_sphere(parent, Vector3(0.0, 1.80, 0.18), Vector3(0.29, 0.32, 0.28), mat["skin"])
	_sphere(parent, Vector3(0.0, 1.63, -0.025), Vector3(0.25, 0.23, 0.12), mat["cream"])
	for side in [-1.0, 1.0]:
		_sphere(parent, Vector3(side * 0.105, 1.86, -0.078), Vector3(0.035, 0.045, 0.025), mat["dark"])
		var arm := _sphere(parent, Vector3(side * 0.42, 1.32, 0.18), Vector3(0.13, 0.36, 0.13), mat["pine"])
		arm.rotation.z = side * -0.30
		_sphere(parent, Vector3(side * 0.49, 1.05, 0.10), Vector3(0.13, 0.13, 0.13), mat["skin"])
	_sphere(parent, Vector3(0.0, 1.75, -0.13), Vector3(0.065, 0.075, 0.075), mat["skin"])
	_cylinder(parent, Vector3(0.0, 2.05, 0.18), 0.42, 0.42, 0.08, mat["amber"], 8)
	_cylinder(parent, Vector3(0.0, 2.2, 0.18), 0.20, 0.28, 0.26, mat["pine"], 8)
	_box(parent, Vector3(0.0, 2.15, 0.18), Vector3(0.54, 0.07, 0.48), mat["wood"])


static func _tent(parent: Node3D, mat: Dictionary) -> void:
	var tent := Node3D.new()
	tent.name = "HuntersTent"
	tent.position = Vector3(-7.0, 0.0, 51.0)
	tent.rotation.y = -PI / 3.0
	parent.add_child(tent)
	var canvas := PrismMesh.new()
	canvas.size = Vector3(3.3, 2.3, 3.4)
	_mesh(tent, canvas, Vector3(0.0, 1.15, 0.0), mat["canvas"])
	var entrance := PrismMesh.new()
	entrance.size = Vector3(1.95, 1.78, 0.035)
	_mesh(tent, entrance, Vector3(0.0, 0.89, -1.72), mat["dark"])
	# Roof seams and the pegged ridge support.
	for side in [-1.0, 1.0]:
		for index in 4:
			var z := -1.35 + index * 0.9
			_beam(tent, Vector3(0.0, 2.31, z), Vector3(side * 1.66, 0.015, z), 0.018, mat["canvas_light"], 4)
		_beam(tent, Vector3(side * 0.06, 2.28, -1.77), Vector3(side * 1.1, 0.0, -1.77), 0.04, mat["canvas_light"], 4)
		for z in [-1.6, 1.6]:
			_beam(tent, Vector3(side * 1.55, 0.2, z), Vector3(side * 2.35, 0.1, z + 0.4), 0.017, mat["rope"], 5)
			_box(tent, Vector3(side * 2.35, 0.1, z + 0.4), Vector3(0.06, 0.20, 0.06), mat["wood"])
	_box(tent, Vector3(0.0, 1.19, -1.78), Vector3(0.09, 2.38, 0.09), mat["wood"])
	_box(tent, Vector3(0.0, 2.32, 0.0), Vector3(0.11, 0.11, 3.9), mat["wood"])
	_box(tent, Vector3(-0.4, 0.07, -1.77), Vector3(0.8, 0.14, 1.5), mat["pine"])
	var blanket := _cylinder(tent, Vector3(-0.4, 0.22, -1.14), 0.17, 0.17, 0.82, mat["cream"], 10)
	blanket.rotation.z = PI * 0.5
	for side in [-1.0, 1.0]:
		_box(tent, Vector3(0.5 + side * 0.13, 0.13, -2.05), Vector3(0.18, 0.26, 0.35), mat["wood"])
	_sphere(tent, Vector3(1.85, 0.42, -0.65), Vector3(0.32, 0.43, 0.27), mat["pine"])
	_box(tent, Vector3(1.85, 0.49, -0.91), Vector3(0.44, 0.27, 0.10), mat["canvas_light"])
	for side in [-1.0, 1.0]:
		_box(tent, Vector3(1.85 + side * 0.19, 0.44, -0.94), Vector3(0.055, 0.65, 0.03), mat["wood"])
	_beam(tent, Vector3(-1.9, 0.0, -1.8), Vector3(-1.9, 1.45, -1.8), 0.035, mat["wood"], 6)
	_lantern(tent, Vector3(-1.9, 1.22, -1.8), mat)
	_crate(tent, Vector3(1.95, 0.0, 0.55), mat, 0.65)
	_barrel(tent, Vector3(-2.0, 0.0, 0.8), mat, 0.7)


static func _campfire(parent: Node3D, mat: Dictionary) -> void:
	var center := Vector3(3.9, 0.0, 54.3)
	_cylinder(parent, center + Vector3.UP * 0.012, 0.61, 0.61, 0.025, mat["coal"], 12)
	for index in 10:
		var angle := index * TAU / 10.0
		var rock := _sphere(parent, center + Vector3(cos(angle) * 0.64, 0.11, sin(angle) * 0.64), Vector3(0.20, 0.14, 0.17), mat["rock_light" if index % 3 == 0 else "rock"])
		rock.rotation.y = angle
	for index in 3:
		var angle := index * PI / 3.0
		var start := center + Vector3(cos(angle) * -0.48, 0.15, sin(angle) * -0.48)
		var end := center + Vector3(cos(angle) * 0.48, 0.21, sin(angle) * 0.48)
		_beam(parent, start, end, 0.09, mat["wood"], 7)
		_beam(parent, end, end + (end - start).normalized() * 0.012, 0.075, mat["wood_end"], 7)
		var flame := _cylinder(parent, center + Vector3(index * 0.14 - 0.14, 0.4, 0.0), 0.0, 0.17, 0.6 - index * 0.1, mat["flame"], 5)
		flame.rotation.z = (index - 1) * 0.24
	# Kettle tripod and split-log seats define a cozy cooking area.
	for offset in [Vector3(-0.57, 0.0, -0.3), Vector3(0.57, 0.0, -0.3), Vector3(0.0, 0.0, 0.6)]:
		_beam(parent, center + offset, center + Vector3(0.0, 1.38, 0.0), 0.028, mat["iron"], 5)
	_beam(parent, center + Vector3(0.0, 1.38, 0.0), center + Vector3(0.0, 0.89, 0.0), 0.016, mat["iron"], 5)
	_sphere(parent, center + Vector3(0.0, 0.79, 0.0), Vector3(0.24, 0.20, 0.24), mat["iron"])
	_cylinder(parent, center + Vector3(0.0, 0.94, 0.0), 0.23, 0.23, 0.035, mat["dark"], 8)
	for side in [-1.0, 1.0]:
		_beam(parent, center + Vector3(side * 1.7, 0.24, -0.7), center + Vector3(side * 1.7, 0.24, 0.65), 0.23, mat["wood"], 8)
		_box(parent, center + Vector3(side * 1.7, 0.43, -0.02), Vector3(0.43, 0.08, 1.35), mat["wood_end"])
	var glow := OmniLight3D.new()
	glow.position = center + Vector3.UP * 0.8
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 0.8
	glow.omni_range = 4.0
	parent.add_child(glow)


static func _sign(parent: Node3D, mat: Dictionary) -> void:
	var at := Vector3(-3.6, 0.0, 55.3)
	_box(parent, at + Vector3(0.0, 0.85, 0.0), Vector3(0.15, 1.7, 0.15), mat["wood"])
	for height in [1.43, 1.74]:
		_box(parent, at + Vector3(0.0, height, -0.05), Vector3(2.4, 0.28, 0.11), mat["plank"])
	_label(parent, GameText.get_text("world.camp"), at + Vector3(0.0, 1.58, -0.13), 0.010)
	for side in [-1.0, 1.0]:
		_cylinder(parent, at + Vector3(side * 0.96, 1.59, -0.12), 0.04, 0.04, 0.03, mat["iron"], 6).rotation.x = PI * 0.5


static func _crate(parent: Node3D, at: Vector3, mat: Dictionary, size: float = 1.0) -> void:
	_box(parent, at + Vector3.UP * 0.39 * size, Vector3(0.78, 0.78, 0.78) * size, mat["wood"])
	for index in 4:
		for face in [-1.0, 1.0]:
			_box(parent, at + Vector3((index * 0.19 - 0.285) * size, 0.40 * size, face * 0.4 * size), Vector3(0.17, 0.69, 0.045) * size, mat["plank"])
	for height in [0.13, 0.66]:
		_box(parent, at + Vector3.UP * height * size, Vector3(0.85, 0.08, 0.85) * size, mat["wood_end"])
	for face in [-1.0, 1.0]:
		_beam(parent, at + Vector3(-0.34, 0.13, face * 0.43) * size, at + Vector3(0.34, 0.66, face * 0.43) * size, 0.04 * size, mat["wood_end"], 4)
	for index in 4:
		_box(parent, at + Vector3((index * 0.19 - 0.285) * size, 0.79 * size, 0.0), Vector3(0.17, 0.04, 0.78) * size, mat["plank"])


static func _barrel(parent: Node3D, at: Vector3, mat: Dictionary, size: float = 1.0) -> void:
	_cylinder(parent, at + Vector3.UP * 0.2 * size, 0.36 * size, 0.30 * size, 0.4 * size, mat["plank"], 12)
	_cylinder(parent, at + Vector3.UP * 0.6 * size, 0.30 * size, 0.36 * size, 0.4 * size, mat["plank"], 12)
	for height in [0.1, 0.4, 0.7]:
		var radius := (0.325 if height != 0.4 else 0.365) * size
		_cylinder(parent, at + Vector3.UP * height * size, radius, radius, 0.055 * size, mat["iron"], 12)
	_cylinder(parent, at + Vector3.UP * 0.805 * size, 0.3 * size, 0.3 * size, 0.025 * size, mat["wood_end"], 12)
	_box(parent, at + Vector3(0.0, 0.824, 0.0) * size, Vector3(0.43, 0.025, 0.05) * size, mat["wood"])


static func _lantern(parent: Node3D, at: Vector3, mat: Dictionary) -> void:
	_cylinder(parent, at, 0.095, 0.095, 0.26, mat["lantern"], 6)
	for height in [-0.16, 0.16]:
		_cylinder(parent, at + Vector3.UP * height, 0.13, 0.13, 0.055, mat["iron"], 6)
	for side in [-1.0, 1.0]:
		_box(parent, at + Vector3(side * 0.11, 0.0, 0.0), Vector3(0.022, 0.3, 0.022), mat["iron"])
	_beam(parent, at + Vector3(-0.08, 0.18, 0.0), at + Vector3(0.0, 0.29, 0.0), 0.012, mat["iron"], 5)
	_beam(parent, at + Vector3(0.08, 0.18, 0.0), at + Vector3(0.0, 0.29, 0.0), 0.012, mat["iron"], 5)


static func _pine(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator, mat: Dictionary) -> void:
	var tree := Node3D.new()
	tree.position = at
	tree.rotation = Vector3(rng.randf_range(-0.045, 0.045), rng.randf_range(0.0, TAU), rng.randf_range(-0.045, 0.045))
	tree.scale = Vector3.ONE * size
	parent.add_child(tree)
	_cylinder(tree, Vector3(0.0, 2.8, 0.0), 0.065, 0.24, 5.6, mat["wood"], 7)
	for root_index in 4:
		var angle := root_index * TAU / 4.0
		_beam(tree, Vector3(0.0, 0.3, 0.0), Vector3(cos(angle) * 0.47, 0.025, sin(angle) * 0.47), 0.09, mat["wood"], 5)
	var offset := rng.randf_range(0.0, TAU)
	for layer in 5:
		var height := 1.5 + layer * 0.88
		var spread := 1.65 - layer * 0.27
		var canopy := _cylinder(tree, Vector3(0.0, height + 0.75, 0.0), 0.0, spread, 1.95, mat["pine_mid" if layer % 2 == 0 else "pine"], 7)
		canopy.rotation = Vector3(rng.randf_range(-0.09, 0.09), offset + layer * 0.48, rng.randf_range(-0.08, 0.08))
		if layer < 4:
			for branch in 3:
				var angle := offset + branch * TAU / 3.0 + layer * 1.45
				var end := Vector3(cos(angle) * spread * 0.7, height + 0.02, sin(angle) * spread * 0.7)
				_beam(tree, Vector3(0.0, height + 0.35, 0.0), end, 0.045, mat["wood"], 5)
				var bough := _cylinder(tree, end + Vector3.UP * 0.28, 0.0, spread * 0.46, 0.86, mat["pine_tip" if branch == 0 else "pine_mid"], 5)
				bough.rotation = Vector3(cos(angle) * 0.20, angle, -sin(angle) * 0.22)


static func _broadleaf(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator, mat: Dictionary) -> void:
	var tree := Node3D.new()
	tree.position = at
	tree.rotation.y = rng.randf_range(0.0, TAU)
	tree.scale = Vector3.ONE * size
	parent.add_child(tree)
	_beam(tree, Vector3.ZERO, Vector3(0.12, 2.9, 0.0), 0.18, mat["wood"], 7)
	for index in 5:
		var angle := index * TAU / 5.0
		var end := Vector3(cos(angle) * 1.15, 3.05 + rng.randf_range(0.0, 1.0), sin(angle) * 1.15)
		_beam(tree, Vector3(0.08, 1.7 + index * 0.17, 0.0), end, 0.085, mat["wood"], 6)
		var crown := _sphere(tree, end, Vector3(1.18, 1.0, 1.13), mat["leaf" if index % 2 == 0 else "leaf_light"])
		crown.rotation.y = angle + 0.3
	_sphere(tree, Vector3(0.0, 4.15, 0.0), Vector3(1.25, 1.1, 1.23), mat["leaf_light"])


static func _rock_cluster(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, mat: Dictionary) -> void:
	var size := rng.randf_range(0.4, 1.0)
	for index in 3:
		var offset := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var height := rng.randf_range(0.22, 0.65) * size
		var rock := _sphere(parent, at + offset + Vector3.UP * height * 0.72, Vector3(rng.randf_range(0.4, 0.8) * size, height, rng.randf_range(0.38, 0.65) * size), mat["rock_light" if index == 0 else "rock"])
		rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.15, 0.15))
		if index == 1:
			_sphere(parent, at + offset + Vector3.UP * height * 1.4, Vector3(0.28 * size, 0.08 * size, 0.27 * size), mat["moss"])


static func _bush(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, mat: Dictionary) -> void:
	for index in 4:
		var offset := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.2, 0.42), rng.randf_range(-0.3, 0.3))
		_sphere(parent, at + offset, Vector3(0.35, 0.32, 0.32), mat["bush" if index % 2 == 0 else "leaf"])
		if index % 2 == 0:
			_sphere(parent, at + offset + Vector3(0.0, 0.25, -0.16), Vector3.ONE * 0.055, mat["berry"])


static func _position(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	for attempt in 40:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(inner, outer)
		var at := Vector3(cos(angle) * radius, IslandBuilder.ground_height_at(radius), sin(angle) * radius)
		if absf(at.x) < 6.0 or at.distance_to(Vector3(8.0, 0.0, 50.0)) < 7.0:
			continue
		if at.distance_to(Vector3(-7.0, 0.0, 51.0)) < 5.0 or at.distance_to(Vector3(3.9, 0.0, 54.3)) < 4.0:
			continue
		return at
	return Vector3(outer, IslandBuilder.ground_height_at(outer), 0.0)


static func _label(parent: Node3D, text: String, at: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = size
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color(1.0, 0.94, 0.75)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)


static func _beam(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material, sides: int) -> MeshInstance3D:
	var direction := end - start
	var visual := _cylinder(parent, (start + end) * 0.5, radius * 0.82, radius, direction.length(), material, sides)
	visual.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return visual


static func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, material)


static func _sphere(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
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
