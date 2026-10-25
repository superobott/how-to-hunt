extends RefCounted
## Builds the island from code: a round plateau with stacked, terraced tiers that form a mountain.
## Every tier is a StaticBody3D with a cylinder collider. Their sheer sides are in the
## "climbable" group, so the player can walk into a cliff and climb it.
##
## Original procedural meadow, layered rock and water. The visual mesh follows the
## cylinder collision closely so climbing and ledges remain predictable.

const CLIMBABLE_GROUP := &"climbable"
const BASE_DEPTH := 6.0 ## how far every tier extends below y = 0, so there are no gaps
const SEA_HEIGHT := -30.0
const TerrainMesh := preload("res://scripts/world/terrain_mesh.gd")
const TerraceShader := preload("res://shaders/terrace.gdshader")
const MeadowShader := preload("res://shaders/meadow.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")

## Tier 0 is the plateau the player spawns on. Each later tier sits on top of the previous one.
## "top" is the walkable height of the tier's flat top.
const TIERS: Array[Dictionary] = [
	{"radius": 60.0, "top": 0.0, "color": Color(0.39, 0.57, 0.26)},
	{"radius": 42.0, "top": 7.0, "color": Color(0.48, 0.58, 0.30)},
	{"radius": 26.0, "top": 15.0, "color": Color(0.53, 0.56, 0.34)},
	{"radius": 12.0, "top": 24.0, "color": Color(0.67, 0.69, 0.53)},
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

	var meadow := ShaderMaterial.new()
	meadow.shader = MeadowShader
	meadow.set_shader_parameter("meadow_color", tier["color"])
	meadow.set_shader_parameter("tier_radius", radius)
	meadow.set_shader_parameter("terrace_index", float(index))
	var cliff := ShaderMaterial.new()
	cliff.shader = TerraceShader
	cliff.set_shader_parameter("meadow_color", tier["color"])
	cliff.set_shader_parameter("cliff_color", Color(0.57, 0.52, 0.43).lerp(Color(0.49, 0.52, 0.48), float(index) / 5.0))
	cliff.set_shader_parameter("tier_top", top)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainSurface"
	mesh_instance.mesh = TerrainMesh.build(radius, height, index, meadow, cliff)
	body.add_child(mesh_instance)
	return body


static func _make_sea() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	var water := ShaderMaterial.new()
	water.shader = WaterShader
	plane.material = water
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = Vector3(0.0, SEA_HEIGHT, 0.0)
	return sea
