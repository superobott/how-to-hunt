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
var _level: Label
var _bag: Label
var _quest_title: Label
var _quest_body: Label
var _quest_hint: Label
var _weapon_name: Label
var _weapon_status: Label
var _reload: ProgressBar
var _prompt_label: Label
var _toast_label: Label
var _shop_bag: Label
var _shop_upgrade: Label
var _shop_details: Label
var _save_status: Label
var _controls: Label
var _crosshair_visible := true
var _last_message := ""
var _last_revision := -1
var _toast_seconds := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = get_parent().get_parent()
	_build_overlay()
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


func _build_overlay() -> void:
	_brand = _card(self, Color(INK, 0.90), Color(MINT, 0.25))
	var brand_stack := _stack(_brand, 5)
	_label(brand_stack, Text.get_text("hud.brand"), 22, CREAM)
	_label(brand_stack, Text.get_text("hud.expedition"), 10, MINT)

	_stats = _card(self)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 26)
	_stats.add_child(stat_row)
	_coins = _stat(stat_row, "hud.coins_caption", AMBER)
	_level = _stat(stat_row, "hud.level_caption", MINT)
	_bag = _stat(stat_row, "hud.bag_caption", CREAM)

	_quest = _card(self)
	var quest_stack := _stack(_quest, 8)
	_label(quest_stack, Text.get_text("hud.objective_caption"), 10, MINT)
	_quest_title = _label(quest_stack, "", 19, CREAM)
	_quest_body = _label(quest_stack, "", 14, CREAM, true)
	_quest_hint = _label(quest_stack, "", 12, MUTED, true)

	_weapon = _card(self)
	var weapon_stack := _stack(_weapon, 7)
	_label(weapon_stack, Text.get_text("hud.equipped_caption"), 10, MINT)
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
	_label(weapon_stack, Text.get_text("hud.fire_controls"), 11, MUTED)

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
	_label(shop_stack, Text.get_text("shop.sell_controls"), 13, CREAM)
	_rule(shop_stack)
	_shop_upgrade = _label(shop_stack, "", 20, CREAM, true)
	_shop_details = _label(shop_stack, "", 13, MUTED, true)
	_label(shop_stack, Text.get_text("shop.upgrade_controls"), 13, AMBER)
	_rule(shop_stack)
	var shop_footer := HBoxContainer.new()
	shop_footer.add_theme_constant_override("separation", 18)
	shop_stack.add_child(shop_footer)
	_label(shop_footer, Text.get_text("shop.close_controls"), 12, CREAM)
	_save_status = _label(shop_footer, "", 11, MUTED)
	_save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop.visible = false
	_ignore_mouse(self)


func _refresh(state: Variant) -> void:
	_coins.text = Text.get_text("hud.coins", [state.coins])
	_level.text = Text.get_text("hud.level", [state.level()])
	_bag.text = Text.get_text("hud.bag", [state.inventory.size(), state.capacity()])
	var tool: Dictionary = state.tool()
	_weapon_name.text = _tool_name(tool, str(state.tool_id))
	var cooldown: float = clampf(float(_world.get("cooldown_ratio")), 0.0, 1.0)
	_reload.value = 1.0 - cooldown
	_weapon_status.text = Text.get_text("hud.reloading" if cooldown > 0.0 else "hud.ready")
	_reload.modulate = Color.WHITE if cooldown > 0.0 else MINT
	var prompt_text: String = _world.interaction_text()
	_prompt_label.text = prompt_text
	_prompt.visible = not prompt_text.is_empty() and not bool(_world.get("shop_open"))
	_refresh_objective(state)
	var show_shop: bool = bool(_world.get("shop_open"))
	_shop.visible = show_shop
	_shade.visible = show_shop
	if not show_shop:
		_toast.position.y = 124.0
	if show_shop:
		_shop_bag.text = Text.get_text("shop.bag_value", [state.bag_value(), state.inventory.size()])
		var next: Dictionary = state.next_tool()
		if next.is_empty():
			_shop_upgrade.text = Text.get_text("shop.max_tool")
			_shop_details.text = Text.get_text("shop.max_tool_detail")
		else:
			var cost: int = int(next.get("price", next.get("cost", 0)))
			_shop_upgrade.text = Text.get_text("shop.next_tool", [_tool_name(next), cost])
			_shop_details.text = Text.get_text("shop.can_afford" if int(state.coins) >= cost else "shop.need_coins", [maxi(0, cost - int(state.coins))])
		if not bool(_world.get("persistence_enabled")):
			_save_status.text = Text.get_text("hud.preview")
		else:
			_save_status.text = Text.get_text("hud.autosave" if bool(_world.get("autosave_ok")) else "hud.save_failed")
		_fit_shop()


