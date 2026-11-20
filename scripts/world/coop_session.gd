extends Node
## Host simulation; clients submit input/intents and render authoritative snapshots.
signal session_changed
signal session_failed(message: String)
const Expedition := preload("res://scripts/core/expedition.gd")
const Player := preload("res://scripts/player/player.gd")
const Animal := preload("res://scripts/hunting/animal.gd")
const Loot := preload("res://scripts/hunting/loot_drop.gd")
const Arrow := preload("res://scripts/hunting/arrow.gd")
const Inputs := preload("res://scripts/core/input_setup.gd")
const SnapshotWire := preload("res://scripts/core/snapshot_wire.gd")
const NetworkPose := preload("res://scripts/core/network_pose.gd")
const PROTOCOL := SnapshotWire.PROTOCOL
var _wire := SnapshotWire.new()
var _poses: Dictionary = {}
var max_snapshot_chunk_bytes := 0
var world: Node3D
var active := false
var hosting := false
var connected := false
var local_transport := false
var ledger: RefCounted
var actors: Dictionary = {}
var replicas: Dictionary = {}
var avatars: Dictionary = {}
var _solo: Dictionary = {}
var _persist := false
var _wildlife := false
var _send_clock := 0.0
var _connect_clock := 0.0
var _input_sequence := 0
var _command_sequence := 0
var _snapshot_sequence := 0
var _last_snapshot := -1
var _stopping := false

func _ready() -> void:
	process_physics_priority = 2
	var steam := get_node("/root/SteamService")
	steam.lobby_changed.connect(_on_lobby)
	steam.lobby_failed.connect(func(reason: String) -> void: session_failed.emit(reason))
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_host_left)

func _on_lobby(id: int) -> void:
	if _stopping:
		return
	if id == 0:
		if active:
			stop()
		return
	var steam := get_node("/root/SteamService")
	var peer: MultiplayerPeer = steam.create_transport()
	if peer == null:
		steam.leave_lobby()
		session_failed.emit("coop.transport_failed")
		return
	begin(peer, steam.is_lobby_host())

func begin(peer: MultiplayerPeer, as_host: bool, local_test: bool = false) -> bool:
	if active or peer == null:
		return false
	active = true
	hosting = as_host
	connected = as_host
	local_transport = local_test
	_input_sequence = 0
	_command_sequence = 0
	_snapshot_sequence = 0
	_last_snapshot = -1
	_wire = SnapshotWire.new()
	_poses.clear()
	max_snapshot_chunk_bytes = 0
	_connect_clock = 0.0
	_solo = world.state.snapshot()
	_persist = world.persistence_enabled
	_wildlife = world.wildlife_enabled
	get_tree().paused = false
	world.player.controls_enabled = true
	if hosting:
		ledger = Expedition.new(world.state)
	else:
		world._save_now()
		world.persistence_enabled = false
		world.wildlife_enabled = false
		world.player.network_view_only = true
		_clear_entities()
	multiplayer.multiplayer_peer = peer
	session_changed.emit()
	return true

func is_guest() -> bool:
	return active and not hosting

func _connected() -> void:
	if is_guest():
		connected = true
		_register.rpc_id(1, PROTOCOL)

@rpc("any_peer", "call_remote", "reliable")
func _register(protocol: String) -> void:
	if not active or not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if actors.has(id):
		return
	if protocol != PROTOCOL or ledger.hunters.size() >= 4:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var identity := "local-%d" % id if local_transport else str(get_node("/root/SteamService").peer_identity(multiplayer.multiplayer_peer, id))
	if not ledger.add_hunter(id, identity):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var body := Player.new()
	body.remote_controlled = true
	body.name = "Hunter_%d" % id
	body.bounds = world.bounds
	body.position = world.SPAWN_POINT + Vector3(2 * actors.size() + 2, 0, 0)
	world.add_child(body)
	actors[id] = {"body": body, "health": 100.0, "hurt": 0.0, "since_hurt": 100.0,
		"cooldown": 0.0, "knife": false, "input_seq": -1, "cmd_seq": -1,
		"input_age": 0.0, "commands": [], "shop": false}
	body.respawned.connect(func() -> void:
		if actors.has(id):
			actors[id].health = 100.0
			actors[id].hurt = 3.0
			actors[id].shop = false
			body.controls_enabled = true
			body.stamina = 100.0
	)
	_send_snapshots()

