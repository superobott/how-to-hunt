extends Control
## Minimal placeholder HUD: game title and Steam status in the top-left corner.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.position = Vector2(16.0, 12.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.text = "How to Hunt  |  %s" % _steam_status_text()
	add_child(label)


func _steam_status_text() -> String:
	var steam := get_node_or_null("/root/SteamService")
	if steam == null:
		return "Steam service missing"
	if steam.is_available():
		return "Steam: online as %s" % steam.get_persona_name()
	return "Steam: offline"
