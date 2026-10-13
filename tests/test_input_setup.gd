extends "res://tests/case_base.gd"

const InputSetup := preload("res://scripts/core/input_setup.gd")


func test_all_actions_are_registered_with_at_least_one_event() -> void:
	InputSetup.ensure_actions()
	for action in InputSetup.ALL_ACTIONS:
		assert_true(InputMap.has_action(action), "%s registered" % action)
		assert_true(InputMap.action_get_events(action).size() > 0, "%s has events" % action)


func test_movement_and_jump_have_a_keyboard_binding() -> void:
	InputSetup.ensure_actions()
	for action in [InputSetup.MOVE_FORWARD, InputSetup.MOVE_BACK, InputSetup.MOVE_LEFT,
			InputSetup.MOVE_RIGHT, InputSetup.JUMP, InputSetup.SPRINT]:
		var has_key := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				has_key = true
		assert_true(has_key, "%s has a key" % action)


func test_every_action_has_a_gamepad_binding() -> void:
	InputSetup.ensure_actions()
	for action in InputSetup.ALL_ACTIONS:
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				has_pad = true
		assert_true(has_pad, "%s has a gamepad binding" % action)


func test_ensure_actions_is_idempotent_and_keeps_custom_bindings() -> void:
	# Remember exactly what the InputMap looked like so this test leaves it untouched.
	var existed := InputMap.has_action(InputSetup.JUMP)
	var original_events: Array[InputEvent] = []
	var original_deadzone := 0.5
	if existed:
		original_events = InputMap.action_get_events(InputSetup.JUMP)
		original_deadzone = InputMap.action_get_deadzone(InputSetup.JUMP)

	InputSetup.ensure_actions()
	if not existed:
		# Only a fresh action gets defaults; an existing one is kept as the player left it.
		assert_true(InputMap.action_get_events(InputSetup.JUMP).size() > 0, "jump has default bindings")

	# Simulate the player rebinding jump, then run setup again.
	InputMap.action_erase_events(InputSetup.JUMP)
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_F
	InputMap.action_add_event(InputSetup.JUMP, custom)
	InputSetup.ensure_actions()
	assert_eq(InputMap.action_get_events(InputSetup.JUMP).size(), 1, "custom binding kept")

	# Put everything back the way it was.
	if existed:
		InputMap.action_erase_events(InputSetup.JUMP)
		for event in original_events:
			InputMap.action_add_event(InputSetup.JUMP, event)
		InputMap.action_set_deadzone(InputSetup.JUMP, original_deadzone)
	else:
		InputMap.erase_action(InputSetup.JUMP)
