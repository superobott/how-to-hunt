extends Control
## The expedition overlay reads game state; all actions remain in the world controller.

const Text := preload("res://scripts/core/game_text.gd")
const INK := Color("182c2d")
const CREAM := Color("fff3db")
const AMBER := Color("ffbc62")
const MINT := Color("a5e2bb")
const MUTED := Color("b7c9bd")

var _world: Node
var _brand: PanelContainer
var _stats: PanelContainer
var _quest: PanelContainer
var _weapon: PanelContainer
var _prompt: PanelContainer
var _toast: PanelContainer
var _shop: PanelContainer
var _shade: ColorRect
var _coins: Label
var _coins_caption: Label
var _party: PanelContainer
var _party_title: Label
var _party_hint: Label
var _level: Label
var _bag: Label
var _mission_progress: ProgressBar
var _quest_title: Label
var _quest_body: Label
var _quest_hint: Label
var _weapon_name: Label
var _weapon_status: Label
var _reload: ProgressBar
var _prompt_label: Label
var _toast_label: Label
var _buy_buttons: Dictionary = {}
var _shop_bag: Label
var _shop_scroll: ScrollContainer
var _save_status: Label
var _controls: Label
var _vitals: PanelContainer
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _health_text: Label
var _stamina_text: Label
var _xp_bar: ProgressBar
var _compass: Label
var _target_card: PanelContainer
var _target_text: Label
var _target_bar: ProgressBar
var _danger: Label
var _fire_controls: Label
var _shop_cards: Dictionary = {}
var _crosshair_visible := true
var _last_message := ""
var _last_revision := -1
var _toast_seconds := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = get_parent().get_parent()
	_build_overlay()
	var pause_menu := preload("res://scripts/ui/pause_menu.gd").new()
	pause_menu.world = _world
	add_child(pause_menu)
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if not is_instance_valid(_world):
		return
	var state: Variant = _world.get("state")
	if state == null:
		return
	_refresh(state)
	var message := str(_world.get("status_message"))
	var revision := int(_world.get("status_revision"))
	if message != _last_message or revision != _last_revision:
		_last_message = message
		_last_revision = revision
		_toast_seconds = 4.5 if not message.is_empty() else 0.0
		_toast_label.text = message
	_toast_seconds = maxf(0.0, _toast_seconds - delta)
	_toast.visible = _toast_seconds > 0.0
	queue_redraw()
	var next_crosshair: bool = not bool(_world.get("shop_open"))
	if _crosshair_visible != next_crosshair:
		_crosshair_visible = next_crosshair
		queue_redraw()


func _draw() -> void:
	if not _crosshair_visible:
		return
	var center := size * 0.5
	var shadow := Color(INK, 0.65)
	for offset in [Vector2(-9, 0), Vector2(5, 0)]:
		draw_line(center + offset, center + offset + Vector2(4, 0), shadow, 4.0)
		draw_line(center + offset, center + offset + Vector2(4, 0), CREAM, 2.0)
	for offset in [Vector2(0, -9), Vector2(0, 5)]:
		draw_line(center + offset, center + offset + Vector2(0, 4), shadow, 4.0)
		draw_line(center + offset, center + offset + Vector2(0, 4), CREAM, 2.0)
	draw_circle(center, 1.6, AMBER)
	if float(_world.hit_marker) > 0:
		for side in [-1.0, 1.0]:
			draw_line(center + Vector2(side * 12, -12), center + Vector2(side * 5, -5), AMBER, 2)
			draw_line(center + Vector2(side * 12, 12), center + Vector2(side * 5, 5), AMBER, 2)
	if float(_world.hurt_flash) > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.12, 0.08, _world.hurt_flash * 0.3), false, 16)


