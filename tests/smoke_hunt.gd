extends SceneTree
## Plays the real hunt, pickup, trader, upgrade, and save loop through world actions.
## Run: godot --headless --fixed-fps 60 --path . -s tests/smoke_hunt.gd

const Animal := preload("res://scripts/hunting/animal.gd")
const Arrow := preload("res://scripts/hunting/arrow.gd")
const HuntState := preload("res://scripts/core/hunt_state.gd")
const SaveStore := preload("res://scripts/core/save_store.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const SAVE_PATH := "user://test_smoke_hunt.json"
const FIRING_POSITION := Vector3(0.0, 0.1, 52.0)
const TARGET_POSITION := Vector3(0.0, 0.1, 47.0)

var _failures: Array[String] = []
var _checks: int = 0
var _finished: bool = false
var _watchdog: Timer


func _initialize() -> void:
	_run()


func _run() -> void:
	# A scene-owned Timer is explicitly stopped at completion. A pending
	# SceneTreeTimer can otherwise survive this short test's early tree shutdown.
	_watchdog = Timer.new()
	_watchdog.wait_time = 30.0
	_watchdog.one_shot = true
	_watchdog.autostart = true
	_watchdog.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_watchdog.timeout.connect(_on_timeout)
	root.add_child(_watchdog)
	_cleanup_save()
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("main scene loads")
		_finish()
		return
	var world := scene.instantiate() as Node3D
	world.set("persistence_enabled", false)
	world.set("wildlife_enabled", false)
	root.add_child(world)
	await process_frame
	# Stop timed wildlife generation while retaining world physics and real cooldowns.
	world.set_process(false)
	for animal in get_nodes_in_group("hunt_animals"):
		animal.queue_free()
	await _frames(3)
	var player := world.get("player") as CharacterBody3D
	var camera: Camera3D = null
	if player != null:
		camera = player.get_node_or_null("Head/Camera") as Camera3D
	var state: HuntState = world.get("state")
	if player == null or camera == null or state == null:
		_fail("world provides the player, camera, and hunting state")
		_finish()
		return
	await _check_wall_and_reload(world, player, camera, state)
	await _check_close_cover(world, player, camera, state)
	await _check_same_frame_aim(world, player, camera, state)
	for index in range(4):
		var collected: bool = await _hunt_and_collect(world, player, camera, state, index + 1)
		if not collected:
			_finish()
			return
	_expect(state.hunts == 4, "four actual arrow hits award four hunts")
	_expect(state.xp == 80, "four body shots award XP once each")
	_expect(state.inventory.size() == 4, "four collected animals remain in the bag")
	_expect(state.coins == 0, "collected loot is not spendable before a sale")
	_check_save_roundtrip(state, "filled bag")
	await _check_trader_and_upgrade(world, player, state)
	_check_save_roundtrip(state, "purchased bow")
	_finish()


func _check_wall_and_reload(world: Node3D, player: CharacterBody3D, camera: Camera3D, state: HuntState) -> void:
	var rabbit := _spawn_rabbit(world, state)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.4)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0.0, 1.2, 49.5)
	world.add_child(wall)
	await _aim(player, camera, rabbit)
	_expect(bool(world.call("fire_arrow")), "a ready bow fires a physical arrow")
	_expect(not bool(world.call("fire_arrow")), "reload rejects a second immediate arrow")
	await _frames(65)
	_expect(is_instance_valid(rabbit) and is_equal_approx(rabbit.health, 20.0),
		"a solid wall stops the arrow before it damages wildlife")
	_expect(state.hunts == 0 and state.xp == 0 and get_nodes_in_group("hunt_loot").is_empty(),
		"blocked shots grant no rewards or loot")
	wall.queue_free()
	if is_instance_valid(rabbit):
		rabbit.queue_free()
	await _frames(3)


