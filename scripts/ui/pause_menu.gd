extends CanvasLayer
## Always-process menu freezes simulation while retaining UI input.
var world: Node
var overlay: Control
var menu: VBoxContainer
var settings: VBoxContainer
var camera_choice: OptionButton
var sensitivity: HSlider
var volume: HSlider
var fullscreen: CheckButton
const SETTINGS_PATH := "user://settings.cfg"
const Text := preload("res://scripts/core/game_text.gd")
var coop_panel: VBoxContainer
var coop_status: Label
var lobby_input: LineEdit
var host_button: Button
var join_button: Button
var leave_button: Button
var invite_button: Button

func _ready() -> void:
	await world.ready
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.05, 0.05, 0.86)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	background.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			resume()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = 360
	stack.add_theme_constant_override("separation", 18)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	var title := Label.new()
	title.text = "HOW TO HUNT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(menu)
	button(menu, "Return to game", resume)
	button(menu, "Settings", func() -> void: menu.hide(); settings.show())
	button(menu, Text.get_text("coop.menu"), func() -> void:
		menu.hide()
		coop_panel.show()
		_refresh_coop()
	)
	button(menu, "Exit", func() -> void:
		world._save_now()
		get_tree().quit()
	)
	settings = VBoxContainer.new()
	settings.add_theme_constant_override("separation", 12)
	stack.add_child(settings)
	label("Camera")
	camera_choice = OptionButton.new()
	camera_choice.add_item("First person")
	camera_choice.add_item("Third person")
	settings.add_child(camera_choice)
	camera_choice.item_selected.connect(func(index: int) -> void:
		if world.player.third_person != (index == 1):
			world.player.toggle_camera()
		save_settings()
	)
	label("Mouse sensitivity")
	sensitivity = slider(0.0005, 0.008, 0.0001, world.player.mouse_sensitivity)
	sensitivity.value_changed.connect(func(value: float) -> void: world.player.mouse_sensitivity = value; save_settings())
	label("Volume")
	volume = slider(0, 1, 0.05, AudioServer.get_bus_volume_linear(0))
	volume.value_changed.connect(func(value: float) -> void: AudioServer.set_bus_volume_linear(0, value); save_settings())
	fullscreen = CheckButton.new()
	fullscreen.text = "Fullscreen"
	settings.add_child(fullscreen)
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
		save_settings()
	)
	button(settings, "Back", func() -> void: settings.hide(); menu.show())
	_build_coop(stack)
	overlay.hide()
	load_settings()

func label(text: String) -> void:
	var control := Label.new()
	control.text = text
	settings.add_child(control)

func slider(low: float, high: float, step_size: float, value: float) -> HSlider:
	var control := HSlider.new()
	control.min_value = low
	control.max_value = high
	control.step = step_size
	control.value = value
	control.custom_minimum_size.y = 28
	settings.add_child(control)
	return control

