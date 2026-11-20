extends SceneTree
## Test the real continuous mountain collision, walking down and back up on four sides.
const InputSetup := preload("res://scripts/core/input_setup.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	world.persistence_enabled = false
	world.wildlife_enabled = false
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	await frames(60)
	expect(player.is_on_floor() and absf(player.position.y - 24) < 0.15, "spawn lands on summit")
	# Diagonal routes avoid the store and caves; each side must be walkable both ways.
	for index in 4:
		var angle := PI * 0.25 + index * PI * 0.5
		var outward := Vector3(cos(angle), 0, sin(angle))
		player.global_position = outward * 65 + Vector3.UP * 0.15
		player.velocity = Vector3.ZERO
		player.yaw = atan2(outward.x, outward.z)
		await frames(20)
		expect(player.is_on_floor(), "surrounding ground supports player %d" % index)
		Input.action_press(InputSetup.MOVE_FORWARD)
		for tick in 1000:
			await physics_frame
			if Vector2(player.position.x, player.position.z).length() < 10:
				break
		Input.action_release(InputSetup.MOVE_FORWARD)
		await frames(20)
		expect(player.position.y > 23.8 and player.is_on_floor(), "walk from foot back to summit %d" % index)
		expect(not player.climbing, "no wall climbing required %d" % index)
		player.yaw += PI
		Input.action_press(InputSetup.MOVE_FORWARD)
		for tick in 1000:
			await physics_frame
			if Vector2(player.position.x, player.position.z).length() > 64:
				break
		Input.action_release(InputSetup.MOVE_FORWARD)
		await frames(20)
		expect(absf(player.position.y) < 0.15 and player.is_on_floor(), "walk down safely %d" % index)
	var start := player.position.y
	Input.action_press(InputSetup.JUMP)
	await frames(1)
	Input.action_release(InputSetup.JUMP)
	await frames(15)
	expect(player.position.y > start + 0.8, "jump still works")
	await frames(60)
	expect(player.is_on_floor(), "jump lands")
	player.position = Vector3(0, -50, 0)
	await frames(60)
	expect(player.position.y > 23.8 and player.is_on_floor(), "out-of-world fall returns to summit")
	print("Mountain movement: %d checks, %d failed" % [checks, failures])
	quit(1 if failures else 0)

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + message)
	else:
		print("PASS " + message)
