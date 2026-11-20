extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.persistence_enabled = false
	world.wildlife_enabled = false
	root.add_child(world)
	await process_frame
	await process_frame
	var hud = world.get_node("HudLayer/Hud")
	var menu = hud.get_child(hud.get_child_count() - 1)
	assert(menu is CanvasLayer)
	assert(not hud._brand.visible)
	assert(hud._mission_progress.max_value == 120)
	var before_feedback: Dictionary = world.state.snapshot()
	var before_health: float = world.health
	world.present_coop_feedback("hit", 0)
	world.present_coop_feedback("hurt", 0)
	assert(world.hit_marker > 0 and world.hurt_flash > 0)
	assert(world.health == before_health and world.state.snapshot() == before_feedback)
	world._update_combat_feedback(1.0)
	assert(world.hit_marker == 0 and world.hurt_flash == 0)
	var predator = preload("res://scripts/hunting/animal.gd").new()
	predator.animal_id = "wolf"
	predator.definition = world.state.animal("wolf")
	predator.position = world.player.position + Vector3.FORWARD * 2
	world.add_child(predator)
	predator.position = world.player.position + Vector3.FORWARD * 2
	predator.set_physics_process(false)
	predator.attack_windup = 0.3
	world._update_combat_feedback(0.0)
	assert("Dodge or guard" in world.threat_text)
	if DisplayServer.get_name() != "headless":
		world.present_coop_feedback("hit", 0)
		world.present_coop_feedback("hurt", 0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/previews/combat-feedback.png")
	predator.attack_windup = 0.0
	world._update_combat_feedback(0.0)
	assert(world.threat_text.is_empty())
	world._update_combat_feedback(1.0)
	world.status_message = ""
	world._notice_time = 0.0
	predator.queue_free()
	world.player.toggle_camera()
	await process_frame
	assert(world.player.third_person)
	assert(world.player._camera.position.length() > 1)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/previews/third-person.png")
	world.player.toggle_camera()
	assert(world.player._camera.position == Vector3.ZERO)
	menu.open_menu()
	assert(paused and menu.overlay.visible)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/previews/pause-menu.png")
	var old_position: Vector3 = world.player.position
	for frame in 5:
		await process_frame
	assert(world.player.position == old_position)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 10)
	root.push_input(click)
	await process_frame
	assert(not paused and not menu.overlay.visible)
	menu.open_menu()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	assert(not paused)
	menu.open_menu()
	menu.menu.hide()
	menu.coop_panel.show()
	menu._refresh_coop()
	await process_frame
	assert(menu.host_button.disabled and menu.join_button.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/previews/coop-menu.png")
	menu.resume()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1")
	assert(peer.create_server(28742, 3) == OK)
	assert(world.coop.begin(peer, true, true))
	await process_frame
	await process_frame
	assert(hud._party.visible and "HOST" in hud._party_title.text)
	assert(hud._coins_caption.text == "SHARED COINS")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/previews/coop-expedition.png")
	menu.open_menu()
	assert(not paused and not world.player.controls_enabled, "co-op menu must not pause other hunters")
	world.coop.stop()
	assert(paused and not world.player.controls_enabled, "leaving returns to the solo pause menu")
	menu.resume()
	assert(not paused and world.player.controls_enabled)
	await process_frame
	await process_frame
	assert(not hud._party.visible and hud._coins_caption.text == "COINS")
	print("HUD, camera, pause, outside-click, Escape and co-op menu checks passed")
	quit()
