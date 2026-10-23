extends Node3D
## Camera-attached presentation only. The world owns ammunition, input and projectiles.

const REST_POSITION := Vector3(0.38, -0.32, -0.65)
const UPPER_TIP := Vector3(-0.125, 0.46, 0.06)
const LOWER_TIP := Vector3(-0.125, -0.46, 0.06)
const ACCENTS: Array[Color] = [Color("78bfae"), Color("f5be66"), Color("d9eee4")]

var reload_ratio: float = 0.0
var moving: float = 0.0
var tier: int = 0

var _upper: Node3D
var _lower: Node3D
var _arrow: Node3D
var _top_string: MeshInstance3D
var _bottom_string: MeshInstance3D
var _accent: StandardMaterial3D
var _age: float = 0.0
var _bob_phase: float = 0.0
var _motion: float = 0.0
var _shown_tier: int = -1


func _ready() -> void:
	position = REST_POSITION
	_build_bow()
	_animate(0.0)


func _process(delta: float) -> void:
	_animate(delta)


func _animate(delta: float) -> void:
	_age += delta
	_motion = move_toward(_motion, clampf(moving, 0.0, 1.0), delta * 5.0)
	_bob_phase += delta * lerpf(2.0, 8.5, _motion)
	var reload := clampf(reload_ratio, 0.0, 1.0)
	var draw_amount := sqrt(1.0 - reload)
	position = REST_POSITION + Vector3(
		sin(_bob_phase) * 0.009 * _motion,
		absf(cos(_bob_phase)) * 0.012 * _motion + sin(_age * 1.8) * 0.002 - reload * 0.09,
		0.0
	)
	rotation = Vector3(0.035 + reload * 0.20, -0.10, -0.10 + sin(_bob_phase) * 0.012 * _motion + reload * 0.16)
	_upper.rotation.z = -draw_amount * 0.045
	_lower.rotation.z = draw_amount * 0.045
	var nock := Vector3(-0.125, 0.0, lerpf(0.035, 0.19, draw_amount))
	_set_segment(_top_string, _upper.transform * UPPER_TIP, nock)
	_set_segment(_bottom_string, nock, _lower.transform * LOWER_TIP)
	_arrow.position = nock
	_arrow.visible = reload <= 0.35
	var clamped_tier := clampi(tier, 0, ACCENTS.size() - 1)
	if clamped_tier != _shown_tier:
		_shown_tier = clamped_tier
		_accent.albedo_color = ACCENTS[clamped_tier]


func _build_bow() -> void:
	var wood := _material(Color("a9703f"))
	var dark_wood := _material(Color("654a35"))
	var string_material := _material(Color("e9d7ad"))
	var skin := _material(Color("d6a37f"))
	var metal := _material(Color("d5e3de"), 0.35)
	_accent = _material(ACCENTS[0])
	_upper = Node3D.new()
	_upper.name = "UpperLimb"
	add_child(_upper)
	_lower = Node3D.new()
	_lower.name = "LowerLimb"
	add_child(_lower)
	var curve: Array[Vector3] = [
		Vector3(0.0, 0.055, 0.0), Vector3(0.030, 0.13, -0.020),
		Vector3(0.045, 0.23, -0.035), Vector3(0.020, 0.32, -0.020),
		Vector3(-0.020, 0.39, 0.005), Vector3(-0.070, 0.44, 0.035), UPPER_TIP,
	]
	for index in curve.size() - 1:
		var radius := lerpf(0.023, 0.011, float(index) / float(curve.size() - 2))
		_segment(_upper, curve[index], curve[index + 1], radius, wood)
		var start := Vector3(curve[index].x, -curve[index].y, curve[index].z)
		var end := Vector3(curve[index + 1].x, -curve[index + 1].y, curve[index + 1].z)
		_segment(_lower, start, end, radius, wood)
	_segment(self, Vector3(0, -0.085, 0), Vector3(0, 0.085, 0), 0.031, dark_wood)
	for index in 6:
		var height := -0.058 + float(index) * 0.023
		_segment(self, Vector3(0, height, 0), Vector3(0, height + 0.013, 0), 0.034, _accent)
	for limb in [_upper, _lower]:
		var tip: Vector3 = UPPER_TIP if limb == _upper else LOWER_TIP
		var band_start := tip + Vector3(0.016, -0.013 if limb == _upper else 0.013, -0.009)
		_segment(limb, band_start, tip, 0.015, _accent)
	_top_string = _segment(self, UPPER_TIP, Vector3(-0.125, 0, 0.19), 0.0023, string_material)
	_bottom_string = _segment(self, Vector3(-0.125, 0, 0.19), LOWER_TIP, 0.0023, string_material)

	# A small mitten and cuff keep the view grounded without obscuring the target.
	var hand := BoxMesh.new()
	hand.size = Vector3(0.085, 0.13, 0.09)
	_add_mesh(self, hand, Vector3(0.026, -0.018, 0.065), skin)
	_segment(self, Vector3(0.055, -0.095, 0.085), Vector3(0.12, -0.20, 0.21), 0.046, _accent)
	_build_arrow(wood, metal)


func _build_arrow(wood: StandardMaterial3D, metal: StandardMaterial3D) -> void:
	_arrow = Node3D.new()
	_arrow.name = "NockedArrow"
	add_child(_arrow)
	_segment(_arrow, Vector3.ZERO, Vector3(0, 0, -0.61), 0.0065, wood)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.026
	tip.height = 0.085
	tip.radial_segments = 4
	var arrowhead := _add_mesh(_arrow, tip, Vector3(0, 0, -0.64), metal)
	arrowhead.rotation.x = -PI / 2.0
	for index in 2:
		var feather := BoxMesh.new()
		feather.size = Vector3(0.052, 0.003, 0.075)
		var visual := _add_mesh(_arrow, feather, Vector3(0, 0, -0.065), _accent)
		visual.rotation.z = float(index) * PI / 2.0


func _segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 7
	var visual := _add_mesh(parent, mesh, (start + end) * 0.5, material)
	_set_segment(visual, start, end)
	return visual


func _set_segment(visual: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var direction := end - start
	var mesh := visual.mesh as CylinderMesh
	mesh.height = maxf(direction.length(), 0.0001)
	visual.position = (start + end) * 0.5
	if not direction.is_zero_approx():
		visual.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))


func _add_mesh(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	material.metallic = metallic
	return material
