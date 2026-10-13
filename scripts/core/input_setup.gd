extends RefCounted
## Registers the default input actions (keyboard, mouse and gamepad) at startup.
## Actions are created in code so bindings stay readable in diffs. The settings menu will
## rebind them later through the same action names.

const MOVE_FORWARD := "move_forward"
const MOVE_BACK := "move_back"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const JUMP := "jump"
const SPRINT := "sprint"
const LOOK_LEFT := "look_left"
const LOOK_RIGHT := "look_right"
const LOOK_UP := "look_up"
const LOOK_DOWN := "look_down"

const STICK_DEADZONE := 0.2

const ALL_ACTIONS: Array[String] = [
	MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT, JUMP, SPRINT,
	LOOK_LEFT, LOOK_RIGHT, LOOK_UP, LOOK_DOWN,
]


## Adds every default action that does not exist yet. Safe to call more than once, and it never
## overwrites bindings the player changed.
static func ensure_actions() -> void:
	_ensure(MOVE_FORWARD, [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_ensure(MOVE_BACK, [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_ensure(MOVE_LEFT, [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_ensure(MOVE_RIGHT, [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_ensure(JUMP, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_ensure(SPRINT, [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])
	_ensure(LOOK_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_ensure(LOOK_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_ensure(LOOK_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_ensure(LOOK_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])


static func _ensure(action: String, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, STICK_DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
