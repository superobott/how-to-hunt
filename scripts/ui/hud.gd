extends Control
## Placeholder boot screen: shows the title and whether Steam is available.


func _ready() -> void:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.text = "How to Hunt\n%s" % _steam_status_text()
	add_child(label)


func _steam_status_text() -> String:
	var steam := get_node_or_null("/root/SteamService")
	if steam == null:
		return "Steam service missing"
	if steam.is_available():
		return "Steam: online as %s" % steam.get_persona_name()
	return "Steam: offline"
