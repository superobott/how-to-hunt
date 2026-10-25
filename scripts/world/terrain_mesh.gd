extends RefCounted
## Deterministic, flat-shaded rock facets surrounding a perfectly level meadow.
## Fine radial segments and <= 0.16 m offsets keep the rendered climbable edge
## close to its analytic cylinder collider, including between segment endpoints.

const SEGMENTS := 96


static func build(radius: float, height: float, tier: int, meadow: Material, cliff: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var top := height * 0.5
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	cap.set_material(meadow)
	for segment in SEGMENTS:
		var a := _point(radius, top, segment, 0, tier, true)
		var b := _point(radius, top, segment + 1, 0, tier, true)
		_triangle(cap, Vector3(0.0, top, 0.0), a, b, Color.WHITE)
	cap.commit(mesh)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	wall.set_material(cliff)
	var rings := ceili(height / 1.55)
	for ring in rings:
		var lower_y := -top + height * float(ring) / float(rings)
		var upper_y := -top + height * float(ring + 1) / float(rings)
		for segment in SEGMENTS:
			var a := _point(radius, lower_y, segment, ring, tier, false)
			var b := _point(radius, lower_y, segment + 1, ring, tier, false)
			var c := _point(radius, upper_y, segment, ring + 1, tier, ring + 1 == rings)
			var d := _point(radius, upper_y, segment + 1, ring + 1, tier, ring + 1 == rings)
			var shade := 0.91 + _variation(segment, ring, tier) * 0.16
			var tint := Color(shade, shade, shade, 1.0)
			# Alternating diagonals avoid a repeated ribbon of identical triangles.
			if (segment + ring) % 2 == 0:
				_triangle(wall, a, d, c, tint)
				_triangle(wall, a, b, d, tint)
			else:
				_triangle(wall, a, b, c, tint)
				_triangle(wall, b, d, c, tint)
	wall.commit(mesh)
	return mesh


static func _point(radius: float, y: float, segment: int, ring: int, tier: int, rim: bool) -> Vector3:
	var wrapped := segment % SEGMENTS
	var angle := TAU * float(wrapped) / float(SEGMENTS)
	# A common rim profile makes the cap and cliff meet without gaps.
	var offset := sin(angle * 13.0 + float(tier) * 0.7) * 0.055
	if not rim:
		offset += (_variation(wrapped, ring, tier) - 0.5) * 0.20
	return Vector3(cos(angle) * (radius + offset), y, sin(angle) * (radius + offset))


static func _variation(segment: int, ring: int, tier: int) -> float:
	# Pure deterministic hash: visual construction never consumes gameplay RNG.
	return fposmod(sin(float(segment * 127 + ring * 311 + tier * 73)) * 43758.5453, 1.0)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	# Godot uses clockwise front faces; each triangle has one deliberate flat normal.
	var normal := (c - a).cross(b - a).normalized()
	surface.set_normal(normal)
	surface.set_color(tint)
	surface.add_vertex(a)
	surface.set_normal(normal)
	surface.set_color(tint)
	surface.add_vertex(b)
	surface.set_normal(normal)
	surface.set_color(tint)
	surface.add_vertex(c)
