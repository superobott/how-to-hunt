extends SceneTree
## Headless physics smoke test. Loads the real main scene and plays it through input actions.
## Usage: godot --headless --fixed-fps 60 --path . -s tests/smoke_world.gd
## (--fixed-fps makes every frame exactly 1/60 s, so the run is deterministic and fast.)
## Exits 1 if any check fails or the scene does not load.

const IslandBuilder := preload("res://scripts/world/island_builder.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const Motion := preload("res://scripts/core/player_motion.gd")

var _failures: Array[String] = []
var _checks := 0
var _respawns := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	# During _initialize the tree is not running yet, so _ready only fires after the first frame.
	await process_frame
	var player: CharacterBody3D = world.get("player")
	if player == null:
		_fail("world has no player")
		_finish()
		return
	player.respawned.connect(func() -> void: _respawns += 1)

	await _check_spawn_and_landing(player)
	await _check_walking(player)
	await _check_jump(player)
	await _check_climb_to_first_tier(player)
	await _check_turn_away_mid_climb(player, PI / 2.0, "a quarter turn")
	await _check_turn_away_mid_climb(player, PI, "a half turn")
	await _check_no_hop_without_a_ledge(world, player)
	await _check_outer_clamp(player)
	await _check_fall_and_respawn(world, player)
	_finish()


func _check_spawn_and_landing(player: CharacterBody3D) -> void:
	await _frames(45)
	_expect(player.is_on_floor(), "player lands on the plateau after spawning")
	_expect_near(player.global_position.y, 0.0, 0.1, "player stands at plateau height")


func _check_walking(player: CharacterBody3D) -> void:
	var start := player.global_position
	await _hold(InputSetup.MOVE_FORWARD, 30)
	var moved := start.distance_to(player.global_position)
	_expect(moved > 1.5, "walking forward moves the player (moved %.2f m)" % moved)
	_expect(player.global_position.z < start.z, "forward is toward the mountain (negative z)")
	await _frames(30) # let the player stop
	_expect(player.velocity.length() < 0.5, "player stops when input is released")


func _check_jump(player: CharacterBody3D) -> void:
	await _frames(10)
	var floor_y := player.global_position.y
	var peak := floor_y
	Input.action_press(InputSetup.JUMP)
	for i in 70:
		await physics_frame
		if i == 0:
			Input.action_release(InputSetup.JUMP)
		peak = maxf(peak, player.global_position.y)
	var height := peak - floor_y
	_expect(height > 1.0 and height < 1.6, "jump rises about 1.3 m (rose %.2f m)" % height)
	_expect(player.is_on_floor(), "player lands after the jump")


func _check_climb_to_first_tier(player: CharacterBody3D) -> void:
	# Stand in front of the first cliff, facing it, and walk into it.
	player.global_position = Vector3(0.0, 0.2, 46.0)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	await _frames(5)
	var top: float = IslandBuilder.TIERS[1]["top"]
	var saw_climbing := false
	Input.action_press(InputSetup.MOVE_FORWARD)
	for i in 600:
		await physics_frame
		saw_climbing = saw_climbing or player.climbing
		if player.is_on_floor() and player.global_position.y > top - 0.3:
			break
	Input.action_release(InputSetup.MOVE_FORWARD)
	await _frames(30)
	_expect(saw_climbing, "walking into the cliff starts a climb")
	_expect_near(player.global_position.y, top, 0.3, "player ends up standing on the first tier")
	var radius := Vector2(player.global_position.x, player.global_position.z).length()
	var tier_radius: float = IslandBuilder.TIERS[1]["radius"]
	_expect(radius < tier_radius, "player is on top of the tier, not outside it (r=%.1f)" % radius)


## Turning away from the cliff mid-climb must not read as "reached the top". Wall contact has to
## stay tied to the wall, not to where the camera points, otherwise the player is flung sideways
## at mid-height by the ledge hop. The climb must end at the ledge, 7 m up, not where the turn happened.
func _check_turn_away_mid_climb(player: CharacterBody3D, turn: float, label: String) -> void:
	player.global_position = Vector3(0.0, 0.2, 46.0)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	await _frames(5)
	var top: float = IslandBuilder.TIERS[1]["top"]
	var turned := false
	var climb_ended := false
	var climb_end_y := 0.0
	var max_flat_speed := 0.0
	Input.action_press(InputSetup.MOVE_FORWARD)
	for i in 600:
		await physics_frame
		if not turned:
			if player.climbing and player.global_position.y > 2.5:
				player.yaw += turn
				turned = true
			continue
		if not climb_ended:
			if player.climbing:
				var flat := Vector2(player.velocity.x, player.velocity.z).length()
				max_flat_speed = maxf(max_flat_speed, flat)
			else:
				climb_ended = true
				climb_end_y = player.global_position.y
				# Face the tier again, as a player would after the hop, so they walk onto it.
				player.yaw -= turn
		elif player.is_on_floor() and player.global_position.y > top - 0.3:
			break
	Input.action_release(InputSetup.MOVE_FORWARD)
	await _frames(30)
	_expect(turned, "reached mid-climb before turning (%s)" % label)
	_expect(climb_ended and climb_end_y > top - 0.6,
			"climb ends at the ledge, not mid-wall, after %s (ended at y=%.2f)" % [label, climb_end_y])
	_expect(max_flat_speed < 0.5,
			"no sideways drift while climbing after %s (peak %.2f m/s)" % [label, max_flat_speed])
	_expect_near(player.global_position.y, top, 0.3, "player ends up on the first tier after %s" % label)


## A wall that ends with nothing behind it (here a thin free-standing fence) is not a ledge.
## Losing the wall at the top must let go, not fire the hop that carries a player over an edge.
func _check_no_hop_without_a_ledge(world: Node, player: CharacterBody3D) -> void:
	var fence := StaticBody3D.new()
	fence.add_to_group(IslandBuilder.CLIMBABLE_GROUP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.1)
	shape.shape = box
	fence.add_child(shape)
	world.add_child(fence)
	fence.global_position = Vector3(0.0, 2.0, 52.0) # on the plateau, outside the first tier
	player.global_position = Vector3(0.0, 0.2, 52.7)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	await _frames(5)
	var saw_climbing := false
	var climb_ended := false
	var end_y := 0.0
	var end_velocity := Vector3.ZERO
	Input.action_press(InputSetup.MOVE_FORWARD)
	for i in 400:
		await physics_frame
		saw_climbing = saw_climbing or player.climbing
		if saw_climbing and not player.climbing:
			climb_ended = true
			end_y = player.global_position.y
			end_velocity = player.velocity
			break
	Input.action_release(InputSetup.MOVE_FORWARD)
	fence.queue_free()
	await _frames(60)
	_expect(saw_climbing, "player grabs the free-standing fence")
	_expect(climb_ended and end_y > 3.0, "player reaches the top of the fence (ended at y=%.2f)" % end_y)
	# Letting go keeps at most the leftover climb speed (minus one gravity step). The ledge hop would
	# add MANTLE_UP_SPEED and a forward push on top of that.
	var flat := Vector2(end_velocity.x, end_velocity.z).length()
	_expect(end_velocity.y <= Motion.CLIMB_SPEED and flat < 1.0,
			"no ledge hop over a wall with nothing behind it (vy %.2f, flat %.2f m/s)" % [end_velocity.y, flat])


func _check_outer_clamp(player: CharacterBody3D) -> void:
	player.global_position = Vector3(500.0, 5.0, 0.0)
	await _frames(2)
	var radius := Vector2(player.global_position.x, player.global_position.z).length()
	_expect(radius <= 90.01, "far-away player is pulled back inside the outer radius (r=%.1f)" % radius)


func _check_fall_and_respawn(world: Node, player: CharacterBody3D) -> void:
	var before := _respawns
	# Stand near the cliff edge facing outward, then walk off it.
	player.global_position = Vector3(0.0, 0.2, 57.0)
	player.velocity = Vector3.ZERO
	player.yaw = PI
	await _frames(5)
	Input.action_press(InputSetup.MOVE_FORWARD)
	var fell_below_plateau := false
	for i in 900:
		await physics_frame
		fell_below_plateau = fell_below_plateau or player.global_position.y < -5.0
		if _respawns > before:
			break
	Input.action_release(InputSetup.MOVE_FORWARD)
	_expect(fell_below_plateau, "walking off the cliff edge makes the player fall")
	_expect(_respawns == before + 1, "falling past the kill height respawns the player")
	await _frames(45)
	var spawn: Vector3 = world.get("SPAWN_POINT")
	var flat_distance := Vector2(
		player.global_position.x - spawn.x, player.global_position.z - spawn.z
	).length()
	_expect(flat_distance < 1.0, "player is back at the spawn point (off by %.2f m)" % flat_distance)
	_expect(player.is_on_floor(), "player is standing again after respawning")


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS  %s" % message)
	else:
		_fail(message)


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (got %.2f, want %.2f)" % [message, actual, expected])


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL  %s" % message)


func _finish() -> void:
	print("\nsmoke: %d checks, %d failed" % [_checks, _failures.size()])
	quit(1 if (_failures.size() > 0 or _checks == 0) else 0)