func _peer_connected(_id: int) -> void:
	pass # Registration confirms protocol and lobby membership before spawning.

func _peer_disconnected(id: int) -> void:
	if hosting and actors.has(id):
		actors[id].body.queue_free()
		actors.erase(id)
		ledger.remove_hunter(id)

func _connection_failed() -> void:
	if active:
		stop()
		session_failed.emit("coop.connection_failed")

func _host_left() -> void:
	if is_guest():
		stop()
		session_failed.emit("coop.host_left")

func stop() -> void:
	if not active or _stopping:
		return
	_stopping = true
	var was_guest := not hosting
	active = false
	connected = false
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for actor in actors.values():
		actor.body.queue_free()
	actors.clear()
	for avatar in avatars.values():
		avatar.queue_free()
	avatars.clear()
	_poses.clear()
	if was_guest:
		_clear_entities()
		replicas.clear()
		world.state.restore(_solo)
		world.persistence_enabled = _persist
		world.wildlife_enabled = _wildlife
		world.player.network_view_only = false
		world.player.respawn()
		world._knife_selected = false
		if _wildlife:
			for index in int(world.state.catalog.spawn.count):
				world._spawn_animal(index == 0)
	else:
		for animal in get_tree().get_nodes_in_group("hunt_animals"):
			animal.player = world.player
		world._save_now()
	ledger = null
	hosting = false
	get_node("/root/SteamService").leave_lobby()
	_stopping = false
	session_changed.emit()

