extends SceneTree
const Animal := preload("res://scripts/hunting/animal.gd")
const Arrow := preload("res://scripts/hunting/arrow.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
var checks := 0
var failures := 0
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	_run()

func _run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	world.persistence_enabled = false
	world.wildlife_enabled = false
	root.add_child(world)
	await process_frame
	player = world.player
	await frames(45)
	expect(world.state.tool_id == "knife", "fresh expedition equips knife")
	expect(world._knife.visible and not world._bow.visible, "only knife model is visible")
	expect(not world.fire_arrow(), "knife cannot fire projectiles")
	player.position = Vector3(0, 0.1, 60)
	player.velocity = Vector3.ZERO
	player.yaw = 0
	var ant := spawn("ant", Vector3(0, 0.1, 58.7))
	ant.set_physics_process(false)
	await frames(5)
	player.get_node("Head/Camera").look_at(ant.position + Vector3.UP * 0.2)
	expect(world.attack(), "knife swings at nearby ant")
	expect(not world.attack(), "knife cooldown rejects immediate repeat")
	await frames(2)
	expect(not is_instance_valid(ant), "close-range knife hit defeats ant")
	expect(world.state.hunts == 1 and world.state.coins >= 3, "ant coins collect automatically")
	for child in world.get_children():
		expect(child.get_script() != Arrow, "melee emits no arrow")
	await frames(40)
	ant = spawn("ant", Vector3(0, 0.1, 56))
	ant.set_physics_process(false)
	player.get_node("Head/Camera").look_at(ant.position + Vector3.UP * 0.2)
	world.attack()
	await frames(2)
	expect(is_instance_valid(ant) and ant.health == 10, "knife cannot hit a distant ant")
	ant.queue_free()
	await frames(40)
	ant = spawn("ant", Vector3(0, 0.1, 58.7))
	ant.set_physics_process(false)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.2, 59.4)
	world.add_child(wall)
	await frames(2)
	player.get_node("Head/Camera").look_at(ant.position + Vector3.UP * 0.2)
	world.attack()
	await frames(2)
	expect(is_instance_valid(ant) and ant.health == 10, "wall blocks melee arc")
	wall.queue_free()
	ant.queue_free()
	await frames(40)
	player.stamina = 0
	expect(not world.attack(), "exhaustion prevents knife attack")
	player.stamina = 100
	world.health = 100
	player.guarding = false
	world.take_player_damage(20, player.position + Vector3.FORWARD)
	expect(world.health == 80, "hostile attack damages player")
	world.take_player_damage(20, player.position + Vector3.FORWARD)
	expect(world.health == 80, "damage grace prevents stacked instant hits")
	await frames(45)
	player.guarding = true
	world.take_player_damage(20, player.position + Vector3.FORWARD)
	expect(world.health == 75, "frontal knife guard blocks 75 percent")
	await frames(45)
	world.health = 10
	world.state.coins = 100
	player.guarding = false
	world.take_player_damage(30, player.position + Vector3.FORWARD)
	expect(world.health == 100 and player.position.y > 24, "defeat restores hunter at summit")
	expect(world.state.coins == 90, "defeat costs ten percent of coins")
	world.health = 50
	world.take_player_damage(50, player.position)
	expect(world.health == 50, "summit is safe")
	await frames(60)
	expect(world.health > 60, "summit heals hunter")
	player.position = Vector3(0, 0.1, 65)
	player.velocity = Vector3.ZERO
	var bird := spawn("bird", Vector3(0, 0.1, 62))
	bird.player = player
	await frames(90)
	expect(bird.position.y > 1.5, "approached bird takes flight")
	expect(bird._wings.size() == 2, "bird retains animated wings")
	bird.queue_free()
	var wolf := spawn("wolf", player.position + Vector3(0, 0.1, -2))
	wolf.player = player
	wolf.attacked.connect(world.take_player_damage)
	await frames(5)
	expect(wolf.attack_windup > 0, "predator telegraphs close attack")
	var before: float = world.health
	await frames(60)
	expect(world.health < before, "predator attack reaches player after windup")
	wolf.queue_free()
	await frames(3)
	player.position = Vector3(0, 0.1, 60)
	player.stamina = 6
	Input.action_press(InputSetup.MOVE_FORWARD)
	Input.action_press(InputSetup.SPRINT)
	await frames(10)
	expect(player.sprint_exhausted, "sprint exhaustion latches instead of flickering")
	Input.action_release(InputSetup.SPRINT)
	Input.action_release(InputSetup.MOVE_FORWARD)
	await frames(65)
	expect(not player.sprint_exhausted and player.stamina >= 30, "rest restores sprint")
	world.state.tool_id = "starter_bow"
	var swap := InputEventKey.new()
	swap.physical_keycode = KEY_Q
	swap.pressed = true
	world._unhandled_input(swap)
	expect(world.using_knife(), "Q returns to knife after buying a bow")
	world._unhandled_input(swap)
	expect(not world.using_knife(), "Q restores equipped bow")
	# A purchased bow must never lend its damage/reload to the selected knife.
	world.state.tool_id = "viking_bow"
	world._knife_selected = true
	world._cooldown = 0.0
	player.stamina = 100.0
	player.position = Vector3(0, 0.1, 60)
	player.velocity = Vector3.ZERO
	var prey := spawn("bear", Vector3(0, 0.1, 58.7))
	prey.set_physics_process(false)
	await frames(5)
	player.get_node("Head/Camera").look_at(prey.position + Vector3.UP * prey._body_radius)
	var prey_health: float = prey.health
	expect(world.attack(), "knife still swings while a high-tier bow is owned")
	expect(is_equal_approx(prey.health, prey_health - float(world.state.catalog.tools.knife.damage)), "knife damage does not inherit owned bow damage")
	expect(is_equal_approx(world._cooldown, float(world.state.catalog.tools.knife.reload)), "knife reload does not inherit owned bow reload")
	prey.queue_free()
	# The dropped currency has geometry and sparkles, never floating text.
	world._on_animal_defeated("bird", false, false, Vector3(0, 5, 50))
	await frames(2)
	for coin in get_nodes_in_group("hunt_loot"):
		var labels := coin.find_children("*", "Label3D", true, false)
		expect(labels.is_empty(), "coins carry no floating labels")
	print("Survival: %d checks, %d failed" % [checks, failures])
	quit(1 if failures else 0)

func spawn(id: String, at: Vector3) -> CharacterBody3D:
	var animal := Animal.new()
	animal.animal_id = id
	animal.definition = world.state.animal(id)
	animal.inner_radius = 15
	animal.outer_radius = 80
	animal.position = at
	animal.home = at
	animal.defeated.connect(world._on_animal_defeated)
	world.add_child(animal)
	return animal

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS " + message)
	else:
		failures += 1
		printerr("FAIL " + message)
