extends RefCounted
## Static painted sky, warm sunlight and inexpensive distance haze for the compatibility renderer.

const SkyShader := preload("res://shaders/painted_sky.gdshader")


static func build() -> Node3D:
	var atmosphere := Node3D.new()
	atmosphere.name = "Atmosphere"
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-39.0, -32.0, 0.0)
	sun.light_color = Color("ffe5b7")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.8
	atmosphere.add_child(sun)
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SkyShader
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2c5cf")
	environment.ambient_light_energy = 0.36
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.03
	environment.adjustment_saturation = 1.03
	environment.fog_enabled = true
	environment.fog_light_color = Color("b5cfd0")
	environment.fog_density = 0.0008
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	atmosphere.add_child(world_environment)
	_add_distant_islands(atmosphere)
	return atmosphere


static func _add_distant_islands(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("688c91")
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in 5:
		var angle := 0.8 + float(index) * 1.25
		var center := Vector3(cos(angle) * 420.0, -7.0, sin(angle) * 420.0)
		for peak in 2:
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = 78.0 - float(peak) * 16.0
			mesh.height = 90.0 + float((index + peak) % 3) * 25.0
			mesh.radial_segments = 5
			mesh.material = material
			var mountain := MeshInstance3D.new()
			mountain.mesh = mesh
			mountain.position = center + Vector3(float(peak) * 55.0, 0.0, float(peak) * 15.0)
			mountain.rotation.y = float(index) * 0.7
			mountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mountain)