func _check_close_cover(world: Node3D, player: CharacterBody3D, camera: Camera3D, state: HuntState) -> void:
	var rabbit := _spawn_rabbit(world, state)
	await _aim(player, camera, rabbit)
	# Keep the eye fixed while placing cover closer than the player capsule's
	# radius. The arrow and physics collision queries continue running normally.
	player.set_physics_process(false)
	var forward := -camera.global_basis.z
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.05)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	wall.global_position = camera.global_position + forward * 0.25
	wall.global_basis = Basis.looking_at(forward, Vector3.UP)
	await _frames(3)
	_expect(absf(camera.global_position.distance_to(wall.global_position) - 0.25) < 0.001,
		"thin cover is placed only 0.25 m in front of the eye")
	_expect(bool(world.call("fire_arrow")), "a ready bow fires toward close cover")
	await _frames(65)
	_expect(is_instance_valid(rabbit) and is_equal_approx(rabbit.health, 20.0),
		"a thin wall inside the old muzzle offset blocks the physical arrow")
	_expect(state.hunts == 0 and state.xp == 0 and get_nodes_in_group("hunt_loot").is_empty(),
		"shooting through close cover grants no rewards")
	wall.queue_free()
	if is_instance_valid(rabbit):
		rabbit.queue_free()
	player.set_physics_process(true)
	await _frames(3)


func _check_same_frame_aim(world: Node3D, player: CharacterBody3D, camera: Camera3D, state: HuntState) -> void:
	player.global_position = FIRING_POSITION
	player.velocity = Vector3.ZERO
	player.set("yaw", 0.0)
	player.set("pitch", 0.0)
	var head := player.get_node("Head") as Node3D
	head.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	await _frames(4)
	var turn := PI / 3.0
	var expected := Vector3.FORWARD.rotated(Vector3.UP, turn)
	# No physics frame may pass between applying this mouse look and firing.
	player.call("_apply_look", Vector2(-turn, 0.0))
	_expect((-camera.global_basis.z).is_equal_approx(expected),
		"mouse look updates horizontal camera aim in the same frame")
	_expect(bool(world.call("fire_arrow")), "the bow fires immediately after the mouse turn")
	var arrow: Node3D = null
	for child in world.get_children():
		if child.get_script() == Arrow:
			arrow = child as Node3D
			break
	_expect(arrow != null, "same-frame turn creates a physical arrow")
	if arrow != null:
		var velocity: Vector3 = arrow.get("_velocity")
		_expect(velocity.is_equal_approx(expected * float(state.tool()["speed"])),
			"arrow trajectory uses the new mouse aim without a physics-frame delay")
		arrow.queue_free()
	player.call("_apply_look", Vector2(turn, 0.0))
	await _frames(65)
	_expect(state.hunts == 0 and state.xp == 0, "trajectory inspection cannot award a hunt")


func _hunt_and_collect(world: Node3D, player: CharacterBody3D, camera: Camera3D, state: HuntState, number: int) -> bool:
	var rabbit := _spawn_rabbit(world, state)
	await _aim(player, camera, rabbit)
	_expect(bool(world.call("fire_arrow")), "hunt %d fires after the previous reload" % number)
	await _frames(65)
	_expect(not is_instance_valid(rabbit), "hunt %d defeats the rabbit with an actual arrow" % number)
	_expect(state.hunts == number and state.xp == number * 20,
		"hunt %d awards one base hunt and its XP" % number)
	var drops := get_nodes_in_group("hunt_loot")
	_expect(drops.size() == 1, "hunt %d creates exactly one collectible drop" % number)
	if drops.size() != 1:
		return false
	var loot := drops[0] as Area3D
	player.global_position = loot.global_position + Vector3(0.0, 0.1, 1.0)
	player.velocity = Vector3.ZERO
	world.call("interact")
	_expect(state.inventory.size() == number, "hunt %d collects loot through interaction" % number)
	var before := state.snapshot()
	world.call("interact")
	_expect(state.snapshot() == before, "repeated pickup cannot duplicate the queued drop")
	await _frames(2)
	_expect(get_nodes_in_group("hunt_loot").is_empty(), "collected drop leaves the world")
	return true


