extends RefCounted
## Keep the last valid save as a backup, promoting a flushed temporary file last.

const HuntState := preload("res://scripts/core/hunt_state.gd")
const DEFAULT_PATH := "user://hunt_save.json"
const MAX_SAVE_BYTES := 65536


static func save_state(state: RefCounted, path: String = DEFAULT_PATH) -> bool:
	var snapshot: Dictionary = state.call("snapshot")
	var validator := HuntState.new()
	if not validator.restore(snapshot):
		return false
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _valid_file(temporary_path):
		return false
	# Never overwrite a good backup with a corrupt main save.
	if _valid_file(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(temporary_path, path) == OK


static func load_state(state: RefCounted, path: String = DEFAULT_PATH) -> bool:
	# The backup is the last committed save. A leftover temporary file is only a
	# final recovery option when neither committed file can be read.
	for candidate in [path, path + ".bak", path + ".tmp"]:
		var data := _read(candidate)
		if not data.is_empty() and bool(state.call("restore", data)):
			return true
	return false


static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {}
	var content := file.get_as_text()
	file.close()
	# JSON.parse_string logs an engine error for damaged user files. The parser
	# instance reports failure as a return value so recovery stays quiet.
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary else {}


static func _valid_file(path: String) -> bool:
	var data := _read(path)
	return not data.is_empty() and HuntState.new().restore(data)