func _refresh_objective(state: Variant) -> void:
	if int(state.hunts) == 0:
		_quest_title.text = Text.get_text("quest.first_title")
		_quest_body.text = Text.get_text("quest.first_body")
		_quest_hint.text = Text.get_text("quest.first_hint")
	elif not state.inventory.is_empty():
		_quest_title.text = Text.get_text("quest.sell_title")
		_quest_body.text = Text.get_text("quest.sell_body", [state.bag_value()])
		_quest_hint.text = Text.get_text("quest.sell_hint")
	elif int(state.coins) == 0 and str(state.tool_id) == "starter_bow":
		_quest_title.text = Text.get_text("quest.collect_title")
		_quest_body.text = Text.get_text("quest.collect_body")
		_quest_hint.text = Text.get_text("quest.collect_hint")
	elif not state.next_tool().is_empty():
		var next: Dictionary = state.next_tool()
		var cost: int = int(next.get("price", next.get("cost", 0)))
		_quest_title.text = Text.get_text("quest.upgrade_title")
		_quest_body.text = Text.get_text("quest.upgrade_body", [_tool_name(next), cost])
		_quest_hint.text = Text.get_text("quest.upgrade_ready" if int(state.coins) >= cost else "quest.upgrade_hint")
	else:
		_quest_title.text = Text.get_text("quest.explore_title")
		_quest_body.text = Text.get_text("quest.explore_body")
		_quest_hint.text = Text.get_text("quest.explore_hint", [state.hunts, state.xp])


func _tool_name(tool: Dictionary, fallback: String = "starter_bow") -> String:
	var key := str(tool.get("name_key", "tool." + str(tool.get("id", fallback))))
	return Text.get_text(key)


func _layout() -> void:
	if _brand == null:
		return
	var margin := 26.0 if size.x >= 1100.0 else 16.0
	_place(_brand, Vector2(margin, margin), Vector2(256, 82))
	_place(_stats, Vector2(size.x - margin - 378, margin), Vector2(378, 82))
	_place(_quest, Vector2(margin, size.y - margin - 176), Vector2(328, 176))
	_place(_weapon, Vector2(size.x - margin - 256, size.y - margin - 142), Vector2(256, 142))
	_place(_controls, Vector2(0, size.y - 25), Vector2(size.x, 18))
	var prompt_width := minf(470.0, size.x - 48.0)
	var prompt_y := minf(size.y * 0.69, size.y - margin - 240.0)
	_place(_prompt, Vector2((size.x - prompt_width) * 0.5, prompt_y), Vector2(prompt_width, 54))
	_place(_toast, Vector2((size.x - 500) * 0.5, 124), Vector2(500, 52))
	var shop_width := minf(560.0, size.x - 40.0)
	_shop.size.x = shop_width
	_fit_shop()
	queue_redraw()


func _fit_shop() -> void:
	# Wrapped labels can initially grow the panel before containers know their width.
	# Reapply the settled content minimum so that temporary growth never persists.
	_shop.size = Vector2(minf(560.0, size.x - 40.0), _shop.get_combined_minimum_size().y)
	_shop.position = (size - _shop.size) * 0.5
	_toast.position.y = maxf(18.0, _shop.position.y - 64.0) if _shop.visible else 124.0


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
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