func _clear_entities() -> void:
	for group in ["hunt_animals", "hunt_loot"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get_parent() == world:
				node.remove_from_group(group)
				node.queue_free()
	for child in world.get_children():
		if child.get_script() == Arrow:
			child.queue_free()

func _process(delta: float) -> void:
	if not is_guest():
		return
	for node in _poses.keys():
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_poses.erase(node)
			continue
		var pose: RefCounted = _poses[node]
		pose.step(delta)
		node.position = pose.position
		if node != world.player:
			node.rotation = pose.rotation

func _present(node: Node3D, position: Vector3, rotation: Vector3) -> void:
	if not _poses.has(node):
		_poses[node] = NetworkPose.new()
	var pose: RefCounted = _poses[node]
	pose.push(position, rotation)
	node.position = pose.position
	if node != world.player:
		node.rotation = pose.rotation

func _physics_process(delta: float) -> void:
	if not active:
		return
	if is_guest():
		_connect_clock += delta
		if _connect_clock > 20.0:
			_connection_failed()
			return
		if connected:
			_input_sequence += 1
			var input_available: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Input.get_connected_joypads().is_empty() or (local_transport and DisplayServer.get_name() == "headless")
			var enabled: bool = world.player.controls_enabled and input_available and not world.shop_open
			_submit_input.rpc_id(1, _input_sequence,
				Input.get_vector(Inputs.MOVE_LEFT, Inputs.MOVE_RIGHT, Inputs.MOVE_BACK, Inputs.MOVE_FORWARD) if enabled else Vector2.ZERO,
				Vector2(world.player.yaw, world.player.pitch), enabled and Input.is_action_just_pressed(Inputs.JUMP),
				enabled and Input.is_action_pressed(Inputs.SPRINT), enabled and Input.is_action_pressed(Inputs.AIM),
				float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL)) if enabled else 0.0)
		return
	ledger.sync_wallet()
	for id in actors.keys():
		var actor: Dictionary = actors[id]
		var body: CharacterBody3D = actor.body
		var state: RefCounted = ledger.hunters[id]
		actor.cooldown = maxf(0, actor.cooldown - delta)
		actor.hurt = maxf(0, actor.hurt - delta)
		actor.since_hurt += delta
		actor.input_age += delta
		if actor.shop and body.position.distance_to(world.TRADER_POINT) >= world.TRADER_RANGE:
			actor.shop = false
			body.controls_enabled = true
		if actor.input_age > 0.5:
			body.network_input = {}
			body.guarding = false
		body.speed_multiplier = state.gear_effect("speed", 1.0)
		body.jump_multiplier = state.gear_effect("jump", 1.0)
		if Vector2(body.position.x, body.position.z).length() < 14:
			actor.health = minf(100, actor.health + 14 * delta)
		elif actor.since_hurt > 12:
			actor.health = minf(100, actor.health + 2 * delta)
		var commands: Array = actor.commands.duplicate()
		actor.commands.clear()
		for command in commands:
			_execute(id, command[0], command[1])
		_collect(id)
	# Every animal chooses its nearest living hunter on the authoritative host.
	for animal in get_tree().get_nodes_in_group("hunt_animals"):
		var nearest: Node3D = world.player
		for actor in actors.values():
			if animal.position.distance_squared_to(actor.body.position) < animal.position.distance_squared_to(nearest.position):
				nearest = actor.body
		animal.player = nearest
	_send_clock -= delta
	if _send_clock <= 0:
		_send_clock = 0.1
		_send_snapshots()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(sequence: int, move: Vector2, look: Vector2, jump: bool, sprint: bool, guard: bool, lift: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not hosting or not actors.has(id) or not valid_input(move, look, lift):
		return
	var actor: Dictionary = actors[id]
	if sequence <= actor.input_seq:
		return
	actor.input_seq = sequence
	actor.input_age = 0.0
	var body: CharacterBody3D = actor.body
	body.network_input = {"move": move.limit_length(), "yaw": wrapf(look.x, -PI, PI),
		"pitch": clampf(look.y, -1.45, 1.45), "jump": jump or bool(body.network_input.get("jump", false)), "sprint": sprint, "lift": lift}
	body.guarding = guard and _using_knife(id) and body.stamina > 8

static func valid_input(move: Vector2, look: Vector2, lift: float) -> bool:
	return move.is_finite() and look.is_finite() and is_finite(lift) and move.length() <= 1.01 and absf(lift) <= 1.0 and absf(look.x) < 100000 and absf(look.y) <= PI

func request(command: String, item: String = "") -> bool:
	if not is_guest() or not connected or _last_snapshot < 0:
		return false
	_command_sequence += 1
	_submit_command.rpc_id(1, _command_sequence, command, item)
	return true

@rpc("any_peer", "call_remote", "reliable", 2)
func _submit_command(sequence: int, command: String, item: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not hosting or not actors.has(id) or command not in ["attack", "buy", "swap", "vehicle", "shop", "close_shop"] or item.length() > 64:
		return
	var actor: Dictionary = actors[id]
	if sequence <= actor.cmd_seq:
		return
	actor.cmd_seq = sequence
	if actor.commands.size() < 8:
		actor.commands.append([command, item])

func _using_knife(id: int) -> bool:
	return bool(actors[id].knife) or ledger.hunters[id].tool_id == "knife"

func _execute(id: int, command: String, item: String) -> void:
	var actor: Dictionary = actors[id]
	var body: CharacterBody3D = actor.body
	var state: RefCounted = ledger.hunters[id]
	var near: bool = body.position.distance_to(world.TRADER_POINT) < world.TRADER_RANGE
	match command:
		"shop":
			actor.shop = near
			body.controls_enabled = not near
		"close_shop":
			actor.shop = false
			body.controls_enabled = true
		"buy":
			if near and actor.shop and ledger.purchase(id, item):
				actor.knife = false
		"swap": actor.knife = not actor.knife
		"attack": _attack(id)
		"vehicle":
			var choices: Array[String] = [""]
			for owned in state.owned_gear:
				if state.catalog.gear[owned].get("vehicle", false):
					choices.append(owned)
			var choice: String = choices[(choices.find(body.vehicle_id) + 1) % choices.size()]
			body.set_vehicle(choice, 0.0 if choice.is_empty() else float(state.catalog.gear[choice].multiplier))

func _attack(id: int) -> void:
	var actor: Dictionary = actors[id]
	var body: CharacterBody3D = actor.body
	var state: RefCounted = ledger.hunters[id]
	if actor.cooldown > 0 or actor.shop or not body.vehicle_id.is_empty():
		return
	var knife := _using_knife(id)
	var tool: Dictionary = state.catalog.tools.knife if knife else state.tool()
	if knife and body.stamina < 12:
		return
	actor.cooldown = float(tool.reload) * (1.0 if knife else state.gear_effect("reload", 1.0))
	_receive_feedback.rpc_id(id, "shoot", 0)
	var eye: Vector3 = body.get_node("Head").global_position
	var camera: Camera3D = body.get_node("Head/Camera")
	var forward := -camera.global_basis.z
	if not knife:
		var arrow := Arrow.new()
		arrow.position = eye
		arrow.direction = forward
		arrow.speed = float(tool.speed)
		arrow.damage = float(tool.damage)
		arrow.shooter = body
		arrow.shot_origin = eye
		arrow.hit_confirmed.connect(func() -> void:
			if active and hosting and actors.has(id):
				_receive_feedback.rpc_id(id, "hit", 0)
		)
		world.add_child(arrow)
		return
	body.stamina -= 12
	var closest: Node3D
	var best := float(tool.range)
	for animal in get_tree().get_nodes_in_group("hunt_animals"):
		if animal.is_queued_for_deletion():
			continue
		var aim: Vector3 = animal.global_position + Vector3.UP * animal._body_radius
		var offset := aim - eye
		if offset.length() > best or forward.dot(offset.normalized()) < 0.72:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, aim)
		query.exclude = [body.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider") == animal:
			closest = animal
			best = offset.length()
	if closest != null:
		closest.take_hit(float(tool.damage), closest.global_position + Vector3.UP * closest._body_radius, eye)
		_receive_feedback.rpc_id(id, "hit", 0)

func _collect(id: int) -> void:
	var body: CharacterBody3D = actors[id].body
	var state: RefCounted = ledger.hunters[id]
	for coin in get_tree().get_nodes_in_group("hunt_loot"):
		if not coin.is_queued_for_deletion() and body.position.distance_to(coin.position) <= state.gear_effect("pickup", 2.2):
			ledger.collect(id, coin.animal_id, coin.rare, coin.trick_shot)
			coin.remove_from_group("hunt_loot")
			coin.queue_free()

func damage_hunter(body: Node3D, amount: float, from: Vector3) -> void:
	for id in actors:
		var actor: Dictionary = actors[id]
		if actor.body != body:
			continue
		if amount <= 0 or actor.hurt > 0 or Vector2(body.position.x, body.position.z).length() < 14:
			return
		var toward := from - body.position
		toward.y = 0
		if body.guarding and body.stamina >= 18 and (-body.global_basis.z).dot(toward.normalized()) > 0.1:
			amount *= 0.25
			body.stamina -= 18
		actor.health = maxf(0, actor.health - amount)
		actor.hurt = 0.7
		actor.since_hurt = 0.0
		if actor.health <= 0:
			var before: int = ledger.host.coins
			ledger.defeat()
			body.respawn()
			_receive_feedback.rpc_id(id, "defeated", before - ledger.host.coins)
		else:
			_receive_feedback.rpc_id(id, "hurt", 0)
		return

@rpc("authority", "call_remote", "reliable")
func _receive_feedback(kind: String, amount: int) -> void:
	if is_guest():
		world.present_coop_feedback(kind, amount)

func _send_snapshots() -> void:
	_snapshot_sequence += 1
	var entities: Array = []
	for child in world.get_children():
		if child.is_queued_for_deletion():
			continue
		var kind := ""
		if child.get_script() == Animal: kind = "animal"
		elif child.get_script() == Loot: kind = "loot"
		elif child.get_script() == Arrow: kind = "arrow"
		if kind.is_empty(): continue
		var record := {"id": child.get_instance_id(), "kind": kind, "position": child.position, "rotation": child.rotation}
		if kind != "arrow":
			record["species"] = child.animal_id
			record["rare"] = child.rare
		if kind == "animal":
			record["health"] = child.health
			record["windup"] = child.attack_windup
		entities.append(record)
	var players: Dictionary = {1: _player_record(world.player, world.health)}
	for id in actors:
		players[id] = _player_record(actors[id].body, actors[id].health)
	for id in actors:
		var chunks := SnapshotWire.encode({"state": ledger.hunters[id].snapshot(), "players": players,
			"entities": entities, "knife": _using_knife(id), "cooldown": actors[id].cooldown})
		for index in chunks.size():
			max_snapshot_chunk_bytes = maxi(max_snapshot_chunk_bytes, chunks[index].size())
			_receive_chunk.rpc_id(id, _snapshot_sequence, index, chunks.size(), chunks[index])

func _player_record(body: Node3D, hp: float) -> Dictionary:
	return {"position": body.position, "yaw": body.yaw, "pitch": body.pitch,
		"stamina": body.stamina, "exhausted": body.sprint_exhausted, "health": hp, "vehicle": body.vehicle_id}

@rpc("authority", "call_remote", "unreliable", 3)
func _receive_chunk(sequence: int, index: int, count: int, payload: PackedByteArray) -> void:
	if not is_guest() or sequence <= _last_snapshot:
		return
	var snapshot := _wire.accept(sequence, index, count, payload)
	if not snapshot.is_empty():
		_receive_snapshot(sequence, snapshot)

func _receive_snapshot(sequence: int, snapshot: Dictionary) -> void:
	if not is_guest() or sequence <= _last_snapshot:
		return
	if not snapshot.has_all(["state", "players", "entities", "knife", "cooldown"]):
		return
	if not world.state.restore(snapshot.state):
		return
	_last_snapshot = sequence
	_connect_clock = 0.0
	world._knife_selected = snapshot.knife
	world._cooldown = snapshot.cooldown
	var own := multiplayer.get_unique_id()
	for id in snapshot.players:
		var info: Dictionary = snapshot.players[id]
		if id == own:
			_present(world.player, info.position, Vector3.ZERO)
			world.player.stamina = info.stamina
			world.player.sprint_exhausted = info.exhausted
			world.health = info.health
			if world.player.vehicle_id != info.vehicle:
				world.player.set_vehicle(info.vehicle)
		else:
			if not avatars.has(id):
				var avatar := Player.new()
				avatar.remote_controlled = true
				world.add_child(avatar)
				avatar.set_physics_process(false)
				avatar.collision_layer = 0
				avatar.collision_mask = 0
				avatars[id] = avatar
			var avatar: Node3D = avatars[id]
			_present(avatar, info.position, Vector3(0, info.yaw, 0))
			if avatar.vehicle_id != info.vehicle:
				avatar.set_vehicle(info.vehicle)
	for id in avatars.keys():
		if not snapshot.players.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
	var seen: Dictionary = {}
	for info in snapshot.entities:
		var id: int = info.id
		seen[id] = true
		if not replicas.has(id):
			var entity: Node3D
			match info.kind:
				"animal":
					entity = Animal.new()
					entity.animal_id = info.species
					entity.definition = world.state.animal(info.species)
					entity.rare = info.rare
					entity.inner_radius = 0
					entity.outer_radius = 110
				"loot":
					entity = Loot.new()
					entity.animal_id = info.species
					entity.rare = info.rare
				"arrow": entity = Arrow.new()
				_: continue
			entity.position = info.position
			world.add_child(entity)
			entity.set_physics_process(false)
			replicas[id] = entity
		var entity: Node3D = replicas[id]
		_present(entity, info.position, info.rotation)
		if info.kind == "animal":
			entity.health = info.health
			entity.attack_windup = info.windup
	for id in replicas.keys():
		if not seen.has(id):
			var entity: Node = replicas[id]
			for group in ["hunt_animals", "hunt_loot"]:
				if entity.is_in_group(group): entity.remove_from_group(group)
			entity.queue_free()
			replicas.erase(id)

func _exit_tree() -> void:
	if active:
		# World owns save flushing; do not rebuild entities during scene teardown.
		active = false
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		var steam := get_node_or_null("/root/SteamService")
		if steam != null:
			steam.leave_lobby()
