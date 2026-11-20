extends RefCounted
## One continuous walkable mountain. The rendered mesh is also its collision surface.
const CLIMBABLE_GROUP := &"climbable"
const SUMMIT_RADIUS := 12.0
const SUMMIT_HEIGHT := 24.0
const FOOT_RADIUS := 44.0
const GROUND_RADIUS := 110.0
const MeadowShader := preload("res://shaders/meadow.gdshader")


static func ground_height_at(distance: float) -> float:
	return clampf((FOOT_RADIUS - distance) * SUMMIT_HEIGHT / (FOOT_RADIUS - SUMMIT_RADIUS), 0.0, SUMMIT_HEIGHT)


static func build() -> Node3D:
	var island := Node3D.new()
	island.name = "Island"
	var body := StaticBody3D.new()
	body.name = "WalkableMountain"
	island.add_child(body)
	var material := ShaderMaterial.new()
	material.shader = MeadowShader
	material.set_shader_parameter("meadow_color", Color("6c9148"))
	material.set_shader_parameter("tier_radius", GROUND_RADIUS)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for ring in 55:
		var inner := float(ring) * 2.0
		var outer := inner + 2.0
		for sector in 128:
			var a := _point(inner, sector)
			var b := _point(inner, sector + 1)
			var c := _point(outer, sector)
			var d := _point(outer, sector + 1)
			if ring > 0:
				_triangle(surface, a, c, b)
			_triangle(surface, b, c, d)
	var mesh := surface.commit()
	var visual := MeshInstance3D.new()
	visual.name = "MountainSurface"
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	var valley := MeshInstance3D.new()
	valley.name = "DryValley"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400, 2400)
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color("b8a177")
	sand.roughness = 1.0
	plane.material = sand
	valley.mesh = plane
	valley.position.y = -0.15
	island.add_child(valley)
	return island


static func _point(radius: float, sector: int) -> Vector3:
	var angle := float(sector % 128) * TAU / 128.0
	return Vector3(cos(angle) * radius, ground_height_at(radius), sin(angle) * radius)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)
