extends Node3D
## Local authority for the first expedition; gameplay rules never depend on nodes or Steam.

const IslandBounds := preload("res://scripts/core/island_bounds.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const HuntState := preload("res://scripts/core/hunt_state.gd")
const SaveStore := preload("res://scripts/core/save_store.gd")
const SpawnRules := preload("res://scripts/core/spawn_rules.gd")
const Text := preload("res://scripts/core/game_text.gd")
const Animal := preload("res://scripts/hunting/animal.gd")
const Arrow := preload("res://scripts/hunting/arrow.gd")
const Loot := preload("res://scripts/hunting/loot_drop.gd")
const KnifeView := preload("res://scripts/hunting/knife_view.gd")
const BowView := preload("res://scripts/hunting/bow_view.gd")
const HuntAudio := preload("res://scripts/hunting/hunt_audio.gd")
const CampScenery := preload("res://scripts/world/camp_scenery.gd")
const WorldAtmosphere := preload("res://scripts/world/world_atmosphere.gd")
const CoopSession := preload("res://scripts/world/coop_session.gd")
var coop: Node

const PLATEAU_RADIUS := 60.0
const OUTER_RADIUS := 90.0
const KILL_HEIGHT := -40.0
const SPAWN_POINT := Vector3(0.0, 25.5, 3.0)
const TRADER_POINT := Vector3(0.0, 24.0, -4.0)
const TRADER_RANGE := 4.5
const LOOT_RANGE := 3.0
const SPAWN_PAUSE_LOOT_COUNT := 48

var bounds: RefCounted
var player: CharacterBody3D
var state := HuntState.new()
var shop_open := false
var status_message := ""
var status_revision := 0
var cooldown_ratio := 0.0
var autosave_ok := true
var health := 100.0
var hurt_flash := 0.0
var hit_marker := 0.0
var target: Node3D
var _hurt_cooldown := 0.0
var _since_hurt := 100.0
var _knife: Node3D
var _knife_selected := false
var threat_text := ""
## Automated playtests opt out before entering the tree to preserve the player's save.
var persistence_enabled := true
var save_path: String = SaveStore.DEFAULT_PATH
var wildlife_enabled := true

var _spawns: RefCounted
var _cooldown := 0.0
var _spawn_clock := 0.0
var _notice_time := 0.0
var _save_clock := -1.0
var _hint_clock := 0.0
var _interaction_hint := ""
var _camera: Camera3D
var _bow: Node3D
var _audio: Node


func _ready() -> void:
	InputSetup.ensure_actions()
	process_physics_priority = 1 # Resolve the player's current look before firing.
	if persistence_enabled:
		SaveStore.load_state(state, save_path)
		# Convert legacy carried loot into coins once, preserving existing progress.
		if not state.inventory.is_empty():
			state.sell_all()
			_save_clock = 0.4
	state.changed.connect(_schedule_save)
	bounds = IslandBounds.new(PLATEAU_RADIUS, OUTER_RADIUS, KILL_HEIGHT, SPAWN_POINT)
	add_child(IslandBuilder.build())
	add_child(CampScenery.build())
	_add_lighting()
	player = PlayerScript.new()
	player.name = "Player"
	player.bounds = bounds
	player.position = SPAWN_POINT
	add_child(player)
	player.respawned.connect(_on_respawned)
	_camera = player.get_node("Head/Camera") as Camera3D
	_bow = BowView.new()
	_camera.add_child(_bow)
	_knife = KnifeView.new()
	_camera.add_child(_knife)
	_audio = HuntAudio.new()
	add_child(_audio)
	_spawns = SpawnRules.new(int(Time.get_unix_time_from_system()))
	if wildlife_enabled:
		for index in int(state.catalog["spawn"]["count"]):
			_spawn_animal(index == 0, "ant" if index < 8 else str(state.catalog["animals"].keys()[(index - 8) % state.catalog["animals"].size()]))
	get_tree().auto_accept_quit = false
	coop = CoopSession.new()
	coop.name = "Coop"
	coop.world = self
	add_child(coop)


func _physics_process(delta: float) -> void:
	_update_combat_feedback(delta)
	if not coop.is_guest():
		_update_survival(delta)
		_collect_nearby_coins()
	else:
		_update_target()
	_cooldown = maxf(0.0, _cooldown - delta)
	var active_tool: Dictionary = state.catalog["tools"]["knife"] if using_knife() else state.tool()
	cooldown_ratio = _cooldown / maxf(0.1, float(active_tool["reload"]) * (1.0 if using_knife() else state.gear_effect("reload", 1.0)))
	player.speed_multiplier = state.gear_effect("speed", 1.0)
	player.jump_multiplier = state.gear_effect("jump", 1.0)
	if Input.is_action_just_pressed(InputSetup.SHOOT) and not shop_open and player.controls_enabled:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Input.get_connected_joypads().is_empty():
			attack()
	var melee: bool = using_knife()
	player.guarding = melee and not shop_open and player.stamina > 8 and Input.is_action_pressed(InputSetup.AIM)
	var aiming := not melee and Input.is_action_pressed(InputSetup.AIM) and not shop_open
	_bow.visible = not melee and not shop_open and not player.third_person
	_knife.visible = melee and not shop_open and not player.third_person
	_knife.reload_ratio = cooldown_ratio
	_knife.guarding = player.guarding
	_knife.moving = Vector2(player.velocity.x, player.velocity.z).length() / 5.0
	_camera.fov = move_toward(_camera.fov, 57.0 if aiming else 75.0, delta * 75.0)
	_bow.reload_ratio = cooldown_ratio
	_bow.moving = Vector2(player.velocity.x, player.velocity.z).length() / 5.0
	_bow.tier = clampi(state.catalog["tools"].keys().find(state.tool_id) - 1, 0, 2)


func _process(delta: float) -> void:
	if shop_open and not _near_trader():
		_close_shop()
	_hint_clock -= delta
	if _hint_clock <= 0.0:
		_hint_clock = 0.1
		_interaction_hint = _build_interaction_text()
	_notice_time = maxf(0.0, _notice_time - delta)
	if _notice_time == 0.0:
		status_message = ""
	if _save_clock >= 0.0:
		_save_clock -= delta
		if _save_clock <= 0.0:
			_save_now()
	if not wildlife_enabled:
		return
	_spawn_clock -= delta
	if _spawn_clock <= 0.0:
		_spawn_clock = float(state.catalog["spawn"]["respawn_seconds"])
		if get_tree().get_nodes_in_group("hunt_animals").size() < int(state.catalog["spawn"]["count"]):
			if get_tree().get_nodes_in_group("hunt_loot").size() < SPAWN_PAUSE_LOOT_COUNT:
				_spawn_animal()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not player.controls_enabled and not shop_open:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_V and not shop_open:
		if coop.is_guest():
			coop.request("vehicle")
			return
		var choices: Array[String] = [""]
		for id in state.owned_gear:
			if state.catalog["gear"][id].get("vehicle", false):
				choices.append(id)
		var selected: String = choices[(choices.find(player.vehicle_id) + 1) % choices.size()]
		player.set_vehicle(selected, 0.0 if selected.is_empty() else float(state.catalog["gear"][selected]["multiplier"]))
		status_message = "On foot" if selected.is_empty() else Text.get_text("gear." + selected) + " / V change / WASD move / Space rise / Ctrl descend"
		status_revision += 1
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_C and not shop_open:
		player.toggle_camera()
	elif event is InputEventMouseButton and event.pressed and not shop_open:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_cooldown = maxf(_cooldown, 0.2)
	elif event.is_action_pressed(InputSetup.INTERACT):
		interact()
	elif event.is_action_pressed(InputSetup.SWAP) and not shop_open:
		if coop.is_guest():
			coop.request("swap")
			return
		_knife_selected = not _knife_selected
	elif event.is_action_pressed(InputSetup.UPGRADE):
		buy_upgrade()


func using_knife() -> bool:
	return state.tool_id == "knife" or _knife_selected


func attack() -> bool:
	if coop.is_guest():
		return coop.request("attack")
	if not player.vehicle_id.is_empty():
		return false
	if not using_knife():
		return fire_arrow()
	if _cooldown > 0 or shop_open:
		return false
	if player.stamina < 12:
		_notice("notice.exhausted")
		return false
	player.stamina -= 12
	var knife: Dictionary = state.catalog["tools"]["knife"]
	_cooldown = float(knife["reload"])
	_audio.play_cue("shoot")
	# A short forgiving arc, but every hit must have an unobstructed physical ray.
	var closest: Node3D = null
	var best := float(state.catalog["tools"]["knife"]["range"])
	for animal in get_tree().get_nodes_in_group("hunt_animals"):
		if animal.is_queued_for_deletion():
			continue
		var aim: Vector3 = animal.global_position + Vector3.UP * animal._body_radius
		var offset: Vector3 = aim - player.get_node("Head").global_position
		if offset.length() > best or (-_camera.global_basis.z).dot(offset.normalized()) < 0.72:
			continue
		var ray := PhysicsRayQueryParameters3D.create(player.get_node("Head").global_position, aim)
		ray.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit["collider"] == animal:
			closest = animal
			best = offset.length()
	if closest != null:
		closest.take_hit(float(knife["damage"]), closest.global_position + Vector3.UP * closest._body_radius, _camera.global_position)
		hit_marker = 0.18
	return true


func _update_survival(delta: float) -> void:
	_hurt_cooldown = maxf(0, _hurt_cooldown - delta)
	_since_hurt += delta
	var safe := Vector2(player.position.x, player.position.z).length() < 14
	if safe:
		health = minf(100, health + delta * 14)
	elif _since_hurt > 12:
		health = minf(100, health + delta * 2)
	_update_target()


func _update_target() -> void:
	var ray := PhysicsRayQueryParameters3D.create(_camera.global_position, _camera.global_position - _camera.global_basis.z * 65)
	ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	target = hit.get("collider") as Node3D if not hit.is_empty() else null
	if target != null and not target.is_in_group("hunt_animals"):
		target = null


func _update_combat_feedback(delta: float) -> void:
	# Presentation uses replicated windups too; guest health remains host-owned.
	hurt_flash = maxf(0, hurt_flash - delta * 1.8)
	hit_marker = maxf(0, hit_marker - delta)
	threat_text = ""
	for animal in get_tree().get_nodes_in_group("hunt_animals"):
		if not animal.is_queued_for_deletion() and animal.attack_windup > 0 and animal.position.distance_to(player.position) < 4:
			threat_text = Text.get_text("notice.predator_windup", [Text.get_text(animal.definition["name_key"])])
			break


func present_coop_feedback(kind: String, amount: int) -> void:
	match kind:
		"shoot": _audio.play_cue("shoot")
		"hit":
			hit_marker = 0.22
			_audio.play_cue("hit")
		"hurt":
			hurt_flash = 0.65
			_notice("notice.hurt")
		"defeated":
			hurt_flash = 0.65
			_notice("notice.defeated", [amount])


func take_player_damage(amount: float, from: Vector3) -> void:
	if coop.is_guest():
		return
	if amount <= 0 or shop_open or _hurt_cooldown > 0 or Vector2(player.position.x, player.position.z).length() < 14:
		return
	var forward := -player.global_basis.z
	var toward := from - player.global_position
	toward.y = 0
	if player.guarding and player.stamina >= 18 and forward.dot(toward.normalized()) > 0.1:
		amount *= 0.25
		player.stamina -= 18
	health = maxf(0, health - amount)
	_since_hurt = 0
	_hurt_cooldown = 0.7
	hurt_flash = 0.65
	if health <= 0:
		var lost := state.defeat_penalty()
		player.respawn()
		_notice("notice.defeated", [lost])
	else:
		_notice("notice.hurt")


func fire_arrow() -> bool:
	if coop.is_guest():
		return coop.request("attack")
	if _cooldown > 0.0 or shop_open or using_knife():
		return false
	var arrow := Arrow.new()
	var eye: Vector3 = player.get_node("Head").global_position
	var aim_point := _camera.global_position - _camera.global_basis.z * 200.0
	var query := PhysicsRayQueryParameters3D.create(_camera.global_position, aim_point)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim_point = hit.position
	arrow.direction = (aim_point - eye).normalized()
	arrow.speed = float(state.tool()["speed"])
	arrow.damage = float(state.tool()["damage"])
	arrow.shooter = player
	arrow.shot_origin = eye
	add_child(arrow)
	# Sweep from the eye, ignoring our own body: close thin cover must also stop arrows.
	arrow.global_position = eye
	_cooldown = float(state.tool()["reload"]) * state.gear_effect("reload", 1.0)
	_audio.play_cue("shoot")
	return true


func interact() -> void:
	if shop_open:
		if not _near_trader():
			_close_shop()
		return
	if _near_trader():
		if coop.is_guest():
			coop.request("shop")
		shop_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.controls_enabled = false
		player.velocity.x = 0.0
		player.velocity.z = 0.0


func _collect_nearby_coins() -> void:
	for coin in get_tree().get_nodes_in_group("hunt_loot"):
		if coin.is_queued_for_deletion() or player.global_position.distance_to(coin.global_position) > state.gear_effect("pickup", 2.2):
			continue
		var paid: int = state.collect_coins(coin.animal_id, coin.rare, coin.trick_shot)
		coin.remove_from_group("hunt_loot")
		coin.queue_free()
		_notice("notice.coins", [paid])
		_audio.play_cue("collect")


func buy_upgrade() -> bool:
	return buy_item(str(state.tool().get("next", "")))


func buy_item(id: String) -> bool:
	if not shop_open or not _near_trader():
		return false
	if coop.is_guest():
		return coop.request("buy", id)
	if state.catalog.get("gear", {}).has(id):
		if not state.buy_gear(id):
			return false
		_notice("notice.purchased", [Text.get_text(state.catalog["gear"][id]["name_key"])])
		_audio.play_cue("upgrade")
		return true
	var next: Dictionary = state.catalog["tools"].get(id, {})
	if next.is_empty():
		_notice("notice.max_tool")
		return false
	if not state.buy_tool(id):
		_notice("notice.need_coins", [int(next["price"]) - state.coins])
		return false
	_knife_selected = false
	_notice("notice.upgraded", [Text.get_text(state.tool()["name_key"])])
	_audio.play_cue("upgrade")
	return true


func interaction_text() -> String:
	return "" if shop_open else _interaction_hint


func _build_interaction_text() -> String:
	if shop_open:
		return ""
	if _near_trader():
		return Text.get_text("prompt.trader")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Input.get_connected_joypads().is_empty():
		return Text.get_text("prompt.capture")
	return ""


func _spawn_animal(first: bool = false, species: String = "") -> void:
	var spawn: Dictionary = _spawns.next_spawn()
	var animal := Animal.new()
	animal.animal_id = "ant" if first else (species if not species.is_empty() else str(spawn["animal_id"]))
	animal.definition = state.animal(animal.animal_id)
	animal.inner_radius = float(state.catalog["spawn"]["inner_radius"])
	animal.outer_radius = float(state.catalog["spawn"]["outer_radius"])
	animal.rare = bool(spawn["rare"]) and not first
	animal.player = player
	animal.position = Vector3(0, 0, 17) if first else spawn["position"]
	if animal.animal_id == "ant":
		animal.inner_radius = 15
		animal.outer_radius = 27
		if not first:
			animal.position = Vector3(_spawns.rng.randf_range(-8, 8), 0, _spawns.rng.randf_range(17, 23))
	elif animal.definition.get("behavior", "") == "hostile":
		animal.inner_radius = 36
	animal.position.y = IslandBuilder.ground_height_at(Vector2(animal.position.x, animal.position.z).length()) + 0.2
	animal.home = animal.position
	animal.defeated.connect(_on_animal_defeated)
	animal.attacked.connect(_on_animal_attack.bind(animal))
	add_child(animal)


func _on_animal_defeated(animal_id: String, rare: bool, trick_shot: bool, at: Vector3) -> void:
	hit_marker = 0.22
	var old_xp: int = state.xp
	if coop != null and coop.active and coop.hosting:
		coop.ledger.record_hunt(animal_id, rare, trick_shot)
	else:
		state.record_hunt(animal_id, rare, trick_shot)
	_notice("notice.hunt", [Text.get_text(state.animal(animal_id)["name_key"]), state.xp - old_xp])
	_audio.play_cue("hit")
	var loot := Loot.new()
	loot.animal_id = animal_id
	loot.rare = rare
	loot.trick_shot = trick_shot
	loot.position = Vector3(at.x, IslandBuilder.ground_height_at(Vector2(at.x, at.z).length()) + 0.15, at.z)
	add_child(loot)


func _nearest_loot() -> Area3D:
	if not is_instance_valid(player):
		return null
	var closest: Area3D = null
	var distance := LOOT_RANGE
	for node in get_tree().get_nodes_in_group("hunt_loot"):
		var loot := node as Area3D
		if loot == null or loot.is_queued_for_deletion():
			continue
		var current := player.global_position.distance_to(loot.global_position)
		if current < distance:
			distance = current
			closest = loot
	return closest


func _near_trader() -> bool:
	return is_instance_valid(player) and player.global_position.distance_to(TRADER_POINT) < TRADER_RANGE


func _on_respawned() -> void:
	health = 100
	player.stamina = 100
	_hurt_cooldown = 3.0
	_close_shop()
	_notice("notice.respawn")


func _close_shop() -> void:
	if coop != null and coop.is_guest():
		coop.request("close_shop")
	shop_open = false
	player.controls_enabled = true
	_cooldown = maxf(_cooldown, 0.2)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notice(key: String, args: Array = []) -> void:
	status_message = Text.get_text(key, args)
	status_revision += 1
	_notice_time = 4.5


func _schedule_save() -> void:
	if persistence_enabled:
		_save_clock = 0.4


func _save_now() -> void:
	_save_clock = -1.0
	if persistence_enabled:
		autosave_ok = SaveStore.save_state(state, save_path)
		if not autosave_ok:
			_notice("notice.save_failed")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
		get_tree().quit()


func _exit_tree() -> void:
	if _save_clock >= 0.0:
		_save_now()


func _add_lighting() -> void:
	add_child(WorldAtmosphere.build())


func _on_animal_attack(amount: float, from: Vector3, animal: Node3D) -> void:
	if coop != null and coop.active and coop.hosting and animal.player != player:
		coop.damage_hunter(animal.player, amount, from)
	else:
		take_player_damage(amount, from)