func button(parent: Node, text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 48
	control.pressed.connect(action)
	parent.add_child(control)

func _input(event: InputEvent) -> void:
	if overlay != null and overlay.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var fields: Control = coop_panel if coop_panel.visible else (settings if settings.visible else menu)
		if not fields.get_global_rect().has_point(event.position):
			resume()
			return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if overlay.visible:
			resume()
		else:
			open_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	world._close_shop()
	world._save_now()
	camera_choice.select(1 if world.player.third_person else 0)
	settings.hide()
	coop_panel.hide()
	menu.show()
	overlay.show()
	get_tree().paused = not world.coop.active
	world.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	save_settings()
	overlay.hide()
	get_tree().paused = false
	world.player.controls_enabled = true
	world._cooldown = maxf(world._cooldown, 0.2)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().set_input_as_handled()

func save_settings() -> void:
	if not world.persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("player", "third_person", world.player.third_person)
	config.set_value("player", "sensitivity", sensitivity.value)
	config.set_value("audio", "volume", volume.value)
	config.set_value("window", "fullscreen", fullscreen.button_pressed)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	if not world.persistence_enabled:
		return
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	world.player.mouse_sensitivity = clampf(float(config.get_value("player", "sensitivity", 0.0025)), 0.0005, 0.008)
	sensitivity.set_value_no_signal(world.player.mouse_sensitivity)
	volume.set_value_no_signal(clampf(float(config.get_value("audio", "volume", 1.0)), 0, 1))
	AudioServer.set_bus_volume_linear(0, volume.value)
	if bool(config.get_value("player", "third_person", false)) != world.player.third_person:
		world.player.toggle_camera()
	fullscreen.set_pressed_no_signal(bool(config.get_value("window", "fullscreen", false)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED)


func _build_coop(parent: Node) -> void:
	coop_panel = VBoxContainer.new()
	coop_panel.add_theme_constant_override("separation", 10)
	parent.add_child(coop_panel)
	var description := Label.new()
	description.text = Text.get_text("coop.description")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 360
	coop_panel.add_child(description)
	coop_status = Label.new()
	coop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coop_panel.add_child(coop_status)
	button(coop_panel, Text.get_text("coop.host"), func() -> void:
		if get_node("/root/SteamService").host_lobby():
			coop_status.text = Text.get_text("coop.connecting")
			host_button.disabled = true
			join_button.disabled = true
	)
	host_button = coop_panel.get_child(coop_panel.get_child_count() - 1)
	lobby_input = LineEdit.new()
	lobby_input.placeholder_text = Text.get_text("coop.lobby_placeholder")
	lobby_input.max_length = 20
	coop_panel.add_child(lobby_input)
	button(coop_panel, Text.get_text("coop.join"), func() -> void:
		var text := lobby_input.text.strip_edges()
		if text.is_valid_int() and int(text) > 0 and get_node("/root/SteamService").join_lobby(int(text)):
			coop_status.text = Text.get_text("coop.connecting")
			host_button.disabled = true
			join_button.disabled = true
		else:
			coop_status.text = Text.get_text("coop.invalid_lobby")
	)
	join_button = coop_panel.get_child(coop_panel.get_child_count() - 1)
	button(coop_panel, Text.get_text("coop.invite"), func() -> void: get_node("/root/SteamService").invite_friends())
	invite_button = coop_panel.get_child(coop_panel.get_child_count() - 1)
	button(coop_panel, Text.get_text("coop.leave"), func() -> void:
		world.coop.stop()
		get_node("/root/SteamService").leave_lobby()
		_refresh_coop()
	)
	leave_button = coop_panel.get_child(coop_panel.get_child_count() - 1)
	button(coop_panel, Text.get_text("coop.back"), func() -> void: coop_panel.hide(); menu.show())
	world.coop.session_changed.connect(func() -> void:
		_refresh_coop()
		if world.coop.active:
			get_tree().paused = false
		else:
			get_tree().paused = overlay.visible
		world.player.controls_enabled = not overlay.visible and not world.shop_open
	)
	world.coop.session_failed.connect(func(reason: String) -> void:
		_refresh_coop()
		coop_status.text = Text.get_text(reason)
		if not overlay.visible:
			open_menu()
			menu.hide()
			coop_panel.show()
	)
	get_node("/root/SteamService").invite_received.connect(func(id: int) -> void:
		open_menu()
		menu.hide()
		coop_panel.show()
		lobby_input.text = str(id)
		_refresh_coop()
	)
	coop_panel.hide()


func _refresh_coop() -> void:
	var steam := get_node("/root/SteamService")
	var busy: bool = world.coop.active
	host_button.disabled = busy or not steam.supports_lobbies()
	join_button.disabled = busy or not steam.supports_lobbies()
	invite_button.visible = busy and world.coop.hosting
	leave_button.visible = busy or not steam._lobby_request.is_empty()
	lobby_input.editable = not busy
	coop_status.text = Text.get_text("coop.connected", [str(steam.lobby_id)]) if busy else Text.get_text("coop.ready" if steam.supports_lobbies() else "coop.unavailable")
