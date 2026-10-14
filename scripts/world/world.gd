extends Node3D
## Assembles the playable world: island, player, light and sky.

const IslandBounds := preload("res://scripts/core/island_bounds.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const PlayerScript := preload("res://scripts/player/player.gd")

const PLATEAU_RADIUS := 60.0
const OUTER_RADIUS := 90.0
const KILL_HEIGHT := -40.0
## On the plateau, between the cliff edge and the foot of the mountain.
const SPAWN_POINT := Vector3(0.0, 1.5, 52.0)

var bounds: RefCounted
var player: CharacterBody3D


func _ready() -> void:
	InputSetup.ensure_actions()
	bounds = IslandBounds.new(PLATEAU_RADIUS, OUTER_RADIUS, KILL_HEIGHT, SPAWN_POINT)
	add_child(IslandBuilder.build())
	_add_lighting()

	player = PlayerScript.new()
	player.name = "Player"
	player.bounds = bounds
	player.position = SPAWN_POINT
	add_child(player)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = false # Keep the 60 FPS budget for later milestones.
	add_child(sun)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.55, 0.90)
	sky_material.sky_horizon_color = Color(0.72, 0.85, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
