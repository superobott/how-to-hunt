extends SceneTree
## Real transport integration fixture. Four processes use loopback, never Steam or solo saves.
const Animal := preload("res://scripts/hunting/animal.gd")
const Arrow := preload("res://scripts/hunting/arrow.gd")
var silence := false
var arrows_spawned := 0
var disconnect_reason := ""
var saw_hit := false
var saw_hurt := false
var gate: Node
var world: Node3D
var role := "host"
var slot := 0
var port := 28741
var failures := 0
var stage := 0
var elapsed := 0.0
var stage_time := 0.0
var old_count := 0
var solo: Dictionary
var save_hash := ""
var baseline_positions: Dictionary = {}
var initialized := false
var file_path := ""
var fired := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="): role = argument.trim_prefix("--role=")
		if argument.begins_with("--slot="): slot = int(argument.trim_prefix("--slot="))
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
		if argument == "--silence": silence = true
	world = load("res://scenes/main.tscn").instantiate()
	world.persistence_enabled = false
	world.wildlife_enabled = false
	root.add_child(world)
	gate = preload("res://tests/coop_gate.gd").new()
	gate.name = "CoopGate"
	root.add_child(gate)
	world.child_entered_tree.connect(func(child: Node) -> void:
		if child.get_script() == Arrow: arrows_spawned += 1
	)
	world.coop.session_failed.connect(func(reason: String) -> void: disconnect_reason = reason)
	await process_frame
	world.state.coins = 1000 if role == "host" else 777 + slot
	file_path = "user://test_coop_%d_%d.json" % [port, slot]
	world.save_path = file_path
	world.persistence_enabled = true
	world._save_now()
	solo = world.state.snapshot()
	save_hash = FileAccess.get_sha256(file_path)
	var peer := ENetMultiplayerPeer.new()
	var result: int
	if role == "host":
		peer.set_bind_ip("127.0.0.1")
		result = peer.create_server(port, 3)
	else:
		result = peer.create_client("127.0.0.1", port)
	expect(result == OK, "loopback transport starts")
	if result != OK:
		finish()
		return
	world.coop.begin(peer, role == "host", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	initialized = true
	print("READY " + role)

func _process(delta: float) -> bool:
	if not initialized: return false
	saw_hit = saw_hit or world.hit_marker > 0
	saw_hurt = saw_hurt or world.hurt_flash > 0
	elapsed += delta
	stage_time += delta
	if elapsed > 55:
		print("DEBUG state ", world.state.snapshot(), " position ", world.player.position)
		if role == "host":
			for id in world.coop.actors:
				print("DEBUG hunter ", id, " ", world.coop.ledger.hunters[id].snapshot(), " position ", world.coop.actors[id].body.position, " shop ", world.coop.actors[id].shop)
		expect(false, "scenario timeout at stage %d (%s)" % [stage, role])
		finish()
		return true
	if role == "host": tick_host()
	else: tick_guest()
	return false

func tick_host() -> void:
	match stage:
		0:
			if world.coop.actors.size() != 3: return
			expect(world.coop.ledger.hunters.size() == 4, "host plus three guests admitted")
			var place := -2.0
			for id in world.coop.actors:
				world.coop.actors[id].body.position = Vector3(place, 24.1, -2)
				world.coop.actors[id].body.velocity = Vector3.ZERO
				world.coop.actors[id].body.set_physics_process(false)
				place += 2.0
			advance()
		1:
			for state in world.coop.ledger.hunters.values():
				if state == world.state: continue
				if state.tool_id != "starter_bow" or not "trail_boots" in state.owned_gear: return
			expect(world.state.coins == 370, "shared wallet pays exactly once for three individual loadouts")
			expect(world.state.tool_id == "knife" and world.state.owned_gear.is_empty(), "guest purchases do not equip the host")
			for id in world.coop.actors:
				baseline_positions[id] = world.coop.actors[id].body.position
				world.coop.actors[id].body.set_physics_process(true)
			advance()
		2:
			var moved := true
			for id in world.coop.actors:
				if world.coop.actors[id].body.position.distance_to(baseline_positions[id]) < 0.5: moved = false
			if not moved: return
			expect(true, "all three guest inputs move host-authoritative bodies")
			var index := 0
			for id in world.coop.actors:
				var body: Node3D = world.coop.actors[id].body
				body.position = Vector3(index * 5, 0.1, 60)
				body.velocity = Vector3.ZERO
				world.coop.damage_hunter(body, 10.0, body.position + Vector3.FORWARD)
				var animal := Animal.new()
				animal.animal_id = "rabbit"
				animal.definition = world.state.animal("rabbit")
				animal.position = Vector3(index * 5, 0.1, 56)
				animal.inner_radius = 0
				animal.outer_radius = 100
				animal.defeated.connect(world._on_animal_defeated)
				world.add_child(animal)
				animal.set_physics_process(false)
				index += 1
			advance()
		3:
			# Hold the firing fixture still until all arrows land. Movement was checked
			# separately; interpolation/transport delay must not shift this aim target.
			if world.state.hunts < 3:
				var index := 0
				for actor in world.coop.actors.values():
					actor.body.position = Vector3(index * 5, 0.1, 60)
					actor.body.velocity = Vector3.ZERO
					index += 1
			if world.state.hunts != 3 or world.state.coins != 406: return
			expect(world.state.xp == 60, "three physical guest arrows award shared hunt XP")
			expect(arrows_spawned == 3, "host cooldown rejects repeated attack commands")
			for state in world.coop.ledger.hunters.values():
				expect(not "coin_magnet" in state.owned_gear, "remote purchases require trader proximity and fresh command sequence")
			expect(get_nodes_in_group("hunt_loot").is_empty(), "host collects each drop once")
			world._save_now()
			expect(FileAccess.get_sha256(file_path) != save_hash, "host persists expedition progress")
			advance()
		4:
			if world.coop.actors.size() != 2 or gate.received.size() != 3: return
			expect(true, "guest departure removes authoritative actor")
			expect(world.coop.max_snapshot_chunk_bytes > 0 and world.coop.max_snapshot_chunk_bytes <= 1000, "snapshot payloads stay within datagram budget")
			if silence:
				world.coop.set_physics_process(false) # Keep transport open but withhold authoritative snapshots.
				stage = 6
			else:
				world.coop.stop()
				advance()
		5:
			if stage_time > 1.0: finish()
		6:
			if not world.coop.actors.is_empty(): return
			expect(true, "guests disconnect from a silent host without transport closure")
			world.coop.stop()
			finish()

func tick_guest() -> void:
	match stage:
		0:
			if world.coop._last_snapshot < 0 or world.player.position.distance_to(world.TRADER_POINT) >= 4: return
			expect(not world.persistence_enabled, "guest persistence disabled before applying host state")
			expect(world.state.tool_id == "knife", "guest starts with session equipment")
			world.coop.request("shop")
			world.state.coins = 999999 # A modified client wallet cannot authorize a purchase.
			world.coop.request("buy", "viking_bow")
			world.coop.request("buy", "nonexistent_item")
			world.coop.request("buy", "trail_boots")
			world.coop.request("buy", "trail_boots") # Duplicate must not charge twice.
			world.coop.request("buy", "starter_bow")
			world.coop._submit_command.rpc_id(1, world.coop._command_sequence, "buy", "coin_magnet")
			advance()
		1:
			if world.state.coins != 370 or world.state.tool_id != "starter_bow": return
			expect("trail_boots" in world.state.owned_gear, "individual equipment replicated")
			expect(world.coop.avatars.size() == 3, "all other hunters replicated")
			var hud: Control = world.get_node("HudLayer/Hud")
			hud._refresh(world.state)
			expect(hud._party.visible and hud._party_title.text == "GUEST  /  4 OF 4 HUNTERS", "guest HUD identifies expedition role and party size")
			expect(hud._coins_caption.text == "SHARED COINS", "guest HUD identifies the shared wallet")
			world.shop_open = true
			hud._refresh(world.state)
			expect(hud._save_status.text == "Session gear only / solo save untouched", "guest store explains session progression instead of preview mode")
			world.shop_open = false
			world.coop.request("close_shop")
			Input.action_press("move_forward")
			advance()
		2:
			if world.player.position.z < 45: return
			Input.action_release("move_forward")
			world.coop.request("shop")
			world.coop.request("buy", "coin_magnet")
			var prey: Node3D
			var best := INF
			for animal in get_nodes_in_group("hunt_animals"):
				var distance: float = world.player.position.distance_to(animal.position)
				if distance < best:
					best = distance
					prey = animal
			if prey == null: return
			var direction: Vector3 = (prey.position + Vector3.UP * prey._body_radius - world.player.get_node("Head").global_position).normalized()
			world.player.yaw = atan2(-direction.x, -direction.z)
			world.player.pitch = asin(direction.y)
			world.player.get_node("Head").rotation.x = world.player.pitch
			advance()
		3:
			if stage_time < 0.25: return
			if not fired:
				world.attack()
				world.coop.request("attack")
				world.coop.request("attack")
				fired = true
			if world.state.hunts != 3: return
			world.player.yaw = 0
			Input.action_press("move_forward")
			advance()
		4:
			if world.state.coins != 406: return
			Input.action_release("move_forward")
			expect(FileAccess.get_sha256(file_path) == save_hash, "guest session never writes solo progress")
			expect(saw_hit, "guest receives host-confirmed hit feedback")
			expect(saw_hurt, "guest receives host-confirmed damage feedback")
			advance()
			gate.ready_to_leave.rpc_id(1)
		5:
			if slot == 1 and gate.confirmed and world.coop.active:
				world.coop.stop()
			if world.coop.active: return
			if silence and slot != 1:
				expect(disconnect_reason == "coop.connection_failed", "snapshot silence restores solo through timeout recovery")
			expect(world.state.snapshot() == solo, "leaving or host disconnect restores solo state")
			expect(world.persistence_enabled, "solo persistence restored")
			expect(FileAccess.get_sha256(file_path) == save_hash, "solo file unchanged after session ends")
			finish()

func advance() -> void:
	stage += 1
	stage_time = 0.0

func expect(ok: bool, message: String) -> void:
	if ok: print("PASS " + message)
	else:
		failures += 1
		printerr("FAIL " + message)

func finish() -> void:
	initialized = false
	world.persistence_enabled = false
	world._save_clock = -1
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(file_path + suffix): DirAccess.remove_absolute(file_path + suffix)
	print("COOP COMPLETE %s %d failures" % [role, failures])
	quit(1 if failures else 0)
