extends SceneTree
## Minimal headless test runner.
## Usage: godot --headless --path . -s tests/run_tests.gd
## Runs every method starting with "test_" in every tests/test_*.gd file.
## Exits with code 1 if anything fails.

const TESTS_DIR := "res://tests"


func _init() -> void:
	var total := 0
	var failed := 0

	for file_name in _list_test_files():
		var script: GDScript = load("%s/%s" % [TESTS_DIR, file_name])
		if script == null:
			printerr("FAIL  %s: could not load script" % file_name)
			failed += 1
			continue

		for method_name in _list_test_methods(script):
			var test_case: RefCounted = script.new()
			total += 1
			test_case.call(method_name)
			var errors: Array = test_case.get("errors")
			if errors.is_empty():
				print("PASS  %s::%s" % [file_name, method_name])
			else:
				failed += 1
				printerr("FAIL  %s::%s" % [file_name, method_name])
				for error in errors:
					printerr("      %s" % error)

	print("\n%d tests, %d failed" % [total, failed])
	if total == 0:
		# A renamed or missing suite must not leave CI green.
		printerr("FAIL  no tests were discovered")
		failed += 1
	quit(1 if failed > 0 else 0)


func _list_test_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file_name in DirAccess.get_files_at(TESTS_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append(file_name)
	files.sort()
	return files


func _list_test_methods(script: GDScript) -> PackedStringArray:
	var methods := PackedStringArray()
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			methods.append(method_name)
	methods.sort()
	return methods
