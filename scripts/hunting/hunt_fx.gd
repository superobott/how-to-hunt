extends Node3D
## A short, bounded confetti puff. Every burst owns and cleans up its own meshes.

var tint := Color(0.99, 0.79, 0.35)
var lifetime: float = 0.65
var _age: float = 0.0
var _pieces: Array[MeshInstance3D] = []
var _directions: Array[Vector3] = []


static func burst(parent: Node, at: Vector3, color: Color) -> void:
	var puff := load("res://scripts/hunting/hunt_fx.gd").new() as Node3D
	puff.set("tint", color)
	parent.add_child(puff)
	puff.global_position = at


func _ready() -> void:
	for index in 9:
		var mesh := SphereMesh.new()
		mesh.radius = 0.13 if index % 3 == 0 else 0.09
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 5
		mesh.rings = 2
		var material := StandardMaterial3D.new()
		material.albedo_color = tint.lightened(float(index % 3) * 0.14)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.scale = Vector3(1.0, 1.65 if index % 2 == 0 else 1.0, 1.0)
		add_child(piece)
		_pieces.append(piece)
		var angle := TAU * float(index) / 9.0
		_directions.append(Vector3(cos(angle), 0.5 + float(index % 3) * 0.35, sin(angle)))


func _process(delta: float) -> void:
	_age += delta
	var progress := clampf(_age / lifetime, 0.0, 1.0)
	for index in _pieces.size():
		var piece := _pieces[index]
		piece.position = _directions[index] * progress * 1.25 + Vector3.DOWN * progress * progress * 0.45
		piece.rotation += Vector3(1.7, 2.3, 0.7) * delta
		piece.scale = Vector3.ONE * maxf(0.001, 1.0 - progress)
	if _age >= lifetime:
		queue_free()
