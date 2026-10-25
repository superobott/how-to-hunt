extends RefCounted
## Seeded, ground-rooted low vegetation. Six MultiMeshes, no per-frame scene work.

const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const FoliageShader := preload("res://shaders/foliage.gdshader")


static func build() -> Node3D:
	var meadow := Node3D.new()
	meadow.name = "MeadowDetails"
	var rng := RandomNumberGenerator.new()
	rng.seed = 569082
	_add_group(meadow, "MeadowGrass", _grass_mesh(), Color("92af65"), 2200, rng, 0.045)
	_add_group(meadow, "ShadedGrass", _grass_mesh(), Color("6c9455"), 1800, rng, 0.04)
	_add_group(meadow, "DrySeedGrass", _seed_mesh(), Color("c3bb78"), 500, rng, 0.05)
	_add_group(meadow, "GoldenFlowers", _flower_mesh(Color("e8c86e")), Color.WHITE, 250, rng, 0.025)
	_add_group(meadow, "BlueWildflowers", _flower_mesh(Color("9cadd2")), Color.WHITE, 220, rng, 0.025)
	_add_group(meadow, "FernFronds", _fern_mesh(), Color("719862"), 220, rng, 0.03)
	return meadow


static func _add_group(parent: Node3D, title: String, mesh: ArrayMesh, color: Color, count: int, rng: RandomNumberGenerator, sway: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = FoliageShader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("sway_strength", sway)
	mesh.surface_set_material(0, material)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = count
	instances.custom_aabb = AABB(Vector3(-61.0, -0.1, -61.0), Vector3(122.0, 28.0, 122.0))
	for index in count:
		var at := _position(rng)
		var size := rng.randf_range(0.65, 1.3)
		var spread := 1.8 if title in ["MeadowGrass", "ShadedGrass"] else 1.0
		var transform := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(size * spread, size, size * spread)), at)
		instances.set_instance_transform(index, transform)
		instances.set_instance_color(index, Color.WHITE)
		instances.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), 0.0, 1.0))
	var visual := MultiMeshInstance3D.new()
	visual.name = title
	visual.multimesh = instances
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


static func _position(rng: RandomNumberGenerator) -> Vector3:
	for attempt in 100:
		var band := rng.randf()
		var inner := 44.3 if band < 0.65 else (28.2 if band < 0.9 else 14.2)
		var outer := 58.2 if band < 0.65 else (40.0 if band < 0.9 else 24.0)
		var radius := sqrt(lerpf(inner * inner, outer * outer, rng.randf()))
		var angle := rng.randf_range(0.0, TAU)
		var at := Vector3(cos(angle) * radius, IslandBuilder.ground_height_at(radius), sin(angle) * radius)
		# Clear shooting/climbing corridor plus the trail connecting spawn to the merchant.
		if at.z > 0.0 and absf(at.x) < 2.8:
			continue
		if at.distance_to(Vector3(8.0, 0.0, 50.0)) < 4.6 or at.distance_to(Vector3(-7.0, 0.0, 51.0)) < 3.7:
			continue
		if at.distance_to(Vector3(3.9, 0.0, 54.3)) < 2.8 or at.distance_to(Vector3(-3.6, 0.0, 55.3)) < 1.5:
			continue
		# Reject alternating patches to make the vegetation read as natural clumps.
		var patch := sin(at.x * 0.43 + sin(at.z * 0.3)) + cos(at.z * 0.5 - at.x * 0.14)
		if patch < -0.8:
			continue
		return at
	return Vector3(-30.0, IslandBuilder.ground_height_at(30.0), -12.0)


static func _grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six tapered, bent blades arranged across three planes; there is no alpha overdraw.
	for index in 6:
		var angle := index * 2.4
		var across := Vector3(cos(angle), 0.0, sin(angle))
		var root := Vector3(sin(angle) * 0.075, 0.0, cos(angle) * 0.075)
		var height := 0.19 + (index % 3) * 0.075
		var shoulder := root + Vector3.UP * height * 0.53 + across * 0.035
		var tip := root + Vector3.UP * height + across * (0.10 if index % 2 == 0 else -0.09)
		_triangle(surface, root - across * 0.026, root + across * 0.026, shoulder + across * 0.019, Color(0.65, 0.74, 0.55))
		_triangle(surface, root - across * 0.026, shoulder + across * 0.019, tip, Color(1.04, 1.06, 0.95))
	return surface.commit()


static func _seed_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 3:
		var angle := index * TAU / 3.0
		var across := Vector3(cos(angle), 0.0, sin(angle))
		var root := across * 0.06
		var tip := root + Vector3(0.04, 0.32 + index * 0.04, 0.02)
		_quad(surface, root - across * 0.007, root + across * 0.007, tip + across * 0.007, tip - across * 0.007, Color(0.7, 0.8, 0.6))
		for seed in 3:
			var center := tip - Vector3.UP * seed * 0.04
			_triangle(surface, center - across * 0.035, center + across * 0.035, center + Vector3.UP * 0.055, Color(1.0, 0.95, 0.75))
	return surface.commit()


static func _flower_mesh(petal_color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flower in 3:
		var root := Vector3((flower - 1) * 0.11, 0.0, (flower % 2) * 0.09)
		var center := root + Vector3(0.015, 0.25 + flower * 0.055, 0.0)
		_quad(surface, root - Vector3.RIGHT * 0.008, root + Vector3.RIGHT * 0.008, center + Vector3.RIGHT * 0.008, center - Vector3.RIGHT * 0.008, Color("698854"))
		_triangle(surface, root + Vector3.UP * 0.09, root + Vector3(-0.07, 0.17, 0.0), root + Vector3.UP * 0.14, Color("7a9b5d"))
		for petal in 5:
			var angle := petal * TAU / 5.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var side := Vector3(-direction.z, 0.0, direction.x) * 0.028
			var end := center + direction * 0.075 + Vector3.UP * 0.02
			_triangle(surface, center, end + side, end - side, petal_color)
		_triangle(surface, center + Vector3(-0.023, 0.008, -0.016), center + Vector3(0.023, 0.008, -0.016), center + Vector3(0.0, 0.008, 0.027), Color("f4dfa2"))
	return surface.commit()


static func _fern_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in 5:
		var angle := frond * TAU / 5.0
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var across := Vector3(-outward.z, 0.0, outward.x)
		for leaf in 4:
			var distance := 0.065 + leaf * 0.065
			var center := outward * distance + Vector3.UP * (0.15 + sin(distance * 6.0) * 0.1)
			var width := 0.085 - leaf * 0.014
			_triangle(surface, center - outward * 0.05, center + across * width, center + outward * 0.035, Color(0.83, 0.95, 0.8))
			_triangle(surface, center - outward * 0.05, center - across * width, center + outward * 0.035, Color(0.69, 0.83, 0.65))
			if leaf == 0:
				_quad(surface, Vector3.ZERO, across * 0.008, center + across * 0.008, center, Color(0.7, 0.86, 0.67))
	return surface.commit()


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(surface, a, b, c, color)
	_triangle(surface, a, c, d, color)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	# Godot's front faces wind clockwise; the shader flips the opposite face.
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.add_vertex(point)
