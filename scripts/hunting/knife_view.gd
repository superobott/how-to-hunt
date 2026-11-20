extends Node3D
## Camera-space knife with a short slash and a raised guarding pose.
var reload_ratio: float = 0.0
var guarding: bool = false
var moving: float = 0.0
var _age := 0.0

func _ready() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("dce7e5")
	steel.metallic = 0.65
	steel.roughness = 0.35
	var blade := SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	blade.set_material(steel)
	var tip := Vector3(0, 0.43, 0)
	var left := Vector3(-0.043, 0.10, 0)
	var right := Vector3(0.043, 0.10, 0)
	for side in [-1.0, 1.0]:
		var ridge := Vector3(0, 0.12, side * 0.017)
		for triangle in [[left, tip, ridge], [ridge, tip, right], [left, ridge, right]]:
			var vertices: Array = triangle.duplicate()
			if side > 0:
				vertices.reverse()
			for point: Vector3 in vertices:
				blade.add_vertex(point)
	blade.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = blade.commit()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_box(Vector3(0, 0.09, 0), Vector3(0.15, 0.025, 0.055), Color("677b7a"))
	_box(Vector3(0, -0.005, 0), Vector3(0.065, 0.18, 0.055), Color("654936"))
	for index in 5:
		_box(Vector3(0, -0.075 + index * 0.035, 0), Vector3(0.069, 0.009, 0.059), Color("aa8356"))
	for index in 4:
		_box(Vector3(-0.008, 0.035 - index * 0.032, 0.035), Vector3(0.085, 0.029, 0.045), Color("dba885"))
	_box(Vector3(0.044, -0.024, 0.025), Vector3(0.035, 0.11, 0.07), Color("e4b393"))
	_box(Vector3(0.035, -0.14, 0.07), Vector3(0.095, 0.09, 0.09), Color("5a4840"))
	_box(Vector3(0.065, -0.25, 0.12), Vector3(0.10, 0.19, 0.10), Color("528d7d"))
	_process(0)

func _process(delta: float) -> void:
	_age += delta
	var slash := sin(clampf(reload_ratio, 0, 1) * PI)
	var rest := Vector3(0.34, -0.27, -0.75)
	if guarding:
		rest = Vector3(0.10, -0.14, -0.65)
	position = rest + Vector3(-slash * 0.35, slash * 0.10 + sin(_age * 8) * moving * 0.004, -slash * 0.12)
	rotation = Vector3(-0.12, -0.15, (0.9 if guarding else -0.18) + slash * 1.25)

func _box(at: Vector3, dimensions: Vector3, color: Color) -> void:
	var shape := BoxMesh.new()
	shape.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	shape.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
