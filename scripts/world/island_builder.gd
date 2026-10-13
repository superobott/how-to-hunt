extends RefCounted
## Builds the island from code: a round plateau with stacked, terraced tiers that form a mountain.
## Every tier is a StaticBody3D with a cylinder collider. Their sheer sides are in the
## "climbable" group, so the player can walk into a cliff and climb it.
##
## PLACEHOLDER ART: flat-coloured cylinders and a plane for the sea. No third-party assets.
## Replace with authored meshes later. Keep the collision layout (tier radii and heights) in sync.

const CLIMBABLE_GROUP := &"climbable"
const BASE_DEPTH := 6.0 ## how far every tier extends below y = 0, so there are no gaps
const SEA_HEIGHT := -30.0
const RADIAL_SEGMENTS := 32

## Tier 0 is the plateau the player spawns on. Each later tier sits on top of the previous one.
## "top" is the walkable height of the tier's flat top.
const TIERS: Array[Dictionary] = [
	{"radius": 60.0, "top": 0.0, "color": Color(0.36, 0.62, 0.30)},
	{"radius": 42.0, "top": 7.0, "color": Color(0.45, 0.55, 0.32)},
	{"radius": 26.0, "top": 15.0, "color": Color(0.55, 0.50, 0.38)},
	{"radius": 12.0, "top": 24.0, "color": Color(0.82, 0.84, 0.88)},
]


## Walkable height at a given horizontal distance from the island centre.
## Returns NAN beyond the plateau edge.
static func ground_height_at(distance: float) -> float:
	var height := NAN
	for tier in TIERS:
		if distance <= float(tier["radius"]):
			height = float(tier["top"])
	return height


static func build() -> Node3D:
	var island := Node3D.new()
	island.name = "Island"
	for i in TIERS.size():
		island.add_child(_make_tier(i))
	island.add_child(_make_sea())
	return island


static func _make_tier(index: int) -> StaticBody3D:
	var tier: Dictionary = TIERS[index]
	var radius: float = tier["radius"]
	var top: float = tier["top"]
	var height := top + BASE_DEPTH

	var body := StaticBody3D.new()
	body.name = "Tier%d" % index
	body.position = Vector3(0.0, top - height / 2.0, 0.0)
	body.add_to_group(CLIMBABLE_GROUP)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = RADIAL_SEGMENTS
	mesh.material = _flat_material(tier["color"])
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	return body


static func _make_sea() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	plane.material = _flat_material(Color(0.18, 0.42, 0.70))
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = Vector3(0.0, SEA_HEIGHT, 0.0)
	return sea


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