func _check_trader_and_upgrade(world: Node3D, player: CharacterBody3D, state: HuntState) -> void:
	var trader: Vector3 = world.get("TRADER_POINT")
	player.global_position = trader + Vector3(0.0, 0.1, 2.0)
	player.velocity = Vector3.ZERO
	await _frames(5)
	_expect(not bool(world.call("buy_upgrade")), "upgrades require entering the trader")
	player.velocity = Vector3(8.0, player.velocity.y, 0.0)
	world.call("interact")
	_expect(bool(world.get("shop_open")), "interacting near camp opens the trader")
	_expect(not bool(player.get("controls_enabled")), "trader disables player movement controls")
	_expect(Vector2(player.velocity.x, player.velocity.z).is_zero_approx(),
		"opening the trader immediately stops existing sprint momentum")
	_expect(not bool(world.call("fire_arrow")), "the bow does not fire while trading")
	var start := player.global_position
	Input.action_press(InputSetup.MOVE_FORWARD)
	await _frames(30)
	Input.action_release(InputSetup.MOVE_FORWARD)
	var movement := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_expect(movement < 0.05, "movement input cannot move the player through the trader")
	var before_remote_sale := state.snapshot()
	player.global_position = FIRING_POSITION
	world.call("interact")
	_expect(not bool(world.get("shop_open")) and bool(player.get("controls_enabled")),
		"interacting outside trader range closes the shop and restores controls")
	_expect(state.snapshot() == before_remote_sale,
		"an out-of-range trader interaction cannot sell the inventory")
	player.global_position = trader + Vector3(0.0, 0.1, 2.0)
	player.velocity = Vector3.ZERO
	world.call("interact")
	_expect(bool(world.get("shop_open")), "returning to camp allows the trader to reopen")
	world.call("interact")
	_expect(state.inventory.is_empty() and state.coins == 48, "trader sells four rabbits for 48 coins")
	world.call("interact")
	_expect(state.coins == 48, "repeating an empty sale cannot duplicate money")
	var old_damage := float(state.tool()["damage"])
	_expect(bool(world.call("buy_upgrade")), "earned coins buy the first bow upgrade")
	_expect(state.tool_id == "hunters_bow" and float(state.tool()["damage"]) > old_damage,
		"the purchased bow increases real weapon damage")
	_expect(state.coins == 0, "buying the first upgrade deducts its full price")
	_expect(not bool(world.call("buy_upgrade")), "an unaffordable next upgrade is rejected")
	_expect(state.tool_id == "hunters_bow" and state.coins == 0,
		"a rejected purchase preserves the equipped bow and money")


func _spawn_rabbit(world: Node3D, state: HuntState) -> CharacterBody3D:
	var rabbit := Animal.new()
	rabbit.animal_id = "rabbit"
	rabbit.definition = state.animal("rabbit")
	rabbit.player = null
	rabbit.position = TARGET_POSITION
	rabbit.home = TARGET_POSITION
	rabbit.defeated.connect(Callable(world, "_on_animal_defeated"))
	world.add_child(rabbit)
	rabbit.set_physics_process(false)
	return rabbit


func _aim(player: CharacterBody3D, camera: Camera3D, rabbit: CharacterBody3D) -> void:
	player.global_position = FIRING_POSITION
	player.velocity = Vector3.ZERO
	player.set("yaw", 0.0)
	await _frames(4)
	camera.look_at(rabbit.global_position + Vector3.UP * 0.6, Vector3.UP)


func _check_save_roundtrip(state: HuntState, label: String) -> void:
	_expect(SaveStore.save_state(state, SAVE_PATH), "%s saves to an isolated test file" % label)
	var restored := HuntState.new()
	_expect(SaveStore.load_state(restored, SAVE_PATH), "%s loads from disk" % label)
	_expect(restored.snapshot() == state.snapshot(), "%s preserves money, XP, hunts, bow, and inventory" % label)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _cleanup_save() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS  %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL  %s" % message)


func _on_timeout() -> void:
	_fail("hunting playtest completes within 30 seconds of simulation")
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
		_watchdog.queue_free()
		_watchdog = null
	Input.action_release(InputSetup.MOVE_FORWARD)
	_cleanup_save()
	print("\nhunting smoke: %d checks, %d failed" % [_checks, _failures.size()])
	quit(1 if not _failures.is_empty() or _checks == 0 else 0)
