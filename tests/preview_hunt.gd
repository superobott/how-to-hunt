extends SceneTree
## Render the real expedition and trader UI into PNGs for visual inspection.
## Run with a graphical Godot driver, not --headless. Saves stay disabled.


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	world.set("persistence_enabled", false)
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.get("player")
	player.set("yaw", -0.55)
	player.get_node("Head").rotation.x = -0.08
	for frame in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/previews")
	var result := root.get_texture().get_image().save_png("res://build/previews/first-expedition.png")
	if result != OK:
		quit(1)
		return
	print("Expedition preview draw calls: %.0f" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	# Stage the actual wildlife models close enough to inspect their silhouettes and rare tint.
	for animal in get_nodes_in_group("hunt_animals"):
		animal.queue_free()
	var animal_script: GDScript = load("res://scripts/hunting/animal.gd")
	for id: String in ["rabbit", "boar"]:
		var animal: CharacterBody3D = animal_script.new()
		animal.set("animal_id", id)
		animal.set("definition", world.get("state").animal(id))
		animal.set("rare", id == "boar")
		animal.position = Vector3(-3.0 if id == "rabbit" else 0.0, 0.1, 48.0)
		world.add_child(animal)
		animal.rotation.y = PI * 0.8
		animal.set_physics_process(false)
	player.global_position = Vector3(-2.0, 0.1, 53.0)
	player.velocity = Vector3.ZERO
	player.set("yaw", -0.10)
	player.get_node("Head").rotation.x = -0.17
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	result = root.get_texture().get_image().save_png("res://build/previews/wildlife.png")
	if result != OK:
		quit(1)
		return
	player.global_position = Vector3(5.5, 0.1, 51.0)
	player.velocity = Vector3.ZERO
	player.set("yaw", -1.1)
	world.get("state").collect_loot("rabbit")
	world.get("state").coins = 48
	world.interact()
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	result = root.get_texture().get_image().save_png("res://build/previews/trader.png")
	var shop: Control = world.get_node("HudLayer/Hud").get("_shop")
	if shop.position.y < 0.0 or shop.get_rect().end.y > root.size.y:
		printerr("Trader panel extends outside the rendered viewport: %s" % shop.get_rect())
		quit(1)
		return
	print("Rendered expedition, wildlife and trader previews.")
	world.get_node("HudLayer").visible = false
	var overview := Camera3D.new()
	world.add_child(overview)
	overview.global_position = Vector3(100.0, 76.0, 135.0)
	overview.look_at(Vector3(0.0, 8.0, 0.0))
	overview.fov = 52.0
	overview.current = true
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	result = root.get_texture().get_image().save_png("res://build/previews/island-overview.png")
	quit(0 if result == OK else 1)
