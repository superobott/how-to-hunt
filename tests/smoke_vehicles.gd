extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.persistence_enabled = false
	world.wildlife_enabled = false
	root.add_child(world)
	await process_frame
	world.state.coins = 1000000
	for id in ["bike", "car", "airplane"]:
		assert(world.state.buy_gear(id))
		assert(not world.state.buy_gear(id))
		world.player.set_vehicle(id, world.state.catalog.gear[id].multiplier)
		assert(world.player.vehicle_id == id)
		Input.action_press("move_forward")
		var start: Vector3 = world.player.position
		for frame in 30:
			await physics_frame
		Input.action_release("move_forward")
		assert(world.player.position.distance_to(start) > 0.1)
	world.player.set_vehicle("")
	assert(world.player.vehicle_id.is_empty())
	var restored = load("res://scripts/core/hunt_state.gd").new()
	assert(restored.restore(world.state.snapshot()))
	assert("airplane" in restored.owned_gear)
	print("Vehicle purchase, movement, dismount and save checks passed")
	quit()
