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
const BowView := preload("res://scripts/hunting/bow_view.gd")
const HuntAudio := preload("res://scripts/hunting/hunt_audio.gd")
const CampScenery := preload("res://scripts/world/camp_scenery.gd")

const PLATEAU_RADIUS := 60.0
const OUTER_RADIUS := 90.0
const KILL_HEIGHT := -40.0
const SPAWN_POINT := Vector3(0.0, 1.5, 52.0)
const TRADER_POINT := Vector3(8.0, 0.0, 50.0)
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
## Automated playtests opt out before entering the tree to preserve the player's save.
var persistence_enabled := true
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
		SaveStore.load_state(state)
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
	_audio = HuntAudio.new()
	add_child(_audio)
	_spawns = SpawnRules.new(int(Time.get_unix_time_from_system()))
	if wildlife_enabled:
		for index in int(state.catalog["spawn"]["count"]):
			_spawn_animal(index == 0)
	get_tree().auto_accept_quit = false


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	cooldown_ratio = _cooldown / maxf(0.1, float(state.tool()["reload"]))
	if Input.is_action_just_pressed(InputSetup.SHOOT) and not shop_open:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Input.get_connected_joypads().is_empty():
			fire_arrow()
	var aiming := Input.is_action_pressed(InputSetup.AIM) and not shop_open
	_camera.fov = move_toward(_camera.fov, 57.0 if aiming else 75.0, delta * 75.0)
	_bow.reload_ratio = cooldown_ratio
	_bow.moving = Vector2(player.velocity.x, player.velocity.z).length() / 5.0
	_bow.tier = ["starter_bow", "hunters_bow", "mountain_bow"].find(state.tool_id)


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
	if event.is_action_pressed("ui_cancel"):
		_close_shop()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not shop_open:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_cooldown = maxf(_cooldown, 0.2)
	elif event.is_action_pressed(InputSetup.INTERACT):
		interact()
	elif event.is_action_pressed(InputSetup.UPGRADE):
		buy_upgrade()


func fire_arrow() -> bool:
	if _cooldown > 0.0 or shop_open:
		return false
	var arrow := Arrow.new()
	arrow.direction = -_camera.global_basis.z
	arrow.speed = float(state.tool()["speed"])
	arrow.damage = float(state.tool()["damage"])
	arrow.shooter = player
	arrow.shot_origin = _camera.global_position
	add_child(arrow)
	# Sweep from the eye, ignoring our own body: close thin cover must also stop arrows.
	arrow.global_position = _camera.global_position
	_cooldown = float(state.tool()["reload"])
	_audio.play_cue("shoot")
	return true


func interact() -> void:
	if shop_open:
		if not _near_trader():
			_close_shop()
			return
		var paid: int = state.sell_all()
		_notice("notice.sold" if paid > 0 else "notice.no_loot", [paid])
		if paid > 0:
			_audio.play_cue("sell")
		return
	var loot := _nearest_loot()
	if loot != null:
		if not state.collect_loot(loot.animal_id, loot.rare, loot.trick_shot):
			_notice("notice.bag_full")
			return
		var info: Dictionary = state.animal(loot.animal_id)
		var value := float(info["value"]) * (float(info["rare_multiplier"]) if loot.rare else 1.0)
		if loot.trick_shot:
			value *= float(state.catalog["economy"]["trick_multiplier"])
		_notice("notice.collected", [Text.get_text(info["name_key"]), roundi(value)])
		loot.remove_from_group("hunt_loot")
		loot.queue_free()
		_audio.play_cue("collect")
	elif _near_trader():
		shop_open = true
		player.controls_enabled = false
		player.velocity.x = 0.0
		player.velocity.z = 0.0


func buy_upgrade() -> bool:
	if not shop_open or not _near_trader():
		return false
	var next: Dictionary = state.next_tool()
	if next.is_empty():
		_notice("notice.max_tool")
		return false
	if not state.buy_upgrade():
		_notice("notice.need_coins", [int(next["price"]) - state.coins])
		return false
	_notice("notice.upgraded", [Text.get_text(state.tool()["name_key"])])
	_audio.play_cue("upgrade")
	return true


func interaction_text() -> String:
	return "" if shop_open else _interaction_hint


func _build_interaction_text() -> String:
	if shop_open:
		return ""
	var loot := _nearest_loot()
	if loot != null:
		return Text.get_text("prompt.collect", [Text.get_text(state.animal(loot.animal_id)["name_key"])])
	if _near_trader():
		return Text.get_text("prompt.trader")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Input.get_connected_joypads().is_empty():
		return Text.get_text("prompt.capture")
	return ""


func _spawn_animal(first: bool = false) -> void:
	var spawn: Dictionary = _spawns.next_spawn()
	var animal := Animal.new()
	animal.animal_id = "rabbit" if first else str(spawn["animal_id"])
	animal.definition = state.animal(animal.animal_id)
	animal.inner_radius = float(state.catalog["spawn"]["inner_radius"])
	animal.outer_radius = float(state.catalog["spawn"]["outer_radius"])
	animal.rare = bool(spawn["rare"]) and not first
	animal.player = player
	animal.position = Vector3(-4.0, 0.15, 45.5) if first else spawn["position"]
	animal.home = animal.position
	animal.defeated.connect(_on_animal_defeated)
	add_child(animal)


func _on_animal_defeated(animal_id: String, rare: bool, trick_shot: bool, at: Vector3) -> void:
	var old_xp: int = state.xp
	state.record_hunt(animal_id, rare, trick_shot)
	_notice("notice.hunt", [Text.get_text(state.animal(animal_id)["name_key"]), state.xp - old_xp])
	_audio.play_cue("hit")
	var loot := Loot.new()
	loot.animal_id = animal_id
	loot.rare = rare
	loot.trick_shot = trick_shot
	loot.position = Vector3(at.x, 0.15, at.z)
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
	_close_shop()
	_notice("notice.respawn")


func _close_shop() -> void:
	shop_open = false
	player.controls_enabled = true


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
		autosave_ok = SaveStore.save_state(state)
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
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	sun.light_color = Color("ffe6ba")
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4198b0")
	sky_material.sky_horizon_color = Color("e6eed0")
	sky_material.ground_horizon_color = Color("d4e2be")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