func _build_overlay() -> void:
	_brand = _card(self, Color(INK, 0.90), Color(MINT, 0.25))
	var brand_stack := _stack(_brand, 5)
	_label(brand_stack, Text.get_text("hud.brand"), 18, CREAM)
	_label(brand_stack, Text.get_text("hud.expedition"), 10, MINT)

	_brand.hide()
	_stats = _card(self)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 26)
	_stats.add_child(stat_row)
	_coins = _stat(stat_row, "hud.coins_caption", AMBER)
	_coins_caption = _coins.get_parent().get_child(0)
	_level = _stat(stat_row, "hud.level_caption", MINT)
	_bag = _stat(stat_row, "hud.bag_caption", CREAM)
	_party = _card(self, Color(INK, 0.94), Color(MINT, 0.45))
	var party_stack := _stack(_party, 7)
	_party_title = _label(party_stack, "", 14, MINT)
	_party_hint = _label(party_stack, "", 12, CREAM, true)
	_party.hide()

	_quest = _card(self)
	var quest_stack := _stack(_quest, 8)
	_label(quest_stack, Text.get_text("hud.objective_caption"), 10, MINT)
	_quest_title = _label(quest_stack, "", 19, CREAM)
	_quest_body = _label(quest_stack, "", 14, CREAM, true)
	_quest_hint = _label(quest_stack, "", 12, MUTED, true)
	_mission_progress = _meter(quest_stack, AMBER)

	_weapon = _card(self)
	var weapon_stack := _stack(_weapon, 7)
	_weapon_name = _label(weapon_stack, "", 18, CREAM)
	_weapon_status = _label(weapon_stack, "", 12, AMBER)
	_reload = ProgressBar.new()
	_reload.custom_minimum_size.y = 5
	_reload.show_percentage = false
	_reload.max_value = 1.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(CREAM, 0.13)
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.set_corner_radius_all(3)
	_reload.add_theme_stylebox_override("background", track)
	_reload.add_theme_stylebox_override("fill", fill)
	weapon_stack.add_child(_reload)
	_fire_controls = _label(weapon_stack, "", 11, MUTED)

	_vitals = _card(self, Color(INK, 0.88))
	var vital_stack := _stack(_vitals, 5)
	_health_text = _label(vital_stack, "", 12, CREAM)
	_health_bar = _meter(vital_stack, Color("e88c76"))
	_stamina_text = _label(vital_stack, "", 11, MUTED)
	_stamina_bar = _meter(vital_stack, MINT)
	_label(vital_stack, "HUNTER EXPERIENCE", 9, MUTED)
	_xp_bar = _meter(vital_stack, AMBER)
	_compass = _label(self, "", 13, CREAM)
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.add_theme_color_override("font_shadow_color", INK)
	_compass.add_theme_constant_override("shadow_offset_y", 2)
	_target_card = _card(self, Color(INK, 0.8))
	var target_stack := _stack(_target_card, 5)
	_target_text = _label(target_stack, "", 13, CREAM)
	_target_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_bar = _meter(target_stack, Color("e88c76"))
	_target_card.visible = false
	_danger = _label(self, "", 16, Color("ffb099"))
	_danger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger.add_theme_color_override("font_shadow_color", INK)
	_danger.add_theme_constant_override("shadow_offset_y", 2)
	_controls = _label(self, Text.get_text("hud.move_controls"), 11, CREAM)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_color_override("font_shadow_color", INK)
	_controls.add_theme_constant_override("shadow_offset_y", 2)

	_prompt = _card(self, Color(INK, 0.95), Color(AMBER, 0.6))
	_prompt_label = _label(_prompt, "", 17, CREAM, true)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_toast = _card(self, Color(INK, 0.96), Color(MINT, 0.55))
	_toast.z_index = 1
	_toast_label = _label(_toast, "", 15, CREAM, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false

	_shade = ColorRect.new()
	_shade.color = Color(0.025, 0.065, 0.065, 0.61)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_shade.visible = false
	_shop = _card(self, Color(INK, 0.99), Color(AMBER, 0.6))
	var shop_stack := _stack(_shop, 15)
	_label(shop_stack, Text.get_text("shop.caption"), 11, MINT)
	_label(shop_stack, Text.get_text("shop.title"), 30, CREAM)
	_label(shop_stack, Text.get_text("shop.intro"), 14, MUTED, true)
	_rule(shop_stack)
	_shop_bag = _label(shop_stack, "", 22, AMBER)
	var filters := OptionButton.new()
	filters.add_item("All stock")
	filters.add_item("Weapons")
	filters.add_item("Equipment")
	filters.add_item("Vehicles")
	filters.item_selected.connect(_filter_shop)
	shop_stack.add_child(filters)
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.custom_minimum_size.y = 320
	shop_stack.add_child(_shop_scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_shop_scroll.add_child(grid)
	for category in ["tools", "gear"]:
		var catalog: Dictionary = _world.state.catalog[category]
		for id in catalog:
			var item: Dictionary = catalog[id]
			var card := _card(grid, Color("20383a"))
			card.set_meta("category", "vehicles" if item.get("vehicle", false) else category)
			_shop_cards[id] = card
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var details := _stack(card, 7)
			_label(details, ("MELEE" if id == "knife" else "BOW") if category == "tools" else ("VEHICLE" if item.get("vehicle", false) else "PERMANENT EQUIPMENT"), 10, MINT)
			_label(details, _tool_name(item), 20, CREAM)
			var description := str(item.get("description", ""))
			if category == "tools":
				description = "%d damage / %d m/s / %.2fs reload" % [item["damage"], item["speed"], item["reload"]]
				if id == "knife":
					description = "18 damage / 2.5m reach / Right-click guard"
			var picture := TextureRect.new()
			picture.texture = load("res://data/icons/%s.svg" % id)
			picture.custom_minimum_size = Vector2(160, 80)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			details.add_child(picture)
			_label(details, "%d COINS" % item["price"], 26, AMBER)
			var info := Button.new()
			info.text = "(i) Details"
			info.tooltip_text = description
			info.pressed.connect(func() -> void:
				var dialog := AcceptDialog.new()
				dialog.title = _tool_name(item)
				dialog.dialog_text = description + "\nPrice: %d coins" % item["price"]
				add_child(dialog)
				dialog.popup_centered(Vector2i(420, 180))
				dialog.confirmed.connect(dialog.queue_free)
				dialog.canceled.connect(dialog.queue_free)
			)
			details.add_child(info)
			var button := Button.new()
			button.custom_minimum_size = Vector2(180, 40)
			button.pressed.connect(func() -> void: _world.buy_item(str(id)))
			details.add_child(button)
			_buy_buttons[id] = button
	_rule(shop_stack)
	var close_button := Button.new()
	close_button.text = "Return to the hunt"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(func() -> void: _world._close_shop())
	shop_stack.add_child(close_button)
	var shop_footer := HBoxContainer.new()
	shop_footer.add_theme_constant_override("separation", 18)
	shop_stack.add_child(shop_footer)
	_label(shop_footer, Text.get_text("shop.close_controls"), 12, CREAM)
	_save_status = _label(shop_footer, "", 11, MUTED)
	_save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop.visible = false
	_ignore_mouse(self)
	_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh(state: Variant) -> void:
	var session: Node = _world.coop
	var online: bool = session != null and session.active
	_coins_caption.text = Text.get_text("hud.shared_coins" if online else "hud.coins_caption")
	_party.visible = online and not _world.shop_open
	if online:
		var hunters: int = session.actors.size() + 1 if session.hosting else (session.avatars.size() + 1 if session._last_snapshot >= 0 else 0)
		_party_title.text = Text.get_text("hud.party_host" if session.hosting else "hud.party_guest", [hunters]) if hunters > 0 else Text.get_text("coop.connecting")
		_party_hint.text = Text.get_text("hud.host_progress" if session.hosting else "hud.guest_progress")
	_coins.text = Text.get_text("hud.coins", [state.coins])
	_level.text = Text.get_text("hud.level", [state.level()])
	_bag.text = str(state.hunts)
	var tool: Dictionary = state.catalog["tools"]["knife"] if _world.using_knife() else state.tool()
	_weapon_name.text = _tool_name(tool, str(state.tool_id))
	_fire_controls.text = "LMB slash / RMB guard / Q switch" if _world.using_knife() else "LMB fire / RMB aim / Q knife"
	_health_text.text = "HEALTH  %d / 100" % int(_world.health)
	_health_bar.value = _world.health
	_stamina_text.text = ("STAMINA  %d / RECOVERING" if _world.player.sprint_exhausted else "STAMINA  %d") % int(_world.player.stamina)
	_stamina_bar.value = _world.player.stamina
	_xp_bar.value = int(state.xp) % 100
	var safe: bool = Vector2(_world.player.position.x, _world.player.position.z).length() < 14
	var bearing: Vector3 = _world.TRADER_POINT - _world.player.position
	var local_bearing: Vector3 = _world.player.global_basis.inverse() * bearing
	var direction := ("ahead" if local_bearing.z < 0 else "behind") if absf(local_bearing.x) < 3 else ("left" if local_bearing.x < 0 else "right")
	_compass.text = "SUMMIT  /  SAFE & RECOVERING" if safe else "WILDERNESS  /  Store %dm %s" % [int(bearing.length()), direction]
	_danger.text = _world.threat_text
	if not safe and _world.health < 30 and _danger.text.is_empty():
		_danger.text = "Low health - return uphill to recover"
	_target_card.visible = is_instance_valid(_world.target) and not _world.shop_open
	if _target_card.visible:
		var prey: Node3D = _world.target
		_target_text.text = Text.get_text(prey.definition["name_key"]) + (" / RARE" if prey.rare else "")
		_target_bar.value = prey.health / float(prey.definition["hp"]) * 100
	_weapon_status.text = "Guarding" if _world.player.guarding else "Ready"
	var cooldown: float = clampf(float(_world.get("cooldown_ratio")), 0.0, 1.0)
	_reload.value = 1.0 - cooldown
	_weapon_status.text = "Guarding" if _world.player.guarding else Text.get_text("hud.reloading" if cooldown > 0.0 else "hud.ready")
	_reload.modulate = Color.WHITE if cooldown > 0.0 else MINT
	var prompt_text: String = _world.interaction_text()
	_prompt_label.text = prompt_text
	_prompt.visible = not prompt_text.is_empty() and not bool(_world.get("shop_open"))
	_refresh_objective(state)
	var show_shop: bool = bool(_world.get("shop_open"))
	_shop.visible = show_shop
	_shade.visible = show_shop
	if not show_shop:
		_toast.position.y = 194.0
	if show_shop:
		_shop_bag.text = Text.get_text("hud.shared_wallet" if online else "hud.solo_wallet", [state.coins])
		for id in _buy_buttons:
			var gear: bool = state.catalog["gear"].has(id)
			var item: Dictionary = state.catalog["gear" if gear else "tools"][id]
			var button: Button = _buy_buttons[id]
			var cost := int(item["price"])
			var owned: bool = id in state.owned_gear if gear else cost <= int(state.tool()["price"])
			button.disabled = owned or state.coins < cost
			button.text = "Equipped" if id == state.tool_id else ("Owned" if owned else ("Buy / %d coins" % cost))
			button.tooltip_text = "Already owned" if owned else ("Click to buy and equip" if state.coins >= cost else "Need %d more coins" % (cost - state.coins))
		if online and session.is_guest():
			_save_status.text = Text.get_text("hud.guest_save")
		elif not bool(_world.get("persistence_enabled")):
			_save_status.text = Text.get_text("hud.preview")
		else:
			_save_status.text = Text.get_text("hud.autosave" if bool(_world.get("autosave_ok")) else "hud.save_failed")
		_fit_shop()


func _refresh_objective(state: Variant) -> void:
	var current: int
	var target_amount: int
	if state.tool_id == "knife":
		_quest_title.text = Text.get_text("goal.first_bow")
		_quest_body.text = Text.get_text("goal.first_bow_hint")
		target_amount = int(state.next_tool()["price"])
		current = mini(state.coins, target_amount)
		_quest_hint.text = Text.get_text("goal.coins", [current, target_amount])
	elif state.level() < 4:
		_quest_title.text = Text.get_text("goal.level_four")
		_quest_body.text = Text.get_text("goal.level_four_hint")
		target_amount = 3 * int(state.catalog["progression"]["xp_per_level"])
		current = mini(state.xp, target_amount)
		_quest_hint.text = Text.get_text("goal.xp", [current, target_amount])
	else:
		_quest_title.text = Text.get_text("goal.master")
		_quest_body.text = Text.get_text("goal.master_hint")
		target_amount = 100
		current = mini(state.hunts, target_amount)
		_quest_hint.text = Text.get_text("goal.hunts", [current, target_amount])
		if current == target_amount:
			_quest_title.text = Text.get_text("goal.master_complete")
			_quest_body.text = Text.get_text("goal.master_complete_hint")
	_mission_progress.max_value = target_amount
	_mission_progress.value = current


func _filter_shop(index: int) -> void:
	for card: Control in _shop_cards.values():
		card.visible = index == 0 or card.get_meta("category") == ["", "tools", "gear", "vehicles"][index]
	_shop_scroll.scroll_vertical = 0


func _meter(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(CREAM, 0.12)
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _tool_name(tool: Dictionary, fallback: String = "starter_bow") -> String:
	var key := str(tool.get("name_key", "tool." + str(tool.get("id", fallback))))
	return Text.get_text(key)


func _layout() -> void:
	if _brand == null:
		return
	var margin := 26.0 if size.x >= 1100.0 else 16.0
	_place(_brand, Vector2(margin, margin), Vector2(256, 65))
	_place(_stats, Vector2(size.x - margin - 378, margin), Vector2(378, 65))
	_place(_party, Vector2(size.x - margin - 378, margin + 90), Vector2(378, 100))
	_place(_quest, Vector2(margin, margin), Vector2(282, 112))
	_place(_vitals, Vector2(margin, size.y - margin - 130), Vector2(282, 130))
	_place(_compass, Vector2(size.x * 0.5 - 220, 30), Vector2(440, 30))
	_place(_target_card, Vector2(size.x * 0.5 - 140, 88), Vector2(280, 62))
	_place(_danger, Vector2(size.x * 0.5 - 280, 155), Vector2(560, 26))
	_place(_weapon, Vector2(size.x - margin - 256, size.y - margin - 110), Vector2(256, 110))
	_place(_controls, Vector2(0, size.y - 25), Vector2(size.x, 18))
	var prompt_width := minf(390.0, size.x - 48.0)
	var prompt_y := size.y - 94.0
	_place(_prompt, Vector2((size.x - prompt_width) * 0.5, prompt_y), Vector2(prompt_width, 54))
	_place(_toast, Vector2((size.x - 460) * 0.5, 194), Vector2(460, 52))
	var shop_width := minf(900.0, size.x - 40.0)
	_shop.size.x = shop_width
	_fit_shop()
	queue_redraw()


func _fit_shop() -> void:
	# Wrapped labels can initially grow the panel before containers know their width.
	# Reapply the settled content minimum so that temporary growth never persists.
	_shop_scroll.custom_minimum_size.y = clampf(size.y - 405.0, 120.0, 400.0)
	_shop.size = Vector2(minf(900.0, size.x - 40.0), _shop.get_combined_minimum_size().y)
	_shop.position = (size - _shop.size) * 0.5
	_toast.position.y = maxf(18.0, _shop.position.y - 64.0) if _shop.visible else 194.0


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions


func _card(parent: Node, background: Color = Color(INK, 0.94), border: Color = Color(MINT, 0.22)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _stack(parent: Node, separation: int) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", separation)
	parent.add_child(stack)
	return stack


func _label(parent: Node, content: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _stat(parent: Node, caption_key: String, color: Color) -> Label:
	var stack := _stack(parent, 4)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(stack, Text.get_text(caption_key), 10, MUTED)
	return _label(stack, "", 23, color)


func _rule(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(MINT, 0.18)
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)


func _ignore_mouse(node: Node) -> void:
	if node is Button:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is ScrollContainer or node is ScrollBar:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
